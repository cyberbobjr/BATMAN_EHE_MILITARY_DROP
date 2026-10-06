-- ============================================================================
-- Military Drop — fichier des zones de largage (idée 11, ZONE-02 et ZONE-08,
-- serveur MP ou solo)
--
-- L'admin d'un serveur PvP définit les zones où tombent les caisses (option
-- DropPlacement, MilitaryDrop_Zones.lua) dans Zomboid/Lua/MilitaryDrop/
-- dropzones.txt : même dossier, même lecteur et mêmes garde-fous que
-- requisition.txt (MilitaryDrop_LotsFile.lua : getFileReader/getFileWriter
-- dans getCacheDir()/Lua, extension .txt imposée, LotsFile.parse sans aucune
-- exécution). Le fichier est commun à toutes les parties du compte système :
-- le champ map (noms de dossiers séparés par « ; », comme Map= ;
-- pz-knowledge map-files.md) lie les zones à une carte. Une zone dont une
-- carte attendue n'est pas chargée est ignorée, avec un avertissement.
-- « Chargée » = dans les dossiers de lots de la partie (getLotDirectories,
-- LuaManager.java:6854-6857) : sans « ; », Map= ne nomme que la carte
-- principale et le moteur ajoute récursivement les lots= de son map.info
-- (IsoMetaGrid.java:1775-1815) ; une carte de mod qui inclut la carte
-- vanilla la charge donc sans la nommer. Repli : getWorld():getMap().
--
-- Modèle : secteur (texte libre, une ville) → zones { id, sector, name,
-- x1, y1, x2, y2, weight, enabled, map }. Rectangle au niveau 0, coins
-- COMPRIS (côté = x2 - x1 + 1, de 1 à MAX_SIDE). Les zones non-PvP et les
-- refuges vanilla excluent au contraire leur bord haut (NonPvpZone :
-- x < getX2(), NonPvpZone.java:70-77 ; SafeHouse : getX2() = x + w,
-- SafeHouse.java:558-564 et getSafehouseOverlapping, :168-174) : les
-- comparaisons ci-dessous en tiennent compte.
--
-- Validation : une erreur de syntaxe (numéro de ligne de LotsFile.parse) ou
-- un fichier trop long = aucune zone (repli : villes vanilla, puis
-- proximité) ; une zone invalide est écartée (« zone #3 (z3): … ») ; au plus
-- MAX_ZONES zones. Chaque problème part au journal ([MilitaryDrop], toujours)
-- et dans le rapport (liste de l'outil d'admin, en-tête des problèmes du
-- fichier). Les constats sur une zone VALIDE (carte non chargée, codes du
-- diagnostic ci-dessous) ne sont pas des problèmes du fichier (retour de
-- l'utilisateur, 2026-10-06 : l'en-tête rouge laissait croire à une erreur à
-- chaque création) : ligne « note: » au journal et codes sur la ligne de la
-- zone dans l'outil (zone.warnings), jamais dans report.problems.
--
-- Diagnostic (ZONE-08), au chargement et à chaque création : surface,
-- bâtiments, présence sur la carte (métagrille), terrain libre, chevauchement
-- d'une zone non-PvP (NonPvpZone.getAllZones, exposée : LuaManager.java:2461)
-- ou d'un refuge (SafeHouse, exposée : LuaManager.java:2053). Les deux listes
-- sont lues de map_meta.bin par IsoMetaGrid.load (IsoMetaGrid.java:1064-1075),
-- appelé par IsoWorld.init (IsoWorld.java:1952) avant OnServerStarted
-- (GameServer.java:1461) et OnGameStart (IngameState.java:849). Codes :
-- offMap, mapNotLoaded, noGround (aucune case échantillonnée hors bâtiment et
-- hors de l'eau connue : ZonesFile.hasOpenGround), nonPvp, safehouse. Les
-- anciens codes noRoad et risk (zone sans route) ont disparu le 2026-10-06 :
-- la caisse tombe n'importe où dans la zone hors bâtiment et hors de l'eau
-- (MilitaryDrop_Zones.lua, Zones.pointInZone), une route n'est plus utile.
--
-- Eau d'une case non chargée : la métagrille ne la connaît qu'en partie. La
-- génération des zones de cueillette (ZoneGenerator.genForaging,
-- ZoneGenerator.java:59-138), lancée au premier chargement d'un chunk d'une
-- cellule (IsoChunk.java:2219-2221 ; serveur : ServerChunkLoader.java:153),
-- inscrit pour TOUTE la cellule (256 × 256) des zones rectangulaires
-- « Water » au grain du chunk (8 × 8 : un chunk dont un pixel de la
-- biomemap est de l'eau, BiomeMapConfig.lua pixel 0), sauvegardées dans
-- map_zone.bin (IsoMetaGrid.java:1451-1454, 1711-1722). Une cellule jamais
-- approchée par un joueur de cette partie n'en a aucune : eau inconnue, la
-- livraison reste le seul contrôle sûr. La biomemap elle-même (BiomeMap,
-- int[]) et IsoWaterFlow ne sont pas exposées à Lua (LuaManager.java).
--
-- Écriture (outil d'admin, MilitaryDrop_Zones.lua : ZoneAdd, ZoneUpdate,
-- ZoneSetEnabled, ZoneDelete) : le serveur RELIT le
-- fichier avant chaque modification (une édition manuelle faite pendant que
-- le serveur tourne est la base de la réécriture), réécrit tout le fichier
-- (notice, puis la table formatée ; ids, champs inconnus simples et zones
-- invalides gardés), puis le relit. Code « syntaxError » (rien n'est écrit,
-- raison au journal et dans les problèmes de la liste) : fichier illisible
-- ou trop long, erreur de syntaxe, ou contenu que la réécriture perdrait
-- (ZonesFile.rewriteProblem : champ inconnu de premier niveau, map qui n'est
-- pas un texte valable, zones qui ne sont pas une liste sans trou, entrée
-- qui n'est pas une table, valeur table ou clé non simple dans une zone,
-- nombre non fini comme 1e999). Un texte qui dépasserait ce que le lecteur
-- accepte (LotsFile.MAX_LINES, MAX_CHARS) n'est pas écrit (« writeFailed »).
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_LotsFile"

local ZonesFile = {}
MilitaryDrop.ZonesFile = ZonesFile

ZonesFile.PATH = "MilitaryDrop/dropzones.txt"
ZonesFile.VERSION = 1
ZonesFile.MAX_ZONES = 200
ZonesFile.MAX_ID = 16
ZonesFile.MAX_TEXT = 32
ZonesFile.MIN_SIDE = 1
ZonesFile.MAX_SIDE = 300
ZonesFile.MAX_WEIGHT = 100
ZonesFile.MAX_MAP = 512
-- Garde-fou des coordonnées lues (la carte vanilla tient sous 20 000).
ZonesFile.MAX_COORD = 1000000
ZonesFile.CELL_SIZE = 256
-- Types des zones d'eau de la métagrille (BiomeMapConfig.lua : « Water » ;
-- « WaterNoFish » y est en commentaire, gardé si une carte l'active).
ZonesFile.WATER_ZONES = { Water = true, WaterNoFish = true }
-- Échantillons par côté au plus pour le diagnostic noGround (24 × 24).
ZonesFile.GROUND_SAMPLES = 24
-- Ordre d'écriture des champs d'une zone.
ZonesFile.FIELDS = { "id", "sector", "name", "x1", "y1", "x2", "y2", "weight", "enabled", "map" }

local KNOWN = {}
for _, field in ipairs(ZonesFile.FIELDS) do
    KNOWN[field] = true
end

-- Dernier chargement (voir ZonesFile.load), nil avant le premier usage.
local current = nil

-- ----------------------------------------------------------------------------
-- Textes, cartes
-- ----------------------------------------------------------------------------

local function trim(text)
    local result = text:gsub("^%s+", ""):gsub("%s+$", "")
    return result
end

--- Texte affiché (secteur, nom) : sans caractère de contrôle ni balise,
--- espaces resserrés ; nil s'il est vide ou trop long (MAX_TEXT caractères).
function ZonesFile.cleanText(text)
    if type(text) ~= "string" then
        return nil
    end
    local cleaned = trim((text:gsub("%c", " "):gsub("[<>]", ""):gsub("%s+", " ")))
    if cleaned == "" or MilitaryDrop.cutText(cleaned, ZonesFile.MAX_TEXT) ~= cleaned then
        return nil
    end
    return cleaned
end

--- Noms de cartes d'un texte « A;B » (espaces autour retirés, vides ignorés).
function ZonesFile.splitMaps(text)
    local list = {}
    for name in string.gmatch(tostring(text or ""), "[^;]+") do
        name = trim(name)
        if name ~= "" then
            list[#list + 1] = name
        end
    end
    return list
end

--- Cartes de la partie telles que Map= les nomme (getWorld():getMap(),
--- IsoWorld.java:593), ou "" : valeur écrite par l'outil dans le fichier.
function ZonesFile.currentMap()
    local map = getWorld():getMap()
    return map and tostring(map) or ""
end

-- Dossiers de lots chargés, recalculés quand getMap() change : { map, set, list }.
local loadedCache = nil

--- Dossiers de lots réellement chargés : ensemble { [nom] = true } et liste.
--- getLotDirectories (global, LuaManager.java:6854-6857) suit les lots= des
--- map.info (IsoMetaGrid.java:1775-1815) ; il lève une exception pour une
--- carte « DEFAULT » à plusieurs mondes (IsoMetaGrid.java:1796-1802), d'où le
--- pcall et le repli sur les noms de getMap().
function ZonesFile.loadedMaps()
    local map = ZonesFile.currentMap()
    if loadedCache and loadedCache.map == map then
        return loadedCache.set, loadedCache.list
    end
    local list = nil
    if type(getLotDirectories) == "function" then
        local ok, dirs = pcall(getLotDirectories)
        if ok and dirs and dirs.size and dirs:size() > 0 then
            list = {}
            for i = 0, dirs:size() - 1 do
                local name = trim(tostring(dirs:get(i)))
                if name ~= "" then
                    list[#list + 1] = name
                end
            end
        end
    end
    list = list or ZonesFile.splitMaps(map)
    local set = {}
    for _, name in ipairs(list) do
        set[name] = true
    end
    loadedCache = { map = map, set = set, list = list }
    return set, list
end

--- Cartes attendues par spec et absentes de la partie (liste, vide si toutes y sont).
function ZonesFile.missingMaps(spec)
    local loaded = ZonesFile.loadedMaps()
    local missing = {}
    for _, name in ipairs(ZonesFile.splitMaps(spec)) do
        if not loaded[name] then
            missing[#missing + 1] = name
        end
    end
    return missing
end

-- ----------------------------------------------------------------------------
-- Validation
-- ----------------------------------------------------------------------------

local function isInteger(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end

--- Rectangle entier normalisé { x1, y1, x2, y2 } (x1 ≤ x2, y1 ≤ y2, coins
--- compris), ou nil, le code d'erreur de l'outil (invalid, tooBig, tooSmall)
--- et le message du journal.
function ZonesFile.normalizeRect(x1, y1, x2, y2)
    local max = ZonesFile.MAX_COORD
    for _, value in ipairs({ x1, y1, x2, y2 }) do
        if not isInteger(value, -max, max) then
            return nil, "invalid", "x1, y1, x2, y2 must be whole numbers"
        end
    end
    -- Quatre valeurs non nil : ipairs les a toutes vues.
    if x1 == nil or y1 == nil or x2 == nil or y2 == nil then
        return nil, "invalid", "x1, y1, x2, y2 must be whole numbers"
    end
    if x1 > x2 then
        x1, x2 = x2, x1
    end
    if y1 > y2 then
        y1, y2 = y2, y1
    end
    local w, h = x2 - x1 + 1, y2 - y1 + 1
    if w > ZonesFile.MAX_SIDE or h > ZonesFile.MAX_SIDE then
        return nil, "tooBig", "the rectangle is " .. w .. " x " .. h .. " tiles (" .. ZonesFile.MAX_SIDE
            .. " at most on each side)"
    end
    if w < ZonesFile.MIN_SIDE or h < ZonesFile.MIN_SIDE then
        return nil, "tooSmall", "the rectangle is " .. w .. " x " .. h .. " tiles"
    end
    return { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

--- Identifiant de zone valable.
function ZonesFile.isId(id)
    return type(id) == "string" and #id >= 1 and #id <= ZonesFile.MAX_ID and id:match("^[%w_%-]+$") ~= nil
end

--- Zone validée (copie normalisée), ou nil et l'erreur (anglais, journal).
function ZonesFile.validateZone(entry)
    if type(entry) ~= "table" then
        return nil, "a zone must be a table { id = ..., sector = ..., name = ..., x1 = ..., ... }"
    end
    for key in pairs(entry) do
        if not KNOWN[key] then
            return nil, "unknown field " .. tostring(key)
        end
    end
    if not ZonesFile.isId(entry.id) then
        return nil, "id must be a name (letters, digits, _ and -; " .. ZonesFile.MAX_ID .. " characters at most)"
    end
    local sector = ZonesFile.cleanText(entry.sector)
    if not sector then
        return nil, "sector must be a non-empty text (" .. ZonesFile.MAX_TEXT .. " characters at most)"
    end
    local name = ZonesFile.cleanText(entry.name)
    if not name then
        return nil, "name must be a non-empty text (" .. ZonesFile.MAX_TEXT .. " characters at most)"
    end
    local rect, _, why = ZonesFile.normalizeRect(entry.x1, entry.y1, entry.x2, entry.y2)
    if not rect then
        return nil, why
    end
    local weight = entry.weight
    if weight == nil then
        weight = 1
    elseif not isInteger(weight, 1, ZonesFile.MAX_WEIGHT) then
        return nil, "weight must be a whole number from 1 to " .. ZonesFile.MAX_WEIGHT
    end
    if entry.enabled ~= nil and type(entry.enabled) ~= "boolean" then
        return nil, "enabled must be true or false"
    end
    if entry.map ~= nil and (type(entry.map) ~= "string" or #entry.map > ZonesFile.MAX_MAP) then
        return nil, "map must be a text: map folders separated by ;"
    end
    return { id = entry.id, sector = sector, name = name, x1 = rect.x1, y1 = rect.y1, x2 = rect.x2, y2 = rect.y2,
        weight = weight, enabled = entry.enabled ~= false, map = entry.map }
end

-- ----------------------------------------------------------------------------
-- Métagrille, zones non-PvP, refuges (ZONE-08)
-- ----------------------------------------------------------------------------

local function cellsOf(rect)
    local size = ZonesFile.CELL_SIZE
    return math.floor(rect.x1 / size), math.floor(rect.y1 / size), math.floor(rect.x2 / size),
        math.floor(rect.y2 / size)
end

--- Le rectangle est entièrement sur la carte : coins valides
--- (IsoMetaGrid.isValidSquare, bornes seules : IsoMetaGrid.java:1199-1210)
--- et chaque cellule couverte présente (getCellData).
function ZonesFile.isOnGrid(grid, rect)
    if not grid:isValidSquare(rect.x1, rect.y1) or not grid:isValidSquare(rect.x2, rect.y2) then
        return false
    end
    local cx1, cy1, cx2, cy2 = cellsOf(rect)
    for cy = cy1, cy2 do
        for cx = cx1, cx2 do
            if not grid:getCellData(cx, cy) then
                return false
            end
        end
    end
    return true
end

--- Zone de la métagrille d'un type d'eau (WATER_ZONES).
function ZonesFile.isWaterZone(zone)
    return zone ~= nil and ZonesFile.WATER_ZONES[zone:getType()] == true
end

--- La case (x, y) est de l'eau connue de la métagrille (zone « Water » de la
--- biomemap, voir l'en-tête) ; faux si l'eau de sa cellule est inconnue.
--- IsoMetaGrid.getZonesAt(x, y, z) : IsoMetaGrid.java:210-220.
function ZonesFile.isKnownWater(grid, x, y)
    local zones = grid:getZonesAt(x, y, 0)
    for i = 0, zones:size() - 1 do
        if ZonesFile.isWaterZone(zones:get(i)) then
            return true
        end
    end
    return false
end

--- Rectangles d'eau connue qui recoupent rect : { { x1, y1, x2, y2 }, … }
--- (zones rectangulaires seules, comme celles de genForaging). Une zone de la
--- métagrille n'est rendue qu'une fois (IsoMetaChunk.getZonesIntersecting :
--- result.contains, IsoMetaChunk.java:213-218).
function ZonesFile.waterRects(grid, rect)
    local w, h = rect.x2 - rect.x1 + 1, rect.y2 - rect.y1 + 1
    local zones = grid:getZonesIntersecting(rect.x1, rect.y1, 0, w, h)
    local list = {}
    for i = 0, zones:size() - 1 do
        local zone = zones:get(i)
        if ZonesFile.isWaterZone(zone) and zone:isRectangle() and zone:getWidth() > 0 and zone:getHeight() > 0 then
            list[#list + 1] = { x1 = zone:getX(), y1 = zone:getY(), x2 = zone:getX() + zone:getWidth() - 1,
                y2 = zone:getY() + zone:getHeight() - 1 }
        end
    end
    return list
end

--- Le rectangle a au moins une case échantillonnée hors bâtiment (emprise du
--- BuildingDef, comme IsoMetaGrid.getBuildingAt(x, y),
--- IsoMetaGrid.java:262-269) et hors de l'eau connue. Échantillons : une case
--- sur step (au plus GROUND_SAMPLES par côté), arrêt au premier terrain libre.
--- buildings : ZonesFile.buildingsIn(grid, rect).
function ZonesFile.hasOpenGround(grid, rect, buildings)
    local covers = ZonesFile.waterRects(grid, rect)
    for _, b in ipairs(buildings) do
        local bx, by = b:getX(), b:getY()
        covers[#covers + 1] = { x1 = bx, y1 = by, x2 = bx + b:getW() - 1, y2 = by + b:getH() - 1 }
    end
    local w, h = rect.x2 - rect.x1 + 1, rect.y2 - rect.y1 + 1
    local step = math.max(1, math.ceil(math.max(w, h) / ZonesFile.GROUND_SAMPLES))
    for y = rect.y1, rect.y2, step do
        for x = rect.x1, rect.x2, step do
            local covered = false
            for _, c in ipairs(covers) do
                if x >= c.x1 and x <= c.x2 and y >= c.y1 and y <= c.y2 then
                    covered = true
                    break
                end
            end
            if not covered then
                return true
            end
        end
    end
    return false
end

--- Bâtiments (BuildingDef) qui recoupent le rectangle, hors sous-sols et
--- bâtiments tracés par les joueurs. Demandé cellule par cellule :
--- IsoMetaGrid.getBuildingsIntersecting parcourt toute la hauteur de la
--- grille (IsoMetaGrid.java:408-416) ; une même liste Java évite les doublons
--- (IsoMetaChunk.java:308-313, result.contains).
function ZonesFile.buildingsIn(grid, rect)
    local list = ArrayList.new()
    local w, h = rect.x2 - rect.x1 + 1, rect.y2 - rect.y1 + 1
    local cx1, cy1, cx2, cy2 = cellsOf(rect)
    for cy = cy1, cy2 do
        for cx = cx1, cx2 do
            local cell = grid:getCellData(cx, cy)
            if cell then
                cell:getBuildingsIntersecting(rect.x1, rect.y1, w, h, list)
            end
        end
    end
    local result = {}
    for i = 0, list:size() - 1 do
        local building = list:get(i)
        if not building:isUserDefined() and not building:isBasement() then
            result[#result + 1] = building
        end
    end
    return result
end

--- Le rectangle (coins compris) recoupe une zone non-PvP.
function ZonesFile.overlapsNonPvp(rect)
    if not NonPvpZone or not NonPvpZone.getAllZones then
        return false
    end
    local zones = NonPvpZone.getAllZones()
    for i = 0, zones:size() - 1 do
        local zone = zones:get(i)
        if rect.x1 < zone:getX2() and rect.x2 >= zone:getX() and rect.y1 < zone:getY2() and rect.y2 >= zone:getY() then
            return true
        end
    end
    return false
end

--- Le rectangle (coins compris) recoupe un refuge.
function ZonesFile.overlapsSafehouse(rect)
    if not SafeHouse or not SafeHouse.getSafehouseOverlapping then
        return false
    end
    return SafeHouse.getSafehouseOverlapping(rect.x1, rect.y1, rect.x2 + 1, rect.y2 + 1) ~= nil
end

--- La caisse posée au point (x, y) (cases x-1..x, y-1..y : Server.landingSquareAt)
--- toucherait une zone non-PvP ou un refuge.
function ZonesFile.isProtected(x, y)
    return ZonesFile.overlapsNonPvp({ x1 = x - 1, y1 = y - 1, x2 = x, y2 = y })
        or ZonesFile.overlapsSafehouse({ x1 = x - 1, y1 = y - 1, x2 = x, y2 = y })
end

--- Diagnostic d'une zone (ZONE-08) : codes d'avertissement et relevé
--- { area, buildings }. zone.mapLoaded == false : seul mapNotLoaded (la
--- métagrille est celle d'une autre carte).
function ZonesFile.diagnose(zone)
    local stats = { area = (zone.x2 - zone.x1 + 1) * (zone.y2 - zone.y1 + 1), buildings = 0 }
    if zone.mapLoaded == false then
        return { "mapNotLoaded" }, stats
    end
    local warnings = {}
    local grid = getWorld():getMetaGrid()
    if not ZonesFile.isOnGrid(grid, zone) then
        warnings[#warnings + 1] = "offMap"
    end
    local buildings = ZonesFile.buildingsIn(grid, zone)
    stats.buildings = #buildings
    if not ZonesFile.hasOpenGround(grid, zone, buildings) then
        warnings[#warnings + 1] = "noGround"
    end
    if ZonesFile.overlapsNonPvp(zone) then
        warnings[#warnings + 1] = "nonPvp"
    end
    if ZonesFile.overlapsSafehouse(zone) then
        warnings[#warnings + 1] = "safehouse"
    end
    return warnings, stats
end

local WARNING_TEXTS = {
    offMap = "partly or wholly off the map",
    noGround = "no open ground: buildings or known water everywhere, no crate can land there",
    nonPvp = "overlaps a non-PvP zone: no crate lands in that part",
    safehouse = "overlaps a safehouse: no crate lands in that part",
}

-- ----------------------------------------------------------------------------
-- Liste des zones
-- ----------------------------------------------------------------------------

--- Rapport d'une table lue : { zones (valides, ordre du fichier, avec
--- index, mapLoaded, active, warnings, stats), problems, notes, map,
--- mapLoaded }. problems : vraies erreurs du fichier (syntaxe, champ
--- inconnu, zone invalide écartée…), montrées à l'admin sous l'en-tête des
--- problèmes du fichier. notes : constats sur des zones valides (carte non
--- chargée, diagnostic ZONE-08), au journal seulement, à titre d'information ;
--- l'outil les montre sur la ligne de chaque zone (zone.warnings).
function ZonesFile.build(data)
    local report = { zones = {}, problems = {}, notes = {}, map = nil, mapLoaded = true }
    local problems, notes = report.problems, report.notes
    if type(data) ~= "table" then
        problems[1] = "the file must contain one table: no drop zone"
        return report
    end
    for key in pairs(data) do
        if key ~= "version" and key ~= "map" and key ~= "zones" then
            problems[#problems + 1] = "unknown top-level field " .. tostring(key) .. " ignored"
        end
    end
    if data.map ~= nil and (type(data.map) ~= "string" or #data.map > ZonesFile.MAX_MAP) then
        problems[#problems + 1] = "map must be a text (map folders separated by ;): ignored"
    elseif data.map ~= nil then
        report.map = data.map
        local missing = ZonesFile.missingMaps(data.map)
        report.mapLoaded = #missing == 0
        if not report.mapLoaded then
            local _, loaded = ZonesFile.loadedMaps()
            notes[#notes + 1] = "map " .. table.concat(missing, ";") .. " is not loaded in this save"
                .. " (loaded: " .. table.concat(loaded, ";") .. "): its zones are not used"
        end
    end
    local zones = data.zones
    if zones == nil then
        return report
    end
    if type(zones) ~= "table" then
        problems[#problems + 1] = "zones must be a list { { id = ... }, ... }: no drop zone"
        return report
    end
    local count = 0
    for _ in pairs(zones) do
        count = count + 1
    end
    if count ~= #zones then
        problems[#problems + 1] = "zones must be a plain list: entries with keys ignored"
    end
    local seen = {}
    for i, entry in ipairs(zones) do
        local id = type(entry) == "table" and type(entry.id) == "string" and entry.id or nil
        local where = "zone #" .. i .. (id and (" (" .. id .. ")") or "")
        local zone, err = ZonesFile.validateZone(entry)
        if zone and seen[zone.id] then
            zone, err = nil, "duplicate id"
        end
        if zone and #report.zones >= ZonesFile.MAX_ZONES then
            zone, err = nil, "more than " .. ZonesFile.MAX_ZONES .. " zones"
        end
        if zone then
            seen[zone.id] = true
            zone.index = i
            local spec = zone.map or report.map
            local missing = spec and ZonesFile.missingMaps(spec) or {}
            zone.mapLoaded = #missing == 0
            zone.active = zone.enabled and zone.mapLoaded
            zone.warnings, zone.stats = ZonesFile.diagnose(zone)
            if not zone.mapLoaded then
                if zone.map then
                    notes[#notes + 1] = where .. ": map " .. table.concat(missing, ";")
                        .. " is not loaded: zone not used"
                end
            else
                for _, code in ipairs(zone.warnings) do
                    notes[#notes + 1] = where .. ": " .. WARNING_TEXTS[code] .. " (" .. code .. ")"
                end
            end
            report.zones[#report.zones + 1] = zone
        else
            problems[#problems + 1] = where .. ": " .. tostring(err) .. "; zone ignored"
        end
    end
    return report
end

-- ----------------------------------------------------------------------------
-- Écriture
-- ----------------------------------------------------------------------------

local ESCAPES = { ["\n"] = "\\n", ["\\"] = "\\\\", ['"'] = '\\"' }

local function quote(text)
    return '"' .. text:gsub('[%c"\\]', function(c)
        return ESCAPES[c] or string.format("\\%03d", string.byte(c))
    end) .. '"'
end

--- Nombre fini (ni NaN ni ±inf : Kahlua les écrit « nan », « inf »,
--- KahluaUtil.numberToString, que LotsFile.parse refuse).
local function isFinite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function formatValue(value)
    if type(value) == "number" then
        -- Écarté plus tôt par rewriteProblem : ne jamais rendre le fichier illisible.
        if not isFinite(value) then
            error("MilitaryDrop: non-finite number in " .. ZonesFile.PATH)
        end
        if value == math.floor(value) and math.abs(value) < 1e15 then
            return string.format("%d", value)
        end
        return tostring(value)
    elseif type(value) == "string" then
        return quote(value)
    end
    return tostring(value)
end

local function formatKey(key)
    if type(key) == "string" and key:match("^[%a_][%w_]*$") then
        return key
    end
    return "[" .. formatValue(key) .. "]"
end

--- Valeur simple que formatZone réécrit telle quelle.
local function isScalar(value)
    local kind = type(value)
    return kind == "string" or kind == "boolean" or isFinite(value)
end

--- Raison (anglais, journal) pour laquelle la réécriture de la table lue
--- perdrait ou abîmerait une partie du fichier, ou nil : l'outil refuse
--- alors d'écrire (ZONE-03, aucune perte silencieuse d'une édition manuelle).
function ZonesFile.rewriteProblem(raw)
    if type(raw) ~= "table" then
        return "the file must contain one table"
    end
    for key in pairs(raw) do
        if key ~= "version" and key ~= "map" and key ~= "zones" then
            return "unknown top-level field " .. tostring(key)
        end
    end
    if raw.version ~= nil and not isFinite(raw.version) then
        return "version must be a number"
    end
    if raw.map ~= nil and (type(raw.map) ~= "string" or #raw.map > ZonesFile.MAX_MAP) then
        return "map must be a text of " .. ZonesFile.MAX_MAP .. " characters at most"
    end
    local zones = raw.zones
    if zones == nil then
        return nil
    end
    if type(zones) ~= "table" then
        return "zones must be a list"
    end
    -- Liste sans trou ni clé : chaque clé est un entier 1..count.
    local count = 0
    for _ in pairs(zones) do
        count = count + 1
    end
    for key, entry in pairs(zones) do
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or key > count then
            return "zones must be a plain list (entry " .. tostring(key) .. ")"
        end
        if type(entry) ~= "table" then
            return "zone #" .. key .. " is not a table"
        end
        for field, value in pairs(entry) do
            if type(field) ~= "string" and not isFinite(field) then
                return "zone #" .. key .. ": field " .. tostring(field) .. " cannot be rewritten"
            end
            if not isScalar(value) then
                return "zone #" .. key .. ": value of " .. tostring(field) .. " cannot be rewritten ("
                    .. (type(value) == "number" and tostring(value) or type(value)) .. ")"
            end
        end
    end
    return nil
end

--- Le texte serait relu en entier (garde-fous de LotsFile.readText : lignes
--- et caractères, saut de ligne compris).
function ZonesFile.fitsReader(text)
    local _, newlines = text:gsub("\n", "")
    local LotsFile = MilitaryDrop.LotsFile
    return newlines + 1 <= LotsFile.MAX_LINES and #text + 1 <= LotsFile.MAX_CHARS
end

--- Une zone sur une ligne : champs connus dans l'ordre, puis les autres
--- valeurs simples (zone invalide gardée telle quelle ; rewriteProblem
--- écarte d'avance les tables et les clés non simples).
local function formatZone(entry)
    local parts = {}
    for _, key in ipairs(ZonesFile.FIELDS) do
        local value = entry[key]
        if value ~= nil and type(value) ~= "table" and type(value) ~= "function" then
            parts[#parts + 1] = key .. " = " .. formatValue(value)
        end
    end
    local extra = {}
    for key, value in pairs(entry) do
        local kind = type(value)
        if not KNOWN[key] and (type(key) == "string" or type(key) == "number")
            and (kind == "string" or kind == "number" or kind == "boolean") then
            extra[#extra + 1] = key
        end
    end
    table.sort(extra, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(extra) do
        parts[#parts + 1] = formatKey(key) .. " = " .. formatValue(entry[key])
    end
    return "        { " .. table.concat(parts, ", ") .. " },\n"
end

ZonesFile.NOTICE = [[
-- ============================================================================
-- Military Drop - drop zones
-- ============================================================================
--
-- Drop zones chosen by the admin, used when the sandbox option "Drop
-- placement" is "Zones" or "Zones if one is near". This file lives in the
-- Zomboid/Lua folder of the system account that runs the game or the server:
-- it is shared by EVERY single-player save and EVERY server started by this
-- account. "map" ties the zones to a map: a zone whose map is not loaded in
-- the current save is ignored.
--
-- Only data is read: one table, no code (functions, names and operators are
-- refused). A syntax error disables every zone: vanilla towns are used
-- instead (vanilla map only), else drops near the caller. An invalid zone is
-- skipped. Problems are written to the server console (console.txt),
-- "[MilitaryDrop]".
--
-- The admin tool in game (admin panel, "Military Drop zones" button) adds,
-- edits, enables, disables and deletes zones, then rewrites this whole file:
-- other comments are lost. It reads this file again before each change, and
-- refuses to write while the file has an error or anything it cannot write
-- back as it is (other top-level fields, tables inside a zone, numbers such
-- as 1e999), so that a manual edit is never overwritten.
--
-- Top-level fields:
--   map      maps the zones are drawn for: map folder names separated by ";",
--            as in the server's Map= line ("Muldraugh, KY"). A map counts as
--            loaded when the game loads its folder, even through another map
--            that includes it. Optional.
--   zones    list of zones.
-- Fields of a zone:
--   id       unique name: letters, digits, _ and -, 16 characters at most.
--   sector   group of zones, usually a town (32 characters at most). The
--            sector nearest to the caller is chosen (or one at random, see
--            the sandbox options), then one of its zones, weighted.
--   name     zone name, read in the radio announcement (32 characters).
--   x1, y1, x2, y2   rectangle on level 0, both corners included, 1 to 300
--            tiles on each side.
--   weight   1 to 100, default 1.
--   enabled  true or false, default true.
--   map      optional: replaces the top-level map for this zone.
-- The crate lands anywhere inside the rectangle (grass, field, sand, path,
-- road, parking lot...), never inside a building, never in water, never
-- outside. Water is checked when the area is loaded: a crate drawn over
-- water lands on the nearest dry ground of the zone, and a zone entirely on
-- water gives no crate. A zone overlapping a non-PvP zone or a safehouse is
-- reported, and no crate lands in the protected part.
--
-- Example (remove the leading "--" of each line inside "zones = { }"):
--   zones = {
--       { id = "z1", sector = "Louisville", name = "Central Park",
--         x1 = 12900, y1 = 2100, x2 = 12980, y2 = 2160, weight = 1, enabled = true },
--   },
--
-- Reload without restarting (admin): the tool's Reload button, or the
-- admin's debug console:
--   sendClientCommand(getPlayer(), "MilitaryDrop", "ZoneReload", {})
]]

--- Texte complet d'une table de zones : notice, version, carte, zones.
function ZonesFile.format(data)
    local parts = { ZonesFile.NOTICE, "return {\n    version = " .. ZonesFile.VERSION .. ",\n" }
    if type(data.map) == "string" then
        parts[#parts + 1] = "    map = " .. quote(data.map) .. ",\n"
    end
    parts[#parts + 1] = "    zones = {\n"
    for _, entry in ipairs(type(data.zones) == "table" and data.zones or {}) do
        if type(entry) == "table" then
            parts[#parts + 1] = formatZone(entry)
        end
    end
    parts[#parts + 1] = "    },\n}\n"
    return table.concat(parts)
end

--- Texte du fichier créé au premier démarrage : notice, aucune zone.
function ZonesFile.defaultText()
    return ZonesFile.format({ zones = {} })
end

--- Écrit le texte du fichier ; vrai s'il a pu l'être.
function ZonesFile.writeText(text)
    local writer = getFileWriter(ZonesFile.PATH, true, false)
    if not writer then
        MilitaryDrop.log("cannot write Zomboid/Lua/" .. ZonesFile.PATH, true)
        return false
    end
    writer:write(text)
    writer:close()
    return true
end

-- ----------------------------------------------------------------------------
-- Lecture, chargement
-- ----------------------------------------------------------------------------

--- Lit le fichier (le crée s'il manque) et installe les zones. Rapport :
--- { source = "file"|"created"|"unreadable"|"syntaxError", zones, problems,
--- map, mapLoaded, syntaxError (fichier illisible : aucune zone, outil
--- bloqué), raw (table lue, base de la réécriture), text (texte lu) }.
function ZonesFile.load()
    local text, readError = MilitaryDrop.LotsFile.readText(ZonesFile.PATH)
    local data, problem, source
    if text == nil then
        source = "created"
        data = { version = ZonesFile.VERSION, zones = {} }
        if ZonesFile.writeText(ZonesFile.defaultText()) then
            MilitaryDrop.log("drop zones file written to Zomboid/Lua/" .. ZonesFile.PATH .. " (no zone)", true)
        end
    elseif text == false then
        source = "unreadable"
        problem = tostring(readError) .. ": no drop zone"
    else
        local parseError
        data, parseError = MilitaryDrop.LotsFile.parse(text)
        if data then
            source = "file"
        else
            source = "syntaxError"
            problem = "syntax error, " .. tostring(parseError) .. ": no drop zone"
        end
    end
    local report
    if data then
        report = ZonesFile.build(data)
    else
        report = { zones = {}, problems = { problem }, map = nil, mapLoaded = true, syntaxError = true }
    end
    report.source = source
    report.raw = data
    -- Texte lu (lignes jointes par « \n », sans le dernier saut de ligne) :
    -- l'outil le remet tel quel s'il doit annuler une écriture.
    report.text = type(text) == "string" and text or nil
    local active = 0
    for _, zone in ipairs(report.zones) do
        if zone.active then
            active = active + 1
        end
    end
    report.activeCount = active
    for _, line in ipairs(report.problems) do
        MilitaryDrop.log(ZonesFile.PATH .. ": " .. line, true)
    end
    for _, line in ipairs(report.notes or {}) do
        MilitaryDrop.log(ZonesFile.PATH .. ": note: " .. line, true)
    end
    MilitaryDrop.log("drop zones: " .. #report.zones .. " (" .. active .. " active) from " .. source
        .. ", " .. #report.problems .. " problem(s)", true)
    current = report
    return report
end

--- Charge le fichier une fois (premier usage).
function ZonesFile.ensureLoaded()
    if not current then
        ZonesFile.load()
    end
    return current
end

--- Relit le fichier (outil d'admin) ; renvoie le rapport.
function ZonesFile.reload()
    return ZonesFile.load()
end

--- Rapport courant (chargé au premier usage).
function ZonesFile.report()
    return ZonesFile.ensureLoaded()
end

--- Zones valides du fichier (actives ou non), ordre du fichier.
function ZonesFile.zones()
    return ZonesFile.ensureLoaded().zones
end

--- Zones utilisables : activées et sur une carte chargée.
function ZonesFile.activeZones()
    local list = {}
    for _, zone in ipairs(ZonesFile.zones()) do
        if zone.active then
            list[#list + 1] = zone
        end
    end
    return list
end

--- Zone valide d'identifiant id, ou nil.
function ZonesFile.get(id)
    for _, zone in ipairs(ZonesFile.zones()) do
        if zone.id == id then
            return zone
        end
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- Modification par l'outil d'admin
-- ----------------------------------------------------------------------------

--- Signale (journal, tête des problèmes de la liste) que l'outil n'écrit pas.
local function refuseRewrite(report, why)
    local line = "the admin tool did not rewrite the file: " .. why .. " (edit the file by hand)"
    MilitaryDrop.log(ZonesFile.PATH .. ": " .. line, true)
    if report and report.problems then
        table.insert(report.problems, 1, line)
    end
end

--- Table lue, modifiable par l'outil, ou nil et "syntaxError". Le fichier
--- est RELU d'abord (installé comme rapport courant) : une édition manuelle
--- faite pendant que le serveur tourne sert de base, jamais écrasée par la
--- copie du dernier chargement. Fichier illisible, trop long, en erreur de
--- syntaxe ou que la réécriture abîmerait (rewriteProblem) : refus.
function ZonesFile.editableData()
    local report = ZonesFile.load()
    local raw = report.raw
    if report.syntaxError or type(raw) ~= "table" then
        return nil, "syntaxError"
    end
    local why = ZonesFile.rewriteProblem(raw)
    if why then
        refuseRewrite(report, why)
        return nil, "syntaxError"
    end
    raw.zones = raw.zones or {}
    return raw
end

--- Carte de la partie à écrire dans le fichier (getMap()), ou nil si elle
--- dépasse MAX_MAP (elle serait ignorée à la relecture : zones sans carte).
function ZonesFile.mapSpec()
    local map = ZonesFile.currentMap()
    if #map > ZonesFile.MAX_MAP then
        MilitaryDrop.log("map list longer than " .. ZonesFile.MAX_MAP .. " characters: zones written without map", true)
        return nil
    end
    return map
end

--- Entrée brute d'identifiant id dans la table lue : entrée, index ; ou nil.
function ZonesFile.findEntry(raw, id)
    for i, entry in ipairs(raw.zones) do
        if type(entry) == "table" and entry.id == id then
            return entry, i
        end
    end
    return nil
end

--- Nouvel identifiant : "z" .. (plus grand numéro des ids « zN » + 1).
function ZonesFile.nextId(raw)
    local highest = 0
    for _, entry in ipairs(raw.zones) do
        local number = type(entry) == "table" and type(entry.id) == "string" and tonumber(entry.id:match("^z(%d+)$"))
        if number and number > highest then
            highest = number
        end
    end
    return "z" .. string.format("%d", highest + 1)
end

--- Réécrit tout le fichier depuis la table modifiée (carte de la partie mise
--- à défaut de map), puis le relit. Renvoie le rapport, ou nil et le code de
--- l'outil : "syntaxError" (table que la réécriture abîmerait), "writeFailed"
--- (texte plus long que ce que le lecteur accepte, ou écriture impossible).
function ZonesFile.save(raw)
    if raw.map == nil then
        raw.map = ZonesFile.mapSpec()
    end
    local why = ZonesFile.rewriteProblem(raw)
    if why then
        refuseRewrite(current, why)
        return nil, "syntaxError"
    end
    local text = ZonesFile.format(raw)
    if not ZonesFile.fitsReader(text) then
        refuseRewrite(current, "the file would be too long to be read back (" .. MilitaryDrop.LotsFile.MAX_LINES
            .. " lines, " .. MilitaryDrop.LotsFile.MAX_CHARS .. " characters at most)")
        return nil, "writeFailed"
    end
    if not ZonesFile.writeText(text) then
        return nil, "writeFailed"
    end
    return ZonesFile.load()
end

--- Oublie le chargement (tests).
function ZonesFile.reset()
    current = nil
    loadedCache = nil
end

return ZonesFile
