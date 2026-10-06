-- MilitaryDrop_Zones : zones de largage côté serveur (idée 11, ZONE-01, 03,
-- 04, 05, 06) — mode proximité inchangé, secteur le plus proche ou au hasard,
-- distance minimale, tirage pondéré et autre zone du même secteur, case tirée
-- n'importe où dans la zone hors bâtiment et hors de l'eau (règle du
-- 2026-10-06 : zone sans route ni bâtiment → caisse sur la terre ferme ; zone
-- entièrement bâtie → aucune caisse dans un bâtiment), jamais de caisse dans
-- l'eau ni hors zone (eau connue ou non de la métagrille simulée : zone à
-- moitié sur l'eau, zone entièrement sur l'eau → noSite ou attente), partie
-- non-PvP écartée, repli
-- villes vanilla puis proximité avec avertissement, mode « zones si
-- proche », leurre par secteur nommé revalidé au serveur, outil d'admin
-- (droits, cadence, coordonnées hors carte, chevauchements, fichier
-- illisible), annonce et rappel avec le nom de la zone, secret de la zone ;
-- édition manuelle jamais écrasée sans rechargement, carte du fichier mise
-- à jour à l'ajout (zones existantes gardant l'ancienne), zone relue
-- revérifiée, carte vanilla incluse par une carte de mod, largage forcé de
-- l'admin (direct, feuille, leurre) soumis aux zones comme celui d'un joueur
-- (décision du 2026-10-06), fournitures d'un crash à l'épave, nouvel essai
-- espacé d'une livraison bloquée.

local T = {}

local PATH = "MilitaryDrop/dropzones.txt"
local CHANNEL = 151400
local CODE = "BRAVO-KILO-07"

-- ----------------------------------------------------------------------------
-- Monde simulé
-- ----------------------------------------------------------------------------

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

--- Zone rectangulaire de la métagrille (Nav, Water).
local function metaZone(kind, r)
    return {
        getType = function() return kind end, isRectangle = function() return true end,
        getX = function() return r.x end, getY = function() return r.y end,
        getWidth = function() return r.w end, getHeight = function() return r.h end,
    }
end

--- Zones de la métagrille : routes ROADS (« Nav ») et eau connue KNOWN_WATER
--- (« Water », cellules déjà approchées), { x, y, w, h }.
local function metaZones()
    local list = {}
    for _, r in ipairs(ROADS) do
        list[#list + 1] = { r = r, zone = metaZone("Nav", r) }
    end
    for _, r in ipairs(KNOWN_WATER) do
        list[#list + 1] = { r = r, zone = metaZone("Water", r) }
    end
    return list
end

--- Métagrille : routes ROADS, bâtiments BUILDINGS et eau connue KNOWN_WATER
--- ({ x, y, w, h }), carte carrée de 20 000 cases. L'eau réelle des cases
--- chargées est WATER(x, y) : la métagrille n'en connaît que KNOWN_WATER.
local function makeGrid()
    return {
        isValidSquare = function(_, x, y) return x >= 0 and x < 20000 and y >= 0 and y < 20000 end,
        getCellData = function(_, cx, cy)
            if cx < 0 or cy < 0 or cx * 256 >= 20000 or cy * 256 >= 20000 then
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
            for _, entry in ipairs(metaZones()) do
                if intersects(entry.r, x, y, w, h) then
                    found[#found + 1] = entry.zone
                end
            end
            return javaList(found)
        end,
        getZonesAt = function(_, x, y)
            local found = {}
            for _, entry in ipairs(metaZones()) do
                if intersects(entry.r, x, y, 1, 1) then
                    found[#found + 1] = entry.zone
                end
            end
            return javaList(found)
        end,
    }
end

--- Case chargée (LOADED(x, y)), d'eau si WATER(x, y).
local function makeSquare(x, y)
    return {
        getX = function() return x end, getY = function() return y end,
        isOutside = function() return true end, isFree = function() return true end,
        isWaterSquare = function() return WATER ~= nil and WATER(x, y) end,
        getVehicleContainer = function() return nil end,
        AddWorldInventoryItem = function(_, item, _, _, _, transmit)
            assert(type(item) == "table" and transmit == true, "objet déjà créé, transmis à la pose")
            PLACED[#PLACED + 1] = { x = x, y = y, item = item }
            return item
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

-- ----------------------------------------------------------------------------
-- Objets et butin minimal (formulaire de réquisition)
-- ----------------------------------------------------------------------------

local ITEMS = { ["Base.TinnedBeans"] = { cat = "Food" }, ["Base.Hammer"] = { cat = "Tool" } }

local function setupLoot()
    ItemType = { CONTAINER = "Container", WEAPON = "Weapon", WEAPON_PART = "WeaponPart", CLOTHING = "Clothing" }
    Fluid = { Water = "Water", Petrol = "Petrol" }
    ItemTag = { PETROL = "Petrol", get = function() return nil end }
    ResourceLocation = { of = function(id) return string.lower(id) end }
    instanceItem = function(fullType)
        local item = { fullType = fullType, modData = {}, kind = "InventoryItem" }
        function item.getModData(self) return self.modData end
        function item.setName(self, text) self.name = text end
        function item.setCustomName(self, value) self.customName = value end
        item.getFluidContainer = function() return nil end
        item.hasTag = function() return false end
        return item
    end
    local function makeScript(fullType)
        local data = ITEMS[fullType]
        return {
            getItemType = function() return "Normal" end, getFullName = function() return fullType end,
            isRanged = function() return false end, getMaxDamage = function() return 0 end,
            getDisplayCategory = function() return data.cat end, getActualWeight = function() return 1 end,
            getDaysTotallyRotten = function() return 1000000000 end, hasTag = function() return false end,
        }
    end
    getScriptManager = function()
        return {
            FindItem = function(_, name)
                local fullType = string.find(name, ".", 1, true) and name or ("Base." .. name)
                return ITEMS[fullType] and makeScript(fullType) or nil
            end,
            getItemsByType = function() return javaList({}) end,
            getAllItems = function()
                local all = {}
                for fullType in pairs(ITEMS) do
                    all[#all + 1] = makeScript(fullType)
                end
                return javaList(all)
            end,
        }
    end
    ProceduralDistributions = { list = { Everything = { items = { "TinnedBeans", 1, "Hammer", 1 } } } }
end

-- ----------------------------------------------------------------------------
-- Joueurs, radio
-- ----------------------------------------------------------------------------

local function makeRadio(on, channel)
    local data = {
        getIsHighTier = function() return true end, getIsPortable = function() return true end,
        getIsTurnedOn = function() return on end, getChannel = function() return channel end,
    }
    return { kind = "Radio", getID = function() return 7 end, getDeviceData = function() return data end,
        getContainer = function() return nil end }
end

local function makePlayer(name, x, y)
    local radio = makeRadio(true, CHANNEL)
    local player = {
        getUsername = function() return name or "tester" end,
        getX = function() return (x or 100) + 0.5 end,
        getY = function() return (y or 200) + 0.5 end,
        getPrimaryHandItem = function() return radio end,
        getSecondaryHandItem = function() return nil end,
        getClothingItem_Back = function() return nil end,
    }
    function player.getModData(self)
        self.characterData = self.characterData or { MilitaryDrop_characterId = "C:" .. self:getUsername() }
        return self.characterData
    end
    function player.getDescriptor() return nil end
    return player
end

function T.setup()
    SandboxVars = { MilitaryDrop = { CooldownHours = 168, AuthCode = 2, Frequency = 151.4, MinZombies = 0,
        MaxZombies = 0, CaseRolls = 2, DecoyEnabled = true, DecoyCost = 3, RequisitionForm = false } }
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    Capability = { MakeEventsAlarmGunshot = "MakeEventsAlarmGunshot",
        ChangeAndReloadServerOptions = "ChangeAndReloadServerOptions" }
    ADMIN = true
    checkPermissions = function() return ADMIN end
    MODDATA = {}
    ModData = { getOrCreate = function(tag)
        MODDATA[tag] = MODDATA[tag] or {}
        return MODDATA[tag]
    end }
    ZombRand = function() return 0 end
    ZombRandFloat = function(low) return low end
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
    WORLD_HOURS = 1000
    getGameTime = function()
        return {
            getWorldAgeHours = function() return WORLD_HOURS end,
            getYear = function() return 1993 end, getMonth = function() return 6 end,
            getDay = function() return 13 end, getTimeOfDay = function() return 12 end,
        }
    end
    -- Monde : rien de chargé par défaut (point lointain), pas d'eau.
    ArrayList = { new = function() return javaList({}) end }
    MAP = "Muldraugh, KY"
    ROADS, BUILDINGS, NONPVP, SAFEHOUSES, KNOWN_WATER = {}, {}, {}, {}, {}
    LOADED, WATER = nil, nil
    PLACED = {}
    local grid = makeGrid()
    getWorld = function()
        return {
            getGameMode = function() return "Sandbox" end, getWorld = function() return "Test Save" end,
            getMap = function() return MAP end, getMetaGrid = function() return grid end,
        }
    end
    getCell = function()
        return { getGridSquare = function(_, x, y)
            if LOADED and LOADED(x, y) then
                return makeSquare(x, y)
            end
            return nil
        end }
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
    spawnHorde = function() end
    addSound = function() end
    getText = function(key, ...)
        local parts = { key }
        for _, value in ipairs({ ... }) do
            parts[#parts + 1] = tostring(value)
        end
        return table.concat(parts, "|")
    end
    FILES, WRITES = { ["MilitaryDrop/Sandbox_Test_Save_code.txt"] = CODE }, 0
    getFileReader = function(name) return FILES[name] and makeReader(FILES[name]) or nil end
    getFileWriter = function(name)
        WRITES = WRITES + 1
        return { write = function(_, text) FILES[name] = text end, close = function() end }
    end
    LOGS = {}
    print = function(text) LOGS[#LOGS + 1] = tostring(text) end
    getActivatedMods = function() return { size = function() return 0 end } end
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function() return PLAYER end
    VehicleDistributions = { {} }
    IsoDirections = { getRandom = function() return "N" end }
    addVehicleDebug = function() return nil end
    -- Chaîne militaire (annonces).
    ChannelCategory = { Military = "Military" }
    AIRING = nil
    DynamicRadioChannel = { new = function(_, freq)
        return { freq = freq, getAiringBroadcast = function() return AIRING end,
            setAiringBroadcast = function(_, bc) AIRING = bc end }
    end }
    RadioBroadCast = { new = function()
        return { lines = {}, AddRadioLine = function(self, line) self.lines[#self.lines + 1] = line end }
    end }
    RadioLine = { new = function(text, _, _, _, codes) return { text = text, codes = codes } end }
    getZomboidRadio = function() return { removeChannelName = function() end } end
    CHANNELS = {}
    SCRIPT_MANAGER = {
        AddChannel = function(_, channel) CHANNELS[#CHANNELS + 1] = channel end,
        getRadioChannel = function() return CHANNELS[1] end,
    }
    setupLoot()
    for _, file in ipairs({ "Core", "Net", "Radio", "Codes", "Loot", "Lots", "Flight" }) do
        loadMod("shared/MilitaryDrop/MilitaryDrop_" .. file .. ".lua")
    end
    for _, file in ipairs({ "Crate", "Secrets", "Guard", "Smoke", "Server", "Teams", "Trust", "Broadcast", "Flights",
        "LotsFile", "Requisition", "ZonesFile", "Zones" }) do
        loadMod("server/MilitaryDrop/MilitaryDrop_" .. file .. ".lua")
    end
    DELIVERED = {}
    MilitaryDrop.Decoy = {
        trunkContents = function() return { { fullType = "MilitaryDrop.DecoyBeacon", name = "DIVERSION" } } end,
        onDelivered = function(dropId, x, y) DELIVERED[#DELIVERED + 1] = { dropId = dropId, x = x, y = y } end,
    }
    SENT, BROADCAST = {}, {}
    MilitaryDrop.Client = { onServerCommand = function() end }
    MilitaryDrop.Net.toPlayer = function(player, command, args)
        SENT[#SENT + 1] = { player = player, command = command, args = args }
    end
    MilitaryDrop.Net.toAll = function(command, args) BROADCAST[#BROADCAST + 1] = { command = command, args = args } end
    PLAYER = makePlayer()
end

-- ----------------------------------------------------------------------------
-- Outils
-- ----------------------------------------------------------------------------

--- Fichier des zones (lignes de zones, carte facultative), relu au prochain usage.
local function zonesFile(lines, map)
    local text = "return {\n    version = 1,\n"
    if map then
        text = text .. '    map = "' .. map .. '",\n'
    end
    text = text .. "    zones = {\n"
    for _, line in ipairs(lines) do
        text = text .. "        " .. line .. ",\n"
    end
    FILES[PATH] = text .. "    },\n}\n"
    MilitaryDrop.ZonesFile.reset()
end

local function zone(id, sector, name, x1, y1, x2, y2, extra)
    return string.format('{ id = "%s", sector = "%s", name = "%s", x1 = %d, y1 = %d, x2 = %d, y2 = %d%s }',
        id, sector, name, x1, y1, x2, y2, extra or "")
end

--- Deux secteurs : Alpha (900 cases à l'est du joueur) et Bravo (2 900), une
--- route nord-sud à travers chaque zone.
local function twoSectors()
    ROADS = { { x = 1020, y = 0, w = 4, h = 1000 }, { x = 3020, y = 0, w = 4, h = 1000 } }
    zonesFile({
        zone("z1", "Alpha", "Alpha Park", 1000, 200, 1050, 250),
        zone("z2", "Bravo", "Bravo Mall", 3000, 200, 3050, 250),
    })
end

local function placement(mode)
    SandboxVars.MilitaryDrop.DropPlacement = mode
end

local function choose(player)
    return MilitaryDrop.Server.chooseDropPoint(player or PLAYER)
end

local function logged(fragment)
    for _, line in ipairs(LOGS) do
        if line:find(fragment, 1, true) then
            return true
        end
    end
    return false
end

local function inside(x, y, x1, y1, x2, y2)
    return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

local function flights()
    return MilitaryDrop.Server.getState().flights or {}
end

local function fly()
    local flight = flights()[1]
    for _ = 1, math.ceil((MilitaryDrop.Flight.dropTime(flight) + 0.5) / 0.25) do
        MilitaryDrop.Flights.advance(flight, 0.25)
    end
    return flight
end

local function call(player)
    NOW_MS = NOW_MS + 5000
    MilitaryDrop.Server.handleRequest(player or PLAYER, { requestId = 1, radio = { kind = "item", id = 7 }, code = CODE })
    return SENT[#SENT].args
end

local function order(lots, decoy, sector)
    NOW_MS = NOW_MS + 5000
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", "RequisitionOrder", PLAYER,
        { requestId = 1, radio = { kind = "item", id = 7 }, order = lots, decoy = decoy, sector = sector })
    return SENT[#SENT].args
end

--- Commande de l'outil d'admin ; renvoie les réponses reçues { command = args }.
local function admin(command, args, player)
    NOW_MS = NOW_MS + 1000
    local before = #SENT
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", command, player or PLAYER, args or {})
    local replies = {}
    for i = before + 1, #SENT do
        replies[SENT[i].command] = SENT[i].args
    end
    return replies
end

-- ----------------------------------------------------------------------------
-- Mode et choix du point
-- ----------------------------------------------------------------------------

function T.proximity_mode_is_unchanged_by_default()
    twoSectors()
    ROADS[#ROADS + 1] = { x = 0, y = 0, w = 100000, h = 100000 }
    local x, y, info = choose()
    assertEq(x .. "," .. y, "250,200", "anneau autour du demandeur, comme avant")
    assertEq(info, nil, "aucune info de zone")
    assertEq(MilitaryDrop.Zones.decoySectors(100, 200), nil, "leurre : N, E, S, O")
end

function T.nearest_sector_gets_the_drop_anywhere_inside_the_zone()
    placement(2)
    twoSectors()
    local x, y, info = choose()
    assertEq(x .. "," .. y, "1001,201", "première case tirée dans la zone Alpha, caisse 2×2 dedans")
    assertEq(info.zoneId, "z1", "zone")
    assertEq(info.zoneName, "Alpha Park", "nom")
    assertEq(info.sector, "Alpha", "secteur le plus proche")
    assertEq(info.source, "zone", "source")
    x, y, info = choose(makePlayer("far", 3200, 220))
    assertEq(info.sector, "Bravo", "autre demandeur, autre secteur")
    assertTrue(inside(x, y, 3000, 200, 3050, 250), "dans la zone Bravo")
end

function T.random_sector_choice()
    placement(2)
    SandboxVars.MilitaryDrop.DropZoneChoice = 2
    twoSectors()
    ZombRand = function(n) return n - 1 end
    local x, y, info = choose()
    assertEq(info.sector, "Bravo", "dernier secteur tiré, pas le plus proche")
    assertTrue(inside(x, y, 3000, 200, 3050, 250), "dans sa zone")
end

function T.min_distance_skips_zones_too_close_then_falls_back_to_the_nearest()
    placement(2)
    twoSectors()
    local caller = makePlayer("inside", 1010, 220)
    SandboxVars.MilitaryDrop.DropZoneMinDistance = 500
    local _, _, info = choose(caller)
    assertEq(info.sector, "Bravo", "Alpha trop proche : écartée")
    SandboxVars.MilitaryDrop.DropZoneMinDistance = 5000
    SandboxVars.MilitaryDrop.DropZoneChoice = 2
    ZombRand = function(n) return n - 1 end
    _, _, info = choose(caller)
    assertEq(info.sector, "Alpha", "toutes trop proches : secteur le plus proche, même au hasard")
end

function T.weighted_draw_then_another_zone_of_the_same_sector()
    placement(2)
    -- Lac connu de la métagrille (cellule déjà approchée).
    KNOWN_WATER = { { x = 1000, y = 200, w = 101, h = 101 } }
    zonesFile({
        zone("lake", "Alpha", "Lake", 1000, 200, 1100, 300, ", weight = 100"),
        zone("park", "Alpha", "Park", 1200, 200, 1250, 250),
        zone("far", "Bravo", "Far", 5000, 200, 5050, 250),
    })
    local x, y, info = choose()
    assertEq(info.zoneId, "park", "le lac (poids 100) ne donne rien : autre zone du secteur")
    assertTrue(inside(x, y, 1200, 200, 1250, 250), "dans le parc")
    assertTrue(logged("drop zone lake (Alpha/Lake): no open ground in 60 draws"), "zone sans case au journal")
end

--- ZombRand qui rend, dans l'ordre, les valeurs données (bornées à n - 1),
--- puis 0.
local function rolls(values)
    local i = 0
    ZombRand = function(n)
        i = i + 1
        return math.min(values[i] or 0, n - 1)
    end
end

function T.zone_without_road_or_building_gets_a_point_on_open_ground()
    placement(2)
    ROADS, BUILDINGS = {}, {}
    zonesFile({ zone("z1", "Alpha", "Field", 1000, 200, 1099, 299) })
    assertEq(table.concat(MilitaryDrop.ZonesFile.zones()[1].warnings, ","), "", "plus d'avertissement risk")
    assertEq(#MilitaryDrop.ZonesFile.report().problems, 0, "aucun problème du fichier")
    -- Tirages de la case (ZombRand(99) : côté de 100 cases moins un) : 40 puis
    -- 60 ; tout autre tirage (zone, code, confiance) rend 0.
    local function fieldRolls()
        local i = 0
        ZombRand = function(n)
            if n ~= 99 then
                return 0
            end
            i = i + 1
            return i == 1 and 40 or 60
        end
    end
    fieldRolls()
    local x, y, info = choose()
    assertEq(x .. "," .. y, "1041,261", "case tirée dans le champ")
    assertEq(info.zoneId, "z1", "zone")
    -- Livraison : la caisse se pose sur la terre ferme de la zone.
    fieldRolls()
    call()
    fly()
    LOADED = function() return true end
    triggerEvent("LoadChunk")
    assertEq(#PLACED, 2, "caisses posées au chargement")
    assertEq(PLACED[1].x .. "," .. PLACED[1].y, "1041,261", "au point tiré, sans route ni bâtiment")
end

function T.building_squares_are_never_drawn()
    placement(2)
    BUILDINGS = { { x = 1000, y = 200, w = 20, h = 31 } }
    zonesFile({ zone("z1", "Alpha", "Block", 1000, 200, 1030, 230) })
    -- 1er tirage dans le bâtiment, 2e : caisse à cheval sur son mur est
    -- (x - 1 = 1019), 3e : dehors.
    -- Premier ZombRand : tirage de la zone (Zones.drawZone).
    rolls({ 0, 5, 5, 19, 5, 25, 5 })
    local x, y = choose()
    assertEq(x .. "," .. y, "1026,206", "caisse 2×2 entièrement hors du bâtiment")
    BUILDINGS = { { x = 990, y = 190, w = 60, h = 60 } }
    zonesFile({ zone("z1", "Alpha", "Block", 1000, 200, 1030, 230) })
    assertEq(table.concat(MilitaryDrop.ZonesFile.zones()[1].warnings, ","), "noGround",
        "zone entièrement bâtie signalée")
    ZombRand = function(n) return n - 1 end
    assertEq(choose(), nil, "zone entièrement bâtie : aucun point")
    assertEq(call().status, "noSite", "refus, délai non consommé")
    assertEq(#PLACED, 0, "aucune caisse dans un bâtiment")
end

-- ----------------------------------------------------------------------------
-- Jamais dans l'eau, jamais hors zone
-- ----------------------------------------------------------------------------

function T.half_water_zone_never_gets_a_crate_in_water()
    placement(2)
    -- Zone x 5000-5099 ; l'ouest (x < 5050) est un lac que la métagrille ne
    -- connaît pas (cellule jamais approchée) : le point tiré tombe dans l'eau.
    zonesFile({ zone("z1", "Shore", "Shore", 5000, 200, 5099, 299) })
    WATER = function(x) return x < 5050 end
    call()
    local flight = fly()
    assertEq(flight.tx, 5001.5, "point tiré sur le lac (eau inconnue, zone non chargée)")
    assertEq(#PLACED, 0, "rien avant le chargement de la zone")
    LOADED = function() return true end
    triggerEvent("LoadChunk")
    assertEq(#PLACED, 2, "caisses posées au chargement")
    for _, placed in ipairs(PLACED) do
        assertTrue(not WATER(placed.x, placed.y) and not WATER(placed.x - 1, placed.y - 1), "aucune case d'eau")
        assertTrue(inside(placed.x, placed.y, 5000, 200, 5100, 300), "dans la zone : " .. placed.x .. "," .. placed.y)
    end
end

function T.half_water_zone_known_to_the_metagrid_is_drawn_on_dry_ground()
    placement(2)
    -- Même rive, lac connu de la métagrille (zone « Water » au grain du chunk).
    KNOWN_WATER = { { x = 4992, y = 200, w = 56, h = 100 } }
    zonesFile({ zone("z1", "Shore", "Shore", 5000, 200, 5099, 299) })
    WATER = function(x) return x < 5048 end
    local seed = 0
    ZombRand = function(n)
        seed = seed + 13
        return seed % n
    end
    for _ = 1, 10 do
        local x, y = choose()
        assertTrue(x ~= nil and x - 1 >= 5048 and inside(x, y, 5001, 201, 5099, 299),
            "caisse sur la partie sèche : " .. tostring(x))
    end
end

function T.zone_entirely_on_water_answers_no_site()
    placement(2)
    ROADS = {}
    KNOWN_WATER = { { x = 4992, y = 192, w = 120, h = 120 } }
    zonesFile({ zone("z1", "Lake", "Lake", 5000, 200, 5099, 299) })
    assertEq(table.concat(MilitaryDrop.ZonesFile.zones()[1].warnings, ","), "noGround", "lac connu signalé")
    WATER = function() return true end
    local reply = call()
    assertEq(reply.status, "noSite", "aucune case : refus")
    assertEq(#flights(), 0, "aucun vol, ni ailleurs ni près du demandeur")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, nil, "délai non consommé")
end

function T.zone_entirely_on_unknown_water_gets_no_crate()
    placement(2)
    -- Lac d'une cellule jamais approchée : le point est accepté, mais aucune
    -- caisse n'est posée (ni dans l'eau, ni hors zone) ; la livraison attend.
    zonesFile({ zone("z1", "Lake", "Lake", 5000, 200, 5099, 299) })
    WATER = function(x, y) return inside(x, y, 4999, 199, 5100, 300) end
    assertEq(call().status, "accepted", "eau inconnue au tirage")
    fly()
    LOADED = function() return true end
    triggerEvent("LoadChunk")
    assertEq(#PLACED, 0, "aucune caisse dans l'eau ni hors zone")
    local waiting = 0
    for _ in pairs(MilitaryDrop.Server.getState().pending or {}) do
        waiting = waiting + 1
    end
    assertEq(waiting, 1, "livraison en attente")
end

function T.delivery_waits_rather_than_leaving_the_zone()
    placement(2)
    ROADS = { { x = 5020, y = 200, w = 4, h = 20 } }
    zonesFile({ zone("z1", "Pond", "Pond", 5000, 200, 5039, 219) })
    call()
    local flight = fly()
    local dropId = flight.dropId
    -- À la livraison, toute la zone est sous l'eau ; la rive sèche est dehors.
    WATER = function(x, y) return inside(x, y, 4999, 199, 5040, 220) end
    LOADED = function() return true end
    assertEq(MilitaryDrop.Server.deliver(5020, 200, "tester", dropId), false, "aucune case sèche dans la zone : attente")
    triggerEvent("LoadChunk")
    assertEq(#PLACED, 0, "rien posé hors zone")
    WATER = nil
    -- Nouvel essai espacé (Flights.RETRY_MS) après un échec case chargée.
    NOW_MS = NOW_MS + MilitaryDrop.Flights.RETRY_MS
    triggerEvent("LoadChunk")
    assertTrue(#PLACED > 0 and inside(PLACED[1].x, PLACED[1].y, 5000, 200, 5040, 220), "posé dans la zone une fois sèche")
end

function T.large_zone_delivery_searches_the_loaded_rectangle_beyond_the_radius()
    placement(2)
    ROADS = { { x = 5020, y = 200, w = 4, h = 20 } }
    zonesFile({ zone("z1", "Delta", "Delta", 5000, 200, 5199, 399) })
    call()
    local flight = fly()
    local dropId = flight.dropId
    -- Tout est sous l'eau sauf un coin sec, à plus de RELOCATE_RADIUS du point.
    local function dry(x, y) return inside(x, y, 5180, 380, 5199, 399) end
    WATER = function(x, y) return not dry(x, y) end
    LOADED = function() return true end
    assertEq(MilitaryDrop.Server.findLandingNear(5021, 200, MilitaryDrop.Server.dropBounds(dropId)), nil,
        "rien à 30 cases du point")
    triggerEvent("LoadChunk")
    assertEq(#PLACED, 2, "caisses posées dans le coin sec")
    for _, placed in ipairs(PLACED) do
        assertTrue(dry(placed.x, placed.y) and dry(placed.x - 1, placed.y - 1),
            "caisse 2×2 hors de l'eau : " .. placed.x .. "," .. placed.y)
    end
    assertEq(PLACED[1].y, 381, "rangée sèche la plus proche du point (distance de Chebyshev)")
end

function T.large_zone_entirely_on_water_still_waits()
    placement(2)
    ROADS = { { x = 5020, y = 200, w = 4, h = 20 } }
    zonesFile({ zone("z1", "Delta", "Delta", 5000, 200, 5199, 399) })
    call()
    local flight = fly()
    -- Le rectangle (élargi d'une case) est sous l'eau, la rive sèche est dehors.
    WATER = function(x, y) return inside(x, y, 4999, 199, 5200, 400) end
    LOADED = function() return true end
    assertEq(MilitaryDrop.Server.deliver(5021, 200, "tester", flight.dropId), false, "aucune case sèche : attente")
    assertEq(#PLACED, 0, "rien posé, ni dans l'eau ni hors zone")
end

function T.protected_part_of_a_zone_gets_no_crate()
    placement(2)
    local seed = 0
    ZombRand = function(n)
        seed = seed + 7
        return seed % n
    end
    ROADS = { { x = 6000, y = 200, w = 100, h = 11 } }
    NONPVP = { { x = 6000, y = 0, x2 = 6050, y2 = 1000 } }
    zonesFile({ zone("z1", "Mixed", "Mixed", 6000, 200, 6099, 210) })
    assertEq(table.concat(MilitaryDrop.ZonesFile.zones()[1].warnings, ","), "nonPvp", "chevauchement signalé")
    for _ = 1, 5 do
        local x = choose()
        assertTrue(x ~= nil and x - 1 >= 6050, "caisse hors de la partie non-PvP : " .. tostring(x))
    end
end

-- ----------------------------------------------------------------------------
-- Repli et mode « zones si proche »
-- ----------------------------------------------------------------------------

function T.no_zone_falls_back_to_vanilla_towns_then_proximity_with_a_warning()
    placement(2)
    ROADS = { { x = 0, y = 0, w = 100000, h = 100000 } }
    zonesFile({})
    local x, y, info = choose()
    assertEq(info.source, "town", "ville vanilla")
    assertEq(info.zoneName, "Brandenburg", "la plus proche du demandeur")
    assertTrue(inside(x, y, 2056 - 150, 6070 - 150, 2056 + 150, 6070 + 150), "dans son rayon")
    assertEq(table.concat(MilitaryDrop.Zones.decoySectors(100, 200), ","),
        "Brandenburg,Echo Creek,Ekron,Fallas Lake,Irvington,Louisville,March Ridge,Muldraugh,Riverside,Rosewood,"
        .. "Valley Station,West Point", "leurre : villes en secteurs")
    MAP = "RavenCreek"
    x, y, info = choose()
    assertEq(x .. "," .. y, "250,200", "carte de mod sans zone : proximité")
    assertEq(info.source, "proximity", "repli signalé")
    assertTrue(logged("no zone is usable and no vanilla town"), "avertissement au journal")
    local notice = SENT[#SENT]
    assertEq(notice.command, "Notice", "message à l'admin connecté")
    assertEq(notice.args.key, "IGUI_MilitaryDrop_ZoneFallbackProximity", "clé de l'avertissement")
    ADMIN = false
    SENT = {}
    choose()
    assertEq(#SENT, 0, "pas de message à un joueur ordinaire")
end

function T.zones_if_near_mode_uses_only_close_zones()
    placement(3)
    SandboxVars.MilitaryDrop.DropZoneMaxDistance = 1000
    twoSectors()
    ROADS[#ROADS + 1] = { x = 0, y = 8000, w = 100000, h = 2000 }
    local _, _, info = choose()
    assertEq(info.zoneId, "z1", "Alpha à 900 cases : zone")
    SandboxVars.MilitaryDrop.DropZoneChoice = 2
    ZombRand = function(n) return n - 1 end
    _, _, info = choose()
    assertEq(info.sector, "Alpha", "Bravo, hors de portée, n'est pas candidat")
    ZombRand = function() return 0 end
    local x, y
    x, y, info = choose(makePlayer("south", 100, 9000))
    assertEq(info, nil, "aucune zone proche : proximité classique, sans avertissement")
    assertEq(x .. "," .. y, "250,9000", "anneau autour du demandeur")
end

-- ----------------------------------------------------------------------------
-- Leurre par secteur nommé
-- ----------------------------------------------------------------------------

function T.decoy_offers_named_sectors_and_falls_in_a_zone_of_it()
    SandboxVars.MilitaryDrop.RequisitionForm = true
    placement(2)
    twoSectors()
    local reply = call()
    assertEq(reply.status, "form", "formulaire")
    assertEq(reply.decoy.zones, true, "leurre en mode zones")
    assertEq(table.concat(reply.decoy.sectors, ","), "Alpha,Bravo", "noms des secteurs, ordre alphabétique")
    assertEq(order(nil, "N").status, "orderInvalid", "secteur de boussole refusé en mode zones")
    assertEq(order(nil, "Charlie").status, "orderInvalid", "secteur inconnu refusé")
    assertEq(order(nil, "Bravo").status, "accepted", "secteur proposé accepté")
    local flight = flights()[1]
    assertTrue(inside(flight.tx, flight.ty, 3000, 200, 3051, 251), "leurre dans une zone du secteur Bravo")
    local drop = MilitaryDrop.Secrets.privateState().drops[flight.dropId]
    assertEq(drop.decoy.sector, "Bravo", "secteur dans l'état privé")
    assertEq(drop.zone.name, "Bravo Mall", "zone dans l'état privé")
end

function T.single_sector_and_disabled_sector()
    SandboxVars.MilitaryDrop.RequisitionForm = true
    placement(2)
    twoSectors()
    zonesFile({
        zone("z1", "Alpha", "Alpha Park", 1000, 200, 1050, 250),
        zone("z2", "Bravo", "Bravo Mall", 3000, 200, 3050, 250, ", enabled = false"),
    })
    local reply = call()
    assertEq(table.concat(reply.decoy.sectors, ","), "Alpha", "un seul secteur actif")
    assertEq(order(nil, "Bravo").status, "orderInvalid", "secteur désactivé refusé au serveur")
end

function T.decoy_sector_without_landing_point_answers_no_site()
    SandboxVars.MilitaryDrop.RequisitionForm = true
    placement(2)
    KNOWN_WATER = { { x = 2992, y = 192, w = 64, h = 64 } }
    zonesFile({
        zone("z1", "Alpha", "Alpha Park", 1000, 200, 1050, 250),
        zone("z2", "Bravo", "Bravo Lake", 3000, 200, 3050, 250),
    })
    call()
    local reply = order(nil, "Bravo")
    assertEq(reply.status, "noSite", "aucune case dans Bravo")
    assertEq(reply.sector, "Bravo", "secteur rappelé")
    assertEq(reply.single, nil, "deux secteurs : un autre secteur est proposé")
    assertTrue(MilitaryDrop.Requisition.pendingFor("tester") ~= nil, "autorisation gardée")
    assertEq(order(nil, "Alpha").status, "accepted", "autre secteur sans rappeler")
end

function T.single_decoy_sector_without_landing_point_says_so()
    SandboxVars.MilitaryDrop.RequisitionForm = true
    placement(2)
    ROADS = {}
    KNOWN_WATER = { { x = 2992, y = 192, w = 64, h = 64 } }
    zonesFile({ zone("z2", "Bravo", "Bravo Lake", 3000, 200, 3050, 250) })
    local form = call()
    assertEq(table.concat(form.decoy.sectors, ","), "Bravo", "un seul secteur")
    local reply = order(nil, "Bravo")
    assertEq(reply.status, "noSite", "aucune case dans Bravo")
    assertEq(reply.sector, "Bravo", "secteur rappelé")
    assertEq(reply.single, true, "secteur unique signalé")
    assertTrue(MilitaryDrop.Requisition.pendingFor("tester") ~= nil, "autorisation gardée")
end

-- ----------------------------------------------------------------------------
-- Secteur du largage choisi par le joueur (ZONE-09, DropZoneChoice 3)
-- ----------------------------------------------------------------------------

local function playerChoice(mode)
    SandboxVars.MilitaryDrop.RequisitionForm = true
    SandboxVars.MilitaryDrop.DropZoneChoice = 3
    placement(mode or 2)
end

--- Nouvel appel possible : délai global libéré, vols oubliés.
local function nextCall()
    MilitaryDrop.Server.getState().lastDropHours = nil
    MilitaryDrop.Server.getState().flights = {}
end

function T.player_chosen_sector_is_offered_and_the_drop_falls_in_it()
    playerChoice()
    twoSectors()
    local reply = call()
    assertEq(reply.status, "form", "formulaire")
    assertEq(reply.drop and reply.drop.zones, true, "champ du secteur de largage")
    assertEq(table.concat(reply.drop.sectors, ","), "Alpha,Bravo", "secteurs actifs, ordre alphabétique")
    assertEq(table.concat(reply.decoy.sectors, ","), "Alpha,Bravo", "même liste que le leurre")
    assertEq(order({ rations = 1 }).status, "orderInvalid", "lots sans secteur refusés")
    assertEq(order({ rations = 1 }, nil, "Charlie").status, "orderInvalid", "secteur inconnu refusé")
    assertEq(order({ rations = 1 }, nil, "N").status, "orderInvalid", "point cardinal refusé")
    assertEq(order({ rations = 1 }, nil, 5).status, "orderInvalid", "secteur non textuel refusé")
    assertTrue(MilitaryDrop.Requisition.pendingFor("tester") ~= nil, "autorisation gardée après les refus")
    -- Bravo est le plus loin du demandeur : seul le choix du joueur l'explique.
    assertEq(order({ rations = 1 }, nil, "Bravo").status, "accepted", "secteur proposé accepté")
    local flight = flights()[1]
    assertTrue(inside(flight.tx, flight.ty, 3000, 200, 3051, 251), "largage dans une zone du secteur Bravo")
    local drop = MilitaryDrop.Secrets.privateState().drops[flight.dropId]
    assertEq(drop.zone.sector, "Bravo", "zone tirée dans le secteur choisi")
    assertEq(drop.zone.name, "Bravo Mall", "zone dans l'état privé")
    assertEq(drop.order.lots.rations, 1, "commande de lots")
    assertEq(drop.decoy, nil, "pas un leurre")
end

function T.player_sector_disabled_out_of_range_or_single()
    playerChoice()
    twoSectors()
    zonesFile({
        zone("z1", "Alpha", "Alpha Park", 1000, 200, 1050, 250),
        zone("z2", "Bravo", "Bravo Mall", 3000, 200, 3050, 250, ", enabled = false"),
    })
    local reply = call()
    assertEq(table.concat(reply.drop.sectors, ","), "Alpha", "secteur désactivé absent")
    assertEq(order({ rations = 1 }, nil, "Bravo").status, "orderInvalid", "secteur désactivé refusé au serveur")
    -- Mode 3 : seuls les secteurs à portée sont proposés.
    nextCall()
    twoSectors()
    placement(3)
    SandboxVars.MilitaryDrop.DropZoneMaxDistance = 1000
    reply = call()
    assertEq(table.concat(reply.drop.sectors, ","), "Alpha", "Bravo hors de portée")
    assertEq(order({ rations = 1 }, nil, "Bravo").status, "orderInvalid", "secteur hors de portée refusé")
    assertEq(order({ rations = 1 }, nil, "Alpha").status, "accepted", "secteur unique accepté")
    -- Mode 3 sans zone à portée : proximité, aucun champ.
    nextCall()
    PLAYER = makePlayer("tester", 100, 9000)
    ROADS[#ROADS + 1] = { x = 0, y = 8000, w = 100000, h = 2000 }
    reply = call()
    assertEq(reply.drop, nil, "aucune zone à portée : pas de champ")
    assertEq(order({ rations = 1 }, nil, "Alpha").status, "orderInvalid", "secteur sans champ refusé")
    assertEq(order({ rations = 1 }).status, "accepted", "lots seuls, près du demandeur")
end

function T.player_sectors_respect_the_minimum_distance()
    playerChoice()
    twoSectors()
    PLAYER = makePlayer("inside", 1010, 220)
    SandboxVars.MilitaryDrop.DropZoneMinDistance = 500
    local reply = call()
    assertEq(table.concat(reply.drop.sectors, ","), "Bravo", "Alpha trop proche : pas proposé")
    assertEq(table.concat(reply.decoy.sectors, ","), "Bravo", "le leurre suit la même liste")
    assertEq(order({ rations = 1 }, nil, "Alpha").status, "orderInvalid", "secteur trop proche refusé")
    assertEq(order(nil, "Alpha").status, "orderInvalid", "leurre aussi")
    -- Toutes trop proches : le seul secteur le plus proche.
    MilitaryDrop.Requisition.reset()
    SandboxVars.MilitaryDrop.DropZoneMinDistance = 5000
    reply = call()
    assertEq(table.concat(reply.drop.sectors, ","), "Alpha", "le plus proche seulement")
    assertEq(order({ rations = 1 }, nil, "Alpha").status, "accepted", "secteur imposé accepté")
end

function T.player_sector_falls_back_on_vanilla_towns()
    playerChoice()
    zonesFile({})
    ROADS = { { x = 0, y = 0, w = 100000, h = 100000 } }
    local reply = call()
    assertTrue(reply.drop ~= nil and #reply.drop.sectors > 1, "villes vanilla du repli proposées")
    assertEq(order({ rations = 1 }, nil, "Riverside").status, "accepted", "ville choisie")
    local drop = MilitaryDrop.Secrets.privateState().drops[flights()[1].dropId]
    assertEq(drop.zone.sector, "Riverside", "zone de la ville")
    assertEq(drop.zone.source, "town", "repli des villes")
end

function T.player_sector_without_landing_point_answers_no_site()
    playerChoice()
    KNOWN_WATER = { { x = 2992, y = 192, w = 64, h = 64 } }
    zonesFile({
        zone("z1", "Alpha", "Alpha Park", 1000, 200, 1050, 250),
        zone("z2", "Bravo", "Bravo Lake", 3000, 200, 3050, 250),
    })
    call()
    local reply = order({ rations = 1 }, nil, "Bravo")
    assertEq(reply.status, "noSite", "aucune case dans Bravo")
    assertEq(reply.sector, "Bravo", "secteur rappelé")
    assertEq(reply.single, nil, "deux secteurs : un autre secteur est proposé")
    assertTrue(MilitaryDrop.Requisition.pendingFor("tester") ~= nil, "autorisation gardée")
    assertTrue(logged("sector Bravo: no landing point"), "journal : secteur choisi")
    assertEq(order({ rations = 1 }, nil, "Alpha").status, "accepted", "autre secteur sans rappeler")
    -- Un seul secteur : signalé.
    nextCall()
    MilitaryDrop.Requisition.reset()
    zonesFile({ zone("z2", "Bravo", "Bravo Lake", 3000, 200, 3050, 250) })
    local form = call()
    assertEq(table.concat(form.drop.sectors, ","), "Bravo", "un seul secteur")
    reply = order({ rations = 1 }, nil, "Bravo")
    assertEq(reply.status, "noSite", "aucune case")
    assertEq(reply.single, true, "secteur unique signalé")
    assertTrue(MilitaryDrop.Requisition.pendingFor("tester") ~= nil, "autorisation gardée")
end

function T.checked_decoy_uses_its_own_sector()
    playerChoice()
    twoSectors()
    call()
    assertEq(order(nil, "Bravo", "Alpha").status, "orderInvalid", "leurre et secteur de largage ensemble refusés")
    assertEq(order({ rations = 1 }, "Bravo").status, "orderInvalid", "leurre avec des lots refusé")
    assertEq(order(nil, "Bravo").status, "accepted", "leurre seul, son secteur")
    local flight = flights()[1]
    assertTrue(inside(flight.tx, flight.ty, 3000, 200, 3051, 251), "leurre dans Bravo")
    assertEq(MilitaryDrop.Secrets.privateState().drops[flight.dropId].decoy.sector, "Bravo", "secteur du leurre")
end

function T.choices_1_and_2_offer_no_sector_field()
    SandboxVars.MilitaryDrop.RequisitionForm = true
    placement(2)
    twoSectors()
    local reply = call()
    assertEq(reply.drop, nil, "plus proche : pas de champ")
    assertEq(reply.decoy.zones, true, "leurre inchangé")
    assertEq(order({ rations = 1 }, nil, "Bravo").status, "orderInvalid", "secteur forgé refusé")
    assertEq(order({ rations = 1 }).status, "accepted", "lots seuls")
    assertEq(MilitaryDrop.Secrets.privateState().drops[flights()[1].dropId].zone.sector, "Alpha", "le plus proche")
    nextCall()
    SandboxVars.MilitaryDrop.DropZoneChoice = 2
    ZombRand = function(n) return n - 1 end
    reply = call()
    assertEq(reply.drop, nil, "au hasard : pas de champ")
    assertEq(order({ rations = 1 }, nil, "Alpha").status, "orderInvalid", "secteur forgé refusé")
    assertEq(order({ rations = 1 }).status, "accepted", "lots seuls")
    assertEq(MilitaryDrop.Secrets.privateState().drops[flights()[1].dropId].zone.sector, "Bravo", "au hasard")
end

function T.choice_3_without_the_form_takes_the_nearest_sector()
    SandboxVars.MilitaryDrop.DropZoneChoice = 3
    placement(2)
    twoSectors()
    ZombRand = function(n) return n - 1 end
    local _, _, info = choose()
    assertEq(info.sector, "Alpha", "rien à choisir : le plus proche, jamais au hasard")
end

function T.admin_sheet_offers_the_sector_field_with_choice_3()
    -- Décision du 2026-10-06 : la feuille admin suit les règles des joueurs.
    playerChoice()
    twoSectors()
    PLAYER = makePlayer("tester", 5000, 5000)
    MilitaryDrop.Server.getState().lastDropHours = WORLD_HOURS
    NOW_MS = NOW_MS + 5000
    MilitaryDrop.Server.handleRequest(PLAYER, { requestId = 1, force = true })
    local form = SENT[#SENT].args
    assertEq(form.forced, true, "feuille admin")
    assertEq(table.concat(form.drop.sectors, ","), "Alpha,Bravo", "champ du secteur de largage")
    assertEq(table.concat(form.decoy.sectors, ","), "Alpha,Bravo", "même liste que le leurre")
    assertEq(order({ rations = 1 }).status, "orderInvalid", "lots sans secteur refusés")
    assertEq(order({ rations = 1 }, nil, "Charlie").status, "orderInvalid", "secteur inconnu refusé")
    assertEq(order({ rations = 1 }, nil, "N").status, "orderInvalid", "point cardinal refusé")
    assertTrue(MilitaryDrop.Requisition.pendingFor("tester") ~= nil, "autorisation gardée après les refus")
    -- Alpha est le plus loin de l'admin : seul son choix l'explique.
    assertEq(order({ rations = 1 }, nil, "Alpha").status, "accepted", "secteur revalidé accepté")
    local flight = flights()[1]
    assertTrue(inside(flight.tx, flight.ty, 1000, 200, 1051, 251), "largage dans une zone d'Alpha")
    local drop = MilitaryDrop.Secrets.privateState().drops[flight.dropId]
    assertEq(drop.forced, true, "largage forcé")
    assertEq(drop.zone.sector, "Alpha", "zone tirée dans le secteur choisi")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, WORLD_HOURS, "délai global non consommé")
    -- Distance minimale depuis l'admin, aucune case : noSite et single.
    MilitaryDrop.Server.getState().flights = {}
    PLAYER = makePlayer("tester", 1010, 220)
    SandboxVars.MilitaryDrop.DropZoneMinDistance = 500
    KNOWN_WATER = { { x = 2992, y = 192, w = 64, h = 64 } }
    zonesFile({
        zone("z1", "Alpha", "Alpha Park", 1000, 200, 1050, 250),
        zone("z2", "Bravo", "Bravo Lake", 3000, 200, 3050, 250),
    })
    NOW_MS = NOW_MS + 5000
    MilitaryDrop.Server.handleRequest(PLAYER, { requestId = 1, force = true })
    form = SENT[#SENT].args
    assertEq(table.concat(form.drop.sectors, ","), "Bravo", "Alpha trop proche de l'admin : pas proposé")
    assertEq(order({ rations = 1 }, nil, "Alpha").status, "orderInvalid", "secteur trop proche refusé")
    local reply = order({ rations = 1 }, nil, "Bravo")
    assertEq(reply.status, "noSite", "aucune case dans Bravo")
    assertEq(reply.sector, "Bravo", "secteur rappelé")
    assertEq(reply.single, true, "secteur unique signalé")
    assertTrue(MilitaryDrop.Requisition.pendingFor("tester") ~= nil, "autorisation gardée")
end

-- ----------------------------------------------------------------------------
-- Annonce, secret
-- ----------------------------------------------------------------------------

function T.announcement_and_reminder_name_the_zone()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    placement(2)
    twoSectors()
    call()
    local flight = fly()
    -- Diffusion à la suite de l'annonce du décollage (Broadcast.air).
    local dropped
    for _, line in ipairs(AIRING.lines) do
        if line.codes == "MDRP" then
            dropped = dropped or line
        end
    end
    assertEq(dropped.text, "IGUI_MilitaryDrop_BroadcastDroppedZone|Alpha Park|1001|201", "nom puis grille")
    local announce
    for _, sent in ipairs(BROADCAST) do
        if sent.command == "DropAnnounce" then
            announce = sent.args
        end
    end
    assertEq(announce.x .. "," .. announce.y, "1001,201", "repère : grille seule")
    local public = MilitaryDrop.Server.getState()
    local function walk(t)
        for k, v in pairs(t) do
            assertTrue(tostring(k) ~= "zone" and v ~= "Alpha Park" and v ~= "Alpha", "zone absente de la ModData publique")
            if type(v) == "table" then
                walk(v)
            end
        end
    end
    walk(public)
    assertEq(MilitaryDrop.Secrets.privateState().drops[flight.dropId].zone.name, "Alpha Park", "état privé")
    AIRING, BROADCAST = nil, {}
    assertEq(MilitaryDrop.Server.repeatGrids(WORLD_HOURS + 6), 1, "rappel")
    assertEq(AIRING.lines[1].text, "IGUI_MilitaryDrop_BroadcastPendingZone|Alpha Park|1001|201", "rappel nommé")
    assertEq(BROADCAST[1].args.grids[1].zoneName, nil, "nom jamais envoyé à tous les clients")
    SandboxVars.MilitaryDrop.DropZoneAnnounceName = false
    AIRING = nil
    MilitaryDrop.Broadcast.dropped(1020, 200, "Alpha Park")
    assertEq(AIRING.lines[1].text, "IGUI_MilitaryDrop_BroadcastDropped|1020|200", "option désactivée : grille seule")
end

-- ----------------------------------------------------------------------------
-- Outil d'admin
-- ----------------------------------------------------------------------------

function T.forged_zone_commands_from_a_non_admin_are_refused()
    twoSectors()
    ADMIN = false
    local before = FILES[PATH]
    local replies = admin("ZoneAdd", { sector = "Alpha", name = "Mine", x1 = 10, y1 = 10, x2 = 20, y2 = 20 })
    assertEq(replies.ZoneReply.ok, false, "refusé")
    assertEq(replies.ZoneReply.error, "denied", "droit")
    assertEq(replies.ZoneListReply, nil, "aucune liste envoyée")
    assertEq(FILES[PATH], before, "fichier intact")
    replies = admin("ZoneList")
    assertEq(replies.ZoneReply.error, "denied", "liste refusée")
    assertEq(replies.ZoneListReply, nil, "zones jamais envoyées à un joueur")
    assertTrue(logged("refused for tester: not an admin"), "journal")
end

function T.admin_adds_a_zone_and_the_file_is_rewritten()
    twoSectors()
    local replies = admin("ZoneAdd", { sector = " Alpha ", name = "North Gate", x1 = 1050, y1 = 320, x2 = 1000, y2 = 300 })
    assertEq(replies.ZoneReply.ok, true, "zone ajoutée")
    assertEq(replies.ZoneReply.action, "add", "action")
    assertEq(replies.ZoneReply.id, "z3", "nouvel id")
    assertEq(table.concat(replies.ZoneReply.warnings, ","), "", "route Alpha : rien à signaler")
    local list = replies.ZoneListReply
    assertEq(#list.zones, 3, "liste renvoyée")
    local added = list.zones[3]
    assertEq(added.x1 .. "," .. added.y1 .. "," .. added.x2 .. "," .. added.y2, "1000,300,1050,320", "normalisée")
    assertEq(added.sector, "Alpha", "secteur nettoyé")
    assertEq(added.active, true, "active")
    assertEq(table.concat(list.sectors, ","), "Alpha,Bravo", "secteurs actifs")
    assertEq(list.map, "Muldraugh, KY", "carte de la partie écrite dans le fichier")
    assertEq(list.placement, 1, "mode")
    local data = MilitaryDrop.LotsFile.parse(FILES[PATH])
    assertEq(data.zones[3].id, "z3", "fichier réécrit")
    assertEq(data.zones[1].id, "z1", "zones existantes gardées")
end

--- Solo, chemin réel (sans Net.toPlayer simulé) : Net.toServer appelle
--- Server.onClientCommand, dont les réponses passent par Net.toPlayer jusqu'à
--- MilitaryDrop.Client.onServerCommand PENDANT l'envoi : ZoneReply puis
--- ZoneListReply, avec le requestId envoyé (nombre), avant le retour de l'envoi.
function T.solo_real_net_delivers_the_reply_with_its_number_during_the_send()
    twoSectors()
    -- Zones.lua garde sa table Net : y remettre les vraies fonctions.
    local Net = MilitaryDrop.Net
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    Net.toPlayer, Net.toAll, Net.toServer = MilitaryDrop.Net.toPlayer, MilitaryDrop.Net.toAll, MilitaryDrop.Net.toServer
    MilitaryDrop.Net = Net
    local got, sending = {}, false
    MilitaryDrop.Client = { onServerCommand = function(module, command, args)
        got[#got + 1] = command .. " " .. tostring(args.requestId) .. " " .. type(args.requestId) .. " "
            .. tostring(args.ok) .. (sending and " pendant" or " après")
    end }
    NOW_MS = NOW_MS + 1000
    local args = { sector = "Alpha", name = "Gate", x1 = 1000, y1 = 300, x2 = 1010, y2 = 310, weight = 1,
        requestId = 7 }
    sending = true
    Net.toServer(PLAYER, "ZoneAdd", args)
    sending = false
    assertEq(table.concat(got, ", "), "ZoneReply 7 number true pendant, ZoneListReply 7 number nil pendant",
        "réponses du vrai serveur pendant l'envoi, même numéro")
    assertEq(args.requestId, 7, "table envoyée intacte")
end

function T.admin_add_refuses_bad_zones()
    twoSectors()
    NONPVP = { { x = 7000, y = 7000, x2 = 7100, y2 = 7100 } }
    SAFEHOUSES = { { x = 8000, y = 8000, w = 10, h = 10 } }
    local cases = {
        { { sector = "A", name = "N", x1 = 19990, y1 = 10, x2 = 20010, y2 = 20 }, "offMap", "hors carte" },
        { { sector = "A", name = "N", x1 = 10, y1 = 10, x2 = 320, y2 = 20 }, "tooBig", "plus de 300 cases" },
        { { sector = "A", name = "N", x1 = "a", y1 = 10, x2 = 20, y2 = 20 }, "invalid", "coordonnée illisible" },
        { { sector = "A", name = "N", x1 = 0 / 0, y1 = 10, x2 = 20, y2 = 20 }, "invalid", "NaN" },
        { { sector = "A", name = "N", x1 = 10, y1 = 10, x2 = 20, y2 = 20, weight = 101 }, "invalid", "poids" },
        { { sector = "", name = "N", x1 = 10, y1 = 10, x2 = 20, y2 = 20 }, "badSector", "secteur vide" },
        { { sector = "A", name = string.rep("n", 33), x1 = 10, y1 = 10, x2 = 20, y2 = 20 }, "badName", "nom trop long" },
        { { sector = "A", name = "N", x1 = 7050, y1 = 7050, x2 = 7200, y2 = 7200 }, "overlapNonPvp", "zone non-PvP" },
        { { sector = "A", name = "N", x1 = 7900, y1 = 7900, x2 = 8000, y2 = 8000 }, "overlapSafehouse", "refuge" },
    }
    local before = FILES[PATH]
    for _, case in ipairs(cases) do
        local replies = admin("ZoneAdd", case[1])
        assertEq(replies.ZoneReply.ok, false, case[3])
        assertEq(replies.ZoneReply.error, case[2], case[3])
    end
    assertEq(FILES[PATH], before, "fichier jamais écrit")
    -- Cadence : deux commandes en moins de 500 ms.
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", "ZoneList", PLAYER, {})
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", "ZoneList", PLAYER, {})
    assertEq(SENT[#SENT].command, "ZoneReply", "seconde commande refusée")
    assertEq(SENT[#SENT].args.error, "busy", "cadence")
end

function T.admin_enables_deletes_reloads_and_never_overwrites_a_broken_file()
    twoSectors()
    local replies = admin("ZoneSetEnabled", { id = "z2", enabled = false })
    assertEq(replies.ZoneReply.ok, true, "désactivée")
    assertEq(replies.ZoneReply.action, "enable", "action")
    assertEq(replies.ZoneListReply.zones[2].enabled, false, "liste à jour")
    assertEq(replies.ZoneListReply.zones[2].active, false, "inactive")
    assertEq(table.concat(replies.ZoneListReply.sectors, ","), "Alpha", "secteur Bravo retiré")
    assertEq(admin("ZoneSetEnabled", { id = "z9", enabled = true }).ZoneReply.error, "unknownZone", "zone inconnue")
    assertEq(admin("ZoneSetEnabled", { id = "z1", enabled = "yes" }).ZoneReply.error, "invalid", "booléen exigé")
    replies = admin("ZoneDelete", { id = "z1" })
    assertEq(replies.ZoneReply.ok, true, "supprimée")
    assertEq(#replies.ZoneListReply.zones, 1, "une zone restante")
    -- Édition manuelle cassée : rechargement signalé, outil bloqué.
    FILES[PATH] = "return { zones = { { id = \"z2\" } }"
    replies = admin("ZoneReload")
    assertEq(replies.ZoneReply.ok, false, "fichier illisible")
    assertEq(replies.ZoneReply.error, "syntaxError", "code")
    assertEq(#replies.ZoneListReply.zones, 0, "aucune zone")
    assertTrue(replies.ZoneListReply.problems[1]:find("syntax error, line 1", 1, true) ~= nil, "problème renvoyé")
    local broken = FILES[PATH]
    replies = admin("ZoneAdd", { sector = "A", name = "N", x1 = 1000, y1 = 200, x2 = 1010, y2 = 210 })
    assertEq(replies.ZoneReply.error, "syntaxError", "écriture refusée")
    assertEq(admin("ZoneDelete", { id = "z2" }).ZoneReply.error, "syntaxError", "suppression refusée")
    assertEq(FILES[PATH], broken, "édition manuelle jamais écrasée")
end

function T.admin_tool_never_overwrites_a_manual_edit_made_while_running()
    twoSectors()
    MilitaryDrop.ZonesFile.report()
    -- L'admin ajoute une zone à la main, serveur lancé, sans « Recharger ».
    FILES[PATH] = FILES[PATH]:gsub("    },\n}\n$", '        { id = "z9", sector = "Alpha", name = "Manual", x1 = 1000,'
        .. ' y1 = 300, x2 = 1010, y2 = 310 },\n    },\n}\n')
    local replies = admin("ZoneSetEnabled", { id = "z1", enabled = false })
    assertEq(replies.ZoneReply.ok, true, "modifiée")
    local data = MilitaryDrop.LotsFile.parse(FILES[PATH])
    assertEq(#data.zones, 3, "zone ajoutée à la main gardée")
    assertEq(data.zones[3].id, "z9", "édition manuelle à la base de la réécriture")
    assertEq(data.zones[1].enabled, false, "modification de l'outil écrite")
    -- Édition manuelle cassée, toujours sans « Recharger » : rien n'est écrit.
    FILES[PATH] = FILES[PATH]:gsub('name = "Manual"', 'name = "Manual')
    local broken = FILES[PATH]
    for _, step in ipairs({
        { "ZoneAdd", { sector = "A", name = "N", x1 = 1000, y1 = 200, x2 = 1010, y2 = 210 } },
        { "ZoneSetEnabled", { id = "z2", enabled = false } },
        { "ZoneDelete", { id = "z2" } },
    }) do
        replies = admin(step[1], step[2])
        assertEq(replies.ZoneReply.error, "syntaxError", step[1] .. " refusée")
        assertEq(FILES[PATH], broken, step[1] .. " : édition manuelle jamais écrasée")
    end
    assertEq(#replies.ZoneListReply.zones, 0, "fichier relu : aucune zone")
end

function T.admin_add_moves_the_file_map_to_the_current_one()
    twoSectors()
    -- Fichier tracé pour une autre carte : ses zones la gardent en propre.
    FILES[PATH] = FILES[PATH]:gsub("version = 1,\n", 'version = 1,\n    map = "RavenCreek",\n')
    MilitaryDrop.ZonesFile.reset()
    local replies = admin("ZoneAdd", { sector = "Alpha", name = "Gate", x1 = 1000, y1 = 300, x2 = 1010, y2 = 310 })
    assertEq(replies.ZoneReply.ok, true, "ajoutée")
    local data = MilitaryDrop.LotsFile.parse(FILES[PATH])
    assertEq(data.map, "Muldraugh, KY", "carte du fichier : celle de la partie")
    assertEq(data.zones[1].map, "RavenCreek", "zone existante : ancienne carte gardée")
    assertEq(data.zones[2].map, "RavenCreek", "idem")
    assertEq(data.zones[3].map, nil, "nouvelle zone sans map répété")
    local list = replies.ZoneListReply
    assertEq(list.zones[1].active, false, "zones existantes toujours sur leur carte")
    assertEq(list.zones[3].active, true, "nouvelle zone utilisable")
end

function T.admin_add_checks_the_zone_read_back()
    twoSectors()
    local before = FILES[PATH]
    -- Zone écartée à la relecture (cas imprévu) : refus, fichier remis en l'état.
    local build = MilitaryDrop.ZonesFile.build
    MilitaryDrop.ZonesFile.build = function(data)
        local report = build(data)
        for i = #report.zones, 1, -1 do
            if report.zones[i].id == "z3" then
                table.remove(report.zones, i)
            end
        end
        return report
    end
    local replies = admin("ZoneAdd", { sector = "Alpha", name = "Gate", x1 = 1000, y1 = 300, x2 = 1010, y2 = 310 })
    assertEq(replies.ZoneReply.ok, false, "pas de « ok » pour une zone absente à la relecture")
    assertEq(replies.ZoneReply.error, "invalid", "code")
    -- Le lecteur simulé rend une dernière ligne vide que BufferedReader ne
    -- rend pas : comparer sans les sauts de ligne finaux.
    assertEq((FILES[PATH]:gsub("\n+$", "")), (before:gsub("\n+$", "")), "fichier remis tel qu'il était")
    assertTrue(logged("drop zone z3 is not usable once read back"), "journal")
end

-- ----------------------------------------------------------------------------
-- Outil d'admin : modification (ZoneUpdate)
-- ----------------------------------------------------------------------------

function T.zone_update_from_a_non_admin_is_refused()
    twoSectors()
    ADMIN = false
    local before = FILES[PATH]
    local replies = admin("ZoneUpdate", { id = "z1", name = "Mine" })
    assertEq(replies.ZoneReply.ok, false, "refusé")
    assertEq(replies.ZoneReply.action, "update", "action")
    assertEq(replies.ZoneReply.error, "denied", "droit")
    assertEq(replies.ZoneListReply, nil, "aucune liste envoyée")
    assertEq(FILES[PATH], before, "fichier intact")
end

function T.zone_replies_echo_a_bounded_integer_request_id_only()
    twoSectors()
    local replies = admin("ZoneSetEnabled", { id = "z2", enabled = false, requestId = 42 })
    assertEq(replies.ZoneReply.requestId, 42, "numéro renvoyé dans ZoneReply")
    assertEq(replies.ZoneListReply.requestId, 42, "et dans la ZoneListReply qui suit")
    replies = admin("ZoneList", { requestId = 2147483647 })
    assertEq(replies.ZoneListReply.requestId, 2147483647, "borne haute acceptée")
    for _, bad in ipairs({ "42", 1.5, 0, -3, 2147483648, 0 / 0, math.huge, { 1 }, true }) do
        replies = admin("ZoneUpdate", { id = "z9", name = "N", requestId = bad })
        assertEq(replies.ZoneReply.error, "unknownZone", "commande traitée : " .. tostring(bad))
        assertEq(replies.ZoneReply.requestId, nil, "numéro ignoré : " .. tostring(bad))
        assertEq(replies.ZoneListReply.requestId, nil, "liste sans numéro : " .. tostring(bad))
    end
    -- Refus : le numéro accompagne aussi « busy » et « denied ».
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", "ZoneReload", PLAYER, { requestId = 7 })
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", "ZoneReload", PLAYER, { requestId = 8 })
    assertEq(SENT[#SENT].args.error, "busy", "cadence")
    assertEq(SENT[#SENT].args.requestId, 8, "numéro du refus « busy »")
    ADMIN = false
    replies = admin("ZoneDelete", { id = "z1", requestId = 9 })
    assertEq(replies.ZoneReply.error, "denied", "droit")
    assertEq(replies.ZoneReply.requestId, 9, "numéro du refus « denied »")
end

function T.zone_update_renames_and_keeps_the_rest()
    twoSectors()
    zonesFile({
        zone("z1", "Alpha", "Alpha Park", 1000, 200, 1050, 250, ", weight = 4, enabled = false"),
        zone("z2", "Bravo", "Bravo Mall", 3000, 200, 3050, 250),
    })
    local replies = admin("ZoneUpdate", { id = "z1", name = " North  Park ", sector = "Charlie", weight = 7 })
    assertEq(replies.ZoneReply.ok, true, "modifiée")
    assertEq(replies.ZoneReply.action, "update", "action")
    assertEq(replies.ZoneReply.id, "z1", "id")
    local data = MilitaryDrop.LotsFile.parse(FILES[PATH])
    local z1 = data.zones[1]
    assertEq(z1.id, "z1", "id conservé, même place")
    assertEq(z1.name, "North Park", "nom nettoyé")
    assertEq(z1.sector, "Charlie", "secteur")
    assertEq(z1.weight, 7, "poids")
    assertEq(z1.x1 .. "," .. z1.y1 .. "," .. z1.x2 .. "," .. z1.y2, "1000,200,1050,250", "rectangle inchangé")
    assertEq(z1.enabled, false, "état gardé")
    assertEq(data.zones[2].name, "Bravo Mall", "autre zone intacte")
    assertEq(replies.ZoneListReply.zones[1].name, "North Park", "liste à jour")
    assertTrue(logged("drop zone z1 updated by tester"), "journal")
end

function T.zone_update_retraces_with_the_same_checks_as_add()
    twoSectors()
    NONPVP = { { x = 7000, y = 7000, x2 = 7100, y2 = 7100 } }
    SAFEHOUSES = { { x = 8000, y = 8000, w = 10, h = 10 } }
    local before = FILES[PATH]
    local cases = {
        { { id = "z1", x1 = 19990, y1 = 10, x2 = 20010, y2 = 20 }, "offMap", "hors carte" },
        { { id = "z1", x1 = 10, y1 = 10, x2 = 320, y2 = 20 }, "tooBig", "plus de 300 cases" },
        { { id = "z1", x1 = 7050, y1 = 7050, x2 = 7200, y2 = 7200 }, "overlapNonPvp", "zone non-PvP" },
        { { id = "z1", x1 = 7900, y1 = 7900, x2 = 8000, y2 = 8000 }, "overlapSafehouse", "refuge" },
        { { id = "z1", x1 = 10, y1 = 10 }, "invalid", "rectangle incomplet" },
        { { id = "z1", x1 = 0 / 0, y1 = 10, x2 = 20, y2 = 20 }, "invalid", "NaN" },
        { { id = "z1" }, "invalid", "rien à changer" },
        { { id = "z1", weight = 0 }, "invalid", "poids" },
        { { id = "z1", name = "" }, "badName", "nom vide" },
        { { id = "z1", sector = string.rep("s", 33) }, "badSector", "secteur trop long" },
        { { id = "bad id", name = "N" }, "invalid", "id illisible" },
        { { id = "z9", name = "N" }, "unknownZone", "zone inconnue" },
    }
    for _, case in ipairs(cases) do
        local replies = admin("ZoneUpdate", case[1])
        assertEq(replies.ZoneReply.ok, false, case[3])
        assertEq(replies.ZoneReply.error, case[2], case[3])
    end
    assertEq(FILES[PATH], before, "fichier jamais écrit")
    local replies = admin("ZoneUpdate", { id = "z2", x1 = 3050, y1 = 320, x2 = 3000, y2 = 300 })
    assertEq(replies.ZoneReply.ok, true, "retracée")
    assertEq(replies.ZoneReply.id, "z2", "id conservé")
    local data = MilitaryDrop.LotsFile.parse(FILES[PATH])
    local z2 = data.zones[2]
    assertEq(z2.id, "z2", "même id")
    assertEq(z2.x1 .. "," .. z2.y1 .. "," .. z2.x2 .. "," .. z2.y2, "3000,300,3050,320", "rectangle normalisé")
    assertEq(z2.name, "Bravo Mall", "nom gardé")
    assertEq(#data.zones, 2, "aucune zone ajoutée")
end

function T.zone_update_never_overwrites_an_unreadable_file()
    twoSectors()
    FILES[PATH] = "return { zones = { { id = \"z1\" } }"
    local broken = FILES[PATH]
    local replies = admin("ZoneUpdate", { id = "z1", name = "N" })
    assertEq(replies.ZoneReply.ok, false, "refusé")
    assertEq(replies.ZoneReply.error, "syntaxError", "fichier illisible")
    assertEq(FILES[PATH], broken, "édition manuelle jamais écrasée")
end

function T.zone_update_checks_the_zone_read_back()
    twoSectors()
    local before = FILES[PATH]
    local build = MilitaryDrop.ZonesFile.build
    MilitaryDrop.ZonesFile.build = function(data)
        local report = build(data)
        for _, z in ipairs(report.zones) do
            if z.id == "z1" and z.name == "Gate" then
                z.name = "Other"
            end
        end
        return report
    end
    local replies = admin("ZoneUpdate", { id = "z1", name = "Gate" })
    assertEq(replies.ZoneReply.ok, false, "valeur relue différente")
    assertEq(replies.ZoneReply.error, "invalid", "code")
    assertEq((FILES[PATH]:gsub("\n+$", "")), (before:gsub("\n+$", "")), "fichier remis tel qu'il était")
    assertTrue(logged("drop zone z1 does not read back as written"), "journal")
end

function T.zone_update_retrace_moves_a_zone_to_the_current_map()
    twoSectors()
    FILES[PATH] = FILES[PATH]:gsub("version = 1,\n", 'version = 1,\n    map = "RavenCreek",\n')
    MilitaryDrop.ZonesFile.reset()
    local replies = admin("ZoneUpdate", { id = "z1", name = "Renamed" })
    assertEq(replies.ZoneReply.ok, true, "renommage d'une zone d'une autre carte accepté")
    assertEq(MilitaryDrop.LotsFile.parse(FILES[PATH]).zones[1].map, nil, "carte inchangée sans retracé")
    replies = admin("ZoneUpdate", { id = "z1", x1 = 1000, y1 = 300, x2 = 1010, y2 = 310 })
    assertEq(replies.ZoneReply.ok, true, "retracée")
    local data = MilitaryDrop.LotsFile.parse(FILES[PATH])
    assertEq(data.zones[1].map, "Muldraugh, KY", "zone retracée sur la carte de la partie")
    assertEq(data.zones[2].map, nil, "autre zone inchangée")
    assertEq(replies.ZoneListReply.zones[1].active, true, "zone retracée utilisable")
    assertEq(replies.ZoneListReply.zones[2].active, false, "autre zone toujours sur l'ancienne carte")
end

function T.vanilla_map_included_by_a_mod_map_keeps_the_town_fallback()
    placement(2)
    ROADS = { { x = 0, y = 0, w = 100000, h = 100000 } }
    zonesFile({})
    MAP = "ModCity"
    getLotDirectories = function() return javaList({ "ModCity", "Muldraugh, KY" }) end
    local _, _, info = choose()
    assertEq(info.source, "town", "carte vanilla chargée par lots= : villes vanilla")
    getLotDirectories = nil
    MilitaryDrop.ZonesFile.reset()
    _, _, info = choose()
    assertEq(info.source, "proximity", "sans l'API, Map= seul : carte vanilla absente")
end

-- ----------------------------------------------------------------------------
-- Largage forcé de l'admin : mêmes règles qu'un joueur (décision du
-- 2026-10-06, qui remplace l'analyse §2.1)
-- ----------------------------------------------------------------------------

local function forcedCall()
    NOW_MS = NOW_MS + 5000
    MilitaryDrop.Server.handleRequest(PLAYER, { requestId = 1, force = true })
    return SENT[#SENT].args
end

function T.forced_admin_drop_falls_in_a_zone()
    placement(2)
    twoSectors()
    PLAYER = makePlayer("tester", 5000, 5000)
    assertEq(forcedCall().status, "accepted", "largage forcé direct")
    local flight = flights()[1]
    assertTrue(inside(flight.tx, flight.ty, 3000, 200, 3051, 251), "zone de Bravo, le plus proche de l'admin")
    local drop = MilitaryDrop.Secrets.privateState().drops[flight.dropId]
    assertEq(drop.forced, true, "largage forcé")
    assertEq(drop.zone.name, "Bravo Mall", "zone rangée dans l'état privé")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, nil, "délai global non consommé")
    -- Mode 3 avec une zone à portée de l'admin : zones aussi.
    placement(3)
    SandboxVars.MilitaryDrop.DropZoneMaxDistance = 20000
    forcedCall()
    flight = flights()[2]
    assertTrue(inside(flight.tx, flight.ty, 3000, 200, 3051, 251), "mode 3 : zone")
    -- DropZoneChoice 3 sans formulaire : rien à choisir, le plus proche.
    placement(2)
    SandboxVars.MilitaryDrop.DropZoneChoice = 3
    ZombRand = function(n) return n - 1 end
    forcedCall()
    assertEq(MilitaryDrop.Secrets.privateState().drops[flights()[3].dropId].zone.sector, "Bravo",
        "choix 3 sans feuille : secteur le plus proche")
end

function T.forced_admin_sheet_decoy_uses_named_sectors()
    SandboxVars.MilitaryDrop.RequisitionForm = true
    placement(2)
    twoSectors()
    PLAYER = makePlayer("tester", 5000, 5000)
    local form = forcedCall()
    assertEq(form.status, "form", "feuille admin")
    assertEq(form.forced, true, "marquée forcée")
    assertEq(form.drop, nil, "choix 1 : pas de champ du secteur de largage")
    assertEq(form.decoy.zones, true, "leurre en mode zones")
    assertEq(table.concat(form.decoy.sectors, ","), "Alpha,Bravo", "secteurs nommés")
    assertEq(order(nil, "N").status, "orderInvalid", "secteur de boussole refusé en mode zones")
    assertEq(order(nil, "Alpha").status, "accepted", "leurre dans Alpha")
    local flight = flights()[1]
    assertTrue(inside(flight.tx, flight.ty, 1000, 200, 1051, 251), "leurre dans une zone d'Alpha")
    local drop = MilitaryDrop.Secrets.privateState().drops[flight.dropId]
    assertEq(drop.forced, true, "forcé")
    assertEq(drop.decoy.sector, "Alpha", "secteur du leurre")
    assertEq(drop.zone.name, "Alpha Park", "zone dans l'état privé")
end

function T.forced_admin_drop_in_proximity_mode_is_unchanged()
    SandboxVars.MilitaryDrop.DropZoneChoice = 3
    twoSectors()
    ROADS[#ROADS + 1] = { x = 0, y = 0, w = 100000, h = 100000 }
    PLAYER = makePlayer("tester", 5000, 5000)
    assertEq(forcedCall().status, "accepted", "largage forcé direct")
    local flight = flights()[1]
    assertEq(flight.tx .. "," .. flight.ty, "5150.5,5000.5", "anneau autour de l'admin")
    assertEq(MilitaryDrop.Secrets.privateState().drops[flight.dropId].zone, nil, "aucune zone rangée")
    SandboxVars.MilitaryDrop.RequisitionForm = true
    local form = forcedCall()
    assertEq(form.drop, nil, "proximité : pas de champ, même avec le choix 3")
    assertEq(form.decoy.zones, nil, "leurre hors zones")
    assertEq(table.concat(form.decoy.sectors, ","), "N,E,S,W", "secteurs de boussole")
    assertEq(order(nil, "N").status, "accepted", "leurre au nord")
    flight = flights()[2]
    assertTrue(flight.ty < 5000, "leurre au nord de l'admin")
end

function T.crash_supplies_land_at_the_wreck_even_far_from_the_zone()
    placement(2)
    twoSectors()
    call()
    local dropId = flights()[1].dropId
    assertTrue(MilitaryDrop.Server.dropBounds(dropId) ~= nil, "largage de zone")
    LOADED = function() return true end
    assertEq(MilitaryDrop.Server.deliver(9000, 9000, "tester", dropId, { crash = true }), true, "fournitures posées")
    assertTrue(#PLACED > 0 and PLACED[1].x >= 8970 and PLACED[1].x <= 9030, "près de l'épave, hors zone")
end

function T.zones_are_read_at_server_start()
    twoSectors()
    FILES[PATH] = nil
    triggerEvent("OnServerStarted")
    assertTrue(FILES[PATH] ~= nil, "fichier créé au démarrage")
    assertTrue(logged("drop zones: 0 (0 active) from created"), "résumé au journal")
end

-- ----------------------------------------------------------------------------
-- Options changées en cours de partie (à chaud)
-- ----------------------------------------------------------------------------

--- Options Java de la partie, copiées de SandboxVars, qui reste périmé (solo :
--- l'éditeur d'options du menu de debug ne change que les options Java).
local function javaOptions()
    local values = {}
    for name, value in pairs(SandboxVars.MilitaryDrop) do
        values["MilitaryDrop." .. name] = value
    end
    return useJavaSandboxOptions(values)
end

function T.placement_option_changed_during_the_game_applies_at_once()
    local java = javaOptions()
    twoSectors()
    ROADS[#ROADS + 1] = { x = 0, y = 0, w = 100000, h = 100000 }
    local _, _, info = choose()
    assertEq(info, nil, "proximité au chargement")
    assertEq(admin("ZoneList").ZoneListReply.placement, 1, "panneau : proximité")
    java["MilitaryDrop.DropPlacement"] = 2
    _, _, info = choose()
    assertEq(info and info.sector, "Alpha", "zones : dès le largage suivant")
    assertEq(admin("ZoneList").ZoneListReply.placement, 2, "panneau : nouveau mode lu par le serveur")
    assertEq(table.concat(MilitaryDrop.Zones.decoySectors(100, 200), ","), "Alpha,Bravo", "leurre : secteurs")
    java["MilitaryDrop.DropPlacement"] = 1
    _, _, info = choose()
    assertEq(info, nil, "retour à la proximité")
end

function T.zone_options_changed_during_the_game_apply_at_once()
    local java = javaOptions()
    java["MilitaryDrop.DropPlacement"] = 2
    twoSectors()
    local caller = makePlayer("inside", 1010, 220)
    local _, _, info = choose(caller)
    assertEq(info.sector, "Alpha", "secteur le plus proche")
    java["MilitaryDrop.DropZoneMinDistance"] = 500
    _, _, info = choose(caller)
    assertEq(info.sector, "Bravo", "distance minimale : Alpha écartée")
    java["MilitaryDrop.DropZoneMinDistance"] = 0
    java["MilitaryDrop.DropZoneChoice"] = 2
    ZombRand = function(n) return n - 1 end
    _, _, info = choose()
    assertEq(info.sector, "Bravo", "secteur au hasard")
    ZombRand = function() return 0 end
    java["MilitaryDrop.DropZoneChoice"] = 1
    java["MilitaryDrop.DropPlacement"] = 3
    java["MilitaryDrop.DropZoneMaxDistance"] = 1000
    ROADS[#ROADS + 1] = { x = 0, y = 8000, w = 100000, h = 2000 }
    _, _, info = choose()
    assertEq(info.zoneId, "z1", "zones proches : Alpha à 900 cases")
    java["MilitaryDrop.DropZoneMaxDistance"] = 500
    _, _, info = choose(makePlayer("south", 100, 9000))
    assertEq(info, nil, "portée réduite : proximité")
    assertEq(MilitaryDrop.Broadcast.announcesZone("Alpha Park"), true, "nom annoncé")
    java["MilitaryDrop.DropZoneAnnounceName"] = false
    assertEq(MilitaryDrop.Broadcast.announcesZone("Alpha Park"), false, "nom tu dès l'annonce suivante")
end

function T.player_sector_choice_changed_during_the_game_applies_at_once()
    SandboxVars.MilitaryDrop.RequisitionForm = true
    local java = javaOptions()
    java["MilitaryDrop.DropPlacement"] = 2
    twoSectors()
    assertEq(call().drop, nil, "plus proche au chargement : pas de champ")
    java["MilitaryDrop.DropZoneChoice"] = 3
    assertEq(order({ rations = 1 }).status, "orderInvalid", "feuille ouverte avant le changement : secteur exigé")
    local reply = call()
    assertEq(table.concat(reply.drop.sectors, ","), "Alpha,Bravo", "champ dès le formulaire suivant")
    assertEq(order({ rations = 1 }, nil, "Bravo").status, "accepted", "secteur choisi")
    assertEq(MilitaryDrop.Secrets.privateState().drops[flights()[1].dropId].zone.sector, "Bravo", "dans Bravo")
    MilitaryDrop.Server.getState().lastDropHours = nil
    MilitaryDrop.Server.getState().flights = {}
    call()
    java["MilitaryDrop.DropZoneChoice"] = 1
    assertEq(order({ rations = 1 }, nil, "Bravo").status, "orderInvalid", "retour au plus proche : secteur refusé")
    assertEq(call().drop, nil, "plus de champ au formulaire suivant")
end

return T
