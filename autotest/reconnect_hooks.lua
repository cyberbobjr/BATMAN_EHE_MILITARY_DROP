local H = { client = {}, server = {} }
local fixture, window, at, reload, ready, done, player, initialErrors
local okay, lines = true, {}
local function rec(value, text)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. text
    if not value then okay = false end
end
local function result() return { ok = okay, summary = #lines .. " real reconnect checks", lines = lines } end
function H.client.start(ctx)
    reload, at, initialErrors = ctx.params.reconnect == "1", getTimestampMs(), getLuaDebuggerErrorCount()
    player = getPlayer()
    player:setGodMod(true)
    UIManager.getDebugConsole():setVisible(false)
    if ISChat.instance then ISChat.instance:setVisible(false) end
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    Events.OnServerCommand.Add(function(m, c, args)
        if m == "MDReconnectTest" and c == "Fixture" then fixture = args end
    end)
    sendClientCommand(player, "MDReconnectTest", "Ready", { reconnect = reload })
    return true
end
function H.client.done()
    if getTimestampMs() - at > 60000 then rec(false, "client reconnect phase completed before timeout"); return true end
    if not fixture then return false end
    if not window then
        local square = getCell():getGridSquare(fixture.ref.x, fixture.ref.y, fixture.ref.z)
        if not square then return false end
        local present = false
        for i = 0, square:getWorldObjects():size() - 1 do
            if square:getWorldObjects():get(i):getItem():getID() == fixture.ref.id then present = true end
        end
        if not present then return false end
        window = MDJammer.Client.open(player, fixture.ref)
    end
    if getTimestampMs() - at < 12000 or not window.data then return false end
    rec(window.data.on and window.data.battery, "actual placed device still powered")
    rec(MDJammer.Client.coverage[0], "coverage received in this process")
    rec(window.data.charge > 0.3 and window.data.charge <= 0.66, "remaining energy not refilled")
    rec(MilitaryDrop.Relay.clientState.phase == "failed" and MilitaryDrop.Relay.clientState.serial == fixture.serial,
        "relay snapshot restored in this client process")
    takeScreenshot(reload and "mp-after-real-reconnect.png" or "mp-before-real-disconnect.png")
    rec(getLuaDebuggerErrorCount() == initialErrors, "no new client Lua errors")
    sendClientCommand(player, "MDReconnectTest", "Observed", { reconnect = reload })
    return true
end
H.client.result = result
local function serverReceive(m, c, p, args)
    if m ~= "MDReconnectTest" then return end
    if c == "Ready" then
        if args.reconnect then
            rec(ready, "second connection follows completed first connection")
            rec(MilitaryDrop.Trust.idFor(p) == fixture.character, "native saved character identifier unchanged")
            rec(MilitaryDrop.Trust.confirmReceipt(p) and not MilitaryDrop.Trust.confirmReceipt(p),
                "receipt available exactly once after real reconnect")
            rec(MilitaryDrop.Secrets.privateState().citationHistory[fixture.character].high == 4,
                "citation history attached to returning character")
        end
        sendServerCommand(p, "MDReconnectTest", "Fixture", fixture)
    elseif c == "Observed" then
        if args.reconnect then
            rec(MDJammer.Server.isJammed(p), "server covers returning connected player")
            done = true
        else ready = true end
    end
end
function H.server.start(ctx)
    at = getTimestampMs()
    for _, p in ipairs(ctx.players()) do if p:getUsername() == "pzat1" then player = p end end
    local M, J = MilitaryDrop, MDJammer
    fixture = { character = M.Trust.idFor(player) }
    player:setGodMod(true)
    local square = player:getSquare()
    local item = instanceItem(J.TYPE)
    square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
    fixture.ref = { id = item:getID(), x = square:getX(), y = square:getY(), z = square:getZ() }
    local battery = player:getInventory():AddItem("Base.Battery")
    battery:setCurrentUsesFloat(0.65)
    J.Server.command(J.MODULE, "Insert", player, { ref = fixture.ref, battery = battery:getID() })
    J.Server.command(J.MODULE, "Toggle", player, { ref = fixture.ref })
    M.Trust.add(fixture.character, 100, "drop")
    local drop = M.Trust.registerDrop(fixture.character, player:getUsername(), false)
    M.Trust.onDropDelivered(drop)
    local case = instanceItem("Base.Paperwork")
    M.Trust.tagItem(case, drop)
    M.Trust.onCaseOpened(case, player)
    M.RelayServer.state().phase = "operational"
    M.RelayServer.fail(2)
    fixture.serial = M.RelayServer.state().serial
    rec(J.Server.isJammed(player), "server seeded powered world device")
    Events.OnClientCommand.Add(serverReceive)
    return true
end
function H.server.done()
    if getTimestampMs() - at > 240000 then rec(false, "real reconnect before timeout"); return true end
    return done == true
end
H.server.result = result
return H
