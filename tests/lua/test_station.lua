-- MilitaryDrop_NumbersStation : fréquence (ondes courtes, option, collisions),
-- message chiffré sans le code en clair, une diffusion par demi-heure.

local T = {}

local SEED = 424242

function T.setup()
    SandboxVars = { MilitaryDrop = { Frequency = 151.4, AuthCode = 4 } }
    isClient = function() return false end
    isServer = function() return false end
    getText = function(key, a) return a and (key .. "|" .. tostring(a)) or key end
    ZombRand = function() return 0 end
    FILES = { ["MilitaryDrop/Sandbox_Test_Save_seed.txt"] = tostring(SEED) }
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
    -- Mercredi 14 juillet 1993, midi ; partie commencée le vendredi 9 juillet à 9 h.
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
    ChannelCategory = { Military = "Military" }
    AIRED = nil
    DynamicRadioChannel = { new = function(name, freq, category, uuid)
        return {
            name = name, freq = freq, category = category, uuid = uuid,
            getAiringBroadcast = function() return AIRED end,
            setAiringBroadcast = function(_, bc) AIRED = bc end,
        }
    end }
    RadioBroadCast = { new = function(id)
        return { id = id, lines = {}, AddRadioLine = function(self, line) self.lines[#self.lines + 1] = line end }
    end }
    RadioLine = { new = function(text, r, g, b, codes) return { text = text, codes = codes } end }
    TAKEN = {}
    CHANNELS = {}
    SCRIPT_MANAGER = {
        AddChannel = function(_, channel)
            if not TAKEN[channel.freq] then
                CHANNELS[channel.uuid] = channel
            end
        end,
        getRadioChannel = function(_, uuid) return CHANNELS[uuid] end,
    }
    REMOVED_NAMES = {}
    getZomboidRadio = function()
        return { removeChannelName = function(_, freq) REMOVED_NAMES[#REMOVED_NAMES + 1] = freq end }
    end
    MODDATA = {}
    ModData = { getOrCreate = function(tag)
        MODDATA[tag] = MODDATA[tag] or {}
        return MODDATA[tag]
    end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_NumbersStation.lua")
end

local function load()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    return MilitaryDrop.NumbersStation
end

local function clock()
    return MilitaryDrop.Codes.gameClock(getGameTime())
end

function T.free_shortwave_frequency_from_the_seed()
    local station = load()
    local frequency = station.frequency
    assertTrue(frequency >= 10000 and frequency <= 25000, "ondes courtes : " .. tostring(frequency))
    assertEq(frequency % 200, 0, "pas de réglage des radios")
    assertEq(station.channel.freq, frequency, "chaîne créée sur cette fréquence")
    assertEq(REMOVED_NAMES[1], frequency, "nom masqué dans le panneau de la radio")
    CHANNELS = {}
    assertEq(load().frequency, frequency, "même graine : même fréquence au rechargement")
end

function T.taken_frequency_is_skipped()
    local first = load().frequency
    CHANNELS = {}
    TAKEN[first] = true
    local second = load().frequency
    assertTrue(second ~= first, "fréquence prise : la suivante")
    assertTrue(second >= 10000 and second <= 25000, "toujours dans la bande")
end

function T.military_frequency_is_never_used()
    SandboxVars.MilitaryDrop.Frequency = 12.0
    for _, channel in ipairs(MilitaryDrop.NumbersStation.candidates(SEED)) do
        assertTrue(channel ~= 12000, "fréquence militaire exclue")
    end
    SandboxVars.MilitaryDrop.NumbersStationFrequency = 12.0
    local list = MilitaryDrop.NumbersStation.candidates(SEED)
    assertEq(#list, 1, "option : une seule fréquence")
    assertEq(list[1], 12200, "égale à la fréquence militaire : décalée d'un pas")
    SandboxVars.MilitaryDrop.NumbersStationFrequency = 14.63
    assertEq(MilitaryDrop.NumbersStation.candidates(SEED)[1], 14600, "option arrondie au pas")
end

function T.no_station_without_the_encrypted_code()
    SandboxVars.MilitaryDrop.AuthCode = 3
    local station = load()
    assertEq(station.channel, nil, "pas de chaîne")
    assertEq(station.frequency, nil, "pas de fréquence")
    assertEq(station.air(clock()), false, "rien à diffuser")
end

function T.message_is_encrypted_with_the_game_table()
    local Codes = MilitaryDrop.Codes
    local lines = MilitaryDrop.NumbersStation.message(clock())
    assertEq(#lines, 5, "appel, trois groupes, fin")
    assertEq(lines[1], "IGUI_MilitaryDrop_Numbers_Open", "appel, sans édition")
    assertEq(lines[5], "IGUI_MilitaryDrop_Numbers_End", "fin du message")
    local code = Codes.weeklyCode(SEED, Codes.weekOf(clock()))
    local cipher = lines[2]:match("|(.+)$")
    assertEq(Codes.decrypt(cipher, Codes.cipherTable(SEED)), code, "déchiffré par la table de la partie")
    for _, line in ipairs(lines) do
        assertTrue(line:find(code, 1, true) == nil, "code en clair jamais diffusé")
        assertTrue(line:find(code:match("^(%u+)"), 1, true) == nil, "aucun mot du code")
    end
    DATE.month, DATE.day = 7, 4 -- 5 août : autre semaine, autre groupe, même table
    local later = MilitaryDrop.NumbersStation.message(clock())[2]:match("|(.+)$")
    assertEq(Codes.decrypt(later, Codes.cipherTable(SEED)), Codes.weeklyCode(SEED, Codes.weekOf(clock())),
        "même table un mois plus tard")
end

function T.one_broadcast_per_half_hour()
    load()
    triggerEvent("EveryTenMinutes")
    assertTrue(AIRED ~= nil, "première diffusion")
    assertEq(#AIRED.lines, 5, "message complet")
    local first = AIRED
    AIRED = nil
    DATE.hour = 12 + 10 / 60
    triggerEvent("EveryTenMinutes")
    assertEq(AIRED, nil, "même demi-heure : rien")
    DATE.hour = 12 + 20 / 60
    triggerEvent("EveryTenMinutes")
    assertEq(AIRED, nil, "toujours la même demi-heure")
    DATE.hour = 12.5 - 0.00001 -- 12:30 lu comme un flottant à peine plus petit
    triggerEvent("EveryTenMinutes")
    assertTrue(AIRED ~= nil and AIRED ~= first, "demi-heure suivante : nouvelle diffusion")
    AIRED = nil
    DATE.hour = 12.5 + 10 / 60
    triggerEvent("EveryTenMinutes")
    assertEq(AIRED, nil, "une seule fois par demi-heure")
end

function T.broadcast_waits_for_the_previous_one()
    load()
    AIRED = { lines = {} }
    assertEq(MilitaryDrop.NumbersStation.air(clock()), false, "diffusion en cours : pas d'empilement")
    triggerEvent("EveryTenMinutes")
    AIRED = nil
    triggerEvent("EveryTenMinutes")
    assertTrue(AIRED ~= nil, "retentée au passage suivant, dans la même demi-heure")
end

function T.station_keeps_no_state_in_mod_data()
    load()
    MilitaryDrop.NumbersStation.air(clock())
    assertEq(MODDATA.MilitaryDrop, nil, "aucune ModData")
end

return T
