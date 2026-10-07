-- MilitaryDrop_Fulton : classement et barème du contenu d'un kit (FULTON-08,
-- FULTON-09), compatibilité Zombie Virus Vaccine, option FultonValue, partage
-- selon le plafond restant. Les tags d'objets sont simulés par leurs chaînes.

local T = {}

local SCRIPT_NAMES = {
    ["Base.IDcard"] = "ID Card",
    ["Base.IDcard_Male"] = "ID Card",
    ["Base.IDcard_Stolen"] = "Stolen ID Card",
    ["Base.IDcard_Blank"] = "Blank ID Card",
    ["Base.Passport"] = "Passport",
    ["Base.Badge"] = "Badge",
    ["Base.Paperwork"] = "Paperwork",
    ["Base.OfficialDocument"] = "Official Document",
    ["Base.Map"] = "Map",
}

--- Objet simulé : fullType, tags (liste de chaînes), name (nom brut), stash.
local function item(fullType, tags, name, stash)
    local it = { fullType = fullType, tags = {}, stash = stash }
    for _, tag in ipairs(tags or {}) do
        it.tags[tag] = true
    end
    it.name = name or SCRIPT_NAMES[fullType] or fullType
    function it.hasTag(self, tag) return self.tags[tag] == true end
    function it.getFullType(self) return self.fullType end
    function it.getDisplayName(self) return self.name end
    function it.getScriptItem(self)
        local scriptName = SCRIPT_NAMES[self.fullType] or self.fullType
        return { getDisplayName = function() return scriptName end }
    end
    function it.getStashMap(self) return self.stash end
    return it
end

local function idCard(name)
    return item("Base.IDcard", { "base:idcard", "base:applyownername" }, name)
end

local function container()
    local it = item("Base.Bag_Schoolbag", {})
    it.kind = "InventoryContainer"
    return it
end

local function player(forename, surname)
    return {
        getDescriptor = function()
            return { getForename = function() return forename end, getSurname = function() return surname end }
        end,
    }
end

local function mods(list)
    ACTIVE_MODS = list
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return true end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    ItemTag = {
        APPLY_OWNER_NAME = "base:applyownername",
        IDCARD = "base:idcard",
        HAZMAT_SUIT = "base:hazmatsuit",
        SCBA = "base:scba",
        GAS_MASK = "base:gasmask",
        GASMASK_FILTER = "base:gasmaskfilter",
    }
    ACTIVE_MODS = {}
    getActivatedMods = function()
        return {
            size = function() return #ACTIVE_MODS end,
            get = function(_, i) return ACTIVE_MODS[i + 1] end,
        }
    end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Fulton.lua")
    Fulton = MilitaryDrop.Fulton
end

function T.dead_persons_id_card_is_paid_but_not_the_senders_own()
    local me = player("Alice", "Martin")
    assertEq(Fulton.category(idCard("ID Card: John Smith"), me), "identity", "carte renommée d'un mort")
    assertEq(Fulton.category(idCard("ID Card: Alice Martin"), me), nil, "carte du joueur lui-même")
    assertEq(Fulton.category(idCard("Carte d'identité (\"Alice Martin\")"), me), nil, "sa carte, format FR")
    assertEq(Fulton.category(idCard("ID Card"), me), nil, "carte au nom du script : jamais renommée")
end

function T.stolen_and_blank_cards_are_not_identities()
    local stolen = item("Base.IDcard_Stolen", { "base:idcard" }, "Stolen ID Card: Bob Ray")
    local blank = item("Base.IDcard_Blank", {}, "Blank ID Card: Bob Ray")
    assertEq(Fulton.category(stolen, nil), nil, "carte volée : sans applyownername")
    assertEq(Fulton.category(blank, nil), nil, "carte vierge : sans base:idcard")
end

function T.passports_and_badges_count_as_identities()
    local passport = item("Base.Passport", { "base:applyownername" }, "Passport: John Smith")
    local badge = item("Base.Badge", { "base:applyownername" }, "Badge: John Smith")
    local diary = item("Base.Diary1", { "base:applyownername" }, "Diary: John Smith")
    assertEq(Fulton.category(passport, nil), "identity", "passeport")
    assertEq(Fulton.category(badge, nil), "identity", "badge")
    assertEq(Fulton.category(diary, nil), nil, "journal intime : applyownername mais pas une identité")
end

function T.papers_and_stash_maps_are_paid_plain_maps_are_not()
    assertEq(Fulton.category(item("Base.Paperwork"), nil), "papers", "Paperwork")
    assertEq(Fulton.category(item("Base.OfficialDocument"), nil), "papers", "document officiel")
    assertEq(Fulton.category(item("Base.Note"), nil), nil, "note : pas un papier admis")
    assertEq(Fulton.category(item("Base.Map", {}, "Map", "Stash_RiversideHouse"), nil), "stashMap", "carte-cachette")
    assertEq(Fulton.category(item("Base.Map"), nil), nil, "carte ordinaire")
    assertEq(Fulton.category(item("Base.Map", {}, "Map", ""), nil), nil, "nom de cachette vide")
end

function T.military_nbc_gear_only()
    local hazmat = item("Base.HazmatSuit", { "base:hazmatsuit", "base:scba" })
    assertEq(Fulton.category(hazmat, nil), "hazmatSuit", "combinaison : hazmat avant ARI")
    assertEq(Fulton.category(item("Base.SCBA", { "base:scba" }), nil), "scba", "ARI")
    assertEq(Fulton.category(item("Base.Hat_GasMask", { "base:gasmask" }), nil), "gasMask", "masque à gaz")
    assertEq(Fulton.category(item("Base.GasmaskFilter", { "base:gasmaskfilter" }), nil), "gasMaskFilter", "filtre")
    assertEq(Fulton.category(item("Base.Hat_GasMask_nofilter", { "base:gasmasknofilter" }), nil), nil, "sans filtre")
    assertEq(Fulton.category(item("Base.Hat_BuildersRespirator", { "base:respirator" }), nil), nil, "respirateur")
    assertEq(Fulton.category(item("Base.Hat_ImprovisedGasMask", { "base:improvisedgasmask" }), nil), nil, "masque bricolé")
end

function T.nested_containers_are_never_paid()
    local bag = container()
    bag.tags["base:hazmatsuit"] = true
    assertEq(Fulton.category(bag, nil), nil, "conteneur imbriqué")
end

function T.vaccine_items_are_paid_only_when_the_mod_is_active()
    local cure = item("LabItems.CmpSyringeWithCure")
    local fluid = item("LabItems.CmpSyringeReusableWithBrainFluidHigh")
    assertEq(Fulton.category(cure, nil, Fulton.vaccineActive()), nil, "mod absent")
    mods({ "\\ZVirusVaccine42BETA" })
    assertTrue(Fulton.vaccineActive(), "« \\ » initial ignoré")
    assertEq(Fulton.category(cure, nil, true), "cure", "remède")
    assertEq(Fulton.category(fluid, nil, true), "brainFluidHigh", "liquide cérébral haut")
    assertEq(Fulton.category(item("LabItems.RottenHumanBrain"), nil, true), nil, "cerveau pourri : sans valeur")
end

function T.evaluation_sums_capped_and_uncapped_values()
    mods({ "ZVirusVaccine42BETA" })
    local items = {
        idCard("ID Card: John Smith"),                        -- 3
        item("Base.Paperwork"),                               -- 1
        item("Base.Map", {}, "Map", "Stash_A"),               -- 4
        item("Base.HazmatSuit", { "base:hazmatsuit", "base:scba" }), -- 6
        item("LabItems.CmpSyringeWithAdvancedVaccine"),       -- 10
        item("LabItems.CmpSyringeWithCure"),                  -- 25 hors plafond
        item("Base.Note"),
        container(),
    }
    local result = Fulton.evaluate(items, player("Alice", "Martin"))
    assertEq(result.capped, 24, "plafonné : 3 + 1 + 4 + 6 + 10")
    assertEq(result.uncapped, 25, "remède hors plafond")
    assertEq(result.paid, 6, "six objets payés")
    assertEq(result.unpaid, 2, "note et sac non payés")
    assertEq(result.counts.cure, 1, "compte par catégorie")
end

function T.fulton_value_scales_and_disables()
    local items = { item("Base.Paperwork"), item("Base.Hat_GasMask", { "base:gasmask" }) }
    SandboxVars.MilitaryDrop.FultonValue = 150
    assertEq(Fulton.evaluate(items, nil).capped, 5, "3 × 150 % = 4,5 arrondi à 5")
    SandboxVars.MilitaryDrop.FultonValue = 0
    assertEq(Fulton.evaluate(items, nil).capped, 0, "barème à 0")
    assertTrue(not Fulton.isEnabled(), "source désactivée à 0")
    SandboxVars.MilitaryDrop.FultonValue = nil
    assertTrue(Fulton.isEnabled(), "activée par défaut")
end

function T.settle_splits_on_the_remaining_daily_cap()
    local settled = Fulton.settle({ capped = 9, uncapped = 25 }, 4)
    assertEq(settled.credited, 4, "crédité jusqu'au plafond")
    assertEq(settled.lost, 5, "le reste est perdu")
    assertEq(settled.uncapped, 25, "remède intact")
    assertEq(Fulton.settle({ capped = 3, uncapped = 0 }, nil).credited, 0, "plafond inconnu : rien")
end

function T.kit_items_reads_only_direct_contents()
    local inner = item("Base.Paperwork")
    local kit = {
        getItemContainer = function()
            return { getItems = function()
                return { size = function() return 1 end, get = function() return inner end }
            end }
        end,
    }
    local items = Fulton.kitItems(kit)
    assertEq(#items, 1, "un objet")
    assertEq(items[1], inner, "objet du kit")
    assertEq(#Fulton.kitItems({}), 0, "objet sans conteneur")
end

return T
