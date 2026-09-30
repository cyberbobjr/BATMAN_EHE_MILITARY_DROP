-- MilitaryDrop_Announce : repère de carte seulement pour qui entend la ligne.

local T = {}

function T.setup()
    SandboxVars = {}
    SYMBOLS = {}
    local api = {
        getSymbolCount = function() return #SYMBOLS end,
        getSymbolByIndex = function(_, i) return SYMBOLS[i + 1] end,
        addTexture = function(_, id, x, y)
            local symbol = {
                isTexture = function() return true end,
                getSymbolID = function() return id end,
                getWorldX = function() return x end,
                getWorldY = function() return y end,
                setRGBA = function() end,
                setAnchor = function() end,
            }
            SYMBOLS[#SYMBOLS + 1] = symbol
            return symbol
        end,
    }
    UIWorldMap = { new = function()
        return { getAPIv3 = function()
            return { setMapItem = function() end, getSymbolsAPIv2 = function() return api end }
        end }
    end }
    MapItem = { getSingleton = function() return {} end }
    PLAYER = { getX = function() return 100 end, getY = function() return 100 end, getZ = function() return 0 end }
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function() return PLAYER end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_Announce.lua")
end

function T.handheld_radio_marks_once()
    MilitaryDrop.Announce.onDropAnnounce({ x = 500, y = 600 })
    triggerEvent("OnDeviceText", "guid", "MDRP", -1, -1, -1, "line", {})
    triggerEvent("OnDeviceText", "guid", "MDRP", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 1, "un seul symbole malgré trois répétitions")
    assertEq(SYMBOLS[1].getWorldX(), 500, "position")
end

function T.other_codes_are_ignored()
    MilitaryDrop.Announce.onDropAnnounce({ x = 500, y = 600 })
    triggerEvent("OnDeviceText", "guid", "BOR-1", -1, -1, -1, "line", {})
    triggerEvent("OnDeviceText", "guid", nil, -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 0, "pas de repère")
end

function T.far_placed_radio_is_ignored()
    MilitaryDrop.Announce.onDropAnnounce({ x = 500, y = 600 })
    triggerEvent("OnDeviceText", "guid", "MDRP", 300, 300, 0, "line", {})
    assertEq(#SYMBOLS, 0, "radio posée trop loin")
    triggerEvent("OnDeviceText", "guid", "MDRP", 103, 98, 0, "line", {})
    assertEq(#SYMBOLS, 1, "radio posée à portée")
end

function T.no_announce_no_mark()
    triggerEvent("OnDeviceText", "guid", "MDRP", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 0, "rien à marquer")
end

function T.existing_symbol_is_not_duplicated()
    MilitaryDrop.Announce.markMap(500, 600)
    assertEq(MilitaryDrop.Announce.markMap(500, 600), false, "doublon refusé")
    assertEq(#SYMBOLS, 1, "un symbole")
end

return T
