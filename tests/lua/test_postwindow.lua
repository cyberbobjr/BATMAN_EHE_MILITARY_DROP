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
    -- Libellés longs (autre langue, police plus grande) : volet élargi.
    getText = function(k, a)
        if k == "IGUI_MilitaryDrop_PostDeposit" then
            return "Deposit the identification tags of the fallen (" .. tostring(a) .. ")"
        end
        return k .. "|" .. tostring(a)
    end
    local L = W.computeLayout(sampleData())
    local whole = { x = 0, y = 0, w = L.W, h = L.H }
    local label = getText("IGUI_MilitaryDrop_PostDeposit", "99")
    assertTrue(measure(label) <= L.btnB.w - 2 * L.u, "le libellé du dépôt tient dans son bouton")
    for _, key in ipairs({ "IGUI_MilitaryDrop_PostRecorderSend", "IGUI_MilitaryDrop_PostRecorderInsert",
        "IGUI_MilitaryDrop_PostTransmit" }) do
        assertTrue(measure(getText(key)) <= L.btnA.w - 2 * L.u, key .. " tient")
    end
    for _, name in ipairs({ "header", "status", "bezelRect", "list", "detail", "strip", "close", "btnA", "btnB",
        "request", "standText", "tape", "freq" }) do
        assertTrue(within(L[name], whole), name .. " dans la fenêtre")
    end
    assertTrue(disjoint(L.list, L.detail) and disjoint(L.list, L.strip) and disjoint(L.detail, L.strip),
        "liste, volet et bande sans chevauchement")
    assertTrue(disjoint(L.tape, L.freq) and disjoint(L.lampsArea, L.tape), "rangée d'état sans chevauchement")
    assertTrue(disjoint(L.btnA, L.btnB), "deux boutons côte à côte")
    for _, name in ipairs({ "detailTape", "info", "well", "btnA", "btnB", "missionCard" }) do
        assertTrue(within(L[name], L.detail), name .. " dans le volet")
    end
    assertTrue(L.well.y + L.well.h <= L.btnA.y and L.info.y + L.info.h <= L.well.y, "fiche, baie, puis boutons")
    assertTrue(within(L.box, L.well) and within(L.progress, L.well) and disjoint(L.box, L.progress),
        "logement et barre dans la baie")
    assertTrue(#L.slots >= 4, "au moins deux rangées de plaques")
    for _, slot in ipairs(L.slots) do
        assertTrue(within(slot, L.detail) and slot.y + slot.h <= L.tagsHint.y, "plaques au-dessus de la consigne")
    end
    assertTrue(L.tagsHint.y + L.tagsHint.h <= L.btnA.y, "consigne au-dessus des boutons")
    assertTrue(within(L.listArea, L.list) and L.listArea.h >= 4 * L.rowH, "au moins quatre affaires visibles")
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
    local spare = (W.JOURNAL_LINES - W.JOURNAL_MIN_LINES) * FONT_H
    local small = W.computeLayout(sampleData(), 960, big.H - spare)
    assertTrue(small.H <= big.H - spare, "la console tient dans l'écran du joueur")
    assertEq(small.journalLines, W.JOURNAL_MIN_LINES, "journal raccourci au minimum")
end

function T.lamps_never_reveal_the_frequency()
    local data = sampleData()
    data.lines = { { c = 1, t = { text = "hello" } }, { c = 2, sys = "moved" } }
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
    assertEq(W.lastReceivedKey({ lines = { { c = 1, t = { text = "a" } }, { c = 2, gap = 1 } } }), "1|a", "dernière ligne reçue")
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

function T.cleanup_order_shows_team_kills_and_what_is_left()
    local pending = W.missionView({ kind = "cleanup", remaining = 60, hours = 72, x = 300, y = 400,
        progress = 0, spotted = false })
    assertEq(pending.sub, "IGUI_MilitaryDrop_PostGrid|300|400 - IGUI_MilitaryDrop_PostCleanupPending|nil|nil",
        "grille, horde pas encore repérée")
    assertEq(pending.bar.kind, "time", "barre du temps")
    assertTrue(not pending.done, "pas fait")
    local spotted = W.missionView({ kind = "cleanup", remaining = 40, hours = 72, x = 300, y = 400,
        progress = 4, spotted = true, left = 14, down = 13, target = 27 })
    assertEq(spotted.bar.kind, "progress", "barre de la horde")
    assertTrue(math.abs(spotted.bar.fraction - 13 / 27) < 1e-6, "morts de la horde vers l'objectif")
    assertEq(spotted.bar.label, "IGUI_MilitaryDrop_PostCleanupProgress|4|14", "abattus par la station, reste")
    assertTrue(not spotted.done, "pas de tampon « fait »")
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
    assertTrue(within(L.request, L.strip), "bouton dans la bande du bas")
    assertTrue(disjoint(L.request, L.standText) and L.standText.x + L.standText.w <= L.request.x,
        "confiance à gauche du bouton")
    assertTrue(measure(getText("IGUI_MilitaryDrop_RequestDrop")) <= L.request.w - 2 * L.u, "libellé entier")
    assertTrue(L.standText.w >= 10 * FONT_H, "place pour la confiance sur une ligne")
    -- Même appel que la fenêtre radio, par la radio du poste, avec le code du champ.
    local calls = {}
    MilitaryDrop.Client.call = function(player, device, code, force, opts)
        calls[#calls + 1] = { player = player, device = device, code = code, force = force,
            anchor = type(opts) == "table" and opts.anchor or nil }
    end
    local player = { getPlayerNum = function() return 0 end, isDead = function() return false end,
        getX = function() return 10.5 end, getY = function() return 10.5 end, getZ = function() return 0 end }
    local object = { getObjectIndex = function() return 3 end,
        getSquare = function() return { getX = function() return 10 end, getY = function() return 10 end,
            getZ = function() return 0 end } end }
    local closed = false
    local typed = ""
    local window = setmetatable({ player = player, playerNum = 0, object = object, data = sampleData(), L = L,
        codeEntry = { getText = function() return typed end },
        close = function() closed = true end }, { __index = W })
    assertEq(window:requestReason(), "IGUI_MilitaryDrop_RadioModule_NeedCode", "code exigé : grisé sans code")
    assertTrue(window:tooltipFor("request"):find("NeedCode", 1, true) ~= nil, "raison dans l'infobulle")
    typed = "  bravo-kilo-42 "
    assertTrue(window:canRequest(), "poste allumé et alimenté, code saisi")
    assertEq(window:hitTest(L.request.x + 1, L.request.y + 1), "request", "cible du clic")
    window:onRequest()
    assertEq(#calls, 1, "un appel")
    assertEq(calls[1].device, object, "radio du poste")
    assertEq(calls[1].code, "bravo-kilo-42", "code du champ, sans espaces")
    assertEq(calls[1].force, false, "jamais un largage admin")
    assertTrue(not closed, "console gardée ouverte")
    assertEq(calls[1].anchor, window, "feuille collée à la console")
    window.data = sampleData()
    window.data.power = "none"
    assertTrue(not window:canRequest(), "sans courant : grisé")
    window:onRequest()
    assertEq(#calls, 1, "aucun appel sans courant")
    -- Sans code exigé : appel sans code.
    SandboxVars.MilitaryDrop.AuthCode = MilitaryDrop.Codes.MODE_NONE
    window.data = sampleData()
    typed = ""
    window:onRequest()
    assertEq(calls[2].code, nil, "aucun code envoyé")
end

function T.code_field_sits_above_the_request_button()
    getText = function(k, a)
        if k == "IGUI_MilitaryDrop_RadioModule_Code" then
            return "Code d'authentification"
        end
        return k .. "|" .. tostring(a)
    end
    local L = W.computeLayout(sampleData())
    assertTrue(L.codeShown, "code exigé par défaut")
    assertTrue(within(L.code, L.strip), "champ dans la bande du bas")
    assertTrue(disjoint(L.code, L.request) and L.code.x + L.code.w <= L.request.x, "à gauche du bouton")
    assertTrue(L.standText.x + L.standText.w <= L.codeLabelPos.x, "confiance à gauche du libellé")
    assertTrue(L.code.w >= measure("888888"), "assez large pour un code")
    assertTrue(L.codeLabelPos.x + L.codeLabelW <= L.code.x, "libellé à gauche du champ")
    SandboxVars.MilitaryDrop.AuthCode = MilitaryDrop.Codes.MODE_NONE
    local plain = W.computeLayout(sampleData())
    assertTrue(not plain.codeShown and plain.code == nil, "sans code exigé : pas de champ")
end

function T.console_code_is_kept_and_typed_with_the_joypad()
    local kept = {}
    MilitaryDrop.Client.rememberCode = function(playerNum, code) kept[#kept + 1] = playerNum .. ":" .. code end
    local typed = " x-1 "
    local window = setmetatable({ playerNum = 1, data = sampleData(), L = W.computeLayout(sampleData()),
        codeEntry = { getText = function() return typed end } }, { __index = W })
    window:onCodeChange()
    assertEq(kept[1], "1:x-1", "gardé pour le joueur local (écran partagé)")
    typed = ""
    window:onCodeChange()
    assertEq(kept[2], "1:", "effacé")
    -- Manette : Y ouvre le clavier à l'écran tant que le code manque.
    Joypad = { AButton = 0, BButton = 1, XButton = 2, YButton = 3, RBumper = 5 }
    local shown
    OnScreenKeyboard = { IsVisible = function() return false end,
        Show = function(playerNum, entry) shown = { playerNum = playerNum, entry = entry } return {} end }
    JoypadState = { players = { {}, { focus = window } } }
    getText = function(k) return k end
    assertEq(window:getYPrompt(), "IGUI_MilitaryDrop_RadioModule_TypeCode", "Y : saisir le code")
    window:onJoypadDown(Joypad.YButton)
    assertTrue(shown and shown.entry == window.codeEntry and shown.playerNum == 1, "clavier à l'écran vanilla")
    assertTrue(JoypadState.players[2].focus.prevFocus == window, "retour à la console après la saisie")
    typed = "x-1"
    assertEq(window:getYPrompt(), "IGUI_MilitaryDrop_RequestDrop", "code saisi : Y appelle")
end

-- ----------------------------------------------------------------------------
-- Tableau des affaires et baie de lecture (POSTE-08, SRC-08)
-- ----------------------------------------------------------------------------

local function recorderItem(id, site, extra)
    local data = { MilitaryDrop_crashSite = site }
    for name, value in pairs(extra or {}) do
        data[name] = value
    end
    return { getID = function() return id end, getFullType = function() return "MilitaryDrop.FlightRecorder" end,
        getModData = function() return data end }
end

local function keysOf(list)
    local out = {}
    for _, entry in ipairs(list) do
        out[#out + 1] = entry.key or ("[" .. entry.kind .. "]")
    end
    return table.concat(out, " ")
end

function T.affairs_list_recorders_tags_then_orders()
    local data = sampleData()
    data.bay = { site = "W3", progress = 0.4 }
    data.mail = { { id = "1", name = "John Doe", by = "alice" } }
    data.missions = { { kind = "recon", title = "Recon", remaining = 40, hours = 48, x = 1711, y = 6016 },
        { kind = "control", title = "Control", remaining = 2, hours = 4, progress = 0, quota = 1 } }
    local list = W.affairs(data, { recorderItem(7, "W3"), recorderItem(8, "W5", { MilitaryDrop_crashX = 10 }) }, 2)
    assertEq(keysOf(list), "[header] bay rec:W5 tags [header] mission:recon mission:control",
        "à traiter (baie, inventaire, plaques), puis ordres")
    assertEq(list[2].icon, "MilitaryDrop.FlightRecorder", "icône de l'enregistreur")
    assertEq(list[2].sub, "IGUI_MilitaryDrop_PostRecorderReading|40|nil", "lecture en pour-cent")
    assertEq(list[2].lamp, "amber", "voyant ambre pendant la lecture")
    assertEq(list[3].itemId, 8, "objet à insérer")
    assertEq(list[3].cx, 10, "point du crash lu sur l'objet")
    assertEq(list[4].icon, "Base.Necklace_DogTag", "icône de la plaque vanilla")
    assertEq(list[4].sub, "IGUI_MilitaryDrop_PostTagsCount|1|2", "au poste, sur moi")
    assertEq(list[6].title, "Recon", "ordre de la base")
    data.bay.paused = true
    assertEq(W.affairs(data, {}, 0)[2].lamp, "red", "voyant rouge en pause")
    data.bay.done = true
    assertEq(W.affairs(data, {}, 0)[2].sub, "IGUI_MilitaryDrop_PostRecorderDone|nil|nil", "lu")
    data.missions = {}
    data.bay = nil
    local empty = W.affairs(data, {}, 0)
    assertEq(keysOf(empty), "[header] tags [header] [empty]", "sans mission : mention, plaques toujours là")
    assertEq(W.pickAffair(list, "rec:W5").key, "rec:W5", "sélection gardée")
    assertEq(W.pickAffair(list, "gone").key, "bay", "sinon la première ligne")
end

function T.inventory_recorders_are_one_per_site_and_not_worn()
    local a, b, c = recorderItem(1, "W3"), recorderItem(2, "W3"), recorderItem(3, "W4")
    local other = { getFullType = function() return "Base.Battery" end, getModData = function() return {} end }
    local blank = recorderItem(4, nil)
    local items = { a, b, c, other, blank }
    ArrayList = { new = function() return {} end }
    local player = {
        getInventory = function()
            return { getAllEvalRecurse = function(_, predicate)
                local found = {}
                for _, item in ipairs(items) do
                    if predicate(item) then
                        found[#found + 1] = item
                    end
                end
                return arrayList(found)
            end }
        end,
        isEquipped = function(_, item) return item == c end,
        isAttachedItem = function() return false end,
    }
    local found = W.recorders(player)
    assertEq(#found, 1, "un par site, ni objet porté, ni autre objet, ni enregistreur sans site")
    assertEq(found[1], a, "le premier du site")
end

local function window(data, recorders, tags)
    -- Radio posée du poste (référence envoyée au serveur : case et index).
    instanceof = function(_, class) return class == "IsoWaveSignal" end
    local sent = {}
    MilitaryDrop.Net.toServer = function(_, name, args) sent[#sent + 1] = { name = name, args = args } end
    local said = {}
    local player = { getPlayerNum = function() return 0 end, isDead = function() return false end,
        getX = function() return 10.5 end, getY = function() return 10.5 end, getZ = function() return 0 end,
        Say = function(_, text) said[#said + 1] = text end }
    local object = { getObjectIndex = function() return 0 end }
    local square = { getX = function() return 10 end, getY = function() return 10 end,
        getZ = function() return 0 end,
        getObjects = function() return { indexOf = function(_, o) return o == object and 0 or -1 end } end }
    object.getSquare = function() return square end
    local w = setmetatable({ player = player, playerNum = 0, object = object, data = data,
        L = W.computeLayout(data), tagCount = tags or 0, tagLabels = {}, recorderItems = recorders or {},
        affairList = {}, rackScroll = 0, listScroll = 0 }, { __index = W })
    w:refreshAffairs()
    return w, sent, said
end

function T.each_affair_has_its_own_actions()
    getSoundManager = function() return { playUISound = function() end } end
    local data = sampleData()
    data.bay = { site = "W3", progress = 0.5, total = 0.5 }
    local w, sent, said = window(data, { recorderItem(8, "W5") }, 1)
    assertEq(w.selectedKey, "bay", "la baie d'abord")
    local primary, secondary = w:actions()
    assertEq(primary.text, "IGUI_MilitaryDrop_PostRecorderSend|nil|nil", "transmettre à droite")
    assertTrue(not primary.enabled and primary.reason == "IGUI_MilitaryDrop_PostResult_notRead",
        "grisé tant que la lecture n'est pas finie")
    assertTrue(secondary.enabled, "retirer, toujours possible")
    data.bay.done = true
    primary = w:actions()
    assertTrue(primary.enabled, "lu, poste allumé : transmettre")
    assertEq(w:hitTest(w.L.btnA.x + 1, w.L.btnA.y + 1), "primary", "bouton de droite")
    w:activate("primary")
    assertEq(sent[#sent].name, "PostRecorderTransmit", "commande envoyée")
    assertEq(said[1], "IGUI_MilitaryDrop_PostRecorderSendSay|Station Kilo-7|nil", "le personnage parle")
    data.power = "none"
    assertEq(w:sendReason(), "IGUI_MilitaryDrop_TurnOn", "sans courant : grisé")
    data.power = "grid"
    w:activate("secondary")
    assertEq(sent[#sent].name, "PostRecorderEject", "retirer de la baie")
    -- Enregistreur de l'inventaire : baie occupée, puis libre.
    w:select("rec:W5")
    primary, secondary = w:actions()
    assertTrue(secondary == nil, "une seule action")
    assertTrue(not primary.enabled and primary.reason == "IGUI_MilitaryDrop_PostResult_bayBusy", "baie occupée")
    data.bay = nil
    w:refreshAffairs()
    assertEq(w.selectedKey, "rec:W5", "sélection gardée après le rafraîchissement")
    Joypad = { AButton = 0, BButton = 1, XButton = 2, YButton = 3, LBumper = 4, RBumper = 5 }
    w:onJoypadDown(Joypad.AButton)
    assertEq(sent[#sent].name, "PostRecorderInsert", "A : insérer")
    assertEq(sent[#sent].args.item, 8, "l'objet choisi")
    -- Plaques : déposer (X), annoncer (A).
    w:moveSelection(1)
    assertEq(w.selectedKey, "tags", "bas : affaire suivante")
    primary, secondary = w:actions()
    assertTrue(secondary.enabled and not primary.enabled, "une plaque sur soi, casier vide")
    -- Mission : aucune action.
    w:moveSelection(5)
    assertEq(w:selectedAffair().kind, "tags", "dernière ligne sélectionnable")
end

function T.bay_progress_moves_between_two_refreshes_without_finishing()
    local hours = 1000
    getGameTime = function() return { getWorldAgeHours = function() return hours end } end
    local data = sampleData()
    data.bay = { site = "W3", progress = 0.5, total = 0.5 }
    local w = window(data)
    w.dataHours = 1000
    hours = 1000.1
    assertTrue(math.abs(w:bayProgress() - 0.7) < 1e-9, "avancée en temps de jeu depuis la réception")
    assertEq(W.bayStatus(data.bay, w:bayProgress()), "IGUI_MilitaryDrop_PostRecorderReading|70|nil",
        "même valeur dans la liste et sous la barre")
    hours = 1002
    assertEq(w:bayProgress(), 0.99, "jamais finie avant le serveur")
    data.bay.done = true
    assertEq(w:bayProgress(), 1, "finie quand le serveur le dit")
    -- En pause : figée sur la valeur du serveur.
    local paused = sampleData()
    paused.bay = { site = "W4", progress = 0.3, total = 0.5, paused = true }
    local w2 = window(paused)
    w2.dataHours = 1000
    assertEq(w2:bayProgress(), 0.3, "en pause : figée")
end

function T.bay_progress_never_goes_back_for_the_same_recorder()
    local hours = 1000
    getGameTime = function() return { getWorldAgeHours = function() return hours end } end
    local data = sampleData()
    data.bay = { site = "W3", progress = 0.5, total = 0.5 }
    local w = window(data)
    w.dataHours = 1000
    hours = 1000.1
    assertTrue(math.abs(w:bayProgress() - 0.7) < 1e-9, "estimation à 70 %")
    -- Envoi suivant un peu en retard (réseau) : 60 %, reçu maintenant.
    w.data = sampleData()
    w.data.bay = { site = "W3", progress = 0.6, total = 0.5 }
    w.dataHours = hours
    assertTrue(math.abs(w:bayProgress() - 0.7) < 1e-9, "pas de recul de la barre")
    hours = 1000.15
    assertTrue(math.abs(w:bayProgress() - 0.7) < 1e-9, "tient tant que le serveur n'a pas rattrapé")
    hours = 1000.2
    assertTrue(math.abs(w:bayProgress() - 0.8) < 1e-9, "puis reprend sa course")
    -- Autre enregistreur : repart de sa propre valeur.
    w.data.bay = { site = "W5", progress = 0.1, total = 0.5 }
    w.dataHours = hours
    assertTrue(math.abs(w:bayProgress() - 0.1) < 1e-9, "valeur du nouvel enregistreur")
end

function T.journal_names_the_recorder_of_a_bay_event()
    local text = W.journalText({ { c = 100, sys = "recorderRead", site = "W3" }, { c = 100, sys = "installed" } })
    assertTrue(text:find("IGUI_MilitaryDrop_PostSys_recorderRead|W3", 1, true) ~= nil, "site cité")
    assertTrue(text:find("IGUI_MilitaryDrop_PostSys_installed|", 1, true) ~= nil, "autres entrées inchangées")
end

function T.estimated_end_asks_the_server_at_once_instead_of_waiting()
    local hours, now = 1000, 0
    getGameTime = function() return { getWorldAgeHours = function() return hours end } end
    getTimestampMs = function() return now end
    local data = sampleData()
    data.bay = { site = "W3", progress = 0.9, total = 1 / 6 }
    local w, sent = window(data)
    w.dataHours = 1000
    w:bayProgress()
    assertEq(#sent, 0, "lecture en cours : pas de demande")
    hours = 1000 + 0.2 / 6
    assertEq(w:bayProgress(), 0.99, "estimée finie : 99 % en attendant le serveur")
    assertEq(#sent, 1, "état redemandé aussitôt")
    assertEq(sent[1].name, "PostOpen", "rafraîchissement de la console")
    now = 500
    w:bayProgress()
    assertEq(#sent, 1, "au plus une demande par seconde")
    now = 1200
    w:bayProgress()
    assertEq(#sent, 2, "nouvelle demande si la réponse tarde")
end

function T.end_click_refreshes_the_console_open_on_that_post()
    getTimestampMs = function() return 0 end
    local w, sent = window(sampleData())
    W.instances = { [0] = w }
    W.onBaySound({ x = 10, y = 10, z = 0, reading = true })
    assertEq(#sent, 0, "lecture en cours : rien")
    W.onBaySound({ x = 50, y = 10, z = 0, event = "done", reading = false })
    assertEq(#sent, 0, "autre poste : rien")
    W.onBaySound({ x = 10, y = 10, z = 0, event = "done", reading = false })
    assertEq(#sent, 1, "fin sur ce poste : console rafraîchie")
    W.instances = {}
end

return T
