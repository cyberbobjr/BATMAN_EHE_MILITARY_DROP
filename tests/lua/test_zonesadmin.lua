-- MilitaryDrop_ZonesAdmin / MilitaryDrop_ZonesWindow : outil d'admin des
-- zones de largage (ZONE-03) — menu réservé à l'admin, coins → ZoneAdd
-- normalisé, rectangle trop grand refusé, réponses du serveur, contours.

local T = {}

--- Menu contextuel simulé (ISContextMenu) : options, sous-menus, coches.
local function newMenu(registry)
    local menu = { options = {}, registry = registry }
    function menu:addOption(name, target, onSelect, ...)
        local option = { name = name, target = target, onSelect = onSelect, params = { ... } }
        self.options[#self.options + 1] = option
        return option
    end
    function menu:getOptionFromName(name)
        for _, option in ipairs(self.options) do
            if option.name == name then
                return option
            end
        end
    end
    function menu:addSubMenu(option, sub)
        option.subOption = sub.id
        option.sub = sub
    end
    function menu:getSubMenu(id)
        return self.registry[id]
    end
    function menu:setOptionChecked(option, checked)
        option.checkMark = checked
    end
    return menu
end

local function option(menu, name)
    return menu and menu:getOptionFromName(name)
end

--- Choisit une option : appelle onSelect(target, params...).
local function pick(opt)
    assertTrue(opt and opt.onSelect, "option sélectionnable")
    return opt.onSelect(opt.target, unpack(opt.params))
end

function T.setup()
    SandboxVars = {}
    CLIENT, DEBUG = false, true
    isClient = function() return CLIENT end
    isServer = function() return false end
    isDebugEnabled = function() return DEBUG end
    getTimestampMs = function() return 1000 end
    getText = function(key, ...)
        local parts = { key }
        for _, value in ipairs({ ... }) do
            parts[#parts + 1] = tostring(value)
        end
        return table.concat(parts, "|")
    end
    Capability = { ChangeAndReloadServerOptions = "reload", TeleportToCoordinates = "teleport" }
    CAPS = { reload = true, teleport = true }
    SAID = {}
    PLAYER = {
        getPlayerNum = function() return 0 end,
        getRole = function() return { hasCapability = function(_, cap) return CAPS[cap] == true end } end,
        Say = function(_, text) SAID[#SAID + 1] = text end,
        getJoypadBind = function() return -1 end,
        getX = function() return 50.5 end,
        getY = function() return 60.5 end,
        teleportTo = function(self, x, y, z) self.teleported = { x = x, y = y, z = z } end,
    }
    getSpecificPlayer = function(n) return n == 0 and PLAYER or nil end
    -- Messages au serveur : solo (Server.onClientCommand) et MP (sendClientCommand).
    SENT = {}
    MilitaryDrop = nil
    sendClientCommand = function(_, module, command, args)
        SENT[#SENT + 1] = { module = module, command = command, args = args }
    end
    TELEPORT = nil
    SendCommandToServer = function(text) TELEPORT = text end
    -- Boîtes de saisie (ISTextBox) ouvertes.
    BOXES = {}
    ISTextBox = {}
    function ISTextBox.new(_, _, _, _, _, title, default, target, onclick, playerNum)
        local box = { title = title, default = default, target = target, onclick = onclick, playerNum = playerNum }
        function box:setValidateFunction(t, f) self.validateTarget, self.validate = t, f end
        function box:setValidateTooltipText(text) self.validateTip = text end
        function box:initialise() end
        function box:addToUIManager() BOXES[#BOXES + 1] = self end
        return box
    end
    REGISTRY, NEXT_MENU = {}, 0
    ISContextMenu = {
        getNew = function()
            NEXT_MENU = NEXT_MENU + 1
            local menu = newMenu(REGISTRY)
            menu.id = NEXT_MENU
            REGISTRY[menu.id] = menu
            return menu
        end,
    }
    ISWorldObjectContextMenu = {
        addToolTip = function() return {} end,
        setTest = function() return "tested" end,
    }
    JoypadState = { players = {} }
    HIGHLIGHTS = {}
    addAreaHighlightForPlayer = function(playerNum, x1, y1, x2, y2, z, r, g, b, a)
        HIGHLIGHTS[#HIGHLIGHTS + 1] = { playerNum = playerNum, x1 = x1, y1 = y1, x2 = x2, y2 = y2, z = z, r = r, a = a }
    end
    getMouseX = function() return 0 end
    getMouseY = function() return 0 end
    MOUSE = { x = 130.7, y = 90.2 }
    screenToIsoX = function() return MOUSE.x end
    screenToIsoY = function() return MOUSE.y end
    instanceof = function() return false end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_Client.lua")
    MilitaryDrop.Server = { onClientCommand = function(module, command, _, args)
        SENT[#SENT + 1] = { module = module, command = command, args = args }
    end }
    loadMod("client/MilitaryDrop/MilitaryDrop_ZonesAdmin.lua")
end

local function square(x, y, z)
    -- getObjects : parcouru par le menu radio de MilitaryDrop_Client.
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z or 0 end,
        getObjects = function() return { size = function() return 0 end } end }
end

--- Ouvre le menu du monde sur une case ; renvoie le menu racine et le
--- sous-menu « Zones de largage » (nil si absent).
local function openMenu(x, y, z, test)
    local context = newMenu(REGISTRY)
    local object = { getSquare = function() return square(x, y, z) end }
    local result
    for _, handler in ipairs(Events.OnFillWorldObjectContextMenu.handlers) do
        result = handler(0, context, { object }, test) or result
    end
    local admin = option(context, "IGUI_MilitaryDrop_AdminMenu")
    local zones = admin and option(admin.sub, "IGUI_MilitaryDrop_ZonesMenu")
    return context, zones and zones.sub, result
end

local function lastSent()
    return SENT[#SENT]
end

local function listReply(args)
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "ZoneListReply", args)
end

local function zoneReply(args)
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "ZoneReply", args)
end

function T.menu_is_absent_for_a_player_without_the_admin_right()
    CLIENT, CAPS = true, { teleport = true }
    local context = openMenu(10, 10)
    assertEq(#context.options, 0, "client MP sans ChangeAndReloadServerOptions")
    CLIENT, DEBUG = false, false
    context = openMenu(10, 10)
    assertEq(#context.options, 0, "solo hors mode debug")
end

function T.admin_menu_lists_the_tools_and_corner_two_only_after_corner_one()
    CLIENT = true
    local _, zones = openMenu(10, 20)
    assertTrue(zones, "sous-menu Zones de largage pour l'admin MP")
    assertTrue(option(zones, "IGUI_MilitaryDrop_ZoneCorner1|10|20"), "coin 1 avec la case")
    assertEq(option(zones, "IGUI_MilitaryDrop_ZoneCorner2|1|1"), nil, "pas de coin 2 avant le coin 1")
    assertTrue(option(zones, "IGUI_MilitaryDrop_ZoneListOpen"), "liste")
    assertTrue(option(zones, "IGUI_MilitaryDrop_ZoneReloadFile"), "rechargement")
    local outlines = option(zones, "IGUI_MilitaryDrop_ZoneToggleOutlines")
    assertEq(outlines.checkMark, false, "contours masqués par défaut")
    pick(option(zones, "IGUI_MilitaryDrop_ZoneReloadFile"))
    assertEq(lastSent().command, "ZoneReload", "rechargement demandé")
    assertEq(lastSent().module, "MilitaryDrop", "module du mod")
end

function T.test_pass_for_the_controller_adds_nothing()
    local context, _, result = openMenu(10, 20, 0, true)
    assertEq(result, "tested", "setTest renvoyé")
    assertEq(#context.options, 0, "aucune option en test")
end

function T.corners_send_a_normalized_zone_add_with_a_known_sector()
    listReply({ zones = {}, sectors = { "Riverside", "Louisville" } })
    local _, zones = openMenu(120, 80)
    pick(option(zones, "IGUI_MilitaryDrop_ZoneCorner1|120|80"))
    assertEq(#SENT, 0, "liste déjà connue : rien à demander")
    local _, zones2 = openMenu(100, 95)
    local corner2 = option(zones2, "IGUI_MilitaryDrop_ZoneCorner2|21|16")
    assertTrue(corner2 and corner2.sub, "coin 2 : taille du rectangle et choix du secteur")
    assertEq(corner2.sub.options[1].name, "Louisville", "secteurs triés")
    assertEq(corner2.sub.options[3].name, "IGUI_MilitaryDrop_ZoneNewSector", "nouveau secteur en dernier")
    pick(option(corner2.sub, "Louisville"))
    assertEq(#BOXES, 1, "nom de la zone demandé")
    local box = BOXES[1]
    assertEq(box.title, "IGUI_MilitaryDrop_ZoneNameTitle|Louisville", "secteur rappelé")
    assertEq(box.maxChars, 32, "32 caractères au plus")
    assertTrue(box.noEmpty, "nom non vide")
    assertEq(box.validate(nil, "Parc <b>"), false, "balises refusées")
    assertEq(box.validate(nil, "Central Park"), true, "nom ordinaire accepté")
    box.onclick(box.target, { internal = "OK", parent = { entry = { getText = function() return " Central Park " end } } })
    local add = lastSent()
    assertEq(add.command, "ZoneAdd", "ZoneAdd")
    assertEq(add.args.sector, "Louisville", "secteur")
    assertEq(add.args.name, "Central Park", "nom nettoyé")
    assertEq(add.args.x1, 100, "x1 = min")
    assertEq(add.args.y1, 80, "y1 = min")
    assertEq(add.args.x2, 120, "x2 = max")
    assertEq(add.args.y2, 95, "y2 = max")
    zoneReply({ ok = true, action = "add", id = "z3", warnings = { "noRoad" } })
    assertEq(SAID[#SAID], "IGUI_MilitaryDrop_ZoneOk_add|z3 IGUI_MilitaryDrop_ZoneWarnings|IGUI_MilitaryDrop_ZoneWarn_noRoad",
        "succès et avertissement traduits")
    assertEq(MilitaryDrop.ZonesAdmin.drafts[0], nil, "tracé terminé")
end

function T.new_sector_asks_the_sector_then_the_name_and_requests_the_list_once()
    local _, zones = openMenu(5, 5)
    pick(option(zones, "IGUI_MilitaryDrop_ZoneCorner1|5|5"))
    assertEq(lastSent().command, "ZoneList", "secteurs demandés au coin 1")
    local _, zones2 = openMenu(9, 7)
    local corner2 = option(zones2, "IGUI_MilitaryDrop_ZoneCorner2|5|3")
    pick(option(corner2.sub, "IGUI_MilitaryDrop_ZoneNewSector"))
    assertEq(BOXES[1].title, "IGUI_MilitaryDrop_ZoneSectorTitle", "secteur demandé")
    BOXES[1].onclick(nil, { internal = "OK", parent = { entry = { getText = function() return "Raven Creek" end } } })
    assertEq(BOXES[2].title, "IGUI_MilitaryDrop_ZoneNameTitle|Raven Creek", "puis le nom")
    BOXES[2].onclick(nil, { internal = "Cancel", parent = { entry = { getText = function() return "x" end } } })
    assertEq(lastSent().command, "ZoneList", "annulé : rien envoyé")
    BOXES[2].onclick(nil, { internal = "OK", parent = { entry = { getText = function() return "Mall" end } } })
    assertEq(lastSent().command, "ZoneAdd", "ZoneAdd")
    assertEq(lastSent().args.sector, "Raven Creek", "nouveau secteur")
    assertEq(lastSent().args.x2, 9, "coin 2")
end

function T.rectangle_larger_than_300_squares_is_refused()
    local Admin = MilitaryDrop.ZonesAdmin
    local _, zones = openMenu(1000, 2000)
    pick(option(zones, "IGUI_MilitaryDrop_ZoneCorner1|1000|2000"))
    local _, zones2 = openMenu(1300, 2010)
    local corner2 = option(zones2, "IGUI_MilitaryDrop_ZoneCorner2|301|11")
    assertTrue(corner2.notAvailable, "coin 2 grisé au-delà de 300 cases")
    assertEq(corner2.sub, nil, "pas de choix de secteur")
    assertEq(corner2.toolTip.description, "IGUI_MilitaryDrop_ZoneTooBigTip|300", "motif")
    assertEq(Admin.onCorner2(PLAYER, 1300, 2010, "A"), false, "refusé aussi à l'appel direct")
    assertEq(#BOXES, 0, "aucune saisie")
    local _, zones3 = openMenu(1299, 1701)
    local ok = option(zones3, "IGUI_MilitaryDrop_ZoneCorner2|300|300")
    assertTrue(ok and ok.sub and not ok.notAvailable, "300 x 300 accepté")
    for _, sent in ipairs(SENT) do
        assertTrue(sent.command ~= "ZoneAdd", "aucun ZoneAdd")
    end
end

function T.corners_are_ground_level_only()
    local _, zones = openMenu(10, 10, 1)
    local corner1 = option(zones, "IGUI_MilitaryDrop_ZoneCorner1|10|10")
    assertTrue(corner1.notAvailable, "coin 1 grisé à l'étage")
    assertEq(corner1.toolTip.description, "IGUI_MilitaryDrop_ZoneLevel0Tip", "motif")
end

function T.list_reply_is_cleaned_and_every_error_code_is_translated()
    local Admin = MilitaryDrop.ZonesAdmin
    listReply({
        zones = {
            { id = "z1", sector = "<RGB:1,0,0>Louisville", name = "Central\nPark", x1 = 20, y1 = 30, x2 = 10, y2 = 5,
              weight = 2, enabled = true, active = true, warnings = { "risk" } },
            { id = "z2", sector = "Louisville", name = string.rep("N", 50), x1 = 1, y1 = 1, x2 = 2, y2 = 2,
              enabled = false, active = false },
            { id = "bad", sector = "X", name = "Y" },
        },
        sectors = { "Louisville" }, map = "Muldraugh, KY", mapLoaded = true, placement = 2,
        problems = { "zone #3 (z3): bad <rectangle>" },
    })
    local list = Admin.list
    assertEq(#list.zones, 2, "zone sans coordonnées écartée")
    local z1 = list.zones[1]
    assertEq(z1.sector, "RGB:1,0,0Louisville", "sans < >")
    assertEq(z1.name, "CentralPark", "sans caractère de contrôle")
    assertEq(z1.x1 .. "," .. z1.y1 .. "," .. z1.x2 .. "," .. z1.y2, "10,5,20,30", "rectangle normalisé")
    assertEq(z1.width, 11, "largeur incluse")
    assertEq(#list.zones[2].name, 32, "nom coupé à 32")
    assertEq(list.problems[1], "zone #3 (z3): bad rectangle", "problème nettoyé")
    assertEq(#list.sectors, 2, "secteurs reçus et secteurs des zones")
    for code in pairs(Admin.ERRORS) do
        zoneReply({ ok = false, error = code })
        assertEq(SAID[#SAID], "IGUI_MilitaryDrop_ZoneErr_" .. code, "erreur " .. code)
    end
    zoneReply({ ok = false, error = "surprise" })
    assertEq(SAID[#SAID], "IGUI_MilitaryDrop_ZoneErr_other", "code inconnu")
    for code in pairs(Admin.WARNINGS) do
        assertEq(Admin.warningText(code), "IGUI_MilitaryDrop_ZoneWarn_" .. code, "avertissement " .. code)
    end
    zoneReply({ ok = true, action = "delete", id = "z2" })
    assertEq(SAID[#SAID], "IGUI_MilitaryDrop_ZoneOk_delete|z2", "suppression confirmée")
end

function T.outlines_are_drawn_only_when_shown_for_an_admin()
    local Admin = MilitaryDrop.ZonesAdmin
    listReply({ zones = {
        { id = "z1", sector = "A", name = "B", x1 = 10, y1 = 20, x2 = 30, y2 = 40, enabled = true, active = true },
        { id = "z2", sector = "A", name = "C", x1 = 0, y1 = 0, x2 = 1, y2 = 1, enabled = false },
    } })
    triggerEvent("OnPreUIDraw")
    assertEq(#HIGHLIGHTS, 0, "affichage désactivé : rien")
    Admin.toggleOutlines(PLAYER)
    triggerEvent("OnPreUIDraw")
    assertEq(#HIGHLIGHTS, 2, "deux zones")
    assertEq(HIGHLIGHTS[1].x2, 31, "case x2 incluse")
    assertEq(HIGHLIGHTS[1].y2, 41, "case y2 incluse")
    assertEq(HIGHLIGHTS[1].z, 0, "niveau 0")
    assertEq(HIGHLIGHTS[1].r, Admin.COLORS.active[1], "active en vert")
    assertEq(HIGHLIGHTS[2].r, Admin.COLORS.disabled[1], "désactivée en gris")
    -- Tracé en cours : du coin 1 à la case sous la souris.
    Admin.onCorner1(PLAYER, 100, 80)
    HIGHLIGHTS = {}
    triggerEvent("OnPreUIDraw")
    local draft = HIGHLIGHTS[3]
    assertEq(draft.x1 .. "," .. draft.y1 .. "," .. draft.x2 .. "," .. draft.y2, "100,80,131,91", "aperçu jusqu'à la souris")
    MOUSE.x = 500
    HIGHLIGHTS = {}
    triggerEvent("OnPreUIDraw")
    assertEq(HIGHLIGHTS[3].r, Admin.COLORS.tooBig[1], "trop grand : en rouge")
    -- Droit perdu en MP : plus rien.
    CLIENT, CAPS = true, {}
    HIGHLIGHTS = {}
    triggerEvent("OnPreUIDraw")
    assertEq(#HIGHLIGHTS, 0, "plus admin : aucun contour")
end

function T.reloading_the_file_does_not_stack_handlers()
    local menus, draws = listenerCount("OnFillWorldObjectContextMenu"), listenerCount("OnPreUIDraw")
    loadMod("client/MilitaryDrop/MilitaryDrop_ZonesAdmin.lua")
    assertEq(listenerCount("OnFillWorldObjectContextMenu"), menus, "menu inscrit une fois")
    assertEq(listenerCount("OnPreUIDraw"), draws, "dessin inscrit une fois")
end

function T.go_to_uses_the_vanilla_admin_teleport()
    local zone = { x1 = 100, y1 = 80, x2 = 121, y2 = 95 }
    CLIENT = true
    MilitaryDrop.ZonesAdmin.goTo(PLAYER, zone)
    assertEq(TELEPORT, "/teleportto 110,87,0", "commande serveur en MP")
    CLIENT = false
    MilitaryDrop.ZonesAdmin.goTo(PLAYER, zone)
    assertEq(PLAYER.teleported.x, 110.5, "solo : déplacement direct")
    assertEq(PLAYER.teleported.z, 0, "niveau 0")
    CLIENT, CAPS = true, { reload = true }
    assertEq(MilitaryDrop.ZonesAdmin.canTeleport(PLAYER), false, "MP sans TeleportToCoordinates")
end

-- ----------------------------------------------------------------------------
-- Fenêtre : lignes de la liste
-- ----------------------------------------------------------------------------

local function loadWindow()
    UIFont = { Small = "Small" }
    getTextManager = function()
        return {
            MeasureStringX = function(_, _, text) return #text * 7 end,
            getFontHeight = function() return 14 end,
        }
    end
    ISCollapsableWindow = { derive = function(self) return setmetatable({}, { __index = self }) end }
    loadMod("client/MilitaryDrop/MilitaryDrop_ZonesWindow.lua")
    return MilitaryDrop.ZonesWindow
end

function T.window_rows_are_grouped_by_sector_and_fitted()
    local Window = loadWindow()
    local list = MilitaryDrop.ZonesAdmin.normalizeList({
        zones = {
            { id = "z2", sector = "riverside", name = "Docks", x1 = 1, y1 = 1, x2 = 9, y2 = 9, enabled = true,
              active = true },
            { id = "z1", sector = "Louisville", name = string.rep("W", 32), x1 = 1, y1 = 1, x2 = 4, y2 = 2,
              enabled = true, active = false, warnings = { "mapNotLoaded" } },
        },
        problems = { "zone #4: syntax" },
    })
    local rows = Window.buildRows(list, 400)
    assertEq(rows[1].kind, "sector", "en-tête de secteur")
    assertEq(rows[1].lines[1], "Louisville", "secteurs sans casse")
    assertEq(rows[2].zone.id, "z1", "zone du secteur")
    assertTrue(#rows[2].lines[1] * 7 <= 400 - 16, "nom coupé à la largeur")
    assertTrue(rows[2].lines[1]:sub(-3) == "...", "coupure marquée")
    assertEq(rows[2].state, "IGUI_MilitaryDrop_ZoneStateMapNotLoaded", "carte non chargée")
    assertEq(rows[2].lines[3], "IGUI_MilitaryDrop_ZoneWarn_mapNotLoaded", "avertissement traduit")
    assertEq(rows[3].lines[1], "riverside", "second secteur")
    assertEq(rows[4].state, "IGUI_MilitaryDrop_ZoneStateActive", "zone active")
    assertEq(rows[5].lines[1], "IGUI_MilitaryDrop_ZoneProblems", "problèmes du fichier")
    assertEq(rows[6].lines[1], "zone #4: syntax", "problème")
    local empty = Window.buildRows(MilitaryDrop.ZonesAdmin.normalizeList({}), 400)
    assertEq(empty[1].kind, "note", "liste vide : indication")
end

return T
