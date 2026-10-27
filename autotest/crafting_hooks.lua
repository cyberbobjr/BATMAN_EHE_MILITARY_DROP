require "Entity/TimedActions/ISHandcraftAction"
local H = {}
local at, stage, initialErrors, before, tool, tape, inventory, action, init, ack, window
local serverDone, serverStarted
local okay, lines = true, {}
local function rec(value, name)
    lines[#lines + 1] = (value and "PASS " or "FAIL ") .. name
    if not value then okay = false end
end
local function beginAction(p)
    local recipe = ScriptManager.instance:getCraftRecipe("MilitaryDropJammer.MakeRJ93")
    rec(recipe ~= nil, "native B42 recipe registered")
    local logic = HandcraftLogic.new(p, nil, nil)
    local containers = ArrayList.new()
    containers:add(inventory)
    logic:setContainers(containers)
    logic:setManualSelectInputs(false)
    logic:setRecipe(recipe)
    rec(logic:canPerformCurrentRecipe(), "native crafting accepts exact materials and level 3")
    if not logic:canPerformCurrentRecipe() then
        print("[MDJ Craft Test] level=" .. p:getPerkLevel(Perks.Electricity)
            .. " scrap=" .. inventory:getAllTypeRecurse("ElectronicsScrap"):size()
            .. " metal=" .. inventory:getAllTypeRecurse("ScrapMetal"):size()
            .. " wire=" .. inventory:getAllTypeRecurse("ElectricWire"):size()
            .. " tape=" .. tape:getCurrentUsesFloat() .. " tool=" .. tool:getCondition())
        for i = 0, recipe:getInputs():size() - 1 do
            print("[MDJ Craft Test] input=" .. i .. " satisfied="
                .. logic:getSatisfiedInputInventoryItems(recipe:getInputs():get(i)):size())
        end
    end
    logic:setManualSelectInputs(true)
    action = ISHandcraftAction.FromLogic(logic)
    rec(action:getDuration() >= 2900 and action:getDuration() <= 3100, "recipe duration approximately sixty seconds")
    ISTimedActionQueue.add(action)
end
local function ingredients(p)
    local inv = p:getInventory()
    local function add(name)
        local item = inv:AddItem("Base." .. name)
        if isServer() then sendAddItemToContainer(inv, item) end
        return item
    end
    for _, row in ipairs({ { "ElectronicsScrap", 20 }, { "ScrapMetal", 4 }, { "ElectricWire", 2 } }) do
        for _ = 1, row[2] do add(row[1]) end
    end
    return add("Screwdriver"), add("DuctTape")
end
function H.start()
    at, stage, initialErrors = getTimestampMs(), 0, getLuaDebuggerErrorCount()
    setGameSpeed(1)
    local p = getPlayer()
    p:setGodMod(true)
    p:setPerkLevelDebug(Perks.Electricity, 3)
    p:getXp():setXPToLevel(Perks.Electricity, 3)
    UIManager.getDebugConsole():setVisible(false)
    if ISCharacterInfoWindow.instance then ISCharacterInfoWindow.instance:setVisible(false) end
    inventory = p:getInventory()
    before = inventory:getAllTypeRecurse("RJ93"):size()
    if isClient() then
        stage = -1
        Events.OnServerCommand.Add(function(m, c, args)
            if m ~= "MDJNativeCraft" then return end
            if c == "Init" then init = args elseif c == "Created" then ack = args end
        end)
        return true
    end
    tool, tape = ingredients(p)
    beginAction(p)
    return true
end
function H.done()
    local elapsed = getTimestampMs() - at
    if stage == -1 then
        if not init then return false end
        tool = inventory:getItemWithIDRecursiv(init.tool)
        tape = inventory:getItemWithIDRecursiv(init.tape)
        if not tool or not tape or inventory:getAllTypeRecurse("ElectronicsScrap"):size() < 20
            or inventory:getAllTypeRecurse("ScrapMetal"):size() < 4
            or inventory:getAllTypeRecurse("ElectricWire"):size() < 2 then return false end
        getPlayer():setPerkLevelDebug(Perks.Electricity, 3)
        getPlayer():getXp():setXPToLevel(Perks.Electricity, 3)
        beginAction(getPlayer())
        stage, at = 0, getTimestampMs()
        return false
    end
    if stage == 0 and elapsed > 3000 then
        takeScreenshot("jammer-crafting-timed-action.png")
        stage = 1
    end
    local items = inventory:getAllTypeRecurse("RJ93")
    if stage < 2 and items:size() > before then
        local item = items:get(items:size() - 1)
        rec(item:getFullType() == MDJammer.TYPE, "native timed action created dedicated jammer")
        rec(inventory:contains(tool), "screwdriver retained")
        rec(tape:getCurrentUsesFloat() < 1, "duct tape uses consumed")
        if isClient() then sendClientCommand(getPlayer(), "MDJNativeCraft", "Created", { id = item:getID() })
        else
            local square = getPlayer():getSquare()
            inventory:Remove(item)
            square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
            window = MDJammer.Client.open(getPlayer(), { id = item:getID(), x = square:getX(),
                y = square:getY(), z = square:getZ() })
        end
        stage, at = 2, getTimestampMs()
    elseif stage == 2 and elapsed > 1500 then
        if isClient() and not ack then return false end
        if isClient() and not window then
            window = MDJammer.Client.open(getPlayer(), ack.ref)
            return false
        end
        if not window.data then return false end
        rec(not window.data.on and not window.data.battery, "crafted device off and empty")
        rec(getLuaDebuggerErrorCount() == initialErrors, "no new Lua errors during native crafting")
        takeScreenshot("jammer-crafted-device.png")
        return true
    elseif elapsed > 100000 then rec(false, "native crafting completed before timeout"); return true end
    return false
end
function H.result() return { ok = okay, summary = #lines .. " native crafting checks", lines = lines } end
local S = {}
function S.start(ctx)
    serverStarted = getTimestampMs()
    local p
    for _, other in ipairs(ctx.players()) do if other:getUsername() == "pzat1" then p = other end end
    p:setGodMod(true)
    p:setPerkLevelDebug(Perks.Electricity, 3)
    p:getXp():setXPToLevel(Perks.Electricity, 3)
    local screwdriver, ductTape = ingredients(p)
    Events.OnClientCommand.Add(function(m, c, who, args)
        if m ~= "MDJNativeCraft" or c ~= "Created" then return end
        local item = who:getInventory():getItemWithIDRecursiv(args.id)
        rec(item and item:getFullType() == MDJammer.TYPE, "native remote action created the server-owned jammer")
        rec(who:getInventory():contains(screwdriver), "server screwdriver retained")
        rec(ductTape:getCurrentUsesFloat() < 1, "server tape uses consumed")
        rec(who:getInventory():getAllTypeRecurse("ElectronicsScrap"):size() == 0, "server components consumed")
        if item then
            local square, inv = who:getSquare(), who:getInventory()
            inv:Remove(item)
            sendRemoveItemFromContainer(inv, item)
            square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
            sendServerCommand(who, "MDJNativeCraft", "Created", { ref = { id = item:getID(),
                x = square:getX(), y = square:getY(), z = square:getZ() } })
        end
        serverDone = true
    end)
    sendServerCommand(p, "MDJNativeCraft", "Init", { tool = screwdriver:getID(), tape = ductTape:getID() })
    return true
end
function S.done()
    if getTimestampMs() - serverStarted > 140000 then rec(false, "MP craft before timeout"); return true end
    return serverDone
end
S.result = H.result
return { client = H, server = S }
