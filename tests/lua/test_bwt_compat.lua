-- Exécute le vrai RadioPTT de la copie Workshop, sans écrire dans celle-ci.
-- Simulation de l'API Java : routage/micros testés, aucun son VOIP réel.
if not hasBWT then return { skip = "Better Walkie Talkies non installé" } end

local T = {}

local function eq(a, b)
    assert(a == b, "attendu " .. tostring(b) .. ", obtenu " .. tostring(a))
end

local function list(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end

local function loadBWT(rel)
    return assert(loadstring(readBWTFile(rel), "@BWT/" .. rel))()
end

function T.setup()
    Events = setmetatable({}, { __index = function(events, name)
        local event = { handlers = {} }
        event.Add = function(fn) event.handlers[#event.handlers + 1] = fn end
        event.Remove = function(fn)
            for i = #event.handlers, 1, -1 do
                if event.handlers[i] == fn then table.remove(event.handlers, i) end
            end
        end
        rawset(events, name, event)
        return event
    end })
    CLIENT, ENABLED, KEY_DOWN, NOW = true, true, false, 0
    isClient = function() return CLIENT end
    isServer = function() return false end
    Keyboard = { KEY_NONE = 0 }
    getTimeInMillis = function() return NOW end
    isKeyDown = function() return KEY_DOWN end
    isDebugEnabled = function() return false end
    getText = function(key) return key end
    instanceof = function(item, class) return item.kind == class end
    SandboxVars = { BetterWalkieTalkies = { BatteryDrain = true } }
    getActivatedMods = function() return list({ "\\BetterWalkieTalkies" }) end
    local data = { mic = false, on = true }
    data.getIsPortable = function() return true end
    data.getIsTwoWay = function() return true end
    data.getIsHighTier = function() return true end
    data.getIsTurnedOn = function() return data.on end
    data.getMicIsMuted = function() return data.mic end
    data.setMicIsMuted = function(_, value) data.mic = value end
    data.getChannel = function() return 108000 end
    data.getDeviceVolume = function() return 0 end -- clics sans besoin d'un moteur audio
    data.setIsTurnedOn = function(_, value) data.on = value end
    DEVICE = data
    ITEM = { kind = "Radio", getDeviceData = function() return data end, getID = function() return 7 end }
    PLAYER = { speech = {}, getInventory = function() return { getItems = function() return list({ ITEM }) end } end,
        getX = function() return 0 end, getY = function() return 0 end, getZ = function() return 0 end,
        getPrimaryHandItem = function() return ITEM end, getSecondaryHandItem = function() end,
        getClothingItem_Back = function() end }
    PLAYER.Say = function(_, text)
        PLAYER.speech[#PLAYER.speech + 1] = { text = text, muted = data.mic, mode = CORE.mode }
        return "said"
    end
    getPlayer = function() return PLAYER end
    CORE = { mode = 2, getOptionVoiceMode = function() return CORE.mode end,
        setOptionVoiceMode = function(_, mode) CORE.mode = mode end,
        getKey = function() return 9 end, getAltKey = function() return 0 end,
        addKeyBinding = function() end }
    getCore = function() return CORE end
    getZomboidRadio = function() return { getBroadcastDevices = function() return list({}) end } end
    sendClientCommand = function() end
    processSayMessage = function(text) return PLAYER:Say(text) end
    processShoutMessage = processSayMessage
    loadBWT("shared/BetterWalkieTalkies/Constants.lua")
    local options = { EnableRadioPTT = { getValue = function() return ENABLED end },
        RadioPTTKey = { getValue = function() return 42 end },
        HearRadioPTTClicks = { getValue = function() return false end } }
    local cache = {}
    require = function(name)
        if name == "BetterWalkieTalkies/ClientOptions" then return options end
        if name == "BetterWalkieTalkies/ReceivingTransmissions" then
            return { update = function() end, onSignal = function() end }
        end
        if name == "BatmanRadio/BatmanRadio_Compat" then
            cache[name] = cache[name] or loadMod("shared/" .. name .. ".lua")
            return cache[name]
        end
    end
    COMPAT = require "BatmanRadio/BatmanRadio_Compat"
    PTT = loadBWT("client/BetterWalkieTalkies/RadioPTT.lua")
end

local function idle()
    PTT.onTick()
    NOW = 200
    PTT.onTick()
    eq(DEVICE.mic, true)
    eq(CORE.mode, 2)
end

function T.real_ptt_idle_mute_is_not_a_user_muted_microphone()
    idle()
    eq(COMPAT.microphoneAvailable(DEVICE), true)
    eq(DEVICE.mic, true)
    eq(CORE.mode, 2)
    local source = readArtemisFile("shared/Artemis/Artemis_MilRadio.lua")
    if source then
        local milRadio = assert(loadstring(source, "@Artemis_MilRadio.lua"))()
        eq(milRadio.status(PLAYER, ITEM, 108000), nil)
    end
end

function T.deliberately_muted_microphone_stays_unavailable()
    DEVICE.mic = true -- BWT mémorise ce choix avant son activation
    idle()
    eq(COMPAT.microphoneAvailable(DEVICE), false)
    eq(DEVICE.mic, true)
end

function T.scripted_speech_uses_bridge_without_opening_voice_transmission()
    idle()
    eq(COMPAT.say(PLAYER, "Appel Artemis"), "said")
    eq(PLAYER.speech[1].muted, false)
    eq(PLAYER.speech[1].mode, 3) -- capture VOIP coupée pendant la phrase scriptée
    eq(DEVICE.mic, true)
    eq(CORE.mode, 2)
end

function T.bwt_ptt_key_still_transmits_and_restores_idle_mode()
    idle()
    KEY_DOWN, NOW = true, 201
    PTT.onTick()
    NOW = 400
    PTT.onTick()
    eq(DEVICE.mic, false)
    eq(CORE.mode, 1)
    COMPAT.say(PLAYER, "Logistique")
    eq(DEVICE.mic, false)
    eq(CORE.mode, 1) -- nos phrases ne changent pas une VOIP déjà en cours
    KEY_DOWN, NOW = false, 401
    PTT.onTick()
    NOW = 600
    PTT.onTick()
    eq(DEVICE.mic, true)
    eq(CORE.mode, 2)
end

function T.solo_and_disabled_ptt_keep_normal_speech_and_mute_checks()
    CLIENT = false
    PTT.onTick()
    eq(COMPAT.say(PLAYER, "Solo"), "said")
    eq(DEVICE.mic, false)
    DEVICE.mic = true
    eq(COMPAT.microphoneAvailable(DEVICE), false)
    CLIENT, ENABLED, DEVICE.mic = true, false, false
    PTT.onTick()
    eq(COMPAT.microphoneAvailable(DEVICE), true)
end

function T.callback_error_restores_bwt_microphones_and_voice_mode()
    idle()
    PLAYER.Say = function() error("speech failure") end
    local ok = pcall(COMPAT.say, PLAYER, "Erreur")
    eq(ok, false)
    eq(DEVICE.mic, true)
    eq(CORE.mode, 2)
end

function T.real_bwt_battery_remains_the_only_consumer_and_keeps_its_option()
    DEVICE.power = 1
    DEVICE.getPower = function() return DEVICE.power end
    DEVICE.setPower = function(_, value) DEVICE.power = value end
    DEVICE.getUseDelta = function() return 0.01 end
    DEVICE.getIsBatteryPowered = function() return true end
    DEVICE.getHasBattery = function() return true end
    DEVICE.transmitBatteryChange = function() end
    DEVICE.update = function() error("gestionnaire batterie concurrent") end
    PLAYER.getEquipedRadio = function() end
    local bwtBattery = loadBWT("client/BetterWalkieTalkies/PortableRadioBattery.lua")
    local ourBattery = loadMod("client/BatmanRadio/BatmanRadio_BeltBattery.lua")
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function() return PLAYER end
    ourBattery.onTick()
    bwtBattery.onEveryOneMinute()
    ourBattery.onTick()
    eq(DEVICE.power, 0.99)
    SandboxVars.BetterWalkieTalkies.BatteryDrain = false
    bwtBattery.onEveryOneMinute()
    ourBattery.onTick()
    eq(DEVICE.power, 0.99)
end

return T
