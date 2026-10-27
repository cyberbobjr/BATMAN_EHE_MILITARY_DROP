-- Real engine checks in copied worlds only. MP authority uses actual connected players.
local H = { client = {}, server = {} }
local lines, okay, stage, started, sent, player, clientReady = {}, true, 0, 0, false, nil, false
local M, ref, cabinet, actionAt, componentsBefore, xpBefore, initialErrors
local repairShot = false
local citation, printWindow, siteIndex, waitAt, dashboard
local function check(value, name)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. name
    if not value then okay = false end
end
local function result()
    return { ok = okay, summary = tostring(#lines) .. " improvement checks", lines = lines }
end
local function authority(p)
    M = MilitaryDrop
    local T, R, W = M.Trust, M.Relay, M.Weekly
    check(R.cost(0) == 20 and R.cost(10) == 2 and R.seconds(0) == 15 and R.seconds(10) == 3,
        "relay electricity endpoints")
    local offer = W.current()
    check(#offer.categories == 2 and offer.categories[1] ~= offer.categories[2], "two distinct weekly categories")
    check(W.current(offer.week + 1).categories[1] ~= offer.categories[1], "weekly rotation")
    local counts, values = {}, {}
    counts[offer.categories[1]], values[offer.categories[1]] = 2, 10
    check(W.bonus(counts, values, 100, offer.week) == 10, "weekly fifty percent bonus arithmetic")
    local id = T.idFor(p)
    T.add(id, 0, "drop") -- Migration baseline at current tier.
    T.add(id, 100, "drop")
    local drop = T.registerDrop(id, p:getUsername(), false)
    local entries = M.Crate.contentsFor(drop)
    local citations, honorary = 0, 0
    for _, entry in ipairs(entries) do
        if entry.citationTier then
            citations = citations + 1
            local item = instanceItem(entry.fullType)
            M.Crate.applyEntry(item, entry, drop)
            check(item:getModData().printMedia ~= nil, "readable citation generated")
            if not citation then citation = item end
        elseif entry.honorary then
            honorary = honorary + 1
            local item = instanceItem(entry.fullType)
            M.Crate.applyEntry(item, entry, drop)
            check(not M.Exchange.isDogTag(item, p) and M.Fulton.category(item, p, false) == nil,
                "honorary tag excluded from rewards")
        end
    end
    check(citations >= 1 and honorary == 1, "first upward tiers reserve citations and tier IV honor")
    T.onDropDelivered(drop)
    T.add(id, -40, "drop"); T.add(id, 40, "drop")
    local nextDrop = T.registerDrop(id, p:getUsername(), false)
    check(#T.citationsFor(nextDrop) == 0, "lowering and regaining tier never duplicates citation")
    local case = instanceItem("Base.Paperwork")
    T.tagItem(case, drop)
    T.onCaseOpened(case, p)
    check(T.confirmReceipt(p), "own recovered drop receipt acknowledged")
    check(not T.confirmReceipt(p), "receipt replay rejected")
    check(M.Flights.cancelDrop(nextDrop) and not M.Flights.cancelDrop(nextDrop), "pending drop cancellation idempotent")
    check(#M.AdminDashboardServer.rows() > 0, "admin operation projection built")
    T.registerDrop(id, p:getUsername(), false)
    M.Missions.launch("control")
    local square = p:getSquare()
    local flight = M.Flight.new(99123, square:getX(), square:getY(), 0.8)
    flight.elapsed = M.Flight.timeline(flight) + 1
    M.Net.toAll("FlightStart", M.Flight.toArgs(flight))
    p:setGodMod(true)
    for _ = 1, 25 do
        local item = p:getInventory():AddItem("Base.ElectronicsScrap")
        if isServer() then sendAddItemToContainer(p:getInventory(), item) end
    end
    M.RelayServer.state().phase = "operational"
    check(M.RelayServer.fail(3), "relay failure activated at real map cabinet")
    return true
end
local function command(module, name, p, args)
    if module ~= "MDImprovementTest" then return end
    if name == "Begin" then
        check(M.RelayServer.cabinet(M.Relay.SITES[3]) ~= nil, "real cabinet sprite resolved on server")
        M.RelayServer.begin(p)
        check(not M.RelayServer.complete(p, { serial = M.RelayServer.state().serial }), "premature repair rejected")
    elseif name == "Finished" then
        check(M.RelayServer.state().phase == "operational", "repair completion authoritative")
        check(args.spent == args.expected, "client inventory synchronized component consumption")
        check(args.xp, "electrical XP synchronized")
        clientReady = true
    end
end
function H.client.start()
    player, M, started = getPlayer(), MilitaryDrop, getTimestampMs()
    initialErrors = getLuaDebuggerErrorCount()
    player:setGodMod(true)
    player:setPerkLevelDebug(Perks.Electricity, 0)
    player:getXp():setXPToLevel(Perks.Electricity, 0)
    setGameSpeed(1)
    UIManager.getDebugConsole():setVisible(false)
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    player:teleportTo(10276.5, 8744.5, 0)
    if not isClient() then authority(player) end
    return true
end
function H.client.done()
    if getTimestampMs() - started > 120000 then check(false, "scenario before timeout"); return true end
    if stage == 0 then
        if getTimestampMs() - started < 20000 then return false end
        if not M.Relay or M.Relay.clientState.phase ~= "failed" then return false end
        local site = M.Relay.SITES[3]
        cabinet = getCell():getGridSquare(site.x, site.y, 0)
        if not cabinet or not M.Relay.near(player, site) then return false end
        local list = player:getInventory():getAllTypeRecurse("ElectronicsScrap")
        if list:size() < 20 then return false end
        componentsBefore = list:size()
        xpBefore = player:getXp():getXP(Perks.Electricity)
        actionAt = getTimestampMs()
        local level = player:getPerkLevel(Perks.Electricity)
        ref = { cost = M.Relay.cost(level), seconds = M.Relay.seconds(level) }
        if isClient() then sendClientCommand(player, "MDImprovementTest", "Begin", {})
        else
            check(M.RelayServer.cabinet(site) ~= nil, "real cabinet sprite resolved")
            M.RelayServer.begin(player)
            check(not M.RelayServer.complete(player, { serial = M.Relay.clientState.serial }), "premature repair rejected")
        end
        stage = 1
    elseif stage == 1 then
        if not repairShot and getTimestampMs() - actionAt > 2000 then
            takeScreenshot("improvements-relay-repair.png")
            repairShot = true
        end
        if M.Relay.clientState.phase ~= "operational" then return false end
        if player:getXp():getXP(Perks.Electricity) <= xpBefore
            and getTimestampMs() - actionAt < ref.seconds * 1000 + 5000 then return false end
        local spent = componentsBefore - player:getInventory():getAllTypeRecurse("ElectronicsScrap"):size()
        local xp = player:getXp():getXP(Perks.Electricity) > xpBefore
        check(spent == ref.cost, "repair exact components consumed")
        check(getTimestampMs() - actionAt >= ref.seconds * 900, "real timed repair duration")
        check(xp, "repair grants electricity XP")
        dashboard = M.AdminDashboard.open(player)
        check(dashboard ~= nil, "admin dashboard opens with real widgets")
        stage, actionAt = 2, getTimestampMs()
    elseif stage == 2 and getTimestampMs() - actionAt > 2000 then
        takeScreenshot("improvements-admin-dashboard.png")
        if dashboard then dashboard:request("exit") end
        stage, actionAt = 3, getTimestampMs()
    elseif stage == 3 and getTimestampMs() - actionAt > 1000 then
        if citation then
            local value = citation:getModData().printMedia
            printWindow = PZAPI.UI.PrintMedia{ x = 100, y = 50 }
            printWindow.media_id, printWindow.data = value.id, value.info
            printWindow.children.bar.children.name.text = value.title
            printWindow.textTitle, printWindow.textData = value.title, value.text
            printWindow:instantiate()
            printWindow:centerOnScreen(0)
        end
        stage, actionAt = 4, getTimestampMs()
    elseif stage == 4 and getTimestampMs() - actionAt > 1500 then
        if citation then takeScreenshot("improvements-citation.png") end
        if printWindow then UIManager.RemoveElement(printWindow.javaObj) end
        if not isClient() then
            siteIndex, waitAt, stage = 1, getTimestampMs(), 5
            M.RelayServer.state().phase = "operational"
            M.RelayServer.fail(siteIndex)
            local site = M.Relay.SITES[siteIndex]
            player:teleportTo(site.x - 1, site.y, 0)
            return false
        end
        stage = 6
    elseif stage == 5 and getTimestampMs() - waitAt > 16000 then
        local site = M.Relay.SITES[siteIndex]
        check(M.RelayServer.cabinet(site) ~= nil, "actual relay cabinet at site " .. siteIndex)
        takeScreenshot("improvements-relay-site-" .. siteIndex .. ".png")
        siteIndex = siteIndex + 1
        if siteIndex > #M.Relay.SITES then
            M.RelayServer.state().phase = "operational"
            M.RelayServer.snapshot()
            stage = 6
        else
            M.RelayServer.state().phase = "operational"
            M.RelayServer.fail(siteIndex)
            site = M.Relay.SITES[siteIndex]
            player:teleportTo(site.x - 1, site.y, 0)
            waitAt = getTimestampMs()
        end
    elseif stage == 6 then
        if isClient() and not sent then
            sent = true
            sendClientCommand(player, "MDImprovementTest", "Finished", { spent = ref.cost, expected = ref.cost,
                xp = player:getXp():getXP(Perks.Electricity) > xpBefore })
        end
        check(getLuaDebuggerErrorCount() == initialErrors, "no new Lua errors in scenario")
        return true
    end
    return false
end
H.client.result = result
function H.server.start(ctx)
    player, started = ctx.players()[1], getTimestampMs()
    M = MilitaryDrop
    Events.OnClientCommand.Add(command)
    authority(player)
    return true
end
function H.server.done()
    if getTimestampMs() - started > 150000 then check(false, "client finished before timeout"); return true end
    return clientReady
end
H.server.result = result
return H
