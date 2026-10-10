-- MilitaryDrop_RadioModule : module « Logistique » de la fenêtre radio du jeu.
-- Affiché seulement pour une radio militaire, enveloppe idempotente de
-- ISRadioWindow.createChildren, code mémorisé et envoyé, boutons grisés avec
-- leur raison, feuille de réquisition ancrée à la fenêtre radio, dernière
-- réplique de la base, manette. Positions de l'ancrage : test_requisitionwindow.

local T = {}

local CHAR_W = 7
local FONT_H = 16

--- Classe d'interface simulée : position, taille, enfants.
local function newClass(name, base)
    local cls = setmetatable({ Type = name }, { __index = base })
    cls.__index = cls
    return cls
end

local function makeUI()
    UIBase = newClass("UIBase")
    function UIBase.new(cls, x, y, w, h)
        local o = setmetatable({}, cls)
        o.x, o.y, o.width, o.height, o.visible = x, y, w, h, true
        return o
    end
    function UIBase:derive(name) return newClass(name, self) end
    function UIBase:initialise() end
    function UIBase:instantiate()
        if not self.instantiated then
            self.instantiated = true
            if self.createChildren then
                self:createChildren()
            end
        end
    end
    function UIBase:addChild(child)
        child:instantiate()
        child.parent = self
    end
    function UIBase:setX(v) self.x = v end
    function UIBase:setY(v) self.y = v end
    function UIBase:getX() return self.x end
    function UIBase:getY() return self.y end
    function UIBase:getWidth() return self.width end
    function UIBase:getHeight() return self.height end
    function UIBase:setWidth(v) self.width = v end
    function UIBase:setHeight(v) self.height = v end
    function UIBase:setVisible(v) self.visible = v end
    function UIBase:getIsVisible() return self.visible end
    function UIBase:update() end
    function UIBase:render() end
    function UIBase:drawText() end
    function UIBase:drawRect() end
    function UIBase:drawRectBorder() end

    ISPanel = UIBase:derive("ISPanel")
    RWMPanel = UIBase:derive("RWMPanel")
    function RWMPanel:new(x, y, w, h) return UIBase.new(self, x, y, w, h) end
    function RWMPanel:readFromObject(player, device, data, kind)
        self.player, self.device, self.deviceData, self.deviceType = player, device, data, kind
        return true
    end
    function RWMPanel:clear()
        self.player, self.device, self.deviceData, self.deviceType = nil, nil, nil, nil
        self.focusElement = nil
    end

    ISButton = UIBase:derive("ISButton")
    function ISButton:new(x, y, w, h, title, target, onclick)
        local o = UIBase.new(self, x, y, w, h)
        o.title, o.target, o.onclick, o.enable = title, target, onclick, true
        return o
    end
    function ISButton:setTitle(t) self.title = t end
    function ISButton:setEnable(v) self.enable = v end
    function ISButton:setTooltip(t) self.tooltip = t end
    function ISButton:setJoypadFocused(v) self.joypadFocused = v end
    function ISButton:forceClick()
        if self.enable then
            self.onclick(self.target, self)
        end
    end

    ISTextEntryBox = UIBase:derive("ISTextEntryBox")
    function ISTextEntryBox:new(text, x, y, w, h)
        local o = UIBase.new(self, x, y, w, h)
        o.text = text
        return o
    end
    function ISTextEntryBox:getText() return self.text end
    function ISTextEntryBox:setText(t) self.text = t end
    function ISTextEntryBox:setMaxTextLength(n) self.maxLength = n end
    function ISTextEntryBox:setPlaceholderText(t) self.placeholder = t end
    function ISTextEntryBox:setTooltip(t) self.tooltip = t end
    function ISTextEntryBox:setJoypadFocused(v) self.joypadFocused = v end
    --- Saisie du joueur (clavier ou clavier à l'écran) : comme UITextBox2.
    function ISTextEntryBox:type(t)
        self.text = t
        if self.onTextChangeFunction then
            self.onTextChangeFunction(self.target, self)
        end
    end

    OUTER_MOVES = 0
    RWMElement = UIBase:derive("RWMElement")
    function RWMElement:new(x, y, w, h, subpanel, title, radioParent)
        local o = UIBase.new(self, x, y, w, h)
        o.subpanel, o.titleText, o.radioParent = subpanel, title, radioParent
        return o
    end
    function RWMElement:createChildren()
        self.subpanel:setWidth(self.width)
        self:addChild(self.subpanel)
    end
    function RWMElement:calculateHeights() self.heights = (self.heights or 0) + 1 end
    function RWMElement:onJoypadDirUp() OUTER_MOVES = OUTER_MOVES - 1 end
    function RWMElement:onJoypadDirDown() OUTER_MOVES = OUTER_MOVES + 1 end

    -- Fenêtre radio vanilla réduite à ce qu'utilise le module.
    ORIGINAL_CHILDREN = 0
    ISRadioWindow = UIBase:derive("ISRadioWindow")
    function ISRadioWindow:createChildren()
        ORIGINAL_CHILDREN = ORIGINAL_CHILDREN + 1
        self:addModule(RWMPanel:new(0, 0, self.width, 0), "IGUI_RadioGeneral", true)
    end
    function ISRadioWindow:addModule(panel, name, enable)
        local module = { enabled = enable, element = RWMElement:new(0, 0, self.width, 0, panel, name, self) }
        table.insert(self.modules, module)
        self:addChild(module.element)
    end
    function ISRadioWindow:readFromObject(player, device)
        for _, module in ipairs(self.modules) do
            module.enabled = module.element.subpanel:readFromObject(player, device, device:getDeviceData(), "x")
        end
    end
end

--- Fenêtre radio neuve (createChildren comme ISRadioWindow:instantiate).
local function newWindow()
    local window = UIBase.new(ISRadioWindow, 100, 50, 300, 500)
    window.modules = {}
    window:instantiate()
    return window
end

--- Radio d'inventaire ou posée ; opts : highTier, portable, on.
local function makeRadio(kind, opts)
    opts = opts or {}
    local data = {
        getIsHighTier = function() return opts.highTier ~= false end,
        getIsPortable = function() return opts.portable ~= false end,
        getIsTurnedOn = function() return opts.on ~= false end,
        getDeviceVolume = function() return 0.5 end,
    }
    local radio = { kind = kind, said = {} }
    radio.getDeviceData = function() return data end
    radio.getID = function() return 42 end
    radio.getContainer = function() return { isInCharacterInventory = function() return true end } end
    radio.AddDeviceText = function(self, text) self.said[#self.said + 1] = text end
    if kind == "IsoWaveSignal" then
        radio.getSquare = function()
            return { getX = function() return 10 end, getY = function() return 10 end, getZ = function() return 0 end }
        end
    end
    return radio
end

function T.setup()
    SandboxVars = { MilitaryDrop = { AuthCode = 3 } }
    isClient = function() return false end
    isServer = function() return false end
    isDebugEnabled = function() return false end
    NOW = 1000
    getTimestampMs = function() return NOW end
    getText = function(k, a) return a ~= nil and (k .. "|" .. tostring(a)) or k end
    ZombRand = function() return 0 end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    UIFont = { Small = "Small" }
    getTextManager = function()
        return {
            getFontHeight = function() return FONT_H end,
            MeasureStringX = function(_, _, s) return #tostring(s) * CHAR_W end,
        }
    end
    Joypad = { AButton = 0, BButton = 1, LBumper = 4, RBumper = 5 }
    JoypadState = { players = {} }
    KEYBOARD_SHOWN = nil
    OnScreenKeyboard = {
        IsVisible = function() return KEYBOARD_SHOWN ~= nil end,
        Show = function(playerNum, entry, joypadData)
            KEYBOARD_SHOWN = { playerNum = playerNum, entry = entry, joypadData = joypadData }
            return KEYBOARD_SHOWN
        end,
    }
    makeUI()
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    -- Chargé par le require de MilitaryDrop_Exchange.lua (sans effet dans le banc).
    loadMod("shared/MilitaryDrop/MilitaryDrop_Fulton.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Exchange.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_Client.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_ExchangeMenu.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_RadioModule.lua")
    RM = MilitaryDrop.RadioModule
    -- Monde simulé : joueur, messages au serveur, échanges, feuilles ouvertes.
    W = { said = {}, toServer = {}, exchanges = {}, opened = {}, runs = 0 }
    RADIO = makeRadio("Radio")
    PLAYER = {
        getPlayerNum = function() return 0 end,
        Say = function(_, text) W.said[#W.said + 1] = text end,
        getPrimaryHandItem = function() return RADIO end,
        getSecondaryHandItem = function() return nil end,
        getClothingItem_Back = function() return nil end,
        isAttachedItem = function() return false end,
        getX = function() return 10.5 end,
        getY = function() return 10.5 end,
        getZ = function() return 0 end,
    }
    getSpecificPlayer = function() return PLAYER end
    MilitaryDrop.Server = { onClientCommand = function(_, command, _, args)
        W.toServer[#W.toServer + 1] = { command = command, args = args }
    end }
    MilitaryDrop.Exchange.run = function(_, _, _, callback)
        W.runs = W.runs + 1
        callback()
        return true
    end
    MilitaryDrop.Exchange.send = function(_, _, command, _, speech)
        W.exchanges[#W.exchanges + 1] = { command = command, speech = speech }
        return true
    end
    DOG_TAGS = {}
    MilitaryDrop.ExchangeMenu.dogTags = function() return DOG_TAGS end
    MilitaryDrop.RequisitionWindow = {
        open = function(player, device, args, receivedMs, anchor)
            W.opened[#W.opened + 1] = { device = device, anchor = anchor }
        end,
    }
end

--- Panneau du module dans une fenêtre ouverte sur device.
local function openOn(device)
    local window = newWindow()
    window:readFromObject(PLAYER, device)
    local module = window.militaryDropModule
    return module.element.subpanel, module, window
end

local function wait(ms)
    NOW = NOW + ms
    triggerEvent("OnTick")
end

function T.module_shows_only_for_a_military_radio()
    local _, module, window = openOn(RADIO)
    assertEq(#window.modules, 2, "module vanilla puis « Logistique »")
    assertEq(window.modules[2], module, "ajouté en dernier")
    assertEq(module.element.titleText, "IGUI_MilitaryDrop_Logistics", "titre du module")
    assertTrue(module.enabled, "talkie militaire : affiché")
    window:readFromObject(PLAYER, makeRadio("Radio", { highTier = false }))
    assertTrue(not module.enabled, "radio ordinaire : caché")
    window:readFromObject(PLAYER, makeRadio("Radio", { portable = false }))
    assertTrue(not module.enabled, "radio fixe dans l'inventaire : caché")
    window:readFromObject(PLAYER, makeRadio("IsoWaveSignal", { portable = false }))
    assertTrue(module.enabled, "radio militaire posée : affiché")
    window:readFromObject(PLAYER, makeRadio("VehiclePart"))
    assertTrue(not module.enabled, "radio de véhicule : caché")
end

function T.wrapper_is_installed_once()
    local wrapper = ISRadioWindow.createChildren
    assertTrue(wrapper == RM.windowWrapper, "enveloppe posée au chargement")
    assertTrue(not RM.installWindowWrapper(), "pas de seconde enveloppe")
    triggerEvent("OnGameStart")
    assertTrue(ISRadioWindow.createChildren == wrapper, "toujours la même après OnGameStart")
    local window = newWindow()
    assertEq(ORIGINAL_CHILDREN, 1, "original appelé une fois")
    assertEq(#window.modules, 2, "un seul module ajouté")
    assertTrue(not RM.addTo(window), "pas de second module sur la même fenêtre")
    assertEq(#window.modules, 2, "toujours deux modules")
    -- Rechargement d'ISRadioWindow.lua : nouvel original enveloppé à son tour.
    local reloaded = function(self) ORIGINAL_CHILDREN = ORIGINAL_CHILDREN + 10; self.modules = self.modules or {} end
    ISRadioWindow.createChildren = reloaded
    assertTrue(RM.installWindowWrapper(), "enveloppe reposée")
    assertTrue(RM.originalCreateChildren == reloaded, "sur le nouvel original")
    -- L'enveloppe du talkie à la ceinture (update) n'est pas touchée.
    assertTrue(ISRadioWindow.update == UIBase.update, "update intact")
end

function T.code_is_remembered_and_sent_with_the_request()
    local panel, _, window = openOn(RADIO)
    assertTrue(panel.codeShown, "code exigé : champ affiché")
    assertEq(panel.codeEntry:getText(), "", "rien en mémoire au départ")
    assertEq(panel.codeEntry.maxLength, MilitaryDrop.Codes.MAX_INPUT_LENGTH, "longueur bornée")
    panel:refresh()
    assertTrue(not panel.requestButton.enable, "sans code : largage grisé")
    assertEq(panel.requestButton.reason, "IGUI_MilitaryDrop_RadioModule_NeedCode", "raison : code manquant")
    panel.codeEntry:type("  bravo-kilo-42 ")
    assertEq(MilitaryDrop.Client.rememberedCode(0), "bravo-kilo-42", "code gardé pour la session")
    panel:refresh()
    assertTrue(panel.requestButton.enable, "code saisi : largage permis")
    panel.requestButton:forceClick()
    assertEq(W.runs, 1, "prise en main du talkie (Exchange.run)")
    local request = W.toServer[1]
    assertEq(request.command, "Request", "appel envoyé")
    assertEq(request.args.code, "bravo-kilo-42", "code envoyé à l'appel")
    assertEq(request.args.radio.id, 42, "radio de la fenêtre")
    assertTrue(not panel.requestButton.enable, "bouton bloqué après l'envoi")
    assertEq(panel.requestButton.reason, "IGUI_MilitaryDrop_RadioModule_Sending", "transmission en cours")
    -- Fenêtre rouverte (ou autre radio) : champ prérempli.
    window:readFromObject(PLAYER, RADIO)
    assertEq(panel.codeEntry:getText(), "bravo-kilo-42", "prérempli")
    -- Réponse « form » : la feuille s'ouvre ancrée à la fenêtre radio.
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "Result", { requestId = request.args.requestId,
        status = "form", callsign = "Station Kilo-7", budget = 4, lots = {} })
    wait(MilitaryDrop.Client.REPLY_DELAY_MS)
    assertEq(#W.opened, 1, "feuille ouverte")
    assertTrue(W.opened[1].anchor == window, "ancrée à la fenêtre radio")
    -- Sans code exigé : champ caché, appel sans code.
    SandboxVars.MilitaryDrop.AuthCode = MilitaryDrop.Codes.MODE_NONE
    wait(RM.LOCK_MS)
    panel:refresh()
    assertTrue(not panel.codeShown and not panel.codeEntry.visible, "champ caché")
    assertTrue(panel:onRequest(), "appel sans code")
    assertEq(W.toServer[#W.toServer].args.code, nil, "aucun code envoyé")
end

function T.code_field_is_prefilled_after_a_reload()
    local files = {}
    getFileWriter = function(name)
        return { write = function(_, text) files[name] = text end, close = function() end }
    end
    getFileReader = function(name)
        local content = files[name]
        return content and { readLine = function() return content end, close = function() end } or nil
    end
    getWorld = function() return { getWorld = function() return "Partie" end } end
    PLAYER.getUsername = function() return "Kate Smith" end
    PLAYER.getDescriptor = function()
        return { getForename = function() return "Kate" end, getSurname = function() return "Smith" end }
    end
    local panel = openOn(RADIO)
    panel.codeEntry:type("bravo-kilo-42")
    assertEq(files[MilitaryDrop.Client.codeFile(PLAYER)], "bravo-kilo-42", "gardé dans le fichier du personnage")
    -- Partie rechargée : module client relu, nouvelle fenêtre radio.
    loadMod("client/MilitaryDrop/MilitaryDrop_Client.lua")
    local reopened = openOn(RADIO)
    assertEq(reopened.codeEntry:getText(), "bravo-kilo-42", "champ prérempli après rechargement")
end

function T.menu_request_has_no_anchor()
    -- Le menu contextuel garde la feuille centrée (pas d'ancre).
    MilitaryDrop.Client.sendRequest(PLAYER, RADIO, "x", false)
    local requestId = W.toServer[1].args.requestId
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "Result", { requestId = requestId, status = "form",
        callsign = "Station Kilo-7", budget = 4, lots = {} })
    wait(MilitaryDrop.Client.REPLY_DELAY_MS)
    assertEq(W.opened[1].anchor, nil, "pas d'ancre")
end

function T.buttons_are_greyed_with_the_menu_reasons()
    local panel = openOn(RADIO)
    local byLabel = {}
    for _, button in ipairs(panel.optionButtons) do
        byLabel[button.option.source] = button
    end
    panel:refresh()
    assertTrue(byLabel.report.enable, "rapport permis")
    assertTrue(not byLabel.dogtag.enable, "aucune plaque : grisé")
    assertEq(byLabel.dogtag.reason, "IGUI_MilitaryDrop_NoDogTags", "raison du menu")
    assertEq(byLabel.dogtag.fullTitle, "IGUI_MilitaryDrop_Exchange_DogTags (0)", "nombre de plaques affiché")
    local function tag(name) return { getDisplayName = function() return name end } end
    DOG_TAGS = { tag("J. Miller"), tag("R. Ortega"), tag("T. Nguyen") }
    panel:refresh()
    assertTrue(byLabel.dogtag.enable, "trois plaques : permis")
    assertEq(byLabel.dogtag.fullTitle, "IGUI_MilitaryDrop_Exchange_DogTags (3)", "trois plaques")
    assertTrue(byLabel.dogtag.tooltip:find("J. Miller", 1, true) ~= nil, "infobulle : noms des soldats")
    -- Source désactivée sur le serveur.
    SandboxVars.MilitaryDrop.ReconGain = 0
    panel:refresh()
    assertEq(byLabel.recon.reason, "IGUI_MilitaryDrop_SourceDisabled", "source désactivée")
    -- Radio éteinte : tout est grisé avec la même raison que le menu.
    local off = makeRadio("Radio", { on = false })
    RADIO = off
    local panelOff = openOn(off)
    assertEq(panelOff.requestButton.reason, "IGUI_MilitaryDrop_TurnOn", "largage : radio éteinte")
    assertEq(panelOff.optionButtons[1].reason, "IGUI_MilitaryDrop_TurnOn", "rapport : radio éteinte")
    assertEq(panelOff.requestButton.tooltip, "IGUI_MilitaryDrop_TurnOn", "raison dans l'infobulle")
    -- Radio posée trop loin.
    local far = makeRadio("IsoWaveSignal", { portable = false })
    far.getSquare = function() return { getX = function() return 50 end, getY = function() return 50 end,
        getZ = function() return 0 end } end
    local panelFar = openOn(far)
    assertEq(panelFar.requestButton.reason, "IGUI_MilitaryDrop_TooFar", "radio posée trop loin")
end

function T.option_buttons_send_the_menu_exchanges()
    local panel = openOn(RADIO)
    panel.optionButtons[1]:forceClick()
    assertEq(#W.exchanges, 1, "un échange")
    assertEq(W.exchanges[1].command, "MissionReport", "rapport de situation")
    assertEq(W.exchanges[1].speech, "IGUI_MilitaryDrop_Say_Report_1|0", "réplique du personnage")
    panel.optionButtons[4]:forceClick()
    assertEq(#W.exchanges, 1, "double clic bloqué pendant la transmission")
    wait(RM.LOCK_MS)
    panel:refresh()
    panel.optionButtons[4]:forceClick()
    assertEq(W.exchanges[2].command, "MissionControl", "confirmation de réception")
end

function T.status_button_needs_an_open_cleanup()
    local panel = openOn(RADIO)
    local status = panel.optionButtons[#panel.optionButtons]
    assertEq(status.option.command, "cleanupStatus", "« Faire le point » en dernier")
    panel:refresh()
    assertTrue(not status.enable, "aucun nettoyage : grisé")
    assertEq(status.reason, "IGUI_MilitaryDrop_NoCleanup", "avec sa raison")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "CleanupState", { open = true })
    panel:refresh()
    assertTrue(status.enable, "nettoyage annoncé : permis")
    status:forceClick()
    assertEq(W.exchanges[1].command, "MissionCleanupStatus", "échange envoyé au serveur")
    assertEq(W.exchanges[1].speech, "IGUI_MilitaryDrop_Say_CleanupStatus_1|0", "réplique du personnage")
    SandboxVars.MilitaryDrop.CleanupGain = 0
    wait(RM.LOCK_MS)
    panel:refresh()
    assertEq(status.reason, "IGUI_MilitaryDrop_SourceDisabled", "nettoyages désactivés")
    -- Solo : l'état du serveur est lu directement.
    SandboxVars.MilitaryDrop.CleanupGain = 5
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "CleanupState", { open = false })
    MilitaryDrop.Missions = { openMission = function(kind) return kind == "cleanup" and {} or nil end }
    panel:refresh()
    assertTrue(status.enable, "solo : mission ouverte lue sur le serveur")
end

function T.post_radio_shows_only_the_liaison_post_button()
    local calls = { queried = 0, used = 0 }
    local status = "none"
    MilitaryDrop.PostWindow = {
        isEligible = function(device) return device.kind == "IsoWaveSignal" and not device:getDeviceData():getIsPortable() end,
        queryStatus = function() calls.queried = calls.queried + 1 end,
        useReason = function() return status == "otherTeam" and "IGUI_MilitaryDrop_PostResult_otherTeam" or nil end,
        useTooltip = function() return "IGUI_MilitaryDrop_PostInstallTooltip" end,
        useRadio = function() calls.used = calls.used + 1 return "install" end,
    }
    local ham = makeRadio("IsoWaveSignal", { portable = false })
    local panel = openOn(ham)
    assertTrue(panel.postMode, "radio fixe éligible : mode poste")
    assertEq(calls.queried, 1, "état de la radio demandé au serveur")
    local items = panel:items()
    assertEq(#items, 1, "un seul élément")
    assertTrue(items[1] == panel.postButton and panel.postButton.visible, "bouton « Poste de liaison »")
    assertEq(panel.postButton.fullTitle, "IGUI_MilitaryDrop_PostOpen", "libellé")
    assertTrue(not panel.requestButton.visible and not panel.codeEntry.visible, "ni largage ni code")
    for _, button in ipairs(panel.optionButtons) do
        assertTrue(not button.visible, "aucun échange")
    end
    assertEq(panel.height, RM.BORDER * 2 + panel.buttonH, "module réduit au bouton")
    assertEq(panel.postButton.tooltip, "IGUI_MilitaryDrop_PostInstallTooltip", "infobulle")
    panel.postButton:forceClick()
    assertEq(calls.used, 1, "action du poste")
    assertTrue(not panel.postButton.enable, "bloqué pendant l'envoi")
    wait(RM.LOCK_MS)
    status = "otherTeam"
    panel:refresh()
    assertEq(panel.postButton.reason, "IGUI_MilitaryDrop_PostResult_otherTeam", "poste d'une autre équipe : grisé")
    -- Manette : A sur le module choisit le bouton.
    panel:onJoypadDown(Joypad.AButton)
    assertTrue(panel:focusedItem() == panel.postButton, "manette : le bouton")
    -- Même fenêtre, talkie posé : module complet.
    local window = panel.parent.radioParent
    window:readFromObject(PLAYER, makeRadio("IsoWaveSignal", { portable = true }))
    assertTrue(not panel.postMode, "talkie posé : module complet")
    assertTrue(panel.requestButton.visible and not panel.postButton.visible, "largage de retour")
    assertEq(panel:focusedItem(), nil, "curseur relâché au changement de mode")
end

function T.last_reply_of_the_base_is_shown()
    local panel = openOn(RADIO)
    assertEq(#panel.replyLines, 0, "rien reçu")
    local height = panel.height
    MilitaryDrop.Client.radioSay({ playerNum = 0, device = RADIO },
        "Station Kilo-7, ici Logistique. Rapport de situation reçu. Merci, terminé.")
    wait(RM.REFRESH_MS)
    panel:update()
    assertTrue(#panel.replyLines >= 2, "réplique coupée en lignes")
    for _, line in ipairs(panel.replyLines) do
        assertTrue(#line * CHAR_W <= panel.width - 2 * RM.BORDER, "ligne dans la largeur : " .. line)
    end
    assertTrue(panel.height > height, "module agrandi")
    assertTrue(panel.parent.heights ~= nil, "hauteur de l'en-tête recalculée")
    -- Réplique démesurée : bornée, finie par « ... ».
    MilitaryDrop.Client.radioSay({ playerNum = 0, device = RADIO }, string.rep("bla ", 200))
    panel:refresh()
    assertEq(#panel.replyLines, RM.MAX_REPLY_LINES, "lignes bornées")
    assertEq(panel.replyLines[#panel.replyLines]:sub(-3), "...", "texte raccourci")
    -- Réplique d'un autre joueur local (écran partagé) : non affichée.
    MilitaryDrop.Client.radioSay({ playerNum = 1, device = RADIO }, "autre joueur")
    panel:refresh()
    assertTrue(panel.replyLines[1] ~= "autre joueur", "réplique du joueur seulement")
end

function T.labels_fit_the_module_width()
    getText = function(k)
        if k == "IGUI_MilitaryDrop_Exchange_Report" then
            return string.rep("Rapport ", 20)
        end
        return k
    end
    local panel = openOn(RADIO)
    local report = panel.optionButtons[1]
    assertTrue(#report.title * CHAR_W <= report.width, "titre raccourci à la largeur")
    assertEq(report.title:sub(-3), "...", "« ... »")
    assertTrue(report.tooltip:find(string.rep("Rapport ", 20), 1, true) == 1, "titre entier dans l'infobulle")
    for _, button in ipairs(panel:items()) do
        assertTrue(button.x >= RM.BORDER and button.x + button.width <= panel.width - RM.BORDER + 1,
            "élément dans le module")
    end
end

function T.joypad_navigates_inside_the_module()
    local panel, module = openOn(RADIO)
    local element = module.element
    JoypadState.players[1] = { focus = element }
    element:onJoypadDirDown()
    assertEq(OUTER_MOVES, 1, "hors du module : module suivant (vanilla)")
    assertEq(panel:getAPrompt(), "IGUI_MilitaryDrop_RadioModule_Select", "A : choisir une action")
    panel:onJoypadDown(Joypad.AButton)
    assertTrue(panel:focusedItem() == panel.codeEntry, "A : premier élément, le champ de code")
    assertEq(panel:getAPrompt(), "IGUI_MilitaryDrop_RadioModule_TypeCode", "A : saisir le code")
    panel:onJoypadDown(Joypad.AButton)
    assertTrue(KEYBOARD_SHOWN and KEYBOARD_SHOWN.entry == panel.codeEntry, "clavier à l'écran vanilla")
    assertTrue(JoypadState.players[1].focus == KEYBOARD_SHOWN, "focus au clavier")
    assertTrue(KEYBOARD_SHOWN.prevFocus == element, "retour au module après la saisie")
    KEYBOARD_SHOWN = nil
    element:onJoypadDirDown()
    assertEq(OUTER_MOVES, 1, "dans le module : pas de module suivant")
    assertTrue(panel:focusedItem() == panel.requestButton and panel.requestButton.joypadFocused, "bas : largage")
    element:onJoypadDirUp()
    element:onJoypadDirUp()
    local last = panel.optionButtons[#panel.optionButtons]
    assertTrue(panel:focusedItem() == last, "haut : boucle sur le dernier")
    panel:onJoypadDown(Joypad.AButton)
    assertEq(#W.exchanges, 0, "« Faire le point » grisé sans nettoyage : rien")
    element:onJoypadDirUp()
    panel:onJoypadDown(Joypad.AButton)
    assertEq(W.exchanges[1].command, "MissionFulton", "A : bouton activé (passage Fulton, avant « Faire le point »)")
    local consumedLB = panel:onJoypadDown(Joypad.LBumper)
    assertTrue(consumedLB and panel:focusedItem() == nil, "LB : sort des commandes")
    assertTrue(not panel.optionButtons[5].joypadFocused, "surbrillance retirée")
    panel:onJoypadDown(Joypad.AButton)
    panel:onJoypadDown(Joypad.BButton)
    assertTrue(panel:focusedItem() == nil, "B : sort des commandes")
    panel:onJoypadDown(Joypad.AButton)
    panel:clearJoypadFocus()
    assertTrue(panel:focusedItem() == nil and panel.focusElement == nil, "perte du focus : curseur retiré")
end

function T.joypad_is_released_when_the_module_is_folded_by_mouse()
    local panel, module = openOn(RADIO)
    local element = module.element
    JoypadState.players[1] = { focus = element }
    panel:onJoypadDown(Joypad.AButton)
    element:onJoypadDirDown()
    assertTrue(panel:focusedItem() == panel.requestButton, "curseur dans le module")
    -- Module replié à la souris : RWMElement ne transmet plus A, B, LB.
    panel:setVisible(false)
    local before = OUTER_MOVES
    element:onJoypadDirDown()
    assertEq(OUTER_MOVES, before + 1, "panneau masqué : bas va au module suivant (vanilla)")
    assertTrue(panel:focusedItem() == nil and panel.focusElement == nil, "curseur relâché")
    assertTrue(not panel.requestButton.joypadFocused, "surbrillance retirée")
    -- Gauche, droite, boutons : relâché aussi avant le vanilla.
    panel:setVisible(true)
    panel:onJoypadDown(Joypad.AButton)
    panel:setVisible(false)
    element:onJoypadDirRight()
    assertTrue(panel.focusElement == nil, "droite : déplier redevient possible")
end

function T.wrapper_is_put_back_from_the_context_menu()
    local reloaded = function(self) self.modules = self.modules or {} end
    ISRadioWindow.createChildren = reloaded
    triggerEvent("OnFillInventoryObjectContextMenu", 0, {}, {})
    assertTrue(ISRadioWindow.createChildren ~= reloaded, "enveloppe reposée au menu d'inventaire")
    assertTrue(RM.originalCreateChildren == reloaded, "sur le nouvel original")
    local again = function(self) self.modules = self.modules or {} end
    ISRadioWindow.createChildren = again
    triggerEvent("OnFillWorldObjectContextMenu", 0, {}, {}, false)
    assertTrue(RM.originalCreateChildren == again, "et au menu du monde")
end

function T.cutting_loops_always_end()
    -- Unités 128-191 sans octet de tête (Kahlua : « », °, ... sont des
    -- caractères d'une unité) : l'ancien motif ne retirait rien.
    local odd = string.rep("\171", 12)
    local fitted = RM.fit(odd, UIFont.Small, CHAR_W * 4)
    assertTrue(#fitted < #odd + 3, "fit : raccourci")
    local lines = RM.wrap(odd .. " " .. odd, UIFont.Small, CHAR_W * 3, 20)
    assertTrue(#lines >= 2, "wrap : mot coupé")
    for _, line in ipairs(lines) do
        assertTrue(#line > 0, "aucune ligne vide")
    end
    local accented = RM.wrap(string.rep("é", 10), UIFont.Small, CHAR_W, 50)
    for _, line in ipairs(accented) do
        assertTrue(line == "é", "caractère UTF-8 jamais coupé : " .. line)
    end
end

return T
