local T = {}
function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Crash.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Flight.lua")
end
function T.chance_is_bounded_and_storm_is_optional()
    local c = MilitaryDrop.Crash
    assertEq(c.chance(5, 15, false), 5)
    assertEq(c.chance(5, 15, true), 20)
    assertEq(c.chance(90, 40, true), 100)
    assertEq(c.chance(-5, 0, false), 0)
end
function T.disabled_chance_never_calls_the_random_source()
    SandboxVars.MilitaryDrop.CrashChance = 0
    local f = MilitaryDrop.Flight.new(1, 1000, 1000, 0)
    assertEq(MilitaryDrop.Crash.roll(f, false, function() error("no draw") end), nil)
end
function T.crash_has_warning_then_impact_and_no_hover()
    local f = MilitaryDrop.Flight.new(1, 1000, 1000, 0)
    f.crash = MilitaryDrop.Crash.plan(f, "storm")
    assertEq(f.crash.t, 50)
    local x, y, phase = MilitaryDrop.Flight.position(f, 46)
    assertEq(x, 952)
    assertEq(y, 1000)
    assertEq(phase, "crash")
    x, y, phase = MilitaryDrop.Flight.position(f, 50)
    assertEq(x, 1000)
    assertEq(y, 1000)
    assertEq(phase, "done")
    assertEq(MilitaryDrop.Flight.totalTime(f), 50)
end
function T.network_roundtrip_keeps_geometry_but_not_private_cause()
    local f = MilitaryDrop.Flight.new(1, 1000, 1000, 0)
    f.crash = MilitaryDrop.Crash.plan(f, "gunfire")
    local args = MilitaryDrop.Flight.toArgs(f)
    assertEq(args.crash.cause, nil)
    local restored = MilitaryDrop.Flight.fromArgs(args)
    assertEq(restored.crash.t, f.crash.t)
    assertEq(MilitaryDrop.Flight.position(restored, 50), 1000)
end
function T.malformed_network_crash_is_rejected()
    local args = MilitaryDrop.Flight.new(1, 1000, 1000, 0)
    args.crash = { t = 50, x = 0/0, y = 0, dx = 1, dy = 0 }
    assertEq(MilitaryDrop.Flight.fromArgs(args), nil)
    args.crash.x = 1000
    args.crash.t = -1
    assertEq(MilitaryDrop.Flight.fromArgs(args), nil)
end
function T.debris_offsets_follow_each_heading()
    local c = MilitaryDrop.Crash
    local x, y = c.offset({ x = 100, y = 100, dx = 0, dy = 10 }, 12, 2)
    assertEq(x, 98)
    assertEq(y, 112)
    assertEq(c.direction({ dx = 0, dy = 10 }), "S")
    assertEq(c.direction({ dx = -1, dy = 0 }), "W")
end
return T
