-- MilitaryDrop_Lots : les 18 lots de réquisition, filtrés par catégorie
-- d'affichage, propriétés et tags sur des tables de butin simulées (aucun nom
-- d'objet dans le mod) ; récipients remplis d'eau ou d'essence ; ouverture
-- d'une caisse de réquisition par la recette.

local T = {}

--- Scripts simulés : type complet → propriétés.
local ITEMS = {
    ["Base.TinnedBeans"] = { cat = "Food", rotten = 1000000000 },
    ["Base.Bread"] = { cat = "Food", rotten = 6 },
    ["Base.WaterBottle"] = { cat = "Water", fluid = { capacity = 1, initial = "CarbonatedWater" } },
    ["Base.BucketEmpty"] = { cat = "WaterContainer", fluid = { capacity = 10 } },
    ["Base.LockedFlask"] = { cat = "WaterContainer", fluid = { capacity = 1, locked = true } },
    ["Base.Bandage"] = { cat = "Bandage" },
    ["Base.Hammer"] = { cat = "Tool" },
    ["Base.Plank"] = { cat = "Material" },
    ["Base.Matches"] = { cat = "FireSource" },
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
    ["Base.PetrolCan"] = { cat = "VehicleMaintenance", tags = { Petrol = true },
        fluid = { capacity = 10, initial = "Petrol" } },
    ["Base.CarBattery"] = { cat = "VehicleMaintenance" },
    ["Base.WalkieTalkie"] = { cat = "Communications", weight = 1 },
    ["Base.TvBlack"] = { cat = "Communications", weight = 20 },
    ["Base.Seeds"] = { cat = "Gardening" },
    ["Base.BookAiming1"] = { cat = "SkillBook" },
    ["Base.Bag_ALICE"] = { cat = "Bag", itemType = "Container" },
    -- Contenants (catégorie Container), valeurs vanilla 42.21.
    ["Base.Bag_ProtectiveCaseBulky"] = { cat = "Container", itemType = "Container", weight = 1, capacity = 16,
        reduction = 50 },
    ["Base.Plasticbag"] = { cat = "Container", itemType = "Container", weight = 0.1, capacity = 8, reduction = 50 },
    ["Base.Cooler_Beer"] = { cat = "Container", itemType = "Container", weight = 1.5, capacity = 12,
        reduction = 50, tags = { NeverEmpty = true } },
    ["Base.JewelleryBox"] = { cat = "Container", itemType = "Container", weight = 1, capacity = 2, reduction = 50 },
    ["Base.Parcel_Large"] = { cat = "Container", itemType = "Container", weight = 1, capacity = 10, reduction = 0 },
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

--- Récipient de fluide simulé (FluidContainer).
local function makeFluidContainer(spec)
    local fc = { capacity = spec.capacity, fluids = {} }
    if spec.initial then
        fc.fluids[spec.initial] = spec.capacity
    end
    function fc.getCapacity(self) return self.capacity end
    function fc.Empty(self) self.fluids = {} end
    function fc.canAddFluid() return not spec.locked end
    function fc.addFluid(self, fluid, amount)
        if not spec.locked then
            self.fluids[fluid] = (self.fluids[fluid] or 0) + amount
        end
    end
    return fc
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
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
    -- Objets créés, par type complet (le coût à éviter).
    INSTANCED = {}
    instanceItem = function(fullType)
        local data = ITEMS[fullType]
        if not data then
            return nil
        end
        INSTANCED[fullType] = (INSTANCED[fullType] or 0) + 1
        local item = { fullType = fullType, kind = "InventoryItem" }
        if data.itemType == "Container" then
            item.kind = "InventoryContainer"
            item.getCapacity = function() return data.capacity or 0 end
            item.getWeightReduction = function() return data.reduction or 0 end
        end
        if data.itemType == "Weapon" then
            item.kind = "HandWeapon"
            item.getMagazineType = function() return data.magazine end
            item.getAmmoBox = function() return data.ammoBox end
        elseif data.itemType == "Clothing" then
            item.kind = "Clothing"
            item.getBulletDefense = function() return data.bulletDefense end
        end
        local container = data.fluid and makeFluidContainer(data.fluid) or nil
        item.getFluidContainer = function() return container end
        item.hasTag = function(_, tag) return data.tags ~= nil and data.tags[tag] == true end
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
    ProceduralDistributions = { list = { Everything = { items = flat }, Extra = { items = { "WaterBottle", 3 } } } }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Lots.lua")
    Lots = MilitaryDrop.Lots
end

local function candidates(id)
    local result = {}
    for _, entry in ipairs(MilitaryDrop.Loot.candidates(Lots.lootKey(id))) do
        result[#result + 1] = entry.fullType
    end
    table.sort(result)
    return table.concat(result, ",")
end

function T.eighteen_lots_in_three_groups_with_text_keys()
    assertEq(#Lots.LIST, 18, "18 lots")
    local groups, seen = { 0, 0, 0 }, {}
    for _, lot in ipairs(Lots.LIST) do
        assertTrue(not seen[lot.id], "identifiant unique : " .. lot.id)
        seen[lot.id] = true
        groups[lot.group] = groups[lot.group] + 1
        assertEq(lot.label, "IGUI_MilitaryDrop_Lot_" .. lot.id, "libellé")
        assertEq(lot.desc, "IGUI_MilitaryDrop_LotDesc_" .. lot.id, "description")
        assertTrue(lot.count >= 1 and lot.cost >= 1, "coût et nombre d'objets")
    end
    assertEq(groups[1] .. "/" .. groups[2] .. "/" .. groups[3], "6/8/4", "lots par palier (PLAN-V2, idée 6)")
    assertEq(Lots.get("firearms").group, 3, "armes à feu au palier III")
    assertEq(Lots.get(42), nil, "identifiant non textuel")
end

function T.lots_filter_by_category_property_and_tag()
    local expected = {
        rations = "Base.TinnedBeans",
        water = "Base.WaterBottle",
        medical = "Base.Bandage",
        tools = "Base.Hammer",
        materials = "Base.Plank",
        camping = "Base.Matches",
        ammo = "Base.9mmClip,Base.Bullets9mmBox",
        melee = "Base.Machete",
        protection = "Base.Hat_Helmet,Base.Vest_BulletArmy",
        mechanics = "Base.CarBattery",
        comms = "Base.WalkieTalkie",
        seeds = "Base.Seeds",
        books = "Base.BookAiming1",
        packs = "Base.Bag_ALICE,Base.Bag_ProtectiveCaseBulky",
        firearms = "Base.Pistol",
        attachments = "Base.RedDot",
        explosives = "Base.PipeBomb",
        fuel = "Base.PetrolCan",
    }
    for _, lot in ipairs(Lots.LIST) do
        assertEq(candidates(lot.id), expected[lot.id], "candidats du lot " .. lot.id)
    end
end

local function instancedCount()
    local n = 0
    for _, count in pairs(INSTANCED) do
        n = n + count
    end
    return n
end

function T.packs_keep_bags_and_sturdy_useful_containers()
    local isPack = Lots.isPack
    assertTrue(isPack(makeScript("Base.Bag_ALICE")), "sac (Bag)")
    assertTrue(isPack(makeScript("Base.Bag_ProtectiveCaseBulky")), "caisse de protection : 16, réduction 50, 1 kg")
    assertEq(isPack(makeScript("Base.Plasticbag")), false, "sac plastique : trop léger")
    assertEq(isPack(makeScript("Base.Cooler_Beer")), false, "base:neverempty (glacière garnie)")
    assertEq(isPack(makeScript("Base.JewelleryBox")), false, "capacité 2")
    assertEq(isPack(makeScript("Base.Parcel_Large")), false, "sans réduction de poids")
    assertEq(isPack(makeScript("Base.Hammer")), false, "pas un contenant")
    assertEq(INSTANCED["Base.Plasticbag"] or 0, 0, "trop léger : rejeté sur le script")
    assertEq(INSTANCED["Base.Cooler_Beer"] or 0, 0, "tag lu sur le script")
    assertEq(INSTANCED["Base.Bag_ALICE"] or 0, 0, "sac : sans exemplaire")
end

function T.fuel_and_mechanics_read_the_tag_on_the_script()
    assertEq(Lots.isFuelContainer(makeScript("Base.Hammer")), false, "sans tag")
    assertEq(Lots.isMechanics(makeScript("Base.CarBattery")), true, "batterie : mécanique")
    assertEq(instancedCount(), 0, "aucun objet créé sans le tag base:petrol")
    assertTrue(Lots.isFuelContainer(makeScript("Base.PetrolCan")), "bidon")
    assertEq(INSTANCED["Base.PetrolCan"], 1, "seul le candidat tagué est créé")
end

function T.all_lots_are_collected_in_one_pass_and_kept()
    local passes = 0
    local toEntries = MilitaryDrop.Loot.toEntries
    MilitaryDrop.Loot.toEntries = function(flat)
        passes = passes + 1
        return toEntries(flat)
    end
    Lots.warm()
    assertEq(passes, 2, "deux tables : un seul passage pour les 18 lots")
    for fullType, count in pairs(INSTANCED) do
        assertEq(count, 1, "un seul exemplaire de " .. fullType)
    end
    for _, lot in ipairs(Lots.LIST) do
        Lots.hasCandidates(lot.id)
    end
    Lots.warm()
    assertEq(passes, 2, "ensuite, tout vient de la mémoire")
end

function T.empty_lot_is_kept_too()
    ProceduralDistributions.list = { Only = { items = { "Hammer", 1 } } }
    assertEq(Lots.hasCandidates("seeds"), false, "aucune semence")
    ProceduralDistributions.list.Only.items = { "Hammer", 1, "Seeds", 1 }
    assertEq(Lots.hasCandidates("seeds"), false, "résultat vide gardé (pas de nouveau passage)")
end

function T.nothing_is_kept_before_the_tables_exist()
    ProceduralDistributions.list = {}
    assertEq(Lots.hasCandidates("tools"), false, "aucune table encore")
    ProceduralDistributions.list = { Only = { items = { "Hammer", 1 } } }
    assertTrue(Lots.hasCandidates("tools"), "tables arrivées : recalcul")
end

function T.weights_of_all_tables_are_summed()
    for _, entry in ipairs(MilitaryDrop.Loot.candidates(Lots.lootKey("water"))) do
        assertEq(entry.weight, 5, "2 + 3 : deux tables")
    end
end

function T.lot_without_candidates_is_empty()
    ProceduralDistributions.list = { Only = { items = { "Hammer", 1 } } }
    assertTrue(Lots.hasCandidates("tools"), "outils présents")
    assertEq(Lots.hasCandidates("seeds"), false, "aucune semence dans les tables")
    assertEq(#Lots.roll("seeds", function(total) return 0 * total end), 0, "rien à tirer")
end

function T.explosives_and_missing_fluids_disable_their_lot()
    assertEq(Lots.isDisabled(Lots.get("explosives")), false, "explosifs permis par défaut")
    SandboxVars.MilitaryDrop.RequisitionExplosives = false
    assertEq(Lots.isDisabled(Lots.get("explosives")), true, "option RequisitionExplosives")
    assertEq(Lots.isDisabled(Lots.get("fuel")), false, "Fluid.Petrol connu")
    Fluid = {}
    assertEq(Lots.isDisabled(Lots.get("fuel")), true, "fluide absent du moteur : lot désactivé")
end

function T.roll_draws_count_items()
    assertEq(#Lots.roll("rations", function() return 0 end), Lots.get("rations").count, "count tirages")
    assertEq(#Lots.roll("unknown", function() return 0 end), 0, "lot inconnu")
end

function T.water_and_fuel_containers_are_emptied_then_filled()
    local bottle = Lots.prepare(Lots.get("water"), instanceItem("Base.WaterBottle"))
    local fc = bottle:getFluidContainer()
    assertEq(fc.fluids.CarbonatedWater, nil, "contenu d'origine vidé")
    assertEq(fc.fluids.Water, 1, "rempli d'eau propre")
    local can = Lots.prepare(Lots.get("fuel"), instanceItem("Base.PetrolCan"))
    assertEq(can:getFluidContainer().fluids.Petrol, 10, "bidon plein d'essence")
    local tools = Lots.prepare(Lots.get("tools"), instanceItem("Base.Hammer"))
    assertEq(tools.fullType, "Base.Hammer", "objet sans fluide inchangé")
end

-- ----------------------------------------------------------------------------
-- Ouverture par la recette
-- ----------------------------------------------------------------------------

local function openCase(lotId, dropId)
    GIVEN = {}
    Actions = { addOrDropItem = function(_, item) GIVEN[#GIVEN + 1] = item end }
    ZombRandFloat = function(low) return low end
    OPENED = {}
    MilitaryDrop.Trust = { onCaseOpened = function(item) OPENED[#OPENED + 1] = item end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Recipe.lua")
    local case = { modData = { MilitaryDrop_lot = lotId, MilitaryDrop_dropId = dropId } }
    function case.getModData(self) return self.modData end
    function case.getFullType() return "MilitaryDrop.RequisitionCase" end
    local data = { getAllConsumedItems = function() return list({ case }) end }
    MilitaryDrop.Recipe.openSupplyCase(data, { getUsername = function() return "tester" end })
    local types = {}
    for _, item in ipairs(GIVEN) do
        types[#types + 1] = item.fullType
    end
    return table.concat(types, ","), case
end

function T.requisition_case_gives_its_lot_and_notifies_trust()
    local types, case = openCase("water", "D4")
    assertEq(types, "Base.WaterBottle,Base.WaterBottle", "deux bouteilles")
    assertEq(GIVEN[1]:getFluidContainer().fluids.Water, 1, "remplie avant d'être remise")
    assertEq(OPENED[1], case, "suivi de confiance prévenu (dropId en ModData)")
end

function T.firearm_case_comes_with_magazines_and_ammo()
    assertEq(openCase("firearms"), "Base.Pistol,Base.9mmClip,Base.9mmClip,Base.Bullets9mmBox",
        "arme, deux chargeurs et une boîte")
end

function T.other_lots_get_no_weapon_extras()
    assertEq(openCase("melee"), "Base.Machete", "arme de mêlée seule")
end

function T.case_with_unknown_lot_is_given_back_closed()
    local base = instanceItem
    instanceItem = function(fullType)
        if fullType == "MilitaryDrop.RequisitionCase" then
            local copy = { fullType = fullType, modData = {} }
            function copy.getModData(self) return self.modData end
            function copy.setName(self, name) self.name = name end
            function copy.setCustomName(self, value) self.custom = value end
            return copy
        end
        return base(fullType)
    end
    NOTICES = {}
    MilitaryDrop.Net = { toPlayer = function(_, command, args) NOTICES[#NOTICES + 1] = { command, args } end }
    local types, case = openCase("gold", "D9")
    assertEq(types, "MilitaryDrop.RequisitionCase", "lot retiré du fichier : la caisse est rendue, rien d'autre")
    assertTrue(GIVEN[1] ~= case, "nouvel exemplaire (l'ancien est consommé par la recette)")
    assertEq(GIVEN[1].modData.MilitaryDrop_lot, "gold", "même lot : s'ouvrira si le lot revient")
    assertEq(GIVEN[1].modData.MilitaryDrop_dropId, "D9", "même largage")
    assertEq(#OPENED, 0, "rien d'ouvert : la confiance n'est pas prévenue")
    assertEq(NOTICES[1][1], "Notice", "joueur prévenu")
    assertEq(NOTICES[1][2].key, "IGUI_MilitaryDrop_UnknownLotCase", "remarque traduite côté client")
    assertEq(NOTICES[1][2].username, "tester", "au bon joueur")
end

function T.case_with_unknown_lot_keeps_its_name()
    local base = instanceItem
    instanceItem = function(fullType)
        if fullType == "MilitaryDrop.RequisitionCase" then
            local copy = { modData = {} }
            function copy.getModData(self) return self.modData end
            function copy.setName(self, name) self.name = name end
            function copy.setCustomName(self, value) self.custom = value end
            return copy
        end
        return base(fullType)
    end
    GIVEN = {}
    Actions = { addOrDropItem = function(_, item) GIVEN[#GIVEN + 1] = item end }
    MilitaryDrop.Trust = { onCaseOpened = function() error("pas d'ouverture") end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Recipe.lua")
    local case = { modData = { MilitaryDrop_lot = "gold" } }
    function case.getModData(self) return self.modData end
    function case.getFullType() return "MilitaryDrop.RequisitionCase" end
    function case.isCustomName() return true end
    function case.getName() return "Caisse de réquisition : Or" end
    MilitaryDrop.Recipe.openSupplyCase({ getAllConsumedItems = function() return list({ case }) end },
        { getUsername = function() return "tester" end })
    assertEq(GIVEN[1].name, "Caisse de réquisition : Or", "nom gardé")
    assertEq(GIVEN[1].custom, true, "nom personnalisé")
end

return T
