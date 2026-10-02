local T = {}
local function list(values)
    return { size = function() return #values end, get = function(_, i) return values[i+1] end }
end
local function item(name)
    local data = {}
    return { name = name, getModData = function() return data end }
end
local function square(x, y)
    return { getX = function() return x end, getY = function() return y end,
        isOutside = function() return true end, isWaterSquare = function() return WATER end,
        isFree = function() return not BLOCKED end, getVehicleContainer = function() return nil end,
        AddWorldInventoryItem = function(_, it, _, _, _, transmit)
            assertEq(transmit, true)
            GROUND[#GROUND+1] = it
        end }
end
function T.setup()
    isClient = function() return false end
    SandboxVars = { MilitaryDrop = { CrashFire = 2, CrashCrates = true } }
    ZombRand = function() return 0 end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Crash.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Salvage.lua")
    PRIVATE, SENT, GROUND, VEHICLES = {}, {}, {}, {}
    BODIES, DELIVERED, HORDES, SMOKES, FIRES, CLOSED = 0, 0, 0, 0, 0, 0
    TIME, HOURS, LOADED, BLOCKED, WATER = 10000, 10, true, false, false
    getTimestampMs = function() return TIME end
    getGameTime = function() return { getWorldAgeHours = function() return HOURS end } end
    getCell = function() return { getGridSquare = function(_, x, y)
        if not LOADED or (UNLOADED and UNLOADED(x,y)) then return nil end
        return square(x,y)
    end } end
    getAllOutfits = function() return list({ "Army", "Police" }) end
    IsoDirections = { N = "N", E = "E", S = "S", W = "W", getRandom = function() return "N" end }
    instanceItem = item
    addVehicleDebug = function(script, _, _, sq)
        VEHICLES[#VEHICLES+1] = { script = script, x = sq:getX(), y = sq:getY() }
        local data = {}
        return { getSqlId = function() return SPAWN_FAIL and -1 or #VEHICLES end,
            getPartByIndex = function() return { getModData = function() return data end } end,
            transmitPartModData = function() end }
    end
    RandomizedWorldBase = { createRandomDeadBody = function()
        BODIES = BODIES + 1
        local data = {}
        return { getModData = function() return data end, setFakeDead = function(_, v) assertEq(v,false) end,
            setReanimateTime = function(_, v) assertEq(v,-1) end,
            getContainer = function() return { AddItem = function(_, v) return type(v)=="string" and item(v) or v end } end }
    end }
    sendAddItemToContainer = function() end
    addSound = function() end
    spawnHorde = function() HORDES = HORDES + 1 end
    IsoFireManager = { StartFire = function() FIRES = FIRES+1 end, StartSmoke = function() SMOKES = SMOKES+1 end }
    MilitaryDrop.Secrets = { privateState = function() return PRIVATE end }
    MilitaryDrop.Net = { toAll = function(cmd) SENT[#SENT+1] = cmd end }
    MilitaryDrop.Trust = { onCrash = function() CLOSED = CLOSED + 1 end }
    MilitaryDrop.Broadcast = { mayday = function() SENT[#SENT+1] = "MaydayAnnounce" end }
    MilitaryDrop.Notes = { createMemo = function() return item("memo") end,
        createCodebook = function() return item("book") end }
    MilitaryDrop.Server = {
        findOpenGroundNear = function(x,y) return not WATER and getCell():getGridSquare(x,y,0) end,
        hordeSize = function() return 6 end,
        deliver = function(_, _, _, _, opts)
            assertEq(opts.crash,true)
            if DELIVERY_FAIL then return false end
            DELIVERED = DELIVERED+1
            return true
        end,
    }
    loadMod("server/MilitaryDrop/MilitaryDrop_Wreck.lua")
    FLIGHT = { id = 1, requester = "pilot", dropId = "D1", mayday = true,
        crash = { t = 50, x = 100, y = 100, dx = 1, dy = 0, cause = "storm" } }
end
function T.site_waits_for_loading_then_places_once()
    LOADED = false
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(#VEHICLES,0)
    assertEq(BODIES,0)
    assertEq(CLOSED,1)
    LOADED = true
    MilitaryDrop.Wreck.update()
    assertTrue(site.complete)
    assertEq(#VEHICLES,2)
    assertEq(BODIES,1)
    assertEq(DELIVERED,1)
    assertEq(HORDES,1)
    MilitaryDrop.Wreck.restore()
    MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(#VEHICLES,2)
    assertEq(BODIES,1)
    assertEq(DELIVERED,1)
    assertEq(HORDES,1)
end
function T.footprint_waits_for_every_square_including_the_next_chunk()
    UNLOADED = function(x,y) return x==105 and y==105 end
    local loaded, free = MilitaryDrop.Wreck.footprint(100,100,5)
    assertEq(loaded,false)
    assertEq(free,true)
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(site.done.main,nil)
    assertEq(#VEHICLES,1) -- La queue a son propre chunk.
end
function T.blocked_main_and_tail_fall_back_to_ground_materials()
    BLOCKED = true
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertTrue(site.complete)
    assertEq(site.done.main,"skipped")
    assertEq(site.done.tail,"skipped")
    assertEq(#VEHICLES,0)
    assertEq(#GROUND,9) -- 3 débris + 5 pièces du fuselage + 1 de la queue.
    MilitaryDrop.Wreck.update()
    assertEq(#GROUND,9)
end
function T.vehicle_refused_by_java_does_not_lose_the_fallback_materials()
    SPAWN_FAIL = true
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(site.done.main,"skipped")
    assertEq(#GROUND,9)
end
function T.supplies_and_fire_are_optional()
    SandboxVars.MilitaryDrop.CrashCrates = false
    SandboxVars.MilitaryDrop.CrashFire = 1
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertTrue(site.complete)
    assertEq(DELIVERED,0)
    assertEq(FIRES,0)
    assertEq(SMOKES,0)
end
function T.failed_supply_delivery_is_retried_without_repeating_the_pilot_or_horde()
    DELIVERY_FAIL = true
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(site.complete,nil)
    assertEq(BODIES,1)
    DELIVERY_FAIL = false
    MilitaryDrop.Wreck.update()
    assertTrue(site.complete)
    assertEq(BODIES,1)
    assertEq(HORDES,1)
    assertEq(DELIVERED,1)
end
function T.late_arrivals_get_smoke_but_expired_smoke_is_never_restarted()
    MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(SMOKES,1)
    TIME = TIME + 10001
    MilitaryDrop.Wreck.update()
    assertEq(SMOKES,2)
    HOURS = 12
    TIME = TIME + 10001
    MilitaryDrop.Wreck.restore()
    assertEq(SMOKES,2)
end
function T.an_interrupted_component_is_logged_but_not_spawned_twice()
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    site.done.pilot = "placing"
    MilitaryDrop.Wreck.restore()
    assertEq(site.done.pilot,"interrupted")
    assertEq(BODIES,1)
end
function T.restore_announces_a_crash_that_had_not_sent_its_mayday()
    LOADED = false
    FLIGHT.mayday = nil
    MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(SENT[1],"MaydayAnnounce")
    assertEq(SENT[2],"FlightCrash")
end
function T.water_is_never_accepted_as_a_vehicle_footprint()
    WATER = true
    local loaded, free = MilitaryDrop.Wreck.footprint(100,100,5)
    assertEq(loaded,true)
    assertEq(free,false)
    MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(#VEHICLES,0)
    assertEq(BODIES,0)
end
return T
