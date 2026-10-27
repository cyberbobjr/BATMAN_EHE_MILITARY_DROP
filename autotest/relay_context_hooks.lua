local H = {}
local at, phase, context, submenu, player, before, xp, errors
local okay, lines = true, {}
local function rec(value, text)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. text
    if not value then okay = false end
end
function H.start()
    at, phase, player, errors = getTimestampMs(), 0, getPlayer(), getLuaDebuggerErrorCount()
    player:setGodMod(true)
    player:setInvisible(false)
    player:setPerkLevelDebug(Perks.Electricity, 5)
    player:getXp():setXPToLevel(Perks.Electricity, 5)
    setGameSpeed(1)
    UIManager.getDebugConsole():setVisible(false)
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    player:teleportTo(1624, 5755, 0)
    for _ = 1, 11 do player:getInventory():AddItem("Base.ElectronicsScrap") end
    before = player:getInventory():getAllTypeRecurse("ElectronicsScrap"):size()
    xp = player:getXp():getXP(Perks.Electricity)
    return true
end
function H.done()
    local elapsed, M = getTimestampMs() - at, MilitaryDrop
    if phase == 0 and elapsed > 20000 then
        M.RelayServer.state().phase = "operational"
        rec(M.RelayServer.fail(2), "relay mission on real Brandenburg cabinet")
        local cabinet = M.RelayServer.cabinet(M.Relay.SITES[2])
        rec(cabinet ~= nil, "actual clicked cabinet present")
        context = ISContextMenu.get(0, 600, 380)
        triggerEvent("OnFillWorldObjectContextMenu", 0, context, { cabinet }, false)
        local top
        for i, option in ipairs(context.options) do
            if option.name == getText("IGUI_MilitaryDrop_Relay") then top, context.mouseOver = option, i end
        end
        rec(top ~= nil and top.subOption ~= nil, "world context event adds relay submenu")
        if not top then return true end
        submenu = context:getSubMenu(top.subOption)
        rec(submenu.options[1] and not submenu.options[1].notAvailable, "repair enabled with eleven components at level five")
        context:displaySubMenu(submenu, top)
        phase, at = 1, getTimestampMs()
    elseif phase == 1 and elapsed > 1500 then
        takeScreenshot("relay-right-click-repair-menu.png")
        phase, at = 2, getTimestampMs()
    elseif phase == 2 and elapsed > 500 then
        submenu.mouseOver = 1
        submenu:onMouseUp(5, 5)
        phase, at = 3, getTimestampMs()
    elseif phase == 3 and elapsed > 2500 then
        takeScreenshot("relay-native-timed-repair.png")
        phase = 4
    elseif phase == 4 and M.Relay.clientState.phase == "operational" then
        rec(before - player:getInventory():getAllTypeRecurse("ElectronicsScrap"):size() == 11,
            "native context selection consumes exact level-five cost")
        rec(player:getXp():getXP(Perks.Electricity) > xp, "context repair grants native electricity experience")
        phase, at = 5, getTimestampMs()
    elseif phase == 5 and elapsed > 1500 then
        takeScreenshot("relay-repaired-xp-confirmation.png")
        rec(getLuaDebuggerErrorCount() == errors, "no new Lua error in context and action")
        return true
    end
    if elapsed > 45000 then rec(false, "context scenario before timeout"); return true end
    return false
end
function H.result() return { ok = okay, summary = #lines .. " native relay context checks", lines = lines } end
return H
