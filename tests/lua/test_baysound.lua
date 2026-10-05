-- MilitaryDrop_BaySound : sons de la baie de lecture joués localement par le
-- client depuis la case du poste (déclic d'insertion, boucle de lecture,
-- double déclic de fin), arrêt sur ordre, sans rappel ou loin du poste.

local T = {}

function T.setup()
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
    SOUND_VOLUME = 5
    getCore = function() return { getOptionSoundVolume = function() return SOUND_VOLUME end } end
    MINUTES_PER_DAY = 90
    getGameTime = function() return { getMinutesPerDay = function() return MINUTES_PER_DAY end } end
    EMITTERS = {}
    getWorld = function()
        return { getFreeEmitter = function(_, x, y, z)
            local emitter = newSoundEmitter(x, y, z)
            EMITTERS[#EMITTERS + 1] = emitter
            return emitter
        end }
    end
    PLAYER = { x = 101, y = 100, z = 0 }
    function PLAYER.getX(self) return self.x end
    function PLAYER.getY(self) return self.y end
    function PLAYER.getZ(self) return self.z end
    function PLAYER.isDead() return false end
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function() return PLAYER end
    MilitaryDrop = { Client = { HANDLERS = {} } }
    loadMod("client/MilitaryDrop/MilitaryDrop_BaySound.lua")
    B = MilitaryDrop.BaySound
end

local function command(args)
    MilitaryDrop.Client.HANDLERS.BaySound(args)
end

local function played()
    local out = {}
    for _, emitter in ipairs(EMITTERS) do
        for _, sound in ipairs(emitter.played) do
            out[#out + 1] = sound
        end
    end
    return out
end

function T.insertion_click_is_played_locally_on_the_post_square()
    command({ x = 100, y = 100, z = 0, event = "insert" })
    local sounds = played()
    assertEq(#sounds, 1, "un son bref")
    assertEq(sounds[1].name, "MilitaryDropBayInsert", "déclic du lecteur")
    assertEq(sounds[1].x .. "," .. sounds[1].y .. "," .. sounds[1].z, "100.5,100.5,0", "au centre de la case du poste")
    assertEq(sounds[1].relayed, false, "local : jamais relayé aux autres joueurs")
    assertEq(EMITTERS[1].volumes[1], 0.5, "curseur des effets sonores appliqué")
    assertEq(B.count(), 0, "pas de boucle pour un son bref")
end

function T.reading_loop_starts_once_and_stops_on_order()
    command({ x = 100, y = 100, z = 0, reading = true })
    command({ x = 100, y = 100, z = 0, reading = true })
    local sounds = played()
    assertEq(#sounds, 1, "une seule boucle malgré les rappels")
    assertEq(sounds[1].name, "MilitaryDropBayRead", "porteuse de lecture")
    assertTrue(sounds[1].looped and not sounds[1].relayed, "boucle locale")
    assertEq(B.count(), 1, "boucle suivie")
    command({ x = 100, y = 100, z = 0, event = "done", reading = false })
    assertEq(B.count(), 0, "arrêtée")
    assertEq(#EMITTERS[1].stopped, 1, "stopSoundLocal")
    assertEq(played()[2].name, "MilitaryDropBayDone", "double déclic de fin")
end

function T.loop_stops_without_news_or_far_from_the_post()
    command({ x = 100, y = 100, z = 0, reading = true })
    NOW_MS = 14000
    B.onTick()
    assertEq(B.count(), 1, "encore dans le délai (15 s au moins)")
    NOW_MS = 16000
    B.onTick()
    assertEq(B.count(), 0, "sans rappel : arrêtée")
    command({ x = 100, y = 100, z = 0, reading = true })
    PLAYER.x = 100 + B.LOCAL_STOP_RANGE + 2
    NOW_MS = NOW_MS + 2000
    B.onTick()
    assertEq(B.count(), 0, "joueur parti : arrêtée")
end

function T.timeout_follows_the_length_of_a_game_minute()
    MINUTES_PER_DAY = 1440
    assertEq(B.timeoutMs(), 180000, "jour en temps réel : trois minutes réelles")
    MINUTES_PER_DAY = 90
    assertEq(B.timeoutMs(), 15000, "jour court : 15 s au moins")
end

function T.restarted_loop_takes_a_fresh_emitter()
    command({ x = 100, y = 100, z = 0, reading = true })
    EMITTERS[1].playing = {}
    NOW_MS = 1500
    B.onTick()
    assertEq(#EMITTERS, 2, "émetteur rendu à la réserve : un neuf")
    assertEq(B.count(), 1, "toujours suivie")
end

return T
