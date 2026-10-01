-- MilitaryDrop_LotsFile : fichier des lots de réquisition de l'admin (v1.4,
-- REQ-09) — création du fichier par défaut, lecture sans exécution de code,
-- lot modifié, désactivé, ajouté, filtres déclaratifs équivalents aux filtres
-- Lua d'avant, repli lot par lot et journal, textes envoyés dans « form »,
-- caisse d'un lot ajouté, rechargement par un admin.

local T = {}

local PATH = "MilitaryDrop/requisition.txt"

--- Scripts simulés (comme test_lots.lua) : type complet → propriétés.
local ITEMS = {
    ["Base.TinnedBeans"] = { cat = "Food", rotten = 1000000000 },
    ["Base.Bread"] = { cat = "Food", rotten = 6 },
    ["Base.WaterBottle"] = { cat = "Water", fluid = { capacity = 1 } },
    ["Base.BucketEmpty"] = { cat = "WaterContainer", fluid = { capacity = 10 } },
    ["Base.LockedFlask"] = { cat = "WaterContainer", fluid = { capacity = 1, locked = true } },
    ["Base.Bandage"] = { cat = "Bandage" },
    ["Base.Hammer"] = { cat = "Tool", weight = 1 },
    ["Base.Sledgehammer"] = { cat = "Tool", weight = 6 },
    ["Base.Plank"] = { cat = "Material" },
    ["Base.Matches"] = { cat = "FireSource" },
    ["Base.Pot"] = { cat = "Cooking", weight = 1 },
    ["Base.Pistol"] = { cat = "Weapon", itemType = "Weapon", ranged = true, damage = 1,
        magazine = "Base.9mmClip", ammoBox = "Base.Bullets9mmBox" },
    ["Base.Revolver_CapGun"] = { cat = "Memento", itemType = "Weapon", ranged = true, damage = 0 },
    ["Base.9mmClip"] = { cat = "Ammo" },
    ["Base.Bullets9mmBox"] = { cat = "Ammo" },
    ["Base.Machete"] = { cat = "Weapon", itemType = "Weapon", damage = 2 },
    ["Base.Pan"] = { cat = "CookingWeapon", itemType = "Weapon", damage = 1 },
    ["Base.Vest_BulletArmy"] = { cat = "Clothing", itemType = "Clothing", bulletDefense = 50 },
    ["Base.Hat_Helmet"] = { cat = "ProtectiveGear", itemType = "Clothing", bulletDefense = 0 },
    ["Base.Tshirt"] = { cat = "Clothing", itemType = "Clothing", bulletDefense = 0 },
    ["Base.PetrolCan"] = { cat = "VehicleMaintenance", tags = { Petrol = true }, fluid = { capacity = 10 } },
    ["Base.CarBattery"] = { cat = "VehicleMaintenance" },
    ["Base.WalkieTalkie"] = { cat = "Communications", weight = 1 },
    ["Base.TvBlack"] = { cat = "Communications", weight = 20 },
    ["Base.Seeds"] = { cat = "Gardening" },
    ["Base.BookAiming1"] = { cat = "SkillBook" },
    ["Base.Bag_ALICE"] = { cat = "Bag", itemType = "Container" },
    ["Base.Bag_ProtectiveCaseBulky"] = { cat = "Container", itemType = "Container", weight = 1, capacity = 16,
        reduction = 50 },
    ["Base.Plasticbag"] = { cat = "Container", itemType = "Container", weight = 0.1, capacity = 8, reduction = 50 },
    ["Base.Cooler_Beer"] = { cat = "Container", itemType = "Container", weight = 1.5, capacity = 12,
        reduction = 50, tags = { NeverEmpty = true } },
    ["Base.RedDot"] = { cat = "WeaponPart", itemType = "WeaponPart" },
    ["Base.PipeBomb"] = { cat = "Explosives" },
}

local function list(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end

local function makeScript(fullType)
    local data = ITEMS[fullType]
    return {
        getItemType = function() return data.itemType or "Normal" end,
        getFullName = function() return fullType end,
        isRanged = function() return data.ranged == true end,
        getMaxDamage = function() return data.damage or 0 end,
        getDisplayCategory = function() return data.cat end,
        getActualWeight = function() return data.weight or 0.5 end,
        getDaysTotallyRotten = function() return data.rotten or 1000000000 end,
        hasTag = function(_, tag) return data.tags ~= nil and data.tags[tag] == true end,
    }
end

local function makeFluidContainer(spec)
    local fc = { capacity = spec.capacity, fluids = {} }
    function fc.getCapacity(self) return self.capacity end
    function fc.Empty(self) self.fluids = {} end
    function fc.canAddFluid() return not spec.locked end
    function fc.addFluid(self, fluid, amount)
        self.fluids[fluid] = (self.fluids[fluid] or 0) + amount
    end
    return fc
end

--- Lecteur ligne à ligne (BufferedReader.readLine : nil à la fin).
local function makeReader(text)
    local lines = {}
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    local index = 0
    return {
        readLine = function() index = index + 1 return lines[index] end,
        close = function() end,
    }
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return false end
    ItemType = { CONTAINER = "Container", WEAPON = "Weapon", WEAPON_PART = "WeaponPart", CLOTHING = "Clothing" }
    Fluid = { Water = "Water", Petrol = "Petrol" }
    ItemTag = { PETROL = "Petrol", NEVER_EMPTY = "NeverEmpty" }
    -- Registre des tags (ItemTag.get(ResourceLocation.of("base:x")), ItemTag.java:478).
    ResourceLocation = { of = function(id)
        return string.find(id, ":", 1, true) and string.lower(id) or ("base:" .. string.lower(id))
    end }
    ItemTag.get = function(location)
        return ({ ["base:petrol"] = "Petrol", ["base:neverempty"] = "NeverEmpty" })[location]
    end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    instanceItem = function(fullType)
        local data = ITEMS[fullType]
        if not data then
            return nil
        end
        local item = { fullType = fullType, kind = "InventoryItem" }
        if data.itemType == "Container" then
            item.kind = "InventoryContainer"
            item.getCapacity = function() return data.capacity or 0 end
            item.getWeightReduction = function() return data.reduction or 0 end
        elseif data.itemType == "Weapon" then
            item.kind = "HandWeapon"
            item.getMagazineType = function() return data.magazine end
            item.getAmmoBox = function() return data.ammoBox end
        elseif data.itemType == "Clothing" then
            item.kind = "Clothing"
            item.getBulletDefense = function() return data.bulletDefense end
        end
        local container = data.fluid and makeFluidContainer(data.fluid) or nil
        item.getFluidContainer = function() return container end
        return item
    end
    getScriptManager = function()
        return {
            FindItem = function(_, name)
                local fullType = string.find(name, ".", 1, true) and name or ("Base." .. name)
                return ITEMS[fullType] and makeScript(fullType) or nil
            end,
            getItemsByType = function() return list({}) end,
            getAllItems = function()
                local all = {}
                for fullType in pairs(ITEMS) do
                    all[#all + 1] = makeScript(fullType)
                end
                return list(all)
            end,
        }
    end
    local flat = {}
    for fullType in pairs(ITEMS) do
        flat[#flat + 1] = fullType:match("%.(.+)$")
        flat[#flat + 1] = 2
    end
    ProceduralDistributions = { list = { Everything = { items = flat } } }
    -- Fichiers de Zomboid/Lua simulés.
    FILES, WRITES = {}, 0
    getFileReader = function(name)
        return FILES[name] and makeReader(FILES[name]) or nil
    end
    getFileWriter = function(name)
        WRITES = WRITES + 1
        return { write = function(_, text) FILES[name] = text end, close = function() end }
    end
    -- Journal du mod capturé.
    LOGS = {}
    print = function(text) LOGS[#LOGS + 1] = tostring(text) end
    getText = function(key, a) return a and (key .. "(" .. tostring(a) .. ")") or key end
    getTimestampMs = function() return 0 end
    ZombRandFloat = function(low) return low end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Lots.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_LotsFile.lua")
    Lots = MilitaryDrop.Lots
    LotsFile = MilitaryDrop.LotsFile
end

local function logged(fragment)
    for _, line in ipairs(LOGS) do
        if line:find(fragment, 1, true) then
            return true
        end
    end
    return false
end

local function candidates(id)
    local result = {}
    for _, entry in ipairs(Lots.candidates(id)) do
        result[#result + 1] = entry.fullType
    end
    table.sort(result)
    return table.concat(result, ",")
end

local function ids()
    local result = {}
    for i, lot in ipairs(Lots.LIST) do
        result[i] = lot.id
    end
    return table.concat(result, ",")
end

local DEFAULT_IDS = "rations,water,medical,tools,materials,camping,ammo,melee,protection,mechanics,comms,"
    .. "seeds,books,packs,firearms,attachments,explosives,fuel"

--- Fichier de l'admin : lots donnés (texte Lua de données).
local function useFile(lotsText)
    FILES[PATH] = "-- admin file\nreturn {\n    version = 1,\n    lots = {\n" .. lotsText .. "\n    },\n}\n"
    LotsFile.reset()
end

-- ----------------------------------------------------------------------------
-- Fichier par défaut
-- ----------------------------------------------------------------------------

function T.default_file_is_created_with_the_18_lots_and_a_notice()
    assertEq(FILES[PATH], nil, "pas de fichier au départ")
    assertEq(Lots.get("rations").id, "rations", "premier usage : chargement")
    local text = FILES[PATH]
    assertTrue(text ~= nil, "fichier créé dans Zomboid/Lua/" .. PATH)
    assertEq(LotsFile.lastReport().source, "created", "créé")
    assertEq(ids(), DEFAULT_IDS, "18 lots par défaut, dans l'ordre")
    local count = 0
    for _ in text:gmatch('\n            id = "') do
        count = count + 1
    end
    assertEq(count, 18, "18 lots écrits (l'exemple de la notice est commenté)")
    assertTrue(text:find("[EN]", 1, true) and text:find("[FR]", 1, true), "notice en anglais et en français")
    assertTrue(text:find("Base.", 1, true) == nil, "aucun nom d'objet dans le fichier par défaut")
    assertTrue(text:find("ReloadLots", 1, true) ~= nil, "commande de rechargement documentée")
    -- Le fichier relu donne exactement les définitions par défaut.
    local data = LotsFile.parse(text)
    assertEq(#data.lots, 18, "18 entrées lues")
    for i, def in ipairs(Lots.DEFAULTS) do
        local read = data.lots[i]
        assertEq(read.id, def.id, "ordre")
        assertEq(read.enabled, true, "enabled écrit")
        for _, field in ipairs({ "group", "cost", "count", "kind", "fluid", "minLiters", "maxLiters", "maxWeight" }) do
            assertEq(read[field], def[field], def.id .. "." .. field)
        end
        assertEq(table.concat(read.categories or {}, ","), table.concat(def.categories or {}, ","), "catégories")
        assertEq(read.extras == true, def.extras == true, "extras")
    end
end

function T.default_file_is_not_rewritten_and_reads_without_problem()
    LotsFile.ensureLoaded()
    local writes = WRITES
    local report = LotsFile.reload()
    assertEq(report.source, "file", "relu")
    assertEq(#report.problems, 0, "aucun problème")
    assertEq(WRITES, writes, "fichier de l'admin jamais réécrit")
    assertEq(ids(), DEFAULT_IDS, "mêmes lots")
end

function T.declarative_filters_match_the_former_lua_filters()
    LotsFile.ensureLoaded()
    LotsFile.reload()
    local function inCategories(...)
        local set = {}
        for _, name in ipairs({ ... }) do
            set[name] = true
        end
        return function(script) return set[Lots.category(script)] == true end
    end
    -- Filtres Lua des 18 lots avant le fichier (v1.4 d'origine).
    local former = {
        rations = Lots.isRation, water = Lots.isDrinkingWaterContainer,
        medical = inCategories("FirstAid", "Bandage"), tools = inCategories("Tool", "ToolWeapon"),
        materials = inCategories("Material"), camping = inCategories("Camping", "FireSource", "Fishing", "Trapping"),
        ammo = Lots.isAmmunition, melee = Lots.isMeleeWeapon, protection = Lots.isProtection,
        mechanics = Lots.isMechanics, comms = Lots.isTransmission, seeds = inCategories("Gardening"),
        books = inCategories("SkillBook"), packs = Lots.isPack, firearms = MilitaryDrop.Loot.isFirearm,
        attachments = Lots.isAttachment, explosives = inCategories("Explosives"), fuel = Lots.isFuelContainer,
    }
    for _, lot in ipairs(Lots.LIST) do
        for fullType in pairs(ITEMS) do
            local script = makeScript(fullType)
            assertEq(lot.accept(script) == true, former[lot.id](script) == true, lot.id .. " / " .. fullType)
        end
    end
    assertEq(candidates("fuel"), "Base.PetrolCan", "bidon")
    assertEq(candidates("mechanics"), "Base.CarBattery", "mécanique sans bidon")
    assertEq(candidates("comms"), "Base.WalkieTalkie", "portable seulement")
    assertEq(Lots.get("firearms").extras, true, "chargeurs et boîte")
    assertEq(Lots.get("explosives").option, "RequisitionExplosives", "option sandbox gardée")
end

-- ----------------------------------------------------------------------------
-- Lot modifié, désactivé, ajouté
-- ----------------------------------------------------------------------------

local KITCHEN = [[
        { id = "kitchen", enabled = true, group = 1, cost = 2, count = 3,
          categories = { "Cooking", "Tool" }, maxWeight = 3,
          texts = { EN = { label = "Kitchen", desc = "Pots and tools." },
                    FR = { label = "Cuisine", desc = "Casseroles et outils." } } },
]]

function T.modified_disabled_and_added_lots()
    useFile([[
        { id = "rations", cost = 3, count = 6 },
        { id = "tools", group = 2, categories = { "Tool" }, minWeight = 5 },
        { id = "explosives", enabled = false },
]] .. KITCHEN)
    LotsFile.ensureLoaded()
    local report = LotsFile.lastReport()
    assertEq(report.source, "file", "fichier lu")
    assertEq(ids(), "rations,tools,explosives,kitchen,water,medical,materials,camping,ammo,melee,protection,"
        .. "mechanics,comms,seeds,books,packs,firearms,attachments,fuel", "ordre du fichier, défauts absents à la fin")
    assertEq(#report.problems, 15, "chaque lot par défaut absent est signalé")
    assertTrue(logged("default lot water missing from the file: kept"), "journal")
    local rations = Lots.get("rations")
    assertEq(rations.cost .. "/" .. rations.count .. "/" .. rations.group, "3/6/1", "coût et nombre modifiés, palier gardé")
    assertEq(candidates("rations"), "Base.TinnedBeans", "filtre par défaut gardé")
    assertEq(rations.label, "IGUI_MilitaryDrop_Lot_rations", "clé de traduction gardée")
    assertEq(candidates("tools"), "Base.Sledgehammer", "filtre remplacé (catégorie Tool, 5 kg et plus)")
    assertEq(Lots.get("tools").group, 2, "palier modifié")
    assertTrue(Lots.isDisabled(Lots.get("explosives")), "désactivé par le fichier")
    assertTrue(not Lots.isDisabled(Lots.get("rations")), "rations actives")
    local kitchen = Lots.get("kitchen")
    assertEq(kitchen.label, nil, "lot ajouté : pas de clé de traduction")
    assertEq(kitchen.texts.FR.label, "Cuisine", "textes du lot")
    assertEq(candidates("kitchen"), "Base.Hammer,Base.Pot", "Cooking ou Tool, 3 kg au plus")
    assertEq(Lots.text(kitchen, "label", "FR"), "Cuisine", "texte français")
    assertEq(Lots.text(kitchen, "label", "DE"), "Kitchen", "repli anglais")
    assertEq(Lots.text(kitchen, "desc", "EN"), "Pots and tools.", "description")
    assertEq(#Lots.roll("kitchen", function() return 0 end), 3, "count tirages")
end

function T.tags_and_not_tags_select_by_item_tag()
    useFile([[
        { id = "cans", group = 1, cost = 1, count = 1, tags = { "base:petrol" }, texts = { EN = { label = "Cans" } } },
        { id = "maint", group = 1, cost = 1, count = 1, categories = { "VehicleMaintenance" },
          notTags = { "base:petrol", "base:unknowntag" }, texts = { EN = { label = "Maint" } } },
]])
    LotsFile.ensureLoaded()
    assertEq(candidates("cans"), "Base.PetrolCan", "tag")
    assertEq(candidates("maint"), "Base.CarBattery", "sans le tag")
    assertTrue(logged("unknown item tag base:unknowntag"), "tag inconnu signalé")
end

function T.items_option_draws_only_the_listed_items()
    useFile([[
        { id = "admin", group = 1, cost = 1, count = 2, items = { "Base.Hammer", "Base.Nothing" },
          texts = { EN = { label = "Admin kit" } } },
]])
    LotsFile.ensureLoaded()
    assertEq(candidates("admin"), "Base.Hammer", "liste fermée, objets connus seulement")
    assertTrue(logged("unknown item Base.Nothing"), "objet inconnu signalé")
    local rolled = Lots.roll("admin", function() return 0 end)
    assertEq(table.concat(rolled, ","), "Base.Hammer,Base.Hammer", "count tirages dans la liste")
    useFile([[
        { id = "admin", group = 1, cost = 1, count = 2, items = { "Base.Hammer" }, categories = { "Tool" },
          texts = { EN = { label = "Admin kit" } } },
]])
    LotsFile.ensureLoaded()
    assertEq(Lots.get("admin"), nil, "items et un autre filtre : lot écarté")
    assertTrue(logged("items replaces the filter"), "motif au journal")
end

-- ----------------------------------------------------------------------------
-- Erreurs : repli et journal
-- ----------------------------------------------------------------------------

function T.syntax_error_keeps_all_default_lots_and_logs()
    FILES[PATH] = "return {\n    lots = {\n        { id = \"rations\", cost = 3 \n    },\n}\n"
    LotsFile.reset()
    LotsFile.ensureLoaded()
    assertEq(LotsFile.lastReport().source, "defaults", "défauts")
    assertEq(ids(), DEFAULT_IDS, "18 lots par défaut")
    assertEq(Lots.get("rations").cost, 1, "rien du fichier")
    assertTrue(logged("syntax error, line 6: '}' expected"), "erreur et ligne au journal")
    assertTrue(FILES[PATH]:find("cost = 3", 1, true) ~= nil, "fichier de l'admin intact")
end

function T.invalid_lots_fall_back_one_by_one()
    useFile([[
        { id = "rations", cost = 0 },
        { id = "water", colour = "blue" },
        { id = "medical", group = 4 },
        { id = "tools", kind = "spaceship" },
        { id = "seeds", cost = 2.5 },
        { id = "camping", categories = {} },
        { id = "rations", cost = 4 },
        { id = "new1", group = 1, cost = 1, count = 1, categories = { "Tool" } },
        { id = "new2", group = 1, cost = 1, count = 1, texts = { EN = { label = "No filter" } } },
        { id = "bad id", group = 1, cost = 1, count = 1, categories = { "Tool" }, texts = { EN = { label = "X" } } },
        "rations",
        { id = "books", cost = 4 },
]])
    LotsFile.ensureLoaded()
    assertEq(Lots.get("rations").cost, 1, "coût 0 : lot par défaut")
    assertEq(Lots.get("water").fluid, "Water", "champ inconnu : lot par défaut")
    assertEq(Lots.get("medical").group, 1, "palier 4 : lot par défaut")
    assertEq(candidates("tools"), "Base.Hammer,Base.Sledgehammer", "famille inconnue : filtre par défaut")
    assertEq(Lots.get("seeds").cost, 1, "coût non entier : défaut")
    assertEq(Lots.get("books").cost, 4, "lot valide après les erreurs")
    assertEq(Lots.get("new1"), nil, "lot ajouté sans textes : écarté")
    assertEq(Lots.get("new2"), nil, "lot ajouté sans filtre : écarté")
    assertEq(#Lots.LIST, 18, "seulement les 18 lots")
    assertTrue(logged("lot #1 (rations): cost must be a whole number from 1 to 99; default lot kept"), "motif")
    assertTrue(logged("lot #2 (water): unknown field colour"), "champ inconnu")
    assertTrue(logged("lot #4 (tools): kind must be one of"), "famille")
    assertTrue(logged("lot #6 (camping): categories must be a non-empty list"), "liste vide")
    assertTrue(logged("lot #7 (rations): duplicate id; lot ignored"), "doublon")
    assertTrue(logged("lot #8 (new1): texts is missing"), "textes manquants")
    assertTrue(logged("lot #10 (bad id): id must be a name"), "identifiant invalide")
    assertTrue(logged("lot #11: a lot must be a table"), "entrée non table")
end

function T.no_code_is_ever_executed()
    local attempts = {
        "EXECUTED = true return { lots = {} }",
        "return { lots = { { id = (function() EXECUTED = true return 'x' end)() } } }",
        "return { lots = { { id = os.exit() } } }",
        "return { lots = {} } EXECUTED = true",
        "while true do end",
        "return { lots = { { id = \"a\" .. \"b\" } } }",
        "return { lots = { { cost = 1 + 1 } } }",
        "return { lots = {}, x = setmetatable({}, {}) }",
        "return { lots = {} }, { }",
    }
    for i, text in ipairs(attempts) do
        local data, err = LotsFile.parse(text)
        assertEq(data, nil, "refusé : " .. text)
        assertTrue(type(err) == "string" and err:find("line 1", 1, true) ~= nil, "erreur située #" .. i)
    end
    assertEq(EXECUTED, nil, "rien exécuté")
    FILES[PATH] = attempts[1]
    LotsFile.reset()
    LotsFile.ensureLoaded()
    assertEq(EXECUTED, nil, "fichier refusé sans exécution")
    assertEq(#Lots.LIST, 18, "repli sur les défauts")
end

function T.parser_reads_lua_data_syntax()
    local data, err = LotsFile.parse("\239\187\191-- c\n--[[ bloc\n ]] { a = 1, ['b'] = 'x\\\"y\\n', [3] = -2.5e1;"
        .. " c = { true, false, nil, [==[long]==] }, d = .5, }")
    assertEq(err, nil, "pas d'erreur")
    assertEq(data.a, 1, "nombre")
    assertEq(data.b, "x\"y\n", "échappements")
    assertEq(data[3], -25, "clé numérique, exposant négatif")
    assertEq(data.c[1], true, "booléen")
    assertEq(data.c[2], false, "faux")
    assertEq(data.c[4], "long", "chaîne longue, nil compté")
    assertEq(data.d, 0.5, "décimal")
    local _, depthError = LotsFile.parse("{{{{{{{{}}}}}}}}")
    assertTrue(depthError:find("too deep", 1, true) ~= nil, "profondeur bornée")
end

function T.too_long_file_keeps_defaults_without_rewriting()
    FILES[PATH] = string.rep("-- x\n", LotsFile.MAX_LINES + 10) .. "return { lots = {} }"
    LotsFile.reset()
    LotsFile.ensureLoaded()
    assertEq(LotsFile.lastReport().source, "defaults", "défauts")
    assertEq(WRITES, 0, "fichier non réécrit")
    assertTrue(logged("file too long"), "journal")
end

function T.texts_are_cleaned_and_bounded()
    useFile([[
        { id = "x", group = 1, cost = 1, count = 1, categories = { "Tool" },
          texts = { EN = { label = "  <RGB:1,0,0>Big\tlabel  ", desc = "]] .. string.rep("d", 300) .. [[" } } },
]])
    LotsFile.ensureLoaded()
    local x = Lots.get("x")
    assertEq(x.texts.EN.label, "RGB:1,0,0Big label", "sans balise ni contrôle")
    assertEq(#x.texts.EN.desc, LotsFile.MAX_DESC, "description bornée")
end

-- ----------------------------------------------------------------------------
-- Réquisition : réponse « form », caisse, rechargement
-- ----------------------------------------------------------------------------

local function loadRequisition()
    ADMIN = { getUsername = function() return "admin" end, admin = true }
    ADMIN2 = { getUsername = function() return "admin2" end, admin = true }
    PLAYER = { getUsername = function() return "player" end, admin = false }
    -- Rôle gm : MakeEventsAlarmGunshot (Server.canForce) mais pas
    -- ChangeAndReloadServerOptions (Roles.java:374-411).
    GM = { getUsername = function() return "gm" end, admin = false, gm = true }
    Capability = { ChangeAndReloadServerOptions = "ChangeAndReloadServerOptions",
        MakeEventsAlarmGunshot = "MakeEventsAlarmGunshot" }
    checkPermissions = function(player, capability)
        if capability == Capability.MakeEventsAlarmGunshot then
            return player.admin == true or player.gm == true
        end
        return capability == Capability.ChangeAndReloadServerOptions and player.admin == true
    end
    REPLIES = {}
    MilitaryDrop.Net = { toPlayer = function(player, command, args)
        REPLIES[#REPLIES + 1] = { player = player, command = command, args = args }
    end }
    MilitaryDrop.Server = { COMMANDS = {}, canForce = function(player) return player.admin == true or player.gm == true end }
    MilitaryDrop.Trust = { get = function() return 80 end }
    DROPS = {}
    MilitaryDrop.Secrets = { privateState = function() return { drops = DROPS } end }
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Requisition.lua")
    return MilitaryDrop.Requisition
end

function T.form_sends_the_texts_of_added_lots()
    useFile(KITCHEN)
    local R = loadRequisition()
    local offer = R.offer("team")
    local byId = {}
    for _, entry in ipairs(offer.lots) do
        byId[entry.id] = entry
    end
    assertEq(#offer.lots, 19, "18 lots et le lot ajouté")
    assertEq(offer.lots[1].id, "kitchen", "ordre du fichier")
    assertEq(byId.kitchen.texts.EN.label, "Kitchen", "textes anglais")
    assertEq(byId.kitchen.texts.FR.desc, "Casseroles et outils.", "textes français")
    assertEq(byId.kitchen.label, nil, "pas de clé")
    assertEq(byId.kitchen.allowed, true, "candidats présents")
    assertEq(byId.kitchen.cost, 2, "coût")
    assertEq(byId.rations.label, "IGUI_MilitaryDrop_Lot_rations", "lot par défaut : clé")
    assertEq(byId.rations.desc, "IGUI_MilitaryDrop_LotDesc_rations", "lot par défaut : clé de description")
    assertEq(byId.rations.texts, nil, "lot par défaut : pas de textes")
    SandboxVars.MilitaryDrop.RequisitionCostMultiplier = 200
    assertEq(R.offer("team").lots[1].cost, 4, "options sandbox toujours appliquées")
end

function T.cases_of_an_added_lot_are_named_with_its_text()
    useFile(KITCHEN)
    local R = loadRequisition()
    Translator = { getLanguage = function() return { name = function() return "FR" end } end }
    DROPS.D1 = { order = { lots = { kitchen = 2, rations = 1 } } }
    local cases = R.casesFor("D1")
    assertEq(#cases, 3, "une caisse par unité")
    assertEq(cases[1].lot, "kitchen", "ordre des lots")
    assertEq(cases[1].name, "IGUI_MilitaryDrop_RequisitionCaseName(Cuisine)", "texte dans la langue du serveur")
    assertEq(cases[3].name, "IGUI_MilitaryDrop_RequisitionCaseName(IGUI_MilitaryDrop_Lot_rations)", "clé traduite")
    -- Ouverture par la recette.
    local given = {}
    Actions = { addOrDropItem = function(_, item) given[#given + 1] = item.fullType end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Recipe.lua")
    local case = { modData = { MilitaryDrop_lot = "kitchen" } }
    function case.getModData(self) return self.modData end
    function case.getFullType() return "MilitaryDrop.RequisitionCase" end
    MilitaryDrop.Recipe.openSupplyCase({ getAllConsumedItems = function() return list({ case }) end },
        { getUsername = function() return "player" end })
    assertEq(#given, 3, "count objets du lot ajouté")
    for _, fullType in ipairs(given) do
        assertTrue(fullType == "Base.Hammer" or fullType == "Base.Pot", "candidat du lot : " .. fullType)
    end
end

function T.reload_is_admin_only_and_applies_the_file()
    local R = loadRequisition()
    NOW_MS = 100000
    getTimestampMs = function() return NOW_MS end
    LotsFile.ensureLoaded()
    FILES[PATH] = FILES[PATH]:gsub('id = "rations", enabled = true', 'id = "rations", enabled = false')
    R.handleReload(PLAYER)
    assertTrue(not Lots.isDisabled(Lots.get("rations")), "joueur : refusé")
    assertTrue(logged("ReloadLots refused for player"), "refus au journal")
    assertEq(REPLIES[1].command, "ReloadLotsReply", "réponse au joueur refusé")
    assertEq(REPLIES[1].args.ok, false, "refus")
    -- gm : peut forcer un largage (canForce), pas recharger un réglage du serveur.
    R.handleReload(GM)
    assertTrue(not Lots.isDisabled(Lots.get("rations")), "gm : refusé")
    assertTrue(logged("ReloadLots refused for gm"), "refus du gm au journal")
    MilitaryDrop.Server.COMMANDS.ReloadLots(ADMIN)
    assertTrue(Lots.isDisabled(Lots.get("rations")), "admin : fichier relu")
    assertTrue(logged("requisition lots reloaded: 18 lots from file, 0 problem(s)"), "résumé au journal")
    local reply = REPLIES[#REPLIES]
    assertTrue(reply.player == ADMIN and reply.args.ok == true, "réponse à l'admin")
    assertEq(reply.args.lots, 18, "nombre de lots")
    assertEq(reply.args.problemCount, 0, "aucun problème")
    assertTrue(reply.args.summary:find("18 lots from file", 1, true) ~= nil, "résumé")
    -- Cadence globale : un autre admin juste après est refusé.
    FILES[PATH] = FILES[PATH]:gsub('id = "rations", enabled = false', 'id = "rations", enabled = "no"')
    NOW_MS = NOW_MS + 1000
    R.handleReload(ADMIN2)
    assertTrue(Lots.isDisabled(Lots.get("rations")), "second admin trop tôt : pas relu")
    assertEq(REPLIES[#REPLIES].args.ok, false, "second admin prévenu")
    NOW_MS = NOW_MS + R.RELOAD_INTERVAL_MS
    R.handleReload(ADMIN2)
    reply = REPLIES[#REPLIES]
    assertTrue(reply.args.ok and reply.args.problemCount == 1, "relu après le délai, un problème")
    assertTrue(reply.args.problems[1]:find("rations", 1, true) ~= nil, "problème renvoyé à l'admin")
    local summary, report = R.reload()
    assertTrue(summary:find("18 lots from file", 1, true) ~= nil, "console : résumé renvoyé")
    assertEq(report.lots, 18, "rapport renvoyé")
end

function T.reload_keeps_the_supply_case_lists()
    local R = loadRequisition()
    LotsFile.ensureLoaded()
    local Loot = MilitaryDrop.Loot
    Loot.CASES["MilitaryDrop.TestCase"] = { picks = 1, sources = { { accept = function() return true end } } }
    local calls = 0
    local accept = Loot.CASES["MilitaryDrop.TestCase"].sources[1].accept
    Loot.CASES["MilitaryDrop.TestCase"].sources[1].accept = function(script)
        calls = calls + 1
        return accept(script)
    end
    assertTrue(#Loot.candidates("MilitaryDrop.TestCase") > 0, "liste calculée")
    local before = calls
    R.reload()
    assertTrue(#Loot.candidates("MilitaryDrop.TestCase") > 0, "toujours là")
    assertEq(calls, before, "caisse de ravitaillement non recalculée au rechargement des lots")
end

function T.fluid_bounds_are_checked_for_each_lot()
    useFile([[
        { id = "small", group = 1, cost = 1, count = 1, categories = { "Water", "WaterContainer" }, fluid = "Water",
          maxLiters = 2, texts = { EN = { label = "Small" } } },
        { id = "big", group = 1, cost = 1, count = 1, categories = { "Water", "WaterContainer" }, fluid = "Water",
          minLiters = 5, texts = { EN = { label = "Big" } } },
]])
    LotsFile.ensureLoaded()
    -- Même type et même fluide, bornes différentes : le cache ne garde que
    -- capacité et acceptation.
    assertEq(candidates("small"), "Base.WaterBottle", "petite contenance")
    assertEq(candidates("big"), "Base.BucketEmpty", "grande contenance, même cache")
    assertEq(candidates("water"), "Base.WaterBottle", "lot par défaut : bornes 0,5-2 l")
end

function T.texts_on_a_default_id_are_refused()
    useFile([[
        { id = "rations", cost = 3, texts = { EN = { label = "Food" } } },
]])
    LotsFile.ensureLoaded()
    assertEq(Lots.get("rations").cost, 1, "lot par défaut gardé")
    assertEq(Lots.get("rations").texts, nil, "pas de textes sur un id par défaut")
    assertEq(Lots.get("rations").label, "IGUI_MilitaryDrop_Lot_rations", "traduction gardée")
    assertTrue(logged("lot #1 (rations): texts is only for added lots"), "motif clair au journal")
end

function T.max_lots_bounds_the_total_with_the_defaults()
    local entries = {}
    for i = 1, 30 do
        entries[#entries + 1] = '        { id = "extra' .. i .. '", group = 1, cost = 1, count = 1, categories = { "Tool" },'
            .. ' texts = { EN = { label = "Extra ' .. i .. '" } } },'
    end
    useFile(table.concat(entries, "\n"))
    LotsFile.ensureLoaded()
    assertEq(#Lots.LIST, LotsFile.MAX_LOTS, "total borné, défauts absents du fichier compris")
    assertEq(Lots.get("extra" .. (LotsFile.MAX_LOTS - 18)).id, "extra22", "lots ajoutés jusqu'à la borne")
    assertEq(Lots.get("extra23"), nil, "au-delà : écarté")
    assertTrue(Lots.get("fuel") ~= nil, "les 18 lots par défaut restent")
    assertTrue(logged("lot #23 (extra23): more than 40 lots in all"), "journal")
end

function T.notice_says_the_file_is_shared_by_all_saves_and_servers()
    LotsFile.ensureLoaded()
    local text = FILES[PATH]
    assertTrue(text:find("EVERY single-player save and EVERY server", 1, true) ~= nil, "notice anglaise")
    assertTrue(text:find("TOUTES les parties solo et à TOUS les serveurs", 1, true) ~= nil, "notice française")
    assertTrue(text:find("set enabled = false rather than deleting it", 1, true) ~= nil, "retrait conseillé")
end

function T.cases_of_a_lot_removed_before_delivery_are_still_delivered()
    useFile(KITCHEN)
    local R = loadRequisition()
    Translator = { getLanguage = function() return { name = function() return "EN" end } end }
    DROPS.D2 = { order = { lots = { kitchen = 2, rations = 1, zeta = 1 } } }
    LotsFile.ensureLoaded()
    useFile("")
    LotsFile.ensureLoaded()
    local cases = R.casesFor("D2")
    assertEq(#cases, 4, "une caisse par unité commandée, lots retirés compris")
    assertEq(cases[1].lot, "rations", "lots connus d'abord")
    assertEq(cases[2].lot, "kitchen", "puis les lots retirés (ordre des id)")
    assertEq(cases[4].lot, "zeta", "ordre des id")
    assertEq(cases[2].name, "IGUI_MilitaryDrop_RequisitionCaseName(kitchen)", "nommée par son id")
    assertTrue(logged("lot kitchen is no longer in the lots file"), "journal")
end

function T.server_start_reads_the_file_before_warming()
    useFile(KITCHEN)
    loadRequisition()
    triggerEvent("OnServerStarted")
    assertEq(Lots.LIST[1].id, "kitchen", "fichier lu au démarrage")
    assertTrue(#MilitaryDrop.Loot.candidates(Lots.lootKey("kitchen")) > 0, "candidats précalculés")
end

return T
