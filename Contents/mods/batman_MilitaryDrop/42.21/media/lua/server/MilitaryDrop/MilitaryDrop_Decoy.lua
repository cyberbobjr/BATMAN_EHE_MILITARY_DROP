-- ============================================================================
-- Military Drop — leurre à sirène (v1.5, serveur MP ou solo)
--
-- Un largage leurre (commandé par le formulaire de réquisition,
-- MilitaryDrop_Requisition.lua) est identique à un vrai : même hélicoptère,
-- même annonce, même caisse. Son coffre ne contient qu'une balise de
-- diversion (Decoy.trunkContents). Une fois la caisse posée
-- (Decoy.onDelivered, appelé par Server.deliver), une sirène hurle :
--   * bruit serveur répété (WorldSoundManager.addSoundRepeating, comme la
--     sirène d'un véhicule vanilla : BaseVehicle.updateWorldSounds, toutes
--     les 1000 ms, rayon 100, volume 60), rayon DecoyNoiseRadius, seulement
--     si la case est chargée : un bruit hors de la zone chargée n'atteint ni
--     les zombies réels ni les virtuels (limite du moteur) ;
--   * son : chaque client joue lui-même une boucle locale
--     (MilitaryDrop_Siren.lua). La position n'est envoyée (SirenOn) qu'aux
--     joueurs à portée d'écoute (SirenRules.HEAR_RANGE), puis SirenOff quand
--     ils s'éloignent, ou SirenOff { final = true } quand la sirène se tait
--     (le client distingue les deux : écran partagé, MilitaryDrop_Siren.lua).
--     Aucun message à tous.
-- Elle se tait : à l'échéance (DecoySirenHours heures de jeu, piles
-- épuisées), coupée par un joueur (MilitaryDrop.SirenAction, revérifiée ici),
-- caisse démontée (Decoy.onCrateRemoved, MilitaryDrop_Dismantle.lua), ou
-- caisse disparue (détruite, retirée), constaté quand sa zone est chargée.
--
-- État privé (MilitaryDrop.Secrets.privateState, jamais transmis) :
--   sirens[dropId] = { id, x, y, z, crate, startedHours, endsHours }
--   nextSirenId = compteur (numéro envoyé aux clients à portée, sans dropId)
-- Mémoire du serveur seulement : auditeurs de chaque sirène (rejoués après un
-- redémarrage ou une reconnexion), absence de la caisse.
--
-- Langue : le nom de la balise est écrit par le serveur (setName, transmis
-- tel quel), donc dans sa langue en MP dédié (repli anglais hors EN et FR),
-- comme les documents militaires. Le mot « DIVERSION » est le même en
-- anglais et en français ; la description (Tooltip) est traduite par chaque
-- client.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Secrets"
require "MilitaryDrop/MilitaryDrop_Guard"
require "MilitaryDrop/MilitaryDrop_Dismantle"
require "MilitaryDrop/MilitaryDrop_SirenAction"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Rules = MilitaryDrop.SirenRules

local Decoy = {}
MilitaryDrop.Decoy = Decoy

Config.addDefaults({
    DecoyEnabled = true,
    DecoyCost = 3,
    DecoySirenHours = 6,
    DecoyNoiseRadius = 120,
})

Decoy.BEACON = "MilitaryDrop.DecoyBeacon"
-- Cadence du sondage serveur (bruit, échéance, caisse, auditeurs), en ms réelles.
Decoy.POLL_MS = 1000
-- Volume du bruit : celui de la sirène d'un véhicule vanilla.
Decoy.NOISE_VOLUME = 60
-- Les zombies virtuels n'entendent qu'un bruit de rayon ≥ 50
-- (ZombiePopulationManager.addWorldSound).
Decoy.MIN_NOISE_RADIUS = 50
-- Recherche de la caisse autour de la sirène (cases), et durée d'absence
-- constatée, zone chargée, avant d'arrêter la sirène : le véhicule peut
-- arriver un peu après les cases au chargement d'un chunk.
Decoy.CRATE_SEARCH_RADIUS = 2
Decoy.MISSING_GRACE_MS = 20000
-- Caisse démontée : sirène à moins de MATCH_RADIUS cases de son centre.
Decoy.MATCH_RADIUS = 3
-- Cadence de la resynchronisation demandée par un client (SirenSync).
Decoy.SYNC_INTERVAL_MS = 3000

-- dropId → { listeners = { [clé] = true }, missingSince = ms } (mémoire).
local runtime = {}
local ticking = false
local lastPollMs = nil

local function state()
    local s = MilitaryDrop.Secrets.privateState()
    s.sirens = s.sirens or {}
    return s
end

local function hoursNow()
    return getGameTime():getWorldAgeHours()
end

local function runtimeOf(dropId)
    local r = runtime[dropId]
    if not r then
        r = { listeners = {} }
        runtime[dropId] = r
    end
    return r
end

-- ----------------------------------------------------------------------------
-- Contrat avec la réquisition (MilitaryDrop_Requisition.lua, Crate, Server)
-- ----------------------------------------------------------------------------

--- Coffre d'un largage leurre : une seule balise, marquée « DIVERSION ».
function Decoy.trunkContents(dropId)
    return { { fullType = Decoy.BEACON, name = getText("IGUI_MilitaryDrop_DecoyBeaconName") } }
end

--- Sirènes actives : dropId → entrée (état privé ; tests et debug).
function Decoy.sirens()
    return state().sirens
end

--- Rayon du bruit (option DecoyNoiseRadius, au moins MIN_NOISE_RADIUS).
function Decoy.noiseRadius()
    local radius = math.floor(tonumber(Config.get("DecoyNoiseRadius")) or 120)
    return math.max(Decoy.MIN_NOISE_RADIUS, radius)
end

-- ----------------------------------------------------------------------------
-- Joueurs et auditeurs
-- ----------------------------------------------------------------------------

--- Joueurs connectés (serveur MP) ou locaux (solo).
function Decoy.players()
    local list = {}
    if isServer() then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            list[#list + 1] = players:get(i)
        end
        return list
    end
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            list[#list + 1] = player
        end
    end
    return list
end

--- Clé d'auditeur : le nom du joueur en MP ; en solo, tous les joueurs locaux
--- partagent le même client (une seule boucle).
local function listenerKey(player)
    if isServer() then
        return tostring(player:getUsername())
    end
    return "local"
end

local function distance(player, entry)
    local dx = player:getX() - entry.x
    local dy = player:getY() - entry.y
    return math.sqrt(dx * dx + dy * dy)
end

--- Envoie SirenOn aux joueurs qui entrent dans la portée d'écoute, SirenOff à
--- ceux qui en sortent. Liste vide (redémarrage, reconnexion) : rien décidé.
--- partial : players n'est pas la liste complète des joueurs connectés
--- (SirenSync d'un seul joueur) ; les auditeurs absents de la liste restent.
function Decoy.updateListeners(dropId, entry, players, partial)
    if #players == 0 then
        return
    end
    local listeners = runtimeOf(dropId).listeners
    -- Plus proche joueur par clé (solo : tous les joueurs locaux).
    local nearest = {}
    for _, player in ipairs(players) do
        local key = listenerKey(player)
        local d = distance(player, entry)
        if not nearest[key] or d < nearest[key].distance then
            nearest[key] = { player = player, distance = d }
        end
    end
    -- Joueur parti (liste complète seulement) : oublié, il recevra SirenOn à
    -- son retour.
    if not partial then
        local gone = {}
        for key in pairs(listeners) do
            if not nearest[key] then
                gone[#gone + 1] = key
            end
        end
        for _, key in ipairs(gone) do
            listeners[key] = nil
        end
    end
    for key, found in pairs(nearest) do
        if not listeners[key] and found.distance <= Rules.HEAR_RANGE then
            listeners[key] = true
            Net.toPlayer(found.player, "SirenOn", { id = entry.id, x = entry.x, y = entry.y, z = entry.z })
        elseif listeners[key] and found.distance > Rules.HEAR_RANGE + Rules.HEAR_MARGIN then
            listeners[key] = nil
            Net.toPlayer(found.player, "SirenOff", { id = entry.id })
        end
    end
end

--- Sirène qui se tait : SirenOff final aux auditeurs encore connectés (le
--- client coupe la boucle même si un autre joueur local est à portée).
local function silenceListeners(dropId, entry)
    local r = runtime[dropId]
    if not r then
        return
    end
    for _, player in ipairs(Decoy.players()) do
        if r.listeners[listenerKey(player)] then
            r.listeners[listenerKey(player)] = nil
            Net.toPlayer(player, "SirenOff", { id = entry.id, final = true })
        end
    end
end

-- ----------------------------------------------------------------------------
-- Bruit et caisse
-- ----------------------------------------------------------------------------

local function squareOf(entry)
    return getCell():getGridSquare(math.floor(entry.x), math.floor(entry.y), entry.z)
end

--- Bruit qui attire les zombies, seulement si la case est chargée. Renvoie
--- true si le bruit a été émis.
function Decoy.emitNoise(entry)
    if not squareOf(entry) then
        return false
    end
    getWorldSoundManager():addSoundRepeating(nil, math.floor(entry.x), math.floor(entry.y), entry.z,
        Decoy.noiseRadius(), Decoy.NOISE_VOLUME, false, true)
    return true
end

--- Caisse présente (true), absente (false), ou zone pas entièrement chargée (nil).
function Decoy.crateState(entry)
    local cell = getCell()
    local cx, cy = math.floor(entry.x), math.floor(entry.y)
    local r = Decoy.CRATE_SEARCH_RADIUS
    local complete = true
    for dx = -r, r do
        for dy = -r, r do
            local square = cell:getGridSquare(cx + dx, cy + dy, entry.z)
            if not square then
                complete = false
            else
                local vehicle = square:getVehicleContainer()
                if MilitaryDrop.Dismantle.isCrate(vehicle) then
                    return true
                end
            end
        end
    end
    if complete then
        return false
    end
    return nil
end

--- Vrai quand la caisse manque depuis MISSING_GRACE_MS, zone chargée.
function Decoy.crateGone(dropId, entry, nowMs)
    if not entry.crate then
        -- Repli au sol (aucune caisse) : seule l'échéance ou un joueur l'arrêtent.
        return false
    end
    local r = runtimeOf(dropId)
    local present = Decoy.crateState(entry)
    if present ~= false then
        r.missingSince = nil
        return false
    end
    r.missingSince = r.missingSince or nowMs
    return nowMs - r.missingSince >= Decoy.MISSING_GRACE_MS
end

-- ----------------------------------------------------------------------------
-- Cycle de vie
-- ----------------------------------------------------------------------------

local function onTick()
    local now = getTimestampMs()
    if lastPollMs and now >= lastPollMs and now - lastPollMs < Decoy.POLL_MS then
        return
    end
    lastPollMs = now
    Decoy.poll(now)
end

local function startTicking()
    if not ticking then
        ticking = true
        lastPollMs = nil
        Events.OnTick.Add(onTick)
    end
end

local function stopTicking()
    if ticking then
        ticking = false
        Events.OnTick.Remove(onTick)
    end
end

--- Arrête la sirène du largage : SirenOff aux auditeurs, entrée retirée.
function Decoy.stop(dropId, reason)
    local sirens = state().sirens
    local entry = sirens[dropId]
    if not entry then
        return false
    end
    silenceListeners(dropId, entry)
    sirens[dropId] = nil
    runtime[dropId] = nil
    -- Leurre trouvé (sirène coupée, caisse démontée ou disparue) : la base ne
    -- répète plus sa grille, comme pour une caisse ouverte. À l'échéance des
    -- piles, personne ne l'a trouvé : les rappels continuent.
    if reason ~= "expired" and MilitaryDrop.Trust and MilitaryDrop.Trust.markFound then
        MilitaryDrop.Trust.markFound(dropId)
    end
    MilitaryDrop.log(string.format("decoy siren %s stopped (%s)", tostring(dropId), tostring(reason)), true)
    return true
end

--- Caisse posée (ou caisses au sol, vehicle = nil) d'un largage leurre : la
--- sirène démarre. Renvoie son numéro, ou nil (option à 0 heure, pas de largage).
function Decoy.onDelivered(dropId, x, y, z, vehicle)
    if dropId == nil or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    local s = state()
    if s.sirens[dropId] then
        return s.sirens[dropId].id
    end
    local hours = tonumber(Config.get("DecoySirenHours")) or 0
    if hours <= 0 then
        return nil
    end
    s.nextSirenId = (tonumber(s.nextSirenId) or 0) + 1
    local entry = {
        id = s.nextSirenId,
        x = x + 0.5, y = y + 0.5, z = math.floor(tonumber(z) or 0),
        crate = vehicle ~= nil,
        startedHours = hoursNow(),
    }
    if vehicle then
        -- Centre de la caisse : addVehicleDebug la centre sur le coin de la case.
        entry.x, entry.y = vehicle:getX(), vehicle:getY()
    end
    entry.endsHours = entry.startedHours + hours
    s.sirens[dropId] = entry
    runtime[dropId] = nil
    startTicking()
    MilitaryDrop.log(string.format("decoy siren %s started at %d,%d for %s h",
        tostring(dropId), math.floor(entry.x), math.floor(entry.y), tostring(hours)), true)
    return entry.id
end

--- Un tour de sondage : échéance, caisse disparue, bruit, auditeurs.
function Decoy.poll(nowMs)
    local sirens = state().sirens
    local hours = hoursNow()
    local players = Decoy.players()
    -- Kahlua : relever les clés avant d'en retirer.
    local ids = {}
    for dropId in pairs(sirens) do
        ids[#ids + 1] = dropId
    end
    for _, dropId in ipairs(ids) do
        local entry = sirens[dropId]
        if hours >= (tonumber(entry.endsHours) or 0) then
            Decoy.stop(dropId, "expired")
        elseif Decoy.crateGone(dropId, entry, nowMs or getTimestampMs()) then
            Decoy.stop(dropId, "crate gone")
        else
            Decoy.emitNoise(entry)
            Decoy.updateListeners(dropId, entry, players)
        end
    end
    if not Decoy.hasSirens() then
        stopTicking()
    end
end

function Decoy.hasSirens()
    local count = 0
    for _ in pairs(state().sirens) do
        count = count + 1
    end
    return count > 0
end

--- Sirène par son numéro : dropId, entrée ; ou nil.
function Decoy.findById(sirenId)
    local id = tonumber(sirenId)
    if not id then
        return nil
    end
    for dropId, entry in pairs(state().sirens) do
        if entry.id == id then
            return dropId, entry
        end
    end
    return nil
end

--- Action « Couper la sirène » (complete, serveur ou solo) : revérifie la
--- sirène active et la distance du joueur à sa position. Renvoie true si coupée.
function Decoy.stopByPlayer(player, sirenId)
    local dropId, entry = Decoy.findById(sirenId)
    if not player or not dropId or player:isDead() or not Rules.isNear(player, entry.x, entry.y, entry.z) then
        MilitaryDrop.log("siren stop refused for " .. tostring(player and player:getUsername()))
        if player then
            player:transmitHaloNote(getText("IGUI_MilitaryDrop_SirenCannotStop"), 255, 255, 255, 300)
        end
        return false
    end
    Decoy.stop(dropId, "switched off by " .. tostring(player:getUsername()))
    player:transmitHaloNote(getText("IGUI_MilitaryDrop_SirenStopped"), 255, 255, 255, 300)
    return true
end

--- Caisse démontée (MilitaryDrop_Dismantle.lua) : la sirène de cette caisse se tait.
function Decoy.onCrateRemoved(vehicle)
    if not vehicle then
        return false
    end
    local vx, vy, vz = vehicle:getX(), vehicle:getY(), math.floor(vehicle:getZ())
    local matches = {}
    for dropId, entry in pairs(state().sirens) do
        local dx, dy = entry.x - vx, entry.y - vy
        if entry.crate and entry.z == vz and dx * dx + dy * dy <= Decoy.MATCH_RADIUS * Decoy.MATCH_RADIUS then
            matches[#matches + 1] = dropId
        end
    end
    for _, dropId in ipairs(matches) do
        Decoy.stop(dropId, "crate dismantled")
    end
    return #matches > 0
end

--- Client qui (re)vient (MP) : il reçoit à nouveau les sirènes à portée.
--- Seule la clé de ce joueur est revue ; les autres auditeurs restent.
function Decoy.onSirenSync(player)
    if MilitaryDrop.Guard.throttled(player, "SirenSync", Decoy.SYNC_INTERVAL_MS) then
        return
    end
    local key = listenerKey(player)
    for dropId, entry in pairs(state().sirens) do
        local r = runtimeOf(dropId)
        r.listeners[key] = nil
        Decoy.updateListeners(dropId, entry, { player }, true)
    end
end

function Decoy.onClientCommand(module, command, player, args)
    if module == Net.MODULE and command == "SirenSync" and player then
        Decoy.onSirenSync(player)
    end
end

--- Au chargement : les sirènes encore actives reprennent (auditeurs oubliés).
function Decoy.restore()
    runtime = {}
    if Decoy.hasSirens() then
        startTicking()
    end
end

Events.OnInitGlobalModData.Add(Decoy.restore)
Events.OnClientCommand.Add(Decoy.onClientCommand)

return Decoy
