require "MilitaryDrop/MilitaryDrop_Core"

MDJammer = MDJammer or {}
local J = MDJammer
J.MODULE = "MilitaryDropJammer"
J.TYPE = "MilitaryDropJammer.RJ93"
J.RANGE = 3

function J.option(name, default, low, high)
    local options = SandboxVars and SandboxVars.MilitaryDropJammer
    local value = MilitaryDrop.Config.sandboxValue("MilitaryDropJammer." .. name)
    if value == nil then value = options and options[name] end
    value = tonumber(value) or default
    return math.max(low, math.min(high, value))
end

function J.enabled()
    local options = SandboxVars and SandboxVars.MilitaryDropJammer
    local value = MilitaryDrop.Config.sandboxValue("MilitaryDropJammer.Enabled")
    if value == nil then value = options and options.Enabled end
    return value ~= false
end

function J.radius() return J.option("Radius", 100, 10, 200) end
function J.hours() return J.option("BatteryHours", 24, 1, 168) end

function J.number(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function J.near(player, x, y, z)
    return player and not player:isDead() and math.floor(player:getZ()) == z
        and math.abs(player:getX() - x) <= J.RANGE and math.abs(player:getY() - y) <= J.RANGE
end

function J.send(player, command, args)
    if isClient() then sendClientCommand(player, J.MODULE, command, args or {})
    elseif J.Server then J.Server.command(J.MODULE, command, player, args or {}) end
end

function J.reply(player, args)
    if isServer() then sendServerCommand(player, J.MODULE, "State", args)
    elseif J.Client then J.Client.receive(J.MODULE, "State", args) end
end

return J
