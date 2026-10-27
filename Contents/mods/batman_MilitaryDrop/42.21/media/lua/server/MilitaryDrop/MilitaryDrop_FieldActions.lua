if isClient() then return end
require "MilitaryDrop/MilitaryDrop_Missions"
require "MilitaryDrop/MilitaryDrop_Weekly"

local F = {}
if MilitaryDrop.FieldActions then Events.EveryOneMinute.Remove(MilitaryDrop.FieldActions.announceWeekly) end
MilitaryDrop.FieldActions = F
local Exchange, Trust = MilitaryDrop.Exchange, MilitaryDrop.Trust

local function state()
    local s = MilitaryDrop.Secrets.privateState()
    s.fieldActions = s.fieldActions or { reports = {} }
    return s.fieldActions
end

local function reply(player, args, key, ...)
    local line = Exchange.line(key, ...)
    Exchange.toPlayer(player, Exchange.REPLY, { exchangeId = args.exchangeId, status = "ok", lines = { line } })
    local Post = MilitaryDrop.Post
    if Post then Post.record(MilitaryDrop.Teams.idFor(player), line) end
end

local function begin(player, args, source)
    if MilitaryDrop.Guard.throttled(player, "exchange", 3000) then
        Exchange.toPlayer(player, Exchange.REPLY, { exchangeId = args.exchangeId, status = "busy" }); return false
    end
    local radio, reason = Exchange.checkRadio(player, args.radio)
    if not radio then
        Exchange.toPlayer(player, Exchange.REPLY, { exchangeId = args.exchangeId, status = reason }); return false
    end
    if Trust.isLineCut(Trust.idFor(player)) or not Exchange.isEnabled(source) then
        Exchange.toPlayer(player, Exchange.REPLY, { exchangeId = args.exchangeId, status = "lineCut" }); return false
    end
    return true
end

function F.report(player, args)
    if not begin(player, args, "concentration") then return end
    local hour = getGameTime():getWorldAgeHours()
    local reports = state().reports
    local keep = {}
    local duplicate = false
    for _, r in ipairs(reports) do
        if hour - r.hour < 24 then
            keep[#keep + 1] = r
            local dx, dy = r.x - player:getX(), r.y - player:getY()
            if dx * dx + dy * dy <= 80 * 80 then duplicate = true end
        end
    end
    state().reports = keep
    if duplicate or #keep >= 256 then return reply(player, args, "IGUI_MilitaryDrop_HordeDuplicate") end
    if math.floor(player:getZ()) ~= 0 then return reply(player, args, "IGUI_MilitaryDrop_HordeInsufficient") end
    local zombies = {}
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local zombie = list:get(i)
        local dx, dy = zombie:getX() - player:getX(), zombie:getY() - player:getY()
        if not zombie:isDead() and zombie:getZ() == 0 and dx * dx + dy * dy <= 30 * 30 then
            zombies[#zombies + 1] = zombie
        end
    end
    if #zombies < 10 then return reply(player, args, "IGUI_MilitaryDrop_HordeInsufficient") end
    local x, y = math.floor(player:getX()), math.floor(player:getY())
    keep[#keep + 1] = { x = x, y = y, hour = hour }
    Trust.add(Trust.idFor(player), Exchange.gain("concentration"), "concentration")
    if not MilitaryDrop.Missions.openMission("cleanup") then
        MilitaryDrop.Missions.launch("cleanup", hour, { x = x, y = y, zombies = zombies })
    end
    reply(player, args, "IGUI_MilitaryDrop_HordeAccepted")
end

function F.receipt(player, args)
    if not begin(player, args, "receipt") then return end
    reply(player, args, Trust.confirmReceipt(player) and "IGUI_MilitaryDrop_ReceiptAccepted"
        or "IGUI_MilitaryDrop_ReceiptNone")
end

function F.weekly(player, args)
    if not begin(player, args, "weekly") then return end
    local needs = MilitaryDrop.Weekly.current()
    reply(player, args, "IGUI_MilitaryDrop_WeeklyList", Exchange.line("IGUI_MilitaryDrop_Category_" .. needs.categories[1]),
        Exchange.line("IGUI_MilitaryDrop_Category_" .. needs.categories[2]), tostring(needs.percent))
end

function F.announceWeekly()
    if not MilitaryDrop.Broadcast.channel then return end
    local needs = MilitaryDrop.Weekly.current()
    if state().week ~= needs.week then
        state().week = needs.week
        local line = Exchange.line("IGUI_MilitaryDrop_WeeklyList",
            Exchange.line("IGUI_MilitaryDrop_Category_" .. needs.categories[1]),
            Exchange.line("IGUI_MilitaryDrop_Category_" .. needs.categories[2]), tostring(needs.percent))
        MilitaryDrop.Missions.announce(Exchange.lineText(line), 1)
    end
end
MilitaryDrop.Server.COMMANDS.MissionConcentration = F.report
MilitaryDrop.Server.COMMANDS.MissionReceipt = F.receipt
MilitaryDrop.Server.COMMANDS.WeeklyNeeds = F.weekly
Events.EveryOneMinute.Add(F.announceWeekly)
return F
