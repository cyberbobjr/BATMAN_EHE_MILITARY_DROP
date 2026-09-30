-- MilitaryDrop_Crate : distribution du véhicule, remplissage du coffre, apparition.

local T = {}

local function makeContainer()
    local items = {}
    return { kind = "ItemContainer", items = items, AddItem = function(_, t) items[#items + 1] = t end }
end

function T.setup()
    SandboxVars = { MilitaryDrop = { CaseRolls = 4 } }
    isClient = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    ZombRandFloat = function(low) return low end
    VehicleDistributions = { {} }
    SPAWNED = {}
    VEHICLE = { kind = "BaseVehicle" }
    addVehicleDebug = function(script, dir, skin, square)
        SPAWNED[#SPAWNED + 1] = { script = script, skin = skin, square = square }
        return VEHICLE
    end
    IsoDirections = { getRandom = function() return "N" end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Crate.lua")
end

function T.distribution_declared_for_the_trunk()
    triggerEvent("OnPostDistributionMerge")
    local entry = VehicleDistributions[1].MilitaryDrop_SupplyCrate
    assertTrue(entry ~= nil, "distribution déclarée")
    assertEq(entry.Normal.TrailerTrunk.rolls, 0, "vide : rempli par OnFillContainer")
end

function T.trunk_filled_with_case_rolls_cases()
    local container = makeContainer()
    triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", container)
    assertEq(#container.items, 4, "option CaseRolls")
    assertEq(container.items[1], "MilitaryDrop.AmmoSupplyCase", "caisses de ravitaillement")
end

function T.other_containers_untouched()
    local container = makeContainer()
    triggerEvent("OnFillContainer", "Trailer", "TrailerTrunk", container)
    triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", { kind = "ItemPickerContainer" })
    assertEq(#container.items, 0, "autre véhicule ignoré")
end

function T.spawn_uses_vehicle_script()
    local square = { getVehicleContainer = function() return nil end }
    assertEq(MilitaryDrop.Crate.spawn(square), VEHICLE, "véhicule renvoyé")
    assertEq(SPAWNED[1].script, "Base.MilitaryDrop_SupplyCrate", "script complet")
end

function T.occupied_square_does_not_spawn()
    local square = { getVehicleContainer = function() return {} end }
    assertEq(MilitaryDrop.Crate.spawn(square), nil, "case occupée par un véhicule")
    assertEq(#SPAWNED, 0, "rien créé")
end

return T
