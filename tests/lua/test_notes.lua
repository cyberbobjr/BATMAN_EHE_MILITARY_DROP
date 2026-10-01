-- MilitaryDrop_Notes : tenues ciblées, tirage mémorisé et note remise après
-- un second OnZombieDead (mort par le feu), texte selon le mode du code,
-- documents (note, carnet, message intercepté) relus comme le fait le jeu,
-- butin de l'armée.

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
    SandboxVars = { MilitaryDrop = { NoteDropRate = 6, NotesOnlyArmyPolice = true, AuthCode = 2,
        CodebookDropRate = 6, Frequency = 151.4 } }
    isClient = function() return false end
    isServer = function() return false end
    ModData = { getOrCreate = function() return {} end }
    FILES = {}
    getWorld = function()
        return { getGameMode = function() return "Sandbox" end, getWorld = function() return "Test Save" end }
    end
    getFileReader = function(name)
        local value = FILES[name]
        if not value then
            return nil
        end
        return { readLine = function() return value end, close = function() end }
    end
    getFileWriter = function(name)
        return { write = function(_, text) FILES[name] = text end, close = function() end }
    end
    FILES["MilitaryDrop/Sandbox_Test_Save_code.txt"] = "BRAVO-KILO-07"
    ROLL = 0
    ZombRand = function() return ROLL end
    getText = function(key, ...)
        local parts = { key }
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring((select(i, ...)))
        end
        return table.concat(parts, "|")
    end
    -- Calendrier : mercredi 14 juillet 1993, midi ; partie commencée le 9 juillet à 9 h.
    DATE = { year = 1993, month = 6, day = 13, hour = 12 }
    getGameTime = function()
        return {
            getYear = function() return DATE.year end,
            getMonth = function() return DATE.month end,
            getDay = function() return DATE.day end,
            getTimeOfDay = function() return DATE.hour end,
            getStartYear = function() return 1993 end,
            getStartMonth = function() return 6 end,
            getStartDay = function() return 8 end,
            getStartTimeOfDay = function() return 9 end,
        }
    end
    FILES["MilitaryDrop/Sandbox_Test_Save_seed.txt"] = "424242"
    instanceItem = function(fullType)
        local item = { fullType = fullType, modData = {} }
        function item.getModData(self) return self.modData end
        return item
    end
    PARSED = 0
    ItemPickerJava = { Parse = function() PARSED = PARSED + 1 end }
    ProceduralDistributions = { list = {
        ArmyBunkerLockers = { items = { "Base.Something", 4 } },
        ArmyStorageElectronics = { items = {} },
    } }
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
    loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Server.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Teams.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_NumbersStation.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_PrintMedia.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Documents.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Notes.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Memo.lua")
end

local function emptyMemo()
    return instanceItem("MilitaryDrop.MilitaryMemo")
end

local FONTS = {
    SdfRegular = true, SdfItalic = true, SdfBold = true, SdfBoldItalic = true, SdfOldRegular = true,
    SdfOldBold = true, SdfOldItalic = true, SdfOldBoldItalic = true, SdfRobertoSans = true, SdfCaveat = true,
}

local function split(text, sep)
    local parts, start = {}, 1
    while true do
        local i = string.find(text, sep, start, true)
        if not i then
            parts[#parts + 1] = string.sub(text, start)
            return parts
        end
        parts[#parts + 1] = string.sub(text, start, i - 1)
        start = i + 1
    end
end

--- Relit une mise en page comme PZAPI/ui/organisms/PrintMedia.lua (init) :
--- découpe sur « < », « > », « , » et « : » ; rend la liste des éléments.
local function parseMedia(info)
    local elements = {}
    for _, val in ipairs(split(info, "<")) do
        if val ~= "" then
            local data = split(val, ">")
            assertEq(#data, 2, "un seul « > » par élément : " .. val)
            local params = {}
            for _, v in ipairs(split(data[1], ",")) do
                local kv = split(v, ":")
                assertEq(#kv, 2, "paramètre « clé:valeur » : " .. v)
                params[kv[1]:gsub("^%s+", ""):gsub("%s+$", "")] = kv[2]:gsub("^%s+", ""):gsub("%s+$", "")
            end
            local kind = params.type
            assertTrue(kind == "parent" or kind == "text" or kind == "texture", "type connu : " .. tostring(kind))
            for key, value in pairs(params) do
                if key == "font" then
                    assertTrue(FONTS[value], "police vanilla : " .. value)
                elseif key == "texture" then
                    assertTrue(commonFileExists(value), "texture présente dans common : " .. value)
                elseif key ~= "type" then
                    assertTrue(tonumber(value) ~= nil, "valeur numérique : " .. key .. "=" .. value)
                end
            end
            elements[#elements + 1] = { params = params, content = data[2] }
        end
    end
    assertEq(elements[1].params.type, "parent", "taille de la page en premier")
    return elements
end

--- Contenus des éléments texte, concaténés.
local function textOf(elements)
    local list = {}
    for _, element in ipairs(elements) do
        if element.params.type == "text" then
            list[#list + 1] = element.content
        end
    end
    return table.concat(list, "\n")
end

local function media(item)
    return item:getModData().printMedia
end

function T.memo_created_anywhere_gets_a_document()
    local memo = emptyMemo()
    MilitaryDrop.Memo.onCreate(memo)
    local doc = media(memo)
    assertTrue(doc ~= nil, "document écrit (console, debug)")
    assertEq(doc.id, "MilitaryDrop_Memo", "identifiant sans zone de carte")
    assertTrue(doc.title:find("IGUI_MilitaryDrop_Doc_Memo_WindowTitle", 1, true) ~= nil, "titre de fenêtre")
    local text = textOf(parseMedia(doc.info))
    assertTrue(text:find("IGUI_MilitaryDrop_Note_1|151.4|BRAVO-KILO-07", 1, true) ~= nil, "texte de la note")
    assertTrue(text:find("IGUI_MilitaryDrop_Doc_Memo_Hand_Code|BRAVO-KILO-07", 1, true) ~= nil, "annotation")
    assertTrue(doc.text:find("IGUI_MilitaryDrop_Note_1|151.4|BRAVO-KILO-07", 1, true) ~= nil, "transcription")
end

function T.memo_on_client_or_already_written_is_untouched()
    local memo = emptyMemo()
    isClient = function() return true end
    MilitaryDrop.Memo.onCreate(memo)
    assertEq(media(memo), nil, "client MP : le serveur la remplit")
    isClient = function() return false end
    memo:getModData().printMedia = { id = "existing" }
    MilitaryDrop.Memo.onCreate(memo)
    assertEq(media(memo).id, "existing", "document existant conservé")
end

function T.memo_layout_parses_in_every_code_mode()
    MilitaryDrop.NumbersStation.frequency = 14600
    for mode = 1, 4 do
        SandboxVars.MilitaryDrop.AuthCode = mode
        for index = 1, 8 do
            local doc = MilitaryDrop.Notes.memoMedia(index)
            parseMedia(doc.info)
            assertTrue(not doc.info:find("%%"), "aucun % (le texte repasse par getText)")
        end
    end
end

--- Table du carnet d'après sa transcription : nombre → mot.
local function readTable(doc)
    local words = {}
    for number, word in string.gmatch(doc.text, "(%d%d)%s+(%u+)") do
        words[tonumber(number)] = word
    end
    return words
end

function T.codebook_deciphers_the_numbers_station()
    SandboxVars.MilitaryDrop.AuthCode = 4
    local book = instanceItem("MilitaryDrop.Codebook")
    MilitaryDrop.Notes.fillCodebook(book)
    local doc = media(book)
    local elements = parseMedia(doc.info)
    local words = readTable(doc)
    local count = 0
    for number, word in pairs(words) do
        count = count + 1
        local seen = false
        for i, element in ipairs(elements) do
            local nextElement = elements[i + 1]
            seen = seen or (element.content == string.format("%02d", number) and nextElement
                and nextElement.content == word)
        end
        assertTrue(seen, "grille : " .. word .. " à côté de son nombre")
    end
    assertEq(count, 26, "26 groupes dans la table")
    -- Ce que la station diffuse, déchiffré de tête avec le carnet,
    -- cette semaine puis dans trois semaines : un seul carnet suffit.
    for _ = 1, 2 do
        local lines = MilitaryDrop.NumbersStation.message(MilitaryDrop.Server.clock())
        local x, y, digits = lines[2]:match("(%d%d)%-(%d%d)%-(%d%d)")
        assertEq(words[tonumber(x)] .. "-" .. words[tonumber(y)] .. "-" .. digits, MilitaryDrop.Server.getCode(),
            "le carnet déchiffre le code de la semaine")
        DATE.day = DATE.day + 21
    end
end

function T.every_codebook_is_the_same()
    local a, b = instanceItem("MilitaryDrop.Codebook"), instanceItem("MilitaryDrop.Codebook")
    MilitaryDrop.Notes.fillCodebook(a)
    DATE.month = 9
    MilitaryDrop.Notes.fillCodebook(b)
    assertEq(media(a).info, media(b).info, "même document, quelle que soit la date")
end

function T.codebook_on_create_is_server_only()
    local book = instanceItem("MilitaryDrop.Codebook")
    isClient = function() return true end
    MilitaryDrop.Memo.onCreateCodebook(book)
    assertEq(media(book), nil, "client MP : le serveur l'écrit")
    isClient = function() return false end
    MilitaryDrop.Memo.onCreateCodebook(book)
    assertTrue(media(book) ~= nil, "serveur ou solo : écrit")
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

function T.outfits_come_from_sandbox_options()
    SandboxVars.MilitaryDrop.NoteOutfits = " Ranger ; PrisonGuard;"
    SandboxVars.MilitaryDrop.NoteOutfitsExcluded = ""
    local isArmyOrPolice = MilitaryDrop.Notes.isArmyOrPolice
    assertTrue(isArmyOrPolice("Ranger"), "tenue listée (espaces ignorés)")
    assertTrue(isArmyOrPolice("PrisonGuard"), "tenue d'un autre mod ou vanilla")
    assertTrue(not isArmyOrPolice("ArmyCamoGreen"), "tenue non listée")
end

function T.memo_on_a_dead_soldier_has_frequency_and_code()
    local zombie = makeZombie("ArmyCamoGreen")
    MilitaryDrop.Notes.onZombieDead(zombie)
    local memo = zombie.items[1]
    assertEq(memo.fullType, "MilitaryDrop.MilitaryMemo", "note ajoutée")
    assertTrue(memo:getModData().printMedia.info:find("IGUI_MilitaryDrop_Note_1|151.4|BRAVO-KILO-07", 1, true) ~= nil,
        "fréquence et code")
end

function T.free_frequency_is_written_on_the_notes()
    SandboxVars.MilitaryDrop.Frequency = 0
    ChannelCategory = { Military = "Military" }
    local channels = {}
    DynamicRadioChannel = { new = function(_, freq, _, uuid) return { freq = freq, uuid = uuid } end }
    getZomboidRadio = function() return { removeChannelName = function() end } end
    local manager = {
        AddChannel = function(_, channel) channels[channel.uuid] = channels[channel.uuid] or channel end,
        getRadioChannel = function(_, uuid) return channels[uuid] end,
    }
    loadMod("server/MilitaryDrop/MilitaryDrop_Broadcast.lua")
    triggerEvent("OnLoadRadioScripts", manager, false)
    local frequency = MilitaryDrop.Broadcast.frequency
    assertTrue(frequency >= 120000 and frequency <= 170000, "fréquence tirée : " .. tostring(frequency))
    local text = MilitaryDrop.Config.formatChannel(frequency)
    assertEq(MilitaryDrop.Notes.memoText(1), "IGUI_MilitaryDrop_Note_1|" .. text .. "|BRAVO-KILO-07",
        "la note écrit la fréquence réelle")
    assertTrue(MilitaryDrop.Notes.memoMedia(1).info:find(text, 1, true) ~= nil, "document de la note aussi")
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

function T.memo_text_follows_the_code_option()
    SandboxVars.MilitaryDrop.AuthCode = 1
    assertEq(MilitaryDrop.Notes.memoText(2), "IGUI_MilitaryDrop_NoteOpen_2|151.4", "sans code : fréquence seule")
    SandboxVars.MilitaryDrop.AuthCode = 3
    local code = MilitaryDrop.Server.getCode()
    assertTrue(code ~= "BRAVO-KILO-07", "code de la semaine, pas le code fixe")
    assertEq(MilitaryDrop.Notes.memoText(1), "IGUI_MilitaryDrop_NoteWeek_1|151.4|" .. code .. "|18 IGUI_MilitaryDrop_Month_7",
        "code de la semaine, valable jusqu'au dimanche 18 juillet")
    assertEq(MilitaryDrop.Notes.memoText(6), "IGUI_MilitaryDrop_NoteWeek_2|151.4|" .. code .. "|18 IGUI_MilitaryDrop_Month_7",
        "tirage 6 ramené aux 4 textes du mode")
    SandboxVars.MilitaryDrop.AuthCode = 4
    MilitaryDrop.NumbersStation.frequency = 14600
    assertEq(MilitaryDrop.Notes.memoText(3), "IGUI_MilitaryDrop_NoteCipher_3|151.4|14.6",
        "chiffré : fréquence de la station, sans code")
end

local function codebooks(zombie)
    local n = 0
    for _, item in ipairs(zombie.items) do
        n = n + (item.fullType == "MilitaryDrop.Codebook" and 1 or 0)
    end
    return n
end

function T.codebook_only_on_army_zombies_in_encrypted_mode()
    local army = makeZombie("ArmyCamoGreen")
    MilitaryDrop.Notes.onZombieDead(army)
    assertEq(codebooks(army), 0, "code fixe : aucun carnet")
    SandboxVars.MilitaryDrop.AuthCode = 4
    army = makeZombie("ArmyCamoGreen")
    MilitaryDrop.Notes.onZombieDead(army)
    assertEq(codebooks(army), 1, "chiffré : carnet sur un militaire")
    assertEq(#army.items, 2, "avec la note")
    local police = makeZombie("Police")
    MilitaryDrop.Notes.onZombieDead(police)
    assertEq(codebooks(police), 0, "pas sur un policier")
    for i = #army.items, 1, -1 do
        army.items[i] = nil
    end
    MilitaryDrop.Notes.onZombieDead(army)
    assertEq(codebooks(army), 1, "carnet remis après un second OnZombieDead")
end

function T.codebook_added_once_to_army_loot_in_encrypted_mode()
    local lockers = ProceduralDistributions.list.ArmyBunkerLockers.items
    assertEq(MilitaryDrop.Notes.addCodebookToLoot(), false, "code fixe : rien")
    assertEq(#lockers, 2, "liste inchangée")
    SandboxVars.MilitaryDrop.AuthCode = 4
    assertEq(MilitaryDrop.Notes.addCodebookToLoot(), true, "chiffré : ajouté")
    assertEq(lockers[3], "MilitaryDrop.Codebook", "objet du mod")
    assertEq(lockers[4], 25, "poids 50 / 2 (option Débogage)")
    assertEq(ProceduralDistributions.list.ArmyStorageElectronics.items[1], "MilitaryDrop.Codebook", "autre liste")
    assertEq(PARSED, 1, "tables relues")
    assertEq(MilitaryDrop.Notes.addCodebookToLoot(), false, "pas deux fois")
    assertEq(#lockers, 4, "aucun doublon")
    assertEq(PARSED, 1, "pas de seconde relecture")
end

return T
