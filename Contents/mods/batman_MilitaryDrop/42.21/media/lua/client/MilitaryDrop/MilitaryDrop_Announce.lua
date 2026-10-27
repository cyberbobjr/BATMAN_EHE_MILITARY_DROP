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
-- « Skull » rouge au centre de la zone et cercle du rayon (C09) : symbole
-- vanilla « Circle » mis à l'échelle. Une icône d'échelle s couvre 20 × s
-- cases à tout zoom (WorldMapBaseSymbol.getDisplayScale) ; l'anneau de
-- map_o.png occupe environ 50 pixels sur 64. Même couleur que la tête de
-- mort, un peu transparent ; retiré avec elle (MarksActive). Mini-carte :
-- l'échelle y est ignorée, le cercle y reste une petite icône.
--
-- Une mission ouverte est rappelée par la base comme un largage (option
-- DropRepeatHours, Missions.remind) : même annonce, même code. La réponse de
-- la base à un échange qui cite la grille (reconnaissance trop loin, point du
-- nettoyage) porte mark = { kind, id, x, y } : la radio du joueur l'a dite,
-- le repère est posé (Announce.markMission, appelé par Exchange.onReply).
--
-- Repères périmés (C10) : le serveur envoie la liste des grilles encore
-- actives (MarksActive { drops, recon, cleanup }, à l'arrivée et à chaque
-- changement). Les symboles du mod qui n'y sont plus sont retirés : un
-- symbole du mod se reconnaît à son identifiant et à sa couleur, sauvegardée
-- octet par octet (WorldMapBaseSymbol.save/load) ; l'interface vanilla ne
-- propose aucune de ces couleurs (ISWorldMapSymbols.lua:1098-1103). Les
-- repères de MAYDAY (secteur d'épave, sans fin définie) restent.
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
-- Cercle du rayon du nettoyage : symbole vanilla, signé par la couleur de la
-- tête de mort (aucune couleur de l'interface vanilla).
Announce.CLEANUP_CIRCLE_SYMBOL = "Circle"
Announce.CLEANUP_CIRCLE_COLOR = { r = 0.75, g = 0.15, b = 0.1, a = 0.8 }
-- Diamètre (cases) de l'anneau du symbole « Circle » à l'échelle 1.
Announce.CIRCLE_RING_TILES = 20 * 50 / 64
Announce.MAYDAY_CODE = "MDAY"
Announce.MAYDAY_SYMBOL = "Question"
Announce.MAYDAY_COLOR = { r = 0.85, g = 0.35, b = 0.1, a = 1 }
Announce.RELAY_CODE = "MDRL"
Announce.RELAY_SYMBOL = "Exclamation"
Announce.RELAY_COLOR = { r = 0.9, g = 0.65, b = 0.12, a = 1 }
Announce.SECURED_SYMBOL = "Checkmark"
Announce.SECURED_COLOR = { r = 0.12, g = 0.68, b = 0.32, a = 1 }
-- Radio posée : OnDeviceText donne sa position, même loin du joueur (solo).
Announce.HEARING_DISTANCE = 5
-- Durée (ms réelles) pendant laquelle une grille annoncée attend d'être
-- entendue, comptée à l'annonce suivante.
Announce.PENDING_MS = 5 * 60 * 1000
-- Écart toléré sur une composante de couleur relue (octet : 1/255).
Announce.COLOR_TOLERANCE = 0.006

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
    { kind = "relay", code = "RELAY_CODE", symbol = "RELAY_SYMBOL", color = "RELAY_COLOR" },
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
        lastMission[kind] = { id = args.id, x = args.x, y = args.y, radius = tonumber(args.radius),
            marked = markedMissions[args.id] == true }
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

--- Cercle du rayon d'un nettoyage centré sur (x, y), sauf s'il existe déjà
--- (même symbole, même place, même couleur : un cercle du joueur ne compte pas).
function Announce.markCircle(x, y, radius)
    radius = tonumber(radius)
    if not radius or radius <= 0 then
        return false
    end
    local c = Announce.CLEANUP_CIRCLE_COLOR
    local api = getSymbolsApi()
    for i = 0, api:getSymbolCount() - 1 do
        local symbol = api:getSymbolByIndex(i)
        if symbol:isTexture() and symbol:getSymbolID() == Announce.CLEANUP_CIRCLE_SYMBOL
            and math.floor(symbol:getWorldX()) == x and math.floor(symbol:getWorldY()) == y
            and math.abs(symbol:getRed() - c.r) <= Announce.COLOR_TOLERANCE
            and math.abs(symbol:getGreen() - c.g) <= Announce.COLOR_TOLERANCE
            and math.abs(symbol:getBlue() - c.b) <= Announce.COLOR_TOLERANCE then
            return false
        end
    end
    local symbol = api:addTexture(Announce.CLEANUP_CIRCLE_SYMBOL, x, y)
    symbol:setRGBA(c.r, c.g, c.b, c.a)
    symbol:setAnchor(0.5, 0.5)
    symbol:setScale(2 * radius / Announce.CIRCLE_RING_TILES)
    return true
end

--- Symbole d'une mission (et cercle du rayon pour un nettoyage).
local function markMissionSymbols(entry, x, y, radius)
    Announce.markMap(x, y, Announce[entry.symbol], Announce[entry.color])
    if entry.kind == "cleanup" then
        Announce.markCircle(x, y, radius)
    end
end

--- Repère d'une mission dont la radio du joueur vient de dire la grille
--- (réponse de la base) : { kind = "recon" | "cleanup", id, x, y, radius }.
--- Une fois par mission, comme l'annonce.
function Announce.markMission(mark)
    if type(mark) ~= "table" or type(mark.id) ~= "string" or type(mark.x) ~= "number"
        or type(mark.y) ~= "number" then
        return false
    end
    for _, entry in ipairs(MISSION_MARKS) do
        if entry.kind == mark.kind then
            if markedMissions[mark.id] then
                return false
            end
            markedMissions[mark.id] = true
            local mission = lastMission[mark.kind]
            if mission and mission.id == mark.id then
                mission.marked = true
            end
            markMissionSymbols(entry, mark.x, mark.y, mark.radius or (mission and mission.radius))
            MilitaryDrop.log(mark.kind .. " " .. mark.id .. " marked on the map from the base reply")
            return true
        end
    end
    return false
end

function Announce.onRelayState(args)
    if type(args) ~= "table" or args.phase ~= "failed" or type(args.serial) ~= "number" then return false end
    local relay = MilitaryDrop.Relay
    local site = relay and relay.SITES[args.site]
    if not site then return false end
    return Announce.markMission({ kind = "relay", id = "relay:" .. tostring(args.serial), x = site.x, y = site.y })
end

local function sameColor(symbol, c)
    local tolerance = Announce.COLOR_TOLERANCE
    return math.abs(symbol:getRed() - c.r) <= tolerance and math.abs(symbol:getGreen() - c.g) <= tolerance
        and math.abs(symbol:getBlue() - c.b) <= tolerance
end

-- Repères retirables : symbole, couleur, champ de MarksActive.
local REMOVABLE = {
    { symbol = "SYMBOL", color = "COLOR", field = "drops" },
    { symbol = "RECON_SYMBOL", color = "RECON_COLOR", field = "recon" },
    { symbol = "CLEANUP_SYMBOL", color = "CLEANUP_COLOR", field = "cleanup" },
    { symbol = "CLEANUP_CIRCLE_SYMBOL", color = "CLEANUP_CIRCLE_COLOR", field = "cleanup" },
    { symbol = "RELAY_SYMBOL", color = "RELAY_COLOR", field = "relay" },
    { symbol = "SECURED_SYMBOL", color = "SECURED_COLOR", field = "secured" },
}

local function activeSet(list)
    local set = {}
    for _, grid in ipairs(type(list) == "table" and list or {}) do
        if type(grid) == "table" and type(grid.x) == "number" and type(grid.y) == "number" then
            set[math.floor(grid.x) .. "," .. math.floor(grid.y)] = true
        end
    end
    return set
end

--- Grilles encore actives (MarksActive) : retire les repères du mod qui n'y
--- sont plus (largage ouvert, vidé ou perdu, mission close). Renvoie le
--- nombre de symboles retirés.
function Announce.onActiveMarks(args)
    if type(args) ~= "table" then
        return 0
    end
    local kinds = {}
    for _, entry in ipairs(REMOVABLE) do
        kinds[#kinds + 1] = { symbol = Announce[entry.symbol], color = Announce[entry.color],
            active = activeSet(args[entry.field]) }
    end
    local api = getSymbolsApi()
    local removed = 0
    for i = api:getSymbolCount() - 1, 0, -1 do
        local symbol = api:getSymbolByIndex(i)
        if symbol:isTexture() then
            local id = symbol:getSymbolID()
            for _, kind in ipairs(kinds) do
                if id == kind.symbol and sameColor(symbol, kind.color) then
                    local key = math.floor(symbol:getWorldX()) .. "," .. math.floor(symbol:getWorldY())
                    if not kind.active[key] then
                        api:removeSymbolByIndex(i)
                        removed = removed + 1
                    end
                    break
                end
            end
        end
    end
    if removed > 0 then
        MilitaryDrop.log("removed " .. removed .. " outdated map marker(s)")
    end
    -- Active reconnaissance orders must remain locatable even if their radio announcement was missed.
    for _, grid in ipairs(type(args.recon) == "table" and args.recon or {}) do
        if type(grid) == "table" and type(grid.x) == "number" and type(grid.y) == "number" then
            Announce.markMap(math.floor(grid.x), math.floor(grid.y), Announce.RECON_SYMBOL, Announce.RECON_COLOR)
        end
    end
    for _, grid in ipairs(type(args.secured) == "table" and args.secured or {}) do
        if type(grid) == "table" and type(grid.x) == "number" and type(grid.y) == "number" then
            Announce.markMap(math.floor(grid.x), math.floor(grid.y), Announce.SECURED_SYMBOL, Announce.SECURED_COLOR)
        end
    end
    local cleanup = lastMission.cleanup
    if cleanup and not activeSet(args.cleanup)[math.floor(cleanup.x) .. "," .. math.floor(cleanup.y)] then
        lastMission.cleanup = nil
    end
    return removed
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
        markMissionSymbols(mark, mission.x, mission.y, mission.radius)
        MilitaryDrop.log(mark.kind .. " " .. mission.id .. " marked on the map at " .. mission.x .. "," .. mission.y)
    end
end

Events.OnDeviceText.Add(Announce.onDeviceText)

return Announce
