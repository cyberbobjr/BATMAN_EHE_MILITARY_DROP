-- ============================================================================
-- Military Drop — sons de la baie de lecture du poste de liaison (SRC-10)
--
-- Le serveur prévient les joueurs à portée du poste (BaySound,
-- MilitaryDrop_Post.lua) : event « insert » (déclic du lecteur) ou « done »
-- (double déclic de fin), reading vrai (boucle de la porteuse, rappelée chaque
-- minute de jeu) ou faux (arrêt : pause, retrait, fin). Le client joue tout
-- lui-même depuis la case du poste, sur un émetteur libre, sans aucun paquet :
-- playSoundImpl(nom, false, nil) pour un son bref, playSoundLoopedImpl pour la
-- boucle, arrêt par stopSoundLocal. Jamais playSoundImpl(nom, nil) (Kahlua
-- choisit la surcharge IsoGridSquare : NPE) ni playSound (relayé en MP, sans
-- arrêt chez les autres joueurs).
--
-- Arrêt local de la boucle : reading faux, plus aucun rappel depuis trois
-- minutes de jeu (message perdu, poste disparu), ou plus aucun joueur local à
-- portée. Sons « fichier » : le curseur « Effets sonores » ne s'applique pas
-- tout seul, d'où setVolume à chaque lancement et à chaque vérification.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Client"

local BaySound = {}
MilitaryDrop.BaySound = BaySound

BaySound.SOUNDS = { insert = "MilitaryDropBayInsert", done = "MilitaryDropBayDone" }
BaySound.LOOP = "MilitaryDropBayRead"
-- Arrêt local au-delà de cette distance (le serveur prévient jusqu'à 12 cases).
BaySound.LOCAL_STOP_RANGE = 16
-- Vérification de la boucle, en ms réelles.
BaySound.CHECK_MS = 1000
-- Boucle arrêtée sans rappel pendant ce nombre de minutes de jeu (au moins 15 s réelles).
BaySound.TIMEOUT_GAME_MINUTES = 3
BaySound.MIN_TIMEOUT_MS = 15000

-- "x,y,z" → { x, y, z, emitter, sound, lastMs }
local loops = {}
local ticking = false
local lastCheckMs = nil

local function key(x, y, z)
    return x .. "," .. y .. "," .. z
end

--- Volume des effets sonores du joueur (0 à 1).
function BaySound.volume()
    return math.max(0, math.min(1, (tonumber(getCore():getOptionSoundVolume()) or 10) / 10))
end

--- Délai sans rappel avant d'arrêter une boucle (ms réelles) : trois minutes de jeu.
function BaySound.timeoutMs()
    local perDay = tonumber(getGameTime():getMinutesPerDay()) or 0
    local minuteMs = perDay * 60 * 1000 / 1440
    return math.max(BaySound.MIN_TIMEOUT_MS, BaySound.TIMEOUT_GAME_MINUTES * minuteMs)
end

local function nearestLocal(entry)
    local best
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() and math.floor(player:getZ()) == entry.z then
            local dx, dy = player:getX() - (entry.x + 0.5), player:getY() - (entry.y + 0.5)
            local d = math.sqrt(dx * dx + dy * dy)
            if not best or d < best then
                best = d
            end
        end
    end
    return best
end

--- Son bref joué depuis la case du poste.
function BaySound.playOnce(name, x, y, z)
    local emitter = getWorld():getFreeEmitter(x + 0.5, y + 0.5, z)
    local id = emitter:playSoundImpl(name, false, nil)
    if id and id ~= 0 then
        emitter:setVolume(id, BaySound.volume())
    end
    return id
end

local function ensureLoop(entry)
    if entry.emitter and entry.sound and entry.sound ~= 0 and entry.emitter:isPlaying(entry.sound) then
        entry.emitter:setVolume(entry.sound, BaySound.volume())
        return
    end
    -- Un émetteur libre qui ne joue plus est rendu à la réserve : en prendre un neuf.
    entry.emitter = getWorld():getFreeEmitter(entry.x + 0.5, entry.y + 0.5, entry.z)
    entry.sound = entry.emitter:playSoundLoopedImpl(BaySound.LOOP)
    if entry.sound and entry.sound ~= 0 then
        entry.emitter:setVolume(entry.sound, BaySound.volume())
    end
end

local function stop(k)
    local entry = loops[k]
    if entry then
        if entry.emitter and entry.sound and entry.sound ~= 0 then
            entry.emitter:stopSoundLocal(entry.sound)
        end
        loops[k] = nil
    end
end

local function onTick()
    local now = getTimestampMs()
    if lastCheckMs and now - lastCheckMs < BaySound.CHECK_MS and now >= lastCheckMs then
        return
    end
    lastCheckMs = now
    local timeout = BaySound.timeoutMs()
    local ended = {}
    for k, entry in pairs(loops) do
        local distance = nearestLocal(entry)
        if now - entry.lastMs > timeout or now < entry.lastMs or not distance
            or distance > BaySound.LOCAL_STOP_RANGE then
            ended[#ended + 1] = k
        else
            ensureLoop(entry)
        end
    end
    -- Kahlua : retirer après le parcours.
    for _, k in ipairs(ended) do
        stop(k)
    end
    if BaySound.count() == 0 then
        Events.OnTick.Remove(onTick)
        ticking = false
    end
end

--- Nombre de boucles jouées (tests et debug).
function BaySound.count()
    local n = 0
    for _ in pairs(loops) do
        n = n + 1
    end
    return n
end

--- BaySound reçu du serveur.
function BaySound.onCommand(args)
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not x or not y or not z then
        return
    end
    local name = BaySound.SOUNDS[args.event]
    if name then
        BaySound.playOnce(name, x, y, z)
    end
    local k = key(x, y, z)
    if args.reading == true then
        local entry = loops[k]
        if not entry then
            entry = { x = x, y = y, z = z }
            loops[k] = entry
        end
        entry.lastMs = getTimestampMs()
        ensureLoop(entry)
        if not ticking then
            ticking = true
            lastCheckMs = getTimestampMs()
            Events.OnTick.Add(onTick)
        end
    elseif args.reading == false then
        stop(k)
    end
    -- Console ouverte sur ce poste : fin ou coupure affichée sans attendre.
    local PostWindow = MilitaryDrop.PostWindow
    if PostWindow and PostWindow.onBaySound then
        PostWindow.onBaySound({ x = x, y = y, z = z, event = args.event, reading = args.reading })
    end
end

--- Arrête toutes les boucles (déconnexion, tests).
function BaySound.stopAll()
    local keys = {}
    for k in pairs(loops) do
        keys[#keys + 1] = k
    end
    for _, k in ipairs(keys) do
        stop(k)
    end
end

MilitaryDrop.Client.HANDLERS.BaySound = BaySound.onCommand
BaySound.onTick = onTick
Events.OnDisconnect.Add(BaySound.stopAll)

return BaySound
