-- ============================================================================
-- Military Drop — hélicoptère vu et entendu par le client
--
-- Chaque client reproduit le vol reçu du serveur (MilitaryDrop_Flight.lua) et
-- l'extrapole entre deux synchronisations. Tout est local, sans paquet :
--   * son : son vanilla « Helicopter » (événement Meta/Helicopter, portée
--     1000), joué en boucle sur un émetteur libre par playSoundLoopedImpl,
--     déplacé à chaque image. L'émetteur est placé SOUND_Z niveaux plus haut :
--     aucune case n'y existe, donc pas d'étouffement par les murs
--     (ParameterOcclusion), comme l'hélicoptère vanilla ;
--   * ombre : marqueur au sol vanilla « circle_shadow » (WorldMarkers), dont
--     l'opacité pulse comme un rotor ;
--   * flèche : flèche de direction vanilla vers l'hélicoptère pour chaque
--     joueur local à moins d'ARROW_RANGE cases, tant qu'il est hors de vue.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Flight"

local Flight = MilitaryDrop.Flight

local Heli = {}
MilitaryDrop.Heli = Heli

Heli.SOUND = "Helicopter"
Heli.SOUND_Z = 20
Heli.MAX_TICK_SECONDS = 0.25
-- Écart toléré avec le serveur avant de recaler le vol (secondes).
Heli.RESYNC_SECONDS = 0.5
Heli.SHADOW_TEXTURE = "circle_shadow"
Heli.SHADOW_SIZE = 3
Heli.SHADOW_FADE_SPEED = 0.08
Heli.SHADOW_ALPHA_MIN = 0.35
Heli.SHADOW_ALPHA_MAX = 0.8
Heli.ARROW_TEXTURE = "dir_arrow_up"
Heli.ARROW_RANGE = 400
Heli.ARROW_HIDE_DISTANCE = 25
Heli.ARROW_COLOR = { r = 0.45, g = 0.85, b = 0.45, a = 0.9 }
-- Sans FlightEnd (paquet perdu), le vol est retiré après sa durée + GRACE.
Heli.GRACE_SECONDS = 10

local active = {}
local ticking = false
local lastTickMs = 0

-- ----------------------------------------------------------------------------
-- Son
-- ----------------------------------------------------------------------------

local function updateSound(entry, x, y)
    if not entry.emitter then
        entry.emitter = getWorld():getFreeEmitter(x, y, Heli.SOUND_Z)
    end
    entry.emitter:setPos(x, y, Heli.SOUND_Z)
    if not entry.sound or entry.sound == 0 or not entry.emitter:isPlaying(entry.sound) then
        entry.sound = entry.emitter:playSoundLoopedImpl(Heli.SOUND)
    end
end

local function stopSound(entry)
    if entry.emitter and entry.sound and entry.sound ~= 0 then
        entry.emitter:stopSoundLocal(entry.sound)
    end
    entry.emitter, entry.sound = nil, nil
end

-- ----------------------------------------------------------------------------
-- Ombre
-- ----------------------------------------------------------------------------

local function updateShadow(entry, x, y)
    local ix, iy = math.floor(x), math.floor(y)
    if entry.shadow then
        entry.shadow:setPos(ix, iy, 0)
        return
    end
    -- Le marqueur se crée sur une case chargée ; ensuite setPos suffit.
    local square = getCell():getGridSquare(ix, iy, 0)
    if square then
        entry.shadow = getWorldMarkers():addGridSquareMarker(Heli.SHADOW_TEXTURE, nil, square, 1, 1, 1, true,
            Heli.SHADOW_SIZE, Heli.SHADOW_FADE_SPEED, Heli.SHADOW_ALPHA_MIN, Heli.SHADOW_ALPHA_MAX)
    end
end

local function removeShadow(entry)
    if entry.shadow then
        getWorldMarkers():removeGridSquareMarker(entry.shadow)
        entry.shadow = nil
    end
end

-- ----------------------------------------------------------------------------
-- Flèches de direction (une par joueur local)
-- ----------------------------------------------------------------------------

local function removeArrow(entry, playerNum)
    local arrow = entry.arrows[playerNum]
    if arrow then
        getWorldMarkers():removeDirectionArrow(arrow)
        entry.arrows[playerNum] = nil
    end
end

local function updateArrows(entry, x, y)
    local ix, iy = math.floor(x), math.floor(y)
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        local wanted = false
        if player and not player:isDead() then
            local dx, dy = x - player:getX(), y - player:getY()
            local distance = math.sqrt(dx * dx + dy * dy)
            wanted = distance <= Heli.ARROW_RANGE and distance > Heli.ARROW_HIDE_DISTANCE
        end
        local arrow = entry.arrows[playerNum]
        if wanted and not arrow then
            local c = Heli.ARROW_COLOR
            entry.arrows[playerNum] = getWorldMarkers():addDirectionArrow(player, ix, iy, 0, Heli.ARROW_TEXTURE,
                c.r, c.g, c.b, c.a)
        elseif wanted then
            arrow:setX(ix)
            arrow:setY(iy)
        elseif arrow then
            removeArrow(entry, playerNum)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Vols
-- ----------------------------------------------------------------------------

local function removeEntry(id)
    local entry = active[id]
    if not entry then
        return
    end
    stopSound(entry)
    removeShadow(entry)
    -- Kahlua : ne pas retirer de clés pendant un pairs.
    local players = {}
    for playerNum in pairs(entry.arrows) do
        players[#players + 1] = playerNum
    end
    for _, playerNum in ipairs(players) do
        removeArrow(entry, playerNum)
    end
    active[id] = nil
end

local function onTick()
    local now = getTimestampMs()
    local dt = math.min((now - lastTickMs) / 1000, Heli.MAX_TICK_SECONDS)
    lastTickMs = now
    local any = false
    local finished = {}
    for id, entry in pairs(active) do
        entry.flight.elapsed = entry.flight.elapsed + dt
        local x, y, phase = Flight.position(entry.flight, entry.flight.elapsed)
        if phase == "done" and entry.flight.elapsed > Flight.totalTime(entry.flight) + Heli.GRACE_SECONDS then
            finished[#finished + 1] = id
        else
            any = true
            if phase == "done" then
                stopSound(entry)
                removeShadow(entry)
            else
                updateSound(entry, x, y)
                updateShadow(entry, x, y)
                updateArrows(entry, x, y)
            end
        end
    end
    -- Kahlua : retraits après le pairs.
    for _, id in ipairs(finished) do
        removeEntry(id)
    end
    if not any then
        Events.OnTick.Remove(onTick)
        ticking = false
    end
end

local function startTicking()
    if not ticking then
        ticking = true
        lastTickMs = getTimestampMs()
        Events.OnTick.Add(onTick)
    end
end

function Heli.onFlightStart(args)
    local flight = Flight.fromArgs(args)
    if not flight then
        return
    end
    local entry = active[flight.id]
    if entry then
        entry.flight.elapsed = flight.elapsed
        return
    end
    active[flight.id] = { flight = flight, arrows = {} }
    startTicking()
end

function Heli.onFlightSync(args)
    local entry = type(args) == "table" and active[args.id]
    if entry and type(args.elapsed) == "number"
        and math.abs(entry.flight.elapsed - args.elapsed) > Heli.RESYNC_SECONDS then
        entry.flight.elapsed = args.elapsed
    end
end

function Heli.onFlightEnd(args)
    if type(args) == "table" then
        removeEntry(args.id)
    end
end

--- Nombre de vols affichés (tests et debug).
function Heli.count()
    local n = 0
    for _ in pairs(active) do
        n = n + 1
    end
    return n
end

return Heli
