-- ============================================================================
-- Military Drop — talkie accroché à la ceinture (ou à un emplacement)
--
-- Vanilla 42.21, une radio portative accrochée (player:isAttachedItem) :
--   * n'a pas d'option « Options de l'appareil » : le menu d'inventaire ne la
--     propose qu'en main ou sur le dos (ISInventoryPaneContextMenu.lua:896) ;
--   * est éteinte par sa fenêtre de réglage dès qu'elle quitte la main ou le
--     dos (ISRadioWindow:update, ISRadioWindow.lua:137-158) ;
--   * en solo, n'entend rien : ZomboidRadio.DistributeToPlayer ne sert que
--     player:getEquipedRadio() (main ou dos). Sur un client MP, les radios
--     allumées de l'inventaire principal reçoivent déjà
--     (DistributeToPlayerOnClient, VoiceManager.UpdateChannelsRoaming).
--
-- Ce module, pour toute radio portative accrochée :
--   1. ajoute « Options de l'appareil » (même action que le vanilla), sauf si
--      l'option existe déjà ; aussi pour une radio militaire rangée dans
--      l'inventaire ou un sac porté (BeltRadio.isStowedMilitary) : prise en
--      main puis fenêtre, car sa section « Logistique »
--      (MilitaryDrop_RadioModule.lua) remplace le menu contextuel du mod ;
--   2. enveloppe ISRadioWindow.update (une seule fois) : la fenêtre d'une radio
--      accrochée reste ouverte et la radio allumée, y compris pendant sa
--      prise en main (demande du module « Logistique » ou du menu : la radio
--      quitte la ceinture avant d'arriver en main, BeltRadio.isBeingTaken) ;
--      sinon, l'original ;
--   3. en solo seulement, fait entendre à un talkie accroché les lignes des
--      chaînes du mod (chaîne militaire MilitaryDrop.Broadcast.channel et
--      station de chiffres MilitaryDrop.NumbersStation.channel), au moment où
--      chaque chaîne les diffuse : le compteur de lignes de la diffusion en cours
--      (RadioBroadCast:getCurrentLineNumber) est suivi à chaque tick, donc même
--      cadence que la chaîne. Mêmes règles que DistributeToPlayer : portative,
--      allumée, bon canal, volume > 0, sans média ni « noTransmit », pile
--      chargée. Jamais si la radio équipée du joueur reçoit déjà la ligne, et
--      une seule radio accrochée par joueur : aucune ligne en double.
--      Radio:AddDeviceText (Radio.java:78-91) affiche la ligne au-dessus du
--      joueur (SayRadio, comme une radio en main) et déclenche OnDeviceText
--      (x = -1) : le repère de carte (MilitaryDrop_Announce.lua) marche aussi.
--      Les autres chaînes du jeu restent vanilla.
--
-- Pile : en solo, DeviceData.update ne tourne que pour la radio équipée
-- (Radio.update) ; à la ceinture la charge reste figée, puis la consommation
-- du temps passé allumée est rattrapée à la reprise en main
-- (DeviceData.update, écart de getMinutesStamp).
-- ============================================================================

require "ISUI/ISRadioAndTvMenu"
require "RadioCom/ISRadioWindow"
require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Exchange"

-- Table conservée si le fichier est rechargé (débogage) : l'enveloppe de la
-- fenêtre n'est jamais posée deux fois (originalWindowUpdate).
local BeltRadio = MilitaryDrop.BeltRadio or {}
MilitaryDrop.BeltRadio = BeltRadio

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

--- Radio militaire portative rangée dans l'inventaire du joueur (sacs portés
--- compris), ni en main, ni sur le dos, ni accrochée : le vanilla n'offre pas
--- « Options de l'appareil » (ISInventoryPaneContextMenu.lua:896), or la
--- section « Logistique » de cette fenêtre est le seul accès joueur aux
--- échanges du mod (le menu contextuel ne les propose plus).
function BeltRadio.isStowedMilitary(player, item)
    local Radio = MilitaryDrop.Radio
    if not (Radio and Radio.isMilitary) or not BeltRadio.isPortableRadio(item) or not Radio.isMilitary(item) then
        return false
    end
    if player:isAttachedItem(item) or player:getPrimaryHandItem() == item or player:getSecondaryHandItem() == item
        or player:getClothingItem_Back() == item then
        return false
    end
    local container = item:getContainer()
    return container ~= nil and (container == player:getInventory() or container:isInCharacterInventory(player))
end

--- Radio rangée : le personnage la prend en main (action vanilla,
--- Exchange.takeInHand) et la fenêtre s'ouvre aussitôt ; elle reste ouverte
--- pendant la prise en main (BeltRadio.keepsWindow).
function BeltRadio.takeAndOpen(player, item)
    MilitaryDrop.Exchange.takeInHand(player, item)
    ISRadioAndTvMenu.openRadioPanel(player, item)
end

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
        local attached = BeltRadio.isAttachedOnly(player, item)
        if attached or BeltRadio.isStowedMilitary(player, item) then
            local label = getText(BeltRadio.OPTIONS_KEY)
            if context:getOptionFromName(label) then
                return
            end
            local onSelect = attached and ISRadioAndTvMenu.openRadioPanel or BeltRadio.takeAndOpen
            local option = context:addOption(label, player, onSelect, item)
            option.itemForTexture = item
            return
        end
    end
end

-- ----------------------------------------------------------------------------
-- 2. Fenêtre de réglage : pas d'extinction d'une radio accrochée
-- ----------------------------------------------------------------------------

-- Actions qui mènent la radio dans la main : prise en main vanilla
-- (Exchange.takeInHand → ISInventoryPaneContextMenu.equipWeapon), puis
-- l'échange du mod qui suit dans la file. Champ de l'action qui désigne la radio.
BeltRadio.TAKING_ACTIONS = { ISEquipWeaponAction = "item", ["MilitaryDrop.ExchangeAction"] = "device" }

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
-- 3. Écoute de la chaîne militaire en solo
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
    local text, r, g, b, codes = BeltRadio.weathered(line)
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            local radio = BeltRadio.listeningRadio(player, frequency)
            if radio then
                -- Surcharge (String, r, g, b, guid, codes, distance) de Radio :
                -- couleurs 0-1 ; codes = ceux de la ligne (OnDeviceText).
                radio:AddDeviceText(text, r, g, b, nil, codes, -1)
            end
        end
    end
end

-- Par chaîne suivie : diffusion en cours et nombre de ses lignes déjà traitées.
local followed = {}
-- Abonnement à OnTick posé (une seule fois).
local listening = false

--- Chaînes du mod qu'un talkie accroché peut entendre (celles qui existent).
function BeltRadio.channels()
    local list = {}
    local Broadcast = MilitaryDrop.Broadcast
    if Broadcast and Broadcast.channel then
        list[#list + 1] = Broadcast.channel
    end
    local Station = MilitaryDrop.NumbersStation
    if Station and Station.channel then
        list[#list + 1] = Station.channel
    end
    return list
end

--- Lignes qu'une chaîne vient de diffuser, livrées aux talkies accrochés.
function BeltRadio.follow(channel)
    local bc = channel:getAiringBroadcast()
    local track = followed[channel]
    if not bc then
        followed[channel] = nil
        return
    end
    if not track or track.bc ~= bc then
        track = { bc = bc, handled = 0 }
        followed[channel] = track
    end
    local lines = bc:getLines()
    -- Après la dernière ligne, le compteur dépasse d'une unité (getNextLine).
    local aired = math.min(bc:getCurrentLineNumber(), lines:size())
    while track.handled < aired do
        local line = lines:get(track.handled)
        track.handled = track.handled + 1
        if line then
            BeltRadio.deliver(line, channel:GetFrequency())
        end
    end
end

--- Chaque tick (solo) : chaque chaîne du mod.
function BeltRadio.onTick()
    for _, channel in ipairs(BeltRadio.channels()) do
        BeltRadio.follow(channel)
    end
end

--- Solo seulement : sur un client MP, le vanilla sert déjà les radios de
--- l'inventaire principal, et un serveur n'affiche rien.
function BeltRadio.onGameStart()
    if listening or isClient() or isServer() then
        return
    end
    listening = true
    Events.OnTick.Add(BeltRadio.onTick)
end

BeltRadio.installWindowWrapper()
Events.OnGameStart.Add(BeltRadio.onGameStart)
Events.OnFillInventoryObjectContextMenu.Add(BeltRadio.onFillInventoryContextMenu)

return BeltRadio
