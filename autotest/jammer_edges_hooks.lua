-- Two active clients operate the same world item. No production test commands.
local H = { client = {}, server = {} }
local J, ref, window, stage, at, started, players, item, worldObject, batteryIds
local ready, observerDone, clientDone = {}, {}, false
local okay, lines, shots = true, {}, 0
local function rec(value, text)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. text
    print("[MilitaryDrop test] " .. lines[#lines])
    if not value then okay = false end
end
local function result() return { ok = okay, summary = #lines .. " jammer concurrency checks", lines = lines } end
local function clientReceive(m, c, a)
    if m ~= "MDJammerEdges" then return end
    if c == "Init" then
        ref = a.ref
        window = J.Client.open(getPlayer(), ref)
    elseif c == "Insert" then
        J.send(getPlayer(), "Insert", { ref = ref, battery = a.batteries[getPlayer():getUsername()] })
    elseif c == "Toggle" and getPlayer():getUsername() == a.owner then
        J.send(getPlayer(), "Toggle", { ref = ref })
    elseif c == "Remove" then J.send(getPlayer(), "Remove", { ref = ref })
    elseif c == "Observe" then stage, at = a.phase, getTimestampMs()
    elseif c == "Done" then clientDone = true end
end
function H.client.start()
    J, started, stage = MDJammer, getTimestampMs(), "init"
    setGameSpeed(1)
    UIManager.getDebugConsole():setVisible(false)
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    getPlayer():setGodMod(true)
    Events.OnServerCommand.Add(clientReceive)
    return true
end
function H.client.done()
    if getTimestampMs() - started > 130000 then rec(false, "client completed before timeout"); return true end
    if window and window.data then
        if stage == "init" then
            sendClientCommand(getPlayer(), "MDJammerEdges", "Ready", {})
            stage = "wait"
        elseif stage == "active" and window.data.on and getTimestampMs() - at > 2500 then
            rec(J.Client.coverage[0], "shared active coverage visible")
            shots = shots + 1
            takeScreenshot("jammer-active-client-" .. getPlayer():getUsername() .. ".png")
            MilitaryDrop.Net.toServer(getPlayer(), "Request", { code = "ZZ99" })
            sendClientCommand(getPlayer(), "MDJammerEdges", "Observed", { phase = "active" })
            stage, at = "blocked", getTimestampMs()
        elseif stage == "blocked" and getTimestampMs() - at > 1000 then
            takeScreenshot("jammer-blocked-client-" .. getPlayer():getUsername() .. ".png")
            stage = "wait"
        elseif stage == "empty" and not window.data.battery and getTimestampMs() - at > 2500 then
            rec(not window.data.on, "both observers see battery removed and power off")
            takeScreenshot("jammer-removed-client-" .. getPlayer():getUsername() .. ".png")
            sendClientCommand(getPlayer(), "MDJammerEdges", "Observed", { phase = "empty" })
            stage = "wait"
        end
    end
    return clientDone
end
H.client.result = result
local function countBatteries()
    local total = 0
    for _, p in ipairs(players) do total = total + p:getInventory():getAllTypeRecurse("Battery"):size() end
    return total
end
local function serverReceive(m, c, p, a)
    if m ~= "MDJammerEdges" then return end
    if c == "Ready" then ready[p:getUsername()] = true
    elseif c == "Observed" then observerDone[p:getUsername()] = a.phase end
end
local function allIn(tableValue, value)
    for _, p in ipairs(players) do if tableValue[p:getUsername()] ~= value then return false end end
    return true
end
local function tell(command, args) sendServerCommand("MDJammerEdges", command, args or {}) end
function H.server.start(ctx)
    J, players, started, stage = MDJammer, ctx.players(), getTimestampMs(), 0
    Events.OnClientCommand.Add(serverReceive)
    rec(#players == 2, "two real clients connected")
    local p = players[1]
    item = instanceItem(J.TYPE)
    local sq = p:getSquare()
    sq:AddWorldInventoryItem(item, 0.5, 0.5, 0)
    worldObject = item:getWorldItem()
    ref = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), id = item:getID() }
    batteryIds = {}
    for _, other in ipairs(players) do
        other:setGodMod(true)
        local battery = other:getInventory():AddItem("Base.Battery")
        battery:setCurrentUsesFloat(0.15)
        sendAddItemToContainer(other:getInventory(), battery)
        batteryIds[other:getUsername()] = battery:getID()
    end
    tell("Init", { ref = ref })
    return true
end
function H.server.done()
    local stamp = getTimestampMs()
    if stamp - started > 140000 then rec(false, "server scenario completed before timeout"); return true end
    local data = ModData.getOrCreate("MilitaryDropJammerPrivate").devices
    data = data and data[tostring(item:getID())]
    if stage == 0 and allIn(ready, true) then
        rec(countBatteries() == 2, "two batteries initially owned")
        tell("Insert", { batteries = batteryIds }); stage, at = 1, stamp
    elseif stage == 1 and stamp - at > 2500 then
        rec(data and data.charge ~= nil and countBatteries() == 1, "simultaneous insert consumes exactly one battery")
        tell("Toggle", { owner = players[1]:getUsername() }); stage, at = 2, stamp
    elseif stage == 2 and stamp - at > 1000 then
        rec(data and data.on and J.Server.isJammed(players[1]) and J.Server.isJammed(players[2]),
            "server covers both connected players")
        tell("Observe", { phase = "active" }); stage, at = 3, stamp
    elseif stage == 3 and allIn(observerDone, "active") and stamp - at > 4500 then
        tell("Remove"); stage, at = 4, stamp
    elseif stage == 4 and stamp - at > 2500 then
        rec(data.charge == nil and not data.on and countBatteries() == 2,
            "simultaneous removal returns exactly one battery")
        tell("Observe", { phase = "empty" }); stage, at = 5, stamp
    elseif stage == 5 and allIn(observerDone, "empty") then
        local before = countBatteries()
        J.Server.command(J.MODULE, "Insert", players[1], { ref = { x = ref.x + 100, y = ref.y,
            z = ref.z, id = ref.id }, battery = batteryIds[players[1]:getUsername()] })
        rec(countBatteries() == before and data.charge == nil, "forged world coordinates cannot move inventory")
        data.charge, data.on, data.hour = 0.005, true, getGameTime():getWorldAgeHours()
        J.Server.advance(data, data.hour + J.hours())
        rec(data.charge == 0 and not data.on, "energy exhaustion stops device")
        data.on, data.charge = true, 0.5
        worldObject:getSquare():transmitRemoveItemFromSquare(worldObject)
        players[1]:getInventory():AddItem(item)
        rec(not J.Server.active(data) and not data.on, "picked-up device stops emitting")
        tell("Done")
        return true
    end
    return false
end
H.server.result = result
return H
