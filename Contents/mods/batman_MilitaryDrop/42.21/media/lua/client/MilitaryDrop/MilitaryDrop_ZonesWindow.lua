-- ============================================================================
-- Military Drop — « Zones de largage » dans le panneau d'admin vanilla
-- (ZONE-03) : bouton du panneau, fenêtre de liste
--
-- Bouton : ISAdminPanelUI:create (ISAdminPanelUI.lua:24-192) crée ses
-- boutons, puis les range tous par titre en deux colonnes à partir de
-- self:getChildren() (:157-178) et place « Fermer » dessous. L'enveloppe
-- ajoute le bouton du mod AVANT l'original : il est rangé avec les boutons
-- vanilla, sans rien remplacer, et une autre enveloppe d'un autre mod reste
-- appelée. Il n'est créé que pour un joueur qui a le droit à l'ouverture
-- (ZonesAdmin.canUse) ; ISAdminPanelUI:updateButtons (:194-240, rappelée par
-- RefreshCheats et OnRolesReceived) est enveloppée pour le griser si le droit
-- se perd. Le panneau d'admin vanilla n'existe qu'en MP (bouton du HUD créé
-- sous isClient(), ISEquippedItem.lua:904-948) ; en solo avec le mode debug,
-- la même entrée est ajoutée au menu de debug vanilla (ISDebugMenu, onglet
-- « Main », voir installDebugMenuButton plus bas). Elle figure aussi dans le
-- sous-menu « Debug › Main » du clic droit sur le monde (DebugContextMenu,
-- voir installDebugContextMenu), pour tout joueur qui a ce menu et le droit.
--
-- Fenêtre calquée sur ISDesignationZonePanel (zones d'animaux) et
-- ISPvpZonePanel : liste groupée par secteur (nom, identifiant, état, coins,
-- taille, poids, avertissements traduits), en tête la carte attendue et le
-- mode de placement, en bas les problèmes de dropzones.txt relevés par le
-- serveur (textes anglais du journal). Boutons aux libellés vanilla :
-- « Ajouter une zone », « Modifier », « Retirer » (confirmation
-- ISModalDialog, IGUI_Designation_RemoveConfirm), « Activer / Désactiver »,
-- « Se téléporter sur la zone », « Rafraîchir » (relit dropzones.txt),
-- « Fermer ». Ajouter et Modifier ouvrent l'éditeur
-- (MilitaryDrop_ZoneEditor.lua) et masquent la liste, comme le vanilla
-- (ISDesignationZonePanel:onClick:205-214). La zone sélectionnée est
-- surlignée au sol dans prerender, fenêtre ouverte seulement.
-- Retour de l'éditeur : la zone ajoutée ou modifiée n'est resélectionnée
-- par la liste suivante (pendingSelect) qu'après un succès, seul cas où une
-- ZoneListReply suit à coup sûr ; l'annulation la sélectionne tout de suite,
-- et un changement de sélection par l'admin efface pendingSelect.
-- Mort du joueur (OnPlayerDeath, ou personnage mort ou remplacé vu dans
-- prerender) : liste et éditeur fermés ; les actions visent toujours le
-- personnage courant (ZonesAdmin.livePlayer), jamais l'IsoPlayer gardé.
--
-- Textes : drawText ne lit aucune balise ; les noms viennent déjà nettoyés
-- (ZonesAdmin.normalizeList) et chaque ligne est coupée à la largeur de la
-- liste (Window.fit). Largeurs des boutons mesurées sur leurs libellés
-- (pz-knowledge ui-windows.md, largeurs selon la langue). Clavier : Échap
-- ferme (seule la fenêtre la plus haute qui consomme la touche la reçoit,
-- UIManager.java:1357-1363). Manette (comme ISDesignationZonePanel:
-- onGainJoypadFocus:248-253) : croix haut/bas = liste, A modifier, X activer
-- ou désactiver, Y ajouter, B fermer.
-- ============================================================================

require "ISUI/ISCollapsableWindowJoypad"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISModalDialog"
require "ISUI/AdminPanel/ISAdminPanelUI"
require "MilitaryDrop/MilitaryDrop_ZonesAdmin"

local ZonesAdmin = MilitaryDrop.ZonesAdmin

local Window = MilitaryDrop.ZonesWindow or {}
MilitaryDrop.ZonesWindow = Window

Window.WIDTH = 580
Window.HEIGHT = 480
Window.PAD = 10
Window.ADMIN_BUTTON = "MILITARYDROP_ZONES"

local ZW = ISCollapsableWindowJoypad:derive("MilitaryDropZonesWindow")
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

--- Largeur d'un bouton qui doit afficher chacun des textes donnés.
function Window.buttonWidth(texts, minimum)
    local width = minimum or 60
    for _, text in ipairs(texts) do
        width = math.max(width, measure(text) + 20)
    end
    return width
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
        rows[#rows + 1] = { kind = "note", lines = { Window.fit(getText("IGUI_MilitaryDrop_ZoneNone"), width) },
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

--- Dessin d'une ligne (remplace ISScrollingListBox.doDrawItem ; hauteur
--- variable : ISScrollingListBox:prerender relit la hauteur rendue).
local function drawItem(list, y, item, alt)
    local row = item.item
    local lineH = fontHeight()
    local height = #row.lines * lineH + 6
    local top = y + list:getYScroll()
    if top + height < 0 or top >= list.height then
        return y + height
    end
    if row.kind == "zone" and list.selected == item.index then
        -- Couleur de sélection de ISDesignationZonePanel:drawList:115.
        list:drawRect(0, y, list:getWidth(), height - 1, 0.3, 0.7, 0.35, 0.15)
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

-- Boutons : champ, libellés possibles (le premier est affiché), action, rangée.
local BUTTONS = {
    { "addBtn", { "IGUI_PvpZone_AddZone" }, "onAdd", 1 },
    { "editBtn", { "IGUI_MilitaryDrop_ZoneEdit" }, "onEdit", 1 },
    { "removeBtn", { "ContextMenu_Remove" }, "onRemove", 1 },
    { "toggleBtn", { "IGUI_MilitaryDrop_ZoneEnable", "IGUI_MilitaryDrop_ZoneDisable" }, "onToggle", 2 },
    { "teleportBtn", { "IGUI_PvpZone_TeleportToZone" }, "onTeleport", 2 },
    { "reloadBtn", { "UI_Reload" }, "onReload", 2 },
    { "closeBtn", { "IGUI_CraftUI_Close" }, "close", 2 },
}

function ZW:createChildren()
    local pad = Window.PAD
    local lineH = fontHeight()
    local buttonH = lineH + 6
    -- Largeur : la plus longue rangée de boutons, au moins WIDTH ; fixée
    -- avant la barre de titre (bouton de fermeture placé à droite).
    local widths, rowWidth = {}, { 0, 0 }
    for _, spec in ipairs(BUTTONS) do
        local texts = {}
        for i, key in ipairs(spec[2]) do
            texts[i] = getText(key)
        end
        widths[spec[1]] = Window.buttonWidth(texts, 80)
        rowWidth[spec[4]] = rowWidth[spec[4]] + widths[spec[1]] + pad
    end
    self:setWidth(math.max(self.width, math.max(rowWidth[1], rowWidth[2]) + pad))
    ISCollapsableWindowJoypad.createChildren(self)
    self.headerY = self:titleBarHeight() + pad
    local listY = self.headerY + 2 * lineH + pad
    local row2Y = self.height - pad - buttonH
    local row1Y = row2Y - pad - buttonH
    self.statusY = row1Y - lineH - pad
    self.list = ISScrollingListBox:new(pad, listY, self.width - 2 * pad, self.statusY - pad - listY)
    self.list:initialise()
    self.list:instantiate()
    self.list:setFont(UIFont.Small, 3)
    self.list.drawBorder = true
    self.list.joypadParent = self
    self.list.doDrawItem = drawItem
    self:addChild(self.list)

    local x = { pad, pad }
    for _, spec in ipairs(BUTTONS) do
        local width = widths[spec[1]]
        local y = spec[4] == 1 and row1Y or row2Y
        local bx = x[spec[4]]
        if spec[1] == "closeBtn" then
            bx = self.width - pad - width
        end
        local button = ISButton:new(bx, y, width, buttonH, getText(spec[2][1]), self, ZW[spec[3]])
        button:initialise()
        button:instantiate()
        button.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
        self:addChild(button)
        self[spec[1]] = button
        x[spec[4]] = x[spec[4]] + width + pad
    end
    self.closeBtn:enableCancelColor()
    self:updateButtons()
end

function ZW:selectedZone()
    local item = self.list and self.list.items[self.list.selected]
    local row = item and item.item
    return row and row.kind == "zone" and row.zone or nil
end

--- Personnage courant et vivant du joueur de la fenêtre (gardé dans
--- self.player), ou nil.
function ZW:currentPlayer()
    local player = ZonesAdmin.livePlayer(self.playerNum)
    if player then
        self.player = player
    end
    return player
end

--- Sélection changée par l'admin depuis le retour de l'éditeur : la zone
--- en attente n'est plus resélectionnée.
function ZW:dropPendingIfMoved()
    if self.pendingSelect and self.list.selected ~= self.pendingFrom then
        self.pendingSelect, self.pendingFrom = nil, nil
    end
end

--- Boutons selon la sélection et les droits.
function ZW:updateButtons()
    local zone = self:selectedZone()
    self.editBtn:setEnable(zone ~= nil)
    self.removeBtn:setEnable(zone ~= nil)
    self.toggleBtn:setEnable(zone ~= nil)
    self.toggleBtn:setTitle(getText((zone and zone.enabled) and "IGUI_MilitaryDrop_ZoneDisable"
        or "IGUI_MilitaryDrop_ZoneEnable"))
    self.teleportBtn:setEnable(zone ~= nil and ZonesAdmin.canTeleport(self.player))
end

--- Sélectionne la zone d'identifiant id (ou garde la sélection, ou la
--- première zone) après un remplissage de la liste.
function ZW:selectZone(id)
    self.list.selected = -1
    for i, item in ipairs(self.list.items) do
        local row = item.item
        if row.kind == "zone" then
            if self.list.selected == -1 or row.zone.id == id then
                self.list.selected = i
            end
            if row.zone.id == id then
                break
            end
        end
    end
end

function ZW:refresh(list)
    self:dropPendingIfMoved()
    local keep = self.pendingSelect or (self:selectedZone() and self:selectedZone().id)
    self.pendingSelect, self.pendingFrom = nil, nil
    self.data = list
    self:fitHeader()
    self.list:clear()
    local width = self.list:getWidth() - 20
    for _, row in ipairs(Window.buildRows(list, width)) do
        self.list:addItem(row.lines[1], row)
    end
    self:selectZone(keep)
    if self.list.selected > 0 then
        self.list:ensureVisible(self.list.selected)
    end
    self:updateButtons()
end

function ZW:onAdd()
    local Editor = MilitaryDrop.ZoneEditor
    local player = self:currentPlayer()
    if Editor and player then
        self.status = nil
        Editor.open(player, nil)
    end
end

function ZW:onEdit()
    local zone = self:selectedZone()
    local Editor = MilitaryDrop.ZoneEditor
    local player = self:currentPlayer()
    if zone and Editor and player then
        self.status = nil
        Editor.open(player, zone)
    end
end

function ZW:onRemove()
    local zone = self:selectedZone()
    if not zone then
        return
    end
    local text = getText("IGUI_Designation_RemoveConfirm", zone.name .. " (" .. zone.id .. ")")
    local w, h = 350, 150
    local x = getPlayerScreenLeft(self.playerNum) + math.floor((getPlayerScreenWidth(self.playerNum) - w) / 2)
    local y = getPlayerScreenTop(self.playerNum) + math.floor((getPlayerScreenHeight(self.playerNum) - h) / 2)
    local modal = ISModalDialog:new(x, y, w, h, text, true, self, ZW.onRemoveConfirmed, self.playerNum, zone.id)
    modal:initialise()
    modal:addToUIManager()
    modal.moveWithMouse = true
    self.removeModal = modal
    if JoypadState and JoypadState.players[self.playerNum + 1] then
        modal.prevFocus = self
        setJoypadFocus(self.playerNum, modal)
    end
end

function ZW:onRemoveConfirmed(button, id)
    self.removeModal = nil
    local player = self:currentPlayer()
    if button.internal == "YES" and id and player then
        ZonesAdmin.delete(player, id)
    end
end

function ZW:onToggle()
    local zone = self:selectedZone()
    local player = self:currentPlayer()
    if zone and player then
        ZonesAdmin.setEnabled(player, zone.id, not zone.enabled)
    end
end

function ZW:onTeleport()
    local zone = self:selectedZone()
    local player = self:currentPlayer()
    if zone and player and ZonesAdmin.canTeleport(player) then
        ZonesAdmin.goTo(player, zone)
    end
end

function ZW:onReload()
    local player = self:currentPlayer()
    if player then
        ZonesAdmin.reload(player)
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
    ISCollapsableWindowJoypad.prerender(self)
    -- Droit perdu (rôle changé), personnage mort ou remplacé : fermeture,
    -- comme ISPvpZonePanel:prerender:101.
    local player = ZonesAdmin.livePlayer(self.playerNum)
    if player ~= self.player or not ZonesAdmin.canUse(player) then
        self:close()
        return
    end
    if self.isCollapsed then
        return
    end
    self:dropPendingIfMoved()
    self:updateButtons()
    local zone = self:selectedZone()
    if zone then
        ZonesAdmin.highlight(self.playerNum, zone, ZonesAdmin.zoneColor(zone))
    end
end

function ZW:render()
    ISCollapsableWindowJoypad.render(self)
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
    return key == Keyboard.KEY_ESCAPE and self:isReallyVisible()
end

function ZW:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:isReallyVisible() then
        self:close()
    end
end

-- Manette : liste à la croix, boutons sur A, B, X, Y (ISDesignationZonePanel).
function ZW:onGainJoypadFocus(joypadData)
    ISCollapsableWindowJoypad.onGainJoypadFocus(self, joypadData)
    self:setISButtonForA(self.editBtn)
    self:setISButtonForB(self.closeBtn)
    self:setISButtonForX(self.toggleBtn)
    self:setISButtonForY(self.addBtn)
end

function ZW:onLoseJoypadFocus(joypadData)
    ISCollapsableWindowJoypad.onLoseJoypadFocus(self, joypadData)
    self:clearISButtons()
end

--- Croix haut / bas : zone précédente ou suivante (les en-têtes de secteur
--- et les notes sont sautés).
function ZW:moveSelection(step)
    local items = self.list.items
    local i = self.list.selected
    for _ = 1, #items do
        i = i + step
        if i < 1 then
            i = #items
        elseif i > #items then
            i = 1
        end
        if items[i] and items[i].item.kind == "zone" then
            self.pendingSelect, self.pendingFrom = nil, nil
            self.list.selected = i
            self.list:ensureVisible(i)
            return
        end
    end
end

function ZW:onJoypadDirUp()
    self:moveSelection(-1)
end

function ZW:onJoypadDirDown()
    self:moveSelection(1)
end

--- Fermeture réelle (ISCollapsableWindow:close ne fait que masquer).
function ZW:close()
    if self.removeModal then
        self.removeModal:destroy()
        self.removeModal = nil
    end
    if JoypadState and JoypadState.players[self.playerNum + 1] then
        setJoypadFocus(self.playerNum, nil)
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if Window.instance == self then
        Window.instance = nil
    end
    local Editor = MilitaryDrop.ZoneEditor
    if Editor and Editor.closeFor then
        Editor.closeFor(self.playerNum)
    end
end

function ZW:new(x, y, player)
    local o = ISCollapsableWindowJoypad.new(self, x, y, Window.WIDTH, Window.HEIGHT)
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.title = getText("IGUI_MilitaryDrop_ZonesWindowTitle")
    o:setResizable(false)
    o.moveWithMouse = true
    o:setWantKeyEvents(true)
    return o
end

-- ----------------------------------------------------------------------------
-- Entrées (bouton du panneau d'admin, ZonesAdmin, éditeur)
-- ----------------------------------------------------------------------------

--- Ouvre la fenêtre (ou la remet au premier plan) et demande la liste.
function Window.open(player)
    if not ZonesAdmin.canUse(player) or player:isDead() then
        return nil
    end
    local window = Window.instance
    if window and (window.playerNum ~= player:getPlayerNum() or window.player ~= player) then
        window:close()
        window = nil
    end
    local playerNum = player:getPlayerNum()
    if not window then
        local x = getPlayerScreenLeft(playerNum) + math.floor((getPlayerScreenWidth(playerNum) - Window.WIDTH) / 2)
        local y = getPlayerScreenTop(playerNum) + math.floor((getPlayerScreenHeight(playerNum) - Window.HEIGHT) / 2)
        window = ZW:new(math.max(0, x), math.max(0, y), player)
        window:initialise()
        window:addToUIManager()
        Window.instance = window
        if ZonesAdmin.list then
            window:refresh(ZonesAdmin.list)
        end
    else
        window:setVisible(true)
        window:bringToTop()
    end
    if JoypadState and JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, window)
    end
    ZonesAdmin.requestList(player)
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

--- Liste masquée pendant l'édition (ISDesignationZonePanel:onClick:210).
function Window.hide()
    if Window.instance then
        Window.instance:setVisible(false)
    end
end

--- Retour de l'éditeur : liste de nouveau visible, zoneId sélectionné.
--- ok vrai (succès : une ZoneListReply suit) : zoneId (zone ajoutée ou
--- modifiée, peut-être absente de la liste affichée) est aussi resélectionné
--- par cette liste, sauf si l'admin change de sélection d'ici là. Sinon
--- (annulation : aucune liste ne suit) rien n'est mis en attente.
function Window.show(zoneId, statusText, ok)
    local window = Window.instance
    if not window then
        return
    end
    window:setVisible(true)
    window:bringToTop()
    window.pendingSelect, window.pendingFrom = nil, nil
    if zoneId then
        window:selectZone(zoneId)
        if ok == true then
            window.pendingSelect, window.pendingFrom = zoneId, window.list.selected
        end
    end
    if statusText then
        window:setStatus(statusText, ok)
    end
    if JoypadState and JoypadState.players[window.playerNum + 1] then
        setJoypadFocus(window.playerNum, window)
    end
end

-- ----------------------------------------------------------------------------
-- Bouton du panneau d'admin vanilla
-- ----------------------------------------------------------------------------

--- Clic sur le bouton : ouvre la liste (le panneau d'admin reste ouvert).
function Window.onAdminButton(panel, button)
    local player = getPlayer()
    if ZonesAdmin.canUse(player) then
        Window.open(player)
    end
end

--- Ajoute le bouton au panneau avant que ISAdminPanelUI:create range ses
--- enfants ; seulement pour un joueur qui a le droit.
function Window.addAdminButton(panel)
    if panel.militaryDropZonesBtn or not ZonesAdmin.canUse(getPlayer()) then
        return nil
    end
    local height = getTextManager():getFontHeight(UIFont.Small) + 6
    local button = ISButton:new(0, 0, 200, height, getText("IGUI_MilitaryDrop_AdminPanelZones"), panel,
        Window.onAdminButton)
    button.internal = Window.ADMIN_BUTTON
    button:initialise()
    button:instantiate()
    button.borderColor = panel.buttonBorderColor
    button.tooltip = getText("IGUI_MilitaryDrop_AdminPanelZonesTip")
    panel:addChild(button)
    panel.militaryDropZonesBtn = button
    return button
end

--- Enveloppe ISAdminPanelUI.create et .updateButtons une seule fois (sur
--- l'original courant ; reposée si ISAdminPanelUI.lua a été rechargé).
function Window.installAdminButton()
    local Panel = ISAdminPanelUI
    if not Panel or type(Panel.create) ~= "function" or type(Panel.updateButtons) ~= "function" then
        return false
    end
    if Panel.create ~= Window.createWrapper then
        local originalCreate = Panel.create
        Window.createWrapper = function(self, ...)
            Window.addAdminButton(self)
            return originalCreate(self, ...)
        end
        Panel.create = Window.createWrapper
    end
    if Panel.updateButtons ~= Window.updateWrapper then
        local originalUpdate = Panel.updateButtons
        Window.updateWrapper = function(self, ...)
            local result = originalUpdate(self, ...)
            if self.militaryDropZonesBtn then
                self.militaryDropZonesBtn.enable = ZonesAdmin.canUse(getPlayer())
            end
            return result
        end
        Panel.updateButtons = Window.updateWrapper
    end
    return true
end

-- ----------------------------------------------------------------------------
-- Entrée du menu de debug vanilla (solo en mode debug)
-- ----------------------------------------------------------------------------

--- Vrai en solo, mode debug actif : seule situation sans panneau d'admin
--- (en MP, un client en -debug a aussi ISDebugMenu ; il garde le panneau).
function Window.debugMenuAllowed(player)
    return not isClient() and isDebugEnabled() == true and ZonesAdmin.canUse(player)
end

--- Clic dans le menu de debug : ISDebugMenu:onClick appelle func() sans
--- argument (ISDebugMenu.lua:208-214) ; le menu reste ouvert.
function Window.onDebugMenuButton()
    local player = getPlayer()
    if Window.debugMenuAllowed(player) then
        Window.open(player)
    end
end

--- Ajoute l'entrée à la liste du menu. ISDebugMenu n'offre aucun point
--- d'extension : createChildren vide self.buttons puis appelle setupButtons
--- (ISDebugMenu.lua:104-108), qui empile des { title, func, tab, marginTop }
--- par addButtonInfo (:60-66), les trie par titre (:53), puis ajoute les deux
--- « Fermer » (:56-57). L'entrée est posée AVANT l'original pour être triée
--- avec les boutons vanilla ; si l'original (ou une enveloppe d'un autre mod)
--- l'a perdue, elle est remise juste avant le « Fermer » de l'onglet MAIN.
function Window.addDebugMenuButton(menu, before)
    if not Window.debugMenuAllowed(getPlayer()) then
        return nil
    end
    menu.buttons = menu.buttons or {}
    for _, info in ipairs(menu.buttons) do
        if info.militaryDropZones then
            return info
        end
    end
    local info = { title = getText("IGUI_MilitaryDrop_AdminPanelZones"), func = Window.onDebugMenuButton,
        tab = "MAIN", marginTop = 0, militaryDropZones = true }
    local at = #menu.buttons + 1
    if not before then
        for i, entry in ipairs(menu.buttons) do
            if entry.tab == "MAIN" and entry.func == nil then
                at = i
                break
            end
        end
    end
    table.insert(menu.buttons, at, info)
    return info
end

--- Enveloppe ISDebugMenu.setupButtons une seule fois (sur l'original
--- courant ; reposée si ISDebugMenu.lua a été rechargé).
function Window.installDebugMenuButton()
    local Menu = ISDebugMenu
    if not Menu or type(Menu.setupButtons) ~= "function" then
        return false
    end
    if Menu.setupButtons ~= Window.debugMenuWrapper then
        local originalSetup = Menu.setupButtons
        Window.debugMenuWrapper = function(self, ...)
            Window.addDebugMenuButton(self, true)
            local result = originalSetup(self, ...)
            Window.addDebugMenuButton(self, false)
            return result
        end
        Menu.setupButtons = Window.debugMenuWrapper
    end
    return true
end

-- ----------------------------------------------------------------------------
-- Entrée du menu contextuel de debug (clic droit sur le monde, « Debug › Main »)
-- ----------------------------------------------------------------------------
--
-- Le sous-menu est construit par DebugContextMenu.doDebugMenu
-- (DebugUIs/DebugContextMenu.lua:22-188) : refus sans droit (:26-32, client
-- MP sans Capability.UseDebugContextMenu, solo hors mode debug), option
-- « Debug » (:54-56, addDebugOption, retirée si UI.HideDebugContextMenuOptions,
-- ISContextMenu.lua:904-912), sous-menu « Main » en variable locale (:58-60,
-- Téléporter, Gestionnaire de hordes, Points d'apparition... : outils du monde
-- qui ouvrent une fenêtre), « UIs » (:80-95, fenêtres de diagnostic de
-- développement). Aucun événement ni table d'options : Java l'appelle par son
-- nom à chaque menu du monde (ISWorldObjectContextMenuLogic.java:555,
-- LuaHelpers.callLuaClass → LuaManager.getFunctionObject, cache vidé à chaque
-- chargement d'un fichier Lua, LuaManager.java:1358). L'enveloppe appelle
-- l'original puis retrouve « Debug » et « Main » par leurs libellés et leurs
-- sous-menus (ISContextMenu:getSubMenu, :1226) et y ajoute l'entrée à la fin.
-- Pendant un tracé de zone, ISWorldObjectContextMenu.disableWorldMenu
-- (posé par l'éditeur) arrête createMenu avant tout (ISWorldObjectContextMenu.
-- lua:146-148) ; l'enveloppe le vérifie aussi.

--- Sous-menu de l'option de libellé name (la dernière qui en a un).
local function subMenuOf(menu, name)
    if type(menu) ~= "table" or type(menu.options) ~= "table" or type(menu.getSubMenu) ~= "function" then
        return nil
    end
    local found
    for _, option in ipairs(menu.options) do
        if option.name == name and option.subOption then
            found = menu:getSubMenu(option.subOption)
        end
    end
    return found
end

--- Clic sur l'entrée : ISContextMenu appelle onSelect(target), ici le numéro
--- du joueur ; le droit est revérifié sur le personnage courant.
function Window.onDebugContextOption(playerNum)
    local player = ZonesAdmin.livePlayer(playerNum)
    if player and ZonesAdmin.canUse(player) then
        Window.open(player)
    end
end

--- Ajoute l'entrée au sous-menu « Debug › Main » s'il existe (une seule
--- fois) ; renvoie l'option ou nil.
function Window.addDebugContextOption(playerNum, context)
    local worldMenu = ISWorldObjectContextMenu
    if worldMenu and worldMenu.disableWorldMenu then
        return nil
    end
    local player = ZonesAdmin.livePlayer(playerNum)
    if not player or not ZonesAdmin.canUse(player) then
        return nil
    end
    local mainMenu = subMenuOf(subMenuOf(context, getText("ContextMenu_Debug")), getText("IGUI_DebugContext_Main"))
    if not mainMenu then
        return nil
    end
    for _, option in ipairs(mainMenu.options) do
        if option.onSelect == Window.onDebugContextOption then
            return option
        end
    end
    return mainMenu:addOption(getText("IGUI_MilitaryDrop_AdminPanelZones"), playerNum, Window.onDebugContextOption)
end

--- Enveloppe DebugContextMenu.doDebugMenu une seule fois (sur l'original
--- courant ; reposée si DebugContextMenu.lua a été rechargé). Arguments et
--- retour de l'original conservés ; une erreur de l'original remonte telle
--- quelle (aucun pcall).
function Window.installDebugContextMenu()
    local Menu = DebugContextMenu
    if type(Menu) ~= "table" or type(Menu.doDebugMenu) ~= "function" then
        return false
    end
    if Menu.doDebugMenu ~= Window.debugContextWrapper then
        local originalMenu = Menu.doDebugMenu
        Window.debugContextWrapper = function(player, context, ...)
            local result = originalMenu(player, context, ...)
            Window.addDebugContextOption(player, context)
            return result
        end
        Menu.doDebugMenu = Window.debugContextWrapper
    end
    return true
end

--- Mort d'un joueur local (OnPlayerDeath, IsoPlayer.OnDeath : joueurs
--- locaux seulement) : sa liste et son éditeur se ferment, comme
--- ISBuildWindow.OnPlayerDeath.
function Window.onPlayerDeath(player)
    local playerNum = player and player:getPlayerNum()
    if playerNum == nil then
        return
    end
    local window = Window.instance
    if window and window.playerNum == playerNum then
        window:close()
    end
    local Editor = MilitaryDrop.ZoneEditor
    if Editor and Editor.closeFor then
        Editor.closeFor(playerNum)
    end
end

Window.installAdminButton()
Window.installDebugMenuButton()
Window.installDebugContextMenu()
-- Rechargement de ce fichier : un seul abonné (Events.X.Add ne dédoublonne pas).
if Window.registered then
    Events.OnGameStart.Remove(Window.registered)
end
Window.registered = function()
    Window.installAdminButton()
    Window.installDebugMenuButton()
    Window.installDebugContextMenu()
end
Events.OnGameStart.Add(Window.registered)
if Window.deathHandler then
    Events.OnPlayerDeath.Remove(Window.deathHandler)
end
Window.deathHandler = function(player) Window.onPlayerDeath(player) end
Events.OnPlayerDeath.Add(Window.deathHandler)

return Window
