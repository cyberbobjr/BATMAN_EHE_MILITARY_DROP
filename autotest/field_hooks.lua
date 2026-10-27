local H = { client = {}, server = {} }
local M, player, radio, at, stage, initialErrors, observed, reportedGain
local lines, okay = {}, true
local waitDone, radioId, radioWindow
local function openRadio(item)
    if not item or isServer() then return end
    radioWindow = ISRadioWindow.activate(getPlayer(), item)
    radioWindow:setX(80); radioWindow:setY(40)
    for _, module in ipairs(radioWindow.modules) do
        module.element:setExpanded(module.element.titleText == getText("IGUI_MilitaryDrop_Logistics"))
    end
end
local function rec(value, name)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. name
    if not value then okay = false end
end
local function result() return { ok = okay, summary = #lines .. " field intelligence checks", lines = lines } end
local function setup(p)
    M, player, at, stage = MilitaryDrop, p, getTimestampMs(), 0
    player:setGodMod(true)
    radio = p:getInventory():AddItem("Base.WalkieTalkie5")
    if isServer() then sendAddItemToContainer(p:getInventory(), radio) end
    p:setPrimaryHandItem(radio)
    radio:getDeviceData():setTurnedOnRaw(true)
    radio:getDeviceData():setChannelRaw(M.Config.getChannel())
    if isServer() then sendServerCommand(p, "MDFieldTest", "Radio", { id = radio:getID() })
    else openRadio(radio) end
    M.Secrets.privateState().fieldActions = { reports = {} }
    rec(M.Server.spawnHordeAround(math.floor(p:getX()), math.floor(p:getY()), 8, 12) >= 10,
        "native living concentration spawned in loaded area")
end
local function step()
    local elapsed = getTimestampMs() - at
    if stage == 0 and elapsed > 3000 then
        reportedGain = M.Trust.get(M.Trust.idFor(player))
        M.FieldActions.report(player, { radio = M.Radio.makeRef(radio), exchangeId = 701 })
        local reports = M.Secrets.privateState().fieldActions.reports
        rec(#reports == 1, "server verifies living zombies and registers one report")
        local cleanup = M.Missions.openMission("cleanup")
        rec(cleanup and cleanup.horde and cleanup.horde.size >= 10 and cleanup.x == math.floor(player:getX()),
            "clearance targets reported existing zombies")
        rec(M.Trust.get(M.Trust.idFor(player)) == reportedGain + 1, "small daily capped report reward")
        reportedGain = M.Trust.get(M.Trust.idFor(player))
        stage, at = 1, getTimestampMs()
    elseif stage == 1 and elapsed > 3300 then
        M.FieldActions.report(player, { radio = M.Radio.makeRef(radio), exchangeId = 702 })
        rec(#M.Secrets.privateState().fieldActions.reports == 1
            and M.Trust.get(M.Trust.idFor(player)) == reportedGain, "same-area replay grants nothing")
        stage, at = 2, getTimestampMs()
    elseif stage == 2 and elapsed > 3300 then
        M.FieldActions.weekly(player, { radio = M.Radio.makeRef(radio), exchangeId = 703 })
        rec(M.Trust.get(M.Trust.idFor(player)) == reportedGain, "weekly query grants no trust")
        stage, at = 3, getTimestampMs()
    elseif stage == 3 and elapsed > 8000 then
        if isServer() then sendServerCommand(player, "MDFieldTest", "Done", {}) end
        return true
    elseif elapsed > 30000 then rec(false, "field scenario completed before timeout"); return true end
    return false
end
function H.client.start()
    M, initialErrors, at = MilitaryDrop, getLuaDebuggerErrorCount(), getTimestampMs()
    UIManager.getDebugConsole():setVisible(false)
    getPlayer():setGodMod(true)
    if not isClient() then setup(getPlayer())
    else Events.OnServerCommand.Add(function(m, c, a)
        if m == "MDFieldTest" and c == "Done" then observed, waitDone = true, getTimestampMs()
        elseif m == "MDFieldTest" and c == "Radio" then radioId = a.id end
    end) end
    return true
end
function H.client.done()
    if radioId and not radioWindow then openRadio(getPlayer():getInventory():getItemWithIDRecursiv(radioId)) end
    local done = isClient() and observed or (not isClient() and step())
    if isClient() and done and getTimestampMs() - waitDone < 2000 then return false end
    if done then
        takeScreenshot("field-report-and-weekly-response.png")
        rec(getLuaDebuggerErrorCount() == initialErrors, "no new client Lua errors")
    end
    return done
end
H.client.result = result
function H.server.start(ctx) setup(ctx.players()[1]); return true end
H.server.done = step
H.server.result = result
return H
