-- ============================================================================
-- Military Drop — autorité serveur (serveur MP ou solo)
--
-- Le client envoie seulement une demande (commande « Request » : référence de
-- la radio, code saisi, demande admin). Le serveur revérifie tout, dans cet
-- ordre : droits admin, radio à portée, radio militaire allumée sur le bon
-- canal, code, délai global. Le délai n'est révélé qu'après un code juste.
--
-- État persistant : ModData globale « MilitaryDrop » du serveur (code de la
-- partie, heure du dernier largage). Elle n'est jamais transmise aux clients :
-- le code ne doit se lire que sur les notes.
--
-- Livraison (provisoire, phase 2) : les caisses sont posées au sol sur une
-- case extérieure à 15-30 cases, avec la horde. La phase 3 la remplacera par
-- le passage de l'hélicoptère, et la phase 5 par une caisse larguée.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Radio"
require "MilitaryDrop/MilitaryDrop_Codes"
require "MilitaryDrop/MilitaryDrop_Loot"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Radio = MilitaryDrop.Radio
local Codes = MilitaryDrop.Codes
local Loot = MilitaryDrop.Loot

local Server = {}
MilitaryDrop.Server = Server

Server.MODDATA_TAG = "MilitaryDrop"
-- Une demande par joueur toutes les 3 s réelles au plus (anti-rafale).
Server.REQUEST_INTERVAL_MS = 3000
Server.LANDING_MIN_DISTANCE = 15
Server.LANDING_MAX_DISTANCE = 30
Server.LANDING_ATTEMPTS = 40
Server.HORDE_RADIUS = 4
-- Caisses posées à chaque tirage (livraison provisoire).
Server.CASE_WEIGHTS = {
    "MilitaryDrop.AmmoSupplyCase", 45,
    "MilitaryDrop.WeaponSupplyCase", 25,
    "MilitaryDrop.ArmorSupplyCase", 15,
    "MilitaryDrop.AttachmentSupplyCase", 15,
}

local lastRequestMs = {}

--- État persistant de la partie ; tire le code à la première lecture.
function Server.getState()
    local state = ModData.getOrCreate(Server.MODDATA_TAG)
    if type(state.code) ~= "string" or state.code == "" then
        state.code = Codes.generate()
        MilitaryDrop.log("authentication code generated")
    end
    return state
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
    if status then
        return status
    end
    local state = Server.getState()
    if Config.get("RequireAuthCode") and not Codes.matches(args.code, state.code) then
        return "badCode"
    end
    local wait = Server.hoursUntilNextDrop(state, now)
    if wait > 0 then
        return "cooldown", math.ceil(wait)
    end
    return "accepted", radio
end

--- Case d'atterrissage : extérieure, au sol, libre et hors de l'eau.
function Server.isLandingSquare(square)
    return square ~= nil and square:isOutside() and square:isFree(false) and not square:isWaterSquare()
end

--- Case d'atterrissage tirée au hasard autour d'un point, ou nil.
function Server.findLandingSquare(centerX, centerY)
    local cell = getCell()
    for _ = 1, Server.LANDING_ATTEMPTS do
        local angle = ZombRandFloat(0, 2 * math.pi)
        local distance = ZombRandFloat(Server.LANDING_MIN_DISTANCE, Server.LANDING_MAX_DISTANCE)
        local x = math.floor(centerX + math.cos(angle) * distance)
        local y = math.floor(centerY + math.sin(angle) * distance)
        local square = cell:getGridSquare(x, y, 0)
        if Server.isLandingSquare(square) then
            return square
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

--- Livraison provisoire : caisses au sol et horde autour.
function Server.deliver(player, square, requestId)
    local x, y = square:getX(), square:getY()
    local entries = Loot.toEntries(Server.CASE_WEIGHTS)
    local rand = function(total) return ZombRandFloat(0, total) end
    local count = 0
    for _ = 1, math.max(1, math.floor(Config.get("CaseRolls"))) do
        local entry = Loot.pickWeighted(entries, rand)
        if entry and square:AddWorldInventoryItem(entry.name, ZombRandFloat(0.2, 0.8), ZombRandFloat(0.2, 0.8), 0) then
            count = count + 1
        end
    end
    local zombies = Server.hordeSize()
    if zombies > 0 then
        local r = Server.HORDE_RADIUS
        spawnHorde(x - r, y - r, x + r, y + r, 0, zombies)
    end
    local state = Server.getState()
    state.lastDrop = { x = x, y = y, hours = getGameTime():getWorldAgeHours() }
    MilitaryDrop.log(string.format("drop at %d,%d: %d cases, %d zombies, for %s",
        x, y, count, zombies, tostring(player:getUsername())), true)
    Net.toPlayer(player, "Dropped", { requestId = requestId, x = x, y = y })
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
    Server.deliver(player, square, requestId)
end

function Server.onClientCommand(module, command, player, args)
    if module ~= Net.MODULE or not player then
        return
    end
    if command == "Request" then
        Server.handleRequest(player, args)
    end
end

Events.OnInitGlobalModData.Add(function()
    Server.getState()
end)
Events.OnClientCommand.Add(Server.onClientCommand)

return Server
