-- ============================================================================
-- Military Drop — autorité serveur (serveur MP ou solo)
--
-- Le client envoie seulement une demande (commande « Request » : référence de
-- la radio, code saisi, demande admin). Le serveur revérifie tout, dans cet
-- ordre : cadence, droits admin, radio à portée, radio militaire allumée, puis
-- canal et code ensemble, puis délai global. Mauvais canal et mauvais code
-- donnent la même réponse (« noAnswer ») : on ne peut trouver la fréquence en
-- appelant chaque canal. Le délai n'est révélé qu'après un canal et un code
-- justes. Fréquence : option Frequency, ou fréquence libre secrète tirée par
-- le serveur (MilitaryDrop_Broadcast.lua).
--
-- Code (option AuthCode) : aucun, fixe, ou celui de la semaine (le précédent
-- reste accepté 24 h). Après FAILED_CODE_LIMIT codes faux dans la même
-- journée de jeu, la base ne répond plus à ce joueur jusqu'au lendemain,
-- même avec le bon code : la réponse reste « noAnswer », rien ne trahit le
-- silence (parade à la force brute : 676 codes quand les chiffres sont
-- connus). Le compteur reste en mémoire du serveur : dans la ModData, il
-- distinguerait un mauvais code (compté) d'un mauvais canal (non compté) et
-- révélerait la fréquence. Un redémarrage le remet à zéro.
--
-- État persistant public : ModData globale « MilitaryDrop » (heure du dernier
-- largage, vols, livraisons en attente). Tout client connecté peut la lire :
-- les secrets (code fixe, graine) sont dans des fichiers du serveur, et l'état
-- de la v1.3 (équipes, confiance, largages, missions, postes) dans une ModData
-- privée au nom tiré de la graine (MilitaryDrop.Secrets.privateState).
--
-- Une demande acceptée lance un hélicoptère (MilitaryDrop_Flights.lua) vers
-- un point tiré au hasard **loin du demandeur** (options DropMin/MaxDistance,
-- 150-400 cases par défaut), sur la carte et hors bâtiment (métagrille : pas
-- besoin que la zone soit chargée). Au passage de l'hélicoptère, les
-- coordonnées sont annoncées ; deliver pose la caisse de largage
-- (MilitaryDrop_Crate.lua ; à défaut, les caisses de ravitaillement au sol) et
-- la horde dès que la zone est chargée, au besoin sur la case libre la plus
-- proche.
--
-- Confiance (v1.3, MilitaryDrop_Trust.lua) : le délai global est multiplié par
-- le facteur de l'équipe qui appelle ; une ligne coupée répond « lineCut »,
-- révélé comme le délai après un canal et un code justes. Chaque largage
-- accepté reçoit un dropId (équipe du demandeur au moment de l'appel), porté
-- par le vol, la livraison en attente et chaque caisse de ravitaillement.
--
-- Réquisition (v1.4, MilitaryDrop_Requisition.lua) : avec l'option
-- RequisitionForm, un appel accepté ouvre le formulaire au lieu d'envoyer
-- l'hélicoptère ; la commande validée part par Server.launchDrop, comme un
-- appel accepté. Le largage admin l'ouvre aussi (feuille « admin » : tous
-- les lots, budget maximal, sans radio ni délai, Server.canForce revérifié
-- à la commande). Un leurre (v1.5) est tiré dans
-- le secteur choisi (pickDropPoint) ; sa livraison prévient
-- MilitaryDrop.Decoy.onDelivered.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Codes"
require "MilitaryDrop/MilitaryDrop_Secrets"
require "MilitaryDrop/MilitaryDrop_Guard"
require "MilitaryDrop/MilitaryDrop_Loot"
require "MilitaryDrop/MilitaryDrop_Flight"
require "MilitaryDrop/MilitaryDrop_Crate"
require "MilitaryDrop/MilitaryDrop_Broadcast"
require "MilitaryDrop/MilitaryDrop_Smoke"
require "MilitaryDrop/MilitaryDrop_Teams"
require "MilitaryDrop/MilitaryDrop_Trust"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Radio = MilitaryDrop.Radio
local Codes = MilitaryDrop.Codes
local Secrets = MilitaryDrop.Secrets
local Guard = MilitaryDrop.Guard

local Server = {}
MilitaryDrop.Server = Server

Server.MODDATA_TAG = "MilitaryDrop"
-- Une demande par joueur toutes les 3 s réelles au plus (anti-rafale) ; une
-- demande refusée reçoit le statut « busy ».
Server.REQUEST_INTERVAL_MS = 3000
-- Repli quand aucun point lointain ne convient : près du demandeur (zone chargée).
Server.LANDING_MIN_DISTANCE = 15
Server.LANDING_MAX_DISTANCE = 30
Server.LANDING_ATTEMPTS = 40
Server.FAR_ATTEMPTS = 40
Server.HORDE_RADIUS = 4
-- Rayon de recherche d'une case libre autour du point à la livraison
-- (un point lointain est tiré sans voir l'eau ni les obstacles).
Server.RELOCATE_RADIUS = 30
Server.CELL_SIZE = 256
-- Codes faux permis par joueur et par journée de jeu avant le silence.
Server.FAILED_CODE_LIMIT = 3
-- nom du joueur → { day, count } : mémoire du serveur seulement (voir en-tête).
local failedCodes = {}

--- État persistant public (lisible par les clients : vols, livraisons en
--- attente, délai). L'état privé : MilitaryDrop.Secrets.privateState().
function Server.getState()
    return ModData.getOrCreate(Server.MODDATA_TAG)
end

--- Horloge du calendrier du jeu, en heures (semaines alignées sur le lundi 00:00).
function Server.clock()
    return Codes.gameClock(getGameTime())
end

local function isWeekly(mode)
    return mode == Codes.MODE_WEEKLY_PLAIN or mode == Codes.MODE_WEEKLY_CIPHER
end

--- Code en vigueur (notes, console) : celui de la semaine, ou le code fixe.
function Server.getCode(clock)
    if isWeekly(Config.codeMode()) then
        return Codes.weeklyCode(Secrets.getSeed(), Codes.weekOf(clock or Server.clock()))
    end
    return Secrets.getFixedCode()
end

--- Codes acceptés à cette heure : celui de la semaine et, pendant la grâce,
--- celui de la semaine précédente ; ou le code fixe.
function Server.acceptedCodes(clock)
    local mode = Config.codeMode()
    if mode == Codes.MODE_NONE then
        return {}
    end
    if not isWeekly(mode) then
        return { Secrets.getFixedCode() }
    end
    local codes = {}
    for i, week in ipairs(Codes.acceptedWeeks(clock)) do
        codes[i] = Codes.weeklyCode(Secrets.getSeed(), week)
    end
    return codes
end

--- La base ignore ce joueur jusqu'au lendemain (trop de codes faux).
function Server.isSilenced(name, day)
    local entry = failedCodes[name]
    return entry ~= nil and entry.day == day and entry.count >= Server.FAILED_CODE_LIMIT
end

function Server.recordFailedCode(name, day)
    local entry = failedCodes[name]
    if not entry or entry.day ~= day then
        entry = { day = day, count = 0 }
        failedCodes[name] = entry
    end
    entry.count = entry.count + 1
    if entry.count == Server.FAILED_CODE_LIMIT then
        MilitaryDrop.log(name .. ": " .. entry.count .. " wrong codes today, ignored until tomorrow", true)
    end
    -- Code faux répété : perte de confiance de l'équipe (CONF-06). Un appel
    -- sur une mauvaise fréquence compte aussi (Server.evaluate).
    MilitaryDrop.Trust.onFailedCode(name)
end

--- Code juste (ou non exigé) ; compte les codes faux et applique le silence.
function Server.checkCode(player, code)
    if Config.codeMode() == Codes.MODE_NONE then
        return true
    end
    local name = tostring(player:getUsername())
    local clock = Server.clock()
    local day = math.floor(clock / 24)
    if Server.isSilenced(name, day) then
        -- Appel sans réponse compté comme les autres (CONF-06) : la confiance
        -- ne distingue pas le silence d'un code faux.
        MilitaryDrop.Trust.onFailedCode(name)
        return false
    end
    if not Codes.matchesAny(code, Server.acceptedCodes(clock)) then
        Server.recordFailedCode(name, day)
        return false
    end
    failedCodes[name] = nil
    return true
end

--- Heures de jeu avant le prochain largage permis (0 si permis) ; factor :
--- facteur de confiance de l'équipe qui appelle (1 par défaut).
function Server.hoursUntilNextDrop(state, now, factor)
    local last = tonumber(state.lastDropHours)
    if not last then
        return 0
    end
    local remaining = last + Config.get("CooldownHours") * (factor or 1) - now
    if remaining > 0 then
        return remaining
    end
    return 0
end

--- Largage forcé : même droit que la commande /chopper. En solo,
--- checkPermissions renvoie toujours vrai.
function Server.canForce(player)
    return checkPermissions(player, Capability.MakeEventsAlarmGunshot)
end

--- Décision sur une demande : statut, puis radio (acceptée) ou heures d'attente.
function Server.evaluate(player, args, now)
    if type(args) ~= "table" then
        return "invalid"
    end
    local force = args.force == true
    if force and not Server.canForce(player) then
        return "denied"
    end
    local radio = Radio.resolve(player, args.radio)
    if force then
        -- Largage admin : la radio ne sert qu'à situer l'appel (facultative).
        return "accepted", radio
    end
    if not radio then
        return "noRadio"
    end
    local status = Radio.status(radio, Config.getChannel())
    if status == "wrongFrequency" then
        -- Appel sans réponse compté comme un code faux pour la perte de
        -- confiance (CONF-06) : elle ne doit pas distinguer une mauvaise
        -- fréquence d'un mauvais code.
        if Config.codeMode() ~= Codes.MODE_NONE then
            MilitaryDrop.Trust.onFailedCode(tostring(player:getUsername()))
        end
        return "noAnswer"
    end
    if status then
        return status
    end
    if not Server.checkCode(player, args.code) then
        return "noAnswer"
    end
    -- Ligne coupée et délai : révélés seulement après un canal et un code justes.
    local teamId = MilitaryDrop.Teams.idFor(player)
    if MilitaryDrop.Trust.isLineCut(teamId) then
        return "lineCut"
    end
    local wait = Server.hoursUntilNextDrop(Server.getState(), now, MilitaryDrop.Trust.factor(teamId))
    if wait > 0 then
        return "cooldown", math.ceil(wait)
    end
    return "accepted", radio
end

--- Case libre pour la caisse : extérieure, au sol, sans obstacle, hors de
--- l'eau et sans véhicule.
function Server.isFreeSquare(square)
    return square ~= nil and square:isOutside() and square:isFree(false) and not square:isWaterSquare()
        and square:getVehicleContainer() == nil
end

--- Point d'atterrissage (x, y) : addVehicleDebug centre la caisse sur le coin
--- nord-ouest de la case (setX(sq.x)), elle couvre donc les quatre cases
--- x-1..x, y-1..y, qui doivent toutes être libres. Renvoie la case (x, y).
function Server.landingSquareAt(x, y)
    local cell = getCell()
    for dx = -1, 0 do
        for dy = -1, 0 do
            if not Server.isFreeSquare(cell:getGridSquare(x + dx, y + dy, 0)) then
                return nil
            end
        end
    end
    return cell:getGridSquare(x, y, 0)
end

--- Case d'atterrissage tirée au hasard autour d'un point, ou nil.
function Server.findLandingSquare(centerX, centerY)
    for _ = 1, Server.LANDING_ATTEMPTS do
        local angle = ZombRandFloat(0, 2 * math.pi)
        local distance = ZombRandFloat(Server.LANDING_MIN_DISTANCE, Server.LANDING_MAX_DISTANCE)
        local square = Server.landingSquareAt(math.floor(centerX + math.cos(angle) * distance),
            math.floor(centerY + math.sin(angle) * distance))
        if square then
            return square
        end
    end
    return nil
end

--- Case la plus proche de (x, y), dans RELOCATE_RADIUS, qui satisfait accept, ou nil.
local function searchAround(x, y, accept)
    for radius = 0, Server.RELOCATE_RADIUS do
        for dx = -radius, radius do
            for dy = -radius, radius do
                if math.max(math.abs(dx), math.abs(dy)) == radius then
                    local square = accept(x + dx, y + dy)
                    if square then
                        return square
                    end
                end
            end
        end
    end
    return nil
end

--- Case d'atterrissage la plus proche de (x, y), ou nil.
function Server.findLandingNear(x, y)
    return searchAround(x, y, Server.landingSquareAt)
end

--- Case extérieure hors de l'eau la plus proche (repli des caisses au sol), ou nil.
function Server.findOpenGroundNear(x, y)
    local cell = getCell()
    return searchAround(x, y, function(sx, sy)
        local square = cell:getGridSquare(sx, sy, 0)
        if square and square:isOutside() and not square:isWaterSquare() then
            return square
        end
        return nil
    end)
end

--- Point (x, y) sur la carte et hors bâtiment, d'après la métagrille : valable
--- même quand la zone n'est pas chargée (eau et obstacles : vus à la livraison).
function Server.isOnMap(x, y)
    local grid = getWorld():getMetaGrid()
    if not grid:isValidSquare(x, y) then
        return false
    end
    if not grid:getCellData(math.floor(x / Server.CELL_SIZE), math.floor(y / Server.CELL_SIZE)) then
        return false
    end
    return grid:getBuildingAt(x, y) == nil
end

-- Secteurs du leurre : direction centrale (radians, x vers l'est, y vers le
-- sud : le nord est en y décroissant, IsoDirections.N = (0, -1),
-- IsoDirections.java:13). Chaque secteur est un quart de cercle.
Server.SECTOR_ANGLES = { E = 0, S = math.pi / 2, W = math.pi, N = -math.pi / 2 }

--- Point de largage tiré au hasard entre DropMinDistance et DropMaxDistance
--- de (centerX, centerY), ou nil. Si la case est chargée, elle doit déjà être
--- libre ; sinon elle sera revérifiée à la livraison. sector (« N », « E »,
--- « S », « W », facultatif) : quart de cercle centré sur cette direction.
function Server.pickDropPoint(centerX, centerY, sector)
    local low = math.max(0, Config.get("DropMinDistance"))
    local high = math.max(0, Config.get("DropMaxDistance"))
    if high < low then
        low, high = high, low
    end
    local cell = getCell()
    local center = sector and Server.SECTOR_ANGLES[sector]
    for _ = 1, Server.FAR_ATTEMPTS do
        local angle
        if center then
            angle = center + ZombRandFloat(-math.pi / 4, math.pi / 4)
        else
            angle = ZombRandFloat(0, 2 * math.pi)
        end
        local distance = ZombRandFloat(low, high)
        local x = math.floor(centerX + math.cos(angle) * distance)
        local y = math.floor(centerY + math.sin(angle) * distance)
        if Server.isOnMap(x, y) and (not cell:getGridSquare(x, y, 0) or Server.landingSquareAt(x, y)) then
            return x, y
        end
    end
    return nil
end

--- Envoie les coordonnées en privé au demandeur (largage admin, ou chaîne
--- militaire absente : il n'entendrait pas l'annonce).
function Server.notifyDrop(requester, requestId, x, y, forced)
    if not forced and MilitaryDrop.Broadcast.channel then
        return
    end
    local player = requester and Server.findPlayer(requester)
    if player then
        Net.toPlayer(player, "Dropped", { requestId = requestId, x = x, y = y })
    end
end

--- Nombre de zombies de la horde (options Min/MaxZombies, 0 et 0 = aucun).
function Server.hordeSize()
    local low = math.max(0, math.floor(Config.get("MinZombies")))
    local high = math.max(0, math.floor(Config.get("MaxZombies")))
    if high < low then
        low, high = high, low
    end
    if high == 0 then
        return 0
    end
    return ZombRand(low, high + 1)
end

--- Joueur connecté par son nom (serveur MP ou joueurs locaux), ou nil.
function Server.findPlayer(username)
    if isServer() then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player:getUsername() == username then
                return player
            end
        end
        return nil
    end
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and player:getUsername() == username then
            return player
        end
    end
    return nil
end

--- Livraison au point (x, y), déjà annoncé : caisse de largage et horde
--- autour. La zone doit être chargée ; la case est revérifiée (eau, obstacle,
--- véhicule garé) et remplacée au besoin par la plus proche. Renvoie false si
--- aucune case ne convient encore (la livraison reste en attente). dropId :
--- largage (confiance), porté par chaque caisse de ravitaillement.
function Server.deliver(x, y, requester, dropId)
    local square = Server.findLandingNear(x, y)
    local count = 0
    local vehicle = square and MilitaryDrop.Crate.spawn(square, dropId) or nil
    if vehicle then
        count = 1
    else
        -- Repli : la caisse n'a pas pu apparaître (aucune place libre).
        square = square or Server.findOpenGroundNear(x, y)
        if not square then
            MilitaryDrop.log(string.format("no ground near %d,%d yet: delivery waits", x, y))
            return false
        end
        -- Même contenu que le coffre : commande, leurre ou caisses aléatoires.
        -- L'objet est marqué (nom, ModData) avant d'être posé : la pose le
        -- transmet aux clients (transmit = true :
        -- IsoGridSquare.AddWorldInventoryItem(InventoryItem, x, y, h, transmit),
        -- 42.21) ; la variante par nom le transmettrait avant applyEntry.
        for _, entry in ipairs(MilitaryDrop.Crate.contentsFor(dropId)) do
            local item = instanceItem(entry.fullType)
            if item then
                MilitaryDrop.Crate.applyEntry(item, entry, dropId)
                square:AddWorldInventoryItem(item, ZombRandFloat(0.2, 0.8), ZombRandFloat(0.2, 0.8), 0, true)
                count = count + 1
            end
        end
        MilitaryDrop.log("crate could not spawn: supply cases left on the ground", true)
    end
    x, y = square:getX(), square:getY()
    -- Fumée de repérage (Signal Smoke, facultatif).
    MilitaryDrop.Smoke.markCrate(x, y)
    local zombies = Server.hordeSize()
    if zombies > 0 then
        local r = Server.HORDE_RADIUS
        spawnHorde(x - r, y - r, x + r, y + r, 0, zombies)
    end
    local state = Server.getState()
    state.lastDrop = { x = x, y = y, hours = getGameTime():getWorldAgeHours() }
    MilitaryDrop.Trust.onDropDelivered(dropId)
    -- Leurre (v1.5) : la sirène démarre une fois la caisse posée (véhicule nil :
    -- repli au sol).
    local order = MilitaryDrop.Requisition and MilitaryDrop.Requisition.orderOf(dropId)
    if order and order.decoy and MilitaryDrop.Decoy and MilitaryDrop.Decoy.onDelivered then
        MilitaryDrop.Decoy.onDelivered(dropId, x, y, 0, vehicle)
    end
    MilitaryDrop.log(string.format("drop at %d,%d: %d crate/cases, %d zombies, for %s",
        x, y, count, zombies, tostring(requester)), true)
    return true
end

function Server.handleRequest(player, args)
    local name = tostring(player:getUsername())
    local requestId = type(args) == "table" and tonumber(args.requestId) or nil
    if Guard.throttled(player, "Request", Server.REQUEST_INTERVAL_MS) then
        -- Réponse sans texte de la base : le client libère sa demande.
        Net.toPlayer(player, "Result", { requestId = requestId, status = "busy" })
        return
    end

    local now = getGameTime():getWorldAgeHours()
    local status, extra = Server.evaluate(player, args, now)
    if status ~= "accepted" then
        MilitaryDrop.log("request from " .. name .. " refused: " .. status)
        local reply = { requestId = requestId, status = status, hours = extra }
        if status == "lineCut" then
            reply.callsign = MilitaryDrop.Teams.callsign(MilitaryDrop.Teams.idFor(player))
        end
        Net.toPlayer(player, "Result", reply)
        return
    end

    local forced = args.force == true
    -- Formulaire de réquisition (v1.4) : l'hélicoptère attend la commande.
    -- Largage admin : feuille « admin » (MilitaryDrop.Requisition.openForm).
    if MilitaryDrop.Requisition and MilitaryDrop.Requisition.formEnabled() then
        MilitaryDrop.Requisition.openForm(player, requestId, forced)
        return
    end
    Server.launchDrop(player, requestId, forced)
end

--- Point de largage d'un appel : loin du demandeur ; à défaut (carte trop
--- petite, bord de la carte), près de lui. Avec un secteur (leurre),
--- seulement dans ce secteur : refus plutôt qu'une sirène ailleurs ou près
--- du demandeur. Renvoie x, y, ou nil.
function Server.chooseDropPoint(player, sector)
    local px, py = math.floor(player:getX()), math.floor(player:getY())
    local x, y = Server.pickDropPoint(px, py, sector)
    if not x and not sector then
        local square = Server.findLandingSquare(px, py)
        x, y = square and square:getX(), square and square:getY()
    end
    if not x then
        return nil
    end
    return x, y
end

--- Lance le largage d'un appel accepté (ou d'une commande validée) : point,
--- délai global, dropId, réponse « accepted », vol. opts (facultatif) :
--- point ({ x, y } déjà choisi par Server.chooseDropPoint), sector (leurre :
--- point dans ce secteur, sans repli près du demandeur), untracked (hors
--- suivi de confiance), order et decoy (rangés dans l'état privé du largage).
--- Renvoie le dropId, ou nil (réponse « noSite », rien de consommé).
function Server.launchDrop(player, requestId, forced, opts)
    opts = opts or {}
    local name = tostring(player:getUsername())
    local now = getGameTime():getWorldAgeHours()
    local x, y
    if opts.point then
        x, y = opts.point.x, opts.point.y
    else
        x, y = Server.chooseDropPoint(player, opts.sector)
    end
    if not x then
        MilitaryDrop.log("request from " .. name .. ": no landing square", true)
        Net.toPlayer(player, "Result", { requestId = requestId, status = "noSite" })
        return nil
    end
    if not forced then
        Server.getState().lastDropHours = now
    end
    -- Équipe du demandeur au moment de l'appel ; réplique choisie par palier.
    local teamId = MilitaryDrop.Teams.idFor(player)
    local dropId = MilitaryDrop.Trust.registerDrop(teamId, name, forced,
        { untracked = opts.untracked, order = opts.order, decoy = opts.decoy })
    MilitaryDrop.Trust.touch(teamId)
    Net.toPlayer(player, "Result", { requestId = requestId, status = "accepted",
        tier = MilitaryDrop.Trust.tier(teamId), callsign = MilitaryDrop.Teams.callsign(teamId) })
    MilitaryDrop.Flights.launch(x, y, name, requestId, forced, dropId)
    return dropId
end

--- Commandes des clients : nom → function(player, args). Chaque module inscrit
--- les siennes (Server.COMMANDS.X = …) dans son propre fichier.
Server.COMMANDS = {
    Request = function(player, args) Server.handleRequest(player, args) end,
    -- Arrivée d'un client MP : vols en cours, nettoyage ouvert ou non
    -- (MilitaryDrop_Missions.lua, grisé de « Faire le point »).
    Sync = function(player)
        MilitaryDrop.Flights.sendActive(player)
        if MilitaryDrop.Missions and MilitaryDrop.Missions.sync then
            MilitaryDrop.Missions.sync(player)
        end
    end,
}

function Server.onClientCommand(module, command, player, args)
    if module ~= Net.MODULE or not player then
        return
    end
    local handler = type(command) == "string" and Server.COMMANDS[command]
    if handler then
        handler(player, type(args) == "table" and args or {})
    end
end

Events.OnInitGlobalModData.Add(function()
    Secrets.getSeed()
    Server.getCode()
end)
Events.OnClientCommand.Add(Server.onClientCommand)

return Server
