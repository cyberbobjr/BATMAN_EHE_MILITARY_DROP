if isClient() then return end
require "MDJammer/MDJ_Core"
require "MilitaryDrop/MilitaryDrop_Server"

local J = MDJammer
local S = {}
J.Server = S
local lastRequest, tickAt = {}, 0
local worldItems = {}
local BLOCKED = { Request = true, RequisitionOrder = true, MissionReport = true, MissionDogTags = true,
    MissionRecon = true, MissionControl = true, MissionCleanupStatus = true, MissionFulton = true,
    PostTransmit = true, PostRecorderTransmit = true }

local function now() return getGameTime():getWorldAgeHours() end
local function state()
    local data = ModData.getOrCreate("MilitaryDropJammerPrivate")
    data.version = 1
    data.devices = data.devices or {}
    return data.devices
end

local function locate(ref)
    if type(ref) ~= "table" then return end
    for _, key in ipairs({ "x", "y", "z", "id" }) do
        if not J.number(ref[key]) or math.floor(ref[key]) ~= ref[key] then return end
    end
    if math.abs(ref.x) > 50000 or math.abs(ref.y) > 50000 or ref.z < -32 or ref.z > 31 then return end
    local square = getCell():getGridSquare(ref.x, ref.y, ref.z)
    if not square then return end
    local objects = square:getWorldObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local item = object:getItem()
        if item and item:getID() == ref.id and item:getFullType() == J.TYPE then
            return item, object
        end
    end
end
S.locate = locate

local function device(item, ref)
    local devices = state()
    local key = tostring(item:getID())
    if not devices[key] then
        local count = 0
        for _ in pairs(devices) do count = count + 1 end
        if count >= 2048 then return end
        devices[key] = { id = item:getID(), on = false, rev = 0 }
    end
    local data = devices[key]
    if data.x and (data.x ~= ref.x or data.y ~= ref.y or data.z ~= ref.z) then data.on = false end
    data.x, data.y, data.z = ref.x, ref.y, ref.z
    data.seen = now()
    return data
end

function S.advance(data, hour)
    local elapsed = math.max(0, hour - (data.hour or hour))
    if data.on and data.charge then
        data.charge = math.max(0, data.charge - elapsed / J.hours())
        if data.charge <= 0 then data.on = false end
    end
    data.hour = hour
end

function S.active(data)
    -- Never consume energy or broadcast from an item no longer on its recorded square.
    local item, object = locate(data)
    local loaded = getCell():getGridSquare(data.x, data.y, data.z) ~= nil
    local key = tostring(data.id)
    local moved = object and worldItems[key] and worldItems[key] ~= object
    if object then worldItems[key] = object end
    if not J.enabled() or (loaded and not item) or (object and object:getOffZ() > 0.1) or moved then
        data.on = false
        data.hour = now()
        return false
    end
    S.advance(data, now())
    return data.on == true and (data.charge or 0) > 0
end

function S.isJammed(player)
    if not J.enabled() or not player then return false end
    local radius = J.radius()
    for _, data in pairs(state()) do
        if data.on and S.active(data) then
            local dx, dy = player:getX() - data.x, player:getY() - data.y
            if dx * dx + dy * dy <= radius * radius then return true end
        end
    end
    return false
end

local function response(player, data, reason)
    local result = { reason = reason, jammed = S.isJammed(player), radius = J.radius(), username = player:getUsername() }
    local nearest = 10 * 10
    for _, entry in pairs(state()) do
        if entry.on and S.active(entry) then
            local dx, dy = player:getX() - entry.x, player:getY() - entry.y
            local distance = dx * dx + dy * dy
            if distance < nearest and math.floor(player:getZ()) == entry.z then
                nearest = distance
                result.hum = { x = entry.x, y = entry.y, z = entry.z }
            end
        end
    end
    if data then
        result.ref = { x = data.x, y = data.y, z = data.z, id = data.id }
        result.on, result.charge, result.battery = data.on == true, data.charge or 0, data.charge ~= nil
        result.rev = data.rev
    end
    J.reply(player, result)
end

function S.command(module, command, player, args)
    if module ~= J.MODULE or not player or player:isDead() then return end
    args = type(args) == "table" and args or {}
    local key = tostring(player:getUsername()) .. ":" .. tostring(command)
    local stamp = getTimestampMs()
    if stamp - (lastRequest[key] or -10000) < (command == "Inspect" and 250 or 100) then return end
    lastRequest[key] = stamp
    if command == "Coverage" then response(player); return end
    if command ~= "Inspect" and command ~= "Toggle" and command ~= "Insert" and command ~= "Remove" then return end
    local item, object = locate(args.ref)
    if not item or not J.near(player, args.ref.x, args.ref.y, args.ref.z) then
        response(player, nil, "unavailable"); return
    end
    if object:getOffZ() > 0.1 then response(player, nil, "ground"); return end
    local data = device(item, args.ref)
    if not data then response(player, nil, "limit"); return end
    S.active(data)
    if command == "Inspect" then response(player, data); return end
    local reason = "ok"
    if command == "Toggle" then
        if data.on then data.on = false
        elseif not J.enabled() then reason = "disabled"
        elseif not data.charge or data.charge <= 0 then reason = "empty"
        else
            local count = 0
            for _, entry in pairs(state()) do if entry.on and S.active(entry) then count = count + 1 end end
            if count >= 16 then reason = "limit" else data.on, data.hour = true, now() end
        end
    elseif command == "Insert" then
        local battery = J.number(args.battery) and player:getInventory():getItemWithIDRecursiv(args.battery)
        if data.charge ~= nil then reason = "occupied"
        elseif not battery or battery:getFullType() ~= "Base.Battery" or player:isEquipped(battery) then
            reason = "noBattery"
        else
            data.charge = math.max(0, math.min(1, battery:getCurrentUsesFloat()))
            data.condition = battery:getCondition()
            local container = battery:getContainer()
            container:Remove(battery)
            if isServer() then sendRemoveItemFromContainer(container, battery) end
            data.on = false
        end
    elseif command == "Remove" then
        if data.charge == nil then reason = "noBattery"
        else
            local battery = instanceItem("Base.Battery")
            -- B42 batteries store integer uses. Never round a returned charge upwards.
            battery:setCurrentUses(math.floor(data.charge / battery:getUseDelta() + 0.000001))
            battery:setCondition(data.condition or battery:getCondition())
            local inventory = player:getInventory()
            if not inventory:hasRoomFor(player, battery) then reason = "full"
            else
                inventory:AddItem(battery)
                if isServer() then sendAddItemToContainer(inventory, battery) end
                data.on, data.charge, data.condition = false, nil, nil
            end
        end
    end
    data.rev = data.rev + 1
    response(player, data, reason)
end

local function gate(player, command, args)
    if command == "Request" and args.forced and MilitaryDrop.Server.canForce(player) then return true end
    local radioCommand = BLOCKED[command]
    for _, name in pairs(MilitaryDrop.Exchange and MilitaryDrop.Exchange.COMMANDS or {}) do
        if name == command then radioCommand = true end
    end
    if radioCommand and S.isJammed(player) then
        -- No command reaches the business handler: no cost, cooldown or trust penalty.
        response(player, nil, "blocked")
        return false
    end
    return true
end
MilitaryDrop.Extensions.commandGates[J.MODULE] = gate

local previous = J.onServerTick
if previous then Events.OnTick.Remove(previous) end
function J.onServerTick()
    local stamp = getTimestampMs()
    if stamp < tickAt then return end
    tickAt = stamp + 1000
    for _, data in pairs(state()) do
        if data.on then S.active(data) end
    end
    local stale = {}
    for key, data in pairs(state()) do
        if not data.on and data.charge == nil and now() - (data.seen or now()) > 72 then stale[#stale + 1] = key end
    end
    for _, key in ipairs(stale) do state()[key], worldItems[key] = nil, nil end
    -- The limiter only retains recent users, not every character ever connected.
    for key, at in pairs(lastRequest) do if stamp - at > 60000 then lastRequest[key] = nil end end
end
Events.OnTick.Add(J.onServerTick)
if J.onCommand then Events.OnClientCommand.Remove(J.onCommand) end
J.onCommand = S.command
Events.OnClientCommand.Add(J.onCommand)
return S
