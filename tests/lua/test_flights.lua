-- MilitaryDrop_Flights : attente d'un événement HEF, livraison différée
-- jusqu'au chargement de la case, reprise après redémarrage.

local T = {}

local function makeSquare(x, y)
    return {
        getX = function() return x end, getY = function() return y end, getZ = function() return 0 end,
        isOutside = function() return true end, isFree = function() return true end,
        isWaterSquare = function() return false end,
        AddWorldInventoryItem = function(_, name) PLACED[#PLACED + 1] = name return {} end,
    }
end

function T.setup()
    SandboxVars = { MilitaryDrop = { MinZombies = 0, MaxZombies = 0, CaseRolls = 1 } }
    isClient = function() return false end
    isServer = function() return false end
    MODDATA = {}
    ModData = { getOrCreate = function(tag)
        MODDATA[tag] = MODDATA[tag] or {}
        return MODDATA[tag]
    end }
    ZombRand = function() return 0 end
    ZombRandFloat = function(low) return low end
    getTimestampMs = function() return 0 end
    getGameTime = function() return { getWorldAgeHours = function() return 10 end } end
    addSound = function() end
    spawnHorde = function() end
    getNumActivePlayers = function() return 0 end
    PLACED = {}
    LOADED = true
    getCell = function()
        return { getGridSquare = function(_, x, y) return LOADED and makeSquare(x, y) or nil end }
    end
    SENT = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Flight.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Server.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Flights.lua")
    MilitaryDrop.Client = { onServerCommand = function(_, command, args)
        SENT[#SENT + 1] = { command = command, args = args }
    end }
end

local function launch()
    return MilitaryDrop.Flights.launch(makeSquare(500, 600), "tester", 1)
end

function T.hef_event_near_target_delays_departure()
    HTT = { Server = { state = { active = true, centerX = 520, centerY = 610, radius = 50 } } }
    local flight = launch()
    MilitaryDrop.Flights.advance(flight, 0.25)
    assertEq(flight.started, false, "départ retardé")
    assertEq(flight.elapsed, 0, "le vol n'avance pas")
    HTT.Server.state.active = false
    MilitaryDrop.Flights.advance(flight, 0.25)
    assertEq(flight.started, true, "départ quand le ciel est libre")
    assertEq(SENT[1].command, "FlightStart", "clients prévenus")
end

function T.far_hef_event_does_not_delay()
    HTT = { Server = { state = { active = true, centerX = 5000, centerY = 5000, radius = 50 } } }
    local flight = launch()
    MilitaryDrop.Flights.advance(flight, 0.25)
    assertEq(flight.started, true, "événement lointain ignoré")
end

function T.hold_is_limited()
    HTT = { Server = { state = { active = true, centerX = 500, centerY = 600, radius = 50 } } }
    local flight = launch()
    flight.holdSeconds = MilitaryDrop.Flights.MAX_HOLD_SECONDS
    MilitaryDrop.Flights.advance(flight, 0.25)
    assertEq(flight.started, true, "départ forcé après l'attente maximale")
end

function T.unloaded_square_waits_for_load()
    LOADED = false
    MilitaryDrop.Flights.deliverAt(500, 600, "tester", 1)
    assertEq(#PLACED, 0, "case non chargée")
    assertEq(listenerCount("LoadGridsquare"), 1, "surveillance du chargement")
    triggerEvent("LoadGridsquare", makeSquare(10, 10))
    assertEq(#PLACED, 0, "autre case ignorée")
    triggerEvent("LoadGridsquare", makeSquare(500, 600))
    assertEq(#PLACED, 1, "livré au chargement")
    assertEq(listenerCount("LoadGridsquare"), 0, "surveillance arrêtée")
end

function T.restart_turns_flights_into_pending_drops()
    local flight = launch()
    local dropped = launch()
    dropped.dropped = true
    flight.tx, flight.ty = 700.5, 800.5
    MilitaryDrop.Flights.restore()
    local state = MilitaryDrop.Server.getState()
    assertEq(#state.flights, 0, "plus de vol en cours")
    assertTrue(state.pending["700,800"] ~= nil, "livraison en attente")
    assertEq(listenerCount("LoadGridsquare"), 1, "surveillance du chargement")
end

return T
