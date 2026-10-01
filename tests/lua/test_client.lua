-- MilitaryDrop_Client : réponse de la base affichée par la radio.

local T = {}

--- Appareil simulé : kind = "Radio" (inventaire) ou "IsoWaveSignal" (posé).
local function makeDevice(kind)
    local data = {
        getIsTurnedOn = function() return true end,
        getDeviceVolume = function() return 0.5 end,
    }
    return {
        kind = kind,
        getDeviceData = function() return data end,
        AddDeviceText = function(self, text, r, g, b)
            self.said = { text = text, r = r, g = g, b = b }
        end,
    }
end

function T.setup()
    SandboxVars = {}
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return object ~= nil and object.kind == class end
    getSpecificPlayer = function() return { Say = function() end } end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_Client.lua")
end

function T.handheld_radio_gets_colors_from_0_to_1()
    local device = makeDevice("Radio")
    MilitaryDrop.Client.radioSay({ playerNum = 0, device = device }, "ok")
    assertEq(device.said.r, 0.45, "rouge 0-1")
    assertEq(device.said.g, 0.85, "vert 0-1")
end

function T.placed_radio_gets_integer_colors_from_0_to_255()
    local device = makeDevice("IsoWaveSignal")
    MilitaryDrop.Client.radioSay({ playerNum = 0, device = device }, "ok")
    assertEq(device.said.r, 115, "rouge 0-255 (0,45)")
    assertEq(device.said.g, 217, "vert 0-255 (0,85)")
    assertEq(device.said.b, 115, "bleu 0-255")
end

function T.acknowledgement_depends_on_the_trust_tier()
    getText = function(key, a) return key .. "|" .. tostring(a) end
    ZombRand = function() return 0 end
    local Client = MilitaryDrop.Client
    assertEq(Client.ackText({ tier = 1, callsign = "Station Kilo-7" }), "IGUI_MilitaryDrop_AckTier1_1|Station Kilo-7",
        "palier bas")
    assertEq(Client.ackText({ tier = 4, callsign = "Station Kilo-7" }), "IGUI_MilitaryDrop_AckTier4_1|Station Kilo-7",
        "palier haut")
    assertEq(Client.ackText({}), "IGUI_MilitaryDrop_Ack_1|nil", "sans palier : réplique neutre")
    assertEq(Client.ackText({ tier = 9, callsign = "Station Kilo-7" }), "IGUI_MilitaryDrop_Ack_1|nil",
        "palier inconnu : réplique neutre")
end

function T.recon_announce_reaches_the_map_module()
    local received = nil
    MilitaryDrop.Announce = { onReconAnnounce = function(args) received = args end }
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "ReconAnnounce", { id = "M2", x = 1, y = 2 })
    assertEq(received and received.id, "M2", "grille transmise au repère de carte")
end

return T
