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

--- Commandes simulées : D1 réquisition, D2 leurre, D3 sans formulaire.
local function withOrders()
    MilitaryDrop.Lots = { ITEM_KEY = "MilitaryDrop_lot" }
    MilitaryDrop.Requisition = {
        orderOf = function(dropId)
            return ({ D1 = { lots = { rations = 2 } }, D2 = { decoy = "N" } })[dropId]
        end,
        casesFor = function()
            return {
                { fullType = "MilitaryDrop.RequisitionCase", lot = "rations", name = "Case: Rations" },
                { fullType = "MilitaryDrop.RequisitionCase", lot = "rations", name = "Case: Rations" },
            }
        end,
    }
    local beacon = { fullType = "MilitaryDrop.DecoyBeacon", name = "DIVERSION" }
    MilitaryDrop.Decoy = { trunkContents = function() return { beacon } end }
end

--- Coffre rempli pendant Crate.spawn pour le largage dropId.
local function fillFor(dropId)
    local container = makeItemContainer()
    container.AddItem = function(self, fullType)
        local item = { fullType = fullType, modData = {} }
        function item.getModData(this) return this.modData end
        function item.setName(this, text) this.name = text end
        function item.setCustomName(this, value) this.custom = value end
        self.items[#self.items + 1] = item
        return item
    end
    addVehicleDebug = function()
        triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", container)
        return VEHICLE
    end
    MilitaryDrop.Crate.spawn({ getVehicleContainer = function() return nil end }, dropId)
    return container.items
end

function T.trunk_follows_the_requisition_order()
    withOrders()
    local items = fillFor("D1")
    assertEq(#items, 2, "une caisse par unité commandée")
    assertEq(items[1].fullType, "MilitaryDrop.RequisitionCase", "caisse de réquisition")
    assertEq(items[1].modData.MilitaryDrop_lot, "rations", "lot en ModData")
    assertEq(items[1].modData.MilitaryDrop_dropId, "D1", "dropId")
    assertEq(items[1].name, "Case: Rations", "nom composé")
    assertEq(items[1].custom, true, "setCustomName")
end

function T.decoy_trunk_holds_only_the_decoy_contents()
    withOrders()
    local items = fillFor("D2")
    assertEq(#items, 1, "une seule balise")
    assertEq(items[1].fullType, "MilitaryDrop.DecoyBeacon", "fournie par le module leurre")
    MilitaryDrop.Decoy = nil
    assertEq(#fillFor("D2"), 0, "module leurre absent : coffre vide, jamais de fournitures")
end

function T.drop_without_order_keeps_random_cases()
    withOrders()
    local items = fillFor("D3")
    assertEq(#items, 4, "CaseRolls caisses")
    assertEq(items[1].name, nil, "pas de nom composé")
end

--- Journal toujours écrit (DebugLog faux) quand une caisse reçoit le contenu
--- aléatoire alors qu'un largage était attendu (retour joueur du 2026-10-06).
function T.random_contents_for_an_expected_drop_are_always_logged()
    local logged = {}
    print = function(text) logged[#logged + 1] = text end
    withOrders()
    RECORDS = { D3 = { forced = true } }
    MilitaryDrop.Trust = { drop = function(dropId) return RECORDS[dropId] end }
    MilitaryDrop.Requisition.formEnabled = function() return true end
    fillFor("D3")
    assertTrue(logged[1] and logged[1]:find("D3: no order in its record (admin drop)", 1, true) ~= nil,
        "dossier sans commande, formulaire actif : " .. tostring(logged[1]))
    logged = {}
    fillFor("D9")
    assertTrue(logged[1] and logged[1]:find("D9: no drop record", 1, true) ~= nil, "dossier introuvable")
    logged = {}
    triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", makeItemContainer())
    assertTrue(logged[1] and logged[1]:find("without a drop id", 1, true) ~= nil, "coffre rempli hors de Crate.spawn")
    logged = {}
    fillFor("D1")
    assertEq(#logged, 0, "commande trouvée : rien")
    MilitaryDrop.Requisition.formEnabled = function() return false end
    fillFor("D3")
    assertEq(#logged, 0, "formulaire désactivé : un largage sans commande est normal")
end

return T
