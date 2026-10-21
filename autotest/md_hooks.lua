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
  6. Missions.adminLaunch(control): mission open and listed for the character;
  7. liaison post: HAM radio (IsoRadio with the HamRadio2 sprite) on the player's square, Post.install -> owner;
  8. Fulton: FultonServer.launch without a kit -> refused "noKit" (a full launch needs kit, helium tank and a mission
     window: not scripted here).
Client view (solo: same Lua; mp: client 1 with --client-run): MilitaryDrop server commands received ("Result"
accepted, "PostResult" installed) and the crate vehicle seen near the player.

Parameters (ctx.params, text): deliverySec (default 240), clientWaitSec (mp client, default 420).
Run state: MilitaryDrop's world state of the COPIED save only (pz-autotest copies the save and the server).
]]

local H = { client = {}, server = {} }

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

-- Crate vehicle within radius squares of (x, y), level 0.
local function crateNear(x, y, radius)
    local cell = getCell()
    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(x + dx, y + dy, 0)
            local vehicle = square and square:getVehicleContainer()
            if isCrateVehicle(vehicle) then
                return vehicle
            end
        end
    end
    return nil
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

local function addClientSteps(player, waitMs)
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
end

-- ------------------------------------------------------------------ authority path

local function addAuthoritySteps(player, deliveryMs)
    local MD = MilitaryDrop
    local Server, Trust, Config = MD.Server, MD.Trust, MD.Config
    local S = {}

    addStep("setup", function()
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

    addStep("crate vehicle and marked contents", function()
        if not S.placed or type(S.placed.x) ~= "number" then
            rec(false, "crate vehicle and marked contents", "no delivery point")
            return true
        end
        S.vehicle = crateNear(S.placed.x, S.placed.y, 2)
        if not S.vehicle then
            rec(false, "crate vehicle and marked contents", "no crate vehicle near the point (ground fallback?)")
            return true
        end
        local marked, types = markedItems(S.vehicle, S.dropId, Trust.ITEM_KEY)
        S.case = marked[1]
        rec(#marked > 0, "crate vehicle and marked contents", tostring(S.vehicle:getScriptName()) .. ": "
            .. #marked .. " marked of " .. #types .. " (" .. table.concat(types, " ") .. ")")
        return true
    end)

    addStep("trust: first supply case opened by the caller", function()
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
        info("Fulton launch with kit, helium tank and mission window: not scripted (manual protocol F*)")
        return true
    end)
end

-- ------------------------------------------------------------------ hooks

local function seconds(value, default)
    return (tonumber(value) or default) * 1000
end

-- Solo: authority and client view in the same Lua. mp client 1: client view only.
function H.client.start(ctx)
    reset()
    if not MilitaryDrop or not MilitaryDrop.Net then return false, "MilitaryDrop not loaded" end
    local player = ctx.players()[1]
    if not player then return false, "no local player" end
    installObserver()
    if isClient() then
        addClientSteps(player, seconds(ctx.params.clientWaitSec, 420))
    else
        if not MilitaryDrop.Server then return false, "MilitaryDrop.Server missing in solo" end
        addAuthoritySteps(player, seconds(ctx.params.deliverySec, 240))
        addClientSteps(player, 10000)
    end
    return true
end

function H.client.done()
    return runSteps()
end

function H.client.result()
    removeObserver()
    errorCheck()
    return summary()
end

function H.server.start(ctx)
    reset()
    if not MilitaryDrop or not MilitaryDrop.Server then return false, "MilitaryDrop.Server missing" end
    local player = ctx.players()[1]
    if not player then return false, "no connected player (mode server alone: use mp)" end
    addAuthoritySteps(player, seconds(ctx.params.deliverySec, 240))
    return true
end

function H.server.done()
    return runSteps()
end

function H.server.result()
    errorCheck()
    return summary()
end

return H
