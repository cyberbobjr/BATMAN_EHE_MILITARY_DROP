local T = {}
function T.setup()
    AUTHORIZED, FORCE, DEBUG, ACTIVE, CALL = true, true, true, false, nil
    PLAYER = { getPlayerNum = function() return 0 end }
    local function record(name, arg) CALL = { name, arg } end
    MilitaryDrop = {
        Admin = { allowed = function() return AUTHORIZED end },
        Client = { canForce = function() return FORCE end,
            onRequest = function(p, radio, forced) assertEq(radio, nil); record("drop", forced) end,
            onAdminCrashNext = function() record("crash") end },
        FultonRenderDebug = { canUse = function() return DEBUG and FORCE end },
        FultonRender = {
            start = function(index, opts) record("start", opts.vanilla) end,
            selectPlayer = function() return ACTIVE and {} or nil end,
            count = function() return ACTIVE and 1 or 0 end,
            togglePause = function() record("pause") end,
            stop = function() record("stop") end,
            toggleCable = function() record("cable") end,
            setMode = function(mode) record("mode", mode) end } }
    TOOLS = loadMod("client/MilitaryDrop/MilitaryDrop_AdminTools.lua")
end
function T.force_drop_needs_no_radio_and_uses_existing_handler()
    assertEq(TOOLS.execute(PLAYER, "forcedrop", "forceDrop"), true)
    assertEq(CALL[1], "drop"); assertEq(CALL[2], true)
    assertEq(TOOLS.execute(PLAYER, "crash", "crashNext"), true)
    assertEq(CALL[1], "crash")
end
function T.revoked_or_insufficient_role_cannot_dispatch()
    FORCE = false
    assertEq(TOOLS.execute(PLAYER, "forcedrop", "forceDrop"), false)
    FORCE, AUTHORIZED = true, false
    assertEq(TOOLS.execute(PLAYER, "crash", "crashNext"), false)
    assertEq(CALL, nil)
end
function T.fulton_controls_retain_debug_guard_and_active_flight_requirement()
    DEBUG = false
    assertEq(TOOLS.execute(PLAYER, "fultonLaunch", "fultonStart"), false)
    DEBUG = true
    assertEq(TOOLS.execute(PLAYER, "fultonLaunch", "fultonVanilla"), true)
    assertEq(CALL[1], "start"); assertEq(CALL[2], true)
    assertEq(TOOLS.execute(PLAYER, "fultonFlight", "fultonPause"), false)
    ACTIVE = true
    assertEq(TOOLS.execute(PLAYER, "fultonFlight", "fultonPause"), true)
    assertEq(CALL[1], "pause")
    assertEq(TOOLS.execute(PLAYER, "fultonFlight", "fultonCable"), true)
    assertEq(CALL[1], "cable")
    assertEq(TOOLS.execute(PLAYER, "fultonMode", "fultonPost"), true)
    assertEq(CALL[2], "post")
end
function T.cannot_dispatch_operation_from_another_row_or_unknown_operation()
    assertEq(TOOLS.execute(PLAYER, "crash", "forceDrop"), false)
    assertEq(TOOLS.execute(PLAYER, "unknown", "anything"), false)
    assertEq(CALL, nil)
    local rows = TOOLS.rows(PLAYER)
    assertEq(#rows, 5)
    assertEq(rows[4].actions[1].enabled, false)
end
return T
