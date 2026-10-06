-- Lifecycle and render scheduling only; Java/OpenGL compatibility needs the game.
local T = {}

function T.setup()
    MilitaryDrop = {}
    isClient = function() return false end
    PLAYER = { getX = function() return 100 end, getY = function() return 200 end,
        getZ = function() return 0 end, isDead = function() return false end }
    getSpecificPlayer = function() return PLAYER end
    LOADED, SPEED = true, 1
    getCell = function() return { getGridSquare = function() return LOADED and {} or nil end } end
    getGameSpeed = function() return SPEED end
    getGameTime = function() return { getRealworldSecondsSinceLastUpdate = function() return 0.1 end } end
    instanceItem = function(kind)
        return { kind = kind, setWorldAlpha = function(self, alpha) self.alpha = alpha end,
            setWorldScale = function(self, scale) self.scale = scale end }
    end
    IsoPlayer = { getPlayerIndex = function() return 0 end }
    DRAWS = {}
    Render3DItem = function(item, square, x, y, z)
        DRAWS[#DRAWS + 1] = { kind = item.kind, x = x, y = y, z = z, alpha = item.alpha }
    end
    renderIsoLine = function() end
    loadMod("shared/MilitaryDrop/MilitaryDrop_FultonPrototypeFlight.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonPrototype.lua")
end

function T.rise_hold_and_pickup_have_continuous_heights()
    local P = MilitaryDrop.FultonPrototype
    local config = { x = 100, y = 200, z = 2, height = 2.5, duration = 10, hold = 20, pickup = 4 }
    assertEq(P.pose(0, config).balloonZ, 2.2)
    local mid = P.pose(5, config)
    assertEq(mid.balloonZ, 3.45)
    assertEq(mid.bagZ, 2, "bag stays on the ground during rise")
    local hold = P.pose(15, config)
    assertEq(hold.phase, "hold")
    assertEq(hold.balloonZ, 4.7)
    local pickup = P.pose(32, config)
    assertEq(pickup.phase, "pickup")
    assertEq(pickup.bagZ, 3.25)
    assertEq(pickup.x, 102)
    assertEq(P.pose(34, config).phase, "done")
end

function T.auto_draws_once_and_falls_back_if_world_event_is_missing()
    local P = MilitaryDrop.FultonPrototype
    assertTrue(P.start(0))
    triggerEvent("RenderOpaqueObjectsInWorld", 0)
    triggerEvent("OnPostRender")
    assertEq(#DRAWS, 2, "one bag and one balloon, no duplicate post-render")
    triggerEvent("OnPostRender")
    assertEq(#DRAWS, 4, "fallback without cursor-dependent event")
    local status = P.status()
    assertEq(status.worldFrames, 1)
    assertEq(status.postFrames, 1)
    P.setMode("world")
    triggerEvent("OnPostRender")
    assertEq(#DRAWS, 4, "strict world mode has no fallback")
    P.setMode("post")
    triggerEvent("RenderOpaqueObjectsInWorld", 0)
    triggerEvent("OnPostRender")
    assertEq(#DRAWS, 6, "strict post mode")
end

function T.default_ascent_reaches_full_height_in_three_seconds()
    local P = MilitaryDrop.FultonPrototype
    P.start(0)
    for _ = 1, 15 do triggerEvent("OnTick") end
    assertTrue(math.abs(P.status().height - 1.45) < 0.000001, "linear ascent halfway at 1.5s")
    for _ = 1, 16 do triggerEvent("OnTick") end
    assertEq(P.status().phase, "hold")
    assertEq(P.status().height, 2.7)
    assertEq(MilitaryDrop.FultonPrototypeFlight.PICKUP_SECONDS, 1.5)
end

function T.pause_restart_and_unloaded_square_are_clean()
    local P = MilitaryDrop.FultonPrototype
    P.start(0)
    triggerEvent("OnTick")
    local elapsed = P.status().elapsed
    P.togglePause()
    triggerEvent("OnTick")
    assertEq(P.status().elapsed, elapsed, "inspection pause")
    P.togglePause()
    SPEED = 0
    triggerEvent("OnTick")
    assertEq(P.status().elapsed, elapsed, "game pause")
    P.start(0)
    assertEq(listenerCount("OnTick"), 1, "restart doesn't stack callbacks")
    assertEq(listenerCount("OnPostRender"), 1)
    LOADED = false
    triggerEvent("OnTick")
    assertEq(P.status().running, false)
    assertEq(listenerCount("OnTick"), 0)
    assertEq(listenerCount("OnPostRender"), 0)
    assertEq(listenerCount("RenderOpaqueObjectsInWorld"), 0)
end

function T.completion_and_lua_reload_remove_old_callbacks()
    local P = MilitaryDrop.FultonPrototype
    P.start(0, { duration = 1, hold = 0 })
    for _ = 1, 51 do triggerEvent("OnTick") end
    assertEq(P.status().running, false)
    P.start(0)
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonPrototype.lua")
    assertEq(listenerCount("OnTick"), 0)
    assertEq(listenerCount("OnFillWorldObjectContextMenu"), 1)
    assertEq(listenerCount("OnGameStart"), 1)
end

return T
