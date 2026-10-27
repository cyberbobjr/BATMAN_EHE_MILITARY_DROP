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

local function syncWorld()
    local world = { now = 0, online = -1, loaded = false, sent = {}, adds = 0, removes = 0 }
    local player = { getOnlineID = function() return world.online end,
        getSquare = function() return world.loaded and {} or nil end,
        getUsername = function() return "alice" end }
    getTimestampMs = function() return world.now end
    isClient = function() return true end
    getSpecificPlayer = function() return player end
    Events.OnTick = { Add = function() world.adds = world.adds + 1 end,
        Remove = function() world.removes = world.removes + 1 end }
    MilitaryDrop.Net.toServer = function(p, command)
        world.sent[#world.sent + 1] = { player = p, command = command, at = world.now }
    end
    return MilitaryDrop.Client, world
end

function T.initial_sync_waits_for_network_identity_and_loaded_square()
    local C, world = syncWorld()
    C.onGameStart(); C.onGameStart()
    assertEq(world.adds, 1, "single temporary tick subscription")
    C.onSyncTick()
    assertEq(#world.sent, 0, "no request before player connect")
    world.online = 7
    C.onSyncTick()
    assertEq(#world.sent, 0, "no request before loaded square")
    world.loaded = true
    C.onSyncTick()
    assertEq(#world.sent, 1)
    assertEq(world.sent[1].command, "Sync")
end

function T.initial_sync_retries_only_three_times_two_seconds_apart()
    local C, world = syncWorld()
    world.online, world.loaded = 7, true
    C.onGameStart(); C.onSyncTick()
    world.now = 1999; C.onSyncTick()
    assertEq(#world.sent, 1)
    world.now = 2000; C.onSyncTick()
    world.now = 4000; C.onSyncTick()
    assertEq(#world.sent, 3)
    world.now = 6000; C.onSyncTick()
    assertEq(#world.sent, 3)
    assertTrue(world.removes > 0, "temporary callback detached at retry limit")
end

function T.initial_sync_stops_only_on_its_own_marks_reply()
    local C, world = syncWorld()
    world.online, world.loaded = 7, true
    MilitaryDrop.Announce = { onActiveMarks = function() end }
    C.onGameStart(); C.onSyncTick()
    C.onServerCommand("MilitaryDrop", "MarksActive", {})
    C.onServerCommand("MilitaryDrop", "MarksActive", { username = "bob" })
    assertEq(world.removes, 0, "broadcast and another player's reply do not acknowledge this request")
    C.onServerCommand("MilitaryDrop", "MarksActive", { username = "alice" })
    assertTrue(world.removes > 0)
    world.now = 2000; C.onSyncTick()
    assertEq(#world.sent, 1, "no request after acknowledgement")
end

function T.initial_sync_times_out_if_the_player_never_connects()
    local C, world = syncWorld()
    C.onGameStart()
    world.now = 30000; C.onSyncTick()
    assertEq(#world.sent, 0)
    assertTrue(world.removes > 0)
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

function T.cleanup_announce_reaches_the_map_module()
    local received = nil
    MilitaryDrop.Announce = { onCleanupAnnounce = function(args) received = args end }
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "CleanupAnnounce", { id = "M3", x = 1, y = 2, radius = 40 })
    assertEq(received and received.radius, 40, "zone transmise au repère de carte")
end

function T.cleanup_success_notifies_only_the_target_local_player_once()
    local alice = { getUsername = function() return "alice" end }
    local bob = { getUsername = function() return "bob" end }
    getNumActivePlayers = function() return 2 end
    getSpecificPlayer = function(i) return i == 0 and alice or bob end
    local notices = {}
    MilitaryDrop.CleanupFeedback = { show = function(p, text) notices[#notices + 1] = { player = p, text = text } end }
    getText = function(key, a, b) return key .. "|" .. tostring(a) .. "|" .. tostring(b) end
    local args = { id = "M1", username = "bob", contribution = 3, gain = 0 }
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "CleanupCompleted", args)
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "CleanupCompleted", args)
    assertEq(#notices, 1)
    assertEq(notices[1].player, bob)
    assertEq(notices[1].text, "IGUI_MilitaryDrop_CleanupSuccess|3|0")
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

function T.admin_drop_opens_the_admin_form_then_waits_for_its_coordinates()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    Client.sendRequest(w.player, w.device, nil, true)
    local request = w.toServer[1]
    assertEq(request.args.force, true, "largage forcé demandé")
    local requestId = request.args.requestId
    local args = formResult(requestId)
    args.forced, args.budget = true, 20
    result(args)
    wait(Client.REPLY_DELAY_MS)
    assertEq(#w.opened, 1, "feuille ouverte")
    assertEq(w.opened[1].args.forced, true, "marquée admin")
    assertEq(w.opened[1].args.budget, 20, "budget maximal")
    assertTrue(Client.sendRequisition(requestId, { firearms = 1 }, nil, { deadline = NOW + 100000 }), "commande")
    result({ requestId = requestId, status = "accepted", tier = 2, callsign = "Station Kilo-7" })
    wait(Client.REPLY_DELAY_MS)
    -- Largage forcé : coordonnées privées attendues (Dropped).
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "Dropped", { requestId = requestId, x = 10, y = 20 })
    wait(Client.DROPPED_DELAY_MS)
    assertEq(w.device.said.text, "IGUI_MilitaryDrop_Dropped|10", "coordonnées données par la radio")
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

function T.no_point_in_the_chosen_drop_sector_reopens_the_form()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    Client.sendRequest(w.player, w.device, nil, false)
    local requestId = w.toServer[1].args.requestId
    result(formResult(requestId))
    wait(Client.REPLY_DELAY_MS)
    local form = { deadline = NOW + 200000 }
    assertTrue(Client.sendRequisition(requestId, { rations = 1 }, nil, form, "Bravo"), "commande envoyée")
    local order = w.toServer[#w.toServer]
    assertEq(order.args.sector, "Bravo", "secteur du largage transmis (ZONE-09)")
    assertEq(order.args.decoy, nil, "pas de leurre")
    result({ requestId = requestId, status = "noSite", sector = "Bravo" })
    wait(Client.REPLY_DELAY_MS)
    assertEq(w.device.said.text, "IGUI_MilitaryDrop_ReqNoSector|nil", "« aucun point de largage dans ce secteur »")
    assertEq(w.shown[1], form, "feuille rouverte, remplie")
    assertTrue(Client.sendRequisition(requestId, { rations = 1 }, nil, form, "Alpha"), "autre secteur sans rappeler")
    assertEq(w.toServer[#w.toServer].args.sector, "Alpha", "nouveau secteur")
end

function T.no_point_in_the_single_decoy_sector_says_no_zone_site()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    Client.sendRequest(w.player, w.device, nil, false)
    local requestId = w.toServer[1].args.requestId
    result(formResult(requestId))
    wait(Client.REPLY_DELAY_MS)
    local form = { deadline = NOW + 200000 }
    Client.sendRequisition(requestId, {}, "Bravo", form)
    result({ requestId = requestId, status = "noSite", sector = "Bravo", single = true })
    wait(Client.REPLY_DELAY_MS)
    assertEq(w.device.said.text, "IGUI_MilitaryDrop_ReqNoZoneSite|nil", "pas d'« autre secteur » à choisir")
    assertEq(w.shown[1], form, "feuille rouverte (commande de lots, nouvel essai)")
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

function T.code_is_remembered_and_the_anchor_follows_the_request()
    local w = requisitionWorld()
    local Client = MilitaryDrop.Client
    assertEq(Client.rememberedCode(0), "", "rien en mémoire")
    MilitaryDrop.Exchange = { run = function(_, _, _, callback) callback() return true end }
    local anchor = { name = "fenêtre radio" }
    assertTrue(Client.call(w.player, w.device, "BRAVO-KILO-42", false, { anchor = anchor }), "appel lancé")
    assertEq(Client.rememberedCode(0), "BRAVO-KILO-42", "code gardé pour la session")
    assertEq(w.toServer[1].args.code, "BRAVO-KILO-42", "code envoyé")
    local requestId = w.toServer[1].args.requestId
    local anchors = {}
    MilitaryDrop.RequisitionWindow.open = function(_, _, _, _, a) anchors[#anchors + 1] = a end
    MilitaryDrop.RequisitionWindow.show = function(_, _, _, a) anchors[#anchors + 1] = a end
    result(formResult(requestId))
    wait(Client.REPLY_DELAY_MS)
    assertTrue(anchors[1] == anchor, "feuille ancrée à l'ouverture")
    Client.sendRequisition(requestId, { rations = 1 }, nil, { deadline = NOW + 100000 })
    result({ requestId = requestId, status = "busy" })
    assertTrue(anchors[2] == anchor, "feuille rouverte au même endroit")
    -- Dernière réplique de la base gardée par joueur local.
    Client.radioSay({ playerNum = 0, device = w.device }, "reçu")
    assertEq(Client.lastReply(0).text, "reçu", "dernière réplique")
    assertEq(Client.lastReply(1), nil, "rien pour un autre joueur")
    Client.rememberCode(0, "")
    assertEq(Client.rememberedCode(0), "", "code effacé")
end

--- Fichiers simulés sous Zomboid/Lua (getFileWriter / getFileReader).
local function fakeFiles()
    local files = {}
    getFileWriter = function(name, create, append)
        assertEq(create, true, "créé au besoin")
        assertEq(append, false, "écrasé")
        local buffer = {}
        return {
            write = function(_, text) buffer[#buffer + 1] = text end,
            close = function() files[name] = table.concat(buffer) end,
        }
    end
    getFileReader = function(name)
        local content = files[name]
        if not content then
            return nil
        end
        return { readLine = function() return content ~= "" and content or nil end, close = function() end }
    end
    return files
end

local function character(username, forename, surname)
    return {
        getPlayerNum = function() return 0 end,
        getUsername = function() return username end,
        getDescriptor = function()
            return { getForename = function() return forename end, getSurname = function() return surname end }
        end,
        Say = function() end,
    }
end

function T.code_survives_a_reload_per_character()
    local files = fakeFiles()
    local world = "Muldraugh, KY 2026"
    getWorld = function() return { getWorld = function() return world end } end
    local player = character("Kate Smith", "Kate", "Smith")
    getSpecificPlayer = function() return player end
    local Client = MilitaryDrop.Client
    assertEq(Client.rememberedCode(0), "", "rien au départ")
    Client.rememberCode(0, "BRAVO-KILO-42")
    local file = "MilitaryDrop/code_sp_Muldraugh__KY_2026_Kate_Smith_Kate_Smith.txt"
    assertEq(Client.codeFile(player), file, "fichier propre à la partie et au personnage")
    assertEq(files[file], "BRAVO-KILO-42", "écrit dans le fichier du client")
    -- Rechargement de la partie : mémoire du module vide, fichier relu.
    loadMod("client/MilitaryDrop/MilitaryDrop_Client.lua")
    Client = MilitaryDrop.Client
    assertEq(Client.rememberedCode(0), "BRAVO-KILO-42", "prérempli après rechargement")
    -- Autre personnage (mort, nouveau personnage), autre partie : rien.
    player = character("Bob Jones", "Bob", "Jones")
    assertEq(Client.rememberedCode(0), "", "autre personnage : rien")
    player = character("Kate Smith", "Kate", "Smith")
    world = "Riverside"
    assertEq(Client.rememberedCode(0), "", "autre partie : rien")
    -- Client MP : sauvegarde du client (ip_port_compte), compte et personnage.
    isClient = function() return true end
    world = "203.0.113.5_16261_ab12"
    player = character("kate42", "Kate", "Smith")
    assertEq(Client.codeFile(player), "MilitaryDrop/code_mp_203_0_113_5_16261_ab12_kate42_Kate_Smith.txt",
        "fichier propre au serveur et au personnage")
    Client.rememberCode(0, "X")
    Client.rememberCode(0, "")
    assertEq(files[Client.codeFile(player)], "", "code effacé")
    local writes = 0
    getFileWriter = function() writes = writes + 1 return { write = function() end, close = function() end } end
    Client.rememberCode(0, "")
    assertEq(writes, 0, "inchangé : pas de réécriture")
end

function T.central_admin_callbacks_send_existing_commands()
    local Client, sent = MilitaryDrop.Client, {}
    local original = MilitaryDrop.Net.toServer
    MilitaryDrop.Net.toServer = function(player, command, args)
        sent[#sent + 1] = { command, args.kind, args.action }
    end
    Client.onAdminMission({}, "cleanup", "close")
    Client.onAdminMission({}, "cleanup")
    Client.onAdminCrashNext({})
    assertEq(sent[1][1], "AdminMission")
    assertEq(sent[1][2], "cleanup")
    assertEq(sent[1][3], "close")
    assertEq(sent[2][3], nil)
    assertEq(sent[3][1], "AdminCrashNext")
    assertEq(Client.onFillInventoryContextMenu, nil, "no radio admin context hook")
    assertEq(Client.onFillWorldContextMenu, nil, "no radio admin world hook")
    MilitaryDrop.Net.toServer = original
end

function T.character_identity_is_applied_only_to_the_named_local_player()
    local data = {}
    local localPlayer = { getUsername = function() return "batman" end, getModData = function() return data end }
    getSpecificPlayer = function(index) return index == 1 and localPlayer or nil end
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "CharacterIdentity",
        { id = "C:uuid", username = "batman", index = 1 })
    assertEq(data.MilitaryDrop_characterId, "C:uuid", "own identity saved")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "CharacterIdentity",
        { id = "C:other", username = "other", index = 1 })
    assertEq(data.MilitaryDrop_characterId, "C:uuid", "other player ignored")
end

return T
