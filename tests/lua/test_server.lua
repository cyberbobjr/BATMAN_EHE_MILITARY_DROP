-- MilitaryDrop_Server : décision sur une demande de largage, délai global,
-- anti-rafale et envoi des réponses.

local T = {}

local CHANNEL = 151400
local CODE = "BRAVO-KILO-07"

--- Radio d'inventaire simulée.
local function makeRadio(on, channel, highTier)
    local data = {
        getIsHighTier = function() return highTier ~= false end,
        getIsPortable = function() return true end,
        getIsTurnedOn = function() return on end,
        getChannel = function() return channel end,
    }
    return {
        kind = "Radio",
        getID = function() return 7 end,
        getDeviceData = function() return data end,
        getContainer = function() return nil end,
    }
end

local function makePlayer(radio)
    local square = { getX = function() return 100 end, getY = function() return 200 end }
    return {
        getUsername = function() return "tester" end,
        getPrimaryHandItem = function() return radio end,
        getSecondaryHandItem = function() return nil end,
        getInventory = function() return { getItemWithID = function() return nil end } end,
        getCurrentSquare = function() return square end,
    }
end

function T.setup()
    SandboxVars = { MilitaryDrop = { CooldownHours = 168, RequireAuthCode = true, Frequency = 151.4,
        MinZombies = 0, MaxZombies = 0, CaseRolls = 2 } }
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return object ~= nil and object.kind == class end
    Capability = { MakeEventsAlarmGunshot = "MakeEventsAlarmGunshot" }
    ALLOWED = true
    checkPermissions = function() return ALLOWED end
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
    getGameTime = function() return { getWorldAgeHours = function() return WORLD_HOURS end } end
    PLACED = {}
    LANDING = {
        getX = function() return 115 end, getY = function() return 200 end,
        isOutside = function() return true end, isFree = function() return true end,
        isWaterSquare = function() return false end,
        AddWorldInventoryItem = function(_, name) PLACED[#PLACED + 1] = name return {} end,
    }
    getCell = function() return { getGridSquare = function() return LANDING end } end
    spawnHorde = function() end
    SOUNDS = {}
    addSound = function(_, x, y, z, radius, volume) SOUNDS[#SOUNDS + 1] = { x, y, radius, volume } end
    PLAYER = makePlayer(makeRadio(true, CHANNEL))
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function() return PLAYER end
    SENT = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Flight.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Server.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Flights.lua")
    MilitaryDrop.Client = { onServerCommand = function(_, command, args)
        SENT[#SENT + 1] = { command = command, args = args }
    end }
    MilitaryDrop.Server.getState().code = CODE
end

local function evaluate(radio, args)
    return MilitaryDrop.Server.evaluate(makePlayer(radio), args, WORLD_HOURS)
end

local function request(code)
    return { requestId = 1, radio = { kind = "item", id = 7 }, code = code }
end

function T.accepts_good_radio_and_code()
    assertEq(evaluate(makeRadio(true, CHANNEL), request("bravo kilo 07")), "accepted", "demande valide")
end

function T.refusal_order_hides_the_code_and_cooldown()
    assertEq(evaluate(makeRadio(false, CHANNEL), request("x")), "radioOff", "radio éteinte d'abord")
    assertEq(evaluate(makeRadio(true, 107400), request("x")), "wrongFrequency", "puis la fréquence")
    MilitaryDrop.Server.getState().lastDropHours = WORLD_HOURS
    assertEq(evaluate(makeRadio(true, CHANNEL), request("x")), "badCode", "le délai n'est révélé qu'après le code")
    local status, hours = evaluate(makeRadio(true, CHANNEL), request(CODE))
    assertEq(status, "cooldown", "délai global")
    assertEq(hours, 168, "heures restantes")
end

function T.non_military_or_unknown_radio_is_refused()
    assertEq(evaluate(makeRadio(true, CHANNEL, false), request(CODE)), "notMilitary", "radio civile")
    assertEq(evaluate(nil, request(CODE)), "noRadio", "référence introuvable")
    assertEq(evaluate(makeRadio(true, CHANNEL), "junk"), "invalid", "arguments illisibles")
end

function T.code_not_required_when_option_off()
    SandboxVars.MilitaryDrop.RequireAuthCode = false
    assertEq(evaluate(makeRadio(true, CHANNEL), request(nil)), "accepted", "sans code")
end

function T.force_needs_permission_and_skips_checks()
    local args = request(nil)
    args.force = true
    ALLOWED = false
    assertEq(evaluate(makeRadio(false, 1), args), "denied", "sans droit admin")
    ALLOWED = true
    assertEq(evaluate(makeRadio(false, 1), args), "accepted", "admin : radio éteinte et mauvais canal permis")
end

function T.cooldown_expires()
    local state = MilitaryDrop.Server.getState()
    state.lastDropHours = WORLD_HOURS - 168
    assertEq(evaluate(makeRadio(true, CHANNEL), request(CODE)), "accepted", "délai écoulé")
end

--- Fait voler tous les vols en cours jusqu'à t secondes (pas de 0,25 s).
local function fly(seconds)
    for _ = 1, math.ceil(seconds / 0.25) do
        local flights = MilitaryDrop.Server.getState().flights
        for i = #flights, 1, -1 do
            MilitaryDrop.Flights.advance(flights[i], 0.25)
        end
    end
end

local function commands()
    local list = {}
    for _, sent in ipairs(SENT) do
        list[#list + 1] = sent.command
    end
    return table.concat(list, ",")
end

function T.accepted_request_launches_a_flight_then_drops()
    MilitaryDrop.Server.handleRequest(PLAYER, request(CODE))
    assertEq(MilitaryDrop.Server.getState().lastDropHours, WORLD_HOURS, "délai démarré")
    assertEq(SENT[1].args.status, "accepted", "acceptée")
    assertEq(#MilitaryDrop.Server.getState().flights, 1, "un vol lancé")
    assertEq(#PLACED, 0, "rien avant le passage de l'hélicoptère")
    local flight = MilitaryDrop.Server.getState().flights[1]
    fly(MilitaryDrop.Flight.dropTime(flight) + 0.5)
    assertEq(#PLACED, 2, "CaseRolls caisses posées au largage")
    local sequence = commands()
    assertTrue(sequence:find("^Result,FlightStart,FlightSync") ~= nil, "réponse, départ, synchronisation : " .. sequence)
    assertTrue(sequence:find(",Dropped$") ~= nil, "confirmation en dernier : " .. sequence)
    assertEq(SENT[#SENT].args.x, 115, "coordonnées")
end

function T.forced_drop_does_not_touch_cooldown()
    local args = request(nil)
    args.force = true
    MilitaryDrop.Server.handleRequest(PLAYER, args)
    assertEq(MilitaryDrop.Server.getState().lastDropHours, nil, "délai inchangé")
    assertEq(#MilitaryDrop.Server.getState().flights, 1, "vol lancé quand même")
end

function T.request_burst_is_ignored()
    local player = makePlayer(makeRadio(true, 107400))
    MilitaryDrop.Server.handleRequest(player, request(CODE))
    NOW_MS = 1000
    MilitaryDrop.Server.handleRequest(player, request(CODE))
    assertEq(#SENT, 1, "seconde demande ignorée")
    NOW_MS = 4000
    MilitaryDrop.Server.handleRequest(player, request(CODE))
    assertEq(#SENT, 2, "acceptée après 3 s")
end

function T.code_is_generated_once()
    MODDATA = {}
    local first = MilitaryDrop.Server.getState().code
    assertEq(type(first), "string", "code tiré")
    assertEq(MilitaryDrop.Server.getState().code, first, "code conservé")
end

return T
