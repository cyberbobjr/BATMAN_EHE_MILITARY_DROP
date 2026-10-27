if isClient() then return end
require "MilitaryDrop/MilitaryDrop_Admin"
require "MilitaryDrop/MilitaryDrop_Flights"
require "MilitaryDrop/MilitaryDrop_RelayServer"
local D, A = MilitaryDrop, MilitaryDrop.Admin
local S = { tickets = {}, nextTicket = 0, announcements = {} }
MilitaryDrop.AdminDashboardServer = S
local function hours() return getGameTime():getWorldAgeHours() end
local function connected(cid)
    for _, p in ipairs(D.Net.players({ alive = true })) do if D.Trust.idFor(p) == cid then return p end end
end
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < 1000000 end
function S.rows()
    local rows, s, now = {}, D.Secrets.privateState(), hours()
    local flights, pending = {}, {}
    for _, f in ipairs(D.Server.getState().flights or {}) do flights[f.dropId] = f end
    for _, p in pairs(D.Server.getState().pending or {}) do pending[p.dropId] = p end
    for id, drop in pairs(s.drops or {}) do
        local f, p = flights[id], pending[id]
        local target = drop.placed or p or (f and { x = f.tx, y = f.ty }) or drop
        rows[#rows + 1] = { kind = "drop", id = id, requester = A.clean(drop.requester),
            phase = drop.outcome or (drop.deliveredHours and "delivered" or (p and "waiting" or (f and "flying" or "pending"))),
            closed = drop.outcome ~= nil, delivered = drop.deliveredHours ~= nil,
            x = target.x, y = target.y, z = 0, deadline = drop.deadline, opened = drop.requestedHours,
            zone = A.clean(drop.zoneName), decoy = drop.decoy == true }
    end
    local missions = s.missions and s.missions.open or {}
    for _, kind in ipairs({ "recon", "cleanup", "control" }) do
        local m = missions[kind]
        local row = { kind = "mission", id = m and m.id or "slot:" .. kind, missionKind = kind,
            phase = m and ((m.deadline or 0) > now and "active" or "expired") or "idle",
            closed = m ~= nil and (m.deadline or 0) <= now }
        if m then
            row.x, row.y, row.z, row.deadline = m.x, m.y, 0, m.deadline
            row.progress = kind == "cleanup" and D.Missions.cleanupDown(m.horde) or 0
            row.quota = kind == "cleanup" and D.Missions.hordeTarget(m.horde) or nil
            row.winner = kind == "cleanup" and D.Missions.cleanupWinner(m) or nil
            row.contributors = {}
            for cid, count in pairs(m.counts or {}) do
                row.contributors[#row.contributors + 1] = { id = cid, name = A.clean(D.Trust.name(cid)), count = count }
            end
            table.sort(row.contributors, function(a, b) return a.count > b.count end)
            while #row.contributors > 12 do table.remove(row.contributors) end
        end
        rows[#rows + 1] = row
    end
    local relay = D.RelayServer.state()
    for i, site in ipairs(D.Relay.SITES) do
        local failed = relay.phase == "failed" and relay.site == i
        rows[#rows + 1] = { kind = "relay", id = tostring(i), site = i, x = site.x, y = site.y, z = 0,
            serial = relay.serial, phase = failed and "failed" or "operational", closed = not failed,
            launchable = relay.phase ~= "failed" and D.Config.get("RelayEnabled") ~= false,
            launchReason = D.Config.get("RelayEnabled") == false and "disabled" or "relayMissionActive",
            deadline = failed and relay.since + 72 or nil, repairs = D.RelayServer.adminSessionCount(i) }
    end
    for _, player in ipairs(D.Net.players({ alive = true })) do
        local cid = D.Trust.idFor(player)
        local e = s.characterTrust and s.characterTrust[cid] or {}
        rows[#rows + 1] = { kind = "character", id = cid, name = A.clean(player:getUsername()),
            phase = D.Trust.isLineCut(cid) and "blocked" or "available", value = D.Trust.get(cid),
            lockedUntil = e.lockedUntil, deadline = e.lockedUntil, closed = false }
    end
    for id, wreck in pairs(s.wrecks or {}) do
        rows[#rows + 1] = { kind = "wreck", id = tostring(id), x = wreck.x, y = wreck.y, z = wreck.z or 0,
            phase = "present", origin = tostring(wreck.dropId or ""), closed = false }
    end
    table.sort(rows, function(a, b) return a.kind .. a.id < b.kind .. b.id end)
    return rows
end
local function decorate(row, player, beneficiary)
    row.actions = {}
    local function action(op, enabled, reason)
        row.actions[#row.actions + 1] = { op = op, enabled = enabled == true, reason = reason }
    end
    if row.kind ~= "character" then
        local located = finite(row.x) and finite(row.y) and finite(row.z)
        action("teleport", located and A.canTeleport(player), located and "permission" or "noLocation")
    end
    if row.kind == "drop" then
        local cooled = getTimestampMs() - (S.announcements[row.id] or -60000) >= 60000
        action("announce", not row.closed and row.delivered and cooled,
            row.closed and "closed" or (not row.delivered and "notDelivered" or "cooldown"))
        action(row.delivered and "closeDrop" or "cancelDrop", not row.closed, "closed")
    elseif row.kind == "mission" then
        if row.phase == "idle" then
            action("launch", D.Exchange.isEnabled(row.missionKind), "disabled")
        else
            local reward, reason = D.Missions.adminReward(row.missionKind, row.id, beneficiary)
            if reward then
                row.beneficiary, row.reward, row.baseGain = reward.beneficiary, reward.reward, reward.baseGain
                row.beneficiaryName = A.clean(D.Trust.name(reward.beneficiary))
                local p = connected(reward.beneficiary)
                if row.beneficiaryName == "" and p then row.beneficiaryName = A.clean(p:getUsername()) end
            end
            action("succeed", reward ~= nil, reason or "stale")
            action("closeMission", row.phase == "active", "closed")
        end
    elseif row.kind == "relay" then
        action("launchRelay", row.launchable, row.launchReason)
        action("restore", row.phase == "failed", "alreadyOperational")
    elseif row.kind == "character" then
        action("unlock", row.phase == "blocked", "alreadyAvailable")
    end
    return row
end
local function find(kind, id, player, beneficiary)
    for _, row in ipairs(S.rows()) do
        if row.kind == kind and row.id == id then return decorate(row, player, beneficiary) end
    end
end
local function hasAction(row, op)
    for _, action in ipairs(row and row.actions or {}) do
        if action.op == op then return action.enabled, action.reason end
    end
    return false, "invalid"
end
local function pageNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or math.abs(n) == math.huge then return 1 end
    return math.max(1, math.min(100000, math.floor(n)))
end
local function respond(player, args, result)
    result = result or {}
    result.username, result.requestId = player:getUsername(), args.requestId
    local group = args.group or "drop"
    local valid = false
    for _, kind in ipairs(A.GROUPS) do if group == kind then valid = true end end
    if not valid then group = "drop" end
    local rows, counts = {}, {}
    local query = type(args.query) == "string" and args.query:sub(1, 80):lower() or ""
    local source = S.rows()
    counts.radio = 1
    if group == "radio" then
        -- Authorized private response only; never add these values to public syncs or logs.
        local mode = D.Config.codeMode()
        source[#source + 1] = { kind = "radio", id = "communications", phase = "available", closed = false,
            code = mode ~= D.Codes.MODE_NONE and tostring(D.Server.getCode()) or nil,
            codeRequired = mode ~= D.Codes.MODE_NONE, militaryChannel = D.Config.getChannel(),
            numbersChannel = D.NumbersStation and D.NumbersStation.frequency or nil }
        counts.radio = 0
    end
    for _, row in ipairs(source) do
        counts[row.kind] = (counts[row.kind] or 0) + 1
        local searchable = row.id .. " " .. (row.requester or row.name or "") .. " "
            .. (row.missionKind or "") .. " " .. tostring(row.x or "") .. "," .. tostring(row.y or "")
        local matches = query == "" or searchable:lower():find(query, 1, true)
        local stateMatches = args.filter ~= "active" or not row.closed
        if args.filter == "closed" then stateMatches = row.closed end
        if row.kind == group and matches and stateMatches then
            if row.kind == "radio" then row.actions = {}
            else decorate(row, player, args.beneficiary) end
            rows[#rows + 1] = row
        end
    end
    local total = #rows
    local page = math.min(pageNumber(args.page), math.max(1, math.ceil(total / A.PAGE_SIZE)))
    result.rows = {}
    for i = (page - 1) * A.PAGE_SIZE + 1, math.min(page * A.PAGE_SIZE, total) do
        result.rows[#result.rows + 1] = rows[i]
    end
    result.page, result.total, result.counts, result.group = page, total, counts, group
    result.hours, result.stamp = hours(), getTimestampMs()
    result.recipients = {}
    for _, p in ipairs(D.Net.players({ alive = true })) do
        result.recipients[#result.recipients + 1] = { id = D.Trust.idFor(p), name = A.clean(p:getUsername()) }
    end
    D.Net.toPlayer(player, "AdminDashboard", result)
end
function S.safeSquare(row)
    local cell = getCell()
    for radius = 1, 6 do
        for dx = -radius, radius do
            for dy = -radius, radius do
                if math.abs(dx) == radius or math.abs(dy) == radius then
                    local sq = cell:getGridSquare(math.floor(row.x) + dx, math.floor(row.y) + dy, math.floor(row.z))
                    if sq and sq:isFree(true) and not sq:isWaterSquare() and not sq:getVehicleContainer() then return sq end
                end
            end
        end
    end
end
local function perform(player, row, op, beneficiary)
    if op == "teleport" then
        if not A.canTeleport(player) then return false, "permission" end
        local sq = S.safeSquare(row)
        if not sq then return false, "noSafeSquare" end
        D.Net.toPlayer(player, "AdminTeleport", { username = player:getUsername(), x = sq:getX(), y = sq:getY(), z = sq:getZ() })
        return true, "teleportRequested"
    elseif op == "announce" then
        S.announcements[row.id] = getTimestampMs()
        D.Broadcast.dropped(row.x, row.y, row.zone)
        return true
    elseif op == "closeDrop" then return D.Trust.adminClose(player, row.id)
    elseif op == "cancelDrop" then return D.Flights.cancelDrop(row.id)
    elseif op == "closeMission" or op == "succeed" then
        return D.Missions.adminIntervene(player, row.missionKind, row.id, op == "succeed", beneficiary)
    elseif op == "launch" then return D.Missions.launch(row.missionKind) ~= nil
    elseif op == "launchRelay" then return D.RelayServer.adminLaunch(player, row.site)
    elseif op == "restore" then return D.RelayServer.adminRestore(player)
    elseif op == "unlock" then
        return connected(row.id) ~= nil and D.Trust.isLineCut(row.id) and D.Trust.unlock(row.id)
    end
    return false, "invalid"
end
function S.command(player, args)
    if not player then return false end
    args = type(args) == "table" and args or {}
    if not A.allowed(player) then
        S.tickets[player] = nil
        D.Net.toPlayer(player, "AdminDashboard", { username = player:getUsername(), denied = true })
        return false
    end
    if D.Guard.throttled(player, "AdminDashboard", 200) then
        D.Net.toPlayer(player, "AdminDashboard", { username = player:getUsername(), requestId = args.requestId,
            busy = true, status = "busy" })
        return false
    end
    local expired = {}
    for p, ticket in pairs(S.tickets) do
        if getTimestampMs() > ticket.expires then expired[#expired + 1] = p end
    end
    for _, p in ipairs(expired) do S.tickets[p] = nil end
    local action = args.action or "list"
    if action == "list" then respond(player, args); return true end
    if action == "preview" then
        local row = find(args.kind, args.id, player, args.beneficiary)
        local enabled, reason = hasAction(row, args.operation)
        if not enabled then respond(player, args, { status = reason or "stale" }); return false end
        if args.operation == "teleport" and not S.safeSquare(row) then
            respond(player, args, { status = "noSafeSquare" }); return false
        end
        S.nextTicket = S.nextTicket + 1
        local ticket = { token = tostring(S.nextTicket) .. ":" .. tostring(getTimestampMs()), row = row,
            fingerprint = A.fingerprint(row), op = args.operation, beneficiary = args.beneficiary,
            expires = getTimestampMs() + 60000 }
        S.tickets[player] = ticket
        respond(player, args, { preview = { token = ticket.token, row = row, operation = ticket.op } })
        return true
    elseif action == "commit" then
        local ticket = S.tickets[player]
        if not ticket or ticket.token ~= args.ticket then respond(player, args, { status = "stale" }); return false end
        local reason = type(args.reason) == "string" and args.reason:gsub("[%c]", " "):sub(1, 200) or ""
        if ticket.op ~= "teleport" and not reason:find("%S") then
            respond(player, args, { status = "reasonRequired" }); return false
        end
        S.tickets[player] = nil
        local row = find(ticket.row.kind, ticket.row.id, player, ticket.beneficiary)
        local enabled = hasAction(row, ticket.op)
        if not row or not enabled or A.fingerprint(row) ~= ticket.fingerprint then
            respond(player, args, { status = "stale" }); return false
        end
        local changed, status = perform(player, row, ticket.op, ticket.beneficiary)
        local updated = find(row.kind, row.id, player, ticket.beneficiary)
        local after = updated and updated.phase or (ticket.op == "launch" and "active" or "closed")
        D.log("admin " .. tostring(player:getUsername()) .. " " .. ticket.op .. " " .. row.kind .. ":" .. row.id
            .. " phase=" .. row.phase .. "->" .. after .. " changed=" .. tostring(changed) .. " reason=" .. reason, true)
        respond(player, args, { status = changed and (status or "success") or (status or "stale"),
            changed = changed == true, operation = ticket.op, target = row })
        return changed == true
    end
    respond(player, args, { status = "invalid" })
    return false
end
D.Server.COMMANDS.AdminDashboard = S.command
return S
