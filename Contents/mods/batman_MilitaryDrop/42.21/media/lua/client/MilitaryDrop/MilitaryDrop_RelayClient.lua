require "MilitaryDrop/MilitaryDrop_Relay"
require "MilitaryDrop/MilitaryDrop_Client"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
local R = MilitaryDrop.Relay
local hooks = MilitaryDrop.RelayClientHooks or {}
MilitaryDrop.RelayClientHooks = hooks
if hooks.menu then Events.OnFillWorldObjectContextMenu.Remove(hooks.menu) end
if hooks.tick then Events.OnTick.Remove(hooks.tick) end
local Net = MilitaryDrop.Net
local Action = ISBaseTimedAction:derive("MilitaryDropRelayAction")
MilitaryDrop.RelayAction = Action
R.clientState = { phase = "operational" }

function Action:isValid()
    return MilitaryDrop.Config.get("RelayEnabled") ~= false
        and R.clientState.phase == "failed" and R.clientState.serial == self.serial
        and R.near(self.character, R.SITES[self.site])
end
function Action:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.character:faceLocation(R.SITES[self.site].x, R.SITES[self.site].y)
end
function Action:stop()
    Net.toServer(self.character, "RelayCancel", {})
    ISBaseTimedAction.stop(self)
end
function Action:perform()
    Net.toServer(self.character, "RelayComplete", { serial = self.serial })
    ISBaseTimedAction.perform(self)
end
function Action:new(player, args)
    local o = ISBaseTimedAction.new(self, player)
    o.site, o.serial = args.site, args.serial
    o.maxTime = args.seconds * 50
    o.stopOnWalk, o.stopOnRun, o.stopOnAim = true, true, true
    return o
end
local function repair(player) Net.toServer(player, "RelayBegin", {}) end
local function menu(num, context, objects, test)
    local state, player = R.clientState, getSpecificPlayer(num)
    if MilitaryDrop.Config.get("RelayEnabled") == false or not player or state.phase ~= "failed"
        or not R.SITES[state.site] then return end
    local site = R.SITES[state.site]
    for _, obj in ipairs(objects) do
        local square = obj:getSquare()
        if square and square:getX() == site.x and square:getY() == site.y then
            local cabinet = false
            for i = 0, square:getObjects():size() - 1 do
                if square:getObjects():get(i):getSpriteName() == site.sprite then cabinet = true end
            end
            if cabinet then
                if test then return ISWorldObjectContextMenu.setTest() end
                local top = context:addOption(getText("IGUI_MilitaryDrop_Relay"))
                local sub = ISContextMenu:getNew(context)
                context:addSubMenu(top, sub)
                local level = player:getPerkLevel(Perks.Electricity)
                local label = getText("IGUI_MilitaryDrop_RepairRelay", tostring(R.cost(level)), tostring(R.seconds(level)))
                local option = sub:addOption(label, player, repair)
                option.notAvailable = player:getInventory():getAllTypeRecurse("ElectronicsScrap"):size() < R.cost(level)
                    or not R.near(player, site)
                return
            end
        end
    end
end
MilitaryDrop.Client.HANDLERS.RelayState = function(args)
    R.clientState = args
    MilitaryDrop.Announce.onRelayState(args)
end
MilitaryDrop.Client.HANDLERS.RelayReply = function(args)
    local player
    for i = 0, getNumActivePlayers() - 1 do
        local localPlayer = getSpecificPlayer(i)
        if localPlayer and localPlayer:getUsername() == args.username then player = localPlayer end
    end
    if not player then return end
    if args.reason == "begin" then ISTimedActionQueue.add(Action:new(player, args))
    else player:Say(getText("IGUI_MilitaryDrop_Relay_" .. tostring(args.reason))) end
end
hooks.menu = menu
Events.OnFillWorldObjectContextMenu.Add(hooks.menu)
local nextSync = 0
hooks.tick = function()
    local stamp = getTimestampMs()
    if stamp < nextSync then return end
    nextSync = stamp + 10000
    for num = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(num)
        if player and player:getSquare() then Net.toServer(player, "RelaySync", {}) end
    end
end
Events.OnTick.Add(hooks.tick)
