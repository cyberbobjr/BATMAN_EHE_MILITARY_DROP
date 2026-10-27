local H = { client = {}, server = {} }
local D, started, stage, at, panel, init, done, errors, before, cid, delivered, pending, vehicle
local okay, lines = true, {}
local observer, observerReady, observerDone, primaryDenied, sentProbe, verifiedObserver, revoked
local otherPlayer, startX, startY, teleported, relayVisited, repairCount, repairXP, repairSerial
local extended, extraStarted, extraInit, extraDone, extraBefore
local accessMenu, accessClick
local function rec(value, label)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. label
    if not value then okay = false end
end
local function result() return { ok = okay, summary = #lines .. " administration checks", lines = lines } end
local function option(name, value) getSandboxOptions():getOptionByName("MilitaryDrop." .. name):setValue(value) end
local function seed(p)
    D = MilitaryDrop
    p:setGodMod(true)
    option("TrustDailyCap", 2); option("CleanupGain", 5)
    option("MinZombies", 0); option("MaxZombies", 0)
    local s, now = D.Secrets.privateState(), getGameTime():getWorldAgeHours()
    cid = D.Trust.idFor(p)
    D.Trust.touch(cid)
    local e = s.characterTrust[cid]
    e.value, e.dayGain, e.day, e.lockedUntil = 40, 0, math.floor(D.Server.clock() / 24), nil
    before = D.Trust.get(cid)
    s.missions = { characterSchema = 1, nextId = 900010, open = {}, nextHours = {}, last = {} }
    s.missions.open.cleanup = { id = "M900001", kind = "cleanup", deadline = now + 72,
        x = math.floor(p:getX()) + 4, y = math.floor(p:getY()), radius = 40, quota = 10,
        counts = { [cid] = 3 }, reached = { [cid] = 1 }, seq = 1,
        horde = { size = 10, dead = 3, nearbyDead = 0, ids = {}, cleanupSchema = 2, hours = now } }
    s.missions.open.recon = { id = "M900002", kind = "recon", deadline = now + 72,
        x = math.floor(p:getX()) + 6, y = math.floor(p:getY()), radius = 30 }
    delivered = D.Trust.registerDrop(cid, p:getUsername(), false)
    local x, y = math.floor(p:getX()) + 8, math.floor(p:getY())
    rec(D.Server.deliver(x, y, p:getUsername(), delivered), "real supply crate delivered for admin closure")
    local drop = D.Trust.drop(delivered)
    local sq = drop.placed and getCell():getGridSquare(drop.placed.x, drop.placed.y, 0)
    vehicle = sq and sq:getVehicleContainer()
    pending = D.Trust.registerDrop(cid, p:getUsername(), false)
    D.RelayServer.state().phase = "operational"
    D.RelayServer.fail(3)
    init = { delivered = delivered, pending = pending }
    if isServer() then sendServerCommand(p, "MDAdminFixture", "Ready", init) end
end
local function audit(p)
    local s = D.Secrets.privateState()
    local placement = D.Trust.drop(delivered).placed
    if placement then
        for dx = -2, 2 do
            for dy = -2, 2 do
                local sq = getCell():getGridSquare(placement.x + dx, placement.y + dy, 0)
                local candidate = sq and sq:getVehicleContainer()
                if candidate and candidate:getModData()[D.Crate.DROP_KEY] == delivered then vehicle = candidate end
            end
        end
    end
    rec(not s.missions.open.cleanup and s.missions.last.cleanup.outcome == "done", "cleanup completed normally")
    rec(s.missions.last.cleanup.character == cid, "ordinary contribution winner receives reward")
    rec(D.Trust.get(cid) == before + 2, "normal reward respects daily cap and is not repeated")
    rec(not s.missions.open.recon and s.missions.last.recon.outcome == "cancelled", "recon closed without reward")
    rec(D.Trust.drop(delivered).outcome == "cancelled", "delivered dossier closed without penalty")
    rec(vehicle and vehicle:getSquare() ~= nil
        and D.Crate.trunkOf(vehicle):getItems():size() > 0,
        "physical crate and contents survive dossier closure")
    rec(D.Trust.drop(pending).outcome == "expired", "undelivered dossier cancelled")
    rec(D.RelayServer.state().phase == "operational", "relay restored administratively")
    rec(not D.Trust.isLineCut(cid), "selected line restored")
    if repairCount then
        rec(D.RelayServer.adminSessionCount(3) == 0, "admin restoration cancels active repair sessions")
        rec(not D.RelayServer.complete(p, { serial = repairSerial }), "late repair cannot complete after admin restoration")
        rec(p:getInventory():getAllTypeRecurse("ElectronicsScrap"):size() == repairCount,
            "interrupted repair consumes no components")
        rec(p:getXp():getXP(Perks.Electricity) == repairXP, "admin restoration and late repair grant no electricity XP")
    end
    done = true
    if isServer() then sendServerCommand(p, "MDAdminFixture", "Done", {}) end
end
local function seedExtra(p)
    local s = D.Secrets.privateState()
    extraBefore = D.Trust.get(cid)
    s.characterTrust[cid].dayGain = 0
    local id = D.Trust.registerDrop(cid, p:getUsername(), false)
    rec(D.Server.deliver(math.floor(p:getX()) + 12, math.floor(p:getY()) + 3, p:getUsername(), id),
        "extra delivered crate ready for public announcement")
    extraInit = { drop = id }
    if isServer() then sendServerCommand(p, "MDAdminFixture", "ExtraReady", extraInit) end
end
local function auditExtra(p)
    local s = D.Secrets.privateState()
    rec(s.missions.last.control and s.missions.last.control.outcome == "done", "new control mission launched and completed")
    rec(s.missions.last.control.character == cid, "explicit selected recipient receives control reward")
    rec(D.Trust.get(cid) == extraBefore + D.Exchange.gain("control"), "control success applies ordinary base reward once")
    rec(D.AdminDashboardServer.announcements[extraInit.drop] ~= nil, "delivered position publicly reannounced")
    extraDone = true
    if isServer() then sendServerCommand(p, "MDAdminFixture", "ExtraDone", {}) end
end
local function select(kind, id)
    if panel.group ~= kind then panel:selectGroup(kind); return false end
    if not panel.data or panel.data.group ~= kind then return false end
    for _, row in ipairs(panel.data.rows or {}) do
        if row.id == id then panel:selectRow(row); return true end
    end
    return false
end
local function nextStage() stage, at = stage + 1, getTimestampMs() end
function H.client.start(ctx)
    D, started, errors = MilitaryDrop, getTimestampMs(), getLuaDebuggerErrorCount()
    stage, at = 0, getTimestampMs()
    observer = isClient() and getPlayer():getUsername() == "pzat2"
    extended = ctx.params.extended == "1"
    startX, startY = getPlayer():getX(), getPlayer():getY()
    getPlayer():setGodMod(true)
    UIManager.getDebugConsole():setVisible(false)
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    if isClient() then
        Events.OnServerCommand.Add(function(m, c, a)
            if m == D.Net.MODULE and c == "AdminDashboard" and a.denied then
                if observer then observerDone = true else primaryDenied = true end
            end
            if m ~= "MDAdminFixture" then return end
            if c == "Ready" then init = a elseif c == "Done" then done = true end
            if c == "Demote" then SendCommandToServer('/setaccesslevel "pzat2" "user"') end
            if c == "Probe" then observerReady = true end
            if c == "ExtraReady" then extraInit = a elseif c == "ExtraDone" then extraDone = true end
        end)
    else seed(getPlayer()) end
    return true
end
function H.client.done()
    local elapsed = getTimestampMs() - at
    if getTimestampMs() - started > 180000 then rec(false, "native console scenario completed before timeout"); return true end
    if elapsed < 700 then return false end
    if observer then
        if observerReady and not sentProbe then
            if D.Admin.allowed(getPlayer()) then return false end
            rec(not D.Admin.allowed(getPlayer()), "ordinary MP role has no administration access")
            rec(D.AdminDashboard.open(getPlayer()) == nil, "ordinary MP role cannot open the console")
            D.Net.toServer(getPlayer(), "AdminDashboard", { action = "list", group = "drop" })
            sentProbe = true
        end
        if observerDone then
            rec(true, "ordinary client request explicitly denied without private projection")
            takeScreenshot("admin-ordinary-player-denied.png")
            sendClientCommand(getPlayer(), "MDAdminFixture", "ObserverDone", {})
            return true
        end
        return false
    end
    if stage == 0 then
        if not init then return false end
        if isClient() then
            accessMenu = ISContextMenu.get(0, 280, 180)
            D.AdminAccess.worldMenu(0, accessMenu, {}, false)
            local option = accessMenu:getOptionFromName(getText("IGUI_MilitaryDrop_AdminMenuAccess"))
            rec(option ~= nil, "MP admin world context entry exists without a radio or world object")
            if not option then return true end
            accessClick = function() option.onSelect(option.target) end
        else
            accessMenu = ISDebugMenu.OnOpenPanel()
            local selected
            for _, b in ipairs(accessMenu.mainTab._buttons) do
                if b.customData and b.customData.militaryDropAdmin then selected = b end
            end
            rec(selected ~= nil, "SP debug Main contains the admin button alongside vanilla tools")
            if not selected then return true end
            accessClick = function() selected:forceClick() end
        end
        takeScreenshot("admin-entry-menu.png")
        stage, at = 80, getTimestampMs()
    elseif stage == 80 then
        accessClick()
        accessMenu:setVisible(false)
        panel = D.AdminDashboard.windows[getPlayer():getPlayerNum()]
        rec(panel ~= nil, "console available in SP debug or MP admin")
        if not panel then return true end
        stage, at = 81, getTimestampMs()
    elseif stage == 81 then
        if not select("radio", "communications") then return false end
        rec(panel.row.militaryChannel ~= nil, "private communications includes current military frequency")
        rec(not panel.row.codeRequired or type(panel.row.code) == "string", "current code is available only in admin communications")
        takeScreenshot("admin-communications.png")
        stage, at = 82, getTimestampMs()
    elseif stage == 82 then
        if not select("tools", "forcedrop") then return false end
        rec(#panel.data.rows == 5, "legacy tools consolidated without moving drop zones")
        takeScreenshot("admin-tools.png")
        stage, at = 1, getTimestampMs()
    elseif stage == 1 then
        if not select("mission", "M900001") then return false end
        rec(panel.row.reward == 2 and panel.row.baseGain == 5, "preview displays daily-capped normal reward")
        takeScreenshot("admin-missions-details.png")
        panel:preview("succeed"); nextStage()
    elseif stage == 2 then
        if not panel.confirmation then return false end
        rec(panel.confirmation.preview.row.beneficiary ~= nil, "native confirmation identifies the recipient")
        panel.confirmation.reason:setText("Resolve verified test objective")
        takeScreenshot("admin-success-confirmation.png")
        nextStage()
    elseif stage == 3 then
        panel.confirmation.confirm:forceClick(); nextStage()
    elseif stage == 4 then
        if panel.pending then return false end
        if not select("mission", "M900002") then return false end
        local noRecipient = false
        for _, action in ipairs(panel.row.actions) do if action.op == "succeed" then noRecipient = not action.enabled end end
        rec(noRecipient, "recon success disabled until recipient chosen")
        panel:preview("closeMission"); nextStage()
    elseif stage == 5 then
        if not panel.confirmation then return false end
        panel.confirmation.reason:setText("Close without reward test")
        takeScreenshot("admin-close-without-reward.png")
        nextStage()
    elseif stage == 6 then panel.confirmation.confirm:forceClick(); nextStage()
    elseif stage == 7 then
        if panel.pending or not select("drop", init.delivered) then return false end
        takeScreenshot("admin-delivered-drop-details.png")
        if not teleported then panel:preview("teleport"); stage, at = 70, getTimestampMs(); return false end
        panel:preview("closeDrop"); nextStage()
    elseif stage == 70 then
        if not panel.confirmation then return false end
        takeScreenshot("admin-teleport-confirmation.png")
        stage, at = 71, getTimestampMs()
    elseif stage == 71 then
        panel.confirmation.confirm:forceClick(); stage, at = 72, getTimestampMs()
    elseif stage == 72 then
        local p = getPlayer()
        if panel.pending or math.abs(p:getX() - startX) + math.abs(p:getY() - startY) < 1 then return false end
        rec(true, "native teleport moves the requesting admin")
        teleported = true
        takeScreenshot("admin-teleport-arrival.png")
        stage, at = 7, getTimestampMs()
    elseif stage == 8 then
        if not panel.confirmation then return false end
        panel.confirmation.reason:setText("Preserve physical crate test"); nextStage()
    elseif stage == 9 then panel.confirmation.confirm:forceClick(); nextStage()
    elseif stage == 10 then
        if panel.pending or not select("drop", init.pending) then return false end
        panel:preview("cancelDrop"); nextStage()
    elseif stage == 11 then
        if not panel.confirmation then return false end
        panel.confirmation.reason:setText("Cancel pending supply test"); nextStage()
    elseif stage == 12 then panel.confirmation.confirm:forceClick(); nextStage()
    elseif stage == 13 then
        if panel.pending or not select("relay", "3") then return false end
        if isClient() and not relayVisited then
            panel:preview("teleport"); stage, at = 130, getTimestampMs(); return false
        end
        takeScreenshot("admin-relay-details.png")
        panel:preview("restore"); nextStage()
    elseif stage == 130 then
        if not panel.confirmation then return false end
        panel.confirmation.confirm:forceClick(); stage, at = 131, getTimestampMs()
    elseif stage == 131 then
        if panel.pending then return false end
        local p = getPlayer()
        if math.abs(p:getX() - 10277) + math.abs(p:getY() - 8744) > 4 then return false end
        relayVisited = true
        sendClientCommand(p, "MDAdminFixture", "BeginRepair", {})
        stage, at = 13, getTimestampMs()
    elseif stage == 14 then
        if not panel.confirmation then return false end
        panel.confirmation.reason:setText("Restore service without repair rewards"); nextStage()
    elseif stage == 15 then panel.confirmation.confirm:forceClick(); nextStage()
    elseif stage == 16 then
        if panel.pending then return false end
        if isClient() then sendClientCommand(getPlayer(), "MDAdminFixture", "Lock", {})
        else D.Secrets.privateState().characterTrust[cid].lockedUntil = getGameTime():getWorldAgeHours() + 24 end
        nextStage()
    elseif stage == 17 then
        if panel.group ~= "character" then panel:selectGroup("character"); return false end
        if not panel.data or panel.data.group ~= "character" then return false end
        for _, row in ipairs(panel.data.rows or {}) do
            if row.name == getPlayer():getUsername() then panel:selectRow(row) end
        end
        if not panel.row or panel.row.phase ~= "blocked" then panel:request("list"); return false end
        takeScreenshot("admin-character-line.png")
        panel:preview("unlock"); nextStage()
    elseif stage == 18 then
        if not panel.confirmation then return false end
        panel.confirmation.reason:setText("Restore selected line"); nextStage()
    elseif stage == 19 then panel.confirmation.confirm:forceClick(); nextStage()
    elseif stage == 20 then
        if panel.pending then return false end
        rec(getLuaDebuggerErrorCount() == errors, "no new client Lua errors in native console")
        takeScreenshot("admin-intervention-result.png")
        if isClient() then sendClientCommand(getPlayer(), "MDAdminFixture", "Audit", {}) else audit(getPlayer()) end
        nextStage()
    elseif stage == 21 then
        if not done then return false end
        if extended and not extraStarted then
            extraStarted = true
            if isClient() then sendClientCommand(getPlayer(), "MDAdminFixture", "ExtraPrepare", {})
            else seedExtra(getPlayer()) end
            stage, at = 200, getTimestampMs()
            return false
        end
        if isClient() then
            SendCommandToServer('/setaccesslevel "pzat1" "user"')
            nextStage()
        else panel:request("exit"); return true end
    elseif stage == 22 then
        if D.Admin.allowed(getPlayer()) then return false end
        if panel:getIsVisible() then return false end
        rec(not panel:getIsVisible(), "native console closes when admin rights are revoked")
        D.Net.toServer(getPlayer(), "AdminDashboard", { action = "list" })
        nextStage()
    elseif stage == 23 then
        if not primaryDenied then return false end
        rec(true, "revoked admin denied again by the server")
        sendClientCommand(getPlayer(), "MDAdminFixture", "Revoked", {})
        return true
    elseif stage == 200 then
        if not extraInit or not select("mission", "slot:control") then return false end
        takeScreenshot("admin-launch-mission.png")
        panel:preview("launch"); nextStage()
    elseif stage == 201 then
        if not panel.confirmation then return false end
        panel.confirmation.reason:setText("Launch ordinary control mission"); nextStage()
    elseif stage == 202 then panel.confirmation.confirm:forceClick(); nextStage()
    elseif stage == 203 then
        if panel.pending then return false end
        local row
        for _, candidate in ipairs(panel.data.rows or {}) do
            if candidate.missionKind == "control" and candidate.phase == "active" then row = candidate end
        end
        if not row then return false end
        panel:selectRow(row)
        for i, recipient in ipairs(panel.recipients) do
            if recipient.name == getPlayer():getUsername() then panel.beneficiary.selected = i + 1 end
        end
        panel.beneficiary.onChange(panel.beneficiary.target, panel.beneficiary)
        nextStage()
    elseif stage == 204 then
        if not panel.row or not panel.row.beneficiary then return false end
        rec(true, "native recipient selector updates authoritative preview")
        takeScreenshot("admin-explicit-recipient.png")
        panel:preview("succeed"); nextStage()
    elseif stage == 205 then
        if not panel.confirmation then return false end
        panel.confirmation.reason:setText("Validate control for explicitly selected recipient"); nextStage()
    elseif stage == 206 then panel.confirmation.confirm:forceClick(); nextStage()
    elseif stage == 207 then
        if panel.pending or not select("drop", extraInit.drop) then return false end
        panel:preview("announce"); nextStage()
    elseif stage == 208 then
        if not panel.confirmation then return false end
        panel.confirmation.reason:setText("Repeat delivered crate location"); nextStage()
    elseif stage == 209 then panel.confirmation.confirm:forceClick(); nextStage()
    elseif stage == 210 then
        if panel.pending then return false end
        local cooled = false
        for _, action in ipairs(panel.row.actions) do
            if action.op == "announce" then cooled = not action.enabled and action.reason == "cooldown" end
        end
        rec(cooled, "repeat announcement cooldown visible on the native action")
        takeScreenshot("admin-announcement-cooldown.png")
        rec(getLuaDebuggerErrorCount() == errors, "no new Lua errors after recipient, launch and announcement")
        if isClient() then sendClientCommand(getPlayer(), "MDAdminFixture", "ExtraAudit", {}) else auditExtra(getPlayer()) end
        nextStage()
    elseif stage == 211 then
        if not extraDone then return false end
        stage, at = 21, getTimestampMs()
    end
    return false
end
H.client.result = result
function H.server.start(ctx)
    started = getTimestampMs()
    local p
    for _, player in ipairs(ctx.players()) do if player:getUsername() == "pzat1" then p = player end end
    for _, player in ipairs(ctx.players()) do if player:getUsername() == "pzat2" then otherPlayer = player end end
    if otherPlayer then startX, startY = otherPlayer:getX(), otherPlayer:getY() end
    seed(p)
    if otherPlayer then sendServerCommand(p, "MDAdminFixture", "Demote", {}) end
    Events.OnClientCommand.Add(function(m, c, who)
        if m ~= "MDAdminFixture" then return end
        if c == "ObserverDone" and who == otherPlayer then
            verifiedObserver = true
            rec(not D.Admin.allowed(who), "ordinary client role really revoked on the server")
            return
        end
        if who ~= p then return end
        if c == "Lock" then D.Secrets.privateState().characterTrust[cid].lockedUntil = getGameTime():getWorldAgeHours() + 24
        elseif c == "BeginRepair" then
            for _ = 1, 20 do
                local item = p:getInventory():AddItem("Base.ElectronicsScrap")
                sendAddItemToContainer(p:getInventory(), item)
            end
            D.RelayServer.begin(p)
            repairCount = p:getInventory():getAllTypeRecurse("ElectronicsScrap"):size()
            repairXP, repairSerial = p:getXp():getXP(Perks.Electricity), D.RelayServer.state().serial
            rec(D.RelayServer.adminSessionCount(3) > 0, "real cabinet repair session started before admin intervention")
        elseif c == "Audit" then
            rec(not otherPlayer or math.abs(otherPlayer:getX() - startX) + math.abs(otherPlayer:getY() - startY) < 1,
                "other player not moved by the admin teleport")
            audit(p)
        elseif c == "Revoked" then
            revoked = true
            rec(not D.Admin.allowed(p), "primary admin role revocation verified on authority")
        elseif c == "ExtraPrepare" then seedExtra(p)
        elseif c == "ExtraAudit" then auditExtra(p)
        end
    end)
    return true
end
function H.server.done()
    if otherPlayer and not observerReady and not D.Admin.allowed(otherPlayer) then
        observerReady = true
        sendServerCommand(otherPlayer, "MDAdminFixture", "Probe", {})
    end
    if getTimestampMs() - started > 220000 then rec(false, "server audit before timeout"); return true end
    return done and (not otherPlayer or verifiedObserver) and revoked
end
H.server.result = result
return H
