-- ============================================================================
-- Military Drop — zones de largage (idée 11 : ZONE-01, 03, 04, 05 ; serveur
-- MP ou solo)
--
-- Option DropPlacement : 1 proximité (anneau autour du demandeur, comportement
-- d'avant, rien ne change), 2 zones de l'admin (dropzones.txt,
-- MilitaryDrop_ZonesFile.lua), 3 zones si l'une d'elles est à moins de
-- DropZoneMaxDistance du demandeur (seules ces zones proches sont alors
-- candidates), sinon proximité. Le largage forcé de l'admin (APPEL-05 :
-- direct, ou feuille admin, leurre compris) n'est pas concerné (décision de
-- l'analyse §2.1) : il garde le placement par proximité, quel que soit
-- DropPlacement (Server.chooseDropPoint, argument proximity), et son leurre
-- propose les secteurs N/E/S/O.
--
-- Choix du point (Server.chooseDropPoint → Zones.choosePoint) :
--   1. secteur : le plus proche du demandeur (distance au bord de sa zone la
--      plus proche, DropZoneChoice 1) ou au hasard (2), parmi les zones à au
--      moins DropZoneMinDistance cases ; si toutes sont trop proches, le
--      secteur le plus proche. Leurre : le secteur nommé, revérifié.
--   2. zone : tirage pondéré (weight) parmi les zones actives du secteur.
--   3. case : une case de route « Nav » tirée dans le rectangle, sinon le
--      pied d'un bâtiment dans le rectangle ; JAMAIS une case quelconque : la
--      métagrille ne connaît pas l'eau (Server.ROAD_ZONE). Refus d'une case
--      dont la caisse toucherait une zone non-PvP ou un refuge. Case chargée :
--      contrôlée tout de suite (Server.findLandingNear borné à la zone).
--   4. aucune case : une autre zone du même secteur, puis nil (« noSite »),
--      jamais hors zone ni ailleurs.
-- La livraison (Server.deliver) relit le rectangle dans l'état privé du
-- largage (drops[dropId].zone) et ne cherche qu'à l'intérieur (élargi d'une
-- case pour l'empreinte 2 × 2 de la caisse) : pas de case sèche, la caisse
-- attend (aucune caisse dans l'eau ni hors zone).
--
-- Repli du mode 2 sans zone utilisable (ZONE-05) : les villes vanilla
-- (TOWNS, rayon TOWN_RADIUS, chacune secteur d'une seule zone) si la carte
-- vanilla est chargée et que la métagrille connaît le centre ; sinon la
-- proximité, avec un avertissement au journal et une Notice aux admins
-- connectés.
--
-- Leurre (ZONE-04) : en mode zones effectif, la réponse « form » propose les
-- noms de secteurs actifs (Zones.decoySectors) au lieu de N/E/S/O ; la
-- commande renvoie le nom, revérifié par Requisition.validate.
--
-- Secret : la liste des zones ne part qu'à un admin qui la demande ; le nom
-- de la zone tirée reste dans l'état privé du largage jusqu'à l'annonce.
--
-- Outil d'admin (ZONE-03) : commandes ZoneList, ZoneAdd, ZoneSetEnabled,
-- ZoneDelete, ZoneReload ; droit Requisition.canReload (capacité
-- ChangeAndReloadServerOptions, vrai en solo), cadence Guard « Zone ».
-- Réponses ZoneReply { ok, action, id, error, warnings } puis ZoneListReply.
-- Chaque modification relit d'abord le fichier (ZonesFile.editableData) ;
-- ZoneAdd revérifie la zone relue (valide et utilisable, sinon le fichier
-- est remis en l'état et l'outil répond « invalid »).
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Guard"
require "MilitaryDrop/MilitaryDrop_Server"
require "MilitaryDrop/MilitaryDrop_ZonesFile"
require "MilitaryDrop/MilitaryDrop_Requisition"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Server = MilitaryDrop.Server
local ZonesFile = MilitaryDrop.ZonesFile

local Zones = {}
MilitaryDrop.Zones = Zones

Zones.MODE_PROXIMITY = 1
Zones.MODE_ZONES = 2
Zones.MODE_ZONES_NEAR = 3
Zones.CHOICE_NEAREST = 1
Zones.CHOICE_RANDOM = 2
-- Cases de route tirées dans une zone avant les bâtiments.
Zones.ROAD_ATTEMPTS = 30
-- Carte vanilla (dossier de lots, ZonesFile.loadedMaps) et villes du repli.
Zones.VANILLA_MAP = "Muldraugh, KY"
Zones.TOWN_RADIUS = 150
-- Centres des villes (worldmap-annotations.lua, pz-knowledge knox-geography.md).
Zones.TOWNS = {
    { name = "Louisville", x = 13077, y = 2238 },
    { name = "Valley Station", x = 13447, y = 5278 },
    { name = "West Point", x = 11654, y = 6864 },
    { name = "Muldraugh", x = 10754, y = 9926 },
    { name = "Riverside", x = 6450, y = 5430 },
    { name = "Brandenburg", x = 2056, y = 6070 },
    { name = "Ekron", x = 634, y = 9746 },
    { name = "Irvington", x = 2427, y = 14185 },
    { name = "Echo Creek", x = 3589, y = 10952 },
    { name = "March Ridge", x = 10130, y = 12801 },
    { name = "Fallas Lake", x = 7253, y = 8279 },
    { name = "Rosewood", x = 8159, y = 11661 },
}
Zones.COMMAND_INTERVAL_MS = 500
Zones.MAX_REPLY_PROBLEMS = 10
Zones.FALLBACK_NOTICE = "IGUI_MilitaryDrop_ZoneFallbackProximity"

Config.addDefaults({
    DropPlacement = 1,
    DropZoneChoice = 1,
    DropZoneMinDistance = 0,
    DropZoneMaxDistance = 1500,
    DropZoneAnnounceName = true,
})

local function option(name, low, high)
    local value = math.floor(tonumber(Config.get(name)) or low)
    return math.max(low, math.min(high, value))
end

--- Mode de placement (option DropPlacement), borné à 1-3.
function Zones.placement()
    return option("DropPlacement", 1, 3)
end

--- Distance de (x, y) au bord du rectangle de la zone (0 à l'intérieur).
function Zones.distanceTo(zone, x, y)
    local dx = math.max(zone.x1 - x, 0, x - zone.x2)
    local dy = math.max(zone.y1 - y, 0, y - zone.y2)
    return math.sqrt(dx * dx + dy * dy)
end

--- Point d'atterrissage (x, y) dans la zone : la caisse couvre x-1..x et
--- y-1..y (Server.landingSquareAt), donc au plus une case hors du rectangle.
function Zones.landingBounds(zone)
    return { x1 = zone.x1, y1 = zone.y1, x2 = zone.x2 + 1, y2 = zone.y2 + 1 }
end

local function inBounds(bounds, x, y)
    return x >= bounds.x1 and x <= bounds.x2 and y >= bounds.y1 and y <= bounds.y2
end

-- ----------------------------------------------------------------------------
-- Zones candidates
-- ----------------------------------------------------------------------------

--- La carte vanilla est chargée : dans les dossiers de lots de la partie,
--- même incluse par une carte de mod (ZonesFile.loadedMaps).
function Zones.vanillaMapLoaded()
    return #ZonesFile.missingMaps(Zones.VANILLA_MAP) == 0
end

--- Villes vanilla utilisables (repli du mode 2) : zones d'un seul secteur,
--- seulement si la carte vanilla est chargée et que la métagrille connaît
--- le centre.
function Zones.towns()
    local list = {}
    if not Zones.vanillaMapLoaded() then
        return list
    end
    local grid = getWorld():getMetaGrid()
    local r, size = Zones.TOWN_RADIUS, ZonesFile.CELL_SIZE
    for _, town in ipairs(Zones.TOWNS) do
        if grid:isValidSquare(town.x, town.y) and grid:getCellData(math.floor(town.x / size), math.floor(town.y / size)) then
            list[#list + 1] = { id = "town:" .. town.name, sector = town.name, name = town.name, weight = 1,
                x1 = town.x - r, y1 = town.y - r, x2 = town.x + r, y2 = town.y + r, town = true }
        end
    end
    return list
end

--- Zones candidates pour un demandeur en (px, py) : liste et source
--- ("zone" ou "town") ; nil en proximité (nil, ou "proximity" pour le repli
--- du mode 2, qui avertit les admins).
function Zones.candidates(px, py)
    local mode = Zones.placement()
    if mode == Zones.MODE_PROXIMITY then
        return nil
    end
    local zones = ZonesFile.activeZones()
    if mode == Zones.MODE_ZONES_NEAR then
        local range = option("DropZoneMaxDistance", 0, 1000000)
        local near = {}
        for _, zone in ipairs(zones) do
            if Zones.distanceTo(zone, px, py) <= range then
                near[#near + 1] = zone
            end
        end
        if #near == 0 then
            return nil
        end
        return near, "zone"
    end
    if #zones > 0 then
        return zones, "zone"
    end
    local towns = Zones.towns()
    if #towns > 0 then
        return towns, "town"
    end
    return nil, "proximity"
end

--- Noms des secteurs d'une liste de zones, ordre alphabétique.
function Zones.sectorNames(zones)
    local seen, names = {}, {}
    for _, zone in ipairs(zones) do
        if not seen[zone.sector] then
            seen[zone.sector] = true
            names[#names + 1] = zone.sector
        end
    end
    table.sort(names)
    return names
end

--- Zones d'une liste à au moins DropZoneMinDistance cases de (px, py) ; si
--- toutes sont plus proches, nil (l'appelant revient au plus proche).
local function farEnough(zones, px, py)
    local low = option("DropZoneMinDistance", 0, 1000000)
    if low <= 0 then
        return zones
    end
    local far = {}
    for _, zone in ipairs(zones) do
        if Zones.distanceTo(zone, px, py) >= low then
            far[#far + 1] = zone
        end
    end
    if #far == 0 then
        return nil
    end
    return far
end

--- Secteur choisi et ses zones candidates (ZONE-04, étape 1).
function Zones.pickSector(zones, px, py)
    local pool = farEnough(zones, px, py)
    local nearestOnly = pool == nil
    pool = pool or zones
    local bySector, distance = {}, {}
    for _, zone in ipairs(pool) do
        local list = bySector[zone.sector]
        if not list then
            list = {}
            bySector[zone.sector] = list
        end
        list[#list + 1] = zone
        local d = Zones.distanceTo(zone, px, py)
        if not distance[zone.sector] or d < distance[zone.sector] then
            distance[zone.sector] = d
        end
    end
    local names = Zones.sectorNames(pool)
    local chosen
    if not nearestOnly and option("DropZoneChoice", 1, 2) == Zones.CHOICE_RANDOM then
        chosen = names[ZombRand(#names) + 1]
    else
        for _, name in ipairs(names) do
            if not chosen or distance[name] < distance[chosen] then
                chosen = name
            end
        end
    end
    return chosen, bySector[chosen]
end

--- Index d'une zone tirée au poids (weight) dans la liste.
function Zones.drawZone(zones)
    local total = 0
    for _, zone in ipairs(zones) do
        total = total + (tonumber(zone.weight) or 1)
    end
    local roll = ZombRand(math.max(1, total))
    for i, zone in ipairs(zones) do
        roll = roll - (tonumber(zone.weight) or 1)
        if roll < 0 then
            return i
        end
    end
    return #zones
end

-- ----------------------------------------------------------------------------
-- Case dans une zone
-- ----------------------------------------------------------------------------

--- Point de largage dans la zone (route, sinon pied d'un bâtiment, borné au
--- rectangle), ou nil. Une case chargée doit déjà accueillir la caisse dans
--- la zone ; sinon elle est revérifiée à la livraison.
function Zones.pointInZone(zone)
    local grid = getWorld():getMetaGrid()
    local cell = getCell()
    local bounds = Zones.landingBounds(zone)
    local function usable(x, y)
        if not inBounds(bounds, x, y) or not Server.isOnMap(x, y) or ZonesFile.isProtected(x, y) then
            return false
        end
        return not cell:getGridSquare(x, y, 0) or Server.findLandingNear(x, y, bounds) ~= nil
    end
    local roads, total = ZonesFile.roadRects(grid, zone), 0
    for _, road in ipairs(roads) do
        total = total + road.area
    end
    if total > 0 then
        for _ = 1, Zones.ROAD_ATTEMPTS do
            local roll = ZombRand(total)
            for _, road in ipairs(roads) do
                roll = roll - road.area
                if roll < 0 then
                    local x = road.x1 + ZombRand(road.x2 - road.x1 + 1)
                    local y = road.y1 + ZombRand(road.y2 - road.y1 + 1)
                    if usable(x, y) then
                        return x, y
                    end
                    break
                end
            end
        end
    end
    -- Pied d'un bâtiment, dans un ordre tiré au hasard : au sud, au nord, à
    -- l'est, à l'ouest, à deux cases du mur (comme Server.buildingPointNear).
    local buildings = ZonesFile.buildingsIn(grid, zone)
    for i = #buildings, 2, -1 do
        local j = ZombRand(i) + 1
        buildings[i], buildings[j] = buildings[j], buildings[i]
    end
    for _, b in ipairs(buildings) do
        local bx, by, bw, bh = b:getX(), b:getY(), b:getW(), b:getH()
        local cx, cy = bx + math.floor(bw / 2), by + math.floor(bh / 2)
        local feet = { { cx, by + bh + 2 }, { cx, by - 2 }, { bx + bw + 2, cy }, { bx - 2, cy } }
        for _, foot in ipairs(feet) do
            if usable(foot[1], foot[2]) then
                return foot[1], foot[2]
            end
        end
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- Choix du point (Server.chooseDropPoint)
-- ----------------------------------------------------------------------------

--- Joueurs connectés (serveur MP) ou locaux (solo).
function Zones.players()
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

--- Mode 2 sans zone ni ville : avertissement au journal et aux admins connectés.
function Zones.warnFallback()
    MilitaryDrop.log("DropPlacement is set to drop zones but no zone is usable and no vanilla town"
        .. " is loaded: drop near the caller (see Zomboid/Lua/" .. ZonesFile.PATH .. ")", true)
    for _, player in ipairs(Zones.players()) do
        if MilitaryDrop.Requisition.canReload(player) then
            Net.toPlayer(player, "Notice", { username = tostring(player:getUsername()), key = Zones.FALLBACK_NOTICE })
        end
    end
end

local function infoFor(zone, source)
    return { zoneId = zone.id, zoneName = zone.name, sector = zone.sector, source = source,
        x1 = zone.x1, y1 = zone.y1, x2 = zone.x2, y2 = zone.y2 }
end

--- Point d'un appel en (px, py) ; sector : secteur nommé du leurre (mode
--- zones). Renvoie handled, x, y, info : handled faux en proximité (info
--- { source = "proximity" } pour le repli du mode 2, sinon nil) ; handled
--- vrai en mode zones, x nil si aucune case (« noSite »).
function Zones.choosePoint(px, py, sector)
    local zones, source = Zones.candidates(px, py)
    if not zones then
        if source == "proximity" then
            Zones.warnFallback()
            return false, nil, nil, { source = "proximity" }
        end
        return false
    end
    local name, pool
    if sector ~= nil then
        name, pool = sector, {}
        for _, zone in ipairs(zones) do
            if zone.sector == sector then
                pool[#pool + 1] = zone
            end
        end
        pool = farEnough(pool, px, py) or pool
    else
        name, pool = Zones.pickSector(zones, px, py)
    end
    local remaining = {}
    for i, zone in ipairs(pool or {}) do
        remaining[i] = zone
    end
    while #remaining > 0 do
        local index = Zones.drawZone(remaining)
        local zone = remaining[index]
        local x, y = Zones.pointInZone(zone)
        if x then
            MilitaryDrop.log(string.format("drop point %d,%d in %s %s (%s)", x, y, source, tostring(zone.id),
                tostring(zone.sector)))
            return true, x, y, infoFor(zone, source)
        end
        MilitaryDrop.log("drop zone " .. tostring(zone.id) .. " (" .. tostring(zone.sector) .. "/"
            .. tostring(zone.name) .. "): no road or building foot to land on", true)
        table.remove(remaining, index)
    end
    MilitaryDrop.log("sector " .. tostring(name) .. ": no landing point in its zones", true)
    return true, nil
end

--- Secteurs proposés au leurre d'un demandeur en (px, py) : noms des
--- secteurs actifs (zones, ou villes vanilla du repli) en mode zones
--- effectif, ordre alphabétique ; nil en proximité (N, E, S, O).
function Zones.decoySectors(px, py)
    local zones = Zones.candidates(px, py)
    if not zones then
        return nil
    end
    return Zones.sectorNames(zones)
end

-- ----------------------------------------------------------------------------
-- Outil d'admin (ZONE-03)
-- ----------------------------------------------------------------------------

local function sendReply(player, args)
    Net.toPlayer(player, "ZoneReply", args)
end

--- Liste pour l'outil : toutes les zones valides (actives ou non), secteurs
--- actifs, carte du fichier, mode, premiers problèmes du journal.
function Zones.listReply()
    local report = ZonesFile.report()
    local zones = {}
    for i, zone in ipairs(report.zones) do
        local warnings = {}
        for j, code in ipairs(zone.warnings or {}) do
            warnings[j] = code
        end
        zones[i] = { id = zone.id, sector = zone.sector, name = zone.name, x1 = zone.x1, y1 = zone.y1,
            x2 = zone.x2, y2 = zone.y2, weight = zone.weight, enabled = zone.enabled, active = zone.active == true,
            warnings = warnings }
    end
    local problems = {}
    for i = 1, math.min(#report.problems, Zones.MAX_REPLY_PROBLEMS) do
        problems[i] = tostring(report.problems[i])
    end
    return { zones = zones, sectors = Zones.sectorNames(ZonesFile.activeZones()), map = report.map,
        mapLoaded = report.mapLoaded ~= false, placement = Zones.placement(), problems = problems }
end

function Zones.sendList(player)
    Net.toPlayer(player, "ZoneListReply", Zones.listReply())
end

--- Droit et cadence d'une commande de l'outil ; réponse « denied » ou
--- « busy » envoyée en cas de refus.
local function admitted(player, action)
    if not MilitaryDrop.Requisition.canReload(player) then
        MilitaryDrop.log("drop zone command " .. action .. " refused for " .. tostring(player:getUsername())
            .. ": not an admin", true)
        sendReply(player, { ok = false, action = action, error = "denied" })
        return false
    end
    if MilitaryDrop.Guard.throttled(player, "Zone", Zones.COMMAND_INTERVAL_MS) then
        sendReply(player, { ok = false, action = action, error = "busy" })
        return false
    end
    return true
end

local function warningsOf(id)
    local zone = ZonesFile.get(id)
    local warnings = {}
    for i, code in ipairs(zone and zone.warnings or {}) do
        warnings[i] = code
    end
    return warnings
end

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

--- Nouvelle zone de l'outil : { ok, id, warnings } ou { ok = false, error }.
function Zones.add(args, by)
    local sector = ZonesFile.cleanText(args.sector)
    if not sector then
        return { ok = false, error = "badSector" }
    end
    local name = ZonesFile.cleanText(args.name)
    if not name then
        return { ok = false, error = "badName" }
    end
    for _, key in ipairs({ "x1", "y1", "x2", "y2" }) do
        if not finite(args[key]) then
            return { ok = false, error = "invalid" }
        end
    end
    local weight = args.weight
    if weight ~= nil and (not finite(weight) or weight ~= math.floor(weight) or weight < 1
        or weight > ZonesFile.MAX_WEIGHT) then
        return { ok = false, error = "invalid" }
    end
    local rect, code = ZonesFile.normalizeRect(math.floor(args.x1), math.floor(args.y1), math.floor(args.x2),
        math.floor(args.y2))
    if not rect then
        return { ok = false, error = code }
    end
    if not ZonesFile.isOnGrid(getWorld():getMetaGrid(), rect) then
        return { ok = false, error = "offMap" }
    end
    if ZonesFile.overlapsNonPvp(rect) then
        return { ok = false, error = "overlapNonPvp" }
    end
    if ZonesFile.overlapsSafehouse(rect) then
        return { ok = false, error = "overlapSafehouse" }
    end
    local raw, err = ZonesFile.editableData()
    if not raw then
        return { ok = false, error = err }
    end
    if #raw.zones >= ZonesFile.MAX_ZONES then
        return { ok = false, error = "tooMany" }
    end
    local id = ZonesFile.nextId(raw)
    local entry = { id = id, sector = sector, name = name, x1 = rect.x1, y1 = rect.y1, x2 = rect.x2, y2 = rect.y2,
        weight = weight or 1, enabled = true }
    -- Carte du fichier absente de la partie : la carte de premier niveau
    -- devient celle de la partie (la nouvelle zone n'en répète pas une) ; les
    -- zones qui dépendaient de l'ancienne la gardent en propre (map de zone).
    if type(raw.map) == "string" and #ZonesFile.missingMaps(raw.map) > 0 then
        for _, other in ipairs(raw.zones) do
            if other.map == nil then
                other.map = raw.map
            end
        end
        raw.map = nil
    end
    raw.zones[#raw.zones + 1] = entry
    -- Texte lu par editableData, remis tel quel si la zone relue est refusée.
    local original = ZonesFile.report().text
    local report, saveError = ZonesFile.save(raw)
    if not report then
        return { ok = false, error = saveError or "writeFailed" }
    end
    -- Relue, la zone doit être valide et utilisable ; sinon le fichier est
    -- remis dans son état d'avant (journal) et l'outil répond une erreur.
    local added = ZonesFile.get(id)
    if not added or not added.active then
        MilitaryDrop.log("drop zone " .. id .. " is not usable once read back: not added", true)
        if original and ZonesFile.writeText(original .. "\n") then
            ZonesFile.load()
        end
        return { ok = false, error = "invalid" }
    end
    MilitaryDrop.log(string.format("drop zone %s added by %s: %s / %s, %d,%d - %d,%d", id, tostring(by), sector, name,
        rect.x1, rect.y1, rect.x2, rect.y2), true)
    return { ok = true, id = id, warnings = warningsOf(id) }
end

--- Activation ou désactivation d'une zone du fichier.
function Zones.setEnabled(args, by)
    if not ZonesFile.isId(args.id) or type(args.enabled) ~= "boolean" then
        return { ok = false, error = "invalid" }
    end
    local raw, err = ZonesFile.editableData()
    if not raw then
        return { ok = false, error = err, id = args.id }
    end
    local entry = ZonesFile.findEntry(raw, args.id)
    if not entry then
        return { ok = false, error = "unknownZone", id = args.id }
    end
    entry.enabled = args.enabled
    local report, code = ZonesFile.save(raw)
    if not report then
        return { ok = false, error = code or "writeFailed", id = args.id }
    end
    MilitaryDrop.log("drop zone " .. args.id .. (args.enabled and " enabled" or " disabled") .. " by " .. tostring(by), true)
    return { ok = true, id = args.id, warnings = warningsOf(args.id) }
end

--- Suppression d'une zone du fichier.
function Zones.delete(args, by)
    if not ZonesFile.isId(args.id) then
        return { ok = false, error = "invalid" }
    end
    local raw, err = ZonesFile.editableData()
    if not raw then
        return { ok = false, error = err, id = args.id }
    end
    local entry, index = ZonesFile.findEntry(raw, args.id)
    if not entry then
        return { ok = false, error = "unknownZone", id = args.id }
    end
    table.remove(raw.zones, index)
    local report, code = ZonesFile.save(raw)
    if not report then
        return { ok = false, error = code or "writeFailed", id = args.id }
    end
    MilitaryDrop.log("drop zone " .. args.id .. " deleted by " .. tostring(by), true)
    return { ok = true, id = args.id }
end

--- Relecture du fichier.
function Zones.reload(_, by)
    local report = ZonesFile.reload()
    MilitaryDrop.log("drop zones reloaded by " .. tostring(by), true)
    if report.syntaxError then
        return { ok = false, error = "syntaxError" }
    end
    return { ok = true }
end

Zones.ACTIONS = {
    ZoneAdd = { action = "add", run = Zones.add },
    ZoneSetEnabled = { action = "enable", run = Zones.setEnabled },
    ZoneDelete = { action = "delete", run = Zones.delete },
    ZoneReload = { action = "reload", run = Zones.reload },
}

--- Commande de l'outil (nom du protocole) : droit, cadence, action, puis
--- ZoneReply et ZoneListReply à l'appelant seulement.
function Zones.handleCommand(player, command, args)
    args = type(args) == "table" and args or {}
    if command == "ZoneList" then
        if admitted(player, "list") then
            Zones.sendList(player)
        end
        return
    end
    local spec = Zones.ACTIONS[command]
    if not spec or not admitted(player, spec.action) then
        return
    end
    local result = spec.run(args, tostring(player:getUsername()))
    result.action = spec.action
    sendReply(player, result)
    Zones.sendList(player)
end

local function register(command)
    Server.COMMANDS[command] = function(player, args) Zones.handleCommand(player, command, args) end
end
register("ZoneList")
register("ZoneAdd")
register("ZoneSetEnabled")
register("ZoneDelete")
register("ZoneReload")

--- Lecture du fichier au démarrage (serveur dédié : OnServerStarted ; solo :
--- OnGameStart), après le chargement des zones non-PvP et des refuges.
function Zones.warmUp()
    ZonesFile.ensureLoaded()
end

Events.OnServerStarted.Add(Zones.warmUp)
Events.OnGameStart.Add(Zones.warmUp)

return Zones
