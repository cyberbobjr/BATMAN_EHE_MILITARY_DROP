-- ============================================================================
-- Military Drop — échange radio avec la base (client et serveur)
--
-- Tout échange (rapport, plaques d'identité vanilla, missions, poste de liaison, appel de
-- largage) passe par une radio militaire allumée sur la fréquence militaire :
-- tenue en main, posée à MilitaryDrop.Radio.MAX_WORLD_DISTANCE cases au plus,
-- ou le poste de liaison. Le code de la semaine ne sert qu'aux largages
-- (AUTH-01 sans objet).
--
-- Côté client (AUTH-03) : si le talkie est à la ceinture, sur le dos ou dans
-- un sac, le personnage le prend en main par l'action vanilla d'équipement
-- (ISInventoryPaneContextMenu.equipWeapon), puis le garde en main. En MP, le
-- serveur n'applique l'état d'une radio d'inventaire (allumage, canal) que si
-- elle est en main au moment du changement (GameServer.java:3499-3519), et la
-- prise en main ne lui renvoie rien : l'état réglé à la ceinture resterait
-- périmé côté serveur. En MP, le client renvoie donc l'état de TOUTE radio
-- d'inventaire au début de l'action, une fois en main, même si elle y était
-- déjà (réglée hors de la main, le serveur avait ignoré son état) :
-- setIsTurnedOn puis setChannel, qui émettent le paquet RadioDeviceDataState
-- (DeviceData.java:470-485, 550-565). L'appel de largage passe aussi par là.
-- Puis une courte action chronométrée (MilitaryDrop.ExchangeAction) : le
-- personnage parle, et la commande part au serveur à la fin de l'action.
-- L'action n'a pas de complete() : en MP elle reste côté client
-- (useCustomRemoteTimedActionSync, LuaTimedActionNew.java:76-78), le serveur
-- ne la reconstruit jamais. Toute l'autorité est dans la commande, que le
-- serveur revérifie entièrement (Exchange.checkRadio, équipe, échéances).
--
-- Réponses : le serveur écrit les lignes de la base dans sa langue (getText
-- côté serveur) et les envoie au seul joueur (Exchange.toPlayer, commande
-- Exchange.REPLY) ; le client les affiche par la radio
-- (MilitaryDrop.Client.radioSay). En solo, Exchange.toPlayer appelle
-- directement le gestionnaire client (sendServerCommand n'y fait rien).
-- D'autres modules (poste de liaison) inscrivent leurs gestionnaires dans
-- Exchange.HANDLERS[commande] = function(args) et répondent par
-- Exchange.toPlayer.
--
-- Options des sources de confiance : valeurs par défaut ici (lues des deux
-- côtés : le client grise une source désactivée).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Radio"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Radio = MilitaryDrop.Radio

local Exchange = {}
MilitaryDrop.Exchange = Exchange

Exchange.REPLY = "ExchangeReply"
-- Commandes des sources (MilitaryDrop_Missions.lua).
Exchange.COMMANDS = {
    report = "MissionReport",
    dogtag = "MissionDogTags",
    recon = "MissionRecon",
    control = "MissionControl",
    -- « Faire le point » sur le nettoyage (source « cleanup », sans gain).
    cleanupStatus = "MissionCleanupStatus",
}
-- Plaques traitées par transmission radio (MilitaryDrop_Missions.lua).
Exchange.DOGTAGS_PER_CALL = 10
-- Durée de l'action d'échange (unités de maxTime, ~48 par seconde réelle).
Exchange.ACTION_TIME = 60
-- Délais réels (ms) : première réponse de la base, puis entre deux lignes.
Exchange.REPLY_DELAY_MS = 4000
Exchange.LINE_DELAY_MS = 3500

-- Gain de chaque source (0 = désactivée) : option sandbox.
Exchange.GAIN_OPTIONS = {
    report = "ReportGain",
    dogtag = "DogTagGain",
    recon = "ReconGain",
    cleanup = "CleanupGain",
    control = "ControlGain",
}

Config.addDefaults({
    ReportGain = 1,
    DogTagGain = 2,
    ReconGain = 3,
    ReconHours = 48,
    ReconIntervalHours = 24,
    CleanupGain = 5,
    CleanupHours = 72,
    CleanupQuota = 30,
    CleanupIntervalHours = 48,
    ControlGain = 1,
    ControlHours = 4,
    ControlIntervalHours = 24,
})

--- Gain d'une source (entier ≥ 0).
function Exchange.gain(source)
    local option = Exchange.GAIN_OPTIONS[source]
    if not option then
        return 0
    end
    return math.max(0, math.floor(tonumber(Config.get(option)) or 0))
end

function Exchange.isEnabled(source)
    return Exchange.gain(source) > 0
end

-- ----------------------------------------------------------------------------
-- Serveur : radio et réponses
-- ----------------------------------------------------------------------------

--- Radio désignée par le client, revérifiée : militaire, à portée, allumée,
--- sur la fréquence militaire. Renvoie la radio, ou nil et le motif
--- ("noRadio", "notMilitary", "radioOff", "noAnswer" pour une autre fréquence :
--- personne ne répond, comme pour un appel de largage).
function Exchange.checkRadio(player, ref)
    local radio = Radio.resolve(player, ref)
    if not radio then
        return nil, "noRadio"
    end
    local status = Radio.status(radio, Config.getChannel())
    if status == "wrongFrequency" then
        return nil, "noAnswer"
    end
    if status then
        return nil, status
    end
    return radio
end

--- Serveur → un joueur. En solo, appel direct du gestionnaire client.
function Exchange.toPlayer(player, command, args)
    if isServer() then
        Net.toPlayer(player, command, args or {})
    else
        Exchange.onServerCommand(Net.MODULE, command, args or {})
    end
end

-- ----------------------------------------------------------------------------
-- Plaques d'identité vanilla (SRC-02), client et serveur
--
-- Plaques transmissibles : objets du tag base:dogtag (ItemTag.DOG_TAG ; les
-- plaques d'animaux ne l'ont pas) renommés d'après leur porteur. Le jeu les
-- renomme à la mort d'un zombie (IsoZombie.DoZombieInventory, tag
-- base:applyownername) et sur le personnage qui commence avec une plaque
-- (SpawnItems.lua) par InventoryItem.nameAfterDescriptor :
-- « <nom affiché du script>: <prénom> <nom> ». Une plaque du butin garde le
-- nom du script. Test sans dépendre de la langue : nom brut (getDisplayName,
-- sans les préfixes « Ensanglanté », « Usé » de getName) différent du nom
-- affiché du script dans la langue locale, et texte après le dernier « : ».
-- Le nom n'est sauvegardé et transmis que s'il diffère du nom d'origine
-- (InventoryItem.save) : une plaque vierge reçoit le nom du script de la
-- machine qui la lit. Clé d'unicité : getID(), sauvegardé avec l'objet.
-- ----------------------------------------------------------------------------

--- Nom du soldat inscrit sur une plaque vanilla renommée, ou nil.
function Exchange.dogTagSoldier(item)
    if not item or not ItemTag or not ItemTag.DOG_TAG or not item:hasTag(ItemTag.DOG_TAG) then
        return nil
    end
    local name = item:getDisplayName()
    local script = item:getScriptItem()
    if type(name) ~= "string" or (script and name == script:getDisplayName()) then
        return nil
    end
    local soldier = string.match(name, "^.*: (.+)$")
    soldier = soldier and string.match(soldier, "^%s*(.-)%s*$")
    if not soldier or soldier == "" then
        return nil
    end
    return soldier
end

--- Nom du personnage tel que nameAfterDescriptor l'écrit, ou nil.
function Exchange.ownerName(player)
    local desc = player and player:getDescriptor()
    if not desc then
        return nil
    end
    return tostring(desc:getForename()) .. " " .. tostring(desc:getSurname())
end

--- Vrai pour une plaque transmissible : plaque vanilla renommée, et pas
--- celle du joueur lui-même (player facultatif).
function Exchange.isDogTag(item, player)
    local soldier = Exchange.dogTagSoldier(item)
    if not soldier then
        return false
    end
    return player == nil or soldier ~= Exchange.ownerName(player)
end

--- Texte à afficher pour une plaque : nom du soldat, sinon nom de l'objet.
function Exchange.dogTagLabel(item)
    local soldier = Exchange.dogTagSoldier(item)
    if soldier then
        return soldier
    end
    return item and tostring(item:getDisplayName()) or ""
end

--- Identifiant d'unicité d'une plaque (chaîne), ou nil.
function Exchange.dogTagId(item)
    local id = item and tonumber(item:getID())
    if not id or id ~= math.floor(id) then
        return nil
    end
    return string.format("%d", id)
end

--- Plaques transmissibles de l'inventaire du joueur (sacs portés compris),
--- hors objets portés, en main ou accrochés ; max au plus (facultatif).
function Exchange.findDogTags(player, max)
    local found = {}
    if not ItemTag or not ItemTag.DOG_TAG then
        return found
    end
    local items = player:getInventory():getAllTagRecurse(ItemTag.DOG_TAG, ArrayList.new())
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and not player:isEquipped(item) and not player:isAttachedItem(item)
            and Exchange.isDogTag(item, player) and Exchange.dogTagId(item) then
            found[#found + 1] = item
            if max and #found >= max then
                break
            end
        end
    end
    return found
end

--- Liste de noms lisible : les max premiers (3 par défaut), puis « et N autres ».
function Exchange.namesText(names, max)
    max = max or 3
    local shown = {}
    for i = 1, math.min(#names, max) do
        shown[i] = tostring(names[i])
    end
    local text = table.concat(shown, ", ")
    local more = #names - #shown
    if more == 1 then
        return getText("IGUI_MilitaryDrop_NamesMoreOne", text)
    elseif more > 1 then
        return getText("IGUI_MilitaryDrop_NamesMore", text, tostring(more))
    end
    return text
end

-- ----------------------------------------------------------------------------
-- Client : prise en main et action d'échange
-- ----------------------------------------------------------------------------

--- La radio d'inventaire est dans l'inventaire du personnage (sacs portés compris).
function Exchange.canTake(player, item)
    local container = item and item:getContainer()
    return container ~= nil and container:isInCharacterInventory(player)
end

--- La radio peut émettre telle quelle : en main (ou sur le dos en solo), ou
--- posée assez près.
function Exchange.canEmit(player, device)
    if Radio.isInventoryRadio(device) then
        return Radio.isCarried(player, device)
    end
    return Radio.isWorldRadio(device) and Radio.isNear(player, device)
end

--- Motif d'indisponibilité affichable (clé de traduction), sans révéler la
--- fréquence, ou nil. Une radio d'inventaire hors des mains n'est pas un
--- motif : le personnage la prendra en main.
function Exchange.unavailableReason(player, device)
    if Radio.isInventoryRadio(device) then
        if not Radio.isCarried(player, device) and not Exchange.canTake(player, device) then
            return "IGUI_MilitaryDrop_NotInInventory"
        end
    elseif not Radio.isNear(player, device) then
        return "IGUI_MilitaryDrop_TooFar"
    end
    if not device:getDeviceData():getIsTurnedOn() then
        return "IGUI_MilitaryDrop_TurnOn"
    end
    return nil
end

--- MP : renvoie au serveur l'état d'une radio d'inventaire tenue en main.
function Exchange.resync(device)
    local data = device and device:getDeviceData()
    if data then
        data:setIsTurnedOn(data:getIsTurnedOn())
        data:setChannel(data:getChannel())
    end
end

--- Prise en main par l'action vanilla (ceinture, dos, sac : elle s'en charge).
--- Main secondaire, sauf si seule la main principale est libre.
function Exchange.takeInHand(player, item)
    local primary = player:getSecondaryHandItem() ~= nil and player:getPrimaryHandItem() == nil
    ISInventoryPaneContextMenu.equipWeapon(item, primary, item:isRequiresEquippedBothHands(), player:getPlayerNum())
end

if ISBaseTimedAction then
    --- Action d'échange, côté client seulement (voir l'en-tête). Rangée sous
    --- MilitaryDrop et construite par Action.new(_, …) comme une action
    --- réseau, par cohérence, bien que le serveur ne la reconstruise pas.
    local Action = ISBaseTimedAction:derive("MilitaryDrop.ExchangeAction")
    MilitaryDrop.ExchangeAction = Action

    function Action:isValid()
        return Exchange.canEmit(self.character, self.device)
    end

    function Action:start()
        if self.resync then
            Exchange.resync(self.device)
        end
        if self.speech then
            self.character:Say(self.speech)
        end
    end

    function Action:perform()
        ISBaseTimedAction.perform(self)
        if self.callback then
            self.callback()
        end
    end

    function Action.new(_, character, device, speech, callback, resync)
        local o = ISBaseTimedAction.new(Action, character)
        o.device = device
        o.speech = speech
        o.callback = callback
        o.resync = resync == true
        o.maxTime = Exchange.ACTION_TIME
        o.stopOnWalk = false
        o.stopOnRun = true
        o.stopOnAim = false
        return o
    end
end

--- Prend la radio en main si besoin, puis lance l'action d'échange : speech
--- (facultatif) au début, callback à la fin. Renvoie false si la radio n'est
--- pas utilisable.
function Exchange.run(player, device, speech, callback)
    if Radio.isInventoryRadio(device) and not Radio.isCarried(player, device) then
        if not Exchange.canTake(player, device) then
            return false
        end
        Exchange.takeInHand(player, device)
    elseif not Exchange.canEmit(player, device) then
        return false
    end
    -- MP : état de toute radio d'inventaire renvoyé avant l'échange (AUTH-03).
    local resync = isClient() and Radio.isInventoryRadio(device)
    ISTimedActionQueue.add(MilitaryDrop.ExchangeAction.new(nil, player, device, speech, callback, resync))
    return true
end

local pending = {}
local nextExchangeId = 1

--- Échange complet : prise en main, parole, puis commande au serveur avec la
--- référence de la radio. opts.onReply(args) : appelé à la réponse.
function Exchange.send(player, device, command, args, speech, opts)
    local exchangeId = nextExchangeId
    nextExchangeId = nextExchangeId + 1
    pending[exchangeId] = {
        playerNum = player:getPlayerNum(),
        device = device,
        onReply = type(opts) == "table" and opts.onReply or nil,
    }
    local started = Exchange.run(player, device, speech, function()
        local payload = {}
        for key, value in pairs(args or {}) do
            payload[key] = value
        end
        payload.exchangeId = exchangeId
        payload.radio = Radio.makeRef(device)
        Net.toServer(player, command, payload)
    end)
    if not started then
        pending[exchangeId] = nil
    end
    return started
end

-- ----------------------------------------------------------------------------
-- Client : réponses
-- ----------------------------------------------------------------------------

-- Motifs sans ligne de la base : le personnage le dit, ou la radio grésille.
Exchange.STATUS_TEXTS = {
    noAnswer = "IGUI_MilitaryDrop_NoAnswer",
    busy = "IGUI_MilitaryDrop_Busy",
    radioOff = "IGUI_MilitaryDrop_TurnOn",
    noTags = "IGUI_MilitaryDrop_NoDogTags",
}

local function later(delayMs, fn)
    if MilitaryDrop.Client and MilitaryDrop.Client.later then
        MilitaryDrop.Client.later(delayMs, fn)
    else
        fn()
    end
end

local function radioSay(request, text)
    if MilitaryDrop.Client and MilitaryDrop.Client.radioSay then
        MilitaryDrop.Client.radioSay(request, text)
        return
    end
    local player = getSpecificPlayer(request.playerNum)
    if player then
        player:Say(text)
    end
end

local function playerSay(request, text)
    local player = getSpecificPlayer(request.playerNum)
    if player then
        player:Say(text)
    end
end

--- Réponse du serveur à un échange : lignes de la base par la radio, sinon
--- le motif (grésillement ou parole du personnage).
function Exchange.onReply(args)
    local request = pending[args.exchangeId]
    if not request then
        return
    end
    pending[args.exchangeId] = nil
    local lines = type(args.lines) == "table" and args.lines or {}
    local count = 0
    for _, text in ipairs(lines) do
        if type(text) == "string" then
            local delay = Exchange.REPLY_DELAY_MS + count * Exchange.LINE_DELAY_MS
            count = count + 1
            later(delay, function() radioSay(request, text) end)
        end
    end
    if count == 0 then
        local status = args.status
        local key = Exchange.STATUS_TEXTS[status] or "IGUI_MilitaryDrop_CannotCall"
        if status == "noAnswer" then
            later(Exchange.REPLY_DELAY_MS, function() radioSay(request, getText(key)) end)
        else
            playerSay(request, getText(key))
        end
    end
    if request.onReply then
        request.onReply(args)
    end
end

--- Gestionnaires client des commandes du serveur : nom → function(args).
Exchange.HANDLERS = {
    [Exchange.REPLY] = function(args) Exchange.onReply(args) end,
}

function Exchange.onServerCommand(module, command, args)
    if module ~= Net.MODULE or type(args) ~= "table" then
        return
    end
    local handler = type(command) == "string" and Exchange.HANDLERS[command]
    if handler then
        handler(args)
    end
end

-- MP : réponses reçues du serveur (en solo, Exchange.toPlayer appelle directement).
if isClient() then
    Events.OnServerCommand.Add(Exchange.onServerCommand)
end

return Exchange
