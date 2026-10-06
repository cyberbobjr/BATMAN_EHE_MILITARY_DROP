-- Visual-only prototype on prototype/fulton-ascent. No inventory/world writes.
-- Right-click the world, or MilitaryDrop.FultonPrototype.start(0) in debug Lua.
require "MilitaryDrop/MilitaryDrop_Core"

local previous = MilitaryDrop.FultonPrototype
if previous then previous.dispose() end

local Prototype = {}
MilitaryDrop.FultonPrototype = Prototype
local active
local modes = { auto = true, world = true, post = true }

local function bounded(value, default, low, high)
    if type(value) ~= "number" or value ~= value then return default end
    return math.max(low, math.min(high, value))
end

local function smooth(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3 - 2 * t)
end

-- Pure position calculation; heights are world levels, not metres.
function Prototype.pose(elapsed, config)
    local rise = config.duration
    local departure = rise + config.hold
    local height = config.height * smooth(elapsed / rise)
    local lift = elapsed > departure and smooth((elapsed - departure) / 4) or 0
    local phase = elapsed < rise and "rise" or elapsed < departure and "hold" or "pickup"
    if elapsed >= departure + 4 then phase = "done" end
    return {
        phase = phase,
        x = config.x + lift * 4,
        y = config.y + lift * 4,
        bagZ = config.z + lift * 2.5,
        balloonZ = config.z + 0.2 + height + lift * 2.5,
        alpha = 1 - smooth((lift - 0.7) / 0.3),
    }
end

function Prototype.stop()
    if active then print("[MilitaryDrop Fulton prototype] stopped") end
    active = nil
    Events.OnTick.Remove(Prototype.onTick)
    Events.RenderOpaqueObjectsInWorld.Remove(Prototype.onWorldRender)
    Events.OnPostRender.Remove(Prototype.onPostRender)
end

function Prototype.onTick()
    if not active then return end
    local player = getSpecificPlayer(active.playerNum)
    local square = getCell():getGridSquare(math.floor(active.x), math.floor(active.y), active.z)
    if not player or player:isDead() or not square then
        Prototype.stop()
        return
    end
    -- Engine delta avoids a jump after a long pause. Keep real-time test speed.
    if not active.paused and getGameSpeed() ~= 0 then
        local dt = bounded(getGameTime():getRealworldSecondsSinceLastUpdate(), 0, 0, 0.1)
        active.elapsed = active.elapsed + dt
    end
    local pose = Prototype.pose(active.elapsed, active)
    if pose.phase ~= active.phase then
        active.phase = pose.phase
        print("[MilitaryDrop Fulton prototype] " .. pose.phase)
    end
    if pose.phase == "done" then Prototype.stop() end
end

local function draw(playerNum, source)
    if not active or playerNum ~= active.playerNum then return false end
    -- Reacquire the loaded source square; no cached square after chunk unload.
    local square = getCell():getGridSquare(math.floor(active.x), math.floor(active.y), active.z)
    if not square then return false end
    local pose = Prototype.pose(active.elapsed, active)
    active.balloon:setWorldAlpha(pose.alpha)
    active.bag:setWorldAlpha(pose.alpha)
    Render3DItem(active.bag, square, pose.x, pose.y, pose.bagZ, 0)
    Render3DItem(active.balloon, square, pose.x, pose.y, pose.balloonZ, 0)
    if active.cable then
        -- Screen line for this experiment; cable occlusion isn't a 3D guarantee.
        renderIsoLine(pose.x, pose.y, pose.bagZ + 0.25,
            pose.x, pose.y, pose.balloonZ + 0.015, 1, 0.25, 0.28, 0.25, pose.alpha)
    end
    active.lastRenderer = source
    if source == "world" then
        active.worldFrames = active.worldFrames + 1
    else
        active.postFrames = active.postFrames + 1
    end
    return true
end

function Prototype.onWorldRender(playerNum)
    if active and active.mode ~= "post" then
        active.drewInWorld = draw(playerNum, "world")
    end
end

function Prototype.onPostRender()
    if not active or IsoPlayer.getPlayerIndex() ~= active.playerNum then return end
    if active.mode == "post" or (active.mode == "auto" and not active.drewInWorld) then
        draw(active.playerNum, "post")
    end
    active.drewInWorld = false
end

function Prototype.start(playerNum, options)
    playerNum = playerNum or 0
    options = options or {}
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return false, "no living local player" end
    local x, y, z = player:getX() + 1.5, player:getY() + 1.5, math.floor(player:getZ())
    if not getCell():getGridSquare(math.floor(x), math.floor(y), z) then
        return false, "source square not loaded"
    end
    local balloon = instanceItem(options.vanilla and "Base.Bobber" or "MilitaryDrop.FultonPrototypeBalloon")
    local bag = instanceItem("MilitaryDrop.FultonPrototypeBag")
    if not balloon or not bag then
        print("[MilitaryDrop Fulton prototype] missing item scripts; restart the game")
        return false, "missing item scripts"
    end
    if options.vanilla then balloon:setWorldScale(8) end
    Prototype.stop()
    active = {
        playerNum = playerNum, x = x, y = y, z = z,
        balloon = balloon, bag = bag, elapsed = 0, phase = "rise",
        height = bounded(options.height, 2.5, 0.1, 8),
        duration = bounded(options.duration, 10, 1, 60),
        hold = bounded(options.hold, 20, 0, 300),
        mode = modes[options.mode] and options.mode or "auto",
        cable = true, paused = false, drewInWorld = false,
        worldFrames = 0, postFrames = 0,
    }
    Events.OnTick.Add(Prototype.onTick)
    Events.RenderOpaqueObjectsInWorld.Add(Prototype.onWorldRender)
    Events.OnPostRender.Add(Prototype.onPostRender)
    print("[MilitaryDrop Fulton prototype] start; mode=" .. active.mode .. "; height=" .. active.height)
    return true
end

function Prototype.togglePause()
    if active then active.paused = not active.paused end
end

function Prototype.toggleCable()
    if active then active.cable = not active.cable end
end

function Prototype.setMode(mode)
    if not active or not modes[mode] then return false end
    active.mode, active.drewInWorld = mode, false
    print("[MilitaryDrop Fulton prototype] renderer=" .. mode)
    return true
end

function Prototype.status()
    if not active then return { running = false } end
    local pose = Prototype.pose(active.elapsed, active)
    return {
        running = true, phase = pose.phase, height = pose.balloonZ - active.z,
        elapsed = active.elapsed, paused = active.paused, mode = active.mode,
        lastRenderer = active.lastRenderer, worldFrames = active.worldFrames, postFrames = active.postFrames,
    }
end

local function startFromMenu(playerNum, vanilla)
    Prototype.start(playerNum, { vanilla = vanilla })
end

function Prototype.onContext(playerNum, context, worldObjects, test)
    if test or not getSpecificPlayer(playerNum) then return end
    local option = context:addOption("Fulton - prototype visuel")
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    sub:addOption("Lancer la montee du ballon", playerNum, startFromMenu, false)
    sub:addOption("Comparer avec le flotteur vanilla", playerNum, startFromMenu, true)
    if active then
        sub:addOption(active.paused and "Reprendre l'animation" or "Figer l'animation", nil, Prototype.togglePause)
        sub:addOption("Arreter le prototype", nil, Prototype.stop)
        sub:addOption("Afficher / masquer le cable", nil, Prototype.toggleCable)
        sub:addOption("Rendu automatique (avec secours)", "auto", Prototype.setMode)
        sub:addOption("Rendu monde uniquement (flotteur vanilla)", "world", Prototype.setMode)
        sub:addOption("Rendu apres le monde uniquement", "post", Prototype.setMode)
    end
end

function Prototype.dispose()
    Prototype.stop()
    Events.OnFillWorldObjectContextMenu.Remove(Prototype.onContext)
    Events.OnGameStart.Remove(Prototype.stop)
end

-- Menu intentionally available without -debug on this development branch.
Events.OnFillWorldObjectContextMenu.Add(Prototype.onContext)
Events.OnGameStart.Add(Prototype.stop)
