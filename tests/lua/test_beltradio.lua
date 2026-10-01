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
        getDeviceVolume = 0.5, isPlayingMedia = false, isNoTransmit = false,
        getIsBatteryPowered = true, getHasBattery = true, getPower = 0.8,
    }
    for name, value in pairs(values) do
        local v = value
        if opts[name] ~= nil then
            v = opts[name]
        end
        data[name] = function() return v end
    end
    local radio = { kind = "Radio", said = {} }
    radio.getDeviceData = function() return data end
    radio.getContainer = function() return opts.container or INVENTORY end
    radio.AddDeviceText = function(self, text, r, g, b, guid, codes, distance)
        self.said[#self.said + 1] = { text = text, r = r, codes = codes, distance = distance }
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
        return { scrambleString = function(_, text, intensity) return "bzzt" .. intensity .. ":" .. text end }
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
    assertEq(listenerCount("OnTick"), 0, "client MP : pas d'écoute ajoutée")
    SOLO = true
    startListening()
    startListening()
    assertEq(listenerCount("OnTick"), 1, "solo : un seul abonnement")
end

function T.no_channel_no_delivery()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    startListening()
    MilitaryDrop.Broadcast = nil
    triggerEvent("OnTick")
    assertEq(#radio.said, 0, "pas de chaîne")
end

return T
