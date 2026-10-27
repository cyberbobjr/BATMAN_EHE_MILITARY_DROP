local H = { client = {}, server = {} }
local fixture, started, at, stage, reload, closed, firstObserved, finished, errors
local heard = 0
local okay, lines = true, {}
local function rec(value, label)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. label
    if not value then okay = false end
end
local function result() return { ok = okay, summary = #lines .. " recon map checks", lines = lines } end
local function receive(p, command, args)
    local M = MilitaryDrop.Missions
    if command == "Ready" then
        if not fixture then
            local pickSite, announce = M.pickSite, M.announce
            M.pickSite = function() return math.floor(p:getX()) + 4, math.floor(p:getY()), "test" end
            -- Suppress spoken announcements only in this disposable fixture.
            -- The real launch and MarksActive transport remain untouched.
            M.announce = function() end
            local mission = M.launch("recon")
            M.pickSite, M.announce = pickSite, announce
            rec(mission ~= nil, "normal launch accepted on authority")
            if not mission then return end
            fixture = { id = mission.id, x = mission.x, y = mission.y,
                character = MilitaryDrop.Trust.idFor(p) }
            rec(#M.activeMarks().recon == 1, "launched recon included in authoritative active marks")
        elseif args.reconnect then
            rec(firstObserved, "new process connected after first observation")
            rec(MilitaryDrop.Trust.idFor(p) == fixture.character, "same native character after reconnect")
            rec(M.openMission("recon").id == fixture.id, "same mission remains active after disconnect")
        end
        if isServer() then sendServerCommand(p, "MDReconMapFixture", "Fixture", fixture) end
    elseif command == "Close" then
        rec(M.adminIntervene(p, "recon", fixture.id, false), "mission closure accepted on authority")
        rec(#M.activeMarks().recon == 0, "closed mission absent from active marks")
        if isServer() then sendServerCommand(p, "MDReconMapFixture", "Closed", {}) else closed = true end
    elseif command == "Observed" then firstObserved = true
    elseif command == "Done" then finished = true end
end
local function send(command, args)
    if isClient() then sendClientCommand(getPlayer(), "MDReconMapFixture", command, args or {})
    else receive(getPlayer(), command, args or {}) end
end
local function countEye(api, x, y)
    local n = 0
    for i = 0, api:getSymbolCount() - 1 do
        local symbol = api:getSymbolByIndex(i)
        if symbol:isTexture() and symbol:getSymbolID() == "Eye"
            and math.abs(symbol:getWorldX() - x) < 0.1 and math.abs(symbol:getWorldY() - y) < 0.1 then n = n + 1 end
    end
    return n
end
function H.client.start(ctx)
    started, at, stage, reload = getTimestampMs(), getTimestampMs(), 0, ctx.params.reconnect == "1"
    errors = getLuaDebuggerErrorCount()
    getPlayer():setGodMod(true)
    UIManager.getDebugConsole():setVisible(false)
    if ISChat.instance then ISChat.instance:setVisible(false) end
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    Events.OnDeviceText.Add(function(_, codes)
        if type(codes) == "string" and codes:find("MDRC", 1, true) then heard = heard + 1 end
    end)
    if isClient() then
        Events.OnServerCommand.Add(function(m, c, a)
            if m == "MDReconMapFixture" then
                if c == "Fixture" then fixture = a elseif c == "Closed" then closed = true end
            end
        end)
    end
    return true
end
function H.client.done()
    local elapsed = getTimestampMs() - at
    if getTimestampMs() - started > 60000 then
        rec(false, "client map verification before timeout"); send("Done"); return true
    end
    if stage == 0 and elapsed > 2000 then send("Ready", { reconnect = reload }); stage, at = 1, getTimestampMs()
    elseif stage == 1 and fixture and elapsed > 1000 then
        ISWorldMap.ShowWorldMap(0, fixture.x, fixture.y, 19)
        if not reload then MilitaryDrop.Announce.markMap(fixture.x + 12, fixture.y, "Eye", { r = 1, g = 0, b = 0, a = 1 }) end
        stage, at = 2, getTimestampMs()
    elseif stage == 2 and elapsed > 2000 then
        local api = ISWorldMap_instance.mapAPI:getSymbolsAPIv2()
        rec(countEye(api, fixture.x, fixture.y) == 1,
            reload and "eye restored automatically after real reconnect without duplicate"
            or "one recon eye visible at announced coordinates after launch")
        rec(heard == 0, "marker works without hearing an MDRC announcement")
        takeScreenshot(reload and "recon-after-reconnect.png" or "recon-on-launch.png")
        if isClient() and not reload then
            for i = api:getSymbolCount() - 1, 0, -1 do
                local symbol = api:getSymbolByIndex(i)
                if symbol:isTexture() and symbol:getSymbolID() == "Eye"
                    and math.abs(symbol:getWorldX() - fixture.x) < 0.1 then api:removeSymbolByIndex(i) end
            end
            rec(countEye(api, fixture.x, fixture.y) == 0, "eye deliberately erased before disconnect to prove restoration")
            rec(getLuaDebuggerErrorCount() == errors, "no new client Lua error")
            send("Observed")
            return true
        end
        ISWorldMap_instance:close()
        send("Close"); stage, at = 3, getTimestampMs()
    elseif stage == 3 and closed and elapsed > 2000 then
        ISWorldMap.ShowWorldMap(0, fixture.x, fixture.y, 19)
        stage, at = 4, getTimestampMs()
    elseif stage == 4 and elapsed > 2000 then
        local api = ISWorldMap_instance.mapAPI:getSymbolsAPIv2()
        rec(countEye(api, fixture.x, fixture.y) == 0, "recon eye removed when mission closes")
        rec(countEye(api, fixture.x + 12, fixture.y) == 1, "personal red eye note preserved")
        takeScreenshot("recon-after-closure.png")
        rec(getLuaDebuggerErrorCount() == errors, "no new client Lua error")
        send("Done")
        return true
    end
    return false
end
H.client.result = result
function H.server.start()
    started = getTimestampMs()
    Events.OnClientCommand.Add(function(m, c, p, a) if m == "MDReconMapFixture" then receive(p, c, a) end end)
    return true
end
function H.server.done()
    if getTimestampMs() - started > 300000 then rec(false, "server verification before timeout"); return true end
    return finished == true
end
H.server.result = result
return H
