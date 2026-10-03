-- SOURCE COMMUNE : MilitaryDrop/source/radio/lua ; copies générées par sync_radio.py.
-- Un seul menu, wrapper de fenêtre et récepteur solo, même avec Artemis + MilitaryDrop.
-- Les stations viennent du registre vanilla ; les scénarios inscrivent leurs options.
-- En MP, réception et VOIP restent gérées par le vanilla / Better Walkie Talkies.

require "ISUI/ISRadioAndTvMenu"
require "RadioCom/ISRadioWindow"
require "BatmanRadio/BatmanRadio_BeltBattery"
local Compat = require "BatmanRadio/BatmanRadio_Compat"

-- Table conservée si le fichier est rechargé (débogage) : l'enveloppe de la
-- fenêtre n'est jamais posée deux fois (originalWindowUpdate).
BatmanRadioSupport = BatmanRadioSupport or {}
local BeltRadio = BatmanRadioSupport
local providers = BeltRadio.providers or {}
BeltRadio.providers = providers
if BeltRadio.onTick then Events.OnTick.Remove(BeltRadio.onTick) end
if BeltRadio.onGameStart then Events.OnGameStart.Remove(BeltRadio.onGameStart) end
if BeltRadio.onFillInventoryContextMenu then
    Events.OnFillInventoryObjectContextMenu.Remove(BeltRadio.onFillInventoryContextMenu)
end
if BeltRadio.reset then
    Events.OnDisconnect.Remove(BeltRadio.reset)
    Events.OnMainMenuEnter.Remove(BeltRadio.reset)
end

-- Clé vanilla (traductions du jeu), comme le menu d'inventaire vanilla.
BeltRadio.OPTIONS_KEY = "IGUI_DeviceOptions"

-- ----------------------------------------------------------------------------
-- Radio accrochée
-- ----------------------------------------------------------------------------

--- Radio d'inventaire portative (même test que le menu vanilla, sans nom d'objet).
function BeltRadio.isPortableRadio(item)
    if item == nil or not instanceof(item, "Radio") then
        return false
    end
    local data = item:getDeviceData()
    return data ~= nil and data:getIsPortable()
end

--- Radio portative accrochée au joueur, ni en main ni sur le dos (cas où le
--- vanilla n'offre ni réglage ni écoute).
function BeltRadio.isAttachedOnly(player, item)
    return BeltRadio.isPortableRadio(item)
        and player:isAttachedItem(item)
        and player:getPrimaryHandItem() ~= item
        and player:getSecondaryHandItem() ~= item
        and player:getClothingItem_Back() ~= item
end

-- ----------------------------------------------------------------------------
-- 1. Menu « Options de l'appareil »
-- ----------------------------------------------------------------------------

function BeltRadio.onFillInventoryContextMenu(playerNum, context, items)
    -- Avant toute ouverture de la fenêtre : enveloppe reposée si
    -- ISRadioWindow.lua a été rechargé entre-temps (débogage).
    BeltRadio.installWindowWrapper()
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    for _, entry in ipairs(items) do
        local item = entry
        if not instanceof(entry, "InventoryItem") then
            item = entry.items and entry.items[1]
        end
        local onSelect = BeltRadio.isAttachedOnly(player, item) and ISRadioAndTvMenu.openRadioPanel
        if not onSelect then
            for _, provider in pairs(providers) do
                if provider.isStowed and provider.isStowed(player, item) then
                    onSelect = provider.open
                    break
                end
            end
        end
        if onSelect then
            local label = getText(BeltRadio.OPTIONS_KEY)
            if context:getOptionFromName(label) then
                return
            end
            local option = context:addOption(label, player, onSelect, item)
            option.itemForTexture = item
            return
        end
    end
end

-- ----------------------------------------------------------------------------
-- 2. Fenêtre de réglage : pas d'extinction d'une radio accrochée
-- ----------------------------------------------------------------------------

-- Prise en main vanilla ; les scénarios inscrivent leurs autres actions et
-- le champ qui désigne l'appareil dans register().
BeltRadio.TAKING_ACTIONS = BeltRadio.TAKING_ACTIONS or { ISEquipWeaponAction = "item" }

local function sameItem(a, b)
    if a == nil or b == nil then
        return false
    end
    if a == b then
        return true
    end
    return a.getID ~= nil and b.getID ~= nil and a:getID() == b:getID()
end

--- Une prise en main de cette radio par ce joueur est en file ou en cours.
--- ISEquipWeaponAction décroche l'objet de la ceinture à l'événement
--- d'animation detachConnect (ISEquipWeaponAction.lua:48-51) mais ne le met
--- en main qu'à complete() (:182-229) : dans l'intervalle, la radio n'est ni
--- accrochée ni en main, et l'update vanilla de la fenêtre l'éteindrait
--- (ISRadioWindow.lua:152-158). Lu dans la file du joueur
--- (ISTimedActionQueue.queues[joueur].queue) : vidée à l'annulation ou à la
--- fin, sans drapeau à tenir à jour. L'échange qui suit la prise en main
--- garde aussi la fenêtre (en MP, le passage en main peut arriver après la
--- fin de l'action côté client).
function BeltRadio.isBeingTaken(player, item)
    local queues = ISTimedActionQueue and ISTimedActionQueue.queues
    local queue = queues and queues[player]
    if type(queue) ~= "table" or type(queue.queue) ~= "table" then
        return false
    end
    for _, action in ipairs(queue.queue) do
        local field = type(action) == "table" and BeltRadio.TAKING_ACTIONS[action.Type]
        if field and action.character == player and sameItem(action[field], item) then
            return true
        end
    end
    return false
end

--- La fenêtre règle une radio accrochée à son joueur, ou en train d'être
--- prise en main par lui : à garder ouverte, radio allumée.
function BeltRadio.keepsWindow(window)
    if not (window:getIsVisible() and window.deviceType == "InventoryItem"
        and window.device ~= nil and window.player ~= nil and window.deviceData ~= nil) then
        return false
    end
    local player, device = window.player, window.device
    if BeltRadio.isAttachedOnly(player, device) then
        return true
    end
    -- Inventaire principal ou sac porté (BeltRadio.takeAndOpen : transfert
    -- vanilla puis prise en main).
    local container = BeltRadio.isPortableRadio(device) and device:getContainer()
    return container and (container == player:getInventory() or container:isInCharacterInventory(player)) == true
        and BeltRadio.isBeingTaken(player, device)
end

--- Enveloppe ISRadioWindow.update une seule fois. Radio accrochée : le début
--- de l'original (ISCollapsableWindow.update) puis retour, comme le vanilla
--- pour une radio en main ; dans tous les autres cas, l'original. Si
--- ISRadioWindow.lua a été rechargé (débogage), l'enveloppe est reposée sur le
--- nouvel original.
function BeltRadio.installWindowWrapper()
    local RadioWindow = ISRadioWindow
    if not RadioWindow or type(RadioWindow.update) ~= "function"
        or (BeltRadio.windowWrapper and RadioWindow.update == BeltRadio.windowWrapper) then
        return false
    end
    local original = RadioWindow.update
    BeltRadio.originalWindowUpdate = original
    BeltRadio.windowWrapper = function(self, ...)
        if BeltRadio.keepsWindow(self) then
            ISCollapsableWindow.update(self)
            return
        end
        return original(self, ...)
    end
    RadioWindow.update = BeltRadio.windowWrapper
    return true
end

-- ----------------------------------------------------------------------------
-- 3. Écoute des stations radio en solo
-- ----------------------------------------------------------------------------

--- La radio recevrait la chaîne si elle était en main (règles de
--- ZomboidRadio.DistributeToPlayer), pile chargée comprise (DeviceData.update
--- n'éteint pas une radio accrochée vide).
function BeltRadio.receives(radio, frequency)
    local data = radio and radio:getDeviceData()
    if not data or not data:getIsPortable() or not data:getIsTurnedOn() or data:getIsTelevision()
        or data:getChannel() ~= frequency or data:getDeviceVolume() <= 0
        or data:isPlayingMedia() or data:isNoTransmit() then
        return false
    end
    return not data:getIsBatteryPowered() or (data:getHasBattery() and data:getPower() > 0)
end

--- Radio accrochée du joueur qui doit afficher la ligne, ou nil : aucune si sa
--- radio équipée la reçoit déjà, sinon la première qui la reçoit.
function BeltRadio.listeningRadio(player, frequency)
    local equipped = player:getEquipedRadio()
    if equipped and BeltRadio.receives(equipped, frequency) then
        return nil
    end
    local attached = player:getAttachedItems()
    local inventory = player:getInventory()
    for i = 0, attached:size() - 1 do
        local item = attached:getItemByIndex(i)
        if item and item ~= equipped and item:getContainer() == inventory
            and BeltRadio.isAttachedOnly(player, item) and BeltRadio.receives(item, frequency) then
            return item
        end
    end
    return nil
end

--- Texte, couleur et codes d'une ligne après le brouillage de l'orage, comme
--- ZomboidRadio.SendTransmission (ZomboidRadio.java:770-783) le fait pour la
--- radio en main : texte brouillé, gris, codes vidés (pas de repère de carte).
function BeltRadio.weathered(line)
    local text, codes = line:getText(), line:getEffectsString()
    local r, g, b = line:getR(), line:getG(), line:getB()
    local interference = getClimateManager():getWeatherInterference()
    if interference > 0 then
        text = getZomboidRadio():scrambleString(text, math.floor(interference * 100), true, nil)
        r, g, b, codes = 0.5, 0.5, 0.5, ""
    end
    return text, r, g, b, codes
end

--- Fait entendre une ligne de la chaîne aux talkies accrochés des joueurs locaux.
function BeltRadio.deliver(line, frequency)
    if getZomboidRadio():getDisableBroadcasting() then return end
    local text, r, g, b, codes
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            local radio = BeltRadio.listeningRadio(player, frequency)
            if radio then
                -- Sans récepteur à la ceinture, ne pas appeler scrambleString :
                -- il consomme le hasard et modifie l'état interne du moteur radio.
                -- La réception d'une radio en main reste ainsi entièrement native.
                if text == nil then text, r, g, b, codes = BeltRadio.weathered(line) end
                -- Même surcharge que DistributeToPlayerInternal : ChatManager,
                -- trait sourd, parasites et OnDeviceText restent au moteur.
                radio:AddDeviceText(player, text, r, g, b, nil, codes, -1)
            end
        end
    end
end

-- Par chaîne suivie : diffusion en cours et nombre de ses lignes déjà traitées.
local followed = BeltRadio.followed or {}
BeltRadio.followed = followed
-- Les fournisseurs sont remplacés par ID lors d'un rechargement.
function BeltRadio.register(id, provider)
    providers[id] = provider
    for action, field in pairs(provider.takingActions or {}) do
        BeltRadio.TAKING_ACTIONS[action] = field
    end
end

function BeltRadio.channels()
    local list, seen = {}, {}
    local function add(channel)
        if channel and not seen[channel] and not (channel.IsTv and channel:IsTv()) then
            seen[channel] = true
            list[#list + 1] = channel
        end
    end
    local radio = getZomboidRadio()
    local manager = radio and radio:getScriptManager()
    if manager then
        -- Registre réel de la partie : AEBS à fréquence aléatoire, stations
        -- vanilla et stations ajoutées par des mods, sans liste de fréquences figée.
        local channels = manager:getChannelsList()
        for i = 0, channels:size() - 1 do add(channels:get(i)) end
    end
    for _, provider in pairs(providers) do
        for _, channel in ipairs(provider.channels()) do
            add(channel)
        end
    end
    return list
end

--- Les stations scriptées ne démarrent qu'après PlayerListensChannel.
--- Ne jamais envoyer false : une radio posée ou un autre joueur peut écouter.
function BeltRadio.notifyListening()
    local radio, notified = getZomboidRadio(), {}
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            local attached, inventory = player:getAttachedItems(), player:getInventory()
            local equipped = player:getEquipedRadio()
            for i = 0, attached:size() - 1 do
                local item = attached:getItemByIndex(i)
                if item and item:getContainer() == inventory and BeltRadio.isAttachedOnly(player, item) then
                    local data = item:getDeviceData()
                    local frequency = data:getChannel()
                    if data:getIsTurnedOn() and not data:getIsTelevision()
                        and (not data:getIsBatteryPowered() or (data:getHasBattery() and data:getPower() > 0))
                        and not (equipped and BeltRadio.receives(equipped, frequency))
                        and not notified[frequency] then
                        -- Comme TriggerPlayerListening : volume zéro / média
                        -- n'empêchent pas l'écoute déclarée ; receives filtre le texte.
                        notified[frequency] = true
                        radio:PlayerListensChannel(frequency, true, false)
                    end
                end
            end
        end
    end
end

--- Lignes qu'une chaîne vient de diffuser, livrées aux talkies accrochés.
function BeltRadio.follow(channel)
    local bc = channel:getAiringBroadcast()
    local track = followed[channel]
    if not bc then
        followed[channel] = nil
        return
    end
    local lastText = channel.getLastAiredLine and channel:getLastAiredLine()
    local lines = bc:getLines()
    -- Après la dernière ligne, le compteur dépasse d'une unité (getNextLine).
    local aired = math.min(bc:getCurrentLineNumber(), lines:size())
    if not track or track.bc ~= bc then
        local handled = 0
        if channel.getLastAiredLine then
            -- Une sauvegarde peut reprendre au milieu d'une émission : ne
            -- rejouer aucun historique. Seule la dernière ligne réellement
            -- émise depuis le chargement peut être livrée immédiatement.
            handled = aired
            local latest = aired > 0 and lines:get(aired - 1)
            if latest and lastText == latest:getText() then handled = aired - 1 end
        end
        -- À count=0, lastAiredLine peut encore contenir l'émission précédente.
        track = { bc = bc, handled = handled, lastText = bc:getCurrentLineNumber() == 0 and lastText or nil }
        followed[channel] = track
    end
    local mainLine = track.handled < aired
    while track.handled < aired do
        local line = lines:get(track.handled)
        track.handled = track.handled + 1
        if line then
            BeltRadio.deliver(line, channel:GetFrequency())
        end
    end
    -- Les publicités et pauses pré/post n'avancent pas le compteur principal.
    -- Le moteur expose leur texte, mais pas leur RadioLine ni leurs segments :
    -- le texte est reçu en gris, sans codes. Deux publicités identiques
    -- consécutives sont indiscernables avec cette API publique.
    if not mainLine and lastText and lastText ~= "" and lastText ~= track.lastText then
        BeltRadio.deliver(RadioLine.new(lastText, 0.5, 0.5, 0.5), channel:GetFrequency())
    end
    track.lastText = lastText
end

--- Chaque tick (solo) : écoute déclarée, puis lignes réellement diffusées.
function BeltRadio.onTick()
    if not Compat.features().scenarioReception then
        BeltRadio.reset()
        return
    end
    BeltRadio.notifyListening()
    local active = {}
    for _, channel in ipairs(BeltRadio.channels()) do
        active[channel] = true
        BeltRadio.follow(channel)
    end
    for channel in pairs(followed) do
        if not active[channel] then followed[channel] = nil end
    end
end

function BeltRadio.reset()
    for channel in pairs(followed) do followed[channel] = nil end
    Events.OnTick.Remove(BeltRadio.onTick)
    BeltRadio.listening = false
end

--- Solo seulement : sur un client MP, le vanilla sert déjà les radios de
--- l'inventaire principal, et un serveur n'affiche rien.
function BeltRadio.onGameStart()
    if BeltRadio.listening or not Compat.features().scenarioReception then
        return
    end
    BeltRadio.listening = true
    Events.OnTick.Add(BeltRadio.onTick)
end

BeltRadio.installWindowWrapper()
if BeltRadio.listening and Compat.features().scenarioReception then Events.OnTick.Add(BeltRadio.onTick) end
Events.OnGameStart.Add(BeltRadio.onGameStart)
Events.OnFillInventoryObjectContextMenu.Add(BeltRadio.onFillInventoryContextMenu)
Events.OnDisconnect.Add(BeltRadio.reset)
Events.OnMainMenuEnter.Add(BeltRadio.reset)

return BeltRadio
