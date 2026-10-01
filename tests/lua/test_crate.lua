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
    SQL_ID = 12
    VEHICLE = { kind = "BaseVehicle", getSqlId = function() return SQL_ID end }
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

function T.refused_position_is_not_a_crate()
    SQL_ID = -1
    local square = { getVehicleContainer = function() return nil end }
    assertEq(MilitaryDrop.Crate.spawn(square), nil, "véhicule non ajouté au monde")
end

function T.occupied_square_does_not_spawn()
    local square = { getVehicleContainer = function() return {} end }
    assertEq(MilitaryDrop.Crate.spawn(square), nil, "case occupée par un véhicule")
    assertEq(#SPAWNED, 0, "rien créé")
end

--- Conteneur dont AddItem renvoie l'objet créé (ItemContainer.AddItem(String)).
local function makeItemContainer()
    local container = makeContainer()
    container.AddItem = function(self, fullType)
        local item = { fullType = fullType, modData = {} }
        function item.getModData(this) return this.modData end
        self.items[#self.items + 1] = item
        return item
    end
    return container
end

function T.spawned_crate_cases_carry_the_drop_id()
    local container = makeItemContainer()
    -- addVehicleDebug remplit le coffre pendant l'appel (randomizeContainers).
    addVehicleDebug = function()
        triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", container)
        return VEHICLE
    end
    local square = { getVehicleContainer = function() return nil end }
    assertEq(MilitaryDrop.Crate.spawn(square, "D3"), VEHICLE, "caisse posée")
    assertEq(#container.items, 4, "coffre rempli")
    for _, item in ipairs(container.items) do
        assertEq(item.modData.MilitaryDrop_dropId, "D3", "dropId sur chaque caisse de ravitaillement")
    end
    local later = makeItemContainer()
    triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", later)
    assertEq(later.items[1].modData.MilitaryDrop_dropId, nil, "hors de Crate.spawn : aucun dropId")
end

return T
