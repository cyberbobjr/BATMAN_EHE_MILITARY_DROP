-- ============================================================================
-- Military Drop — vols d'hélicoptère côté serveur (serveur MP ou solo)
--
-- Le serveur fait avancer chaque vol (temps réel de jeu non suspendu : OnTick
-- ne tourne pas pendant une pause solo), déclenche le largage au-dessus du
-- point visé et prévient les clients (FlightStart, FlightSync toutes les
-- SYNC_SECONDS, FlightEnd). Les clients dessinent l'hélicoptère eux-mêmes.
--
-- Bruit : addSound à la position de l'hélicoptère toutes les NOISE_SECONDS,
-- et un bruit plus fort au largage. Portées modérées pour ne pas cumuler avec
-- les événements de HEF - Helicopter Event Framework (Workshop 3672792485).
--
-- Cohabitation avec HEF : tant qu'un de ses événements est actif près de la
-- cible (HTT.Server.state, lecture seule), le départ est retardé, au plus
-- MAX_HOLD_SECONDS.
--
-- Persistance (ModData « MilitaryDrop ») : les vols en cours. Au chargement de
-- la partie, un vol interrompu devient une livraison en attente, sans
-- hélicoptère. Une livraison dont la case n'est pas chargée attend son
-- chargement (LoadGridsquare).
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Server"
require "MilitaryDrop/MilitaryDrop_Broadcast"

local Flight = MilitaryDrop.Flight
local Net = MilitaryDrop.Net
local Server = MilitaryDrop.Server
local Broadcast = MilitaryDrop.Broadcast

local Flights = {}
MilitaryDrop.Flights = Flights

Flights.MAX_TICK_SECONDS = 0.25
Flights.SYNC_SECONDS = 5
Flights.NOISE_SECONDS = 3
Flights.NOISE_RADIUS = 60
Flights.NOISE_VOLUME = 40
Flights.DROP_NOISE_RADIUS = 150
Flights.DROP_NOISE_VOLUME = 100
Flights.MAX_HOLD_SECONDS = 300
Flights.AIRSPACE_MARGIN = 300

local ticking = false
local watchingSquares = false
local lastTickMs = 0

local function state()
    local s = Server.getState()
    s.flights = s.flights or {}
    s.pending = s.pending or {}
    return s
end

local function pendingKey(x, y)
    return x .. "," .. y
end

local function hasPending()
    local count = 0
    for _ in pairs(state().pending) do
        count = count + 1
    end
    return count > 0
end

-- ----------------------------------------------------------------------------
-- Livraisons en attente de chargement de leur case
-- ----------------------------------------------------------------------------

local function onLoadGridsquare(square)
    if square:getZ() ~= 0 then
        return
    end
    local pending = state().pending
    local key = pendingKey(square:getX(), square:getY())
    local entry = pending[key]
    if entry then
        pending[key] = nil
        Server.deliver(square, entry.requester, entry.requestId, entry.forced)
    end
    if not hasPending() then
        Events.LoadGridsquare.Remove(onLoadGridsquare)
        watchingSquares = false
    end
end

local function watchSquares()
    if not watchingSquares then
        watchingSquares = true
        Events.LoadGridsquare.Add(onLoadGridsquare)
    end
end

--- Livre sur la case (x, y, 0), tout de suite si elle est chargée.
function Flights.deliverAt(x, y, requester, requestId, forced)
    local square = getCell():getGridSquare(x, y, 0)
    if square then
        Server.deliver(square, requester, requestId, forced)
        return
    end
    state().pending[pendingKey(x, y)] = {
        x = x, y = y, requester = requester, requestId = requestId, forced = forced,
    }
    watchSquares()
    MilitaryDrop.log(string.format("drop at %d,%d waits for its square to load", x, y))
end

-- ----------------------------------------------------------------------------
-- Vols
-- ----------------------------------------------------------------------------

--- Un événement HEF actif près de la cible occupe le ciel.
function Flights.airspaceBusy(flight)
    local hef = HTT and HTT.Server and HTT.Server.state
    if type(hef) ~= "table" or not hef.active then
        return false
    end
    local cx, cy = tonumber(hef.centerX), tonumber(hef.centerY)
    if not cx or not cy then
        return true
    end
    local range = (tonumber(hef.radius) or 0) + Flights.AIRSPACE_MARGIN
    local dx, dy = flight.tx - cx, flight.ty - cy
    return dx * dx + dy * dy <= range * range
end

local function drop(flight)
    flight.dropped = true
    local x, y = math.floor(flight.tx), math.floor(flight.ty)
    addSound(nil, x, y, 0, Flights.DROP_NOISE_RADIUS, Flights.DROP_NOISE_VOLUME)
    Flights.deliverAt(x, y, flight.requester, flight.requestId, flight.forced)
    Broadcast.dropped(x, y)
end

local function removeFlight(index)
    local flights = state().flights
    local flight = flights[index]
    table.remove(flights, index)
    Net.toAll("FlightEnd", { id = flight.id })
end

--- Avance un vol de dt secondes ; renvoie true quand il est terminé.
function Flights.advance(flight, dt)
    if not flight.started then
        if Flights.airspaceBusy(flight) and (flight.holdSeconds or 0) < Flights.MAX_HOLD_SECONDS then
            flight.holdSeconds = (flight.holdSeconds or 0) + dt
            return false
        end
        flight.started = true
        Net.toAll("FlightStart", Flight.toArgs(flight))
        Broadcast.inbound()
        MilitaryDrop.log(string.format("flight %d started toward %d,%d", flight.id, flight.tx, flight.ty))
    end
    flight.elapsed = flight.elapsed + dt
    local x, y, phase = Flight.position(flight, flight.elapsed)
    if not flight.dropped and flight.elapsed >= Flight.dropTime(flight) then
        drop(flight)
    end
    flight.noiseIn = (flight.noiseIn or 0) - dt
    if flight.noiseIn <= 0 then
        flight.noiseIn = Flights.NOISE_SECONDS
        addSound(nil, math.floor(x), math.floor(y), 0, Flights.NOISE_RADIUS, Flights.NOISE_VOLUME)
    end
    flight.syncIn = (flight.syncIn or Flights.SYNC_SECONDS) - dt
    if flight.syncIn <= 0 then
        flight.syncIn = Flights.SYNC_SECONDS
        Net.toAll("FlightSync", { id = flight.id, elapsed = flight.elapsed })
    end
    return phase == "done"
end

local function onTick()
    local now = getTimestampMs()
    local dt = math.min((now - lastTickMs) / 1000, Flights.MAX_TICK_SECONDS)
    lastTickMs = now
    local flights = state().flights
    for i = #flights, 1, -1 do
        if Flights.advance(flights[i], dt) then
            removeFlight(i)
        end
    end
    if #flights == 0 then
        Events.OnTick.Remove(onTick)
        ticking = false
    end
end

local function startTicking()
    if not ticking then
        ticking = true
        lastTickMs = getTimestampMs()
        Events.OnTick.Add(onTick)
    end
end

--- Lance un hélicoptère vers une case d'atterrissage (forced : largage admin).
function Flights.launch(square, requester, requestId, forced)
    local s = state()
    s.nextFlightId = (tonumber(s.nextFlightId) or 0) + 1
    local flight = Flight.new(s.nextFlightId, square:getX() + 0.5, square:getY() + 0.5, ZombRandFloat(0, 2 * math.pi))
    flight.requester = requester
    flight.requestId = requestId
    flight.forced = forced == true
    flight.dropped = false
    flight.started = false
    table.insert(s.flights, flight)
    startTicking()
    return flight
end

--- Vols en cours pour un joueur qui (re)vient.
function Flights.sendActive(player)
    for _, flight in ipairs(state().flights) do
        if flight.started then
            Net.toPlayer(player, "FlightStart", Flight.toArgs(flight))
        end
    end
end

--- Au chargement : les vols interrompus deviennent des livraisons en attente.
function Flights.restore()
    local s = state()
    for _, flight in ipairs(s.flights) do
        if not flight.dropped then
            local x, y = math.floor(flight.tx), math.floor(flight.ty)
            s.pending[pendingKey(x, y)] = {
                x = x, y = y, requester = flight.requester, requestId = flight.requestId, forced = flight.forced,
            }
        end
    end
    s.flights = {}
    if hasPending() then
        watchSquares()
    end
end

Events.OnInitGlobalModData.Add(Flights.restore)

return Flights
