-- MilitaryDrop_BeltRadio : talkie accroché à la ceinture (menu de réglage,
-- fenêtre qui ne l'éteint plus, écoute de la chaîne militaire en solo).

local T = {}

local FREQ = 151400

--- Radio d'inventaire simulée ; opts remplace les valeurs de DeviceData.
local function makeRadio(opts)
    opts = opts or {}
    local data = {}
    local values = {
        getIsPortable = true, getIsTurnedOn = true, getIsTelevision = false, getChannel = FREQ,
        getDeviceVolume = 0.5, getDeviceVolumeRange = 12, isPlayingMedia = false, isNoTransmit = false,
        getIsBatteryPowered = true, getHasBattery = true, getPower = 0.8,
    }
    for name, value in pairs(values) do
        local v = value
        if opts[name] ~= nil then
            v = opts[name]
        end
        data[name] = function() return v end
    end
    local radio = { kind = "Radio", said = {}, shown = {} }
    data.update = function() end -- batterie native couverte par test_beltbattery
    radio.getDeviceData = function() return data end
    radio.getContainer = function() return opts.container or INVENTORY end
    -- Doublure fidèle des deux surcharges Java (volume > 0 et sourd exclus dans les deux).
    -- 8 arguments, joueur en premier (WaveSignalDevice.java:41-62) : bulle seulement si
    -- player:isEquipped(radio) (mains ou vêtement porté, jamais la ceinture), le reste au chat
    -- radio, absent en solo. 7 arguments, texte en premier (Radio.java:77-89) : SayRadio, bulle
    -- « radio » au-dessus du propriétaire (getPlayer : conteneur parent). Puis OnDeviceText
    -- si codes ~= nil. said : lignes reçues (OnDeviceText) ; shown : bulles à l'écran.
    radio.AddDeviceText = function(self, first, ...)
        local player, text, r, guid, codes, distance, shown, _
        if type(first) == "string" then
            text, r, _, _, guid, codes, distance = first, ...
            player = self:getContainer() == INVENTORY and PLAYER or nil
            shown = player ~= nil
        else
            player = first
            text, r, _, _, guid, codes, distance = ...
            shown = player:isEquipped(self)
        end
        if not player or self:getDeviceData():getDeviceVolume() <= 0 or player.deaf then return end
        if shown then self.shown[#self.shown + 1] = text end
        if codes ~= nil then
            self.said[#self.said + 1] = { text = text, r = r, codes = codes, distance = distance, guid = guid }
        end
    end
    return radio
end

local function makePlayer()
    local player = { attached = {}, hands = {} }
    player.isAttachedItem = function(self, item)
        for _, v in ipairs(self.attached) do
            if v == item then
                return true
            end
        end
        return false
    end
    player.getPrimaryHandItem = function(self) return self.hands[1] end
    player.getSecondaryHandItem = function(self) return self.hands[2] end
    player.getClothingItem_Back = function(self) return self.back end
    player.getEquipedRadio = function(self) return self.equipped end
    player.isEquipped = function(self, item) return item == self.hands[1] or item == self.hands[2] end
    player.bubbles = {}
    -- IsoGameCharacter.addLineChatElement (12 arguments) : bulle ajoutée directement.
    player.addLineChatElement = function(self, text, r, g, b, font, range, tag)
        self.bubbles[#self.bubbles + 1] = { text = text, r = r, g = g, b = b, font = font, range = range, tag = tag }
    end
    player.getInventory = function() return INVENTORY end
    player.isDead = function() return false end
    player.getAttachedItems = function(self)
        local list = self.attached
        return {
            size = function() return #list end,
            getItemByIndex = function(_, i) return list[i + 1] end,
        }
    end
    return player
end

--- Diffusion simulée (RadioBroadCast) : lignes et compteur de lignes diffusées.
local function makeBroadcast(texts)
    local bc = { lines = {}, count = 0 }
    for i, entry in ipairs(texts) do
        bc.lines[i] = {
            getText = function() return entry[1] end,
            getR = function() return 0.45 end, getG = function() return 0.85 end, getB = function() return 0.45 end,
            getEffectsString = function() return entry[2] or "" end,
        }
    end
    bc.getLines = function()
        return { size = function() return #bc.lines end, get = function(_, i) return bc.lines[i + 1] end }
    end
    bc.getCurrentLineNumber = function() return bc.count end
    return bc
end

function T.setup()
    getGameTime = function() return { getMinutesStamp = function() return 100 end } end
    SandboxVars = {}
    SOLO = true
    isClient = function() return not SOLO end
    isServer = function() return false end
    instanceof = function(object, class)
        if type(object) ~= "table" then
            return false
        end
        return object.kind == class or (class == "InventoryItem" and object.kind == "Radio")
    end
    getText = function(key) return key end
    INVENTORY = { name = "main" }
    PLAYER = makePlayer()
    getSpecificPlayer = function() return PLAYER end
    getNumActivePlayers = function() return 1 end
    COLLAPSABLE_UPDATES = 0
    ISCollapsableWindow = { update = function() COLLAPSABLE_UPDATES = COLLAPSABLE_UPDATES + 1 end }
    ORIGINAL_CALLS = 0
    ISRadioWindow = { update = function(self)
        ORIGINAL_CALLS = ORIGINAL_CALLS + 1
        -- Comportement vanilla hors main : extinction et fermeture.
        if self.deviceData then
            self.deviceData.turnedOff = true
        end
        return "original"
    end }
    ISRadioAndTvMenu = { openRadioPanel = function() end }
    INTERFERENCE = 0
    getClimateManager = function()
        return { getWeatherInterference = function() return INTERFERENCE end }
    end
    getZomboidRadio = function()
        return { scrambleString = function(_, text, intensity) return "bzzt" .. intensity .. ":" .. text end,
            getScriptManager = function() end, getDisableBroadcasting = function() return false end,
            PlayerListensChannel = function() end }
    end
    AIRING = nil
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_BeltRadio.lua")
    MilitaryDrop.Broadcast = { channel = {
        getAiringBroadcast = function() return AIRING end,
        GetFrequency = function() return FREQ end,
    } }
end

--- Menu contextuel simulé.
local function makeContext(existing)
    local context = { options = {} }
    if existing then
        context.options[1] = { name = existing }
    end
    context.getOptionFromName = function(self, name)
        for _, option in ipairs(self.options) do
            if option.name == name then
                return option
            end
        end
        return nil
    end
    context.addOption = function(self, name, target, fn, param)
        local option = { name = name, target = target, fn = fn, param = param }
        self.options[#self.options + 1] = option
        return option
    end
    return context
end

-- 1. Menu ----------------------------------------------------------------------

function T.attached_radio_gets_device_options()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    local context = makeContext()
    triggerEvent("OnFillInventoryObjectContextMenu", 0, context, { radio })
    assertEq(#context.options, 1, "une option")
    assertEq(context.options[1].name, "IGUI_DeviceOptions", "clé vanilla")
    assertEq(context.options[1].fn, ISRadioAndTvMenu.openRadioPanel, "même action que le vanilla")
    assertEq(context.options[1].param, radio, "radio réglée")
end

function T.vanilla_option_is_not_doubled()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    local context = makeContext("IGUI_DeviceOptions")
    triggerEvent("OnFillInventoryObjectContextMenu", 0, context, { { items = { radio } } })
    assertEq(#context.options, 1, "option déjà là : rien ajouté")
end

function T.radio_in_hand_or_unattached_gets_nothing()
    local radio = makeRadio()
    local context = makeContext()
    triggerEvent("OnFillInventoryObjectContextMenu", 0, context, { radio })
    assertEq(#context.options, 0, "non accrochée : menu vanilla seul")
    PLAYER.attached = { radio }
    PLAYER.hands = { radio }
    triggerEvent("OnFillInventoryObjectContextMenu", 0, context, { radio })
    assertEq(#context.options, 0, "en main : option vanilla")
end

function T.fixed_radio_is_not_portable()
    local radio = makeRadio({ getIsPortable = false })
    PLAYER.attached = { radio }
    local context = makeContext()
    triggerEvent("OnFillInventoryObjectContextMenu", 0, context, { radio })
    assertEq(#context.options, 0, "radio non portative")
end

-- 2. Fenêtre ---------------------------------------------------------------------

local function makeWindow(radio, visible)
    return {
        deviceType = "InventoryItem", device = radio, player = PLAYER, deviceData = radio:getDeviceData(),
        getIsVisible = function() return visible ~= false end,
    }
end

function T.window_keeps_an_attached_radio_on()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    local window = makeWindow(radio)
    local result = ISRadioWindow.update(window)
    assertEq(result, nil, "retour vanilla d'une radio gardée")
    assertEq(ORIGINAL_CALLS, 0, "original non appelé")
    assertEq(COLLAPSABLE_UPDATES, 1, "mise à jour de la fenêtre conservée")
    assertEq(window.deviceData.turnedOff, nil, "pas d'extinction")
end

function T.window_calls_the_original_otherwise()
    local radio = makeRadio()
    local window = makeWindow(radio)
    assertEq(ISRadioWindow.update(window), "original", "radio rangée : original et son retour")
    assertEq(window.deviceData.turnedOff, true, "extinction vanilla conservée")
    PLAYER.attached = { radio }
    ISRadioWindow.update(makeWindow(radio, false))
    assertEq(ORIGINAL_CALLS, 2, "fenêtre masquée : original")
end

function T.window_stays_open_while_the_radio_is_taken_in_hand()
    -- Exchange.takeInHand : ISEquipWeaponAction décroche la radio
    -- (detachConnect) avant de la mettre en main (complete).
    local radio = makeRadio()
    local equip = { Type = "ISEquipWeaponAction", character = PLAYER, item = radio }
    local exchange = { Type = "MilitaryDrop.ExchangeAction", character = PLAYER, device = radio }
    ISTimedActionQueue = { queues = { [PLAYER] = { queue = { equip, exchange } } } }
    local window = makeWindow(radio)
    assertEq(ISRadioWindow.update(window), nil, "décrochée, pas encore en main : fenêtre gardée")
    assertEq(window.deviceData.turnedOff, nil, "radio toujours allumée (pas de radioOff)")
    ISTimedActionQueue.queues[PLAYER].queue = { exchange }
    ISRadioWindow.update(window)
    assertEq(window.deviceData.turnedOff, nil, "échange en file (MP : main pas encore synchronisée)")
    assertEq(ORIGINAL_CALLS, 0, "original jamais appelé")
    -- Annulation : la file est vidée, comportement vanilla.
    ISTimedActionQueue.queues[PLAYER].queue = {}
    assertEq(ISRadioWindow.update(window), "original", "file vide : original")
    assertEq(window.deviceData.turnedOff, true, "extinction vanilla")
    -- Prise en main d'un autre objet, ou par un autre joueur : rien de gardé.
    local other = makeRadio()
    ISTimedActionQueue.queues[PLAYER].queue = { { Type = "ISEquipWeaponAction", character = PLAYER, item = other },
        { Type = "ISEquipWeaponAction", character = {}, item = radio } }
    ISRadioWindow.update(makeWindow(radio))
    assertEq(ORIGINAL_CALLS, 2, "autre objet ou autre joueur : original")
    -- Radio hors de l'inventaire du personnage (au sol, meuble) : pas concernée.
    local away = makeRadio({ container = { name = "floor", isInCharacterInventory = function() return false end } })
    ISTimedActionQueue.queues[PLAYER].queue = { { Type = "ISEquipWeaponAction", character = PLAYER, item = away } }
    ISRadioWindow.update(makeWindow(away))
    assertEq(ORIGINAL_CALLS, 3, "radio hors de l'inventaire : original")
    -- Sac porté (transfert vanilla puis prise en main) : gardée.
    local bagged = makeRadio({ container = { name = "bag", isInCharacterInventory = function() return true end } })
    ISTimedActionQueue.queues[PLAYER].queue = { { Type = "ISInventoryTransferAction", character = PLAYER, item = bagged },
        { Type = "ISEquipWeaponAction", character = PLAYER, item = bagged } }
    ISRadioWindow.update(makeWindow(bagged))
    assertEq(ORIGINAL_CALLS, 3, "radio dans un sac porté, en cours de prise : fenêtre gardée")
end

function T.stowed_military_radio_gets_device_options_that_take_it_in_hand()
    -- Le menu contextuel du mod n'existe plus : « Options de l'appareil » est
    -- le seul accès à la section « Logistique » d'un talkie rangé.
    local military = true
    MilitaryDrop.Radio = { isMilitary = function() return military end }
    local taken = {}
    MilitaryDrop.Exchange = { takeInHand = function(player, item) taken[#taken + 1] = { player, item } end }
    local opened = {}
    ISRadioAndTvMenu.openRadioPanel = function(player, item) opened[#opened + 1] = item end
    local bag = { name = "bag", isInCharacterInventory = function() return true end }
    local radio = makeRadio({ container = bag })
    local context = makeContext()
    MilitaryDrop.BeltRadio.onFillInventoryContextMenu(0, context, { radio })
    assertEq(#context.options, 1, "option ajoutée")
    local option = context.options[1]
    assertEq(option.name, "IGUI_DeviceOptions", "même libellé que le vanilla")
    option.fn(option.target, option.param)
    assertTrue(taken[1] and taken[1][2] == radio, "prise en main (action vanilla)")
    assertTrue(opened[1] == radio, "fenêtre ouverte aussitôt")
    -- Radio non militaire, ou déjà en main : rien (vanilla).
    military = false
    local other = makeContext()
    MilitaryDrop.BeltRadio.onFillInventoryContextMenu(0, other, { radio })
    assertEq(#other.options, 0, "radio ordinaire rangée : vanilla")
    military = true
    PLAYER.hands = { radio }
    MilitaryDrop.BeltRadio.onFillInventoryContextMenu(0, other, { radio })
    assertEq(#other.options, 0, "en main : option vanilla")
end

function T.window_wrapper_is_installed_once()
    local wrapped = ISRadioWindow.update
    assertEq(MilitaryDrop.BeltRadio.installWindowWrapper(), false, "deuxième installation refusée")
    assertEq(ISRadioWindow.update, wrapped, "pas d'enveloppe empilée")
end

function T.window_wrapper_is_put_back_after_a_reload()
    local reloaded = function() return "reloaded" end
    ISRadioWindow.update = reloaded
    MilitaryDrop.BeltRadio.onFillInventoryContextMenu(0, makeContext(), {})
    assertTrue(ISRadioWindow.update ~= reloaded, "enveloppe reposée sur le fichier rechargé")
    assertEq(ISRadioWindow.update(makeWindow(makeRadio())), "reloaded", "nouvel original appelé hors ceinture")
end

-- 3. Écoute en solo ----------------------------------------------------------------

local function startListening()
    triggerEvent("OnGameStart")
end

function T.belt_radio_hears_each_line_when_it_airs()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    startListening()
    AIRING = makeBroadcast({ { "grille 1", "MDRP" }, { "grille 1", "MDRP" }, { "terminé" } })
    triggerEvent("OnTick")
    assertEq(#radio.said, 0, "rien avant la diffusion de la première ligne")
    AIRING.count = 1
    triggerEvent("OnTick")
    triggerEvent("OnTick")
    assertEq(#radio.said, 1, "une ligne, une seule fois")
    assertEq(radio.said[1].codes, "MDRP", "codes de la ligne (OnDeviceText, repère)")
    assertEq(radio.said[1].r, 0.45, "couleur 0-1")
    assertEq(radio.said[1].distance, -1, "sans distorsion")
    assertEq(#radio.shown, 1, "ligne affichée au-dessus du joueur (surcharge à 7 arguments)")
    assertEq(radio.shown[1], "grille 1", "texte de la bulle")
    AIRING.count = 4
    triggerEvent("OnTick")
    assertEq(#radio.said, 3, "répétition identique comptée, compteur borné")
    assertEq(radio.said[3].codes, "", "fin sans code")
    AIRING = nil
    triggerEvent("OnTick")
    AIRING = makeBroadcast({ { "suite" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(#radio.said, 4, "nouvelle diffusion suivie depuis le début")
end

function T.storm_scrambles_the_line_like_a_radio_in_hand()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    startListening()
    INTERFERENCE = 0.35
    AIRING = makeBroadcast({ { "grille 1", "MDRP" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(radio.said[1].text, "bzzt35:grille 1", "texte brouillé selon l'intensité")
    assertEq(radio.said[1].codes, "", "codes vidés : pas de repère de carte")
    assertEq(radio.said[1].r, 0.5, "gris")
end

function T.belt_radio_hears_the_numbers_station_on_its_own_frequency()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    startListening()
    local stationAiring = makeBroadcast({ { "Attention" }, { "Groupe 17-04-58" } })
    MilitaryDrop.NumbersStation = { channel = {
        getAiringBroadcast = function() return stationAiring end,
        GetFrequency = function() return 14600 end,
    } }
    stationAiring.count = 2
    triggerEvent("OnTick")
    assertEq(#radio.said, 0, "radio sur la fréquence militaire : rien de la station")
    local tuned = makeRadio({ getChannel = 14600 })
    PLAYER.attached = { tuned }
    stationAiring = makeBroadcast({ { "Attention" }, { "Groupe 17-04-58" } })
    stationAiring.count = 2
    triggerEvent("OnTick")
    assertEq(#tuned.said, 2, "réglée sur la station : les deux lignes")
    assertEq(tuned.said[2].text, "Groupe 17-04-58", "code chiffré entendu à la ceinture")
    MilitaryDrop.NumbersStation = nil
end

function T.lines_aired_before_switching_on_are_not_replayed()
    local radio = makeRadio({ getIsTurnedOn = false })
    PLAYER.attached = { radio }
    startListening()
    AIRING = makeBroadcast({ { "a" }, { "b" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(#radio.said, 0, "éteinte")
    radio.getDeviceData().getIsTurnedOn = function() return true end
    AIRING.count = 2
    triggerEvent("OnTick")
    assertEq(#radio.said, 1, "seule la ligne diffusée radio allumée")
    assertEq(radio.said[1].text, "b", "ligne b")
end

function T.equipped_radio_on_the_channel_prevents_doubles()
    local belt = makeRadio()
    local hand = makeRadio()
    PLAYER.attached = { belt }
    PLAYER.hands = { hand }
    PLAYER.equipped = hand
    startListening()
    AIRING = makeBroadcast({ { "a" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(#belt.said, 0, "la radio en main reçoit déjà (vanilla)")
end

function T.equipped_radio_elsewhere_leaves_the_belt_radio_listening()
    local belt = makeRadio()
    local hand = makeRadio({ getChannel = 100000 })
    PLAYER.attached = { belt }
    PLAYER.hands = { hand }
    PLAYER.equipped = hand
    startListening()
    AIRING = makeBroadcast({ { "a" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(#belt.said, 1, "radio en main sur un autre canal")
    assertEq(#hand.said, 0, "rien ajouté à la radio en main")
end

function T.only_one_attached_radio_per_player()
    local first = makeRadio()
    local second = makeRadio()
    PLAYER.attached = { first, second }
    startListening()
    AIRING = makeBroadcast({ { "a" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(#first.said + #second.said, 1, "une seule ligne")
end

function T.vanilla_reception_rules_apply()
    local cases = {
        { getIsTurnedOn = false }, { getChannel = 100000 }, { getDeviceVolume = 0 },
        { isPlayingMedia = true }, { isNoTransmit = true }, { getPower = 0 }, { getHasBattery = false },
        { getIsPortable = false }, { container = { name = "bag" } },
    }
    startListening()
    for i, opts in ipairs(cases) do
        local radio = makeRadio(opts)
        PLAYER.attached = { radio }
        AIRING = makeBroadcast({ { "a" } })
        AIRING.count = 1
        triggerEvent("OnTick")
        assertEq(#radio.said, 0, "cas " .. i .. " : pas de réception")
        AIRING = nil
        triggerEvent("OnTick")
    end
end

function T.mains_powered_radio_needs_no_battery()
    local radio = makeRadio({ getIsBatteryPowered = false, getHasBattery = false, getPower = 0 })
    PLAYER.attached = { radio }
    startListening()
    AIRING = makeBroadcast({ { "a" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(#radio.said, 1, "pas de pile exigée")
end

function T.multiplayer_client_is_left_to_vanilla()
    SOLO = false
    startListening()
    assertEq(listenerCount("OnTick"), 1, "client MP : batterie seulement, pas d'écoute ajoutée")
    SOLO = true
    startListening()
    startListening()
    assertEq(listenerCount("OnTick"), 2, "solo : batterie et un seul récepteur")
end

function T.no_channel_no_delivery()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    startListening()
    MilitaryDrop.Broadcast = nil
    triggerEvent("OnTick")
    assertEq(#radio.said, 0, "pas de chaîne")
end

function T.world_restart_releases_broadcasts_and_keeps_one_receiver()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    startListening()
    AIRING = makeBroadcast({ { "premier monde" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(#radio.said, 1, "premier monde")
    triggerEvent("OnMainMenuEnter")
    assertEq(listenerCount("OnTick"), 1, "retour au menu : plus de récepteur, batterie seule")
    AIRING = makeBroadcast({ { "second monde" } })
    AIRING.count = 1
    startListening()
    startListening()
    triggerEvent("OnTick")
    assertEq(#radio.said, 2, "nouvelle diffusion reçue une seule fois")
    assertEq(listenerCount("OnTick"), 2, "un récepteur et une batterie")
end

function T.belt_line_is_shown_once_and_never_doubled_after_taking_the_radio_in_hand()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    startListening()
    AIRING = makeBroadcast({ { "a" }, { "b" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(#radio.shown, 1, "ceinture, mains vides : une bulle")
    -- Reprise en main : le vanilla (radio équipée) reçoit seul la ligne suivante.
    PLAYER.attached, PLAYER.hands[1], PLAYER.equipped = {}, radio, radio
    AIRING.count = 2
    triggerEvent("OnTick")
    assertEq(#radio.shown, 1, "radio en main : rien ajouté par le récepteur")
end

function T.deaf_player_sees_and_hears_nothing_at_the_belt()
    local radio = makeRadio()
    PLAYER.attached, PLAYER.deaf = { radio }, true
    startListening()
    AIRING = makeBroadcast({ { "a", "MDRP" } })
    AIRING.count = 1
    triggerEvent("OnTick")
    assertEq(#radio.shown + #radio.said, 0, "sourd : ni bulle ni OnDeviceText (Radio.java:83)")
end

-- MP : bulle d'une radio non tenue (BatmanRadio_Core.onDeviceTextMP).
local function mpSetup(frequencyOption)
    SOLO = false
    SandboxVars = { MilitaryDrop = { Frequency = frequencyOption } }
    MilitaryDrop.Broadcast = { COLOR = { r = 0.45, g = 0.85, b = 0.45 } } -- client MP : pas de chaîne
    UIFont = { Medium = "Medium" }
    NOW = 1000
    getTimestampMs = function() return NOW end
    getActivatedMods = function() return { size = function() return 0 end } end
end

--- Ligne d'une chaîne scriptée servie par ZomboidRadio.DistributeToPlayerOnClient :
--- surcharge à 8 arguments pour chaque radio de l'inventaire principal sur la fréquence.
local function vanillaMpLine(radios, text, codes)
    codes = codes or ""
    for _, radio in ipairs(radios) do
        radio:AddDeviceText(PLAYER, text, 0.45, 0.85, 0.45, nil, codes, -1)
        triggerEvent("OnDeviceText", nil, codes, -1, -1, -1, text, radio)
    end
end

function T.mp_belt_radio_on_a_public_channel_gets_one_bubble()
    mpSetup(151.4)
    local a, b = makeRadio(), makeRadio()
    PLAYER.attached = { a }
    vanillaMpLine({ a, b }, "grille 1")
    assertEq(#a.shown + #b.shown, 0, "vanilla : chat radio seulement")
    assertEq(#PLAYER.bubbles, 1, "une seule bulle pour deux radios non tenues")
    assertEq(PLAYER.bubbles[1].tag, "radio", "bulle radio")
    assertEq(PLAYER.bubbles[1].r, 0.45, "couleur de la chaîne")
    assertEq(PLAYER.bubbles[1].range, 12, "portée du volume")
    NOW = NOW + 5000
    vanillaMpLine({ a }, "grille 1")
    assertEq(#PLAYER.bubbles, 2, "même texte plus tard : nouvelle transmission")
end

function T.mp_bubble_skipped_for_held_radio_other_channel_secret_frequency_bwt_and_solo()
    mpSetup(151.4)
    local hand, belt = makeRadio(), makeRadio()
    PLAYER.hands[1], PLAYER.equipped, PLAYER.attached = hand, hand, { belt }
    vanillaMpLine({ hand, belt }, "en main")
    assertEq(#hand.shown, 1, "radio en main : bulle vanilla")
    assertEq(#PLAYER.bubbles, 0, "rien ajouté si la radio équipée reçoit")
    PLAYER.hands[1], PLAYER.equipped = nil, nil
    local other = makeRadio({ getChannel = 98000 })
    vanillaMpLine({ other }, "météo")
    assertEq(#PLAYER.bubbles, 0, "chaîne vanilla : laissée au vanilla")
    mpSetup(0)
    vanillaMpLine({ belt }, "secrète, brouillée")
    assertEq(#PLAYER.bubbles, 0, "fréquence libre jamais reconnue, ligne sans code : rien")
    mpSetup(151.4)
    getActivatedMods = function()
        return { size = function() return 1 end, get = function() return "BetterWalkieTalkies" end }
    end
    vanillaMpLine({ belt }, "bwt")
    assertEq(#PLAYER.bubbles, 0, "Better Walkie Talkies actif : rien ajouté")
    mpSetup(151.4)
    SOLO = true
    triggerEvent("OnDeviceText", nil, "", -1, -1, -1, "solo", belt)
    assertEq(#PLAYER.bubbles, 0, "solo : la livraison du récepteur affiche déjà")
end

function T.mp_secret_frequency_is_learned_from_the_first_marked_line()
    mpSetup(0) -- fréquence libre tirée par le serveur : aucune fréquence connue du client
    MilitaryDrop.NumbersStation = { COLOR = { r = 0.85, g = 0.75, b = 0.45 } }
    local belt = makeRadio({ getChannel = 133400 })
    PLAYER.attached = { belt }
    vanillaMpLine({ belt }, "Base à toutes les stations", "MDTX")
    assertEq(#PLAYER.bubbles, 1, "ligne marquée du mod : bulle")
    assertEq(PLAYER.bubbles[1].g, 0.85, "couleur de la chaîne militaire")
    NOW = NOW + 5000
    vanillaMpLine({ belt }, "bzzt brouillée", "")
    assertEq(#PLAYER.bubbles, 2, "orage (codes vidés) : fréquence déjà reconnue")
    local station = makeRadio({ getChannel = 14200 })
    PLAYER.attached = { station }
    vanillaMpLine({ station }, "Groupe 17-04-58", "MDNS")
    assertEq(PLAYER.bubbles[3].r, 0.85, "station de chiffres : sa couleur")
    local vanillaRadio = makeRadio({ getChannel = 98000 })
    vanillaMpLine({ vanillaRadio }, "Météo", "")
    vanillaMpLine({ vanillaRadio }, "Musique", "MOR+5")
    assertEq(#PLAYER.bubbles, 3, "autres chaînes et codes vanilla : rien")
    triggerEvent("OnDisconnect")
    NOW = NOW + 5000
    PLAYER.attached = { belt }
    vanillaMpLine({ belt }, "bzzt après reconnexion", "")
    assertEq(#PLAYER.bubbles, 3, "déconnexion : fréquences reconnues oubliées")
end

function T.mp_direct_reply_without_codes_adds_no_bubble()
    mpSetup(151.4)
    local belt = makeRadio()
    PLAYER.attached = { belt }
    -- Réponse directe (MilitaryDrop_Client.radioSay) : 7 arguments, codes nil, pas d'OnDeviceText.
    belt:AddDeviceText("Reçu.", 0.45, 0.85, 0.45, nil, nil, -1)
    triggerEvent("OnDeviceText", nil, nil, -1, -1, -1, "Reçu.", belt) -- appel sans codes ignoré
    assertEq(#belt.shown, 1, "bulle de la surcharge à 7 arguments")
    assertEq(#PLAYER.bubbles, 0, "aucune seconde bulle")
end

return T
