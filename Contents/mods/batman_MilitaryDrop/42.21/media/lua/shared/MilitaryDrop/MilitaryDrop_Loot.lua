-- ============================================================================
-- Military Drop — contenu des caisses de ravitaillement
--
-- Chaque type de caisse tire ses objets d'une liste pondérée { nom, poids, … } :
-- les tables vanilla de l'armée (ProceduralDistributions), donc aussi ce que
-- les mods d'armes y ajoutent. Un filtre par catégorie d'objet (ItemType)
-- écarte ce qui n'a pas sa place dans la caisse, et chaque nom est vérifié
-- dans le ScriptManager avant d'être créé.
--
-- Extension pour d'autres mods : MilitaryDrop.Loot.CASES[type].source est une
-- fonction qui renvoie la liste pondérée ; on peut la remplacer.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Loot = {}
MilitaryDrop.Loot = Loot

local function proceduralList(name)
    local list = ProceduralDistributions and ProceduralDistributions.list
    local entry = list and list[name]
    return entry and entry.items or {}
end

-- Accessoires d'armes vanilla 42.21 (la B41 avait Sling, IronSight,
-- FiberglassStock, absents de 42.21 ; les noms inconnus sont ignorés).
Loot.ATTACHMENTS = {
    "AmmoStrap_Bullets", 6,
    "AmmoStrap_Shells", 4,
    "ChokeTubeFull", 6,
    "ChokeTubeImproved", 6,
    "GunLight", 6,
    "Hat_EarMuff_Protectors", 8,
    "Laser", 6,
    "RecoilPad", 6,
    "RedDot", 6,
    "TritiumSights", 4,
    "x2Scope", 8,
    "x4Scope", 6,
    "x8Scope", 4,
}

--- picks : nombre d'objets tirés ; accept(script) : filtre facultatif.
Loot.CASES = {
    ["MilitaryDrop.AmmoSupplyCase"] = {
        picks = 5,
        source = function() return proceduralList("ArmyStorageAmmunition") end,
        -- Les sacs de munitions de la table arrivent vides hors du remplissage
        -- des conteneurs : seulement les boîtes et cartons.
        accept = function(script) return script:getItemType() ~= ItemType.CONTAINER end,
    },
    ["MilitaryDrop.WeaponSupplyCase"] = {
        picks = 1,
        source = function() return proceduralList("ArmyStorageGuns") end,
        -- ArmyStorageGuns contient aussi des étuis et du matériel médical.
        accept = function(script) return script:getItemType() == ItemType.WEAPON end,
    },
    ["MilitaryDrop.ArmorSupplyCase"] = {
        picks = 5,
        source = function() return proceduralList("ArmyStorageOutfit") end,
    },
    ["MilitaryDrop.AttachmentSupplyCase"] = {
        picks = 5,
        source = function() return Loot.ATTACHMENTS end,
    },
}

--- Liste { {name, weight}, … } à partir d'une table { nom, poids, nom, poids… },
--- sans les poids nuls, négatifs ou illisibles.
function Loot.toEntries(flat)
    local entries = {}
    for i = 1, #flat - 1, 2 do
        local name, weight = flat[i], tonumber(flat[i + 1])
        if type(name) == "string" and weight and weight > 0 then
            entries[#entries + 1] = { name = name, weight = weight }
        end
    end
    return entries
end

--- Tire une entrée selon les poids (décimaux permis). rand(total) doit
--- renvoyer un nombre dans [0, total[.
function Loot.pickWeighted(entries, rand)
    local total = 0
    for _, entry in ipairs(entries) do
        total = total + entry.weight
    end
    if total <= 0 then
        return nil
    end
    local point = rand(total)
    local sum = 0
    for _, entry in ipairs(entries) do
        sum = sum + entry.weight
        if point < sum then
            return entry
        end
    end
    return entries[#entries]
end

local function gameRand(total)
    return ZombRandFloat(0, total)
end

--- Entrées valides pour un type de caisse : objet connu du jeu et accepté.
function Loot.candidates(caseType)
    local case = Loot.CASES[caseType]
    if not case then
        return {}
    end
    local manager = getScriptManager()
    local result = {}
    for _, entry in ipairs(Loot.toEntries(case.source())) do
        local script = manager:FindItem(entry.name)
        if script and (not case.accept or case.accept(script)) then
            entry.fullType = script:getFullName()
            result[#result + 1] = entry
        end
    end
    return result
end

-- Avec chaque arme à feu : ses chargeurs et une boîte de ses munitions.
Loot.MAGAZINES_PER_WEAPON = 2
Loot.AMMO_BOXES_PER_WEAPON = 1

--- Types complets à ajouter avec une arme (HandWeapon) : chargeurs et boîte de
--- munitions, s'ils existent dans le jeu.
function Loot.weaponExtras(weapon)
    local extras = {}
    if not instanceof(weapon, "HandWeapon") then
        return extras
    end
    local manager = getScriptManager()
    local function add(fullType, count)
        if type(fullType) == "string" and fullType ~= "" and manager:FindItem(fullType) then
            for _ = 1, count do
                extras[#extras + 1] = fullType
            end
        end
    end
    add(weapon:getMagazineType(), Loot.MAGAZINES_PER_WEAPON)
    add(weapon:getAmmoBox(), Loot.AMMO_BOXES_PER_WEAPON)
    return extras
end

--- Types complets des objets à créer pour une caisse ouverte.
function Loot.roll(caseType, rand)
    local case = Loot.CASES[caseType]
    local results = {}
    if not case then
        return results
    end
    local entries = Loot.candidates(caseType)
    if #entries == 0 then
        MilitaryDrop.log("no valid loot for " .. tostring(caseType), true)
        return results
    end
    for _ = 1, case.picks do
        local entry = Loot.pickWeighted(entries, rand or gameRand)
        if entry then
            results[#results + 1] = entry.fullType
        end
    end
    return results
end

return Loot
