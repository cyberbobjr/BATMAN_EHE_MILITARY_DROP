-- Mayday : décision unique du serveur, géométrie et données du vol.
require "MilitaryDrop/MilitaryDrop_Core"

local Crash = {}
MilitaryDrop.Crash = Crash
MilitaryDrop.Config.addDefaults({ CrashChance = 5, CrashStormBonus = 15, CrashGunfire = false,
    CrashGunfireChance = 10,
    CrashFire = 3, CrashSmokeMinutes = 60, CrashCrates = true, SalvageRolls = 3,
    PilotOutfits = "Army", PilotDocuments = true })
Crash.WARNING_SECONDS = 5

function Crash.finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Crash.chance(base, bonus, storm)
    return math.max(0, math.min(100, (tonumber(base) or 0) + (storm and (tonumber(bonus) or 0) or 0)))
end

-- Impact à la fin de l'approche : le point visé est déjà choisi sur terre ferme.
function Crash.plan(flight, cause)
    local dx, dy = flight.tx - flight.sx, flight.ty - flight.sy
    local time = math.sqrt(dx * dx + dy * dy) / 12
    return { t = time, x = flight.tx, y = flight.ty, dx = dx, dy = dy, cause = cause or "failure" }
end

function Crash.copy(data)
    if type(data) ~= "table" then return nil end
    for _, key in ipairs({ "t", "x", "y", "dx", "dy" }) do
        if not Crash.finite(data[key]) then return nil end
    end
    if data.t < 0 or data.dx * data.dx + data.dy * data.dy == 0 then return nil end
    return { t = data.t, x = data.x, y = data.y, dx = data.dx, dy = data.dy }
end

function Crash.roll(flight, storm, rand)
    local config = MilitaryDrop.Config
    local chance = Crash.chance(config.get("CrashChance"), config.get("CrashStormBonus"), storm)
    if chance > 0 and (rand or ZombRand)(100) < chance then
        return Crash.plan(flight, storm and "storm" or "failure")
    end
    return nil
end

function Crash.offset(data, along, across)
    local length = math.sqrt(data.dx * data.dx + data.dy * data.dy)
    local dx, dy = data.dx / length, data.dy / length
    return math.floor(data.x + dx * along - dy * across), math.floor(data.y + dy * along + dx * across)
end

function Crash.direction(data)
    if math.abs(data.dx) > math.abs(data.dy) then return data.dx > 0 and "E" or "W" end
    return data.dy > 0 and "S" or "N"
end

return Crash
