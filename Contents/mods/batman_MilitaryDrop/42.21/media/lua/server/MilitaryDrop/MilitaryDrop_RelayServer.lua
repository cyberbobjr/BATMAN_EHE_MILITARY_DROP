if isClient() then return end
require "MilitaryDrop/MilitaryDrop_Relay"
require "MilitaryDrop/MilitaryDrop_Missions"
local R = MilitaryDrop.Relay
local hooks = MilitaryDrop.RelayServerHooks or {}
MilitaryDrop.RelayServerHooks = hooks
if hooks.minute then Events.EveryOneMinute.Remove(hooks.minute) end
if hooks.chunk then Events.LoadChunk.Remove(hooks.chunk) end
local S = {}
MilitaryDrop.RelayServer = S
local sessions = {}
local function hour() return getGameTime():getWorldAgeHours() end
function S.state()
    local data = MilitaryDrop.Secrets.privateState()
    data.relay = data.relay or { serial = 0, phase = "operational", created = {} }
    return data.relay
end
local function snapshot(player)
    local s = S.state()
    local args = { phase = s.phase, serial = s.serial, site = s.site }
    if player then MilitaryDrop.Net.toPlayer(player, "RelayState", args)
    else
        MilitaryDrop.Net.toAll("RelayState", args)
        MilitaryDrop.Missions.sendMarks()
    end
end
S.snapshot = snapshot
function S.postMission()
    local s = S.state()
    local site = R.SITES[s.site]
    if MilitaryDrop.Config.get("RelayEnabled") == false or s.phase ~= "failed" or not site then return nil end
    return { kind = "relay", x = site.x, y = site.y, deadline = s.since + 72, hours = 72 }
end
function S.adminSessionCount(site)
    local count = 0
    for _, session in pairs(sessions) do
        if session.site == site then count = count + 1 end
    end
    return count
end
function S.adminRestore(player)
    if not MilitaryDrop.Admin.allowed(player) then return false end
    local s = S.state()
    if s.phase ~= "failed" then return false end
    s.phase, s.cooldown = "operational", hour() + (MilitaryDrop.Config.get("RelayRearmDays") or 7) * 24
    sessions = {}
    MilitaryDrop.Missions.announce(getText("IGUI_MilitaryDrop_AdminUI_RelayRestored"), 1)
    snapshot()
    return true
end
local function announce(key, ...)
    MilitaryDrop.Missions.announce(getText(key, ...), 1)
end
function S.cabinet(site)
    local square = getCell():getGridSquare(site.x, site.y, 0)
    if not square then return nil, false end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj:getSpriteName() == site.sprite then return obj, true end
    end
    return nil, true
end
local function ensureCabinet()
    local s = S.state()
    if s.phase ~= "failed" then return end
    local site = R.SITES[s.site]
    local object, loaded = S.cabinet(site)
    if object or not loaded or not site.create or s.created[tostring(s.site)] then return end
    local square = getCell():getGridSquare(site.x, site.y, 0)
    if not square:isSolidFloor() or not square:isFree(false) then return end
    s.created[tostring(s.site)] = true
    local obj = IsoObject.new(getCell(), square, site.sprite)
    square:transmitAddObjectToSquare(obj, -1)
end

function S.fail(index)
    local s = S.state()
    if s.phase ~= "operational" or MilitaryDrop.Config.get("RelayEnabled") == false then return false end
    index = tonumber(index) or (s.serial % #R.SITES + 1)
    if index ~= math.floor(index) or not R.SITES[index] then return false end
    s.serial, s.site, s.phase, s.since = s.serial + 1, index, "failed", hour()
    ensureCabinet()
    local site = R.SITES[index]
    announce("IGUI_MilitaryDrop_RelayOrder", tostring(site.x), tostring(site.y))
    snapshot()
    return true
end

function S.adminLaunch(player, index)
    if not MilitaryDrop.Admin.allowed(player) then return false end
    if type(index) ~= "number" or index ~= math.floor(index) or not R.SITES[index] then return false end
    -- Manual orders bypass weather/rearm timing, but never replace an active repair mission.
    return S.fail(index)
end

local function reply(player, reason, extra)
    local args = extra or {}
    args.reason = reason
    args.username = player:getUsername()
    MilitaryDrop.Net.toPlayer(player, "RelayReply", args)
end
function S.begin(player)
    local s = S.state()
    local site = R.SITES[s.site]
    if MilitaryDrop.Config.get("RelayEnabled") == false or s.phase ~= "failed" or not site
        or not R.near(player, site) or not S.cabinet(site) then
        reply(player, "unavailable"); return
    end
    local level = math.max(0, math.min(10, player:getPerkLevel(Perks.Electricity)))
    local cost = R.cost(level)
    local scraps = player:getInventory():getAllTypeRecurse("ElectronicsScrap")
    if scraps:size() < cost then reply(player, "components"); return end
    local id = MilitaryDrop.Trust.idFor(player)
    sessions[id] = { serial = s.serial, site = s.site, cost = cost, seconds = R.seconds(level), at = hour(),
        stamp = getTimestampMs() }
    reply(player, "begin", { serial = s.serial, site = s.site, seconds = R.seconds(level), cost = cost })
end

function S.complete(player, args)
    local id = MilitaryDrop.Trust.idFor(player)
    local session = sessions[id]
    local s = S.state()
    if MilitaryDrop.Config.get("RelayEnabled") == false or not session or args.serial ~= session.serial
        or s.serial ~= session.serial or s.phase ~= "failed" then
        reply(player, "unavailable"); return false
    end
    local site = R.SITES[session.site]
    local elapsed = (hour() - session.at) * getGameTime():getMinutesPerDay() * 60 / 24
    if not R.near(player, site) or not S.cabinet(site) or elapsed + 0.1 < session.seconds then
        reply(player, "unavailable"); return false
    end
    local scraps = player:getInventory():getAllTypeRecurse("ElectronicsScrap")
    if scraps:size() < session.cost then sessions[id] = nil; reply(player, "components"); return false end
    -- All validation is complete before inventory and mission changes.
    for i = 0, session.cost - 1 do
        local item = scraps:get(i)
        local container = item:getContainer()
        container:Remove(item)
        if isServer() then sendRemoveItemFromContainer(container, item) end
    end
    s.phase, s.cooldown = "operational", hour() + (MilitaryDrop.Config.get("RelayRearmDays") or 7) * 24
    sessions = {}
    addXp(player, Perks.Electricity, 10)
    MilitaryDrop.Trust.add(id, 3, "relay")
    announce("IGUI_MilitaryDrop_RelayRestored")
    reply(player, "complete")
    snapshot()
    return true
end

local function update()
    local s = S.state()
    local stale = {}
    for id, session in pairs(sessions) do
        if getTimestampMs() - session.stamp > 120000 then stale[#stale + 1] = id end
    end
    for _, id in ipairs(stale) do sessions[id] = nil end
    local enabled = MilitaryDrop.Config.get("RelayEnabled") ~= false
    local storm = getClimateManager():getIsThunderStorming()
    local hydro = getWorld():isHydroPowerOn()
    local transition = (storm and s.storm == false) or (hydro == false and s.hydro == true)
    s.storm, s.hydro = storm, hydro
    if not enabled or (s.phase == "failed" and hour() - s.since >= 72) then
        if s.phase == "failed" then
            s.phase, s.cooldown = "operational", hour() + 168
            sessions = {}
            announce("IGUI_MilitaryDrop_RelayBypass")
            snapshot()
        end
    elseif s.phase == "operational" and transition and hour() >= (s.cooldown or 0) then S.fail()
    elseif s.phase == "failed" then ensureCabinet() end
end

local function gate(player, command, args)
    if MilitaryDrop.Config.get("RelayEnabled") == false then return true end
    local s = S.state()
    if s.phase ~= "failed" then return true end
    if command == "Request" and args.forced and MilitaryDrop.Server.canForce(player) then return true end
    if command == "Request" or command == "RequisitionOrder" then
        snapshot(player)
        reply(player, "failed")
        return false
    end
    return true
end
MilitaryDrop.Extensions.commandGates.Relay = gate
local C = MilitaryDrop.Server.COMMANDS
C.RelaySync = snapshot
C.RelayBegin = function(player)
    if not MilitaryDrop.Guard.throttled(player, "RelayBegin", 1000) then S.begin(player) end
end
C.RelayComplete = function(player, args) S.complete(player, args) end
C.RelayCancel = function(player) sessions[MilitaryDrop.Trust.idFor(player)] = nil end
hooks.minute, hooks.chunk = update, ensureCabinet
Events.EveryOneMinute.Add(hooks.minute)
Events.LoadChunk.Add(hooks.chunk)
return S
