-- ============================================================================
-- Military Drop — fenêtre « Logistique » séparée, pour les mods qui remplacent
-- toute la fenêtre radio (client)
--
-- Sans ces mods (MilitaryDrop.RadioModule.windowReplaced faux), ce fichier
-- ne fait rien : le module reste dans la fenêtre radio du jeu.
--
-- Avec l'un d'eux (TVRadio ReInvented), le module « Logistique » ne peut pas
-- entrer dans leur fenêtre. Ce fichier enveloppe ISRadioWindow.activate (par
-- où passent « Options de l'appareil » et la prise en main d'une radio) :
-- après leur fenêtre, il ouvre, pour une radio militaire, une petite fenêtre
-- portant le même panneau (MilitaryDrop.RadioModule.Panel), collée à droite
-- de la leur (à gauche si l'écran manque). Elle suit la fenêtre radio et se
-- ferme avec elle ou quand elle passe à un autre appareil.
--
-- Une fenêtre par joueur local, créée une fois puis réutilisée. Fenêtre
-- radio cherchée dans ISRadioWindow.instances / instancesIso (même rangement
-- que le vanilla et TVRadio), pas dans la valeur rendue par activate.
-- Limite : la manette reste sur la fenêtre radio (pas de navigation ici).
-- ============================================================================

require "ISUI/ISCollapsableWindow"
require "RadioCom/ISRadioWindow"
require "MilitaryDrop/MilitaryDrop_RadioModule"

local RM = MilitaryDrop.RadioModule

-- Table conservée si le fichier est rechargé (débogage) : l'enveloppe n'est
-- jamais posée deux fois.
local RC = MilitaryDrop.RadioCompanion or {}
MilitaryDrop.RadioCompanion = RC
RC.windows = RC.windows or {}

-- ----------------------------------------------------------------------------
-- Fenêtre
-- ----------------------------------------------------------------------------

local Window = ISCollapsableWindow:derive("MilitaryDropLogisticsWindow")
RC.Window = Window

function Window:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = getText("IGUI_MilitaryDrop_Logistics")
    o.resizable = false
    return o
end

function Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.panel = RM.Panel:new(0, self:titleBarHeight(), self.width, 0)
    -- Ancre de la feuille de réquisition (Panel:onRequest).
    self.panel.radioWindow = self
    self.panel:initialise()
    self:addChild(self.panel)
    self:calculateHeights()
end

--- Appelé par le panneau quand sa hauteur change (setContentHeight).
function Window:calculateHeights()
    if self.panel then
        self:setHeight(self:titleBarHeight() + self.panel:getHeight())
    end
end

--- Colle la fenêtre à droite de la fenêtre radio, à gauche si l'écran du
--- joueur manque de place.
function Window:stickTo(radioWindow)
    local x = radioWindow:getX() + radioWindow:getWidth()
    local right = getPlayerScreenLeft(self.playerNum) + getPlayerScreenWidth(self.playerNum)
    if x + self.width > right then
        x = radioWindow:getX() - self.width
    end
    if self.x ~= x then
        self:setX(x)
    end
    if self.y ~= radioWindow:getY() then
        self:setY(radioWindow:getY())
    end
end

--- Montre le panneau pour cet appareil ; ferme la fenêtre s'il ne s'y
--- affiche pas (radio non militaire).
function Window:follow(radioWindow, player, device)
    self.radioWindow = radioWindow
    self.device = device
    self.playerNum = player:getPlayerNum()
    self.panel:clear()
    if not self.panel:readFromObject(player, device, radioWindow.deviceData or device:getDeviceData(),
        radioWindow.deviceType) then
        self:close()
        return false
    end
    self:stickTo(radioWindow)
    self:addToUIManager()
    self:setVisible(true)
    return true
end

function Window:update()
    ISCollapsableWindow.update(self)
    local radioWindow = self.radioWindow
    if not radioWindow or not radioWindow:getIsVisible() or radioWindow.device ~= self.device then
        self:close()
        return
    end
    self:stickTo(radioWindow)
end

function Window:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if self.panel then
        self.panel:clear()
    end
    self.radioWindow = nil
    self.device = nil
end

-- ----------------------------------------------------------------------------
-- Ouverture
-- ----------------------------------------------------------------------------

--- Fenêtre radio du joueur pour ce genre d'appareil (inventaire ou posé).
function RC.radioWindowFor(playerNum, device)
    local instances = instanceof(device, "Radio") and ISRadioWindow.instances or ISRadioWindow.instancesIso
    return instances and instances[playerNum]
end

--- Après l'ouverture de la fenêtre radio : ouvre ou ferme la fenêtre
--- « Logistique » du joueur.
function RC.open(player, device)
    local playerNum = player:getPlayerNum()
    local window = RC.windows[playerNum]
    local radioWindow = RC.radioWindowFor(playerNum, device)
    if not radioWindow or not RM.shows(device) then
        if window then
            window:close()
        end
        return false
    end
    if not window then
        local width = math.max(260, getTextManager():getFontHeight(UIFont.Small) * 18)
        window = Window:new(radioWindow:getX() + radioWindow:getWidth(), radioWindow:getY(), width, 100)
        window:initialise()
        window:instantiate()
        RC.windows[playerNum] = window
    end
    return window:follow(radioWindow, player, device)
end

--- Enveloppe ISRadioWindow.activate une seule fois, seulement si la fenêtre
--- radio est remplacée ; reposée au prochain menu contextuel si
--- ISRadioWindow.lua a été rechargé (comme RM.installWindowWrapper).
function RC.install()
    local RadioWindow = ISRadioWindow
    if not RM.windowReplaced() or not RadioWindow or type(RadioWindow.activate) ~= "function"
        or (RC.activateWrapper and RadioWindow.activate == RC.activateWrapper) then
        return false
    end
    local original = RadioWindow.activate
    RC.originalActivate = original
    RC.activateWrapper = function(player, device, ...)
        local result = original(player, device, ...)
        if player and device then
            RC.open(player, device)
        end
        return result
    end
    RadioWindow.activate = RC.activateWrapper
    return true
end

function RC.onFillContextMenu()
    RC.install()
end

RC.install()
Events.OnGameStart.Add(RC.install)
Events.OnFillInventoryObjectContextMenu.Add(RC.onFillContextMenu)
Events.OnFillWorldObjectContextMenu.Add(RC.onFillContextMenu)

return RC
