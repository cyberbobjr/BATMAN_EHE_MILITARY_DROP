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
-- d'atterrissage) : réponse « noSite » (avec le secteur du leurre),
-- autorisation gardée ; le client rouvre la feuille pour un autre secteur.
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
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Lots"
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

Config.addDefaults({
    RequisitionForm = true,
    RequisitionBudget = 100,
    RequisitionCostMultiplier = 100,
    RequisitionTier2 = 50,
    RequisitionTier3 = 75,
})

-- nom du joueur → { requestId, expiresAt (ms réelles) }
local pending = {}

local function round(value)
    return math.floor(value + 0.5)
end

local function isSector(value)
    for _, sector in ipairs(Requisition.SECTORS) do
        if value == sector then
            return true
        end
    end
    return false
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
local function decoyOffer()
    if not MilitaryDrop.Decoy or Config.get("DecoyEnabled") ~= true then
        return nil
    end
    return { cost = Requisition.cost(tonumber(Config.get("DecoyCost")) or 3), allowed = true,
        sectors = { "N", "E", "S", "W" } }
end

--- Offre d'une équipe : budget, palier de lots, lots (ordre d'affichage) et
--- leurre. Contrat de la réponse « form » (docs/PLAN-V14.md).
function Requisition.offer(teamId)
    -- Repli paresseux : un seul passage sur les tables pour les 18 lots.
    Lots.warm()
    local note = MilitaryDrop.Trust.get(teamId)
    local maxGroup = Requisition.maxGroup(note)
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
        lots[#lots + 1] = { id = lot.id, group = lot.group, cost = Requisition.cost(lot.cost),
            allowed = reason == nil, reason = reason, label = lot.label, desc = lot.desc }
    end
    return { budget = Requisition.budget(note), lots = lots, decoy = decoyOffer() }
end

--- Commande normalisée { lots = { [id] = n } } ou { decoy = "N" }, ou nil et
--- le motif (journal seulement) si elle ne respecte pas l'offre.
function Requisition.validate(order, decoy, offer)
    if order ~= nil and type(order) ~= "table" then
        return nil, "order not a table"
    end
    if decoy ~= nil and not isSector(decoy) then
        return nil, "bad sector"
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
    return { lots = lots }
end

-- ----------------------------------------------------------------------------
-- Autorisations en attente
-- ----------------------------------------------------------------------------

--- Ouvre le formulaire : autorisation en attente et réponse « form » au seul
--- demandeur (appelé par Server.handleRequest, appel déjà accepté).
function Requisition.openForm(player, requestId)
    local name = tostring(player:getUsername())
    local teamId = MilitaryDrop.Teams.idFor(player)
    local offer = Requisition.offer(teamId)
    pending[name] = { requestId = requestId, expiresAt = getTimestampMs() + Requisition.AUTH_MS }
    MilitaryDrop.Trust.touch(teamId)
    MilitaryDrop.log("request from " .. name .. ": requisition form, budget " .. offer.budget)
    Net.toPlayer(player, "Result", {
        requestId = requestId, status = "form",
        callsign = MilitaryDrop.Teams.callsign(teamId), tier = MilitaryDrop.Trust.tier(teamId),
        budget = offer.budget, expiresMs = Requisition.AUTH_MS,
        lots = offer.lots, decoy = offer.decoy,
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

--- Commande du formulaire : revalidation complète, puis lancement du vol.
function Requisition.handleOrder(player, args)
    local name = tostring(player:getUsername())
    local requestId = tonumber(args.requestId)
    if MilitaryDrop.Guard.throttled(player, "RequisitionOrder", Requisition.ORDER_INTERVAL_MS) then
        reply(player, requestId, "busy")
        return
    end
    local auth = pending[name]
    if not auth or auth.requestId ~= requestId then
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
    -- Radio : comme Server.evaluate, sans redemander le code. Ces refus gardent
    -- l'autorisation (le joueur peut rallumer sa radio et renvoyer).
    local radio = MilitaryDrop.Radio.resolve(player, args.radio)
    if not radio then
        reply(player, requestId, "noRadio")
        return
    end
    local status = MilitaryDrop.Radio.status(radio, Config.getChannel())
    if status == "wrongFrequency" or Server.isSilenced(name, math.floor(Server.clock() / 24)) then
        reply(player, requestId, "noAnswer")
        return
    end
    if status then
        reply(player, requestId, status)
        return
    end
    local teamId = MilitaryDrop.Teams.idFor(player)
    if MilitaryDrop.Trust.isLineCut(teamId) then
        pending[name] = nil
        reply(player, requestId, "lineCut", { callsign = MilitaryDrop.Teams.callsign(teamId) })
        return
    end
    -- Un autre joueur a pu appeler entre-temps.
    local now = getGameTime():getWorldAgeHours()
    local wait = Server.hoursUntilNextDrop(Server.getState(), now, MilitaryDrop.Trust.factor(teamId))
    if wait > 0 then
        pending[name] = nil
        reply(player, requestId, "cooldown", { hours = math.ceil(wait) })
        return
    end
    local order, why = Requisition.validate(args.order, args.decoy, Requisition.offer(teamId))
    if not order then
        MilitaryDrop.log("order from " .. name .. " refused: " .. tostring(why))
        reply(player, requestId, "orderInvalid")
        return
    end
    -- Point choisi avant de consommer l'autorisation : sans point (secteur
    -- hors carte), le joueur choisit un autre secteur sans rappeler.
    local x, y = Server.chooseDropPoint(player, order.decoy)
    if not x then
        MilitaryDrop.log("order from " .. name .. ": no landing point"
            .. (order.decoy and (" in sector " .. order.decoy) or "") .. ", authorization kept")
        reply(player, requestId, "noSite", { sector = order.decoy })
        return
    end
    pending[name] = nil
    local point = { x = x, y = y }
    if order.decoy then
        -- Leurre : hors du suivi de confiance (LEURRE-04), point dans le secteur.
        Server.launchDrop(player, requestId, false,
            { sector = order.decoy, point = point, untracked = true, decoy = { sector = order.decoy } })
    else
        Server.launchDrop(player, requestId, false, { point = point, order = { lots = order.lots } })
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
function Requisition.casesFor(dropId)
    local order = Requisition.orderOf(dropId)
    local cases = {}
    if not order or not order.lots then
        return cases
    end
    for _, lot in ipairs(Lots.LIST) do
        local quantity = math.floor(tonumber(order.lots[lot.id]) or 0)
        local name = getText("IGUI_MilitaryDrop_RequisitionCaseName", getText(lot.label))
        for _ = 1, quantity do
            cases[#cases + 1] = { fullType = Lots.CASE_TYPE, lot = lot.id, name = name }
        end
    end
    return cases
end

--- Calcule les candidats des lots une fois (démarrage du serveur ou de la
--- partie solo), si le formulaire est actif. Renvoie la durée en ms.
function Requisition.warmUp()
    if not Requisition.formEnabled() then
        return 0
    end
    local started = getTimestampMs()
    Lots.warm()
    local elapsed = getTimestampMs() - started
    MilitaryDrop.log("requisition lots ready in " .. tostring(elapsed) .. " ms")
    return elapsed
end

Server.COMMANDS.RequisitionOrder = function(player, args) Requisition.handleOrder(player, args) end
Server.COMMANDS.RequisitionCancel = function(player, args) Requisition.handleCancel(player, args) end

-- Serveur dédié : OnServerStarted ; solo : OnGameStart (un second appel ne
-- recalcule rien).
Events.OnServerStarted.Add(Requisition.warmUp)
Events.OnGameStart.Add(Requisition.warmUp)

return Requisition
