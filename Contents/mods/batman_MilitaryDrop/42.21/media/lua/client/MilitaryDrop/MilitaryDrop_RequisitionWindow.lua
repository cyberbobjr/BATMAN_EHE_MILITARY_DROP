-- ============================================================================
-- Military Drop — formulaire de réquisition (client, v1.4)
--
-- Fichiers : ce fichier (fenêtre, souris, infobulles, clavier et manette,
-- ouverture), MilitaryDrop_RequisitionWindow_Form.lua (formulaire, budget,
-- secteurs, lots), _Layout.lua (mesures et disposition), _Draw.lua (dessin).
--
-- Ouvert quand le serveur accepte un appel et répond « form » (contrat de
-- docs/annexes/plans/plan-v14.md) : feuille dactylographiée pincée sur une planchette de
-- tôle olive. Lots groupés par palier (I, II, III) puis « Commande spéciale »
-- (le leurre, v1.5) ; chaque ligne : libellé, coût, boutons − et +, quantité
-- écrite à la main. Lots non permis grisés avec leur raison. Budget, points
-- engagés et restants en bas (les points non dépensés sont perdus), tampon
-- « Autorisé » avec le délai de validité.
--
-- Le leurre est exclusif : le cocher bloque les autres lots, et un lot choisi
-- bloque le leurre ; il exige un secteur (N, E, S, O).
--
-- Zones de largage (ZONE-04, decoy.zones = true) : les secteurs sont des
-- noms libres de l'admin (villes, ≤ 32 caractères, liste triée par le
-- serveur) au lieu de N/E/S/O. La rose des vents laisse place à un sélecteur
-- « < Louisville > » : flèches et nom cliquables (le nom passe au suivant),
-- gauche et droite à la manette ; nom mesuré, raccourci (« ... ») s'il ne
-- tient pas, complet dans l'infobulle. Un seul secteur : aucun choix, il est
-- sélectionné d'office et affiché pour information (le serveur tire une zone
-- de ce secteur). Le nom des zones n'est jamais connu du client. La commande
-- envoie decoy = "<secteur>" ; le serveur le revalide.
--
-- Secteur de largage choisi par le joueur (ZONE-09, option DropZoneChoice 3,
-- réponse « form » avec drop = { zones = true, sectors }) : champ « Secteur
-- de largage » au pied de la feuille, au-dessus du budget, avec le même
-- sélecteur « < nom > » (souris, manette, noms nettoyés et raccourcis,
-- infobulle) ; un seul secteur : choisi d'office et imprimé pour information.
-- Le serveur tire ensuite une zone de ce secteur, au poids : le client ne
-- connaît que le nom du secteur. Cohabitation avec le leurre : un seul
-- sélecteur et un seul secteur choisi (form.sector). Le serveur propose au
-- leurre et au largage la même liste (Zones.playerSectors renvoie
-- Zones.decoySectors), et le leurre coché remplace la commande de lots : le
-- secteur du champ sert au largage, ou au leurre quand il est coché (la case
-- du leurre perd alors son propre sélecteur ; cocher ou décocher le leurre
-- garde le secteur). Deux sélecteurs auraient montré deux choix pour un seul
-- point de largage, dont l'un sans effet. Au pied, le champ reste visible sur
-- chaque page d'une feuille paginée. La transmission attend un secteur
-- (motif « choisir un secteur ») ; la commande envoie sector = "<secteur>"
-- avec les lots, ou decoy = "<secteur>" seul pour le leurre. Feuille admin
-- (forced) comprise : mêmes champ et secteurs que pour un joueur (décision
-- du 2026-10-06).
--
-- Le client ne décide rien : il compose la commande (budget, paliers) pour
-- l'affichage, puis MilitaryDrop.Client l'envoie (RequisitionOrder) ou
-- l'annule (RequisitionCancel) ; le serveur revalide tout. Fermer la feuille
-- (Échap, B, croix, joueur éloigné de la radio) annule la réquisition.
--
-- Tout est dessiné par la fenêtre (textures du mod, polices du jeu) ; les
-- largeurs sont mesurées selon la langue et la taille de police, et la mise
-- en page passe de deux colonnes à une, puis en version serrée (deux, une,
-- trois colonnes), pour tenir dans l'écran du joueur (écran partagé
-- compris) ; une longue section continue dans la colonne suivante. Si rien
-- ne tient (beaucoup de lots ajoutés par l'admin, petit écran), la feuille
-- est paginée : « < Page 1/2 > » au pied (clic, molette ; à la manette, la
-- page suit la ligne choisie). Aucune ligne n'est coupée.
--
-- Demande partie du module « Logistique » de la fenêtre radio
-- (MilitaryDrop_RadioModule.lua) : la feuille s'ouvre collée à droite de cette
-- fenêtre, ou à gauche si elle déborderait de l'écran du joueur ; sinon au
-- centre de l'écran.
--
-- Largage forcé de l'admin (Result « form » avec forced = true) : tampon
-- « ADMIN » au lieu de « Autorisé » ; la feuille ne se ferme pas quand le
-- joueur s'éloigne de la radio (le serveur ne l'exige pas) ; sans fenêtre
-- radio d'origine (menu contextuel), elle s'ouvre au centre de l'écran.
--
-- Lots ajoutés par l'admin : lot.texts = { EN = { label, desc }, FR = … }
-- (textes libres, prioritaires sur les clés label/desc) ; affichés dans la
-- langue du client, sinon sa langue de base, sinon l'anglais, sinon la
-- première langue fournie (ordre alphabétique, comme Lots.text sur le
-- serveur), sinon la clé.
-- ============================================================================

require "ISUI/ISPanelJoypad"
require "ISUI/ISToolTip"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Client"

local Radio = MilitaryDrop.Radio

local RW = ISPanelJoypad:derive("MilitaryDropRequisitionWindow")
MilitaryDrop.RequisitionWindow = RW

-- Secteurs du leurre, dans l'ordre du contrat (W s'affiche « O » en français).
RW.SECTORS = { "N", "E", "S", "W" }
-- Secteurs nommés (mode zones) : longueur (unités de chaîne, comme le
-- serveur) et nombre bornés ; largeur réservée au nom dans la colonne, en
-- hauteurs de police (au-delà, nom raccourci).
RW.SECTOR_NAME_LIMIT = 32
RW.MAX_ZONE_SECTORS = 200
RW.SECTOR_NAME_EM = 12
-- Validité par défaut si le serveur ne l'envoie pas (ms réelles), et marge
-- retranchée côté client : le délai part de la réception, après celui du serveur.
RW.DEFAULT_EXPIRES_MS = 300000
RW.SAFETY_MS = 2000
RW.MAX_QTY = 99
-- Seuils de confiance affichés pour un lot réservé à un palier (options
-- sandbox, lues par nom composé ; valeurs par défaut du PLAN-V14).
RW.TIER_OPTIONS = { [2] = { "RequisitionTier2", 50 }, [3] = { "RequisitionTier3", 75 } }
RW.GROUP_COUNT = 3
-- Fermeture quand le joueur s'éloigne de la radio posée (même portée que le serveur).
RW.CLOSE_DISTANCE = Radio.MAX_WORLD_DISTANCE + 0.5
-- Textures du mod (common/media/textures/MilitaryDrop/…) ; préfixes
-- distinctifs : le jeu cherche d'abord le nom de base dans ses packs.
RW.TEXTURE_PATH = "media/textures/MilitaryDrop/RequisitionForm/MDReq_"
RW.POST_TEXTURE_PATH = "media/textures/MilitaryDrop/PostConsole/MDPost_"
-- Langues dont l'alphabet tient dans la police à chasse fixe du jeu (Latin-1) :
-- texte dactylographié ; sinon police normale.
RW.MONO_LANGUAGES = {
    EN = true, FR = true, DE = true, ES = true, IT = true, PT = true, PTBR = true, NL = true, DA = true,
    NO = true, FI = true, ID = true,
}
-- Mises en page essayées dans l'ordre : la première qui tient dans l'écran.
-- Trois colonnes serrées : beaucoup de lots (fichier de l'admin) sur un écran
-- large mais bas.
RW.MODES = {
    { cols = 2, compact = false },
    { cols = 1, compact = false },
    { cols = 2, compact = true },
    { cols = 1, compact = true },
    { cols = 3, compact = true },
}
-- Si aucune ne tient (beaucoup de lots, petit écran, écran partagé) : la
-- feuille est paginée, avec ces mises en page (la plus serrée d'abord), le
-- plus de lots possible par page. Aucune ligne n'est jamais coupée.
RW.PAGED_MODES = {
    { cols = 3, compact = true },
    { cols = 2, compact = true },
    { cols = 1, compact = true },
}

RW.instances = {}

-- ----------------------------------------------------------------------------
-- Outils partagés avec les autres fichiers du formulaire (C08 : découpe sans
-- changement de comportement) : MilitaryDrop_RequisitionWindow_Form.lua
-- (formulaire, budget, secteurs, lots), _Layout.lua (mesures et disposition),
-- _Draw.lua (dessin). Ils se chargent après ce fichier (chemins triés sans
-- casse : « . » avant « _ ») et l'exigent ; rien ici ne les appelle au chargement.
-- ----------------------------------------------------------------------------

local function measure(text, font)
    return getTextManager():MeasureStringX(font or UIFont.Small, tostring(text or ""))
end

local function fontHeight(font)
    return getTextManager():getFontHeight(font)
end

local BUDGET_KEYS = { "IGUI_MilitaryDrop_ReqBudget", "IGUI_MilitaryDrop_ReqSpent", "IGUI_MilitaryDrop_ReqLeft" }

RW.util = { measure = measure, fontHeight = fontHeight, BUDGET_KEYS = BUDGET_KEYS }

-- ----------------------------------------------------------------------------
-- Fenêtre
-- ----------------------------------------------------------------------------

function RW:new(x, y, width, height, player, device, form)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.device = device
    o.form = form
    o.background = false
    o.moveWithMouse = true
    o.maxWidth = width
    o.maxHeight = height
    o.cursor = 1
    o.done = false
    o:setWantKeyEvents(true)
    return o
end

function RW:createChildren()
    ISPanelJoypad.createChildren(self)
    self:layout()
end

function RW:layout()
    local L = RW.computeLayout(self.form, self.maxWidth, self.maxHeight, self.page)
    self:applyLayout(L)
end

function RW:applyLayout(L)
    self.L = L
    self.page = L.page
    if self.width ~= L.W or self.height ~= L.H then
        self:setWidth(L.W)
        self:setHeight(L.H)
    end
end

--- Feuille paginée : affiche la page (bornée) ; vrai si elle a changé.
function RW:setPage(page)
    local paging = self.L and self.L.paging
    if not paging then
        return false
    end
    page = math.max(1, math.min(paging.pages, page))
    if page == self.page then
        return false
    end
    self:applyLayout(RW.pageLayout(self.form, paging, page))
    return true
end

--- Page où se trouve une ligne de la manette (lot, ou leurre en dernière
--- page) ; nil pour le champ du largage (ZONE-09), au pied de chaque page.
function RW:pageOfItem(item)
    local paging = self.L and self.L.paging
    if not paging or not item then
        return nil
    end
    if item.kind == "lot" then
        return paging.pageOf[item.id]
    end
    if item.kind == "sectors" and self.form.drop then
        return nil
    end
    return paging.pages
end

--- La ligne de la manette est sur la page affichée.
function RW:showCursor()
    local page = self:pageOfItem(self:navigation()[self.cursor])
    if page then
        self:setPage(page)
    end
end

--- Molette : page suivante ou précédente.
function RW:onMouseWheel(delta)
    if self.L and self.L.paging then
        self:setPage((self.page or 1) + (delta > 0 and 1 or -1))
        return true
    end
    return false
end

--- La radio est toujours utilisable par le joueur : talkie en main (ou sur le
--- dos en solo), ou appareil posé à portée, au même étage.
function RW:deviceValid()
    local device, player = self.device, self.player
    if self.form.forced then
        -- Largage admin : la radio ne sert qu'à situer l'appel.
        return player ~= nil and not player:isDead()
    end
    if not device or not player or player:isDead() then
        return false
    end
    if Radio.isInventoryRadio(device) then
        return Radio.isCarried(player, device)
    end
    if device:getObjectIndex() == -1 then
        return false
    end
    local square = device:getSquare()
    if not square or math.floor(player:getZ()) ~= square:getZ() then
        return false
    end
    local limit = RW.CLOSE_DISTANCE
    return math.abs(player:getX() - (square:getX() + 0.5)) <= limit
        and math.abs(player:getY() - (square:getY() + 0.5)) <= limit
end

--- Lignes accessibles à la manette : lots permis, leurre, secteurs (sauf
--- secteur imposé : rien à choisir) ; avec le champ du largage (ZONE-09),
--- les secteurs en dernier (pied de la feuille), même sans leurre.
function RW:navigation()
    local form = self.form
    local items = {}
    for _, section in ipairs(RW.sections(form)) do
        for _, lot in ipairs(section.lots) do
            if lot.allowed then
                items[#items + 1] = { kind = "lot", id = lot.id }
            end
        end
        if section.decoy and form.decoy.allowed then
            items[#items + 1] = { kind = "decoy" }
            if not form.drop and not RW.fixedSector(form) then
                items[#items + 1] = { kind = "sectors" }
            end
        end
    end
    if form.drop and not RW.fixedSector(form) and RW.sectorList(form)[1] ~= nil then
        items[#items + 1] = { kind = "sectors" }
    end
    return items
end

function RW:transmit()
    local now = getTimestampMs()
    if self.done or not RW.canTransmit(self.form, now) then
        return false
    end
    self.done = true
    local Client = MilitaryDrop.Client
    if Client and Client.sendRequisition then
        local order = RW.buildOrder(self.form, nil)
        Client.sendRequisition(self.form.requestId, order.order, order.decoy, self.form, order.sector)
    end
    self:close()
    return true
end

--- Annulation : bouton « Annuler » (le personnage le dit à la radio), ou
--- fermeture de la feuille (croix, Échap, B, radio hors de portée).
function RW:cancel(spoken)
    if not self.done then
        self.done = true
        local Client = MilitaryDrop.Client
        if Client and Client.cancelRequisition then
            Client.cancelRequisition(self.form.requestId, spoken == true)
        end
    end
    self:close()
end

function RW:close()
    self:showTooltip(nil)
    if not self.done then
        -- Fermée sans transmettre : la réquisition est annulée.
        self:cancel(false)
        return
    end
    self:setVisible(false)
    if JoypadState and JoypadState.players[self.playerNum + 1] and getFocusForPlayer(self.playerNum) == self then
        setJoypadFocus(self.playerNum, nil)
    end
    self:removeFromUIManager()
    if RW.instances[self.playerNum] == self then
        RW.instances[self.playerNum] = nil
    end
end

-- ----------------------------------------------------------------------------
-- Souris
-- ----------------------------------------------------------------------------

local function inside(r, x, y)
    return r ~= nil and x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h
end

--- Élément sous (x, y) : nom, donnée (lot ou secteur).
function RW:hitTest(x, y)
    local L = self.L
    if not L then
        return nil
    end
    if inside(L.close, x, y) then
        return "close"
    elseif inside(L.transmit, x, y) then
        return "transmit"
    elseif inside(L.cancel, x, y) then
        return "cancel"
    elseif inside(L.pagePrev, x, y) then
        return "pagePrev"
    elseif inside(L.pageNext, x, y) then
        return "pageNext"
    end
    for _, lot in ipairs(self.form.lots) do
        local row = L.rows[lot.id]
        if row then
            if lot.allowed and inside(row.minus, x, y) then
                return "minus", lot.id
            elseif lot.allowed and inside(row.plus, x, y) then
                return "plus", lot.id
            elseif inside(row.row, x, y) then
                return "lot", lot.id
            end
        end
    end
    if L.zones then
        -- Secteurs nommés : flèches, nom (suivant), ou nom imposé (infobulle seule).
        if inside(L.sectorPrev, x, y) then
            return "sectorPrev"
        elseif inside(L.sectorNext, x, y) then
            return "sectorNext"
        elseif inside(L.sectorName, x, y) then
            return L.sectorPrev and "sectorName" or "sectorInfo"
        end
    else
        for _, sector in ipairs(self.form.decoy and self.form.decoy.sectors or {}) do
            if inside(L.sectorBoxes[sector], x, y) then
                return "sector", sector
            end
        end
    end
    if L.decoyRow and inside(L.decoyRow.row, x, y) then
        return "decoy"
    end
    return nil
end

function RW:mouseTarget()
    if not self:isReallyVisible() then
        return nil
    end
    local x, y = self:getMouseX(), self:getMouseY()
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return nil
    end
    return self:hitTest(x, y)
end

function RW:isEnabled(target, payload)
    local form, now = self.form, getTimestampMs()
    if target == "close" or target == "cancel" then
        return true
    elseif target == "pagePrev" or target == "pageNext" then
        local L = self.L
        return L.paging ~= nil and ((target == "pagePrev" and L.page > 1) or (target == "pageNext" and L.page < L.pages))
    elseif target == "transmit" then
        return RW.canTransmit(form, now)
    elseif RW.expired(form, now) then
        return false
    elseif target == "minus" then
        return RW.canRemove(form, payload)
    elseif target == "plus" then
        return RW.canAdd(form, payload)
    elseif target == "decoy" then
        return RW.canToggleDecoy(form)
    elseif target == "sector" then
        return RW.canPickSector(form, payload)
    elseif target == "sectorPrev" or target == "sectorNext" or target == "sectorName" then
        return RW.canStepSector(form)
    end
    return false
end

function RW:activate(target, payload)
    local form = self.form
    getSoundManager():playUISound("UIActivateButton")
    if target == "close" then
        self:close()
    elseif target == "cancel" then
        self:cancel(true)
    elseif target == "transmit" then
        self:transmit()
    elseif target == "pagePrev" or target == "pageNext" then
        self:setPage((self.page or 1) + (target == "pageNext" and 1 or -1))
    elseif target == "minus" then
        RW.remove(form, payload)
    elseif target == "plus" then
        RW.add(form, payload)
    elseif target == "decoy" then
        RW.toggleDecoy(form)
    elseif target == "sector" then
        RW.pickSector(form, payload)
    elseif target == "sectorPrev" then
        RW.stepSector(form, -1)
    elseif target == "sectorNext" or target == "sectorName" then
        RW.stepSector(form, 1)
    end
end

local CLICKABLE = { close = true, transmit = true, cancel = true, minus = true, plus = true, decoy = true, sector = true,
    pagePrev = true, pageNext = true, sectorPrev = true, sectorNext = true, sectorName = true }

function RW:onMouseDown(x, y)
    local target, payload = self:hitTest(x, y)
    if CLICKABLE[target] then
        if self:isEnabled(target, payload) then
            self.pressed, self.pressedPayload = target, payload
        end
        return true
    end
    return ISPanelJoypad.onMouseDown(self, x, y)
end

function RW:onMouseUp(x, y)
    local pressed, payload = self.pressed, self.pressedPayload
    self.pressed, self.pressedPayload = nil, nil
    if pressed then
        local target, again = self:hitTest(x, y)
        if target == pressed and again == payload and self:isEnabled(pressed, payload) then
            self:activate(pressed, payload)
        end
        return true
    end
    return ISPanelJoypad.onMouseUp(self, x, y)
end

function RW:onMouseUpOutside(x, y)
    self.pressed, self.pressedPayload = nil, nil
    return ISPanelJoypad.onMouseUpOutside(self, x, y)
end

-- ----------------------------------------------------------------------------
-- Infobulles
-- ----------------------------------------------------------------------------

local function escape(text)
    return (tostring(text or ""):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

--- Texte riche de l'infobulle de la cible, ou nil.
function RW:tooltipFor(target, payload)
    local form = self.form
    if target == "lot" or target == "minus" or target == "plus" then
        local lot = form.byId[payload]
        if not lot then
            return nil
        end
        local parts = { " <RGB:1,1,1> " .. escape(RW.lotLabel(lot)) .. " <LINE> " }
        local desc = RW.lotDesc(lot)
        if desc then
            parts[#parts + 1] = " <RGB:0.85,0.85,0.85> " .. escape(desc) .. " <LINE> "
        end
        if not lot.allowed then
            parts[#parts + 1] = " <RGB:1,0.55,0.45> " .. escape(RW.reasonText(lot))
        end
        return table.concat(parts)
    elseif form.drop and (target == "sectorPrev" or target == "sectorNext" or target == "sectorName"
        or target == "sectorInfo") then
        -- Champ du largage (ZONE-09) : libellé, explication, secteur choisi
        -- (nom libre complet, échappé).
        local parts = { " <RGB:1,1,1> " .. escape(getText("IGUI_MilitaryDrop_ReqSectorLabel")) .. " <LINE> ",
            " <RGB:0.85,0.85,0.85> " .. escape(getText("IGUI_MilitaryDrop_ReqSectorDesc")) }
        if form.sector then
            parts[#parts + 1] = " <LINE> <RGB:1,1,1> " .. escape(form.sector)
        end
        return table.concat(parts)
    elseif target == "decoy" or target == "sector" or target == "sectorPrev" or target == "sectorNext"
        or target == "sectorName" or target == "sectorInfo" then
        local parts = { " <RGB:1,1,1> " .. escape(getText("IGUI_MilitaryDrop_ReqDecoy")) .. " <LINE> ",
            " <RGB:0.85,0.85,0.85> " .. escape(getText("IGUI_MilitaryDrop_ReqDecoyDesc")) }
        -- Secteur visé : la case survolée (rose), sinon le secteur choisi ou
        -- imposé (nom libre complet, échappé : jamais interprété en balise).
        local sector = target == "sector" and payload or (target ~= "decoy" and form.sector) or nil
        if sector then
            parts[#parts + 1] = " <LINE> <RGB:1,1,1> " .. escape(RW.sectorName(form, sector))
        elseif target == "decoy" and form.decoy and not form.decoy.allowed then
            parts[#parts + 1] = " <LINE> <RGB:1,0.55,0.45> " .. escape(RW.reasonText(form.decoy))
        end
        return table.concat(parts)
    elseif target == "transmit" then
        local blocker = RW.blocker(form, getTimestampMs())
        return blocker and escape(getText("IGUI_MilitaryDrop_ReqBlock_" .. blocker)) or nil
    elseif target == "close" then
        return escape(getText("IGUI_MilitaryDrop_ReqCancel"))
    end
    return nil
end

function RW:showTooltip(text)
    if text and text ~= "" then
        if not self.tooltipUI then
            self.tooltipUI = ISToolTip:new()
            self.tooltipUI:setOwner(self)
            self.tooltipUI:setVisible(false)
            self.tooltipUI:setAlwaysOnTop(true)
            self.tooltipUI.maxLineWidth = 340
        end
        if not self.tooltipUI:getIsVisible() then
            self.tooltipUI:addToUIManager()
            self.tooltipUI:setVisible(true)
        end
        self.tooltipUI.description = text
        self.tooltipUI:setDesiredPosition(getMouseX(), getMouseY() + self.L.fh + 8)
    elseif self.tooltipUI and self.tooltipUI:getIsVisible() then
        self.tooltipUI:setVisible(false)
        self.tooltipUI:removeFromUIManager()
    end
end

function RW:update()
    ISPanelJoypad.update(self)
    if not self:getIsVisible() then
        return
    end
    if not self:deviceValid() then
        self:close()
        return
    end
    self:showTooltip(self:tooltipFor(self:mouseTarget()))
end

-- ----------------------------------------------------------------------------
-- Clavier et manette
-- ----------------------------------------------------------------------------

-- Échap ferme la feuille (annulation) sans ouvrir le menu de pause.
function RW:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function RW:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:isReallyVisible() then
        self:close()
    end
end

-- Manette : haut et bas choisissent la ligne, gauche et droite retirent ou
-- ajoutent (leurre : décoche ou coche ; secteurs : tour de la rose, ou
-- secteur nommé précédent ou suivant en mode zones et dans le champ du
-- largage), A transmet, B annule.
function RW:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self.drawJoypadFocus = true
    self:showCursor()
end

function RW:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
    self.drawJoypadFocus = false
end

function RW:moveCursor(delta)
    local count = #self:navigation()
    if count > 0 then
        self.cursor = math.max(1, math.min(count, self.cursor + delta))
        -- Feuille paginée : la page suit la ligne choisie.
        self:showCursor()
    end
end

--- Gauche (-1) ou droite (+1) sur la ligne de la manette.
function RW:stepCursor(delta)
    local form = self.form
    if RW.expired(form, getTimestampMs()) then
        return
    end
    local item = self:navigation()[self.cursor]
    if not item then
        return
    end
    if item.kind == "lot" then
        if delta > 0 then
            RW.add(form, item.id)
        else
            RW.remove(form, item.id)
        end
    elseif item.kind == "decoy" then
        if (delta > 0) ~= form.decoyOn then
            RW.toggleDecoy(form)
        end
    elseif item.kind == "sectors" then
        -- Tour de la rose (N, E, S, O) ou secteur nommé précédent/suivant.
        RW.stepSector(form, delta)
    end
end

function RW:onJoypadDown(button)
    if button == Joypad.AButton then
        self:transmit()
    elseif button == Joypad.BButton then
        self:cancel(true)
    end
end

function RW:onJoypadDirUp()
    self:moveCursor(-1)
end

function RW:onJoypadDirDown()
    self:moveCursor(1)
end

function RW:onJoypadDirLeft()
    self:stepCursor(-1)
end

function RW:onJoypadDirRight()
    self:stepCursor(1)
end

function RW:getAPrompt()
    return getText("IGUI_MilitaryDrop_ReqTransmit")
end

function RW:getBPrompt()
    return getText("IGUI_MilitaryDrop_ReqCancel")
end

-- ----------------------------------------------------------------------------
-- Ouverture
-- ----------------------------------------------------------------------------

--- Ouvre la feuille du joueur pour le Result « form » args (reçu à
--- receivedMs). Une feuille déjà ouverte pour ce joueur est annulée.
--- anchor (facultatif) : fenêtre radio du jeu d'où vient la demande (module
--- « Logistique ») ; la feuille s'ouvre collée à elle.
function RW.open(player, device, args, receivedMs, anchor)
    return RW.show(player, device, RW.newForm(args, receivedMs or getTimestampMs()), anchor)
end

--- Rectangle à l'écran de la fenêtre d'ancrage, si elle est encore affichée.
function RW.anchorRect(anchor)
    if type(anchor) ~= "table" or not anchor.getIsVisible or not anchor:getIsVisible() then
        return nil
    end
    local x = anchor.getAbsoluteX and anchor:getAbsoluteX() or anchor:getX()
    local y = anchor.getAbsoluteY and anchor:getAbsoluteY() or anchor:getY()
    return { x = x, y = y, w = anchor:getWidth(), h = anchor:getHeight() }
end

--- Position d'une feuille width × height collée à la fenêtre a : à sa droite,
--- sinon à sa gauche si la droite déborde de l'écran s du joueur, sinon le
--- côté le moins débordant ramené dans l'écran ; hauteur alignée sur le haut
--- de la fenêtre, ramenée dans l'écran.
function RW.anchoredPosition(width, height, a, s)
    local right, left = a.x + a.w, a.x - width
    local x
    if right + width <= s.x + s.w then
        x = right
    elseif left >= s.x then
        x = left
    else
        local spaceRight, spaceLeft = s.x + s.w - right, a.x - s.x
        x = spaceRight >= spaceLeft and right or left
    end
    x = math.max(s.x, math.min(x, s.x + s.w - width))
    local y = math.max(s.y, math.min(a.y, s.y + s.h - height))
    return math.floor(x), math.floor(y)
end

--- Affiche la feuille d'un formulaire (nouveau, ou rouvert après un refus
--- qui garde l'autorisation : radio éteinte, cadence). anchor : voir RW.open.
function RW.show(player, device, form, anchor)
    local playerNum = player:getPlayerNum()
    local previous = RW.instances[playerNum]
    if previous then
        previous:close()
    end
    local screenW, screenH = getPlayerScreenWidth(playerNum), getPlayerScreenHeight(playerNum)
    local screenX, screenY = getPlayerScreenLeft(playerNum), getPlayerScreenTop(playerNum)
    local width, height = RW.measureSize(form, screenW, screenH)
    width, height = math.min(width, screenW), math.min(height, screenH)
    local x = screenX + math.floor((screenW - width) / 2)
    local y = screenY + math.floor((screenH - height) / 2)
    local anchorBox = RW.anchorRect(anchor)
    if anchorBox then
        x, y = RW.anchoredPosition(width, height, anchorBox, { x = screenX, y = screenY, w = screenW, h = screenH })
    end
    local window = RW:new(x, y, width, height, player, device, form)
    window.maxWidth, window.maxHeight = screenW, screenH
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    RW.instances[playerNum] = window
    if JoypadState and JoypadState.players[playerNum + 1] then
        if getPlayerInventory(playerNum) then
            getPlayerInventory(playerNum):close()
        end
        if getPlayerLoot(playerNum) then
            getPlayerLoot(playerNum):close()
        end
        setJoypadFocus(playerNum, window)
    end
    return window
end

--- Ferme sans rien envoyer la feuille d'une demande que le serveur a déjà
--- tranchée (réponse reçue pendant que la feuille est ouverte).
function RW.dismiss(requestId)
    local closing = {}
    for _, window in pairs(RW.instances) do
        if window.form.requestId == requestId then
            closing[#closing + 1] = window
        end
    end
    for _, window in ipairs(closing) do
        window.done = true
        window:close()
    end
end

return RW
