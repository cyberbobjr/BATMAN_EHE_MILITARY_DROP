require "MilitaryDrop/MilitaryDrop_Core"
local A = { GROUPS = { "drop", "mission", "relay", "character", "wreck", "radio" }, PAGE_SIZE = 24 }
MilitaryDrop.Admin = A
function A.allowed(player)
    if not player or player:isDead() then return false end
    if not isClient() and not isServer() then return isDebugEnabled() == true end
    local cap = Capability and Capability.ChangeAndReloadServerOptions
    local role = player:getRole()
    return cap ~= nil and role ~= nil and role:hasCapability(cap) == true
        and checkPermissions(player, cap) == true
end
function A.canTeleport(player)
    if not A.allowed(player) then return false end
    if not isClient() and not isServer() then return true end
    if isClient() and player:getPlayerNum() ~= 0 then return false end
    local cap = Capability and Capability.TeleportToCoordinates
    return cap ~= nil and player:getRole():hasCapability(cap) == true and checkPermissions(player, cap) == true
end
function A.clean(value) return (tostring(value or ""):gsub("[<>\r\n]", " ")) end
function A.text(key, ...) return getText("IGUI_MilitaryDrop_AdminUI_" .. key, ...) end
function A.title(row)
    if row.kind == "radio" then return A.text("Group_radio") end
    if row.kind == "tool" then return A.text("ToolTitle_" .. row.id) end
    if row.kind == "character" then return A.clean(row.name) end
    if row.kind == "drop" then return A.text("DropTitle", A.clean(row.requester or row.id)) end
    if row.kind == "mission" then return getText("IGUI_MilitaryDrop_AdminMission_" .. row.missionKind) end
    if row.kind == "relay" then return A.text("RelayTitle", tostring(row.site)) end
    return A.text("WreckTitle", row.id)
end
function A.fingerprint(row)
    local parts = {}
    for _, key in ipairs({ "kind", "id", "phase", "x", "y", "z", "deadline", "progress", "quota",
        "winner", "value", "lockedUntil", "serial", "repairs", "responded", "reward", "baseGain", "beneficiary",
        "launchable" }) do
        parts[#parts + 1] = key .. "=" .. tostring(row[key])
    end
    return table.concat(parts, "|")
end
return A
