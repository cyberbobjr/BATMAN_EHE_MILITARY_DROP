-- Shared visual trajectory and wire constants. No world/inventory mutation.
require "MilitaryDrop/MilitaryDrop_Core"
local Flight = {}
MilitaryDrop.FultonPrototypeFlight = Flight
Flight.MODULE = "MilitaryDropFultonPrototype"
Flight.RISE_SECONDS = 3
Flight.HOLD_SECONDS = 0
Flight.PICKUP_SECONDS = 1.5
Flight.MAX_FLIGHTS = 8
Flight.SYNC_SECONDS = 0.5

function Flight.bounded(value, default, low, high)
    if type(value) ~= "number" or value ~= value then return default end
    return math.max(low, math.min(high, value))
end

local function smooth(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

function Flight.totalTime(config)
    return config.duration + config.hold + (config.pickup or Flight.PICKUP_SECONDS)
end

function Flight.pose(elapsed, config)
    local departure = config.duration + config.hold
    -- Immediate vertical motion after release; no slow acceleration at launch.
    local height = config.height * math.max(0, math.min(1, elapsed / config.duration))
    local lift = elapsed > departure and smooth((elapsed - departure) / (config.pickup or Flight.PICKUP_SECONDS)) or 0
    local phase = elapsed < config.duration and "rise" or elapsed < departure and "hold" or "pickup"
    if elapsed >= Flight.totalTime(config) then phase = "done" end
    return {
        phase = phase, x = config.x + lift * 4, y = config.y + lift * 4,
        bagZ = config.z + lift * 2.5,
        balloonZ = config.z + 0.2 + height + lift * 2.5,
        alpha = 1 - smooth((lift - 0.7) / 0.3),
    }
end

-- Engine clock synchronized to the server, milliseconds (0 before MP sync).
function Flight.clock()
    return GameTime.getServerTimeMills()
end

return Flight
