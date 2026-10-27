local T = {}
function T.setup()
    ALLOWED, ENABLED, ANNOUNCED, SYNCS, MARK_SYNCS = true, true, 0, 0, 0
    STATE = { relay = { serial = 4, phase = "operational", cooldown = 9999, created = {} } }
    getGameTime = function() return { getWorldAgeHours = function() return 12 end } end
    getCell = function() return { getGridSquare = function() return nil end } end
    getText = function(key) return key end
    isClient = function() return false end
    Events = { EveryOneMinute = { Add = function() end }, LoadChunk = { Add = function() end } }
    MilitaryDrop = {
        Admin = { allowed = function() return ALLOWED end },
        Config = { get = function(key) if key == "RelayEnabled" then return ENABLED end return 7 end },
        Secrets = { privateState = function() return STATE end },
        Relay = { SITES = { { x = 10, y = 20 }, { x = 30, y = 40 } } },
        Missions = { announce = function() ANNOUNCED = ANNOUNCED + 1 end,
            sendMarks = function() MARK_SYNCS = MARK_SYNCS + 1 end },
        Net = { toAll = function(_, data) SYNCS = SYNCS + 1; SNAPSHOT = data end,
            toPlayer = function() end },
        Extensions = { commandGates = {} }, Server = { COMMANDS = {} },
    }
    RELAY = loadMod("server/MilitaryDrop/MilitaryDrop_RelayServer.lua")
end
function T.launches_selected_site_despite_rearm_without_awarding_rewards()
    assertEq(RELAY.adminLaunch({}, 2), true)
    assertEq(STATE.relay.site, 2)
    assertEq(STATE.relay.phase, "failed")
    assertEq(STATE.relay.since, 12)
    assertEq(STATE.relay.serial, 5)
    assertEq(ANNOUNCED, 1)
    assertEq(SYNCS, 1)
    assertEq(SNAPSHOT.site, 2)
    assertEq(MARK_SYNCS, 1, "launch synchronizes map markers")
    local player = { getUsername = function() return "test" end }
    assertEq(MilitaryDrop.Extensions.commandGates.Relay(player, "Request", {}), false)
end
function T.never_replaces_an_active_mission_or_announces_twice()
    assertEq(RELAY.adminLaunch({}, 1), true)
    assertEq(RELAY.adminLaunch({}, 2), false)
    assertEq(STATE.relay.site, 1)
    assertEq(STATE.relay.serial, 5)
    assertEq(ANNOUNCED, 1)
end
function T.post_projection_follows_active_relay_state_and_disappears_after_restoration()
    assertEq(RELAY.postMission(), nil)
    RELAY.adminLaunch({}, 2)
    local mission = RELAY.postMission()
    assertEq(mission.kind, "relay")
    assertEq(mission.x, 30)
    assertEq(mission.y, 40)
    assertEq(mission.deadline, 84)
    assertEq(mission.hours, 72)
    ENABLED = false
    assertEq(RELAY.postMission(), nil)
    ENABLED = true
    RELAY.adminRestore({})
    assertEq(RELAY.postMission(), nil)
    assertEq(MARK_SYNCS, 2, "restoration synchronizes marker removal")
end
function T.rejects_disabled_unauthorized_or_invalid_launches()
    ALLOWED = false
    assertEq(RELAY.adminLaunch({}, 1), false)
    ALLOWED, ENABLED = true, false
    assertEq(RELAY.adminLaunch({}, 1), false)
    ENABLED = true
    for _, index in ipairs({ 0, 3, 1.5, "1" }) do assertEq(RELAY.adminLaunch({}, index), false) end
    assertEq(RELAY.adminLaunch({}, nil), false)
    assertEq(STATE.relay.phase, "operational")
    assertEq(ANNOUNCED, 0)
end
return T
