require "MilitaryDrop/MilitaryDrop_Admin"
require "DebugUIs/DebugMenu/ISDebugMenu"

local A = MilitaryDrop.Admin
local Access = MilitaryDrop.AdminAccess or {}
MilitaryDrop.AdminAccess = Access

function Access.open(player)
    if A.allowed(player) and MilitaryDrop.AdminDashboard then
        return MilitaryDrop.AdminDashboard.open(player)
    end
end

function Access.onDebugButton()
    if not isClient() and not isServer() then
        return Access.open(getSpecificPlayer(0))
    end
end

function Access.addDebugButton(menu)
    if isClient() or isServer() or not A.allowed(getSpecificPlayer(0)) then return end
    for _, info in ipairs(menu.buttons) do
        if info.militaryDropAdmin then return end
    end
    -- Build the entry explicitly: an installed addButtonInfo wrapper may not return its table.
    -- The previous setup still sorts this entry and supplies all vanilla/third-party buttons.
    table.insert(menu.buttons, { title = getText("IGUI_MilitaryDrop_AdminMenuAccess"),
        func = Access.onDebugButton, tab = "MAIN", marginTop = 0, militaryDropAdmin = true })
end

function Access.install()
    local menuClass = ISDebugMenu
    if menuClass.setupButtons ~= Access.wrapper then
        local previous = menuClass.setupButtons
        Access.wrapper = function(self, ...)
            Access.addDebugButton(self)
            return previous(self, ...)
        end
        menuClass.setupButtons = Access.wrapper
    end
end

if Access.worldMenu then Events.OnFillWorldObjectContextMenu.Remove(Access.worldMenu) end
function Access.worldMenu(playerNum, context, _, test)
    if not isClient() then return end
    local player = getSpecificPlayer(playerNum)
    if not A.allowed(player) then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    context:addOption(getText("IGUI_MilitaryDrop_AdminMenuAccess"), player, Access.open)
end
Events.OnFillWorldObjectContextMenu.Add(Access.worldMenu)
Access.install()
return Access
