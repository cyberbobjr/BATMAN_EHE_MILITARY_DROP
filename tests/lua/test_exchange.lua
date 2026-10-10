-- MilitaryDrop_Exchange : radio revérifiée par le serveur (fréquence, allumage,
-- en main), réponses (solo : appel direct ; MP : commande au seul joueur),
-- prise en main du talkie (AUTH-03) et renvoi de son état en MP, action
-- d'échange, affichage des réponses de la base, options des sources,
-- plaques d'identité vanilla (renommées, pas la sienne, toute langue) et
-- infobulle du sous-menu « Logistique ».

local T = {}

local CHANNEL = 151400

--- Radio d'inventaire simulée, rangée dans container (nil : aucun).
local function makeRadio(channel, on, container)
    local data = { channel = channel or CHANNEL, on = on ~= false, sent = {} }
    function data.getIsHighTier() return true end
    function data.getIsPortable() return true end
    function data.getIsTurnedOn(self) return self.on end
    function data.getChannel(self) return self.channel end
    function data.getDeviceVolume() return 0.5 end
    function data.setIsTurnedOn(self, value) self.sent[#self.sent + 1] = "on:" .. tostring(value) end
    function data.setChannel(self, value) self.sent[#self.sent + 1] = "channel:" .. tostring(value) end
    return {
        kind = "Radio",
        data = data,
        getID = function() return 7 end,
        getDeviceData = function() return data end,
        getContainer = function() return container end,
        isRequiresEquippedBothHands = function() return false end,
        AddDeviceText = function(self, text) self.said = text end,
    }
end

--- Joueur simulé ; where = "hand", "back", "belt" (accrochée) ou "bag" (rangée).
local function makePlayer(radio, where)
    local player = { where = where or "hand", said = {} }
    function player.getUsername() return "tester" end
    function player.getPlayerNum() return 0 end
    function player.getX() return 10.5 end
    function player.getY() return 10.5 end
    function player.getZ() return 0 end
    function player.getPrimaryHandItem(self) return self.where == "hand" and radio or nil end
    function player.getSecondaryHandItem() return nil end
    function player.getClothingItem_Back(self) return self.where == "back" and radio or nil end
    function player.isAttachedItem(self, item) return self.where == "belt" and item == radio end
    function player.Say(self, text) self.said[#self.said + 1] = text end
    return player
end

--- Conteneur simulé : dans l'inventaire du joueur ou non.
local function makeContainer(inInventory)
    return { isInCharacterInventory = function() return inInventory end }
end

function T.setup()
    SandboxVars = { MilitaryDrop = { Frequency = 151.4 } }
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    getText = function(key, a) return key .. (a and ("|" .. tostring(a)) or "") end
    ZombRand = function() return 0 end
    SENT = {}
    sendServerCommand = function(player, module, command, args)
        SENT[#SENT + 1] = { player = player, module = module, command = command, args = args }
    end
    sendClientCommand = function(player, module, command, args)
        SENT[#SENT + 1] = { player = player, module = module, command = command, args = args, toServer = true }
    end
    -- Actions chronométrées vanilla simulées.
    ISBaseTimedAction = {}
    function ISBaseTimedAction.derive(parent, type)
        local class = setmetatable({ Type = type }, { __index = parent })
        return class
    end
    function ISBaseTimedAction.new(class, character)
        local o = setmetatable({}, { __index = class })
        o.character = character
        return o
    end
    function ISBaseTimedAction.perform(self) self.performed = true end
    QUEUE = {}
    ISTimedActionQueue = { add = function(action) QUEUE[#QUEUE + 1] = action end }
    EQUIPPED = {}
    ISInventoryPaneContextMenu = { equipWeapon = function(item, primary, twoHands, playerNum)
        EQUIPPED[#EQUIPPED + 1] = { item = item, primary = primary, twoHands = twoHands, playerNum = playerNum }
    end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    -- Chargé par le require de MilitaryDrop_Exchange.lua (sans effet dans le banc).
    loadMod("shared/MilitaryDrop/MilitaryDrop_Fulton.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Exchange.lua")
    Exchange = MilitaryDrop.Exchange
end

-- ----------------------------------------------------------------------------
-- Serveur : radio
-- ----------------------------------------------------------------------------

function T.military_radio_in_hand_on_the_frequency_is_accepted()
    local radio = makeRadio()
    local player = makePlayer(radio)
    assertEq(Exchange.checkRadio(player, { kind = "item", id = 7 }), radio, "radio acceptée")
end

function T.wrong_frequency_gets_no_answer()
    local player = makePlayer(makeRadio(CHANNEL + 200))
    local radio, status = Exchange.checkRadio(player, { kind = "item", id = 7 })
    assertEq(radio, nil, "refusée")
    assertEq(status, "noAnswer", "même réponse qu'un appel de largage sur une autre fréquence")
end

function T.frequency_follows_the_sandbox_option()
    SandboxVars.MilitaryDrop.Frequency = 42.6
    local player = makePlayer(makeRadio(42600))
    assertTrue(Exchange.checkRadio(player, { kind = "item", id = 7 }) ~= nil, "option Frequency")
end

function T.radio_turned_off_or_missing_is_refused()
    local player = makePlayer(makeRadio(CHANNEL, false))
    assertEq(select(2, Exchange.checkRadio(player, { kind = "item", id = 7 })), "radioOff", "éteinte")
    assertEq(select(2, Exchange.checkRadio(player, { kind = "item", id = 8 })), "noRadio", "autre objet")
    assertEq(select(2, Exchange.checkRadio(player, nil)), "noRadio", "sans référence")
end

function T.radio_on_the_back_is_refused_in_multiplayer()
    isServer = function() return true end
    local player = makePlayer(makeRadio(), "back")
    assertEq(select(2, Exchange.checkRadio(player, { kind = "item", id = 7 })), "noRadio",
        "MP : état d'une radio hors des mains inconnu du serveur")
    isServer = function() return false end
    assertTrue(Exchange.checkRadio(player, { kind = "item", id = 7 }) ~= nil, "solo : le dos compte")
end

-- ----------------------------------------------------------------------------
-- Réponses
-- ----------------------------------------------------------------------------

function T.reply_goes_to_the_player_in_multiplayer()
    isServer = function() return true end
    local player = makePlayer(makeRadio())
    Exchange.toPlayer(player, Exchange.REPLY, { exchangeId = 3 })
    assertEq(#SENT, 1, "une commande")
    assertEq(SENT[1].player, player, "au seul joueur")
    assertEq(SENT[1].module, "MilitaryDrop", "module du mod")
    assertEq(SENT[1].command, "ExchangeReply", "commande")
end

function T.reply_is_dispatched_directly_in_solo()
    local received = nil
    Exchange.HANDLERS.Test = function(args) received = args end
    Exchange.toPlayer(nil, "Test", { value = 1 })
    assertEq(#SENT, 0, "aucun réseau en solo")
    assertEq(received.value, 1, "gestionnaire client appelé")
    Exchange.onServerCommand("OtherMod", "Test", { value = 2 })
    assertEq(received.value, 1, "autre module ignoré")
end

-- ----------------------------------------------------------------------------
-- Client : disponibilité, prise en main, action
-- ----------------------------------------------------------------------------

function T.radio_anywhere_in_the_inventory_can_be_used()
    local bag = makeRadio(CHANNEL, true, makeContainer(true))
    assertEq(Exchange.unavailableReason(makePlayer(bag, "bag"), bag), nil, "inventaire ou sac : il la prendra en main")
    local belt = makeRadio(CHANNEL, true, makeContainer(true))
    assertEq(Exchange.unavailableReason(makePlayer(belt, "belt"), belt), "IGUI_MilitaryDrop_TakeInHand",
        "ceinture : reçoit, n'émet pas")
    local floor = makeRadio(CHANNEL, true, makeContainer(false))
    assertEq(Exchange.unavailableReason(makePlayer(floor, "bag"), floor), "IGUI_MilitaryDrop_NotInInventory",
        "radio hors de l'inventaire")
    local off = makeRadio(CHANNEL, false, makeContainer(true))
    assertEq(Exchange.unavailableReason(makePlayer(off, "bag"), off), "IGUI_MilitaryDrop_TurnOn", "éteinte")
    local wrong = makeRadio(CHANNEL + 200, true, makeContainer(true))
    assertEq(Exchange.unavailableReason(makePlayer(wrong, "bag"), wrong), nil,
        "la fréquence n'est jamais vérifiée par le client")
end

function T.placed_radio_must_be_near()
    local square = { getX = function() return 20 end, getY = function() return 10 end, getZ = function() return 0 end }
    local data = { getIsTurnedOn = function() return true end }
    local placed = { kind = "IsoWaveSignal", getSquare = function() return square end,
        getDeviceData = function() return data end }
    assertEq(Exchange.unavailableReason(makePlayer(nil), placed), "IGUI_MilitaryDrop_TooFar", "à 10 cases")
end

function T.radio_on_the_belt_never_transmits()
    local radio = makeRadio(CHANNEL, true, makeContainer(true))
    local player = makePlayer(radio, "belt")
    assertEq(Exchange.run(player, radio, "hello", function() end), false, "refusé à la ceinture")
    assertEq(#EQUIPPED, 0, "pas de prise en main automatique")
    assertEq(#QUEUE, 0, "aucune action d'échange")
    assertEq(#player.said, 0, "le personnage ne parle pas")
    player.where = "hand"
    assertTrue(Exchange.run(player, radio, "hello", function() end), "prise en main par le joueur : appel possible")
end

function T.stowed_radio_is_taken_in_hand_then_resent_in_multiplayer()
    isClient = function() return true end
    local radio = makeRadio(CHANNEL, true, makeContainer(true))
    local player = makePlayer(radio, "bag")
    local done = false
    assertTrue(Exchange.run(player, radio, "hello", function() done = true end), "échange lancé")
    assertEq(#EQUIPPED, 1, "action vanilla d'équipement")
    assertEq(EQUIPPED[1].item, radio, "le talkie")
    assertEq(#QUEUE, 1, "action d'échange ensuite")
    local action = QUEUE[1]
    player.where = "hand"
    assertTrue(action:isValid(), "valide une fois en main")
    action:start()
    assertEq(radio.data.sent[1], "on:true", "allumage renvoyé au serveur")
    assertEq(radio.data.sent[2], "channel:" .. CHANNEL, "canal renvoyé au serveur")
    assertEq(player.said[1], "hello", "le personnage parle")
    assertEq(done, false, "commande à la fin de l'action seulement")
    action:perform()
    assertTrue(done, "puis la commande")
end

function T.radio_in_hand_is_not_equipped_again_but_resynced_in_multiplayer()
    isClient = function() return true end
    local radio = makeRadio()
    local player = makePlayer(radio)
    Exchange.run(player, radio, nil, function() end)
    assertEq(#EQUIPPED, 0, "déjà en main")
    QUEUE[1]:start()
    -- Réglée hors de la main, son état avait été ignoré par le serveur (AUTH-03).
    assertEq(radio.data.sent[1], "on:true", "allumage renvoyé même déjà en main")
    assertEq(radio.data.sent[2], "channel:" .. CHANNEL, "canal renvoyé même déjà en main")
end

function T.solo_and_world_radios_are_not_resynced()
    local radio = makeRadio()
    local player = makePlayer(radio)
    Exchange.run(player, radio, nil, function() end)
    QUEUE[1]:start()
    assertEq(#radio.data.sent, 0, "solo : un seul état, rien à renvoyer")
    isClient = function() return true end
    local square = { getX = function() return 10 end, getY = function() return 10 end, getZ = function() return 0 end }
    local world = makeRadio()
    world.kind = "IsoWaveSignal"
    world.getSquare = function() return square end
    Exchange.run(player, world, nil, function() end)
    QUEUE[2]:start()
    assertEq(#world.data.sent, 0, "MP : un appareil posé est toujours synchronisé")
end

function T.free_frequency_is_unknown_to_a_multiplayer_client()
    SandboxVars.MilitaryDrop.Frequency = 0
    assertEq(MilitaryDrop.Config.getChannel(), nil, "client MP : aucun module serveur, fréquence inconnue")
end

function T.radio_out_of_the_inventory_is_not_used()
    local radio = makeRadio(CHANNEL, true, makeContainer(false))
    assertEq(Exchange.run(makePlayer(radio, "bag"), radio, nil, function() end), false, "refusé")
    assertEq(#QUEUE, 0, "aucune action")
end

function T.send_carries_the_radio_reference_and_shows_the_base_lines()
    isClient = function() return true end
    local shown = {}
    MilitaryDrop.Client = {
        later = function(_, fn) fn() end,
        radioSay = function(request, text) shown[#shown + 1] = { request.device, text } end,
    }
    local radio = makeRadio()
    local player = makePlayer(radio)
    getSpecificPlayer = function() return player end
    local replied = nil
    Exchange.send(player, radio, "MissionReport", { extra = 1 }, "call", { onReply = function(args) replied = args end })
    QUEUE[1]:start()
    QUEUE[1]:perform()
    local sent = SENT[1]
    assertTrue(sent.toServer, "commande au serveur")
    assertEq(sent.command, "MissionReport", "commande")
    assertEq(sent.args.radio.id, 7, "référence de la radio")
    assertEq(sent.args.extra, 1, "paramètres conservés")
    Exchange.onServerCommand("MilitaryDrop", "ExchangeReply",
        { exchangeId = sent.args.exchangeId, status = "ok", lines = { { text = "line 1" }, { text = "line 2" } } })
    assertEq(#shown, 2, "deux lignes de la base")
    assertEq(shown[1][1], radio, "par la radio")
    assertEq(shown[2][2], "line 2", "dans l'ordre")
    assertEq(replied.status, "ok", "rappel du demandeur")
    Exchange.onServerCommand("MilitaryDrop", "ExchangeReply", { exchangeId = sent.args.exchangeId, lines = { { text = "x" } } })
    assertEq(#shown, 2, "réponse déjà traitée : ignorée")
end

function T.fulton_reply_keeps_the_window_for_the_local_player()
    isClient = function() return true end
    HOURS = 500
    getGameTime = function() return { getWorldAgeHours = function() return HOURS end } end
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonClient.lua")
    local FultonClient = MilitaryDrop.FultonClient
    MilitaryDrop.Client = { later = function(_, fn) fn() end, radioSay = function() end }
    local radio = makeRadio()
    local player = makePlayer(radio)
    getSpecificPlayer = function() return player end
    Exchange.send(player, radio, "MissionFulton", {}, nil)
    QUEUE[1]:perform()
    Exchange.onReply({ exchangeId = SENT[1].args.exchangeId, status = "ok", lines = { { text = "ok" } },
        fulton = { minutesLeft = 30, dailyLeft = 7 } })
    local window = FultonClient.window(0)
    assertTrue(window ~= nil, "créneau gardé pour le joueur 0")
    assertEq(window.dailyLeft, 7, "plafond restant du serveur")
    assertEq(FultonClient.minutesLeft(0), 30, "30 minutes")
    assertEq(FultonClient.window(1), nil, "rien pour un autre joueur local")
    HOURS = HOURS + 0.25
    assertEq(FultonClient.minutesLeft(0), 15, "décompte dans l'heure du client")
    HOURS = HOURS + 0.25
    assertEq(FultonClient.window(0), nil, "échu")
    FultonClient.onWindow(0, { minutesLeft = 0 })
    assertEq(FultonClient.window(0), nil, "durée nulle ignorée")
end

function T.legacy_plain_text_journal_lines_do_not_crash()
    assertEq(Exchange.lineText("Old base line"), "Old base line", "ligne d'avant la 0.3.3 : texte simple")
    assertEq(Exchange.lineText({ key = "IGUI_MilitaryDrop_Fulton_Cure" }), "IGUI_MilitaryDrop_Fulton_Cure",
        "ligne sans paramètres")
    assertEq(Exchange.lineText(nil), "", "ligne absente")
    assertEq(Exchange.lineText({}), "", "ligne vide")
end

function T.statuses_without_base_lines_are_said_locally()
    isClient = function() return true end
    local shown = {}
    MilitaryDrop.Client = {
        later = function(_, fn) fn() end,
        radioSay = function(_, text) shown[#shown + 1] = text end,
    }
    local radio = makeRadio()
    local player = makePlayer(radio)
    getSpecificPlayer = function() return player end
    Exchange.send(player, radio, "MissionReport", {}, nil)
    QUEUE[1]:perform()
    Exchange.onReply({ exchangeId = SENT[1].args.exchangeId, status = "noAnswer" })
    assertEq(shown[1], "IGUI_MilitaryDrop_NoAnswer", "grésillement par la radio")
    Exchange.send(player, radio, "MissionDogTags", {}, nil)
    QUEUE[2]:perform()
    Exchange.onReply({ exchangeId = SENT[2].args.exchangeId, status = "noTags" })
    assertEq(player.said[#player.said], "IGUI_MilitaryDrop_NoDogTags", "le personnage le dit")
    local replied = nil
    Exchange.send(player, radio, "MissionReport", {}, nil, { onReply = function(args) replied = args end })
    QUEUE[3]:perform()
    Exchange.onReply({ exchangeId = SENT[3].args.exchangeId, status = "busy" })
    assertEq(player.said[#player.said], "IGUI_MilitaryDrop_Busy", "cadence : le personnage le dit, rien de la base")
    assertEq(#shown, 1, "aucune ligne par la radio")
    assertEq(replied.status, "busy", "attente libérée")
end

-- ----------------------------------------------------------------------------
-- Options
-- ----------------------------------------------------------------------------

function T.scripted_exchange_uses_bwt_text_bridge_when_present()
    isClient = function() return true end
    getActivatedMods = function()
        return { size = function() return 1 end, get = function() return "\\BetterWalkieTalkies" end }
    end
    local called = 0
    BetterWalkieTalkies = { RadioTextBridgeHandler = function(callback, message)
        called = called + 1
        return callback(message)
    end }
    local radio = makeRadio()
    local player = makePlayer(radio)
    Exchange.run(player, radio, "MissionReport", function() end)
    QUEUE[1]:start()
    assertEq(called, 1, "parole de l'action transmise par le bridge BWT")
end

function T.source_gains_have_defaults_and_0_disables()
    assertEq(Exchange.gain("report"), 1, "rapport")
    assertEq(Exchange.gain("dogtag"), 2, "plaque")
    assertEq(Exchange.gain("recon"), 3, "reconnaissance")
    assertEq(Exchange.gain("cleanup"), 5, "nettoyage")
    assertEq(Exchange.gain("control"), 1, "appel de contrôle")
    assertEq(Exchange.gain("fulton"), 100, "Fulton : barème en pour cent")
    SandboxVars.MilitaryDrop.ReconGain = 0
    assertEq(Exchange.isEnabled("recon"), false, "0 : désactivée")
    assertEq(Exchange.isEnabled("unknown"), false, "source inconnue")
    assertEq(MilitaryDrop.Config.get("CleanupQuota"), 30, "quota par défaut")
    assertEq(MilitaryDrop.Config.get("ControlHours"), 4, "appel de contrôle : 4 h")
end

-- ----------------------------------------------------------------------------
-- Plaques d'identité vanilla
-- ----------------------------------------------------------------------------

--- Plaque simulée : name brut (nil : nom du script), tag base:dogtag sauf pet.
local function makeTag(id, name, pet)
    local tag = { id = id, name = name or "Dog Tags", tag = not pet and "base:dogtag" or nil }
    function tag.hasTag(self, itemTag) return self.tag == itemTag end
    function tag.getDisplayName(self) return self.name end
    function tag.getScriptItem() return { getDisplayName = function() return "Dog Tags" end } end
    function tag.getID(self) return self.id end
    return tag
end

local function makeCarrier(tags)
    local player = { worn = {}, attached = {} }
    function player.getDescriptor()
        return { getForename = function() return "Alice" end, getSurname = function() return "Smith" end }
    end
    function player.isEquipped(self, item) return self.worn[item] == true end
    function player.isAttachedItem(self, item) return self.attached[item] == true end
    function player.getInventory()
        return { getAllTagRecurse = function(_, itemTag, list)
            assertEq(type(list), "table", "liste Java fournie")
            local found = {}
            for _, tag in ipairs(tags) do
                if tag:hasTag(itemTag) then
                    found[#found + 1] = tag
                end
            end
            return { size = function() return #found end, get = function(_, i) return found[i + 1] end }
        end }
    end
    return player
end

local function setupTags()
    ItemTag = { DOG_TAG = "base:dogtag" }
    ArrayList = { new = function() return {} end }
    getText = function(key, ...)
        local parts = { key }
        for _, value in ipairs({ ... }) do
            parts[#parts + 1] = tostring(value)
        end
        return table.concat(parts, "|")
    end
end

function T.only_renamed_vanilla_dog_tags_of_others_are_transmissible()
    setupTags()
    local player = makeCarrier({})
    assertEq(Exchange.isDogTag(makeTag(1, "Dog Tags: John Doe"), player), true, "plaque d'un soldat")
    assertEq(Exchange.isDogTag(makeTag(2, "Plaques militaires: Jean Dupont"), player), true,
        "renommée dans une autre langue : reconnue quand même")
    assertEq(Exchange.isDogTag(makeTag(3), player), false, "plaque vierge du butin")
    assertEq(Exchange.isDogTag(makeTag(4, "Dog Tags: Alice Smith"), player), false, "la sienne")
    assertEq(Exchange.isDogTag(makeTag(4, "Dog Tags: Alice Smith")), true, "sans joueur : toute plaque renommée")
    assertEq(Exchange.isDogTag(makeTag(5, "Dog Tag: Rex", true), player), false, "plaque d'animal (sans le tag)")
    assertEq(Exchange.isDogTag(makeTag(6, "Dog Tags:  "), player), false, "nom vide")
    assertEq(Exchange.isDogTag(nil, player), false, "rien")
    ItemTag = nil
    assertEq(Exchange.isDogTag(makeTag(1, "Dog Tags: John Doe"), player), false, "registre des tags absent")
end

function T.dog_tag_label_and_id()
    setupTags()
    assertEq(Exchange.dogTagLabel(makeTag(1, "Dog Tags: Mary Ann O'Neil")), "Mary Ann O'Neil", "nom du soldat")
    assertEq(Exchange.dogTagLabel(makeTag(1)), "Dog Tags", "plaque vierge : nom de l'objet")
    assertEq(Exchange.dogTagId(makeTag(2146250223, "x: y")), "2146250223", "identifiant en texte, sans exposant")
    assertEq(Exchange.dogTagId(makeTag(1.5, "x: y")), nil, "identifiant invalide")
end

function T.find_dog_tags_skips_worn_attached_and_stops_at_max()
    setupTags()
    local tags = { makeTag(1, "Dog Tags: A B"), makeTag(2, "Dog Tags: C D"), makeTag(3, "Dog Tags: E F"),
        makeTag(4, "Dog Tags: G H"), makeTag(5), makeTag(6, "Dog Tags: Alice Smith") }
    local player = makeCarrier(tags)
    player.worn[tags[1]] = true
    player.attached[tags[2]] = true
    local found = Exchange.findDogTags(player)
    assertEq(#found, 2, "portée, accrochée, vierge et la sienne exclues")
    assertEq(found[1], tags[3], "ordre de l'inventaire")
    assertEq(#Exchange.findDogTags(player, 1), 1, "max")
end

function T.names_text_lists_three_names_then_the_rest()
    setupTags()
    assertEq(Exchange.namesText({ "A" }), "A", "un nom")
    assertEq(Exchange.namesText({ "A", "B", "C" }), "A, B, C", "trois noms")
    assertEq(Exchange.namesText({ "A", "B", "C", "D" }), "IGUI_MilitaryDrop_NamesMoreOne|A, B, C", "et un autre")
    assertEq(Exchange.namesText({ "A", "B", "C", "D", "E" }), "IGUI_MilitaryDrop_NamesMore|A, B, C|2", "et 2 autres")
    assertEq(Exchange.namesText({ "A", "B" }, 1), "IGUI_MilitaryDrop_NamesMoreOne|A", "maximum choisi")
end

function T.logistics_menu_counts_and_names_the_dog_tags()
    setupTags()
    loadMod("client/MilitaryDrop/MilitaryDrop_ExchangeMenu.lua")
    local Menu = MilitaryDrop.ExchangeMenu
    local player = makeCarrier({ makeTag(1, "Dog Tags: John Doe"), makeTag(2), makeTag(3, "Dog Tags: Alice Smith") })
    assertEq(Menu.dogTagCount(player), 1, "une plaque transmissible")
    local option = Menu.OPTIONS[2]
    assertEq(option.source, "dogtag", "option des plaques")
    assertEq(Menu.tooltipText(player, option), "IGUI_MilitaryDrop_Exchange_DogTagsTooltip <LINE> <LINE> John Doe",
        "noms dans l'infobulle")
    assertEq(Menu.tooltipText(makeCarrier({}), option), "IGUI_MilitaryDrop_Exchange_DogTagsTooltip", "sans plaque")
    assertEq(Menu.tooltipText(player, Menu.OPTIONS[1]), "IGUI_MilitaryDrop_Exchange_ReportTooltip", "autre option")
end

function T.logistics_submenu_is_no_longer_in_the_context_menu()
    -- La section « Logistique » de la fenêtre radio remplace le sous-menu.
    local inventory = #Events.OnFillInventoryObjectContextMenu.handlers
    local world = #Events.OnFillWorldObjectContextMenu.handlers
    loadMod("client/MilitaryDrop/MilitaryDrop_ExchangeMenu.lua")
    assertEq(#Events.OnFillInventoryObjectContextMenu.handlers, inventory, "pas d'inscription au menu d'inventaire")
    assertEq(#Events.OnFillWorldObjectContextMenu.handlers, world, "ni au menu du monde")
    local Menu = MilitaryDrop.ExchangeMenu
    assertTrue(type(Menu.reason) == "function" and type(Menu.onOption) == "function"
        and type(Menu.tooltipText) == "function", "fonctions gardées pour la fenêtre radio")
end


function T.private_reply_is_translated_in_each_receiving_client_language()
    isClient = function() return true end
    local shown = {}
    MilitaryDrop.Client = {
        later = function(_, fn) fn() end,
        radioSay = function(_, text) shown[#shown + 1] = text end,
    }
    local radio = makeRadio()
    local player = makePlayer(radio)
    getSpecificPlayer = function() return player end
    -- Le serveur construit le message sans aucun dictionnaire de traduction.
    getText = function() error("server dictionary unavailable") end
    local line = Exchange.line("IGUI_MilitaryDrop_Reply_DogTags", "Alpha",
        Exchange.namesLine({ "A", "B", "C", "D" }))
    for _, language in ipairs({ "FR", "EN" }) do
        getText = function(key, a, b)
            if key == "IGUI_MilitaryDrop_NamesMoreOne" then
                return a .. (language == "FR" and " et un autre" or " and one other")
            end
            return language .. ": " .. a .. " / " .. b
        end
        Exchange.send(player, radio, "MissionDogTags", {}, nil)
        QUEUE[#QUEUE]:perform()
        Exchange.onReply({ exchangeId = SENT[#SENT].args.exchangeId, lines = { line }, status = "ok" })
    end
    assertEq(shown[1], "FR: Alpha / A, B, C et un autre", "client français, paramètre imbriqué")
    assertEq(shown[2], "EN: Alpha / A, B, C and one other", "client anglais, même message réseau")
    assertEq(line.params[2].key, "IGUI_MilitaryDrop_NamesMoreOne", "résolution sans mutation du message")
end

return T
