local T = {}
function T.setup()
    MilitaryDrop = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Recorders.lua")
    PROVIDERS = {}
    TooltipLib = {
        hasProvider = function(id) return PROVIDERS[id] ~= nil end,
        registerProvider = function(p) PROVIDERS[p.id] = p end,
        replaceProvider = function(id, p) PROVIDERS[id] = p end,
    }
    getText = function(key) return key end
    PROVIDER = loadMod("client/MilitaryDrop/MilitaryDrop_RecorderTooltip.lua")
end
function T.tooltip_tracks_the_live_persisted_marker_and_reload_keeps_one_provider()
    local data = {}
    local item = { getFullType = function() return "MilitaryDrop.FlightRecorder" end,
        getModData = function() return data end }
    assertEq(PROVIDER.enabled(item), false)
    data.MilitaryDrop_recorderTransmitted = true
    assertEq(PROVIDER.enabled(item), true)
    assertEq(PROVIDER.cacheable, false)
    local labels = {}
    PROVIDER.callback({ item = item, addLabel = function(_, value) labels[#labels + 1] = value end })
    assertEq(labels[1], "IGUI_MilitaryDrop_RecorderTransmitted")
    assertEq(labels[2], "IGUI_MilitaryDrop_RecorderDismantleHint")
    loadMod("client/MilitaryDrop/MilitaryDrop_RecorderTooltip.lua")
    local count = 0; for _ in pairs(PROVIDERS) do count = count + 1 end
    assertEq(count, 1)
    assertEq(PROVIDER.enabled({ getFullType = function() return "Base.Battery" end }), false)
end
function T.legacy_or_unexpected_optional_data_is_safe_and_never_overwrites_existing_fields()
    local item = { getFullType = function() return "MilitaryDrop.FlightRecorder" end,
        getModData = function() return nil end }
    assertEq(PROVIDER.enabled(item), false)
    assertEq(MilitaryDrop.Recorders.site(item), nil)
    item.getModData = function() return false end
    assertEq(PROVIDER.enabled(item), false)
    assertEq(MilitaryDrop.Recorders.site(item), nil)
    local data = { MilitaryDrop_crashSite = "W1", otherMod = { retained = true } }
    item.getModData = function() return data end
    assertEq(PROVIDER.enabled(item), false, "old save without new property")
    for _, value in ipairs({ false, 1, "true" }) do
        data.MilitaryDrop_recorderTransmitted = value
        assertEq(PROVIDER.enabled(item), false, "only a boolean marker is accepted")
    end
    assertEq(data.MilitaryDrop_crashSite, "W1")
    assertEq(data.otherMod.retained, true)
end
return T
