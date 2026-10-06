-- MilitaryDrop_ZonesAdmin / ZonesWindow / ZoneEditor : outil d'admin des
-- zones de largage (ZONE-03) — bouton du panneau d'admin vanilla réservé à
-- l'admin, tracé à la souris (glisser ou deux clics, clics consommés,
-- rectangle figé après le second coin, clic droit et Échap), ZoneAdd
-- normalisé, ZoneUpdate des seuls champs modifiés, rectangle trop grand
-- refusé, réponses du serveur, contours, manette, aucun menu du monde ;
-- réponses identifiées par requestId, envoi jamais réactivé par un simple
-- délai, sélection de retour de l'éditeur, mort du joueur, étage du tracé,
-- couche recalée sur l'écran.

local T = {}

-- ----------------------------------------------------------------------------
-- Interface simulée (ISUIElement et dérivés, ISAdminPanelUI)
-- ----------------------------------------------------------------------------

local function setupUI()
    UI = {}
    DRAWN = {}
    local Base = {}
    Base.__index = Base
    function Base:derive(name)
        local class = setmetatable({}, { __index = self })
        class.__index = class
        class.Type = name
        return class
    end
    function Base.new(class, x, y, w, h)
        local o = setmetatable({}, class)
        o.x, o.y, o.width, o.height = x or 0, y or 0, w or 0, h or 0
        o.children, o.visible = {}, true
        return o
    end
    local noop = function() end
    for _, name in ipairs({ "instantiate", "bringToTop", "setWantKeyEvents", "setResizable", "drawRect",
        "drawRectBorder", "drawTextRight", "drawMouseOverHighlight", "renderJoypadFocus", "clearISButtons",
        "clearJoypadFocus", "restoreJoypadFocus", "onLoseJoypadFocus", "onJoypadDown", "onJoypadDirUp",
        "onJoypadDirDown", "onJoypadDirLeft", "onJoypadDirRight", "prerender", "render", "enableCancelColor",
        "enableAcceptColor", "ensureVisible" }) do
        Base[name] = noop
    end
    function Base:initialise() end
    function Base:createChildren() end
    function Base:addChild(child)
        child.parent = self
        self.children[#self.children + 1] = child
    end
    function Base:getChildren() return self.children end
    function Base:setVisible(visible) self.visible = visible end
    function Base:getIsVisible() return self.visible end
    function Base:isReallyVisible() return self.visible and self.inUI == true end
    function Base:addToUIManager()
        UI[#UI + 1] = self
        self.inUI = true
        if not self.created then
            self.created = true
            self:createChildren()
        end
    end
    function Base:removeFromUIManager()
        self.inUI = false
        for i = #UI, 1, -1 do
            if UI[i] == self then
                table.remove(UI, i)
            end
        end
    end
    function Base:backMost() self.isBackMost = true end
    function Base:setX(x) self.x = x end
    function Base:setY(y) self.y = y end
    function Base:setWidth(w) self.width = w end
    function Base:setHeight(h) self.height = h end
    function Base:getWidth() return self.width end
    function Base:getHeight() return self.height end
    function Base:getYScroll() return 0 end
    function Base:isMouseOver() return false end
    function Base:titleBarHeight() return 16 end
    function Base:drawText(text) DRAWN[#DRAWN + 1] = text end
    function Base:drawTextCentre(text) DRAWN[#DRAWN + 1] = text end
    function Base:setEnable(enable) self.enable = enable end
    function Base:setTitle(title) self.title = title end
    function Base:setISButtonForA(b) self.buttonA = b end
    function Base:setISButtonForB(b) self.buttonB = b end
    function Base:setISButtonForX(b) self.buttonX = b end
    function Base:setISButtonForY(b) self.buttonY = b end
    function Base:onGainJoypadFocus(joypadData) self.joyfocus = joypadData end
    function Base:insertNewLineOfButtons(...)
        self.joypadButtonsY[#self.joypadButtonsY + 1] = { ... }
    end

    ISUIElement = Base
    ISPanel = Base:derive("ISPanel")
    ISPanelJoypad = Base:derive("ISPanelJoypad")
    ISCollapsableWindowJoypad = ISPanelJoypad:derive("ISCollapsableWindowJoypad")

    ISButton = Base:derive("ISButton")
    function ISButton:new(x, y, w, h, title, target, onclick)
        local o = Base.new(self, x, y, w, h)
        o.title, o.target, o.onclick, o.enable = title, target, onclick, true
        return o
    end
    function ISButton:forceClick()
        assertTrue(self.enable ~= false, "bouton actif : " .. tostring(self.title))
        return self.onclick(self.target, self)
    end

    ISScrollingListBox = Base:derive("ISScrollingListBox")
    function ISScrollingListBox:new(x, y, w, h)
        local o = Base.new(self, x, y, w, h)
        o.items, o.selected = {}, -1
        return o
    end
    function ISScrollingListBox:setFont() end
    function ISScrollingListBox:clear() self.items = {} end
    function ISScrollingListBox:addItem(text, item)
        self.items[#self.items + 1] = { text = text, item = item, index = #self.items + 1 }
    end

    ISTextEntryBox = Base:derive("ISTextEntryBox")
    function ISTextEntryBox:new(title, x, y, w, h)
        local o = Base.new(self, x, y, w, h)
        o.text = title
        return o
    end
    function ISTextEntryBox:getText() return self.text end
    function ISTextEntryBox:setText(text) self.text = text end
    function ISTextEntryBox:setMaxTextLength(n) self.maxLength = n end
    function ISTextEntryBox:setOnlyNumbers(b) self.onlyNumbers = b end
    function ISTextEntryBox:isFocused() return self.focused == true end
    function ISTextEntryBox:unfocus() self.focused = false end

    ISComboBox = Base:derive("ISComboBox")
    function ISComboBox:new(x, y, w, h, target, onChange)
        local o = Base.new(self, x, y, w, h)
        o.options, o.selected, o.target, o.onChange = {}, 0, target, onChange
        return o
    end
    function ISComboBox:clear() self.options, self.selected = {}, 0 end
    function ISComboBox:addOptionWithData(text, data) self.options[#self.options + 1] = { text = text, data = data } end
    function ISComboBox:getOptionData(i) return self.options[i] and self.options[i].data end
    --- Choix de l'option de texte donné, comme un clic dans la liste.
    function ISComboBox:pick(text)
        for i, option in ipairs(self.options) do
            if option.text == text then
                self.selected = i
                return self.onChange(self.target, self)
            end
        end
        error("option absente : " .. text)
    end

    MODALS = {}
    ISModalDialog = Base:derive("ISModalDialog")
    function ISModalDialog:new(x, y, w, h, text, yesno, target, onclick, player, p1, p2)
        local o = Base.new(self, x, y, w, h)
        o.text, o.target, o.onclick, o.param1, o.param2 = text, target, onclick, p1, p2
        MODALS[#MODALS + 1] = o
        return o
    end
    function ISModalDialog:destroy() self.destroyed = true end
    function ISModalDialog:answer(internal)
        self:destroy()
        self.onclick(self.target, { internal = internal }, self.param1, self.param2)
    end

    -- Panneau d'admin : comme ISAdminPanelUI:create (boutons, puis rangement
    -- par titre de tous les enfants) et :updateButtons.
    ISAdminPanelUI = ISPanel:derive("ISAdminPanelUI")
    function ISAdminPanelUI:initialise()
        self:create()
    end
    function ISAdminPanelUI:create()
        for _, title in ipairs({ "IGUI_AdminPanel_NonPvpZone", "IGUI_AdminPanel_SeeSafehouses" }) do
            self:addChild(ISButton:new(0, 0, 200, 20, title, self, function() end))
        end
        self.layout = {}
        for _, child in ipairs(self:getChildren()) do
            self.layout[#self.layout + 1] = child.title
        end
        table.sort(self.layout)
        self:updateButtons()
    end
    function ISAdminPanelUI:updateButtons()
        self.vanillaUpdated = (self.vanillaUpdated or 0) + 1
    end
    function ISAdminPanelUI:new()
        local o = ISPanel.new(self, 200, 200, 350, 400)
        o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
        return o
    end
    ISWorldObjectContextMenu = { disableWorldMenu = false }
end

--- Panneau d'admin ouvert ; renvoie le panneau et le bouton du mod (ou nil).
local function openAdminPanel()
    local panel = ISAdminPanelUI:new()
    panel:initialise()
    for _, child in ipairs(panel:getChildren()) do
        if child.internal == "MILITARYDROP_ZONES" then
            return panel, child
        end
    end
    return panel, nil
end

--- Menu de debug : le vrai ISDebugMenu.lua 42.21 si le jeu est installé,
--- sinon une copie de son comportement (setupButtons appelé par
--- createChildren sur une liste vide, tri par titre, deux « Fermer » ajoutés
--- après le tri, ISDebugMenu:onClick qui appelle func() sans argument).
local function setupDebugMenu()
    getCore = function() return { getDebug = function() return DEBUG end } end
    PZAPI = { UI = {} }
    -- Comparaison de chaînes de Kahlua (StringLib) : vrai si a > b.
    string.sort = function(a, b) return a > b end
    function ISUIElement:getX() return self.x end
    function ISUIElement:getY() return self.y end
    function ISUIElement:ignoreWidthChange() end
    ISLabel = ISUIElement:derive("ISLabel")
    function ISLabel:new(x, y, h, title)
        local o = ISUIElement.new(self, x, y, 0, h)
        o.title = title
        return o
    end
    if hasVanilla and loadVanilla("client/DebugUIs/DebugMenu/ISDebugUtils.lua")
        and loadVanilla("client/DebugUIs/DebugMenu/ISDebugMenu.lua") then
        return
    end
    ISDebugMenu = ISPanel:derive("ISDebugMenu")
    ISDebugMenu.forceEnable = false
    function ISDebugMenu:setupButtons()
        self:addButtonInfo(getText("IGUI_DebugMenu_Main_General"), function() end, "MAIN")
        self:addButtonInfo(getText("IGUI_DebugMenu_Main_Sandbox"), function() end, "MAIN")
        self:addButtonInfo(getText("IGUI_DebugMenu_Dev_Audio"), function() end, "DEV")
        table.sort(self.buttons, function(a, b) return string.sort(b.title, a.title) end)
        self:addButtonInfo(getText("IGUI_DebugMenu_Close"), nil, "MAIN")
        self:addButtonInfo(getText("IGUI_DebugMenu_Close"), nil, "DEV")
    end
    function ISDebugMenu:addButtonInfo(title, func, tab, marginTop)
        self.buttons = self.buttons or {}
        local info = { title = title, func = func, tab = tab, marginTop = marginTop or 0 }
        table.insert(self.buttons, info)
        return info
    end
    function ISDebugMenu:createChildren()
        self.buttons = {}
        self:setupButtons()
        for _, info in ipairs(self.buttons) do
            local button = ISButton:new(0, 0, 200, 20, info.title, self, ISDebugMenu.onClick)
            button.customData = info
            self:addChild(button)
        end
    end
    function ISDebugMenu:onClick(button)
        if button.customData.func then
            button.customData.func()
        end
    end
    function ISDebugMenu.OnOpenPanel()
        if getCore():getDebug() or ISDebugMenu.forceEnable then
            if not ISDebugMenu.instance then
                ISDebugMenu.instance = ISDebugMenu:new(100, 100, 200, 20)
                ISDebugMenu.instance:initialise()
            end
            ISDebugMenu.instance:addToUIManager()
            return ISDebugMenu.instance
        end
    end
end

--- Menu de debug ouvert (nouvelle instance) ; renvoie le menu, l'indice de
--- l'entrée du mod dans menu.buttons et son bouton (ou nil).
local function openDebugMenu()
    if ISDebugMenu.instance then
        ISDebugMenu.instance:removeFromUIManager()
        ISDebugMenu.instance = nil
    end
    local menu = ISDebugMenu.OnOpenPanel()
    if not menu then
        return nil
    end
    local index
    for i, info in ipairs(menu.buttons) do
        if info.militaryDropZones then
            index = i
        end
    end
    for _, child in ipairs(menu:getChildren()) do
        if child.customData and child.customData.militaryDropZones then
            return menu, index, child
        end
    end
    return menu, index, nil
end

-- ----------------------------------------------------------------------------
-- Mise en place
-- ----------------------------------------------------------------------------

function T.setup()
    SandboxVars = {}
    CLIENT, DEBUG = true, false
    isClient = function() return CLIENT end
    isServer = function() return false end
    isDebugEnabled = function() return DEBUG end
    NOW = 1000
    getTimestampMs = function() return NOW end
    getText = function(key, ...)
        local parts = { key }
        for _, value in ipairs({ ... }) do
            parts[#parts + 1] = tostring(value)
        end
        return table.concat(parts, "|")
    end
    getTextOrNull = getText
    Capability = { ChangeAndReloadServerOptions = "reload", TeleportToCoordinates = "teleport" }
    CAPS = { reload = true, teleport = true }
    -- Étage du joueur (LEVEL) ; personnage courant du joueur 0 (PLAYER,
    -- remplacé par un nouveau personnage après une mort).
    LEVEL = 0
    PLAYER = {
        getPlayerNum = function() return 0 end,
        getRole = function() return { hasCapability = function(_, cap) return CAPS[cap] == true end } end,
        getX = function() return 50.5 end,
        getY = function() return 60.5 end,
        getZ = function() return LEVEL end,
        isDead = function(self) return self.dead == true end,
        getCurrentSquare = function()
            return { getX = function() return 50 end, getY = function() return 60 end, getZ = function() return LEVEL end }
        end,
        teleportTo = function(self, x, y, z) self.teleported = { x = x, y = y, z = z } end,
    }
    getSpecificPlayer = function(n) return n == 0 and PLAYER or nil end
    getPlayer = function() return PLAYER end
    SENT = {}
    MilitaryDrop = nil
    sendClientCommand = function(_, module, command, args)
        SENT[#SENT + 1] = { module = module, command = command, args = args }
    end
    TELEPORT = nil
    SendCommandToServer = function(text) TELEPORT = text end
    JoypadState = { players = {} }
    JOYPAD = nil
    getJoypadData = function() return JOYPAD end
    setJoypadFocus = function(_, element) FOCUS = element end
    HIGHLIGHTS = {}
    addAreaHighlightForPlayer = function(playerNum, x1, y1, x2, y2, z, r, g, b, a)
        HIGHLIGHTS[#HIGHLIGHTS + 1] = { playerNum = playerNum, x1 = x1, y1 = y1, x2 = x2, y2 = y2, z = z, r = r, a = a }
    end
    -- Souris : case du niveau 0 visée (MOUSE) et boutons tenus. À l'étage z,
    -- la case vue au même point de l'écran est décalée de 3 z cases en x et
    -- en y (projection isométrique) ; ISO_Z : étages demandés.
    MOUSE, BUTTONS, ISO_Z = { x = 0.5, y = 0.5 }, {}, {}
    getMouseX = function() return 0 end
    getMouseY = function() return 0 end
    screenToIsoX = function(_, _, _, z) ISO_Z[#ISO_Z + 1] = z return MOUSE.x + 3 * z end
    screenToIsoY = function(_, _, _, z) return MOUSE.y + 3 * z end
    isMouseButtonDown = function(n) return BUTTONS[n] == true end
    SCREEN = { w = 1920, h = 1080 }
    getPlayerScreenLeft = function() return 0 end
    getPlayerScreenTop = function() return 0 end
    getPlayerScreenWidth = function() return SCREEN.w end
    getPlayerScreenHeight = function() return SCREEN.h end
    UIFont = { Small = "Small", Medium = "Medium" }
    getTextManager = function()
        return {
            MeasureStringX = function(_, _, text) return #text * 7 end,
            getFontHeight = function() return 14 end,
        }
    end
    Keyboard = { KEY_ESCAPE = 1 }
    Joypad = { AButton = 0, BButton = 1, XButton = 2, YButton = 3 }
    instanceof = function() return false end
    setupUI()
    setupDebugMenu()
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_Client.lua")
    MilitaryDrop.Server = { onClientCommand = function(module, command, _, args)
        SENT[#SENT + 1] = { module = module, command = command, args = args }
    end }
    BASE_LISTENERS = { menu = listenerCount("OnFillWorldObjectContextMenu"), draw = listenerCount("OnPreUIDraw") }
    loadMod("client/MilitaryDrop/MilitaryDrop_ZonesAdmin.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_ZonesWindow.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_ZoneEditor.lua")
end

-- ----------------------------------------------------------------------------
-- Outils
-- ----------------------------------------------------------------------------

local function lastSent()
    return SENT[#SENT]
end

local function listReply(args)
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "ZoneListReply", args)
end

local function zoneReply(args)
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "ZoneReply", args)
end

local ZONES = {
    { id = "z1", sector = "Riverside", name = "Docks", x1 = 6400, y1 = 5400, x2 = 6420, y2 = 5410, weight = 2,
      enabled = true, active = true },
    { id = "z2", sector = "Louisville", name = "Central Park", x1 = 12900, y1 = 2100, x2 = 12980, y2 = 2160,
      enabled = false, active = false },
}

--- Liste ouverte depuis le panneau d'admin, avec deux zones connues.
local function openWindow()
    local _, button = openAdminPanel()
    button:forceClick()
    listReply({ zones = ZONES, sectors = { "Riverside" }, map = "Muldraugh, KY", mapLoaded = true, placement = 2 })
    return MilitaryDrop.ZonesWindow.instance
end

local function editor()
    return MilitaryDrop.ZoneEditor.instance
end

local function frame()
    editor():prerender()
end

local function aim(x, y)
    MOUSE.x, MOUSE.y = x + 0.4, y + 0.7
end

--- Appui gauche sur la case (x, y) du monde : reçu par la couche de tracé.
local function press(x, y)
    aim(x, y)
    BUTTONS[0] = true
    local layer = editor().layer
    assertTrue(layer and layer.inUI, "couche de tracé posée")
    return layer:onMouseDown(10, 10)
end

local function release(x, y)
    aim(x, y)
    BUTTONS[0] = false
    return editor().layer:onMouseUp(10, 10)
end

local function rectOf(r)
    return r.x1 .. "," .. r.y1 .. "," .. r.x2 .. "," .. r.y2
end

local function selectZone(window, id)
    for i, item in ipairs(window.list.items) do
        if item.item.kind == "zone" and item.item.zone.id == id then
            window.list.selected = i
            return
        end
    end
    error("zone absente de la liste : " .. id)
end

-- ----------------------------------------------------------------------------
-- Bouton du panneau d'admin
-- ----------------------------------------------------------------------------

function T.admin_panel_button_is_absent_without_the_right()
    CAPS = { teleport = true }
    local _, button = openAdminPanel()
    assertEq(button, nil, "client MP sans ChangeAndReloadServerOptions : pas de bouton")
    CLIENT, DEBUG = false, false
    _, button = openAdminPanel()
    assertEq(button, nil, "solo hors mode debug : pas de bouton")
    CLIENT, CAPS = true, { reload = true }
    local panel
    panel, button = openAdminPanel()
    assertTrue(button ~= nil, "admin MP : bouton")
    assertEq(button.title, "IGUI_MilitaryDrop_AdminPanelZones", "libellé")
    assertEq(#panel.layout, 3, "rangé avec les boutons vanilla par ISAdminPanelUI:create")
    assertEq(panel.vanillaUpdated, 1, "updateButtons vanilla appelé")
    assertEq(button.enable, true, "actif")
    CAPS = {}
    panel:updateButtons()
    assertEq(button.enable, false, "droit perdu : grisé")
    assertEq(panel.vanillaUpdated, 2, "original toujours appelé")
    CAPS = { reload = true }
    button.enable = true
    button:forceClick()
    assertTrue(MilitaryDrop.ZonesWindow.instance ~= nil, "liste ouverte")
    assertEq(lastSent().command, "ZoneList", "liste demandée")
    assertEq(lastSent().module, "MilitaryDrop", "module du mod")
end

function T.no_world_context_menu_and_reloads_do_not_stack()
    assertEq(listenerCount("OnFillWorldObjectContextMenu"), BASE_LISTENERS.menu, "plus de menu du monde")
    assertEq(listenerCount("OnPreUIDraw"), BASE_LISTENERS.draw, "contours dessinés par les fenêtres seulement")
    local starts = listenerCount("OnGameStart")
    loadMod("client/MilitaryDrop/MilitaryDrop_ZonesWindow.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_ZoneEditor.lua")
    assertEq(listenerCount("OnGameStart"), starts, "installation inscrite une fois")
    local panel = openAdminPanel()
    local count = 0
    for _, child in ipairs(panel:getChildren()) do
        if child.internal == "MILITARYDROP_ZONES" then
            count = count + 1
        end
    end
    assertEq(count, 1, "enveloppe posée une seule fois")
    assertEq(panel.vanillaUpdated, 1, "updateButtons enveloppé une seule fois")
end

-- ----------------------------------------------------------------------------
-- Entrée du menu de debug (solo, mode debug)
-- ----------------------------------------------------------------------------

function T.debug_menu_entry_opens_the_list_in_solo_debug()
    CLIENT, DEBUG = false, true
    local menu, index, button = openDebugMenu()
    assertTrue(menu ~= nil, "menu de debug ouvert")
    assertTrue(button ~= nil, "solo en mode debug : entrée présente")
    assertEq(button.title, "IGUI_MilitaryDrop_AdminPanelZones", "libellé du bouton du panneau d'admin")
    local info = menu.buttons[index]
    assertEq(info.tab, "MAIN", "onglet principal")
    local close = getText("IGUI_DebugMenu_Close")
    local last
    for i, entry in ipairs(menu.buttons) do
        if entry.tab == "MAIN" then
            last = i
        end
        assertTrue(entry.title ~= close or i > index, "entrée avant les boutons « Fermer »")
        if i > 1 and entry.title ~= close then
            -- Tri vanilla par titre (« General » remonté en tête).
            assertEq(i < index, entry.title < info.title, "triée avec les boutons vanilla : " .. entry.title)
        end
    end
    assertEq(menu.buttons[last].title, close, "« Fermer » reste le dernier bouton de l'onglet")
    button:forceClick()
    assertTrue(MilitaryDrop.ZonesWindow.instance ~= nil, "liste ouverte")
    assertEq(lastSent().command, "ZoneList", "liste demandée")
    assertTrue(ISDebugMenu.instance == menu, "menu de debug laissé ouvert")
end

function T.debug_menu_entry_is_absent_outside_debug_and_in_mp()
    CLIENT, DEBUG = false, false
    ISDebugMenu.forceEnable = true
    local menu, index, button = openDebugMenu()
    assertTrue(menu ~= nil, "menu forcé en solo hors debug (ISDebugMenu.forceEnable)")
    assertEq(index, nil, "solo hors mode debug : pas d'entrée")
    assertEq(button, nil, "solo hors mode debug : pas de bouton")
    ISDebugMenu.forceEnable = false
    CLIENT, DEBUG = true, true
    menu, index, button = openDebugMenu()
    assertTrue(menu ~= nil, "client MP en -debug : menu de debug présent")
    assertEq(index, nil, "MP : pas d'entrée (panneau d'admin)")
    assertEq(button, nil, "MP : pas de bouton")
    CLIENT, DEBUG = false, true
    MilitaryDrop.ZonesWindow.onDebugMenuButton()
    CLIENT = true
    assertTrue(MilitaryDrop.ZonesWindow.instance ~= nil, "contrôle témoin : ouverture en solo debug")
end

function T.debug_menu_entry_is_added_once_after_reloads_and_other_wrappers()
    CLIENT, DEBUG = false, true
    loadMod("client/MilitaryDrop/MilitaryDrop_ZonesWindow.lua")
    -- Autre mod qui enveloppe setupButtons après le nôtre et reconstruit la liste.
    local previous = ISDebugMenu.setupButtons
    ISDebugMenu.setupButtons = function(self, ...)
        previous(self, ...)
        local kept = {}
        for _, info in ipairs(self.buttons) do
            if not info.militaryDropZones then
                kept[#kept + 1] = info
            end
        end
        self.buttons = kept
    end
    triggerEvent("OnGameStart")
    local menu, index = openDebugMenu()
    local count = 0
    for _, info in ipairs(menu.buttons) do
        if info.militaryDropZones then
            count = count + 1
        end
    end
    assertEq(count, 1, "une seule entrée")
    assertEq(menu.buttons[index + 1].title, getText("IGUI_DebugMenu_Close"), "remise avant « Fermer »")
    assertEq(menu.buttons[index + 1].tab, "MAIN", "« Fermer » de l'onglet principal")
end

-- ----------------------------------------------------------------------------
-- Tracé et ajout
-- ----------------------------------------------------------------------------

function T.drag_trace_sends_a_normalized_zone_add()
    local window = openWindow()
    window.addBtn:forceClick()
    local e = editor()
    assertTrue(e ~= nil, "éditeur ouvert")
    assertEq(window.visible, false, "liste masquée pendant l'ajout")
    assertTrue(e.layer.isBackMost, "couche au fond de la pile d'interface")
    assertEq(ISWorldObjectContextMenu.disableWorldMenu, true, "menu du monde coupé pendant le tracé")
    aim(130, 90)
    HIGHLIGHTS = {}
    frame()
    assertEq(rectOf(HIGHLIGHTS[#HIGHLIGHTS]), "130,90,131,91", "case survolée surlignée")
    assertEq(press(120, 80), true, "clic du coin 1 consommé")
    aim(100, 95)
    frame()
    assertEq(rectOf(e.trace:rect()), "100,80,120,95", "le rectangle suit la souris")
    assertEq(release(100, 95), true, "relâchement consommé")
    assertEq(e.trace, nil, "tracé terminé")
    assertEq(rectOf(e.rect), "100,80,120,95", "rectangle figé")
    assertEq(e.layer, nil, "couche retirée : la souris revient au jeu")
    assertEq(ISWorldObjectContextMenu.disableWorldMenu, false, "menu du monde rétabli")
    -- Formulaire : secteur connu, nom, poids.
    assertEq(e.sectorCombo.options[1].text, "Louisville", "secteurs triés")
    assertEq(e.sectorCombo.options[#e.sectorCombo.options].data, false, "nouveau secteur en dernier")
    assertEq(e.newSectorEntry.visible, false, "nom du nouveau secteur masqué")
    frame()
    assertEq(e.submitBtn.enable, false, "nom manquant : ajout grisé")
    e.nameEntry:setText(" Central Gate ")
    e.weightEntry:setText("3")
    frame()
    e.submitBtn:forceClick()
    local add = lastSent()
    assertEq(add.command, "ZoneAdd", "ZoneAdd")
    assertEq(add.args.sector, "Louisville", "secteur")
    assertEq(add.args.name, "Central Gate", "nom nettoyé")
    assertEq(rectOf(add.args), "100,80,120,95", "coins normalisés")
    assertEq(add.args.weight, 3, "poids")
    assertEq(type(add.args.requestId), "number", "numéro de requête")
    frame()
    assertEq(e.submitBtn.enable, false, "attente de la réponse : pas de double envoi")
    zoneReply({ ok = true, action = "add", id = "z3", warnings = { "noRoad" }, requestId = add.args.requestId })
    assertEq(editor(), nil, "éditeur fermé")
    assertEq(window.visible, true, "liste de retour")
    assertEq(window.status.fitted,
        "IGUI_MilitaryDrop_ZoneOk_add|z3 IGUI_MilitaryDrop_ZoneWarnings|IGUI_MilitaryDrop_ZoneWarn_noRoad",
        "succès et avertissement traduits")
    local zones = { ZONES[1], ZONES[2], { id = "z3", sector = "Louisville", name = "Central Gate", x1 = 100,
        y1 = 80, x2 = 120, y2 = 95, weight = 3, enabled = true, active = true } }
    listReply({ zones = zones, sectors = { "Louisville", "Riverside" } })
    assertEq(window:selectedZone().id, "z3", "zone ajoutée sélectionnée")
    assertEq(MilitaryDrop.ZoneEditor.lastSector, "Louisville", "secteur retenu pour le prochain ajout")
end

function T.two_click_trace_is_frozen_after_the_second_corner()
    local window = openWindow()
    window.addBtn:forceClick()
    local e = editor()
    press(10, 10)
    release(10, 10)
    assertEq(e.trace.state, "second", "clic simple : coin 1 fixé, second clic attendu")
    assertTrue(e.layer ~= nil, "souris toujours capturée")
    aim(30, 25)
    frame()
    assertEq(rectOf(e.trace:rect()), "10,10,30,25", "le coin 2 suit la souris")
    assertEq(press(30, 25), true, "second clic consommé")
    assertEq(rectOf(e.rect), "10,10,30,25", "rectangle figé au second clic")
    frame()
    assertTrue(e.layer ~= nil, "bouton encore tenu : la couche consomme aussi le relâchement")
    assertEq(release(30, 25), true, "relâchement consommé")
    assertEq(e.layer, nil, "couche retirée")
    -- Après le second coin : ni mouvement ni clic ne changent le rectangle.
    aim(500, 400)
    frame()
    e:onTracePress()
    e:onTraceRelease()
    BUTTONS[0] = true
    frame()
    BUTTONS[0] = false
    frame()
    assertEq(rectOf(e.rect), "10,10,30,25", "rectangle inchangé")
    assertEq(rectOf(e:currentRect()), "10,10,30,25", "rectangle affiché inchangé")
end

function T.release_over_another_window_still_ends_the_drag()
    openWindow().addBtn:forceClick()
    local e = editor()
    press(5, 5)
    -- Relâché au-dessus d'une fenêtre : la couche ne le reçoit pas.
    aim(9, 7)
    BUTTONS[0] = false
    frame()
    assertEq(rectOf(e.rect), "5,5,9,7", "fin du glisser vue à l'image suivante")
    assertEq(e.layer, nil, "couche retirée")
end

function T.right_click_and_escape_cancel_the_trace()
    local window = openWindow()
    window.addBtn:forceClick()
    local e = editor()
    press(10, 10)
    aim(20, 20)
    frame()
    BUTTONS[1] = true
    assertEq(e.layer:onRightMouseDown(0, 0), true, "clic droit consommé")
    assertEq(e.trace, nil, "tracé annulé")
    assertEq(e.rect, nil, "aucun rectangle")
    assertTrue(e.layer ~= nil, "couche gardée jusqu'au relâchement du clic droit")
    BUTTONS[0], BUTTONS[1] = false, false
    assertEq(e.layer:onRightMouseUp(0, 0), true, "relâchement consommé")
    assertEq(e.layer, nil, "puis retirée")
    assertEq(editor(), e, "l'éditeur reste ouvert")
    frame()
    -- Nouveau tracé, puis Échap : tracé annulé ; second Échap : édition annulée.
    e.redrawBtn:forceClick()
    press(1, 1)
    assertEq(e:isKeyConsumed(Keyboard.KEY_ESCAPE), true, "Échap consommé (pas de menu du jeu)")
    BUTTONS[0] = false
    e:onKeyRelease(Keyboard.KEY_ESCAPE)
    assertEq(e.trace, nil, "Échap : tracé annulé")
    assertEq(editor(), e, "éditeur encore ouvert")
    e:onKeyRelease(Keyboard.KEY_ESCAPE)
    assertEq(editor(), nil, "second Échap : éditeur fermé")
    assertEq(window.visible, true, "liste de retour")
    for _, sent in ipairs(SENT) do
        assertTrue(sent.command ~= "ZoneAdd", "rien envoyé")
    end
end

function T.rectangle_larger_than_300_squares_is_refused()
    openWindow().addBtn:forceClick()
    local e = editor()
    e.nameEntry:setText("Big")
    press(1000, 2000)
    release(1300, 2010)
    assertEq(rectOf(e.rect), "1000,2000,1300,2010", "301 x 11")
    HIGHLIGHTS, DRAWN = {}, {}
    frame()
    assertEq(e.submitBtn.enable, false, "ajout grisé")
    assertEq(HIGHLIGHTS[#HIGHLIGHTS].r, MilitaryDrop.ZonesAdmin.COLORS.tooBig[1], "contour rouge")
    local found = false
    for _, text in ipairs(DRAWN) do
        found = found or text == "IGUI_MilitaryDrop_ZoneTooBigTip|300"
    end
    assertTrue(found, "motif affiché")
    e:onSubmit()
    assertEq(lastSent().command, "ZoneList", "rien envoyé, même au clic forcé")
    e.redrawBtn:forceClick()
    press(1000, 1701)
    release(1299, 2000)
    frame()
    assertEq(e.submitBtn.enable, true, "300 x 300 accepté")
end

function T.new_sector_is_typed_in_the_panel()
    openWindow().addBtn:forceClick()
    local e = editor()
    press(1, 1)
    release(4, 4)
    e.sectorCombo:pick("IGUI_MilitaryDrop_ZoneNewSector")
    assertEq(e.newSectorEntry.visible, true, "champ du nouveau secteur affiché")
    e.nameEntry:setText("Mall")
    frame()
    assertEq(e.submitBtn.enable, false, "secteur vide refusé")
    e.newSectorEntry:setText("Raven <b>Creek")
    frame()
    assertEq(e.submitBtn.enable, false, "balises refusées")
    e.newSectorEntry:setText("Raven Creek")
    frame()
    e.submitBtn:forceClick()
    assertEq(lastSent().args.sector, "Raven Creek", "nouveau secteur")
    assertEq(lastSent().args.weight, 1, "poids par défaut")
end

-- ----------------------------------------------------------------------------
-- Modification
-- ----------------------------------------------------------------------------

function T.edit_sends_only_the_changed_fields()
    local window = openWindow()
    selectZone(window, "z1")
    window.editBtn:forceClick()
    local e = editor()
    assertEq(e.trace, nil, "modification : pas de tracé d'office")
    assertEq(e.nameEntry:getText(), "Docks", "nom de la zone")
    assertEq(e.weightEntry:getText(), "2", "poids de la zone")
    assertEq(e.sectorCombo:getOptionData(e.sectorCombo.selected), "Riverside", "secteur de la zone")
    HIGHLIGHTS = {}
    frame()
    assertEq(rectOf(HIGHLIGHTS[#HIGHLIGHTS]), "6400,5400,6421,5411", "zone surlignée (fin exclusive)")
    assertEq(e.submitBtn.enable, false, "rien changé : enregistrement grisé")
    e.nameEntry:setText("North Docks")
    e.weightEntry:setText("5")
    frame()
    e.submitBtn:forceClick()
    local update = lastSent()
    assertEq(update.command, "ZoneUpdate", "ZoneUpdate")
    assertEq(update.args.id, "z1", "id")
    assertEq(update.args.name, "North Docks", "nouveau nom")
    assertEq(update.args.weight, 5, "nouveau poids")
    assertEq(update.args.sector, nil, "secteur inchangé : absent")
    assertEq(update.args.x1, nil, "rectangle inchangé : absent")
    -- Refus du serveur : affiché dans l'éditeur, qui reste ouvert.
    zoneReply({ ok = false, action = "update", id = "z1", error = "busy", requestId = update.args.requestId })
    assertEq(editor(), e, "éditeur ouvert")
    assertEq(e.serverStatus.text, "IGUI_MilitaryDrop_ZoneErr_busy", "refus traduit")
    frame()
    assertEq(e.submitBtn.enable, true, "nouvel essai possible")
    -- Retracé : le rectangle entier part, l'ancien reste affiché en gris.
    e.redrawBtn:forceClick()
    press(6430, 5420)
    HIGHLIGHTS = {}
    aim(6400, 5400)
    frame()
    assertEq(rectOf(HIGHLIGHTS[1]), "6400,5400,6421,5411", "ancienne zone en gris")
    assertEq(HIGHLIGHTS[1].r, MilitaryDrop.ZonesAdmin.COLORS.previous[1], "couleur de l'ancienne zone")
    release(6400, 5400)
    e.nameEntry:setText("Docks")
    e.weightEntry:setText("2")
    frame()
    e.submitBtn:forceClick()
    update = lastSent()
    assertEq(rectOf(update.args), "6400,5400,6430,5420", "rectangle retracé")
    assertEq(update.args.name, nil, "nom inchangé")
    zoneReply({ ok = true, action = "update", id = "z1", requestId = update.args.requestId })
    assertEq(editor(), nil, "éditeur fermé")
    assertEq(window.status.fitted, "IGUI_MilitaryDrop_ZoneOk_update|z1", "succès")
end

function T.cancelled_retrace_restores_the_zone_rectangle()
    local window = openWindow()
    selectZone(window, "z1")
    window.editBtn:forceClick()
    local e = editor()
    e.redrawBtn:forceClick()
    press(1, 1)
    BUTTONS[1] = true
    e.layer:onRightMouseDown(0, 0)
    assertEq(rectOf(e.rect), "6400,5400,6420,5410", "rectangle de la zone rétabli")
    e.cancelBtn:forceClick()
    assertEq(editor(), nil, "annulé")
    assertEq(window:selectedZone().id, "z1", "zone toujours sélectionnée")
end

-- ----------------------------------------------------------------------------
-- Liste, réponses, contours
-- ----------------------------------------------------------------------------

function T.list_reply_is_cleaned_and_every_error_code_is_translated()
    local Admin = MilitaryDrop.ZonesAdmin
    local window = openWindow()
    listReply({
        zones = {
            { id = "z1", sector = "<RGB:1,0,0>Louisville", name = "Central\nPark", x1 = 20, y1 = 30, x2 = 10, y2 = 5,
              weight = 2, enabled = true, active = true, warnings = { "risk" } },
            { id = "z2", sector = "Louisville", name = string.rep("N", 50), x1 = 1, y1 = 1, x2 = 2, y2 = 2,
              enabled = false, active = false },
            { id = "bad", sector = "X", name = "Y" },
        },
        sectors = { "Louisville" }, map = "Muldraugh, KY", mapLoaded = true, placement = 2,
        problems = { "zone #3 (z3): bad <rectangle>" },
    })
    local list = Admin.list
    assertEq(#list.zones, 2, "zone sans coordonnées écartée")
    local z1 = list.zones[1]
    assertEq(z1.sector, "RGB:1,0,0Louisville", "sans < >")
    assertEq(z1.name, "CentralPark", "sans caractère de contrôle")
    assertEq(rectOf(z1), "10,5,20,30", "rectangle normalisé")
    assertEq(z1.width, 11, "largeur incluse")
    assertEq(#list.zones[2].name, 32, "nom coupé à 32")
    assertEq(list.problems[1], "zone #3 (z3): bad rectangle", "problème nettoyé")
    assertEq(#list.sectors, 2, "secteurs reçus et secteurs des zones")
    for code in pairs(Admin.ERRORS) do
        zoneReply({ ok = false, action = "enable", error = code })
        assertEq(window.status.fitted, "IGUI_MilitaryDrop_ZoneErr_" .. code, "erreur " .. code)
    end
    zoneReply({ ok = false, error = "surprise" })
    assertEq(window.status.fitted, "IGUI_MilitaryDrop_ZoneErr_other", "code inconnu")
    for code in pairs(Admin.WARNINGS) do
        assertEq(Admin.warningText(code), "IGUI_MilitaryDrop_ZoneWarn_" .. code, "avertissement " .. code)
    end
    zoneReply({ ok = true, action = "delete", id = "z2" })
    assertEq(window.status.fitted, "IGUI_MilitaryDrop_ZoneOk_delete|z2", "suppression confirmée")
end

function T.list_buttons_send_the_commands()
    local window = openWindow()
    selectZone(window, "z1")
    window.toggleBtn:forceClick()
    assertEq(lastSent().command, "ZoneSetEnabled", "activer / désactiver")
    assertEq(lastSent().args.enabled, false, "zone active : désactivée")
    window.reloadBtn:forceClick()
    assertEq(lastSent().command, "ZoneReload", "rechargement")
    window.removeBtn:forceClick()
    local modal = MODALS[#MODALS]
    assertEq(modal.text, "IGUI_Designation_RemoveConfirm|Docks (z1)", "confirmation vanilla")
    modal:answer("NO")
    assertEq(lastSent().command, "ZoneReload", "non : rien envoyé")
    window.removeBtn:forceClick()
    MODALS[#MODALS]:answer("YES")
    assertEq(lastSent().command, "ZoneDelete", "suppression")
    assertEq(lastSent().args.id, "z1", "zone sélectionnée")
    -- Sélection sur un en-tête de secteur : boutons de zone grisés.
    window.list.selected = 1
    window:updateButtons()
    assertEq(window.editBtn.enable, false, "aucune zone sélectionnée")
end

function T.selected_zone_is_outlined_by_the_open_window_only()
    local window = openWindow()
    selectZone(window, "z2")
    HIGHLIGHTS = {}
    window:prerender()
    assertEq(#HIGHLIGHTS, 1, "zone sélectionnée seulement")
    assertEq(rectOf(HIGHLIGHTS[1]), "12900,2100,12981,2161", "fin exclusive")
    assertEq(HIGHLIGHTS[1].z, 0, "niveau 0")
    assertEq(HIGHLIGHTS[1].playerNum, 0, "joueur local seulement")
    assertEq(HIGHLIGHTS[1].r, MilitaryDrop.ZonesAdmin.COLORS.disabled[1], "désactivée en gris")
    -- Droit perdu : la fenêtre se ferme sans rien dessiner.
    CAPS = {}
    HIGHLIGHTS = {}
    window:prerender()
    assertEq(#HIGHLIGHTS, 0, "plus admin : aucun contour")
    assertEq(MilitaryDrop.ZonesWindow.instance, nil, "fenêtre fermée")
end

function T.joypad_trace_uses_the_dpad_and_a()
    JOYPAD = { player = 0 }
    JoypadState.players[1] = JOYPAD
    openWindow().addBtn:forceClick()
    local e = editor()
    assertEq(e.layer, nil, "manette : pas de couche souris")
    assertEq(e.joypadTrace, true, "tracé à la manette")
    e:onJoypadDirRight()
    e:onJoypadDirDown()
    e:onJoypadDown(Joypad.AButton)
    assertEq(e.trace.state, "second", "A : coin 1")
    for _ = 1, 4 do
        e:onJoypadDirRight()
    end
    e:onJoypadDown(Joypad.AButton)
    assertEq(rectOf(e.rect), "51,61,55,61", "A : coin 2, depuis la case du joueur")
    e:onJoypadDirRight()
    assertEq(rectOf(e.rect), "51,61,55,61", "figé ensuite")
    e.redrawBtn:forceClick()
    e:onJoypadDown(Joypad.BButton)
    assertEq(rectOf(e.rect), "51,61,55,61", "B : tracé annulé, rectangle précédent rétabli")
end

function T.go_to_uses_the_vanilla_admin_teleport()
    local zone = { x1 = 100, y1 = 80, x2 = 121, y2 = 95 }
    MilitaryDrop.ZonesAdmin.goTo(PLAYER, zone)
    assertEq(TELEPORT, "/teleportto 110,87,0", "commande serveur en MP")
    CLIENT = false
    MilitaryDrop.ZonesAdmin.goTo(PLAYER, zone)
    assertEq(PLAYER.teleported.x, 110.5, "solo : déplacement direct")
    assertEq(PLAYER.teleported.z, 0, "niveau 0")
    PLAYER.teleported = nil
    PLAYER.dead = true
    assertEq(MilitaryDrop.ZonesAdmin.goTo(PLAYER, zone), false, "personnage mort : refusé")
    assertEq(PLAYER.teleported, nil, "jamais téléporté")
    PLAYER.dead = false
    CLIENT, CAPS = true, { reload = true }
    assertEq(MilitaryDrop.ZonesAdmin.canTeleport(PLAYER), false, "MP sans TeleportToCoordinates")
end

function T.window_rows_are_grouped_by_sector_and_fitted()
    local Window = MilitaryDrop.ZonesWindow
    local list = MilitaryDrop.ZonesAdmin.normalizeList({
        zones = {
            { id = "z2", sector = "riverside", name = "Docks", x1 = 1, y1 = 1, x2 = 9, y2 = 9, enabled = true,
              active = true },
            { id = "z1", sector = "Louisville", name = string.rep("W", 32), x1 = 1, y1 = 1, x2 = 4, y2 = 2,
              enabled = true, active = false, warnings = { "mapNotLoaded" } },
        },
        problems = { "zone #4: syntax" },
    })
    local rows = Window.buildRows(list, 400)
    assertEq(rows[1].kind, "sector", "en-tête de secteur")
    assertEq(rows[1].lines[1], "Louisville", "secteurs sans casse")
    assertEq(rows[2].zone.id, "z1", "zone du secteur")
    assertTrue(#rows[2].lines[1] * 7 <= 400 - 16, "nom coupé à la largeur")
    assertTrue(rows[2].lines[1]:sub(-3) == "...", "coupure marquée")
    assertEq(rows[2].state, "IGUI_MilitaryDrop_ZoneStateMapNotLoaded", "carte non chargée")
    assertEq(rows[2].lines[3], "IGUI_MilitaryDrop_ZoneWarn_mapNotLoaded", "avertissement traduit")
    assertEq(rows[3].lines[1], "riverside", "second secteur")
    assertEq(rows[4].state, "IGUI_MilitaryDrop_ZoneStateActive", "zone active")
    assertEq(rows[5].lines[1], "IGUI_MilitaryDrop_ZoneProblems", "problèmes du fichier")
    assertEq(rows[6].lines[1], "zone #4: syntax", "problème")
    local empty = Window.buildRows(MilitaryDrop.ZonesAdmin.normalizeList({}), 400)
    assertEq(empty[1].lines[1], "IGUI_MilitaryDrop_ZoneNone", "liste vide : indication")
end

-- ----------------------------------------------------------------------------
-- Constats de revue : sélection de retour, numéros de requête, délai, mort,
-- étage, taille de la couche
-- ----------------------------------------------------------------------------

--- Liste renvoyée par le serveur après une commande (numéro facultatif).
local function listAfter(requestId, zones)
    listReply({ zones = zones or ZONES, sectors = { "Riverside" }, map = "Muldraugh, KY", mapLoaded = true,
        placement = 2, requestId = requestId })
end

--- Ajout tracé et rempli, prêt à envoyer.
local function filledAdd(window)
    window.addBtn:forceClick()
    local e = editor()
    press(100, 80)
    release(120, 95)
    e.nameEntry:setText("Gate")
    frame()
    return e
end

local function drawnText(text)
    for _, drawn in ipairs(DRAWN) do
        if drawn == text then
            return true
        end
    end
    return false
end

function T.cancelled_edit_never_reselects_its_zone_after_another_action()
    local window = openWindow()
    selectZone(window, "z1")
    window.editBtn:forceClick()
    editor().cancelBtn:forceClick()
    assertEq(window:selectedZone().id, "z1", "annulation : zone sélectionnée tout de suite")
    assertEq(window.pendingSelect, nil, "aucune liste ne suit une annulation : rien en attente")
    selectZone(window, "z2")
    window:prerender()
    window.toggleBtn:forceClick()
    local toggle = lastSent()
    assertEq(toggle.args.id, "z2", "« Désactiver » vise la zone choisie")
    zoneReply({ ok = true, action = "enable", id = "z2", requestId = toggle.args.requestId })
    listAfter(toggle.args.requestId)
    assertEq(window:selectedZone().id, "z2", "la liste suivante garde la zone choisie")
    window.toggleBtn:forceClick()
    assertEq(lastSent().args.id, "z2", "l'action suivante vise encore la zone choisie")
end

function T.selection_changed_after_a_successful_edit_wins_over_the_pending_zone()
    local window = openWindow()
    selectZone(window, "z1")
    window.editBtn:forceClick()
    local e = editor()
    e.nameEntry:setText("North Docks")
    frame()
    e.submitBtn:forceClick()
    local update = lastSent()
    zoneReply({ ok = true, action = "update", id = "z1", requestId = update.args.requestId })
    assertEq(window.pendingSelect, "z1", "succès : zone resélectionnée par la liste qui suit")
    -- L'admin choisit une autre zone avant l'arrivée de la liste.
    selectZone(window, "z2")
    window:prerender()
    assertEq(window.pendingSelect, nil, "sélection changée : attente effacée")
    listAfter(update.args.requestId)
    assertEq(window:selectedZone().id, "z2", "choix de l'admin gardé")
    -- Même cas sans image entre le clic et la liste (contrôle dans refresh).
    selectZone(window, "z1")
    window.editBtn:forceClick()
    e = editor()
    e.nameEntry:setText("South Docks")
    frame()
    e.submitBtn:forceClick()
    update = lastSent()
    zoneReply({ ok = true, action = "update", id = "z1", requestId = update.args.requestId })
    selectZone(window, "z2")
    listAfter(update.args.requestId)
    assertEq(window:selectedZone().id, "z2", "choix de l'admin gardé par refresh")
    -- Contrôle témoin : sans changement, la zone ajoutée est sélectionnée.
    local added = filledAdd(window)
    added.submitBtn:forceClick()
    local add = lastSent()
    zoneReply({ ok = true, action = "add", id = "z3", requestId = add.args.requestId })
    local zones = { ZONES[1], ZONES[2], { id = "z3", sector = "Riverside", name = "Gate", x1 = 100, y1 = 80,
        x2 = 120, y2 = 95, weight = 1, enabled = true, active = true } }
    listAfter(add.args.requestId, zones)
    assertEq(window:selectedZone().id, "z3", "zone ajoutée sélectionnée")
end

function T.editor_takes_only_the_reply_to_its_own_request()
    local window = openWindow()
    local e = filledAdd(window)
    e.submitBtn:forceClick()
    local add = lastSent()
    assertEq(add.command, "ZoneAdd", "ZoneAdd")
    -- Réponse d'une autre commande de même action (autre éditeur, ancienne
    -- commande) ou sans numéro : laissée à la liste.
    zoneReply({ ok = true, action = "add", id = "z8", requestId = add.args.requestId + 7 })
    zoneReply({ ok = false, action = "add", error = "busy" })
    assertEq(editor(), e, "éditeur toujours ouvert")
    assertTrue(e:isWaiting(), "toujours en attente de sa réponse")
    assertEq(e.serverStatus, nil, "aucune réponse étrangère affichée dans l'éditeur")
    zoneReply({ ok = false, action = "add", error = "tooMany", requestId = add.args.requestId })
    assertEq(e.serverStatus.text, "IGUI_MilitaryDrop_ZoneErr_tooMany", "sa réponse est prise")
    assertEq(e:isWaiting(), false, "attente terminée")
    -- Numéros croissants, communs à toutes les commandes.
    window.reloadBtn.onclick(window)
    assertTrue(lastSent().args.requestId > add.args.requestId, "numéro suivant")
end

function T.add_is_never_resent_after_a_timeout_until_the_server_answers()
    local window = openWindow()
    local e = filledAdd(window)
    e.submitBtn:forceClick()
    local add = lastSent()
    NOW = NOW + MilitaryDrop.ZoneEditor.REPLY_TIMEOUT_MS + 1
    DRAWN = {}
    frame()
    local refresh = lastSent()
    assertEq(refresh.command, "ZoneList", "délai dépassé : liste redemandée")
    assertTrue(refresh.args.requestId > add.args.requestId, "numéro postérieur à l'ajout")
    assertEq(e.submitBtn.enable, false, "ajout toujours bloqué")
    assertTrue(drawnText("IGUI_MilitaryDrop_ZoneWaiting"), "« en attente du serveur »")
    local sent = #SENT
    frame()
    assertEq(#SENT, sent, "une demande par délai")
    -- Liste d'une commande antérieure : ne prouve rien, toujours bloqué.
    listAfter(add.args.requestId - 1)
    frame()
    assertEq(e.submitBtn.enable, false, "liste antérieure : toujours bloqué")
    e:onSubmit()
    assertEq(#SENT, sent, "aucun second ZoneAdd, même au clic forcé")
    -- Réponse en retard : traitée normalement.
    zoneReply({ ok = true, action = "add", id = "z3", requestId = add.args.requestId })
    assertEq(editor(), nil, "réponse tardive : éditeur fermé")
    assertEq(window.status.fitted, "IGUI_MilitaryDrop_ZoneOk_add|z3", "succès affiché")
    -- Réponse perdue : la liste de numéro supérieur débloque l'envoi.
    e = filledAdd(window)
    e.submitBtn:forceClick()
    add = lastSent()
    assertEq(add.command, "ZoneAdd", "second ajout")
    NOW = NOW + MilitaryDrop.ZoneEditor.REPLY_TIMEOUT_MS + 1
    frame()
    refresh = lastSent()
    assertTrue(refresh.args.requestId > add.args.requestId, "liste demandée après l'ajout")
    NOW = NOW + MilitaryDrop.ZoneEditor.REPLY_TIMEOUT_MS + 1
    frame()
    assertEq(lastSent().command, "ZoneList", "nouvelle demande au délai suivant")
    assertEq(e.submitBtn.enable, false, "toujours bloqué")
    listAfter(refresh.args.requestId)
    assertEq(e:isWaiting(), false, "serveur passé au-delà de l'ajout : attente levée")
    assertEq(e.serverStatus.text, "IGUI_MilitaryDrop_ZoneErr_other", "refus générique affiché")
    frame()
    assertEq(e.submitBtn.enable, true, "nouvel envoi possible")
end

function T.player_death_closes_the_editor_and_the_list()
    local window = openWindow()
    window.addBtn:forceClick()
    local e = editor()
    press(10, 10)
    local layer = e.layer
    PLAYER.dead = true
    triggerEvent("OnPlayerDeath", PLAYER)
    assertEq(editor(), nil, "OnPlayerDeath : éditeur fermé")
    assertEq(layer.inUI, false, "couche de tracé retirée")
    assertEq(ISWorldObjectContextMenu.disableWorldMenu, false, "menu du monde rétabli")
    assertEq(MilitaryDrop.ZonesWindow.instance, nil, "liste fermée")
    assertEq(window.inUI, false, "liste retirée de l'interface")
    -- Sans l'événement : mort vue dans prerender.
    PLAYER.dead = false
    window = openWindow()
    selectZone(window, "z1")
    window.editBtn:forceClick()
    assertTrue(editor() ~= nil, "éditeur ouvert")
    PLAYER.dead = true
    frame()
    assertEq(editor(), nil, "mort vue par l'éditeur : fermé")
    window:prerender()
    assertEq(MilitaryDrop.ZonesWindow.instance, nil, "mort vue par la liste : fermée")
    assertEq(MilitaryDrop.ZonesWindow.open(PLAYER), nil, "pas de liste pour un mort")
    assertEq(MilitaryDrop.ZoneEditor.open(PLAYER, nil), nil, "pas d'éditeur pour un mort")
end

function T.actions_always_target_the_current_character()
    CLIENT, DEBUG = false, true
    local window = openWindow()
    selectZone(window, "z1")
    local old = PLAYER
    old.dead = true
    window:onTeleport()
    assertEq(old.teleported, nil, "solo : l'ancien personnage mort n'est jamais téléporté")
    -- Nouveau personnage du même joueur.
    local fresh = {}
    for key, value in pairs(old) do
        fresh[key] = value
    end
    fresh.dead, fresh.teleported = false, nil
    PLAYER = fresh
    window:onTeleport()
    assertEq(fresh.teleported.x, 6410.5, "le personnage courant est téléporté")
    assertEq(old.teleported, nil, "jamais l'ancien")
    -- Fenêtre d'un personnage remplacé : fermée à l'image suivante, et
    -- rouverte pour le nouveau.
    window.player = old
    window:prerender()
    assertEq(MilitaryDrop.ZonesWindow.instance, nil, "personnage remplacé : liste fermée")
    local reopened = MilitaryDrop.ZonesWindow.open(PLAYER)
    assertEq(reopened.player, PLAYER, "nouvelle liste du personnage courant")
end

function T.trace_aims_and_draws_at_the_player_level()
    LEVEL = 2
    local window = openWindow()
    window.addBtn:forceClick()
    local e = editor()
    aim(100, 100)
    HIGHLIGHTS, ISO_Z = {}, {}
    frame()
    assertEq(ISO_Z[#ISO_Z], 2, "case visée à l'étage du joueur")
    assertEq(rectOf(HIGHLIGHTS[#HIGHLIGHTS]), "106,106,107,107", "case vue sous le curseur à l'étage 2")
    assertEq(HIGHLIGHTS[#HIGHLIGHTS].z, 2, "contour du curseur à l'étage du joueur")
    press(100, 100)
    release(110, 105)
    assertEq(rectOf(e.rect), "106,106,116,111", "rectangle des cases vues à l'étage 2")
    HIGHLIGHTS = {}
    frame()
    assertEq(HIGHLIGHTS[#HIGHLIGHTS].z, 2, "contour du tracé à l'étage du joueur")
    e.nameEntry:setText("Roof")
    frame()
    e.submitBtn:forceClick()
    local add = lastSent()
    assertEq(rectOf(add.args), "106,106,116,111", "zone enregistrée en x / y")
    assertEq(add.args.z, nil, "aucun étage envoyé (largage au niveau 0)")
    -- Liste : la zone sélectionnée reste dessinée au niveau 0.
    LEVEL = 0
end

function T.trace_layer_follows_the_player_screen_size()
    openWindow().addBtn:forceClick()
    local e = editor()
    local layer = e.layer
    assertEq(layer.width .. "x" .. layer.height, "1920x1080", "couche à la taille de l'écran")
    SCREEN.w, SCREEN.h = 1280, 720
    frame()
    assertEq(layer.width .. "x" .. layer.height, "1280x720", "résolution changée : couche recalée")
    press(3, 4)
    release(6, 8)
    assertEq(rectOf(e.rect), "3,4,6,8", "tracé toujours reçu")
end

return T
