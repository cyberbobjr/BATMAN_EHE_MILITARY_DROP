-- MilitaryDrop_Broadcast : chaîne militaire et annonces.

local T = {}

function T.setup()
    SandboxVars = { MilitaryDrop = { Frequency = 151.4 } }
    isClient = function() return false end
    isServer = function() return false end
    getText = function(key, a, b) return key .. "|" .. tostring(a) .. "|" .. tostring(b) end
    ChannelCategory = { Military = "Military" }
    CHANNELS = {}
    DynamicRadioChannel = { new = function(name, freq, category, uuid)
        AIRED = nil
        return {
            name = name, freq = freq, category = category, uuid = uuid,
            setAiringBroadcast = function(_, bc) AIRED = bc end,
        }
    end }
    RadioBroadCast = { new = function(id)
        return { id = id, lines = {}, AddRadioLine = function(self, line) self.lines[#self.lines + 1] = line end }
    end }
    RadioLine = { new = function(text, r, g, b, codes) return { text = text, codes = codes } end }
    FREQUENCY_TAKEN = false
    SCRIPT_MANAGER = {
        AddChannel = function(_, channel)
            if not FREQUENCY_TAKEN then
                CHANNELS[channel.uuid] = channel
            end
        end,
        getRadioChannel = function(_, uuid) return CHANNELS[uuid] end,
    }
    REMOVED_NAMES = {}
    getZomboidRadio = function()
        return { removeChannelName = function(_, freq) REMOVED_NAMES[#REMOVED_NAMES + 1] = freq end }
    end
    SENT = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Broadcast.lua")
    MilitaryDrop.Client = { onServerCommand = function(_, command, args)
        SENT[#SENT + 1] = { command = command, args = args }
    end }
end

function T.channel_on_military_frequency()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    local channel = MilitaryDrop.Broadcast.channel
    assertEq(channel.freq, 151400, "fréquence sandbox en kHz")
    assertEq(channel.category, "Military", "catégorie militaire")
    assertEq(REMOVED_NAMES[1], 151400, "nom masqué dans le panneau de la radio")
end

function T.dropped_repeats_coordinates_with_code()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    MilitaryDrop.Broadcast.dropped(115, 200)
    assertEq(SENT[1].command, "DropAnnounce", "coordonnées envoyées aux clients")
    assertEq(#AIRED.lines, MilitaryDrop.Broadcast.REPEATS + 1, "trois répétitions et fin")
    assertEq(AIRED.lines[1].text, "IGUI_MilitaryDrop_BroadcastDropped|115|200", "coordonnées dans le texte")
    assertEq(AIRED.lines[1].codes, "MDRP", "code du repère de carte")
    assertEq(AIRED.lines[#AIRED.lines].codes, nil, "fin sans code")
end

function T.inbound_has_no_coordinates_or_code()
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    MilitaryDrop.Broadcast.inbound()
    assertEq(#AIRED.lines, 1, "une ligne")
    assertEq(AIRED.lines[1].codes, nil, "pas de repère")
end

function T.taken_frequency_disables_broadcast_quietly()
    FREQUENCY_TAKEN = true
    triggerEvent("OnLoadRadioScripts", SCRIPT_MANAGER, false)
    assertEq(MilitaryDrop.Broadcast.channel, nil, "pas de chaîne")
    assertEq(MilitaryDrop.Broadcast.air({ { "x" } }), false, "rien diffusé")
    MilitaryDrop.Broadcast.dropped(1, 2)
    assertEq(SENT[1].command, "DropAnnounce", "les coordonnées partent quand même")
end

return T
