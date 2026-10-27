local T = {}
local function list(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end
local function battery(id, uses)
    local item = { id = id, uses = uses or 100, condition = 80 }
    function item:getID() return self.id end
    function item:getFullType() return "Base.Battery" end
    function item:getCurrentUsesFloat() return self.uses * 0.007 end
    function item:getUseDelta() return 0.007 end
    function item:setCurrentUses(usesValue) self.uses = usesValue end
    function item:getCondition() return self.condition end
    function item:setCondition(value) self.condition = value end
    function item:getContainer() return self.container end
    return item
end
local function player(name, id)
    local inv = { items = {}, room = true }
    function inv:getItemWithIDRecursiv(itemId)
        for _, item in ipairs(self.items) do if item.id == itemId then return item end end
    end
    function inv:Remove(item)
        for i, known in ipairs(self.items) do if known == item then table.remove(self.items, i); break end end
        item.container = nil
    end
    function inv:AddItem(item) self.items[#self.items + 1], item.container = item, self; return item end
    function inv:hasRoomFor() return self.room end
    inv:AddItem(battery(id))
    return { getUsername = function() return name end, getInventory = function() return inv end,
        isDead = function() return false end, isEquipped = function() return false end,
        getX = function() return 0.5 end, getY = function() return 0.5 end, getZ = function() return 0 end }
end
local function send(p, command, args)
    STAMP = STAMP + 1000
    MDJammer.Server.command(MDJammer.MODULE, command, p, args or { ref = REF })
end
local function data() return STATE.devices[tostring(REF.id)] end
function T.setup()
    MilitaryDrop = { Config = { sandboxValue = function() return nil end },
        Extensions = { commandGates = {} }, Server = { canForce = function() return false end } }
    SandboxVars = { MilitaryDropJammer = {} }
    isClient, isServer = function() return false end, function() return true end
    STATE, STAMP, HOUR, LOADED, PRESENT = {}, 0, 1000, true, true
    ModData = { getOrCreate = function() return STATE end }
    getTimestampMs = function() return STAMP end
    getGameTime = function() return { getWorldAgeHours = function() return HOUR end } end
    REF = { id = 1001, x = 0, y = 0, z = 0 }
    ITEM = { getID = function() return REF.id end, getFullType = function() return "MilitaryDropJammer.RJ93" end }
    OBJECT = { getItem = function() return ITEM end, getOffZ = function() return 0 end }
    local square = { getWorldObjects = function() return list(PRESENT and { OBJECT } or {}) end }
    getCell = function() return { getGridSquare = function(_, x, y)
        if LOADED and x == 0 and y == 0 then return square end
    end } end
    sendServerCommand = function(_, _, _, args) REPLY = args end
    sendAddItemToContainer, sendRemoveItemFromContainer = function() end, function() end
    instanceItem = function() return battery(999) end
    P1, P2 = player("one", 201), player("two", 202)
    loadJammer("shared/MDJammer/MDJ_Core.lua")
    loadJammer("server/MDJammer/MDJ_Server.lua")
end
function T.full_inventory_keeps_battery_in_device()
    send(P1, "Insert", { ref = REF, battery = 201 })
    send(P1, "Toggle")
    P1:getInventory().room = false
    send(P1, "Remove")
    assertEq(REPLY.reason, "full")
    assertTrue(data().on and data().charge ~= nil, "failed removal preserves installed energy")
    assertEq(#P1:getInventory().items, 0)
end
function T.forged_reference_cannot_consume_battery()
    send(P1, "Insert", { ref = { x = 0 / 0, y = 0, z = 0, id = 1001 }, battery = 201 })
    assertEq(REPLY.reason, "unavailable")
    assertEq(#P1:getInventory().items, 1)
    assertEq(data(), nil)
end
function T.unloaded_square_preserves_energy_but_missing_loaded_item_stops_it()
    send(P1, "Insert", { ref = REF, battery = 201 })
    send(P1, "Toggle")
    LOADED, HOUR = false, HOUR + 1
    assertTrue(MDJammer.Server.active(data()), "unloaded device stays active for a later reload")
    assertTrue(data().charge < 0.7 and data().charge > 0.65)
    LOADED, PRESENT = true, false
    assertTrue(not MDJammer.Server.active(data()))
    assertTrue(not data().on, "picked up or deleted device never emits")
end
function T.disable_and_exhaustion_stop_without_recharging()
    send(P1, "Insert", { ref = REF, battery = 201 })
    send(P1, "Toggle")
    SandboxVars.MilitaryDropJammer.Enabled = false
    assertTrue(not MDJammer.Server.isJammed(P1))
    send(P1, "Toggle")
    assertEq(REPLY.reason, "disabled")
    SandboxVars.MilitaryDropJammer.Enabled = true
    data().on, data().hour = true, HOUR
    MDJammer.Server.advance(data(), HOUR + 24)
    assertEq(data().charge, 0)
    assertTrue(not data().on)
    MDJammer.Server.advance(data(), HOUR)
    assertEq(data().charge, 0, "clock rollback cannot refill battery")
end
return T
