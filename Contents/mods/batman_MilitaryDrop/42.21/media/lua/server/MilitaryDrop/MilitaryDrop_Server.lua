-- ============================================================================
-- Military Drop — autorité serveur (serveur MP ou solo)
--
-- Le client envoie seulement une demande (commande « Request » : référence de
-- la radio, code saisi, demande admin). Le serveur revérifie tout, dans cet
-- ordre : droits admin, radio à portée, radio militaire allumée, puis canal et
-- code ensemble, puis délai global. Mauvais canal et mauvais code donnent la
-- même réponse (« noAnswer ») : on ne peut trouver la fréquence en appelant
-- chaque canal. Le délai n'est révélé qu'après un canal et un code justes.
--
-- État persistant : ModData globale « MilitaryDrop » (heure du dernier
-- largage, vols, livraisons en attente). Tout client connecté peut lire une
-- ModData globale (ModData.request, GlobalModData.receiveRequest, 42.21) : le
-- code de la partie n'y est donc pas. Il est gardé dans un fichier du serveur
-- (Zomboid/Lua/MilitaryDrop/<mode>_<partie>_code.txt).
--
-- Une demande acceptée lance un hélicoptère (MilitaryDrop_Flights.lua) vers
-- une case extérieure à 15-30 cases de la radio. À son passage, deliver pose
-- la caisse de largage (MilitaryDrop_Crate.lua ; à défaut, les caisses de
-- ravitaillement au sol) et la horde.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Codes"
require "MilitaryDrop/MilitaryDrop_Loot"
require "MilitaryDrop/MilitaryDrop_Flight"
require "MilitaryDrop/MilitaryDrop_Crate"
require "MilitaryDrop/MilitaryDrop_Broadcast"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Radio = MilitaryDrop.Radio
local Codes = MilitaryDrop.Codes

local Server = {}
MilitaryDrop.Server = Server

Server.MODDATA_TAG = "MilitaryDrop"
-- Une demande par joueur toutes les 3 s réelles au plus (anti-rafale).
Server.REQUEST_INTERVAL_MS = 3000
Server.LANDING_MIN_DISTANCE = 15
Server.LANDING_MAX_DISTANCE = 30
Server.LANDING_ATTEMPTS = 40
Server.HORDE_RADIUS = 4
-- Rayon de recherche d'une autre case si la case prévue n'est plus libre.
Server.RELOCATE_RADIUS = 6
local lastRequestMs = {}
local secretCode = nil

--- État persistant de la partie (lisible par les clients : rien de secret).
function Server.getState()
    return ModData.getOrCreate(Server.MODDATA_TAG)
end

--- Fichier du code, propre à la partie (dossier Lua du serveur ou du joueur).
function Server.codeFile()
    local world = getWorld()
    local key = tostring(world:getGameMode()) .. "_" .. tostring(world:getWorld())
    return "MilitaryDrop/" .. key:gsub("[^%w_%-]", "_") .. "_code.txt"
end

local function readCode(file)
    local reader = getFileReader(file, false)
    if not reader then
        return nil
    end
    local line = reader:readLine()
    reader:close()
    if type(line) == "string" and line ~= "" then
        return line
    end
    return nil
end

local function writeCode(file, code)
    local writer = getFileWriter(file, true, false)
    if writer then
        writer:write(code)
        writer:close()
    else
        MilitaryDrop.log("cannot write " .. file .. ": the code will change at the next restart", true)
    end
end

--- Code d'authentification de la partie, tiré à la première lecture.
function Server.getCode()
    if secretCode then
        return secretCode
    end
    local file = Server.codeFile()
    local state = Server.getState()
    secretCode = readCode(file)
    if not secretCode then
        -- Reprise d'une version de développement qui le gardait en ModData.
        secretCode = type(state.code) == "string" and state.code ~= "" and state.code or Codes.generate()
        writeCode(file, secretCode)
        MilitaryDrop.log("authentication code stored in " .. file)
    end
    state.code = nil
    return secretCode
end

--- Heures de jeu avant le prochain largage permis (0 si permis).
function Server.hoursUntilNextDrop(state, now)
    local last = tonumber(state.lastDropHours)
    if not last then
        return 0
    end
    local remaining = last + Config.get("CooldownHours") - now
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
    if not radio then
        return "noRadio"
    end
    if force then
        return "accepted", radio
    end
    local status = Radio.status(radio, Config.getChannel())
    if status == "wrongFrequency" then
        return "noAnswer"
    end
    if status then
        return status
    end
    if Config.get("RequireAuthCode") and not Codes.matches(args.code, Server.getCode()) then
        return "noAnswer"
    end
    local wait = Server.hoursUntilNextDrop(Server.getState(), now)
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

--- Case d'atterrissage la plus proche de (x, y), dans RELOCATE_RADIUS, ou nil.
function Server.findLandingNear(x, y)
    for radius = 0, Server.RELOCATE_RADIUS do
        for dx = -radius, radius do
            for dy = -radius, radius do
                if math.max(math.abs(dx), math.abs(dy)) == radius then
                    local square = Server.landingSquareAt(x + dx, y + dy)
                    if square then
                        return square
                    end
                end
            end
        end
    end
    return nil
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

--- Livraison : caisse de largage, horde autour et annonce sur la chaîne
--- militaire. La case doit être chargée ; elle est revérifiée (un véhicule a pu
--- s'y garer pendant le vol ou avant un redémarrage) et remplacée au besoin
--- par la plus proche. requester : nom du joueur qui a appelé. notify : lui
--- envoyer les coordonnées en privé (largage admin, qui n'exige pas d'être à
--- l'écoute ; ou chaîne militaire absente).
function Server.deliver(square, requester, requestId, notify)
    square = Server.findLandingNear(square:getX(), square:getY()) or square
    local x, y = square:getX(), square:getY()
    local count = 0
    if MilitaryDrop.Crate.spawn(square) then
        count = 1
    else
        -- Repli : la caisse n'a pas pu apparaître (aucune place libre).
        for _, fullType in ipairs(MilitaryDrop.Crate.rollCases()) do
            if square:AddWorldInventoryItem(fullType, ZombRandFloat(0.2, 0.8), ZombRandFloat(0.2, 0.8), 0) then
                count = count + 1
            end
        end
        MilitaryDrop.log("crate could not spawn: supply cases left on the ground", true)
    end
    local zombies = Server.hordeSize()
    if zombies > 0 then
        local r = Server.HORDE_RADIUS
        spawnHorde(x - r, y - r, x + r, y + r, 0, zombies)
    end
    local state = Server.getState()
    state.lastDrop = { x = x, y = y, hours = getGameTime():getWorldAgeHours() }
    MilitaryDrop.log(string.format("drop at %d,%d: %d crate/cases, %d zombies, for %s",
        x, y, count, zombies, tostring(requester)), true)
    MilitaryDrop.Broadcast.dropped(x, y)
    notify = notify or not MilitaryDrop.Broadcast.channel
    local player = notify and requester and Server.findPlayer(requester)
    if player then
        Net.toPlayer(player, "Dropped", { requestId = requestId, x = x, y = y })
    end
end

function Server.handleRequest(player, args)
    local name = tostring(player:getUsername())
    local nowMs = getTimestampMs()
    if lastRequestMs[name] and nowMs - lastRequestMs[name] < Server.REQUEST_INTERVAL_MS then
        return
    end
    lastRequestMs[name] = nowMs

    local requestId = type(args) == "table" and tonumber(args.requestId) or nil
    local now = getGameTime():getWorldAgeHours()
    local status, extra = Server.evaluate(player, args, now)
    if status ~= "accepted" then
        MilitaryDrop.log("request from " .. name .. " refused: " .. status)
        Net.toPlayer(player, "Result", { requestId = requestId, status = status, hours = extra })
        return
    end

    local origin = Radio.isWorldRadio(extra) and extra:getSquare() or player:getCurrentSquare()
    local square = origin and Server.findLandingSquare(origin:getX(), origin:getY())
    if not square then
        MilitaryDrop.log("request from " .. name .. ": no landing square", true)
        Net.toPlayer(player, "Result", { requestId = requestId, status = "noSite" })
        return
    end
    if args.force ~= true then
        Server.getState().lastDropHours = now
    end
    Net.toPlayer(player, "Result", { requestId = requestId, status = "accepted" })
    MilitaryDrop.Flights.launch(square, name, requestId, args.force == true)
end

function Server.onClientCommand(module, command, player, args)
    if module ~= Net.MODULE or not player then
        return
    end
    if command == "Request" then
        Server.handleRequest(player, args)
    elseif command == "Sync" then
        MilitaryDrop.Flights.sendActive(player)
    end
end

Events.OnInitGlobalModData.Add(function()
    Server.getCode()
end)
Events.OnClientCommand.Add(Server.onClientCommand)

return Server
