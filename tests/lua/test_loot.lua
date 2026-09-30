-- MilitaryDrop_Loot : tirage pondéré et filtrage des objets de chaque caisse.

local T = {}

local SCRIPTS = {
    Bullets9mmBox = "Normal",
    Bag_AmmoBox_9mm = "Container",
    Pistol = "Weapon",
    AssaultRifle = "Weapon",
    BandageBox = "Normal",
    RedDot = "WeaponPart",
}

function T.setup()
    SandboxVars = {}
    ItemType = { CONTAINER = "Container", WEAPON = "Weapon" }
    getScriptManager = function()
        return {
            FindItem = function(_, name)
                local kind = SCRIPTS[name]
                if not kind then
                    return nil
                end
                return {
                    getItemType = function() return kind end,
                    getFullName = function() return "Base." .. name end,
                }
            end,
        }
    end
    ProceduralDistributions = { list = {
        ArmyStorageAmmunition = { items = { "Bullets9mmBox", 20, "Bag_AmmoBox_9mm", 10, "Unknown", 5 } },
        ArmyStorageGuns = { items = { "Pistol", 20, "BandageBox", 10, "AssaultRifle", 0.5 } },
        ArmyStorageOutfit = { items = {} },
    } }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
end

--- rand(total) qui renvoie toujours la même fraction du total.
local function fixed(fraction)
    return function(total) return total * fraction end
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
    assertEq(pick(entries, fixed(0.999999)).name, "B", "borne haute")
end

function T.pick_weighted_empty_is_nil()
    assertEq(MilitaryDrop.Loot.pickWeighted({}, fixed(0)), nil, "aucune entrée")
end

function T.ammo_case_excludes_containers_and_unknown_items()
    local candidates = MilitaryDrop.Loot.candidates("MilitaryDrop.AmmoSupplyCase")
    assertEq(#candidates, 1, "seule la boîte de balles reste")
    assertEq(candidates[1].fullType, "Base.Bullets9mmBox", "type complet")
end

function T.weapon_case_keeps_only_weapons()
    local candidates = MilitaryDrop.Loot.candidates("MilitaryDrop.WeaponSupplyCase")
    assertEq(#candidates, 2, "Pistol et AssaultRifle, sans BandageBox")
    local results = MilitaryDrop.Loot.roll("MilitaryDrop.WeaponSupplyCase", fixed(0.99))
    assertEq(#results, 1, "une seule arme par caisse")
    assertEq(results[1], "Base.AssaultRifle", "le poids 0,5 est tirable")
end

function T.ammo_case_rolls_five_items()
    local results = MilitaryDrop.Loot.roll("MilitaryDrop.AmmoSupplyCase", fixed(0))
    assertEq(#results, 5, "cinq tirages")
end

function T.empty_source_gives_nothing()
    local results = MilitaryDrop.Loot.roll("MilitaryDrop.ArmorSupplyCase", fixed(0))
    assertEq(#results, 0, "table vide")
end

function T.weapon_comes_with_magazines_and_ammo()
    instanceof = function(object, class) return object.kind == class end
    SCRIPTS["Base.9mmClip"] = "Normal"
    SCRIPTS["Base.Bullets9mmBox"] = "Normal"
    local pistol = {
        kind = "HandWeapon",
        getMagazineType = function() return "Base.9mmClip" end,
        getAmmoBox = function() return "Base.Bullets9mmBox" end,
    }
    local extras = MilitaryDrop.Loot.weaponExtras(pistol)
    assertEq(#extras, 3, "deux chargeurs et une boîte")
    assertEq(extras[1], "Base.9mmClip", "chargeur")
    assertEq(extras[3], "Base.Bullets9mmBox", "munitions")
end

function T.shotgun_without_magazine_gets_ammo_only()
    instanceof = function(object, class) return object.kind == class end
    SCRIPTS["Base.ShotgunShellsBox"] = "Normal"
    local shotgun = {
        kind = "HandWeapon",
        getMagazineType = function() return nil end,
        getAmmoBox = function() return "Base.ShotgunShellsBox" end,
    }
    local extras = MilitaryDrop.Loot.weaponExtras(shotgun)
    assertEq(#extras, 1, "une boîte de cartouches")
    instanceof = function() return false end
    assertEq(#MilitaryDrop.Loot.weaponExtras({}), 0, "pas une arme : rien")
end

function T.unknown_case_gives_nothing()
    assertEq(#MilitaryDrop.Loot.roll("Base.Nothing", fixed(0)), 0, "type inconnu")
end

return T
