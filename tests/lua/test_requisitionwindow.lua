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

function T.admin_lots_show_free_texts_in_the_client_language()
    local args = formArgs(1, 8)
    args.lots[#args.lots + 1] = { id = "admin1", group = 1, cost = 2, allowed = true,
        texts = { EN = { label = "Hunting kit", desc = "Rifle, knife and traps." },
            fr = { label = "Lot de chasse" }, DE = { label = 5 }, IT = "x" } }
    args.lots[#args.lots + 1] = { id = "admin2", group = 1, cost = 1, allowed = true,
        label = "IGUI_MilitaryDrop_Lot_rations", texts = { EN = { desc = string.rep("é", 400) } } }
    local form = RW.newForm(args, NOW)
    local hunting = form.byId.admin1
    -- Client en français (setup) : libellé FR, description absente en FR → anglais.
    assertEq(RW.lotLabel(hunting), "Lot de chasse", "libellé dans la langue du client (clé en minuscules admise)")
    assertEq(RW.lotDesc(hunting), "Rifle, knife and traps.", "description : repli sur l'anglais")
    -- Autre langue sans texte : anglais.
    Translator = { getLanguage = function() return { name = function() return "DE" end } end }
    assertEq(RW.lotLabel(hunting), "Hunting kit", "allemand : repli sur l'anglais (valeur non textuelle ignorée)")
    -- Langue de base (Language.base) : PTBR → PT.
    hunting.texts.PT = { label = "Kit de caça" }
    Translator = { getLanguage = function()
        return { name = function() return "PTBR" end, base = function() return "PT" end }
    end }
    assertEq(RW.lotLabel(hunting), "Kit de caça", "langue de base")
    -- Sans texte libre : clé de traduction, puis identifiant.
    assertEq(RW.lotLabel(form.byId.admin2), "IGUI_MilitaryDrop_Lot_rations", "clé de traduction")
    assertEq(RW.lotLabel(form.byId.rations), "IGUI_MilitaryDrop_Lot_rations", "lot ordinaire inchangé")
    assertEq(RW.lotDesc(form.byId.rations), "IGUI_MilitaryDrop_LotDesc_rations", "description ordinaire")
    local bare = RW.newForm({ requestId = 1, budget = 3, lots = { { id = "naked", allowed = true } } }, NOW)
    assertEq(RW.lotLabel(bare.byId.naked), "naked", "ni texte ni clé : identifiant")
    -- Description démesurée : bornée sans couper un caractère UTF-8.
    local long = RW.lotDesc(form.byId.admin2)
    assertTrue(#long <= RW.TEXT_LIMITS.desc, "description bornée")
    assertTrue(long:find("^[\195][\169]") ~= nil and #long % 2 == 0, "caractères entiers")
    -- Infobulle et disposition utilisent les textes libres.
    local window = makeWindow(form)
    Translator = { getLanguage = function() return { name = function() return "FR" end } end }
    local tip = window:tooltipFor("lot", "admin1")
    assertTrue(tip:find("Lot de chasse", 1, true) and tip:find("Rifle, knife and traps.", 1, true), "infobulle")
    checkLayout(RW.computeLayout(form, 1920, 1080), form, "lots de l'admin")
end

function T.client_text_falls_back_on_the_first_language()
    local args = formArgs(1, 8)
    args.lots[#args.lots + 1] = { id = "admin1", group = 1, cost = 1, allowed = true,
        texts = { IT = { label = "Cucina" }, DE = { label = "Küche", desc = "Töpfe." } } }
    local form = RW.newForm(args, NOW)
    -- Client en français, ni FR ni EN : première langue (ordre alphabétique), comme Lots.text.
    assertEq(RW.lotLabel(form.byId.admin1), "Küche", "DE avant IT")
    assertEq(RW.lotDesc(form.byId.admin1), "Töpfe.", "description : première langue qui la donne")
end

--- Formulaire de n lots ajoutés (paliers 1 à 3), libellés de longueur moyenne.
local function manyLots(n, withDecoy)
    local args = formArgs(3, 40, withDecoy)
    for i = 1, n - #args.lots do
        args.lots[#args.lots + 1] = { id = "extra" .. i, group = (i % 3) + 1, cost = 1, allowed = true,
            texts = { EN = { label = "Extra lot " .. i } } }
    end
    return RW.newForm(args, NOW)
end

--- Toutes les pages : chaque lot sur exactement une page, lignes entières dans
--- la feuille, feuille dans l'écran, taille constante.
local function checkPages(form, maxW, maxH, label, oversize)
    local L1 = RW.computeLayout(form, maxW, maxH)
    assertTrue(L1.paging ~= nil, label .. " : feuille paginée")
    local seen, pages = {}, L1.paging.pages
    for p = 1, pages do
        local L = RW.pageLayout(form, L1.paging, p)
        assertTrue(oversize or (L.W <= maxW and L.H <= maxH), label .. " : page " .. p .. " dans l'écran")
        assertEq(L.W, L1.W, label .. " : même largeur")
        assertEq(L.H, L1.H, label .. " : même hauteur")
        assertTrue(L.pagePrev and L.pageNext, label .. " : boutons de page")
        local whole = { x = 0, y = 0, w = L.W, h = L.H }
        for id, row in pairs(L.rows) do
            assertTrue(not seen[id], label .. " : " .. id .. " sur une seule page")
            seen[id] = p
            assertTrue(within(row.row, L.paper) and within(row.row, whole), label .. " : ligne " .. id .. " entière")
            assertTrue(disjoint(row.row, L.budget) and disjoint(row.row, L.transmit), label .. " : hors du pied")
            assertTrue(disjoint(row.row, L.pagePrev) and disjoint(row.row, L.pageNext), label .. " : hors des pages")
            assertEq(L1.paging.pageOf[id], p, label .. " : index des pages")
        end
        assertTrue(within(L.transmit, L.paper) and within(L.budget, L.paper), label .. " : pied sur la feuille")
        if L.decoyRow then
            assertEq(p, pages, label .. " : leurre en dernière page")
            assertTrue(within(L.sectorsArea, L.paper), label .. " : rose des vents entière")
        end
    end
    for _, lot in ipairs(form.lots) do
        assertTrue(seen[lot.id] ~= nil, label .. " : lot " .. lot.id .. " présent")
    end
    return L1
end

function T.long_section_continues_in_the_next_column()
    useTexts(FRENCH)
    local args = { requestId = 3, budget = 40, tier = 3, lots = {} }
    for i = 1, 24 do
        args.lots[i] = { id = "l" .. i, group = 1, cost = 1, allowed = true, texts = { EN = { label = "Lot " .. i } } }
    end
    local form = RW.newForm(args, NOW)
    local L = RW.computeLayout(form, 1920, 1080)
    assertEq(L.cols, 2, "une seule section, deux colonnes")
    assertEq(#L.sectionsAt, 2, "titre répété en tête de la seconde colonne")
    assertEq(L.sectionsAt[1].label, L.sectionsAt[2].label, "même palier")
    assertTrue(L.sectionsAt[2].x > L.sectionsAt[1].x, "dans la colonne de droite")
    checkLayout(L, form, "section longue")
end

function T.many_lots_use_columns_or_pages_without_cutting_a_row()
    useTexts(FRENCH)
    local form = manyLots(40)
    -- Grand écran : tout tient, sans page (trois colonnes au besoin).
    local big = RW.computeLayout(form, 1920, 1080)
    assertEq(big.paging, nil, "1920 x 1080 : sans page")
    assertTrue(big.W <= 1920 and big.H <= 1080, "tient")
    checkLayout(big, form, "40 lots")
    assertTrue(big.cols >= 2, "plusieurs colonnes")
    -- Écran partagé en quatre (960 x 540) et écran étroit et bas : pages.
    checkPages(form, 960, 540, "écran partagé")
    checkPages(form, 560, 540, "étroit et bas")
    -- Écran partagé en quatre à 1280 x 720.
    checkPages(form, 640, 360, "quatre joueurs en 720p")
    -- Plus petit que le pied et l'en-tête : le moins débordant, paginé quand même.
    local tiny = checkPages(form, 480, 200, "minuscule", true)
    assertTrue(tiny.paging.pages >= 2, "plusieurs pages")
end

function T.paged_sheet_follows_the_cursor_and_the_wheel()
    useTexts(FRENCH)
    local form = manyLots(40)
    local player = { getPlayerNum = function() return 0 end, isDead = function() return false end }
    local window = RW:new(0, 0, 960, 540, player, nil, form)
    window.maxWidth, window.maxHeight = 960, 540
    window:layout()
    assertTrue(window.L.paging ~= nil and window.page == 1, "page 1")
    local pages = window.L.paging.pages
    assertTrue(not window:isEnabled("pagePrev") and window:isEnabled("pageNext"), "boutons de page")
    local L = window.L
    window:onMouseDown(L.pageNext.x + 1, L.pageNext.y + 1)
    window:onMouseUp(L.pageNext.x + 1, L.pageNext.y + 1)
    assertEq(window.page, 2, "clic sur > : page suivante")
    assertTrue(window:onMouseWheel(-1) and window.page == 1, "molette : page précédente")
    window:onMouseWheel(-1)
    assertEq(window.page, 1, "bornée")
    -- Manette : la page suit la ligne choisie.
    local nav = window:navigation()
    window.cursor = 1
    window:moveCursor(#nav)
    assertEq(window.page, pages, "dernière ligne (secteurs) : dernière page")
    assertTrue(window.L.decoyRow ~= nil, "leurre affiché")
    window:moveCursor(-#nav)
    assertEq(window.page, 1, "première ligne : première page")
    -- Le lot choisi est sur la page affichée et cliquable.
    local id = nav[1].id
    local row = window.L.rows[id]
    assertTrue(row ~= nil, "ligne du curseur affichée")
    local target, payload = window:hitTest(row.plus.x + 1, row.plus.y + 1)
    assertEq(target, "plus", "bouton + de la page")
    assertEq(payload, id, "du bon lot")
    window:stepCursor(1)
    assertEq(form.qty[id], 1, "droite : +1 sur la page")
end

function T.sheet_is_anchored_to_the_radio_window()
    local screen = { x = 0, y = 0, w = 1920, h = 1080 }
    local x, y = RW.anchoredPosition(500, 600, { x = 100, y = 50, w = 300, h = 700 }, screen)
    assertEq(x, 400, "collée à droite de la fenêtre radio")
    assertEq(y, 50, "alignée sur son haut")
    x, y = RW.anchoredPosition(500, 600, { x = 1500, y = 700, w = 300, h = 300 }, screen)
    assertEq(x, 1000, "déborde à droite : collée à gauche")
    assertEq(y, 480, "ramenée dans l'écran en hauteur")
    -- Écran partagé (joueur 2 à droite, écran étroit) : ni d'un côté ni de l'autre → dans l'écran.
    local half = { x = 960, y = 0, w = 960, h = 1080 }
    x = RW.anchoredPosition(700, 600, { x = 1100, y = 0, w = 300, h = 500 }, half)
    assertTrue(x >= half.x and x + 700 <= half.x + half.w, "reste dans l'écran du joueur")
    -- Fenêtre d'ancrage : seulement si elle est encore affichée.
    local anchor = { visible = true, getIsVisible = function(self) return self.visible end,
        getAbsoluteX = function() return 10 end, getAbsoluteY = function() return 20 end,
        getWidth = function() return 300 end, getHeight = function() return 400 end }
    local r = RW.anchorRect(anchor)
    assertEq(r.x + r.w, 310, "rectangle de la fenêtre")
    anchor.visible = false
    assertEq(RW.anchorRect(anchor), nil, "fenêtre fermée : pas d'ancre")
    assertEq(RW.anchorRect(nil), nil, "pas d'ancre : centrée")
    -- Ouverture réelle : position ancrée transmise à la fenêtre.
    getPlayerScreenWidth = function() return 1920 end
    getPlayerScreenHeight = function() return 1080 end
    getPlayerScreenLeft = function() return 0 end
    getPlayerScreenTop = function() return 0 end
    function ISPanelJoypad:initialise() end
    function ISPanelJoypad:instantiate() end
    function ISPanelJoypad:addToUIManager() end
    anchor.visible = true
    local player = { getPlayerNum = function() return 0 end, isDead = function() return false end }
    local window = RW.open(player, nil, formArgs(1, 8, false), NOW, anchor)
    assertEq(window.x, 310, "feuille à droite de la fenêtre radio")
    assertEq(window.y, 20, "même hauteur")
    local centred = RW.open(player, nil, formArgs(1, 8, false), NOW)
    assertEq(centred.x, math.floor((1920 - centred.width) / 2), "sans ancre : centrée")
end

return T
