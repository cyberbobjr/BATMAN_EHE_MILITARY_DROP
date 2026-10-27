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
    loadMod("shared/MilitaryDrop/MilitaryDrop_FultonFlight.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonRender.lua")
end

function T.rise_hold_and_pickup_have_continuous_heights()
    local P = MilitaryDrop.FultonRender
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
    local P = MilitaryDrop.FultonRender
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
    local P = MilitaryDrop.FultonRender
    P.start(0)
    for _ = 1, 15 do triggerEvent("OnTick") end
    assertTrue(math.abs(P.status().height - 1.45) < 0.000001, "linear ascent halfway at 1.5s")
    for _ = 1, 16 do triggerEvent("OnTick") end
    assertEq(P.status().phase, "pickup", "pickup immediately follows ascent")
    DRAWS = {}
    triggerEvent("OnPostRender")
    assertTrue(DRAWS[1].z > 0, "bag already rises at 3.1s without an idle hold")
    assertEq(MilitaryDrop.FultonFlight.HOLD_SECONDS, 0)
    assertEq(MilitaryDrop.FultonFlight.PICKUP_SECONDS, 1.5)
    for _ = 1, 15 do triggerEvent("OnTick") end
    assertEq(P.status().running, false, "complete cycle finishes after 4.5s")
end

function T.pause_restart_and_unloaded_square_are_clean()
    local P = MilitaryDrop.FultonRender
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
    local P = MilitaryDrop.FultonRender
    P.start(0, { duration = 1, hold = 0 })
    for _ = 1, 51 do triggerEvent("OnTick") end
    assertEq(P.status().running, false)
    P.start(0)
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonRender.lua")
    assertEq(listenerCount("OnTick"), 0)
    assertEq(listenerCount("OnFillWorldObjectContextMenu"), 0, "no test menu in the render file")
    assertEq(listenerCount("OnGameStart"), 1)
end

function T.test_menu_file_loads_only_in_debug_mode()
    isDebugEnabled = function() return false end
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonRender_Debug.lua")
    assertEq(MilitaryDrop.FultonRenderDebug, nil, "skipped outside debug mode")
    assertEq(listenerCount("OnFillWorldObjectContextMenu"), 0, "no menu outside debug mode")
    isDebugEnabled = function() return true end
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonRender_Debug.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonRender_Debug.lua")
    assertEq(listenerCount("OnFillWorldObjectContextMenu"), 0, "tools live in the central admin console")
    assertTrue(MilitaryDrop.FultonRenderDebug.canUse(getSpecificPlayer(0)))

end

return T
