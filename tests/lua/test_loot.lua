-- MilitaryDrop_Loot : caisses remplies depuis les tables du jeu, par catégorie,
-- sans aucun nom d'objet dans le mod. Jeu simulé : objets vanilla (Base) et
-- un mod d'armes (module GunMod) inscrit sans préfixe dans les tables.

local T = {}

--- Scripts d'objets simulés : type complet → { itemType, ranged, magazine, ammoBox, bulletDefense }.
local ITEMS = {
    ["Base.Pistol"] = {
        itemType = "Weapon", ranged = true, damage = 1, magazine = "Base.9mmClip", ammoBox = "Base.Bullets9mmBox",
    },
    ["Base.Shotgun"] = { itemType = "Weapon", ranged = true, damage = 2, ammoBox = "Base.ShotgunShellsBox" },
    ["Base.Revolver_CapGun"] = { itemType = "Weapon", ranged = true, damage = 0, ammoBox = "Base.CapGunCapBox" },
    ["Base.CapGunCapBox"] = { itemType = "Normal" },
    ["Base.Axe"] = { itemType = "Weapon", ranged = false },
    ["Base.9mmClip"] = { itemType = "Normal" },
    ["Base.Bullets9mmBox"] = { itemType = "Normal" },
    ["Base.ShotgunShellsBox"] = { itemType = "Normal" },
    ["Base.Bag_AmmoBox_9mm"] = { itemType = "Container" },
    ["Base.BandageBox"] = { itemType = "Normal" },
    ["Base.RedDot"] = { itemType = "WeaponPart" },
    ["Base.Vest_BulletArmy"] = { itemType = "Clothing", bulletDefense = 50 },
    ["Base.Tshirt_ArmyGreen"] = { itemType = "Clothing", bulletDefense = 0 },
    ["GunMod.M4"] = { itemType = "Weapon", ranged = true, damage = 1.5, magazine = "GunMod.M4Mag", ammoBox = "GunMod.556Box" },
    ["GunMod.M4Mag"] = { itemType = "Normal" },
    ["GunMod.556Box"] = { itemType = "Normal" },
    ["GunMod.Suppressor"] = { itemType = "WeaponPart" },
}

local function list(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end

local function makeScript(fullType)
    local data = ITEMS[fullType]
    return {
        getItemType = function() return data.itemType end,
        getFullName = function() return fullType end,
        isRanged = function() return data.ranged == true end,
        getMaxDamage = function() return data.damage or 0 end,
    }
end

function T.setup()
    SandboxVars = {}
    ItemType = { CONTAINER = "Container", WEAPON = "Weapon", WEAPON_PART = "WeaponPart", CLOTHING = "Clothing" }
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    INSTANCED = 0
    instanceItem = function(fullType)
        INSTANCED = INSTANCED + 1
        local data = ITEMS[fullType]
        if data.itemType == "Weapon" then
            return {
                kind = "HandWeapon",
                getMagazineType = function() return data.magazine end,
                getAmmoBox = function() return data.ammoBox end,
            }
        end
        if data.itemType == "Clothing" then
            return { kind = "Clothing", getBulletDefense = function() return data.bulletDefense end }
        end
        return { kind = "InventoryItem" }
    end
    getScriptManager = function()
        return {
            -- Comme le jeu : un nom sans module n'est cherché que dans Base.
            FindItem = function(_, name)
                local fullType = string.find(name, ".", 1, true) and name or ("Base." .. name)
                return ITEMS[fullType] and makeScript(fullType) or nil
            end,
            getItemsByType = function(_, name)
                local found = {}
                for fullType in pairs(ITEMS) do
                    if fullType:match("%.(.+)$") == name then
                        found[#found + 1] = makeScript(fullType)
                    end
                end
                return list(found)
            end,
            getAllItems = function()
                local all = {}
                for fullType in pairs(ITEMS) do
                    all[#all + 1] = makeScript(fullType)
                end
                return list(all)
            end,
        }
    end
    ProceduralDistributions = { list = {
        ArmyStorageGuns = { items = { "Pistol", 20, "Axe", 10, "BandageBox", 10, "M4", 5, "Removed", 5 } },
        ArmyStorageAmmunition = { items = { "Bullets9mmBox", 20, "Bag_AmmoBox_9mm", 10 } },
        ArmyStorageOutfit = { items = { "Tshirt_ArmyGreen", 6, "Vest_BulletArmy", 2 } },
        GunStore = { items = { "Shotgun", 8, "ShotgunShellsBox", 4, "RedDot", 3, "GunMod.Suppressor", 1, "556Box", 2 } },
        ToyStore = { items = { "Revolver_CapGun", 10, "CapGunCapBox", 10 } },
        PoliceStorage = { items = { "RedDot", 2, "Vest_BulletArmy", 3, "9mmClip", 1 } },
    } }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
end

--- rand(total) qui renvoie toujours la même fraction du total.
local function fixed(fraction)
    return function(total) return total * fraction end
end

local function names(entries)
    local result = {}
    for _, entry in ipairs(entries) do
        result[#result + 1] = entry.fullType
    end
    table.sort(result)
    return table.concat(result, ",")
end

function T.entries_skip_bad_weights()
    local entries = MilitaryDrop.Loot.toEntries({ "A", 2, "B", 0, "C", -1, "D", "x", "E", 0.5 })
    assertEq(#entries, 2, "seuls A et E ont un poids positif")
    assertEq(entries[2].name, "E", "poids décimal conservé")
end

function T.pick_weighted_respects_decimal_weights()
    local entries = MilitaryDrop.Loot.toEntries({ "A", 0.5, "B", 0.5 })
    local pick = MilitaryDrop.Loot.pickWeighted
    assertEq(pick(entries, fixed(0.25)).name, "A", "première moitié")
    assertEq(pick(entries, fixed(0.75)).name, "B", "seconde moitié")
    assertEq(pick({}, fixed(0)), nil, "aucune entrée")
end

function T.weapon_case_keeps_firearms_including_mod_names_without_module()
    local candidates = MilitaryDrop.Loot.candidates("MilitaryDrop.WeaponSupplyCase")
    assertEq(names(candidates), "Base.Pistol,GunMod.M4",
        "armes à feu seulement ; « M4 » sans module trouvé dans GunMod ; hache, bandages et objet retiré écartés")
end

function T.weapon_case_falls_back_to_all_tables()
    ProceduralDistributions.list.ArmyStorageGuns = nil
    local candidates = MilitaryDrop.Loot.candidates("MilitaryDrop.WeaponSupplyCase")
    assertEq(names(candidates), "Base.Shotgun",
        "table de l'armée absente : armes à feu de toutes les tables, sans le pistolet à amorces (dégâts nuls)")
end

function T.ammo_case_excludes_containers()
    assertEq(names(MilitaryDrop.Loot.candidates("MilitaryDrop.AmmoSupplyCase")), "Base.Bullets9mmBox", "sans sac vide")
end

function T.ammo_case_falls_back_to_supplies_of_existing_firearms()
    ProceduralDistributions.list.ArmyStorageAmmunition = { items = {} }
    assertEq(names(MilitaryDrop.Loot.candidates("MilitaryDrop.AmmoSupplyCase")),
        "Base.9mmClip,Base.ShotgunShellsBox,GunMod.556Box",
        "chargeurs et boîtes d'armes à feu du jeu, trouvés dans toutes les tables")
end

function T.armor_case_falls_back_to_bullet_protection()
    ProceduralDistributions.list.ArmyStorageOutfit = nil
    assertEq(names(MilitaryDrop.Loot.candidates("MilitaryDrop.ArmorSupplyCase")), "Base.Vest_BulletArmy",
        "vêtements qui protègent des balles")
end

function T.attachments_come_from_all_tables_with_summed_weights()
    local candidates = MilitaryDrop.Loot.candidates("MilitaryDrop.AttachmentSupplyCase")
    assertEq(names(candidates), "Base.RedDot,GunMod.Suppressor", "pièces d'armes vanilla et de mod")
    for _, entry in ipairs(candidates) do
        if entry.fullType == "Base.RedDot" then
            assertEq(entry.weight, 5, "3 (armurerie) + 2 (police)")
        end
    end
end

function T.candidates_are_cached()
    MilitaryDrop.Loot.candidates("MilitaryDrop.ArmorSupplyCase")
    ProceduralDistributions.list.ArmyStorageOutfit = nil
    assertEq(names(MilitaryDrop.Loot.candidates("MilitaryDrop.ArmorSupplyCase")),
        "Base.Tshirt_ArmyGreen,Base.Vest_BulletArmy", "liste calculée une seule fois")
end

function T.roll_counts_and_unknown_case()
    assertEq(#MilitaryDrop.Loot.roll("MilitaryDrop.AmmoSupplyCase", fixed(0)), 5, "cinq tirages")
    assertEq(#MilitaryDrop.Loot.roll("MilitaryDrop.WeaponSupplyCase", fixed(0.99)), 1, "une arme")
    assertEq(#MilitaryDrop.Loot.roll("Base.Nothing", fixed(0)), 0, "type inconnu")
end

function T.empty_game_gives_nothing()
    ProceduralDistributions = { list = {} }
    assertEq(#MilitaryDrop.Loot.roll("MilitaryDrop.WeaponSupplyCase", fixed(0)), 0, "aucune table")
end

function T.weapon_comes_with_its_magazines_and_ammo()
    local extras = MilitaryDrop.Loot.weaponExtras(instanceItem("GunMod.M4"))
    assertEq(table.concat(extras, ","), "GunMod.M4Mag,GunMod.M4Mag,GunMod.556Box", "deux chargeurs et une boîte du mod")
    assertEq(#MilitaryDrop.Loot.weaponExtras(instanceItem("Base.Shotgun")), 1, "fusil à pompe : cartouches seulement")
    assertEq(#MilitaryDrop.Loot.weaponExtras({ kind = "InventoryItem" }), 0, "pas une arme")
end

return T
