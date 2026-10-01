-- MilitaryDrop_RequisitionWindow : formulaire de réquisition (client, v1.4).
-- Disposition mesurée sans débordement (langue longue, anglais, petit écran),
-- budget et restant, boutons − et + bornés par le budget et les paliers,
-- leurre exclusif et secteur obligatoire, lots grisés et leur raison,
-- construction exacte de RequisitionOrder, annulation, expiration.
-- Le protocole avec MilitaryDrop.Client est dans test_client.lua.

local T = {}

local CHAR_W = 7
local FONT_H = 19

local sent

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return true end
    isServer = function() return false end
    NOW = 1000000
    getTimestampMs = function() return NOW end
    getText = function(k, a) return a ~= nil and (k .. "|" .. tostring(a)) or k end
    Translator = { getLanguage = function() return { name = function() return "FR" end } end }
    UIFont = { Small = "Small", Medium = "Medium", CodeSmall = "CodeSmall", CodeMedium = "CodeMedium",
        Handwritten = "Handwritten" }
    getTextManager = function()
        return {
            getFontHeight = function(_, font) return font == "Handwritten" and 40 or FONT_H end,
            MeasureStringX = function(_, _, s) return #s * CHAR_W end,
        }
    end
    instanceof = function(object, class) return object ~= nil and object.kind == class end
    ISPanelJoypad = { derive = function(self, name)
        return setmetatable({ Type = name }, { __index = self })
    end }
    function ISPanelJoypad.new(cls, x, y, w, h)
        local o = setmetatable({}, { __index = cls })
        o.x, o.y, o.width, o.height, o.visible = x, y, w, h, true
        return o
    end
    function ISPanelJoypad:setWantKeyEvents() end
    function ISPanelJoypad:createChildren() end
    function ISPanelJoypad:setWidth(v) self.width = v end
    function ISPanelJoypad:setHeight(v) self.height = v end
    function ISPanelJoypad:setVisible(v) self.visible = v end
    function ISPanelJoypad:removeFromUIManager() self.removed = true end
    getSoundManager = function() return { playUISound = function() end } end
    JoypadState = { players = {} }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    sent = {}
    MilitaryDrop.Client = {
        HANDLERS = {},
        sendRequisition = function(requestId, order, decoy, form)
            sent[#sent + 1] = { kind = "order", requestId = requestId, order = order, decoy = decoy, form = form }
            return true
        end,
        cancelRequisition = function(requestId, spoken)
            sent[#sent + 1] = { kind = "cancel", requestId = requestId, spoken = spoken }
            return true
        end,
    }
    loadMod("client/MilitaryDrop/MilitaryDrop_RequisitionWindow.lua")
    RW = MilitaryDrop.RequisitionWindow
end

local LOTS = {
    { "rations", 1, 1 }, { "water", 1, 1 }, { "medical", 1, 2 }, { "tools", 1, 2 }, { "materials", 1, 1 },
    { "camping", 1, 2 }, { "ammo", 2, 2 }, { "melee", 2, 3 }, { "protection", 2, 3 }, { "mechanics", 2, 2 },
    { "comms", 2, 2 }, { "seeds", 2, 1 }, { "books", 2, 2 }, { "packs", 2, 2 }, { "firearms", 3, 5 },
    { "attachments", 3, 3 }, { "explosives", 3, 5 }, { "fuel", 3, 3 },
}

--- Result « form » du contrat : maxGroup paliers permis, budget, leurre.
local function formArgs(maxGroup, budget, withDecoy)
    local lots = {}
    for _, def in ipairs(LOTS) do
        local allowed = def[2] <= maxGroup
        lots[#lots + 1] = { id = def[1], group = def[2], cost = def[3], allowed = allowed,
            reason = not allowed and "tier" or nil,
            label = "IGUI_MilitaryDrop_Lot_" .. def[1], desc = "IGUI_MilitaryDrop_LotDesc_" .. def[1] }
    end
    local args = { requestId = 7, status = "form", callsign = "Station Kilo-7", tier = 2, budget = budget,
        expiresMs = 300000, lots = lots }
    if withDecoy ~= false then
        args.decoy = { cost = 3, allowed = true, sectors = { "N", "E", "S", "W" } }
    end
    return args
end

local function within(inner, outer)
    return inner.x >= outer.x and inner.y >= outer.y and inner.x + inner.w <= outer.x + outer.w
        and inner.y + inner.h <= outer.y + outer.h
end

local function disjoint(a, b)
    return a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y
end

local function measure(s)
    return #tostring(s) * CHAR_W
end

--- Aucun élément ne déborde : rectangles dans la feuille, contrôles sans
--- chevauchement, textes mesurés dans leur case.
local function checkLayout(L, form, label)
    local paper = L.paper
    local whole = { x = 0, y = 0, w = L.W, h = L.H }
    assertTrue(within(paper, whole), label .. " : feuille dans la fenêtre")
    assertTrue(within(L.close, whole) and disjoint(L.close, paper), label .. " : croix sur la planchette")
    for _, name in ipairs({ "stamp", "transmit", "cancel", "budget" }) do
        assertTrue(within(L[name], paper), label .. " : " .. name .. " sur la feuille")
    end
    assertTrue(disjoint(L.transmit, L.cancel), label .. " : boutons séparés")
    assertTrue(L.textX + L.infoW <= L.stamp.x, label .. " : en-tête à gauche du tampon")
    assertTrue(measure(getText("IGUI_MilitaryDrop_ReqTransmit")) <= L.transmit.w - 2 * L.u,
        label .. " : « Transmettre » tient")
    assertTrue(measure(getText("IGUI_MilitaryDrop_ReqCancel")) <= L.cancel.w - 2 * L.u, label .. " : « Annuler » tient")
    assertTrue(measure(getText("IGUI_MilitaryDrop_ReqStamp")) <= L.stamp.w - 2 * L.u, label .. " : tampon")
    local rows = {}
    for _, lot in ipairs(form.lots) do
        local row = L.rows[lot.id]
        assertTrue(row ~= nil, label .. " : ligne de " .. lot.id)
        assertTrue(within(row.row, paper), label .. " : ligne " .. lot.id .. " sur la feuille")
        assertTrue(within(row.minus, row.row) and within(row.qty, row.row) and within(row.plus, row.row),
            label .. " : contrôles de " .. lot.id .. " dans la ligne")
        assertTrue(disjoint(row.minus, row.qty) and disjoint(row.qty, row.plus), label .. " : − case + séparés")
        assertTrue(row.costRight <= row.minus.x, label .. " : coût avant les boutons")
        assertTrue(measure(RW.costText(lot.cost)) <= L.costW, label .. " : coût dans sa colonne")
        if not lot.allowed then
            assertTrue(measure(RW.reasonText(lot)) <= row.span.w, label .. " : raison de " .. lot.id .. " entière")
        end
        assertTrue(not disjoint(row.row, L.columns[1]) or (L.columns[2] and not disjoint(row.row, L.columns[2])),
            label .. " : ligne dans une colonne")
        for _, other in ipairs(rows) do
            assertTrue(disjoint(other, row.row), label .. " : lignes sans chevauchement")
        end
        assertTrue(disjoint(row.row, L.budget) and disjoint(row.row, L.transmit), label .. " : lignes hors du pied")
        rows[#rows + 1] = row.row
    end
    if form.decoy then
        assertTrue(within(L.decoyRow.check, L.decoyRow.row), label .. " : case du leurre")
        for _, sector in ipairs(RW.SECTORS) do
            local box = L.sectorBoxes[sector]
            assertTrue(within(box, L.sectorsArea), label .. " : secteur " .. sector .. " dans son bloc")
            for _, other in ipairs(RW.SECTORS) do
                assertTrue(other == sector or disjoint(box, L.sectorBoxes[other]), label .. " : secteurs séparés")
            end
        end
        assertTrue(disjoint(L.sectorsArea, L.budget), label .. " : secteurs au-dessus du budget")
    end
end

function T.layout_fits_in_french_and_english()
    local form = RW.newForm(formArgs(2, 12), NOW)
    -- Clés brutes (« IGUI_… », longues) : comme une langue bavarde.
    local L = RW.computeLayout(form, 1920, 1080)
    assertEq(L.cols, 2, "grand écran : deux colonnes")
    assertTrue(not L.compact, "grand écran : mise en page aérée")
    checkLayout(L, form, "clés longues")
    -- Anglais : textes courts.
    local english = {
        IGUI_MilitaryDrop_ReqTransmit = "Transmit requisition", IGUI_MilitaryDrop_ReqCancel = "Cancel",
        IGUI_MilitaryDrop_ReqStamp = "AUTHORIZED", IGUI_MilitaryDrop_ReqReasonTier = "trust %1+",
        IGUI_MilitaryDrop_ReqPoints = "%1 pts", IGUI_MilitaryDrop_ReqPoint = "%1 pt",
        IGUI_MilitaryDrop_Lot_attachments = "Weapon attachments",
    }
    getText = function(k, a)
        local text = english[k] or k:gsub("^IGUI_MilitaryDrop_", "")
        return (text:gsub("%%1", tostring(a)))
    end
    local L2 = RW.computeLayout(form, 1920, 1080)
    checkLayout(L2, form, "anglais")
    assertTrue(L2.W < L.W, "textes courts : feuille plus étroite")
    -- Libellé démesuré : raccourci à la largeur de la colonne des lots.
    english.IGUI_MilitaryDrop_Lot_fuel = string.rep("Carburant ", 12)
    local L3 = RW.computeLayout(form, 1920, 1080)
    checkLayout(L3, form, "libellé démesuré")
    local fitted = RW.fit(getText("IGUI_MilitaryDrop_Lot_fuel"), UIFont.CodeSmall, L3.labelW)
    assertTrue(measure(fitted) <= L3.labelW and fitted:sub(-3) == "...", "libellé raccourci")
end

-- Textes français du formulaire (les plus longs mesurés par la disposition).
local FRENCH = {
    IGUI_MilitaryDrop_ReqTitle = "FORMULAIRE DE RÉQUISITION",
    IGUI_MilitaryDrop_ReqService = "LOGISTIQUE - RAVITAILLEMENT AÉRIEN",
    IGUI_MilitaryDrop_ReqFrom = "Demandeur : %1", IGUI_MilitaryDrop_ReqRef = "Réf. %1",
    IGUI_MilitaryDrop_ReqStamp = "AUTORISÉ", IGUI_MilitaryDrop_ReqStampExpired = "EXPIRÉ",
    IGUI_MilitaryDrop_ReqValid = "valable %1",
    IGUI_MilitaryDrop_ReqColLot = "LOT", IGUI_MilitaryDrop_ReqColCost = "COÛT", IGUI_MilitaryDrop_ReqColQty = "QTÉ",
    IGUI_MilitaryDrop_ReqPoint = "%1 pt", IGUI_MilitaryDrop_ReqPoints = "%1 pts",
    IGUI_MilitaryDrop_ReqReasonTier = "confiance %1+", IGUI_MilitaryDrop_ReqReasonEmpty = "indisponible",
    IGUI_MilitaryDrop_ReqReasonDisabled = "non autorisé", IGUI_MilitaryDrop_ReqDecoy = "Leurre à sirène",
    IGUI_MilitaryDrop_ReqBudget = "Budget alloué", IGUI_MilitaryDrop_ReqSpent = "Engagé",
    IGUI_MilitaryDrop_ReqLeft = "Restant", IGUI_MilitaryDrop_ReqLost = "points non utilisés perdus",
    IGUI_MilitaryDrop_ReqTransmit = "Transmettre la réquisition", IGUI_MilitaryDrop_ReqCancel = "Annuler",
    IGUI_MilitaryDrop_Lot_attachments = "Accessoires d'armes", IGUI_MilitaryDrop_Lot_melee = "Armes de mêlée",
    IGUI_MilitaryDrop_Lot_comms = "Transmissions",
}

local function useTexts(texts)
    getText = function(k, a)
        local text = texts[k] or k:gsub("^IGUI_MilitaryDrop_Lot_", ""):gsub("^IGUI_MilitaryDrop_", "")
        return (text:gsub("%%1", tostring(a)))
    end
end

function T.layout_fits_a_small_screen()
    useTexts(FRENCH)
    local form = RW.newForm(formArgs(3, 20), NOW)
    local big = RW.computeLayout(form, 1920, 1080)
    local L = RW.computeLayout(form, 960, 540)
    assertTrue(L.W <= 960 and L.H <= 540, "tient dans 960 x 540")
    assertTrue(L.H < big.H, "plus serré que sur grand écran")
    checkLayout(L, form, "petit écran")
    -- Écran étroit (écran partagé vertical) : une seule colonne.
    local narrow = RW.computeLayout(form, 560, 1080)
    assertEq(narrow.cols, 1, "écran étroit : une colonne")
    assertTrue(narrow.W <= 560, "tient en largeur")
    checkLayout(narrow, form, "une colonne")
end

function T.budget_spent_and_remaining()
    local form = RW.newForm(formArgs(2, 12), NOW)
    assertEq(form.budget, 12, "budget reçu")
    assertTrue(RW.add(form, "rations") and RW.add(form, "melee") and RW.add(form, "melee"), "trois ajouts")
    assertEq(RW.spent(form), 7, "1 + 3 + 3")
    assertEq(RW.remaining(form), 5, "restant")
    assertTrue(RW.remove(form, "melee"), "retrait")
    assertEq(RW.remaining(form), 8, "restant après retrait")
    local bad = RW.newForm({ requestId = 1, budget = -4, lots = {} }, NOW)
    assertEq(bad.budget, 0, "budget négatif ramené à zéro")
end

function T.plus_and_minus_are_bounded_by_budget_and_tiers()
    local form = RW.newForm(formArgs(2, 8), NOW)
    assertTrue(not RW.canRemove(form, "rations") and not RW.remove(form, "rations"), "rien à retirer à zéro")
    assertTrue(not RW.canAdd(form, "firearms") and not RW.add(form, "firearms"), "palier III fermé")
    assertTrue(not RW.canAdd(form, "nope"), "lot inconnu")
    while RW.add(form, "melee") do end
    assertEq(form.qty.melee, 2, "deux armes de mêlée (6 points sur 8)")
    assertTrue(not RW.canAdd(form, "melee"), "+ grisé : 2 points restants pour un lot à 3")
    assertTrue(RW.canAdd(form, "medical"), "un lot à 2 passe encore")
    RW.add(form, "medical")
    assertEq(RW.remaining(form), 0, "budget épuisé")
    for _, lot in ipairs(form.lots) do
        assertTrue(not RW.canAdd(form, lot.id), "plus aucun + : " .. lot.id)
    end
    -- Plafond de quantité.
    local rich = RW.newForm(formArgs(1, 500), NOW)
    while RW.add(rich, "rations") do end
    assertEq(rich.qty.rations, RW.MAX_QTY, "quantité plafonnée")
end

function T.decoy_is_exclusive_and_needs_a_sector()
    local form = RW.newForm(formArgs(3, 12), NOW)
    RW.add(form, "rations")
    assertTrue(not RW.canToggleDecoy(form) and not RW.toggleDecoy(form), "un lot choisi bloque le leurre")
    assertTrue(not RW.canPickSector(form, "N"), "secteur bloqué aussi")
    RW.remove(form, "rations")
    assertTrue(RW.toggleDecoy(form), "leurre coché")
    assertEq(RW.spent(form), 3, "coût du leurre engagé")
    assertTrue(not RW.canAdd(form, "rations"), "le leurre bloque les lots")
    assertEq(RW.blocker(form, NOW), "sector", "secteur obligatoire")
    assertTrue(not RW.pickSector(form, "X"), "secteur inconnu refusé")
    assertTrue(RW.pickSector(form, "W"), "ouest")
    assertEq(RW.blocker(form, NOW), nil, "transmissible")
    assertTrue(RW.toggleDecoy(form), "leurre décoché")
    assertEq(form.sector, nil, "secteur oublié")
    assertEq(RW.blocker(form, NOW), "nothing", "rien de choisi")
    assertTrue(RW.pickSector(form, "E") and form.decoyOn, "choisir un secteur coche le leurre")
    -- Budget trop court, leurre refusé, sans leurre.
    local poor = RW.newForm(formArgs(1, 2), NOW)
    assertTrue(not RW.canToggleDecoy(poor), "budget inférieur au coût")
    local args = formArgs(3, 12)
    args.decoy = { cost = 3, allowed = false, reason = "disabled", sectors = { "N" } }
    local refused = RW.newForm(args, NOW)
    assertTrue(not RW.canToggleDecoy(refused) and not RW.canPickSector(refused, "N"), "leurre non permis")
    assertEq(RW.reasonText(refused.decoy), "IGUI_MilitaryDrop_ReqReasonDisabled", "raison du leurre")
    local none = RW.newForm(formArgs(3, 12, false), NOW)
    assertEq(none.decoy, nil, "v1.5 désactivée : pas de leurre")
    assertTrue(not RW.canToggleDecoy(none), "rien à cocher")
    local L = RW.computeLayout(none, 1920, 1080)
    assertEq(L.decoyRow, nil, "pas de ligne du leurre")
end

function T.greyed_lots_show_their_reason()
    local args = formArgs(1, 8)
    args.lots[2].allowed, args.lots[2].reason = false, "empty"
    args.lots[17].reason = "disabled"
    args.lots[18].reason = "weird"
    local form = RW.newForm(args, NOW)
    assertEq(RW.reasonText(form.byId.ammo), "IGUI_MilitaryDrop_ReqReasonTier|50", "palier II : seuil par défaut")
    assertEq(RW.reasonText(form.byId.firearms), "IGUI_MilitaryDrop_ReqReasonTier|75", "palier III")
    SandboxVars.MilitaryDrop.RequisitionTier3 = 80
    assertEq(RW.reasonText(form.byId.firearms), "IGUI_MilitaryDrop_ReqReasonTier|80", "seuil de l'option")
    assertEq(RW.reasonText(form.byId.water), "IGUI_MilitaryDrop_ReqReasonEmpty", "indisponible")
    assertEq(RW.reasonText(form.byId.explosives), "IGUI_MilitaryDrop_ReqReasonDisabled", "non autorisé")
    assertEq(RW.reasonText(form.byId.fuel), "IGUI_MilitaryDrop_ReqReasonEmpty", "raison inconnue : indisponible")
    -- Données incohérentes du serveur : lots sans id ou en double ignorés.
    local messy = RW.newForm({ requestId = 2, budget = 5, lots = { { id = "a", cost = 0 }, { cost = 2 },
        { id = "a", cost = 9 }, "x" }, decoy = { cost = 2, allowed = true, sectors = { "N", "Q", "N" } } }, NOW)
    assertEq(#messy.lots, 1, "un seul lot gardé")
    assertEq(messy.lots[1].cost, 1, "coût au moins 1")
    assertTrue(not messy.lots[1].allowed, "permis seulement si le serveur le dit")
    assertEq(#messy.decoy.sectors, 1, "secteurs filtrés")
end

function T.order_is_built_exactly()
    local form = RW.newForm(formArgs(2, 12), NOW)
    RW.add(form, "rations")
    RW.add(form, "rations")
    RW.add(form, "ammo")
    RW.add(form, "water")
    RW.remove(form, "water")
    local ref = { kind = "item", id = 42 }
    local order = RW.buildOrder(form, ref)
    assertEq(order.requestId, 7, "requestId du formulaire")
    assertEq(order.radio, ref, "référence de la radio")
    assertEq(order.decoy, nil, "pas de leurre")
    local count = 0
    for id, n in pairs(order.order) do
        count = count + 1
        assertEq(n, id == "rations" and 2 or 1, "quantité de " .. id)
    end
    assertEq(count, 2, "seulement les lots commandés (pas de zéro)")
    local decoy = RW.newForm(formArgs(3, 12), NOW)
    RW.pickSector(decoy, "S")
    local order2 = RW.buildOrder(decoy, nil)
    assertEq(order2.decoy, "S", "secteur du leurre")
    for _ in pairs(order2.order) do
        error("le leurre part seul")
    end
end

function T.expiry_follows_the_server_delay()
    local form = RW.newForm(formArgs(1, 8), NOW)
    assertEq(form.deadline, NOW + 300000 - RW.SAFETY_MS, "délai du serveur moins la marge")
    RW.add(form, "rations")
    assertTrue(RW.canTransmit(form, form.deadline - 1), "encore valable")
    assertEq(RW.blocker(form, form.deadline), "expired", "expiré à l'échéance")
    assertEq(RW.clockText(272000), "4:32", "minutes et secondes")
    assertEq(RW.clockText(-5), "0:00", "jamais négatif")
    local default = RW.newForm({ requestId = 1, budget = 1, lots = {} }, 0)
    assertEq(default.deadline, RW.DEFAULT_EXPIRES_MS - RW.SAFETY_MS, "délai par défaut")
end

local function makeWindow(form)
    local player = { getPlayerNum = function() return 0 end, isDead = function() return false end }
    local window = RW:new(0, 0, 1920, 1080, player, nil, form)
    window.L = RW.computeLayout(form, 1920, 1080)
    RW.instances[0] = window
    return window
end

function T.transmit_sends_the_order_once_and_closes()
    local form = RW.newForm(formArgs(2, 12), NOW)
    local window = makeWindow(form)
    assertTrue(not window:transmit(), "rien de choisi : rien n'est envoyé")
    assertEq(#sent, 0, "aucun message")
    RW.add(form, "melee")
    assertTrue(window:transmit(), "transmis")
    assertEq(#sent, 1, "une commande")
    assertEq(sent[1].kind, "order", "RequisitionOrder")
    assertEq(sent[1].requestId, 7, "même requestId")
    assertEq(sent[1].order.melee, 1, "contenu")
    assertEq(sent[1].form, form, "formulaire gardé pour un renvoi")
    assertTrue(window.removed and RW.instances[0] == nil, "feuille fermée")
    assertTrue(not window:transmit(), "pas de second envoi")
    assertEq(#sent, 1, "toujours une commande")
end

function T.closing_cancels_and_expiry_blocks_transmission()
    local form = RW.newForm(formArgs(2, 12), NOW)
    local window = makeWindow(form)
    window:close()
    assertEq(#sent, 1, "fermer annule")
    assertEq(sent[1].kind, "cancel", "RequisitionCancel")
    assertEq(sent[1].requestId, 7, "même requestId")
    assertEq(sent[1].spoken, false, "fermeture silencieuse")
    window:close()
    assertEq(#sent, 1, "une seule annulation")
    -- Bouton « Annuler » : le personnage le dit.
    local window2 = makeWindow(RW.newForm(formArgs(2, 12), NOW))
    window2:activate("cancel")
    assertEq(sent[2].spoken, true, "annulation dite à la radio")
    -- Expiré : le bouton « Transmettre » est inactif, l'annulation reste possible.
    local expired = RW.newForm(formArgs(2, 12), NOW)
    RW.add(expired, "rations")
    local window3 = makeWindow(expired)
    NOW = expired.deadline + 1
    assertTrue(not window3:isEnabled("transmit"), "transmettre grisé")
    assertTrue(not window3:isEnabled("plus", "rations"), "+ grisé")
    assertTrue(window3:isEnabled("cancel"), "annuler possible")
    assertTrue(not window3:transmit(), "rien n'est envoyé")
    assertEq(window3:tooltipFor("transmit"), "IGUI_MilitaryDrop_ReqBlock_expired", "motif affiché")
    -- Réponse du serveur pendant que la feuille est ouverte : fermée sans message.
    local window4 = makeWindow(RW.newForm(formArgs(2, 12), NOW))
    local before = #sent
    RW.dismiss(7)
    assertTrue(window4.removed, "feuille fermée")
    assertEq(#sent, before, "aucune annulation envoyée")
end

function T.mouse_targets_and_joypad_steps()
    local form = RW.newForm(formArgs(3, 12), NOW)
    local window = makeWindow(form)
    local L = window.L
    local row = L.rows.rations
    local target, payload = window:hitTest(row.plus.x + 1, row.plus.y + 1)
    assertEq(target, "plus", "bouton +")
    assertEq(payload, "rations", "du bon lot")
    window:onMouseDown(row.plus.x + 1, row.plus.y + 1)
    window:onMouseUp(row.plus.x + 1, row.plus.y + 1)
    assertEq(form.qty.rations, 1, "clic sur + : un de plus")
    assertEq(window:hitTest(L.sectorBoxes.N.x + 1, L.sectorBoxes.N.y + 1), "sector", "case de secteur")
    assertEq(window:hitTest(L.transmit.x + 1, L.transmit.y + 1), "transmit", "bouton transmettre")
    assertTrue(window:tooltipFor("lot", "rations"):find("IGUI_MilitaryDrop_LotDesc_rations", 1, true) ~= nil,
        "infobulle : description du lot")
    -- Manette : la première ligne est le premier lot permis.
    window.cursor = 1
    window:stepCursor(1)
    assertEq(form.qty.rations, 2, "droite : +1")
    window:stepCursor(-1)
    window:stepCursor(-1)
    assertEq(form.qty.rations, 0, "gauche : -1")
    local nav = window:navigation()
    assertEq(#nav, 18 + 2, "18 lots permis, leurre, secteurs")
    window.cursor = #nav
    window:stepCursor(1)
    assertTrue(form.decoyOn and form.sector == "N", "secteurs : coche le leurre et choisit le premier")
    window:stepCursor(-1)
    assertEq(form.sector, "W", "tour de la rose vers la gauche")
    window.cursor = #nav - 1
    window:stepCursor(-1)
    assertTrue(not form.decoyOn, "leurre décoché")
end

return T
