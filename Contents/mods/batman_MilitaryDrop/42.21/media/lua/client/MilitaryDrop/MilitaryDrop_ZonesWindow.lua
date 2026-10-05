-- ============================================================================
-- Military Drop — fenêtre « Zones de largage » de l'admin (ZONE-03)
--
-- Liste de la dernière ZoneListReply (MilitaryDrop_ZonesAdmin.lua), groupée
-- par secteur : nom, identifiant, état (active, désactivée, carte non
-- chargée), coins, taille, poids et avertissements traduits ; en bas, les
-- problèmes du fichier relevés par le serveur (textes anglais du journal).
-- Boutons : Activer / Désactiver, Supprimer (second clic de confirmation
-- dans les DELETE_CONFIRM_MS, sans boîte modale), Aller à (téléportation
-- d'admin), Recharger, Fermer. La liste est redemandée à chaque ouverture ;
-- chaque réponse du serveur la remplace en gardant la zone sélectionnée.
--
-- Textes : drawText ne lit aucune balise ; les noms viennent déjà nettoyés
-- (ZonesAdmin.normalizeList) et chaque ligne est coupée à la largeur de la
-- liste (Window.fit), avec une marge pour AngelCodeFont.getWidth.
-- Clavier : Échap ferme (seule la fenêtre la plus haute qui consomme la
-- touche la reçoit, UIManager.java:1357-1363). Manette : la liste prend le
-- focus ; A active ou désactive, X va à la zone, Y recharge, B ferme (la
-- suppression reste à la souris).
-- ============================================================================

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "MilitaryDrop/MilitaryDrop_ZonesAdmin"

local ZonesAdmin = MilitaryDrop.ZonesAdmin

local Window = MilitaryDrop.ZonesWindow or {}
MilitaryDrop.ZonesWindow = Window

Window.WIDTH = 580
Window.HEIGHT = 460
Window.PAD = 8
Window.DELETE_CONFIRM_MS = 4000

local ZW = ISCollapsableWindow:derive("MilitaryDropZonesWindow")
Window.class = ZW

local COLOR_SECTOR = { 1.0, 0.8, 0.4 }
local COLOR_TEXT = { 0.95, 0.95, 0.95 }
local COLOR_DIM = { 0.7, 0.7, 0.7 }
local COLOR_WARN = { 1.0, 0.65, 0.2 }
local COLOR_OK = { 0.4, 0.9, 0.4 }
local COLOR_ERR = { 1.0, 0.4, 0.4 }

local function measure(text)
    return getTextManager():MeasureStringX(UIFont.Small, text)
end

local function fontHeight()
    return getTextManager():getFontHeight(UIFont.Small)
end

--- Texte coupé (avec « ... ») pour tenir dans width pixels.
function Window.fit(text, width)
    text = tostring(text or "")
    if measure(text) <= width then
        return text
    end
    local cut = text
    while cut ~= "" and measure(cut .. "...") > width do
        cut = MilitaryDrop.dropLastChar(cut)
    end
    return cut .. "..."
end

-- ----------------------------------------------------------------------------
-- Lignes de la liste
-- ----------------------------------------------------------------------------

local function stateOf(zone)
    if not zone.enabled then
        return getText("IGUI_MilitaryDrop_ZoneStateDisabled"), COLOR_DIM
    end
    if not zone.active then
        return getText("IGUI_MilitaryDrop_ZoneStateMapNotLoaded"), COLOR_WARN
    end
    return getText("IGUI_MilitaryDrop_ZoneStateActive"), COLOR_OK
end

local function lower(text)
    return string.lower(text or "")
end

--- Lignes affichées pour une liste reçue : { kind, zone?, lines, colors }.
--- width : largeur utile en pixels.
function Window.buildRows(list, width)
    local rows = {}
    local zones = {}
    for _, zone in ipairs(list.zones) do
        zones[#zones + 1] = zone
    end
    table.sort(zones, function(a, b)
        if lower(a.sector) ~= lower(b.sector) then
            return lower(a.sector) < lower(b.sector)
        end
        if lower(a.name) ~= lower(b.name) then
            return lower(a.name) < lower(b.name)
        end
        return a.id < b.id
    end)
    local sector = nil
    for _, zone in ipairs(zones) do
        if zone.sector ~= sector then
            sector = zone.sector
            rows[#rows + 1] = { kind = "sector", lines = { Window.fit(sector, width) }, colors = { COLOR_SECTOR } }
        end
        local state, stateColor = stateOf(zone)
        local stateWidth = measure(state) + 12
        local corners = zone.x1 .. "," .. zone.y1 .. " - " .. zone.x2 .. "," .. zone.y2
        local size = zone.width .. " x " .. zone.height
        local row = {
            kind = "zone", zone = zone, state = state, stateColor = stateColor,
            lines = {
                Window.fit(zone.name .. "  (" .. zone.id .. ")", width - 16 - stateWidth),
                Window.fit(getText("IGUI_MilitaryDrop_ZoneRowDetails", corners, size, tostring(zone.weight)), width - 16),
            },
            colors = { COLOR_TEXT, COLOR_DIM },
        }
        local warnings = ZonesAdmin.warningsText(zone.warnings)
        if warnings ~= "" then
            row.lines[3] = Window.fit(warnings, width - 16)
            row.colors[3] = COLOR_WARN
        end
        rows[#rows + 1] = row
    end
    if #zones == 0 then
        rows[#rows + 1] = { kind = "note", lines = { Window.fit(getText("IGUI_MilitaryDrop_ZoneEmpty"), width) },
            colors = { COLOR_DIM } }
    end
    if #list.problems > 0 then
        rows[#rows + 1] = { kind = "sector", lines = { Window.fit(getText("IGUI_MilitaryDrop_ZoneProblems"), width) },
            colors = { COLOR_ERR } }
        for _, problem in ipairs(list.problems) do
            rows[#rows + 1] = { kind = "note", lines = { Window.fit(problem, width - 16) }, colors = { COLOR_WARN } }
        end
    end
    return rows
end

--- Dessin d'une ligne (remplace ISScrollingListBox.doDrawItem).
local function drawItem(list, y, item, alt)
    local row = item.item
    local lineH = fontHeight()
    local height = #row.lines * lineH + 6
    local top = y + list:getYScroll()
    if top + height < 0 or top >= list.height then
        return y + height
    end
    if row.kind == "zone" and list.selected == item.index then
        list:drawSelection(0, y, list:getWidth(), height - 1)
    elseif row.kind == "zone" and list.mouseoverselected == item.index and list:isMouseOver() then
        list:drawMouseOverHighlight(0, y, list:getWidth(), height - 1)
    end
    local indent = row.kind == "sector" and 6 or 16
    for i, line in ipairs(row.lines) do
        local c = row.colors[i] or COLOR_TEXT
        list:drawText(line, indent, y + 3 + (i - 1) * lineH, c[1], c[2], c[3], 1, UIFont.Small)
    end
    if row.state then
        local c = row.stateColor
        list:drawTextRight(row.state, list:getWidth() - 8, y + 3, c[1], c[2], c[3], 1, UIFont.Small)
    end
    list:drawRect(0, y + height - 1, list:getWidth(), 1, 0.3, 0.4, 0.4, 0.4)
    return y + height
end

-- ----------------------------------------------------------------------------
-- Fenêtre
-- ----------------------------------------------------------------------------

local function buttonWidth(keys)
    local width = 60
    for _, key in ipairs(keys) do
        width = math.max(width, measure(getText(key)) + 20)
    end
    return width
end

function ZW:createChildren()
    ISCollapsableWindow.createChildren(self)
    local pad = Window.PAD
    local lineH = fontHeight()
    local buttonH = lineH + 6
    self.headerY = self:titleBarHeight() + pad
    local listY = self.headerY + 2 * lineH + pad
    local buttonsY = self.height - pad - buttonH - self:resizeWidgetHeight()
    self.statusY = buttonsY - lineH - pad
    self.list = ISScrollingListBox:new(pad, listY, self.width - 2 * pad, self.statusY - pad - listY)
    self.list:initialise()
    self.list:instantiate()
    self.list:setFont(UIFont.Small, 3)
    self.list.drawBorder = true
    self.list.doDrawItem = drawItem
    local window = self
    self.list.onJoypadDown = function(_, button)
        window:onJoypadButton(button)
    end
    self:addChild(self.list)

    local specs = {
        { "toggle", { "IGUI_MilitaryDrop_ZoneEnable", "IGUI_MilitaryDrop_ZoneDisable" }, self.onToggle },
        { "delete", { "IGUI_MilitaryDrop_ZoneDelete", "IGUI_MilitaryDrop_ZoneDeleteConfirm" }, self.onDelete },
        { "goTo", { "IGUI_MilitaryDrop_ZoneGoTo" }, self.onGoTo },
        { "reload", { "IGUI_MilitaryDrop_ZoneReload" }, self.onReload },
        { "closeBtn", { "IGUI_MilitaryDrop_ZoneClose" }, self.close },
    }
    local x = pad
    for _, spec in ipairs(specs) do
        local width = buttonWidth(spec[2])
        local button = ISButton:new(x, buttonsY, width, buttonH, getText(spec[2][1]), self, spec[3])
        button:initialise()
        button:instantiate()
        self:addChild(button)
        self[spec[1]] = button
        x = x + width + pad
    end
    self:updateButtons()
end

function ZW:selectedZone()
    local item = self.list and self.list.items[self.list.selected]
    local row = item and item.item
    return row and row.kind == "zone" and row.zone or nil
end

--- Boutons selon la sélection ; titre de Supprimer pendant la confirmation.
function ZW:updateButtons()
    local zone = self:selectedZone()
    self.toggle:setEnable(zone ~= nil)
    self.toggle:setTitle(getText((zone and zone.enabled) and "IGUI_MilitaryDrop_ZoneDisable"
        or "IGUI_MilitaryDrop_ZoneEnable"))
    self.delete:setEnable(zone ~= nil)
    local confirming = zone ~= nil and self.confirmId == zone.id and getTimestampMs() < (self.confirmUntil or 0)
    self.delete:setTitle(getText(confirming and "IGUI_MilitaryDrop_ZoneDeleteConfirm" or "IGUI_MilitaryDrop_ZoneDelete"))
    self.goTo:setEnable(zone ~= nil and ZonesAdmin.canTeleport(self.player))
end

function ZW:refresh(list)
    local keep = self:selectedZone()
    self.data = list
    self:fitHeader()
    self.list:clear()
    local width = self.list:getWidth() - 20
    for _, row in ipairs(Window.buildRows(list, width)) do
        self.list:addItem(row.lines[1], row)
    end
    self.list.selected = -1
    for i, item in ipairs(self.list.items) do
        local row = item.item
        if row.kind == "zone" and (self.list.selected == -1 or (keep and row.zone.id == keep.id)) then
            self.list.selected = i
            if keep and row.zone.id == keep.id then
                break
            end
        end
    end
    self:updateButtons()
end

function ZW:onToggle()
    local zone = self:selectedZone()
    if zone then
        ZonesAdmin.setEnabled(self.player, zone.id, not zone.enabled)
    end
end

function ZW:onDelete()
    local zone = self:selectedZone()
    if not zone then
        return
    end
    local now = getTimestampMs()
    if self.confirmId == zone.id and now < (self.confirmUntil or 0) then
        self.confirmId = nil
        ZonesAdmin.delete(self.player, zone.id)
    else
        self.confirmId = zone.id
        self.confirmUntil = now + Window.DELETE_CONFIRM_MS
    end
    self:updateButtons()
end

function ZW:onGoTo()
    local zone = self:selectedZone()
    if zone and ZonesAdmin.canTeleport(self.player) then
        ZonesAdmin.goTo(self.player, zone)
    end
end

function ZW:onReload()
    ZonesAdmin.reload(self.player)
end

function ZW:onJoypadButton(button)
    if button == Joypad.AButton then
        self:onToggle()
    elseif button == Joypad.XButton then
        self:onGoTo()
    elseif button == Joypad.YButton then
        self:onReload()
    elseif button == Joypad.BButton then
        self:close()
    end
end

local function headerLines(data)
    if not data then
        return { getText("IGUI_MilitaryDrop_ZoneWaiting") }
    end
    local map = data.map ~= "" and data.map or getText("IGUI_MilitaryDrop_ZoneMapAny")
    local loaded = getText(data.mapLoaded and "IGUI_MilitaryDrop_ZoneMapLoaded" or "IGUI_MilitaryDrop_ZoneMapMissing")
    local placement = data.placement and getTextOrNull("IGUI_MilitaryDrop_ZonePlacement_" .. data.placement) or "?"
    local usable = 0
    for _, zone in ipairs(data.zones) do
        if zone.active then
            usable = usable + 1
        end
    end
    return {
        getText("IGUI_MilitaryDrop_ZoneHeaderMap", map, loaded),
        getText("IGUI_MilitaryDrop_ZoneHeaderPlacement", placement) .. "   "
            .. getText("IGUI_MilitaryDrop_ZoneHeaderCount", tostring(#data.zones), tostring(usable)),
    }
end

--- En-tête (carte, mode, nombre de zones) coupé une fois par réponse.
function ZW:fitHeader()
    local width = self.width - 2 * Window.PAD
    self.header = {}
    for i, line in ipairs(headerLines(self.data)) do
        self.header[i] = Window.fit(line, width)
    end
end

function ZW:prerender()
    ISCollapsableWindow.prerender(self)
    if not self.isCollapsed then
        self:updateButtons()
    end
end

function ZW:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then
        return
    end
    local pad = Window.PAD
    local lineH = fontHeight()
    if not self.header then
        self:fitHeader()
    end
    for i, line in ipairs(self.header) do
        local c = (i == 1 and self.data and not self.data.mapLoaded) and COLOR_WARN or COLOR_TEXT
        self:drawText(line, pad, self.headerY + (i - 1) * lineH, c[1], c[2], c[3], 1, UIFont.Small)
    end
    if self.status then
        local c = self.status.ok and COLOR_OK or COLOR_ERR
        self:drawText(self.status.fitted, pad, self.statusY, c[1], c[2], c[3], 1, UIFont.Small)
    end
end

function ZW:setStatus(text, ok)
    self.status = { fitted = Window.fit(text, self.width - 2 * Window.PAD), ok = ok }
end

function ZW:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function ZW:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:isReallyVisible() then
        self:close()
    end
end

--- Fermeture réelle (ISCollapsableWindow:close ne fait que masquer).
function ZW:close()
    if JoypadState and JoypadState.players[self.playerNum + 1] then
        setJoypadFocus(self.playerNum, nil)
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if Window.instance == self then
        Window.instance = nil
    end
end

function ZW:new(x, y, player)
    local o = ISCollapsableWindow.new(self, x, y, Window.WIDTH, Window.HEIGHT)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.title = getText("IGUI_MilitaryDrop_ZonesWindowTitle")
    o.resizable = false
    o:setWantKeyEvents(true)
    return o
end

-- ----------------------------------------------------------------------------
-- Entrées (ZonesAdmin)
-- ----------------------------------------------------------------------------

--- Ouvre la fenêtre (ou la remet au premier plan) ; la liste est demandée
--- par l'appelant (ZonesAdmin.openList).
function Window.open(player)
    local window = Window.instance
    if window and window.playerNum ~= player:getPlayerNum() then
        window:close()
        window = nil
    end
    if not window then
        local playerNum = player:getPlayerNum()
        local x = getPlayerScreenLeft(playerNum) + math.floor((getPlayerScreenWidth(playerNum) - Window.WIDTH) / 2)
        local y = getPlayerScreenTop(playerNum) + math.floor((getPlayerScreenHeight(playerNum) - Window.HEIGHT) / 2)
        window = ZW:new(math.max(0, x), math.max(0, y), player)
        window:initialise()
        window:addToUIManager()
        Window.instance = window
        if ZonesAdmin.list then
            window:refresh(ZonesAdmin.list)
        end
        if JoypadState and JoypadState.players[playerNum + 1] then
            setJoypadFocus(playerNum, window.list)
        end
    else
        window:setVisible(true)
        window:bringToTop()
    end
    return window
end

function Window.refresh(list)
    if Window.instance then
        Window.instance:refresh(list)
    end
end

function Window.setStatus(text, ok)
    if Window.instance then
        Window.instance:setStatus(text, ok)
    end
end

return Window
