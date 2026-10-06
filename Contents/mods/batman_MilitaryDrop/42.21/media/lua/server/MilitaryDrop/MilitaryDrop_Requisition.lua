-- ============================================================================
-- Military Drop — formulaire de réquisition, côté serveur (v1.4, serveur MP ou solo)
--
-- Un appel accepté (Server.evaluate : radio, canal, code, ligne, délai) qui
-- n'est pas un largage admin n'envoie pas l'hélicoptère quand l'option
-- RequisitionForm est vraie : le serveur ouvre une autorisation en attente
-- pour ce joueur (AUTH_MS, temps réel) et lui répond Result { status = "form" }
-- avec son budget et les lots permis. Le délai global n'est pas consommé.
--
-- Le client renvoie sa commande (RequisitionOrder) ou l'annule
-- (RequisitionCancel). Le serveur revérifie tout : autorisation de ce joueur,
-- même requestId, non expirée ; radio à portée, allumée, sur le canal (sans
-- redemander le code) ; ligne non coupée ; délai global toujours libre ; lots
-- permis au palier, non vides, quantités entières positives, somme des coûts
-- dans le budget ; au moins un lot, ou le leurre seul. Puis le vol part par le
-- chemin d'un appel accepté (Server.launchDrop). Points non dépensés : perdus
-- (REQ-07).
--
-- Largage admin (« Largage forcé », Server.canForce) : avec RequisitionForm,
-- il ouvre aussi la feuille, marquée « forced » : tous les paliers, budget
-- d'une note de Trust.MAX, leurre compris s'il est actif (lots désactivés ou
-- vides exclus comme pour tous). Sans radio, code, ligne ni délai, comme le
-- largage admin direct. À la commande, le droit est revérifié
-- (Server.canForce) au lieu de la radio ; le vol part en largage forcé
-- (délai global non consommé, hors suivi de confiance, coordonnées privées).
-- Point, secteurs du leurre et secteur du largage : comme pour un joueur
-- (décision de l'utilisateur du 2026-10-06, qui remplace l'analyse §2.1).
--
-- Budget (REQ-03) : floor((4 + note × 0,16) × RequisitionBudget / 100).
-- Paliers : groupe 1 toujours, 2 dès RequisitionTier2, 3 dès RequisitionTier3.
-- Coût effectif : max(1, arrondi(coût × RequisitionCostMultiplier / 100)),
-- leurre compris (DecoyCost, option du module leurre).
--
-- Secret : la commande est rangée dans l'état privé du largage
-- (drops[dropId].order, ou drops[dropId].decoy pour un leurre), jamais dans
-- la ModData publique ni dans un message à tous. Les autorisations en attente
-- restent en mémoire du serveur (un redémarrage les oublie).
--
-- Point de largage : choisi (Server.chooseDropPoint) avant de consommer
-- l'autorisation. Aucun point (secteur du leurre hors carte, aucune case
-- d'atterrissage) : réponse « noSite » (avec le secteur du leurre, et
-- single = true si l'offre n'a qu'un secteur de zones), autorisation gardée ;
-- le client rouvre la feuille pour un autre secteur (ou une commande de lots).
-- Zones de largage (idée 11) : en mode zones effectif, les secteurs du
-- leurre sont les noms des secteurs actifs (MilitaryDrop.Zones.decoySectors,
-- decoy.zones = true) ; la commande renvoie un nom, revérifié contre l'offre
-- recalculée, et le leurre tombe dans une zone de ce secteur. La feuille
-- admin (largage forcé, APPEL-05) suit les mêmes règles (secteurs nommés,
-- distances depuis l'admin).
--
-- Secteur choisi par le joueur (ZONE-09, DropZoneChoice 3, décision de
-- l'utilisateur du 2026-10-06) : en mode zones effectif pour ce demandeur
-- (mode 2, ou mode 3 avec des zones à portée ; villes vanilla du repli
-- comprises), la réponse « form » porte aussi drop = { zones = true,
-- sectors = { noms } } (Zones.playerSectors : secteurs actifs ayant une zone
-- à DropZoneMinDistance au moins, sinon le plus proche ; le leurre reçoit la
-- même liste, le formulaire n'ayant qu'un sélecteur) et la commande de lots,
-- sector = "<nom>". Le serveur le revérifie contre
-- l'offre recalculée (absent, inconnu, désactivé, hors portée, ou donné
-- alors que l'offre n'en propose plus : « orderInvalid ») ; la zone est tirée
-- au poids dans ce secteur (Zones.choosePoint), aucune case : « noSite »
-- avec le secteur, et single = true s'il est seul. Un leurre ne porte pas
-- sector (son secteur est decoy). Choix 1 et 2 : ni drop ni sector (une
-- commande qui en porte un est refusée), feuille admin comprise.
--
-- Candidats des lots : calculés d'un seul passage (Lots.warm) au démarrage
-- du serveur (OnServerStarted) ou de la partie solo (OnGameStart), après la
-- fusion des distributions et les retouches des mods à OnInitGlobalModData
-- (options sandbox lues : pz-knowledge loot-distributions.md) ; sinon au
-- premier formulaire.
--
-- Langue : le nom des caisses de réquisition (« Caisse de réquisition :
-- <lot> ») est écrit par le serveur, donc dans sa langue en MP dédié (repli
-- anglais hors EN et FR), comme les documents militaires : setName est
-- sauvegardé et transmis tel quel. Le libellé du lot reste lisible ; la
-- description (Tooltip) et le nom du script sont traduits par chaque client.
-- Un lot ajouté par l'admin (fichier des lots) n'a pas de clé de traduction :
-- son nom de caisse prend son texte dans la langue du serveur (Lots.text).
--
-- Fichier des lots (MilitaryDrop_LotsFile.lua) : lu au démarrage avant le
-- précalcul, ou au premier usage. Rechargement par l'admin sans redémarrer :
-- MilitaryDrop.Requisition.reload() (console de débogage en solo), ou la
-- commande ReloadLots d'un vrai admin en MP (Requisition.canReload), une fois
-- toutes les RELOAD_INTERVAL_MS au plus pour tout le serveur ; l'admin reçoit
-- le résumé (ReloadLotsReply, affiché dans sa console) :
--   sendClientCommand(getPlayer(), "MilitaryDrop", "ReloadLots", {})
-- Un lot retiré du fichier alors que des caisses existent : elles gardent
-- son id ; la recette refuse de les ouvrir (MilitaryDrop_Recipe.lua) tant que
-- le lot n'est pas revenu. La notice conseille enabled = false.
-- Les autorisations en attente restent : la commande est revalidée contre la
-- nouvelle liste.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Lots"
require "MilitaryDrop/MilitaryDrop_LotsFile"
require "MilitaryDrop/MilitaryDrop_Server"

local Config = MilitaryDrop.Config
local Lots = MilitaryDrop.Lots
local Net = MilitaryDrop.Net
local Server = MilitaryDrop.Server

local Requisition = {}
MilitaryDrop.Requisition = Requisition

-- Validité d'une autorisation : 5 minutes réelles.
Requisition.AUTH_MS = 300000
Requisition.ORDER_INTERVAL_MS = 3000
Requisition.SECTORS = { "N", "E", "S", "W" }
-- Garde-fou contre une commande démesurée (entrées lues dans la table du client).
Requisition.MAX_ENTRIES = 64
-- Cadence de la commande d'admin ReloadLots.
Requisition.RELOAD_INTERVAL_MS = 3000

Config.addDefaults({
    RequisitionForm = true,
    RequisitionBudget = 100,
    RequisitionCostMultiplier = 100,
    RequisitionTier2 = 50,
    RequisitionTier3 = 75,
})

-- nom du joueur → { requestId, expiresAt (ms réelles), forced (largage admin) }
local pending = {}

local function round(value)
    return math.floor(value + 0.5)
end

local function listed(value, sectors)
    for _, sector in ipairs(sectors) do
        if value == sector then
            return true
        end
    end
    return false
end

--- Secteur proposé par l'offre : N/E/S/W en proximité, nom d'un secteur de
--- zones en mode zones (idée 11, offer.decoy.sectors).
local function isSector(value, offer)
    return listed(value, offer and offer.decoy and offer.decoy.sectors or Requisition.SECTORS)
end

-- ----------------------------------------------------------------------------
-- Budget, paliers, offre
-- ----------------------------------------------------------------------------

function Requisition.formEnabled()
    return Config.get("RequisitionForm") == true
end

--- Budget en points entiers pour une note de confiance.
function Requisition.budget(note)
    local percent = math.max(0, tonumber(Config.get("RequisitionBudget")) or 100)
    local value = tonumber(note) or 0
    return math.max(0, math.floor((400 + 16 * value) * percent / 10000 + 1e-9))
end

--- Coût effectif d'un coût de base (multiplicateur en %, au moins 1).
function Requisition.cost(base)
    local percent = math.max(0, tonumber(Config.get("RequisitionCostMultiplier")) or 100)
    return math.max(1, round((tonumber(base) or 0) * percent / 100))
end

--- Plus haut groupe de lots permis pour une note.
function Requisition.maxGroup(note)
    local value = tonumber(note) or 0
    if value >= (tonumber(Config.get("RequisitionTier3")) or 75) then
        return 3
    end
    if value >= (tonumber(Config.get("RequisitionTier2")) or 50) then
        return 2
    end
    return 1
end

--- Leurre proposé (v1.5) : module leurre chargé et option DecoyEnabled vraie.
--- Secteurs : N, E, S, W en proximité ; en mode zones effectif pour ce
--- demandeur (idée 11, Zones.decoySectors), noms des secteurs actifs, ordre
--- alphabétique, et zones = true (feuille admin comprise).
local function decoyOffer(player)
    if not MilitaryDrop.Decoy or Config.get("DecoyEnabled") ~= true then
        return nil
    end
    local offer = { cost = Requisition.cost(tonumber(Config.get("DecoyCost")) or 3), allowed = true,
        sectors = { "N", "E", "S", "W" } }
    local Zones = MilitaryDrop.Zones
    local named = player and Zones
        and Zones.decoySectors(math.floor(player:getX()), math.floor(player:getY()))
    if named and #named > 0 then
        offer.zones = true
        offer.sectors = named
    end
    return offer
end

--- Secteur du largage choisi par le joueur (ZONE-09) : { zones = true,
--- sectors } avec DropZoneChoice 3 en mode zones effectif pour ce demandeur
--- (secteurs du leurre : Zones.playerSectors), sinon nil ; feuille admin
--- comprise.
local function dropOffer(player)
    local Zones = MilitaryDrop.Zones
    local named = player and Zones
        and Zones.playerSectors(math.floor(player:getX()), math.floor(player:getY()))
    if named and #named > 0 then
        return { zones = true, sectors = named }
    end
    return nil
end

--- Offre d'un personnage : budget, palier de lots, lots (ordre d'affichage),
--- leurre et secteur du largage (drop). Contrat de la réponse « form » (dev/PLAN-V14.md). forced :
--- largage admin, tous les paliers et le budget d'une note maximale. player
--- (facultatif) : demandeur, dont la position fixe les secteurs du leurre et
--- du largage.
function Requisition.offer(characterId, forced, player)
    -- Repli paresseux : un seul passage sur les tables pour les 18 lots.
    Lots.warm()
    local note = forced and MilitaryDrop.Trust.MAX or MilitaryDrop.Trust.get(characterId)
    local maxGroup = forced and math.huge or Requisition.maxGroup(note)
    local lots = {}
    for _, lot in ipairs(Lots.LIST) do
        local reason = nil
        if Lots.isDisabled(lot) then
            reason = "disabled"
        elseif lot.group > maxGroup then
            reason = "tier"
        elseif not Lots.hasCandidates(lot.id) then
            reason = "empty"
        end
        local entry = { id = lot.id, group = lot.group, cost = Requisition.cost(lot.cost),
            allowed = reason == nil, reason = reason, label = lot.label, desc = lot.desc }
        -- Lot du fichier avec ses textes : affichés par le client dans sa langue.
        if type(lot.texts) == "table" then
            entry.texts = {}
            for language, text in pairs(lot.texts) do
                entry.texts[language] = { label = text.label, desc = text.desc }
            end
        end
        lots[#lots + 1] = entry
    end
    local decoy, drop = decoyOffer(player), dropOffer(player)
    if decoy and decoy.zones and drop then
        -- Un seul sélecteur au formulaire (ZONE-09) : le leurre prend la liste
        -- du largage (distance minimale comprise), revalidée de même.
        decoy.sectors = drop.sectors
    end
    return { budget = Requisition.budget(note), lots = lots, decoy = decoy, drop = drop }
end

--- Commande normalisée { lots = { [id] = n }, sector = nom ou nil } ou
--- { decoy = "N" } (ou le nom d'un secteur de zones proposé par l'offre), ou
--- nil et le motif (journal seulement) si elle ne respecte pas l'offre.
--- sector : secteur du largage choisi par le joueur (ZONE-09), exigé si et
--- seulement si l'offre le propose (offer.drop), jamais avec un leurre.
function Requisition.validate(order, decoy, offer, sector)
    if order ~= nil and type(order) ~= "table" then
        return nil, "order not a table"
    end
    if decoy ~= nil and not isSector(decoy, offer) then
        return nil, "bad sector"
    end
    if decoy ~= nil and sector ~= nil then
        return nil, "decoy with drop sector"
    end
    if sector ~= nil and not (offer.drop and listed(sector, offer.drop.sectors)) then
        return nil, "bad drop sector"
    end
    if decoy == nil and sector == nil and offer.drop then
        return nil, "no drop sector"
    end
    local offered = {}
    for _, entry in ipairs(offer.lots) do
        offered[entry.id] = entry
    end
    local lots, units, total, entries = {}, 0, 0, 0
    for id, quantity in pairs(order or {}) do
        entries = entries + 1
        if entries > Requisition.MAX_ENTRIES then
            return nil, "too many entries"
        end
        local entry = type(id) == "string" and offered[id]
        if not entry then
            return nil, "unknown lot"
        end
        if type(quantity) ~= "number" or quantity ~= quantity or quantity < 0 or quantity ~= math.floor(quantity)
            or quantity > offer.budget then
            return nil, "bad quantity for " .. id
        end
        if quantity > 0 then
            if not entry.allowed then
                return nil, "lot " .. id .. " not allowed (" .. tostring(entry.reason) .. ")"
            end
            lots[id] = quantity
            units = units + quantity
            total = total + quantity * entry.cost
        end
    end
    if decoy then
        if not offer.decoy or not offer.decoy.allowed then
            return nil, "decoy not offered"
        end
        if units > 0 then
            return nil, "decoy with lots"
        end
        if offer.decoy.cost > offer.budget then
            return nil, "over budget"
        end
        return { decoy = decoy }
    end
    if units == 0 then
        return nil, "empty order"
    end
    if total > offer.budget then
        return nil, "over budget"
    end
    return { lots = lots, sector = sector }
end

-- ----------------------------------------------------------------------------
-- Autorisations en attente
-- ----------------------------------------------------------------------------

--- Ouvre le formulaire : autorisation en attente et réponse « form » au seul
--- demandeur (appelé par Server.handleRequest, appel déjà accepté). forced :
--- largage admin (droit déjà vérifié par Server.evaluate).
function Requisition.openForm(player, requestId, forced)
    forced = forced == true
    local name = tostring(player:getUsername())
    local teamId = MilitaryDrop.Teams.idFor(player)
    local characterId = MilitaryDrop.Trust.idFor(player)
    local offer = Requisition.offer(characterId, forced, player)
    pending[name] = { requestId = requestId, expiresAt = getTimestampMs() + Requisition.AUTH_MS,
        forced = forced or nil, characterId = characterId }
    if not forced then
        MilitaryDrop.Trust.touch(characterId)
    end
    MilitaryDrop.log("request from " .. name .. ": " .. (forced and "admin " or "") .. "requisition form, budget "
        .. offer.budget)
    Net.toPlayer(player, "Result", {
        requestId = requestId, status = "form", forced = forced or nil,
        callsign = MilitaryDrop.Teams.callsign(teamId), tier = MilitaryDrop.Trust.tier(characterId),
        budget = offer.budget, expiresMs = Requisition.AUTH_MS,
        lots = offer.lots, decoy = offer.decoy, drop = offer.drop,
    })
end

--- Autorisation en attente d'un joueur (tests, console), ou nil.
function Requisition.pendingFor(name)
    return pending[name]
end

function Requisition.reset()
    pending = {}
end

local function reply(player, requestId, status, extra)
    local args = { requestId = requestId, status = status }
    for k, v in pairs(extra or {}) do
        args[k] = v
    end
    Net.toPlayer(player, "Result", args)
end

--- Réponse « noSite » : secteur du leurre ou du largage (ZONE-09), et
--- single = true quand l'offre n'a qu'un secteur de zones (le client ne
--- propose pas d'en choisir un autre).
local function noSiteArgs(order, offer)
    local sectors
    if order.decoy ~= nil then
        local decoy = offer and offer.decoy
        sectors = decoy and decoy.zones == true and decoy.sectors or nil
    elseif order.sector ~= nil then
        sectors = offer and offer.drop and offer.drop.sectors
    end
    return { sector = order.decoy or order.sector, single = (sectors ~= nil and #sectors == 1) or nil }
end

--- Commande du formulaire : revalidation complète, puis lancement du vol.
function Requisition.handleOrder(player, args)
    local name = tostring(player:getUsername())
    local requestId = tonumber(args.requestId)
    if MilitaryDrop.Guard.throttled(player, "RequisitionOrder", Requisition.ORDER_INTERVAL_MS) then
        reply(player, requestId, "busy")
        return
    end
    local auth = pending[name]
    if not auth or auth.requestId ~= requestId or auth.characterId ~= MilitaryDrop.Trust.idFor(player) then
        MilitaryDrop.log("order from " .. name .. " refused: no authorization")
        reply(player, requestId, "expired")
        return
    end
    if getTimestampMs() > auth.expiresAt then
        pending[name] = nil
        MilitaryDrop.log("order from " .. name .. " refused: authorization expired")
        reply(player, requestId, "expired")
        return
    end
    if auth.forced then
        Requisition.handleForcedOrder(player, args, auth)
        return
    end
    -- Radio : comme Server.evaluate, sans redemander le code. Ces refus gardent
    -- l'autorisation (le joueur peut rallumer sa radio et renvoyer).
    local radio = MilitaryDrop.Radio.resolve(player, args.radio)
    if not radio then
        reply(player, requestId, "noRadio")
        return
    end
    local status = MilitaryDrop.Radio.status(radio, Config.getChannel())
    if status == "wrongFrequency" or Server.isSilenced(MilitaryDrop.Trust.idFor(player), math.floor(Server.clock() / 24)) then
        reply(player, requestId, "noAnswer")
        return
    end
    if status then
        reply(player, requestId, status)
        return
    end
    local teamId = MilitaryDrop.Teams.idFor(player)
    local characterId = MilitaryDrop.Trust.idFor(player)
    if MilitaryDrop.Trust.isLineCut(characterId) then
        pending[name] = nil
        reply(player, requestId, "lineCut", { callsign = MilitaryDrop.Teams.callsign(teamId) })
        return
    end
    -- Un autre joueur a pu appeler entre-temps.
    local now = getGameTime():getWorldAgeHours()
    local wait = Server.hoursUntilNextDrop(Server.getState(), now, MilitaryDrop.Trust.factor(characterId))
    if wait > 0 then
        pending[name] = nil
        reply(player, requestId, "cooldown", { hours = math.ceil(wait) })
        return
    end
    local offer = Requisition.offer(characterId, nil, player)
    -- Offre recalculée : un secteur de zones retiré par l'admin pendant que
    -- la feuille est ouverte (dernier secteur compris) rend le leurre, ou le
    -- largage par secteur (ZONE-09), « orderInvalid » ; de même DropZoneChoice
    -- changé à chaud (secteur exigé ou plus proposé). Voulu, le joueur
    -- rappelle la base.
    local order, why = Requisition.validate(args.order, args.decoy, offer, args.sector)
    if not order then
        MilitaryDrop.log("order from " .. name .. " refused: " .. tostring(why))
        reply(player, requestId, "orderInvalid")
        return
    end
    -- Point choisi avant de consommer l'autorisation : sans point (secteur
    -- hors carte, zones sans case), le joueur choisit un autre secteur sans
    -- rappeler. info : zone tirée (idée 11), rangée par Server.launchDrop.
    -- Secteur nommé : celui du leurre, sinon celui du largage (ZONE-09).
    local sector = order.decoy or order.sector
    local x, y, info = Server.chooseDropPoint(player, sector)
    if not x then
        MilitaryDrop.log("order from " .. name .. ": no landing point"
            .. (sector and (" in sector " .. sector) or "") .. ", authorization kept")
        reply(player, requestId, "noSite", noSiteArgs(order, offer))
        return
    end
    pending[name] = nil
    local point = { x = x, y = y, info = info }
    if order.decoy then
        -- Leurre : hors du suivi de confiance (LEURRE-04), point dans le secteur.
        Server.launchDrop(player, requestId, false,
            { sector = order.decoy, point = point, untracked = true, decoy = { sector = order.decoy } })
    else
        Server.launchDrop(player, requestId, false, { point = point, order = { lots = order.lots } })
    end
end

--- Commande d'une feuille admin : droit revérifié (il a pu être retiré
--- depuis l'ouverture), puis vol forcé. Ni radio, ni ligne, ni délai.
function Requisition.handleForcedOrder(player, args, auth)
    local name = tostring(player:getUsername())
    local requestId = auth.requestId
    if not Server.canForce(player) then
        pending[name] = nil
        MilitaryDrop.log("admin order from " .. name .. " refused: no longer allowed", true)
        reply(player, requestId, "denied")
        return
    end
    local characterId = MilitaryDrop.Trust.idFor(player)
    local offer = Requisition.offer(characterId, true, player)
    -- Offre recalculée depuis la position de l'admin : secteurs revalidés
    -- comme pour un joueur (ZONE-09, leurre par secteur nommé).
    local order, why = Requisition.validate(args.order, args.decoy, offer, args.sector)
    if not order then
        MilitaryDrop.log("admin order from " .. name .. " refused: " .. tostring(why))
        reply(player, requestId, "orderInvalid")
        return
    end
    -- Point comme pour un joueur : secteur du leurre, sinon du largage.
    local sector = order.decoy or order.sector
    local x, y, info = Server.chooseDropPoint(player, sector)
    if not x then
        MilitaryDrop.log("admin order from " .. name .. ": no landing point"
            .. (sector and (" in sector " .. sector) or "") .. ", authorization kept")
        reply(player, requestId, "noSite", noSiteArgs(order, offer))
        return
    end
    pending[name] = nil
    local point = { x = x, y = y, info = info }
    MilitaryDrop.log("admin order from " .. name .. " accepted", true)
    if order.decoy then
        Server.launchDrop(player, requestId, true,
            { sector = order.decoy, point = point, untracked = true, decoy = { sector = order.decoy } })
    else
        Server.launchDrop(player, requestId, true, { point = point, untracked = true, order = { lots = order.lots } })
    end
end

--- Annulation : l'autorisation est oubliée, rien n'est consommé.
function Requisition.handleCancel(player, args)
    local name = tostring(player:getUsername())
    local auth = pending[name]
    if auth and auth.requestId == tonumber(args.requestId) then
        pending[name] = nil
        MilitaryDrop.log("requisition cancelled by " .. name)
    end
end

-- ----------------------------------------------------------------------------
-- API pour la livraison (Crate, Server, Decoy)
-- ----------------------------------------------------------------------------

local function dropOf(dropId)
    local drops = dropId and MilitaryDrop.Secrets.privateState().drops
    return drops and drops[dropId] or nil
end

--- Commande d'un largage : { lots = { [id] = n } }, { decoy = "N" }, ou nil
--- (largage sans formulaire).
function Requisition.orderOf(dropId)
    local drop = dropOf(dropId)
    if not drop then
        return nil
    end
    if type(drop.decoy) == "table" then
        return { decoy = drop.decoy.sector }
    end
    if type(drop.order) == "table" and type(drop.order.lots) == "table" then
        return { lots = drop.order.lots }
    end
    return nil
end

--- Caisses de réquisition à créer pour un largage, dans l'ordre des lots :
--- { { fullType, lot, name }, … } (une par unité commandée), ou {} sans commande.
--- Un lot commandé puis retiré du fichier avant la livraison (rechargement
--- pendant le vol) est livré quand même, après les autres (ordre des id) :
--- sa caisse garde l'id et son nom ; elle ne s'ouvre pas tant que le lot
--- manque (Recipe), et s'ouvrira s'il revient.
function Requisition.casesFor(dropId)
    local order = Requisition.orderOf(dropId)
    local cases = {}
    if not order or not order.lots then
        return cases
    end
    Lots.ensureLoaded()
    local function addCases(id, label, quantity)
        local name = getText("IGUI_MilitaryDrop_RequisitionCaseName", label)
        for _ = 1, quantity do
            cases[#cases + 1] = { fullType = Lots.CASE_TYPE, lot = id, name = name }
        end
    end
    for _, lot in ipairs(Lots.LIST) do
        local quantity = math.floor(tonumber(order.lots[lot.id]) or 0)
        local label = lot.label and getText(lot.label) or Lots.text(lot, "label", Requisition.serverLanguage())
        addCases(lot.id, label, quantity)
    end
    local missing = {}
    for id, quantity in pairs(order.lots) do
        if type(id) == "string" and not Lots.get(id) and (tonumber(quantity) or 0) >= 1 then
            missing[#missing + 1] = id
        end
    end
    table.sort(missing)
    for _, id in ipairs(missing) do
        MilitaryDrop.log("drop " .. tostring(dropId) .. ": lot " .. id
            .. " is no longer in the lots file; its cases are delivered but cannot be opened until it is back", true)
        -- Quantité validée à la commande (budget) : comme les autres lots.
        addCases(id, id, math.floor(tonumber(order.lots[id])))
    end
    return cases
end

--- Langue du serveur (Translator.getLanguage():name(), comme ISLcdBar.lua:14),
--- ou "EN".
function Requisition.serverLanguage()
    local language = Translator and Translator.getLanguage and Translator.getLanguage()
    local name = language and language:name()
    return name ~= nil and tostring(name) or "EN"
end

--- Calcule les candidats des lots une fois (démarrage du serveur ou de la
--- partie solo), si le formulaire est actif, après lecture du fichier des
--- lots. Renvoie la durée en ms.
function Requisition.warmUp()
    MilitaryDrop.LotsFile.ensureLoaded()
    if not Requisition.formEnabled() then
        return 0
    end
    local started = getTimestampMs()
    Lots.warm()
    local elapsed = getTimestampMs() - started
    MilitaryDrop.log("requisition lots ready in " .. tostring(elapsed) .. " ms")
    return elapsed
end

--- Relit le fichier des lots (admin, sans redémarrer) et recalcule les
--- candidats. Renvoie un résumé (console de débogage en solo) et le rapport
--- de chargement { source, lots, problems }.
function Requisition.reload()
    local report = MilitaryDrop.LotsFile.reload()
    if Requisition.formEnabled() then
        Lots.warm()
    end
    return "requisition lots reloaded: " .. report.lots .. " lots from " .. report.source
        .. ", " .. #report.problems .. " problem(s) (see the console)", report
end

-- Problèmes renvoyés au plus à l'admin (le journal du serveur les a tous).
Requisition.MAX_REPLY_PROBLEMS = 10
-- Dernier rechargement accepté (ms réelles) : cadence globale, tous admins
-- confondus (relire le fichier et recalculer les lots coûte au serveur).
local lastReloadMs = nil

--- Le joueur peut recharger un réglage du serveur : vrai admin, capacité
--- ChangeAndReloadServerOptions (/changeoption, /reloadoptions :
--- ChangeOptionCommand.java:23, ReloadOptionsCommand.java:22). Parmi les rôles
--- par défaut, seul admin l'a : moderator la perd (Roles.java:420), gm et
--- observer ne l'ont pas (Server.canForce, MakeEventsAlarmGunshot, est déjà
--- donné à gm : Roles.java:399). checkPermissions ne vérifie que sur un
--- serveur MP (LuaManager.java:2914-2920) ; en solo, la console suffit.
function Requisition.canReload(player)
    return Capability ~= nil and Capability.ChangeAndReloadServerOptions ~= nil
        and checkPermissions(player, Capability.ChangeAndReloadServerOptions) == true
end

local function replyReload(player, args)
    Net.toPlayer(player, "ReloadLotsReply", args)
end

--- Commande ReloadLots : vrai admin seulement, cadence globale, réponse à
--- l'appelant (résumé, nombre de lots, problèmes).
function Requisition.handleReload(player)
    local name = tostring(player:getUsername())
    if not Requisition.canReload(player) then
        MilitaryDrop.log("ReloadLots refused for " .. name .. ": not an admin", true)
        replyReload(player, { ok = false, summary = "ReloadLots refused: admin only" })
        return
    end
    local now = getTimestampMs()
    if lastReloadMs and now >= lastReloadMs and now - lastReloadMs < Requisition.RELOAD_INTERVAL_MS then
        replyReload(player, { ok = false, summary = "ReloadLots: reloaded less than "
            .. math.floor(Requisition.RELOAD_INTERVAL_MS / 1000) .. " s ago, try again" })
        return
    end
    lastReloadMs = now
    local summary, report = Requisition.reload()
    MilitaryDrop.log(summary .. ", by " .. name, true)
    local problems = {}
    for i = 1, math.min(#report.problems, Requisition.MAX_REPLY_PROBLEMS) do
        problems[i] = tostring(report.problems[i])
    end
    replyReload(player, { ok = true, summary = summary, lots = report.lots, source = report.source,
        problemCount = #report.problems, problems = problems })
end

Server.COMMANDS.RequisitionOrder = function(player, args) Requisition.handleOrder(player, args) end
Server.COMMANDS.RequisitionCancel = function(player, args) Requisition.handleCancel(player, args) end
Server.COMMANDS.ReloadLots = function(player) Requisition.handleReload(player) end

--- Option RequisitionForm activée en cours de partie : lots précalculés tout
--- de suite plutôt qu'au premier formulaire (Requisition.warmUp, sans effet
--- formulaire désactivé). Les autres options du formulaire sont lues à chaque offre.
function Requisition.onOptionsChanged()
    if Requisition.formEnabled() then
        Requisition.warmUp()
    end
end

-- Serveur dédié : OnServerStarted ; solo : OnGameStart (un second appel ne
-- recalcule rien).
Events.OnServerStarted.Add(Requisition.warmUp)
Events.OnGameStart.Add(Requisition.warmUp)
Config.onChange("Requisition", { "RequisitionForm" }, Requisition.onOptionsChanged)

return Requisition
