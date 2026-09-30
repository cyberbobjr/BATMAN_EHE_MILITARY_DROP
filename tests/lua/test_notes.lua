-- MilitaryDrop_Notes : tenues ciblées, tirage mémorisé et note remise après
-- un second OnZombieDead (mort par le feu).

local T = {}

local function makeZombie(outfit)
    local items = {}
    return {
        modData = {},
        items = items,
        getModData = function(self) return self.modData end,
        getOutfitName = function() return outfit end,
        getInventory = function()
            return {
                containsType = function(_, fullType)
                    for _, item in ipairs(items) do
                        if item.fullType == fullType then
                            return true
                        end
                    end
                    return false
                end,
                AddItem = function(_, item) items[#items + 1] = item end,
            }
        end,
    }
end

function T.setup()
    SandboxVars = { MilitaryDrop = { NoteDropRate = 6, NotesOnlyArmyPolice = true } }
    isClient = function() return false end
    isServer = function() return false end
    ModData = { getOrCreate = function() return { code = "BRAVO-KILO-07" } end }
    ROLL = 0
    ZombRand = function() return ROLL end
    getText = function(key, a, b) return key .. "|" .. tostring(a) .. "|" .. tostring(b) end
    instanceItem = function(fullType)
        local memo = { fullType = fullType }
        function memo.addPage(self, index, text) self.page = { index, text } end
        function memo.setLockedBy(self, by) self.lockedBy = by end
        return memo
    end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    VehicleDistributions = { {} }
    SPAWNED = {}
    addVehicleDebug = function(script) SPAWNED[#SPAWNED + 1] = script return VEHICLE end
    IsoDirections = { getRandom = function() return "N" end }
    loadMod("server/MilitaryDrop/MilitaryDrop_Crate.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Server.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Notes.lua")
end

function T.outfit_filter()
    local isArmyOrPolice = MilitaryDrop.Notes.isArmyOrPolice
    assertTrue(isArmyOrPolice("ArmyCamoGreen"), "armée")
    assertTrue(isArmyOrPolice("Police_SWAT"), "police")
    assertTrue(isArmyOrPolice("Sheriff_Deputy"), "shérif")
    assertTrue(not isArmyOrPolice("PoliceStripper"), "déguisement exclu")
    assertTrue(not isArmyOrPolice(nil), "sans tenue : pas de note (bug B41)")
    assertTrue(not isArmyOrPolice("Farmer"), "civil")
end

function T.memo_has_frequency_code_and_lock()
    local zombie = makeZombie("ArmyCamoGreen")
    MilitaryDrop.Notes.onZombieDead(zombie)
    local memo = zombie.items[1]
    assertEq(memo.fullType, "MilitaryDrop.MilitaryMemo", "note ajoutée")
    assertEq(memo.page[2], "IGUI_MilitaryDrop_Note_1|151.4|BRAVO-KILO-07", "fréquence et code")
    assertEq(memo.lockedBy, "MilitaryDrop", "verrouillée")
end

function T.civilian_gets_nothing_when_option_on()
    local zombie = makeZombie("Farmer")
    MilitaryDrop.Notes.onZombieDead(zombie)
    assertEq(#zombie.items, 0, "aucune note")
    SandboxVars.MilitaryDrop.NotesOnlyArmyPolice = false
    local other = makeZombie("Farmer")
    MilitaryDrop.Notes.onZombieDead(other)
    assertEq(#other.items, 1, "option désactivée : tous les zombies")
end

function T.failed_roll_is_remembered()
    local zombie = makeZombie("Police")
    ROLL = 1
    MilitaryDrop.Notes.onZombieDead(zombie)
    ROLL = 0
    MilitaryDrop.Notes.onZombieDead(zombie)
    assertEq(#zombie.items, 0, "pas de second tirage")
end

function T.memo_restored_after_second_death_event()
    local zombie = makeZombie("Police")
    MilitaryDrop.Notes.onZombieDead(zombie)
    for i = #zombie.items, 1, -1 do
        zombie.items[i] = nil
    end
    MilitaryDrop.Notes.onZombieDead(zombie)
    assertEq(#zombie.items, 1, "note remise")
    MilitaryDrop.Notes.onZombieDead(zombie)
    assertEq(#zombie.items, 1, "pas de doublon")
end

return T
