-- MilitaryDrop_Broadcast : chaîne militaire et annonces ; fréquence fixe
-- (option) ou libre et secrète, tirée de la graine (bande 120-170 MHz,
-- réserves, station de chiffres évitée, fréquence déjà prise).

local T = {}

local SEED = 424242

function T.setup()
    SandboxVars = { MilitaryDrop = { Frequency = 151.4 } }
    isClient = function() return false end
    isServer = function() return false end
    getText = function(key, a, b) return key .. "|" .. tostring(a) .. "|" .. tostring(b) end
    ChannelCategory = { Military = "Military" }
    CHANNELS = {}
    DynamicRadioChannel = { new = function(name, freq, category, uuid)
        AIRED = nil
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
    FREQUENCY_TAKEN = false
    -- Fréquences déjà prises par d'autres chaînes (RadioScriptManager.AddChannel refuse).
    TAKEN = {}
    SCRIPT_MANAGER = {
        AddChannel = function(_, channel)
            if not FREQUENCY_TAKEN and not TAKEN[channel.freq] then
                CHANNELS[channel.uuid] = channel
            end
        end,
        getRadioChannel = function(_, uuid) return CHANNELS[uuid] end,
    }
    REMOVED_NAMES = {}
    getZomboidRadio = function()
        return { removeChannelName = function(_, freq) REMOVED_NAMES[#REMOVED_NAMES + 1] = freq end }
    end
    SENT = {}
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
    ZombRand = function() return 0 end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Broadcast.lua")
    MilitaryDrop.Client = { onServerCommand = function(_, command, args)
        SENT[#SENT + 1] = { command = command, args = args }
    end }
end

function T.channel_on_military_frequency()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    local channel = MilitaryDrop.Broadcast.channel
    assertEq(channel.freq, 151400, "fréquence sandbox en kHz")
    assertEq(channel.category, "Military", "catégorie militaire")
    assertEq(REMOVED_NAMES[1], 151400, "nom masqué dans le panneau de la radio")
end

function T.dropped_repeats_coordinates_with_code()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    MilitaryDrop.Broadcast.dropped(115, 200)
    assertEq(SENT[1].command, "DropAnnounce", "coordonnées envoyées aux clients")
    assertEq(#AIRED.lines, MilitaryDrop.Broadcast.REPEATS + 1, "trois répétitions et fin")
    assertEq(AIRED.lines[1].text, "IGUI_MilitaryDrop_BroadcastDropped|115|200", "coordonnées dans le texte")
    assertEq(AIRED.lines[1].codes, "MDRP", "code du repère de carte")
    assertEq(AIRED.lines[#AIRED.lines].codes, nil, "fin sans code")
end

function T.inbound_has_no_coordinates_or_code()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    MilitaryDrop.Broadcast.inbound()
    assertEq(#AIRED.lines, 1, "une ligne")
    assertEq(AIRED.lines[1].codes, nil, "pas de repère")
end

function T.second_drop_is_appended_to_the_airing_broadcast()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    MilitaryDrop.Broadcast.dropped(1, 2)
    local first = AIRED
    MilitaryDrop.Broadcast.inbound()
    assertEq(AIRED, first, "même diffusion")
    assertEq(#AIRED.lines, MilitaryDrop.Broadcast.REPEATS + 2, "annonce ajoutée à la suite")
end

function T.recon_coordinates_go_to_all_with_their_code()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    local code = MilitaryDrop.Broadcast.reconAnnounced("M7", 1500, 2500)
    assertEq(code, "MDRC", "code de la ligne d'annonce")
    assertTrue(code ~= MilitaryDrop.Broadcast.CODE, "distinct du largage")
    assertEq(SENT[1].command, "ReconAnnounce", "grille envoyée aux clients")
    assertEq(SENT[1].args.id, "M7", "mission")
    assertEq(SENT[1].args.x, 1500, "x")
    assertEq(SENT[1].args.y, 2500, "y")
    assertEq(AIRED, nil, "rien diffusé : l'annonce reste à l'appelant")
end

function T.cleanup_zone_goes_to_all_with_its_own_code()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    local code = MilitaryDrop.Broadcast.cleanupAnnounced("M8", 1600, 2600, 40)
    assertEq(code, "MDCU", "code de la ligne d'annonce")
    assertTrue(code ~= MilitaryDrop.Broadcast.CODE and code ~= MilitaryDrop.Broadcast.RECON_CODE, "code distinct")
    assertEq(SENT[1].command, "CleanupAnnounce", "zone envoyée aux clients")
    assertEq(SENT[1].args.id, "M8", "mission")
    assertEq(SENT[1].args.x .. "," .. SENT[1].args.y, "1600,2600", "centre")
    assertEq(SENT[1].args.radius, 40, "rayon")
    assertEq(AIRED, nil, "rien diffusé : l'annonce reste à l'appelant")
end

function T.taken_frequency_disables_broadcast_quietly()
    FREQUENCY_TAKEN = true
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    assertEq(MilitaryDrop.Broadcast.channel, nil, "pas de chaîne")
    assertEq(MilitaryDrop.Broadcast.air({ { "x" } }), false, "rien diffusé")
    MilitaryDrop.Broadcast.dropped(1, 2)
    assertEq(SENT[1].command, "DropAnnounce", "les coordonnées partent quand même")
end

function T.announcements_go_to_command_post_logs()
    local recorded = {}
    MilitaryDrop.Post = { record = function(team, text) recorded[#recorded + 1] = { team = team, text = text } end }
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    MilitaryDrop.Broadcast.inbound()
    MilitaryDrop.Broadcast.dropped(1200, 3400)
    assertEq(#recorded, 2, "départ et coordonnées au journal")
    assertEq(recorded[1].team, nil, "à toutes les stations")
    assertEq(recorded[2].text, "IGUI_MilitaryDrop_BroadcastDropped|1200|3400", "coordonnées")
    MilitaryDrop.Broadcast.channel = nil
    MilitaryDrop.Broadcast.inbound()
    assertEq(#recorded, 2, "sans chaîne : rien au journal")
end

-- ----------------------------------------------------------------------------
-- Fréquence libre (option Frequency à 0)
-- ----------------------------------------------------------------------------

local function loadFree()
    SandboxVars.MilitaryDrop.Frequency = 0
    CHANNELS = {}
    REMOVED_NAMES = {}
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    return MilitaryDrop.Broadcast.frequency
end

local function inBand(channel)
    return channel >= 120000 and channel <= 170000 and channel % 200 == 0
end

function T.free_frequency_is_drawn_in_the_military_band()
    local frequency = loadFree()
    assertTrue(inBand(frequency), "bande 120-170 MHz, pas de 0,2 MHz : " .. tostring(frequency))
    assertEq(MilitaryDrop.Broadcast.channel.freq, frequency, "chaîne créée sur cette fréquence")
    assertEq(REMOVED_NAMES[1], frequency, "nom masqué dans le panneau de la radio")
    assertEq(MilitaryDrop.Config.getChannel(), frequency, "serveur : canal militaire de la partie")
    assertEq(MilitaryDrop.Config.isFixedFrequency(), false, "fréquence non publique")
end

function T.free_frequency_is_stable_for_a_seed()
    local frequency = loadFree()
    assertEq(loadFree(), frequency, "même graine : même fréquence au rechargement")
    assertEq(MilitaryDrop.Broadcast.candidates(SEED)[1], frequency, "premier candidat de la graine")
    local others = 0
    for seed = 1, 20 do
        if MilitaryDrop.Broadcast.candidates(SEED + seed)[1] ~= frequency then
            others = others + 1
        end
    end
    assertTrue(others >= 18, "autre graine : autre fréquence (" .. others .. "/20)")
end

function T.free_frequency_is_known_before_the_channel_exists()
    SandboxVars.MilitaryDrop.Frequency = 0
    assertEq(MilitaryDrop.Broadcast.frequency, nil, "chaîne pas encore créée")
    assertEq(MilitaryDrop.Config.getChannel(), MilitaryDrop.Broadcast.candidates(SEED)[1],
        "premier candidat (station de chiffres chargée avant, notes)")
end

function T.free_frequency_skips_taken_channels()
    local first = loadFree()
    TAKEN[first] = true
    local second = loadFree()
    assertTrue(second ~= first, "fréquence prise par une autre chaîne : la suivante")
    assertTrue(inBand(second), "toujours dans la bande")
    assertEq(MilitaryDrop.Config.getChannel(), second, "canal de la chaîne réellement créée")
end

function T.free_frequency_avoids_reserved_and_numbers_station_channels()
    local first = loadFree()
    MilitaryDrop.Config.RESERVED_CHANNELS[first] = true
    local list = MilitaryDrop.Broadcast.candidates(SEED)
    for _, channel in ipairs(list) do
        assertTrue(channel ~= first, "canal réservé exclu")
        assertTrue(channel ~= 112200, "112,2 MHz (HEF) jamais utilisée")
        assertTrue(inBand(channel), "jamais hors bande (station de chiffres libre : 10-25 MHz)")
    end
    MilitaryDrop.Config.RESERVED_CHANNELS[first] = nil
    SandboxVars.MilitaryDrop.NumbersStationFrequency = first / 1000
    for _, channel in ipairs(MilitaryDrop.Broadcast.candidates(SEED)) do
        assertTrue(channel ~= first, "fréquence fixée de la station de chiffres exclue")
    end
    assertTrue(loadFree() ~= first, "la chaîne militaire prend une autre fréquence")
end

function T.fixed_frequency_is_used_as_is()
    SandboxVars.MilitaryDrop.Frequency = 133.3
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    assertEq(MilitaryDrop.Broadcast.frequency, 133400, "option arrondie au pas")
    assertEq(MilitaryDrop.Config.getChannel(), 133400, "canal fixe")
end

return T
