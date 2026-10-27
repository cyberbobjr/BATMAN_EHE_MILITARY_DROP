local H = {}
local at, window, phase, initialErrors
local lines, okay = {}, true
local function rec(value, name)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. name
    if not value then okay = false end
end
function H.start(ctx)
    at, phase, initialErrors = getTimestampMs(), ctx.params.phase or "seed", getLuaDebuggerErrorCount()
    UIManager.getDebugConsole():setVisible(false)
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    setGameSpeed(1)
    local M, J, p = MilitaryDrop, MDJammer, getPlayer()
    local fixture = ModData.getOrCreate("MilitaryDropTestPersistence")
    if phase == "seed" then
        local sq = p:getSquare()
        local item = instanceItem(J.TYPE)
        sq:AddWorldInventoryItem(item, 0.5, 0.5, 0)
        fixture.ref = { id = item:getID(), x = sq:getX(), y = sq:getY(), z = sq:getZ() }
        local battery = p:getInventory():AddItem("Base.Battery")
        battery:setCurrentUsesFloat(0.65)
        J.send(p, "Insert", { ref = fixture.ref, battery = battery:getID() })
        J.send(p, "Toggle", { ref = fixture.ref })
        local id = M.Trust.idFor(p)
        M.Trust.add(id, 100, "drop")
        fixture.character = id
        fixture.drop = M.Trust.registerDrop(id, p:getUsername(), false)
        M.Trust.onDropDelivered(fixture.drop)
        local case = instanceItem("Base.Paperwork")
        M.Trust.tagItem(case, fixture.drop)
        M.Trust.onCaseOpened(case, p)
        M.RelayServer.state().phase = "operational"
        M.RelayServer.fail(2)
        fixture.relaySerial = M.RelayServer.state().serial
        rec(J.Server.isJammed(p), "seed powered world jammer")
    else
        rec(fixture.ref ~= nil, "test fixture persisted through real game shutdown")
        rec(M.Trust.idFor(p) == fixture.character, "character persistent identifier unchanged")
        rec(M.RelayServer.state().phase == "failed" and M.RelayServer.state().serial == fixture.relaySerial,
            "relay mission persisted")
        rec(M.Trust.confirmReceipt(p) and not M.Trust.confirmReceipt(p), "saved receipt acknowledged exactly once")
        local history = M.Secrets.privateState().citationHistory
        rec(history and history[fixture.character] and history[fixture.character].high == 4,
            "citation lifetime history persisted")
        rec(J.Server.isJammed(p), "powered placed jammer resumed after reload")
        local data = ModData.getOrCreate("MilitaryDropJammerPrivate").devices[tostring(fixture.ref.id)]
        rec(data and data.charge > 0.62 and data.charge <= 0.66, "battery energy persisted without refilling")
    end
    window = J.Client.open(p, fixture.ref)
    return true
end
function H.done()
    if getTimestampMs() - at < 4000 then return false end
    takeScreenshot("persistence-" .. phase .. "-jammer.png")
    rec(window.data and window.data.on and window.data.battery, "persisted device visible in actual control window")
    rec(getLuaDebuggerErrorCount() == initialErrors, "no new Lua error in persistence phase")
    return true
end
function H.result() return { ok = okay, summary = #lines .. " saved world checks", lines = lines } end
return H
