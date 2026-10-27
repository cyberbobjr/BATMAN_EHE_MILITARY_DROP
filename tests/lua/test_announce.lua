-- MilitaryDrop_Announce : repère de carte seulement pour qui entend la ligne.

local T = {}

--- Symbole simulé : couleur relue octet par octet, comme après un rechargement.
function MAKE_SYMBOL(id, x, y, r, g, b)
    local symbol = { color = { r, g, b } }
    symbol.isTexture = function() return true end
    symbol.getSymbolID = function() return id end
    symbol.getWorldX = function() return x end
    symbol.getWorldY = function() return y end
    symbol.setRGBA = function(_, cr, cg, cb)
        symbol.color = { math.floor(cr * 255) / 255, math.floor(cg * 255) / 255, math.floor(cb * 255) / 255 }
    end
    symbol.getRed = function() return symbol.color[1] end
    symbol.getGreen = function() return symbol.color[2] end
    symbol.getBlue = function() return symbol.color[3] end
    symbol.setAnchor = function() end
    symbol.scale = 1
    symbol.setScale = function(_, value) symbol.scale = value end
    return symbol
end

function T.setup()
    SandboxVars = {}
    SYMBOLS = {}
    local api = {
        getSymbolCount = function() return #SYMBOLS end,
        getSymbolByIndex = function(_, i) return SYMBOLS[i + 1] end,
        addTexture = function(_, id, x, y)
            local symbol = MAKE_SYMBOL(id, x, y, 1, 1, 1)
            SYMBOLS[#SYMBOLS + 1] = symbol
            return symbol
        end,
        removeSymbolByIndex = function(_, i) table.remove(SYMBOLS, i + 1) end,
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

function T.recon_radio_path_ignores_unheard_lines()
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
    assertEq(#SYMBOLS, 2, "seul le nettoyage (tête de mort et cercle), une fois")
    assertEq(SYMBOLS[1].getSymbolID(), "Skull", "symbole du nettoyage")
    assertEq(SYMBOLS[2].getSymbolID(), "Circle", "cercle du rayon")
    assertEq(SYMBOLS[1].getWorldX() .. "," .. SYMBOLS[1].getWorldY(), "1200,1300", "centre de la zone")
    local A = MilitaryDrop.Announce
    assertTrue(A.CLEANUP_SYMBOL ~= A.RECON_SYMBOL and A.CLEANUP_SYMBOL ~= A.SYMBOL, "symbole distinct")
    assertTrue(A.CLEANUP_CODE ~= A.RECON_CODE and A.CLEANUP_CODE ~= A.CODE, "code distinct")
    assertTrue(A.CLEANUP_COLOR.r ~= A.RECON_COLOR.r and A.CLEANUP_COLOR.r ~= A.COLOR.r, "couleur distincte")
    assertEq(colors[1][1], A.CLEANUP_COLOR.r, "couleur appliquée")
    triggerEvent("OnDeviceText", "guid", "MDRC", -1, -1, -1, "line", {})
    assertEq(SYMBOLS[3].getSymbolID(), "Eye", "puis la reconnaissance, indépendante, sans cercle")
    assertEq(#SYMBOLS, 3, "pas de cercle pour la reconnaissance")
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
    assertEq(#SYMBOLS, 2, "radio posée à portée : tête de mort et cercle")
end

function T.existing_symbol_is_not_duplicated()
    MilitaryDrop.Announce.markMap(500, 600)
    assertEq(MilitaryDrop.Announce.markMap(500, 600), false, "doublon refusé")
    assertEq(#SYMBOLS, 1, "un symbole")
end

function T.base_reply_marks_the_mission_once()
    local A = MilitaryDrop.Announce
    assertEq(A.markMission({ kind = "recon", id = "M7", x = 700, y = 800 }), true, "grille dite par la base")
    assertEq(SYMBOLS[1].getSymbolID(), "Eye", "symbole de la reconnaissance")
    assertEq(A.markMission({ kind = "recon", id = "M7", x = 700, y = 800 }), false, "une fois par mission")
    -- Annonce entendue ensuite : déjà marquée.
    A.onReconAnnounce({ id = "M7", x = 700, y = 800 })
    triggerEvent("OnDeviceText", "guid", "MDRC", -1, -1, -1, "line", {})
    assertEq(#SYMBOLS, 1, "pas de doublon")
    assertEq(A.markMission({ kind = "cleanup", id = "M8", x = 900, y = 950, radius = 40 }), true, "nettoyage")
    assertEq(SYMBOLS[2].getSymbolID(), "Skull", "symbole du nettoyage")
    assertEq(SYMBOLS[3].getSymbolID(), "Circle", "cercle du rayon dit par la base")
    assertEq(A.markMission({ kind = "control", id = "M9", x = 1, y = 1 }), false, "mission sans grille")
    assertEq(A.markMission({ kind = "recon", id = 5, x = 1, y = 1 }), false, "identifiant invalide")
end

function T.outdated_markers_are_removed_and_others_kept()
    local A = MilitaryDrop.Announce
    A.markMap(500, 600)
    A.markMap(510, 610)
    A.markMap(700, 800, A.RECON_SYMBOL, A.RECON_COLOR)
    A.markMap(900, 950, A.CLEANUP_SYMBOL, A.CLEANUP_COLOR)
    A.markMap(525, 625, A.MAYDAY_SYMBOL, A.MAYDAY_COLOR)
    -- Symboles du joueur : même icône, couleur d'un stylo vanilla.
    SYMBOLS[#SYMBOLS + 1] = MAKE_SYMBOL("Target", 520, 620, 0.06, 0.39, 0.17)
    SYMBOLS[#SYMBOLS + 1] = MAKE_SYMBOL("Eye", 720, 820, 0.156, 0.188, 0.49)
    local removed = A.onActiveMarks({ drops = { { x = 510, y = 610 } }, recon = {}, cleanup = { { x = 900, y = 950 } } })
    assertEq(removed, 2, "largage clos et reconnaissance close retirés")
    local left = {}
    for _, symbol in ipairs(SYMBOLS) do
        left[#left + 1] = symbol.getSymbolID() .. "@" .. symbol.getWorldX()
    end
    assertEq(table.concat(left, " "), "Target@510 Skull@900 Question@525 Target@520 Eye@720",
        "actifs, MAYDAY et symboles du joueur gardés")
    assertEq(A.onActiveMarks(nil), 0, "liste invalide ignorée")
end

function T.legacy_markers_with_full_alpha_are_recognised()
    local A = MilitaryDrop.Announce
    local c = A.RECON_COLOR
    SYMBOLS[1] = MAKE_SYMBOL("Eye", 700, 800, math.floor(c.r * 255) / 255, math.floor(c.g * 255) / 255,
        math.floor(c.b * 255) / 255)
    assertEq(A.onActiveMarks({ drops = {}, recon = {}, cleanup = {} }), 1, "repère d'une session précédente")
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

function T.cleanup_circle_covers_the_radius_and_is_removed_with_the_mission()
    local A = MilitaryDrop.Announce
    A.onCleanupAnnounce({ id = "M3", x = 1200, y = 1300, radius = 40 })
    triggerEvent("OnDeviceText", "guid", "MDCU", -1, -1, -1, "line", {})
    local circle = SYMBOLS[2]
    assertEq(circle.getSymbolID(), "Circle", "cercle posé")
    assertEq(circle.getWorldX() .. "," .. circle.getWorldY(), "1200,1300", "centré sur la zone")
    -- Anneau de 50 pixels sur 64 d'une icône de 20 cases : diamètre = 2 × rayon.
    assertTrue(math.abs(circle.scale * 20 * 50 / 64 - 80) < 1e-9, "diamètre de 80 cases pour un rayon de 40")
    assertTrue(math.abs(circle.color[1] - A.CLEANUP_CIRCLE_COLOR.r) <= A.COLOR_TOLERANCE, "couleur du mod")
    -- Cercle d'un joueur (couleur vanilla) au même endroit : jamais retiré.
    local own = MAKE_SYMBOL("Circle", 1200, 1300, 0.65, 0.054, 0.054)
    SYMBOLS[#SYMBOLS + 1] = own
    assertEq(A.onActiveMarks({ drops = {}, recon = {}, cleanup = { { x = 1200, y = 1300 } } }), 0,
        "mission encore ouverte : rien de retiré")
    assertEq(A.onActiveMarks({ drops = {}, recon = {}, cleanup = {} }), 2, "mission close : tête de mort et cercle retirés")
    assertEq(#SYMBOLS, 1, "seul le cercle du joueur reste")
    assertEq(SYMBOLS[1], own, "cercle du joueur gardé")
end

function T.cleanup_circle_is_not_duplicated_and_needs_a_radius()
    local A = MilitaryDrop.Announce
    assertEq(A.markCircle(500, 600, 40), true, "premier cercle")
    assertEq(A.markCircle(500, 600, 40), false, "doublon refusé")
    assertEq(A.markCircle(700, 800, nil), false, "sans rayon : rien")
    assertEq(A.markCircle(700, 800, 0), false, "rayon nul : rien")
    assertEq(#SYMBOLS, 1, "un seul cercle")
end

function T.relay_marker_appears_once_resynchronizes_and_only_removes_its_own_symbol()
    local A = MilitaryDrop.Announce
    MilitaryDrop.Relay = { SITES = { { x = 4832, y = 6281 } } }
    local update = { phase = "failed", site = 1, serial = 7 }
    assertEq(A.onRelayState(update), true)
    assertEq(A.onRelayState(update), false)
    assertEq(#SYMBOLS, 1)
    assertEq(SYMBOLS[1].getSymbolID(), "Exclamation")
    assertEq(SYMBOLS[1].getWorldX(), 4832)
    assertEq(SYMBOLS[1].getWorldY(), 6281)
    local own = MAKE_SYMBOL("Exclamation", 5000, 6300, 0.65, 0.054, 0.054)
    SYMBOLS[#SYMBOLS + 1] = own
    assertEq(A.onActiveMarks({ relay = { { x = 4832, y = 6281 } } }), 0)
    loadMod("client/MilitaryDrop/MilitaryDrop_Announce.lua")
    A = MilitaryDrop.Announce
    A.onRelayState(update)
    assertEq(#SYMBOLS, 2, "a saved marker is not duplicated after reconnect")
    assertEq(A.onActiveMarks({ relay = {} }), 1)
    assertEq(SYMBOLS[1], own, "personal notes are retained")
    assertEq(A.onRelayState({ phase = "operational", site = 1, serial = 7 }), false)
    assertEq(A.onRelayState({ phase = "failed", site = 99, serial = 8 }), false)
end

function T.secured_marker_replaces_cleanup_and_expires_without_touching_personal_notes()
    local A = MilitaryDrop.Announce
    A.markMission({ kind = "cleanup", id = "M_done", x = 700, y = 800, radius = 40 })
    SYMBOLS[#SYMBOLS + 1] = MAKE_SYMBOL("Checkmark", 710, 810, 1, 0, 0)
    A.onActiveMarks({ cleanup = {}, secured = { { x = 700, y = 800 } } })
    assertEq(#SYMBOLS, 2, "only personal note and secured marker remain")
    assertEq(SYMBOLS[2].getSymbolID(), "Checkmark")
    loadMod("client/MilitaryDrop/MilitaryDrop_Announce.lua")
    A = MilitaryDrop.Announce
    A.onActiveMarks({ secured = { { x = 700, y = 800 } } })
    assertEq(#SYMBOLS, 2, "reconnection does not duplicate saved marker")
    A.onActiveMarks({ secured = {} })
    assertEq(#SYMBOLS, 1, "expired secured marker removed")
    assertEq(SYMBOLS[1].getWorldX(), 710, "personal annotation retained")
end

function T.active_recon_is_marked_without_radio_and_restored_after_reconnect()
    local A = MilitaryDrop.Announce
    local state = { drops = {}, recon = { { x = 700, y = 800 } }, cleanup = {}, relay = {} }
    A.onActiveMarks(state)
    assertEq(#SYMBOLS, 1)
    assertEq(SYMBOLS[1].getSymbolID(), "Eye")
    assertEq(SYMBOLS[1].getWorldX(), 700)
    A.onActiveMarks(state)
    assertEq(#SYMBOLS, 1, "periodic state does not duplicate the eye")
    loadMod("client/MilitaryDrop/MilitaryDrop_Announce.lua")
    A = MilitaryDrop.Announce
    A.onActiveMarks(state)
    assertEq(#SYMBOLS, 1, "saved map remains deduplicated after reconnect")
    SYMBOLS[1] = nil
    A.onActiveMarks(state)
    assertEq(#SYMBOLS, 1, "missing active marker is restored")
    assertEq(A.onActiveMarks({ recon = {} }), 1, "closed mission removes the eye")
    assertEq(#SYMBOLS, 0)
end

return T
