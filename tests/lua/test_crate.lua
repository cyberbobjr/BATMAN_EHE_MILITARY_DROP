-- MilitaryDrop_Crate : distribution du véhicule, remplissage du coffre, apparition,
-- diagnostics « crate contents » et parade aux mods qui re-remplissent les coffres.

local T = {}

local function makeContainer()
    local items = {}
    return { kind = "ItemContainer", items = items, AddItem = function(_, t) items[#items + 1] = t end }
end

--- Liste Java simulée (size, get à partir de 0).
local function javaList(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end

--- InventoryItem simulé.
local function makeItem(fullType)
    local item = { fullType = fullType, modData = {} }
    function item.getFullType(this) return this.fullType end
    function item.getModData(this) return this.modData end
    function item.setName(this, text) this.name = text end
    function item.setCustomName(this, value) this.custom = value end
    return item
end

--- Conteneur dont AddItem renvoie l'objet créé (ItemContainer.AddItem(String)).
local function makeItemContainer()
    local container = { kind = "ItemContainer", items = {}, explored = false }
    function container.AddItem(self, fullType)
        local item = makeItem(fullType)
        self.items[#self.items + 1] = item
        return item
    end
    function container.getItems(self) return javaList(self.items) end
    function container.clear(self) self.items = {} end
    return container
end

--- Véhicule simulé avec un coffre TrailerTrunk (ItemContainer.getVehiclePart,
--- VehiclePart.getVehicle) et sa ModData.
local function makeVehicle(script)
    local vehicle = { modData = {}, script = script or "Base.MilitaryDrop_SupplyCrate" }
    local trunk = makeItemContainer()
    local part = { getItemContainer = function() return trunk end, getVehicle = function() return vehicle end }
    function trunk.getVehiclePart() return part end
    vehicle.trunk = trunk
    function vehicle.getModData(this) return this.modData end
    function vehicle.getSqlId() return SQL_ID end
    function vehicle.getScriptName(this) return this.script end
    function vehicle.getPartById(_, id) return id == "TrailerTrunk" and part or nil end
    function vehicle.getX() return 10.5 end
    function vehicle.getY() return 20.5 end
    return vehicle
end

--- Remplissage du moteur (BaseVehicle.randomizeContainers / forceVehicleDistribution) :
--- coffre déjà exploré ignoré, sinon vidé, distribution (DISTRIBUTION), puis
--- OnFillContainer avec le type du véhicule, puis exploré.
local function engineFill(vehicle)
    local trunk = vehicle.trunk
    if trunk.explored then
        return
    end
    trunk:clear()
    for _, fullType in ipairs(DISTRIBUTION) do
        trunk:AddItem(fullType)
    end
    triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", trunk)
    trunk.explored = true
end

local function captureLog()
    local logged = {}
    print = function(text) logged[#logged + 1] = text end
    return logged
end

local function find(logged, text)
    for _, line in ipairs(logged) do
        if line:find(text, 1, true) then
            return line
        end
    end
    return nil
end

local function countTypes(items)
    local counts = {}
    for _, item in ipairs(items) do
        counts[item.fullType] = (counts[item.fullType] or 0) + 1
    end
    return counts
end

function T.setup()
    SandboxVars = { MilitaryDrop = { CaseRolls = 4 } }
    isClient = function() return false end
    isMultiplayer = function() return MULTIPLAYER end
    MULTIPLAYER = false
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    ZombRandFloat = function(low) return low end
    VehicleDistributions = { {} }
    DISTRIBUTION = {}
    SPAWNED = {}
    SQL_ID = 12
    -- addVehicleDebug : createPhysics → randomizeContainers (OnFillContainer)
    -- puis OnSpawnVehicleEnd (BaseVehicle.java:888, 897), si la position est acceptée.
    addVehicleDebug = function(script, _, skin, square)
        local vehicle = makeVehicle(script)
        SPAWNED[#SPAWNED + 1] = { script = script, skin = skin, square = square, vehicle = vehicle }
        if SQL_ID ~= -1 then
            engineFill(vehicle)
            triggerEvent("OnSpawnVehicleEnd", vehicle)
        end
        return vehicle
    end
    IsoDirections = { getRandom = function() return "N" end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Crate.lua")
end

local function freeSquare()
    return { getVehicleContainer = function() return nil end }
end

--- Caisse posée pour le largage dropId ; renvoie le véhicule (dernier créé).
local function spawnFor(dropId)
    MilitaryDrop.Crate.spawn(freeSquare(), dropId)
    return SPAWNED[#SPAWNED].vehicle
end

local function fillFor(dropId)
    return spawnFor(dropId).trunk.items
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
    RECORDS = { D1 = {}, D2 = {}, D3 = {} }
    MilitaryDrop.Trust = { drop = function(dropId) return RECORDS[dropId] end }
end

-- ----------------------------------------------------------------------------
-- Distribution et ligne de démarrage
-- ----------------------------------------------------------------------------

function T.distribution_declared_for_the_trunk()
    triggerEvent("OnPostDistributionMerge")
    local entry = VehicleDistributions[1].MilitaryDrop_SupplyCrate
    assertTrue(entry ~= nil, "distribution déclarée")
    assertEq(entry.Normal.TrailerTrunk.rolls, 0, "vide : rempli par OnFillContainer")
end

function T.start_line_describes_the_crate_distribution_once()
    triggerEvent("OnPostDistributionMerge")
    local logged = captureLog()
    triggerEvent("OnGameStart")
    triggerEvent("OnServerStarted")
    assertEq(#logged, 1, "une seule ligne")
    assertTrue(logged[1]:find("crate contents at start: entry MilitaryDrop_SupplyCrate present", 1, true) ~= nil, logged[1])
    assertTrue(logged[1]:find("unchanged since this mod declared it", 1, true) ~= nil, logged[1])
    assertTrue(logged[1]:find("not visible from Lua", 1, true) ~= nil, "abonnés illisibles")
end

function T.start_line_reports_a_distribution_changed_by_another_mod()
    triggerEvent("OnPostDistributionMerge")
    local trunk = VehicleDistributions[1].MilitaryDrop_SupplyCrate.Normal.TrailerTrunk
    trunk.rolls = 2
    trunk.items = { "Base.Axe", 10, "Base.Pistol", 5 }
    VehicleDistributions[1].MilitaryDrop_SupplyCrate0 = { Normal = {} }
    local logged = captureLog()
    triggerEvent("OnServerStarted")
    assertTrue(find(logged, "CHANGED by another mod") ~= nil, tostring(logged[1]))
    assertTrue(find(logged, "TrailerTrunk rolls 2 with 2 item(s)") ~= nil, "objets ajoutés")
    assertTrue(find(logged, "skin entry MilitaryDrop_SupplyCrate0 added") ~= nil, "entrée de skin lue d'abord")
end

function T.start_line_reports_a_removed_distribution()
    triggerEvent("OnPostDistributionMerge")
    VehicleDistributions[1].MilitaryDrop_SupplyCrate = nil
    local logged = captureLog()
    triggerEvent("OnGameStart")
    assertTrue(find(logged, "entry MilitaryDrop_SupplyCrate missing") ~= nil, tostring(logged[1]))
end

-- ----------------------------------------------------------------------------
-- Remplissage et apparition
-- ----------------------------------------------------------------------------

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
    local vehicle = MilitaryDrop.Crate.spawn(freeSquare())
    assertEq(vehicle, SPAWNED[1].vehicle, "véhicule renvoyé")
    assertEq(SPAWNED[1].script, "Base.MilitaryDrop_SupplyCrate", "script complet")
end

function T.refused_position_is_not_a_crate()
    SQL_ID = -1
    assertEq(MilitaryDrop.Crate.spawn(freeSquare()), nil, "véhicule non ajouté au monde")
end

function T.occupied_square_does_not_spawn()
    local square = { getVehicleContainer = function() return {} end }
    assertEq(MilitaryDrop.Crate.spawn(square), nil, "case occupée par un véhicule")
    assertEq(#SPAWNED, 0, "rien créé")
end

function T.spawned_crate_cases_carry_the_drop_id()
    local vehicle = spawnFor("D3")
    assertEq(#vehicle.trunk.items, 4, "coffre rempli")
    for _, item in ipairs(vehicle.trunk.items) do
        assertEq(item.modData.MilitaryDrop_dropId, "D3", "dropId sur chaque caisse de ravitaillement")
    end
    assertEq(vehicle.modData.MilitaryDrop_dropId, "D3", "dropId dans la ModData de la caisse")
    assertEq(vehicle.modData.resetedContainers, true, "marqueur contre les re-remplissages tiers")
    local later = makeItemContainer()
    triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", later)
    assertEq(later.items[1].modData.MilitaryDrop_dropId, nil, "hors de Crate.spawn, caisse inconnue : aucun dropId")
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

function T.damaged_fulton_kit_only_in_crates_without_order()
    withOrders()
    MilitaryDrop.FultonLoot = { DAMAGED_KIT = "MilitaryDrop.FultonKitDamaged", rollCrate = function() return true end }
    local items = fillFor("D3")
    assertEq(#items, 5, "CaseRolls caisses et un kit endommagé")
    assertEq(items[5].fullType, "MilitaryDrop.FultonKitDamaged", "kit endommagé")
    assertEq(items[5].modData.MilitaryDrop_dropId, "D3", "marqué du largage comme les caisses")
    assertEq(#fillFor("D1"), 2, "commande : jamais de kit")
    assertEq(#fillFor("D2"), 1, "leurre : jamais de kit")
    MilitaryDrop.FultonLoot.rollCrate = function() return false end
    assertEq(#fillFor("D3"), 4, "tirage perdu : caisses seules")
end

-- ----------------------------------------------------------------------------
-- Journal « crate contents »
-- ----------------------------------------------------------------------------

--- Journal toujours écrit (DebugLog faux) quand une caisse reçoit le contenu
--- aléatoire alors qu'un largage était attendu (retour joueur du 2026-10-06).
function T.random_contents_for_an_expected_drop_are_always_logged()
    withOrders()
    local logged = captureLog()
    RECORDS = { D3 = { forced = true } }
    MilitaryDrop.Requisition.formEnabled = function() return true end
    fillFor("D3")
    assertTrue(logged[1] and logged[1]:find("D3: no order in its record (admin drop)", 1, true) ~= nil,
        "dossier sans commande, formulaire actif : " .. tostring(logged[1]))
    logged = captureLog()
    fillFor("D9")
    assertTrue(logged[1] and logged[1]:find("D9: no drop record", 1, true) ~= nil, "dossier introuvable")
    logged = captureLog()
    triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", makeItemContainer())
    assertTrue(find(logged, "crate contents: supply crate trunk filled without a drop id") ~= nil,
        "coffre rempli hors de Crate.spawn : " .. tostring(logged[1]))
    logged = captureLog()
    fillFor("D1")
    assertEq(#logged, 1, "commande trouvée : la seule ligne de livraison")
    MilitaryDrop.Requisition.formEnabled = function() return false end
    logged = captureLog()
    fillFor("D3")
    assertEq(#logged, 1, "formulaire désactivé : un largage sans commande est normal")
end

function T.matching_contents_give_a_single_delivery_line()
    withOrders()
    local logged = captureLog()
    fillFor("D1")
    assertEq(#logged, 1, "une ligne par largage : " .. table.concat(logged, " | "))
    assertTrue(logged[1]:find("crate contents for drop D1 at 10,20 (requisition order): 2 item(s): "
        .. "MilitaryDrop.RequisitionCase x2, as ordered, our OnFillContainer fill: once", 1, true) ~= nil, logged[1])
end

function T.contents_changed_by_another_mod_raise_an_alert()
    withOrders()
    -- Distribution du coffre modifiée (avant notre ajout) et abonné inscrit après nous.
    DISTRIBUTION = { "Base.Pistol" }
    Events.OnFillContainer.Add(function(_, _, container) container:AddItem("Base.Axe") end)
    local logged = captureLog()
    fillFor("D1")
    assertEq(#logged, 2, "ligne de livraison et alerte")
    assertTrue(logged[1]:find("crate contents for drop D1", 1, true) ~= nil, logged[1])
    assertTrue(logged[1]:find("as ordered", 1, true) == nil, "pas conforme")
    local alert = logged[2]
    assertTrue(alert:find("crate contents differ from the order: drop D1, expected 2 item(s): "
        .. "MilitaryDrop.RequisitionCase x2, found 4 item(s): Base.Axe x1, Base.Pistol x1, "
        .. "MilitaryDrop.RequisitionCase x2", 1, true) ~= nil, alert)
    assertTrue(alert:find("before our fill the trunk already held 1 item(s): Base.Pistol x1", 1, true) ~= nil, alert)
    assertTrue(alert:find("another mod may fill vehicle containers", 1, true) ~= nil, alert)
end

function T.missing_fill_raises_an_alert()
    withOrders()
    VehicleDistributions[1] = {}
    -- Sans entrée de distribution, le moteur ne remplit pas le coffre (BaseVehicle.java:7980-7988).
    addVehicleDebug = function(script)
        local vehicle = makeVehicle(script)
        SPAWNED[#SPAWNED + 1] = { vehicle = vehicle }
        return vehicle
    end
    local logged = captureLog()
    fillFor("D1")
    assertTrue(find(logged, "our OnFillContainer fill: NOT RECEIVED") ~= nil, tostring(logged[1]))
    assertTrue(find(logged, "our fill never ran") ~= nil, tostring(logged[2]))
end

-- ----------------------------------------------------------------------------
-- Mod tiers qui re-remplit les coffres des véhicules de mod
-- ----------------------------------------------------------------------------

--- Simulation fidèle du mod tiers observé (Workshop 3457132019,
--- ResetContainers.lua:6-33, 99-109) : inscrit à OnSpawnVehicleEnd, il agit
--- plus tard (5 s solo, 10 s serveur MP) sur un véhicule non vanilla dont le
--- type a une entrée Normal non vide : sort si resetedContainers, sort si le
--- coffre a été pillé, sinon setExplored(false), vidage en MP, puis
--- forceVehicleDistribution (vide puis rappelle OnFillContainer). honorMarker
--- faux : un autre mod du même genre qui ignore le marqueur.
local function installRefillMod(honorMarker)
    local pending = {}
    Events.OnSpawnVehicleEnd.Add(function(vehicle) pending[#pending + 1] = vehicle end)
    return function()
        for _, vehicle in ipairs(pending) do
            local modData = vehicle:getModData()
            local entry = VehicleDistributions[1].MilitaryDrop_SupplyCrate
            if not (honorMarker and modData.resetedContainers == true) and entry and entry.Normal then
                local trunk = vehicle.trunk
                if not trunk.looted then
                    trunk.explored = false
                    if isMultiplayer() then
                        trunk:clear()
                    end
                    engineFill(vehicle)
                    modData.resetedContainers = true
                end
            end
        end
        pending = {}
    end
end

local function assertOrderIntact(items, label)
    local counts = countTypes(items)
    assertEq(#items, 2, label .. " : deux caisses commandées")
    assertEq(counts["MilitaryDrop.RequisitionCase"], 2, label .. " : commande")
    assertEq(counts["MilitaryDrop.AmmoSupplyCase"], nil, label .. " : aucune caisse aléatoire")
    for _, item in ipairs(items) do
        assertEq(item.modData.MilitaryDrop_dropId, "D1", label .. " : dropId")
    end
end

function T.refill_mod_honouring_the_marker_leaves_the_order_solo_and_mp()
    for _, mp in ipairs({ false, true }) do
        MULTIPLAYER = mp
        withOrders()
        triggerEvent("OnPostDistributionMerge")
        local runLater = installRefillMod(true)
        local vehicle = spawnFor("D1")
        runLater()
        assertOrderIntact(vehicle.trunk.items, mp and "MP" or "solo")
    end
end

function T.refill_ignoring_the_marker_restores_the_order_once_solo_and_mp()
    for _, mp in ipairs({ false, true }) do
        MULTIPLAYER = mp
        withOrders()
        triggerEvent("OnPostDistributionMerge")
        local runLater = installRefillMod(false)
        local vehicle = spawnFor("D1")
        local logged = captureLog()
        runLater()
        local label = mp and "MP" or "solo"
        assertOrderIntact(vehicle.trunk.items, label)
        assertTrue(find(logged, "crate container refilled by another mod (forceVehicleDistribution?) for drop D1"
            .. " at 10,20: order restored (2 item(s): MilitaryDrop.RequisitionCase x2)") ~= nil,
            label .. " : " .. tostring(logged[1]))
        -- Second re-remplissage : jamais une seconde commande à piller.
        vehicle.trunk.explored = false
        engineFill(vehicle)
        assertEq(#vehicle.trunk.items, 0, label .. " : rendue une fois au plus")
    end
end

function T.refill_of_an_emptied_drop_adds_nothing()
    withOrders()
    local vehicle = spawnFor("D1")
    RECORDS.D1.collectedHours = 30
    local logged = captureLog()
    vehicle.trunk.explored = false
    engineFill(vehicle)
    assertEq(#vehicle.trunk.items, 0, "largage vidé : ni commande ni caisses aléatoires")
    assertTrue(find(logged, "drop already emptied, closed or restored once") ~= nil, tostring(logged[1]))
end

function T.refill_without_clearing_does_not_duplicate_the_order()
    withOrders()
    local vehicle = spawnFor("D1")
    triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", vehicle.trunk)
    assertOrderIntact(vehicle.trunk.items, "coffre non vidé")
end

function T.crates_and_wrecks_of_existing_saves_are_marked_when_loaded()
    local crate = makeVehicle()
    local case = crate.trunk:AddItem("MilitaryDrop.AmmoSupplyCase")
    case.modData.MilitaryDrop_dropId = "D5"
    triggerEvent("OnSpawnVehicleEnd", crate)
    assertEq(crate.modData.resetedContainers, true, "caisse chargée : marqueur")
    assertEq(crate.modData.MilitaryDrop_dropId, "D5", "dropId repris du coffre")
    local wreck = makeVehicle("Base.MilitaryDrop_HeliWreckBurnt")
    triggerEvent("OnSpawnVehicleEnd", wreck)
    assertEq(wreck.modData.resetedContainers, true, "épave : marqueur")
    assertEq(wreck.modData.MilitaryDrop_dropId, nil, "épave : pas de dropId")
    local van = makeVehicle("Base.Van")
    triggerEvent("OnSpawnVehicleEnd", van)
    assertEq(van.modData.resetedContainers, nil, "véhicule d'un autre mod ou vanilla : intact")
end

return T
