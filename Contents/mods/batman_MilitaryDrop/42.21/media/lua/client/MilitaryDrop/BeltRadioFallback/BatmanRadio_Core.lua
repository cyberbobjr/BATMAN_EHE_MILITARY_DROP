-- Copie de secours de Belt Walkie-Talkie (batman_BeltRadio 1.0.0), générée par
-- BeltRadio/tools/sync_fallback.py depuis media/lua/client/BatmanRadio/BatmanRadio_Core.lua :
-- ne pas modifier ici. Elle ne fait rien si batman_BeltRadio est activé (le mod
-- commun s'en charge) ; sinon elle garde les globales BatmanRadioSupport et
-- BatmanBeltRadioBattery, si bien que deux copies de secours (deux mods sans
-- batman_BeltRadio) se remplacent au lieu de s'additionner.
local beltRadioActive = false
do
    local mods = getActivatedMods and getActivatedMods()
    for i = 0, (mods and mods:size() or 0) - 1 do
        if string.gsub(mods:get(i), "^\\", "") == "batman_BeltRadio" then beltRadioActive = true end
    end
end
if beltRadioActive then return end

-- Belt Walkie-Talkie (batman_BeltRadio), source unique du récepteur commun BatmanRadio.
-- Un seul menu, wrapper de fenêtre et récepteur solo, quel que soit le nombre de
-- mods qui s'inscrivent (Military Drop, Opération Artemis, Radio Survivor...).
-- Les stations viennent du registre vanilla ; les mods inscrivent leurs chaînes
-- (BatmanRadioSupport.register, docs/API.md).
-- Seule une radio accrochée (ceinture) est servie en solo : une radio rangée
-- (inventaire, sac) n'entend rien, comme en vanilla (décision 3).
-- En MP, réception et VOIP restent gérées par le vanilla / Better Walkie Talkies ;
-- seule la bulle d'une ligne de chaîne reçue par un talkie à la ceinture est ajoutée.
-- Options sandbox (page BeltRadio) relues à chaque usage : BeltListening (écoute
-- solo), MPBubble (bulle MP) ; BeltBattery dans BatmanRadio_BeltBattery.lua.

require "ISUI/ISRadioAndTvMenu"
require "RadioCom/ISRadioWindow"
require "MilitaryDrop/BeltRadioFallback/BatmanRadio_BeltBattery"
-- Partie partagée de l'API (VERSION, options, canTransmitWith) : même table.
require "MilitaryDrop/BeltRadioFallback/BatmanRadio_Support"
local Compat = require "MilitaryDrop/BeltRadioFallback/BatmanRadio_Compat"

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
if BeltRadio.onDeviceTextMP then Events.OnDeviceText.Remove(BeltRadio.onDeviceTextMP) end
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
                -- Surcharge à 7 arguments, texte en premier (Radio.java:77-89) :
                -- SayRadio dessine la bulle « radio » au-dessus du propriétaire
                -- et passe au chat radio (ChatManager), sourd exclu, puis
                -- OnDeviceText (codes non nil). Pas celle à 8 arguments de
                -- DistributeToPlayerInternal (WaveSignalDevice.java:41-62) : sa
                -- bulle exige player:isEquipped(radio), jamais vrai à la ceinture,
                -- et le chat radio n'existe pas en solo (ISChat : MP seulement).
                radio:AddDeviceText(text, r, g, b, nil, codes, -1)
            end
        end
    end
end

-- Par chaîne suivie : diffusion en cours et nombre de ses lignes déjà traitées.
local followed = BeltRadio.followed or {}
BeltRadio.followed = followed
-- Par joueur local : dernière bulle MP ajoutée (texte, horodatage), section 4.
local lastBubble = BeltRadio.lastBubble or {}
BeltRadio.lastBubble = lastBubble
-- Client MP : fréquences reconnues à une ligne reçue (fréquence -> entrée), section 4.
local learned = BeltRadio.learned or {}
BeltRadio.learned = learned
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
--- Option BeltListening fausse : comportement vanilla (aucune écoute déclarée,
--- rien livré), le récepteur reste inscrit pour reprendre si elle est rétablie.
function BeltRadio.onTick()
    if not Compat.features().scenarioReception then
        BeltRadio.reset()
        return
    end
    if not BeltRadio.enabled("BeltListening") then
        for channel in pairs(followed) do followed[channel] = nil end
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
    for playerNum in pairs(lastBubble) do lastBubble[playerNum] = nil end
    for frequency in pairs(learned) do learned[frequency] = nil end
    Events.OnTick.Remove(BeltRadio.onTick)
    BeltRadio.listening = false
end

-- ----------------------------------------------------------------------------
-- 4. Bulle en MP pour un talkie accroché à la ceinture
-- ----------------------------------------------------------------------------

-- Client MP : ZomboidRadio.DistributeToPlayerOnClient sert toutes les radios
-- allumées de l'inventaire principal (VoiceManager), ceinture comprise, par la
-- surcharge à 8 arguments : pour une radio ni en main ni portée, la ligne
-- n'arrive qu'au chat radio, sans bulle, puis OnDeviceText. Les lignes des
-- chaînes scriptées (RadioChannel.java:223-225) ont toujours des codes non nil
-- et une portée -1 (aucune déformation, donc jamais la surcharge à 7
-- arguments) ; les réponses directes de nos mods (7 arguments, codes nil) ne
-- déclenchent pas l'événement et ont déjà leur bulle.
BeltRadio.MP_BUBBLE_DEDUP_MS = 2000

--- Fréquences de nos chaînes connues de ce client, avec leur couleur :
--- fréquence -> { frequency, r, g, b }. Le gestionnaire de chaînes vaut nil
--- sur un client MP : chaque fournisseur déclare ce qu'il sait (frequencies :
--- options publiques), sinon ses chaînes si elles existent (solo, hôte), plus
--- les fréquences reconnues pendant la session (BeltRadio.recognize).
function BeltRadio.scenarioFrequencies()
    local known = {}
    for frequency, entry in pairs(learned) do known[frequency] = entry end
    for _, provider in pairs(providers) do
        for _, entry in ipairs(provider.frequencies and provider.frequencies() or {}) do
            if entry.frequency then known[entry.frequency] = entry end
        end
        for _, channel in ipairs(provider.channels and provider.channels() or {}) do
            local frequency = channel:GetFrequency()
            known[frequency] = known[frequency] or { frequency = frequency }
        end
    end
    return known
end

--- Couleur d'une fréquence secrète (tirée par le serveur, jamais envoyée) : un
--- fournisseur reconnaît ses lignes à leurs codes (recognize(codes) -> couleur ou nil), que
--- le paquet de la ligne transmet au client. La fréquence où la radio vient de
--- recevoir une telle ligne est retenue jusqu'à la déconnexion : les lignes
--- suivantes, y compris brouillées par l'orage (codes vidés), sont reconnues.
--- Le client n'apprend ainsi que la fréquence qu'il écoute déjà.
function BeltRadio.recognize(frequency, codes)
    if type(codes) ~= "string" or codes == "" then
        return nil
    end
    for _, provider in pairs(providers) do
        local color = provider.recognize and provider.recognize(codes)
        if color then
            local entry = { frequency = frequency, r = color.r, g = color.g, b = color.b }
            learned[frequency] = entry
            return entry
        end
    end
    return nil
end

-- Couleur d'une ligne d'une chaîne inconnue de nos fournisseurs (vanilla,
-- autres mods) : l'événement ne transmet pas celle de la ligne.
BeltRadio.DEFAULT_LINE_COLOR = { r = 1, g = 1, b = 1 }

--- OnDeviceText sur un client MP : bulle « radio » au-dessus du joueur, comme
--- pour une radio en main, si la radio qui reçoit une ligne de chaîne (toutes
--- les chaînes : décision de l'utilisateur du 2026-10-10) est accrochée à la
--- ceinture (isAttachedOnly) et que la radio équipée ne reçoit pas déjà la
--- fréquence (le vanilla dessine alors la bulle) ; une seule fois si plusieurs
--- radios reçoivent la même ligne. Une radio rangée (inventaire principal,
--- ni accrochée ni tenue) n'a pas de bulle (décision 3 : elle ne reçoit rien ;
--- en MP le vanilla la fait quand même recevoir au chat radio, sans plus). Phrases radio des autres joueurs exclues
--- (ChatMessage, codes nil : chat radio). Le sourd n'arrive jamais ici
--- (WaveSignalDevice.java:46). La couleur de la ligne n'est pas transmise à
--- l'événement : celle que déclare le fournisseur pour nos chaînes, sinon
--- DEFAULT_LINE_COLOR (brouillage gris perdu).
function BeltRadio.onDeviceTextMP(_guid, codes, _x, _y, _z, line, device)
    if codes == nil or type(line) ~= "string" or line == "" or not Compat.features().mpBubble
        or not BeltRadio.enabled("MPBubble") then
        return
    end
    if not BeltRadio.isPortableRadio(device) then
        return
    end
    local data = device:getDeviceData()
    local frequency = data:getChannel()
    local entry = BeltRadio.scenarioFrequencies()[frequency] or BeltRadio.recognize(frequency, codes)
        or BeltRadio.DEFAULT_LINE_COLOR
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() and device:getContainer() == player:getInventory() then
            if player:isEquipped(device) then return end
            -- Radio rangée : chat radio vanilla seulement (décision 3).
            if not BeltRadio.isAttachedOnly(player, device) then return end
            local equipped = player:getEquipedRadio()
            if equipped and BeltRadio.receives(equipped, frequency) then return end
            local now = getTimestampMs()
            local last = lastBubble[playerNum]
            if last and last.text == line and now - last.ms < BeltRadio.MP_BUBBLE_DEDUP_MS then return end
            lastBubble[playerNum] = { text = line, ms = now }
            player:addLineChatElement(line, entry.r or 1, entry.g or 1, entry.b or 1, UIFont.Medium,
                data:getDeviceVolumeRange(), "radio", true, true, true, false, false, true)
            return
        end
    end
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
Events.OnDeviceText.Add(BeltRadio.onDeviceTextMP)
Events.OnDisconnect.Add(BeltRadio.reset)
Events.OnMainMenuEnter.Add(BeltRadio.reset)

return BeltRadio
