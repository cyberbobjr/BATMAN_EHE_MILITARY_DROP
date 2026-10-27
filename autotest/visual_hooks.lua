local H = {}
local at, phase, window, errors
function H.start()
    errors = getLuaDebuggerErrorCount()
    at, phase = getTimestampMs(), 0
    setGameSpeed(1)
    getGameTime():setTimeOfDay(12)
    local player = getPlayer()
    player:setGodMod(true)
    player:setInvisible(false)
    UIManager.getDebugConsole():setVisible(false)
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    player:teleportTo(10824, 9446, 0)
    return true
end
function H.done()
    local elapsed = getTimestampMs() - at
    local player = getPlayer()
    if phase == 0 and elapsed > 20000 then
        if MDJammer then
            local item = player:getInventory():AddItem(MDJammer.TYPE)
            local sq = player:getSquare()
            player:getInventory():Remove(item)
            sq:AddWorldInventoryItem(item, 0.5, 0.5, 0)
            window = MDJammer.Client.open(player, { id = item:getID(), x = sq:getX(), y = sq:getY(), z = 0 })
        end
        phase, at = 4, getTimestampMs()
    elseif phase == 4 and elapsed > 2000 then
        if window then takeScreenshot("jammer-window-empty.png") end
        return true
    end
    return false
end
function H.result()
    local jammer = instanceItem(MDJammer.TYPE)
    local model = ScriptManager.instance:getModelScript(jammer:getWorldStaticItem())
    return { ok = getLuaDebuggerErrorCount() == errors and window ~= nil and model ~= nil,
        summary = "jammer model and window; image inspection required", lines = {} }
end
return H
