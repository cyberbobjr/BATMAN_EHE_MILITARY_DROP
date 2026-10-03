-- Politique testée sans dépendre de l'installation Workshop de BWT.
local T = {}

local function eq(actual, expected)
    assert(actual == expected, "attendu " .. tostring(expected) .. ", obtenu " .. tostring(actual))
end

function T.setup()
    ACTIVE, CLIENT, SERVER = {}, false, false
    isClient = function() return CLIENT end
    isServer = function() return SERVER end
    getActivatedMods = function()
        return { size = function() return #ACTIVE end, get = function(_, i) return ACTIVE[i + 1] end }
    end
    BetterWalkieTalkies = nil
    COMPAT = loadMod("shared/BatmanRadio/BatmanRadio_Compat.lua")
end

function T.installed_name_workshop_id_and_saved_options_do_not_activate_bwt()
    ACTIVE = { "Better Walkie Talkies", "3779480293", "AnotherBetterWalkieTalkies" }
    SandboxVars = { BetterWalkieTalkies = { BatteryDrain = true } }
    eq(COMPAT.hasBWT(), false)
    eq(COMPAT.features().beltBattery, true)
end

function T.real_ids_and_build42_prefix_activate_both_supported_variants()
    for _, id in ipairs({ "BetterWalkieTalkies", "\\BetterWalkieTalkies",
        "BetterWalkieTalkiesDev", "\\BetterWalkieTalkiesDev" }) do
        ACTIVE = { "OtherMod", id }
        eq(COMPAT.hasBWT(), true)
        eq(COMPAT.features().beltBattery, false)
        eq(COMPAT.features().scenarioReception, true) -- BWT ne fournit pas ce secours solo
    end
end

function T.stale_bridge_from_inactive_mod_is_never_called()
    CLIENT = true
    BetterWalkieTalkies = { RadioTextBridgeHandler = function() error("BWT désactivé") end }
    local player = { Say = function(_, text) return text end }
    local data = { getMicIsMuted = function() return true end }
    eq(COMPAT.say(player, "Appel direct"), "Appel direct")
    eq(COMPAT.microphoneAvailable(data), false)
end

function T.late_bridge_and_activation_changes_are_detected_without_reloading()
    CLIENT, ACTIVE = true, { "BetterWalkieTalkies" }
    local player = { Say = function(_, text) return text end }
    eq(COMPAT.say(player, "Sans bridge"), "Sans bridge")
    local calls = 0
    BetterWalkieTalkies = { RadioTextBridgeHandler = function(callback, text)
        calls = calls + 1
        return callback(text)
    end }
    eq(COMPAT.say(player, "Avec bridge"), "Avec bridge")
    eq(calls, 1)
    ACTIVE = {}
    eq(COMPAT.say(player, "Après désactivation"), "Après désactivation")
    eq(calls, 1)
    eq(COMPAT.features().beltBattery, true)
end

function T.solo_client_and_server_select_only_their_own_features()
    for _, active in ipairs({ false, true }) do
        ACTIVE = active and { "BetterWalkieTalkies" } or {}
        CLIENT, SERVER = false, false
        eq(COMPAT.features().scenarioReception, true)
        eq(COMPAT.features().beltBattery, not active)
        CLIENT = true
        eq(COMPAT.features().scenarioReception, false)
        eq(COMPAT.features().beltBattery, not active)
        SERVER = true
        eq(COMPAT.features().scenarioReception, false)
        eq(COMPAT.features().beltBattery, false)
        eq(COMPAT.features().radioTextBridge, nil)
    end
end

function T.bridge_is_client_only_and_must_be_callable()
    ACTIVE = { "BetterWalkieTalkies" }
    local bridge = function() end
    BetterWalkieTalkies = { RadioTextBridgeHandler = bridge }
    eq(COMPAT.features().radioTextBridge, nil)
    CLIENT = true
    eq(COMPAT.features().radioTextBridge, bridge)
    BetterWalkieTalkies.RadioTextBridgeHandler = true
    eq(COMPAT.features().radioTextBridge, nil)
end

return T
