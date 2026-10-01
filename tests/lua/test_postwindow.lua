-- MilitaryDrop_PostWindow : console « poste radio militaire » (client).
-- Disposition mesurée selon la langue (aucun texte ne déborde, petit écran),
-- voyants sans indice sur la fréquence, ordres de mission (barres), galons sans
-- chiffre, plaques du casier ({ id, name, by }), troncature sans caractère
-- coupé, plaques du joueur par MilitaryDrop.Exchange et repli sans lui,
-- bouton « Demander un largage » (v1.4).
-- Les tests du protocole avec le serveur sont dans test_post.lua.

local T = {}

local CHAR_W = 7
local FONT_H = 14

local function arrayList(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end

function T.setup()
    SandboxVars = { MilitaryDrop = { Frequency = 151.4 } }
    isClient = function() return true end
    isServer = function() return false end
    getText = function(k, a, b) return k .. "|" .. tostring(a) .. "|" .. tostring(b) end
    getTimestampMs = function() return 0 end
    ItemTag = { DOG_TAG = "base:dogtag" }
    ISPanelJoypad = { derive = function(self, name)
        return setmetatable({ Type = name }, { __index = self })
    end }
    UIFont = { Small = "Small", Medium = "Medium", CodeSmall = "CodeSmall" }
    getTextManager = function()
        return {
            getFontHeight = function() return FONT_H end,
            -- Octets : un caractère accentué compte double, comme une police plus large.
            MeasureStringX = function(_, _, s) return #s * CHAR_W end,
        }
    end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Exchange.lua")
    MilitaryDrop.Client = { HANDLERS = {} }
    loadMod("client/MilitaryDrop/MilitaryDrop_PostWindow.lua")
    W = MilitaryDrop.PostWindow
end

local function measure(s)
    return #tostring(s) * CHAR_W
end

local function within(inner, outer)
    return inner.x >= outer.x and inner.y >= outer.y and inner.x + inner.w <= outer.x + outer.w
        and inner.y + inner.h <= outer.y + outer.h
end

local function disjoint(a, b)
    return a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y
end

local function sampleData()
    return { callsign = "Station Kilo-7", channel = 151400, on = true, power = "grid", tier = 3,
        lines = {}, missions = {}, mail = {} }
end

function T.layout_widths_follow_the_texts()
    -- Libellés longs (autre langue, police plus grande) : colonnes élargies.
    getText = function(k, a)
        if k == "IGUI_MilitaryDrop_PostDeposit" then
            return "Deposit the identification tags of the fallen (" .. tostring(a) .. ")"
        end
        return k .. "|" .. tostring(a)
    end
    local L = W.computeLayout(sampleData())
    local whole = { x = 0, y = 0, w = L.W, h = L.H }
    local label = getText("IGUI_MilitaryDrop_PostDeposit", "99")
    assertTrue(measure(label) <= L.deposit.w - 2 * L.u, "le libellé du dépôt tient dans le bouton")
    assertTrue(measure(getText("IGUI_MilitaryDrop_PostTransmit")) <= L.transmit.w - 2 * L.u, "transmettre tient")
    for _, name in ipairs({ "header", "status", "bezelRect", "orders", "rack", "standing", "close", "deposit",
        "transmit", "standText", "tape", "freq" }) do
        assertTrue(within(L[name], whole), name .. " dans la fenêtre")
    end
    assertTrue(disjoint(L.orders, L.rack) and disjoint(L.rack, L.standing), "colonnes sans chevauchement")
    assertTrue(disjoint(L.tape, L.freq) and disjoint(L.lampsArea, L.tape), "rangée d'état sans chevauchement")
    assertTrue(#L.cards >= 3, "trois ordres visibles")
    assertTrue(#L.slots >= 4, "au moins deux rangées de plaques")
    for _, slot in ipairs(L.slots) do
        assertTrue(within(slot, L.rack) and slot.y + slot.h <= L.deposit.y, "plaques au-dessus des boutons")
    end
    assertTrue(within(L.journal, L.screen), "journal sur le verre")
    -- Ruban : l'indicatif mesuré tient.
    local data = sampleData()
    data.callsign = "Station November-99 bis"
    local L2 = W.computeLayout(data)
    assertTrue(measure(data.callsign) <= L2.tape.w - 2 * L2.u, "indicatif long : ruban élargi")
end

function T.layout_shrinks_the_journal_on_a_small_screen()
    local big = W.computeLayout(sampleData())
    assertEq(big.journalLines, W.JOURNAL_LINES, "écran large : toutes les lignes")
    local small = W.computeLayout(sampleData(), 960, big.H - 3 * FONT_H)
    assertTrue(small.H <= big.H - 3 * FONT_H, "la console tient dans l'écran du joueur")
    assertTrue(small.journalLines >= W.JOURNAL_MIN_LINES and small.journalLines < W.JOURNAL_LINES,
        "journal raccourci")
end

function T.lamps_never_reveal_the_frequency()
    local data = sampleData()
    data.lines = { { c = 1, t = "hello" }, { c = 2, sys = "moved" } }
    local lamps = W.lamps(data)
    assertTrue(lamps.on and lamps.rx and lamps.power, "allumé, dernière ligne reçue (entrée système ignorée)")
    data.lines[#data.lines + 1] = { c = 3, gap = 2 }
    assertTrue(not W.lamps(data).rx, "aucune réception : voyant éteint")
    data.power = "none"
    lamps = W.lamps(data)
    assertTrue(not lamps.on and not lamps.rx and not lamps.power, "sans courant : tout est éteint")
    data.power, data.battery = "battery", 0.1
    assertEq(W.lamps(data).level, "low", "pile presque vide")
    data.battery = nil
    assertEq(W.lamps(data).level, "battery", "pile, charge inconnue")
    assertEq(W.lamps(data).battery, nil, "pas de jauge sans la charge")
    assertEq(W.lastReceivedKey({ lines = { { c = 1, t = "a" }, { c = 2, gap = 1 } } }), "1|a", "dernière ligne reçue")
end

function T.mission_orders_show_deadline_grid_and_bar()
    local recon = W.missionView({ kind = "recon", title = "Recon", remaining = 31.2, x = 10874, y = 9512 })
    assertEq(recon.due, "IGUI_MilitaryDrop_PostDue|32|nil", "échéance arrondie au-dessus")
    assertEq(recon.sub, "IGUI_MilitaryDrop_PostGrid|10874|9512", "grille")
    assertEq(recon.bar.kind, "time", "barre du temps restant")
    assertTrue(math.abs(recon.bar.fraction - 31.2 / 48) < 1e-6, "durée par défaut de l'option ReconHours")
    local sent = W.missionView({ kind = "recon", remaining = 6, hours = 12 })
    assertEq(sent.bar.fraction, 0.5, "durée envoyée par le serveur d'abord")
    local cleanup = W.missionView({ kind = "cleanup", remaining = 50, progress = 12, quota = 30 })
    assertEq(cleanup.bar.kind, "progress", "nettoyage : progression")
    assertEq(cleanup.bar.label, "12 / 30", "compte affiché")
    local control = W.missionView({ kind = "control", remaining = 0.5, progress = 1, quota = 1 })
    assertEq(control.due, "IGUI_MilitaryDrop_PostDueSoon|nil|nil", "moins d'une heure")
    assertEq(control.sub, "IGUI_MilitaryDrop_PostControlDone|nil|nil", "réponse donnée")
    assertTrue(control.done and control.bar.urgent, "fait, et presque échu")
    local unknown = W.missionView({ kind = "other", title = "X" })
    assertEq(unknown.bar, nil, "sans échéance ni quota : pas de barre")
    assertTrue(W.missionTooltip({ title = "<b>", text = "a <LINE> b" }):find("&lt;LINE&gt;", 1, true) ~= nil,
        "texte de la base échappé dans l'infobulle")
end

function T.standing_is_plain_words_never_a_number()
    assertEq(W.trustText({ tier = 3 }), "IGUI_MilitaryDrop_PostTrust3|nil|nil", "phrase du commandement")
    assertEq(W.effectText({ tier = 3 }), "IGUI_MilitaryDrop_PostEffect3|nil|nil", "effet sur les largages")
    assertEq(W.trustText({ tier = 3, lineCut = true }), "IGUI_MilitaryDrop_PostLineCut|nil|nil",
        "ligne coupée d'abord")
    assertEq(W.effectText({ tier = 4, lineCut = true }), "IGUI_MilitaryDrop_PostEffectLineCut|nil|nil",
        "aucun largage")
    assertEq(W.effectText({ tier = 9 }), "", "palier invalide")
    assertEq(W.trustText({}), "", "rien sans palier")
end

function T.mail_entries_carry_the_soldier_name()
    assertEq(W.mailName({ id = "1", name = "John Doe", by = "alice" }), "John Doe", "nom du soldat")
    assertEq(W.mailName({ serial = "123" }), "123", "ancien format")
    assertEq(W.mailName({}), "?", "inconnu")
end

function T.fit_never_cuts_a_character()
    local text = W.fit("ééééééééé", UIFont.Small, 6 * CHAR_W)
    assertEq(text:sub(-3), "...", "trois points")
    assertEq((#text - 3) % 2, 0, "aucun caractère accentué coupé")
    assertTrue(measure(text) <= 6 * CHAR_W, "tient dans la largeur")
    assertEq(W.fit("abc", UIFont.Small, 100), "abc", "texte court inchangé")
    local lines = W.wrap("Le commandement vous fait confiance", UIFont.Small, 16 * CHAR_W)
    assertEq(#lines, 3, "coupé aux mots")
    for _, line in ipairs(lines) do
        assertTrue(measure(line) <= 16 * CHAR_W, "ligne dans la largeur")
    end
end

local function makeItem(name, id, tagged)
    return {
        hasTag = function() return tagged end,
        getDisplayName = function() return name end,
        getScriptItem = function() return { getDisplayName = function() return "Dog Tag" end } end,
        getID = function() return id end,
        getFullType = function() return "Base.Whatever" end,
    }
end

function T.player_dog_tags_come_from_the_exchange_module()
    local own = makeItem("Dog Tag: Bob Smith", 1, true)
    local other = makeItem("Dog Tag: John Doe", 2, true)
    local blank = makeItem("Dog Tag", 3, true)
    local worn = makeItem("Dog Tag: Jane Roe", 4, true)
    local items = { own, other, blank, worn }
    ArrayList = { new = function() return {} end }
    local player = {
        getInventory = function()
            return {
                getAllTagRecurse = function() return arrayList(items) end,
                getAllEvalRecurse = function(_, predicate)
                    local found = {}
                    for _, item in ipairs(items) do
                        if predicate(item) then
                            found[#found + 1] = item
                        end
                    end
                    return arrayList(found)
                end,
            }
        end,
        getDescriptor = function()
            return { getForename = function() return "Bob" end, getSurname = function() return "Smith" end }
        end,
        isEquipped = function(_, item) return item == worn end,
        isAttachedItem = function() return false end,
    }
    local tags = W.dogTags(player)
    assertEq(#tags, 1, "ni la sienne, ni la vierge, ni celle portée")
    assertEq(W.dogTagLabel(tags[1]), "John Doe", "nom gravé")
    -- Sans le module d'échange : étiquette du jeu seule (repli).
    MilitaryDrop.Exchange = nil
    assertEq(#W.dogTags(player), 3, "repli : toutes les plaques non portées")
    assertEq(W.dogTagLabel(other), "Dog Tag: John Doe", "repli : nom de l'objet")
end

function T.request_button_calls_the_base_like_the_radio_menu()
    getText = function(k, a)
        if k == "IGUI_MilitaryDrop_RequestDrop" then
            return "Demander un largage de ravitaillement"
        end
        return k .. "|" .. tostring(a)
    end
    local L = W.computeLayout(sampleData())
    assertTrue(within(L.request, L.standing), "bouton dans la colonne de confiance")
    assertTrue(disjoint(L.request, L.standText), "sous le texte de confiance")
    assertTrue(measure(getText("IGUI_MilitaryDrop_RequestDrop")) <= L.request.w - 2 * L.u, "libellé entier")
    assertTrue(L.standText.h >= 4 * FONT_H, "place pour la phrase et l'effet")
    -- Même appel que le menu de la radio, par la radio du poste ; la console se ferme.
    local calls = {}
    MilitaryDrop.Client.onRequest = function(player, device, force)
        calls[#calls + 1] = { player = player, device = device, force = force }
    end
    local player = { getPlayerNum = function() return 0 end, isDead = function() return false end,
        getX = function() return 10.5 end, getY = function() return 10.5 end, getZ = function() return 0 end }
    local object = { getObjectIndex = function() return 3 end,
        getSquare = function() return { getX = function() return 10 end, getY = function() return 10 end,
            getZ = function() return 0 end } end }
    local closed = false
    local window = setmetatable({ player = player, object = object, data = sampleData(), L = L,
        close = function() closed = true end }, { __index = W })
    assertTrue(window:canRequest(), "poste allumé et alimenté")
    assertEq(window:hitTest(L.request.x + 1, L.request.y + 1), "request", "cible du clic")
    window:onRequest()
    assertEq(#calls, 1, "un appel")
    assertEq(calls[1].device, object, "radio du poste")
    assertEq(calls[1].force, false, "jamais un largage admin")
    assertTrue(closed, "console fermée")
    window.data = sampleData()
    window.data.power = "none"
    assertTrue(not window:canRequest(), "sans courant : grisé")
    window:onRequest()
    assertEq(#calls, 1, "aucun appel sans courant")
end

return T
