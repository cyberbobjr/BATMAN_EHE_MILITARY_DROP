local T = {}
function T.setup()
    MP, SERVER, DEBUG, AUTHORIZED, OPENED, BASE_CALLS = false, false, true, true, nil, 0
    PLAYER = { isDead = function() return false end,
        getRole = function() return { hasCapability = function() return AUTHORIZED end } end }
    isClient = function() return MP end
    isServer = function() return SERVER end
    isDebugEnabled = function() return DEBUG end
    getSpecificPlayer = function(index) if index == 0 then return PLAYER end end
    getText = function() return "Military Drop Admin Menu" end
    Capability = { ChangeAndReloadServerOptions = "admin" }
    checkPermissions = function() return AUTHORIZED end
    MilitaryDrop = { AdminDashboard = { open = function(p) OPENED = p; return p end } }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Admin.lua")
    HANDLERS = {}
    Events = { OnFillWorldObjectContextMenu = {
        Add = function(fn) HANDLERS[fn] = true end,
        Remove = function(fn) HANDLERS[fn] = nil end } }
    ISWorldObjectContextMenu = { setTest = function() return "available" end }
    ISDebugMenu = {
        addButtonInfo = function(self, title, fn, tab)
            local row = { title = title, func = fn, tab = tab }
            self.buttons[#self.buttons + 1] = row
            return row
        end,
        setupButtons = function(self, value)
            BASE_CALLS = BASE_CALLS + 1
            self:addButtonInfo("Vanilla", function() end, "MAIN")
            self:addButtonInfo("Close", nil, "MAIN")
            return value
        end }
    ACCESS = loadMod("client/MilitaryDrop/MilitaryDrop_AdminAccess.lua")
end
local function menu()
    return setmetatable({ buttons = {} }, { __index = ISDebugMenu })
end
local function world(test)
    local options = {}
    local context = { addOption = function(_, title, player, fn)
        options[#options + 1] = { title = title, player = player, fn = fn }
    end }
    local result = ACCESS.worldMenu(0, context, {}, test)
    return options, result
end
function T.solo_debug_adds_main_button_and_opens_without_radio()
    local m = menu()
    assertEq(m:setupButtons("return preserved"), "return preserved")
    assertEq(#m.buttons, 3)
    assertEq(m.buttons[1].title, "Military Drop Admin Menu")
    assertEq(m.buttons[1].tab, "MAIN")
    m.buttons[1].func()
    assertEq(OPENED, PLAYER)
    assertEq(#world(false), 0, "SP access belongs in Debug only")
end
function T.solo_without_debug_has_no_button_and_callback_rechecks_rights()
    DEBUG = false
    local m = menu(); m:setupButtons()
    assertEq(#m.buttons, 2)
    ACCESS.onDebugButton()
    assertEq(OPENED, nil)
end
function T.multiplayer_admin_gets_world_entry_even_on_empty_ground()
    MP, DEBUG = true, false
    local options = world(false)
    assertEq(#options, 1)
    assertEq(options[1].title, "Military Drop Admin Menu")
    options[1].fn(options[1].player)
    assertEq(OPENED, PLAYER)
    local m = menu(); m:setupButtons()
    assertEq(#m.buttons, 2, "no SP debug entry in MP")
    local probe, result = world(true)
    assertEq(#probe, 0)
    assertEq(result, "available")
end
function T.ordinary_or_revoked_multiplayer_role_cannot_open()
    MP, AUTHORIZED = true, false
    assertEq(#world(false), 0)
    ACCESS.open(PLAYER)
    assertEq(OPENED, nil)
end
function T.reload_preserves_other_debug_buttons_and_one_world_hook()
    loadMod("client/MilitaryDrop/MilitaryDrop_AdminAccess.lua")
    local count = 0
    for _ in pairs(HANDLERS) do count = count + 1 end
    assertEq(count, 1)
    local m = menu(); m:setupButtons()
    assertEq(BASE_CALLS, 1)
    assertEq(#m.buttons, 3)
    assertEq(m.buttons[2].title, "Vanilla")
    assertEq(m.buttons[3].title, "Close")
end
function T.debug_button_does_not_depend_on_add_button_info_return_value()
    local original = ISDebugMenu.addButtonInfo
    for _, value in ipairs({ false, 1, "wrapped" }) do
        ISDebugMenu.addButtonInfo = function(self, ...)
            original(self, ...)
            return value
        end
        local m = menu()
        m:setupButtons()
        assertEq(#m.buttons, 3)
        assertEq(m.buttons[1].militaryDropAdmin, true)
        m.buttons[1].func()
        assertEq(OPENED, PLAYER)
    end
    ISDebugMenu.addButtonInfo = function(self, ...) original(self, ...) end
    local m = menu(); m:setupButtons()
    assertEq(#m.buttons, 3, "nil return also keeps the admin and vanilla buttons")
end
return T
