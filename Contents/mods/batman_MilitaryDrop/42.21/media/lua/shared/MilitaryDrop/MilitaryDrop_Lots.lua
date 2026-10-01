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
--
-- Définitions déclaratives (v1.4) : chaque lot est une table de données
-- (Lots.DEFAULTS : catégories, tags, poids, famille kind, fluide), compilée en
-- filtre (Lots.compile). Le serveur les écrit dans un fichier que l'admin
-- modifie (MilitaryDrop_LotsFile.lua) et remplace Lots.LIST par la liste lue
-- (Lots.setList). Sur un client MP, seule la liste par défaut existe : aucun
-- code client ne s'en sert.
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

-- Récipient de fluide : "type complet|fluide" → { capacity, accepts } (lus sur
-- un exemplaire vidé). Propriétés de l'objet seulement : les bornes de
-- contenance d'un lot (minLiters, maxLiters) sont comparées à chaque appel.
local fluidCache = {}
-- Contenant portable : type complet → acceptation (lue sur un exemplaire).
local packCache = {}

--- Oublie les propriétés lues sur des exemplaires (rechargement du fichier
--- des lots par l'admin : tout est relu au calcul suivant).
function Lots.clearCaches()
    fluidCache = {}
    packCache = {}
end

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

--- Capacité (litres) et acceptation du fluide d'un récipient, lues une fois
--- par type et par fluide sur un exemplaire neuf vidé.
local function fluidInfo(fullType, fluidName)
    local key = fullType .. "|" .. fluidName
    local info = fluidCache[key]
    if info == nil then
        info = { capacity = 0, accepts = false }
        local fluid = Fluid and Fluid[fluidName]
        local item = fluid and instanceItem(fullType)
        local container = item and item:getFluidContainer()
        if container then
            info.capacity = tonumber(container:getCapacity()) or 0
            container:Empty()
            info.accepts = container:canAddFluid(fluid) == true
        end
        fluidCache[key] = info
    end
    return info
end

--- L'objet est un récipient qui, vidé, accepte le fluide et contient
--- capacité min à max litres (bornes facultatives, celles du lot appelant).
--- L'appelant a déjà filtré le script (catégorie, tag).
local function acceptsFluid(fullType, fluidName, minCapacity, maxCapacity)
    local info = fluidInfo(fullType, fluidName)
    local capacity = info.capacity
    return info.accepts and capacity > 0 and (not minCapacity or capacity >= minCapacity)
        and (not maxCapacity or capacity <= maxCapacity)
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
-- Filtres déclaratifs (définitions de lots, fichier de l'admin)
-- ----------------------------------------------------------------------------

--- Familles d'objets reconnues par le mod (champ kind d'une définition) :
--- chacune renvoie à un filtre Lua ci-dessus, lu à l'appel (remplaçable).
Lots.KINDS = {
    ration = function(script) return Lots.isRation(script) end,
    firearm = function(script) return Loot.isFirearm(script) end,
    melee = function(script) return Lots.isMeleeWeapon(script) end,
    ammo = function(script) return Lots.isAmmunition(script) end,
    armor = function(script) return Lots.isProtection(script) end,
    attachment = function(script) return Lots.isAttachment(script) end,
    pack = function(script) return Lots.isPack(script) end,
}
Lots.KIND_NAMES = { "ration", "firearm", "melee", "ammo", "armor", "attachment", "pack" }

-- Champs de filtre d'une définition : s'il en donne un, le fichier remplace
-- tout le filtre du lot par défaut de même identifiant.
Lots.FILTER_FIELDS = { "categories", "tags", "notTags", "minWeight", "maxWeight", "kind", "fluid",
    "minLiters", "maxLiters", "items" }

-- Option sandbox qui désactive un lot : par identifiant, et pour tout lot qui
-- vise la catégorie Explosives.
Lots.OPTIONS = { explosives = "RequisitionExplosives" }
Lots.CATEGORY_OPTIONS = { Explosives = "RequisitionExplosives" }

--- Tag du jeu d'un identifiant « espace:nom » (ItemTag.get, registre du moteur,
--- comme ISMapSymbolDialog.lua:45), ou nil s'il est inconnu.
function Lots.resolveTag(name)
    if type(name) ~= "string" or name == "" or not (ItemTag and ItemTag.get and ResourceLocation) then
        return nil
    end
    -- ResourceLocation.of lève une exception Java sur un identifiant mal
    -- formé : pcall seulement contre cette donnée de l'admin.
    local ok, tag = pcall(function() return ItemTag.get(ResourceLocation.of(name)) end)
    return ok and tag or nil
end

local function toSet(values)
    if not values then
        return nil
    end
    local set = {}
    for _, value in ipairs(values) do
        set[value] = true
    end
    return set
end

--- Filtre (script → booléen) d'une définition déclarative. Chaque champ
--- présent restreint le lot (ET) ; une liste vaut « l'un d'eux » (OU) :
--- categories (DisplayCategory), kind (Lots.KINDS), tags (au moins un),
--- notTags (aucun), minWeight/maxWeight (poids du script), fluid (récipient
--- qui, vidé, accepte ce fluide, entre minLiters et maxLiters litres). Les
--- tags sont résolus au premier appel (registre rempli par les scripts).
--- Ordre : script d'abord, objet créé (récipient) en dernier.
function Lots.buildFilter(def)
    local categories = toSet(def.categories)
    local kind = def.kind and Lots.KINDS[def.kind] or nil
    local tags, notTags = nil, nil
    local function resolveAll(names)
        local resolved = {}
        for _, name in ipairs(names) do
            local tag = Lots.resolveTag(name)
            if tag then
                resolved[#resolved + 1] = tag
            else
                MilitaryDrop.log("lot " .. tostring(def.id) .. ": unknown item tag " .. tostring(name), true)
            end
        end
        return resolved
    end
    return function(script)
        if categories and not categories[Lots.category(script)] then
            return false
        end
        if def.minWeight or def.maxWeight then
            local weight = tonumber(script:getActualWeight()) or 0
            if (def.minWeight and weight < def.minWeight) or (def.maxWeight and weight > def.maxWeight) then
                return false
            end
        end
        if def.tags then
            tags = tags or resolveAll(def.tags)
            local any = false
            for _, tag in ipairs(tags) do
                if scriptHasTag(script, tag) then
                    any = true
                    break
                end
            end
            if not any then
                return false
            end
        end
        if def.notTags then
            notTags = notTags or resolveAll(def.notTags)
            for _, tag in ipairs(notTags) do
                if scriptHasTag(script, tag) then
                    return false
                end
            end
        end
        if def.kind and not (kind and kind(script)) then
            return false
        end
        if def.fluid then
            return acceptsFluid(script:getFullName(), def.fluid, def.minLiters, def.maxLiters)
        end
        return true
    end
end

-- ----------------------------------------------------------------------------
-- Les 18 lots par défaut, dans l'ordre d'affichage
-- ----------------------------------------------------------------------------

--- Définitions déclaratives (données seules, aucun nom d'objet) : id, groupe
--- (palier), coût (points), count (objets par caisse), filtre (champs
--- ci-dessus), extras (chargeurs et munitions d'une arme). Le serveur écrit
--- ces définitions dans le fichier de l'admin (MilitaryDrop_LotsFile.lua).
Lots.DEFAULTS = {
    { id = "rations", group = 1, cost = 1, count = 4, kind = "ration" },
    { id = "water", group = 1, cost = 1, count = 2, categories = { "WaterContainer", "Water" }, fluid = "Water",
        minLiters = Lots.WATER_MIN_CAPACITY, maxLiters = Lots.WATER_MAX_CAPACITY },
    { id = "medical", group = 1, cost = 2, count = 3, categories = { "FirstAid", "Bandage" } },
    { id = "tools", group = 1, cost = 2, count = 2, categories = { "Tool", "ToolWeapon" } },
    { id = "materials", group = 1, cost = 1, count = 4, categories = { "Material" } },
    { id = "camping", group = 1, cost = 2, count = 3, categories = { "Camping", "FireSource", "Fishing", "Trapping" } },
    { id = "ammo", group = 2, cost = 2, count = 3, kind = "ammo" },
    { id = "melee", group = 2, cost = 3, count = 1, kind = "melee" },
    { id = "protection", group = 2, cost = 3, count = 2, kind = "armor" },
    -- Sans les bidons d'essence (tag base:petrol), livrés par le lot Carburant.
    { id = "mechanics", group = 2, cost = 2, count = 2, categories = { "VehicleMaintenance" },
        notTags = { "base:petrol" } },
    -- Objets portables seulement (les téléviseurs sont dans ces catégories).
    { id = "comms", group = 2, cost = 2, count = 2, categories = { "Electronics", "Communications", "LightSource" },
        maxWeight = Lots.COMMS_MAX_WEIGHT },
    { id = "seeds", group = 2, cost = 1, count = 3, categories = { "Gardening" } },
    { id = "books", group = 2, cost = 2, count = 2, categories = { "SkillBook" } },
    { id = "packs", group = 2, cost = 2, count = 1, kind = "pack" },
    { id = "firearms", group = 3, cost = 5, count = 1, kind = "firearm", extras = true },
    { id = "attachments", group = 3, cost = 3, count = 2, kind = "attachment" },
    { id = "explosives", group = 3, cost = 5, count = 2, categories = { "Explosives" } },
    -- Bidon (tag base:petrol, comme ISVehiclePartMenu.lua) qui accepte l'essence.
    { id = "fuel", group = 3, cost = 3, count = 1, tags = { "base:petrol" }, fluid = "Petrol" },
}

--- Définition par défaut d'un identifiant, ou nil.
function Lots.defaultOf(id)
    for _, def in ipairs(Lots.DEFAULTS) do
        if def.id == id then
            return def
        end
    end
    return nil
end

--- Lot utilisable d'une définition (déjà validée) : filtre compilé, option
--- sandbox, textes. Un lot par défaut garde ses clés de traduction ; un lot
--- ajouté par l'admin porte ses textes (texts = { EN = { label, desc }, … }).
--- items (option d'admin) : liste fermée de types complets, tirés à poids
--- égaux, hors des tables de butin.
function Lots.compile(def)
    local lot = {
        id = def.id, group = def.group, cost = def.cost, count = def.count,
        enabled = def.enabled ~= false, extras = def.extras == true,
        fluid = def.fluid, texts = def.texts, items = def.items, def = def,
    }
    if not def.items then
        lot.accept = Lots.buildFilter(def)
    end
    lot.option = Lots.OPTIONS[def.id]
    for _, category in ipairs(def.categories or {}) do
        lot.option = lot.option or Lots.CATEGORY_OPTIONS[category]
    end
    if Lots.defaultOf(def.id) then
        lot.label = "IGUI_MilitaryDrop_Lot_" .. def.id
        lot.desc = "IGUI_MilitaryDrop_LotDesc_" .. def.id
    end
    return lot
end

local byId = {}

--- Remplace la liste des lots (ordre d'affichage) et les réinscrit dans Loot.
function Lots.setList(list)
    Lots.LIST = list
    byId = {}
    for _, lot in ipairs(list) do
        byId[lot.id] = lot
    end
    Lots.register()
end

--- Lots compilés des définitions par défaut.
function Lots.defaultList()
    local list = {}
    for i, def in ipairs(Lots.DEFAULTS) do
        list[i] = Lots.compile(def)
    end
    return list
end

--- Chargeur de la liste du serveur (MilitaryDrop_LotsFile.lua), appelé avant
--- le premier usage ; nil sur un client MP.
Lots.loader = nil

function Lots.ensureLoaded()
    if Lots.loader then
        Lots.loader()
    end
end

--- Lot d'un identifiant (chaîne), ou nil.
function Lots.get(id)
    if type(id) ~= "string" then
        return nil
    end
    Lots.ensureLoaded()
    return byId[id]
end

--- Texte d'un lot ajouté (field = "label" ou "desc") dans la langue donnée,
--- sinon en anglais, sinon dans la première langue fournie (ordre
--- alphabétique) ; l'identifiant à défaut de libellé.
function Lots.text(lot, field, language)
    local texts = type(lot.texts) == "table" and lot.texts or {}
    local chosen = texts[language] or texts.EN
    if not chosen then
        local languages = {}
        for name in pairs(texts) do
            languages[#languages + 1] = name
        end
        table.sort(languages)
        chosen = languages[1] and texts[languages[1]]
    end
    local value = chosen and chosen[field]
    if type(value) == "string" and value ~= "" then
        return value
    end
    return field == "label" and lot.id or ""
end

--- Clé du lot dans Loot.CASES.
function Lots.lootKey(id)
    return Lots.LOOT_PREFIX .. id
end

--- Inscrit (ou réinscrit) les lots comme caisses de Loot : toutes les tables,
--- filtrées par le lot. Les inscriptions d'anciens lots sont retirées et leurs
--- seules listes calculées oubliées (filtres changés par un rechargement).
function Lots.register()
    local stale = {}
    for key in pairs(Loot.CASES) do
        if type(key) == "string" and key:sub(1, #Lots.LOOT_PREFIX) == Lots.LOOT_PREFIX then
            stale[#stale + 1] = key
        end
    end
    for _, key in ipairs(stale) do
        Loot.CASES[key] = nil
    end
    for _, lot in ipairs(Lots.LIST) do
        if lot.accept then
            Loot.CASES[Lots.lootKey(lot.id)] = { picks = lot.count, sources = { { accept = lot.accept } } }
        end
    end
    -- Seulement les listes des lots : celles des caisses de ravitaillement restent.
    Loot.clearCache(Lots.LOOT_PREFIX)
end

--- Calcule d'un seul passage les candidats de tous les lots (gardés en mémoire).
function Lots.warm()
    Lots.ensureLoaded()
    local keys = {}
    for _, lot in ipairs(Lots.LIST) do
        if lot.accept then
            keys[#keys + 1] = Lots.lootKey(lot.id)
        end
    end
    MilitaryDrop.Loot.warm(keys)
end

--- Candidats d'une liste fermée (option items) : types connus du jeu, poids 1.
local function listedCandidates(lot)
    if not lot.listed then
        lot.listed = {}
        for _, name in ipairs(lot.items) do
            local script = Loot.resolve(name)
            if script then
                lot.listed[#lot.listed + 1] = { name = name, fullType = script:getFullName(), weight = 1 }
            else
                MilitaryDrop.log("lot " .. lot.id .. ": unknown item " .. tostring(name), true)
            end
        end
    end
    return lot.listed
end

--- Candidats d'un lot : { { fullType, weight }, … }.
function Lots.candidates(id)
    local lot = Lots.get(id)
    if not lot then
        return {}
    end
    if lot.items then
        return listedCandidates(lot)
    end
    return Loot.candidates(Lots.lootKey(id))
end

--- Le lot a au moins un candidat dans les tables de butin (ou dans sa liste).
function Lots.hasCandidates(id)
    return #Lots.candidates(id) > 0
end

--- Le lot est désactivé : par le fichier (enabled = false), par son option.
function Lots.isDisabled(lot)
    if lot.enabled == false then
        return true
    end
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

local function gameRand(total)
    return ZombRandFloat(0, total)
end

--- Types complets tirés pour une caisse du lot (count tirages pondérés).
function Lots.roll(id, rand)
    local lot = Lots.get(id)
    if not lot then
        return {}
    end
    if not lot.items then
        return Loot.roll(Lots.lootKey(id), rand)
    end
    local entries, results = listedCandidates(lot), {}
    if #entries == 0 then
        MilitaryDrop.log("no valid loot for lot " .. lot.id, true)
        return results
    end
    for _ = 1, lot.count do
        local entry = Loot.pickWeighted(entries, rand or gameRand)
        if entry then
            results[#results + 1] = entry.fullType
        end
    end
    return results
end

Lots.setList(Lots.defaultList())

return Lots
