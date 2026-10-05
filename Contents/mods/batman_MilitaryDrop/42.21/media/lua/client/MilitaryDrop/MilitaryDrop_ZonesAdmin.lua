-- ============================================================================
-- Military Drop — outil d'admin des zones de largage (ZONE-03, côté client)
--
-- Menu du monde (clic droit sur une case du niveau 0), pour un admin
-- seulement : « Military Drop (admin) » › « Zones de largage » › Coin 1 ici,
-- Coin 2 ici (secteur connu ou nouveau, puis nom), Liste des zones…,
-- Recharger dropzones.txt, Afficher / masquer les contours. Le client
-- n'envoie que des coordonnées et des noms (ZoneAdd, ZoneSetEnabled,
-- ZoneDelete, ZoneReload, ZoneList) ; le serveur revérifie le droit
-- (Requisition.canReload), valide, écrit dropzones.txt et répond ZoneReply
-- puis ZoneListReply (contrat : dev/analyses/idee-11-zones-de-largage.md §2.3).
-- Droit affiché ici : capacité ChangeAndReloadServerOptions sur un client MP,
-- mode debug en solo (le serveur, lui, accepte tout en solo).
--
-- Rectangle : les deux cases cliquées en font partie (bornes incluses,
-- x1 ≤ x2, y1 ≤ y2) ; côté = x2 - x1 + 1, refusé ici au-delà de MAX_SIDE.
--
-- Contours au sol : addAreaHighlightForPlayer (LuaManager.java:9802), le
-- tracé vanilla des zones non-PvP (ISAddNonPvpZoneUI:prerender). Un contour
-- ne vit qu'une image d'interface : FBORenderAreaHighlights.render
-- (FBORenderAreaHighlights.java:61-66) jette ceux dont renderTimeMs n'est plus
-- UIManager.uiRenderTimeMS, mis à jour au début de UIManager.render, juste
-- avant OnPreUIDraw (UIManager.java:283-303). Ils sont donc reposés à chaque
-- OnPreUIDraw, seulement chez ce client (aucun paquet) et seulement pour les
-- zones reçues par ZoneListReply : les joueurs ne reçoivent jamais la liste.
-- Le quadrilatère va de x1 à x2 en coordonnées du monde (render:229-262) :
-- une zone de cases x1..x2 incluses se dessine de x1 à x2 + 1.
--
-- Textes de l'admin (secteur, nom) et du serveur : sans caractère de contrôle
-- ni < >, coupés à MAX_TEXT caractères entiers (MilitaryDrop.cutText).
-- ============================================================================

require "ISUI/ISTextBox"
require "ISUI/ISContextMenu"
require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Client"

local Net = MilitaryDrop.Net
local Client = MilitaryDrop.Client

local ZonesAdmin = MilitaryDrop.ZonesAdmin or {}
MilitaryDrop.ZonesAdmin = ZonesAdmin

ZonesAdmin.MAX_SIDE = 300
ZonesAdmin.MAX_TEXT = 32
-- Secteurs proposés dans le sous-menu de « Coin 2 ici ».
ZonesAdmin.MAX_SECTORS_MENU = 30

-- Codes du contrat ; tout autre code reçoit le message générique (« other »).
ZonesAdmin.ERRORS = {
    denied = true, busy = true, invalid = true, badName = true, badSector = true, tooBig = true,
    tooSmall = true, offMap = true, overlapNonPvp = true, overlapSafehouse = true, tooMany = true,
    unknownZone = true, writeFailed = true, syntaxError = true,
}
ZonesAdmin.WARNINGS = {
    noRoad = true, risk = true, nonPvp = true, safehouse = true, offMap = true, mapNotLoaded = true,
}
ZonesAdmin.ACTIONS = { add = true, enable = true, delete = true, reload = true }

-- Couleurs des contours (r, g, b, opacité du remplissage).
ZonesAdmin.COLORS = {
    active = { 0.2, 0.9, 0.2, 0.12 },
    disabled = { 0.6, 0.6, 0.6, 0.08 },
    unusable = { 1.0, 0.6, 0.1, 0.12 },
    draft = { 0.2, 0.5, 1.0, 0.2 },
    tooBig = { 1.0, 0.1, 0.1, 0.25 },
}

-- Dernière ZoneListReply : { zones, sectors, map, mapLoaded, placement,
-- problems } nettoyée (ZonesAdmin.normalizeList), ou nil.
ZonesAdmin.list = ZonesAdmin.list
-- Joueur local → tracé en cours : { x1, y1 } puis { x2, y2 } au coin 2.
ZonesAdmin.drafts = ZonesAdmin.drafts or {}
-- Joueur local → contours affichés.
ZonesAdmin.shown = ZonesAdmin.shown or {}
-- Joueur local qui a envoyé la dernière commande (reçoit les réponses).
ZonesAdmin.lastPlayerNum = ZonesAdmin.lastPlayerNum or 0

-- ----------------------------------------------------------------------------
-- Outils
-- ----------------------------------------------------------------------------

--- Texte affichable : sans caractère de contrôle ni < >, espaces de bord
--- retirés, coupé à max caractères entiers (MAX_TEXT par défaut).
function ZonesAdmin.cleanText(text, max)
    if type(text) ~= "string" and type(text) ~= "number" then
        return ""
    end
    local clean = string.gsub(tostring(text), "[%c<>]", "")
    clean = string.gsub(clean, "^%s+", "")
    clean = string.gsub(clean, "%s+$", "")
    return MilitaryDrop.cutText(clean, max or ZonesAdmin.MAX_TEXT)
end

--- Vrai si le texte saisi est accepté tel quel (rien à retirer, non vide).
function ZonesAdmin.validText(text)
    if type(text) ~= "string" then
        return false
    end
    if string.find(text, "[%c<>]") then
        return false
    end
    return ZonesAdmin.cleanText(text, #text + 1) ~= ""
end

--- Rectangle normalisé de deux coins (cases incluses) : x1, y1, x2, y2,
--- largeur, hauteur (en cases).
function ZonesAdmin.rect(ax, ay, bx, by)
    local x1, x2 = math.min(ax, bx), math.max(ax, bx)
    local y1, y2 = math.min(ay, by), math.max(ay, by)
    return x1, y1, x2, y2, x2 - x1 + 1, y2 - y1 + 1
end

function ZonesAdmin.tooBig(width, height)
    return width > ZonesAdmin.MAX_SIDE or height > ZonesAdmin.MAX_SIDE
end

--- Droit d'afficher l'outil (le serveur revérifie : Requisition.canReload).
function ZonesAdmin.canUse(player)
    if not player then
        return false
    end
    if isClient() then
        local role = player:getRole()
        return role ~= nil and role:hasCapability(Capability.ChangeAndReloadServerOptions)
    end
    return isDebugEnabled() == true
end

--- Droit de la téléportation vanilla (/teleportto, TeleportToCommand.java:24).
function ZonesAdmin.canTeleport(player)
    if not player then
        return false
    end
    if isClient() then
        local role = player:getRole()
        return role ~= nil and role:hasCapability(Capability.TeleportToCoordinates)
    end
    return true
end

local function send(player, command, args)
    ZonesAdmin.lastPlayerNum = player:getPlayerNum()
    Net.toServer(player, command, args)
end

--- Message d'erreur traduit d'un code du serveur.
function ZonesAdmin.errorText(code)
    if ZonesAdmin.ERRORS[code] then
        return getText("IGUI_MilitaryDrop_ZoneErr_" .. code)
    end
    return getText("IGUI_MilitaryDrop_ZoneErr_other")
end

--- Avertissement traduit ; un code inconnu est montré nettoyé.
function ZonesAdmin.warningText(code)
    if ZonesAdmin.WARNINGS[code] then
        return getText("IGUI_MilitaryDrop_ZoneWarn_" .. code)
    end
    return ZonesAdmin.cleanText(code, 24)
end

--- Liste d'avertissements traduits, séparés par « ; » ("" si aucun).
function ZonesAdmin.warningsText(warnings)
    local parts = {}
    if type(warnings) == "table" then
        for _, code in ipairs(warnings) do
            local text = ZonesAdmin.warningText(code)
            if text ~= "" then
                parts[#parts + 1] = text
            end
        end
    end
    return table.concat(parts, "; ")
end

-- ----------------------------------------------------------------------------
-- Réponses du serveur
-- ----------------------------------------------------------------------------

local function toInt(value)
    local n = tonumber(value)
    if not n then
        return nil
    end
    return math.floor(n)
end

--- ZoneListReply nettoyée : zones valides seulement, textes affichables.
function ZonesAdmin.normalizeList(args)
    local list = { zones = {}, sectors = {}, problems = {} }
    list.map = ZonesAdmin.cleanText(args.map, 120)
    list.mapLoaded = args.mapLoaded ~= false
    list.placement = toInt(args.placement)
    local seenSector = {}
    local function addSector(name)
        if name ~= "" and not seenSector[name] then
            seenSector[name] = true
            list.sectors[#list.sectors + 1] = name
        end
    end
    if type(args.sectors) == "table" then
        for _, name in ipairs(args.sectors) do
            addSector(ZonesAdmin.cleanText(name))
        end
    end
    if type(args.zones) == "table" then
        for _, zone in ipairs(args.zones) do
            if type(zone) == "table" then
                local ax, ay, bx, by = toInt(zone.x1), toInt(zone.y1), toInt(zone.x2), toInt(zone.y2)
                local id = ZonesAdmin.cleanText(zone.id, 16)
                if ax and ay and bx and by and id ~= "" then
                    local x1, y1, x2, y2, w, h = ZonesAdmin.rect(ax, ay, bx, by)
                    local warnings = {}
                    if type(zone.warnings) == "table" then
                        for _, code in ipairs(zone.warnings) do
                            if type(code) == "string" then
                                warnings[#warnings + 1] = code
                            end
                        end
                    end
                    local entry = {
                        id = id,
                        sector = ZonesAdmin.cleanText(zone.sector),
                        name = ZonesAdmin.cleanText(zone.name),
                        x1 = x1, y1 = y1, x2 = x2, y2 = y2, width = w, height = h,
                        weight = toInt(zone.weight) or 1,
                        enabled = zone.enabled ~= false,
                        active = zone.active == true,
                        warnings = warnings,
                    }
                    list.zones[#list.zones + 1] = entry
                    addSector(entry.sector)
                end
            end
        end
    end
    if type(args.problems) == "table" then
        for i, problem in ipairs(args.problems) do
            if i > 10 then
                break
            end
            local text = ZonesAdmin.cleanText(problem, 200)
            if text ~= "" then
                list.problems[#list.problems + 1] = text
            end
        end
    end
    table.sort(list.sectors, function(a, b) return string.lower(a) < string.lower(b) end)
    return list
end

function ZonesAdmin.onListReply(args)
    ZonesAdmin.list = ZonesAdmin.normalizeList(args)
    local Window = MilitaryDrop.ZonesWindow
    if Window and Window.refresh then
        Window.refresh(ZonesAdmin.list)
    end
end

--- Message de ZoneReply : succès (et avertissements) ou erreur traduite.
function ZonesAdmin.replyText(args)
    local text
    if args.ok == true then
        local action = ZonesAdmin.ACTIONS[args.action] and args.action or "reload"
        text = getText("IGUI_MilitaryDrop_ZoneOk_" .. action, ZonesAdmin.cleanText(args.id, 16))
        local warnings = ZonesAdmin.warningsText(args.warnings)
        if warnings ~= "" then
            text = text .. " " .. getText("IGUI_MilitaryDrop_ZoneWarnings", warnings)
        end
    else
        text = ZonesAdmin.errorText(args.error)
    end
    return text
end

function ZonesAdmin.onReply(args)
    local playerNum = ZonesAdmin.lastPlayerNum or 0
    local text = ZonesAdmin.replyText(args)
    if args.ok == true and args.action == "add" then
        -- Zone écrite : le tracé est terminé.
        ZonesAdmin.drafts[playerNum] = nil
    end
    local Window = MilitaryDrop.ZonesWindow
    if Window and Window.setStatus then
        Window.setStatus(text, args.ok == true)
    end
    local player = getSpecificPlayer(playerNum)
    if player then
        player:Say(text)
    end
end

Client.HANDLERS.ZoneListReply = ZonesAdmin.onListReply
Client.HANDLERS.ZoneReply = ZonesAdmin.onReply

-- ----------------------------------------------------------------------------
-- Commandes
-- ----------------------------------------------------------------------------

function ZonesAdmin.requestList(player)
    send(player, "ZoneList", {})
end

function ZonesAdmin.reload(player)
    send(player, "ZoneReload", {})
end

function ZonesAdmin.setEnabled(player, id, enabled)
    send(player, "ZoneSetEnabled", { id = id, enabled = enabled == true })
end

function ZonesAdmin.delete(player, id)
    send(player, "ZoneDelete", { id = id })
end

--- Coin 1 : nouveau tracé ; les contours s'affichent pour le suivre, et la
--- liste est demandée une fois (secteurs connus pour le coin 2).
function ZonesAdmin.onCorner1(player, x, y)
    local playerNum = player:getPlayerNum()
    ZonesAdmin.drafts[playerNum] = { x1 = x, y1 = y }
    ZonesAdmin.shown[playerNum] = true
    if not ZonesAdmin.list then
        ZonesAdmin.requestList(player)
    end
end

function ZonesAdmin.cancelDraft(player)
    ZonesAdmin.drafts[player:getPlayerNum()] = nil
end

--- Envoie ZoneAdd pour le tracé complet du joueur ; false si rien d'envoyable.
function ZonesAdmin.sendAdd(player, sector, name)
    local draft = ZonesAdmin.drafts[player:getPlayerNum()]
    if not draft or not draft.x2 then
        return false
    end
    sector, name = ZonesAdmin.cleanText(sector), ZonesAdmin.cleanText(name)
    if sector == "" or name == "" then
        return false
    end
    local x1, y1, x2, y2, w, h = ZonesAdmin.rect(draft.x1, draft.y1, draft.x2, draft.y2)
    if ZonesAdmin.tooBig(w, h) then
        return false
    end
    send(player, "ZoneAdd", { sector = sector, name = name, x1 = x1, y1 = y1, x2 = x2, y2 = y2 })
    return true
end

--- Boîte de saisie d'un texte court (nom de secteur ou de zone).
local function askText(player, title, onOk)
    local playerNum = player:getPlayerNum()
    local box = ISTextBox:new(0, 0, 300, 180, title, "", nil, function(_, button)
        if button.internal == "OK" then
            onOk(button.parent.entry:getText())
        end
    end, playerNum)
    box.maxChars = ZonesAdmin.MAX_TEXT
    box.noEmpty = true
    box:setValidateFunction(nil, function(_, text) return ZonesAdmin.validText(text) end)
    box:setValidateTooltipText(getText("IGUI_MilitaryDrop_ZoneBadChars"))
    box:initialise()
    box:addToUIManager()
    if JoypadState and JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, box)
    end
    return box
end

function ZonesAdmin.askName(player, sector)
    local clean = ZonesAdmin.cleanText(sector)
    return askText(player, getText("IGUI_MilitaryDrop_ZoneNameTitle", clean), function(name)
        ZonesAdmin.sendAdd(player, clean, name)
    end)
end

--- Coin 2 : fixe le rectangle, puis demande le nom (secteur connu) ou le
--- secteur puis le nom (sector nil : « Nouveau secteur… »).
function ZonesAdmin.onCorner2(player, x, y, sector)
    local draft = ZonesAdmin.drafts[player:getPlayerNum()]
    if not draft then
        return false
    end
    local _, _, _, _, w, h = ZonesAdmin.rect(draft.x1, draft.y1, x, y)
    if ZonesAdmin.tooBig(w, h) then
        player:Say(getText("IGUI_MilitaryDrop_ZoneTooBigTip", tostring(ZonesAdmin.MAX_SIDE)))
        return false
    end
    draft.x2, draft.y2 = x, y
    if sector then
        ZonesAdmin.askName(player, sector)
    else
        askText(player, getText("IGUI_MilitaryDrop_ZoneSectorTitle"), function(text)
            ZonesAdmin.askName(player, text)
        end)
    end
    return true
end

function ZonesAdmin.toggleOutlines(player)
    local playerNum = player:getPlayerNum()
    ZonesAdmin.shown[playerNum] = not ZonesAdmin.shown[playerNum]
    if ZonesAdmin.shown[playerNum] and not ZonesAdmin.list then
        ZonesAdmin.requestList(player)
    end
end

function ZonesAdmin.openList(player)
    local Window = MilitaryDrop.ZonesWindow
    if Window then
        Window.open(player)
    end
    ZonesAdmin.requestList(player)
end

--- Téléportation d'admin au centre de la zone : commande vanilla /teleportto
--- en MP (ISPvpZonePanel.lua:153), déplacement direct en solo
--- (ISAdminMessage.lua:81-85).
function ZonesAdmin.goTo(player, zone)
    local x = math.floor((zone.x1 + zone.x2) / 2)
    local y = math.floor((zone.y1 + zone.y2) / 2)
    if isClient() then
        SendCommandToServer("/teleportto " .. x .. "," .. y .. ",0")
    else
        player:teleportTo(x + 0.5, y + 0.5, 0)
    end
end

-- ----------------------------------------------------------------------------
-- Menu contextuel du monde
-- ----------------------------------------------------------------------------

local function tooltip(text)
    local tip = ISWorldObjectContextMenu.addToolTip()
    tip.description = text
    return tip
end

local function disable(option, text)
    option.notAvailable = true
    option.toolTip = tooltip(text)
end

--- Sous-menu « Military Drop (admin) » du menu, créé s'il manque (partagé
--- avec un autre outil d'admin du mod qui utiliserait le même libellé).
function ZonesAdmin.adminMenu(context)
    local label = getText("IGUI_MilitaryDrop_AdminMenu")
    local option = context:getOptionFromName(label)
    if option and option.subOption then
        local sub = context:getSubMenu(option.subOption)
        if sub then
            return sub
        end
    end
    option = context:addOption(label)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    return sub
end

function ZonesAdmin.fillMenu(player, context, square)
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local admin = ZonesAdmin.adminMenu(context)
    local parent = admin:addOption(getText("IGUI_MilitaryDrop_ZonesMenu"))
    local menu = ISContextMenu:getNew(admin)
    admin:addSubMenu(parent, menu)
    local playerNum = player:getPlayerNum()
    local groundLevel = z == 0

    local corner1 = menu:addOption(getText("IGUI_MilitaryDrop_ZoneCorner1", tostring(x), tostring(y)), player,
        ZonesAdmin.onCorner1, x, y)
    if not groundLevel then
        disable(corner1, getText("IGUI_MilitaryDrop_ZoneLevel0Tip"))
    end

    local draft = ZonesAdmin.drafts[playerNum]
    if draft then
        local _, _, _, _, w, h = ZonesAdmin.rect(draft.x1, draft.y1, x, y)
        local corner2 = menu:addOption(getText("IGUI_MilitaryDrop_ZoneCorner2", tostring(w), tostring(h)))
        if not groundLevel then
            disable(corner2, getText("IGUI_MilitaryDrop_ZoneLevel0Tip"))
        elseif ZonesAdmin.tooBig(w, h) then
            disable(corner2, getText("IGUI_MilitaryDrop_ZoneTooBigTip", tostring(ZonesAdmin.MAX_SIDE)))
        else
            local sectors = ISContextMenu:getNew(menu)
            menu:addSubMenu(corner2, sectors)
            local known = ZonesAdmin.list and ZonesAdmin.list.sectors or {}
            for i, sector in ipairs(known) do
                if i > ZonesAdmin.MAX_SECTORS_MENU then
                    break
                end
                sectors:addOption(sector, player, ZonesAdmin.onCorner2, x, y, sector)
            end
            sectors:addOption(getText("IGUI_MilitaryDrop_ZoneNewSector"), player, ZonesAdmin.onCorner2, x, y, nil)
        end
        menu:addOption(getText("IGUI_MilitaryDrop_ZoneCancelDraft"), player, ZonesAdmin.cancelDraft)
    end

    menu:addOption(getText("IGUI_MilitaryDrop_ZoneListOpen"), player, ZonesAdmin.openList)
    menu:addOption(getText("IGUI_MilitaryDrop_ZoneReloadFile"), player, ZonesAdmin.reload)
    local outlines = menu:addOption(getText("IGUI_MilitaryDrop_ZoneToggleOutlines"), player,
        ZonesAdmin.toggleOutlines)
    menu:setOptionChecked(outlines, ZonesAdmin.shown[playerNum] == true)
end

function ZonesAdmin.onFillWorldContextMenu(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if not ZonesAdmin.canUse(player) then
        return
    end
    -- Case cliquée : celle du premier objet, comme AdminContextMenu.doMenu.
    local object = worldObjects and worldObjects[1]
    local square = object and object:getSquare()
    if not square then
        return
    end
    if test then
        return ISWorldObjectContextMenu.setTest()
    end
    ZonesAdmin.fillMenu(player, context, square)
end

-- ----------------------------------------------------------------------------
-- Contours au sol (admin seulement, affichage activé)
-- ----------------------------------------------------------------------------

local function highlight(playerNum, x1, y1, x2, y2, color)
    addAreaHighlightForPlayer(playerNum, x1, y1, x2 + 1, y2 + 1, 0, color[1], color[2], color[3], color[4])
end

--- Case visée pendant le tracé : sous la souris, ou sous le joueur à la manette.
function ZonesAdmin.pointedSquare(player, playerNum)
    if player:getJoypadBind() ~= -1 then
        return math.floor(player:getX()), math.floor(player:getY())
    end
    local mx, my = getMouseX(), getMouseY()
    return math.floor(screenToIsoX(playerNum, mx, my, 0)), math.floor(screenToIsoY(playerNum, mx, my, 0))
end

function ZonesAdmin.drawPlayer(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player or not ZonesAdmin.canUse(player) then
        return
    end
    local colors = ZonesAdmin.COLORS
    local list = ZonesAdmin.list
    if list then
        for _, zone in ipairs(list.zones) do
            local color = colors.active
            if not zone.enabled then
                color = colors.disabled
            elseif not zone.active then
                color = colors.unusable
            end
            highlight(playerNum, zone.x1, zone.y1, zone.x2, zone.y2, color)
        end
    end
    local draft = ZonesAdmin.drafts[playerNum]
    if draft then
        local bx, by = draft.x2, draft.y2
        if not bx then
            bx, by = ZonesAdmin.pointedSquare(player, playerNum)
        end
        local x1, y1, x2, y2, w, h = ZonesAdmin.rect(draft.x1, draft.y1, bx, by)
        highlight(playerNum, x1, y1, x2, y2, ZonesAdmin.tooBig(w, h) and colors.tooBig or colors.draft)
    end
end

function ZonesAdmin.onPreUIDraw()
    for playerNum, shown in pairs(ZonesAdmin.shown) do
        if shown then
            ZonesAdmin.drawPlayer(playerNum)
        end
    end
end

-- Rechargement du fichier : les anciens abonnés sont retirés (Events.X.Add
-- ne dédoublonne pas).
if ZonesAdmin.registered then
    Events.OnFillWorldObjectContextMenu.Remove(ZonesAdmin.registered.menu)
    Events.OnPreUIDraw.Remove(ZonesAdmin.registered.draw)
end
ZonesAdmin.registered = {
    menu = function(...) return ZonesAdmin.onFillWorldContextMenu(...) end,
    draw = function() ZonesAdmin.onPreUIDraw() end,
}
Events.OnFillWorldObjectContextMenu.Add(ZonesAdmin.registered.menu)
Events.OnPreUIDraw.Add(ZonesAdmin.registered.draw)

return ZonesAdmin
