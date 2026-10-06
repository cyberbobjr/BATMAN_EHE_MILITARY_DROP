-- MilitaryDrop_Flights : attente d'un événement HEF, livraison différée
-- jusqu'au chargement de la case, reprise après redémarrage, deux largages
-- au même point (clé avec dropId, ancienne clé relue), nouvel essai espacé
-- d'une livraison bloquée.

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
    assertEq(MilitaryDrop.Server.getState().pending["500,600,D7"].dropId, "D7", "dropId de la livraison en attente")
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

function T.two_drops_at_the_same_point_are_both_delivered()
    -- Livraison d'une sauvegarde d'avant (clé « x,y »), puis deux largages au
    -- même point : aucun n'écrase l'autre.
    local state = MilitaryDrop.Server.getState()
    state.pending = { ["500,600"] = { x = 500, y = 600, requester = "tester", dropId = "D1" } }
    LOADED = false
    MilitaryDrop.Flights.restore()
    MilitaryDrop.Flights.deliverAt(500, 600, "tester", "D2")
    MilitaryDrop.Flights.deliverAt(500, 600, "tester", "D3")
    MilitaryDrop.Flights.deliverAt(500, 600, "tester", "D3")
    local count = 0
    for _ in pairs(state.pending) do
        count = count + 1
    end
    assertEq(count, 4, "quatre livraisons en attente, ancienne clé comprise")
    LOADED = true
    triggerEvent("LoadChunk", makeChunk(496, 600))
    local ids = {}
    for _, item in ipairs(PLACED_ITEMS) do
        ids[#ids + 1] = item.modData.MilitaryDrop_dropId
    end
    table.sort(ids)
    assertEq(table.concat(ids, ","), "D1,D2,D3,D3", "toutes livrées, l'ancienne entrée aussi")
    assertEq(listenerCount("LoadChunk"), 0, "plus rien en attente")
end

function T.blocked_delivery_is_retried_at_most_once_a_minute()
    -- Sondage des options (MilitaryDrop_Core.lua) : abonné permanent.
    local permanent = listenerCount("EveryOneMinute")
    local now = 0
    getTimestampMs = function() return now end
    local dry = false
    getCell = function()
        return { getGridSquare = function(_, x, y)
            if not LOADED then
                return nil
            end
            local square = makeSquare(x, y)
            square.isWaterSquare = function() return not dry end
            return square
        end }
    end
    local calls = 0
    local deliver = MilitaryDrop.Server.deliver
    MilitaryDrop.Server.deliver = function(...)
        calls = calls + 1
        return deliver(...)
    end
    -- Case jamais chargée : premier essai dès son chargement.
    LOADED = false
    MilitaryDrop.Flights.deliverAt(500, 600, "tester", "D1")
    assertEq(calls, 0, "rien tant que la case n'est pas chargée")
    LOADED = true
    triggerEvent("LoadChunk", makeChunk(496, 600))
    assertEq(calls, 1, "essai immédiat au premier chargement")
    for _ = 1, 5 do
        triggerEvent("LoadChunk", makeChunk(504, 600))
        triggerEvent("EveryOneMinute")
    end
    assertEq(calls, 1, "pas de nouvelle recherche avant RETRY_MS")
    now = MilitaryDrop.Flights.RETRY_MS
    triggerEvent("EveryOneMinute")
    assertEq(calls, 2, "nouvel essai espacé, même sans chargement de chunk")
    -- Case déchargée puis rechargée : essai immédiat.
    LOADED = false
    triggerEvent("LoadChunk", makeChunk(800, 800))
    LOADED, dry = true, true
    triggerEvent("LoadChunk", makeChunk(496, 600))
    assertEq(calls, 3, "case revenue : essai sans attendre")
    assertEq(#PLACED, 1, "livré")
    assertEq(listenerCount("EveryOneMinute"), permanent, "surveillance arrêtée")
end

local function maydaySetup()
    loadMod("shared/MilitaryDrop/MilitaryDrop_Crash.lua")
    getClimateManager = function() return { getIsThunderStorming = function() return false end } end
    CRASHES, MAYDAYS = 0, 0
    MilitaryDrop.Wreck = { add = function() CRASHES = CRASHES + 1 end }
    MilitaryDrop.Broadcast.mayday = function() MAYDAYS = MAYDAYS + 1 end
end

function T.crash_warns_before_impact_and_does_not_deliver_normally()
    maydaySetup()
    local flight = launch()
    assertTrue(flight.crash)
    flight.elapsed = 44
    MilitaryDrop.Flights.advance(flight, 1)
    assertEq(MAYDAYS, 1)
    assertEq(CRASHES, 0)
    MilitaryDrop.Flights.advance(flight, 5)
    assertEq(CRASHES, 1)
    assertEq(#PLACED, 0)
    MilitaryDrop.Flights.advance(flight, 1)
    assertEq(CRASHES, 1)
    assertEq(MAYDAYS, 1)
end

function T.crash_restore_creates_one_site_instead_of_rerolling_or_delivering()
    maydaySetup()
    local flight = launch()
    flight.started = true
    MilitaryDrop.Flights.restore()
    assertEq(CRASHES, 1)
    assertEq(#MilitaryDrop.Server.getState().flights, 0)
    MilitaryDrop.Flights.restore()
    assertEq(CRASHES, 1)
    assertEq(#PLACED, 0)
    assertTrue(flight.crash)
end

function T.admin_and_decoy_flights_are_not_randomly_crashed()
    maydaySetup()
    local admin = MilitaryDrop.Flights.launch(500,600,"tester",1,true)
    assertEq(admin.crash,nil)
    MilitaryDrop.Requisition = { orderOf = function() return { decoy=true } end }
    local decoy = MilitaryDrop.Flights.launch(500,600,"tester",1,false,"D1")
    assertEq(decoy.crash,nil)
end

function T.gunfire_checks_its_option_weapon_ammo_heading_and_distance()
    maydaySetup()
    SandboxVars.MilitaryDrop.CrashChance = 0
    SandboxVars.MilitaryDrop.CrashGunfireChance = 100
    local flight = launch()
    flight.started, flight.elapsed = true, 35
    MilitaryDrop.Guard.throttled = function() return false end
    instanceof = function(_, cls) return cls=="HandWeapon" end
    local px, ammo, heading = 300, 1, 1
    local weapon = { isRanged=function() return true end, getMaxDamage=function() return 1 end,
        isJammed=function() return false end, getCurrentAmmoCount=function() return ammo end,
        isRoundChambered=function() return false end }
    local player = { isDead=function() return false end, getZ=function() return 0 end,
        getX=function() return px end, getY=function() return 600.5 end,
        getPrimaryHandItem=function() return weapon end, getForwardDirectionX=function() return heading end,
        getForwardDirectionY=function() return 0 end }
    assertEq(MilitaryDrop.Flights.groundFire(player),false)
    SandboxVars.MilitaryDrop.CrashGunfire = true
    px = 1
    assertEq(MilitaryDrop.Flights.groundFire(player),false)
    px, ammo = 300, 0
    assertEq(MilitaryDrop.Flights.groundFire(player),false)
    ammo, heading = 1, -1
    assertEq(MilitaryDrop.Flights.groundFire(player),false)
    heading = 1
    assertTrue(MilitaryDrop.Flights.groundFire(player))
    assertEq(flight.crash.cause,"gunfire")
end

function T.next_crash_requires_admin_and_does_not_stack_orders()
    maydaySetup()
    local Flights, Server = MilitaryDrop.Flights, MilitaryDrop.Server
    local player = { getUsername=function() return "admin" end }
    local allowed, throttled = false, false
    Server.canForce = function() return allowed end
    MilitaryDrop.Guard.throttled = function() return throttled end
    assertEq(Server.COMMANDS.AdminCrashNext(player), "denied")
    assertEq(MilitaryDrop.Secrets.privateState().nextCrash, nil)
    allowed, throttled = true, true
    assertEq(Flights.adminCrashNext(player), "busy")
    assertEq(MilitaryDrop.Secrets.privateState().nextCrash, nil)
    throttled = false
    assertEq(Flights.adminCrashNext(player), "armed")
    assertEq(Flights.adminCrashNext(player), "armedAlready")
    assertEq(SENT[#SENT].args.key, "IGUI_MilitaryDrop_AdminCrashAlreadyArmed")
    assertEq(MilitaryDrop.Server.getState().nextCrash, nil, "ordre privé")
end

function T.next_crash_waits_for_takeoff_and_only_affects_one_flight_after_restart()
    maydaySetup()
    SandboxVars.MilitaryDrop.CrashChance = 0
    local Flights = MilitaryDrop.Flights
    local flying = launch()
    Flights.advance(flying, 0.25)
    MilitaryDrop.Secrets.privateState().nextCrash = true
    local queued = MilitaryDrop.Flights.launch(500,600,"tester",1,true)
    HTT = { Server={state={active=true, centerX=500, centerY=600, radius=100}} }
    Flights.advance(queued, 0.25)
    assertEq(queued.started, false)
    assertEq(MilitaryDrop.Secrets.privateState().nextCrash, true, "attente HEF")
    Flights.restore()
    Flights.advance(flying, 0.25)
    assertEq(flying.crash, nil, "vol déjà parti conservé")
    HTT = nil
    Flights.advance(queued, 0.25)
    assertEq(queued.crash.cause, "admin", "largage forcé ciblé")
    assertEq(MilitaryDrop.Secrets.privateState().nextCrash, nil)
    local nextFlight = MilitaryDrop.Flights.launch(500,600,"tester",2,true)
    Flights.advance(nextFlight, 0.25)
    assertEq(nextFlight.crash, nil, "ordre consommé une fois")
end

function T.condemned_flight_waiting_for_departure_is_not_crashed_by_restart()
    maydaySetup()
    local flight = launch()
    MilitaryDrop.Flights.restore()
    assertEq(CRASHES, 0)
    assertEq(#MilitaryDrop.Server.getState().flights, 1)
    assertTrue(flight.crash)
    MilitaryDrop.Flights.advance(flight, 0.25)
    assertTrue(flight.started)
end

return T
