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
    isServer = function() return false end
    SandboxVars = { MilitaryDrop = { CrashFire = 2, CrashCrates = true } }
    ZombRand = function() return 0 end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Crash.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Salvage.lua")
    PRIVATE, SENT, GROUND, VEHICLES, PILOTS = {}, {}, {}, {}, {}
    BODIES, DELIVERED, HORDES, SMOKES, FIRES, CLOSED = 0, 0, 0, 0, 0, 0
    TIME, HOURS, LOADED, BLOCKED, WATER = 10000, 10, true, false, false
    getTimestampMs = function() return TIME end
    getGameTime = function() return { getWorldAgeHours = function() return HOURS end } end
    getCell = function() return { getGridSquare = function(_, x, y)
        if not LOADED or (UNLOADED and UNLOADED(x,y)) then return nil end
        return square(x,y)
    end } end
    getAllOutfits = function() return list({ "Army", "Police" }) end
    IsoWorld = { getZombiesDisabled = function() return ZOMBIES_DISABLED == true end }
    isDebugEnabled = function() return false end
    addZombiesInOutfit = function(x,y,z,count,outfit,femaleChance)
        assertEq(count,1)
        assertEq(z,0)
        assertEq(outfit,"ArmyCamoGreen")
        assertEq(femaleChance,50)
        if CREW_FAIL and #PILOTS == 1 then return list({}) end
        local data = {}
        PILOTS[#PILOTS+1] = {x=x,y=y,data=data}
        return list({{getModData=function() return data end}})
    end
    IsoDirections = { N = "N", E = "E", S = "S", W = "W", getRandom = function() return "N" end }
    instanceItem = item
    addVehicleDebug = function(script, _, _, sq)
        local vehicleData = {}
        VEHICLES[#VEHICLES+1] = { script = script, x = sq:getX(), y = sq:getY(), modData = vehicleData }
        local data = {}
        return { getSqlId = function() return SPAWN_FAIL and -1 or #VEHICLES end,
            getModData = function() return vehicleData end,
            getPartByIndex = function() return { getModData = function() return data end } end,
            transmitPartModData = function() end }
    end
    RandomizedWorldBase = { createRandomDeadBody = function()
        BODIES = BODIES + 1
        local data = {}
        return { getModData = function() return data end, setFakeDead = function(_, v) assertEq(v,false) end,
            setReanimateTime = function(_, v) assertEq(v,-1) end,
            getContainer = function() return { AddItem = function(_, v)
                local added = type(v)=="string" and item(v) or v
                ADDED[#ADDED+1] = added
                return added
            end } end }
    end }
    sendAddItemToContainer = function() end
    addSound = function() end
    spawnHorde = function() HORDES = HORDES + 1 end
    FIRE_POS, SMOKE_POS = {}, {}
    IsoFireManager = { StartFire = function(_,sq,_,energy,life)
        FIRES = FIRES+1
        FIRE_POS[#FIRE_POS+1] = {x=sq:getX(),y=sq:getY(),energy=energy,life=life}
    end, StartSmoke = function(_,sq,_,energy,life)
        SMOKES = SMOKES+1
        SMOKE_POS[#SMOKE_POS+1] = {x=sq:getX(),y=sq:getY(),energy=energy,life=life}
    end }
    MilitaryDrop.Secrets = { privateState = function() return PRIVATE end }
    MilitaryDrop.Net = { toAll = function(cmd) SENT[#SENT+1] = cmd end }
    MilitaryDrop.Trust = { onCrash = function(_, supplies) CLOSED = CLOSED + 1 SUPPLIES_PENDING = supplies end }
    MilitaryDrop.Broadcast = { mayday = function() SENT[#SENT+1] = "MaydayAnnounce" end }
    MilitaryDrop.Notes = { createMemo = function() return item("memo") end,
        createCodebook = function() return item("book") end }
    MilitaryDrop.WreckSmoke = { show = function(args)
        SMOKES = SMOKES+1
        SMOKE_POS[#SMOKE_POS+1] = {x=args.x,y=args.y}
    end }
    ADDED = {}
    MilitaryDrop.Server = {
        clock = function() return 2412.5 end,
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
    assertEq(#PILOTS,2)
    assertEq(PILOTS[1].data.MilitaryDrop_crashSite,site.id)
    assertTrue(PILOTS[1].x ~= PILOTS[2].x or PILOTS[1].y ~= PILOTS[2].y)
    assertEq(DELIVERED,1)
    assertEq(HORDES,1)
    MilitaryDrop.Wreck.restore()
    MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(#VEHICLES,2)
    assertEq(BODIES,1)
    assertEq(DELIVERED,1)
    assertEq(HORDES,1)
    assertEq(#PILOTS,2)
end
function T.pilot_may_carry_a_damaged_fulton_kit_once()
    local rolls = 0
    MilitaryDrop.FultonLoot = { DAMAGED_KIT = "MilitaryDrop.FultonKitDamaged",
        rollWreck = function() rolls = rolls + 1 return true end }
    MilitaryDrop.Wreck.add(FLIGHT)
    local kits = 0
    for _, added in ipairs(ADDED) do
        if added.name == "MilitaryDrop.FultonKitDamaged" then
            kits = kits + 1
        end
    end
    assertEq(kits, 1, "un kit endommagé sur le pilote")
    MilitaryDrop.Wreck.restore()
    MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(rolls, 1, "tiré une seule fois par site")
end

--- Épaves marquées contre les mods qui re-remplissent les véhicules de mod
--- (resetedContainers, Crate.protect).
function T.wrecks_carry_the_refill_marker()
    MilitaryDrop.Crate = { protect = function(vehicle) vehicle:getModData().resetedContainers = true end }
    MilitaryDrop.Wreck.add(FLIGHT)
    MilitaryDrop.Wreck.update()
    assertEq(#VEHICLES,2)
    assertEq(VEHICLES[1].modData.resetedContainers,true,"fuselage")
    assertEq(VEHICLES[2].modData.resetedContainers,true,"queue")
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
    BLOCKED = false -- La zone bloquée reporte les zombies, sans perdre le butin.
    MilitaryDrop.Wreck.update()
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
function T.by_default_the_crash_site_has_no_supplies_but_everything_else()
    -- Défaut du 2026-10-06 : CrashCrates faux, la commande est perdue avec l'appareil.
    SandboxVars.MilitaryDrop.CrashCrates = nil
    assertEq(MilitaryDrop.Config.get("CrashCrates"),false)
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(site.crates,false)
    assertEq(SUPPLIES_PENDING,false,"aucune fourniture attendue")
    assertTrue(site.complete)
    assertEq(DELIVERED,0)
    assertEq(site.done.supplies,nil)
    assertEq(#VEHICLES,2)
    assertEq(#GROUND,3)
    assertEq(BODIES,1)
    assertTrue(#ADDED > 0, "documents et enregistreur sur le pilote")
    assertEq(#PILOTS,2)
    assertEq(HORDES,1)
    assertEq(SMOKES,1)
    assertEq(CLOSED,1)
    MilitaryDrop.Wreck.update()
    assertEq(DELIVERED,0)
end
function T.enabled_option_still_delivers_the_supplies_at_the_wreck()
    SandboxVars.MilitaryDrop.CrashCrates = true
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(site.crates,true)
    assertEq(SUPPLIES_PENDING,true,"dossier gardé jusqu'aux fournitures")
    assertTrue(site.complete)
    assertEq(site.done.supplies,"done")
    assertEq(DELIVERED,1)
    MilitaryDrop.Wreck.update()
    assertEq(DELIVERED,1)
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
function T.restore_before_the_cell_exists_waits_for_load_chunk()
    -- OnInitGlobalModData précède CellLoader.LoadCellBinaryChunk : getCell() vaut nil.
    local cell = getCell
    getCell = function() return nil end
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    site.done.pilot = "placing"
    MilitaryDrop.Wreck.restore()
    assertEq(site.done.pilot,"interrupted")
    assertEq(#VEHICLES,0)
    assertTrue(not site.complete)
    getCell = cell
    MilitaryDrop.Wreck.update()
    assertEq(#VEHICLES,2)
    assertEq(BODIES,0)
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
function T.only_the_missing_pilot_is_retried()
    CREW_FAIL = true
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(#PILOTS,1)
    assertEq(site.complete,false)
    CREW_FAIL = false
    MilitaryDrop.Wreck.update()
    assertTrue(site.complete)
    assertEq(#PILOTS,2)
    MilitaryDrop.Wreck.restore()
    assertEq(#PILOTS,2)
    assertEq(BODIES,1)
end
function T.pilots_wait_for_free_ground()
    BLOCKED = true
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(#PILOTS,0)
    assertEq(site.complete,false)
    BLOCKED = false
    MilitaryDrop.Wreck.update()
    assertEq(#PILOTS,2)
    assertTrue(site.complete)
end
function T.legacy_crashes_do_not_gain_a_new_crew_on_restore()
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    site.crewVersion = nil
    site.done.pilotZombie1,site.done.pilotZombie2 = nil,nil
    site.complete = nil
    MilitaryDrop.Wreck.restore()
    assertTrue(site.complete)
    assertEq(#PILOTS,2)
end
function T.disabled_zombies_do_not_leave_a_site_pending_forever()
    ZOMBIES_DISABLED = true
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertTrue(site.complete)
    assertEq(#PILOTS,0)
    assertEq(site.done.pilotZombie1,"skipped")
end
function T.fire_and_smoke_follow_the_relocated_fuselage_on_separate_squares()
    SandboxVars.MilitaryDrop.CrashFire = 3
    LOADED = false
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    site.done.main = "done"
    site.positions.main = {x=120,y=130}
    LOADED = true
    MilitaryDrop.Wreck.update()
    assertTrue(site.complete)
    assertEq(FIRES,1)
    assertEq(SMOKES,1)
    assertEq(FIRE_POS[1].x,120)
    assertEq(FIRE_POS[1].y,132)
    assertEq(SMOKE_POS[1].x,120)
    assertEq(SMOKE_POS[1].y,128)
    assertEq(FIRE_POS[1].energy,40)
    assertEq(FIRE_POS[1].life,1800)
    TIME = TIME+10001
    MilitaryDrop.Wreck.restore()
    assertEq(FIRES,1,"ne pas rallumer un incendie éteint")
    assertEq(SMOKES,2,"fumée pour les arrivants")
end
function T.fire_waits_for_its_own_loaded_square()
    SandboxVars.MilitaryDrop.CrashFire = 3
    LOADED = false
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    site.done.main = "done"
    site.positions.main = {x=120,y=130}
    LOADED = true
    UNLOADED = function(x,y) return x==120 and y==132 end
    MilitaryDrop.Wreck.update()
    assertEq(FIRES,0)
    assertEq(site.complete,false)
    UNLOADED = nil
    MilitaryDrop.Wreck.update()
    assertEq(FIRES,1)
    assertTrue(site.complete)
end
function T.new_default_enables_fire_and_smoke_but_explicit_smoke_only_is_kept()
    SandboxVars.MilitaryDrop.CrashFire = nil
    MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(FIRES,1)
    assertEq(SMOKES,1)
end
function T.recorder_carries_the_site_point_and_time_of_the_crash()
    local site = MilitaryDrop.Wreck.add(FLIGHT)
    assertEq(site.c, 2412.5, "horloge du crash gardée avec le site")
    local recorder
    for _, added in ipairs(ADDED) do
        if added.name == "MilitaryDrop.FlightRecorder" then recorder = added end
    end
    assertTrue(recorder ~= nil, "enregistreur sur le pilote")
    local data = recorder.getModData()
    assertEq(data.MilitaryDrop_crashSite, site.id, "site")
    assertEq(data.MilitaryDrop_crashX .. "/" .. data.MilitaryDrop_crashY, site.x .. "/" .. site.y,
        "point du crash (case du pilote)")
    assertEq(data.MilitaryDrop_crashClock, 2412.5, "heure du crash")
end

return T
