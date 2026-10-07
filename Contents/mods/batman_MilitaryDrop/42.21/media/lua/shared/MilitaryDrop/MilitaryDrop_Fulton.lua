-- ============================================================================
-- Military Drop — Fulton : classement et barème du contenu d'un kit (FULTON-08,
-- FULTON-09), client et serveur
--
-- Le serveur fait autorité (solo, ou serveur MP) : il classe le contenu du kit
-- au lâcher et paie. Le client n'utilise ce module que pour l'aperçu avant
-- confirmation ; ses noms d'objets traduits peuvent différer de ceux du serveur.
-- Conception : dev/analyses/idee-12-fulton-conception.md §2.
--
-- Seuls les objets directement dans le kit comptent ; un conteneur imbriqué part
-- avec le kit sans être payé. Tout ce qui est envoyé est détruit : aucun registre
-- d'unicité (contrairement aux plaques SRC-02, transmises par radio).
--
-- Reconnaissance des objets vanilla 42.21 :
--   * pièce d'identité nominative : tag base:applyownername et (tag base:idcard
--     ou type d'identité de IDENTITY_TYPES), nom brut (getDisplayName) différent
--     du nom du script et ne contenant pas le nom du joueur qui envoie. Le jeu
--     renomme la carte d'un mort (InventoryItem.nameAfterDescriptor) ou nomme au
--     hasard celle du butin (ItemCodeOnCreate.onCreateIDCard) : indiscernables,
--     toutes deux acceptées. Exclues : IDcard_Stolen (sans applyownername),
--     IDcard_Blank (sans base:idcard) ;
--   * papiers : types de PAPER_TYPES (aucun tag vanilla ne les désigne) ;
--   * carte-cachette : getStashMap() non nul (StashSystem.doStashItem, champ
--     sauvegardé avec l'objet) ; les annotations d'une carte ordinaire ne sont
--     pas lisibles côté serveur (MapItem.getSymbols caché à Lua) ;
--   * NRBC militaire : base:hazmatsuit avant base:scba (HazmatSuit porte les
--     deux), base:gasmask, base:gasmaskfilter. Respirateurs, masques bricolés
--     et masques sans filtre exclus.
--   * Zombie Virus Vaccine (Workshop 3615135168, id ZVirusVaccine42BETA,
--     module LabItems, variante 42.20) : types relevés le 2026-10-07, payés
--     seulement si ce mod est actif.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Config = MilitaryDrop.Config

local Fulton = {}
MilitaryDrop.Fulton = Fulton

Config.addDefaults({
    -- Barème en pour cent ; 0 désactive la source Fulton.
    FultonValue = 100,
    FultonWindowMinutes = 30,
    FultonLootRate = 100,
})

Fulton.VACCINE_MOD = "ZVirusVaccine42BETA"
Fulton.KIT_TYPE = "MilitaryDrop.FultonKit"
Fulton.TANK_TYPE = "MilitaryDrop.HeliumTank"
-- Vent au-delà duquel le ballon ne peut pas être lâché (km/h, ClimateManager).
Fulton.MAX_WIND_KPH = 60
-- Distance maximale (cases, même étage) entre le joueur et le kit posé au sol.
Fulton.REACH = 2

-- Valeurs de base par catégorie (décisions du 2026-10-07 ; ARI : proposition).
Fulton.VALUES = {
    identity = 3,
    papers = 1,
    stashMap = 4,
    hazmatSuit = 6,
    scba = 2,
    gasMask = 2,
    gasMaskFilter = 1,
    blood = 1,
    brainFluidLow = 2,
    brainFluidMid = 3,
    brainFluidHigh = 4,
    brain = 3,
    vaccinePlain = 5,
    vaccineQuality = 7,
    vaccineAdvanced = 10,
    cure = 25,
}
-- Catégories payées hors plafond quotidien (source de confiance fultonCure).
Fulton.UNCAPPED = { cure = true }

Fulton.IDENTITY_TYPES = {
    ["Base.Passport"] = true,
    ["Base.PressID"] = true,
    ["Base.Badge"] = true,
    ["Base.KeyRing_SecurityPass"] = true,
}

Fulton.PAPER_TYPES = {
    ["Base.Paperwork"] = true,
    ["Base.OfficialDocument"] = true,
}

local function lab(categories)
    local types = {}
    for category, names in pairs(categories) do
        for _, name in ipairs(names) do
            types["LabItems." .. name] = category
        end
    end
    return types
end

-- Type → catégorie (cerveaux pourris ou brûlés absents : sans valeur).
Fulton.VACCINE_TYPES = lab({
    blood = { "MatInfectedBlood", "MatTaintedBlood", "CmpSyringeWithBlood", "CmpSyringeReusableWithBlood",
        "CmpSyringeWithTaintedBlood", "CmpSyringeReusableWithTaintedBlood" },
    brainFluidLow = { "CmpSyringeWithBrainFluidLow", "CmpSyringeReusableWithBrainFluidLow" },
    brainFluidMid = { "CmpSyringeWithBrainFluidMid", "CmpSyringeReusableWithBrainFluidMid" },
    brainFluidHigh = { "CmpSyringeWithBrainFluidHigh", "CmpSyringeReusableWithBrainFluidHigh" },
    brain = { "HumanBrainLow", "HumanBrainMid", "HumanBrainHigh" },
    vaccinePlain = { "CmpSyringeWithPlainVaccine", "CmpSyringeReusableWithPlainVaccine" },
    vaccineQuality = { "CmpSyringeWithQualityVaccine", "CmpSyringeReusableWithQualityVaccine" },
    vaccineAdvanced = { "CmpSyringeWithAdvancedVaccine", "CmpSyringeReusableWithAdvancedVaccine" },
    cure = { "CmpSyringeWithCure", "CmpSyringeReusableWithCure" },
})

-- Ordre des tests NRBC : HazmatSuit porte aussi base:scba.
local GEAR_TAGS = {
    { "HAZMAT_SUIT", "hazmatSuit" },
    { "SCBA", "scba" },
    { "GAS_MASK", "gasMask" },
    { "GASMASK_FILTER", "gasMaskFilter" },
}

local function hasTag(item, name)
    local tag = ItemTag and ItemTag[name]
    return tag ~= nil and item:hasTag(tag)
end

--- Zombie Virus Vaccine est actif dans cette partie (liste Java des IDs,
--- « \ » initial possible).
function Fulton.vaccineActive()
    local mods = getActivatedMods and getActivatedMods()
    if not mods then
        return false
    end
    for i = 0, mods:size() - 1 do
        if (tostring(mods:get(i)):gsub("^\\", "")) == Fulton.VACCINE_MOD then
            return true
        end
    end
    return false
end

--- Nom du personnage tel que InventoryItem.nameAfterDescriptor l'écrit, ou nil.
function Fulton.ownerName(player)
    local desc = player and player.getDescriptor and player:getDescriptor()
    if not desc then
        return nil
    end
    return tostring(desc:getForename()) .. " " .. tostring(desc:getSurname())
end

--- Vrai pour une pièce d'identité nominative qui n'est pas celle de player
--- (player facultatif).
function Fulton.isIdentity(item, player)
    if not hasTag(item, "APPLY_OWNER_NAME") then
        return false
    end
    if not hasTag(item, "IDCARD") and not Fulton.IDENTITY_TYPES[item:getFullType()] then
        return false
    end
    local name = item:getDisplayName()
    local script = item:getScriptItem()
    if type(name) ~= "string" or name == "" or (script and name == script:getDisplayName()) then
        return false
    end
    local owner = Fulton.ownerName(player)
    return owner == nil or string.find(name, owner, 1, true) == nil
end

--- Catégorie d'un objet envoyé (clé de VALUES), ou nil s'il n'est pas payé.
function Fulton.category(item, player, vaccine)
    if not item or instanceof(item, "InventoryContainer") then
        return nil
    end
    local fullType = item:getFullType()
    if vaccine then
        local category = Fulton.VACCINE_TYPES[fullType]
        if category then
            return category
        end
    end
    for _, gear in ipairs(GEAR_TAGS) do
        if hasTag(item, gear[1]) then
            return gear[2]
        end
    end
    local stash = item:getStashMap()
    if stash ~= nil and stash ~= "" then
        return "stashMap"
    end
    if Fulton.isIdentity(item, player) then
        return "identity"
    end
    if Fulton.PAPER_TYPES[fullType] then
        return "papers"
    end
    return nil
end

local function scaled(points, percent)
    return math.floor(points * percent / 100 + 0.5)
end

--- Valeur d'une liste d'objets (tableau Lua) envoyée par player :
--- { capped, uncapped, counts = { catégorie = nombre }, paid, unpaid }.
--- Les points sont multipliés par FultonValue (pour cent) puis arrondis.
function Fulton.evaluate(items, player)
    local percent = math.max(0, tonumber(Config.get("FultonValue")) or 0)
    local vaccine = Fulton.vaccineActive()
    local result = { capped = 0, uncapped = 0, counts = {}, paid = 0, unpaid = 0 }
    local cappedPoints, uncappedPoints = 0, 0
    for _, item in ipairs(items) do
        local category = Fulton.category(item, player, vaccine)
        if category then
            result.counts[category] = (result.counts[category] or 0) + 1
            result.paid = result.paid + 1
            if Fulton.UNCAPPED[category] then
                uncappedPoints = uncappedPoints + Fulton.VALUES[category]
            else
                cappedPoints = cappedPoints + Fulton.VALUES[category]
            end
        else
            result.unpaid = result.unpaid + 1
        end
    end
    result.capped = scaled(cappedPoints, percent)
    result.uncapped = scaled(uncappedPoints, percent)
    return result
end

--- Objets directement contenus dans un kit (tableau Lua), sans descendre dans
--- les conteneurs imbriqués.
function Fulton.kitItems(kit)
    local items = {}
    local container = kit and kit.getItemContainer and kit:getItemContainer()
    if not container then
        return items
    end
    local list = container:getItems()
    for i = 0, list:size() - 1 do
        items[#items + 1] = list:get(i)
    end
    return items
end

--- Partage d'une évaluation selon le plafond restant du jour (dailyLeft) :
--- { credited, lost, uncapped }.
function Fulton.settle(evaluation, dailyLeft)
    local left = math.max(0, math.floor(tonumber(dailyLeft) or 0))
    local credited = math.min(evaluation.capped, left)
    return { credited = credited, lost = evaluation.capped - credited, uncapped = evaluation.uncapped }
end

--- La source Fulton est activée (barème non nul).
function Fulton.isEnabled()
    return (tonumber(Config.get("FultonValue")) or 0) > 0
end

-- ----------------------------------------------------------------------------
-- Conditions de lâcher (FULTON-07) : client pour griser le menu, serveur pour
-- décider. Les zones protégées (non-PvP, refuges) ne sont connues que du serveur.
-- ----------------------------------------------------------------------------

--- Motif (clé de traduction) qui empêche de lâcher un ballon depuis square, ou nil.
function Fulton.siteReason(square)
    if not square or not square:isOutside() then
        return "IGUI_MilitaryDrop_Fulton_NotOutside"
    end
    if square:getTree() ~= nil then
        return "IGUI_MilitaryDrop_Fulton_Tree"
    end
    local climate = getClimateManager and getClimateManager()
    if climate then
        if climate:getIsThunderStorming() then
            return "IGUI_MilitaryDrop_Fulton_Storm"
        end
        if climate:getWindspeedKph() > Fulton.MAX_WIND_KPH then
            return "IGUI_MilitaryDrop_Fulton_Wind"
        end
    end
    return nil
end

--- Bouteille d'hélium avec au moins une charge.
function Fulton.tankHasHelium(tank)
    return tank ~= nil and tank:getFullType() == Fulton.TANK_TYPE and tank:getCurrentUses() > 0
end

--- Première bouteille d'hélium non vide de l'inventaire (sacs portés compris
--- si recursive), ou nil.
function Fulton.findTank(inventory, recursive)
    local items = recursive and inventory:getAllTypeRecurse(Fulton.TANK_TYPE) or inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if Fulton.tankHasHelium(item) then
            return item
        end
    end
    return nil
end
