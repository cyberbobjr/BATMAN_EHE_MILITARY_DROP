-- ============================================================================
-- Military Drop — interface client : appel radio et réponses de la base
--
-- Appel de largage par une radio militaire (objet d'inventaire, ou appareil
-- posé à portée), lancé par le bouton « Demander un largage » de la section
-- « Logistique » de la fenêtre radio (MilitaryDrop_RadioModule.lua) ou de la
-- console du poste de liaison (Client.onRequest, boîte de saisie du code). Le
-- menu contextuel n'offre plus aux joueurs que « Options de l'appareil »
-- (décision du 2026-10-01) ; seul le largage forcé de l'admin y reste
-- (Client.addOptions). Le client ne décide rien : il demande le code si
-- l'option l'exige, fait parler le personnage, envoie la demande au serveur,
-- puis affiche la réponse par la radio.
--
-- La fréquence militaire n'est jamais vérifiée ici : griser l'option sur une
-- mauvaise fréquence permettrait de la trouver en balayant les canaux.
--
-- Confiance personnelle : le serveur envoie avec l'accord le palier du personnage
-- (args.tier, 1 à 4) et son indicatif ; la réplique de la base en dépend. Aucun
-- chiffre n'est jamais affiché.
--
-- AUTH-03 (v1.3) : un talkie à la ceinture, sur le dos ou dans un sac n'est
-- plus un motif de refus. Après la saisie du code, le personnage le prend en
-- main (MilitaryDrop.Exchange.run : action vanilla), puis appelle ; en MP,
-- l'état de toute radio d'inventaire est renvoyé au serveur avant l'appel,
-- même déjà en main. Le serveur ne connaît l'état d'une radio d'inventaire
-- que si elle est en main au moment du réglage.
--
-- La fréquence militaire n'est connue du client MP que si l'option Frequency
-- la fixe ; par défaut, elle est tirée par le serveur et lue sur les notes.
--
-- Réquisition (v1.4, dev/PLAN-V14.md) : un appel accepté peut recevoir
-- Result « form » au lieu de « accepted ». La base le dit à la radio, puis le
-- formulaire s'ouvre (MilitaryDrop.RequisitionWindow) ; la demande reste en
-- attente jusqu'à la commande (RequisitionOrder, même requestId et même
-- radio) ou l'annulation (RequisitionCancel). La réponse à la commande est un
-- Result ordinaire (accepted, ou orderInvalid, expired, cooldown…). Les
-- répliques du personnage (player:Say) restent locales en MP : le contenu de
-- la commande n'est jamais prononcé. Le largage forcé de l'admin reçoit aussi
-- « form » (args.forced : feuille « ADMIN », tous les lots, budget maximal,
-- sans radio exigée) ; accepté, il attend ensuite ses coordonnées privées
-- (Dropped), comme un largage forcé direct.
--
-- Module « Logistique » de la fenêtre radio (MilitaryDrop_RadioModule.lua) :
-- même appel (Client.call), avec opts.anchor = fenêtre radio pour coller la
-- feuille de réquisition à cette fenêtre. Le code saisi (Client.rememberCode)
-- préremplit le champ du module et la saisie de la console du poste ; il
-- survit au rechargement, par personnage, dans un fichier du client
-- (Client.codeFile : Zomboid/Lua/MilitaryDrop/code_<partie>_<personnage>.txt,
-- getFileWriter), jamais envoyé ailleurs qu'à l'appel. Pas dans la ModData
-- du joueur : en MP, seule celle de l'IsoPlayer du serveur est sauvegardée
-- (ServerPlayerDB.java:122, 346-359 : player.save côté serveur), et la
-- transmettre (transmitModData → ObjectModDataPacket) la relaie aux clients
-- proches (ObjectModDataPacket.processServer → sendToRelativeClients,
-- INetworkPacket.java:118-124) : le code serait lu par les voisins. Partie :
-- getWorld():getWorld() (Core.gameSaveWorld : nom de la sauvegarde en solo,
-- « ip_port_hash du compte » sur un client MP, GameClient.java:1723).
-- La dernière réplique de la base reçue par chaque joueur local
-- (Client.radioSay) est gardée pour l'afficher dans le module
-- (Client.lastReply).
-- ============================================================================

require "ISUI/ISTextBox"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Exchange"
require "MilitaryDrop/MilitaryDrop_Codes"
require "MilitaryDrop/MilitaryDrop_Heli"
require "MilitaryDrop/MilitaryDrop_Announce"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Radio = MilitaryDrop.Radio
local Codes = MilitaryDrop.Codes

local Client = {}
MilitaryDrop.Client = Client

Client.CALL_COUNT = 5
Client.ACK_COUNT = 5
-- Répliques d'accord par palier de confiance (IGUI_MilitaryDrop_AckTier<palier>_<n>).
Client.TIER_COUNT = 4
Client.TIER_ACK_COUNT = 3
-- Délais réels (ms) : code après l'appel, réponse de la base, confirmation
-- après le largage (envoyé par le serveur au passage de l'hélicoptère).
Client.CODE_DELAY_MS = 2500
Client.REPLY_DELAY_MS = 5000
Client.DROPPED_DELAY_MS = 4000
Client.RADIO_COLOR = { r = 0.45, g = 0.85, b = 0.45 }

local pending = {}
local nextRequestId = 1
-- Joueur local → { file, code } : code gardé (voir Client.rememberCode).
local rememberedCodes = {}
local lastReplies = {}
local replyCount = 0

-- ----------------------------------------------------------------------------
-- Tâches différées (abonnement à OnTick seulement quand il y en a)
-- ----------------------------------------------------------------------------

local tasks = {}
local ticking = false

local function runTasks()
    local now = getTimestampMs()
    for i = #tasks, 1, -1 do
        local task = tasks[i]
        if now >= task.at then
            table.remove(tasks, i)
            task.fn()
        end
    end
    if #tasks == 0 then
        Events.OnTick.Remove(runTasks)
        ticking = false
    end
end

function Client.later(delayMs, fn)
    tasks[#tasks + 1] = { at = getTimestampMs() + delayMs, fn = fn }
    if not ticking then
        ticking = true
        Events.OnTick.Add(runTasks)
    end
end

-- ----------------------------------------------------------------------------
-- Paroles
-- ----------------------------------------------------------------------------

local function randomText(prefix, count)
    return getText(prefix .. (ZombRand(count) + 1))
end

--- La base répond par la radio ; si elle est éteinte ou perdue, par le
--- personnage (il répète ce qu'il a entendu).
--- Un appareil posé (IsoWaveSignal) a aussi une surcharge AddDeviceText en
--- entiers 0-255 que Kahlua choisit pour des flottants : 0,45 devenait 0 et le
--- texte s'affichait en noir. Il reçoit donc des entiers 0-255, qui donnent la
--- même couleur avec les deux surcharges. Une radio d'inventaire (Radio) n'a
--- que la version 0-1.
function Client.radioSay(request, text)
    replyCount = replyCount + 1
    lastReplies[request.playerNum] = { text = text, device = request.device, seq = replyCount }
    local player = getSpecificPlayer(request.playerNum)
    local device = request.device
    local data = device and device:getDeviceData()
    if data and data:getIsTurnedOn() and data:getDeviceVolume() > 0 then
        local color = Client.RADIO_COLOR
        if Radio.isWorldRadio(device) then
            device:AddDeviceText(text, math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
                math.floor(color.b * 255 + 0.5), nil, nil, -1)
        else
            device:AddDeviceText(text, color.r, color.g, color.b, nil, nil, -1)
        end
    elseif player then
        player:Say(text)
    end
end

local function playerSay(request, text)
    local player = getSpecificPlayer(request.playerNum)
    if player then
        player:Say(text)
    end
end

--- Dernière réplique de la base reçue par le joueur local : { text, device,
--- seq (croissant à chaque réplique) }, ou nil.
function Client.lastReply(playerNum)
    return lastReplies[playerNum]
end

-- Code gardé : dossier sous Zomboid/Lua, longueur des parties du nom.
Client.CODE_DIR = "MilitaryDrop"
Client.CODE_NAME_MAX = 60

--- Partie de nom de fichier sûre : lettres, chiffres, tirets ; le reste en « _ ».
local function fileSafe(text)
    local safe = string.gsub(tostring(text or ""), "[^%w%-]", "_")
    if #safe > Client.CODE_NAME_MAX then
        safe = string.sub(safe, 1, Client.CODE_NAME_MAX)
    end
    return safe
end

--- Fichier du code d'un personnage (chemin relatif à Zomboid/Lua), ou nil :
--- partie (mode, sauvegarde ou serveur) et personnage (compte, prénom, nom).
function Client.codeFile(player)
    if not player or not getWorld or not getWorld() then
        return nil
    end
    local world = getWorld():getWorld()
    if type(world) ~= "string" or world == "" then
        return nil
    end
    local desc = player:getDescriptor()
    local character = desc and (tostring(desc:getForename()) .. "_" .. tostring(desc:getSurname())) or ""
    local mode = isClient() and "mp" or "sp"
    return Client.CODE_DIR .. "/code_" .. mode .. "_" .. fileSafe(world) .. "_"
        .. fileSafe(tostring(player:getUsername()) .. "_" .. character) .. ".txt"
end

local function readCodeFile(file)
    local reader = getFileReader(file, false)
    if not reader then
        return ""
    end
    local line = reader:readLine()
    reader:close()
    return type(line) == "string" and line or ""
end

local function writeCodeFile(file, code)
    local writer = getFileWriter(file, true, false)
    if writer then
        writer:write(code)
        writer:close()
    end
end

--- Code d'authentification saisi par le joueur local : gardé en mémoire et
--- dans le fichier de son personnage (Client.codeFile), réécrit seulement
--- s'il change. Vide : effacé.
function Client.rememberCode(playerNum, code)
    if type(code) ~= "string" then
        code = ""
    end
    local file = Client.codeFile(getSpecificPlayer(playerNum))
    local known = rememberedCodes[playerNum]
    if known and known.file == file and known.code == code then
        return
    end
    rememberedCodes[playerNum] = { file = file, code = code }
    if file then
        writeCodeFile(file, code)
    end
end

--- Code gardé du joueur local (lu une fois dans le fichier de son
--- personnage, puis en mémoire), ou "".
function Client.rememberedCode(playerNum)
    local file = Client.codeFile(getSpecificPlayer(playerNum))
    local known = rememberedCodes[playerNum]
    if not known or known.file ~= file then
        known = { file = file, code = file and readCodeFile(file) or "" }
        rememberedCodes[playerNum] = known
    end
    return known.code
end

-- ----------------------------------------------------------------------------
-- Demande
-- ----------------------------------------------------------------------------

--- Droit d'afficher le largage forcé (le serveur revérifie).
function Client.canForce(player)
    if isClient() then
        local role = player:getRole()
        return role ~= nil and role:hasCapability(Capability.MakeEventsAlarmGunshot)
    end
    return isDebugEnabled()
end

--- opts.anchor (facultatif) : fenêtre à laquelle coller la feuille de réquisition.
function Client.sendRequest(player, device, code, force, opts)
    local requestId = nextRequestId
    nextRequestId = nextRequestId + 1
    local request = { playerNum = player:getPlayerNum(), device = device, force = force == true,
        anchor = type(opts) == "table" and opts.anchor or nil }
    pending[requestId] = request

    player:Say(randomText("IGUI_MilitaryDrop_Call_", Client.CALL_COUNT))
    local args = { requestId = requestId, radio = Radio.makeRef(device), force = force == true }
    if code then
        args.code = code
        Client.later(Client.CODE_DELAY_MS, function()
            playerSay(request, getText("IGUI_MilitaryDrop_CallCode", code))
        end)
    end
    Net.toServer(player, "Request", args)
end

--- Appel par la radio : prise en main du talkie si besoin (AUTH-03), puis
--- demande. Le largage admin n'exige pas la radio : envoyé aussitôt. Renvoie
--- false si la radio n'est pas utilisable (rien n'est envoyé). opts : voir
--- Client.sendRequest.
function Client.call(player, device, code, force, opts)
    if code then
        Client.rememberCode(player:getPlayerNum(), code)
    end
    if force then
        Client.sendRequest(player, device, code, force, opts)
        return true
    end
    return MilitaryDrop.Exchange.run(player, device, nil, function()
        Client.sendRequest(player, device, code, false, opts)
    end)
end

local function onCodeEntered(_, button, player, device)
    if button.internal ~= "OK" then
        return
    end
    local code = button.parent.entry:getText()
    if code and code ~= "" then
        Client.call(player, device, code, false)
    end
end

function Client.onRequest(player, device, force)
    if force or Config.codeMode() == Codes.MODE_NONE then
        Client.call(player, device, nil, force)
        return
    end
    local modal = ISTextBox:new(0, 0, 280, 180, getText("IGUI_MilitaryDrop_EnterCode"),
        Client.rememberedCode(player:getPlayerNum()), nil,
        onCodeEntered, player:getPlayerNum(), player, device)
    modal:initialise()
    modal:addToUIManager()
end

-- ----------------------------------------------------------------------------
-- Réponses du serveur
-- ----------------------------------------------------------------------------

-- Mauvais canal ou mauvais code : même réponse du serveur (« noAnswer »).
-- Réquisition : autorisation expirée, commande refusée par le serveur.
local RADIO_REPLIES = {
    noAnswer = "IGUI_MilitaryDrop_NoAnswer",
    noSite = "IGUI_MilitaryDrop_NoSite",
    expired = "IGUI_MilitaryDrop_ReqExpired",
    orderInvalid = "IGUI_MilitaryDrop_ReqOrderInvalid",
}

-- ----------------------------------------------------------------------------
-- Réquisition (v1.4)
-- ----------------------------------------------------------------------------

-- Refus d'une commande qui gardent l'autorisation du serveur (radio éteinte
-- ou introuvable, cadence, aucun point de largage : secteur du leurre hors
-- carte) : le formulaire se rouvre, rempli, pour renvoyer. Leurre à secteur
-- unique (single) : la feuille reste utile (commande de lots, nouvel essai).
Client.REQUISITION_RETRY = { busy = true, radioOff = true, noRadio = true, notMilitary = true, noSite = true }

--- La base invite à transmettre, puis le formulaire s'ouvre. Le délai de
--- validité part de la réception (receivedMs), pas de l'ouverture.
local function openForm(requestId, request, args, receivedMs)
    if pending[requestId] ~= request or request.formOpen then
        return
    end
    Client.radioSay(request, getText("IGUI_MilitaryDrop_ReqFormSay", tostring(args.callsign or "")))
    local Window = MilitaryDrop.RequisitionWindow
    local player = getSpecificPlayer(request.playerNum)
    if not Window or not player then
        Client.cancelRequisition(requestId, false)
        return
    end
    request.formOpen = true
    Window.open(player, request.device, args, receivedMs, request.anchor)
end

--- Radio de la demande désignable pour le serveur (appareil posé encore sur
--- sa case) : référence comme pour Request, sinon nil.
local function radioRef(device)
    if not device then
        return nil
    end
    if Radio.isWorldRadio(device) and not device:getSquare() then
        return nil
    end
    return Radio.makeRef(device)
end

--- Transmet la commande (RequisitionOrder) : order = { [lotId] = quantité },
--- decoy = secteur ou nil ; form : formulaire gardé pour le rouvrir si le
--- serveur garde l'autorisation (REQUISITION_RETRY). Renvoie false si la
--- demande n'attend plus rien.
function Client.sendRequisition(requestId, order, decoy, form)
    local request = pending[requestId]
    if not request or request.ordered then
        return false
    end
    local player = getSpecificPlayer(request.playerNum)
    if not player then
        pending[requestId] = nil
        return false
    end
    request.ordered = true
    request.form = form
    player:Say(getText("IGUI_MilitaryDrop_ReqOrderSay", tostring(request.callsign or "")))
    Net.toServer(player, "RequisitionOrder", { requestId = requestId, radio = radioRef(request.device),
        order = order or {}, decoy = decoy })
    return true
end

--- Annule la réquisition (RequisitionCancel) ; spoken : le personnage le dit
--- (bouton « Annuler »), sinon silence (feuille fermée, radio hors de portée).
function Client.cancelRequisition(requestId, spoken)
    local request = pending[requestId]
    if not request or request.ordered then
        return false
    end
    pending[requestId] = nil
    local player = getSpecificPlayer(request.playerNum)
    if not player then
        return false
    end
    if spoken then
        player:Say(getText("IGUI_MilitaryDrop_ReqCancelSay", tostring(request.callsign or "")))
    end
    Net.toServer(player, "RequisitionCancel", { requestId = requestId })
    return true
end

--- Réplique d'accord : selon le palier de confiance reçu, sinon la réplique neutre.
function Client.ackText(args)
    local tier = math.floor(tonumber(args.tier) or 0)
    if tier >= 1 and tier <= Client.TIER_COUNT and type(args.callsign) == "string" then
        return getText("IGUI_MilitaryDrop_AckTier" .. tier .. "_" .. (ZombRand(Client.TIER_ACK_COUNT) + 1), args.callsign)
    end
    return randomText("IGUI_MilitaryDrop_Ack_", Client.ACK_COUNT)
end

local function onResult(request, args)
    local status = args.status
    if status == "form" then
        local receivedMs = getTimestampMs()
        local requestId = args.requestId
        request.callsign = args.callsign
        Client.later(Client.REPLY_DELAY_MS, function()
            openForm(requestId, request, args, receivedMs)
        end)
    elseif status == "accepted" then
        Client.later(Client.REPLY_DELAY_MS, function()
            Client.radioSay(request, Client.ackText(args))
        end)
    elseif status == "noSite" and args.sector then
        -- Leurre : aucun point de largage dans le secteur choisi. Secteur
        -- unique (single, mode zones) : pas d'« autre secteur » à proposer.
        local key = args.single == true and "IGUI_MilitaryDrop_ReqNoZoneSite" or "IGUI_MilitaryDrop_ReqNoSector"
        Client.later(Client.REPLY_DELAY_MS, function()
            Client.radioSay(request, getText(key))
        end)
    elseif status == "lineCut" then
        -- Ligne coupée : la base le dit (révélé seulement après un canal et un code justes).
        Client.later(Client.REPLY_DELAY_MS, function()
            Client.radioSay(request, getText("IGUI_MilitaryDrop_LineCut", tostring(args.callsign or "")))
        end)
    elseif RADIO_REPLIES[status] then
        Client.later(Client.REPLY_DELAY_MS, function()
            Client.radioSay(request, getText(RADIO_REPLIES[status]))
        end)
    elseif status == "cooldown" then
        playerSay(request, getText("IGUI_MilitaryDrop_Cooldown", tostring(args.hours or "?")))
    elseif status == "radioOff" then
        playerSay(request, getText("IGUI_MilitaryDrop_TurnOn"))
    elseif status == "busy" then
        -- Demande trop rapprochée (cadence du serveur) : rien de la base.
        playerSay(request, getText("IGUI_MilitaryDrop_Busy"))
    else
        playerSay(request, getText("IGUI_MilitaryDrop_CannotCall"))
    end
end

local function onDropped(request, args)
    Client.later(Client.DROPPED_DELAY_MS, function()
        Client.radioSay(request, getText("IGUI_MilitaryDrop_Dropped", tostring(args.x), tostring(args.y)))
    end)
end

local FLIGHT_COMMANDS = {
    FlightStart = "onFlightStart",
    FlightSync = "onFlightSync",
    FlightEnd = "onFlightEnd",
    FlightCrash = "onFlightCrash",
}

--- Commandes du serveur traitées par d'autres modules client (poste…) :
--- nom → function(args). En solo, Net.toPlayer appelle directement
--- Client.onServerCommand ; en MP, Client.onServerCommand est l'abonné
--- d'OnServerCommand : un seul point d'entrée dans les deux cas.
Client.HANDLERS = {}

Client.HANDLERS.CharacterIdentity = function(args)
    if type(args.id) ~= "string" or not args.id:match("^C:") then
        return
    end
    local player = getSpecificPlayer(tonumber(args.index) or 0)
    if player and tostring(player:getUsername()) == args.username then
        player:getModData().MilitaryDrop_characterId = args.id
    end
end

function Client.onServerCommand(module, command, args)
    if module ~= Net.MODULE or type(args) ~= "table" then
        return
    end
    local handler = Client.HANDLERS[command]
    if handler then
        handler(args)
        return
    end
    if FLIGHT_COMMANDS[command] then
        MilitaryDrop.Heli[FLIGHT_COMMANDS[command]](args)
        return
    end
    if command == "DropAnnounce" then
        MilitaryDrop.Announce.onDropAnnounce(args)
        return
    end
    if command == "MaydayAnnounce" then
        MilitaryDrop.Announce.onMaydayAnnounce(args)
        return
    end
    if command == "ReconAnnounce" then
        MilitaryDrop.Announce.onReconAnnounce(args)
        return
    end
    if command == "CleanupAnnounce" then
        MilitaryDrop.Announce.onCleanupAnnounce(args)
        return
    end
    local request = pending[args.requestId]
    if not request then
        return
    end
    if command == "Result" then
        local Window = MilitaryDrop.RequisitionWindow
        if request.ordered and request.form and Client.REQUISITION_RETRY[args.status] and Window
            and not Window.expired(request.form, getTimestampMs()) then
            -- Commande refusée mais autorisation gardée : le personnage dit le
            -- motif, puis la feuille se rouvre telle quelle.
            onResult(request, args)
            local player = getSpecificPlayer(request.playerNum)
            if player then
                request.ordered = false
                Window.show(player, request.device, request.form, request.anchor)
                return
            end
        end
        if args.status ~= "form" and request.formOpen and Window then
            -- Réponse du serveur pendant que la feuille est ouverte : elle se ferme.
            Window.dismiss(args.requestId)
        end
        onResult(request, args)
        -- Seul un largage admin attend encore un message (coordonnées privées) ;
        -- les autres les entendent sur la chaîne militaire. Un formulaire
        -- attend la commande ou l'annulation.
        if args.status ~= "form" and (args.status ~= "accepted" or not request.force) then
            pending[args.requestId] = nil
        end
    elseif command == "Dropped" then
        onDropped(request, args)
        pending[args.requestId] = nil
    end
end

-- ----------------------------------------------------------------------------
-- Remarques du serveur, réponse à l'admin
-- ----------------------------------------------------------------------------

--- Joueur local de ce nom (écran partagé), sinon le premier.
local function localPlayer(username)
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and (username == nil or player:getUsername() == username) then
            return player
        end
    end
    return getSpecificPlayer(0)
end

--- Notice : remarque du personnage envoyée par le serveur (clé de traduction
--- du mod, args.key), dite dans la langue du client. Ex. caisse de
--- réquisition rendue fermée (lot inconnu, MilitaryDrop_Recipe.lua).
function Client.onNotice(args)
    local key = args.key
    if type(key) ~= "string" or key:sub(1, 18) ~= "IGUI_MilitaryDrop_" then
        return
    end
    local player = localPlayer(args.username)
    if player then
        player:Say(getText(key))
    end
end

--- ReloadLotsReply : résumé du rechargement des lots (commande d'admin),
--- écrit dans la console de l'admin, comme les autres commandes de console.
function Client.onReloadLotsReply(args)
    print("[MilitaryDrop] " .. tostring(args.summary))
    for _, problem in ipairs(type(args.problems) == "table" and args.problems or {}) do
        print("[MilitaryDrop]   " .. tostring(problem))
    end
    local count = tonumber(args.problemCount) or 0
    if type(args.problems) == "table" and count > #args.problems then
        print("[MilitaryDrop]   ... " .. (count - #args.problems) .. " more in the server console")
    end
end

Client.HANDLERS.Notice = Client.onNotice
Client.HANDLERS.ReloadLotsReply = Client.onReloadLotsReply

-- ----------------------------------------------------------------------------
-- Menus contextuels
-- ----------------------------------------------------------------------------

--- Menu contextuel d'une radio militaire : seulement le largage admin.
--- Les joueurs passent par la section « Logistique » de la fenêtre radio
--- (MilitaryDrop_RadioModule.lua, RADIO-06), ouverte par « Options de
--- l'appareil » : elle remplace le menu « Logistique » et « Demander un
--- largage » (décision de l'utilisateur du 2026-10-01).
function Client.addOptions(player, context, device)
    -- Largage admin : jamais grisé, le serveur n'exige pas la radio en main.
    if Client.canForce(player) then
        context:addOption(getText("IGUI_MilitaryDrop_RequestDropAdmin"), player, Client.onRequest, device, true)
        -- Missions à la demande (admin) : le serveur revérifie le droit.
        local parent = context:addOption(getText("IGUI_MilitaryDrop_AdminMissions"))
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(parent, sub)
        for _, kind in ipairs(Client.ADMIN_MISSIONS) do
            sub:addOption(getText("IGUI_MilitaryDrop_AdminMission_" .. kind), player, Client.onAdminMission, kind)
        end
        for _, kind in ipairs(Client.ADMIN_MISSIONS) do
            sub:addOption(getText("IGUI_MilitaryDrop_AdminMissionClose_" .. kind), player, Client.onAdminMission, kind,
                "close")
        end
        context:addOption(getText("IGUI_MilitaryDrop_AdminCrashNext"), player, Client.onAdminCrashNext)
    end
end

-- Missions qu'un admin peut lancer (MilitaryDrop.Missions.KINDS côté serveur).
Client.ADMIN_MISSIONS = { "recon", "cleanup", "control" }

function Client.onAdminMission(player, kind, action)
    Net.toServer(player, "AdminMission", { kind = kind, action = action })
end

function Client.onAdminCrashNext(player)
    Net.toServer(player, "AdminCrashNext", {})
end

function Client.onFillInventoryContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    for _, entry in ipairs(items) do
        local item = entry
        if not instanceof(entry, "InventoryItem") then
            item = entry.items and entry.items[1]
        end
        if Radio.isInventoryRadio(item) and Radio.isMilitary(item) then
            Client.addOptions(player, context, item)
            return
        end
    end
end

function Client.onFillWorldContextMenu(playerNum, context, worldObjects, test)
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
                if Radio.isWorldRadio(candidate) and Radio.isMilitary(candidate) then
                    Client.addOptions(player, context, candidate)
                    return
                end
            end
        end
    end
end

--- MP : à l'arrivée en jeu, demande les vols déjà en cours (reconnexion).
function Client.onGameStart()
    local player = getSpecificPlayer(0)
    if isClient() and player then
        Net.toServer(player, "Sync", {})
    end
end

Events.OnGameStart.Add(Client.onGameStart)
Events.OnCreatePlayer.Add(function(index, player)
    if isClient() and index > 0 then
        Net.toServer(player, "Sync", {})
    end
end)
Events.OnFillInventoryObjectContextMenu.Add(Client.onFillInventoryContextMenu)
Events.OnFillWorldObjectContextMenu.Add(Client.onFillWorldContextMenu)
Events.OnServerCommand.Add(Client.onServerCommand)

return Client
