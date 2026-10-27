-- Fulton balloon controls for the administration console, debug mode only.
-- Admin-only: in MP, a role with Capability.MakeEventsAlarmGunshot (same right
-- as /chopper and the forced drop); in solo, debug mode only. The server
-- re-checks the right for Start/Stop/Pause (MilitaryDrop_FultonFlightServer.lua).
if isDebugEnabled == nil or isDebugEnabled() ~= true then
    return
end
require "MilitaryDrop/MilitaryDrop_FultonRender"
local previous = MilitaryDrop.FultonRenderDebug
if previous then previous.dispose() end
local Debug = {}
MilitaryDrop.FultonRenderDebug = Debug



--- Right to see the test menu (display only; the server re-checks).
--- Debug mode always (checked again here: it can be toggled), plus an admin role in MP.
function Debug.canUse(player)
    if not player then return false end
    if isDebugEnabled == nil or isDebugEnabled() ~= true then return false end
    if isClient() then
        local role = player:getRole()
        return role ~= nil and Capability ~= nil and role:hasCapability(Capability.MakeEventsAlarmGunshot) == true
    end
    return true
end

-- Tools are exposed by MilitaryDrop_AdminTools inside the administration console.
function Debug.dispose() end
return Debug
