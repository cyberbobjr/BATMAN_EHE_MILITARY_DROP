-- Appel de la vraie API de mise à jour, avec modèle du compteur Java 42.21.
-- Les paquets / Java restent simulés : ce fichier ne remplace pas un test en jeu.
local T = {}
local MODULE = "client/BatmanRadio/BatmanRadio_BeltBattery.lua"

local function eq(a, b)
    assert(a == b, "attendu " .. tostring(b) .. ", obtenu " .. tostring(a))
end

local function close(a, b)
    assert(math.abs(a - b) < 0.00001, "attendu " .. tostring(b) .. ", obtenu " .. tostring(a))
end

local function list(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end,
        getItemByIndex = function(_, i) return items[i + 1] end }
end

local function player()
    local p = { attached = {}, inventory = {} }
    p.getInventory = function() return p.inventory end
    p.getEquipedRadio = function() return p.equipped end
    p.getPrimaryHandItem = function() return p.primary end
    p.getSecondaryHandItem = function() return p.secondary end
    p.getClothingItem_Back = function() return p.back end
    p.isDead = function() return p.dead or false end
    p.isAttachedItem = function(_, item)
        for _, v in ipairs(p.attached) do if v == item then return true end end
        return false
    end
    p.getAttachedItems = function() return list(p.attached) end
    return p
end

local function radio(p, opts)
    opts = opts or {}
    local data = { power = opts.power or 1, on = opts.on ~= false,
        lastMinuteStamp = -1, calls = 0, packets = 0, useDelta = 0.01 }
    data.getIsPortable = function() return opts.portable ~= false end
    data.getIsBatteryPowered = function() return opts.batteryPowered ~= false end
    data.getHasBattery = function() return opts.hasBattery ~= false end
    data.getIsTurnedOn = function() return data.on end
    data.getDeviceVolume = function() return opts.volume or 0.5 end
    data.getChannel = function() return opts.channel or 108000 end
    data.setIsTurnedOn = function(_, on)
        data.on = on
        if not on then data.lastMinuteStamp = -1 end
    end
    data.update = function(_, isIso, inRange)
        -- DeviceData.java:763-795, réduit à la pile et au compteur temporel.
        eq(isIso, false)
        eq(inRange, true)
        data.calls = data.calls + 1
        if data.lastMinuteStamp == -1 then data.lastMinuteStamp = MINUTE end
        if MINUTE > data.lastMinuteStamp then
            local diff = MINUTE - data.lastMinuteStamp
            data.lastMinuteStamp = MINUTE
            if data.on and data.power > 0 then
                data.power = math.max(0, data.power - data.useDelta * diff)
                if CLIENT then data.packets = data.packets + 1 end
            end
        end
        if data.on and data.power <= 0 then
            data.on = false
            if CLIENT then data.packets = data.packets + 1 end
        end
    end
    local item = { kind = opts.kind or "Radio", data = data }
    item.getDeviceData = function() return data end
    item.getContainer = function() return opts.container or p.inventory end
    return item
end

function T.setup()
    -- Fonctionne aussi dans le lanceur Artemis, sans le prélude MilitaryDrop.
    Events = {}
    for _, name in ipairs({ "OnTick", "OnDisconnect", "OnMainMenuEnter" }) do
        local event = { handlers = {} }
        event.Add = function(fn) event.handlers[#event.handlers + 1] = fn end
        event.Remove = function(fn)
            for i = #event.handlers, 1, -1 do
                if event.handlers[i] == fn then table.remove(event.handlers, i) end
            end
        end
        Events[name] = event
    end
    MINUTE, CLIENT, SERVER = 100, false, false
    isServer = function() return SERVER end
    isClient = function() return CLIENT end
    getGameTime = function() return { getMinutesStamp = function() return MINUTE end } end
    instanceof = function(item, class) return item.kind == class end
    SandboxVars, ACTIVE = {}, {}
    getActivatedMods = function() return list(ACTIVE) end
    PLAYERS = { player() }
    getNumActivePlayers = function() return #PLAYERS end
    getSpecificPlayer = function(i) return PLAYERS[i + 1] end
    local loaded = {}
    require = function(name)
        if name == "BatmanRadio/BatmanRadio_Compat" then
            loaded[name] = loaded[name] or loadMod("shared/" .. name .. ".lua")
            return loaded[name]
        end
    end
end

local function tick(minutes)
    MINUTE = MINUTE + (minutes or 0)
    for _, fn in ipairs(Events.OnTick.handlers) do fn() end
end

local function start(opts)
    local item = radio(PLAYERS[1], opts)
    PLAYERS[1].attached = { item }
    loadMod(MODULE)
    tick()
    return item.data, item
end

function T.drains_each_minute_even_at_zero_volume_or_other_channel()
    local data = start({ volume = 0, channel = 151400 })
    eq(data.calls, 1)
    tick()
    tick()
    eq(data.calls, 1)
    tick(1)
    close(data.power, 0.99)
    tick(1)
    close(data.power, 0.98)
end

function T.elapsed_minutes_are_counted_in_fast_forward()
    local data = start()
    tick(30)
    close(data.power, 0.7)
    eq(data.lastMinuteStamp, 130)
end

function T.switching_back_to_hand_does_not_drain_the_same_period_again()
    local data, item = start()
    tick(10)
    close(data.power, 0.9)
    PLAYERS[1].attached, PLAYERS[1].equipped = {}, item
    tick()
    data:update(false, true) -- reprise par Radio.update vanilla, même minute
    close(data.power, 0.9)
    MINUTE = MINUTE + 1
    data:update(false, true)
    close(data.power, 0.89)
    PLAYERS[1].equipped, PLAYERS[1].attached = nil, { item }
    tick()
    close(data.power, 0.89)
    tick(1)
    close(data.power, 0.88)
end

function T.already_used_in_hand_preserves_the_native_timestamp()
    local item = radio(PLAYERS[1])
    item.data:update(false, true)
    PLAYERS[1].attached = { item }
    loadMod(MODULE)
    tick(5)
    close(item.data.power, 0.95)
end

function T.turning_off_and_on_does_not_charge_for_the_off_period()
    local data = start()
    tick(1)
    data:setIsTurnedOn(false)
    tick()
    tick(30)
    close(data.power, 0.99)
    local calls = data.calls
    data:setIsTurnedOn(true)
    tick()
    eq(data.calls, calls + 1)
    close(data.power, 0.99)
    tick(1)
    close(data.power, 0.98)
end

function T.empty_battery_turns_off_and_client_uses_vanilla_update()
    CLIENT = true
    local data = start({ power = 0.02 })
    tick(3)
    eq(data.power, 0)
    eq(data.on, false)
    eq(data.packets, 2)
end

function T.second_mod_copy_and_lua_reload_keep_one_handler()
    local data = start()
    loadMod(MODULE) -- seconde copie identique, ou require puis autoload
    eq(#Events.OnTick.handlers, 1)
    eq(#Events.OnDisconnect.handlers, 1)
    eq(#Events.OnMainMenuEnter.handlers, 1)
    tick()
    eq(data.calls, 1)
    tick(1)
    close(data.power, 0.99)
    eq(data.calls, 2)
end

function T.every_local_player_and_device_is_updated_once()
    PLAYERS[2] = player()
    local first, second = radio(PLAYERS[1]), radio(PLAYERS[2])
    PLAYERS[1].attached, PLAYERS[2].attached = { first, first }, { second }
    loadMod(MODULE)
    tick()
    tick(1)
    close(first.data.power, 0.99)
    close(second.data.power, 0.99)
    eq(first.data.calls, 2)
end

function T.unattached_nonportable_bag_no_battery_and_dead_player_are_excluded()
    loadMod(MODULE)
    local p = PLAYERS[1]
    local unattached = radio(p)
    local a = radio(p, { portable = false })
    local b = radio(p, { batteryPowered = false })
    local c = radio(p, { hasBattery = false })
    local d = radio(p, { container = {} })
    local e = radio(p, { kind = "Weapon" })
    p.attached = { a, b, c, d, e }
    tick(10)
    for _, item in ipairs({ unattached, a, b, c, d, e }) do eq(item.data.calls, 0) end
    p.dead, p.attached = true, { unattached }
    tick(10)
    eq(unattached.data.calls, 0)
end

function T.hand_and_back_are_left_to_vanilla_even_during_attachment_transition()
    local data, item = start()
    for _, field in ipairs({ "equipped", "primary", "secondary", "back" }) do
        PLAYERS[1][field] = item
        tick(1)
        eq(data.calls, 1)
        PLAYERS[1][field] = nil
    end
end

function T.dedicated_server_does_not_update_client_radios()
    SERVER = true
    local data = start()
    tick(10)
    eq(data.calls, 0)
end

function T.bwt_owns_battery_and_its_disabled_option_is_respected()
    local data = start()
    SandboxVars.BetterWalkieTalkies = { BatteryDrain = true }
    tick(1) -- option conservée dans une sauvegarde, mod absent
    close(data.power, 0.99)
    ACTIVE = { "\\BetterWalkieTalkies" }
    local calls = data.calls
    tick(1)
    eq(data.calls, calls)
    SandboxVars.BetterWalkieTalkies.BatteryDrain = false
    tick()
    eq(data.calls, calls) -- BWT actif : son choix « pas de drain » reste respecté
end

function T.disconnect_and_menu_release_device_references()
    start()
    Events.OnDisconnect.handlers[1]()
    for _ in pairs(BatmanBeltRadioBattery.tracked) do error("registre non vidé") end
    tick()
    Events.OnMainMenuEnter.handlers[1]()
    for _ in pairs(BatmanBeltRadioBattery.tracked) do error("registre non vidé") end
end

return T
