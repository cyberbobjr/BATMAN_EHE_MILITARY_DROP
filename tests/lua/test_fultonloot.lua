-- MilitaryDrop_FultonLoot : objets Fulton dans les listes procédurales vanilla
-- (sans doublon, poids × FultonLootRate, retrait à 0, rafraîchissement à chaud)
-- et tirages des kits endommagés (épave, caisse).

local T = {}

local function lists(names)
    local result = {}
    for _, name in ipairs(names) do
        result[name] = { items = { "Base.Something", 2 } }
    end
    return result
end

--- Poids de fullType dans la liste name, ou nil ; nombre d'occurrences.
local function weightIn(name, fullType)
    local items = ProceduralDistributions.list[name].items
    local weight, count = nil, 0
    for i = 1, #items - 1 do
        if items[i] == fullType then
            weight, count = items[i + 1], count + 1
        end
    end
    return weight, count
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return true end
    PARSES = 0
    ItemPickerJava = { Parse = function() PARSES = PARSES + 1 end }
    ProceduralDistributions = { list = lists({ "GiftStoreToys", "ArmyStorageMedical", "ArmyBunkerStorage",
        "ArmyStorageElectronics" }) }
    RANDOM = 50
    ZombRandFloat = function() return RANDOM end
    local noop = { Add = function() end, Remove = function() end }
    Events = setmetatable({}, { __index = function() return noop end })
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Fulton.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_FultonLoot.lua")
    FultonLoot = MilitaryDrop.FultonLoot
end

function T.items_are_added_once_with_their_weights()
    assertTrue(FultonLoot.addToLoot(), "ajoutés")
    assertEq(PARSES, 1, "tables relues")
    assertEq(weightIn("GiftStoreToys", "MilitaryDrop.HeliumTank"), 1.5, "hélium : magasins de cadeaux et de jouets")
    assertEq(weightIn("ArmyStorageMedical", "MilitaryDrop.HeliumTank"), 1, "hélium : réserve médicale de l'armée")
    assertEq(weightIn("ArmyStorageElectronics", "MilitaryDrop.FultonKitDamaged"), 0.3, "kit endommagé : rare")
    local _, tanks = weightIn("ArmyBunkerStorage", "MilitaryDrop.HeliumTank")
    local _, kits = weightIn("ArmyBunkerStorage", "MilitaryDrop.FultonKitDamaged")
    assertEq(tanks + kits, 2, "deux objets dans la réserve du bunker")
    assertTrue(not FultonLoot.addToLoot(), "second appel : rien")
    assertEq(PARSES, 1, "pas de relecture inutile")
    local _, count = weightIn("GiftStoreToys", "MilitaryDrop.HeliumTank")
    assertEq(count, 1, "aucun doublon")
end

function T.rate_scales_weights_and_zero_removes()
    SandboxVars.MilitaryDrop.FultonLootRate = 200
    FultonLoot.addToLoot()
    assertEq(weightIn("GiftStoreToys", "MilitaryDrop.HeliumTank"), 3, "taux 200 %")
    SandboxVars.MilitaryDrop.FultonLootRate = 50
    assertTrue(FultonLoot.refresh(), "changement à chaud")
    assertEq(weightIn("GiftStoreToys", "MilitaryDrop.HeliumTank"), 0.75, "nouveau poids")
    local _, count = weightIn("GiftStoreToys", "MilitaryDrop.HeliumTank")
    assertEq(count, 1, "remplacé, pas ajouté")
    SandboxVars.MilitaryDrop.FultonLootRate = 0
    FultonLoot.refresh()
    assertEq(weightIn("GiftStoreToys", "MilitaryDrop.HeliumTank"), nil, "taux 0 : retiré")
    assertEq(ProceduralDistributions.list.GiftStoreToys.items[1], "Base.Something", "le reste de la liste intact")
    assertEq(#ProceduralDistributions.list.GiftStoreToys.items, 2, "rien d'autre retiré")
end

function T.missing_list_is_skipped_without_error()
    ProceduralDistributions.list.ArmyBunkerStorage = nil
    assertTrue(FultonLoot.addToLoot(), "les autres listes reçoivent leurs objets")
    assertEq(weightIn("GiftStoreToys", "MilitaryDrop.HeliumTank"), 1.5, "ajouté ailleurs")
end

function T.rolls_follow_chance_and_rate()
    RANDOM = 24.9
    assertTrue(FultonLoot.rollWreck(), "25 % sur l'épave")
    RANDOM = 25
    assertTrue(not FultonLoot.rollWreck(), "au-delà : rien")
    RANDOM = 4.9
    assertTrue(FultonLoot.rollCrate(), "5 % dans une caisse")
    RANDOM = 5
    assertTrue(not FultonLoot.rollCrate(), "au-delà : rien")
    SandboxVars.MilitaryDrop.FultonLootRate = 500
    RANDOM = 99.9
    assertTrue(FultonLoot.rollWreck(), "borné à 100 %")
    SandboxVars.MilitaryDrop.FultonLootRate = 0
    RANDOM = 0
    assertTrue(not FultonLoot.rollWreck() and not FultonLoot.rollCrate(), "taux 0 : jamais")
end

return T
