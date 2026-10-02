-- ============================================================================
-- Military Drop — repère de largage sur la carte des joueurs à l'écoute
--
-- Le serveur envoie les coordonnées à tous (DropAnnounce) et diffuse les
-- lignes de la chaîne militaire avec le code MilitaryDrop.Announce.CODE. Un
-- client ne marque sa carte que si l'une de ses radios reçoit vraiment une de
-- ces lignes (OnDeviceText : allumée, bon canal, volume > 0, pas sourd, pas
-- brouillée par un orage), et seulement une fois par largage.
--
-- Symbole « Target » ajouté par l'API de symboles d'une carte cachée (sans
-- ouvrir la carte du monde) : sauvegardé comme une note du joueur, qui peut
-- l'effacer.
--
-- Rappel de la base (option DropRepeatHours, Server.repeatGrids) : même
-- principe, DropAnnounce { grids = { { x, y }, ... } } pour toutes les grilles
-- du rappel. Les grilles en attente d'être entendues forment une liste : une
-- ligne entendue les marque toutes (elles sont diffusées ensemble). Une
-- annonce qui n'a pas été entendue est oubliée à l'arrivée d'une suivante,
-- au-delà de PENDING_MS : jamais de repère pour une grille qu'on n'a pas
-- entendue.
--
-- Reconnaissance (SRC-03) : même principe. Le serveur envoie la grille à tous
-- (ReconAnnounce, { id, x, y }, MilitaryDrop.Broadcast.reconAnnounced) et
-- l'annonce de la mission porte le code RECON_CODE ; symbole « Eye », bleu,
-- posé une fois par mission (id), seulement si une radio du joueur l'entend.
-- Un talkie accroché à la ceinture compte aussi (MilitaryDrop_BeltRadio.lua
-- en solo, le vanilla sur un client MP).
--
-- Nettoyage (SRC-04) : même principe (CleanupAnnounce, { id, x, y, radius },
-- MilitaryDrop.Broadcast.cleanupAnnounced), code CLEANUP_CODE, symbole
-- « Skull » rouge au centre de la zone. Le rayon n'est pas dessiné : l'API
-- des symboles n'a ni cercle ni échelle réglable (WorldMapSymbolsV2.java:
-- 62-83, 370-520) ; l'annonce le donne.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Announce = {}
MilitaryDrop.Announce = Announce

Announce.CODE = "MDRP"
Announce.SYMBOL = "Target"
Announce.COLOR = { r = 0.2, g = 0.55, b = 0.2, a = 1 }
-- Reconnaissance : code de 4 caractères (ignoré par ISRadioInteractions) et
-- symbole vanilla distinct (MapSymbolDefinitions).
Announce.RECON_CODE = "MDRC"
Announce.RECON_SYMBOL = "Eye"
Announce.RECON_COLOR = { r = 0.15, g = 0.35, b = 0.75, a = 1 }
-- Nettoyage : autre code, autre symbole vanilla, autre couleur.
Announce.CLEANUP_CODE = "MDCU"
Announce.CLEANUP_SYMBOL = "Skull"
Announce.CLEANUP_COLOR = { r = 0.75, g = 0.15, b = 0.1, a = 1 }
Announce.MAYDAY_CODE = "MDAY"
Announce.MAYDAY_SYMBOL = "Question"
Announce.MAYDAY_COLOR = { r = 0.85, g = 0.35, b = 0.1, a = 1 }
-- Radio posée : OnDeviceText donne sa position, même loin du joueur (solo).
Announce.HEARING_DISTANCE = 5
-- Durée (ms réelles) pendant laquelle une grille annoncée attend d'être
-- entendue, comptée à l'annonce suivante.
Announce.PENDING_MS = 5 * 60 * 1000

-- Grilles annoncées pas encore entendues : { x, y, at }.
local pendingDrops = {}
-- Dernière mission annoncée par type (recon, cleanup) : { id, x, y, marked }.
local lastMission = {}
-- Missions déjà marquées (id → true) : une fois par mission. Les id
-- (« M<n> ») sont communs aux types.
local markedMissions = {}
local symbolsApi = nil

-- Repère de chaque type de mission : code de ligne, symbole, couleur.
local MISSION_MARKS = {
    { kind = "recon", code = "RECON_CODE", symbol = "RECON_SYMBOL", color = "RECON_COLOR" },
    { kind = "cleanup", code = "CLEANUP_CODE", symbol = "CLEANUP_SYMBOL", color = "CLEANUP_COLOR" },
    { kind = "mayday", code = "MAYDAY_CODE", symbol = "MAYDAY_SYMBOL", color = "MAYDAY_COLOR" },
}

local function addPending(x, y, now)
    local kept = {}
    for _, entry in ipairs(pendingDrops) do
        if now - entry.at <= Announce.PENDING_MS and not (entry.x == x and entry.y == y) then
            kept[#kept + 1] = entry
        end
    end
    kept[#kept + 1] = { x = x, y = y, at = now }
    pendingDrops = kept
end

--- Annonce d'un largage ({ x, y }) ou rappel de la base ({ grids }).
function Announce.onDropAnnounce(args)
    if type(args) ~= "table" then
        return
    end
    local now = getTimestampMs()
    if type(args.x) == "number" and type(args.y) == "number" then
        addPending(args.x, args.y, now)
    end
    if type(args.grids) == "table" then
        for _, grid in ipairs(args.grids) do
            if type(grid) == "table" and type(grid.x) == "number" and type(grid.y) == "number" then
                addPending(grid.x, grid.y, now)
            end
        end
    end
end

local function onMissionAnnounce(kind, args)
    if type(args) == "table" and type(args.id) == "string" and type(args.x) == "number"
        and type(args.y) == "number" then
        lastMission[kind] = { id = args.id, x = args.x, y = args.y, marked = markedMissions[args.id] == true }
    end
end

function Announce.onMaydayAnnounce(args)
    if type(args) == "table" then
        onMissionAnnounce("mayday", { id = "W" .. tostring(args.id), x = args.x, y = args.y })
    end
end

function Announce.onReconAnnounce(args)
    onMissionAnnounce("recon", args)
end

function Announce.onCleanupAnnounce(args)
    onMissionAnnounce("cleanup", args)
end

local function getSymbolsApi()
    if not symbolsApi then
        local ui = {}
        ui.javaObject = UIWorldMap.new(ui)
        local mapApi = ui.javaObject:getAPIv3()
        mapApi:setMapItem(MapItem.getSingleton())
        symbolsApi = mapApi:getSymbolsAPIv2()
    end
    return symbolsApi
end

--- Ajoute le symbole (par défaut celui du largage), sauf s'il existe déjà à
--- cet endroit.
function Announce.markMap(x, y, symbolId, color)
    symbolId = symbolId or Announce.SYMBOL
    local api = getSymbolsApi()
    for i = 0, api:getSymbolCount() - 1 do
        local symbol = api:getSymbolByIndex(i)
        if symbol:isTexture() and symbol:getSymbolID() == symbolId
            and math.floor(symbol:getWorldX()) == x and math.floor(symbol:getWorldY()) == y then
            return false
        end
    end
    local symbol = api:addTexture(symbolId, x, y)
    local c = color or Announce.COLOR
    symbol:setRGBA(c.r, c.g, c.b, c.a)
    symbol:setAnchor(0.5, 0.5)
    return true
end

--- Un joueur local entend l'appareil : radio portée (x = -1), ou posée assez près.
local function heardByLocalPlayer(x, y, z)
    if x == -1 then
        return true
    end
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        -- OnDeviceText donne des flottants (getX/getY/getZ de l'appareil).
        if player and math.floor(player:getZ()) == math.floor(z)
            and math.abs(player:getX() - x) <= Announce.HEARING_DISTANCE
            and math.abs(player:getY() - y) <= Announce.HEARING_DISTANCE then
            return true
        end
    end
    return false
end

local function hasCode(codes, code)
    return type(codes) == "string" and string.find(codes, code, 1, true) ~= nil
end

function Announce.onDeviceText(_, codes, x, y, z)
    local drop = #pendingDrops > 0 and hasCode(codes, Announce.CODE)
    local missions = {}
    for _, mark in ipairs(MISSION_MARKS) do
        local mission = lastMission[mark.kind]
        if mission and not mission.marked and hasCode(codes, Announce[mark.code]) then
            missions[#missions + 1] = { mission = mission, mark = mark }
        end
    end
    if not (drop or #missions > 0) or not heardByLocalPlayer(x, y, z) then
        return
    end
    if drop then
        local heard = pendingDrops
        pendingDrops = {}
        for _, entry in ipairs(heard) do
            Announce.markMap(entry.x, entry.y)
            MilitaryDrop.log("drop marked on the map at " .. entry.x .. "," .. entry.y)
        end
    end
    for _, entry in ipairs(missions) do
        local mission, mark = entry.mission, entry.mark
        mission.marked = true
        markedMissions[mission.id] = true
        Announce.markMap(mission.x, mission.y, Announce[mark.symbol], Announce[mark.color])
        MilitaryDrop.log(mark.kind .. " " .. mission.id .. " marked on the map at " .. mission.x .. "," .. mission.y)
    end
end

Events.OnDeviceText.Add(Announce.onDeviceText)

return Announce
