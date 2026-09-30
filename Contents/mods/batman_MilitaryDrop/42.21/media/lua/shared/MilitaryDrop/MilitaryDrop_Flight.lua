-- ============================================================================
-- Military Drop — trajectoire de l'hélicoptère (calcul pur, partagé)
--
-- Ligne droite : arrivée depuis APPROACH_DISTANCE cases, vol stationnaire de
-- HOVER_SECONDS au-dessus du point de largage (la caisse tombe après
-- DROP_DELAY_SECONDS), puis départ dans le même cap sur EXIT_DISTANCE cases.
-- La position ne dépend que du temps écoulé (secondes réelles de jeu non
-- suspendu) : le serveur l'avance, les clients l'extrapolent entre deux
-- synchronisations et obtiennent la même position.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Flight = {}
MilitaryDrop.Flight = Flight

Flight.SPEED = 12 -- cases par seconde
Flight.APPROACH_DISTANCE = 600
Flight.EXIT_DISTANCE = 600
Flight.HOVER_SECONDS = 8
Flight.DROP_DELAY_SECONDS = 3

--- Nouveau vol vers (tx, ty) selon un cap en radians.
function Flight.new(id, tx, ty, heading)
    local dx, dy = math.cos(heading), math.sin(heading)
    return {
        id = id,
        sx = tx - dx * Flight.APPROACH_DISTANCE, sy = ty - dy * Flight.APPROACH_DISTANCE,
        tx = tx, ty = ty,
        ex = tx + dx * Flight.EXIT_DISTANCE, ey = ty + dy * Flight.EXIT_DISTANCE,
        elapsed = 0,
    }
end

local function distance(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    return math.sqrt(dx * dx + dy * dy)
end

--- Durées des trois phases (secondes).
function Flight.timeline(flight)
    local approach = distance(flight.sx, flight.sy, flight.tx, flight.ty) / Flight.SPEED
    local leave = distance(flight.tx, flight.ty, flight.ex, flight.ey) / Flight.SPEED
    return approach, Flight.HOVER_SECONDS, leave
end

--- Instant du largage (secondes depuis le départ).
function Flight.dropTime(flight)
    local approach = Flight.timeline(flight)
    return approach + Flight.DROP_DELAY_SECONDS
end

function Flight.totalTime(flight)
    local approach, hover, leave = Flight.timeline(flight)
    return approach + hover + leave
end

--- Position (x, y) et phase ("approach", "hover", "leave", "done") à l'instant t.
function Flight.position(flight, t)
    local approach, hover, leave = Flight.timeline(flight)
    if t <= 0 then
        return flight.sx, flight.sy, "approach"
    end
    if t < approach then
        local k = t / approach
        return flight.sx + (flight.tx - flight.sx) * k, flight.sy + (flight.ty - flight.sy) * k, "approach"
    end
    if t < approach + hover then
        return flight.tx, flight.ty, "hover"
    end
    local after = t - approach - hover
    if after < leave then
        local k = after / leave
        return flight.tx + (flight.ex - flight.tx) * k, flight.ty + (flight.ey - flight.ty) * k, "leave"
    end
    return flight.ex, flight.ey, "done"
end

--- Copie transmissible d'un vol (nombres seulement).
function Flight.toArgs(flight)
    return {
        id = flight.id, sx = flight.sx, sy = flight.sy, tx = flight.tx, ty = flight.ty,
        ex = flight.ex, ey = flight.ey, elapsed = flight.elapsed,
    }
end

--- Vol reçu du réseau ou relu de la ModData, ou nil s'il est incohérent.
function Flight.fromArgs(args)
    if type(args) ~= "table" then
        return nil
    end
    for _, key in ipairs({ "id", "sx", "sy", "tx", "ty", "ex", "ey", "elapsed" }) do
        if type(args[key]) ~= "number" then
            return nil
        end
    end
    return Flight.toArgs(args)
end

return Flight
