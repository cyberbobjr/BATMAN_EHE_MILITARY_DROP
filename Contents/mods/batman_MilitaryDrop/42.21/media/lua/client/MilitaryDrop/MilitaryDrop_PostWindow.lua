-- ============================================================================
-- Military Drop — console du poste de liaison (client)
--
-- Radio posée pouvant servir de poste (non portable, haut de gamme,
-- émettrice : propriétés DeviceData, aucun nom d'objet). Depuis le
-- 2026-10-01, plus de menu contextuel (PostWindow.addOptions et
-- onFillWorldContextMenu restent, non inscrites) : la section « Logistique »
-- de la fenêtre radio (« Options de l'appareil », MilitaryDrop_RadioModule.lua)
-- n'offre sur cette radio qu'un bouton « Poste de liaison »
-- (PostWindow.useRadio) : pas de poste → installation puis console ; poste de
-- l'équipe → console ; poste ailleurs → confirmation (ISModalDialog) puis
-- transfert et console ; poste d'une autre équipe → bouton grisé. L'état de
-- la radio vient du serveur (PostQuery → PostStatus), deviné en attendant
-- d'après la position du poste de l'équipe (PostInfo) :
--   * installation : le serveur l'enregistre pour l'équipe du joueur (un
--     poste par équipe ; installer ailleurs déplace) ;
--   * « Poste de liaison » sur le poste de l'équipe : console « poste radio
--     militaire » : façade de tôle olive vissée, voyants (marche, réception,
--     alimentation), indicatif sur ruban, fréquence sur afficheur, journal sur
--     écran à phosphore vert façon téléimprimeur, ordres de mission (échéance,
--     barre de progression ; nettoyage : zombies de la horde abattus par la
--     station et reste à abattre, ou « horde non repérée »), casier des plaques d'identité (bouton
--     « Transmettre »), confiance en galons (paliers en mots, jamais de chiffre),
--     bouton « Demander un largage » (v1.4) : même appel que la section
--     « Logistique » de la fenêtre radio (MilitaryDrop.Client.call, puis
--     formulaire de réquisition), par la radio du poste, avec le code du
--     champ « Code » de la colonne de confiance (si l'option AuthCode
--     l'exige) : prérempli et gardé comme celui du module, par personnage,
--     après un rechargement aussi (MilitaryDrop.Client.rememberCode). Manette :
--     Y saisit le code (clavier à l'écran) tant qu'il manque, puis appelle ;
--     RB rouvre la saisie.
-- Fichiers : ce fichier (radio et poste, menu, fenêtre, souris, clavier et
-- manette, réponses du serveur), MilitaryDrop_PostWindow_Layout.lua (mise en
-- forme et disposition), MilitaryDrop_PostWindow_Affairs.lua (affaires) et
-- MilitaryDrop_PostWindow_Draw.lua (dessin).
--
-- Disposition « tableau des affaires » (maquette C validée le 2026-10-05,
-- POSTE-08) : sous le journal, la liste des affaires à gauche (à traiter :
-- enregistreur dans la baie, enregistreurs de l'inventaire, plaques ; ordres de
-- la base : missions), chacune avec l'icône de l'objet du jeu, et à droite le
-- volet de l'affaire choisie avec ses actions (deux boutons au plus) ; en bas,
-- la bande de la confiance, du code et de l'appel. Une mission future ajoute
-- une ligne à la liste et un volet, sans toucher à la disposition.
-- Baie de lecture (SRC-08) : fiche du crash, enregistreur dans son logement,
-- barre de lecture (avancée par le serveur en temps de jeu, interpolée entre
-- deux rafraîchissements), retrait et « Transmettre à la base ».
-- Tout est dessiné par la fenêtre (textures du mod, polices du jeu) ; les
-- largeurs sont mesurées selon la langue et la taille de police.
--
-- Le client ne décide rien : il connaît seulement la position du poste de son
-- équipe (PostInfo) pour choisir l'entrée du menu, et affiche ce que le serveur
-- envoie (PostData), qui revérifie équipe, poste, distance et objets.
--
-- La console ne dit jamais si la radio est sur la fréquence militaire (elle
-- servirait à la trouver en balayant les canaux) : le voyant de réception ne
-- reflète que la dernière entrée du journal (reçue ou « aucune réception »).
--
-- Solo : MilitaryDrop.Net appelle directement MilitaryDrop.Client.onServerCommand,
-- dont les gestionnaires HANDLERS reçoivent les commandes du poste. MP :
-- événement OnServerCommand.
-- ============================================================================

require "ISUI/ISPanelJoypad"
require "ISUI/ISModalDialog"
require "ISUI/ISTextEntryBox"
require "ISUI/ISRichTextPanel"
require "ISUI/ISToolTip"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Codes"
require "MilitaryDrop/MilitaryDrop_Exchange"
require "MilitaryDrop/MilitaryDrop_Recorders"
require "MilitaryDrop/MilitaryDrop_Client"
require "MilitaryDrop/MilitaryDrop_ExchangeMenu"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Radio = MilitaryDrop.Radio
local Codes = MilitaryDrop.Codes

local PostWindow = ISPanelJoypad:derive("MilitaryDropPostWindow")
MilitaryDrop.PostWindow = PostWindow

PostWindow.DEPOSIT_MAX = 50
-- Rafraîchissement de la console ouverte (ms réelles).
PostWindow.REFRESH_MS = 10000
-- Rafraîchissement anticipé (lecture de la baie estimée finie, fin annoncée) :
-- au plus une demande par intervalle, en ms réelles.
PostWindow.EARLY_REFRESH_MS = 1000
PostWindow.EXCHANGE_LOCK_MS = 10000
-- Fermeture quand le joueur s'éloigne : même portée que le serveur
-- (Radio.isNear), sinon la console resterait ouverte sans pouvoir agir.
PostWindow.CLOSE_DISTANCE = Radio.MAX_WORLD_DISTANCE + 0.5
PostWindow.TIER_COUNT = 4
-- Lignes visibles du journal (moins si l'écran du joueur est petit).
PostWindow.JOURNAL_LINES = 6
PostWindow.JOURNAL_MIN_LINES = 4
-- Durée du clignotement du voyant de réception après une nouvelle ligne (ms).
PostWindow.RX_FLASH_MS = 2500
-- Textures du mod (common/media/textures/MilitaryDrop/PostConsole) ; préfixe
-- distinctif : le jeu cherche d'abord le nom de base dans ses packs.
PostWindow.TEXTURE_PATH = "media/textures/MilitaryDrop/PostConsole/MDPost_"
-- Enregistreur de vol (MilitaryDrop_Post.lua) : objet et clés de ModData du crash.
PostWindow.RECORDER_TYPE = "MilitaryDrop.FlightRecorder"
PostWindow.DOG_TAG_TYPE = "Base.Necklace_DogTag"
PostWindow.SITE_KEY = "MilitaryDrop_crashSite"
-- Segments de la barre de lecture de la baie.
PostWindow.BAY_SEGMENTS = 10
-- Durée totale d'une mission par type, si le serveur ne l'envoie pas (heures).
PostWindow.HOURS_OPTIONS = { recon = "ReconHours", cleanup = "CleanupHours", control = "ControlHours" }
-- Titre d'une mission, traduit ici dans la langue du joueur (le serveur
-- n'envoie que kind).
PostWindow.MISSION_TITLES = { recon = "IGUI_MilitaryDrop_Mission_Recon",
    cleanup = "IGUI_MilitaryDrop_Mission_Cleanup", control = "IGUI_MilitaryDrop_Mission_Control",
    relay = "IGUI_MilitaryDrop_Mission_Relay" }
-- Langues dont l'alphabet tient dans la police à chasse fixe du jeu (Latin-1) :
-- journal et plaques en caractères de téléimprimeur ; sinon police normale.
PostWindow.MONO_LANGUAGES = {
    EN = true, FR = true, DE = true, ES = true, IT = true, PT = true, PTBR = true, NL = true, DA = true,
    NO = true, FI = true, ID = true,
}

-- Couleurs du texte riche du journal (phosphore vert).
PostWindow.COLORS = {
    stamp = "0.32,0.66,0.38",
    line = "0.62,1,0.62",
    gap = "0.42,0.62,0.42",
    sys = "0.86,1,0.62",
    text = "0.5,0.82,0.54",
}

-- Statuts de PostResult affichés (IGUI_MilitaryDrop_PostResult_<statut>) ;
-- « busy » (cadence du serveur) n'affiche rien.
PostWindow.RESULTS = {
    installed = true, moved = true, already = true, otherTeam = true, notEligible = true, notPost = true,
    tooFar = true, deposited = true, noTags = true, emptyMail = true, radioOff = true, noAnswer = true,
    unavailable = true, transmitted = true, held = true, lineCut = true,
    recorderIn = true, recorderOut = true, recorderSent = true, bayBusy = true, bayEmpty = true,
    recorderUsed = true, notRead = true, notRecorder = true,
}

-- Statuts qui ferment la console du joueur : poste qui n'est plus le sien
-- (sorti de la faction, poste déplacé) ou hors de portée.
-- « tooFar » n'en fait pas partie : la console se ferme d'elle-même quand le
-- joueur s'éloigne (PostWindow:objectValid, même distance que le serveur).
PostWindow.CLOSING = { notPost = true, otherTeam = true }

-- Position du poste de l'équipe ({ x, y, z }), envoyée par le serveur.
PostWindow.myPost = nil
PostWindow.instances = {}
local pendingOpen = nil

-- ----------------------------------------------------------------------------
-- Radio et poste
-- ----------------------------------------------------------------------------

--- Radio posée pouvant servir de poste (même règle que MilitaryDrop.Post.isEligible).
function PostWindow.isEligible(object)
    if not Radio.isWorldRadio(object) then
        return false
    end
    local data = object:getDeviceData()
    return data ~= nil and not data:getIsPortable() and data:getIsHighTier() == true and data:getIsTwoWay() == true
end

--- La radio est à l'emplacement du poste de l'équipe (le serveur revérifie).
function PostWindow.isOwnPost(object)
    local post = PostWindow.myPost
    local square = object and object:getSquare()
    return post ~= nil and square ~= nil and square:getX() == post.x and square:getY() == post.y
        and square:getZ() == post.z
end

local function sendToServer(player, command, object, extra)
    local args = extra or {}
    args.radio = Radio.makeRef(object)
    Net.toServer(player, command, args)
end

function PostWindow.requestInstall(player, object)
    sendToServer(player, "PostInstall", object)
end

-- Installation suivie de l'ouverture de la console (bouton de la fenêtre
-- radio) : joueur local → radio.
local pendingInstallOpen = {}
-- État des radios reçu du serveur (PostStatus) : "x,y,z" → statut.
PostWindow.radioStates = {}

local function radioKey(x, y, z)
    return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
end

local function objectKey(object)
    local square = object and object:getSquare()
    return square and radioKey(square:getX(), square:getY(), square:getZ()) or nil
end

--- Installe le poste sur la radio puis ouvre la console (au résultat
--- installed, moved ou already).
function PostWindow.installThenOpen(player, object)
    pendingInstallOpen[player:getPlayerNum()] = object
    PostWindow.requestInstall(player, object)
end

--- Demande au serveur l'état de la radio (bouton de la fenêtre radio).
function PostWindow.queryStatus(player, object)
    sendToServer(player, "PostQuery", object)
end

--- État de la radio pour le bouton : celui du serveur s'il est connu, sinon
--- deviné d'après la position du poste de l'équipe ("own", "elsewhere",
--- "none" ; « autre équipe » n'est connu que du serveur).
function PostWindow.radioStatus(object)
    local key = objectKey(object)
    local known = key and PostWindow.radioStates[key]
    if known then
        return known
    end
    if PostWindow.isOwnPost(object) then
        return "own"
    elseif PostWindow.myPost then
        return "elsewhere"
    end
    return "none"
end

--- Raison de grisé du bouton « Poste de liaison » (clé de traduction), ou nil.
function PostWindow.useReason(player, object)
    if not Radio.isNear(player, object) then
        return "IGUI_MilitaryDrop_TooFar"
    end
    local status = PostWindow.radioStatus(object)
    if status == "otherTeam" or status == "notEligible" then
        return "IGUI_MilitaryDrop_PostResult_" .. status
    end
    return nil
end

--- Infobulle du bouton selon l'état de la radio.
function PostWindow.useTooltip(object)
    local status = PostWindow.radioStatus(object)
    if status == "own" then
        return "IGUI_MilitaryDrop_PostOpenTooltip"
    elseif status == "elsewhere" then
        return "IGUI_MilitaryDrop_PostTransferTooltip"
    end
    return "IGUI_MilitaryDrop_PostInstallTooltip"
end

--- Réponse à la confirmation du transfert (ISModalDialog).
function PostWindow.onTransferConfirm(_, button, playerNum, object)
    local player = getSpecificPlayer(playerNum)
    if button.internal == "YES" and player and object then
        PostWindow.installThenOpen(player, object)
    end
end

--- Confirmation vanilla oui/non du transfert ; focus manette pris, rendu à
--- la fermeture (ISModalDialog:destroy rend prevFocus).
function PostWindow.confirmTransfer(player, object)
    local playerNum = player:getPlayerNum()
    local modal = ISModalDialog:new(0, 0, 300, 150, getText("IGUI_MilitaryDrop_PostTransferConfirm"), true, nil,
        PostWindow.onTransferConfirm, playerNum, playerNum, object)
    modal:initialise()
    modal:addToUIManager()
    local joypad = JoypadState and JoypadState.players[playerNum + 1]
    if joypad then
        modal.prevFocus = joypad.focus
        setJoypadFocus(playerNum, modal)
    end
    return modal
end

--- Bouton « Poste de liaison » de la fenêtre radio. Renvoie l'action
--- choisie ("open", "install", "confirm"), ou nil (grisé). Le serveur
--- revérifie tout (PostInstall, PostOpen).
function PostWindow.useRadio(player, object)
    if PostWindow.useReason(player, object) then
        return nil
    end
    local status = PostWindow.radioStatus(object)
    if status == "own" then
        PostWindow.requestOpen(player, object)
        return "open"
    elseif status == "elsewhere" then
        PostWindow.confirmTransfer(player, object)
        return "confirm"
    end
    PostWindow.installThenOpen(player, object)
    return "install"
end

function PostWindow.requestOpen(player, object)
    pendingOpen = { playerNum = player:getPlayerNum(), object = object }
    sendToServer(player, "PostOpen", object)
end

--- Plaque d'identité transmissible (MilitaryDrop.Exchange.isDogTag : plaque
--- vanilla gravée, pas celle du joueur) ; repli : étiquette du jeu seule.
function PostWindow.isDogTag(item, player)
    local Exchange = MilitaryDrop.Exchange
    if type(Exchange) == "table" and type(Exchange.isDogTag) == "function" then
        return Exchange.isDogTag(item, player) == true
    end
    return ItemTag ~= nil and ItemTag.DOG_TAG ~= nil and item:hasTag(ItemTag.DOG_TAG)
end

--- Nom gravé sur une plaque de l'inventaire.
function PostWindow.dogTagLabel(item)
    local Exchange = MilitaryDrop.Exchange
    if type(Exchange) == "table" and type(Exchange.dogTagLabel) == "function" then
        local label = Exchange.dogTagLabel(item)
        if label ~= nil and label ~= "" then
            return tostring(label)
        end
    end
    return tostring(item:getDisplayName())
end

--- Plaques d'identité de l'inventaire (sacs compris), ni portées ni accrochées
--- (MilitaryDrop.Exchange.findDogTags s'il existe).
function PostWindow.dogTags(player)
    local Exchange = MilitaryDrop.Exchange
    if type(Exchange) == "table" and type(Exchange.findDogTags) == "function" then
        return Exchange.findDogTags(player, PostWindow.DEPOSIT_MAX)
    end
    local found = {}
    local items = player:getInventory():getAllEvalRecurse(function(item)
        return PostWindow.isDogTag(item, player)
    end)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if #found < PostWindow.DEPOSIT_MAX and not player:isEquipped(item) and not player:isAttachedItem(item) then
            found[#found + 1] = item
        end
    end
    return found
end

-- ----------------------------------------------------------------------------
-- Menu contextuel
-- ----------------------------------------------------------------------------

local function addTooltip(option, text)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip.description = text
    option.toolTip = tooltip
end

function PostWindow.addOptions(player, context, object)
    local option
    if PostWindow.isOwnPost(object) then
        option = context:addOption(getText("IGUI_MilitaryDrop_PostOpen"), player, PostWindow.requestOpen, object)
    else
        option = context:addOption(getText("IGUI_MilitaryDrop_PostInstall"), player, PostWindow.requestInstall, object)
        addTooltip(option, getText("IGUI_MilitaryDrop_PostInstallTooltip"))
    end
    if not Radio.isNear(player, object) then
        option.notAvailable = true
        addTooltip(option, getText("IGUI_MilitaryDrop_PostResult_tooFar"))
    end
end

function PostWindow.onFillWorldContextMenu(playerNum, context, worldObjects, test)
    if test then
        return
    end
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    local seen = {}
    for _, object in ipairs(worldObjects) do
        local square = object and object:getSquare()
        if square and not seen[square] then
            seen[square] = true
            local objects = square:getObjects()
            for i = 0, objects:size() - 1 do
                local candidate = objects:get(i)
                if PostWindow.isEligible(candidate) then
                    PostWindow.addOptions(player, context, candidate)
                    return
                end
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Outils partagés avec les autres fichiers de la console (C08 : découpe sans
-- changement de comportement) : MilitaryDrop_PostWindow_Layout.lua (mise en
-- forme et disposition), _Affairs.lua (liste des affaires), _Draw.lua (dessin).
-- Ils se chargent après ce fichier (chemins triés sans casse : « . » avant « _ »)
-- et l'exigent ; rien ici ne les appelle au chargement.
-- ----------------------------------------------------------------------------

--- Texte de la base inséré dans un texte riche (« < » et « > » échappés).
local function escape(text)
    return (tostring(text or ""):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
PostWindow.escape = escape

local function measure(text, font)
    return getTextManager():MeasureStringX(font or UIFont.Small, tostring(text or ""))
end

local function fontHeight(font)
    return getTextManager():getFontHeight(font)
end

local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

local LAMP_KEYS = { "IGUI_MilitaryDrop_PostLampOn", "IGUI_MilitaryDrop_PostLampRx", "IGUI_MilitaryDrop_PostLampPower" }

PostWindow.util = { escape = escape, measure = measure, fontHeight = fontHeight, rect = rect,
    LAMP_KEYS = LAMP_KEYS }

-- ----------------------------------------------------------------------------
-- Fenêtre
-- ----------------------------------------------------------------------------

function PostWindow:new(x, y, width, height, player, object)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.object = object
    o.data = nil
    o.background = false
    o.moveWithMouse = true
    o.lastRefreshMs = getTimestampMs()
    o.rxFlashUntil = 0
    o.rackScroll = 0
    o.listScroll = 0
    o.tagCount = 0
    o.tagLabels = {}
    o.recorderItems = {}
    o.affairList = {}
    o.selectedKey = nil
    o.dataHours = 0
    o.maxWidth = width
    o.maxHeight = height
    o:setWantKeyEvents(true)
    return o
end

function PostWindow:createChildren()
    ISPanelJoypad.createChildren(self)
    local journal = ISRichTextPanel:new(0, 0, 100, 100)
    journal:initialise()
    journal.background = false
    journal.clip = true
    journal.autosetheight = false
    journal.defaultFont = PostWindow.monoFont()
    journal:setMargins(0, 0, 0, 0)
    -- Molette bornée (pas de barre de défilement : témoin dessiné sur le verre).
    journal.onMouseWheel = function(panel, del)
        PostWindow.scrollJournal(panel, -del * panel.lineStep)
        return true
    end
    self:addChild(journal)
    self.journal = journal
    -- Champ du code : prérempli avec le code gardé du personnage.
    local Client = MilitaryDrop.Client
    local remembered = Client and type(Client.rememberedCode) == "function" and Client.rememberedCode(self.playerNum)
        or ""
    local entry = ISTextEntryBox:new(remembered, 0, 0, 100, 20)
    entry.font = UIFont.Small
    entry:initialise()
    entry:instantiate()
    entry:setMaxTextLength(Codes.MAX_INPUT_LENGTH)
    entry:setPlaceholderText(getText("IGUI_MilitaryDrop_RadioModule_CodeHint"))
    entry:setTooltip(getText("IGUI_MilitaryDrop_EnterCode"))
    -- Afficheur sombre au verre vert, cadre de laiton : style de la façade.
    entry.backgroundColor = { r = 0.03, g = 0.06, b = 0.02, a = 1 }
    entry.borderColor = { r = 0.62, g = 0.55, b = 0.32, a = 1 }
    entry.target = self
    entry.onTextChangeFunction = PostWindow.onCodeChange
    local window = self
    -- Entrée au clavier : même effet que le bouton « Demander un largage ».
    entry.onCommandEntered = function()
        if window:canRequest() then
            window:onRequest()
        end
    end
    self:addChild(entry)
    self.codeEntry = entry
    self:layout()
end

--- Le serveur exige un code pour les largages (option AuthCode).
function PostWindow.codeRequired()
    return Config.codeMode() ~= Codes.MODE_NONE
end

--- Code saisi sans espaces autour, ou nil.
function PostWindow.cleanCode(text)
    local code = type(text) == "string" and string.match(text, "^[ \t]*(.-)[ \t]*$") or ""
    if code == "" then
        return nil
    end
    return code
end

--- Code du champ de la console, ou nil.
function PostWindow:currentCode()
    return self.codeEntry and PostWindow.cleanCode(self.codeEntry:getText()) or nil
end

--- Saisie du code : gardé pour le personnage (MilitaryDrop.Client.rememberCode).
function PostWindow:onCodeChange()
    local Client = MilitaryDrop.Client
    if Client and type(Client.rememberCode) == "function" then
        Client.rememberCode(self.playerNum, self:currentCode() or "")
    end
end

--- Clavier à l'écran vanilla pour le champ du code (manette).
function PostWindow:openKeyboard()
    local joypadData = JoypadState and JoypadState.players[self.playerNum + 1]
    if not self.codeEntry or not self.L or not self.L.codeShown or not joypadData or not OnScreenKeyboard
        or OnScreenKeyboard.IsVisible() then
        return false
    end
    local keyboard = OnScreenKeyboard.Show(self.playerNum, self.codeEntry, joypadData)
    keyboard.prevFocus = joypadData.focus
    joypadData.focus = keyboard
    return true
end

--- Défile le journal de dy pixels (positif : vers le haut), borné au texte.
function PostWindow.scrollJournal(journal, dy)
    local lowest = -math.max(0, journal:getScrollHeight() - journal:getHeight())
    journal:setYScroll(math.max(lowest, math.min(0, journal:getYScroll() + dy)))
end

local function journalAtBottom(journal)
    local lowest = -math.max(0, journal:getScrollHeight() - journal:getHeight())
    return journal:getYScroll() <= lowest + 2
end

--- Recalcule la disposition (taille selon les données) et place le journal.
function PostWindow:layout()
    local L = PostWindow.computeLayout(self.data, self.maxWidth, self.maxHeight)
    self.L = L
    if self.width ~= L.W or self.height ~= L.H then
        self:setWidth(L.W)
        self:setHeight(L.H)
    end
    local journal = self.journal
    journal.defaultFont = L.mono
    journal.lineStep = L.lh * 2
    journal:setX(L.journal.x)
    journal:setY(L.journal.y)
    journal:setWidth(L.journal.w)
    journal:setHeight(L.journal.h)
    journal.textDirty = true
    local entry = self.codeEntry
    if entry then
        entry:setVisible(L.codeShown == true)
        if L.codeShown then
            entry:setX(L.code.x)
            entry:setY(L.code.y)
            entry:setWidth(L.code.w)
            entry:setHeight(L.code.h)
        end
    end
end

--- Données reçues du serveur (PostData) : tout est remplacé.
function PostWindow:setData(data)
    local first = self.data == nil
    local previous = self.data
    self.data = data
    -- Heure de réception : la barre de lecture est interpolée jusqu'au prochain envoi.
    self.dataHours = getGameTime():getWorldAgeHours()
    -- Autre enregistreur (ou baie vidée) : l'affichage repart de sa propre valeur.
    if not (type(data.bay) == "table" and self.bayShown and self.bayShown.site == data.bay.site) then
        self.bayShown = nil
    end
    self:layout()
    local journal = self.journal
    local stick = first or journalAtBottom(journal)
    journal.text = PostWindow.journalText(data.lines)
    journal:paginate()
    if stick then
        PostWindow.scrollJournal(journal, -journal:getScrollHeight())
    else
        PostWindow.scrollJournal(journal, 0)
    end
    -- Nouvelle ligne reçue : le voyant de réception clignote.
    if not first and PostWindow.lastReceivedKey(data) ~= PostWindow.lastReceivedKey(previous) then
        self.rxFlashUntil = getTimestampMs() + PostWindow.RX_FLASH_MS
    end
    self:updateButtons()
end

--- Clé de la dernière ligne reçue (horloge et texte), pour le clignotement.
function PostWindow.lastReceivedKey(data)
    local lines = data and data.lines or {}
    for i = #lines, 1, -1 do
        local entry = lines[i]
        if entry.t and not entry.gap then
            return tostring(entry.c) .. "|" .. MilitaryDrop.Exchange.lineText(entry.t)
        end
    end
    return ""
end

function PostWindow:updateButtons()
    local tags = PostWindow.dogTags(self.player)
    self.tagCount = #tags
    self.tagLabels = {}
    for i, item in ipairs(tags) do
        self.tagLabels[i] = PostWindow.dogTagLabel(item)
    end
    self.recorderItems = PostWindow.recorders(self.player)
    self:refreshAffairs()
end

--- Reconstruit la liste des affaires ; la sélection suit sa clé, sinon la
--- première ligne (enregistreur dans la baie, puis de l'inventaire, plaques).
function PostWindow:refreshAffairs()
    self.affairList = PostWindow.affairs(self.data, self.recorderItems, self.tagCount)
    local selected = PostWindow.pickAffair(self.affairList, self.selectedKey)
    self.selectedKey = selected and selected.key or nil
end

--- Affaire choisie (ligne de la liste), ou nil.
function PostWindow:selectedAffair()
    for _, entry in ipairs(self.affairList or {}) do
        if entry.key and entry.key == self.selectedKey then
            return entry
        end
    end
    return nil
end

function PostWindow:select(key)
    if key and key ~= self.selectedKey then
        self.selectedKey = key
        self.rackScroll = 0
        getSoundManager():playUISound("UISelectListItem")
    end
end

--- Sélection précédente (-1) ou suivante (+1) dans la liste (manette).
function PostWindow:moveSelection(delta)
    local keys, current = {}, 1
    for _, entry in ipairs(self.affairList or {}) do
        if entry.key then
            keys[#keys + 1] = entry.key
            if entry.key == self.selectedKey then
                current = #keys
            end
        end
    end
    if #keys > 0 then
        self:select(keys[math.max(1, math.min(#keys, current + delta))])
    end
end

--- Lecture de la baie affichée, seule valeur de la console (liste, barre,
--- pour-cent, minutes restantes) : progression exacte reçue du serveur,
--- avancée depuis sa réception tant qu'elle n'est ni finie ni en pause (sans
--- jamais l'achever), et jamais en recul pour un même enregistreur (latence
--- réseau, coupure survenue entre deux envois).
function PostWindow:bayProgress()
    local bay = self.data and self.data.bay
    if type(bay) ~= "table" then
        self.bayShown = nil
        return 0
    end
    local progress = math.max(0, math.min(1, tonumber(bay.progress) or 0))
    local total = tonumber(bay.total)
    if bay.done then
        progress = 1
    elseif not bay.paused and total and total > 0 then
        local elapsed = math.max(0, getGameTime():getWorldAgeHours() - (self.dataHours or 0))
        local estimate = progress + elapsed / total
        -- Estimée finie : seul le serveur l'achève, on lui redemande l'état
        -- aussitôt plutôt que d'attendre le rafraîchissement suivant (10 s).
        if estimate >= 1 then
            self:refreshSoon()
        end
        progress = math.min(0.99, estimate)
    end
    local shown = self.bayShown
    if shown and shown.site == bay.site and shown.value > progress then
        progress = shown.value
    end
    self.bayShown = { site = bay.site, value = progress }
    return progress
end

--- Redemande les données au serveur sans attendre REFRESH_MS (au plus une fois
--- par EARLY_REFRESH_MS).
function PostWindow:refreshSoon()
    local now = getTimestampMs()
    if self.earlyRefreshMs and now - self.earlyRefreshMs < PostWindow.EARLY_REFRESH_MS and now >= self.earlyRefreshMs then
        return
    end
    if not self:objectValid() then
        return
    end
    self.earlyRefreshMs = now
    self.lastRefreshMs = now
    sendToServer(self.player, "PostOpen", self.object)
end

--- Son de la baie reçu (MilitaryDrop_BaySound.lua) : la fin ou une coupure de
--- la lecture sur ce poste rafraîchit tout de suite les consoles ouvertes dessus.
function PostWindow.onBaySound(args)
    if args.event ~= "done" and args.reading ~= false then
        return
    end
    for _, window in pairs(PostWindow.instances) do
        local square = window.object and window.object:getSquare()
        if square and square:getX() == args.x and square:getY() == args.y and square:getZ() == args.z then
            window:refreshSoon()
        end
    end
end

function PostWindow:canInsert()
    return self.data ~= nil and self.data.bay == nil
end

function PostWindow:onInsert(entry)
    if entry and entry.itemId and self:objectValid() then
        sendToServer(self.player, "PostRecorderInsert", self.object, { item = entry.itemId })
    end
end

function PostWindow:canEject()
    return self.data ~= nil and self.data.bay ~= nil
end

function PostWindow:onEject()
    if self:objectValid() then
        sendToServer(self.player, "PostRecorderEject", self.object)
    end
end

--- Raison de grisé de « Transmettre à la base » (clé de traduction), ou nil.
function PostWindow:sendReason()
    local bay = self.data and self.data.bay
    if not bay then
        return "IGUI_MilitaryDrop_PostResult_bayEmpty"
    elseif not bay.done then
        return "IGUI_MilitaryDrop_PostResult_notRead"
    elseif not PostWindow.lamps(self.data).on then
        return "IGUI_MilitaryDrop_TurnOn"
    end
    return nil
end

function PostWindow:canSendRecorder()
    return self:sendReason() == nil
end

function PostWindow:onSendRecorder()
    if not self:objectValid() then
        return
    end
    local callsign = self.data and self.data.callsign
    if callsign then
        self.player:Say(getText("IGUI_MilitaryDrop_PostRecorderSendSay", tostring(callsign)))
    end
    sendToServer(self.player, "PostRecorderTransmit", self.object)
end

-- Reuse the portable radio's options and timed exchanges on the post radio.
function PostWindow:exchangeReason(option, entry)
    if getTimestampMs() < (self.exchangeLockedUntil or 0) then
        return "IGUI_MilitaryDrop_RadioModule_Sending"
    end
    if self.data == nil or not PostWindow.lamps(self.data).on then
        return "IGUI_MilitaryDrop_TurnOn"
    end
    if self.data.lineCut then
        return "IGUI_MilitaryDrop_PostResult_lineCut"
    end
    local reason = MilitaryDrop.ExchangeMenu.reason(self.player, self.object, option)
    if reason then
        return reason
    end
    local states = self.data.exchanges or {}
    if option.source == "report" and states.reportDone then
        return "IGUI_MilitaryDrop_PostReportDone"
    elseif option.source == "fulton" and states.fultonOpen then
        return "IGUI_MilitaryDrop_PostFultonOpen"
    elseif option.source == "control" and entry.mission and entry.mission.progress == 1 then
        return "IGUI_MilitaryDrop_PostControlDone"
    end
    return nil
end

function PostWindow:onExchange(option, entry)
    if not self:objectValid() or self:exchangeReason(option, entry) then
        return false
    end
    self.exchangeLockedUntil = getTimestampMs() + PostWindow.EXCHANGE_LOCK_MS
    local started = MilitaryDrop.ExchangeMenu.onOption(self.player, self.object, option, {
        onReply = function()
            self.exchangeLockedUntil = 0
            self:refreshSoon()
        end,
    })
    if not started then
        self.exchangeLockedUntil = 0
    end
    return started
end

--- Actions du volet : principale (bouton de droite, A) et secondaire (bouton
--- de gauche, X), chacune { text, enabled, reason, run } ou nil.
function PostWindow:actions()
    local entry = self:selectedAffair()
    if not entry then
        return nil, nil
    end
    if entry.mission and entry.mission.history then return nil, nil end
    if entry.kind == "bay" then
        return { text = getText("IGUI_MilitaryDrop_PostRecorderSend"), enabled = self:canSendRecorder(),
                reason = self:sendReason(), run = function() self:onSendRecorder() end },
            { text = getText("IGUI_MilitaryDrop_PostRecorderEject"), enabled = self:canEject(),
                run = function() self:onEject() end }
    elseif entry.kind == "recorder" then
        return { text = getText("IGUI_MilitaryDrop_PostRecorderInsert"), enabled = self:canInsert(),
            reason = not self:canInsert() and "IGUI_MilitaryDrop_PostResult_bayBusy" or nil,
            run = function() self:onInsert(entry) end }, nil
    elseif entry.kind == "tags" then
        return { text = getText("IGUI_MilitaryDrop_PostTransmit"), enabled = self:canTransmit(),
                reason = not self:canTransmit() and "IGUI_MilitaryDrop_PostMailEmpty" or nil,
                run = function() self:onTransmit() end },
            { text = getText("IGUI_MilitaryDrop_PostDeposit", tostring(self.tagCount)), enabled = self:canDeposit(),
                reason = not self:canDeposit() and "IGUI_MilitaryDrop_PostResult_noTags" or nil,
                run = function() self:onDeposit() end }
    elseif entry.kind == "exchange" or entry.kind == "mission" then
        local source = entry.source or (entry.mission and entry.mission.kind)
        local option = MilitaryDrop.ExchangeMenu.optionFor(source)
        if option then
            local reason = self:exchangeReason(option, entry)
            return { text = getText(option.label), enabled = reason == nil, reason = reason,
                run = function() self:onExchange(option, entry) end }, nil
        end
    end
    return nil, nil
end

function PostWindow:canDeposit()
    return self.tagCount > 0
end

function PostWindow:canTransmit()
    return self.data ~= nil and #(self.data.mail or {}) > 0
end

function PostWindow:onDeposit()
    local ids = {}
    for i, item in ipairs(PostWindow.dogTags(self.player)) do
        ids[i] = item:getID()
    end
    if #ids > 0 and self:objectValid() then
        sendToServer(self.player, "PostDeposit", self.object, { items = ids })
    end
end

function PostWindow:onTransmit()
    if not self:objectValid() then
        return
    end
    local callsign = self.data and self.data.callsign
    if callsign then
        self.player:Say(getText("IGUI_MilitaryDrop_PostTransmitSay", tostring(callsign)))
    end
    sendToServer(self.player, "PostTransmit", self.object)
end

--- Raison de grisé de « Demander un largage » (clé de traduction), ou nil :
--- poste éteint ou sans courant (état envoyé par le serveur), code manquant.
function PostWindow:requestReason()
    if self.data == nil or not PostWindow.lamps(self.data).on then
        return "IGUI_MilitaryDrop_TurnOn"
    end
    if PostWindow.codeRequired() and not self:currentCode() then
        return "IGUI_MilitaryDrop_RadioModule_NeedCode"
    end
    return nil
end

--- Appel de la base possible (le serveur revérifie tout à l'appel).
function PostWindow:canRequest()
    return self:requestReason() == nil
end

--- « Demander un largage » : même appel que la section « Logistique » de la
--- fenêtre radio (MilitaryDrop.Client.call, code du champ s'il est exigé),
--- par la radio du poste. La console reste ouverte ; la feuille de
--- réquisition s'ouvre collée à elle (opts.anchor).
function PostWindow:onRequest()
    local Client = MilitaryDrop.Client
    if not self:canRequest() or not self:objectValid() or not Client or type(Client.call) ~= "function" then
        return
    end
    local code = PostWindow.codeRequired() and self:currentCode() or nil
    Client.call(self.player, self.object, code, false, { anchor = self })
end

--- La radio est toujours là et le joueur à côté (même étage).
function PostWindow:objectValid()
    local object, player = self.object, self.player
    if not object or not player or player:isDead() or object:getObjectIndex() == -1 then
        return false
    end
    local square = object:getSquare()
    if not square or math.floor(player:getZ()) ~= square:getZ() then
        return false
    end
    local limit = PostWindow.CLOSE_DISTANCE
    return math.abs(player:getX() - (square:getX() + 0.5)) <= limit
        and math.abs(player:getY() - (square:getY() + 0.5)) <= limit
end

-- ----------------------------------------------------------------------------
-- Souris : zones actives dessinées par la fenêtre
-- ----------------------------------------------------------------------------

local function inside(r, x, y)
    return r ~= nil and x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h
end

--- Lignes de la liste visibles, avec leur rectangle : { entry, r }.
function PostWindow:affairRows()
    local L = self.L
    local area = L.listArea
    local rows, y = {}, area.y
    local hidden = 0
    for index, entry in ipairs(self.affairList or {}) do
        if index > self.listScroll then
            local h = entry.key and L.rowH or L.headH
            if y + h > area.y + area.h then
                hidden = hidden + (entry.key and 1 or 0)
            else
                rows[#rows + 1] = { entry = entry, r = rect(area.x, y, area.w, h) }
                y = y + h + (entry.key and L.rowGap or 0)
            end
        end
    end
    return rows, hidden
end

--- Élément sous le point (x, y) de la fenêtre : nom, donnée.
function PostWindow:hitTest(x, y)
    local L = self.L
    if not L then
        return nil
    end
    local primary, secondary = self:actions()
    if inside(L.close, x, y) then
        return "close"
    elseif primary and inside(L.btnA, x, y) then
        return "primary"
    elseif secondary and inside(L.btnB, x, y) then
        return "secondary"
    elseif inside(L.request, x, y) then
        return "request"
    elseif inside(L.standText, x, y) then
        return "standing"
    elseif inside(L.lampsArea, x, y) or inside(L.tape, x, y) or inside(L.freq, x, y) then
        return "status"
    end
    if inside(L.listArea, x, y) then
        for _, row in ipairs(self:affairRows()) do
            if row.entry.key and inside(row.r, x, y) then
                return "affair", row.entry
            end
        end
        return nil
    end
    local entry = self:selectedAffair()
    if entry and entry.kind == "tags" then
        local mail = self.data and self.data.mail or {}
        for i, slot in ipairs(L.slots) do
            local tag = mail[i + self.rackScroll * 2]
            if tag and inside(slot, x, y) then
                return "tag", tag
            end
        end
    elseif entry and entry.kind == "mission" and (inside(L.missionCard, x, y) or inside(L.missionText, x, y)) then
        return "mission", entry.mission
    end
    return nil
end

function PostWindow:mouseTarget()
    if not self:isReallyVisible() then
        return nil
    end
    local x, y = self:getMouseX(), self:getMouseY()
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return nil
    end
    return self:hitTest(x, y)
end

function PostWindow:isEnabled(target)
    if target == "primary" or target == "secondary" then
        local primary, secondary = self:actions()
        local action = target == "primary" and primary or secondary
        return action ~= nil and action.enabled == true
    elseif target == "request" then
        return self:canRequest()
    end
    return target == "close"
end

function PostWindow:activate(target)
    getSoundManager():playUISound("UIActivateButton")
    if target == "close" then
        self:close("close button")
    elseif target == "primary" or target == "secondary" then
        local primary, secondary = self:actions()
        local action = target == "primary" and primary or secondary
        if action and action.enabled then
            action.run()
        end
    elseif target == "request" then
        self:onRequest()
    end
end

local BUTTONS = { close = true, primary = true, secondary = true, request = true }

function PostWindow:onMouseDown(x, y)
    local target, payload = self:hitTest(x, y)
    if BUTTONS[target] then
        self.pressed = self:isEnabled(target) and target or nil
        return true
    elseif target == "affair" then
        self:select(payload.key)
        return true
    end
    return ISPanelJoypad.onMouseDown(self, x, y)
end

function PostWindow:onMouseUp(x, y)
    local pressed = self.pressed
    self.pressed = nil
    if pressed then
        if self:hitTest(x, y) == pressed and self:isEnabled(pressed) then
            self:activate(pressed)
        end
        return true
    end
    return ISPanelJoypad.onMouseUp(self, x, y)
end

function PostWindow:onMouseUpOutside(x, y)
    self.pressed = nil
    return ISPanelJoypad.onMouseUpOutside(self, x, y)
end

function PostWindow:onMouseWheel(del)
    local L = self.L
    local x, y = self:getMouseX(), self:getMouseY()
    local step = del > 0 and 1 or -1
    if L and inside(L.listArea, x, y) then
        local _, hidden = self:affairRows()
        local maxScroll = math.max(0, self.listScroll + (step > 0 and (hidden > 0 and 1 or 0) or 0))
        self.listScroll = math.max(0, math.min(maxScroll, self.listScroll + step))
        return true
    end
    local entry = self:selectedAffair()
    if L and entry and entry.kind == "tags" and inside(L.detail, x, y) then
        local rows = math.ceil(#(self.data and self.data.mail or {}) / 2) - math.floor(#L.slots / 2)
        self.rackScroll = math.max(0, math.min(math.max(0, rows), self.rackScroll + step))
        return true
    end
    return false
end

--- Texte de l'infobulle de la cible survolée (texte riche), ou nil.
function PostWindow:tooltipFor(target, payload)
    local data = self.data
    if not data then
        return nil
    end
    if target == "mission" then
        return nil
    elseif target == "affair" then
        if payload.kind == "mission" then
            return nil
        end
        return escape(payload.title) .. " <LINE> " .. escape(payload.sub or "")
    elseif target == "tag" then
        return escape(getText("IGUI_MilitaryDrop_PostTagTooltip", PostWindow.mailName(payload), tostring(payload.by or "?")))
    elseif target == "standing" then
        return escape(PostWindow.trustText(data)) .. " <LINE> " .. escape(PostWindow.effectText(data))
            .. " <LINE> <LINE> " .. escape(getText("IGUI_MilitaryDrop_PostStandingTooltip"))
    elseif target == "status" then
        return escape(PostWindow.statusText(data))
    elseif target == "primary" or target == "secondary" then
        local primary, secondary = self:actions()
        local action = target == "primary" and primary or secondary
        if action and not action.enabled and action.reason then
            return escape(getText(action.reason, "0"))
        end
        local entry = self:selectedAffair()
        if target == "secondary" and entry and entry.kind == "tags" and #self.tagLabels > 0 then
            local names = {}
            for i, label in ipairs(self.tagLabels) do
                names[i] = escape(label)
            end
            return table.concat(names, " <LINE> ")
        end
        return action and escape(action.text) or nil
    elseif target == "request" then
        return escape(getText(self:requestReason() or "IGUI_MilitaryDrop_RequestTooltip"))
    elseif target == "close" then
        return escape(getText("IGUI_MilitaryDrop_PostClose"))
    end
    return nil
end

function PostWindow:showTooltip(text)
    if text and text ~= "" then
        if not self.tooltipUI then
            self.tooltipUI = ISToolTip:new()
            self.tooltipUI:setOwner(self)
            self.tooltipUI:setVisible(false)
            self.tooltipUI:setAlwaysOnTop(true)
            self.tooltipUI.maxLineWidth = 360
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

function PostWindow:update()
    ISPanelJoypad.update(self)
    if not self:getIsVisible() then
        return
    end
    if not self:objectValid() then
        self:close("radio gone or player too far")
        return
    end
    local now = getTimestampMs()
    if now - self.lastRefreshMs >= PostWindow.REFRESH_MS or now < self.lastRefreshMs then
        self.lastRefreshMs = now
        sendToServer(self.player, "PostOpen", self.object)
        self:updateButtons()
    end
    self:showTooltip(self:tooltipFor(self:mouseTarget()))
end

--- reason : cause de la fermeture, notée au journal (option DebugLog).
function PostWindow:close(reason)
    MilitaryDrop.log("post console closed: " .. tostring(reason or "?"))
    self:showTooltip(nil)
    self:setVisible(false)
    if JoypadState.players[self.playerNum + 1] and getFocusForPlayer(self.playerNum) == self then
        setJoypadFocus(self.playerNum, nil)
    end
    self:removeFromUIManager()
    if PostWindow.instances[self.playerNum] == self then
        PostWindow.instances[self.playerNum] = nil
    end
end

-- Clavier : Échap ferme la console (sans ouvrir le menu de pause).
function PostWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function PostWindow:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE and self:isReallyVisible() then
        self:close("escape")
    end
end

-- Manette : haut et bas choisissent l'affaire, A et X lancent ses actions
-- (bouton de droite, de gauche), Y demande un largage (ou ouvre le clavier à
-- l'écran tant que le code manque), RB saisit le code, LB fait défiler le
-- journal (revient en bas une fois en haut), B ferme.
function PostWindow:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self.drawJoypadFocus = true
end

function PostWindow:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
    self.drawJoypadFocus = false
end

function PostWindow:onJoypadDown(button)
    if button == Joypad.AButton then
        if self:isEnabled("primary") then
            self:activate("primary")
        end
    elseif button == Joypad.XButton then
        if self:isEnabled("secondary") then
            self:activate("secondary")
        end
    elseif button == Joypad.YButton then
        if self:requestReason() == "IGUI_MilitaryDrop_RadioModule_NeedCode" then
            self:openKeyboard()
        else
            self:onRequest()
        end
    elseif button == Joypad.RBumper then
        self:openKeyboard()
    elseif button == Joypad.LBumper then
        local journal = self.journal
        if journal:getYScroll() >= 0 then
            PostWindow.scrollJournal(journal, -journal:getScrollHeight())
        else
            PostWindow.scrollJournal(journal, self.L.lh * 3)
        end
    elseif button == Joypad.BButton then
        self:close("joypad B")
    end
end

function PostWindow:onJoypadDirUp()
    self:moveSelection(-1)
end

function PostWindow:onJoypadDirDown()
    self:moveSelection(1)
end

function PostWindow:getAPrompt()
    local primary = self:actions()
    return primary and primary.text or nil
end

function PostWindow:getXPrompt()
    local _, secondary = self:actions()
    return secondary and secondary.text or nil
end

function PostWindow:getYPrompt()
    if self:requestReason() == "IGUI_MilitaryDrop_RadioModule_NeedCode" then
        return getText("IGUI_MilitaryDrop_RadioModule_TypeCode")
    end
    return getText("IGUI_MilitaryDrop_RequestDrop")
end

function PostWindow:getBPrompt()
    return getText("IGUI_MilitaryDrop_PostClose")
end

--- Ouvre (ou met à jour) la console du joueur.
function PostWindow.show(player, object, data)
    local playerNum = player:getPlayerNum()
    local window = PostWindow.instances[playerNum]
    if not window then
        local screenW, screenH = getPlayerScreenWidth(playerNum), getPlayerScreenHeight(playerNum)
        local width, height = PostWindow.measureSize(data, screenW, screenH)
        width, height = math.min(width, screenW), math.min(height, screenH)
        local x = getPlayerScreenLeft(playerNum) + math.floor((screenW - width) / 2)
        local y = getPlayerScreenTop(playerNum) + math.floor((screenH - height) / 2)
        window = PostWindow:new(x, y, width, height, player, object)
        window.maxWidth, window.maxHeight = screenW, screenH
        window:initialise()
        window:instantiate()
        window:addToUIManager()
        PostWindow.instances[playerNum] = window
        if JoypadState.players[playerNum + 1] then
            if getPlayerInventory(playerNum) then
                getPlayerInventory(playerNum):close()
            end
            if getPlayerLoot(playerNum) then
                getPlayerLoot(playerNum):close()
            end
            setJoypadFocus(playerNum, window)
        end
    end
    window.object = object
    window:setVisible(true)
    window:setData(data)
    return window
end

-- ----------------------------------------------------------------------------
-- Réponses du serveur
-- ----------------------------------------------------------------------------

local function localPlayer(playerNum)
    return getSpecificPlayer(playerNum or 0)
end

local function onPostData(args)
    if type(args.x) == "number" then
        PostWindow.myPost = { x = args.x, y = args.y, z = args.z }
    end
    local request = pendingOpen
    pendingOpen = nil
    if request then
        local player = localPlayer(request.playerNum)
        if player and request.object then
            PostWindow.show(player, request.object, args)
        end
        return
    end
    -- Rafraîchissement, dépôt, transmission : console du joueur concerné
    -- (toutes si le nom manque).
    for _, window in pairs(PostWindow.instances) do
        if type(args.username) ~= "string" or (window.player and window.player:getUsername() == args.username) then
            window:setData(args)
        end
    end
end

--- Joueur local concerné par une réponse (écran partagé : nom envoyé par le
--- serveur), sinon le joueur 0.
function PostWindow.playerFor(username)
    if type(username) == "string" then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player and player:getUsername() == username then
                return player
            end
        end
    end
    return localPlayer(0)
end

local function onPostResult(args)
    local status = tostring(args.status)
    if status ~= "installed" and status ~= "moved" then
        pendingOpen = nil
    end
    local player = PostWindow.playerFor(args.username)
    -- Installation demandée par le bouton de la fenêtre radio : la console
    -- s'ouvre ensuite (poste installé, déplacé, ou déjà là).
    local waiting = false
    for _ in pairs(pendingInstallOpen) do
        waiting = true
    end
    local playerNum = waiting and player and player:getPlayerNum() or nil
    local installed = playerNum ~= nil and pendingInstallOpen[playerNum]
    if installed and status ~= "busy" then
        pendingInstallOpen[playerNum] = nil
        if status == "installed" or status == "moved" or status == "already" then
            PostWindow.requestOpen(player, installed)
        end
    end
    if PostWindow.RESULTS[status] and player then
        player:Say(getText("IGUI_MilitaryDrop_PostResult_" .. status, tostring(args.count or 0)))
    end
    -- Poste de l'équipe inconnu ou périmé (nouveau membre d'une faction, poste
    -- déplacé par un coéquipier) : redemander sa position.
    if (status == "already" or status == "notPost" or status == "otherTeam") and player then
        Net.toServer(player, "PostSync", {})
    end
    if PostWindow.CLOSING[status] and player then
        -- Fermées après le parcours (close retire l'instance de la table).
        local closing = {}
        for _, window in pairs(PostWindow.instances) do
            if window.player == player then
                closing[#closing + 1] = window
            end
        end
        for _, window in ipairs(closing) do
            window:close("server: " .. status)
        end
    end
end

--- Commandes du poste ; renvoie vrai si la commande a été traitée.
function PostWindow.handleCommand(module, command, args)
    if module ~= Net.MODULE or type(args) ~= "table" then
        return false
    end
    if command == "PostInfo" then
        if type(args.x) == "number" then
            PostWindow.myPost = { x = args.x, y = args.y, z = args.z }
        else
            PostWindow.myPost = nil
        end
        -- Poste installé, déplacé ou perdu : états des radios à redemander.
        PostWindow.radioStates = {}
        return true
    elseif command == "PostStatus" then
        if type(args.x) == "number" and type(args.status) == "string" then
            PostWindow.radioStates[radioKey(args.x, args.y, args.z)] = args.status
        end
        return true
    elseif command == "PostData" then
        onPostData(args)
        return true
    elseif command == "PostResult" then
        onPostResult(args)
        return true
    end
    return false
end

-- Commandes du poste, reçues par MilitaryDrop.Client (solo et MP).
for _, command in ipairs({ "PostInfo", "PostData", "PostResult", "PostStatus" }) do
    MilitaryDrop.Client.HANDLERS[command] = function(args)
        PostWindow.handleCommand(Net.MODULE, command, args)
    end
end

--- Arrivée en jeu : position du poste de l'équipe.
function PostWindow.onGameStart()
    local player = getSpecificPlayer(0)
    if player then
        Net.toServer(player, "PostSync", {})
    end
end

Events.OnGameStart.Add(PostWindow.onGameStart)
-- Plus de menu contextuel (2026-10-01) : bouton « Poste de liaison » de la
-- fenêtre radio (MilitaryDrop_RadioModule.lua, PostWindow.useRadio).

return PostWindow
