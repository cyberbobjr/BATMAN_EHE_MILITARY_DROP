-- ============================================================================
-- Military Drop — sirène du leurre entendue par le client, et « Couper la
-- sirène » (menu contextuel du monde)
--
-- Le serveur n'envoie la position d'une sirène qu'aux joueurs à portée
-- d'écoute (SirenOn), puis SirenOff (MilitaryDrop_Decoy.lua). Le client joue
-- la boucle lui-même, sans paquet : son vanilla « VehicleSirenWall » (sirène
-- de police en boucle, distanceMax 500) sur un émetteur libre, par
-- playSoundLoopedImpl, arrêté par stopSoundLocal. Jamais emitter:playSound
-- sur un émetteur libre : en MP, il serait relayé aux autres joueurs sans
-- arrêt possible (pz-knowledge sounds-and-noise.md).
--
-- Arrêt local : SirenOff, plus aucun joueur local à portée (filet de sécurité
-- si SirenOff se perd), déconnexion. À l'arrivée en jeu (MP), le client
-- redemande les sirènes à portée (SirenSync).
--
-- Écran partagé en MP : le serveur suit les auditeurs par joueur, mais tous
-- les joueurs locaux partagent ce client et la même boucle. Un SirenOff
-- d'éloignement (un joueur sort de la portée) ne coupe pas la boucle tant
-- qu'un autre joueur local vivant est à portée d'écoute (HEAR_RANGE) : il est
-- déjà auditeur du serveur (sondage d'une seconde) ou le devient par le
-- SirenSync renvoyé en son nom, et recevra le SirenOff final (sirène tue)
-- ou le sien en s'éloignant. Le SirenOff final coupe toujours. Filet : une
-- boucle sans joueur local à LOCAL_STOP_RANGE s'arrête seule (Siren.check).
--
-- Menu : la caisse leurre n'est reconnue que par une sirène reçue à cette
-- position (jamais par un nom ni par un objet) : un joueur loin de toute
-- sirène ne voit rien. Marche jusqu'au coffre (ou à côté de la case), puis
-- l'action MilitaryDrop.SirenAction ; le serveur revérifie tout.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Client"
require "MilitaryDrop/MilitaryDrop_Dismantle"
require "MilitaryDrop/MilitaryDrop_SirenAction"

local Net = MilitaryDrop.Net
local Rules = MilitaryDrop.SirenRules

local Siren = {}
MilitaryDrop.Siren = Siren

Siren.SOUND = "VehicleSirenWall"
-- Vérification du son et de la portée, en ms réelles.
Siren.CHECK_MS = 1000
-- Arrêt local au-delà de cette distance (le serveur envoie SirenOff avant,
-- à HEAR_RANGE + HEAR_MARGIN).
Siren.LOCAL_STOP_RANGE = Rules.HEAR_RANGE + 2 * Rules.HEAR_MARGIN
-- Rayon (cases) autour d'une sirène où le menu propose de la couper.
Siren.MENU_RADIUS = 3

-- id → { id, x, y, z, emitter, sound }
local active = {}
local ticking = false
local lastCheckMs = nil

-- ----------------------------------------------------------------------------
-- Son
-- ----------------------------------------------------------------------------

local function ensureSound(entry)
    if entry.emitter and entry.sound and entry.sound ~= 0 and entry.emitter:isPlaying(entry.sound) then
        return
    end
    -- Un émetteur libre qui ne joue plus est rendu à la réserve : en prendre un neuf.
    entry.emitter = getWorld():getFreeEmitter(entry.x, entry.y, entry.z)
    entry.emitter:setPos(entry.x, entry.y, entry.z)
    entry.sound = entry.emitter:playSoundLoopedImpl(Siren.SOUND)
end

local function stopSound(entry)
    if entry.emitter and entry.sound and entry.sound ~= 0 then
        entry.emitter:stopSoundLocal(entry.sound)
    end
    entry.emitter, entry.sound = nil, nil
end

-- ----------------------------------------------------------------------------
-- Sirènes reçues
-- ----------------------------------------------------------------------------

--- Sirène reçue par son numéro, ou nil.
function Siren.get(id)
    return active[tonumber(id) or -1]
end

--- Nombre de sirènes jouées (tests et debug).
function Siren.count()
    local n = 0
    for _ in pairs(active) do
        n = n + 1
    end
    return n
end

local function remove(id)
    local entry = active[id]
    if entry then
        stopSound(entry)
        active[id] = nil
    end
end

--- Plus petite distance d'un joueur local vivant à la sirène, ou nil ; et ce joueur.
local function nearestLocal(entry)
    local best, bestPlayer = nil, nil
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            local dx, dy = player:getX() - entry.x, player:getY() - entry.y
            local d = math.sqrt(dx * dx + dy * dy)
            if not best or d < best then
                best, bestPlayer = d, player
            end
        end
    end
    return best, bestPlayer
end

local function onTick()
    local now = getTimestampMs()
    if lastCheckMs and now >= lastCheckMs and now - lastCheckMs < Siren.CHECK_MS then
        return
    end
    lastCheckMs = now
    Siren.check()
end

local function startTicking()
    if not ticking then
        ticking = true
        lastCheckMs = nil
        Events.OnTick.Add(onTick)
    end
end

local function stopTicking()
    if ticking then
        ticking = false
        Events.OnTick.Remove(onTick)
    end
end

--- Relance les boucles arrêtées, oublie les sirènes hors de portée.
function Siren.check()
    local far = {}
    for id, entry in pairs(active) do
        local d = nearestLocal(entry)
        if d and d > Siren.LOCAL_STOP_RANGE then
            far[#far + 1] = id
        else
            ensureSound(entry)
        end
    end
    -- Kahlua : retraits après le pairs.
    for _, id in ipairs(far) do
        remove(id)
    end
    if Siren.count() == 0 then
        stopTicking()
    end
end

function Siren.onSirenOn(args)
    local id = tonumber(args.id)
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z) or 0
    if not id or not x or not y then
        return
    end
    local entry = active[id]
    if entry then
        if entry.x ~= x or entry.y ~= y or entry.z ~= z then
            stopSound(entry)
            entry.x, entry.y, entry.z = x, y, z
        end
    else
        entry = { id = id, x = x, y = y, z = z }
        active[id] = entry
    end
    ensureSound(entry)
    startTicking()
end

function Siren.onSirenOff(args)
    local id = tonumber(args.id)
    local entry = id and active[id]
    if entry and args.final ~= true then
        -- Éloignement d'un joueur : un autre joueur local encore à portée
        -- garde la boucle (écran partagé).
        local d, player = nearestLocal(entry)
        if d and d <= Rules.HEAR_RANGE then
            if isClient() then
                -- Il devient auditeur du serveur s'il ne l'était pas encore.
                Net.toServer(player, "SirenSync", {})
            end
            return
        end
    end
    if id then
        remove(id)
    end
    if Siren.count() == 0 then
        stopTicking()
    end
end

--- Déconnexion : toutes les boucles s'arrêtent.
function Siren.stopAll()
    local ids = {}
    for id in pairs(active) do
        ids[#ids + 1] = id
    end
    for _, id in ipairs(ids) do
        remove(id)
    end
    stopTicking()
end

--- MP : à l'arrivée en jeu, redemande les sirènes à portée (reconnexion).
function Siren.onGameStart()
    local player = getSpecificPlayer(0)
    if isClient() and player then
        Net.toServer(player, "SirenSync", {})
    end
end

-- ----------------------------------------------------------------------------
-- Menu « Couper la sirène »
-- ----------------------------------------------------------------------------

--- Sirène reçue la plus proche de (x, y), au même étage, à MENU_RADIUS cases au plus.
function Siren.findNear(x, y, z)
    local best, bestDistance = nil, nil
    for _, entry in pairs(active) do
        if math.floor(entry.z) == math.floor(z) then
            local dx, dy = entry.x - x, entry.y - y
            local d = dx * dx + dy * dy
            if d <= Siren.MENU_RADIUS * Siren.MENU_RADIUS and (not bestDistance or d < bestDistance) then
                best, bestDistance = entry, d
            end
        end
    end
    return best
end

--- Caisse de largage près de la sirène (pour marcher jusqu'à son coffre), ou nil.
local function crateNear(entry)
    local cell = getCell()
    local cx, cy = math.floor(entry.x), math.floor(entry.y)
    for dx = -1, 1 do
        for dy = -1, 1 do
            local square = cell:getGridSquare(cx + dx, cy + dy, entry.z)
            local vehicle = square and square:getVehicleContainer()
            if MilitaryDrop.Dismantle.isCrate(vehicle) then
                return vehicle
            end
        end
    end
    return nil
end

--- Marche jusqu'à la caisse (zone du coffre) ou à côté de la case, puis l'action.
function Siren.onStop(player, id)
    local entry = Siren.get(id)
    if not entry then
        return
    end
    local vehicle = crateNear(entry)
    local area = nil
    if vehicle then
        for i = 0, vehicle:getPartCount() - 1 do
            local part = vehicle:getPartByIndex(i)
            if not area and part and part:getItemContainer() then
                area = part:getArea()
            end
        end
    end
    if vehicle and area then
        ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(player, vehicle, area))
    elseif vehicle then
        ISTimedActionQueue.add(ISPathFindAction:pathToVehicleAdjacent(player, vehicle))
    else
        local square = getCell():getGridSquare(math.floor(entry.x), math.floor(entry.y), entry.z)
        if square and not luautils.walkAdj(player, square, true) then
            return
        end
    end
    ISTimedActionQueue.add(MilitaryDrop.SirenAction.new(nil, player, entry.id))
end

--- Points visés : caisse sous la souris, cases cliquées, case du personnage
--- (manette). Renvoie la sirène reçue la plus proche de l'un d'eux, ou nil.
function Siren.findTarget(playerNum, player, worldObjects)
    local points = {}
    if JoypadState and JoypadState.players[playerNum + 1] then
        points[#points + 1] = { player:getX(), player:getY(), player:getZ() }
    elseif IsoObjectPicker and IsoObjectPicker.Instance then
        local vehicle = IsoObjectPicker.Instance:PickVehicle(getMouseXScaled(), getMouseYScaled())
        if vehicle then
            points[#points + 1] = { vehicle:getX(), vehicle:getY(), vehicle:getZ() }
        end
    end
    for _, object in ipairs(worldObjects or {}) do
        local square = object and object:getSquare()
        if square then
            points[#points + 1] = { square:getX() + 0.5, square:getY() + 0.5, square:getZ() }
        end
    end
    for _, point in ipairs(points) do
        local entry = Siren.findNear(point[1], point[2], point[3])
        if entry then
            return entry
        end
    end
    return nil
end

function Siren.onFillWorldContextMenu(playerNum, context, worldObjects, test)
    if test or Siren.count() == 0 then
        return
    end
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then
        return
    end
    local entry = Siren.findTarget(playerNum, player, worldObjects)
    if not entry then
        return
    end
    local option = context:addOption(getText("IGUI_MilitaryDrop_SirenStop"), player, Siren.onStop, entry.id)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip:setName(getText("IGUI_MilitaryDrop_SirenStop"))
    tooltip.description = getText("IGUI_MilitaryDrop_SirenStopTooltip")
    option.toolTip = tooltip
end

MilitaryDrop.Client.HANDLERS.SirenOn = Siren.onSirenOn
MilitaryDrop.Client.HANDLERS.SirenOff = Siren.onSirenOff

Events.OnGameStart.Add(Siren.onGameStart)
Events.OnDisconnect.Add(Siren.stopAll)
Events.OnFillWorldObjectContextMenu.Add(Siren.onFillWorldContextMenu)

return Siren
