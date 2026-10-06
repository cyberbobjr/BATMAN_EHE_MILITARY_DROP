-- ============================================================================
-- Military Drop — outil d'admin des zones de largage (ZONE-03, côté client) :
-- logique sans interface (droits, protocole, réponses, tracé, formulaire)
--
-- Interface : MilitaryDrop_ZonesWindow.lua (bouton du panneau d'admin
-- vanilla, liste) et MilitaryDrop_ZoneEditor.lua (ajout, modification,
-- tracé au sol). Le client n'envoie que des coordonnées et des noms
-- (ZoneList, ZoneAdd, ZoneUpdate, ZoneSetEnabled, ZoneDelete, ZoneReload) ;
-- le serveur revérifie le droit (Requisition.canReload), valide, écrit
-- dropzones.txt et répond ZoneReply puis ZoneListReply (protocole : en-tête
-- de server/MilitaryDrop/MilitaryDrop_Zones.lua). Chaque commande porte un
-- numéro (requestId, croissant, commun à toutes les commandes du client)
-- renvoyé par le serveur dans ZoneReply et ZoneListReply : l'éditeur ne
-- traite que la réponse à son envoi ; le serveur traitant les commandes
-- d'un client dans l'ordre, une réponse de numéro supérieur prouve que les
-- précédentes ont été traitées (ou perdues). Les réponses ne sont
-- montrées que dans les fenêtres de l'admin (jamais par Say : une bulle
-- serait vue des joueurs proches).
-- Droit affiché ici : capacité ChangeAndReloadServerOptions sur un client MP,
-- mode debug en solo (le serveur, lui, accepte tout en solo).
--
-- Rectangle : les deux cases des coins en font partie (bornes incluses,
-- x1 ≤ x2, y1 ≤ y2) ; côté = x2 - x1 + 1, refusé ici au-delà de MAX_SIDE.
-- Tracé (ZonesAdmin.Trace) comme les zones d'animaux vanilla
-- (ISAddDesignationAnimalZoneUI.lua:47-74 : appui, glisser, relâcher) ou en
-- deux clics : un appui relâché sur la même case fixe le coin 1 et attend
-- un second clic. Une fois les deux coins fixés, le rectangle est figé
-- (souris et clics ignorés) jusqu'à validation, annulation ou « Retracer ».
--
-- Le tracé vise l'étage du joueur comme le vanilla (pickSquare :
-- screenToIsoX/Y à l'étage de sa case, ISAddDesignationAnimalZoneUI:
-- 296-301) : la case retenue est celle vue sous le curseur à cet étage, et
-- le contour du tracé y est dessiné ; la zone n'enregistre que x et y (le
-- largage tombe au niveau 0).
--
-- Contours au sol : addAreaHighlightForPlayer (LuaManager.java:9803), tracé
-- vanilla des zones (ISAddDesignationAnimalZoneUI:prerender:271). Un contour
-- est horodaté par UIManager.uiRenderTimeMS, en millisecondes, et le rendu
-- du monde jette ceux d'un autre horodatage (FBORenderAreaHighlights.java:
-- 61-66, 195) : les fenêtres le reposent dans leur prerender, donc seulement
-- chez l'admin et seulement fenêtre ouverte. Fin exclusive : cases x1..x2 →
-- x1, x2 + 1.
-- Surbrillance stable : deux images d'interface dans la même milliseconde
-- gardent le même horodatage (UIManager.java:283-285) ; le contour de la
-- première survit alors et celui de la seconde s'y ajoute, d'où un
-- remplissage deux ou trois fois plus opaque par moments (clignotement).
-- Comme le vanilla redessine ses zones une seule fois par rendu
-- (renderAnimalDesigationZones), un même contour n'est posé qu'une fois par
-- horodatage : ZonesAdmin.drawn retient les contours posés et n'est vidé, en
-- OnPreUIDraw (déclenché juste après la mise à jour de l'horodatage,
-- UIManager.java:283-303), que si l'horodatage a changé
-- (UIManager.getMillisSinceLastRender() non nul).
--
-- Textes de l'admin (secteur, nom) et du serveur : sans caractère de contrôle
-- ni < >, coupés à MAX_TEXT caractères entiers (MilitaryDrop.cutText).
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Client"

local Net = MilitaryDrop.Net
local Client = MilitaryDrop.Client

local ZonesAdmin = MilitaryDrop.ZonesAdmin or {}
MilitaryDrop.ZonesAdmin = ZonesAdmin

ZonesAdmin.MAX_SIDE = 300
ZonesAdmin.MAX_TEXT = 32
ZonesAdmin.MAX_WEIGHT = 100

-- Codes du contrat ; tout autre code reçoit le message générique (« other »).
ZonesAdmin.ERRORS = {
    denied = true, busy = true, invalid = true, badName = true, badSector = true, tooBig = true,
    tooSmall = true, offMap = true, overlapNonPvp = true, overlapSafehouse = true, tooMany = true,
    unknownZone = true, writeFailed = true, syntaxError = true,
}
ZonesAdmin.WARNINGS = {
    noRoad = true, risk = true, nonPvp = true, safehouse = true, offMap = true, mapNotLoaded = true,
}
ZonesAdmin.ACTIONS = { add = true, update = true, enable = true, delete = true, reload = true }

-- Couleurs des contours (r, g, b, opacité du remplissage).
ZonesAdmin.COLORS = {
    active = { 0.2, 0.9, 0.2, 0.15 },
    disabled = { 0.6, 0.6, 0.6, 0.12 },
    unusable = { 1.0, 0.6, 0.1, 0.15 },
    previous = { 0.6, 0.6, 0.6, 0.1 },
    draft = { 0.2, 0.5, 1.0, 0.25 },
    tooBig = { 1.0, 0.1, 0.1, 0.3 },
    cursor = { 0.2, 0.5, 1.0, 1.0 },
}

-- Dernière ZoneListReply : { zones, sectors, map, mapLoaded, placement,
-- problems } nettoyée (ZonesAdmin.normalizeList), ou nil.
ZonesAdmin.list = ZonesAdmin.list
-- Joueur local qui a envoyé la dernière commande.
ZonesAdmin.lastPlayerNum = ZonesAdmin.lastPlayerNum or 0
-- Numéro de la prochaine commande (1..MAX_REQUEST_ID, borne du serveur).
ZonesAdmin.MAX_REQUEST_ID = 2147483647
ZonesAdmin.nextRequestId = ZonesAdmin.nextRequestId or 1

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

--- Vrai si le texte saisi est accepté tel quel : ni caractère de contrôle ni
--- < >, non vide une fois les espaces de bord retirés, MAX_TEXT au plus.
function ZonesAdmin.validText(text)
    if type(text) ~= "string" or string.find(text, "[%c<>]") then
        return false
    end
    local trimmed = ZonesAdmin.cleanText(text, #text + 1)
    return trimmed ~= "" and MilitaryDrop.cutText(trimmed, ZonesAdmin.MAX_TEXT) == trimmed
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

--- Droit de la téléportation vanilla (/teleportto, TeleportToCommand.java:24 ;
--- même test que ISPvpZonePanel:render:116).
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

--- Joueur local vivant de ce numéro (getSpecificPlayer : le personnage
--- courant, jamais un IsoPlayer mort gardé par une fenêtre), ou nil.
function ZonesAdmin.livePlayer(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then
        return nil
    end
    return player
end

--- Étage du joueur (celui de sa case, sinon de sa position).
function ZonesAdmin.levelOf(player)
    local square = player and player:getCurrentSquare()
    if square then
        return square:getZ()
    end
    return player and math.floor(player:getZ()) or 0
end

--- Envoi d'une commande numérotée ; renvoie son requestId.
local function send(player, command, args)
    local requestId = ZonesAdmin.nextRequestId
    ZonesAdmin.nextRequestId = requestId >= ZonesAdmin.MAX_REQUEST_ID and 1 or requestId + 1
    args.requestId = requestId
    ZonesAdmin.lastPlayerNum = player:getPlayerNum()
    Net.toServer(player, command, args)
    return requestId
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

--- Zone de la dernière liste par son id, ou nil.
function ZonesAdmin.findZone(id)
    for _, zone in ipairs(ZonesAdmin.list and ZonesAdmin.list.zones or {}) do
        if zone.id == id then
            return zone
        end
    end
    return nil
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

--- ZoneListReply : d'abord à l'éditeur qui attend une réponse perdue
--- (ZoneEditor.onListReply), puis à la liste.
function ZonesAdmin.onListReply(args)
    ZonesAdmin.list = ZonesAdmin.normalizeList(args)
    local Editor = MilitaryDrop.ZoneEditor
    if Editor and Editor.onListReply then
        Editor.onListReply(args.requestId)
    end
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

--- ZoneReply : d'abord à l'éditeur ouvert s'il en attendait ce numéro
--- (ajout, modification), sinon à la liste. La liste suit (ZoneListReply),
--- sauf après un refus « denied » ou « busy ».
function ZonesAdmin.onReply(args)
    local text = ZonesAdmin.replyText(args)
    local ok = args.ok == true
    local Editor = MilitaryDrop.ZoneEditor
    if Editor and Editor.onReply and Editor.onReply(args, text) then
        return
    end
    local Window = MilitaryDrop.ZonesWindow
    if Window and Window.setStatus then
        Window.setStatus(text, ok)
    end
end

Client.HANDLERS.ZoneListReply = ZonesAdmin.onListReply
Client.HANDLERS.ZoneReply = ZonesAdmin.onReply

-- ----------------------------------------------------------------------------
-- Commandes
-- ----------------------------------------------------------------------------

-- Chaque commande renvoie son requestId.
function ZonesAdmin.requestList(player)
    return send(player, "ZoneList", {})
end

function ZonesAdmin.reload(player)
    return send(player, "ZoneReload", {})
end

function ZonesAdmin.setEnabled(player, id, enabled)
    return send(player, "ZoneSetEnabled", { id = id, enabled = enabled == true })
end

function ZonesAdmin.delete(player, id)
    return send(player, "ZoneDelete", { id = id })
end

function ZonesAdmin.add(player, args)
    return send(player, "ZoneAdd", args)
end

function ZonesAdmin.update(player, args)
    return send(player, "ZoneUpdate", args)
end

--- Téléportation d'admin au centre de la zone : commande vanilla /teleportto
--- en MP (ISPvpZonePanel.lua:153), déplacement direct en solo
--- (ISAdminMessage.lua:81-85). Jamais pour un personnage mort (un IsoPlayer
--- mort resté dans une fenêtre) : faux, rien n'est fait.
function ZonesAdmin.goTo(player, zone)
    if not player or player:isDead() then
        return false
    end
    local x = math.floor((zone.x1 + zone.x2) / 2)
    local y = math.floor((zone.y1 + zone.y2) / 2)
    if isClient() then
        SendCommandToServer("/teleportto " .. x .. "," .. y .. ",0")
    else
        player:teleportTo(x + 0.5, y + 0.5, 0)
    end
    return true
end

-- ----------------------------------------------------------------------------
-- Formulaire (éditeur) : contrôle local avant envoi
-- ----------------------------------------------------------------------------

--- Poids saisi : entier 1..MAX_WEIGHT, 1 si vide ; nil s'il est refusé.
function ZonesAdmin.parseWeight(text)
    text = ZonesAdmin.cleanText(text, 8)
    if text == "" then
        return 1
    end
    local n = tonumber(text)
    if not n or n ~= math.floor(n) or n < 1 or n > ZonesAdmin.MAX_WEIGHT then
        return nil
    end
    return n
end

--- Valeurs d'un formulaire { name, sector, weight (texte), rect = { x1, y1,
--- x2, y2 } } contrôlées : valeurs propres, ou nil et la clé du motif.
function ZonesAdmin.checkForm(form)
    local rect = form.rect
    if not rect then
        return nil, "IGUI_MilitaryDrop_ZoneNoRect"
    end
    local x1, y1, x2, y2, w, h = ZonesAdmin.rect(rect.x1, rect.y1, rect.x2, rect.y2)
    if ZonesAdmin.tooBig(w, h) then
        return nil, "IGUI_MilitaryDrop_ZoneTooBigTip"
    end
    if not ZonesAdmin.validText(form.name) then
        return nil, "IGUI_MilitaryDrop_ZoneErr_badName"
    end
    if not ZonesAdmin.validText(form.sector) then
        return nil, "IGUI_MilitaryDrop_ZoneErr_badSector"
    end
    local weight = ZonesAdmin.parseWeight(form.weight)
    if not weight then
        return nil, "IGUI_MilitaryDrop_ZoneBadWeight"
    end
    return { name = ZonesAdmin.cleanText(form.name), sector = ZonesAdmin.cleanText(form.sector), weight = weight,
        x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

--- Arguments de ZoneAdd pour un formulaire, ou nil et la clé du motif.
function ZonesAdmin.addArgs(form)
    return ZonesAdmin.checkForm(form)
end

--- Arguments de ZoneUpdate : id et champs modifiés seulement (rectangle
--- entier s'il a changé), ou nil et la clé du motif (« rien à enregistrer »
--- compris).
function ZonesAdmin.updateArgs(zone, form)
    local values, why = ZonesAdmin.checkForm(form)
    if not values then
        return nil, why
    end
    local args, changed = { id = zone.id }, false
    for _, key in ipairs({ "name", "sector", "weight" }) do
        if values[key] ~= zone[key] then
            args[key] = values[key]
            changed = true
        end
    end
    if values.x1 ~= zone.x1 or values.y1 ~= zone.y1 or values.x2 ~= zone.x2 or values.y2 ~= zone.y2 then
        args.x1, args.y1, args.x2, args.y2 = values.x1, values.y1, values.x2, values.y2
        changed = true
    end
    if not changed then
        return nil, "IGUI_MilitaryDrop_ZoneNoChange"
    end
    return args
end

-- ----------------------------------------------------------------------------
-- Tracé du rectangle (souris : glisser ou deux clics ; manette : deux A)
-- ----------------------------------------------------------------------------

local Trace = {}
Trace.__index = Trace
ZonesAdmin.Trace = Trace

--- États : "first" (coin 1 attendu), "drag" (bouton tenu depuis le coin 1),
--- "second" (coin 1 fixé, second clic attendu), "done" (figé), "cancelled".
function Trace.new()
    return setmetatable({ state = "first" }, Trace)
end

--- Tracé en cours (souris ou manette encore attendues).
function Trace:active()
    return self.state == "first" or self.state == "drag" or self.state == "second"
end

--- Case visée (souris ou curseur de manette) : survol avant le coin 1, coin
--- opposé ensuite ; ignorée une fois le rectangle figé.
function Trace:hover(x, y)
    if self.state == "first" then
        self.hx, self.hy = x, y
    elseif self.state == "drag" or self.state == "second" then
        self.x2, self.y2 = x, y
    end
end

--- Appui : coin 1, ou coin 2 au second clic. Vrai si l'appui a servi.
function Trace:press(x, y)
    if self.state == "first" then
        self.x1, self.y1, self.x2, self.y2 = x, y, x, y
        self.state = "drag"
        return true
    elseif self.state == "second" then
        self.x2, self.y2 = x, y
        self.state = "done"
        return true
    end
    return false
end

--- Relâchement : fin du glisser (rectangle figé), ou attente du second clic
--- si le bouton est relâché sur la case du coin 1.
function Trace:release(x, y)
    if self.state ~= "drag" then
        return false
    end
    self.x2, self.y2 = x, y
    if x == self.x1 and y == self.y1 then
        self.state = "second"
    else
        self.state = "done"
    end
    return true
end

function Trace:cancel()
    if self:active() then
        self.state = "cancelled"
        return true
    end
    return false
end

--- Rectangle courant { x1, y1, x2, y2, width, height } normalisé, ou nil.
function Trace:rect()
    if not self.x1 or not self.x2 then
        return nil
    end
    local x1, y1, x2, y2, w, h = ZonesAdmin.rect(self.x1, self.y1, self.x2, self.y2)
    return { x1 = x1, y1 = y1, x2 = x2, y2 = y2, width = w, height = h }
end

-- ----------------------------------------------------------------------------
-- Contours au sol
-- ----------------------------------------------------------------------------

-- Contours déjà posés pour l'horodatage d'interface courant (clé → true).
ZonesAdmin.drawn = ZonesAdmin.drawn or {}

--- Début d'une image d'interface (OnPreUIDraw) : nouvel horodatage, les
--- contours de l'image précédente seront jetés par le rendu du monde ; même
--- horodatage (intervalle nul), ils restent dessinés et ne sont pas reposés.
function ZonesAdmin.onPreUIDraw()
    if UIManager.getMillisSinceLastRender() ~= 0 then
        ZonesAdmin.drawn = {}
    end
end

--- Contour des cases x1..y2 incluses, à l'étage z (0 par défaut), pour ce
--- joueur seulement ; une seule fois par horodatage d'interface. Vrai s'il
--- vient d'être posé.
function ZonesAdmin.highlight(playerNum, rect, color, z)
    local x1, y1 = math.floor(rect.x1), math.floor(rect.y1)
    local x2, y2 = math.floor(rect.x2) + 1, math.floor(rect.y2) + 1
    z = math.floor(z or 0)
    local key = playerNum .. ":" .. x1 .. "," .. y1 .. "," .. x2 .. "," .. y2 .. "," .. z .. ":"
        .. color[1] .. "," .. color[2] .. "," .. color[3] .. "," .. color[4]
    if ZonesAdmin.drawn[key] then
        return false
    end
    ZonesAdmin.drawn[key] = true
    addAreaHighlightForPlayer(playerNum, x1, y1, x2, y2, z, color[1], color[2], color[3], color[4])
    return true
end

-- Rechargement de ce fichier : un seul abonné (Events.X.Add ne dédoublonne pas).
if ZonesAdmin.preUIDrawHandler then
    Events.OnPreUIDraw.Remove(ZonesAdmin.preUIDrawHandler)
end
ZonesAdmin.preUIDrawHandler = function() ZonesAdmin.onPreUIDraw() end
Events.OnPreUIDraw.Add(ZonesAdmin.preUIDrawHandler)

--- Couleur d'une zone de la liste selon son état.
function ZonesAdmin.zoneColor(zone)
    if not zone.enabled then
        return ZonesAdmin.COLORS.disabled
    elseif not zone.active then
        return ZonesAdmin.COLORS.unusable
    end
    return ZonesAdmin.COLORS.active
end

--- Case de l'étage z (0 par défaut) vue sous la souris, comme
--- ISAddDesignationAnimalZoneUI:pickSquare:296-301.
function ZonesAdmin.squareAtMouse(playerNum, z)
    local mx, my = getMouseX(), getMouseY()
    z = z or 0
    return math.floor(screenToIsoX(playerNum, mx, my, z)), math.floor(screenToIsoY(playerNum, mx, my, z))
end

return ZonesAdmin
