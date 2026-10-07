-- ============================================================================
-- Military Drop — Fulton : lâcher et paiement (FULTON-07), serveur MP ou solo
--
-- Le client termine l'action « Gonfler et lâcher le Fulton »
-- (MilitaryDrop_FultonMenu.lua), puis envoie FultonLaunch { kitId, tankId, x, y, z }.
-- Le kit est POSÉ AU SOL (décision de l'utilisateur du 2026-10-07) ; x, y, z
-- désignent sa case. L'action reste côté client (pas de complete(), comme
-- ExchangeAction) : toute l'autorité est ici. Le serveur revérifie tout avant d'agir :
--   cadence, case du kit à Fulton.REACH cases au plus du joueur et au même
--   étage, kit trouvé parmi les objets au sol de cette case (identifiant et
--   type), bouteille dans l'inventaire principal (ni portée, ni en main, ni
--   accrochée) et non vide, ligne ouverte, source activée, créneau ouvert
--   (Missions.fultonWindow), case du kit extérieure sans arbre, météo
--   (MilitaryDrop.Fulton.siteReason), hors zone non-PvP et refuge, kit non vide.
-- Puis, dans cet ordre : une charge d'hélium (UseAndSync : synchronisée en
-- MP), retrait du kit et de son contenu du sol pour tous
-- (transmitRemoveItemFromSquare, comme ISBuildIsoEntity), paiement (« fulton » plafonné,
-- « fultonCure » hors plafond), fermeture du créneau, réponse au joueur et
-- ligne au journal du poste de son équipe. Les objets ne passent jamais par
-- le sol : aucun doublon possible si une case se décharge.
-- Puis FultonServer.onLaunched : vol visible attaché au point du lâcher (serveur
-- MP : Snapshot à tous les clients, qui jouent le passage de l'avion ; solo :
-- vol local), bruit du passage pour les zombies, annonce du secteur.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Server"
require "MilitaryDrop/MilitaryDrop_Guard"
require "MilitaryDrop/MilitaryDrop_Teams"
require "MilitaryDrop/MilitaryDrop_Trust"
require "MilitaryDrop/MilitaryDrop_Missions"
require "MilitaryDrop/MilitaryDrop_ZonesFile"
require "MilitaryDrop/MilitaryDrop_Broadcast"
require "MilitaryDrop/MilitaryDrop_FultonPrototypeServer"
require "MilitaryDrop/MilitaryDrop_Fulton"
require "MilitaryDrop/MilitaryDrop_Exchange"

local Fulton = MilitaryDrop.Fulton
local Exchange = MilitaryDrop.Exchange

local FultonServer = {}
MilitaryDrop.FultonServer = FultonServer

FultonServer.RESULT = "FultonResult"
-- Un lâcher par joueur toutes les 3 s réelles au plus.
FultonServer.INTERVAL_MS = 3000
-- Bruit du passage de l'avion pour les zombies (rayon, volume) [proposition].
FultonServer.FLYBY_NOISE_RADIUS = 40
FultonServer.FLYBY_NOISE_VOLUME = 40

-- Motifs de refus → réplique du personnage (clé de traduction).
FultonServer.REASONS = {
    busy = "IGUI_MilitaryDrop_Busy",
    noKit = "IGUI_MilitaryDrop_Fulton_NoKit",
    noHelium = "IGUI_MilitaryDrop_Fulton_NoHelium",
    lineCut = "IGUI_MilitaryDrop_Fulton_LineCut",
    disabled = "IGUI_MilitaryDrop_SourceDisabled",
    noWindow = "IGUI_MilitaryDrop_Fulton_NoWindow",
    protected = "IGUI_MilitaryDrop_Fulton_Protected",
    emptyKit = "IGUI_MilitaryDrop_Fulton_EmptyKit",
}

--- Réponse au joueur : { status, reason (clé) } pour un refus, ou { status = "ok",
--- lines } (lignes de la base, traduites par le client).
local function send(player, args)
    args.username = tostring(player:getUsername())
    MilitaryDrop.Net.toPlayer(player, FultonServer.RESULT, args)
end

local function refuse(player, status, reason)
    MilitaryDrop.log("Fulton launch refused for " .. tostring(player:getUsername()) .. ": " .. status)
    send(player, { status = status, reason = reason or FultonServer.REASONS[status] })
    return status
end

--- Objet de l'inventaire principal du joueur (pas dans un sac), ni porté, ni
--- en main, ni accroché, ou nil.
local function ownItem(player, id, fullType)
    id = tonumber(id)
    if not id then
        return nil
    end
    local item = player:getInventory():getItemWithID(id)
    if not item or item:getFullType() ~= fullType then
        return nil
    end
    if player:isEquipped(item) or player:isAttachedItem(item) then
        return nil
    end
    return item
end

--- Kit posé au sol sur la case désignée par le client, à portée du joueur :
--- objet, objet du monde et case, ou nil.
local function groundKit(player, args)
    local x, y, z, id = tonumber(args.x), tonumber(args.y), tonumber(args.z), tonumber(args.kitId)
    if not (x and y and z and id) then
        return nil
    end
    if z ~= math.floor(player:getZ()) or math.abs(x - math.floor(player:getX())) > Fulton.REACH
        or math.abs(y - math.floor(player:getY())) > Fulton.REACH then
        return nil
    end
    local cell = getCell()
    local square = cell and cell:getGridSquare(x, y, z)
    if not square then
        return nil
    end
    local objects = square:getWorldObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local item = object and object:getItem()
        if item and item:getID() == id and item:getFullType() == Fulton.KIT_TYPE then
            return item, object, square
        end
    end
    return nil
end

--- Zone non-PvP ou refuge sur la case (zones connues du serveur seulement).
local function protectedAt(x, y)
    local ZonesFile = MilitaryDrop.ZonesFile
    if not ZonesFile then
        return false
    end
    local rect = { x1 = x, y1 = y, x2 = x, y2 = y }
    return ZonesFile.overlapsNonPvp(rect) or ZonesFile.overlapsSafehouse(rect)
end

--- Lignes de la base pour un envoi payé (sans chiffre de confiance).
function FultonServer.resultLines(callsign, evaluation, lost)
    local lines = {}
    if evaluation.paid == 0 then
        lines[1] = Exchange.line("IGUI_MilitaryDrop_Fulton_ReceivedNothing", callsign)
        return lines
    end
    lines[1] = Exchange.line("IGUI_MilitaryDrop_Fulton_Received", callsign, tostring(evaluation.paid))
    if (evaluation.counts.cure or 0) > 0 then
        lines[#lines + 1] = Exchange.line("IGUI_MilitaryDrop_Fulton_Cure")
    end
    if lost > 0 then
        lines[#lines + 1] = Exchange.line("IGUI_MilitaryDrop_Fulton_CapReached")
    end
    return lines
end

--- Lâcher demandé par le joueur. Renvoie le statut (tests).
function FultonServer.launch(player, args)
    args = type(args) == "table" and args or {}
    if MilitaryDrop.Guard.throttled(player, "fulton", FultonServer.INTERVAL_MS) then
        return refuse(player, "busy")
    end
    local kit, kitObject, square = groundKit(player, args)
    if not kit then
        return refuse(player, "noKit")
    end
    local tank = ownItem(player, args.tankId, Fulton.TANK_TYPE)
    if not Fulton.tankHasHelium(tank) then
        return refuse(player, "noHelium")
    end
    local Trust = MilitaryDrop.Trust
    local characterId = Trust.idFor(player)
    if Trust.isLineCut(characterId) then
        return refuse(player, "lineCut")
    end
    if not Fulton.isEnabled() then
        return refuse(player, "disabled")
    end
    local Missions = MilitaryDrop.Missions
    if not Missions.fultonWindow(characterId) then
        return refuse(player, "noWindow")
    end
    local siteReason = Fulton.siteReason(square)
    if siteReason then
        return refuse(player, "site", siteReason)
    end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    if protectedAt(x, y) then
        return refuse(player, "protected")
    end
    local items = Fulton.kitItems(kit)
    if #items == 0 then
        return refuse(player, "emptyKit")
    end

    local evaluation = Fulton.evaluate(items, player)
    tank:UseAndSync()
    square:transmitRemoveItemFromSquare(kitObject)
    local credited = Trust.add(characterId, evaluation.capped, "fulton")
    local cure = Trust.add(characterId, evaluation.uncapped, "fultonCure")
    local lost = math.max(0, evaluation.capped - credited)
    Missions.closeFultonWindow(characterId)
    local teamId = MilitaryDrop.Teams.idFor(player)
    local callsign = MilitaryDrop.Teams.callsign(teamId) or ""
    local lines = FultonServer.resultLines(callsign, evaluation, lost)
    local Post = MilitaryDrop.Post
    if Post and Post.record then
        for _, line in ipairs(lines) do
            Post.record(teamId, line)
        end
    end
    MilitaryDrop.log(string.format("Fulton launched by %s at %d,%d,%d: %d paid, %d unpaid, +%d capped (%d lost), +%d cure",
        tostring(player:getUsername()), x, y, z, evaluation.paid, evaluation.unpaid, credited, lost, cure), true)
    send(player, { status = "ok", lines = lines })
    if FultonServer.onLaunched then
        FultonServer.onLaunched(player, x, y, z)
    end
    return "ok"
end

--- Après un lâcher payé : vol visible au centre de la case, bruit, annonce.
function FultonServer.onLaunched(player, x, y, z)
    local fx, fy = x + 0.5, y + 0.5
    if isServer() then
        local Flights = MilitaryDrop.FultonPrototypeServer
        if Flights and Flights.startFlight then
            Flights.startFlight(fx, fy, z)
        end
    elseif MilitaryDrop.FultonPrototype and MilitaryDrop.FultonPrototype.startAt then
        MilitaryDrop.FultonPrototype.startAt(fx, fy, z)
    end
    local sounds = getWorldSoundManager and getWorldSoundManager()
    if sounds then
        sounds:addSound(nil, x, y, z, FultonServer.FLYBY_NOISE_RADIUS, FultonServer.FLYBY_NOISE_VOLUME)
    end
    if MilitaryDrop.Broadcast and MilitaryDrop.Broadcast.fulton then
        MilitaryDrop.Broadcast.fulton(x, y)
    end
end

MilitaryDrop.Server.COMMANDS.FultonLaunch = function(player, args) FultonServer.launch(player, args) end

return FultonServer
