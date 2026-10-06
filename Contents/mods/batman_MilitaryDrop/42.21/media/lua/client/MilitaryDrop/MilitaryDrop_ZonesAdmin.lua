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
-- Surbrillance au sol (ZonesAdmin.Ground) : le pourtour seulement de chaque
-- rectangle, par la surbrillance persistante de l'objet de sol de ses cases :
-- IsoObject:setHighlightColor(joueur, r, g, b, a) puis
-- setHighlighted(joueur, true, false) (IsoObject.java:4689-4699, 4746-4750).
-- L'objet est inscrit dans FBORenderObjectHighlight, que le moteur redessine
-- à chaque rendu du monde (FBORenderCell.java:1041 → FBORenderObjectHighlight.
-- render) tant que la surbrillance n'est pas retirée ; seules les
-- surbrillances « une image » sont effacées après le rendu
-- (clearHighlightOnceFlag, IngameState.java:1344). Rien n'est donc reposé à
-- chaque image depuis Lua. Le surlignage de zone addAreaHighlight*, reposé
-- à chaque image d'interface, clignotait en jeu (même dédoublonné par
-- horodatage) : il n'est plus utilisé. Variante par joueur : seul l'écran de
-- l'admin la voit (écran partagé compris) ; c'est un état local de l'objet,
-- jamais envoyé au serveur. L'opacité a est la part de la couleur mélangée à
-- celle du sol éclairé (IsoObject.prepareToRender, :3702-3713) : visible de
-- nuit aussi.
-- Cases chargées seulement (getGridSquare nil sinon), bornées à la carte de
-- chunks du joueur (IsoChunkMap:getWorldXMinTiles... ; 19 chunks de large au
-- plus, IsoChunkMap.java:139 : 4 × 152 = 608 cases au plus par rectangle). Un balayage (OnTickEvenPaused : aussi en
-- pause solo) repasse le pourtour au plus toutes les SWEEP_MS ms, BUDGET cases
-- au plus par mise à jour pour la liste (200 zones) : il surligne les cases
-- des chunks chargés depuis, reprend une surbrillance que le jeu a effacée,
-- et retire celles qui ne sont plus voulues (zone retirée, modifiée,
-- recolorée, sortie de la carte chargée).
-- Jamais d'écrasement : une case déjà surlignée (jeu, autre mod) n'est pas
-- prise ; une case prise n'est effacée que si elle porte encore notre
-- couleur (sinon elle est laissée à qui l'a reprise), puis sa couleur
-- d'avant lui est rendue. Si l'objet a changé (sol remplacé, chunk déchargé
-- puis rechargé), l'ancien n'est touché que s'il est encore sur sa case.
-- Deux couches : « editor » (tracé et rectangle de l'éditeur, prioritaire,
-- refaite en entier à chaque changement) et « list » (zones de la liste,
-- case « Surbrillance » du panneau).
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
    noGround = true, nonPvp = true, safehouse = true, offMap = true, mapNotLoaded = true,
}
ZonesAdmin.ACTIONS = { add = true, update = true, enable = true, delete = true, reload = true }

-- Couleurs de la surbrillance au sol (r, g, b, part de la couleur mélangée au
-- sol). Tables constantes : la surbrillance les compare par référence.
ZonesAdmin.COLORS = {
    active = { 0.2, 0.9, 0.2, 0.5 },
    disabled = { 0.6, 0.6, 0.6, 0.45 },
    unusable = { 1.0, 0.6, 0.1, 0.5 },
    previous = { 0.6, 0.6, 0.6, 0.45 },
    draft = { 0.2, 0.5, 1.0, 0.7 },
    tooBig = { 1.0, 0.1, 0.1, 0.8 },
    cursor = { 0.2, 0.5, 1.0, 0.8 },
}
-- Zone sélectionnée dans la liste : même teinte, plus marquée.
ZonesAdmin.SELECTED_COLORS = {
    active = { 0.2, 0.9, 0.2, 0.85 },
    disabled = { 0.6, 0.6, 0.6, 0.8 },
    unusable = { 1.0, 0.6, 0.1, 0.85 },
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
-- Surbrillance au sol (pourtour des rectangles, voir l'en-tête)
-- ----------------------------------------------------------------------------

local Ground = ZonesAdmin.Ground or {}
ZonesAdmin.Ground = Ground

-- Cases visitées au plus par mise à jour pour la couche « list ».
Ground.BUDGET = 1000
-- Délai minimal entre deux balayages d'une couche (chunks chargés depuis,
-- surbrillance effacée par le jeu).
Ground.SWEEP_MS = 1000
-- Ordre de priorité des couches : la première qui veut une case la colore.
Ground.ORDER = { "editor", "list" }
-- Écart toléré sur une composante de couleur relue (ColorInfo en float).
local COLOR_EPSILON = 0.002

-- État gardé au rechargement de ce fichier, pour pouvoir tout effacer :
-- layers[nom] = { shapes, sig, sync, desired, gen, sweep, sweptMs } ;
-- desired[clé] = { x, y, z, color, gen } ; owned[clé] = { obj, x, y, z,
-- color, prev } (case surlignée par nous, couleur d'avant).
Ground.layers = Ground.layers or {}
Ground.owned = Ground.owned or {}
Ground.ownedCount = Ground.ownedCount or 0
Ground.playerNum = Ground.playerNum or 0

--- Clé numérique d'une case (0 ≤ x < 2^20, 0 ≤ y < 2^20, z de -64 à 63 :
--- au plus 2^47, exacte en double).
local function keyOf(x, y, z)
    return (y * 1048576 + x) * 128 + z + 64
end

local function sameColor(info, color)
    return math.abs(info:getR() - color[1]) < COLOR_EPSILON and math.abs(info:getG() - color[2]) < COLOR_EPSILON
        and math.abs(info:getB() - color[3]) < COLOR_EPSILON and math.abs(info:getA() - color[4]) < COLOR_EPSILON
end

--- Objet de sol de la case chargée (x, y, z), ou nil.
function Ground.floorAt(x, y, z)
    local cell = getCell()
    local square = cell and cell:getGridSquare(x, y, z)
    return square and square:getFloor() or nil
end

--- Bornes incluses { x1, y1, x2, y2 } de la carte de chunks du joueur, ou nil.
function Ground.bounds(playerNum)
    local cell = getCell()
    local map = cell and cell:getChunkMap(playerNum)
    if not map then
        return nil
    end
    return { map:getWorldXMinTiles(), map:getWorldYMinTiles(), map:getWorldXMaxTiles() - 1,
        map:getWorldYMaxTiles() - 1 }
end

--- Appelle fn(x, y, z) pour chaque case du pourtour de shape (cases x1..x2,
--- y1..y2 incluses) comprise dans bounds, chacune une fois ; renvoie le
--- nombre de cases visitées.
function Ground.eachPerimeterSquare(shape, bounds, fn)
    local x1, y1, x2, y2, z = shape.x1, shape.y1, shape.x2, shape.y2, shape.z
    local count = 0
    local fromX, toX = math.max(x1, bounds[1]), math.min(x2, bounds[3])
    for _, y in ipairs(y1 == y2 and { y1 } or { y1, y2 }) do
        if y >= bounds[2] and y <= bounds[4] then
            for x = fromX, toX do
                fn(x, y, z)
                count = count + 1
            end
        end
    end
    local fromY, toY = math.max(y1 + 1, bounds[2]), math.min(y2 - 1, bounds[4])
    for _, x in ipairs(x1 == x2 and { x1 } or { x1, x2 }) do
        if x >= bounds[1] and x <= bounds[3] then
            for y = fromY, toY do
                fn(x, y, z)
                count = count + 1
            end
        end
    end
    return count
end

--- Case voulue par la couche la plus prioritaire, ou nil.
local function wanted(key)
    for _, name in ipairs(Ground.ORDER) do
        local layer = Ground.layers[name]
        local want = layer and layer.desired[key]
        if want then
            return want
        end
    end
    return nil
end

local function paint(obj, playerNum, color)
    obj:setHighlightColor(playerNum, color[1], color[2], color[3], color[4])
    obj:setHighlighted(playerNum, true, false)
end

--- Retire notre surbrillance d'une case possédée, seulement si l'objet est
--- encore sur sa case et porte encore notre couleur ; rend sa couleur d'avant.
local function release(key, rec)
    Ground.owned[key] = nil
    Ground.ownedCount = Ground.ownedCount - 1
    local obj = rec.obj
    local p = Ground.playerNum
    if obj:getObjectIndex() == -1 then
        return
    end
    local square = obj:getSquare()
    if not square or square:getX() ~= rec.x or square:getY() ~= rec.y or square:getZ() ~= rec.z then
        return
    end
    if not sameColor(obj:getHighlightColor(p), rec.color) then
        return
    end
    if obj:isHighlighted(p) then
        obj:setHighlighted(p, false, false)
    end
    local prev = rec.prev
    obj:setHighlightColor(p, prev[1], prev[2], prev[3], prev[4])
end

--- Met la case au goût des couches : la surligne (sans voler celle d'un
--- autre), change sa couleur, la reprend si le jeu l'a effacée, ou la libère.
function Ground.applyKey(key)
    local want = wanted(key)
    local rec = Ground.owned[key]
    local where = want or rec
    if not where then
        return
    end
    local floor = Ground.floorAt(where.x, where.y, where.z)
    if rec and (not want or rec.obj ~= floor) then
        release(key, rec)
        rec = nil
    end
    if not want or not floor then
        return
    end
    local p = Ground.playerNum
    local prev
    if rec then
        if floor:isHighlighted(p) then
            if sameColor(floor:getHighlightColor(p), rec.color) then
                if rec.color ~= want.color then
                    paint(floor, p, want.color)
                    rec.color = want.color
                end
            else
                -- Reprise par le jeu ou un autre mod : elle lui est laissée.
                Ground.owned[key] = nil
                Ground.ownedCount = Ground.ownedCount - 1
            end
            return
        end
        -- Effacée par le jeu (surbrillance « une image » d'un curseur...) :
        -- reprise, avec la couleur d'avant notre première prise.
        prev = rec.prev
        Ground.owned[key] = nil
        Ground.ownedCount = Ground.ownedCount - 1
    elseif floor:isHighlighted(p) then
        return
    end
    if not prev then
        local info = floor:getHighlightColor(p)
        prev = { info:getR(), info:getG(), info:getB(), info:getA() }
    end
    paint(floor, p, want.color)
    Ground.owned[key] = { obj = floor, x = where.x, y = where.y, z = where.z, color = want.color, prev = prev }
    Ground.ownedCount = Ground.ownedCount + 1
end

local function startSweep(layer)
    layer.gen = layer.gen + 1
    layer.sweep = { gen = layer.gen, index = 1, bounds = Ground.bounds(Ground.playerNum) }
end

--- Fin d'un balayage : les cases qu'il n'a pas revues sont libérées.
local function finishSweep(layer, nowMs)
    local gen = layer.sweep.gen
    layer.sweep = nil
    layer.sweptMs = nowMs
    local stale = {}
    for key, want in pairs(layer.desired) do
        if want.gen ~= gen then
            stale[#stale + 1] = key
        end
    end
    for _, key in ipairs(stale) do
        layer.desired[key] = nil
        Ground.applyKey(key)
    end
end

--- Poursuit le balayage (budget nil : en entier) ; renvoie les cases visitées.
local function stepSweep(layer, budget, nowMs)
    local sweep = layer.sweep
    local visited = 0
    local function mark(x, y, z, color)
        local key = keyOf(x, y, z)
        local want = layer.desired[key]
        if want and want.gen == sweep.gen then
            return -- déjà prise par une forme plus prioritaire de ce balayage
        end
        if want then
            want.color, want.gen = color, sweep.gen
        else
            layer.desired[key] = { x = x, y = y, z = z, color = color, gen = sweep.gen }
        end
        Ground.applyKey(key)
    end
    while sweep.index <= #layer.shapes and (not budget or visited < budget) do
        local shape = layer.shapes[sweep.index]
        sweep.index = sweep.index + 1
        if sweep.bounds then
            visited = visited + Ground.eachPerimeterSquare(shape, sweep.bounds,
                function(x, y, z) mark(x, y, z, shape.color) end)
        end
    end
    if sweep.index > #layer.shapes then
        finishSweep(layer, nowMs)
    end
    return visited
end

local function signature(shapes)
    local parts = {}
    for i, shape in ipairs(shapes) do
        local c = shape.color
        parts[i] = shape.x1 .. "," .. shape.y1 .. "," .. shape.x2 .. "," .. shape.y2 .. "," .. shape.z .. ":"
            .. c[1] .. "," .. c[2] .. "," .. c[3] .. "," .. c[4]
    end
    return table.concat(parts, ";")
end

--- Formes de la couche name pour ce joueur : { x1, y1, x2, y2, z, color },
--- la plus prioritaire d'abord (coordonnées entières, x1 ≤ x2, y1 ≤ y2).
--- sync : couche refaite en entier à chaque changement (éditeur, quelques
--- rectangles), sinon par BUDGET cases par mise à jour. Sans changement,
--- rien n'est refait. Vrai si les formes ont changé.
function Ground.setShapes(name, playerNum, shapes, sync)
    if playerNum ~= Ground.playerNum then
        Ground.clearAll()
        Ground.playerNum = playerNum
    end
    local sig = signature(shapes)
    local layer = Ground.layers[name]
    if layer and layer.sig == sig then
        return false
    end
    if not layer then
        layer = { desired = {}, gen = 0 }
        Ground.layers[name] = layer
    end
    layer.shapes, layer.sig, layer.sync = shapes, sig, sync == true
    startSweep(layer)
    stepSweep(layer, not layer.sync and Ground.BUDGET or nil, getTimestampMs())
    return true
end

--- Retire la couche name : ses cases sont libérées (ou prises par l'autre).
function Ground.remove(name)
    local layer = Ground.layers[name]
    if not layer then
        return
    end
    Ground.layers[name] = nil
    local keys = {}
    for key in pairs(layer.desired) do
        keys[#keys + 1] = key
    end
    for _, key in ipairs(keys) do
        Ground.applyKey(key)
    end
end

--- Retire toutes les couches et toutes nos surbrillances.
function Ground.clearAll()
    Ground.layers = {}
    local keys = {}
    for key in pairs(Ground.owned) do
        keys[#keys + 1] = key
    end
    for _, key in ipairs(keys) do
        release(key, Ground.owned[key])
    end
end

--- Vrai si au moins une couche est posée.
function Ground.active()
    for _, name in ipairs(Ground.ORDER) do
        if Ground.layers[name] then
            return true
        end
    end
    return false
end

--- Mise à jour (OnTickEvenPaused) : balayages en cours ou dus.
function Ground.update()
    if not Ground.active() or not getCell() then
        return
    end
    local nowMs = getTimestampMs()
    for _, name in ipairs(Ground.ORDER) do
        local layer = Ground.layers[name]
        if layer then
            if not layer.sweep and nowMs - (layer.sweptMs or 0) >= Ground.SWEEP_MS then
                startSweep(layer)
            end
            if layer.sweep then
                stepSweep(layer, not layer.sync and Ground.BUDGET or nil, nowMs)
            end
        end
    end
end

-- Rechargement de ce fichier : un seul abonné (Events.X.Add ne dédoublonne pas).
if Ground.tickHandler then
    Events.OnTickEvenPaused.Remove(Ground.tickHandler)
end
Ground.tickHandler = function() Ground.update() end
Events.OnTickEvenPaused.Add(Ground.tickHandler)

--- Couleur d'une zone de la liste selon son état (plus marquée si elle est
--- sélectionnée).
function ZonesAdmin.zoneColor(zone, selected)
    local colors = selected and ZonesAdmin.SELECTED_COLORS or ZonesAdmin.COLORS
    if not zone.enabled then
        return colors.disabled
    elseif not zone.active then
        return colors.unusable
    end
    return colors.active
end

--- Case de l'étage z (0 par défaut) vue sous la souris, comme
--- ISAddDesignationAnimalZoneUI:pickSquare:296-301.
function ZonesAdmin.squareAtMouse(playerNum, z)
    local mx, my = getMouseX(), getMouseY()
    z = z or 0
    return math.floor(screenToIsoX(playerNum, mx, my, z)), math.floor(screenToIsoY(playerNum, mx, my, z))
end

return ZonesAdmin
