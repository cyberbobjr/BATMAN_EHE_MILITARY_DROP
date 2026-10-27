if isServer() then return end
require "MDJammer/MDJ_Core"
require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "ISUI/ISComboBox"

local J = MDJammer
local C = { windows = {}, coverage = {}, snapshots = {}, nextPoll = 0, notices = {}, hums = {} }
J.Client = C
local Window = ISPanelJoypad:derive("MDJammerWindow")
C.Window = Window
local function text(key) return getText("IGUI_MDJ_" .. key) end

local function tell(player, key)
    player:Say(text(key))
end

local function batteries(player)
    local found = {}
    local all = player:getInventory():getAllEvalRecurse(function(item) return item:getFullType() == "Base.Battery" end)
    for i = 0, all:size() - 1 do found[#found + 1] = all:get(i) end
    return found
end

function Window:new(player, ref)
    local scale = getTextManager():getFontHeight(UIFont.Small)
    local width = math.max(420, scale * 25)
    local o = ISPanelJoypad.new(self, 120, 100, width, math.max(430, scale * 25))
    o.player, o.ref, o.title, o.resizable = player, ref, text("Title"), false
    o.moveWithMouse = true
    o.backgroundColor = { r = 0.08, g = 0.09, b = 0.08, a = 0.98 }
    return o
end

function Window:createChildren()
    ISPanelJoypad.createChildren(self)
    local w, h = self.width, self.height
    local close = ISButton:new(w - 36, 4, 28, 24, "X", self, Window.close)
    self:addChild(close)
    self.toggle = ISButton:new(16, h - 142, w - 32, 28, text("TurnOn"), self, Window.toggleClick)
    self:addChild(self.toggle)
    self.choice = ISComboBox:new(16, h - 107, w - 32, 25, self, function() end)
    self:addChild(self.choice)
    self.insert = ISButton:new(16, h - 74, (w - 40) / 2, 28, text("Insert"), self, Window.insertClick)
    self.remove = ISButton:new(24 + (w - 40) / 2, h - 74, (w - 40) / 2, 28,
        text("Remove"), self, Window.removeClick)
    self:addChild(self.insert)
    self:addChild(self.remove)
    self:insertNewLineOfButtons(self.toggle)
    self:insertNewLineOfButtons(self.choice)
    self:insertNewLineOfButtons(self.insert, self.remove)
    self:refreshBatteries()
end

function Window:refreshBatteries()
    local old = self.choice.options[self.choice.selected]
    local previous = type(old) == "table" and old.data
    self.choice:clear()
    local items = batteries(self.player)
    for _, item in ipairs(items) do
        self.choice:addOptionWithData(item:getDisplayName() .. " (" .. math.ceil(item:getCurrentUsesFloat() * 100) .. " %)",
            item:getID())
        if item:getID() == previous then self.choice.selected = #self.choice.options end
    end
    self.batteryCount = #items
end

function Window:toggleClick() J.send(self.player, "Toggle", { ref = self.ref }) end
function Window:insertClick()
    local selected = self.choice.options[self.choice.selected]
    if type(selected) == "table" then J.send(self.player, "Insert", { ref = self.ref, battery = selected.data }) end
end
function Window:removeClick() J.send(self.player, "Remove", { ref = self.ref }) end

function Window:prerender()
    ISPanelJoypad.prerender(self)
    local data = self.data
    local w = self.width
    self:drawText(text("Title"), 12, 6, 1, 1, 1, 1, UIFont.Small)
    local illustration = getTexture("media/textures/MDJ_Panel.png")
    if illustration then self:drawTextureScaled(illustration, w / 2 - 58, 30, 116, 116, 1) end
    local status = not data and "Loading" or not data.battery and "NoBattery"
        or data.charge <= 0 and "Empty" or data.on and "On" or "Off"
    local charge = data and data.charge or 0
    self:drawText(text("Status") .. ": " .. text(status), 16, 156, 1, 1, 1, 1, UIFont.Small)
    local orange = charge < 0.2
    self:drawRect(16, 184, w - 32, 18, 1, 0.18, 0.18, 0.18)
    self:drawRect(16, 184, (w - 32) * charge, 18, 1, orange and 0.85 or 0.32, 0.52, 0.18)
    self:drawTextCentre(math.ceil(charge * 100) .. " %", w / 2, 184, 1, 1, 1, 1, UIFont.Small)
    self:drawText(text("Radius") .. ": " .. tostring(data and data.radius or J.radius()), 16, 214, 0.8, 0.8, 0.8, 1,
        UIFont.Small)
    self:drawText(text("Hint1"), 16, 239, 0.72, 0.72, 0.72, 1, UIFont.Small)
    self:drawText(text("Hint2"), 16, 260, 0.72, 0.72, 0.72, 1, UIFont.Small)
    self.toggle:setTitle(text(data and data.on and "TurnOff" or "TurnOn"))
    self.toggle:setEnable(data ~= nil and (data.on or (data.battery and data.charge > 0)))
    self.remove:setEnable(data ~= nil and data.battery)
    self.insert:setEnable(data ~= nil and not data.battery and (self.batteryCount or 0) > 0)
    self.insert.tooltip = text(data and data.battery and "Occupied" or "ChooseBattery")
end

function Window:update()
    ISPanelJoypad.update(self)
    local square = getCell():getGridSquare(self.ref.x, self.ref.y, self.ref.z)
    local present = false
    if square then
        local objects = square:getWorldObjects()
        for i = 0, objects:size() - 1 do
            if objects:get(i):getItem():getID() == self.ref.id then present = true; break end
        end
    end
    if not present or not J.near(self.player, self.ref.x, self.ref.y, self.ref.z) then self:close() end
end

function Window:close()
    C.windows[self.player:getPlayerNum()] = nil
    self:setVisible(false)
    self:removeFromUIManager()
    if JoypadState.players[self.player:getPlayerNum() + 1] then setJoypadFocus(self.player:getPlayerNum(), nil) end
end

function Window:onJoypadDown(button)
    if button == Joypad.BButton then self:close()
    else ISPanelJoypad.onJoypadDown(self, button) end
end

function C.open(player, ref)
    local num = player:getPlayerNum()
    if C.windows[num] then C.windows[num]:close() end
    local window = Window:new(player, ref)
    window:initialise()
    window:addToUIManager()
    C.windows[num] = window
    J.send(player, "Inspect", { ref = ref })
    if JoypadState.players[num + 1] then setJoypadFocus(num, window) end
    return window
end

function C.receive(module, command, args)
    if module ~= J.MODULE or command ~= "State" or type(args) ~= "table" then return end
    for num = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(num)
        if player and (not args.username or args.username == player:getUsername()) then
            local hum = C.hums[num]
            if args.hum then
                if not hum then
                    hum = { emitter = getWorld():getFreeEmitter(args.hum.x, args.hum.y, args.hum.z) }
                    C.hums[num] = hum
                end
                hum.emitter:setPos(args.hum.x, args.hum.y, args.hum.z)
                if not hum.sound or not hum.emitter:isPlaying(hum.sound) then
                    hum.sound = hum.emitter:playSoundLoopedImpl("MDJ_Hum")
                end
            elseif hum then
                if hum.sound then hum.emitter:stopSoundLocal(hum.sound) end
                C.hums[num] = nil
            end
            local was = C.coverage[num]
            C.coverage[num] = args.jammed == true
            if was == true and not args.jammed then tell(player, "Restored") end
            if args.reason == "blocked" and getTimestampMs() > (C.notices[num] or 0) then
                C.notices[num] = getTimestampMs() + 3000
                tell(player, "Blocked")
                player:playSoundLocal("MDJ_Static")
            end
            local window = C.windows[num]
            if window and args.ref and window.ref.id == args.ref.id then
                if not window.data or args.rev >= window.data.rev then window.data = args end
                window:refreshBatteries()
            elseif window and args.reason == "unavailable" then window:close() end
            if args.reason and args.reason ~= "ok" and args.reason ~= "blocked" then
                local key = "Error_" .. args.reason
                tell(player, key)
            end
        end
    end
end

local function contextMenu(num, context, objects, test)
    local player = getSpecificPlayer(num)
    if not player then return end
    local seen = {}
    for _, object in ipairs(objects) do
        local square = object:getSquare()
        if square then
            local world = square:getWorldObjects()
            for i = 0, world:size() - 1 do
                local item = world:get(i):getItem()
                if item and item:getFullType() == J.TYPE and not seen[item:getID()] then
                    if test then return ISWorldObjectContextMenu.setTest() end
                    seen[item:getID()] = true
                    context:addOption(text("Control"), player, C.open,
                        { id = item:getID(), x = square:getX(), y = square:getY(), z = square:getZ() })
                end
            end
        end
    end
end

local function tick()
    local stamp = getTimestampMs()
    if stamp < C.nextPoll then return end
    C.nextPoll = stamp + 2000
    for num = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(num)
        if player and player:getSquare() then
            local window = C.windows[num]
            if window then J.send(player, "Inspect", { ref = window.ref })
            else J.send(player, "Coverage", {}) end
        end
    end
end

MilitaryDrop.Extensions.radioStatus[J.MODULE] = function(player)
    if player and C.coverage[player:getPlayerNum()] then return "IGUI_MDJ_LinkJammed" end
end
if J.onReceive then Events.OnServerCommand.Remove(J.onReceive) end
if J.onContext then Events.OnFillWorldObjectContextMenu.Remove(J.onContext) end
if J.onClientTick then Events.OnTick.Remove(J.onClientTick) end
J.onReceive, J.onContext, J.onClientTick = C.receive, contextMenu, tick
Events.OnServerCommand.Add(J.onReceive)
Events.OnFillWorldObjectContextMenu.Add(J.onContext)
Events.OnTick.Add(J.onClientTick)
return C
