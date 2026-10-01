-- MilitaryDrop_Client : réponse de la base affichée par la radio ; formulaire
-- de réquisition (Result « form », RequisitionOrder, RequisitionCancel, refus).

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

-- ----------------------------------------------------------------------------
-- Réquisition (v1.4)
-- ----------------------------------------------------------------------------

--- Joueur, talkie, paroles, messages au serveur et feuilles ouvertes simulés.
local function requisitionWorld()
    getText = function(key, a) return key .. "|" .. tostring(a) end
    ZombRand = function() return 0 end
    NOW = 1000
    getTimestampMs = function() return NOW end
    local w = { said = {}, toServer = {}, opened = {}, shown = {}, dismissed = {} }
    w.player = {
        getPlayerNum = function() return 0 end,
        Say = function(_, text) w.said[#w.said + 1] = text end,
    }
    getSpecificPlayer = function() return w.player end
    w.device = makeDevice("Radio")
    w.device.getID = function() return 42 end
    MilitaryDrop.Server = { onClientCommand = function(_, command, _, args)
        w.toServer[#w.toServer + 1] = { command = command, args = args }
    end }
    MilitaryDrop.RequisitionWindow = {
        open = function(player, device, args, receivedMs)
            w.opened[#w.opened + 1] = { player = player, device = device, args = args, receivedMs = receivedMs }
        end,
        show = function(_, _, form) w.shown[#w.shown + 1] = form end,
        dismiss = function(requestId) w.dismissed[#w.dismissed + 1] = requestId end,
        expired = function(form, now) return now >= form.deadline end,
    }
    return w
end

local function result(args)
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "Result", args)
end

local function wait(ms)
    NOW = NOW + ms
    triggerEvent("OnTick")
end

local function formResult(requestId)
    return { requestId = requestId, status = "form", callsign = "Station Kilo-7", tier = 2, budget = 12,
        expiresMs = 300000, lots = {} }
end

function T.form_result_opens_the_form_after_the_base_speaks()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    Client.sendRequest(w.player, w.device, nil, false)
    local request = w.toServer[1]
    assertEq(request.command, "Request", "appel")
    local requestId = request.args.requestId
    result(formResult(requestId))
    assertEq(#w.opened, 0, "la base parle d'abord")
    wait(Client.REPLY_DELAY_MS)
    assertEq(w.device.said.text, "IGUI_MilitaryDrop_ReqFormSay|Station Kilo-7", "« transmettez votre réquisition »")
    assertEq(#w.opened, 1, "formulaire ouvert")
    assertEq(w.opened[1].device, w.device, "avec la radio de l'appel")
    assertEq(w.opened[1].receivedMs, 1000, "délai compté depuis la réception")
    assertEq(w.opened[1].args.budget, 12, "données du serveur")
    -- Commande : même requestId, même référence de radio que la demande.
    local form = { deadline = NOW + 200000 }
    assertTrue(Client.sendRequisition(requestId, { rations = 2 }, nil, form), "commande envoyée")
    local order = w.toServer[2]
    assertEq(order.command, "RequisitionOrder", "RequisitionOrder")
    assertEq(order.args.requestId, requestId, "même requestId")
    assertEq(order.args.radio.kind, request.args.radio.kind, "même radio (genre)")
    assertEq(order.args.radio.id, request.args.radio.id, "même radio (identifiant)")
    assertEq(order.args.order.rations, 2, "contenu")
    assertEq(order.args.decoy, nil, "pas de leurre")
    assertEq(w.said[#w.said], "IGUI_MilitaryDrop_ReqOrderSay|Station Kilo-7", "le personnage parle à la radio")
    for _, text in ipairs(w.said) do
        assertTrue(not text:find("rations", 1, true), "le contenu n'est jamais prononcé")
    end
    assertTrue(not Client.sendRequisition(requestId, { rations = 1 }, nil, form), "pas de seconde commande")
    -- Refus qui garde l'autorisation : la feuille se rouvre, remplie.
    result({ requestId = requestId, status = "radioOff" })
    assertEq(w.said[#w.said], "IGUI_MilitaryDrop_TurnOn|nil", "motif dit par le personnage")
    assertEq(w.shown[1], form, "même formulaire rouvert")
    assertTrue(Client.sendRequisition(requestId, { rations = 2 }, nil, form), "renvoi possible")
    -- Accord : comportement habituel, la demande est close.
    result({ requestId = requestId, status = "accepted", tier = 2, callsign = "Station Kilo-7" })
    wait(Client.REPLY_DELAY_MS)
    assertEq(w.device.said.text, "IGUI_MilitaryDrop_AckTier2_1|Station Kilo-7", "accord de la base")
    assertTrue(not Client.sendRequisition(requestId, { rations = 1 }, nil, form), "demande close")
end

function T.cancelled_form_sends_requisition_cancel()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    Client.sendRequest(w.player, w.device, nil, false)
    local requestId = w.toServer[1].args.requestId
    result(formResult(requestId))
    wait(Client.REPLY_DELAY_MS)
    assertTrue(Client.cancelRequisition(requestId, true), "annulation")
    local cancel = w.toServer[2]
    assertEq(cancel.command, "RequisitionCancel", "RequisitionCancel")
    assertEq(cancel.args.requestId, requestId, "même requestId")
    assertEq(w.said[#w.said], "IGUI_MilitaryDrop_ReqCancelSay|Station Kilo-7", "dite à la radio")
    assertTrue(not Client.cancelRequisition(requestId, false), "une seule fois")
    assertTrue(not Client.sendRequisition(requestId, {}, nil, {}), "plus de commande après l'annulation")
    -- Annulée avant l'ouverture (délai de la réplique) : la feuille ne s'ouvre pas.
    Client.sendRequest(w.player, w.device, nil, false)
    local second = w.toServer[3].args.requestId
    result(formResult(second))
    Client.cancelRequisition(second, false)
    wait(Client.REPLY_DELAY_MS)
    assertEq(#w.opened, 1, "pas de feuille pour une demande annulée")
end

function T.order_refusals_are_spoken_by_the_base()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    for _, case in ipairs({ { "expired", "IGUI_MilitaryDrop_ReqExpired|nil" },
        { "orderInvalid", "IGUI_MilitaryDrop_ReqOrderInvalid|nil" } }) do
        Client.sendRequest(w.player, w.device, nil, false)
        local requestId = w.toServer[#w.toServer].args.requestId
        result(formResult(requestId))
        wait(Client.REPLY_DELAY_MS)
        Client.sendRequisition(requestId, { rations = 1 }, nil, { deadline = NOW + 100000 })
        result({ requestId = requestId, status = case[1] })
        wait(Client.REPLY_DELAY_MS)
        assertEq(w.device.said.text, case[2], "réplique de la base : " .. case[1])
        assertTrue(not Client.sendRequisition(requestId, {}, nil, {}), "demande close : " .. case[1])
    end
    -- Réponse reçue pendant que la feuille est encore ouverte : elle se ferme.
    Client.sendRequest(w.player, w.device, nil, false)
    local requestId = w.toServer[#w.toServer].args.requestId
    result(formResult(requestId))
    wait(Client.REPLY_DELAY_MS)
    result({ requestId = requestId, status = "expired" })
    assertEq(w.dismissed[#w.dismissed], requestId, "feuille fermée")
end

function T.no_point_in_decoy_sector_reopens_the_form()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    Client.sendRequest(w.player, w.device, nil, false)
    local requestId = w.toServer[1].args.requestId
    result(formResult(requestId))
    wait(Client.REPLY_DELAY_MS)
    local form = { deadline = NOW + 200000 }
    Client.sendRequisition(requestId, {}, "N", form)
    result({ requestId = requestId, status = "noSite", sector = "N" })
    wait(Client.REPLY_DELAY_MS)
    assertEq(w.device.said.text, "IGUI_MilitaryDrop_ReqNoSector|nil", "« aucun point de largage dans ce secteur »")
    assertEq(w.shown[1], form, "feuille rouverte, remplie")
    assertTrue(Client.sendRequisition(requestId, {}, "S", form), "autre secteur sans rappeler")
end

function T.no_site_without_form_is_unchanged()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    Client.sendRequest(w.player, w.device, nil, false)
    local requestId = w.toServer[1].args.requestId
    result({ requestId = requestId, status = "noSite" })
    wait(Client.REPLY_DELAY_MS)
    assertEq(w.device.said.text, "IGUI_MilitaryDrop_NoSite|nil", "réplique habituelle")
    assertEq(#w.shown, 0, "aucune feuille")
end

function T.accepted_without_form_is_unchanged()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    Client.sendRequest(w.player, w.device, nil, false)
    local requestId = w.toServer[1].args.requestId
    result({ requestId = requestId, status = "accepted", tier = 3, callsign = "Station Kilo-7" })
    wait(Client.REPLY_DELAY_MS)
    assertEq(#w.opened, 0, "aucun formulaire")
    assertEq(w.device.said.text, "IGUI_MilitaryDrop_AckTier3_1|Station Kilo-7", "accord habituel")
    assertTrue(not Client.sendRequisition(requestId, {}, nil, {}), "aucune commande possible")
end

return T
