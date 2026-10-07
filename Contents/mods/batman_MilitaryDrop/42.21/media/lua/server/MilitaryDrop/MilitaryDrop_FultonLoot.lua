-- ============================================================================
-- Military Drop — Fulton : butin (FULTON-10), serveur MP ou solo
--
-- Sur le modèle du carnet de codes (MilitaryDrop_Notes.lua) : objets ajoutés aux
-- listes procédurales vanilla 42.21 sur OnInitGlobalModData (options sandbox
-- connues, y compris en solo), sans doublon, puis ItemPickerJava.Parse(). Poids
-- multipliés par FultonLootRate (pour cent ; 0 : rien). Option changée en cours
-- de partie : objets retirés puis remis avec le nouveau poids, tables relues ;
-- seuls les conteneurs remplis ensuite changent.
--   * bouteille d'hélium : magasins de cadeaux et de jouets (GiftStoreToys ;
--     aucune salle de magasin de fêtes en 42.21), réserves de l'armée ;
--   * kit Fulton endommagé : réserves de l'armée (rare) ; aussi sur le pilote
--     d'une épave Mayday (Wreck.pilot) et dans une caisse de largage sans
--     commande (Crate.contentsFor), par tirage.
-- Listes relevées dans ProceduralDistributions.lua 42.21 (contrôle statique :
-- tests/run_tests.py). ArmyHangar* ne sont citées par aucune salle : à éviter.
-- Poids et chances : propositions de la conception (§6), à régler en jeu.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Fulton"

local Config = MilitaryDrop.Config
local Fulton = MilitaryDrop.Fulton

local FultonLoot = {}
MilitaryDrop.FultonLoot = FultonLoot

FultonLoot.DAMAGED_KIT = "MilitaryDrop.FultonKitDamaged"
-- { objet, liste procédurale, poids de base }.
FultonLoot.ENTRIES = {
    { Fulton.TANK_TYPE, "GiftStoreToys", 1.5 },
    { Fulton.TANK_TYPE, "ArmyStorageMedical", 1 },
    { Fulton.TANK_TYPE, "ArmyBunkerStorage", 0.5 },
    { "MilitaryDrop.FultonKitDamaged", "ArmyStorageElectronics", 0.3 },
    { "MilitaryDrop.FultonKitDamaged", "ArmyBunkerStorage", 0.3 },
}
-- Chances de base (pour cent) d'un kit endommagé sur le pilote d'une épave
-- Mayday et dans une caisse de largage sans commande.
FultonLoot.WRECK_CHANCE = 25
FultonLoot.CRATE_CHANCE = 5

--- Taux de butin (FultonLootRate) en fraction : 1 par défaut, 0 au plus bas.
function FultonLoot.rate()
    return math.max(0, tonumber(Config.get("FultonLootRate")) or 0) / 100
end

local function listItems(name)
    local list = ProceduralDistributions and ProceduralDistributions.list[name]
    return list and list.items
end

--- Retire les objets Fulton des listes (objet et poids qui le suit) ; vrai si retiré.
local function removeAll()
    local removed = false
    for _, entry in ipairs(FultonLoot.ENTRIES) do
        local items = listItems(entry[2])
        if items then
            for i = #items - 1, 1, -1 do
                if items[i] == entry[1] and type(items[i + 1]) == "number" then
                    table.remove(items, i + 1)
                    table.remove(items, i)
                    removed = true
                end
            end
        end
    end
    return removed
end

--- Ajoute chaque objet absent de sa liste, avec son poids × taux ; vrai si ajouté.
local function insertAll()
    local rate = FultonLoot.rate()
    if rate <= 0 then
        return false
    end
    local added = false
    for _, entry in ipairs(FultonLoot.ENTRIES) do
        local items = listItems(entry[2])
        if items then
            local present = false
            for _, value in ipairs(items) do
                present = present or value == entry[1]
            end
            if not present then
                table.insert(items, entry[1])
                table.insert(items, entry[3] * rate)
                added = true
            end
        else
            MilitaryDrop.log("Fulton loot: procedural list " .. entry[2] .. " not found", true)
        end
    end
    return added
end

--- Premier ajout (OnInitGlobalModData) ; vrai si les listes ont changé.
function FultonLoot.addToLoot()
    if not ProceduralDistributions then
        return false
    end
    local added = insertAll()
    if added then
        ItemPickerJava.Parse()
        MilitaryDrop.log("Fulton items added to loot lists, rate " .. FultonLoot.rate())
    end
    return added
end

--- FultonLootRate changé en cours de partie : retrait, nouvel ajout, relecture.
function FultonLoot.refresh()
    if not ProceduralDistributions then
        return false
    end
    local removed = removeAll()
    local added = insertAll()
    if removed or added then
        ItemPickerJava.Parse()
        MilitaryDrop.log("Fulton loot lists refreshed, rate " .. FultonLoot.rate())
    end
    return removed or added
end

--- Tirage d'une chance de base (pour cent) multipliée par le taux, bornée à 100.
function FultonLoot.roll(chance)
    local percent = math.min(100, chance * FultonLoot.rate())
    return percent > 0 and ZombRandFloat(0, 100) < percent
end

--- Kit endommagé sur le pilote d'une épave Mayday (tirage unique : Wreck.pilot
--- n'est exécuté qu'une fois par site).
function FultonLoot.rollWreck()
    return FultonLoot.roll(FultonLoot.WRECK_CHANCE)
end

--- Kit endommagé dans une caisse de largage sans commande.
function FultonLoot.rollCrate()
    return FultonLoot.roll(FultonLoot.CRATE_CHANCE)
end

Events.OnInitGlobalModData.Add(FultonLoot.addToLoot)
Config.onChange("FultonLoot.lists", { "FultonLootRate" }, FultonLoot.refresh)

return FultonLoot
