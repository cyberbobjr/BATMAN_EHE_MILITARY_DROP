-- ============================================================================
-- Military Drop — lots du formulaire de réquisition (v1.4, REQ-02)
--
-- Dix-huit lots en trois groupes (paliers de confiance : MilitaryDrop_
-- Requisition.lua). Aucun nom d'objet : chaque lot filtre le script d'objet
-- par sa catégorie d'affichage (DisplayCategory, relevée dans les scripts
-- vanilla 42.21, scripts/generated/items/*.txt), ses propriétés ou ses tags.
-- Les objets des mods rejoignent leur lot seuls.
--
-- Les candidats d'un lot sont les objets présents dans toutes les tables de
-- butin, pondérés par leur poids : chaque lot est inscrit comme une caisse de
-- MilitaryDrop.Loot (Loot.CASES[Lots.lootKey(id)]), qui garde la collecte, la
-- mise en cache et le tirage. Un mod de compatibilité peut remplacer ses
-- sources comme celles des caisses de ravitaillement.
--
-- Cas particuliers :
--   * armes à feu : l'arme, puis ses chargeurs et sa boîte (Loot.weaponExtras) ;
--   * eau potable et carburant : récipient qui accepte le fluide (composant
--     FluidContainer), vidé puis rempli à la création par un Fluid du moteur
--     (Fluid.Water, Fluid.Petrol ; FluidContainer.addFluid, 42.21). Un récipient
--     verrouillé (InputLocked, CanEmpty = false) ou à liste blanche qui refuse
--     le fluide est écarté (FluidContainer.canAddFluid) ;
--   * explosifs : désactivables (option RequisitionExplosives) ;
--   * paquetage : catégorie Bag, plus les contenants (Container) portables
--     et solides (voir Lots.isPack et ses seuils).
-- Coût : chaque filtre teste d'abord le script (catégorie, propriétés, tags :
-- Item.hasTag(ItemTag), Item.java:3983, 42.21) et n'instancie un objet
-- (capacité d'un récipient ou d'un sac) qu'en dernier recours. Les candidats
-- des 18 lots sont calculés d'un seul passage sur les tables (Lots.warm),
-- une fois au démarrage du serveur ou de la partie solo
-- (MilitaryDrop_Requisition.lua), sinon au premier formulaire.
-- Le contenu d'une caisse de réquisition est tiré à son ouverture, sur le
-- serveur (MilitaryDrop_Recipe.lua).
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Loot"

local Loot = MilitaryDrop.Loot

MilitaryDrop.Config.addDefaults({ RequisitionExplosives = true })

local Lots = {}
MilitaryDrop.Lots = Lots

-- Objet du mod livré dans le coffre, un par unité commandée.
Lots.CASE_TYPE = "MilitaryDrop.RequisitionCase"
-- ModData de la caisse : identifiant du lot (le dropId : Trust.ITEM_KEY).
Lots.ITEM_KEY = "MilitaryDrop_lot"
Lots.LOOT_PREFIX = "lot:"
-- Rations : aliments qui se gardent au moins ce nombre de jours (les conserves
-- et aliments secs n'ont pas de durée : 1 000 000 000 par défaut, Item.java:111).
Lots.RATION_MIN_DAYS = 60
-- Eau potable : gourdes et bouteilles, pas les verres ni les seaux (litres).
Lots.WATER_MIN_CAPACITY = 0.5
Lots.WATER_MAX_CAPACITY = 2
-- Transmissions : objets portables seulement (les téléviseurs sont dans la catégorie).
Lots.COMMS_MAX_WEIGHT = 5
-- Paquetage : un contenant de catégorie Container n'est retenu que s'il est
-- solide et utile. Relevé vanilla 42.21 (scripts/generated/items) : sacs
-- plastique, poubelle et d'épicerie pèsent 0,1 ; sacs de toile, de linge,
-- fourre-tout 0,5 ; mallettes, valises, caisses de protection, boîtes à
-- outils, étuis d'armes 1 à 3. Capacités : 1 à 4 pour les boîtes à bijoux,
-- trousses, portefeuilles ; 7 à 16 pour les mallettes et caisses de transport.
-- Réduction de poids : 50 pour tous les contenants (0 pour les colis et
-- cadeaux, sans WeightReduction). Le tag base:neverempty marque les
-- contenants que le jeu remplit toujours (glacières garnies, mallette
-- d'argent, sacs-poubelle) : livrés vides, ils trompent.
Lots.PACK_MIN_WEIGHT = 1
Lots.PACK_MIN_CAPACITY = 7
Lots.PACK_MIN_WEIGHT_REDUCTION = 50

-- Récipient de fluide : type complet → acceptation (lue sur un exemplaire).
local fluidCache = {}
-- Contenant portable : type complet → acceptation (lue sur un exemplaire).
local packCache = {}

-- ----------------------------------------------------------------------------
-- Filtres (script d'objet, sans nom)
-- ----------------------------------------------------------------------------

--- Catégorie d'affichage du script (DisplayCategory), ou "".
function Lots.category(script)
    local category = script:getDisplayCategory()
    return type(category) == "string" and category or ""
end

--- Filtre : catégorie d'affichage parmi celles données.
local function inCategories(...)
    local set = {}
    for _, name in ipairs({ ... }) do
        set[name] = true
    end
    return function(script)
        return set[Lots.category(script)] == true
    end
end

local function weightAtMost(script, max)
    return (tonumber(script:getActualWeight()) or 0) <= max
end

--- Fluide d'un lot (registre du moteur), ou nil si le jeu ne le fournit pas.
function Lots.fluidOf(lot)
    if not lot.fluid then
        return nil
    end
    return Fluid and Fluid[lot.fluid] or nil
end

--- Le script porte le tag (ItemTag), lu sans créer d'objet.
local function scriptHasTag(script, tag)
    return tag ~= nil and script:hasTag(tag) == true
end

--- L'objet est un récipient qui, vidé, accepte le fluide et contient
--- capacité min à max litres (bornes facultatives). Lu sur un exemplaire neuf :
--- l'appelant a déjà filtré le script (catégorie, tag).
local function acceptsFluid(fullType, fluidName, minCapacity, maxCapacity)
    local key = fullType .. "|" .. fluidName
    if fluidCache[key] == nil then
        local ok = false
        local fluid = Fluid and Fluid[fluidName]
        local item = fluid and instanceItem(fullType)
        local container = item and item:getFluidContainer()
        if container then
            local capacity = tonumber(container:getCapacity()) or 0
            container:Empty()
            ok = capacity > 0 and (not minCapacity or capacity >= minCapacity)
                and (not maxCapacity or capacity <= maxCapacity) and container:canAddFluid(fluid)
        end
        fluidCache[key] = ok
    end
    return fluidCache[key]
end

function Lots.isRation(script)
    if Lots.category(script) ~= "Food" then
        return false
    end
    return (tonumber(script:getDaysTotallyRotten()) or 0) >= Lots.RATION_MIN_DAYS
end

function Lots.isDrinkingWaterContainer(script)
    local category = Lots.category(script)
    if category ~= "WaterContainer" and category ~= "Water" then
        return false
    end
    return acceptsFluid(script:getFullName(), "Water", Lots.WATER_MIN_CAPACITY, Lots.WATER_MAX_CAPACITY)
end

--- Bidon d'essence : tag base:petrol (ItemTag.PETROL, comme le menu vanilla
--- ISVehiclePartMenu), lu sur le script, puis récipient qui accepte l'essence.
function Lots.isFuelContainer(script)
    if not scriptHasTag(script, ItemTag and ItemTag.PETROL) then
        return false
    end
    return acceptsFluid(script:getFullName(), "Petrol")
end

local isMaintenance = inCategories("VehicleMaintenance")

--- Mécanique : sans les bidons d'essence, livrés pleins par le jeu (lot Carburant).
function Lots.isMechanics(script)
    return isMaintenance(script) and not Lots.isFuelContainer(script)
end

local isTransmission = inCategories("Electronics", "Communications", "LightSource")

function Lots.isTransmission(script)
    return isTransmission(script) and weightAtMost(script, Lots.COMMS_MAX_WEIGHT)
end

--- Arme de mêlée : catégorie Weapon exactement (les objets improvisés sont
--- dans ToolWeapon, HouseholdWeapon…, WeaponCrafted), sans tir, dégâts > 0.
function Lots.isMeleeWeapon(script)
    return Lots.category(script) == "Weapon" and not script:isRanged() and script:getMaxDamage() > 0
end

local isAmmoCategory = inCategories("Ammo")

function Lots.isAmmunition(script)
    return isAmmoCategory(script) or Loot.isAmmo(script)
end

local isProtectiveGear = inCategories("ProtectiveGear")

function Lots.isProtection(script)
    return isProtectiveGear(script) or Loot.isArmor(script)
end

--- Paquetage : tout sac (catégorie Bag) ; un contenant (catégorie Container)
--- seulement s'il est solide (poids propre ≥ PACK_MIN_WEIGHT), sans le tag
--- base:neverempty, et, lu en dernier sur un exemplaire, d'une capacité ≥
--- PACK_MIN_CAPACITY avec une réduction de poids ≥ PACK_MIN_WEIGHT_REDUCTION.
function Lots.isPack(script)
    local category = Lots.category(script)
    if category == "Bag" then
        return true
    end
    if category ~= "Container" or script:getItemType() ~= ItemType.CONTAINER
        or (tonumber(script:getActualWeight()) or 0) < Lots.PACK_MIN_WEIGHT
        or scriptHasTag(script, ItemTag and ItemTag.NEVER_EMPTY) then
        return false
    end
    local fullType = script:getFullName()
    if packCache[fullType] == nil then
        local item = instanceItem(fullType)
        packCache[fullType] = item ~= nil and instanceof(item, "InventoryContainer")
            and (tonumber(item:getCapacity()) or 0) >= Lots.PACK_MIN_CAPACITY
            and (tonumber(item:getWeightReduction()) or 0) >= Lots.PACK_MIN_WEIGHT_REDUCTION
    end
    return packCache[fullType]
end

local isWeaponPartCategory = inCategories("WeaponPart")

function Lots.isAttachment(script)
    return isWeaponPartCategory(script) or Loot.isWeaponPart(script)
end

-- ----------------------------------------------------------------------------
-- Les 18 lots, dans l'ordre d'affichage
-- ----------------------------------------------------------------------------

--- id, groupe (palier), coût (points), count (objets par caisse), filtre ;
--- option : lot désactivable ; fluid : rempli à la création ; extras :
--- chargeurs et munitions de l'arme.
Lots.LIST = {
    { id = "rations", group = 1, cost = 1, count = 4, accept = Lots.isRation },
    { id = "water", group = 1, cost = 1, count = 2, accept = Lots.isDrinkingWaterContainer, fluid = "Water" },
    { id = "medical", group = 1, cost = 2, count = 3, accept = inCategories("FirstAid", "Bandage") },
    { id = "tools", group = 1, cost = 2, count = 2, accept = inCategories("Tool", "ToolWeapon") },
    { id = "materials", group = 1, cost = 1, count = 4, accept = inCategories("Material") },
    { id = "camping", group = 1, cost = 2, count = 3, accept = inCategories("Camping", "FireSource", "Fishing", "Trapping") },
    { id = "ammo", group = 2, cost = 2, count = 3, accept = Lots.isAmmunition },
    { id = "melee", group = 2, cost = 3, count = 1, accept = Lots.isMeleeWeapon },
    { id = "protection", group = 2, cost = 3, count = 2, accept = Lots.isProtection },
    { id = "mechanics", group = 2, cost = 2, count = 2, accept = Lots.isMechanics },
    { id = "comms", group = 2, cost = 2, count = 2, accept = Lots.isTransmission },
    { id = "seeds", group = 2, cost = 1, count = 3, accept = inCategories("Gardening") },
    { id = "books", group = 2, cost = 2, count = 2, accept = inCategories("SkillBook") },
    { id = "packs", group = 2, cost = 2, count = 1, accept = Lots.isPack },
    { id = "firearms", group = 3, cost = 5, count = 1, accept = Loot.isFirearm, extras = true },
    { id = "attachments", group = 3, cost = 3, count = 2, accept = Lots.isAttachment },
    { id = "explosives", group = 3, cost = 5, count = 2, accept = inCategories("Explosives"),
        option = "RequisitionExplosives" },
    { id = "fuel", group = 3, cost = 3, count = 1, accept = Lots.isFuelContainer, fluid = "Petrol" },
}

local byId = {}
for _, lot in ipairs(Lots.LIST) do
    lot.label = "IGUI_MilitaryDrop_Lot_" .. lot.id
    lot.desc = "IGUI_MilitaryDrop_LotDesc_" .. lot.id
    byId[lot.id] = lot
end

--- Lot d'un identifiant (chaîne), ou nil.
function Lots.get(id)
    if type(id) ~= "string" then
        return nil
    end
    return byId[id]
end

--- Clé du lot dans Loot.CASES.
function Lots.lootKey(id)
    return Lots.LOOT_PREFIX .. id
end

--- Inscrit (ou réinscrit) les lots comme caisses de Loot : toutes les tables,
--- filtrées par le lot.
function Lots.register()
    for _, lot in ipairs(Lots.LIST) do
        Loot.CASES[Lots.lootKey(lot.id)] = { picks = lot.count, sources = { { accept = lot.accept } } }
    end
end

--- Calcule d'un seul passage les candidats de tous les lots (gardés en mémoire).
function Lots.warm()
    local keys = {}
    for i, lot in ipairs(Lots.LIST) do
        keys[i] = Lots.lootKey(lot.id)
    end
    MilitaryDrop.Loot.warm(keys)
end

--- Le lot a au moins un candidat dans les tables de butin.
function Lots.hasCandidates(id)
    return #Loot.candidates(Lots.lootKey(id)) > 0
end

--- Le lot est désactivé par son option.
function Lots.isDisabled(lot)
    if lot.option and not MilitaryDrop.Config.get(lot.option) then
        return true
    end
    -- Fluide absent du moteur : le récipient serait livré vide.
    return lot.fluid ~= nil and Lots.fluidOf(lot) == nil
end

--- Prépare un objet tiré : un récipient du lot est vidé puis rempli de son
--- fluide. Renvoie l'objet.
function Lots.prepare(lot, item)
    local fluid = Lots.fluidOf(lot)
    local container = fluid and item and item:getFluidContainer()
    if container then
        container:Empty()
        container:addFluid(fluid, container:getCapacity())
    end
    return item
end

--- Types complets tirés pour une caisse du lot (count tirages pondérés).
function Lots.roll(id, rand)
    if not byId[id] then
        return {}
    end
    return Loot.roll(Lots.lootKey(id), rand)
end

Lots.register()

return Lots
