local T = {}
local function player(name)
    return { getUsername = function() return name end, isDead = function() return false end,
        getRole = function() return { hasCapability = function(_, cap) return ALLOWED and (cap ~= "tp" or TELEPORT) end } end }
end
local function reply() return RESPONSES[#RESPONSES] end
local function invoke(args)
    NOW = NOW + 250
    return A.command(PLAYER, args)
end
local function preview(kind, id, op)
    invoke({ action = "preview", kind = kind, id = id, operation = op })
    return reply().preview and reply().preview.token
end
function T.setup()
    ALLOWED, TELEPORT, DEBUG, MP, NOW, MUTATIONS = true, true, true, true, 1000, 0
    RESPONSES, TELEPORTS = {}, {}
    PRIVATE = { seed = "never-send", drops = {}, missions = { open = {} }, characterTrust = {} }
    PLAYER, OTHER = player("admin"), player("ordinary")
    ONLINE = { PLAYER }
    isClient = function() return false end
    isServer = function() return MP end
    isDebugEnabled = function() return DEBUG end
    Capability = { ChangeAndReloadServerOptions = "admin", TeleportToCoordinates = "tp" }
    checkPermissions = function() return true end -- disconnected-connection fallback must not grant a role!
    getTimestampMs = function() return NOW end
    getGameTime = function() return { getWorldAgeHours = function() return 100 end } end
    getText = function(key) return key end
    LOADED, FREE, WATER, VEHICLE = true, true, false, nil
    getCell = function() return { getGridSquare = function(_, x, y, z)
        if not LOADED then return nil end
        return { isFree = function() return FREE end, isWaterSquare = function() return WATER end,
            getVehicleContainer = function() return VEHICLE end, getX = function() return x end,
            getY = function() return y end, getZ = function() return z end }
    end } end
    MilitaryDrop = {
        Guard = { throttled = function() return false end },
        Secrets = { privateState = function() return PRIVATE end },
        Server = { COMMANDS = {}, getState = function() return { flights = {}, pending = {} } end,
            getCode = function() return "01234" end },
        Config = { codeMode = function() return 4 end, getChannel = function() return 151400 end,
            get = function() return true end },
        Codes = { MODE_NONE = 1 }, NumbersStation = { frequency = 12300 },
        Net = { players = function() return ONLINE end, toPlayer = function(_, command, args)
            if command == "AdminTeleport" then TELEPORTS[#TELEPORTS + 1] = args
            else RESPONSES[#RESPONSES + 1] = args end
        end },
        Trust = { idFor = function(p) return "C:" .. p:getUsername() end, get = function() return 25 end,
            name = function(cid) return cid end, isLineCut = function(cid) return PRIVATE.characterTrust[cid] ~= nil end,
            unlock = function(cid) MUTATIONS = MUTATIONS + 1; PRIVATE.characterTrust[cid] = nil; return true end,
            adminClose = function(_, id) MUTATIONS = MUTATIONS + 1; PRIVATE.drops[id].outcome = "cancelled"; return true end },
        Flights = { cancelDrop = function(id) MUTATIONS = MUTATIONS + 1; PRIVATE.drops[id].outcome = "expired"; return true end },
        Missions = { cleanupDown = function() return 3 end, hordeTarget = function() return 9 end,
            cleanupWinner = function() return nil end, adminReward = function() return nil, "noBeneficiary" end,
            launch = function() return false end },
        Exchange = { isEnabled = function() return true end },
        Relay = { SITES = { { x = 10, y = 20 } } },
        RelayServer = { state = function() return { serial = 2, phase = "operational" } end,
            adminSessionCount = function() return 0 end },
        Broadcast = { dropped = function() MUTATIONS = MUTATIONS + 1 end }, log = function() end,
    }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Admin.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_AdminDashboard.lua")
    A = MilitaryDrop.AdminDashboardServer
end
function T.solo_requires_debug_and_mp_requires_real_role_even_with_permission_fallback()
    MP, DEBUG, ALLOWED = false, false, true
    assertTrue(not MilitaryDrop.Admin.allowed(PLAYER))
    DEBUG = true
    assertTrue(MilitaryDrop.Admin.allowed(PLAYER))
    MP, DEBUG, ALLOWED = true, true, false
    assertTrue(not MilitaryDrop.Admin.allowed(PLAYER), "MP debug never bypasses the server role")
    invoke({ action = "list" })
    assertTrue(reply().denied)
    assertEq(reply().rows, nil, "ordinary role receives no operation data")
end
function T.secondary_mp_local_player_cannot_trigger_native_primary_player_teleport()
    isClient = function() return true end
    PLAYER.getPlayerNum = function() return 1 end
    assertTrue(MilitaryDrop.Admin.allowed(PLAYER))
    assertTrue(not MilitaryDrop.Admin.canTeleport(PLAYER))
    PLAYER.getPlayerNum = function() return 0 end
    assertTrue(MilitaryDrop.Admin.canTeleport(PLAYER))
end
function T.communications_values_are_private_current_and_keep_leading_zeroes()
    invoke({ action = "list", group = "radio" })
    local row = reply().rows[1]
    assertEq(row.code, "01234")
    assertEq(row.militaryChannel, 151400)
    assertEq(row.numbersChannel, 12300)
    assertEq(#row.actions, 0)
    invoke({ action = "list", group = "drop" })
    for _, item in ipairs(reply().rows) do assertEq(item.code, nil) end
    ALLOWED = false
    invoke({ action = "list", group = "radio" })
    assertEq(reply().denied, true)
    assertEq(reply().rows, nil)
end
function T.no_code_or_numbers_broadcast_is_shown_explicitly()
    MilitaryDrop.Config.codeMode = function() return 1 end
    MilitaryDrop.NumbersStation.frequency = nil
    invoke({ action = "list", group = "radio" })
    assertEq(reply().rows[1].codeRequired, false)
    assertEq(reply().rows[1].code, nil)
    assertEq(reply().rows[1].numbersChannel, nil)
end
function T.relay_launch_is_confirmed_and_uses_the_server_selected_site()
    local state = { serial = 2, phase = "operational", cooldown = 9999 }
    MilitaryDrop.RelayServer.state = function() return state end
    MilitaryDrop.RelayServer.adminLaunch = function(p, index)
        assertEq(p, PLAYER)
        assertEq(index, 1, "target comes from the server row, not forged arguments")
        state.serial, state.phase, state.site, state.since = 3, "failed", index, 100
        MUTATIONS = MUTATIONS + 1
        return true
    end
    local token = preview("relay", "1", "launchRelay")
    assertTrue(token ~= nil)
    assertEq(MUTATIONS, 0)
    invoke({ action = "commit", ticket = token, reason = "Manual relay mission", site = 999 })
    assertEq(MUTATIONS, 1)
    assertEq(reply().status, "success")
    assertEq(preview("relay", "1", "launchRelay"), nil, "active repair mission blocks a second launch")
end
function T.projections_are_paginated_separated_searchable_and_do_not_leak_dossiers()
    for i = 1, 100 do PRIVATE.drops["D" .. i] = { requester = "caller", secret = "never-send" } end
    invoke({ action = "list", group = "drop", page = 2 })
    assertEq(reply().total, 100)
    assertEq(#reply().rows, 24)
    for _, row in ipairs(reply().rows) do
        assertEq(row.kind, "drop")
        assertEq(row.secret, nil)
        assertEq(row.seed, nil)
    end
    invoke({ action = "list", group = "character", query = "admin" })
    assertEq(reply().total, 1)
    invoke({ action = "list", group = "drop", page = 0 / 0 })
    assertEq(reply().page, 1)
end
function T.a_preview_does_not_mutate_and_a_ticket_is_single_use()
    PRIVATE.drops.D1 = { requester = "caller" }
    local token = preview("drop", "D1", "cancelDrop")
    assertTrue(token ~= nil)
    assertEq(MUTATIONS, 0)
    assertTrue(invoke({ action = "commit", ticket = token, reason = "cancel pending delivery" }))
    assertEq(MUTATIONS, 1)
    assertTrue(not invoke({ action = "commit", ticket = token, reason = "replay" }))
    assertEq(MUTATIONS, 1)
end
function T.throttled_admin_request_gets_an_explicit_retry_response_without_data_or_mutation()
    MilitaryDrop.Guard.throttled = function() return true end
    assertTrue(not invoke({ action = "preview", kind = "drop", id = "D1", operation = "cancelDrop" }))
    assertTrue(reply().busy)
    assertEq(reply().rows, nil)
    assertEq(MUTATIONS, 0)
end
function T.changed_or_expired_target_and_revoked_permission_cannot_commit()
    PRIVATE.drops.D1 = { requester = "caller" }
    local token = preview("drop", "D1", "cancelDrop")
    PRIVATE.drops.D1.deliveredHours = 99
    assertTrue(not invoke({ action = "commit", ticket = token, reason = "stale" }))
    assertEq(MUTATIONS, 0)
    token = preview("drop", "D1", "closeDrop")
    NOW = NOW + 60001
    assertTrue(not invoke({ action = "commit", ticket = token, reason = "expired" }))
    token = preview("drop", "D1", "closeDrop")
    ALLOWED = false
    assertTrue(not invoke({ action = "commit", ticket = token, reason = "permission revoked" }))
    assertEq(MUTATIONS, 0)
end
function T.tickets_cannot_be_committed_by_another_admin_and_reason_is_required()
    PRIVATE.drops.D1 = { requester = "caller" }
    local token = preview("drop", "D1", "cancelDrop")
    assertTrue(not A.command(OTHER, { action = "commit", ticket = token, reason = "stolen" }))
    assertTrue(not invoke({ action = "commit", ticket = token, reason = "   " }))
    assertEq(reply().status, "reasonRequired")
    assertTrue(invoke({ action = "commit", ticket = token, reason = "valid reason" }))
    assertEq(MUTATIONS, 1)
end
function T.closed_and_undelivered_drops_cannot_announce_and_cooldown_is_checked()
    PRIVATE.drops.D1 = { requester = "caller", x = 10, y = 20 }
    assertEq(preview("drop", "D1", "announce"), nil)
    PRIVATE.drops.D1.deliveredHours = 99
    local token = preview("drop", "D1", "announce")
    assertTrue(invoke({ action = "commit", ticket = token, reason = "repeat location" }))
    assertEq(MUTATIONS, 1)
    assertEq(preview("drop", "D1", "announce"), nil)
    assertEq(reply().status, "cooldown")
end
function T.teleport_uses_server_coordinates_and_refuses_unloaded_water_and_occupied_squares()
    PRIVATE.drops.D1 = { requester = "caller", x = 100, y = 200, deliveredHours = 99 }
    LOADED = false
    assertEq(preview("drop", "D1", "teleport"), nil)
    assertEq(reply().status, "noSafeSquare")
    LOADED, WATER = true, true
    assertEq(preview("drop", "D1", "teleport"), nil)
    WATER, FREE = false, false
    assertEq(preview("drop", "D1", "teleport"), nil)
    FREE = true
    local token = preview("drop", "D1", "teleport")
    assertTrue(invoke({ action = "commit", ticket = token, x = 99999, y = 99999 }))
    assertEq(#TELEPORTS, 1)
    assertTrue(math.abs(TELEPORTS[1].x - 100) < 7)
    assertTrue(math.abs(TELEPORTS[1].y - 200) < 7)
    assertEq(TELEPORTS[1].username, "admin")
end
function T.unlock_needs_a_connected_blocked_character_and_keeps_the_score()
    PRIVATE.characterTrust["C:admin"] = { lockedUntil = 200 }
    local token = preview("character", "C:admin", "unlock")
    assertTrue(invoke({ action = "commit", ticket = token, reason = "restore line" }))
    assertEq(MUTATIONS, 1)
    assertEq(preview("character", "C:admin", "unlock"), nil)
    assertEq(preview("character", "C:other", "unlock"), nil)
end
return T
