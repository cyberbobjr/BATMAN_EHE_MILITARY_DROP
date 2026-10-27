local H = { client = {}, server = {} }
local ready, stage, at, ref, batteryId, blocked, window, expected
local lines, ok = {}, true
local function rec(value, name)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. name
    if not value then ok = false end
end
local function setup(player)
    local item = instanceItem(MDJammer.TYPE)
    local sq = player:getSquare()
    sq:AddWorldInventoryItem(item, 0.5, 0.5, 0)
    local battery = player:getInventory():AddItem("Base.Battery")
    battery:setCurrentUsesFloat(0.6)
    if isServer() then sendAddItemToContainer(player:getInventory(), battery) end
    return { ref = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), id = item:getID() },
        battery = battery:getID(), charge = battery:getCurrentUsesFloat() }
end
local function receive(module, command, args)
    if module == "MDJammerTest" and command == "Init" then
        ref, batteryId, ready = args.ref, args.battery, true
        expected = args.charge
    elseif module == MDJammer.MODULE and args.reason == "blocked" then blocked = true end
end
function H.client.start()
    stage, at = 0, getTimestampMs()
    Events.OnServerCommand.Add(receive)
    if not isClient() then
        local args = setup(getPlayer())
        ref, batteryId, ready = args.ref, args.battery, true
        expected = args.charge
        local original = MDJammer.Client.receive
        MDJammer.Client.receive = function(m, c, a) receive(m, c, a); original(m, c, a) end
    end
    return true
end
function H.client.done()
    local player = getPlayer()
    if getTimestampMs() - at > 60000 then rec(false, "scenario completed before timeout"); return true end
    if not ready then return false end
    if stage == 0 then
        local sq = getCell():getGridSquare(ref.x, ref.y, ref.z)
        if not sq then return false end
        local found = false
        for i = 0, sq:getWorldObjects():size() - 1 do
            if sq:getWorldObjects():get(i):getItem():getID() == ref.id then found = true end
        end
        if not found or not player:getInventory():getItemWithIDRecursiv(batteryId) then return false end
        rec(instanceItem(MDJammer.TYPE) ~= nil, "jammer item script loaded")
        window = MDJammer.Client.open(player, ref)
        stage = 1
    elseif stage == 1 and window.data then
        rec(not window.data.battery and not window.data.on, "new jammer empty and off")
        MDJammer.send(player, "Insert", { ref = ref, battery = batteryId })
        stage = 2
    elseif stage == 2 and window.data.battery then
        rec(math.abs(window.data.charge - expected) < 0.001, "insert preserves partial charge")
        MDJammer.send(player, "Toggle", { ref = ref })
        stage = 3
    elseif stage == 3 and window.data.on then
        rec(MDJammer.Client.coverage[player:getPlayerNum()], "coverage detected")
        MilitaryDrop.Net.toServer(player, "Request", { code = "ZZ99" })
        takeScreenshot("jammer-window.png")
        stage = 4
    elseif stage == 4 and blocked then
        rec(true, "real request blocked before business handler")
        MDJammer.send(player, "Remove", { ref = ref })
        stage = 5
    elseif stage == 5 and not window.data.battery then
        rec(not window.data.on, "removal switches jammer off")
        local all = player:getInventory():getItems()
        local returned = false
        for i = 0, all:size() - 1 do
            local item = all:get(i)
            if item:getFullType() == "Base.Battery" and item:getCurrentUsesFloat() > expected - 0.015
                and item:getCurrentUsesFloat() <= expected + 0.00001 then returned = true end
        end
        rec(returned, "battery returned with remaining charge")
        window:close()
        if isClient() then sendClientCommand(player, "MDJammerTest", "Done", { ok = ok }) end
        stage = 6
        return true
    end
    return false
end
function H.client.result()
    return { ok = ok, summary = tostring(#lines) .. " jammer checks", lines = lines }
end
local serverDone, serverOk, started
function H.server.start(ctx)
    started = getTimestampMs()
    local player = ctx.players()[1]
    local args = setup(player)
    Events.OnClientCommand.Add(function(m, c, _, a)
        if m == "MDJammerTest" and c == "Done" then serverDone, serverOk = true, a.ok end
    end)
    sendServerCommand(player, "MDJammerTest", "Init", args)
    return true
end
function H.server.done() return serverDone or getTimestampMs() - started > 80000 end
function H.server.result()
    return { ok = serverDone and serverOk, summary = "jammer client/server transport", lines = {} }
end
return H
