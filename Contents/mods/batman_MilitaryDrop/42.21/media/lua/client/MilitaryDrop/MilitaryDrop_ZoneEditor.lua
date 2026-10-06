-- ============================================================================
-- Military Drop — éditeur d'une zone de largage (ZONE-03) : ajout,
-- modification (nom, secteur, poids), tracé du rectangle au sol
--
-- Calqué sur ISAddDesignationAnimalZoneUI (zones d'animaux) : petit panneau
-- en haut à gauche de l'écran du joueur, la liste masquée pendant ce temps
-- (MilitaryDrop_ZonesWindow.lua), consigne, largeur et longueur du
-- rectangle (en rouge au-delà de 300 cases), puis le formulaire : nom,
-- secteur (secteurs connus, ou « Nouveau secteur... » et son nom), poids.
-- Ajout : le tracé commence à l'ouverture. Modification : la zone est
-- surlignée, « Retracer » relance un tracé ; « Enregistrer » n'envoie que les
-- champs changés (ZoneUpdate). La réponse du serveur ferme l'éditeur (succès,
-- zone sélectionnée dans la liste) ou s'affiche dans l'éditeur (refus).
-- Seule la ZoneReply portant le requestId de l'envoi est prise (jamais celle
-- d'une autre commande de même action), et seule elle décide : succès ou
-- refus avec son code. L'attente (self.waiting) est déclarée AVANT l'envoi
-- (rappel onSending de ZonesAdmin.add/update) : en solo, Net.toServer
-- appelle le serveur, dont la ZoneReply puis la ZoneListReply arrivent
-- pendant l'envoi, avant son retour (MilitaryDrop_Net.lua). Les listes
-- (ZoneListReply) ne concluent jamais à un refus : en MP, commandes et
-- réponses partent en RELIABLE non ordonné (PacketTypes.java:492), leur
-- ordre d'arrivée ne prouve rien. Sans réponse après REPLY_TIMEOUT_MS,
-- l'envoi reste bloqué (un ZoneAdd arrivé en retard ajouterait sinon la
-- zone deux fois) et l'éditeur affiche « En attente du serveur... » ;
-- l'annulation reste possible (la liste montre alors l'état du serveur).
--
-- Mort du joueur ou personnage remplacé (prerender, et OnPlayerDeath dans
-- MilitaryDrop_ZonesWindow.lua) : éditeur fermé, couche retirée ; les envois
-- visent le personnage courant (ZonesAdmin.livePlayer). La couche de tracé
-- est recalée chaque image sur l'écran du joueur (résolution changée).
-- Étage : le tracé vise et dessine à l'étage du joueur (ZonesAdmin).
--
-- Retour visuel au sol (couche « editor » de ZonesAdmin.Ground, prioritaire
-- sur la liste, chez cet admin seulement) : pourtour du rectangle en cours
-- (bleu, rouge au-delà de 300 cases), case survolée avant le premier coin,
-- ancien rectangle en gris pendant un nouveau tracé. Surbrillance
-- persistante des sols, sans clignotement : prerender ne fait que comparer
-- les formes, et la couche n'est refaite que si la case visée, le
-- rectangle ou l'étage changent. Le rectangle figé reste affiché tant que
-- l'éditeur est ouvert ; la couche est retirée à sa fermeture (validation,
-- annulation, mort, droit perdu).
--
-- Tracé à la souris (ZonesAdmin.Trace) : appui-glisser-relâcher comme
-- ISAddDesignationAnimalZoneUI:onMouseDownOutside/MoveOutside/UpOutside
-- (:47-74), ou deux clics. Le vanilla écoute les clics « hors » du panneau,
-- qui ne sont PAS consommés : UIManager.updateMouseButtons (UIManager.java:
-- 607-637) n'appelle onMouseDownOutside que pour informer, puis le clic
-- part au jeu (OnMouseDown, Attack/Click : porte ouverte, déplacement,
-- menu). Ici, une couche transparente plein écran (Layer) est posée
-- pendant le tracé, au fond de la pile (backMost : replacée en tête de
-- UIManager.UI à chaque mise à jour, UIManager.java:512-517) : les autres
-- fenêtres gardent leurs clics, tout clic sur le monde la touche et elle le
-- consomme (onMouseDown rend vrai → UIElement.onMouseDown vrai,
-- UIElement.java:870-930 → Mouse.UIBlockButtonDown, UIManager.java:660-664 ;
-- GameKeyboard.isKeyDown(10000) faux tant que le bouton est tenu,
-- Mouse.java:111-125 : ni attaque ni clic d'objet). Le déplacement de la
-- souris est consommé aussi (pas de surbrillance d'objet), la molette non
-- (onMouseWheel faux : zoom du jeu). Le clic droit annule le tracé en cours,
-- comme Échap (MultiplayerZoneEditorMode_NonPVP.lua:230-238) ; le menu du
-- monde est en plus coupé pendant le tracé (ISWorldObjectContextMenu.
-- disableWorldMenu, comme ISAddDesignationAnimalZoneUI:58). Une fois les deux
-- coins fixés, le rectangle est figé ; la couche reste jusqu'au relâchement
-- des boutons (le relâchement du clic qui fixe le coin est consommé aussi),
-- puis elle est retirée et la souris revient au jeu.
-- Manette (ISAddDesignationAnimalZoneUI:onClick:332-397) : croix = case
-- visée (depuis la case du joueur), A fixe le coin 1 puis le coin 2, B
-- annule le tracé ; hors tracé, la croix parcourt le formulaire
-- (ISPanelJoypad) et B annule l'édition.
--
-- Champs de saisie (pz-knowledge ui-windows.md) : tant qu'un
-- ISTextEntryBox a le focus, aucune touche n'arrive au panneau ; le focus
-- n'est perdu qu'au prochain clic gauche : unfocus() à la fermeture et avant
-- un tracé. Textes contrôlés localement (ZonesAdmin.checkForm), revérifiés
-- par le serveur.
-- ============================================================================

require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "MilitaryDrop/MilitaryDrop_ZonesAdmin"

local ZonesAdmin = MilitaryDrop.ZonesAdmin

local Editor = MilitaryDrop.ZoneEditor or {}
MilitaryDrop.ZoneEditor = Editor

Editor.PAD = 10
Editor.MIN_WIDTH = 360
Editor.ENTRY_WIDTH = 200
-- Réponse attendue en ce délai ; au-delà, « En attente du serveur... »
-- (l'envoi reste bloqué, voir l'en-tête).
Editor.REPLY_TIMEOUT_MS = 5000
-- Dernier secteur validé (proposé au prochain ajout).
Editor.lastSector = Editor.lastSector

local ZE = ISPanelJoypad:derive("MilitaryDropZoneEditor")
Editor.class = ZE
local Layer = ISUIElement:derive("MilitaryDropZoneTraceLayer")
Editor.Layer = Layer

local COLOR_TEXT = { 1, 1, 1 }
local COLOR_DIM = { 0.75, 0.75, 0.75 }
local COLOR_BAD = { 0.9, 0.1, 0.1 }
local COLOR_OK = { 0.4, 0.9, 0.4 }
local COLOR_ERR = { 1.0, 0.4, 0.4 }

local function measure(text, font)
    return getTextManager():MeasureStringX(font or UIFont.Small, text)
end

local function fontHeight(font)
    return getTextManager():getFontHeight(font or UIFont.Small)
end

local function usesJoypad(playerNum)
    return getJoypadData(playerNum) ~= nil
end

-- ----------------------------------------------------------------------------
-- Couche de tracé : consomme les clics et déplacements sur le monde
-- ----------------------------------------------------------------------------

function Layer:new(editor)
    local n = editor.playerNum
    local o = ISUIElement.new(self, getPlayerScreenLeft(n), getPlayerScreenTop(n), getPlayerScreenWidth(n),
        getPlayerScreenHeight(n))
    o.editor = editor
    return o
end

--- Couche recalée sur l'écran du joueur (résolution ou écran partagé changés
--- pendant le tracé).
function Layer:fit()
    local n = self.editor.playerNum
    local x, y, w, h = getPlayerScreenLeft(n), getPlayerScreenTop(n), getPlayerScreenWidth(n),
        getPlayerScreenHeight(n)
    if self.x ~= x or self.y ~= y or self.width ~= w or self.height ~= h then
        self:setX(x)
        self:setY(y)
        self:setWidth(w)
        self:setHeight(h)
    end
end

function Layer:onMouseDown(x, y)
    self.editor:onTracePress()
    return true
end

function Layer:onMouseUp(x, y)
    self.editor:onTraceRelease()
    return true
end

function Layer:onRightMouseDown(x, y)
    self.editor:cancelTrace()
    return true
end

function Layer:onRightMouseUp(x, y)
    self.editor:releaseLayerIfIdle()
    return true
end

function Layer:onMouseMove(dx, dy)
    return true
end

function Layer:onMouseWheel(del)
    return false
end

-- ----------------------------------------------------------------------------
-- Panneau
-- ----------------------------------------------------------------------------

local function labelKeys()
    return { "IGUI_PvpZone_ZoneName", "IGUI_MilitaryDrop_ZoneSectorLabel", "IGUI_MilitaryDrop_ZoneNewSectorLabel",
        "IGUI_MilitaryDrop_ZoneWeightLabel" }
end

function ZE:initialise()
    ISPanelJoypad.initialise(self)
    local pad = Editor.PAD
    local lineH = fontHeight()
    local rowH = lineH + 6
    self.split = 0
    for _, key in ipairs(labelKeys()) do
        self.split = math.max(self.split, measure(getText(key)))
    end
    self.split = self.split + 2 * pad
    local y = self.formY

    local zone = self.zone
    self.nameEntry = ISTextEntryBox:new(zone and zone.name or "", self.split, y, Editor.ENTRY_WIDTH, rowH)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self.nameEntry:setMaxTextLength(ZonesAdmin.MAX_TEXT)
    self:addChild(self.nameEntry)
    self.nameY = y
    y = y + rowH + pad

    self.sectorCombo = ISComboBox:new(self.split, y, Editor.ENTRY_WIDTH, rowH, self, ZE.onSectorChange)
    self.sectorCombo:initialise()
    self:addChild(self.sectorCombo)
    self.sectorY = y
    y = y + rowH + pad

    self.newSectorEntry = ISTextEntryBox:new("", self.split, y, Editor.ENTRY_WIDTH, rowH)
    self.newSectorEntry:initialise()
    self.newSectorEntry:instantiate()
    self.newSectorEntry:setMaxTextLength(ZonesAdmin.MAX_TEXT)
    self:addChild(self.newSectorEntry)
    self.newSectorY = y
    y = y + rowH + pad

    self.weightEntry = ISTextEntryBox:new(tostring(zone and zone.weight or 1), self.split, y, 60, rowH)
    self.weightEntry:initialise()
    self.weightEntry:instantiate()
    self.weightEntry:setOnlyNumbers(true)
    self.weightEntry:setMaxTextLength(3)
    self:addChild(self.weightEntry)
    self.weightY = y
    y = y + rowH + pad

    self.statusY = y
    y = y + lineH + pad

    local submitKey = zone and "IGUI_MilitaryDrop_ZoneSave" or "IGUI_PvpZone_AddZone"
    local specs = {
        { "redrawBtn", "IGUI_MilitaryDrop_ZoneRedraw", ZE.onRedraw },
        { "submitBtn", submitKey, ZE.onSubmit },
        { "cancelBtn", "UI_Cancel", ZE.onCancel },
    }
    local x = pad
    for _, spec in ipairs(specs) do
        local width = math.max(80, measure(getText(spec[2])) + 20)
        local button = ISButton:new(x, y, width, rowH, getText(spec[2]), self, spec[3])
        button:initialise()
        button:instantiate()
        button.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
        self:addChild(button)
        self[spec[1]] = button
        x = x + width + pad
    end
    self.submitBtn:enableAcceptColor()
    self.cancelBtn:enableCancelColor()
    self:setWidth(math.max(self.width, x, self.split + Editor.ENTRY_WIDTH + pad))
    self.cancelBtn:setX(self.width - pad - self.cancelBtn.width)
    self:setHeight(y + rowH + pad)
    self:fillSectors()
end

--- Secteurs connus (dernière liste), celui de la zone, puis « Nouveau
--- secteur... » (donnée false) ; sélection : secteur de la zone, dernier
--- secteur validé, sinon le premier.
function ZE:fillSectors()
    local combo = self.sectorCombo
    combo:clear()
    local names, seen = {}, {}
    local function add(name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    for _, name in ipairs(ZonesAdmin.list and ZonesAdmin.list.sectors or {}) do
        add(name)
    end
    add(self.zone and self.zone.sector)
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    for _, name in ipairs(names) do
        combo:addOptionWithData(name, name)
    end
    combo:addOptionWithData(getText("IGUI_MilitaryDrop_ZoneNewSector"), false)
    local wanted = (self.zone and self.zone.sector) or Editor.lastSector
    combo.selected = 1
    for i, name in ipairs(names) do
        if name == wanted then
            combo.selected = i
        end
    end
    self:onSectorChange()
end

function ZE:isNewSector()
    return self.sectorCombo:getOptionData(self.sectorCombo.selected) == false
end

function ZE:onSectorChange()
    local visible = self:isNewSector()
    self.newSectorEntry:setVisible(visible)
    if self.joyfocus then
        self:buildJoypadGrid(self.joyfocus)
    end
end

--- Valeurs du formulaire (textes bruts, rectangle fixé ou nil).
function ZE:form()
    local sector = self.sectorCombo:getOptionData(self.sectorCombo.selected)
    if sector == false then
        sector = self.newSectorEntry:getText()
    end
    return { name = self.nameEntry:getText(), sector = sector, weight = self.weightEntry:getText(), rect = self.rect }
end

--- Arguments à envoyer (ZoneAdd ou ZoneUpdate), ou nil et la clé du motif.
function ZE:request()
    if self.trace then
        return nil, nil
    end
    if self.zone then
        return ZonesAdmin.updateArgs(self.zone, self:form())
    end
    return ZonesAdmin.addArgs(self:form())
end

--- Envoi en attente de sa réponse (sans limite de temps, voir l'en-tête).
function ZE:isWaiting()
    return self.waiting ~= nil
end

--- Délai dépassé : « En attente du serveur... », envoi toujours bloqué.
function ZE:checkWaiting()
    local waiting = self.waiting
    if waiting and not waiting.late and getTimestampMs() >= waiting.untilMs then
        waiting.late = true
        -- DIAGNOSTIC TEMPORAIRE (éditeur bloqué en solo) : à retirer.
        MilitaryDrop.log("zone editor " .. tostring(self) .. ": no reply to #" .. tostring(waiting.requestId)
            .. " in time, instance=" .. tostring(Editor.instance) .. ", visible=" .. tostring(self:getIsVisible())
            .. ", removed=" .. tostring(self.removed))
    end
end

function ZE:updateButtons()
    local args = self:request()
    self.submitBtn:setEnable(args ~= nil and not self:isWaiting())
    self.redrawBtn:setEnable(self.trace == nil and not self:isWaiting())
end

-- ----------------------------------------------------------------------------
-- Tracé
-- ----------------------------------------------------------------------------

local function unfocus(entry)
    if entry and entry:isFocused() then
        entry:unfocus()
    end
end

function ZE:unfocusEntries()
    unfocus(self.nameEntry)
    unfocus(self.newSectorEntry)
    unfocus(self.weightEntry)
end

--- Case visée : curseur de manette pendant un tracé à la manette, sinon
--- case de l'étage du joueur vue sous la souris.
function ZE:pointedSquare()
    if self.joypadTrace then
        return self.cursorX, self.cursorY
    end
    return ZonesAdmin.squareAtMouse(self.playerNum, self.level)
end

function ZE:addLayer()
    if self.layer then
        return
    end
    self.layer = Layer:new(self)
    self.layer:initialise()
    self.layer:backMost()
    self.layer:addToUIManager()
    local worldMenu = ISWorldObjectContextMenu
    if not self.menuDisabled and worldMenu then
        self.menuDisabled = true
        self.menuWasDisabled = worldMenu.disableWorldMenu
        worldMenu.disableWorldMenu = true
    end
end

function ZE:removeLayer()
    if self.layer then
        self.layer:removeFromUIManager()
        self.layer = nil
    end
    local worldMenu = ISWorldObjectContextMenu
    if self.menuDisabled and worldMenu then
        self.menuDisabled = false
        worldMenu.disableWorldMenu = self.menuWasDisabled == true
        self.menuWasDisabled = nil
    end
end

--- Nouveau tracé : l'ancien rectangle (zone modifiée ou tracé précédent)
--- reste affiché en gris et revient si le tracé est annulé.
function ZE:startTrace()
    self:unfocusEntries()
    self.serverStatus = nil
    if not self.trace then
        self.previousRect = self.rect
    end
    self.rect = nil
    self.trace = ZonesAdmin.Trace.new()
    self.joypadTrace = usesJoypad(self.playerNum)
    self.level = ZonesAdmin.levelOf(self.player)
    if self.joypadTrace then
        local square = self.player:getCurrentSquare()
        self.cursorX = square and square:getX() or math.floor(self.player:getX())
        self.cursorY = square and square:getY() or math.floor(self.player:getY())
        self.trace:hover(self.cursorX, self.cursorY)
    else
        self:addLayer()
        self.trace:hover(self:pointedSquare())
    end
end

--- Rectangle figé : fin du tracé, la souris revient au jeu dès que ses
--- boutons sont relâchés.
function ZE:finishTrace()
    self.rect = self.trace:rect()
    self.trace = nil
    self.joypadTrace = false
    self:releaseLayerIfIdle()
end

function ZE:cancelTrace()
    if not self.trace then
        return false
    end
    self.trace:cancel()
    self.trace = nil
    self.joypadTrace = false
    self.rect = self.previousRect
    self:releaseLayerIfIdle()
    return true
end

--- Couche retirée quand aucun tracé n'attend plus la souris et que ses
--- boutons sont relâchés (le relâchement reste consommé par la couche).
function ZE:releaseLayerIfIdle()
    if self.layer and not self.trace and not isMouseButtonDown(0) and not isMouseButtonDown(1) then
        self:removeLayer()
    end
end

function ZE:onTracePress()
    if self.trace and not self.joypadTrace then
        self.trace:press(self:pointedSquare())
        if not self.trace:active() then
            self:finishTrace()
        end
    end
end

function ZE:onTraceRelease()
    if self.trace and not self.joypadTrace then
        self.trace:release(self:pointedSquare())
        if not self.trace:active() then
            self:finishTrace()
        end
    end
    self:releaseLayerIfIdle()
end

--- Suivi image par image : case visée ; relâchement manqué par la couche
--- (souris relâchée au-dessus d'une autre fenêtre) ; retrait de la couche.
function ZE:updateTrace()
    if self.layer then
        self.layer:fit()
    end
    if self.trace then
        local x, y = self:pointedSquare()
        if self.trace.state == "drag" and not self.joypadTrace and not isMouseButtonDown(0) then
            self.trace:release(x, y)
        end
        self.trace:hover(x, y)
        if not self.trace:active() then
            self:finishTrace()
        end
    end
    self:releaseLayerIfIdle()
end

-- ----------------------------------------------------------------------------
-- Dessin
-- ----------------------------------------------------------------------------

local function sizeLines(rect)
    local w, h = rect.x2 - rect.x1 + 1, rect.y2 - rect.y1 + 1
    local max = ZonesAdmin.MAX_SIDE
    return {
        { getText("IGUI_MilitaryDrop_ZoneCorners", tostring(rect.x1), tostring(rect.y1), tostring(rect.x2),
            tostring(rect.y2)), COLOR_TEXT },
        { getText("IGUI_DesignationZone_Type_Width") .. ": " .. w, w > max and COLOR_BAD or COLOR_TEXT,
          getText("IGUI_DesignationZone_Type_Height") .. ": " .. h, h > max and COLOR_BAD or COLOR_TEXT },
    }
end

--- Consigne du tracé (souris ou manette, comme ISAddDesignationAnimalZoneUI:
--- prerender:213-221), ou rien hors tracé.
function ZE:howTo()
    if not self.trace then
        return nil
    end
    if self.joypadTrace then
        return getText(self.trace.state == "first" and "IGUI_DesignationZone_HowToJoypadStart"
            or "IGUI_DesignationZone_HowToJoypadEnd")
    end
    return getText("IGUI_MilitaryDrop_ZoneTraceHowTo")
end

function ZE:currentRect()
    if self.trace then
        return self.trace:rect()
    end
    return self.rect
end

--- Surbrillance au sol à l'étage du joueur (voir l'en-tête) : rectangle
--- courant ou case survolée d'abord, puis l'ancien rectangle en gris.
function ZE:updateGround()
    local colors = ZonesAdmin.COLORS
    local z = self.level
    local shapes = {}
    local function add(x1, y1, x2, y2, color)
        local ax, ay, bx, by = ZonesAdmin.rect(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2))
        shapes[#shapes + 1] = { x1 = ax, y1 = ay, x2 = bx, y2 = by, z = z, color = color }
    end
    local rect = self:currentRect()
    if rect then
        local _, _, _, _, w, h = ZonesAdmin.rect(rect.x1, rect.y1, rect.x2, rect.y2)
        add(rect.x1, rect.y1, rect.x2, rect.y2, ZonesAdmin.tooBig(w, h) and colors.tooBig or colors.draft)
    elseif self.trace and self.trace.hx then
        add(self.trace.hx, self.trace.hy, self.trace.hx, self.trace.hy, colors.cursor)
    end
    if self.trace and self.previousRect then
        local prev = self.previousRect
        add(prev.x1, prev.y1, prev.x2, prev.y2, colors.previous)
    end
    ZonesAdmin.Ground.setShapes("editor", self.playerNum, shapes, true)
end

function ZE:prerender()
    -- Droit perdu, personnage mort ou remplacé : fermeture (la couche aussi).
    local player = ZonesAdmin.livePlayer(self.playerNum)
    if player ~= self.player or not ZonesAdmin.canUse(player) then
        self:close()
        return
    end
    self.level = ZonesAdmin.levelOf(player)
    self:checkWaiting()
    self:updateTrace()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r,
        self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)
    local pad = Editor.PAD
    local lineH = fontHeight()
    self:drawTextCentre(self.title, self.width / 2, pad, 1, 1, 1, 1, UIFont.Medium)
    local y = self.infoY
    local howTo = self:howTo()
    if howTo then
        self:drawText(howTo, pad, y, 1, 1, 1, 1, UIFont.Small)
    end
    y = y + lineH
    local rect = self:currentRect()
    if rect then
        local lines = sizeLines(rect)
        local c = lines[1][2]
        self:drawText(lines[1][1], pad, y, c[1], c[2], c[3], 1, UIFont.Small)
        y = y + lineH
        c = lines[2][2]
        self:drawText(lines[2][1], pad, y, c[1], c[2], c[3], 1, UIFont.Small)
        c = lines[2][4]
        self:drawText(lines[2][3], pad + measure(lines[2][1]) + 2 * pad, y, c[1], c[2], c[3], 1, UIFont.Small)
    end
    local labelY = 3
    self:drawText(getText("IGUI_PvpZone_ZoneName"), pad, self.nameY + labelY, 1, 1, 1, 1, UIFont.Small)
    self:drawText(getText("IGUI_MilitaryDrop_ZoneSectorLabel"), pad, self.sectorY + labelY, 1, 1, 1, 1, UIFont.Small)
    if self.newSectorEntry:getIsVisible() then
        self:drawText(getText("IGUI_MilitaryDrop_ZoneNewSectorLabel"), pad, self.newSectorY + labelY, 1, 1, 1, 1,
            UIFont.Small)
    end
    self:drawText(getText("IGUI_MilitaryDrop_ZoneWeightLabel"), pad, self.weightY + labelY, 1, 1, 1, 1, UIFont.Small)
    self:updateButtons()
    self:drawStatus()
    self:updateGround()
end

--- Ligne d'état : réponse du serveur (refus), attente, ou motif local qui
--- grise le bouton de validation.
function ZE:drawStatus()
    local text, c
    if self.serverStatus then
        text, c = self.serverStatus.text, self.serverStatus.ok and COLOR_OK or COLOR_ERR
    elseif self:isWaiting() then
        text = getText(self.waiting.late and "IGUI_MilitaryDrop_ZoneWaiting" or "IGUI_MilitaryDrop_ZoneSending")
        c = COLOR_DIM
    elseif not self.trace then
        local args, why = self:request()
        if not args and why then
            text, c = getText(why, tostring(ZonesAdmin.MAX_SIDE)), COLOR_DIM
        end
    end
    if text then
        local Window = MilitaryDrop.ZonesWindow
        local fitted = Window and Window.fit and Window.fit(text, self.width - 2 * Editor.PAD) or text
        self:drawText(fitted, Editor.PAD, self.statusY, c[1], c[2], c[3], 1, UIFont.Small)
    end
end

function ZE:render()
    ISPanelJoypad.render(self)
    if self.joyfocus and not self.trace then
        self:renderJoypadFocus()
    end
end

-- ----------------------------------------------------------------------------
-- Boutons, clavier, manette
-- ----------------------------------------------------------------------------

function ZE:onRedraw()
    if not self.trace and not self:isWaiting() then
        self:startTrace()
    end
end

function ZE:onSubmit()
    local args = self:request()
    local player = ZonesAdmin.livePlayer(self.playerNum)
    if not args or self:isWaiting() or not player then
        return
    end
    self:unfocusEntries()
    self.serverStatus = nil
    self.sentSector = args.sector or (self.zone and self.zone.sector)
    -- Attente déclarée avant l'envoi : en solo, la réponse arrive pendant
    -- l'appel (éditeur déjà fermé ou refus affiché à son retour) ; rien
    -- n'est donc touché après.
    local untilMs = getTimestampMs() + Editor.REPLY_TIMEOUT_MS
    local function onSending(requestId)
        self.waiting = { requestId = requestId, untilMs = untilMs }
        -- DIAGNOSTIC TEMPORAIRE (éditeur bloqué en solo) : à retirer.
        MilitaryDrop.log("zone editor " .. tostring(self) .. ": waiting for #" .. tostring(requestId) .. " ("
            .. type(requestId) .. "), instance=" .. tostring(Editor.instance))
    end
    if self.zone then
        ZonesAdmin.update(player, args, onSending)
    else
        ZonesAdmin.add(player, args, onSending)
    end
end

function ZE:onCancel()
    self:close()
    local Window = MilitaryDrop.ZonesWindow
    if Window and Window.show then
        Window.show(self.zone and self.zone.id)
    end
end

--- Réponse du serveur à l'envoi en cours (même requestId) : vrai si elle
--- concerne l'éditeur.
function ZE:onReply(args, text)
    -- DIAGNOSTIC TEMPORAIRE (éditeur bloqué en solo) : à retirer.
    MilitaryDrop.log("zone editor " .. tostring(self) .. ": reply #" .. tostring(args.requestId) .. ", waiting="
        .. (self.waiting and ("#" .. tostring(self.waiting.requestId)) or "nil") .. ", same number="
        .. tostring(self.waiting ~= nil and args.requestId == self.waiting.requestId))
    if not self.waiting or args.requestId ~= self.waiting.requestId then
        return false
    end
    self.waiting = nil
    if args.ok == true then
        Editor.lastSector = self.sentSector or Editor.lastSector
        self:close()
        local Window = MilitaryDrop.ZonesWindow
        if Window and Window.show then
            Window.show(ZonesAdmin.cleanText(args.id, 16), text, true, args.requestId)
        end
    else
        self.serverStatus = { text = text, ok = false }
    end
    return true
end

function ZE:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE and self:isReallyVisible()
end

--- Échap : annule le tracé en cours, sinon l'édition.
function ZE:onKeyRelease(key)
    if key ~= Keyboard.KEY_ESCAPE or not self:isReallyVisible() then
        return
    end
    if not self:cancelTrace() then
        self:onCancel()
    end
end

function ZE:buildJoypadGrid(joypadData)
    self:clearJoypadFocus(joypadData)
    self.joypadIndexY = 1
    self.joypadIndex = 1
    self.joypadButtonsY = {}
    self.joypadButtons = {}
    self:insertNewLineOfButtons(self.nameEntry)
    self:insertNewLineOfButtons(self.sectorCombo)
    if self.newSectorEntry:getIsVisible() then
        self:insertNewLineOfButtons(self.newSectorEntry)
    end
    self:insertNewLineOfButtons(self.weightEntry)
    self:insertNewLineOfButtons(self.redrawBtn, self.submitBtn, self.cancelBtn)
    self:restoreJoypadFocus(joypadData)
end

function ZE:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:buildJoypadGrid(joypadData)
    self:setISButtonForB(self.cancelBtn)
end

function ZE:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
    self:clearJoypadFocus(joypadData)
    self:clearISButtons()
end

--- Croix pendant un tracé à la manette : déplace la case visée.
function ZE:moveCursor(dx, dy)
    self.cursorX = self.cursorX + dx
    self.cursorY = self.cursorY + dy
    self.trace:hover(self.cursorX, self.cursorY)
end

function ZE:onJoypadDown(button, joypadData)
    if self.joypadTrace and self.trace then
        if button == Joypad.AButton then
            -- Un appui-relâché par coin : coin 1, puis coin 2.
            self.trace:press(self.cursorX, self.cursorY)
            self.trace:release(self.cursorX, self.cursorY)
            if not self.trace:active() then
                self:finishTrace()
            end
        elseif button == Joypad.BButton then
            self:cancelTrace()
        end
        return
    end
    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end

function ZE:onJoypadDirUp(joypadData)
    if self.joypadTrace and self.trace then
        return self:moveCursor(0, -1)
    end
    ISPanelJoypad.onJoypadDirUp(self, joypadData)
end

function ZE:onJoypadDirDown(joypadData)
    if self.joypadTrace and self.trace then
        return self:moveCursor(0, 1)
    end
    ISPanelJoypad.onJoypadDirDown(self, joypadData)
end

function ZE:onJoypadDirLeft(joypadData)
    if self.joypadTrace and self.trace then
        return self:moveCursor(-1, 0)
    end
    ISPanelJoypad.onJoypadDirLeft(self, joypadData)
end

function ZE:onJoypadDirRight(joypadData)
    if self.joypadTrace and self.trace then
        return self:moveCursor(1, 0)
    end
    ISPanelJoypad.onJoypadDirRight(self, joypadData)
end

function ZE:close()
    -- DIAGNOSTIC TEMPORAIRE (éditeur bloqué en solo) : à retirer.
    MilitaryDrop.log("zone editor " .. tostring(self) .. ": close, instance=" .. tostring(Editor.instance))
    self:unfocusEntries()
    if self.trace then
        self.trace:cancel()
        self.trace = nil
    end
    self:removeLayer()
    if JoypadState and JoypadState.players[self.playerNum + 1] then
        setJoypadFocus(self.playerNum, nil)
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if Editor.instance == self then
        Editor.instance = nil
        ZonesAdmin.Ground.remove("editor")
    end
end

function ZE:new(x, y, player, zone)
    local o = ISPanelJoypad.new(self, x, y, Editor.MIN_WIDTH, 100)
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.level = ZonesAdmin.levelOf(player)
    o.zone = zone
    o.rect = zone and { x1 = zone.x1, y1 = zone.y1, x2 = zone.x2, y2 = zone.y2 } or nil
    o.title = zone and (getText("IGUI_MilitaryDrop_ZoneEditTitle") .. " " .. zone.id) or getText("IGUI_PvpZone_AddZone")
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
    o.moveWithMouse = true
    local pad = Editor.PAD
    local lineH = fontHeight()
    o.infoY = pad + fontHeight(UIFont.Medium) + pad
    -- Consigne, coins, largeur et longueur, puis le formulaire.
    o.formY = o.infoY + 3 * lineH + pad
    local width = Editor.MIN_WIDTH
    for _, key in ipairs({ "IGUI_MilitaryDrop_ZoneTraceHowTo", "IGUI_DesignationZone_HowToJoypadStart",
        "IGUI_DesignationZone_HowToJoypadEnd" }) do
        width = math.max(width, measure(getText(key)) + 2 * pad + 2)
    end
    o:setWidth(width)
    o:setWantKeyEvents(true)
    return o
end

-- ----------------------------------------------------------------------------
-- Entrées (fenêtre de liste, ZonesAdmin)
-- ----------------------------------------------------------------------------

--- Ouvre l'éditeur (zone nil : ajout, tracé lancé tout de suite ; sinon
--- modification de cette zone) et masque la liste.
function Editor.open(player, zone)
    if not ZonesAdmin.canUse(player) or player:isDead() then
        return nil
    end
    if Editor.instance then
        Editor.instance:close()
    end
    local playerNum = player:getPlayerNum()
    local editor = ZE:new(getPlayerScreenLeft(playerNum) + 10, getPlayerScreenTop(playerNum) + 10, player, zone)
    editor:initialise()
    editor:addToUIManager()
    Editor.instance = editor
    -- DIAGNOSTIC TEMPORAIRE (éditeur bloqué en solo) : à retirer.
    MilitaryDrop.log("zone editor " .. tostring(editor) .. ": opened (" .. (zone and tostring(zone.id) or "add") .. ")")
    local Window = MilitaryDrop.ZonesWindow
    if Window and Window.hide then
        Window.hide()
    end
    if usesJoypad(playerNum) then
        setJoypadFocus(playerNum, editor)
    end
    if not zone then
        editor:startTrace()
    end
    return editor
end

--- ZoneReply : vrai si l'éditeur ouvert attendait cette réponse.
function Editor.onReply(args, text)
    local editor = Editor.instance
    return editor ~= nil and editor:onReply(args, text)
end

--- Fermeture de la liste : l'éditeur du même joueur se ferme aussi.
function Editor.closeFor(playerNum)
    if Editor.instance and Editor.instance.playerNum == playerNum then
        Editor.instance:close()
    end
end

return Editor
