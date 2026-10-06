-- ============================================================================
-- Military Drop — caisse de largage (véhicule Base.MilitaryDrop_SupplyCrate)
--
-- Le coffre d'un véhicule est rempli par le serveur à sa création
-- (BaseVehicle.randomizeContainers, 42.21), seulement si le type a une
-- distribution. On en déclare une vide ; le contenu est ajouté par
-- OnFillContainer, qui lit les options sandbox au moment même (pas besoin de
-- relire les tables de butin après leur fusion).
--
-- Serveur MP ou solo seulement : un client ne crée ni ne remplit de véhicule.
--
-- Confiance : chaque caisse de ravitaillement du coffre porte le dropId du
-- largage (ModData MilitaryDrop_dropId). addVehicleDebug remplit le coffre
-- pendant l'appel (addToWorld → createPhysics → randomizeContainers →
-- OnFillContainer, BaseVehicle.java:804-888, 42.21) : le dropId en cours est
-- donc connu de onFillContainer.
--
-- Contenu (Crate.contentsFor) : sans commande, CaseRolls caisses de
-- ravitaillement tirées au hasard ; commande du formulaire (v1.4) : une
-- caisse de réquisition par unité commandée (MilitaryDrop.Requisition.casesFor :
-- lot en ModData, nom composé) ; leurre (v1.5) : ce que fournit
-- MilitaryDrop.Decoy.trunkContents (balise de diversion). Même contenu au sol
-- quand la caisse ne peut pas apparaître (Server.deliver).
-- ============================================================================

if isClient() then
    return
end

require "Vehicles/VehicleDistributions"
require "MilitaryDrop/MilitaryDrop_Loot"

local Config = MilitaryDrop.Config
local Loot = MilitaryDrop.Loot

local Crate = {}
MilitaryDrop.Crate = Crate

-- Largage de la caisse en cours de création (Crate.spawn), ou nil.
local fillingDropId = nil

Crate.SCRIPT = "MilitaryDrop_SupplyCrate"
Crate.FULL_SCRIPT = "Base." .. Crate.SCRIPT
Crate.TRUNK = "TrailerTrunk"
-- ModData d'objet : largage d'une caisse de ravitaillement (MilitaryDrop_Trust.lua).
Crate.DROP_KEY = "MilitaryDrop_dropId"
-- Caisses de ravitaillement tirées à chaque option CaseRolls.
Crate.CASE_WEIGHTS = {
    "MilitaryDrop.AmmoSupplyCase", 45,
    "MilitaryDrop.WeaponSupplyCase", 25,
    "MilitaryDrop.ArmorSupplyCase", 15,
    "MilitaryDrop.AttachmentSupplyCase", 15,
}

--- Types complets des caisses de ravitaillement d'un largage.
function Crate.rollCases(rand)
    rand = rand or function(total) return ZombRandFloat(0, total) end
    local entries = Loot.toEntries(Crate.CASE_WEIGHTS)
    local cases = {}
    for _ = 1, math.max(1, math.floor(Config.get("CaseRolls"))) do
        local entry = Loot.pickWeighted(entries, rand)
        if entry then
            cases[#cases + 1] = entry.name
        end
    end
    return cases
end

--- Contenu d'un largage : { { fullType, name?, lot? }, … }.
function Crate.contentsFor(dropId)
    local Requisition = MilitaryDrop.Requisition
    local order = dropId and Requisition and Requisition.orderOf(dropId)
    if order and order.decoy then
        local Decoy = MilitaryDrop.Decoy
        local contents = Decoy and Decoy.trunkContents and Decoy.trunkContents(dropId)
        if type(contents) ~= "table" then
            MilitaryDrop.log("decoy " .. tostring(dropId) .. ": no decoy module, empty trunk", true)
            return {}
        end
        return contents
    end
    if order and order.lots then
        return Requisition.casesFor(dropId)
    end
    -- Contenu aléatoire alors qu'un largage était désigné : dossier introuvable
    -- (oublié, état privé perdu), ou sans commande alors que le formulaire est
    -- actif (largage d'avant l'option, ou commande perdue). Toujours journalisé
    -- (retour joueur du 2026-10-06 : commande admin livrée au hasard).
    local Trust = MilitaryDrop.Trust
    if dropId and Trust and Trust.drop then
        local drop = Trust.drop(dropId)
        if not drop then
            MilitaryDrop.log("drop " .. tostring(dropId) .. ": no drop record, random supply cases", true)
        elseif Requisition and Requisition.formEnabled and Requisition.formEnabled() then
            MilitaryDrop.log("drop " .. tostring(dropId) .. ": no order in its record"
                .. (drop.forced and " (admin drop)" or "") .. ", random supply cases", true)
        end
    end
    local entries = {}
    for i, fullType in ipairs(Crate.rollCases()) do
        entries[i] = { fullType = fullType }
    end
    return entries
end

--- Marque un objet créé pour un largage : dropId (confiance), lot d'une
--- caisse de réquisition, nom composé (setName + setCustomName, sauvegardé et
--- transmis au client).
function Crate.applyEntry(item, entry, dropId)
    local modData = item:getModData()
    if dropId then
        modData[Crate.DROP_KEY] = dropId
    end
    if entry.lot and MilitaryDrop.Lots then
        modData[MilitaryDrop.Lots.ITEM_KEY] = entry.lot
    end
    if type(entry.name) == "string" and entry.name ~= "" then
        item:setName(entry.name)
        item:setCustomName(true)
    end
end

function Crate.registerDistribution()
    local tables = VehicleDistributions and VehicleDistributions[1]
    if type(tables) ~= "table" then
        MilitaryDrop.log("VehicleDistributions[1] missing: the crate trunk stays empty", true)
        return
    end
    tables[Crate.SCRIPT] = { Normal = { [Crate.TRUNK] = { rolls = 0, items = {} } } }
end

function Crate.onFillContainer(roomType, _, container)
    if roomType ~= Crate.SCRIPT or not instanceof(container, "ItemContainer") then
        return
    end
    if fillingDropId == nil then
        -- Coffre rempli hors de Crate.spawn (aucun appel connu du moteur 42.21 :
        -- BaseVehicle.randomizeContainers ne repasse pas sur un coffre exploré).
        MilitaryDrop.log("supply crate trunk filled without a drop id (outside Crate.spawn): random supply cases", true)
    end
    for _, entry in ipairs(Crate.contentsFor(fillingDropId)) do
        local item = container:AddItem(entry.fullType)
        if item then
            Crate.applyEntry(item, entry, fillingDropId)
        end
    end
end

--- Fait apparaître la caisse sur la case (chargée) ; renvoie le véhicule ou nil.
--- dropId : largage, posé sur chaque caisse de ravitaillement du coffre.
--- addVehicleDebug renvoie le véhicule même quand sa position est refusée
--- (collision avec un autre véhicule), sans l'ajouter au monde : seul un
--- véhicule ajouté reçoit un identifiant de base (VehiclesDB2.addVehicle).
function Crate.spawn(square, dropId)
    if square:getVehicleContainer() then
        return nil
    end
    -- Une erreur Java laisserait fillingDropId posé : seul Crate.spawn crée ce
    -- véhicule, et il le repose à chaque appel.
    fillingDropId = dropId
    local vehicle = addVehicleDebug(Crate.FULL_SCRIPT, IsoDirections.getRandom(), 0, square)
    fillingDropId = nil
    if vehicle and vehicle:getSqlId() ~= -1 then
        return vehicle
    end
    return nil
end

Events.OnPostDistributionMerge.Add(Crate.registerDistribution)
Events.OnFillContainer.Add(Crate.onFillContainer)

return Crate
