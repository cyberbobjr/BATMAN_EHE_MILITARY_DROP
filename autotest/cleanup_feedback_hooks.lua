local H = { client = {}, server = {} }
local D, started, stage, at, ready, payload, panel, errors, notices, seeded, finished
local okay, lines = true, {}
local function rec(ok, label)
    lines[#lines + 1] = (ok and "PASS " or "FAIL ") .. label
    if not ok then okay = false end
end
local function result() return { ok = okay, summary = #lines .. " cleanup feedback checks", lines = lines } end
local function reply(p, command, args)
    if isServer() then sendServerCommand(p, "MDCleanupFixture", command, args)
    elseif command == "Ready" then ready = args else payload = args end
end
local function fixture(p, command)
    local now = getGameTime():getWorldAgeHours()
    local cid = D.Trust.idFor(p)
    local s = D.Secrets.privateState()
    if command == "Seed" and not seeded then
        seeded = true
        p:setGodMod(true)
        D.Trust.touch(cid)
        s.characterTrust[cid].value = 40
        s.characterTrust[cid].dayGain = 0
        s.characterTrust[cid].day = math.floor(D.Server.clock() / 24)
        getSandboxOptions():getOptionByName("MilitaryDrop.TrustDailyCap"):setValue(2)
        s.missions = { characterSchema = 1, open = {}, last = {}, nextHours = {} }
        local sq = p:getCurrentSquare()
        local object = IsoRadio.new(getCell(), sq, getSprite("appliances_com_01_8"))
        sq:AddSpecialObject(object)
        local dd = object:getDeviceData()
        dd:setIsBatteryPowered(true); dd:setPower(1)
        dd:setChannelRaw(D.Config.getChannel()); dd:setIsTurnedOn(true)
        if isServer() then object:transmitCompleteItemToClients() end
        D.Post.install(p, { radio = D.Radio.makeRef(object) })
        local mission = { id = "M_feedback", kind = "cleanup", x = sq:getX() + 4, y = sq:getY(),
            radius = 40, quota = 10, deadline = now + 72, counts = { [cid] = 3 }, reached = { [cid] = 1 },
            horde = { size = 10, dead = 3, nearbyDead = 0, ids = {}, cleanupSchema = 2 } }
        s.missions.open.cleanup = mission
        D.Broadcast.cleanupAnnounced(mission.id, mission.x, mission.y, mission.radius)
        ready = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), mx = mission.x, my = mission.y }
        reply(p, "Ready", ready)
    elseif command == "Finish" and not finished then
        finished = true
        rec(D.Missions.adminIntervene(p, "cleanup", "M_feedback", true), "native cleanup success transition")
        local list = D.Missions.completedForCharacter(cid)
        rec(#list == 1 and list[1].gain == 2 and list[1].contribution == 3, "private history uses actual capped gain")
        rec(#D.Missions.activeMarks().secured == 1, "secured marker active on authority")
        local sq = getCell():getGridSquare(ready.x, ready.y, ready.z)
        local object
        for i = 0, sq:getObjects():size() - 1 do
            local candidate = sq:getObjects():get(i)
            if instanceof(candidate, "IsoWaveSignal") then object = candidate end
        end
        reply(p, "Data", D.Post.consoleData(D.Teams.idFor(p), object, p))
    elseif command == "Expire" then
        s.missions.cleanupHistory[1].completedHours = now - 1
        D.Missions.sendMarks()
        rec(#D.Missions.activeMarks().secured == 0, "one-hour boundary expires the server marker")
        rec(#D.Missions.completedForCharacter(cid) == 1, "history survives marker expiry")
        reply(p, "Expired", { expired = true })
    elseif command == "Done" then finished = "done" end
end
local function send(command)
    if isClient() then sendClientCommand(getPlayer(), "MDCleanupFixture", command, {})
    else fixture(getPlayer(), command) end
end
function H.client.start()
    D, started, at, stage, notices = MilitaryDrop, getTimestampMs(), getTimestampMs(), 0, 0
    errors = getLuaDebuggerErrorCount()
    getPlayer():setGodMod(true)
    UIManager.getDebugConsole():setVisible(false)
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    local previous = D.Client.HANDLERS.CleanupCompleted
    D.Client.HANDLERS.CleanupCompleted = function(args) notices = notices + 1; previous(args) end
    if isClient() then
        Events.OnServerCommand.Add(function(m, c, a)
            if m == "MDCleanupFixture" then
                if c == "Ready" then ready = a else payload = a end
            end
        end)
    end
    return true
end
function H.client.done()
    local elapsed = getTimestampMs() - at
    if getTimestampMs() - started > 90000 then rec(false, "client feedback timeout"); send("Done"); return true end
    if stage == 0 and elapsed > 2000 then send("Seed"); stage, at = 1, getTimestampMs()
    elseif stage == 1 and ready and elapsed > 2000 then send("Finish"); stage, at = 2, getTimestampMs()
    elseif stage == 2 and payload and elapsed > 1000 then
        takeScreenshot("cleanup-success-notification.png")
        rec(notices == 1, "success notification received through real transport")
        local sq = getCell():getGridSquare(ready.x, ready.y, ready.z)
        local object
        for i = 0, sq:getObjects():size() - 1 do
            local candidate = sq:getObjects():get(i)
            if instanceof(candidate, "IsoWaveSignal") then object = candidate end
        end
        panel = D.PostWindow.show(getPlayer(), object, payload)
        panel:select("completed:M_feedback")
        panel.listScroll = math.max(0, #panel.affairList - 4)
        rec(panel:selectedAffair() and panel:selectedAffair().mission.history, "completed mission selected in native post")
        rec(panel:actions() == nil, "completed mission offers no repeat reward action")
        stage, at = 3, getTimestampMs()
    elseif stage == 3 and elapsed > 2000 then
        takeScreenshot("cleanup-success-history.png")
        panel:close("test")
        ISWorldMap.ShowWorldMap(0, ready.mx, ready.my, 19)
        stage, at = 4, getTimestampMs()
    elseif stage == 4 and elapsed > 2000 then
        takeScreenshot("cleanup-secured-map.png")
        ISWorldMap_instance:close()
        payload = nil; send("Expire"); stage, at = 5, getTimestampMs()
    elseif stage == 5 and payload and payload.expired and elapsed > 2000 then
        ISWorldMap.ShowWorldMap(0, ready.mx, ready.my, 19)
        stage, at = 6, getTimestampMs()
    elseif stage == 6 and elapsed > 2000 then
        local api = ISWorldMap_instance.mapAPI:getSymbolsAPIv2()
        local remaining = 0
        for i = 0, api:getSymbolCount() - 1 do
            local symbol = api:getSymbolByIndex(i)
            if symbol:isTexture() and symbol:getSymbolID() == "Checkmark"
                and math.abs(symbol:getWorldX() - ready.mx) < 0.1 and math.abs(symbol:getWorldY() - ready.my) < 0.1 then
                remaining = remaining + 1
                print("[MDCleanupFixture] remaining color " .. symbol:getRed() .. "," .. symbol:getGreen() .. "," .. symbol:getBlue())
            end
        end
        rec(remaining == 0, "expired checkmark actually removed from native client map")
        takeScreenshot("cleanup-map-after-hour.png")
        rec(getLuaDebuggerErrorCount() == errors, "no new native Lua error")
        send("Done")
        return true
    end
    return false
end
H.client.result = result
function H.server.start()
    D, started = MilitaryDrop, getTimestampMs()
    Events.OnClientCommand.Add(function(m, c, p) if m == "MDCleanupFixture" then fixture(p, c) end end)
    return true
end
function H.server.done()
    if getTimestampMs() - started > 120000 then rec(false, "server feedback timeout"); return true end
    return finished == "done"
end
H.server.result = result
return H
