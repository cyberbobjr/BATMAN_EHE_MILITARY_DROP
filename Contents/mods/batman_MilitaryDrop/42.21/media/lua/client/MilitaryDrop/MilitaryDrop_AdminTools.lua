require "MilitaryDrop/MilitaryDrop_Admin"
local Tools = {}
MilitaryDrop.AdminTools = Tools
local A = MilitaryDrop.Admin
local OPERATIONS = {
    forcedrop = { "forceDrop" }, crash = { "crashNext" },
    fultonLaunch = { "fultonStart", "fultonVanilla" },
    fultonFlight = { "fultonPause", "fultonStop", "fultonCable" },
    fultonMode = { "fultonAuto", "fultonWorld", "fultonPost" },
}
function Tools.allowed(player, op)
    if not A.allowed(player) then return false end
    if op == "forceDrop" or op == "crashNext" then return MilitaryDrop.Client.canForce(player) end
    local debug = MilitaryDrop.FultonRenderDebug
    if not debug or not debug.canUse(player) then return false end
    local render = MilitaryDrop.FultonRender
    if not render then return false end
    if op == "fultonStart" or op == "fultonVanilla" then return true end
    if op == "fultonPause" or op == "fultonStop" then return render.selectPlayer(player:getPlayerNum()) ~= nil end
    return render.count() > 0
end
function Tools.rows(player)
    local result = {}
    for _, id in ipairs({ "forcedrop", "crash", "fultonLaunch", "fultonFlight", "fultonMode" }) do
        local row = { kind = "tool", id = id, phase = "tool", actions = {} }
        for _, op in ipairs(OPERATIONS[id]) do
            row.actions[#row.actions + 1] = { op = op, enabled = Tools.allowed(player, op), reason = "toolUnavailable" }
        end
        result[#result + 1] = row
    end
    return result
end
function Tools.execute(player, id, op)
    local known = false
    for _, candidate in ipairs(OPERATIONS[id] or {}) do if candidate == op then known = true end end
    if not known or not Tools.allowed(player, op) then return false end
    local render = MilitaryDrop.FultonRender
    if op == "forceDrop" then MilitaryDrop.Client.onRequest(player, nil, true)
    elseif op == "crashNext" then MilitaryDrop.Client.onAdminCrashNext(player)
    elseif op == "fultonStart" or op == "fultonVanilla" then
        render.start(player:getPlayerNum(), { vanilla = op == "fultonVanilla" })
    elseif op == "fultonPause" then render.selectPlayer(player:getPlayerNum()); render.togglePause()
    elseif op == "fultonStop" then render.selectPlayer(player:getPlayerNum()); render.stop()
    elseif op == "fultonCable" then render.toggleCable()
    elseif op == "fultonAuto" then render.setMode("auto")
    elseif op == "fultonWorld" then render.setMode("world")
    elseif op == "fultonPost" then render.setMode("post") end
    return true
end
return Tools
