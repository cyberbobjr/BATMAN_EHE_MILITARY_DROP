-- ============================================================================
-- Military Drop — notes militaires sur les zombies morts (serveur MP ou solo)
--
-- Une note (MilitaryDrop.MilitaryMemo, une page verrouillée : « Lire »
-- seulement) donne la fréquence et le code de la partie. Elle est ajoutée à
-- l'inventaire du zombie dans OnZombieDead, avant la création du cadavre qui
-- le reprend (IsoZombie.onKilled, 42.21). Sur un client MP, l'ajout n'aurait
-- aucune autorité : ce fichier ne tourne que sur le serveur ou en solo.
--
-- Mort par le feu : OnZombieDead peut arriver deux fois et le second passage
-- vide l'inventaire. Le tirage est mémorisé sur le zombie ; la note est
-- remise si elle a disparu.
--
-- Le texte est écrit dans la langue du serveur (celle du joueur en solo).
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Server"

local Config = MilitaryDrop.Config

local Notes = {}
MilitaryDrop.Notes = Notes

Notes.ITEM = "MilitaryDrop.MilitaryMemo"
Notes.TEXT_COUNT = 8
Notes.LOCKED_BY = "MilitaryDrop"
-- Option NoteDropRate (1 à 6) : une chance sur N.
Notes.RATES = { 1000, 500, 100, 50, 25, 2 }
-- Tenues vanilla militaires et de police (clothing.xml, 42.21), en minuscules.
Notes.OUTFIT_WORDS = { "army", "police", "sheriff" }
Notes.OUTFIT_EXCLUDED = { "stripper" }

local MODDATA_KEY = "MilitaryDrop_note"

local function containsAny(text, words)
    for _, word in ipairs(words) do
        if string.find(text, word, 1, true) then
            return true
        end
    end
    return false
end

--- Tenue militaire ou de police (nom d'outfit vanilla ou de mod).
function Notes.isArmyOrPolice(outfitName)
    if type(outfitName) ~= "string" then
        return false
    end
    local lower = string.lower(outfitName)
    return containsAny(lower, Notes.OUTFIT_WORDS) and not containsAny(lower, Notes.OUTFIT_EXCLUDED)
end

function Notes.dropRate()
    return Notes.RATES[Config.get("NoteDropRate")] or 50
end

--- Crée la note (texte n° index) avec la fréquence et le code de la partie.
function Notes.createMemo(index)
    local memo = instanceItem(Notes.ITEM)
    if not memo then
        return nil
    end
    local frequency = Config.formatChannel(Config.getChannel())
    local code = MilitaryDrop.Server.getState().code
    memo:addPage(1, getText("IGUI_MilitaryDrop_Note_" .. index, frequency, code))
    memo:setLockedBy(Notes.LOCKED_BY)
    return memo
end

function Notes.onZombieDead(zombie)
    local modData = zombie:getModData()
    local index = modData[MODDATA_KEY]
    if index == nil then
        index = false
        if not Config.get("NotesOnlyArmyPolice") or Notes.isArmyOrPolice(zombie:getOutfitName()) then
            if ZombRand(Notes.dropRate()) == 0 then
                index = ZombRand(Notes.TEXT_COUNT) + 1
            end
        end
        modData[MODDATA_KEY] = index
    end
    if not index then
        return
    end
    local inventory = zombie:getInventory()
    if inventory:containsType(Notes.ITEM) then
        return
    end
    local memo = Notes.createMemo(index)
    if memo then
        inventory:AddItem(memo)
        MilitaryDrop.log("note " .. index .. " dropped on " .. tostring(zombie:getOutfitName()))
    end
end

Events.OnZombieDead.Add(Notes.onZombieDead)

return Notes
