-- ============================================================================
-- Military Drop — notes militaires et carnet de codes (serveur MP ou solo)
--
-- Documents affichés comme les journaux du jeu (« Inspecter », printMedia :
-- MilitaryDrop_Documents.lua), écrits par le serveur à la création de l'objet
-- dans modData.printMedia, donc dans sa langue :
--   * note (MilitaryDrop.MilitaryMemo) : fréquence militaire et, selon
--     l'option AuthCode : 1 aucun code ; 2 code fixe ; 3 code de la semaine et
--     sa date de fin ; 4 fréquence de la station de chiffres ;
--   * carnet (MilitaryDrop.Codebook, AuthCode 4) : la table qui déchiffre les
--     groupes de la station. Un seul carnet par partie : la table est fixe,
--     seul le code change chaque semaine. Le déchiffrement se fait de tête :
--     la graine ne quitte jamais le serveur.
--
-- Note et carnet sont ajoutés à l'inventaire du zombie dans OnZombieDead,
-- avant la création du cadavre qui le reprend (IsoZombie.onKilled, 42.21). Sur
-- un client MP, l'ajout n'aurait aucune autorité : ce fichier ne tourne que
-- sur le serveur ou en solo. Le carnet est aussi ajouté aux listes de butin
-- de l'armée (sources, aucun nom d'objet vanilla), à OnInitGlobalModData : en
-- solo, les options sandbox de la partie ne sont connues qu'à ce moment.
--
-- Mort par le feu : OnZombieDead peut arriver deux fois et le second passage
-- vide l'inventaire. Le tirage est mémorisé sur le zombie ; l'objet est remis
-- s'il a disparu.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Server"
require "MilitaryDrop/MilitaryDrop_NumbersStation"
require "MilitaryDrop/MilitaryDrop_Documents"

local Config = MilitaryDrop.Config
local Codes = MilitaryDrop.Codes
local Secrets = MilitaryDrop.Secrets
local Documents = MilitaryDrop.Documents

local Notes = {}
MilitaryDrop.Notes = Notes

Notes.ITEM = "MilitaryDrop.MilitaryMemo"
Notes.CODEBOOK_ITEM = "MilitaryDrop.Codebook"
-- Tirage d'un texte de note (1 à TEXT_COUNT), ramené au nombre de textes du mode.
Notes.TEXT_COUNT = 8
-- Options NoteDropRate et CodebookDropRate (1 à 6) : une chance sur N.
Notes.RATES = { 1000, 500, 100, 50, 25, 2 }
-- Textes de la note selon le mode du code : préfixe des clés et nombre.
Notes.FAMILIES = {
    [Codes.MODE_NONE] = { prefix = "IGUI_MilitaryDrop_NoteOpen_", count = 4 },
    [Codes.MODE_FIXED] = { prefix = "IGUI_MilitaryDrop_Note_", count = 8 },
    [Codes.MODE_WEEKLY_PLAIN] = { prefix = "IGUI_MilitaryDrop_NoteWeek_", count = 4 },
    [Codes.MODE_WEEKLY_CIPHER] = { prefix = "IGUI_MilitaryDrop_NoteCipher_", count = 4 },
}
-- Listes de butin de l'armée qui reçoivent le carnet, avec un poids
-- CODEBOOK_LOOT_FACTOR / N (N : option CodebookDropRate).
Notes.CODEBOOK_LISTS = { "ArmyBunkerLockers", "ArmyStorageElectronics", "ArmyStorageOutfit" }
Notes.CODEBOOK_LOOT_FACTOR = 50
-- Tenues ciblées : options NoteOutfits, CodebookOutfits et NoteOutfitsExcluded
-- (mots contenus dans le nom de la tenue, séparés par « ; »), pour suivre les
-- tenues des mods.

local MEMO_KEY = "MilitaryDrop_note"
local CODEBOOK_KEY = "MilitaryDrop_codebook"

local function containsAny(text, words)
    for _, word in ipairs(words) do
        if string.find(text, word, 1, true) then
            return true
        end
    end
    return false
end

--- Tenue désignée par l'option listName (NoteOutfits par défaut), hors tenues exclues.
function Notes.outfitMatches(outfitName, listName)
    if type(outfitName) ~= "string" then
        return false
    end
    local lower = string.lower(outfitName)
    return containsAny(lower, Config.getList(listName or "NoteOutfits"))
        and not containsAny(lower, Config.getList("NoteOutfitsExcluded"))
end

--- Tenue ciblée par les notes (nom d'outfit vanilla ou de mod).
function Notes.isArmyOrPolice(outfitName)
    return Notes.outfitMatches(outfitName, "NoteOutfits")
end

function Notes.dropRate()
    return Notes.RATES[Config.get("NoteDropRate")] or 50
end

function Notes.codebookRate()
    return Notes.RATES[Config.get("CodebookDropRate")] or 100
end

--- « 18 JUL » pour un jour compté depuis le 1970-01-01.
function Notes.formatDay(days)
    local _, month, day = Codes.civilFromDays(days)
    return string.format("%02d %s", day, getText("IGUI_MilitaryDrop_Month_" .. month))
end

--- « 18 JUL 1993 ».
function Notes.formatDate(days)
    local year = Codes.civilFromDays(days)
    return Notes.formatDay(days) .. " " .. year
end

--- Jour (depuis le 1970-01-01) et heure « 14:30 » d'une horloge du calendrier.
function Notes.splitClock(clock)
    local dayIndex = math.floor(clock / 24)
    local minutes = math.floor((clock - dayIndex * 24) * 60 + 0.5)
    if minutes >= 24 * 60 then
        minutes = 24 * 60 - 1
    end
    -- L'horloge compte depuis le lundi 1969-12-29, trois jours avant l'époque.
    return dayIndex - 3, string.format("%02d:%02d", math.floor(minutes / 60), minutes % 60)
end

--- L'objet porte déjà son document.
function Notes.hasDocument(item)
    return item:getModData().printMedia ~= nil
end

-- ----------------------------------------------------------------------------
-- Note militaire
-- ----------------------------------------------------------------------------

--- Fréquence de la station de chiffres, affichable.
function Notes.stationText()
    local station = MilitaryDrop.NumbersStation.frequency
    return station and Config.formatChannel(station) or "?"
end

--- Texte n° index de la note, selon le mode du code.
function Notes.memoText(index)
    local mode = Config.codeMode()
    local family = Notes.FAMILIES[mode]
    local key = family.prefix .. ((index - 1) % family.count + 1)
    local frequency = Config.formatChannel(Config.getChannel())
    if mode == Codes.MODE_NONE then
        return getText(key, frequency)
    elseif mode == Codes.MODE_FIXED then
        return getText(key, frequency, MilitaryDrop.Server.getCode())
    elseif mode == Codes.MODE_WEEKLY_PLAIN then
        local clock = MilitaryDrop.Server.clock()
        local lastDay = Codes.weekStartDay(Codes.weekOf(clock)) + 6
        return getText(key, frequency, MilitaryDrop.Server.getCode(clock), Notes.formatDay(lastDay))
    end
    return getText(key, frequency, Notes.stationText())
end

--- Annotation manuscrite de la note, selon le mode du code.
function Notes.memoHand()
    local mode = Config.codeMode()
    if mode == Codes.MODE_NONE then
        return getText("IGUI_MilitaryDrop_Doc_Memo_Hand_Open")
    elseif mode == Codes.MODE_FIXED then
        return getText("IGUI_MilitaryDrop_Doc_Memo_Hand_Code", MilitaryDrop.Server.getCode())
    elseif mode == Codes.MODE_WEEKLY_PLAIN then
        local clock = MilitaryDrop.Server.clock()
        local lastDay = Codes.weekStartDay(Codes.weekOf(clock)) + 6
        return getText("IGUI_MilitaryDrop_Doc_Memo_Hand_Week", MilitaryDrop.Server.getCode(clock),
            Notes.formatDay(lastDay))
    end
    return getText("IGUI_MilitaryDrop_Doc_Memo_Hand_Station", Notes.stationText())
end

--- Document de la note n° index : numéro de série et tache tirés au hasard,
--- date du jour.
function Notes.memoMedia(index)
    local days = Notes.splitClock(MilitaryDrop.Server.clock())
    return Documents.memo({
        serial = tostring(ZombRand(1000, 10000)),
        date = Notes.formatDate(days),
        body = Notes.memoText(index),
        frequency = Config.formatChannel(Config.getChannel()),
        hand = Notes.memoHand(),
        stain = ZombRand(3) == 0,
    })
end

--- Écrit la note n° index.
function Notes.fillMemo(memo, index)
    memo:getModData().printMedia = Notes.memoMedia(index)
end

--- Crée la note avec le texte n° index (son OnCreate en a déjà tiré un).
function Notes.createMemo(index)
    local memo = instanceItem(Notes.ITEM)
    if not memo then
        return nil
    end
    Notes.fillMemo(memo, index)
    return memo
end

-- ----------------------------------------------------------------------------
-- Carnet de codes
-- ----------------------------------------------------------------------------

--- Lignes de la table : { number, word } triées par nombre.
function Notes.tableEntries(numbers)
    local entries = {}
    for i, number in ipairs(numbers) do
        entries[#entries + 1] = { number = number, word = Codes.WORDS[i] }
    end
    table.sort(entries, function(a, b) return a.number < b.number end)
    return entries
end

--- Écrit le carnet : la table de la partie, en dossier kraft.
function Notes.fillCodebook(book)
    book:getModData().printMedia = Documents.codebook({
        entries = Notes.tableEntries(Codes.cipherTable(Secrets.getSeed())),
    })
end

function Notes.createCodebook()
    local book = instanceItem(Notes.CODEBOOK_ITEM)
    if book and not Notes.hasDocument(book) then
        -- OnCreate l'a normalement déjà écrit.
        Notes.fillCodebook(book)
    end
    return book
end

-- ----------------------------------------------------------------------------
-- Butin et zombies
-- ----------------------------------------------------------------------------

--- Listes de butin de l'armée qui existent : { items, … }.
local function codebookListItems()
    local result = {}
    for _, name in ipairs(Notes.CODEBOOK_LISTS) do
        local list = ProceduralDistributions.list[name]
        if list and list.items then
            result[#result + 1] = list.items
        end
    end
    return result
end

--- Ajoute le carnet (et son poids) aux listes qui ne l'ont pas ; vrai si ajouté.
local function insertCodebook()
    local weight = Notes.CODEBOOK_LOOT_FACTOR / Notes.codebookRate()
    local added = false
    for _, items in ipairs(codebookListItems()) do
        local present = false
        for _, entry in ipairs(items) do
            present = present or entry == Notes.CODEBOOK_ITEM
        end
        if not present then
            table.insert(items, Notes.CODEBOOK_ITEM)
            table.insert(items, weight)
            added = true
        end
    end
    if added then
        MilitaryDrop.log("codebook added to army loot lists, weight " .. weight)
    end
    return added
end

--- Ajoute le carnet aux listes de butin de l'armée (AuthCode 4), une seule
--- fois, puis relit les tables (ItemPickerJava.Parse, idempotent).
function Notes.addCodebookToLoot()
    if Config.codeMode() ~= Codes.MODE_WEEKLY_CIPHER or not ProceduralDistributions then
        return false
    end
    local added = insertCodebook()
    if added then
        ItemPickerJava.Parse()
    end
    return added
end

--- Options AuthCode ou CodebookDropRate changées en cours de partie : le
--- carnet est retiré des listes (objet et poids qui le suit), remis avec le
--- nouveau poids en mode 4, puis les tables sont relues (ItemPickerJava.Parse,
--- comme le bouton « Appliquer » vanilla : IsoWorld.parseDistributions,
--- IsoWorld.java:3115-3118). Seuls les conteneurs remplis ensuite changent.
--- Vrai si les listes ont changé.
function Notes.refreshCodebookLoot()
    if not ProceduralDistributions then
        return false
    end
    local removed = false
    for _, items in ipairs(codebookListItems()) do
        for i = #items - 1, 1, -1 do
            if items[i] == Notes.CODEBOOK_ITEM and type(items[i + 1]) == "number" then
                table.remove(items, i + 1)
                table.remove(items, i)
                removed = true
            end
        end
    end
    local added = Config.codeMode() == Codes.MODE_WEEKLY_CIPHER and insertCodebook()
    if removed or added then
        ItemPickerJava.Parse()
        if not added then
            MilitaryDrop.log("codebook removed from army loot lists")
        end
    end
    return removed or added
end

--- Tirage de la note : index du texte, ou false.
local function rollMemo(zombie)
    if Config.get("NotesOnlyArmyPolice") and not Notes.isArmyOrPolice(zombie:getOutfitName()) then
        return false
    end
    if ZombRand(Notes.dropRate()) ~= 0 then
        return false
    end
    return ZombRand(Notes.TEXT_COUNT) + 1
end

--- Tirage du carnet (tenues militaires seulement, AuthCode 4).
local function rollCodebook(zombie)
    return Config.codeMode() == Codes.MODE_WEEKLY_CIPHER
        and Notes.outfitMatches(zombie:getOutfitName(), "CodebookOutfits")
        and ZombRand(Notes.codebookRate()) == 0
end

--- Tirage mémorisé sur le zombie (clé key), objet remis s'il a disparu.
local function dropOnce(zombie, key, roll, fullType, create)
    local modData = zombie:getModData()
    local value = modData[key]
    if value == nil then
        value = roll(zombie) or false
        modData[key] = value
    end
    if not value then
        return
    end
    local inventory = zombie:getInventory()
    if inventory:containsType(fullType) then
        return
    end
    local item = create(value)
    if item then
        inventory:AddItem(item)
        MilitaryDrop.log(fullType .. " dropped on " .. tostring(zombie:getOutfitName()))
    end
end

function Notes.onZombieDead(zombie)
    dropOnce(zombie, MEMO_KEY, rollMemo, Notes.ITEM, Notes.createMemo)
    dropOnce(zombie, CODEBOOK_KEY, rollCodebook, Notes.CODEBOOK_ITEM, Notes.createCodebook)
end

Events.OnZombieDead.Add(Notes.onZombieDead)
Events.OnInitGlobalModData.Add(Notes.addCodebookToLoot)
Config.onChange("Notes.codebookLoot", { "AuthCode", "CodebookDropRate" }, Notes.refreshCodebookLoot)

return Notes
