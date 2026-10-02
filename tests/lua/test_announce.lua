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
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
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

function T.grid_reminder_marks_every_grid_heard()
    MilitaryDrop.Announce.onDropAnnounce({ grids = { { x = 500, y = 600 }, { x = 700, y = 800 } } })
    triggerEvent("OnDeviceText", "guid", "MDRP", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 2, "les deux grilles du rappel")
    MilitaryDrop.Announce.onDropAnnounce({ grids = { { x = 500, y = 600 } } })
    triggerEvent("OnDeviceText", "guid", "MDRP", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 2, "grille déjà marquée : pas de doublon")
end

function T.unheard_announcement_is_forgotten_at_the_next_one()
    MilitaryDrop.Announce.onDropAnnounce({ x = 500, y = 600 })
    NOW_MS = MilitaryDrop.Announce.PENDING_MS + 1
    MilitaryDrop.Announce.onDropAnnounce({ x = 700, y = 800 })
    triggerEvent("OnDeviceText", "guid", "MDRP", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 1, "seule la grille entendue")
    assertEq(SYMBOLS[1].getWorldX(), 700, "la dernière annonce")
end

function T.announcement_and_reminder_aired_together_are_both_marked()
    MilitaryDrop.Announce.onDropAnnounce({ x = 500, y = 600 })
    NOW_MS = 1000
    MilitaryDrop.Announce.onDropAnnounce({ grids = { { x = 700, y = 800 } } })
    triggerEvent("OnDeviceText", "guid", "MDRP", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 2, "les deux grilles en cours de diffusion")
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

function T.recon_marked_once_per_mission_with_its_own_symbol()
    MilitaryDrop.Announce.onReconAnnounce({ id = "M3", x = 700, y = 800 })
    triggerEvent("OnDeviceText", "guid", "MDRC", -1, -1, -1, "line", {})
    triggerEvent("OnDeviceText", "guid", "MDRC", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 1, "un seul symbole malgré la répétition")
    assertEq(SYMBOLS[1].getSymbolID(), "Eye", "symbole de la reconnaissance")
    assertEq(SYMBOLS[1].getWorldX(), 700, "position")
    -- Même mission annoncée de nouveau : pas de second repère, même effacé.
    SYMBOLS[1] = nil
    MilitaryDrop.Announce.onReconAnnounce({ id = "M3", x = 700, y = 800 })
    triggerEvent("OnDeviceText", "guid", "MDRC", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 0, "une fois par mission")
    MilitaryDrop.Announce.onReconAnnounce({ id = "M4", x = 900, y = 950 })
    triggerEvent("OnDeviceText", "guid", "MDRC", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 1, "mission suivante marquée")
end

function T.recon_and_drop_codes_are_distinct()
    MilitaryDrop.Announce.onDropAnnounce({ x = 500, y = 600 })
    MilitaryDrop.Announce.onReconAnnounce({ id = "M1", x = 700, y = 800 })
    triggerEvent("OnDeviceText", "guid", "MDRC", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 1, "seule la reconnaissance")
    assertEq(SYMBOLS[1].getSymbolID(), "Eye", "symbole de la reconnaissance")
    triggerEvent("OnDeviceText", "guid", "MDRP", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 2, "puis le largage")
    assertEq(SYMBOLS[2].getSymbolID(), "Target", "symbole du largage")
end

function T.recon_needs_a_radio_that_hears_it()
    MilitaryDrop.Announce.onReconAnnounce({ id = "M1", x = 700, y = 800 })
    triggerEvent("OnDeviceText", "guid", "MDRC", 300, 300, 0, "line", {})
    triggerEvent("OnDeviceText", "guid", "", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 0, "radio posée trop loin, ou ligne sans code")
    MilitaryDrop.Announce.onReconAnnounce({ id = 5, x = 700, y = 800 })
    assertTrue(true, "identifiant invalide ignoré sans erreur")
end

function T.cleanup_zone_marked_once_with_its_own_symbol_and_color()
    local colors = {}
    local api = UIWorldMap.new():getAPIv3():getSymbolsAPIv2()
    local addTexture = api.addTexture
    api.addTexture = function(self, id, x, y)
        local symbol = addTexture(self, id, x, y)
        symbol.setRGBA = function(_, r, g, b) colors[#colors + 1] = { r, g, b } end
        return symbol
    end
    MilitaryDrop.Announce.onReconAnnounce({ id = "M1", x = 700, y = 800 })
    MilitaryDrop.Announce.onCleanupAnnounce({ id = "M2", x = 1200, y = 1300, radius = 40 })
    triggerEvent("OnDeviceText", "guid", "MDCU", -1, -1, -1, "line", {})
    triggerEvent("OnDeviceText", "guid", "MDCU", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 1, "seul le nettoyage, une fois")
    assertEq(SYMBOLS[1].getSymbolID(), "Skull", "symbole du nettoyage")
    assertEq(SYMBOLS[1].getWorldX() .. "," .. SYMBOLS[1].getWorldY(), "1200,1300", "centre de la zone")
    local A = MilitaryDrop.Announce
    assertTrue(A.CLEANUP_SYMBOL ~= A.RECON_SYMBOL and A.CLEANUP_SYMBOL ~= A.SYMBOL, "symbole distinct")
    assertTrue(A.CLEANUP_CODE ~= A.RECON_CODE and A.CLEANUP_CODE ~= A.CODE, "code distinct")
    assertTrue(A.CLEANUP_COLOR.r ~= A.RECON_COLOR.r and A.CLEANUP_COLOR.r ~= A.COLOR.r, "couleur distincte")
    assertEq(colors[1][1], A.CLEANUP_COLOR.r, "couleur appliquée")
    triggerEvent("OnDeviceText", "guid", "MDRC", -1, -1, -1, "line", {})
    assertEq(SYMBOLS[2].getSymbolID(), "Eye", "puis la reconnaissance, indépendante")
    -- Même mission annoncée de nouveau (reconnexion) : pas de second repère.
    MilitaryDrop.Announce.onCleanupAnnounce({ id = "M2", x = 1200, y = 1300, radius = 40 })
    SYMBOLS = {}
    triggerEvent("OnDeviceText", "guid", "MDCU", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 0, "une fois par mission")
end

function T.cleanup_needs_a_radio_that_hears_it()
    MilitaryDrop.Announce.onCleanupAnnounce({ id = "M5", x = 1200, y = 1300, radius = 40 })
    triggerEvent("OnDeviceText", "guid", "MDCU", 300, 300, 0, "line", {})
    triggerEvent("OnDeviceText", "guid", "MDRC", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 0, "radio posée trop loin, ou ligne d'une autre mission")
    triggerEvent("OnDeviceText", "guid", "MDCU", 102, 99, 0, "line", {})
    assertEq(#SYMBOLS, 1, "radio posée à portée")
end

function T.existing_symbol_is_not_duplicated()
    MilitaryDrop.Announce.markMap(500, 600)
    assertEq(MilitaryDrop.Announce.markMap(500, 600), false, "doublon refusé")
    assertEq(#SYMBOLS, 1, "un symbole")
end

function T.mayday_marks_an_approximate_sector_only_when_heard()
    MilitaryDrop.Announce.onMaydayAnnounce({ id="7", x=525, y=625 })
    assertEq(#SYMBOLS,0)
    triggerEvent("OnDeviceText", "guid", "MDAY", -1, -1, -1, "MAYDAY", {})
    assertEq(#SYMBOLS,1)
    assertEq(SYMBOLS[1].getSymbolID(),"Question")
    assertEq(SYMBOLS[1].getWorldX(),525)
    triggerEvent("OnDeviceText", "guid", "MDAY", -1, -1, -1, "MAYDAY", {})
    assertEq(#SYMBOLS,1)
end

return T
