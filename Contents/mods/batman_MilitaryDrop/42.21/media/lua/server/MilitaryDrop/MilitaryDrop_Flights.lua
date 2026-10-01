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
-- Largage : les coordonnées sont annoncées au passage de l'hélicoptère, même
-- si la zone n'est pas chargée (point lointain). La caisse est posée dès que
-- la case du point est chargée : aussitôt, ou à la fin du chargement d'un
-- chunk (LoadChunk : après les histoires de bâtiment et le butin, une fois par
-- chunk de 8 × 8 cases), jusqu'à ce qu'une case convienne. Livrer dès qu'un
-- chunk voisin se chargeait posait la caisse sur la case chargée la plus
-- proche, en bordure de la zone chargée, loin du repère (test solo du
-- 2026-09-30 : 24 et 42 cases).
--
-- Persistance (ModData « MilitaryDrop ») : les vols en cours et les
-- livraisons en attente, avec le dropId du largage (confiance, jamais envoyé
-- aux clients). Au chargement de la partie, un vol interrompu reprend là où il
-- en était ; les clients le redemandent (Sync).
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Server"

local Flight = MilitaryDrop.Flight
local Net = MilitaryDrop.Net
local Server = MilitaryDrop.Server

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
Flights.CHUNK_SIZE = 8

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
-- Livraisons en attente du chargement de leur chunk
-- ----------------------------------------------------------------------------

--- Livre les largages en attente dont la case du point est désormais chargée.
local function onLoadChunk()
    local pending = state().pending
    local cell = getCell()
    -- Kahlua : relever les entrées, puis les retirer après le pairs.
    local ready = {}
    for key, entry in pairs(pending) do
        if cell:getGridSquare(entry.x, entry.y, 0) then
            ready[#ready + 1] = key
        end
    end
    for _, key in ipairs(ready) do
        local entry = pending[key]
        if Server.deliver(entry.x, entry.y, entry.requester, entry.dropId) then
            pending[key] = nil
        end
    end
    if not hasPending() then
        Events.LoadChunk.Remove(onLoadChunk)
        watchingSquares = false
    end
end

local function watchSquares()
    if not watchingSquares then
        watchingSquares = true
        Events.LoadChunk.Add(onLoadChunk)
    end
end

--- Livre au point (x, y) : tout de suite si la zone est chargée, sinon en
--- attente du chargement de cette case. dropId : largage (confiance).
function Flights.deliverAt(x, y, requester, dropId)
    if getCell():getGridSquare(x, y, 0) and Server.deliver(x, y, requester, dropId) then
        return
    end
    state().pending[pendingKey(x, y)] = { x = x, y = y, requester = requester, dropId = dropId }
    watchSquares()
    MilitaryDrop.log(string.format("drop at %d,%d waits for its area to load", x, y))
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
    MilitaryDrop.Broadcast.dropped(x, y)
    Server.notifyDrop(flight.requester, flight.requestId, x, y, flight.forced)
    Flights.deliverAt(x, y, flight.requester, flight.dropId)
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
        MilitaryDrop.Broadcast.inbound()
        MilitaryDrop.log(string.format("flight %d started toward %d,%d", flight.id, flight.tx, flight.ty))
    elseif flight.resumed then
        -- Vol repris après un chargement : les clients (solo compris) le redécouvrent.
        flight.resumed = nil
        Net.toAll("FlightStart", Flight.toArgs(flight))
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

--- Lance un hélicoptère vers le point (x, y) (forced : largage admin ;
--- dropId : largage, Trust.registerDrop).
function Flights.launch(x, y, requester, requestId, forced, dropId)
    local s = state()
    s.nextFlightId = (tonumber(s.nextFlightId) or 0) + 1
    local flight = Flight.new(s.nextFlightId, x + 0.5, y + 0.5, ZombRandFloat(0, 2 * math.pi))
    flight.requester = requester
    flight.requestId = requestId
    flight.forced = forced == true
    flight.dropId = dropId
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

--- Au chargement : les vols interrompus reprennent, les livraisons en attente
--- guettent le chargement de leur zone.
function Flights.restore()
    local s = state()
    for _, flight in ipairs(s.flights) do
        flight.resumed = true
    end
    if #s.flights > 0 then
        startTicking()
    end
    if hasPending() then
        watchSquares()
    end
end

Events.OnInitGlobalModData.Add(Flights.restore)

return Flights
