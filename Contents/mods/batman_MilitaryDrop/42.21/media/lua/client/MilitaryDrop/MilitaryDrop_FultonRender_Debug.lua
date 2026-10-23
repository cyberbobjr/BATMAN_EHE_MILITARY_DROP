-- Fulton balloon test menu: development tool, loaded only in debug mode.
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

local function render()
    return MilitaryDrop.FultonRender
end

local function startFromMenu(playerNum, vanilla) render().start(playerNum, { vanilla = vanilla }) end

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

function Debug.onContext(playerNum, context, worldObjects, test)
    if test or not Debug.canUse(getSpecificPlayer(playerNum)) then return end
    local Render = render()
    local active = Render.selectPlayer(playerNum)
    local option = context:addOption("Fulton - visual test (debug)")
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    sub:addOption("Launch the balloon ascent", playerNum, startFromMenu, false)
    sub:addOption("Compare with the vanilla floating item", playerNum, startFromMenu, true)
    if active then
        sub:addOption(active.paused and "Resume the animation" or "Freeze the animation", nil, Render.togglePause)
        sub:addOption("Stop the test flight", nil, Render.stop)
    end
    if Render.count() > 0 then
        sub:addOption("Show / hide the cable", nil, Render.toggleCable)
        sub:addOption("Automatic rendering (with fallback)", "auto", Render.setMode)
        sub:addOption("World rendering only (vanilla floating item)", "world", Render.setMode)
        sub:addOption("Post-world rendering only", "post", Render.setMode)
    end
end

function Debug.dispose()
    Events.OnFillWorldObjectContextMenu.Remove(Debug.onContext)
end

Events.OnFillWorldObjectContextMenu.Add(Debug.onContext)
