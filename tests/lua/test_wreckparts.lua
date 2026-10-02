local T = {}
function T.setup()
    isClient = function() return false end
    SandboxVars = {}
    ItemTag = { get = function(x) return x end, WELDING_MASK = "mask" }
    ResourceLocation = { of = function(x) return x end }
    Perks = { FromString = function(x) return x end }
    GIVEN, XP, ORIGINAL = {}, 0, 0
    Actions = { addOrDropItem = function(_, item) GIVEN[#GIVEN+1] = item end }
    addXp = function(_, _, value) XP = XP + value end
    ISUninstallVehiclePart = { complete = function(_, arg) ORIGINAL = ORIGINAL + 1 return arg, "return" end }
    ISInstallVehiclePart = { complete = function() return "installed" end }
    ISRemoveBurntVehicle = { isValid = function() return true end, complete = function() return "cut" end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Crash.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Salvage.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_WreckParts.lua")
    TOOL, LEVEL, FAR, DEAD, REMOVED = true, 3, false, false, false
    PLAYER = { getInventory = function() return { getFirstTagRecurse = function() return TOOL and {} end } end,
        getX = function() return FAR and 100 or 0 end, getY = function() return 0 end, getZ = function() return 0 end,
        isDead = function() return DEAD end, getPerkLevel = function() return LEVEL end }
    PARTS = {}
    VEHICLE = { getScriptName = function() return "Base.MilitaryDrop_HeliWreckBurnt" end,
        isRemovedFromWorld = function() return REMOVED end, getX = function() return 0 end,
        getY = function() return 0 end, getPartById = function(_, id) return PARTS[id] end,
        transmitPartItem = function() end }
    for id in pairs(MilitaryDrop.Salvage.PARTS) do
        local p = { id = id, item = { id = id } }
        p.getVehicle = function() return VEHICLE end
        p.getId = function(self) return self.id end
        p.getInventoryItem = function(self) return self.item end
        p.setInventoryItem = function(self, item) self.item = item end
        PARTS[id] = p
    end
    ACTION = { vehicle = VEHICLE, part = PARTS.Avionics, character = PLAYER }
end
function T.server_rechecks_tools_at_completion()
    assertTrue(MilitaryDrop.WreckParts.test(VEHICLE, PARTS.Avionics, PLAYER))
    TOOL = false
    assertEq(ISUninstallVehiclePart.complete(ACTION), false)
    assertTrue(PARTS.Avionics.item)
    assertEq(#GIVEN, 0)
end
function T.requirements_include_skill_distance_life_and_part_order()
    assertEq(MilitaryDrop.WreckParts.test(VEHICLE, PARTS.RadioRack, PLAYER), false)
    PARTS.Avionics.item = nil
    assertTrue(MilitaryDrop.WreckParts.test(VEHICLE, PARTS.RadioRack, PLAYER))
    LEVEL = 0
    assertEq(MilitaryDrop.WreckParts.test(VEHICLE, PARTS.RadioRack, PLAYER), false)
    LEVEL, FAR = 3, true
    assertEq(ISUninstallVehiclePart.complete(ACTION), false)
    FAR, DEAD = false, true
    assertEq(ISUninstallVehiclePart.complete(ACTION), false)
end
function T.two_players_cannot_receive_the_same_part()
    assertTrue(ISUninstallVehiclePart.complete(ACTION))
    assertEq(ISUninstallVehiclePart.complete(ACTION), false)
    assertEq(#GIVEN, 1)
    assertEq(XP, 5)
end
function T.unrelated_vehicle_preserves_arguments_and_multiple_returns()
    ACTION.vehicle = { getScriptName = function() return "Base.CarNormal" end }
    local a, b = ISUninstallVehiclePart.complete(ACTION, "argument")
    assertEq(a, "argument")
    assertEq(b, "return")
    assertEq(ORIGINAL, 1)
end
function T.installation_is_refused_even_for_a_forged_action()
    assertEq(ISInstallVehiclePart.complete(ACTION), false)
end
function T.final_cut_waits_for_every_part_and_checks_the_mask()
    assertEq(ISRemoveBurntVehicle.isValid(ACTION), false)
    for _, p in pairs(PARTS) do p.item = nil end
    TOOL = false
    assertEq(ISRemoveBurntVehicle.complete(ACTION), false)
    TOOL = true
    assertEq(ISRemoveBurntVehicle.complete(ACTION), "cut")
end
function T.reload_does_not_chain_another_vanilla_wrapper()
    loadMod("shared/MilitaryDrop/MilitaryDrop_WreckParts.lua")
    ACTION.vehicle = { getScriptName = function() return "Base.CarNormal" end }
    assertEq(ISUninstallVehiclePart.complete(ACTION, "ok"), "ok")
    assertEq(ORIGINAL, 1)
end
return T
