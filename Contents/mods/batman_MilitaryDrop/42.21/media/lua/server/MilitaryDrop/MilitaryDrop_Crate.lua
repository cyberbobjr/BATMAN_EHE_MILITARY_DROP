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

Crate.SCRIPT = "MilitaryDrop_SupplyCrate"
Crate.FULL_SCRIPT = "Base." .. Crate.SCRIPT
Crate.TRUNK = "TrailerTrunk"
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
    for _, fullType in ipairs(Crate.rollCases()) do
        container:AddItem(fullType)
    end
end

--- Fait apparaître la caisse sur la case (chargée) ; renvoie le véhicule ou nil.
--- addVehicleDebug renvoie le véhicule même quand sa position est refusée
--- (collision avec un autre véhicule), sans l'ajouter au monde : seul un
--- véhicule ajouté reçoit un identifiant de base (VehiclesDB2.addVehicle).
function Crate.spawn(square)
    if square:getVehicleContainer() then
        return nil
    end
    local vehicle = addVehicleDebug(Crate.FULL_SCRIPT, IsoDirections.getRandom(), 0, square)
    if vehicle and vehicle:getSqlId() ~= -1 then
        return vehicle
    end
    return nil
end

Events.OnPostDistributionMerge.Add(Crate.registerDistribution)
Events.OnFillContainer.Add(Crate.onFillContainer)

return Crate
