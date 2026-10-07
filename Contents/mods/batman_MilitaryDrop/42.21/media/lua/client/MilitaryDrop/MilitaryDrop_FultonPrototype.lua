-- Fulton balloon rendering; MP trajectories come exclusively from the server.
-- Real launches (FULTON-07): server flights marked `real`, or a local anchored
-- flight in solo (Prototype.startAt). Each client plays the aircraft flyby
-- locally when a real flight starts (FULTON-06 sound, peak at 3.8 s = pickup).
-- The test menu is admin-only: in MP, a role with Capability.MakeEventsAlarmGunshot
-- (same right as /chopper and the forced drop); in solo, debug mode only. The server
-- re-checks the right for Start/Stop/Pause.
require "MilitaryDrop/MilitaryDrop_FultonPrototypeFlight"
local Flight = MilitaryDrop.FultonPrototypeFlight
local previous = MilitaryDrop.FultonPrototype
if previous then previous.dispose() end
local Prototype = {}
MilitaryDrop.FultonPrototype = Prototype
Prototype.pose = Flight.pose
local entries, active = {}, nil
-- Solo anchored flights use negative ids (server flights are positive).
local nextLocalId = 0
local modes = { auto = true, world = true, post = true }
local mode, cable, selectedPlayerNum = "auto", true, 0
local ticking, revision = false, -1
local worldFrames, postFrames, lastRenderer = 0, 0, nil
local drewInWorld = {}
Prototype.SOUND = "MilitaryDropFultonFlyby"
-- High emitter: never muffled by walls (as MilitaryDrop_Heli.lua).
Prototype.SOUND_Z = 20
-- A flight discovered later than this (join, unloaded area) plays no flyby.
Prototype.SOUND_LATE_SECONDS = 1

--- Aircraft flyby, local to this client. Never playSoundImpl(name, nil): Kahlua
--- would pick the (String, IsoGridSquare) overload and throw (NPE).
function Prototype.playFlyby(x, y)
    local world = getWorld and getWorld()
    local emitter = world and world:getFreeEmitter(x, y, Prototype.SOUND_Z)
    if emitter then
        emitter:playSoundImpl(Prototype.SOUND, false, nil)
    end
end

local function clear()
    entries, active, drewInWorld = {}, nil, {}
    ticking = false
    Events.OnTick.Remove(Prototype.onTick)
    Events.RenderOpaqueObjectsInWorld.Remove(Prototype.onWorldRender)
    Events.OnPostRender.Remove(Prototype.onPostRender)
end

local function startTicking()
    if ticking then return end
    ticking = true
    Events.OnTick.Add(Prototype.onTick)
    Events.RenderOpaqueObjectsInWorld.Add(Prototype.onWorldRender)
    Events.OnPostRender.Add(Prototype.onPostRender)
end

local function request(command, args)
    local player = getSpecificPlayer(selectedPlayerNum)
    if not player then return false end
    MilitaryDrop.FultonPrototypeRequest = (MilitaryDrop.FultonPrototypeRequest or 0) + 1
    args = args or {}
    args.request = MilitaryDrop.FultonPrototypeRequest
    sendClientCommand(player, Flight.MODULE, command, args)
    return true
end

function Prototype.stop()
    if isClient() then return request("Stop") end
    clear()
end

local function items(vanilla)
    local balloon = instanceItem(vanilla and "Base.Bobber" or "MilitaryDrop.FultonPrototypeBalloon")
    local bag = instanceItem("MilitaryDrop.FultonPrototypeBag")
    if balloon and vanilla then balloon:setWorldScale(8) end
    return balloon, bag
end

function Prototype.onServerCommand(module, command, args)
    if module ~= Flight.MODULE or command ~= "Snapshot" or type(args) ~= "table" then return end
    if type(args.revision) ~= "number" or args.revision <= revision or type(args.flights) ~= "table" then return end
    revision = args.revision
    local updated = {}
    local ownPlayer = getSpecificPlayer(selectedPlayerNum)
    active = nil
    for _, row in ipairs(args.flights) do
        local known = entries[row.id] ~= nil
        local e = entries[row.id] or {}
        if not e.balloon then e.balloon, e.bag = items(row.vanilla) end
        if e.balloon and e.bag then
            for _, key in ipairs({ "id", "owner", "x", "y", "z", "height", "duration", "hold", "pickup",
                "elapsed", "paused", "vanilla" }) do e[key] = row[key] end
            e.shared, e.serverAt, e.serverElapsed = true, args.sentAt or 0, row.elapsed
            updated[e.id] = e
            if row.real and not known and (tonumber(row.elapsed) or 0) < Prototype.SOUND_LATE_SECONDS then
                Prototype.playFlyby(row.x, row.y)
            end
            if ownPlayer and e.owner == ownPlayer:getOnlineID() then active = e end
        end
    end
    entries = updated
    if #args.flights == 0 then clear() else startTicking() end
end

function Prototype.onTick()
    local dt = Flight.bounded(getGameTime():getRealworldSecondsSinceLastUpdate(), 0, 0, 0.25)
    local now = isClient() and Flight.clock() or 0
    local finished = {}
    for id, e in pairs(entries) do
        if e.anchored then
            if not e.paused and getGameSpeed() ~= 0 then e.elapsed = e.elapsed + dt end
        elseif e.shared then
            -- Server clock also accounts for packet transit time.
            if e.paused then e.elapsed = e.serverElapsed
            elseif now > 0 and e.serverAt > 0 then
                e.elapsed = e.serverElapsed + math.max(0, (now - e.serverAt) / 1000)
            else e.elapsed = e.elapsed + dt end
        else
            local player = getSpecificPlayer(e.playerNum)
            local square = getCell():getGridSquare(math.floor(e.x), math.floor(e.y), e.z)
            if not player or player:isDead() or not square then finished[#finished + 1] = id
            elseif not e.paused and getGameSpeed() ~= 0 then e.elapsed = e.elapsed + dt end
        end
        local pose = Flight.pose(e.elapsed, e)
        if pose.phase ~= e.phase then
            e.phase = pose.phase
            print("[MilitaryDrop Fulton prototype] " .. tostring(id) .. " " .. pose.phase)
        end
        if pose.phase == "done" then finished[#finished + 1] = id end
    end
    for _, id in ipairs(finished) do
        if entries[id] == active then active = nil end
        entries[id] = nil
    end
    if Prototype.count() == 0 then clear() end
end

function Prototype.count()
    local n = 0
    for _ in pairs(entries) do n = n + 1 end
    return n
end

local function draw(playerNum, source)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return false end
    local drawn = false
    for _, e in pairs(entries) do
        local dx, dy = player:getX() - e.x, player:getY() - e.y
        local square = dx * dx + dy * dy <= 120 * 120
            and getCell():getGridSquare(math.floor(e.x), math.floor(e.y), e.z) or nil
        -- Unloaded squares hide MP visuals without cancelling the shared flight.
        if square then
            local pose = Flight.pose(e.elapsed, e)
            e.balloon:setWorldAlpha(pose.alpha)
            e.bag:setWorldAlpha(pose.alpha)
            Render3DItem(e.bag, square, pose.x, pose.y, pose.bagZ, 0)
            Render3DItem(e.balloon, square, pose.x, pose.y, pose.balloonZ, 0)
            if cable then
                renderIsoLine(pose.x, pose.y, pose.bagZ + 0.25,
                    pose.x, pose.y, pose.balloonZ + 0.015, 1, 0.25, 0.28, 0.25, pose.alpha)
            end
            drawn = true
        end
    end
    if drawn then
        lastRenderer = source
        if source == "world" then worldFrames = worldFrames + 1 else postFrames = postFrames + 1 end
    end
    return drawn
end

function Prototype.onWorldRender(playerNum)
    if mode ~= "post" then drewInWorld[playerNum] = draw(playerNum, "world") end
end

function Prototype.onPostRender()
    local playerNum = IsoPlayer.getPlayerIndex()
    if mode == "post" or (mode == "auto" and not drewInWorld[playerNum]) then draw(playerNum, "post") end
    drewInWorld[playerNum] = nil
end

function Prototype.start(playerNum, options)
    playerNum, options = playerNum or 0, options or {}
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return false, "no living local player" end
    selectedPlayerNum = playerNum
    mode = modes[options.mode] and options.mode or "auto"
    if isClient() then
        return request("Start", { height = options.height, duration = options.duration,
            hold = options.hold, vanilla = options.vanilla == true })
    end
    local x, y, z = player:getX() + 1.5, player:getY() + 1.5, math.floor(player:getZ())
    if not getCell():getGridSquare(math.floor(x), math.floor(y), z) then return false, "source square not loaded" end
    local balloon, bag = items(options.vanilla)
    if not balloon or not bag then return false, "missing item scripts; restart game" end
    clear()
    active = { id = 0, playerNum = playerNum, x = x, y = y, z = z,
        balloon = balloon, bag = bag, elapsed = 0, phase = "rise", paused = false,
        height = Flight.bounded(options.height, 2.5, 0.1, 8),
        duration = Flight.bounded(options.duration, Flight.RISE_SECONDS, 1, 60),
        hold = Flight.bounded(options.hold, Flight.HOLD_SECONDS, 0, 300), pickup = Flight.PICKUP_SECONDS }
    entries[0] = active
    worldFrames, postFrames, lastRenderer = 0, 0, nil
    startTicking()
    return true
end

--- Solo real launch (FULTON-07): local flight anchored at x, y, z, independent
--- of any player, with the flyby. MP launches arrive by Snapshot instead.
function Prototype.startAt(x, y, z)
    local balloon, bag = items(false)
    if not balloon or not bag then return false end
    nextLocalId = nextLocalId - 1
    entries[nextLocalId] = { id = nextLocalId, anchored = true, real = true, x = x, y = y, z = math.floor(z),
        balloon = balloon, bag = bag, elapsed = 0, phase = "rise", paused = false, height = 2.5,
        duration = Flight.RISE_SECONDS, hold = Flight.HOLD_SECONDS, pickup = Flight.PICKUP_SECONDS }
    startTicking()
    Prototype.playFlyby(x, y)
    return true
end

function Prototype.togglePause()
    if not active then return end
    if isClient() then return request("Pause", { id = active.id, paused = not active.paused }) end
    active.paused = not active.paused
end

function Prototype.toggleCable() cable = not cable end

function Prototype.setMode(value)
    if not modes[value] then return false end
    mode, drewInWorld = value, {}
    return true
end

function Prototype.status()
    local s = { running = active ~= nil, count = Prototype.count(), mode = mode, revision = revision,
        worldFrames = worldFrames, postFrames = postFrames, lastRenderer = lastRenderer }
    if active then
        local pose = Flight.pose(active.elapsed, active)
        s.phase, s.height = pose.phase, pose.balloonZ - active.z
        s.elapsed, s.paused = active.elapsed, active.paused
    end
    return s
end

local function startFromMenu(playerNum, vanilla) Prototype.start(playerNum, { vanilla = vanilla }) end

--- Right to see the test menu (display only; the server re-checks).
function Prototype.canUse(player)
    if not player then return false end
    if isClient() then
        local role = player:getRole()
        return role ~= nil and Capability ~= nil and role:hasCapability(Capability.MakeEventsAlarmGunshot) == true
    end
    return isDebugEnabled ~= nil and isDebugEnabled() == true
end

function Prototype.onContext(playerNum, context, worldObjects, test)
    if test or not Prototype.canUse(getSpecificPlayer(playerNum)) then return end
    selectedPlayerNum = playerNum
    if isClient() then
        active = nil
        for _, e in pairs(entries) do
            if e.owner == getSpecificPlayer(playerNum):getOnlineID() then active = e end
        end
    end
    local option = context:addOption("Fulton - prototype visuel")
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    sub:addOption("Lancer la montee du ballon", playerNum, startFromMenu, false)
    sub:addOption("Comparer avec le flotteur vanilla", playerNum, startFromMenu, true)
    if active then
        sub:addOption(active.paused and "Reprendre l'animation" or "Figer l'animation", nil, Prototype.togglePause)
        sub:addOption("Arreter le prototype", nil, Prototype.stop)
    end
    if Prototype.count() > 0 then
        sub:addOption("Afficher / masquer le cable", nil, Prototype.toggleCable)
        sub:addOption("Rendu automatique (avec secours)", "auto", Prototype.setMode)
        sub:addOption("Rendu monde uniquement (flotteur vanilla)", "world", Prototype.setMode)
        sub:addOption("Rendu apres le monde uniquement", "post", Prototype.setMode)
    end
end

function Prototype.onGameStart()
    clear()
    revision = -1
    if isClient() then request("Sync") end
end

function Prototype.onDisconnect()
    clear()
    revision = -1
end

function Prototype.dispose()
    clear() -- A local Lua reload mustn't stop the shared server flight.
    Events.OnFillWorldObjectContextMenu.Remove(Prototype.onContext)
    Events.OnGameStart.Remove(Prototype.onGameStart)
    Events.OnDisconnect.Remove(Prototype.onDisconnect)
    Events.OnServerCommand.Remove(Prototype.onServerCommand)
end

Events.OnFillWorldObjectContextMenu.Add(Prototype.onContext)
Events.OnGameStart.Add(Prototype.onGameStart)
Events.OnDisconnect.Add(Prototype.onDisconnect)
Events.OnServerCommand.Add(Prototype.onServerCommand)
