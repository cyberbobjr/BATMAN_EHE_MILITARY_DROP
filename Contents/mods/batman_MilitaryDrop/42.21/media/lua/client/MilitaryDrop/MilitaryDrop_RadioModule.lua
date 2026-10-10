-- ============================================================================
-- Military Drop — module « Logistique » de la fenêtre radio du jeu (client)
--
-- Vanilla 42.21 (client/RadioCom/ISRadioWindow.lua) : la fenêtre radio est
-- une pile de modules (ISRadioWindow:addModule → RWMElement, en-tête
-- repliable, autour d'un panneau RWMPanel). À chaque ouverture,
-- ISRadioWindow:readFromObject appelle readFromObject de chaque panneau, qui
-- renvoie s'il s'affiche pour cet appareil. Une fenêtre par joueur local et
-- par genre d'appareil (inventaire, posé), créée une fois puis réutilisée.
--
-- Ce module enveloppe ISRadioWindow.createChildren (une seule fois, l'original
-- est appelé d'abord ; si ISRadioWindow.lua est rechargé, reposée au
-- prochain menu contextuel, par lequel s'ouvre une fenêtre radio) et ajoute à
-- chaque fenêtre un module « Logistique », affiché seulement pour une radio
-- militaire (MilitaryDrop.Radio.isMilitary : objet d'inventaire portatif ou
-- appareil posé). L'enveloppe d'ISRadioWindow.update du talkie à la ceinture
-- (MilitaryDrop_BeltRadio.lua) porte sur une autre fonction : les deux
-- coexistent.
--
-- Depuis le 2026-10-01, ce module REMPLACE le menu contextuel du mod pour les
-- joueurs (sous-menu « Logistique » et option « Demander un largage »
-- retirés ; restent le largage forcé de l'admin et les entrées du poste de
-- liaison). On l'ouvre par « Options de l'appareil » : vanilla (radio en
-- main, sur le dos, radio posée), ou ajoutée par MilitaryDrop_BeltRadio.lua
-- (talkie à la ceinture, radio militaire rangée dans un sac : prise en main).
--
-- Contenu :
--   * champ « Code » (si l'option AuthCode l'exige), prérempli avec le code
--     gardé par personnage, y compris après un rechargement
--     (MilitaryDrop.Client.rememberCode : fichier du client, jamais envoyé
--     ailleurs qu'à l'appel) ;
--   * « Demander un largage » : MilitaryDrop.Client.call (prise en main d'une
--     radio rangée ; talkie à la ceinture : boutons grisés, AUTH-04), sans
--     boîte de saisie ;
--     la feuille de réquisition s'ouvre collée à la fenêtre radio ;
--   * rapport, matricules (avec le nombre de plaques), reconnaissance,
--     confirmation de réception, « Faire le point » sur le nettoyage (grisé
--     sans nettoyage en cours) : envois et raisons de grisé de
--     MilitaryDrop.ExchangeMenu (Menu.onOption, Menu.reason, Menu.tooltipText) ;
--   * dernière réplique de la base reçue par ce joueur
--     (MilitaryDrop.Client.lastReply).
-- Radio posée pouvant servir de poste de liaison (non portable, haut de
-- gamme, émettrice : MilitaryDrop.PostWindow.isEligible, même règle que le
-- serveur) : à la place, un seul bouton « Poste de liaison »
-- (MilitaryDrop.PostWindow.useRadio : installation puis console, console,
-- ou confirmation du transfert ; grisé si la radio est le poste d'une autre
-- équipe, état demandé au serveur à l'ouverture : PostQuery). Les autres
-- radios militaires posées (talkie posé) gardent le module complet.
-- Le client ne décide rien : le serveur revérifie tout. La fréquence n'est
-- jamais vérifiée ici : griser sur un mauvais canal la révélerait.
--
-- Manette : sur le module, A entre dans ses commandes ; haut et bas passent
-- de l'une à l'autre ; A active (le champ de code ouvre le clavier à l'écran
-- vanilla, OnScreenKeyboard, comme ISTextEntryBox:onJoypadDown) ; B ou LB
-- ressort. Largeurs : textes mesurés, raccourcis (« ... ») s'ils dépassent,
-- texte entier dans l'infobulle.
-- ============================================================================

require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "RadioCom/ISRadioWindow"
require "RadioCom/RadioWindowModules/RWMPanel"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Exchange"
require "MilitaryDrop/MilitaryDrop_Codes"
require "MilitaryDrop/MilitaryDrop_Client"
require "MilitaryDrop/MilitaryDrop_ExchangeMenu"
require "MilitaryDrop/MilitaryDrop_PostWindow"

local Config = MilitaryDrop.Config
local Radio = MilitaryDrop.Radio
local Codes = MilitaryDrop.Codes

-- Table conservée si le fichier est rechargé (débogage) : l'enveloppe n'est
-- jamais posée deux fois.
local RM = MilitaryDrop.RadioModule or {}
MilitaryDrop.RadioModule = RM

-- Marges des modules vanilla (RWMMicrophone.lua, RWMChannel.lua).
RM.BORDER = 10
-- Dernière réplique : lignes affichées au plus.
RM.MAX_REPLY_LINES = 4
-- Relecture des états (radio, plaques, réplique), en ms réelles.
RM.REFRESH_MS = 500
-- Boutons bloqués après un envoi (double clic), en ms réelles.
RM.LOCK_MS = 2500
RM.REPLY_COLOR = { r = 0.45, g = 0.85, b = 0.45 }

-- ----------------------------------------------------------------------------
-- Règles (fonctions pures, testées hors jeu)
-- ----------------------------------------------------------------------------

--- Le module s'affiche pour cet appareil.
function RM.shows(device)
    return Radio.isMilitary(device)
end

--- Radio posée pouvant servir de poste de liaison : bouton « Poste de
--- liaison » seul (MilitaryDrop.PostWindow, s'il est chargé).
function RM.isPostRadio(device)
    local PostWindow = MilitaryDrop.PostWindow
    return type(PostWindow) == "table" and type(PostWindow.isEligible) == "function"
        and PostWindow.isEligible(device) == true
end

--- Le serveur exige un code pour les largages.
function RM.codeRequired()
    return Config.codeMode() ~= Codes.MODE_NONE
end

--- Code saisi sans espaces autour (nil si vide).
function RM.cleanCode(text)
    local code = type(text) == "string" and string.match(text, "^[ \t]*(.-)[ \t]*$") or ""
    if code == "" then
        return nil
    end
    return code
end

--- Raison de grisé de « Demander un largage » (clé de traduction), ou nil :
--- celles d'Exchange.unavailableReason, puis le code manquant.
function RM.requestReason(player, device, code)
    local reason = MilitaryDrop.Exchange.unavailableReason(player, device)
    if reason then
        return reason
    end
    if RM.codeRequired() and not RM.cleanCode(code) then
        return "IGUI_MilitaryDrop_RadioModule_NeedCode"
    end
    return nil
end

local function measure(text, font)
    return getTextManager():MeasureStringX(font or UIFont.Small, tostring(text or ""))
end

--- Retire le dernier caractère, toujours au moins une unité (Kahlua : chaîne
--- Java en UTF-16, pas en octets UTF-8 ; voir MilitaryDrop.dropLastChar).
local function dropLastChar(text)
    return MilitaryDrop.dropLastChar(text)
end

--- Texte raccourci (« ... ») pour tenir dans maxWidth.
function RM.fit(text, font, maxWidth)
    text = tostring(text or "")
    if measure(text, font) <= maxWidth then
        return text
    end
    while #text > 0 and measure(text .. "...", font) > maxWidth do
        text = dropLastChar(text)
    end
    return text .. "..."
end

--- Lignes d'un texte coupé aux espaces pour tenir dans maxWidth ; un mot trop
--- long est coupé ; au-delà de maxLines, la dernière ligne finit par « ... ».
function RM.wrap(text, font, maxWidth, maxLines)
    local lines, current = {}, ""
    local overflow = false
    -- Espaces ASCII seulement : sous lupa (octets), %s prendrait le 0xA0 de « à ».
    for word in tostring(text or ""):gmatch("[^ \t\r\n]+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if measure(candidate, font) <= maxWidth then
            current = candidate
        else
            if current ~= "" then
                lines[#lines + 1] = current
            end
            current = word
            -- Mot plus large que la ligne (et de plus d'un caractère) : coupé au
            -- caractère près. head garde au moins un caractère et reste plus
            -- court que current : chaque tour avance.
            while measure(current, font) > maxWidth and dropLastChar(current) ~= "" do
                local head = current
                while measure(head, font) > maxWidth do
                    local shorter = dropLastChar(head)
                    if shorter == "" then
                        break
                    end
                    head = shorter
                end
                lines[#lines + 1] = head
                current = current:sub(#head + 1)
            end
        end
    end
    if current ~= "" then
        lines[#lines + 1] = current
    end
    if maxLines and #lines > maxLines then
        overflow = true
        local kept = {}
        for i = 1, maxLines do
            kept[i] = lines[i]
        end
        lines = kept
    end
    if overflow then
        lines[#lines] = RM.fit(lines[#lines] .. " ...", font, maxWidth)
        if lines[#lines]:sub(-3) ~= "..." then
            lines[#lines] = RM.fit(lines[#lines] .. "...", font, maxWidth)
        end
    end
    return lines
end

-- ----------------------------------------------------------------------------
-- Panneau du module
-- ----------------------------------------------------------------------------

local Panel = RWMPanel:derive("MilitaryDropRadioModule")
RM.Panel = Panel

local function styleButton(button)
    button.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    button.backgroundColorMouseOver = { r = 1.0, g = 1.0, b = 1.0, a = 0.1 }
    button.borderColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.3 }
end

function Panel:initialise()
    ISPanel.initialise(self)
end

function Panel:new(x, y, width, height)
    local o = RWMPanel.new(self, x, y, width, height)
    o.font = UIFont.Small
    o.fh = getTextManager():getFontHeight(o.font)
    o.buttonH = o.fh + 6
    o.gap = math.max(4, math.floor(o.fh * 0.3))
    o.replyLines = {}
    o.lockedUntil = 0
    o.nextRefresh = 0
    return o
end

function Panel:createChildren()
    local b = RM.BORDER
    local w = self.width - 2 * b
    self.codeLabel = getText("IGUI_MilitaryDrop_RadioModule_Code")
    self.codeEntry = ISTextEntryBox:new("", b, b, w, self.buttonH)
    self.codeEntry:initialise()
    self.codeEntry:instantiate()
    self.codeEntry:setMaxTextLength(Codes.MAX_INPUT_LENGTH)
    self.codeEntry:setPlaceholderText(getText("IGUI_MilitaryDrop_RadioModule_CodeHint"))
    self.codeEntry:setTooltip(getText("IGUI_MilitaryDrop_EnterCode"))
    self.codeEntry.target = self
    self.codeEntry.onTextChangeFunction = Panel.onCodeChange
    local panel = self
    -- Entrée au clavier : même effet que le bouton.
    self.codeEntry.onCommandEntered = function()
        panel:onRequest()
    end
    self:addChild(self.codeEntry)

    self.requestButton = ISButton:new(b, b, w, self.buttonH, "", self, Panel.onRequest)
    self.requestButton:initialise()
    styleButton(self.requestButton)
    self.requestButton.fullTitle = getText("IGUI_MilitaryDrop_RequestDrop")
    self:addChild(self.requestButton)

    self.postButton = ISButton:new(b, b, w, self.buttonH, "", self, Panel.onPost)
    self.postButton:initialise()
    styleButton(self.postButton)
    self.postButton.fullTitle = getText("IGUI_MilitaryDrop_PostOpen")
    self:addChild(self.postButton)

    self.optionButtons = {}
    for _, option in ipairs(MilitaryDrop.ExchangeMenu.OPTIONS) do
        local button = ISButton:new(b, b, w, self.buttonH, "", self, Panel.onOption)
        button:initialise()
        styleButton(button)
        button.option = option
        button.fullTitle = getText(option.label)
        self:addChild(button)
        self.optionButtons[#self.optionButtons + 1] = button
    end
    self:layout()
end

--- Éléments dans l'ordre de navigation (champ de code s'il est affiché ;
--- radio du poste : le seul bouton « Poste de liaison »).
function Panel:items()
    if self.postMode then
        return { self.postButton }
    end
    local items = {}
    if self.codeShown then
        items[#items + 1] = self.codeEntry
    end
    items[#items + 1] = self.requestButton
    for _, button in ipairs(self.optionButtons) do
        items[#items + 1] = button
    end
    return items
end

--- Titre d'un bouton raccourci à sa largeur ; texte entier dans l'infobulle.
local function setButtonTitle(panel, button, title)
    button.fullTitle = title
    local fitted = RM.fit(title, panel.font, button:getWidth() - 2 * panel.gap)
    if button.title ~= fitted then
        button:setTitle(fitted)
    end
end

--- Hauteur du panneau ; l'en-tête du module est recalculé si elle change.
local function setContentHeight(panel, height)
    panel.contentH = height
    if panel.height ~= height then
        panel:setHeight(height)
        if panel.parent and panel.parent.calculateHeights then
            panel.parent:calculateHeights()
        end
    end
end

--- Positions et hauteur (champ de code, boutons, dernière réplique ; radio
--- du poste : le bouton « Poste de liaison » seul).
function Panel:layout()
    local b, gap = RM.BORDER, self.gap
    local w = self.width - 2 * b
    local y = b
    local postMode = self.postMode == true
    self.postButton:setVisible(postMode)
    self.requestButton:setVisible(not postMode)
    for _, button in ipairs(self.optionButtons) do
        button:setVisible(not postMode)
    end
    if postMode then
        self.codeShown = false
        self.codeEntry:setVisible(false)
        self.postButton:setX(b)
        self.postButton:setY(y)
        self.postButton:setWidth(w)
        self.postButton:setHeight(self.buttonH)
        setButtonTitle(self, self.postButton, self.postButton.fullTitle)
        setContentHeight(self, y + self.buttonH + b)
        return
    end
    self.codeShown = RM.codeRequired()
    self.codeEntry:setVisible(self.codeShown)
    if self.codeShown then
        -- Libellé à gauche, au plus 40 % de la largeur ; champ à droite.
        self.codeLabelW = math.min(measure(self.codeLabel, self.font), math.floor(w * 0.4))
        local x = b + self.codeLabelW + gap
        self.codeEntry:setX(x)
        self.codeEntry:setY(y)
        self.codeEntry:setWidth(self.width - b - x)
        self.codeEntry:setHeight(self.buttonH)
        self.codeY = y
        y = y + self.buttonH + gap
    end
    local buttons = { self.requestButton }
    for _, button in ipairs(self.optionButtons) do
        buttons[#buttons + 1] = button
    end
    for i, button in ipairs(buttons) do
        button:setX(b)
        button:setY(y)
        button:setWidth(w)
        button:setHeight(self.buttonH)
        setButtonTitle(self, button, button.fullTitle)
        y = y + self.buttonH + gap
        if i == 1 then
            -- Séparation entre le largage et les échanges.
            self.ruleY = y
            y = y + gap
        end
    end
    self.replyTitleY = y
    y = y + self.fh
    self.replyY = y
    y = y + math.max(1, #self.replyLines) * self.fh
    setContentHeight(self, y + b)
end

function Panel:clear()
    self:clearJoypadFocus()
    RWMPanel.clear(self)
end

function Panel:readFromObject(player, device, deviceData, deviceType)
    if not RM.shows(device) then
        return false
    end
    RWMPanel.readFromObject(self, player, device, deviceData, deviceType)
    self.playerNum = player:getPlayerNum()
    self.codeEntry:setText(MilitaryDrop.Client.rememberedCode(self.playerNum))
    self.lockedUntil = 0
    -- Fenêtre réutilisée d'une radio à l'autre : mode à revoir à chaque fois.
    local postMode = RM.isPostRadio(device)
    if postMode ~= (self.postMode == true) then
        self:clearJoypadFocus()
        self.postMode = postMode
        self:layout()
    end
    if postMode then
        -- État de la radio (poste de l'équipe, d'une autre, ailleurs) : serveur.
        MilitaryDrop.PostWindow.queryStatus(player, device)
    end
    self:refresh()
    return true
end

function Panel:onCodeChange()
    if self.player then
        MilitaryDrop.Client.rememberCode(self.player:getPlayerNum(), RM.cleanCode(self.codeEntry:getText()))
    end
    self.nextRefresh = 0
end

--- Bouton actif, ou grisé avec sa raison en infobulle (texte riche) ; titre
--- entier en tête de l'infobulle s'il est raccourci.
local function setState(button, reason, tooltip)
    button:setEnable(reason == nil)
    button.reason = reason
    local text = reason and getText(reason) or tooltip
    if button.title ~= button.fullTitle then
        text = button.fullTitle .. " <LINE> <LINE> " .. text
    end
    button:setTooltip(text)
end

--- Relit les états : code exigé, raisons de grisé, nombre de plaques, réplique.
function Panel:refresh()
    if not self.player or not self.device then
        return
    end
    local now = getTimestampMs()
    self.nextRefresh = now + RM.REFRESH_MS
    local locked = now < self.lockedUntil and "IGUI_MilitaryDrop_RadioModule_Sending" or nil
    if self.postMode then
        local PostWindow = MilitaryDrop.PostWindow
        setState(self.postButton, locked or PostWindow.useReason(self.player, self.device),
            getText(PostWindow.useTooltip(self.device)))
        return
    end
    if self.codeShown ~= RM.codeRequired() then
        self:layout()
    end
    local Menu = MilitaryDrop.ExchangeMenu
    setState(self.requestButton, locked or RM.requestReason(self.player, self.device, self.codeEntry:getText()),
        getText("IGUI_MilitaryDrop_RequestTooltip"))
    for _, button in ipairs(self.optionButtons) do
        local option = button.option
        local title = getText(option.label)
        if option.source == "dogtag" then
            title = title .. " (" .. tostring(Menu.dogTagCount(self.player)) .. ")"
        end
        setButtonTitle(self, button, title)
        setState(button, locked or Menu.reason(self.player, self.device, option), Menu.tooltipText(self.player, option))
    end
    self:readReply()
end

--- Dernière réplique de la base pour ce joueur, coupée à la largeur.
function Panel:readReply()
    local reply = MilitaryDrop.Client.lastReply(self.player:getPlayerNum())
    local seq = reply and reply.seq or 0
    if seq == self.replySeq and self.replyWidth == self.width then
        return
    end
    self.replySeq, self.replyWidth = seq, self.width
    local lines = {}
    if reply then
        lines = RM.wrap(reply.text, self.font, self.width - 2 * RM.BORDER, RM.MAX_REPLY_LINES)
    end
    local before = #self.replyLines
    self.replyLines = lines
    if math.max(1, before) ~= math.max(1, #lines) then
        self:layout()
    end
end

function Panel:update()
    RWMPanel.update(self)
    if self.player and getTimestampMs() >= self.nextRefresh then
        self:refresh()
    end
end

function Panel:render()
    RWMPanel.render(self)
    local b = RM.BORDER
    if self.postMode then
        self:renderFocus()
        return
    end
    if self.codeShown then
        self:drawText(RM.fit(self.codeLabel, self.font, self.codeLabelW), b,
            self.codeY + (self.buttonH - self.fh) / 2, 1, 1, 1, 1, self.font)
    end
    self:drawRect(b, self.ruleY, self.width - 2 * b, 1, 0.3, 1, 1, 1)
    local w = self.width - 2 * b
    self:drawText(RM.fit(getText("IGUI_MilitaryDrop_RadioModule_LastReply"), self.font, w), b, self.replyTitleY,
        0.7, 0.7, 0.7, 1, self.font)
    if #self.replyLines == 0 then
        self:drawText(RM.fit(getText("IGUI_MilitaryDrop_RadioModule_NoReply"), self.font, w), b, self.replyY,
            0.5, 0.5, 0.5, 1, self.font)
    end
    local c = RM.REPLY_COLOR
    for i, line in ipairs(self.replyLines) do
        self:drawText(line, b, self.replyY + (i - 1) * self.fh, c.r, c.g, c.b, 1, self.font)
    end
    self:renderFocus()
end

--- Cadre de l'élément choisi à la manette.
function Panel:renderFocus()
    local focused = self:focusedItem()
    if focused then
        local x, y, fw, fh = focused:getX(), focused:getY(), focused:getWidth(), focused:getHeight()
        self:drawRectBorder(x, y, fw, fh, 0.4, 0.2, 1.0, 1.0)
        self:drawRectBorder(x + 1, y + 1, fw - 2, fh - 2, 0.4, 0.2, 1.0, 1.0)
    end
end

-- ----------------------------------------------------------------------------
-- Actions
-- ----------------------------------------------------------------------------

--- Boutons grisés pendant RM.LOCK_MS (double clic, action en cours).
function Panel:lock()
    self.lockedUntil = getTimestampMs() + RM.LOCK_MS
    self:refresh()
end

--- « Demander un largage » : Client.call, avec le code saisi ; la
--- feuille de réquisition sera collée à la fenêtre radio.
function Panel:onRequest()
    if not self.player or not self.device then
        return false
    end
    self:refresh()
    if not self.requestButton.enable then
        return false
    end
    local code = RM.codeRequired() and RM.cleanCode(self.codeEntry:getText()) or nil
    self:lock()
    return MilitaryDrop.Client.call(self.player, self.device, code, false, { anchor = self.radioWindow }) ~= false
end

--- « Poste de liaison » (radio du poste) : MilitaryDrop.PostWindow.useRadio
--- (installation puis console, console, ou confirmation du transfert).
function Panel:onPost()
    if not self.player or not self.device or not self.postMode then
        return false
    end
    self:refresh()
    if not self.postButton.enable then
        return false
    end
    self:lock()
    return MilitaryDrop.PostWindow.useRadio(self.player, self.device) ~= nil
end

--- Rapport, matricules, reconnaissance, réception : MilitaryDrop.ExchangeMenu.onOption.
function Panel:onOption(button)
    if not self.player or not self.device or not button or not button.option then
        return false
    end
    self:refresh()
    if not button.enable then
        return false
    end
    self:lock()
    return MilitaryDrop.ExchangeMenu.onOption(self.player, self.device, button.option) ~= false
end

-- ----------------------------------------------------------------------------
-- Manette
-- ----------------------------------------------------------------------------

function Panel:focusedItem()
    return self.focusIndex and self:items()[self.focusIndex] or nil
end

--- Surbrillance manette d'un bouton. isJoypad pendant le focus : un bouton
--- grisé et focalisé écrirait sinon son titre en noir sur le fond sombre
--- (ISButton:render, ISButton.lua:253) ; le cadre est dessiné par le panneau.
local function setItemFocused(item, focused)
    if item and item.setJoypadFocused then
        if item.forceClick then
            item.isJoypad = focused
        end
        item:setJoypadFocused(focused)
    end
end

--- Place le curseur sur l'élément index (bouclé), ou le retire (nil).
function Panel:setFocusIndex(index)
    local items = self:items()
    setItemFocused(self:focusedItem(), false)
    if index == nil or #items == 0 then
        self.focusIndex = nil
        self.focusElement = nil
        return
    end
    index = ((index - 1) % #items) + 1
    self.focusIndex = index
    self.focusElement = items[index]
    -- Le champ de code n'est pris que sur A (clavier à l'écran) : pas de focus clavier ici.
    if items[index] ~= self.codeEntry then
        setItemFocused(items[index], true)
    end
end

function Panel:moveFocus(delta)
    self:setFocusIndex((self.focusIndex or 0) + delta)
end

function Panel:clearJoypadFocus()
    if self.focusIndex then
        self:setFocusIndex(nil)
    end
end

--- Clavier à l'écran vanilla pour le champ de code (ISTextEntryBox:onJoypadDown).
function Panel:openKeyboard()
    local playerNum = self.playerNum or (self.player and self.player:getPlayerNum())
    local joypadData = playerNum and JoypadState and JoypadState.players[playerNum + 1]
    if not joypadData or not OnScreenKeyboard or OnScreenKeyboard.IsVisible() then
        return false
    end
    local keyboard = OnScreenKeyboard.Show(playerNum, self.codeEntry, joypadData)
    keyboard.prevFocus = joypadData.focus
    joypadData.focus = keyboard
    return true
end

--- Bouton de la manette transmis par RWMElement:onJoypadDown ; renvoie
--- (LB consommé, RB consommé) comme les modules vanilla.
function Panel:onJoypadDown(button)
    if not self.player then
        return false, false
    end
    local focused = self:focusedItem()
    if button == Joypad.AButton then
        if not focused then
            self:setFocusIndex(1)
        elseif focused == self.codeEntry then
            self:openKeyboard()
        elseif focused.enable then
            focused:forceClick()
        end
    elseif button == Joypad.BButton and focused then
        self:setFocusIndex(nil)
    elseif button == Joypad.LBumper and focused then
        self:setFocusIndex(nil)
        return true, false
    end
    return false, false
end

function Panel:getAPrompt()
    local focused = self:focusedItem()
    if not focused then
        return getText("IGUI_MilitaryDrop_RadioModule_Select")
    end
    if focused == self.codeEntry then
        return getText("IGUI_MilitaryDrop_RadioModule_TypeCode")
    end
    if focused.enable then
        return focused.fullTitle
    end
    return nil
end

function Panel:getBPrompt()
    if self.focusIndex then
        return getText("IGUI_MilitaryDrop_RadioModule_Back")
    end
    return nil
end

function Panel:getLBPrompt()
    if self.focusIndex then
        return getText("IGUI_MilitaryDrop_RadioModule_Back")
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- Ajout à la fenêtre radio
-- ----------------------------------------------------------------------------

--- Le curseur manette est dans le module alors que son panneau est masqué
--- (module replié à la souris pendant la sélection) : RWMElement ne
--- transmet plus A, B ni LB au panneau (RWMElement.lua:146), et gauche/droite
--- refusent de déplier tant que focusElement existe (:130-142). Le curseur
--- est alors relâché : la manette retrouve la navigation vanilla.
local function releaseHiddenFocus(panel)
    if panel.focusIndex and not panel:getIsVisible() then
        panel:clearJoypadFocus()
    end
end

--- Haut et bas de l'en-tête du module : d'une commande à l'autre quand le
--- curseur est dans le module (panneau visible), sinon comportement vanilla
--- (module voisin). Gauche, droite et boutons : curseur d'un panneau masqué
--- relâché d'abord. Posé sur l'instance d'en-tête de ce module seulement.
local function wrapElementNavigation(element, panel)
    local up, down = element.onJoypadDirUp, element.onJoypadDirDown
    local left, right, pressed = element.onJoypadDirLeft, element.onJoypadDirRight, element.onJoypadDown
    element.onJoypadDirUp = function(self, joypadData)
        releaseHiddenFocus(panel)
        if panel.focusIndex then
            panel:moveFocus(-1)
            return
        end
        return up(self, joypadData)
    end
    element.onJoypadDirDown = function(self, joypadData)
        releaseHiddenFocus(panel)
        if panel.focusIndex then
            panel:moveFocus(1)
            return
        end
        return down(self, joypadData)
    end
    element.onJoypadDirLeft = function(self, joypadData)
        releaseHiddenFocus(panel)
        if left then
            return left(self, joypadData)
        end
    end
    element.onJoypadDirRight = function(self, joypadData)
        releaseHiddenFocus(panel)
        if right then
            return right(self, joypadData)
        end
    end
    element.onJoypadDown = function(self, button, joypadData)
        releaseHiddenFocus(panel)
        if pressed then
            return pressed(self, button, joypadData)
        end
    end
end

--- Ajoute le module à une fenêtre radio (une fois par fenêtre).
function RM.addTo(window)
    if window.militaryDropModule or type(window.modules) ~= "table" or type(window.addModule) ~= "function" then
        return false
    end
    local panel = Panel:new(0, 0, window.width, 0)
    panel.radioWindow = window
    window:addModule(panel, getText("IGUI_MilitaryDrop_Logistics"), true)
    local module = window.modules[#window.modules]
    window.militaryDropModule = module
    if module and module.element and module.element.subpanel == panel then
        wrapElementNavigation(module.element, panel)
    end
    return true
end

--- Enveloppe ISRadioWindow.createChildren une seule fois (original d'abord,
--- puis le module). Si ISRadioWindow.lua a été rechargé (débogage),
--- l'enveloppe est reposée sur le nouvel original au prochain menu
--- contextuel (inventaire ou monde) : c'est par lui qu'une fenêtre radio
--- s'ouvre, donc avant la création de ses modules (RM.onFillContextMenu).
function RM.installWindowWrapper()
    local RadioWindow = ISRadioWindow
    if not RadioWindow or type(RadioWindow.createChildren) ~= "function"
        or (RM.windowWrapper and RadioWindow.createChildren == RM.windowWrapper) then
        return false
    end
    local original = RadioWindow.createChildren
    RM.originalCreateChildren = original
    RM.windowWrapper = function(self, ...)
        original(self, ...)
        RM.addTo(self)
    end
    RadioWindow.createChildren = RM.windowWrapper
    return true
end

--- Point d'entrée fréquent : chaque menu contextuel, avant toute ouverture
--- de fenêtre radio (« Options de l'appareil »), repose l'enveloppe si
--- besoin (comme MilitaryDrop_BeltRadio.lua). Coût : une comparaison.
function RM.onFillContextMenu()
    RM.installWindowWrapper()
end

RM.installWindowWrapper()
Events.OnGameStart.Add(RM.installWindowWrapper)
Events.OnFillInventoryObjectContextMenu.Add(RM.onFillContextMenu)
Events.OnFillWorldObjectContextMenu.Add(RM.onFillContextMenu)

return RM
