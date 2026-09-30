-- MilitaryDrop_Heli : son local, ombre et flèches créés puis retirés.

local T = {}

function T.setup()
    SandboxVars = {}
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
    PLAYING = {}
    STOPPED = 0
    EMITTER = {
        setPos = function(self, x, y, z) self.x, self.y, self.z = x, y, z end,
        isPlaying = function(_, id) return PLAYING[id] == true end,
        playSoundLoopedImpl = function(_, name)
            PLAYING[1] = true
            SOUND_NAME = name
            return 1
        end,
        stopSoundLocal = function(_, id)
            PLAYING[id] = nil
            STOPPED = STOPPED + 1
        end,
    }
    getWorld = function() return { getFreeEmitter = function() return EMITTER end } end
    MARKERS, ARROWS = 0, 0
    getWorldMarkers = function()
        return {
            addGridSquareMarker = function()
                MARKERS = MARKERS + 1
                return { setPos = function() end }
            end,
            removeGridSquareMarker = function() MARKERS = MARKERS - 1 end,
            addDirectionArrow = function()
                ARROWS = ARROWS + 1
                return { setX = function() end, setY = function() end }
            end,
            removeDirectionArrow = function() ARROWS = ARROWS - 1 end,
        }
    end
    getCell = function() return { getGridSquare = function() return {} end } end
    PLAYER = { getX = function() return 1000 end, getY = function() return 2000 end, isDead = function() return false end }
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function() return PLAYER end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Flight.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_Heli.lua")
end

local function start()
    local flight = MilitaryDrop.Flight.new(4, 1000, 2000, 0)
    MilitaryDrop.Heli.onFlightStart(MilitaryDrop.Flight.toArgs(flight))
    return flight
end

--- Avance le temps réel et déclenche un tick.
local function tick(ms)
    NOW_MS = NOW_MS + ms
    triggerEvent("OnTick")
end

function T.start_plays_sound_and_shows_shadow_and_arrow()
    local flight = start()
    assertEq(listenerCount("OnTick"), 1, "tick abonné")
    tick(100)
    assertEq(SOUND_NAME, "Helicopter", "son vanilla")
    assertEq(EMITTER.z, MilitaryDrop.Heli.SOUND_Z, "son en altitude")
    assertEq(MARKERS, 1, "ombre au sol")
    assertEq(ARROWS, 0, "pas de flèche au-delà d'ARROW_RANGE (départ à 600 cases)")
    local approach = MilitaryDrop.Flight.timeline(flight)
    MilitaryDrop.Heli.onFlightSync({ id = 4, elapsed = approach - 200 / MilitaryDrop.Flight.SPEED })
    tick(100)
    assertEq(ARROWS, 1, "flèche à 200 cases")
end

function T.arrow_hidden_when_helicopter_is_close()
    local flight = start()
    local approach = MilitaryDrop.Flight.timeline(flight)
    MilitaryDrop.Heli.onFlightSync({ id = 4, elapsed = approach })
    tick(100)
    assertEq(ARROWS, 0, "pas de flèche au-dessus du joueur")
end

function T.end_removes_everything_and_unsubscribes()
    start()
    tick(100)
    MilitaryDrop.Heli.onFlightEnd({ id = 4 })
    assertEq(STOPPED, 1, "son arrêté localement")
    assertEq(MARKERS, 0, "ombre retirée")
    assertEq(ARROWS, 0, "flèche retirée")
    tick(100)
    assertEq(listenerCount("OnTick"), 0, "tick désabonné")
end

function T.lost_end_message_is_handled_by_timeout()
    local flight = start()
    MilitaryDrop.Heli.onFlightSync({ id = 4, elapsed = MilitaryDrop.Flight.totalTime(flight) + 60 })
    tick(100)
    assertEq(MilitaryDrop.Heli.count(), 0, "vol retiré sans FlightEnd")
end

function T.duplicate_start_only_resyncs()
    start()
    start()
    assertEq(MilitaryDrop.Heli.count(), 1, "un seul vol")
end

return T
