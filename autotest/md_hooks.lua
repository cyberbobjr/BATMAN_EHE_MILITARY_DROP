--[[
Hooks of the generic launcher pz-autotest (.claude/tools/pz-autotest) for Military Drop: nominal path (C13 of
docs/ameliorations-et-idees.md). Configuration: MilitaryDrop/autotest.json. Loaded by batman_PZAutoTestDriver with
loadstring (global environment, the mod already loaded). ASCII only (Kahlua lexer).

Authority (solo client, or mp server with the first connected player), through the mod's own server entry points:
  1. military radio (Base.WalkieTalkie5) in the main hand, on, tuned to the military channel (Config.getChannel);
  2. Server.evaluate: wrong code -> "noAnswer", right code (Server.acceptedCodes) -> "accepted";
  3. Server.launchDrop (what handleRequest does without the requisition form) to a landing square near the player
     (Server.findLandingNear, opts.point), then Server.evaluate again -> "cooldown" (global delay recorded);
  4. real flight (MilitaryDrop_Flights, OnTick) until Server.deliver records the delivery (Trust.drop(id));
     crate vehicle on the square, marked supply cases in its trunk;
  5. Trust.onCaseOpened (called by Recipe.openSupplyCase) on a marked case: outcome "recovered", trust not lower;
     mp with a second connected player (--clients 2): the case is opened by that other player instead (no common
     faction): outcome "taken", the caller's trust lowered by Trust.DROP_TAKEN (C13);
  6. Missions.adminLaunch(control): mission open and listed for the character;
  7. liaison post: HAM radio (IsoRadio with the HamRadio2 sprite) on the player's square, Post.install -> owner;
  8. Fulton: FultonServer.launch without a kit -> refused "noKit" (the full launch is the scenario -P scenario=fulton).
Client view (solo: same Lua; mp: client 1 with --client-run): MilitaryDrop server commands received ("Result"
accepted, "PostResult" installed) and the crate vehicle seen near the player; Fulton modules loaded under their
production names (C03), liaison post console opened through the server (PostOpen -> PostData) and requisition sheet
opened, both drawn for a few frames then closed (C08: split window files, Lua errors counted at the end).

Parameters (ctx.params, text): deliverySec (default 240), clientWaitSec (mp client, default 420), crateWaitSec
(crate vehicle or ground cases after the delivery, default 30), serverLeadSec (mp server, delay before step 1 so
that client 1 observes the "Result" reply, default 20).
Run state: MilitaryDrop's world state of the COPIED save only (pz-autotest copies the save and the server).
]]

local H = { client = {}, server = {} }

-- -P shots=1: screenshots for a visual check (Zomboid/Screenshots of the cache, copied into runs/... by pz-autotest).
-- takeScreenshot reads the last presented frame: wait a few frames after a UI change.
local SHOTS = false


local REQUEST_ID = 9001
local WRONG_CODE = "ZZ99"

-- ------------------------------------------------------------------ report

local R = { lines = {}, ok = true }

local function reset()
    R = { lines = {}, ok = true, seen = {}, steps = {}, index = 0, at = 0 }
end

local function rec(ok, name, detail)
    if not ok then R.ok = false end
    R.lines[#R.lines + 1] = (ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" - " .. tostring(detail)) or "")
end

local function info(text)
    R.lines[#R.lines + 1] = "INFO " .. tostring(text)
end

local function shotAfter(S, key, frames, name)
    S[key] = (S[key] or 0) + 1
    if S[key] < frames then return false end
    if S[key] == frames then
        takeScreenshot(name)
        info("screenshot " .. name)
        return false
    end
    return S[key] >= frames + 5
end

local function check(name, fn)
    local ok, res, detail = pcall(fn)
    if not ok then
        rec(false, name, "error: " .. tostring(res))
        return false
    end
    rec(res == true, name, detail)
    return res == true
end

local function nowMs()
    return getTimestampMs()
end

-- Step machine polled by the done hook: each step returns true (next step), or false to be polled again until
-- its deadline (then FAIL with its name).
local function addStep(name, fn, limitMs)
    R.steps[#R.steps + 1] = { name = name, fn = fn, limitMs = limitMs or 0 }
end

local function runSteps()
    while true do
        local step = R.steps[R.index + 1]
        if not step then return true end
        if not step.started then
            step.started = nowMs()
        end
        local ok, res = pcall(step.fn)
        if not ok then
            rec(false, step.name, "error: " .. tostring(res))
            R.index = R.index + 1
        elseif res == true then
            R.index = R.index + 1
        elseif nowMs() - step.started > step.limitMs then
            rec(false, step.name, "timeout after " .. tostring(math.floor(step.limitMs / 1000)) .. " s")
            R.index = R.index + 1
        else
            return false
        end
    end
end

local function summary()
    local pass, total = 0, 0
    for i = 1, #R.lines do
        local head = R.lines[i]:sub(1, 4)
        if head == "PASS" then pass = pass + 1 end
        if head == "PASS" or head == "FAIL" then total = total + 1 end
    end
    return { ok = R.ok and total > 0, summary = tostring(pass) .. "/" .. tostring(total) .. " PASS", lines = R.lines }
end

local function errorCheck()
    check("no Lua error recorded", function()
        local n = getLuaDebuggerErrorCount and getLuaDebuggerErrorCount() or 0
        return n == 0, "errors=" .. tostring(n)
    end)
end

-- ------------------------------------------------------------------ helpers

local function isCrateVehicle(vehicle)
    local name = vehicle and vehicle:getScriptName()
    return name ~= nil and string.find(tostring(name), "MilitaryDrop_", 1, true) ~= nil
end

-- Crate vehicle within radius squares of (x, y), level 0, and the list of distinct crate vehicles seen.
-- IsoGridSquare.getVehicleContainer only finds a vehicle once its first update ran: addVehicleDebug ->
-- createPhysics only queues it in IsoCell.addVehicles (BaseVehicle.java:883), and isIntersectingSquare is false
-- while BaseVehicle.current is nil (set by postupdate, BaseVehicle.java:3591 and 5318). Poll, never conclude at once.
local function crateNear(x, y, radius)
    local cell = getCell()
    local first, seen, list = nil, {}, {}
    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(x + dx, y + dy, 0)
            local vehicle = square and square:getVehicleContainer()
            if isCrateVehicle(vehicle) and not seen[vehicle] then
                seen[vehicle] = true
                list[#list + 1] = vehicle
                if not first then first = vehicle end
            end
        end
    end
    return first, list
end

-- Ground items marked with dropId within radius squares of (x, y), level 0 (ground fallback of Server.deliver).
local function markedGround(x, y, radius, dropId, key)
    local cell = getCell()
    local found, types = {}, {}
    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(x + dx, y + dy, 0)
            local objects = square and square:getWorldObjects()
            for i = 0, (objects and objects:size() or 0) - 1 do
                local item = objects:get(i):getItem()
                if item and item:getModData()[key] == dropId then
                    found[#found + 1] = item
                    types[#types + 1] = item:getFullType()
                end
            end
        end
    end
    return found, types
end

local function describeVehicles(list)
    local parts = {}
    for _, vehicle in ipairs(list) do
        parts[#parts + 1] = tostring(vehicle:getScriptName()) .. "@" .. math.floor(vehicle:getX()) .. ","
            .. math.floor(vehicle:getY())
    end
    return #parts > 0 and table.concat(parts, " ") or "none"
end

-- Items of the vehicle marked with dropId (MilitaryDrop.Trust.ITEM_KEY), list of full types.
local function markedItems(vehicle, dropId, key)
    local found, types = {}, {}
    for i = 0, vehicle:getPartCount() - 1 do
        local container = vehicle:getPartByIndex(i):getItemContainer()
        if container then
            local items = container:getItems()
            for j = 0, items:size() - 1 do
                local item = items:get(j)
                types[#types + 1] = item:getFullType()
                if item:getModData()[key] == dropId then
                    found[#found + 1] = item
                end
            end
        end
    end
    return found, types
end

local function giveMilitaryRadio(player, channel)
    local inv = player:getInventory()
    local radio = inv:AddItem("Base.WalkieTalkie5")
    if not radio then return nil end
    if isServer() and sendAddItemToContainer then
        sendAddItemToContainer(inv, radio)
    end
    player:setPrimaryHandItem(radio)
    local data = radio:getDeviceData()
    data:setTurnedOnRaw(true)
    data:setChannelRaw(channel)
    return radio
end

-- ------------------------------------------------------------------ client observer

-- Records the MilitaryDrop server commands received by this client. Solo: Net.toPlayer calls
-- MilitaryDrop.Client.onServerCommand directly (field looked up at each call): wrapped, arguments and return kept.
-- mp: an extra OnServerCommand subscriber (the mod's own subscriber is untouched).
local Observer = { installed = false }

local function observe(module, command, args)
    -- Fulton flights (MilitaryDrop_FultonFlightServer.lua): own module, recorded as "FlightSnapshot".
    if module == "MilitaryDropFultonFlight" and command == "Snapshot" then
        module, command = "MilitaryDrop", "FlightSnapshot"
    end
    if module ~= "MilitaryDrop" or type(command) ~= "string" then return end
    local list = R.seen[command] or {}
    list[#list + 1] = type(args) == "table" and args or {}
    R.seen[command] = list
end

local function installObserver()
    if Observer.installed then return end
    Observer.installed = true
    if isClient() then
        Observer.listener = function(module, command, args) observe(module, command, args) end
        Events.OnServerCommand.Add(Observer.listener)
    elseif MilitaryDrop.Client and MilitaryDrop.Client.onServerCommand then
        local original = MilitaryDrop.Client.onServerCommand
        Observer.original = original
        MilitaryDrop.Client.onServerCommand = function(module, command, args)
            observe(module, command, args)
            return original(module, command, args)
        end
    end
end

local function removeObserver()
    if not Observer.installed then return end
    if Observer.listener then Events.OnServerCommand.Remove(Observer.listener) end
    if Observer.original then MilitaryDrop.Client.onServerCommand = Observer.original end
    Observer = { installed = false }
end

local function received(command, pred)
    for _, args in ipairs(R.seen[command] or {}) do
        if not pred or pred(args) then return args end
    end
    return nil
end

--- Liaison post radio of the player's team within 2 squares (client view), or nil.
local function ownPostNear(player)
    local cell, PW = getCell(), MilitaryDrop.PostWindow
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for dx = -2, 2 do
        for dy = -2, 2 do
            local square = cell:getGridSquare(px + dx, py + dy, pz)
            local objects = square and square:getObjects()
            for i = 0, (objects and objects:size() or 0) - 1 do
                local object = objects:get(i)
                if instanceof(object, "IsoWaveSignal") and PW.isOwnPost(object) then return object end
            end
        end
    end
    return nil
end

local function addClientSteps(player, waitMs)
    local MD = MilitaryDrop
    local S = {}
    addStep("Fulton modules loaded under their production names", function()
        local debugMenu = MD.FultonRenderDebug ~= nil
        local debugMode = isDebugEnabled() == true
        local server = isClient() or MD.FultonFlightServer ~= nil
        rec(MD.FultonFlight ~= nil and MD.FultonRender ~= nil and MD.FultonRender.startAt ~= nil and server
            and MD.FultonPrototype == nil and debugMenu == debugMode,
            "Fulton modules loaded under their production names",
            "debug=" .. tostring(debugMode) .. " testMenu=" .. tostring(debugMenu))
        return true
    end)
    addStep("client received Result accepted", function()
        local args = received("Result", function(a) return tonumber(a.requestId) == REQUEST_ID end)
        if not args then return false end
        rec(args.status == "accepted", "client received Result accepted", "status=" .. tostring(args.status))
        return true
    end, waitMs)
    addStep("client received PostResult installed", function()
        local args = received("PostResult", function(a) return a.status == "installed" or a.status == "already" end)
        if not args then return false end
        rec(true, "client received PostResult installed", "status=" .. tostring(args.status))
        return true
    end, waitMs)
    addStep("client sees the crate vehicle", function()
        local vehicle = crateNear(math.floor(player:getX()), math.floor(player:getY()), 30)
        if not vehicle then return false end
        rec(true, "client sees the crate vehicle", tostring(vehicle:getScriptName()) .. " at "
            .. math.floor(vehicle:getX()) .. "," .. math.floor(vehicle:getY()))
        return true
    end, waitMs)
    addStep("liaison post console opens and draws", function()
        local PW = MD.PostWindow
        local playerNum = player:getPlayerNum()
        if not S.postAsked then
            local object = ownPostNear(player)
            if not object then return false end
            S.postAsked = true
            PW.requestOpen(player, object)
            return false
        end
        local window = PW.instances[playerNum]
        if not window or not window:getIsVisible() or not window.data then return false end
        S.postFrames = (S.postFrames or 0) + 1
        if S.postFrames < 30 then return false end
        if SHOTS and not shotAfter(S, "postShot", 1, "md_liaison_post.png") then return false end
        local affairs = window.affairList and #window.affairList or -1
        window:close("autotest")
        rec(PW.instances[playerNum] == nil, "liaison post console opens and draws",
            "size=" .. math.floor(window.width) .. "x" .. math.floor(window.height) .. " affairs=" .. tostring(affairs))
        return true
    end, 30000)
    -- Solo: the server's real offer (Requisition.offer, same fields as the "form" reply of Requisition.openForm):
    -- the character's own tier, then an admin sheet (all tiers). mp client: a synthetic admin sheet (the offer
    -- is built on the server). Sheets are closed without transmitting or cancelling a real request.
    local function sheetArgs(forced)
        local Req, Trust = MD.Requisition, MD.Trust
        if not (Req and Req.offer and Trust) then
            return { requestId = 0, callsign = "Autotest", tier = 2, budget = 10, forced = true, expiresMs = 120000,
                lots = { { id = "autotest", group = 1, cost = 2, allowed = true, label = "Autotest lot" } },
                decoy = { cost = 3, allowed = true, sectors = { "N", "E", "S", "W" } } }, "synthetic"
        end
        local cid = Trust.idFor(player)
        local offer = Req.offer(cid, forced, player)
        local teamId = MD.Teams.idFor(player)
        local allowed = 0
        for _, lot in ipairs(offer.lots) do
            if lot.allowed then allowed = allowed + 1 end
        end
        return { requestId = 0, status = "form", forced = forced or nil, callsign = MD.Teams.callsign(teamId),
            tier = Trust.tier(cid), budget = offer.budget, expiresMs = 120000, lots = offer.lots,
            decoy = offer.decoy, drop = offer.drop },
            "real offer: " .. #offer.lots .. " lots, " .. allowed .. " allowed, budget " .. tostring(offer.budget)
            .. ", tier " .. tostring(Trust.tier(cid)) .. (forced and " (admin)" or "")
    end

    local function addSheetStep(name, forced, shot)
        addStep(name, function()
            local RW = MD.RequisitionWindow
            local playerNum = player:getPlayerNum()
            local key = forced and "admin" or "own"
            if not S[key] then
                local args, detail = sheetArgs(forced)
                S[key .. "Detail"] = detail
                -- A normal sheet closes itself without the calling radio (RW:deviceValid): the radio in hand.
                local radio = not forced and (player:getPrimaryHandItem() or player:getSecondaryHandItem()) or nil
                S[key] = RW.open(player, radio, args)
                return false
            end
            local sheet = S[key]
            S[key .. "Frames"] = (S[key .. "Frames"] or 0) + 1
            if S[key .. "Frames"] < 30 then return false end
            if SHOTS and not shotAfter(S, key .. "Shot", 1, shot) then return false end
            local visible = sheet:getIsVisible() and RW.instances[playerNum] == sheet
            local w, h = sheet.width, sheet.height
            sheet.done = true
            sheet:close()
            rec(visible and RW.instances[playerNum] == nil, name,
                "size=" .. math.floor(w) .. "x" .. math.floor(h) .. " " .. tostring(S[key .. "Detail"]))
            return true
        end, 30000)
    end

    if not isClient() then
        addSheetStep("requisition sheet opens and draws (own tier)", false, "md_requisition_sheet_own_tier.png")
    end
    addSheetStep("requisition sheet opens and draws", true, "md_requisition_sheet.png")
end

-- ------------------------------------------------------------------ authority path

local function addAuthoritySteps(player, deliveryMs, crateWaitMs, leadMs, other)
    local MD = MilitaryDrop
    local Server, Trust, Config = MD.Server, MD.Trust, MD.Config
    local S = {}

    -- mp server: the client hooks start a few seconds after the server's (control file read later); the
    -- "Result" reply of launchDrop is only sent once, so the client observer must be installed before it.
    if leadMs > 0 then
        addStep("wait for the client hooks", function()
            S.leadSince = S.leadSince or nowMs()
            if nowMs() - S.leadSince < leadMs then return false end
            info("server waited " .. math.floor(leadMs / 1000) .. " s for the client hooks")
            return true
        end, leadMs + 5000)
    end

    addStep("setup", function()
        -- The nominal delivery scenario must not turn into a random Mayday.
        -- These options belong only to the copied test world.
        for _, name in ipairs({ "CrashChance", "CrashStormBonus" }) do
            getSandboxOptions():getOptionByName("MilitaryDrop." .. name):setValue(0)
            SandboxVars.MilitaryDrop[name] = 0
        end
        info("nominal fixture disables random flight crashes in the copied test world")
        S.channel = Config.getChannel()
        S.cid = Trust.idFor(player)
        S.teamId = MD.Teams.idFor(player)
        -- Copied world only: a cooldown left in the copied save would hide the nominal answer.
        Server.getState().lastDropHours = nil
        S.radio = giveMilitaryRadio(player, S.channel)
        rec(S.radio ~= nil and MD.Radio.isMilitary(S.radio), "military radio in hand",
            "channel=" .. tostring(S.channel) .. " codeMode=" .. tostring(Config.codeMode()))
        S.ref = S.radio and MD.Radio.makeRef(S.radio)
        S.codes = Server.acceptedCodes(Server.clock())
        return true
    end)

    addStep("server refuses a wrong code", function()
        if Config.codeMode() == MD.Codes.MODE_NONE then
            info("AuthCode = none: wrong code check skipped")
            return true
        end
        local status = Server.evaluate(player, { radio = S.ref, code = WRONG_CODE }, getGameTime():getWorldAgeHours())
        rec(status == "noAnswer", "server refuses a wrong code", "status=" .. tostring(status))
        return true
    end)

    addStep("server accepts the right code", function()
        local status, extra = Server.evaluate(player, { radio = S.ref, code = S.codes[1] },
            getGameTime():getWorldAgeHours())
        rec(status == "accepted", "server accepts the right code", "status=" .. tostring(status)
            .. (extra and type(extra) == "number" and (" hours=" .. extra) or ""))
        return true
    end)

    addStep("drop launched near the player", function()
        local square = Server.findLandingNear(math.floor(player:getX()) + 8, math.floor(player:getY()), nil)
        if not square then
            rec(false, "drop launched near the player", "no landing square near the player")
            return true
        end
        S.point = { x = square:getX(), y = square:getY() }
        S.dropId = Server.launchDrop(player, REQUEST_ID, false, { point = { x = square:getX(), y = square:getY() } })
        rec(type(S.dropId) == "string", "drop launched near the player", "dropId=" .. tostring(S.dropId)
            .. " point=" .. square:getX() .. "," .. square:getY())
        return true
    end)

    addStep("server applies the cooldown", function()
        local status, hours = Server.evaluate(player, { radio = S.ref, code = S.codes[1] },
            getGameTime():getWorldAgeHours())
        rec(status == "cooldown" and (tonumber(hours) or 0) > 0, "server applies the cooldown",
            "status=" .. tostring(status) .. " hours=" .. tostring(hours))
        return true
    end)

    addStep("crate delivered by the helicopter", function()
        local drop = S.dropId and Trust.drop(S.dropId)
        if not drop then
            rec(false, "crate delivered by the helicopter", "no drop record")
            return true
        end
        if not drop.deliveredHours then return false end
        local placed = drop.placed or {}
        S.placed = placed
        rec(type(placed.x) == "number" and (tonumber(placed.cases) or 0) > 0, "crate delivered by the helicopter",
            "at " .. tostring(placed.x) .. "," .. tostring(placed.y) .. " cases=" .. tostring(placed.cases))
        return true
    end, deliveryMs)

    -- Polled (crateWaitMs): the vehicle is only found by the squares after its first update (crateNear).
    -- Ground fallback of Server.deliver (no free place for the crate, intended): marked cases on the ground pass.
    addStep("crate vehicle and marked contents", function()
        if not S.placed or type(S.placed.x) ~= "number" then
            rec(false, "crate vehicle and marked contents", "no delivery point")
            return true
        end
        local px, py = S.placed.x, S.placed.y
        local vehicle = crateNear(px, py, 2)
        local ground, groundTypes = markedGround(px, py, 2, S.dropId, Trust.ITEM_KEY)
        local waited = nowMs() - (S.crateSince or nowMs())
        S.crateSince = S.crateSince or nowMs()
        if not vehicle and #ground == 0 and waited < crateWaitMs then
            return false
        end
        local _, wide = crateNear(px, py, 10)
        info("crate search: point " .. tostring(S.point and S.point.x) .. "," .. tostring(S.point and S.point.y)
            .. ", landed " .. px .. "," .. py .. ", after " .. math.floor(waited / 1000) .. " s, crate vehicles"
            .. " within 10: " .. describeVehicles(wide) .. ", marked items on the ground within 2: " .. #ground
            .. (#ground > 0 and (" (" .. table.concat(groundTypes, " ") .. ")") or ""))
        if vehicle then
            S.vehicle = vehicle
            local marked, types = markedItems(vehicle, S.dropId, Trust.ITEM_KEY)
            S.case = marked[1]
            rec(#marked > 0, "crate vehicle and marked contents", tostring(vehicle:getScriptName()) .. ": "
                .. #marked .. " marked of " .. #types .. " (" .. table.concat(types, " ") .. ")")
        elseif #ground > 0 then
            S.case = ground[1]
            rec(true, "crate vehicle and marked contents", "ground fallback: " .. #ground .. " marked case(s) on the"
                .. " ground (" .. table.concat(groundTypes, " ") .. ")")
        else
            rec(false, "crate vehicle and marked contents", "neither crate vehicle nor marked ground case near "
                .. px .. "," .. py .. " after " .. math.floor(waited / 1000) .. " s")
        end
        return true
    end, crateWaitMs + 5000)

    if other then
        addStep("trust: supply case opened by another player", function()
            if not S.case then
                rec(false, "trust: supply case opened by another player", "no marked case")
                return true
            end
            local before = Trust.get(S.cid)
            Trust.onCaseOpened(S.case, other)
            local drop = Trust.drop(S.dropId)
            local after = Trust.get(S.cid)
            rec(drop and drop.outcome == "taken" and drop.openedBy == tostring(other:getUsername())
                and after == math.max(Trust.MIN, before + Trust.DROP_TAKEN),
                "trust: supply case opened by another player", "opener=" .. tostring(other:getUsername())
                .. " outcome=" .. tostring(drop and drop.outcome) .. " caller trust " .. tostring(before) .. " -> "
                .. tostring(after))
            return true
        end)
    end

    addStep("trust: first supply case opened by the caller", function()
        if other then return true end
        if not S.case then
            rec(false, "trust: first supply case opened by the caller", "no marked case")
            return true
        end
        local before = Trust.get(S.cid)
        Trust.onCaseOpened(S.case, player)
        local drop = Trust.drop(S.dropId)
        local after = Trust.get(S.cid)
        rec(drop and drop.outcome == "recovered" and after >= before, "trust: first supply case opened by the caller",
            "outcome=" .. tostring(drop and drop.outcome) .. " trust " .. tostring(before) .. " -> " .. tostring(after))
        return true
    end)

    addStep("admin mission (control) open and listed", function()
        local Missions = MD.Missions
        local status = Missions.adminLaunch(player, { kind = "control" })
        local listed = false
        for _, entry in ipairs(Missions.listForCharacter(S.cid)) do
            if entry.kind == "control" then listed = true end
        end
        rec((status == "launched" or status == "open") and listed, "admin mission (control) open and listed",
            "status=" .. tostring(status) .. " listed=" .. tostring(listed))
        return true
    end)

    addStep("liaison post installed", function()
        local square = player:getCurrentSquare()
        local object = square and IsoRadio.new(getCell(), square, getSprite("appliances_com_01_8"))
        if not object then
            rec(false, "liaison post installed", "no square or radio object")
            return true
        end
        square:AddSpecialObject(object)
        if isServer() then object:transmitCompleteItemToClients() end
        local eligible = MD.Post.isEligible(object)
        MD.Post.install(player, { radio = MD.Radio.makeRef(object) })
        local owner = MD.Post.ownerOf(object)
        rec(eligible and owner ~= nil and owner == S.teamId, "liaison post installed",
            "eligible=" .. tostring(eligible) .. " owner=" .. tostring(owner) .. " team=" .. tostring(S.teamId))
        return true
    end)

    addStep("Fulton refused without a kit", function()
        local FultonServer = MD.FultonServer
        if not FultonServer or not FultonServer.launch then
            rec(false, "Fulton refused without a kit", "MilitaryDrop.FultonServer missing")
            return true
        end
        local result = FultonServer.launch(player, {})
        rec(result == nil or result ~= "ok", "Fulton refused without a kit", "result=" .. tostring(result))
        info("full Fulton launch (kit, helium tank, window): -P scenario=fulton")
        return true
    end)
end

-- ------------------------------------------------------------------ scenario "marks" (solo)

-- -P scenario=marks: map markers of the missions and outdated markers (QUAL-09, QUAL-10), real radio path.
--   1. radio off, recon R1 launched: no Eye symbol once the announcement has aired;
--   2. radio on, "Confirm the recon" through Exchange.send (timed action, server reply): Eye symbol at R1;
--   3. R1 closed by the admin entry point: its Eye symbol removed (MarksActive);
--   4. radio off, recon R2 launched and aired, no symbol; radio on, reminder forced (openedHours moved back by
--      DropRepeatHours): Eye symbol at R2 heard through OnDeviceText;
--   5. drops: announced drop D1 (Trust record of the copied save) with its Target, stray Target elsewhere;
--      Missions.sendMarks(player): stray removed, D1 kept; D1 emptied (markCollected) + Missions.update(): removed;
--   6. R2 closed: Eye removed;
--   7. clearance C1 launched, radio on: Skull and radius Circle (scale 2 * radius / (20 * 50 / 64)) once aired;
--      a player's own Circle (vanilla red pen color) at the same place; C1 closed: Skull and mod Circle removed,
--      the player's Circle kept (C09).
local function symbolsApi()
    local ui = {}
    ui.javaObject = UIWorldMap.new(ui)
    local api = ui.javaObject:getAPIv3()
    api:setMapItem(MapItem.getSingleton())
    return api:getSymbolsAPIv2()
end

local function countSymbols(id, x, y)
    local api, n = symbolsApi(), 0
    for i = 0, api:getSymbolCount() - 1 do
        local symbol = api:getSymbolByIndex(i)
        if symbol:isTexture() and symbol:getSymbolID() == id and math.floor(symbol:getWorldX()) == x
            and math.floor(symbol:getWorldY()) == y then
            n = n + 1
        end
    end
    return n
end

--- Scale of the first mod-colored Circle at x, y (the clearance radius), or nil.
local function circleScale(x, y)
    local api, c = symbolsApi(), MilitaryDrop.Announce.CLEANUP_CIRCLE_COLOR
    for i = 0, api:getSymbolCount() - 1 do
        local symbol = api:getSymbolByIndex(i)
        if symbol:isTexture() and symbol:getSymbolID() == "Circle" and math.floor(symbol:getWorldX()) == x
            and math.floor(symbol:getWorldY()) == y and math.abs(symbol:getRed() - c.r) < 0.01 then
            return symbol:getScale()
        end
    end
    return nil
end

--- Player's own circle (vanilla red pen color, ISWorldMapSymbols.lua) at x, y.
local function addPlayerCircle(x, y)
    local symbol = symbolsApi():addTexture("Circle", x, y)
    symbol:setRGBA(0.65, 0.054, 0.054, 1)
    symbol:setAnchor(0.5, 0.5)
end

local function removePlayerCircle(x, y)
    local api = symbolsApi()
    for i = api:getSymbolCount() - 1, 0, -1 do
        local symbol = api:getSymbolByIndex(i)
        if symbol:isTexture() and symbol:getSymbolID() == "Circle" and math.floor(symbol:getWorldX()) == x
            and math.floor(symbol:getWorldY()) == y and math.abs(symbol:getRed() - 0.65) < 0.01 then
            api:removeSymbolByIndex(i)
            return true
        end
    end
    return false
end

local function expectedCircleScale(radius)
    return 2 * radius / (20 * 50 / 64)
end

local function airingDone()
    local channel = MilitaryDrop.Broadcast.channel
    return channel == nil or channel:getAiringBroadcast() == nil
end

local function addMarksSteps(player, airMs)
    local MD = MilitaryDrop
    local Missions, Trust, Announce = MD.Missions, MD.Trust, MD.Announce
    local S = {}

    local function setOn(on)
        S.radio:getDeviceData():setTurnedOnRaw(on)
    end

    local function closeRecon()
        if Missions.openMission("recon") then
            Missions.adminLaunch(player, { kind = "recon", action = "close" })
        end
    end

    addStep("marks: setup", function()
        S.radio = giveMilitaryRadio(player, MD.Config.getChannel())
        S.every = math.floor(tonumber(MD.Config.get("DropRepeatHours")) or 0)
        rec(S.radio ~= nil and S.every > 0, "marks: setup", "DropRepeatHours=" .. tostring(S.every))
        closeRecon()
        return true
    end)

    addStep("marks: wait for the channel", function() return airingDone() end, airMs)

    addStep("marks: unheard recon gives no symbol", function()
        if not S.r1 then
            setOn(false)
            S.r1 = Missions.launch("recon")
            if not S.r1 then
                rec(false, "marks: unheard recon gives no symbol", "launch failed")
                return true
            end
            info("R1 " .. S.r1.id .. " at " .. S.r1.x .. "," .. S.r1.y)
            return false
        end
        if not airingDone() then return false end
        local n = countSymbols("Eye", S.r1.x, S.r1.y)
        rec(n == 0, "marks: unheard recon gives no symbol", "eye=" .. n)
        return true
    end, airMs)

    addStep("marks: base reply (too far) marks the recon", function()
        if not S.r1 then return true end
        if not S.sent then
            setOn(true)
            -- Solo: Exchange.toPlayer calls the client handler directly (not seen by the observer).
            S.sent = MD.Exchange.send(player, S.radio, MD.Exchange.COMMANDS.recon, {}, nil,
                { onReply = function(args) S.reply = args end })
            if not S.sent then
                rec(false, "marks: base reply (too far) marks the recon", "exchange not started")
                return true
            end
            return false
        end
        local reply = S.reply
        if not reply then return false end
        local n = countSymbols("Eye", S.r1.x, S.r1.y)
        if n == 0 then return false end
        rec(reply.status == "tooFar" and n == 1, "marks: base reply (too far) marks the recon",
            "status=" .. tostring(reply.status) .. " eye=" .. n)
        return true
    end, 60000)

    addStep("marks: closed recon symbol removed", function()
        if not S.r1 then return true end
        if not S.closed1 then
            S.closed1 = true
            closeRecon()
        end
        if countSymbols("Eye", S.r1.x, S.r1.y) > 0 then return false end
        rec(true, "marks: closed recon symbol removed", "R1 " .. S.r1.id)
        return true
    end, 10000)

    addStep("marks: wait for the channel (2)", function() return airingDone() end, airMs)

    addStep("marks: reminder heard marks the recon", function()
        if not S.r2 then
            setOn(false)
            S.r2 = Missions.launch("recon")
            if not S.r2 then
                rec(false, "marks: reminder heard marks the recon", "launch failed")
                return true
            end
            info("R2 " .. S.r2.id .. " at " .. S.r2.x .. "," .. S.r2.y)
            return false
        end
        if not S.reminded then
            if not airingDone() then return false end
            if countSymbols("Eye", S.r2.x, S.r2.y) ~= 0 then
                rec(false, "marks: reminder heard marks the recon", "marked before the reminder")
                return true
            end
            setOn(true)
            S.r2.openedHours = S.r2.openedHours - S.every - 0.1
            S.reminded = Missions.remind()
            info("reminders aired: " .. tostring(S.reminded))
            return false
        end
        local n = countSymbols("Eye", S.r2.x, S.r2.y)
        if n == 0 then return false end
        rec(S.reminded == 1, "marks: reminder heard marks the recon", "eye=" .. n)
        return true
    end, airMs * 2)

    addStep("marks: drop announcement heard", function()
        if not S.d1 then
            if not airingDone() then return false end
            local px, py = math.floor(player:getX()), math.floor(player:getY())
            S.d1 = Trust.registerDrop(Trust.idFor(player), "autotest", true, {})
            S.d1x, S.d1y, S.strayX, S.strayY = px + 40, py, px + 60, py
            -- What the flight does at the drop (MilitaryDrop_Flights.lua, drop()).
            Trust.onDropAnnounced(S.d1, S.d1x, S.d1y)
            MD.Broadcast.dropped(S.d1x, S.d1y)
            return false
        end
        if countSymbols("Target", S.d1x, S.d1y) == 0 then return false end
        rec(true, "marks: drop announcement heard", "D1 " .. S.d1 .. " at " .. S.d1x .. "," .. S.d1y)
        return true
    end, airMs)

    addStep("marks: outdated drop markers removed, active kept", function()
        if not S.d1x then return true end
        Announce.markMap(S.strayX, S.strayY)
        Missions.sendMarks(player)
        local px, py = S.strayX - 60, S.strayY
        local active, stray = countSymbols("Target", S.d1x, S.d1y), countSymbols("Target", px + 60, py)
        rec(active == 1 and stray == 0, "marks: outdated drop markers removed, active kept",
            "active=" .. active .. " stray=" .. stray)
        return true
    end)

    addStep("marks: emptied drop marker removed", function()
        Trust.markCollected(S.d1)
        Missions.update()
        local n = countSymbols("Target", S.d1x, S.d1y)
        rec(n == 0, "marks: emptied drop marker removed", "target=" .. n)
        return true
    end)

    addStep("marks: second recon closed, symbol removed", function()
        if not S.r2 then return true end
        closeRecon()
        local n = countSymbols("Eye", S.r2.x, S.r2.y)
        rec(n == 0, "marks: second recon closed, symbol removed", "eye=" .. n)
        return true
    end)

    addStep("marks: clearance heard: skull and radius circle", function()
        if not S.c1 then
            if not airingDone() then return false end
            if Missions.openMission("cleanup") then
                if Missions.adminLaunch(player, { kind = "cleanup", action = "close" }) == "busy" then return false end
            end
            setOn(true)
            S.c1 = Missions.launch("cleanup")
            if not S.c1 then
                rec(false, "marks: clearance heard: skull and radius circle", "launch failed")
                return true
            end
            info("C1 " .. S.c1.id .. " at " .. S.c1.x .. "," .. S.c1.y .. " radius " .. tostring(S.c1.radius))
            return false
        end
        local skull, scale = countSymbols("Skull", S.c1.x, S.c1.y), circleScale(S.c1.x, S.c1.y)
        if skull == 0 or not scale then return false end
        local expected = expectedCircleScale(S.c1.radius)
        rec(skull == 1 and countSymbols("Circle", S.c1.x, S.c1.y) == 1 and math.abs(scale - expected) < 0.01,
            "marks: clearance heard: skull and radius circle",
            "skull=" .. skull .. " scale=" .. tostring(scale) .. " expected=" .. tostring(expected))
        return true
    end, airMs)

    addStep("marks: world map screenshots of the clearance zone", function()
        if not SHOTS or not S.c1 then return true end
        local playerNum = player:getPlayerNum()
        if not S.mapOpen then
            S.mapOpen = true
            ISWorldMap.ShowWorldMap(playerNum, S.c1.x, S.c1.y, 15)
            return false
        end
        local map = ISWorldMap_instance
        if not map then
            rec(false, "marks: world map screenshots of the clearance zone", "world map not opened")
            return true
        end
        if not S.zoom1 then
            map.mapAPI:centerOn(S.c1.x, S.c1.y)
            map.mapAPI:setZoom(15)
            if not shotAfter(S, "mapShot1", 20, "md_clearance_circle_zoom15.png") then return false end
            S.zoom1 = true
            return false
        end
        if not S.zoom2 then
            map.mapAPI:centerOn(S.c1.x, S.c1.y)
            map.mapAPI:setZoom(17)
            if not shotAfter(S, "mapShot2", 20, "md_clearance_circle_zoom17.png") then return false end
            S.zoom2 = true
            return false
        end
        ISWorldMap.HideWorldMap(playerNum)
        setGameSpeed(1)
        rec(true, "marks: world map screenshots of the clearance zone", "zoom 15 and 17")
        return true
    end, 30000)

    addStep("marks: player's own circle added", function()
        if S.c1 then addPlayerCircle(S.c1.x, S.c1.y) end
        return true
    end)

    addStep("marks: closed clearance removes skull and circle, keeps the player's circle", function()
        if not S.c1 then return true end
        if not S.c1closed then
            local status = Missions.adminLaunch(player, { kind = "cleanup", action = "close" })
            if status == "busy" then return false end
            S.c1closed = true
        end
        local skull, circles = countSymbols("Skull", S.c1.x, S.c1.y), countSymbols("Circle", S.c1.x, S.c1.y)
        if skull > 0 or circleScale(S.c1.x, S.c1.y) then return false end
        rec(circles == 1 and removePlayerCircle(S.c1.x, S.c1.y),
            "marks: closed clearance removes skull and circle, keeps the player's circle",
            "skull=" .. skull .. " circles left=" .. circles)
        return true
    end, 15000)
end

-- ------------------------------------------------------------------ scenario "fulton" (authority helpers, solo)

-- -P scenario=fulton: real Fulton launch (FULTON-06/07), through the mod's player path:
--   1. military radio in hand, "request a Fulton pass" through Exchange.send (timed action, Missions.requestFulton):
--      reply ok (or pending), window kept by FultonClient.window and Missions.fultonWindow;
--   2. kit (Fulton.KIT_TYPE) filled with paid items (papers, identity card of someone else, gas mask, filter,
--      stash map) and one unpaid item, laid on an outside square near the player (Fulton.siteReason, free square),
--      helium tank in the main inventory; menu reason nil (option enabled);
--   3. FultonMenu.queueLaunch: walk to the kit, FultonLaunchAction, FultonLaunch -> FultonServer.launch;
--   4. FultonResult ok, kit gone from the ground, one helium use spent, trust raised by
--      min(Fulton.evaluate().capped, Trust.dailyLeft) + uncapped, window closed, Broadcast.fulton called once,
--      visible flight started (solo: FultonRender anchored flight; mp: Snapshot with a real flight).
-- No valid square because of the weather (storm, wind): FAIL "site: <reason>" (never hidden).
-- Screenshots (-P shots=1): kit on the ground, then the balloon rise and the pickup at FULTON_SHOTS seconds.
local FULTON_SHOTS = { 0.4, 1.5, 2.8, 3.5, 4.0, 4.4 }
local FULTON_STRANGER = "Autotest Stranger"

--- Outside square near the player for the kit: Fulton.siteReason nil, free, no water; Chebyshev distance 2 to
--- radius first (the character walks to it), then 1. Returns the square, or nil and the refusal seen.
local function fultonSite(player, radius)
    local Fulton = MilitaryDrop.Fulton
    local cell = getCell()
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local best, bestD, seen = nil, nil, nil
    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(px + dx, py + dy, pz)
            local d = math.max(math.abs(dx), math.abs(dy))
            if square and d > 0 and square:isFree(false) and not square:isWaterSquare() then
                local reason = Fulton.siteReason(square)
                if reason then
                    if reason ~= "IGUI_MilitaryDrop_Fulton_NotOutside" or not seen then seen = reason end
                else
                    local rank = d >= 2 and d or radius + 1
                    if not bestD or rank < bestD then best, bestD = square, rank end
                end
            end
        end
    end
    return best, seen
end

--- Kit filled with paid items and one unpaid item, laid on square (transmitted in mp).
local function fultonPlaceKit(square)
    local Fulton = MilitaryDrop.Fulton
    local kit = instanceItem(Fulton.KIT_TYPE)
    local container = kit:getItemContainer()
    local card = instanceItem("Base.IDcard")
    card:setName(FULTON_STRANGER)
    card:setCustomName(true)
    local map = instanceItem("Base.MuldraughMap")
    map:setStashMap("MulStashMap1")
    for _, item in ipairs({ instanceItem("Base.Paperwork"), card, instanceItem("Base.Hat_GasMask"),
        instanceItem("Base.GasmaskFilter"), map, instanceItem("Base.Pencil") }) do
        container:AddItem(item)
    end
    square:AddWorldInventoryItem(kit, 0.5, 0.5, 0, true)
    return kit
end

local function fultonGiveTank(player)
    local inv = player:getInventory()
    local tank = inv:AddItem(MilitaryDrop.Fulton.TANK_TYPE)
    if tank and isServer() then sendAddItemToContainer(inv, tank) end
    return tank
end

local function countsText(counts)
    local parts = {}
    for category, n in pairs(counts) do parts[#parts + 1] = category .. "=" .. n end
    table.sort(parts)
    return table.concat(parts, ",")
end

-- Broadcast.fulton recorded on the authority (called by FultonServer.onLaunched through the field).
local FultonCalls = {}

local function wrapFultonBroadcast()
    local B = MilitaryDrop.Broadcast
    if FultonCalls.original or not B or not B.fulton then return end
    local original = B.fulton
    FultonCalls.original, FultonCalls.list = original, {}
    B.fulton = function(x, y)
        local sx, sy = original(x, y)
        FultonCalls.list[#FultonCalls.list + 1] = { x = x, y = y, sx = sx, sy = sy }
        return sx, sy
    end
end

local function unwrapFultonBroadcast()
    if FultonCalls.original then MilitaryDrop.Broadcast.fulton = FultonCalls.original end
    FultonCalls = {}
end

--- Authority preparation: site, kit, tank, expected payment. Returns state, or nil and the failure text.
local function fultonPrepare(player)
    local MD = MilitaryDrop
    local Fulton, Trust = MD.Fulton, MD.Trust
    local square, seen = fultonSite(player, 8)
    if not square then
        return nil, "site: " .. tostring(seen or "no free outside square within 8")
    end
    wrapFultonBroadcast()
    local kit = fultonPlaceKit(square)
    local tank = fultonGiveTank(player)
    local cid = Trust.idFor(player)
    local items = Fulton.kitItems(kit)
    local evaluation = Fulton.evaluate(items, player)
    local left = Trust.dailyLeft(cid)
    local F = { cid = cid, kit = kit, tank = tank, square = square, x = square:getX(), y = square:getY(),
        z = square:getZ(), kitId = kit:getID(), tankId = tank and tank:getID(), uses = tank and tank:getCurrentUses(),
        items = #items, evaluation = evaluation, left = left, trust = Trust.get(cid),
        expected = math.min(evaluation.capped, left) + evaluation.uncapped }
    return F
end

--- Kit with kitId still on the ground of square.
local function kitOnSquare(square, kitId)
    local objects = square and square:getWorldObjects()
    for i = 0, (objects and objects:size() or 0) - 1 do
        local item = objects:get(i):getItem()
        if item and item:getID() == kitId then return item end
    end
    return nil
end

--- Authority checks after the launch: { name = { ok, detail } } in a fixed order.
local function fultonVerify(player, F)
    local MD = MilitaryDrop
    local Trust, Missions = MD.Trust, MD.Missions
    local out = {}
    local gone = kitOnSquare(F.square, F.kitId) == nil
    out[#out + 1] = { "fulton: kit removed from the ground", gone, F.x .. "," .. F.y .. "," .. F.z }
    local uses = F.tank and F.tank:getCurrentUses()
    out[#out + 1] = { "fulton: one helium use spent", uses == (F.uses or 0) - 1,
        "uses " .. tostring(F.uses) .. " -> " .. tostring(uses) }
    local after = Trust.get(F.cid)
    out[#out + 1] = { "fulton: trust raised by the scale", after - F.trust == F.expected,
        "trust " .. tostring(F.trust) .. " -> " .. tostring(after) .. " expected +" .. F.expected .. " (capped "
        .. F.evaluation.capped .. ", dailyLeft " .. F.left .. ", paid " .. F.evaluation.paid .. ", unpaid "
        .. F.evaluation.unpaid .. ")" }
    out[#out + 1] = { "fulton: window closed", Missions.fultonWindow(F.cid) == nil, nil }
    local calls = FultonCalls.list or {}
    local call = calls[1]
    out[#out + 1] = { "fulton: sector announced (Broadcast.fulton)", #calls == 1 and call.x == F.x and call.y == F.y,
        "calls=" .. #calls .. (call and (" sector " .. tostring(call.sx) .. "," .. tostring(call.sy)) or "") }
    return out
end

local function fultonExpectedOk(F)
    local paid = F.evaluation.paid
    return F.items == 6 and paid == 5 and F.evaluation.unpaid == 1, "items=" .. F.items .. " paid=" .. paid
        .. " (" .. countsText(F.evaluation.counts) .. ") capped=" .. F.evaluation.capped .. " dailyLeft=" .. F.left
end

--- Screenshots of the flight: every window hidden (ISUIHandler.setVisibleAllUI(false) leaves the radio windows,
--- hidden one by one) and the camera zoomed out up to five steps (doZoomScroll +1 = next larger zoom value, MultiTextureFBO2:
--- zoom levels sorted from the widest) so that the balloon stays on screen. Restored after the flight.
local function hideUiForShots(S, player)
    if S.uiHidden then return end
    S.uiHidden = true
    S.zoomBefore = getCore():getZoom(player:getPlayerNum())
    ISUIHandler.setVisibleAllUI(false)
    for _, list in ipairs({ ISRadioWindow and ISRadioWindow.instances, ISRadioWindow and ISRadioWindow.instancesIso }) do
        for _, window in pairs(list or {}) do
            if window and window.setVisible then window:setVisible(false) end
        end
    end
    for _ = 1, 5 do getCore():doZoomScroll(player:getPlayerNum(), 1) end
end

local function restoreUiAfterShots(S, player)
    if not S.uiHidden then return end
    S.uiHidden = false
    ISUIHandler.setVisibleAllUI(true)
    info("camera zoom " .. tostring(S.zoomBefore) .. " -> " .. tostring(getCore():getZoom(player:getPlayerNum()))
        .. " for the screenshots")
end

--- Shared client steps: request the window by radio, then launch the kit through the menu path; screenshots.
--- getKit() returns the kit item seen by this client (nil while not there yet).
local function addFultonLaunchSteps(player, S, prefix)
    local MD = MilitaryDrop
    local FultonMenu, FultonClient = MD.FultonMenu, MD.FultonClient

    addStep(prefix .. "kit ready, menu option enabled", function()
        if not S.items then return true end
        local kit = S.getKit()
        if not kit or #MD.Fulton.kitItems(kit) < S.items or not MD.Fulton.findTank(player:getInventory(), true) then
            return false
        end
        S.kit = kit
        if SHOTS then
            hideUiForShots(S, player)
            if not shotAfter(S, "kitShot", 60, "md_fulton_kit_ground.png") then return false end
        end
        local reason = FultonMenu.reason(player, kit)
        local text = FultonMenu.confirmText(player, kit)
        rec(reason == nil and type(text) == "string" and text ~= "", prefix .. "kit ready, menu option enabled",
            "reason=" .. tostring(reason) .. " kitItems=" .. #MD.Fulton.kitItems(kit))
        return true
    end, 30000)

    addStep(prefix .. "launch queued (walk, inflate, FultonLaunch)", function()
        if not S.kit then return true end
        if ISTimedActionQueue.isPlayerDoingAction(player) then return false end
        S.queued = FultonMenu.queueLaunch(player, S.kit)
        rec(S.queued == true, prefix .. "launch queued (walk, inflate, FultonLaunch)",
            "kit at " .. tostring(S.x) .. "," .. tostring(S.y))
        return true
    end, 30000)

    addStep(prefix .. "FultonResult ok", function()
        if not S.queued then return true end
        local args = received("FultonResult")
        if not args then return false end
        S.result = args
        S.t0 = nowMs()
        local lines = type(args.lines) == "table" and #args.lines or 0
        rec(args.status == "ok" and lines > 0, prefix .. "FultonResult ok", "status=" .. tostring(args.status)
            .. " reason=" .. tostring(args.reason) .. " lines=" .. lines)
        return true
    end, 90000)

    addStep(prefix .. "visible flight started", function()
        if not S.result or S.result.status ~= "ok" then return true end
        local Render = MD.FultonRender
        local snapshot = received("FlightSnapshot", function(a)
            for _, row in ipairs(type(a.flights) == "table" and a.flights or {}) do
                if row.real and math.abs((tonumber(row.x) or 0) - (S.x + 0.5)) < 0.01
                    and math.abs((tonumber(row.y) or 0) - (S.y + 0.5)) < 0.01 then return true end
            end
            return false
        end)
        local count = Render and Render.count() or 0
        if isClient() and not snapshot then return false end
        if count == 0 then return false end
        rec(true, prefix .. "visible flight started", "rendered flights=" .. count
            .. (isClient() and " (Snapshot with a real flight received)" or " (solo anchored flight)"))
        return true
    end, 10000)

    addStep(prefix .. "flight screenshots", function()
        if not SHOTS or not S.t0 then return true end
        S.shot = S.shot or 1
        local at = FULTON_SHOTS[S.shot]
        if not at then return true end
        if nowMs() - S.t0 >= at * 1000 then
            local name = string.format("md_fulton_flight_%02d_%04dms.png", S.shot, math.floor(at * 1000))
            takeScreenshot(name)
            info("screenshot " .. name .. " (" .. (nowMs() - S.t0) .. " ms after the result)")
            S.shot = S.shot + 1
        end
        return false
    end, 15000)

    addStep(prefix .. "client window cleared, flight over", function()
        if not S.result then return true end
        local count = MD.FultonRender and MD.FultonRender.count() or 0
        if count > 0 then return false end
        restoreUiAfterShots(S, player)
        rec(FultonClient.window(player:getPlayerNum()) == nil, prefix .. "client window cleared, flight over",
            "rendered flights=" .. count)
        return true
    end, 20000)
end

local function addFultonSoloSteps(player)
    local MD = MilitaryDrop
    local S = {}
    addStep("fulton: setup (radio)", function()
        S.radio = giveMilitaryRadio(player, MD.Config.getChannel())
        S.cid = MD.Trust.idFor(player)
        rec(S.radio ~= nil and MD.Fulton.isEnabled(), "fulton: setup (radio)",
            "FultonValue=" .. tostring(MD.Config.get("FultonValue")) .. " lineCut="
            .. tostring(MD.Trust.isLineCut(S.cid)))
        return true
    end)

    addStep("fulton: pass requested by radio", function()
        if not S.sent then
            S.sent = MD.Exchange.send(player, S.radio, MD.Exchange.COMMANDS.fulton, {}, nil,
                { onReply = function(args) S.reply = args end })
            if not S.sent then
                rec(false, "fulton: pass requested by radio", "exchange not started")
                return true
            end
            return false
        end
        if not S.reply then return false end
        local window = MD.FultonClient.window(player:getPlayerNum())
        rec((S.reply.status == "ok" or S.reply.status == "pending") and window ~= nil
            and MD.Missions.fultonWindow(S.cid) ~= nil, "fulton: pass requested by radio",
            "status=" .. tostring(S.reply.status) .. " minutesLeft=" .. tostring(S.reply.fulton and S.reply.fulton.minutesLeft)
            .. " dailyLeft=" .. tostring(S.reply.fulton and S.reply.fulton.dailyLeft))
        return true
    end, 60000)

    addStep("fulton: kit laid outside, tank given", function()
        local F, err = fultonPrepare(player)
        if not F then
            rec(false, "fulton: kit laid outside, tank given", err)
            return true
        end
        S.F, S.x, S.y, S.items = F, F.x, F.y, F.items
        S.getKit = function() return kitOnSquare(F.square, F.kitId) end
        local ok, detail = fultonExpectedOk(F)
        rec(ok and F.tank ~= nil, "fulton: kit laid outside, tank given", "at " .. F.x .. "," .. F.y .. "," .. F.z
            .. " player " .. math.floor(player:getX()) .. "," .. math.floor(player:getY()) .. " " .. detail)
        return true
    end)

    S.getKit = function() return nil end
    addFultonLaunchSteps(player, S, "fulton: ")

    addStep("fulton: authority paid and cleaned up", function()
        if not S.F or not S.result then return true end
        for _, c in ipairs(fultonVerify(player, S.F)) do rec(c[2] == true, c[1], c[3]) end
        return true
    end)
end

-- ------------------------------------------------------------------ scenario "marks" (mp)

-- Same checks as the solo scenario, through the network: the client (client 1, --client-run) drives the sequence
-- and asks the server for each authority action with a test command (module PZATMD); the server answers with the
-- same op. Client checks its own map symbols (announcements heard by its radio, MarksActive, Sync, base reply).
local OPS_MODULE = "PZATMD"
local Ops = { replies = {}, installed = false }

local function onOpReply(module, command, args)
    if module ~= OPS_MODULE then return end
    Ops.replies[command] = type(args) == "table" and args or {}
end

local function request(player, op, args)
    Ops.replies[op] = nil
    sendClientCommand(player, OPS_MODULE, op, args or {})
end

local function replyOf(op)
    return Ops.replies[op]
end

-- Ask once, then poll the reply (false until it arrives).
local function asked(S, key, player, op, args)
    if not S[key] then
        S[key] = true
        request(player, op, args)
        return nil
    end
    return replyOf(op)
end

local function findRadio(player, id)
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getID() == id then return item end
    end
    return nil
end

local function addMarksClientSteps(player, airMs)
    local MD = MilitaryDrop
    local S = {}
    if not Ops.installed then
        Ops.installed = true
        Events.OnServerCommand.Add(onOpReply)
    end

    -- The military frequency is unknown to an mp client (Config.getChannel is nil there): the server tunes the
    -- radio before giving it and sends the channel.
    local function setOn(on)
        local data = S.radio:getDeviceData()
        data:setIsTurnedOn(on)
        data:setChannel(S.channel)
    end

    -- Poll the server until the military channel has nothing left to air.
    local function airingDoneMp(key)
        if not S[key] or (nowMs() - S[key]) > 1000 then
            local r = replyOf("airing")
            if S[key] and r and r.done then
                S[key] = nil
                return true
            end
            S[key] = nowMs()
            request(player, "airing")
        end
        return false
    end

    addStep("mp marks: radio given by the server and taken in hand", function()
        local r = asked(S, "askedRadio", player, "giveRadio")
        if not r then return false end
        S.radio = S.radio or findRadio(player, r.id)
        S.channel = tonumber(r.channel)
        if not S.radio or not S.channel then return false end
        if player:getPrimaryHandItem() ~= S.radio and player:getSecondaryHandItem() ~= S.radio then
            if not S.equipping then
                S.equipping = true
                MD.Exchange.takeInHand(player, S.radio)
            end
            return false
        end
        setOn(false)
        rec(true, "mp marks: radio given by the server and taken in hand", "id=" .. tostring(r.id))
        return true
    end, 30000)

    addStep("mp marks: unheard recon gives no symbol", function()
        local r = asked(S, "askedR1", player, "launch")
        if not r then return false end
        if not r.id then
            rec(false, "mp marks: unheard recon gives no symbol", "launch failed")
            return true
        end
        S.r1 = r
        if not airingDoneMp("air1") then return false end
        local n = countSymbols("Eye", r.x, r.y)
        info("R1 " .. r.id .. " at " .. r.x .. "," .. r.y)
        rec(n == 0 and received("ReconAnnounce", function(a) return a.id == r.id end) ~= nil,
            "mp marks: unheard recon gives no symbol", "eye=" .. n .. " (ReconAnnounce received)")
        return true
    end, airMs)

    addStep("mp marks: base reply (too far) marks the recon", function()
        if not S.r1 then return true end
        if not S.sent then
            setOn(true)
            S.sent = MD.Exchange.send(player, S.radio, MD.Exchange.COMMANDS.recon, {}, nil,
                { onReply = function(args) S.reply = args end })
            if not S.sent then
                rec(false, "mp marks: base reply (too far) marks the recon", "exchange not started")
                return true
            end
            return false
        end
        if not S.reply then return false end
        local n = countSymbols("Eye", S.r1.x, S.r1.y)
        if n == 0 then return false end
        rec(S.reply.status == "tooFar" and n == 1, "mp marks: base reply (too far) marks the recon",
            "status=" .. tostring(S.reply.status) .. " eye=" .. n)
        return true
    end, 60000)

    addStep("mp marks: closed recon symbol removed (MarksActive)", function()
        if not S.r1 then return true end
        if not asked(S, "askedClose1", player, "close") then return false end
        if countSymbols("Eye", S.r1.x, S.r1.y) > 0 then return false end
        rec(true, "mp marks: closed recon symbol removed (MarksActive)", "R1 " .. S.r1.id)
        return true
    end, 15000)

    addStep("mp marks: reminder heard marks the recon", function()
        if not S.air2 and not S.waited2 then
            if not airingDoneMp("airPre2") then return false end
            S.waited2 = true
            setOn(false)
        end
        local r = asked(S, "askedR2", player, "launch")
        if not r then return false end
        if not r.id then
            rec(false, "mp marks: reminder heard marks the recon", "launch failed")
            return true
        end
        S.r2 = r
        if not S.remindAsked then
            if not airingDoneMp("air2") then return false end
            if countSymbols("Eye", r.x, r.y) ~= 0 then
                rec(false, "mp marks: reminder heard marks the recon", "marked before the reminder")
                return true
            end
            info("R2 " .. r.id .. " at " .. r.x .. "," .. r.y)
            setOn(true)
            S.remindAsked = true
            request(player, "remind")
            return false
        end
        local rr = replyOf("remind")
        local n = countSymbols("Eye", r.x, r.y)
        if not rr or n == 0 then return false end
        rec(rr.count == 1 and n == 1, "mp marks: reminder heard marks the recon",
            "reminders=" .. tostring(rr.count) .. " eye=" .. n)
        return true
    end, airMs * 3)

    addStep("mp marks: drop announcement heard", function()
        if not S.dropAsked then
            if not airingDoneMp("airPre3") then return false end
        end
        local r = asked(S, "dropAsked", player, "drop")
        if not r then return false end
        S.d1 = r
        if countSymbols("Target", r.x, r.y) == 0 then return false end
        rec(true, "mp marks: drop announcement heard", "D1 " .. tostring(r.id) .. " at " .. r.x .. "," .. r.y)
        return true
    end, airMs)

    addStep("mp marks: Sync removes a stray marker, keeps the active one", function()
        if not S.d1 then return true end
        if not S.syncSent then
            S.strayX, S.strayY = S.d1.x + 20, S.d1.y
            MD.Announce.markMap(S.strayX, S.strayY)
            S.syncSent = true
            MD.Net.toServer(player, "Sync", {})
            return false
        end
        if countSymbols("Target", S.strayX, S.strayY) > 0 then return false end
        local active = countSymbols("Target", S.d1.x, S.d1.y)
        rec(active == 1, "mp marks: Sync removes a stray marker, keeps the active one", "active=" .. active)
        return true
    end, 15000)

    addStep("mp marks: emptied drop marker removed", function()
        if not S.d1 then return true end
        if not asked(S, "askedCollect", player, "collect") then return false end
        if countSymbols("Target", S.d1.x, S.d1.y) > 0 then return false end
        rec(true, "mp marks: emptied drop marker removed", "D1 " .. tostring(S.d1.id))
        return true
    end, 15000)

    addStep("mp marks: second recon closed, symbol removed", function()
        if not S.r2 then return true end
        if not asked(S, "askedClose2", player, "close") then return false end
        if countSymbols("Eye", S.r2.x, S.r2.y) > 0 then return false end
        rec(true, "mp marks: second recon closed, symbol removed", "R2 " .. S.r2.id)
        return true
    end, 15000)

    addStep("mp marks: clearance heard: skull and radius circle", function()
        if not S.cAsked then
            if not airingDoneMp("airPre4") then return false end
            setOn(true)
        end
        local r = asked(S, "cAsked", player, "launchCleanup")
        if not r then return false end
        if not r.id then
            rec(false, "mp marks: clearance heard: skull and radius circle", "launch failed")
            return true
        end
        S.c1 = r
        local skull, scale = countSymbols("Skull", r.x, r.y), circleScale(r.x, r.y)
        if skull == 0 or not scale then return false end
        local expected = expectedCircleScale(r.radius)
        rec(skull == 1 and countSymbols("Circle", r.x, r.y) == 1 and math.abs(scale - expected) < 0.01,
            "mp marks: clearance heard: skull and radius circle",
            "C1 " .. r.id .. " skull=" .. skull .. " scale=" .. tostring(scale) .. " expected=" .. tostring(expected))
        addPlayerCircle(r.x, r.y)
        return true
    end, airMs)

    addStep("mp marks: closed clearance removes skull and circle, keeps the player's circle", function()
        if not S.c1 then return true end
        if not asked(S, "askedCloseC1", player, "closeCleanup") then return false end
        local skull, circles = countSymbols("Skull", S.c1.x, S.c1.y), countSymbols("Circle", S.c1.x, S.c1.y)
        if skull > 0 or circleScale(S.c1.x, S.c1.y) then return false end
        rec(circles == 1 and removePlayerCircle(S.c1.x, S.c1.y),
            "mp marks: closed clearance removes skull and circle, keeps the player's circle",
            "circles left=" .. circles)
        return true
    end, 15000)

    addStep("mp marks: finish", function()
        request(player, "finish")
        return true
    end)
end

-- Server side of the mp scenario: one handler per op, answered to the sender.
local ServerOps = { finished = false }

-- Corrections scenario: real fixed radio, console actions and zombie death events.
-- Only the launcher's disposable copy is changed by these helpers.
local function correctionPrepare(player)
    local MD = MilitaryDrop
    local cfg = SandboxVars.MilitaryDrop
    cfg.ReportGain, cfg.ControlGain, cfg.CleanupGain = 1, 1, 5
    cfg.CleanupQuota, cfg.TrustDailyCap, cfg.TrustPostBonus = 10, 100, 50
    -- Config.get prioritizes the live Java options in B42.21, not the Lua mirror.
    for _, key in ipairs({ "ReportGain", "ControlGain", "CleanupGain", "CleanupQuota", "TrustDailyCap", "TrustPostBonus" }) do
        getSandboxOptions():getOptionByName("MilitaryDrop." .. key):setValue(cfg[key])
    end
    local cid = MD.Trust.idFor(player)
    local private = MD.Secrets.privateState()
    private.characterTrust[cid].value = 25
    private.characterTrust[cid].dayGain = 0
    private.characterTrust[cid].lockedUntil = nil
    MD.Missions.postExchanges(cid)
    private.missions.reports[cid] = nil
    private.missions.open.control = nil
    MD.Missions.launch("control")
    local square = player:getCurrentSquare()
    local object = IsoRadio.new(getCell(), square, getSprite("appliances_com_01_8"))
    square:AddSpecialObject(object)
    local dd = object:getDeviceData()
    dd:setIsBatteryPowered(true)
    dd:setPower(1)
    dd:setChannelRaw(MD.Config.getChannel())
    dd:setIsTurnedOn(true)
    if isServer() then object:transmitCompleteItemToClients() end
    MD.Post.install(player, { radio = MD.Radio.makeRef(object) })
    local ok = MD.Post.ownerOf(object) == MD.Teams.idFor(player) and dd:getIsTurnedOn()
    rec(ok, "corrections: powered fixed post installed")
    return { ok = ok, x = square:getX(), y = square:getY(), z = square:getZ() }
end

local function correctionKills(player)
    local MD = MilitaryDrop
    local Missions, Trust = MD.Missions, MD.Trust
    local cid = Trust.idFor(player)
    local state = MD.Secrets.privateState()
    local postDone = state.missions.reports[cid] ~= nil
        and state.missions.open.control and state.missions.open.control.responded[cid]
    rec(postDone == true, "corrections: report and control accepted by the authority")
    rec(Trust.get(cid) == 29, "corrections: both post bonuses credited once", "trust=" .. Trust.get(cid))
    state.missions.open.cleanup = nil
    local square = MD.Server.findLandingNear(math.floor(player:getX()) + 18, math.floor(player:getY()))
    if not square then return { ok = false, error = "no loaded outdoor square" } end
    local mission = Missions.launch("cleanup")
    if not mission then return { ok = false, error = "mission launch failed" } end
    mission.x, mission.y, mission.horde = square:getX(), square:getY(), nil
    Missions.trySpawnHorde()
    if not mission.horde then return { ok = false, error = "horde not spawned" } end
    local target = Missions.hordeTarget(mission.horde)
    rec(target == 9 and mission.horde.size == 10, "corrections: target is 90 percent", "target=" .. target)
    local other
    if isServer() then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            if players:get(i) ~= player then other = players:get(i); break end
        end
        rec(other ~= nil, "corrections: second real player participates")
    end
    local winner = other or player
    local wid = Trust.idFor(winner)
    local before = Trust.get(wid)
    for i = 1, target do
        local zombies = getCell():getZombieList()
        local count = zombies:size()
        spawnHorde(square:getX() + 0.5, square:getY() + 0.5, square:getX() + 0.5, square:getY() + 0.5, 0, 1)
        if zombies:size() <= count then return { ok = false, error = "ambient spawn failed" } end
        local zombie = zombies:get(zombies:size() - 1)
        local killer = i <= 3 and player or winner
        if isServer() then
            zombie:setAttackedBy(killer)
            zombie:die()
        else
            zombie:Kill(nil, killer)
        end
        -- Simulate the duplicate death notification seen with burning zombies.
        Missions.countKill(zombie)
        if i == target - 1 then
            rec(Missions.openMission("cleanup") ~= nil and Missions.cleanupDown(mission.horde) == target - 1,
                "corrections: local deaths shared and deduplicated before threshold")
        end
    end
    local last = state.missions.last.cleanup
    local ok = Missions.openMission("cleanup") == nil and last and last.character == wid
    rec(ok == true, "corrections: shared order closed with one winner")
    rec(Trust.get(wid) == before + 5, "corrections: winner paid exactly once", "trust=" .. Trust.get(wid))
    if other then rec(Trust.get(cid) == 29, "corrections: other contributor not paid") end
    return { ok = ok == true }
end

local function serverOp(module, command, player, args)
    if module ~= OPS_MODULE or not player then return end
    local MD = MilitaryDrop
    local Missions, Trust = MD.Missions, MD.Trust
    local reply = {}
    local function closeRecon()
        if Missions.openMission("recon") then
            ServerOps.closeAt = nowMs()
            return Missions.adminLaunch(player, { kind = "recon", action = "close" })
        end
        return "none"
    end
    if command == "correctionPrepare" then
        reply = correctionPrepare(player)
    elseif command == "correctionKills" then
        reply = correctionKills(player)
    elseif command == "giveRadio" then
        local inv = player:getInventory()
        local radio = inv:AddItem("Base.WalkieTalkie5")
        local channel = MD.Config.getChannel()
        radio:getDeviceData():setChannelRaw(channel)
        sendAddItemToContainer(inv, radio)
        reply.id, reply.channel = radio:getID(), channel
    elseif command == "airing" then
        reply.done = airingDone()
    elseif command == "launch" then
        closeRecon()
        local mission = Missions.launch("recon")
        ServerOps.mission = mission
        if mission then
            reply.id, reply.x, reply.y = mission.id, mission.x, mission.y
        end
        rec(mission ~= nil, "server: recon launched", mission and mission.id or "nil")
    elseif command == "close" then
        local status = closeRecon()
        reply.status = status
        rec(status == "closed", "server: recon closed", "status=" .. tostring(status))
    elseif command == "remind" then
        local mission = ServerOps.mission
        local every = math.floor(tonumber(MD.Config.get("DropRepeatHours")) or 0)
        if mission then
            mission.openedHours = mission.openedHours - every - 0.1
        end
        reply.count = Missions.remind()
        rec(reply.count == 1, "server: reminder aired", "count=" .. tostring(reply.count))
    elseif command == "drop" then
        local x, y = math.floor(player:getX()) + 40, math.floor(player:getY())
        local dropId = Trust.registerDrop(Trust.idFor(player), "autotest", true, {})
        Trust.onDropAnnounced(dropId, x, y)
        MD.Broadcast.dropped(x, y)
        ServerOps.dropId = dropId
        reply.id, reply.x, reply.y = dropId, x, y
    elseif command == "collect" then
        reply.ok = Trust.markCollected(ServerOps.dropId)
        Missions.update()
        rec(reply.ok == true, "server: drop emptied", tostring(ServerOps.dropId))
    elseif command == "launchCleanup" then
        if Missions.openMission("cleanup") then
            Missions.adminLaunch(player, { kind = "cleanup", action = "close" })
        end
        local mission = Missions.launch("cleanup")
        ServerOps.cleanup = mission
        if mission then
            reply.id, reply.x, reply.y, reply.radius = mission.id, mission.x, mission.y, mission.radius
        end
        rec(mission ~= nil, "server: clearance launched", mission and mission.id or "nil")
    elseif command == "closeCleanup" then
        -- Admin commands are throttled (1 s): closed from H.server.done a moment later.
        if Missions.openMission("cleanup") then
            ServerOps.pendingClose = { player = player, at = nowMs() }
            return
        end
        reply.status = "none"
    elseif command == "fultonPrepare" then
        local F, err = fultonPrepare(player)
        ServerOps.fulton = F
        if F then
            local ok, detail = fultonExpectedOk(F)
            rec(ok and F.tank ~= nil, "server: fulton kit laid outside, tank given", "at " .. F.x .. "," .. F.y .. ","
                .. F.z .. " " .. detail)
            rec(Missions.fultonWindow(F.cid) ~= nil, "server: fulton window open before the launch")
            reply.x, reply.y, reply.z, reply.kitId, reply.tankId, reply.items = F.x, F.y, F.z, F.kitId, F.tankId, F.items
        else
            rec(false, "server: fulton kit laid outside, tank given", err)
            reply.error = err
        end
    elseif command == "fultonCheck" then
        local F = ServerOps.fulton
        reply.ok = F ~= nil
        if F then
            for _, c in ipairs(fultonVerify(player, F)) do
                rec(c[2] == true, "server: " .. c[1], c[3])
                if c[2] ~= true then
                    reply.ok = false
                    reply.failed = c[1]
                end
            end
        end
    elseif command == "finish" then
        ServerOps.finished = true
        return
    else
        return
    end
    sendServerCommand(player, OPS_MODULE, command, reply)
end

-- ------------------------------------------------------------------ scenario "fulton" (mp client)

-- Client 1 drives: radio from the server (tuned there), pass requested by radio, kit and tank laid and given by the
-- server (op fultonPrepare), real menu launch, then the server checks payment and removal (op fultonCheck).
local function addFultonClientSteps(player)
    local MD = MilitaryDrop
    local S = {}
    if not Ops.installed then
        Ops.installed = true
        Events.OnServerCommand.Add(onOpReply)
    end

    -- The mp test world is new at each run, with ambient zombies, and the inflation is noisy: the character is
    -- made invisible and invincible like the solo test save (admin powers, as ISAdminPowerUI: setter then
    -- sendPlayerExtraInfo), so that a zombie never cancels the timed action.
    addStep("mp fulton: admin powers (invisible, god mode)", function()
        player:setInvisible(true)
        player:setGodMod(true)
        sendPlayerExtraInfo(player)
        info("mp fulton: character invisible and invincible for the test")
        return true
    end)

    addStep("mp fulton: radio given by the server and taken in hand", function()
        local r = asked(S, "askedRadio", player, "giveRadio")
        if not r then return false end
        S.radio = S.radio or findRadio(player, r.id)
        S.channel = tonumber(r.channel)
        if not S.radio or not S.channel then return false end
        if player:getPrimaryHandItem() ~= S.radio and player:getSecondaryHandItem() ~= S.radio then
            if not S.equipping then
                S.equipping = true
                MD.Exchange.takeInHand(player, S.radio)
            end
            return false
        end
        local data = S.radio:getDeviceData()
        data:setIsTurnedOn(true)
        data:setChannel(S.channel)
        rec(true, "mp fulton: radio given by the server and taken in hand", "id=" .. tostring(r.id))
        return true
    end, 30000)

    addStep("mp fulton: pass requested by radio", function()
        if not S.radio then return true end
        if not S.sent then
            if ISTimedActionQueue.isPlayerDoingAction(player) then return false end
            S.sent = MD.Exchange.send(player, S.radio, MD.Exchange.COMMANDS.fulton, {}, nil,
                { onReply = function(args) S.reply = args end })
            if not S.sent then
                rec(false, "mp fulton: pass requested by radio", "exchange not started")
                return true
            end
            return false
        end
        if not S.reply then return false end
        local window = MD.FultonClient.window(player:getPlayerNum())
        rec((S.reply.status == "ok" or S.reply.status == "pending") and window ~= nil,
            "mp fulton: pass requested by radio", "status=" .. tostring(S.reply.status) .. " minutesLeft="
            .. tostring(window and MD.FultonClient.minutesLeft(player:getPlayerNum())) .. " dailyLeft="
            .. tostring(window and window.dailyLeft))
        return true
    end, 60000)

    addStep("mp fulton: kit laid and tank given by the server", function()
        local r = asked(S, "askedPrep", player, "fultonPrepare")
        if not r then return false end
        if r.error or not r.kitId then
            rec(false, "mp fulton: kit laid and tank given by the server", tostring(r.error))
            return true
        end
        S.x, S.y, S.z, S.kitId, S.items = r.x, r.y, r.z, r.kitId, r.items
        rec(true, "mp fulton: kit laid and tank given by the server", "kit " .. tostring(r.kitId) .. " at " .. r.x
            .. "," .. r.y .. "," .. r.z .. " tank " .. tostring(r.tankId))
        return true
    end, 30000)

    S.getKit = function()
        if not S.kitId then return nil end
        return kitOnSquare(getCell():getGridSquare(S.x, S.y, S.z), S.kitId)
    end
    addFultonLaunchSteps(player, S, "mp fulton: ")

    addStep("mp fulton: server paid and cleaned up", function()
        if not S.result then return true end
        local r = asked(S, "askedCheck", player, "fultonCheck")
        if not r then return false end
        rec(r.ok == true, "mp fulton: server paid and cleaned up", r.failed and ("failed: " .. tostring(r.failed))
            or "all server checks passed")
        return true
    end, 30000)

    addStep("mp fulton: kit gone for the client", function()
        if not S.kitId then return true end
        if S.getKit() then return false end
        rec(true, "mp fulton: kit gone for the client", S.x .. "," .. S.y .. "," .. S.z)
        return true
    end, 15000)

    addStep("mp fulton: finish", function()
        request(player, "finish")
        return true
    end)
end

-- ------------------------------------------------------------------ hooks

local function addCorrectionsSteps(player)
    local MD, S = MilitaryDrop, {}
    if isClient() and not Ops.installed then
        Ops.installed = true
        Events.OnServerCommand.Add(onOpReply)
    end
    addStep("corrections: prepare post without portable radio", function()
        player:setGodMod(true)
        player:setInvisible(true)
        player:setPrimaryHandItem(nil)
        player:setSecondaryHandItem(nil)
        if isClient() then sendPlayerExtraInfo(player) end
        local r
        if isClient() then r = asked(S, "prepareAsked", player, "correctionPrepare")
        else r = correctionPrepare(player) end
        if not r then return false end
        S.post = r
        rec(r.ok == true, "corrections: post preparation received")
        return true
    end, 30000)
    addStep("corrections: open real post console", function()
        if not S.post or not S.post.ok then return true end
        S.radio = S.radio or ownPostNear(player)
        if not S.radio then return false end
        if not S.openAsked then
            S.openAsked = true
            MD.PostWindow.requestOpen(player, S.radio)
        end
        S.window = MD.PostWindow.instances[player:getPlayerNum()]
        if not S.window or not S.window.data then return false end
        rec(true, "corrections: console opened")
        return true
    end, 30000)
    for _, spec in ipairs({ { key = "exchange:report", state = "reportDone" },
        { key = "mission:control", state = "control" } }) do
        local actionSpec = spec
        addStep("corrections: " .. actionSpec.key .. " through console action", function()
            local w = S.window
            if not w then return true end
            if not S[actionSpec.key] then
                if ISTimedActionQueue.isPlayerDoingAction(player) then return false end
                if S.previousExchangeAt and getTimestampMs() - S.previousExchangeAt < 3500 then return false end
                w:select(actionSpec.key)
                local action = w:actions()
                if not action or not action.enabled then return false end
                w:activate("primary")
                S[actionSpec.key] = true
            end
            local done = w.data.exchanges and w.data.exchanges[actionSpec.state]
            if actionSpec.state == "control" then
                for _, mission in ipairs(w.data.missions) do
                    if mission.kind == "control" then done = mission.progress == 1 end
                end
            end
            if not done then return false end
            S.previousExchangeAt = getTimestampMs()
            rec(not w:actions().enabled, "corrections: " .. actionSpec.key .. " completed and disabled")
            return true
        end, 45000)
    end
    addStep("corrections: draw and capture the fixed post", function()
        if not S.window then return true end
        if SHOTS and not shotAfter(S, "correctionShot", 10, "md_post_corrections.png") then return false end
        return true
    end, 10000)
    addStep("corrections: real shared clearance deaths", function()
        local r
        if isClient() then r = asked(S, "killsAsked", player, "correctionKills")
        else r = correctionKills(player) end
        if not r then return false end
        rec(r.ok == true, "corrections: clearance outcome received", r.error)
        if S.window then S.window:close("corrections complete") end
        if isClient() then request(player, "finish") end
        return true
    end, 30000)
end

local function seconds(value, default)
    return (tonumber(value) or default) * 1000
end

-- Solo: authority and client view in the same Lua. mp client 1: client view only.
function H.client.start(ctx)
    reset()
    SHOTS = ctx.params.shots == "1"
    if not MilitaryDrop or not MilitaryDrop.Net then return false, "MilitaryDrop not loaded" end
    local player = ctx.players()[1]
    if not player then return false, "no local player" end
    installObserver()
    if ctx.params.scenario == "corrections" then
        addCorrectionsSteps(player)
        return true
    end
    if isClient() then
        if ctx.params.scenario == "marks" then
            addMarksClientSteps(player, seconds(ctx.params.airSec, 240))
            return true
        end
        if ctx.params.scenario == "fulton" then
            addFultonClientSteps(player)
            return true
        end
        addClientSteps(player, seconds(ctx.params.clientWaitSec, 420))
    else
        if not MilitaryDrop.Server then return false, "MilitaryDrop.Server missing in solo" end
        if ctx.params.scenario == "marks" then
            addMarksSteps(player, seconds(ctx.params.airSec, 240))
            return true
        end
        if ctx.params.scenario == "fulton" then
            addFultonSoloSteps(player)
            return true
        end
        addAuthoritySteps(player, seconds(ctx.params.deliverySec, 240), seconds(ctx.params.crateWaitSec, 30), 0)
        addClientSteps(player, 10000)
    end
    return true
end

function H.client.done()
    return runSteps()
end

function H.client.result()
    removeObserver()
    unwrapFultonBroadcast()
    errorCheck()
    return summary()
end

function H.server.start(ctx)
    reset()
    if not MilitaryDrop or not MilitaryDrop.Server then return false, "MilitaryDrop.Server missing" end
    local player = ctx.players()[1]
    if not player then return false, "no connected player (mode server alone: use mp)" end
    if ctx.params.scenario == "marks" or ctx.params.scenario == "fulton" or ctx.params.scenario == "corrections" then
        ServerOps.finished = false
        ServerOps.started = nowMs()
        ServerOps.limitMs = seconds(ctx.params.airSec, 240) * 6
        Events.OnClientCommand.Add(serverOp)
        return true
    end
    local other = ctx.players()[2]
    if other then
        info("second player connected: " .. tostring(other:getUsername()) .. " opens the supply case")
    end
    addAuthoritySteps(player, seconds(ctx.params.deliverySec, 240), seconds(ctx.params.crateWaitSec, 30),
        seconds(ctx.params.serverLeadSec, 20), other)
    return true
end

function H.server.done()
    if ServerOps.started then
        local pending = ServerOps.pendingClose
        if pending and nowMs() - pending.at > 1500 then
            ServerOps.pendingClose = nil
            local status = MilitaryDrop.Missions.adminLaunch(pending.player, { kind = "cleanup", action = "close" })
            rec(status == "closed", "server: clearance closed", "status=" .. tostring(status))
            sendServerCommand(pending.player, OPS_MODULE, "closeCleanup", { status = status })
        end
        if ServerOps.finished then return true end
        if nowMs() - ServerOps.started > ServerOps.limitMs then
            rec(false, "server: client finished the scenario", "timeout")
            return true
        end
        return false
    end
    return runSteps()
end

function H.server.result()
    if ServerOps.started then
        Events.OnClientCommand.Remove(serverOp)
        unwrapFultonBroadcast()
        rec(ServerOps.finished, "server: client finished the scenario")
    end
    errorCheck()
    return summary()
end

return H
