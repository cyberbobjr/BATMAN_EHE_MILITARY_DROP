-- Ephemeral, server-authoritative prototype. Dedicated server never renders.
if isClient() then return end
require "MilitaryDrop/MilitaryDrop_FultonPrototypeFlight"
local Flight = MilitaryDrop.FultonPrototypeFlight
local previous = MilitaryDrop.FultonPrototypeServer
if previous then previous.dispose() end
local Server = {}
MilitaryDrop.FultonPrototypeServer = Server
local entries, requests = {}, {}
local ticking, syncIn = false, Flight.SYNC_SECONDS
local lastClock = 0
local nextId = MilitaryDrop.FultonPrototypeNextId or 0

local function broadcast(player)
    MilitaryDrop.FultonPrototypeRevision = (MilitaryDrop.FultonPrototypeRevision or 0) + 1
    local rows = {}
    for _, e in pairs(entries) do
        rows[#rows + 1] = { id = e.id, owner = e.owner, x = e.x, y = e.y, z = e.z,
            height = e.height, duration = e.duration, hold = e.hold, pickup = e.pickup,
            elapsed = e.elapsed, paused = e.paused, vanilla = e.vanilla }
    end
    local args = { revision = MilitaryDrop.FultonPrototypeRevision, sentAt = Flight.clock(), flights = rows }
    if player then
        sendServerCommand(player, Flight.MODULE, "Snapshot", args)
    else
        sendServerCommand(Flight.MODULE, "Snapshot", args)
    end
end

function Server.onTick()
    local players = getOnlinePlayers()
    local connected = {}
    for i = 0, players:size() - 1 do connected[players:get(i)] = true end
    -- Forget disconnected sender references and their request sequence.
    local forgotten = {}
    for player in pairs(requests) do
        if not connected[player] then forgotten[#forgotten + 1] = player end
    end
    for _, player in ipairs(forgotten) do requests[player] = nil end
    local now = Flight.clock()
    local dt = now > 0 and lastClock > 0 and math.max(0, (now - lastClock) / 1000)
        or Flight.bounded(getGameTime():getRealworldSecondsSinceLastUpdate(), 0, 0, 0.25)
    lastClock = now
    local finished = {}
    for id, e in pairs(entries) do
        if not e.paused then e.elapsed = e.elapsed + dt end
        if not connected[e.player] or e.player:isDead() or e.elapsed >= Flight.totalTime(e) then
            finished[#finished + 1] = id
        end
    end
    for _, id in ipairs(finished) do entries[id] = nil end
    syncIn = syncIn - dt
    if #finished > 0 or syncIn <= 0 then
        broadcast()
        syncIn = Flight.SYNC_SECONDS
    end
    if Server.count() == 0 then
        Events.OnTick.Remove(Server.onTick)
        ticking = false
    end
end

function Server.count()
    local n = 0
    for _ in pairs(entries) do n = n + 1 end
    return n
end

function Server.onClientCommand(module, command, player, args)
    if module ~= Flight.MODULE or not isServer() or not player then return end
    if command == "Sync" then broadcast(player); return end
    if command ~= "Start" and command ~= "Stop" and command ~= "Pause" then return end
    args = type(args) == "table" and args or {}
    local request = args.request
    if type(request) ~= "number" or request ~= request or request < 1 or request > 1e12
        or request ~= math.floor(request) then return end
    local owner = player:getOnlineID()
    local ownId
    for id, e in pairs(entries) do if e.owner == owner then ownId = id end end
    -- Pause targets an acknowledged flight, independently of newer starts.
    if command == "Pause" then
        if not ownId or args.id ~= ownId or request <= (entries[ownId].pauseRequest or 0) then return end
        entries[ownId].pauseRequest, entries[ownId].paused = request, args.paused == true
        broadcast()
        return
    end
    -- Start/Stop describe the latest desired flight; Stop cancels older starts.
    if request <= (requests[player] or 0) then return end
    requests[player] = request
    if command == "Start" then
        if player:isDead() or (not ownId and Server.count() >= Flight.MAX_FLIGHTS) then return end
        if ownId then entries[ownId] = nil end
        nextId = nextId + 1
        MilitaryDrop.FultonPrototypeNextId = nextId
        -- Never accept coordinates, owner or elapsed time supplied by the client.
        entries[nextId] = { id = nextId, player = player, owner = owner,
            x = player:getX() + 1.5, y = player:getY() + 1.5, z = math.floor(player:getZ()),
            height = Flight.bounded(args.height, 2.5, 0.1, 8),
            duration = Flight.bounded(args.duration, Flight.RISE_SECONDS, 1, 60),
            hold = Flight.bounded(args.hold, 20, 0, 300), pickup = Flight.PICKUP_SECONDS,
            elapsed = 0, paused = false, vanilla = args.vanilla == true }
        if not ticking then
            lastClock = Flight.clock()
            Events.OnTick.Add(Server.onTick)
            ticking = true
            syncIn = Flight.SYNC_SECONDS
        end
    elseif ownId then
        entries[ownId] = nil
    end
    broadcast()
end

function Server.dispose()
    entries = {}
    if isServer() then broadcast() end
    Events.OnTick.Remove(Server.onTick)
    Events.OnClientCommand.Remove(Server.onClientCommand)
end

Events.OnClientCommand.Add(Server.onClientCommand)
