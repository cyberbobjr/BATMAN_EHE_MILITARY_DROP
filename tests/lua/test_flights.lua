-- MilitaryDrop_Flights : attente d'un événement HEF, livraison différée
-- jusqu'au chargement de la case, reprise après redémarrage.

local T = {}

local function makeSquare(x, y)
    return {
        getX = function() return x end, getY = function() return y end, getZ = function() return 0 end,
        isOutside = function() return true end, isFree = function() return true end,
        isWaterSquare = function() return false end,
        getVehicleContainer = function() return nil end,
        -- Repli au sol : objet créé (instanceItem), marqué, puis posé.
        AddWorldInventoryItem = function(_, item, _, _, _, transmit)
            assert(type(item) == "table" and transmit == true, "objet déjà créé, transmis à la pose")
            PLACED[#PLACED + 1] = item.fullType
            PLACED_ITEMS[#PLACED_ITEMS + 1] = item
            return item
        end,
    }
end

function T.setup()
    -- Objet créé par le serveur (repli au sol des caisses).
    instanceItem = function(fullType)
        local item = { fullType = fullType, modData = {} }
        function item.getModData(self) return self.modData end
        function item.setName(self, text) self.name = text end
        function item.setCustomName(self, value) self.customName = value end
        return item
    end
    SandboxVars = { MilitaryDrop = { MinZombies = 0, MaxZombies = 0, CaseRolls = 1 } }
    isClient = function() return false end
    isServer = function() return false end
    MODDATA = {}
    ModData = { getOrCreate = function(tag)
        MODDATA[tag] = MODDATA[tag] or {}
        return MODDATA[tag]
    end }
    ZombRand = function() return 0 end
    ZombRandFloat = function(low) return low end
    getTimestampMs = function() return 0 end
    getGameTime = function() return { getWorldAgeHours = function() return 10 end } end
    addSound = function() end
    spawnHorde = function() end
    getNumActivePlayers = function() return 0 end
    PLACED = {}
    PLACED_ITEMS = {}
    LOADED = true
    -- Zone chargée : tout (LOADED), ou seulement les cases x < LOADED_UP_TO_X.
    LOADED_UP_TO_X = nil
    getCell = function()
        return { getGridSquare = function(_, x, y)
            if LOADED or (LOADED_UP_TO_X and x < LOADED_UP_TO_X) then
                return makeSquare(x, y)
            end
            return nil
        end }
    end
    getText = function(key) return key end
    FILES = {}
    getWorld = function()
        return {
            getGameMode = function() return "Sandbox" end,
            getWorld = function() return "Test Save" end,
        getMetaGrid = function()
            return {
                isValidSquare = function(_, x, y) return not (OFF_MAP and OFF_MAP(x, y)) end,
                getCellData = function() return {} end,
                getBuildingAt = function(_, x, y) return BUILDING and BUILDING(x, y) or nil end,
            }
        end,
        }
    end
    getFileReader = function(name)
        local value = FILES[name]
        if not value then
            return nil
        end
        return { readLine = function() return value end, close = function() end }
    end
    getFileWriter = function(name)
        return { write = function(_, text) FILES[name] = text end, close = function() end }
    end
    ChannelCategory = { Military = "Military" }
    AIRING = nil
    DynamicRadioChannel = { new = function(name, freq)
        return {
            freq = freq,
            getAiringBroadcast = function() return AIRING end,
            setAiringBroadcast = function(_, bc) AIRING = bc end,
        }
    end }
    RadioBroadCast = { new = function()
        return { lines = {}, AddRadioLine = function(self, line) self.lines[#self.lines + 1] = line end }
    end }
    RadioLine = { new = function(text, r, g, b, codes) return { text = text, codes = codes } end }
    getZomboidRadio = function() return { removeChannelName = function() end } end
    CHANNELS = {}
    SCRIPT_MANAGER = {
        AddChannel = function(_, channel) CHANNELS[#CHANNELS + 1] = channel end,
        getRadioChannel = function() return CHANNELS[1] end,
    }
    SENT = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Flight.lua")
    VehicleDistributions = { {} }
    SPAWNED = {}
    addVehicleDebug = function(script) SPAWNED[#SPAWNED + 1] = script return VEHICLE end
    IsoDirections = { getRandom = function() return "N" end }
    loadMod("server/MilitaryDrop/MilitaryDrop_Crate.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    getActivatedMods = function() return { size = function() return 0 end } end
    loadMod("server/MilitaryDrop/MilitaryDrop_Smoke.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Server.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Teams.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Broadcast.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Flights.lua")
    MilitaryDrop.Client = { onServerCommand = function(_, command, args)
        SENT[#SENT + 1] = { command = command, args = args }
    end }
end

local function launch()
    return MilitaryDrop.Flights.launch(500, 600, "tester", 1)
end

local function commands()
    local list = {}
    for _, sent in ipairs(SENT) do
        list[#list + 1] = sent.command
    end
    return table.concat(list, ",")
end

function T.hef_event_near_target_delays_departure()
    HTT = { Server = { state = { active = true, centerX = 520, centerY = 610, radius = 50 } } }
    local flight = launch()
    MilitaryDrop.Flights.advance(flight, 0.25)
    assertEq(flight.started, false, "départ retardé")
    assertEq(flight.elapsed, 0, "le vol n'avance pas")
    HTT.Server.state.active = false
    MilitaryDrop.Flights.advance(flight, 0.25)
    assertEq(flight.started, true, "départ quand le ciel est libre")
    assertEq(SENT[1].command, "FlightStart", "clients prévenus")
end

function T.far_hef_event_does_not_delay()
    HTT = { Server = { state = { active = true, centerX = 5000, centerY = 5000, radius = 50 } } }
    local flight = launch()
    MilitaryDrop.Flights.advance(flight, 0.25)
    assertEq(flight.started, true, "événement lointain ignoré")
end

function T.hold_is_limited()
    HTT = { Server = { state = { active = true, centerX = 500, centerY = 600, radius = 50 } } }
    local flight = launch()
    flight.holdSeconds = MilitaryDrop.Flights.MAX_HOLD_SECONDS
    MilitaryDrop.Flights.advance(flight, 0.25)
    assertEq(flight.started, true, "départ forcé après l'attente maximale")
end

--- Chunk de 8 × 8 cases dont le coin nord-ouest est (x0, y0).
local function makeChunk(x0, y0)
    return { getGridSquare = function(_, lx, ly) return makeSquare(x0 + lx, y0 + ly) end }
end

function T.far_drop_is_announced_before_its_area_loads()
    LOADED = false
    local flight = launch()
    for _ = 1, math.ceil((MilitaryDrop.Flight.dropTime(flight) + 0.5) / 0.25) do
        MilitaryDrop.Flights.advance(flight, 0.25)
    end
    assertTrue(commands():find("DropAnnounce") ~= nil, "coordonnées annoncées au largage")
    assertEq(#PLACED, 0, "zone non chargée : rien de posé")
    assertEq(listenerCount("LoadChunk"), 1, "livraison en attente")
end

function T.unloaded_square_waits_for_its_own_chunk()
    LOADED = false
    MilitaryDrop.Flights.deliverAt(500, 600, "tester")
    assertEq(#PLACED, 0, "case non chargée")
    assertEq(listenerCount("LoadChunk"), 1, "surveillance du chargement")
    -- Le joueur arrive de l'ouest : la zone chargée s'arrête à 24 cases du point.
    LOADED_UP_TO_X = 476
    triggerEvent("LoadChunk", makeChunk(468, 600))
    assertEq(#PLACED, 0, "bordure de la zone chargée : rien de posé loin du repère (bug du 2026-09-30)")
    LOADED_UP_TO_X = 504
    triggerEvent("LoadChunk", makeChunk(496, 600))
    assertEq(#PLACED, 1, "case du point chargée : livré")
    assertEq(listenerCount("LoadChunk"), 0, "surveillance arrêtée")
end

function T.delivery_lands_at_the_announced_point()
    LOADED = false
    SPAWNED = {}
    addVehicleDebug = function(script, _, _, square)
        SPAWNED[#SPAWNED + 1] = square
        return nil
    end
    MilitaryDrop.Flights.deliverAt(500, 600, "tester")
    LOADED_UP_TO_X = 476
    triggerEvent("LoadChunk", makeChunk(468, 600))
    LOADED_UP_TO_X = 600
    triggerEvent("LoadChunk", makeChunk(496, 600))
    local state = MilitaryDrop.Server.getState()
    assertEq(state.lastDrop.x, 500, "posé au point annoncé")
    assertEq(state.lastDrop.y, 600, "même ligne")
end

function T.no_ground_keeps_the_delivery_pending()
    LOADED = true
    local water = function(square) square.isWaterSquare = function() return true end return square end
    getCell = function()
        return { getGridSquare = function(_, x, y) return water(makeSquare(x, y)) end }
    end
    MilitaryDrop.Flights.deliverAt(500, 600, "tester")
    assertEq(#PLACED, 0, "que de l'eau : rien de posé")
    assertTrue(MilitaryDrop.Server.getState().pending["500,600"] ~= nil, "livraison toujours en attente")
end

function T.restart_resumes_flights_and_pending_deliveries()
    -- État relu de la sauvegarde : un vol en cours et une livraison en attente.
    local state = MilitaryDrop.Server.getState()
    state.flights = { MilitaryDrop.Flight.new(9, 500, 600, 0) }
    state.pending = { ["700,800"] = { x = 700, y = 800, requester = "tester" } }
    MilitaryDrop.Flights.restore()
    assertEq(#MilitaryDrop.Server.getState().flights, 1, "vol conservé")
    assertEq(listenerCount("OnTick"), 1, "le vol reprend")
    assertEq(listenerCount("LoadChunk"), 1, "livraison en attente surveillée")
    state.flights[1].started = true
    MilitaryDrop.Flights.advance(state.flights[1], 0.25)
    assertEq(SENT[1].command, "FlightStart", "vol repris renvoyé aux clients")
end

--- Largue le vol (avance jusqu'au passage au-dessus du point).
local function flyOver(flight)
    for _ = 1, math.ceil((MilitaryDrop.Flight.dropTime(flight) + 0.5) / 0.25) do
        MilitaryDrop.Flights.advance(flight, 0.25)
    end
end

function T.drop_id_follows_the_flight_and_the_pending_delivery()
    LOADED = false
    local flight = MilitaryDrop.Flights.launch(500, 600, "tester", 1, false, "D7")
    flyOver(flight)
    assertEq(MilitaryDrop.Server.getState().pending["500,600"].dropId, "D7", "dropId de la livraison en attente")
    for _, sent in ipairs(SENT) do
        assertEq(sent.args.dropId, nil, "jamais envoyé aux clients (" .. sent.command .. ")")
    end
    LOADED = true
    triggerEvent("LoadChunk", makeChunk(496, 600))
    assertEq(#PLACED_ITEMS, 1, "livré")
    assertEq(PLACED_ITEMS[1].modData.MilitaryDrop_dropId, "D7", "caisse marquée")
end

function T.restart_keeps_the_drop_id_of_flights_and_pending_deliveries()
    local state = MilitaryDrop.Server.getState()
    local flight = MilitaryDrop.Flight.new(9, 500.5, 600.5, 0)
    flight.requester, flight.dropId, flight.started, flight.dropped = "tester", "D5", true, false
    state.flights = { flight }
    state.pending = { ["700,800"] = { x = 700, y = 800, requester = "tester", dropId = "D9" } }
    LOADED = false
    MilitaryDrop.Flights.restore()
    LOADED = true
    triggerEvent("LoadChunk", makeChunk(696, 800))
    assertEq(PLACED_ITEMS[1].modData.MilitaryDrop_dropId, "D9", "livraison en attente reprise avec son dropId")
    flyOver(state.flights[1])
    assertEq(PLACED_ITEMS[2].modData.MilitaryDrop_dropId, "D5", "vol repris avec son dropId")
end

return T
