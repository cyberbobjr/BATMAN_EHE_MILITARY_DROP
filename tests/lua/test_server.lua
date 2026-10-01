-- MilitaryDrop_Server : décision sur une demande de largage, délai global,
-- anti-rafale, code (fixe, de la semaine, grâce, silence après des codes faux)
-- et envoi des réponses.

local T = {}

-- Carte simulée : par défaut, une route couvre toute la carte (le point tiré
-- est donc retenu tel quel). ROADS (liste { x, y, w, h }) remplace ce réseau ;
-- les bâtiments : aucun.
local function stubList(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end
function TEST_ZONES(x, y, w, h)
    local roads = ROADS or { { x = 0, y = 0, w = 100000, h = 100000 } }
    local found = {}
    for _, r in ipairs(roads) do
        if r.x < x + w and x < r.x + r.w and r.y < y + h and y < r.y + r.h then
            found[#found + 1] = {
                getType = function() return "Nav" end, isRectangle = function() return true end,
                getX = function() return r.x end, getY = function() return r.y end,
                getWidth = function() return r.w end, getHeight = function() return r.h end,
            }
        end
    end
    return stubList(found)
end

local CHANNEL = 151400
local CODE = "BRAVO-KILO-07"

--- Radio d'inventaire simulée.
local function makeRadio(on, channel, highTier)
    local data = {
        getIsHighTier = function() return highTier ~= false end,
        getIsPortable = function() return true end,
        getIsTurnedOn = function() return on end,
        getChannel = function() return channel end,
    }
    return {
        kind = "Radio",
        getID = function() return 7 end,
        getDeviceData = function() return data end,
        getContainer = function() return nil end,
    }
end

--- Joueur simulé ; where = "hand" (défaut), "back" ou "bag".
local function makePlayer(radio, where)
    where = where or "hand"
    local square = { getX = function() return 100 end, getY = function() return 200 end }
    return {
        getUsername = function() return "tester" end,
        getX = function() return 100.5 end,
        getY = function() return 200.5 end,
        getPrimaryHandItem = function() return where == "hand" and radio or nil end,
        getSecondaryHandItem = function() return nil end,
        getClothingItem_Back = function() return where == "back" and radio or nil end,
        getInventory = function() return { getItemWithID = function() return radio end } end,
        getCurrentSquare = function() return square end,
    }
end

function T.setup()
    -- Objet créé par le serveur (repli au sol des caisses).
    instanceItem = function(fullType)
        local item = { fullType = fullType, modData = {} }
        function item.getModData(self) return self.modData end
        function item.setName(self, text) self.name = text end
        function item.setCustomName(self, value) self.customName = value end
        return item
    end
    SandboxVars = { MilitaryDrop = { CooldownHours = 168, AuthCode = 2, Frequency = 151.4,
        MinZombies = 0, MaxZombies = 0, CaseRolls = 2 } }
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return object ~= nil and object.kind == class end
    Capability = { MakeEventsAlarmGunshot = "MakeEventsAlarmGunshot" }
    ALLOWED = true
    checkPermissions = function() return ALLOWED end
    MODDATA = {}
    ModData = { getOrCreate = function(tag)
        MODDATA[tag] = MODDATA[tag] or {}
        return MODDATA[tag]
    end }
    ZombRand = function() return 0 end
    ZombRandFloat = function(low) return low end
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
    WORLD_HOURS = 1000
    -- Calendrier du jeu : mercredi 14 juillet 1993, midi (mois et jour depuis 0).
    DATE = { year = 1993, month = 6, day = 13, hour = 12 }
    getGameTime = function()
        return {
            getWorldAgeHours = function() return WORLD_HOURS end,
            getYear = function() return DATE.year end,
            getMonth = function() return DATE.month end,
            getDay = function() return DATE.day end,
            getTimeOfDay = function() return DATE.hour end,
        }
    end
    PLACED = {}
    PLACED_ITEMS = {}
    LANDING = {
        getX = function() return 115 end, getY = function() return 200 end,
        isOutside = function() return true end, isFree = function() return true end,
        isWaterSquare = function() return false end,
        getVehicleContainer = function() return nil end,
        -- Repli au sol : objet créé (instanceItem), marqué, puis posé.
        AddWorldInventoryItem = function(_, item, _, _, _, transmit)
            assert(type(item) == "table" and transmit == true, "objet déjà créé, transmis à la pose")
            PLACED[#PLACED + 1] = item.fullType
            PLACED_ITEMS[#PLACED_ITEMS + 1] = item
            return item
        end,
    }
    getCell = function() return { getGridSquare = function() return LANDING end } end
    spawnHorde = function() end
    SOUNDS = {}
    addSound = function(_, x, y, z, radius, volume) SOUNDS[#SOUNDS + 1] = { x, y, radius, volume } end
    PLAYER = makePlayer(makeRadio(true, CHANNEL))
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function() return PLAYER end
    getText = function(key, a, b) return key .. "|" .. tostring(a) .. "|" .. tostring(b) end
    FILES = {}
    getWorld = function()
        return {
            getGameMode = function() return "Sandbox" end,
            getWorld = function() return "Test Save" end,
        getMetaGrid = function()
            return {
                isValidSquare = function(_, x, y) return not (OFF_MAP and OFF_MAP(x, y)) end,
                getCellData = function() return { getBuildingsIntersecting = function() end } end,
                getBuildingAt = function(_, x, y) return BUILDING and BUILDING(x, y) or nil end,
                getZonesIntersecting = function(_, x, y, _z, w, h) return TEST_ZONES(x, y, w, h) end,
            }
        end,
        }
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
    ChannelCategory = { Military = "Military" }
    AIRING = nil
    DynamicRadioChannel = { new = function(name, freq)
        return {
            freq = freq,
            getAiringBroadcast = function() return AIRING end,
            setAiringBroadcast = function(_, bc) AIRING = bc end,
        }
    end }
    RadioBroadCast = { new = function()
        return { lines = {}, AddRadioLine = function(self, line) self.lines[#self.lines + 1] = line end }
    end }
    RadioLine = { new = function(text, r, g, b, codes) return { text = text, codes = codes } end }
    getZomboidRadio = function() return { removeChannelName = function() end } end
    CHANNELS = {}
    SCRIPT_MANAGER = {
        AddChannel = function(_, channel) CHANNELS[#CHANNELS + 1] = channel end,
        getRadioChannel = function() return CHANNELS[1] end,
    }
    FILES["MilitaryDrop/Sandbox_Test_Save_code.txt"] = CODE
    SENT = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Flight.lua")
    VehicleDistributions = { {} }
    SPAWNED = {}
    addVehicleDebug = function(script) SPAWNED[#SPAWNED + 1] = script return VEHICLE end
    IsoDirections = { getRandom = function() return "N" end }
    loadMod("server/MilitaryDrop/MilitaryDrop_Crate.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    getActivatedMods = function() return { size = function() return 0 end } end
    loadMod("server/MilitaryDrop/MilitaryDrop_Smoke.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Server.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Teams.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Broadcast.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Flights.lua")
    MilitaryDrop.Client = { onServerCommand = function(_, command, args)
        SENT[#SENT + 1] = { command = command, args = args }
    end }
end

--- Crée la chaîne militaire (annonces) comme au chargement du monde.
local function withChannel()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
end

local function evaluate(radio, args)
    return MilitaryDrop.Server.evaluate(makePlayer(radio), args, WORLD_HOURS)
end

local function request(code)
    return { requestId = 1, radio = { kind = "item", id = 7 }, code = code }
end

function T.accepts_good_radio_and_code()
    assertEq(evaluate(makeRadio(true, CHANNEL), request("bravo kilo 07")), "accepted", "demande valide")
end

function T.refusal_order_hides_the_code_and_cooldown()
    assertEq(evaluate(makeRadio(false, CHANNEL), request("x")), "radioOff", "radio éteinte d'abord")
    assertEq(evaluate(makeRadio(true, 107400), request(CODE)), "noAnswer", "mauvais canal")
    MilitaryDrop.Server.getState().lastDropHours = WORLD_HOURS
    assertEq(evaluate(makeRadio(true, CHANNEL), request("x")), "noAnswer",
        "mauvais code : même réponse qu'un mauvais canal, délai non révélé")
    local status, hours = evaluate(makeRadio(true, CHANNEL), request(CODE))
    assertEq(status, "cooldown", "délai global")
    assertEq(hours, 210, "heures restantes : 168 × 1,25 à la note de départ 25")
end

function T.radio_must_be_in_hand_or_on_the_back()
    local args = request(CODE)
    assertEq(MilitaryDrop.Server.evaluate(makePlayer(makeRadio(true, CHANNEL), "back"), args, WORLD_HOURS),
        "accepted", "radio portée sur le dos")
    assertEq(MilitaryDrop.Server.evaluate(makePlayer(makeRadio(true, CHANNEL), "bag"), args, WORLD_HOURS),
        "noRadio", "radio rangée : elle n'entendrait pas la chaîne en solo")
end

function T.non_military_or_unknown_radio_is_refused()
    assertEq(evaluate(makeRadio(true, CHANNEL, false), request(CODE)), "notMilitary", "radio civile")
    assertEq(evaluate(nil, request(CODE)), "noRadio", "référence introuvable")
    assertEq(evaluate(makeRadio(true, CHANNEL), "junk"), "invalid", "arguments illisibles")
end

function T.code_not_required_when_option_off()
    SandboxVars.MilitaryDrop.AuthCode = 1
    assertEq(evaluate(makeRadio(true, CHANNEL), request(nil)), "accepted", "sans code")
end

local SEED = 424242

--- Code de la semaine du calendrier (DATE), pour la graine de test.
local function weeklyCode(dayOffset)
    local Codes = MilitaryDrop.Codes
    local clock = Codes.clockHours(DATE.year, DATE.month, DATE.day + (dayOffset or 0), DATE.hour)
    return Codes.weeklyCode(SEED, Codes.weekOf(clock))
end

function T.weekly_code_changes_on_monday_with_24_hours_of_grace()
    SandboxVars.MilitaryDrop.AuthCode = 3
    FILES["MilitaryDrop/Sandbox_Test_Save_seed.txt"] = tostring(SEED)
    DATE.day, DATE.hour = 17, 23.5 -- dimanche 18 juillet, 23:30
    local old = weeklyCode()
    assertEq(MilitaryDrop.Server.getCode(), old, "code de la semaine")
    assertEq(evaluate(makeRadio(true, CHANNEL), request(old)), "accepted", "dimanche soir")
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "noAnswer", "code fixe ignoré")
    DATE.day, DATE.hour = 18, 1 -- lundi 19 juillet, 01:00
    local new = weeklyCode()
    assertTrue(new ~= old, "nouveau code le lundi")
    assertEq(evaluate(makeRadio(true, CHANNEL), request(new)), "accepted", "nouveau code")
    assertEq(evaluate(makeRadio(true, CHANNEL), request(old)), "accepted", "ancien code pendant la grâce")
    DATE.day, DATE.hour = 19, 0.5 -- mardi 00:30
    assertEq(evaluate(makeRadio(true, CHANNEL), request(old)), "noAnswer", "ancien code après 24 h")
end

function T.three_wrong_codes_silence_the_caller_until_the_next_day()
    for i = 1, MilitaryDrop.Server.FAILED_CODE_LIMIT do
        assertEq(evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-0" .. i)), "noAnswer", "code faux " .. i)
    end
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "noAnswer",
        "silence : même le bon code reçoit la réponse d'un mauvais canal")
    DATE.hour = 23.9
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "noAnswer", "jusqu'à minuit")
    DATE.day, DATE.hour = DATE.day + 1, 0.1
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "accepted", "le lendemain")
end

function T.wrong_frequency_and_good_code_reset_the_count()
    for _ = 1, 5 do
        evaluate(makeRadio(true, 107400), request("ALPHA-ALPHA-01"))
    end
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "accepted", "mauvais canal : non compté")
    evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-01"))
    evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-02"))
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "accepted", "bon code : compteur remis à zéro")
    evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-03"))
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "accepted", "un seul code faux depuis")
end

function T.silence_is_per_player()
    for i = 1, MilitaryDrop.Server.FAILED_CODE_LIMIT do
        evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-0" .. i))
    end
    local other = makePlayer(makeRadio(true, CHANNEL))
    other.getUsername = function() return "other" end
    assertEq(MilitaryDrop.Server.evaluate(other, request(CODE), WORLD_HOURS), "accepted", "autre joueur")
end

--- Toutes les chaînes et nombres de la ModData, à plat.
local function modDataValues()
    local values = {}
    local function walk(t)
        for _, v in pairs(t) do
            if type(v) == "table" then
                walk(v)
            else
                values[#values + 1] = tostring(v)
            end
        end
    end
    walk(MODDATA.MilitaryDrop or {})
    return table.concat(values, "|")
end

function T.no_secret_or_failure_count_in_mod_data()
    SandboxVars.MilitaryDrop.AuthCode = 4
    FILES["MilitaryDrop/Sandbox_Test_Save_seed.txt"] = tostring(SEED)
    for i = 1, 4 do
        evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-0" .. i))
    end
    DATE.day = DATE.day + 1
    MilitaryDrop.Server.handleRequest(PLAYER, request(weeklyCode()))
    assertEq(#MilitaryDrop.Server.getState().flights, 1, "largage accepté")
    local values = modDataValues()
    assertTrue(values:find(tostring(SEED), 1, true) == nil, "graine absente de la ModData")
    assertTrue(values:find(weeklyCode(), 1, true) == nil, "code absent de la ModData")
    assertTrue(values:find("ALPHA-ALPHA", 1, true) == nil, "codes saisis absents de la ModData")
    local state = MilitaryDrop.Server.getState()
    assertTrue(state.failedCodes == nil and state.code == nil and state.seed == nil,
        "ni compteur de codes faux, ni code, ni graine dans l'état lisible")
end

function T.private_state_is_named_from_the_seed()
    FILES["MilitaryDrop/Sandbox_Test_Save_seed.txt"] = tostring(SEED)
    local tag = MilitaryDrop.Secrets.privateTag()
    assertTrue(tag:match("^MilitaryDrop_%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil, "nom privé : " .. tag)
    assertTrue(tag:find(tostring(SEED), 1, true) == nil, "la graine n'y est pas en clair")
    assertEq(MilitaryDrop.Secrets.privateState(), MODDATA[tag], "ModData globale de ce nom")
    -- Même graine (nouveau chargement du Lua) : même nom.
    loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
    assertEq(MilitaryDrop.Secrets.privateTag(), tag, "nom stable pour une même graine")
    FILES["MilitaryDrop/Sandbox_Test_Save_seed.txt"] = tostring(SEED + 1)
    loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
    assertTrue(MilitaryDrop.Secrets.privateTag() ~= tag, "autre partie, autre nom")
end

function T.private_state_is_read_again_after_the_mod_data_reset()
    local before = MilitaryDrop.Secrets.privateState()
    before.marker = true
    -- GlobalModData.init vide toutes les tables et relit la sauvegarde.
    MODDATA = {}
    assertEq(MilitaryDrop.Secrets.privateState().marker, nil, "table relue, pas gardée d'avant")
end

function T.seed_is_generated_once_and_written()
    local first = MilitaryDrop.Secrets.getSeed()
    assertEq(FILES["MilitaryDrop/Sandbox_Test_Save_seed.txt"], tostring(first), "écrite dans le fichier de la partie")
    assertTrue(MilitaryDrop.Codes.validSeed(first) ~= nil, "graine valable")
    assertEq(MilitaryDrop.Secrets.getSeed(), first, "graine conservée")
end

function T.force_needs_permission_and_skips_checks()
    local args = request(nil)
    args.force = true
    ALLOWED = false
    assertEq(evaluate(makeRadio(false, 1), args), "denied", "sans droit admin")
    ALLOWED = true
    assertEq(evaluate(makeRadio(false, 1), args), "accepted", "admin : radio éteinte et mauvais canal permis")
end

function T.forced_drop_needs_no_radio_in_hand()
    local args = request(nil)
    args.force = true
    local status, radio = MilitaryDrop.Server.evaluate(makePlayer(makeRadio(true, CHANNEL), "bag"), args, WORLD_HOURS)
    assertEq(status, "accepted", "admin : radio rangée acceptée")
    assertEq(radio, nil, "pas de radio : l'appel part de la position du joueur")
    MilitaryDrop.Server.handleRequest(makePlayer(makeRadio(true, CHANNEL), "bag"), args)
    assertEq(#MilitaryDrop.Server.getState().flights, 1, "vol lancé")
end

function T.cooldown_expires()
    local state = MilitaryDrop.Server.getState()
    -- Équipe neuve (note 25) : délai de 168 × 1,25 = 210 h.
    state.lastDropHours = WORLD_HOURS - 210
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "accepted", "délai écoulé")
end

--- Fait voler tous les vols en cours jusqu'à t secondes (pas de 0,25 s).
local function fly(seconds)
    for _ = 1, math.ceil(seconds / 0.25) do
        local flights = MilitaryDrop.Server.getState().flights
        for i = #flights, 1, -1 do
            MilitaryDrop.Flights.advance(flights[i], 0.25)
        end
    end
end

local function commands()
    local list = {}
    for _, sent in ipairs(SENT) do
        list[#list + 1] = sent.command
    end
    return table.concat(list, ",")
end

function T.accepted_request_launches_a_flight_then_drops()
    withChannel()
    MilitaryDrop.Server.handleRequest(PLAYER, request(CODE))
    assertEq(MilitaryDrop.Server.getState().lastDropHours, WORLD_HOURS, "délai démarré")
    assertEq(SENT[1].args.status, "accepted", "acceptée")
    assertEq(#MilitaryDrop.Server.getState().flights, 1, "un vol lancé")
    assertEq(#PLACED, 0, "rien avant le passage de l'hélicoptère")
    local flight = MilitaryDrop.Server.getState().flights[1]
    fly(MilitaryDrop.Flight.dropTime(flight) + 0.5)
    assertEq(#PLACED, 2, "CaseRolls caisses posées au largage")
    local sequence = commands()
    assertTrue(sequence:find("^Result,FlightStart,FlightSync") ~= nil, "réponse, départ, synchronisation : " .. sequence)
    assertTrue(sequence:find(",DropAnnounce$") ~= nil, "annonce des coordonnées en dernier : " .. sequence)
    assertTrue(sequence:find("Dropped") == nil, "pas de message privé : la chaîne suffit")
    assertEq(SENT[#SENT].args.x, 250, "point lointain : 150 cases à l'est du joueur (100, 200)")
    assertTrue(AIRING ~= nil and #AIRING.lines >= 4, "coordonnées diffusées sur la chaîne")
end

function T.without_channel_requester_gets_private_coordinates()
    MilitaryDrop.Server.handleRequest(PLAYER, request(CODE))
    fly(MilitaryDrop.Flight.dropTime(MilitaryDrop.Server.getState().flights[1]) + 0.5)
    assertTrue(commands():find("Dropped") ~= nil, "chaîne absente : message privé")
end

function T.forced_drop_does_not_touch_cooldown()
    local args = request(nil)
    args.force = true
    MilitaryDrop.Server.handleRequest(PLAYER, args)
    assertEq(MilitaryDrop.Server.getState().lastDropHours, nil, "délai inchangé")
    assertEq(#MilitaryDrop.Server.getState().flights, 1, "vol lancé quand même")
    fly(MilitaryDrop.Flight.dropTime(MilitaryDrop.Server.getState().flights[1]) + 0.5)
    assertTrue(commands():find("Dropped") ~= nil, "admin : coordonnées en privé")
end

function T.request_burst_gets_a_busy_answer()
    local player = makePlayer(makeRadio(true, 107400))
    MilitaryDrop.Server.handleRequest(player, request(CODE))
    assertEq(SENT[1].args.status, "noAnswer", "première demande traitée")
    NOW_MS = 1000
    local counted = 0
    MilitaryDrop.Trust.onFailedCode = function() counted = counted + 1 end
    MilitaryDrop.Server.handleRequest(player, request(CODE))
    assertEq(#SENT, 2, "seconde demande : une réponse")
    assertEq(SENT[2].args.status, "busy", "refusée par la cadence, sans texte de la base")
    assertEq(SENT[2].args.requestId, 1, "le client libère sa demande")
    assertEq(counted, 0, "rien de compté pour la demande refusée")
    NOW_MS = 4000
    MilitaryDrop.Server.handleRequest(player, request(CODE))
    assertEq(SENT[3].args.status, "noAnswer", "traitée après 3 s")
end

function T.drop_point_is_far_from_the_requester()
    SandboxVars.MilitaryDrop.DropMinDistance = 300
    SandboxVars.MilitaryDrop.DropMaxDistance = 300
    local x, y = MilitaryDrop.Server.pickDropPoint(100, 200)
    assertEq(x, 400, "300 cases à l'est")
    assertEq(y, 200, "même ligne")
end

function T.drop_point_avoids_buildings_and_off_map()
    local tries = 0
    ZombRandFloat = function(low, high)
        tries = tries + 1
        return tries <= 2 and low or high
    end
    BUILDING = function(x) return x == 250 end
    local x = MilitaryDrop.Server.pickDropPoint(100, 200)
    assertTrue(x ~= 250, "bâtiment écarté")
    OFF_MAP = function() return true end
    assertEq(MilitaryDrop.Server.pickDropPoint(100, 200), nil, "hors carte : aucun point")
end

function T.drop_point_lands_on_a_road_never_in_open_water()
    -- Point tiré au milieu d'un lac (400, 200) : la seule route passe à
    -- x 430-433 ; le point retenu est sur la route, jamais le point brut.
    SandboxVars.MilitaryDrop.DropMinDistance = 300
    SandboxVars.MilitaryDrop.DropMaxDistance = 300
    ROADS = { { x = 430, y = 0, w = 4, h = 1000 } }
    local x, y = MilitaryDrop.Server.pickDropPoint(100, 200)
    assertEq(x, 430, "case de route la plus proche")
    assertEq(y, 200, "même ligne")
    ROADS = {}
    ArrayList = ArrayList or { new = function() return { size = function() return 0 end } end }
    assertEq(MilitaryDrop.Server.pickDropPoint(100, 200), nil, "ni route ni bâtiment : aucun point brut")
    ROADS = nil
end

function T.no_far_point_falls_back_near_the_requester()
    OFF_MAP = function() return true end
    MilitaryDrop.Server.handleRequest(PLAYER, request(CODE))
    local flight = MilitaryDrop.Server.getState().flights[1]
    assertTrue(flight ~= nil, "vol lancé quand même")
    assertEq(flight.tx, 115.5, "repli près du joueur (15 cases)")
end

function T.code_is_kept_in_a_server_file_not_in_mod_data()
    assertEq(MilitaryDrop.Server.getCode(), CODE, "code relu du fichier")
    assertEq(MilitaryDrop.Server.getState().code, nil, "absent de la ModData lisible par les clients")
end

function T.code_is_generated_once_and_written()
    FILES = {}
    local first = MilitaryDrop.Server.getCode()
    assertEq(type(first), "string", "code tiré")
    assertEq(FILES["MilitaryDrop/Sandbox_Test_Save_code.txt"], first, "écrit dans le fichier de la partie")
    assertEq(MilitaryDrop.Server.getCode(), first, "code conservé")
end

function T.old_mod_data_code_is_migrated()
    FILES = {}
    MilitaryDrop.Server.getState().code = "ALPHA-BRAVO-01"
    assertEq(MilitaryDrop.Server.getCode(), "ALPHA-BRAVO-01", "code repris")
    assertEq(FILES["MilitaryDrop/Sandbox_Test_Save_code.txt"], "ALPHA-BRAVO-01", "déplacé dans le fichier")
    assertEq(MilitaryDrop.Server.getState().code, nil, "retiré de la ModData")
end

function T.landing_needs_the_four_squares_under_the_crate()
    local blocked = { ["114,199"] = true }
    getCell = function()
        return { getGridSquare = function(_, x, y)
            local square = {}
            for k, v in pairs(LANDING) do
                square[k] = v
            end
            square.getX = function() return x end
            square.getY = function() return y end
            square.isFree = function() return not blocked[x .. "," .. y] end
            return square
        end }
    end
    assertEq(MilitaryDrop.Server.landingSquareAt(115, 200), nil, "case voisine nord-ouest occupée")
    local square = MilitaryDrop.Server.findLandingNear(115, 200)
    assertTrue(square ~= nil, "autre case trouvée")
    assertTrue(not (square:getX() == 115 and square:getY() == 200), "déplacée")
end

function T.delivery_marks_the_crate_with_smoke_when_signal_smoke_is_active()
    getActivatedMods = function()
        return { size = function() return 1 end, get = function() return "batman_SignalSmoke" end }
    end
    local smoke = {}
    require = function(name)
        return name == "SignalSmoke/SignalSmoke" and { start = function(opts) smoke[#smoke + 1] = opts return opts.id end }
            or nil
    end
    assertTrue(MilitaryDrop.Server.deliver(115, 200, "tester"), "livré")
    assertEq(#smoke, 1, "une fumée")
    assertEq(smoke[1].x, 115, "sur la case de la caisse")
end

function T.back_radio_is_refused_on_a_multiplayer_server()
    isServer = function() return true end
    assertEq(MilitaryDrop.Server.evaluate(makePlayer(makeRadio(true, CHANNEL), "back"), request(CODE), WORLD_HOURS),
        "noRadio", "MP : état d'une radio sur le dos inconnu du serveur (seule la main compte)")
    assertEq(MilitaryDrop.Server.evaluate(makePlayer(makeRadio(true, CHANNEL), "hand"), request(CODE), WORLD_HOURS),
        "accepted", "MP : radio en main acceptée")
end

-- ----------------------------------------------------------------------------
-- Confiance (v1.3) : palier et indicatif, dropId, ligne coupée, délai, codes faux
-- ----------------------------------------------------------------------------

function T.accepted_request_carries_tier_callsign_and_a_drop_id()
    withChannel()
    MilitaryDrop.Server.handleRequest(PLAYER, request(CODE))
    local result = SENT[1].args
    assertEq(result.status, "accepted", "acceptée")
    assertEq(result.tier, 2, "palier de la note de départ 25")
    assertEq(result.callsign, MilitaryDrop.Teams.callsign(MilitaryDrop.Teams.SOLO_ID), "indicatif de l'équipe")
    local flight = MilitaryDrop.Server.getState().flights[1]
    local drop = MilitaryDrop.Secrets.privateState().drops[flight.dropId]
    assertTrue(drop ~= nil, "largage enregistré")
    assertEq(drop.team, MilitaryDrop.Teams.SOLO_ID, "équipe du demandeur au moment de l'appel")
    assertEq(drop.requester, "tester", "demandeur")
    fly(MilitaryDrop.Flight.dropTime(flight) + 0.5)
    assertEq(#PLACED_ITEMS, 2, "caisses au sol (repli)")
    for _, item in ipairs(PLACED_ITEMS) do
        assertEq(item.modData.MilitaryDrop_dropId, flight.dropId, "dropId sur chaque caisse de ravitaillement")
    end
    assertEq(drop.deadline, WORLD_HOURS + 48, "échéance de 48 h depuis la pose")
end

function T.line_cut_is_revealed_only_after_channel_and_code()
    local team = MilitaryDrop.Teams.idFor(PLAYER)
    MilitaryDrop.Trust.add(team, -40, "drop")
    assertTrue(MilitaryDrop.Trust.isLineCut(team), "note sous 15 : ligne coupée")
    assertEq(evaluate(makeRadio(true, 107400), request(CODE)), "noAnswer", "mauvais canal : rien ne trahit la coupure")
    assertEq(evaluate(makeRadio(true, CHANNEL), request("x")), "noAnswer", "mauvais code : idem")
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "lineCut", "canal et code justes : ligne coupée")
    MilitaryDrop.Server.handleRequest(PLAYER, request(CODE))
    assertEq(SENT[1].args.status, "lineCut", "réponse au joueur")
    assertEq(SENT[1].args.callsign, MilitaryDrop.Teams.callsign(team), "indicatif dans la réponse")
    assertEq(SENT[1].args.tier, nil, "aucun palier ni chiffre")
    assertEq(#(MilitaryDrop.Server.getState().flights or {}), 0, "aucun vol")
end

function T.cooldown_is_scaled_by_the_caller_team_trust()
    local state = MilitaryDrop.Server.getState()
    state.lastDropHours = WORLD_HOURS
    local team = MilitaryDrop.Teams.idFor(PLAYER)
    MilitaryDrop.Trust.add(team, MilitaryDrop.Trust.MAX - MilitaryDrop.Trust.get(team), "drop")
    local private = MilitaryDrop.Secrets.privateState()
    local status, hours = evaluate(makeRadio(true, CHANNEL), request(CODE))
    assertEq(status, "cooldown", "délai")
    assertEq(hours, 101, "note 100 : 168 × 0,6")
    private.trust[team].value = 0
    status, hours = evaluate(makeRadio(true, CHANNEL), request(CODE))
    assertEq(status, "cooldown", "délai allongé")
    assertEq(hours, 252, "note 0 : 168 × 1,5")
    state.lastDropHours = WORLD_HOURS - 101
    private.trust[team].value = 100
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "accepted", "délai raccourci écoulé")
end

function T.repeated_wrong_codes_cost_trust_at_the_next_hour()
    for i = 1, MilitaryDrop.Server.FAILED_CODE_LIMIT do
        evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-0" .. i))
    end
    local team = MilitaryDrop.Teams.idFor(PLAYER)
    assertEq(MilitaryDrop.Trust.get(team), 25, "rien de visible sur-le-champ")
    triggerEvent("EveryHours")
    assertEq(MilitaryDrop.Trust.get(team), 23, "−2 au changement d'heure")
end

function T.repeated_unanswered_calls_cost_trust_whatever_the_cause()
    -- 3 appels sans réponse dans l'heure (mauvais canal compris) : −2 au
    -- changement d'heure, comme 3 codes faux. La note ne révèle pas le canal.
    for _ = 1, 3 do
        evaluate(makeRadio(true, 107400), request("ALPHA-ALPHA-01"))
    end
    triggerEvent("EveryHours")
    assertEq(MilitaryDrop.Trust.get(MilitaryDrop.Teams.idFor(PLAYER)), 23, "mauvais canal : compté comme un code faux")
end

function T.silenced_caller_still_counts_for_trust()
    -- CONF-06 : réduit au silence par 3 codes faux, le joueur qui rappelle
    -- (même avec le bon code) compte comme un appel sans réponse.
    local counted = {}
    MilitaryDrop.Trust.onFailedCode = function(name) counted[#counted + 1] = name end
    for i = 1, MilitaryDrop.Server.FAILED_CODE_LIMIT do
        evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-0" .. i))
    end
    assertEq(#counted, 3, "trois codes faux")
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "noAnswer", "silence")
    assertEq(#counted, 4, "l'appel réduit au silence compte aussi")
end

function T.wrong_frequency_and_wrong_code_cost_the_same_trust()
    -- La note est lisible par les clients : elle ne doit pas révéler qu'un
    -- appel était sur la bonne fréquence.
    local counted = {}
    MilitaryDrop.Trust.onFailedCode = function(name) counted[#counted + 1] = name end
    evaluate(makeRadio(true, 107400), request(CODE))
    evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-01"))
    assertEq(#counted, 2, "mauvaise fréquence et mauvais code comptés pareil")
    SandboxVars.MilitaryDrop.AuthCode = 1
    evaluate(makeRadio(true, 107400), request(nil))
    assertEq(#counted, 2, "sans code exigé : rien à cacher, rien de compté")
end

function T.v13_state_never_goes_to_the_public_mod_data()
    withChannel()
    MilitaryDrop.Server.handleRequest(PLAYER, request(CODE))
    local flight = MilitaryDrop.Server.getState().flights[1]
    fly(MilitaryDrop.Flight.dropTime(flight) + 0.5)
    local team = MilitaryDrop.Teams.idFor(PLAYER)
    MilitaryDrop.Trust.add(team, 5, "report")
    MilitaryDrop.Trust.onCaseOpened(PLACED_ITEMS[1], PLAYER)
    for i = 1, 3 do
        evaluate(makeRadio(true, CHANNEL), request("ALPHA-ALPHA-0" .. i))
    end
    triggerEvent("EveryHours")
    local public = MilitaryDrop.Server.getState()
    for _, key in ipairs({ "teams", "teamPlayers", "nextTeamId", "trust", "drops", "nextDropId", "missions",
        "posts", "postLogs", "postMail", "nextPostUid" }) do
        assertEq(public[key], nil, key .. " absent de la table publique")
    end
    local private = MilitaryDrop.Secrets.privateState()
    assertTrue(private.teams[team] ~= nil and private.trust[team] ~= nil, "équipes et confiance dans l'état privé")
    assertEq(private.drops[flight.dropId].outcome, "recovered", "largages dans l'état privé")
    assertTrue(public.flights ~= nil and public.lastDropHours ~= nil, "vols et délai restent publics")
end

return T
