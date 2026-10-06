-- MilitaryDrop_ZonesFile : fichier des zones de largage (idée 11, ZONE-02 et
-- ZONE-08) — création avec notice et aucune zone, erreur de syntaxe citée
-- par sa ligne (aucune zone), zone invalide écartée avec son numéro, carte
-- non chargée, diagnostic (bâtiments, terrain libre : zone entièrement
-- bâtie ou sur l'eau connue → noGround, plus de risk ni de noRoad ; hors
-- carte, chevauchement non-PvP ou refuge) rangé en notes du journal et
-- jamais dans les problèmes du fichier, réécriture fidèle et nouvel id ;
-- relecture avant toute modification de l'outil, refus d'une réécriture qui
-- perdrait des données (champ de premier niveau, liste à clés ou à trou,
-- table dans une zone, nombre non fini) ou dépasserait le lecteur, carte
-- chargée par les lots= d'une autre (getLotDirectories, repli getMap()).

local T = {}

local PATH = "MilitaryDrop/dropzones.txt"

--- Liste Java simulée (ArrayList : size, get, add, contains).
local function javaList(items)
    local list = { items = items or {} }
    function list.size(self) return #self.items end
    function list.get(self, i) return self.items[i + 1] end
    function list.add(self, value) self.items[#self.items + 1] = value return true end
    function list.contains(self, value)
        for _, item in ipairs(self.items) do
            if item == value then
                return true
            end
        end
        return false
    end
    return list
end

local function intersects(r, x, y, w, h)
    return r.x < x + w and x < r.x + r.w and r.y < y + h and y < r.y + r.h
end

local function buildingDef(b)
    b.def = b.def or {
        getX = function() return b.x end, getY = function() return b.y end,
        getW = function() return b.w end, getH = function() return b.h end,
        isUserDefined = function() return false end, isBasement = function() return false end,
    }
    return b.def
end

--- Métagrille simulée : ROADS, BUILDINGS et eau connue KNOWN_WATER
--- ({ x, y, w, h }), carte GRID,
--- cellules absentes MISSING_CELLS["cx,cy"].
local function makeGrid()
    return {
        isValidSquare = function(_, x, y) return x >= GRID.x1 and x < GRID.x2 and y >= GRID.y1 and y < GRID.y2 end,
        getCellData = function(_, cx, cy)
            if cx < 0 or cy < 0 or cx * 256 >= GRID.x2 or cy * 256 >= GRID.y2 or MISSING_CELLS[cx .. "," .. cy] then
                return nil
            end
            return { getBuildingsIntersecting = function(_, x, y, w, h, list)
                for _, b in ipairs(BUILDINGS) do
                    if intersects(b, x, y, w, h) and not list:contains(buildingDef(b)) then
                        list:add(buildingDef(b))
                    end
                end
            end }
        end,
        getBuildingAt = function(_, x, y)
            for _, b in ipairs(BUILDINGS) do
                if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
                    return buildingDef(b)
                end
            end
            return nil
        end,
        getZonesIntersecting = function(_, x, y, _z, w, h)
            local found = {}
            for kind, rects in pairs({ Nav = ROADS, Water = KNOWN_WATER }) do
                for _, r in ipairs(rects) do
                    if intersects(r, x, y, w, h) then
                        found[#found + 1] = {
                            getType = function() return kind end, isRectangle = function() return true end,
                            getX = function() return r.x end, getY = function() return r.y end,
                            getWidth = function() return r.w end, getHeight = function() return r.h end,
                        }
                    end
                end
            end
            return javaList(found)
        end,
    }
end

local function makeReader(text)
    local lines = {}
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    local index = 0
    return { readLine = function() index = index + 1 return lines[index] end, close = function() end }
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return false end
    ArrayList = { new = function() return javaList({}) end }
    MAP = "Muldraugh, KY"
    GRID = { x1 = 0, y1 = 0, x2 = 20000, y2 = 20000 }
    MISSING_CELLS = {}
    ROADS, BUILDINGS, KNOWN_WATER = {}, {}, {}
    -- Zones non-PvP (bord haut exclu) et refuges ({ x, y, w, h }).
    NONPVP, SAFEHOUSES = {}, {}
    local grid = makeGrid()
    getWorld = function()
        return { getMap = function() return MAP end, getMetaGrid = function() return grid end }
    end
    NonPvpZone = { getAllZones = function()
        local zones = {}
        for i, z in ipairs(NONPVP) do
            zones[i] = { getX = function() return z.x end, getY = function() return z.y end,
                getX2 = function() return z.x2 end, getY2 = function() return z.y2 end }
        end
        return javaList(zones)
    end }
    SafeHouse = { getSafehouseOverlapping = function(x1, y1, x2, y2)
        for _, s in ipairs(SAFEHOUSES) do
            if not (x1 >= s.x + s.w or x2 <= s.x or y1 >= s.y + s.h or y2 <= s.y) then
                return s
            end
        end
        return nil
    end }
    FILES, WRITES = {}, 0
    getFileReader = function(name) return FILES[name] and makeReader(FILES[name]) or nil end
    getFileWriter = function(name)
        WRITES = WRITES + 1
        return { write = function(_, text) FILES[name] = text end, close = function() end }
    end
    LOGS = {}
    print = function(text) LOGS[#LOGS + 1] = tostring(text) end
    getText = function(key) return key end
    getTimestampMs = function() return 0 end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Lots.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_LotsFile.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_ZonesFile.lua")
    ZF = MilitaryDrop.ZonesFile
end

local function logged(fragment)
    for _, line in ipairs(LOGS) do
        if line:find(fragment, 1, true) then
            return true
        end
    end
    return false
end

local function hasProblem(report, fragment)
    for _, line in ipairs(report.problems) do
        if line:find(fragment, 1, true) then
            return true
        end
    end
    return false
end

--- Fichier de zones : { map = ..., zones = { ligne, … } } en texte.
local function writeFile(zoneLines, map)
    local text = "return {\n    version = 1,\n"
    if map then
        text = text .. '    map = "' .. map .. '",\n'
    end
    text = text .. "    zones = {\n"
    for _, line in ipairs(zoneLines) do
        text = text .. "        " .. line .. ",\n"
    end
    FILES[PATH] = text .. "    },\n}\n"
end

local function codes(zone)
    return table.concat(zone.warnings, ",")
end

-- ----------------------------------------------------------------------------

function T.missing_file_is_created_with_a_notice_and_no_zone()
    local report = ZF.load()
    assertEq(report.source, "created", "fichier créé")
    assertEq(#report.zones, 0, "aucune zone")
    local text = FILES[PATH]
    assertTrue(text:find("Military Drop - drop zones", 1, true) ~= nil, "notice anglaise")
    assertTrue(text:find("shared by EVERY single-player save", 1, true) ~= nil, "fichier commun à toutes les parties")
    assertTrue(text:find('--       { id = "z1", sector = "Louisville"', 1, true) ~= nil, "exemple commenté")
    local data = MilitaryDrop.LotsFile.parse(text)
    assertTrue(data ~= nil and type(data.zones) == "table" and #data.zones == 0, "zones = {} vide, relisible")
    -- Relu sans être réécrit.
    WRITES = 0
    assertEq(ZF.load().source, "file", "relu")
    assertEq(WRITES, 0, "pas réécrit")
end

function T.syntax_error_gives_no_zone_and_cites_the_line()
    FILES[PATH] = 'return {\n    zones = {\n        { id = "z1", sector = "A", name = "B" x1 = 1 },\n    },\n}\n'
    local report = ZF.load()
    assertEq(report.syntaxError, true, "fichier illisible")
    assertEq(#report.zones, 0, "aucune zone")
    assertTrue(logged("syntax error, line 3:"), "erreur et numéro de ligne au journal")
    local _, err = ZF.editableData()
    assertEq(err, "syntaxError", "l'outil refuse d'écrire")
    -- Du code est refusé comme une erreur de syntaxe.
    FILES[PATH] = "return { zones = { os.exit() } }"
    assertEq(ZF.load().syntaxError, true, "aucun nom ni appel")
end

function T.invalid_zones_are_skipped_with_their_number()
    writeFile({
        '{ id = "z1", sector = " Louisville ", name = "Central  Park", x1 = 120, y1 = 60, x2 = 100, y2 = 50 }',
        '{ id = "z2", sector = "Louisville", name = "Mall", x1 = 0, y1 = 0, x2 = 10, y2 = 10, weight = 0 }',
        '{ id = "z3", sector = "Louisville", name = "Huge", x1 = 0, y1 = 0, x2 = 300, y2 = 10 }',
        '{ id = "z1", sector = "Louisville", name = "Twin", x1 = 0, y1 = 0, x2 = 10, y2 = 10 }',
        '{ id = "z5", sector = "Louisville", name = "Odd", x1 = 0, y1 = 0, x2 = 10, y2 = 10, color = "red" }',
        '{ id = "bad id!", sector = "S", name = "N", x1 = 0, y1 = 0, x2 = 1, y2 = 1 }',
        '{ id = "z7", sector = "", name = "N", x1 = 0, y1 = 0, x2 = 1, y2 = 1 }',
        '{ id = "z8", sector = "S", name = "<b>' .. string.rep("x", 40) .. '</b>", x1 = 0, y1 = 0, x2 = 1, y2 = 1 }',
        '{ id = "z9", sector = "S", name = "N", x1 = 0.5, y1 = 0, x2 = 1, y2 = 1 }',
        '{ id = "z10", sector = "S", name = "N", x1 = 0, y1 = 0, x2 = 299, y2 = 299, enabled = false, weight = 100 }',
    })
    local report = ZF.load()
    assertEq(#report.zones, 2, "deux zones valides")
    local z1 = report.zones[1]
    assertEq(z1.sector, "Louisville", "secteur nettoyé")
    assertEq(z1.name, "Central Park", "espaces resserrés")
    assertEq(z1.x1 .. "," .. z1.y1 .. "," .. z1.x2 .. "," .. z1.y2, "100,50,120,60", "rectangle normalisé")
    assertEq(z1.weight, 1, "poids par défaut")
    assertEq(z1.enabled, true, "activée par défaut")
    assertEq(report.zones[2].id, "z10", "côté de 300 cases permis")
    assertEq(report.zones[2].active, false, "désactivée : inactive")
    assertTrue(hasProblem(report, "zone #2 (z2): weight must be"), "poids hors bornes")
    assertTrue(hasProblem(report, "zone #3 (z3): the rectangle is 301 x 11"), "trop grande")
    assertTrue(hasProblem(report, "zone #4 (z1): duplicate id"), "id en double")
    assertTrue(hasProblem(report, "zone #5 (z5): unknown field color"), "champ inconnu")
    assertTrue(hasProblem(report, "zone #6 (bad id!): id must be"), "id invalide")
    assertTrue(hasProblem(report, "zone #7 (z7): sector must be"), "secteur vide")
    assertTrue(hasProblem(report, "zone #8 (z8): name must be"), "nom trop long")
    assertTrue(hasProblem(report, "zone #9 (z9): x1, y1, x2, y2 must be whole numbers"), "coordonnée non entière")
    assertTrue(logged("dropzones.txt: zone #2 (z2)"), "problèmes au journal")
end

function T.zones_of_a_map_not_loaded_are_ignored()
    ROADS = { { x = 0, y = 0, w = 1000, h = 1000 } }
    writeFile({
        '{ id = "z1", sector = "Raven", name = "Square", x1 = 10, y1 = 10, x2 = 20, y2 = 20 }',
        '{ id = "z2", sector = "Louisville", name = "Park", x1 = 10, y1 = 10, x2 = 20, y2 = 20, map = "Muldraugh, KY" }',
    }, "Muldraugh, KY;RavenCreek")
    local report = ZF.load()
    assertEq(report.mapLoaded, false, "carte du fichier absente")
    assertTrue(not hasProblem(report, "map RavenCreek is not loaded"), "pas une erreur du fichier")
    assertTrue(logged("note: map RavenCreek is not loaded"), "note au journal")
    assertEq(report.zones[1].active, false, "zone ignorée")
    assertEq(codes(report.zones[1]), "mapNotLoaded", "code")
    assertEq(report.zones[2].active, true, "map de la zone prioritaire")
    assertEq(#ZF.activeZones(), 1, "une zone utilisable")
    MAP = "Muldraugh, KY;RavenCreek"
    assertEq(#ZF.reload().zones, 2, "les deux zones")
    assertEq(#ZF.activeZones(), 2, "carte chargée : les deux sont utilisables")
end

function T.diagnosis_flags_only_zones_without_open_ground()
    BUILDINGS = { { x = 300, y = 300, w = 10, h = 10 }, { x = 700, y = 700, w = 40, h = 40 } }
    KNOWN_WATER = { { x = 896, y = 896, w = 120, h = 120 } }
    writeFile({
        '{ id = "field", sector = "S", name = "Field", x1 = 90, y1 = 90, x2 = 120, y2 = 110 }',
        '{ id = "town", sector = "S", name = "Houses", x1 = 290, y1 = 290, x2 = 330, y2 = 330 }',
        '{ id = "mall", sector = "S", name = "Mall", x1 = 705, y1 = 705, x2 = 730, y2 = 730 }',
        '{ id = "lake", sector = "S", name = "Lake", x1 = 900, y1 = 900, x2 = 1000, y2 = 1000 }',
        '{ id = "shore", sector = "S", name = "Shore", x1 = 990, y1 = 900, x2 = 1100, y2 = 1000 }',
    })
    local report = ZF.load()
    local field, town, mall, lake, shore = report.zones[1], report.zones[2], report.zones[3], report.zones[4],
        report.zones[5]
    assertEq(codes(field), "", "ni route ni bâtiment : plus d'avertissement")
    assertEq(field.stats.area, 31 * 21, "surface, coins compris")
    assertEq(field.stats.roads, nil, "plus de relevé des routes")
    assertEq(codes(town), "", "bâtiment et terrain libre autour")
    assertEq(town.stats.buildings, 1, "un bâtiment")
    assertEq(codes(mall), "noGround", "entièrement bâtie")
    assertEq(codes(lake), "noGround", "entièrement sur l'eau connue")
    assertEq(codes(shore), "", "rive : terrain libre")
    assertEq(#report.problems, 0, "constats sur des zones valides : aucun problème du fichier")
    assertTrue(logged("note: zone #3 (mall): no open ground"), "note au journal")
    assertTrue(not logged("warning"), "aucun « warning » au journal")
    for _, code in ipairs({ "risk", "noRoad" }) do
        assertTrue(not logged(code), "code retiré : " .. code)
    end
end

function T.diagnosis_flags_off_map_non_pvp_and_safehouse()
    ROADS = { { x = 0, y = 0, w = 20000, h = 20000 } }
    GRID.x2 = 1000
    NONPVP = { { x = 200, y = 200, x2 = 210, y2 = 210 } }
    SAFEHOUSES = { { x = 400, y = 400, w = 5, h = 5 } }
    writeFile({
        '{ id = "edge", sector = "S", name = "Edge", x1 = 990, y1 = 10, x2 = 1010, y2 = 20 }',
        '{ id = "pve", sector = "S", name = "Pve", x1 = 209, y1 = 209, x2 = 220, y2 = 220 }',
        '{ id = "near", sector = "S", name = "Near", x1 = 210, y1 = 180, x2 = 220, y2 = 220 }',
        '{ id = "home", sector = "S", name = "Home", x1 = 404, y1 = 404, x2 = 410, y2 = 410 }',
        '{ id = "next", sector = "S", name = "Next", x1 = 405, y1 = 380, x2 = 410, y2 = 420 }',
    })
    local report = ZF.load()
    assertEq(codes(report.zones[1]), "offMap", "hors carte")
    assertEq(#report.problems, 0, "diagnostic hors des problèmes du fichier")
    assertEq(codes(report.zones[2]), "nonPvp", "coin commun avec une zone non-PvP")
    assertEq(codes(report.zones[3]), "", "bord haut de la zone non-PvP exclu (NonPvpZone.java:70-77)")
    assertEq(codes(report.zones[4]), "safehouse", "refuge recoupé")
    assertEq(codes(report.zones[5]), "", "x = 405 : hors du refuge (x + w exclu)")
    assertEq(ZF.isProtected(210, 210), true, "caisse en 209..210 : touche la zone non-PvP")
    assertEq(ZF.isProtected(211, 211), false, "caisse en 210..211 : dehors")
    assertEq(ZF.isProtected(405, 405), true, "dans le refuge")
    -- Cellule absente de la métagrille.
    MISSING_CELLS["0,0"] = true
    writeFile({ '{ id = "hole", sector = "S", name = "Hole", x1 = 10, y1 = 10, x2 = 20, y2 = 20 }' })
    assertEq(codes(ZF.load().zones[1]), "offMap", "cellule inconnue")
end

function T.rewrite_keeps_ids_unknown_scalars_and_invalid_zones()
    writeFile({
        '{ id = "z2", sector = "A \\"quoted\\"", name = "One", x1 = 1, y1 = 2, x2 = 3, y2 = 4, weight = 3 }',
        '{ id = "keep", sector = "", name = "Broken", x1 = 1, y1 = 1, x2 = 2, y2 = 2, note = "admin" }',
        '{ id = "z10", sector = "B", name = "Two", x1 = 1, y1 = 2, x2 = 3, y2 = 4, enabled = false }',
    })
    ZF.load()
    local raw = assert(ZF.editableData())
    assertEq(ZF.nextId(raw), "z11", "plus grand numéro + 1")
    raw.zones[1].enabled = false
    assertTrue(ZF.save(raw) ~= nil, "écrit et relu")
    local text = FILES[PATH]
    assertTrue(text:find('map = "Muldraugh, KY"', 1, true) ~= nil, "carte de la partie ajoutée")
    assertTrue(text:find('sector = "A \\"quoted\\""', 1, true) ~= nil, "guillemets échappés")
    assertTrue(text:find('note = "admin"', 1, true) ~= nil, "champ inconnu simple gardé")
    local data = MilitaryDrop.LotsFile.parse(text)
    assertEq(#data.zones, 3, "zone invalide gardée dans le fichier")
    assertEq(data.zones[1].enabled, false, "modification écrite")
    assertEq(data.zones[1].weight, 3, "poids gardé")
    assertEq(data.zones[3].id, "z10", "ids conservés")
    local report = ZF.report()
    assertEq(#report.zones, 2, "relu : deux zones valides")
    assertTrue(text:find("^%-%- =+\n%-%- Military Drop %- drop zones\n") ~= nil, "notice en tête")
end

function T.the_tool_rereads_the_file_before_any_change()
    writeFile({ '{ id = "z1", sector = "S", name = "One", x1 = 1, y1 = 1, x2 = 2, y2 = 2 }' })
    ZF.load()
    -- Édition manuelle pendant que le serveur tourne, sans rechargement.
    writeFile({
        '{ id = "z1", sector = "S", name = "One", x1 = 1, y1 = 1, x2 = 2, y2 = 2 }',
        '{ id = "z7", sector = "S", name = "Manual", x1 = 1, y1 = 1, x2 = 2, y2 = 2 }',
    })
    local raw = assert(ZF.editableData())
    assertEq(#raw.zones, 2, "l'édition manuelle sert de base")
    assertEq(ZF.nextId(raw), "z8", "id suivant d'après le fichier relu")
    assertEq(#ZF.zones(), 2, "rapport courant à jour")
    -- Édition manuelle cassée ou fichier trop long : refus, même sans rechargement.
    FILES[PATH] = FILES[PATH]:gsub("Manual\"", "Manual")
    local data, err = ZF.editableData()
    assertEq(data, nil, "rien à modifier")
    assertEq(err, "syntaxError", "erreur de syntaxe")
    FILES[PATH] = string.rep("-- comment\n", MilitaryDrop.LotsFile.MAX_LINES + 1) .. "return { zones = {} }\n"
    data, err = ZF.editableData()
    assertEq(data, nil, "rien à modifier")
    assertEq(err, "syntaxError", "fichier illisible (trop long)")
end

function T.rewrite_refuses_what_it_would_lose()
    local zone = '{ id = "z1", sector = "S", name = "One", x1 = 1, y1 = 1, x2 = 2, y2 = 2 }'
    local cases = {
        { "return { zones = { " .. zone .. " }, owner = \"admin\" }", "unknown top-level field owner" },
        { "return { map = 5, zones = { " .. zone .. " } }", "map must be a text" },
        { "return { zones = { " .. zone .. ", extra = " .. zone .. " } }", "zones must be a plain list" },
        { "return { zones = { " .. zone .. ", \"oops\" } }", "zone #2 is not a table" },
        { "return { zones = { " .. zone .. ", nil, " .. zone:gsub("z1", "z3") .. " } }", "zones must be a plain list" },
        { "return { zones = { { id = \"z1\", sector = \"S\", name = \"N\", x1 = 1, y1 = 1, x2 = 2, y2 = 2,"
            .. " tags = { \"a\" } } } }", "value of tags cannot be rewritten (table)" },
        { "return { zones = { { id = \"z1\", sector = \"S\", name = \"N\", x1 = 1, y1 = 1, x2 = 2, y2 = 2,"
            .. " weight = 1e999 } } }", "value of weight cannot be rewritten (inf)" },
        { "return { version = -1e999, zones = {} }", "version must be a number" },
    }
    for _, case in ipairs(cases) do
        FILES[PATH] = case[1]
        local before, writes = FILES[PATH], WRITES
        local data, err = ZF.editableData()
        assertEq(data, nil, case[2])
        assertEq(err, "syntaxError", case[2])
        assertTrue(ZF.report().problems[1]:find(case[2], 1, true) ~= nil, "raison en tête des problèmes : " .. case[2])
        assertTrue(logged("did not rewrite the file") and logged(case[2]), "au journal : " .. case[2])
        assertEq(FILES[PATH], before, "fichier intact : " .. case[2])
        assertEq(WRITES, writes, "rien écrit : " .. case[2])
    end
end

function T.save_never_writes_an_unreadable_file()
    writeFile({ '{ id = "z1", sector = "S", name = "One", x1 = 1, y1 = 1, x2 = 2, y2 = 2 }' })
    local raw = assert(ZF.editableData())
    local before, writes = FILES[PATH], WRITES
    raw.zones[1].weight = math.huge
    local report, code = ZF.save(raw)
    assertEq(report, nil, "nombre non fini : refus")
    assertEq(code, "syntaxError", "code")
    raw.zones[1].weight = 0 / 0
    assertEq(select(2, ZF.save(raw)), "syntaxError", "NaN : refus")
    raw.zones[1].weight = 1
    raw.zones[1].note = string.rep("x", MilitaryDrop.LotsFile.MAX_CHARS)
    report, code = ZF.save(raw)
    assertEq(report, nil, "texte trop long pour être relu")
    assertEq(code, "writeFailed", "code")
    assertEq(FILES[PATH], before, "fichier intact")
    assertEq(WRITES, writes, "rien écrit")
    raw.zones[1].note = "ok"
    assertTrue(ZF.save(raw) ~= nil, "écrit une fois corrigé")
    assertTrue(ZF.fitsReader(FILES[PATH]), "relisible")
end

function T.maps_loaded_through_another_map_count_as_loaded()
    -- Map=ModCity sans « ; » : le moteur charge aussi les lots= de son
    -- map.info (IsoMetaGrid.java:1775-1815), ici la carte vanilla.
    MAP = "ModCity"
    getLotDirectories = function() return javaList({ "ModCity", "Muldraugh, KY" }) end
    writeFile({
        '{ id = "z1", sector = "S", name = "Vanilla", x1 = 10, y1 = 10, x2 = 20, y2 = 20, map = "Muldraugh, KY" }',
        '{ id = "z2", sector = "S", name = "Raven", x1 = 10, y1 = 10, x2 = 20, y2 = 20, map = "RavenCreek" }',
    })
    local report = ZF.load()
    assertEq(report.zones[1].active, true, "carte vanilla incluse par la carte de mod : chargée")
    assertEq(report.zones[2].active, false, "carte absente")
    -- Repli sans l'API (ou si elle lève une exception) : noms de getMap().
    getLotDirectories = function() error("GameMap is DEFAULT but there are multiple worlds to choose from") end
    ZF.reset()
    assertEq(ZF.load().zones[1].active, false, "exception : repli sur getMap()")
    getLotDirectories = nil
    ZF.reset()
    assertEq(ZF.load().zones[1].active, false, "sans l'API : repli sur getMap()")
    writeFile({ '{ id = "z1", sector = "S", name = "N", x1 = 10, y1 = 10, x2 = 20, y2 = 20 }' }, "Muldraugh, KY")
    MAP = "ModCity;Muldraugh, KY"
    ZF.reset()
    assertEq(ZF.load().zones[1].active, true, "liste « ; » de getMap()")
end

function T.at_most_200_zones()
    local lines = {}
    for i = 1, 201 do
        lines[i] = '{ id = "z' .. i .. '", sector = "S", name = "N", x1 = 1, y1 = 1, x2 = 2, y2 = 2 }'
    end
    writeFile(lines)
    local report = ZF.load()
    assertEq(#report.zones, 200, "200 zones au plus")
    assertTrue(hasProblem(report, "zone #201 (z201): more than 200 zones"), "la suivante écartée")
end

return T
