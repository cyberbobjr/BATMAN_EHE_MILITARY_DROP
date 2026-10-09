-- Registre et émissions vanilla simulés, avec écoute obligatoire et segments.
-- Aucune exécution Java ni capture audio : les limites privées sont documentées.
local T = {}

local function eq(a, b)
    assert(a == b, "attendu " .. tostring(b) .. ", obtenu " .. tostring(a))
end

local function list(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end,
        getItemByIndex = function(_, i) return items[i + 1] end }
end

local function line(text, codes)
    return { getText = function() return text end, getEffectsString = function() return codes or "" end,
        getR = function() return 0.7 end, getG = function() return 0.8 end, getB = function() return 0.9 end }
end

local function broadcast(lines)
    local bc = { count = 0 }
    bc.getCurrentLineNumber = function() return bc.count end
    bc.getLines = function() return list(lines) end
    return bc
end

local function channel(frequency, tv)
    local c = { frequency = frequency, last = "", pending = broadcast({ line("Bulletin", "MAPTEST") }) }
    c.GetFrequency = function() return c.frequency end
    c.IsTv = function() return tv or false end
    c.getAiringBroadcast = function() return c.airing end
    c.getLastAiredLine = function() return c.last end
    return c
end

local function radio(frequency)
    local data = { on = true, frequency = frequency }
    data.getIsPortable = function() return true end
    data.getIsTurnedOn = function() return data.on end
    data.getIsTelevision = function() return false end
    data.getChannel = function() return data.frequency end
    data.getDeviceVolume = function() return 0.5 end
    data.isPlayingMedia = function() return false end
    data.isNoTransmit = function() return false end
    data.getIsBatteryPowered = function() return true end
    data.getHasBattery = function() return true end
    data.getPower = function() return 1 end
    local item = { kind = "Radio", said = {}, shown = {}, data = data }
    item.getDeviceData = function() return data end
    item.getContainer = function() return INVENTORY end
    -- Doublure fidèle des deux surcharges Java. 8 arguments (WaveSignalDevice.java:41-62) :
    -- bulle seulement si player:isEquipped(radio), jamais à la ceinture ; le reste au chat
    -- radio, absent en solo. 7 arguments, texte en premier (Radio.java:77-89) : SayRadio,
    -- bulle au-dessus du propriétaire. Puis OnDeviceText (said) si codes ~= nil.
    item.AddDeviceText = function(self, first, ...)
        local text, r, g, b, guid, codes, distance, shown
        if type(first) == "string" then
            text, r, g, b, guid, codes, distance = first, ...
            shown = true -- getPlayer() : PLAYER, parent du conteneur INVENTORY
        else
            text, r, g, b, guid, codes, distance = ...
            shown = first:isEquipped(self)
        end
        eq(guid, nil)
        eq(distance, -1)
        if shown then self.shown[#self.shown + 1] = text end
        if codes ~= nil then
            self.said[#self.said + 1] = { text = text, r = r, g = g, b = b, codes = codes }
        end
    end
    return item
end

function T.setup()
    Events = setmetatable({}, { __index = function(events, name)
        local e = { handlers = {} }
        e.Add = function(fn) e.handlers[#e.handlers + 1] = fn end
        e.Remove = function(fn)
            for i = #e.handlers, 1, -1 do
                if e.handlers[i] == fn then table.remove(e.handlers, i) end
            end
        end
        rawset(events, name, e)
        return e
    end })
    CLIENT, SERVER, ACTIVE, DISABLED = false, false, {}, false
    isClient = function() return CLIENT end
    isServer = function() return SERVER end
    getActivatedMods = function() return list(ACTIVE) end
    instanceof = function(item, class) return item.kind == class end
    getClimateManager = function() return { getWeatherInterference = function() return 0 end } end
    INVENTORY, CHANNELS, REQUESTS = {}, {}, {}
    PLAYER = { attached = {} }
    PLAYER.getInventory = function() return INVENTORY end
    PLAYER.getAttachedItems = function() return list(PLAYER.attached) end
    PLAYER.getEquipedRadio = function() return PLAYER.equipped end
    PLAYER.getPrimaryHandItem = function() return PLAYER.equipped end
    PLAYER.isEquipped = function(_, item) return item == PLAYER.equipped end
    PLAYER.getSecondaryHandItem = function() end
    PLAYER.getClothingItem_Back = function() end
    PLAYER.isDead = function() return false end
    PLAYER.isAttachedItem = function(_, item)
        for _, attached in ipairs(PLAYER.attached) do if attached == item then return true end end
        return false
    end
    getSpecificPlayer = function() return PLAYER end
    getNumActivePlayers = function() return 1 end
    local manager = { getChannelsList = function() return list(CHANNELS) end }
    ZRADIO = { getScriptManager = function() return manager end,
        getDisableBroadcasting = function() return DISABLED end }
    ZRADIO.PlayerListensChannel = function(_, frequency, mode, tv)
        REQUESTS[#REQUESTS + 1] = { frequency = frequency, mode = mode, tv = tv }
        for _, c in ipairs(CHANNELS) do
            if c.frequency == frequency and c:IsTv() == tv and mode and not c.airing then
                c.airing = c.pending -- modèle de SetPlayerIsListening / getValidAirBroadcast
            end
        end
    end
    getZomboidRadio = function() return ZRADIO end
    RadioLine = { new = function(text, r, g, b)
        local l = line(text)
        l.getR, l.getG, l.getB = function() return r end, function() return g end, function() return b end
        return l
    end }
    ISRadioWindow = { update = function() end }
    local modules = {}
    require = function(name)
        if name == "BatmanRadio/BatmanRadio_BeltBattery" then return end -- testé séparément
        if name == "BatmanRadio/BatmanRadio_Compat" then
            modules[name] = modules[name] or loadMod("shared/" .. name .. ".lua")
            return modules[name]
        end
    end
    SUPPORT = loadMod("client/BatmanRadio/BatmanRadio_Core.lua")
    SUPPORT.onGameStart()
end

function T.vanilla_schedule_is_started_by_belt_listening_without_scenario_provider()
    local c, item = channel(89400), radio(89400)
    CHANNELS, PLAYER.attached = { c }, { item }
    SUPPORT.onTick()
    eq(c.airing, c.pending)
    eq(#item.said, 0)
    c.airing.count, c.last = 1, "Bulletin"
    SUPPORT.onTick()
    SUPPORT.onTick()
    eq(#item.said, 1)
    eq(item.said[1].codes, "MAPTEST")
    eq(item.said[1].r, 0.7)
    eq(#item.shown, 1) -- affichée à l'écran, pas seulement OnDeviceText
end

function T.random_aebs_frequency_and_late_channel_registration_are_discovered()
    local item = radio(104600)
    PLAYER.attached = { item }
    SUPPORT.onTick()
    local c = channel(104600)
    CHANNELS = { c }
    SUPPORT.onTick()
    c.airing.count, c.last = 1, "Bulletin"
    SUPPORT.onTick()
    eq(#item.said, 1)
end

function T.mod_station_added_during_play_needs_no_provider_or_frequency_whitelist()
    local item = radio(145800)
    PLAYER.attached = { item }
    SUPPORT.onTick()
    local modStation = channel(145800)
    modStation.pending = broadcast({ line("Station ajoutée par un mod", "MODCODE") })
    CHANNELS[#CHANNELS + 1] = modStation
    SUPPORT.onTick()
    modStation.airing.count, modStation.last = 1, "Station ajoutée par un mod"
    SUPPORT.onTick()
    eq(#item.said, 1)
    eq(item.said[1].text, "Station ajoutée par un mod")
    eq(item.said[1].codes, "MODCODE")
end

function T.radio_in_hand_is_never_notified_written_to_or_weather_scrambled_by_our_receiver()
    local c, hand = channel(89400), radio(89400)
    -- État transitoire : encore référencée dans les attaches, déjà en main.
    CHANNELS, PLAYER.attached, PLAYER.equipped = { c }, { hand }, hand
    c.airing = c.pending -- le vanilla démarre et transmet lui-même
    c.airing.count, c.last = 1, "Bulletin"
    getClimateManager = function() return { getWeatherInterference = function() return 0.5 end } end
    ZRADIO.scrambleString = function() error("modification inutile du hasard / moteur radio") end
    SUPPORT.onTick()
    eq(#REQUESTS, 0)
    eq(#hand.said, 0)
    eq(hand.data.on, true)
    eq(hand.data.frequency, 89400)
end

function T.hand_and_belt_on_same_frequency_keep_native_reception_without_extra_scrambling()
    local c, hand, belt = channel(89400), radio(89400), radio(89400)
    CHANNELS, PLAYER.attached, PLAYER.equipped = { c }, { belt }, hand
    c.airing = c.pending -- démarrage géré par la radio en main
    SUPPORT.onTick()
    c.airing.count, c.last = 1, "Bulletin"
    getClimateManager = function() return { getWeatherInterference = function() return 0.5 end } end
    ZRADIO.scrambleString = function() error("la radio en main reçoit déjà") end
    SUPPORT.onTick()
    eq(#REQUESTS, 0)
    eq(#hand.said, 0)
    eq(#belt.said, 0)
end

function T.vanilla_registry_and_scenario_provider_are_deduplicated_and_tv_is_excluded()
    local c, tv = channel(108000), channel(203, true)
    CHANNELS = { c, tv }
    SUPPORT.register("scenario", { channels = function() return { c, tv } end })
    eq(#SUPPORT.channels(), 1)
    PLAYER.attached = { radio(203) }
    tv.airing = tv.pending
    tv.airing.count, tv.last = 1, "Télévision"
    SUPPORT.onTick()
    eq(#PLAYER.attached[1].said, 0)
end

function T.retuning_does_not_replay_lines_aired_on_another_frequency()
    local a, b, item = channel(89400), channel(104600), radio(89400)
    CHANNELS, PLAYER.attached = { a, b }, { item }
    b.airing = b.pending
    b.airing.count, b.last = 1, "Bulletin"
    SUPPORT.onTick()
    eq(#item.said, 0)
    item.data.frequency = 104600
    SUPPORT.onTick()
    eq(#item.said, 0)
    b.airing = broadcast({ line("Nouveau bulletin") })
    b.airing.count, b.last = 1, "Nouveau bulletin"
    SUPPORT.onTick()
    eq(item.said[1].text, "Nouveau bulletin")
end

function T.pre_and_post_segments_and_pauses_are_received_without_main_counter_changes()
    local c, item = channel(89400), radio(89400)
    CHANNELS, PLAYER.attached = { c }, { item }
    SUPPORT.onTick()
    c.last = "Publicité avant"
    SUPPORT.onTick()
    SUPPORT.onTick()
    c.last = "~"
    SUPPORT.onTick()
    c.airing.count, c.last = 1, "Bulletin"
    SUPPORT.onTick()
    c.last = "~"
    SUPPORT.onTick()
    c.last = "Publicité après"
    SUPPORT.onTick()
    eq(#item.said, 5)
    eq(item.said[1].text, "Publicité avant")
    eq(item.said[1].r, 0.5) -- métadonnées privées : limite du secours Lua
    eq(item.said[1].codes, "")
    eq(item.said[3].codes, "MAPTEST")
    eq(item.said[5].text, "Publicité après")
end

function T.identical_main_lines_are_distinct_transmissions()
    local c, item = channel(89400), radio(89400)
    c.pending = broadcast({ line("Répétition"), line("Répétition") })
    CHANNELS, PLAYER.attached = { c }, { item }
    SUPPORT.onTick()
    c.airing.count, c.last = 1, "Répétition"
    SUPPORT.onTick()
    c.airing.count = 2
    SUPPORT.onTick()
    eq(#item.said, 2)
end

function T.loaded_broadcast_does_not_replay_saved_history()
    local c, item = channel(89400), radio(89400)
    c.airing = broadcast({ line("Ancien 1"), line("Ancien 2"), line("Suite") })
    c.airing.count = 2
    CHANNELS, PLAYER.attached = { c }, { item }
    SUPPORT.onTick()
    eq(#item.said, 0)
    c.airing.count, c.last = 3, "Suite"
    SUPPORT.onTick()
    eq(#item.said, 1)
    eq(item.said[1].text, "Suite")
end

function T.first_observation_only_delivers_the_latest_aired_line()
    local c, item = channel(89400), radio(89400)
    c.airing = broadcast({ line("Ancien"), line("Actuel") })
    c.airing.count, c.last = 2, "Actuel"
    CHANNELS, PLAYER.attached = { c }, { item }
    SUPPORT.onTick()
    eq(#item.said, 1)
    eq(item.said[1].text, "Actuel")
end

function T.disabled_broadcasting_is_respected_without_replay_when_reenabled()
    local c, item = channel(89400), radio(89400)
    CHANNELS, PLAYER.attached = { c }, { item }
    SUPPORT.onTick()
    DISABLED = true
    c.airing.count, c.last = 1, "Bulletin"
    SUPPORT.onTick()
    DISABLED = false
    SUPPORT.onTick()
    eq(#item.said, 0)
end

function T.listening_requests_are_unique_and_never_turn_off_other_receivers()
    CHANNELS = { channel(89400) }
    local a, b = radio(89400), radio(89400)
    PLAYER.attached = { a, b }
    SUPPORT.onTick()
    eq(#REQUESTS, 1)
    eq(REQUESTS[1].mode, true)
    eq(REQUESTS[1].tv, false)
    a.data.on, b.data.on = false, false
    SUPPORT.onTick()
    PLAYER.attached = {}
    SUPPORT.onTick()
    eq(#REQUESTS, 1)
end

function T.bwt_active_keeps_vanilla_solo_reception_but_mp_adds_no_delivery()
    ACTIVE = { "\\BetterWalkieTalkies" }
    local c, item = channel(89400), radio(89400)
    CHANNELS, PLAYER.attached = { c }, { item }
    SUPPORT.onTick()
    c.airing.count, c.last = 1, "Bulletin"
    SUPPORT.onTick()
    eq(#item.said, 1)
    CLIENT = true
    SUPPORT.onTick()
    eq(SUPPORT.listening, false)
    eq(#item.said, 1)
end

return T
