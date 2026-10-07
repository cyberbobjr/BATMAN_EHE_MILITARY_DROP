-- MilitaryDrop_Missions : rapport quotidien, plaques d'identité vanilla
-- (renommées seulement, pas la sienne, identifiant unique, plaque consommée,
-- plafond, plaque d'un autre joueur, état v1.3 d'essai), missions
-- publiques (reconnaissance, nettoyage, appel de contrôle), planification,
-- radio revérifiée, cadence, ligne coupée, poste de liaison.

local T = {}

local CHANNEL = 151400

local function arrayList(values)
    return {
        size = function() return #values end,
        get = function(_, i) return values[i + 1] end,
    }
end

local function makeRadio(channel, on)
    local data = {
        getIsHighTier = function() return true end,
        getIsPortable = function() return true end,
        getIsTurnedOn = function() return on ~= false end,
        getChannel = function() return channel or CHANNEL end,
    }
    NEXT_ID = NEXT_ID + 1
    local id = NEXT_ID
    return { kind = "Radio", getID = function() return id end, getDeviceData = function() return data end }
end

--- Joueur simulé : radio en main, inventaire de plaques (liste Lua),
--- personnage « <Name> Smith ».
local function makePlayer(name, x, y, radio)
    local player = { kind = "IsoPlayer", name = name, x = x or 0, y = y or 0, tags = {}, worn = {} }
    player.radio = radio or makeRadio()
    function player.getUsername() return name end
    function player.getX(self) return self.x end
    function player.getY(self) return self.y end
    function player.getZ() return 0 end
    function player.isDead() return false end
    function player.getPrimaryHandItem(self) return self.radio end
    function player.getSecondaryHandItem() return nil end
    function player.getClothingItem_Back() return nil end
    function player.isEquipped(self, item) return self.worn[item] == true end
    function player.isAttachedItem() return false end
    function player.getDescriptor()
        return { getForename = function() return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) end,
            getSurname = function() return "Smith" end }
    end
    function player.getInventory(self)
        return {
            getAllTagRecurse = function(_, itemTag)
                local found = {}
                for _, tag in ipairs(self.tags) do
                    if tag.tag == itemTag then
                        found[#found + 1] = tag
                    end
                end
                return arrayList(found)
            end,
        }
    end
    ONLINE[#ONLINE + 1] = player
    function player.getModData(self)
        self.characterData = self.characterData or { MilitaryDrop_characterId = "C:" .. self:getUsername() }
        return self.characterData
    end
    return player
end

--- Plaque vanilla simulée (tag base:dogtag), rangée dans l'inventaire de
--- owner ; soldier : nom inscrit par nameAfterDescriptor (nil : plaque vierge).
local function giveTag(owner, id, soldier)
    local tag = { tag = "base:dogtag", id = id, name = soldier and ("Dog Tags: " .. soldier) or "Dog Tags" }
    function tag.hasTag(self, itemTag) return self.tag == itemTag end
    function tag.getDisplayName(self) return self.name end
    function tag.getScriptItem() return { getDisplayName = function() return "Dog Tags" end } end
    function tag.getID(self) return self.id end
    function tag.getContainer()
        return {
            Remove = function(_, item)
                for i = #owner.tags, 1, -1 do
                    if owner.tags[i] == item then
                        table.remove(owner.tags, i)
                    end
                end
            end,
        }
    end
    owner.tags[#owner.tags + 1] = tag
    return tag
end

--- Liste Java simulée (add, contains, size, get).
local function javaList()
    local l = { items = {} }
    function l.add(self, v) self.items[#self.items + 1] = v end
    function l.contains(self, v)
        for _, item in ipairs(self.items) do
            if item == v then
                return true
            end
        end
        return false
    end
    function l.size(self) return #self.items end
    function l.get(self, i) return self.items[i + 1] end
    return l
end

local function overlaps(x, y, w, h, r)
    return not (x + w <= r.x or x >= r.x + r.w or y + h <= r.y or y >= r.y + r.h)
end

--- Métagrille simulée, carte de 16 × 16 cellules : bâtiments { x, y, w, h,
--- userDefined, basement } rangés dans la cellule de leur coin (comme leurs
--- pièces), zones { type, x, y, w, h, polyline }. Pas de
--- getBuildingsIntersecting sur la grille : son parcours des cellules est
--- faux en 42.21, le mod interroge chaque cellule.
local function makeGrid(buildings, zones)
    local defs = {}
    for _, b in ipairs(buildings or {}) do
        local def = { b = b }
        function def.getX() return b.x end
        function def.getY() return b.y end
        function def.getW() return b.w end
        function def.getH() return b.h end
        function def.isUserDefined() return b.userDefined == true end
        function def.isBasement() return b.basement == true end
        defs[#defs + 1] = def
    end
    local zoneObjects = {}
    for _, z in ipairs(zones or {}) do
        local zone = { z = z }
        function zone.getType() return z.type end
        function zone.isRectangle() return not z.polyline end
        function zone.getX() return z.x end
        function zone.getY() return z.y end
        function zone.getWidth() return z.w end
        function zone.getHeight() return z.h end
        zoneObjects[#zoneObjects + 1] = zone
    end
    local grid = { cellCalls = 0 }
    function grid.isValidSquare(_, x, y) return x >= 0 and y >= 0 and x < 4096 and y < 4096 end
    function grid.getCellData(self, cx, cy)
        if cx < 0 or cy < 0 or cx >= 16 or cy >= 16 then
            return nil
        end
        self.cellCalls = self.cellCalls + 1
        return {
            getBuildingsIntersecting = function(_, x, y, w, h, list)
                for _, def in ipairs(defs) do
                    local b = def.b
                    if math.floor(b.x / 256) == cx and math.floor(b.y / 256) == cy and overlaps(x, y, w, h, b)
                        and not list:contains(def) then
                        list:add(def)
                    end
                end
            end,
        }
    end
    function grid.getZonesIntersecting(_, x, y, z, w, h)
        assertEq(z, 0, "zones du rez-de-chaussée")
        local found = javaList()
        for _, zone in ipairs(zoneObjects) do
            if overlaps(x, y, w, h, zone.z) then
                found:add(zone)
            end
        end
        return found
    end
    return grid
end

--- Tirages pseudo-aléatoires reproductibles (comme ZombRand / ZombRandFloat).
local function seededRandom(seed)
    math.randomseed(seed)
    ZombRand = function(low, high)
        if high then
            return math.random(low, high - 1)
        end
        return math.random(low) - 1
    end
    ZombRandFloat = function(low, high) return low + math.random() * (high - low) end
end

local function radioRef(player)
    return { kind = "item", id = player.radio:getID() }
end

--- Dernière réponse envoyée au joueur (commande ExchangeReply).
local function lastReply(player)
    for i = #SENT, 1, -1 do
        if SENT[i].player == player and SENT[i].command == "ExchangeReply" then
            local args = SENT[i].args
            local displayed = { status = args.status, exchangeId = args.exchangeId, lines = {} }
            for n, line in ipairs(args.lines or {}) do
                displayed.lines[n] = MilitaryDrop.Exchange.lineText(line)
            end
            return displayed
        end
    end
    return nil
end

--- Avance le temps réel (cadence) et le temps de jeu.
local function wait(hours)
    NOW_MS = NOW_MS + 10000
    WORLD_HOURS = WORLD_HOURS + (hours or 0)
    CLOCK = CLOCK + (hours or 0)
end

local function call(command, player, args)
    wait(0)
    args = args or {}
    args.radio = args.radio or radioRef(player)
    args.exchangeId = 1
    MilitaryDrop.Server.onClientCommand(command, player, args)
end

function T.setup()
    SandboxVars = { MilitaryDrop = { Frequency = 151.4 } }
    isClient = function() return false end
    isServer = function() return true end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    STATE = {}
    NEXT_ID = 0
    WORLD_HOURS = 1000
    CLOCK = 24 * 100 + 1
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
    getGameTime = function() return { getWorldAgeHours = function() return WORLD_HOURS end } end
    ZombRand = function(low, high)
        if high then
            return low
        end
        return 0
    end
    ZombRandFloat = function(low, high) return (low + high) / 2 end
    getText = function(key, ...)
        local parts = { key }
        for _, value in ipairs({ ... }) do
            parts[#parts + 1] = tostring(value)
        end
        return table.concat(parts, "|")
    end
    SENT = {}
    sendServerCommand = function(player, module, command, args)
        if type(player) == "string" then
            -- Forme « à tous » : (module, commande, args).
            SENT[#SENT + 1] = { all = true, module = player, command = module, args = command }
            return
        end
        SENT[#SENT + 1] = { player = player, module = module, command = command, args = args }
    end
    -- Monde simulé : cases chargées (LOADED(x, y)), cases bloquées (BLOCKED),
    -- zombies de la cellule (ZLIST), tenues persistantes tirées par
    -- NEXT_OUTFIT ; spawnHorde sur une case crée un zombie (SPAWN_ZOMBIE).
    LOADED = function() return false end
    BLOCKED = {}
    ZLIST = javaList()
    HORDE_SPAWNED = {}
    OUTFIT_SEQ = 0
    NEXT_OUTFIT = function()
        OUTFIT_SEQ = OUTFIT_SEQ + 1
        return (OUTFIT_SEQ % 40 + 1) * 65536 + OUTFIT_SEQ
    end
    getCell = function()
        return {
            getGridSquare = function(_, x, y, z)
                if z ~= 0 or not LOADED(x, y) then
                    return nil
                end
                return { key = x .. "," .. y, getX = function() return x end, getY = function() return y end }
            end,
            getZombieList = function() return ZLIST end,
        }
    end
    spawnHorde = function(x1, y1, x2, y2, z, count)
        assertEq(x1 .. "," .. y1 .. "," .. z .. "," .. count, x2 .. "," .. y2 .. ",0,1", "une case, un zombie")
        SPAWN_ZOMBIE(math.floor(x1), math.floor(y1))
    end
    REMOVED = {}
    sendRemoveItemFromContainer = function(_, item) REMOVED[#REMOVED + 1] = item end
    ItemTag = { DOG_TAG = "base:dogtag" }
    ArrayList = { new = javaList }
    -- Métagrille vide : point des missions par repli (Server.pickDropPoint).
    GRID = makeGrid()
    getWorld = function() return { getMetaGrid = function() return GRID end } end
    ONLINE = {}
    getOnlinePlayers = function() return arrayList(ONLINE) end
    FACTIONS = {}
    Faction = { getFactions = function() return arrayList(FACTIONS) end }
    AIRED = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    -- Chargé par le require de MilitaryDrop_Exchange.lua (sans effet dans le banc).
    loadMod("shared/MilitaryDrop/MilitaryDrop_Fulton.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Exchange.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    PICK = { 300, 400 }
    -- État privé (ModData au nom tiré de la graine, jamais transmise).
    PUBLIC = {}
    MilitaryDrop.Secrets = { privateState = function() return STATE end }
    MilitaryDrop.Server = {
        -- État public (lisible par les clients) : rien de la v1.3 n'y va.
        getState = function() return PUBLIC end,
        clock = function() return CLOCK end,
        pickDropPoint = function() return PICK[1], PICK[2] end,
        isFreeSquare = function(square) return square ~= nil and not BLOCKED[square.key] end,
        COMMANDS = {},
        onClientCommand = function(command, player, args)
            MilitaryDrop.Server.COMMANDS[command](player, args)
        end,
    }
    MilitaryDrop.Broadcast = {
        channel = {},
        air = function(lines)
            AIRED[#AIRED + 1] = lines
            return true
        end,
    }
    loadMod("server/MilitaryDrop/MilitaryDrop_Teams.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Missions.lua")
    Missions = MilitaryDrop.Missions
    Trust = MilitaryDrop.Trust
    Teams = MilitaryDrop.Teams
end

local function makeFaction(name, owner, players)
    local faction = { name = name, owner = owner, players = players }
    function faction.getName(self) return self.name end
    function faction.getOwner(self) return self.owner end
    function faction.getPlayers(self) return arrayList(self.players) end
    FACTIONS[#FACTIONS + 1] = faction
    return faction
end

-- ----------------------------------------------------------------------------
-- Commandes et radio
-- ----------------------------------------------------------------------------

function T.commands_are_registered_in_the_server_table()
    for _, name in ipairs({ "MissionReport", "MissionDogTags", "MissionRecon", "MissionControl",
        "MissionCleanupStatus" }) do
        assertEq(type(MilitaryDrop.Server.COMMANDS[name]), "function", name)
    end
end

--- Champs fulton de la dernière réponse au joueur (créneau Fulton), ou nil.
local function lastFulton(player)
    for i = #SENT, 1, -1 do
        if SENT[i].player == player and SENT[i].command == "ExchangeReply" then
            return SENT[i].args.fulton
        end
    end
    return nil
end

function T.fulton_request_opens_a_window_with_the_remaining_cap()
    local alice = makePlayer("alice")
    Trust.add("C:alice", 3, "report")
    call("MissionFulton", alice)
    local reply = lastReply(alice)
    assertEq(reply.status, "ok", "créneau ouvert")
    assertEq(reply.lines[1], "IGUI_MilitaryDrop_Reply_FultonOpen|" .. Teams.callsign("P:alice") .. "|30",
        "30 minutes par défaut, avec l'indicatif")
    local fulton = lastFulton(alice)
    assertEq(fulton.minutesLeft, 30, "minutes transmises au client")
    assertEq(fulton.dailyLeft, 7, "plafond restant calculé par le serveur")
    local window = STATE.missions.fulton.windows["C:alice"]
    assertEq(window.deadline, 1000.5, "échéance en heures de jeu")
    assertEq(Trust.get("C:alice"), 28, "la demande ne rapporte rien")
end

function T.fulton_second_request_recalls_the_open_window()
    local alice = makePlayer("alice")
    call("MissionFulton", alice)
    wait(1 / 6)
    call("MissionFulton", alice)
    assertEq(lastReply(alice).status, "pending", "créneau déjà ouvert")
    assertEq(lastFulton(alice).minutesLeft, 20, "20 minutes restantes")
    assertEq(STATE.missions.fulton.windows["C:alice"].deadline, 1000.5, "échéance inchangée")
end

function T.fulton_window_expires_without_penalty_and_can_be_reopened()
    local alice = makePlayer("alice")
    call("MissionFulton", alice)
    wait(0.5)
    assertEq(Missions.fultonWindow("C:alice"), nil, "échu à l'échéance exacte")
    assertEq(Trust.get("C:alice"), 25, "aucune pénalité")
    call("MissionFulton", alice)
    assertEq(lastReply(alice).status, "ok", "nouveau créneau")
    assertEq(STATE.missions.fulton.windows["C:alice"].deadline, 1001, "nouvelle échéance")
end

function T.fulton_windows_are_personal_and_follow_the_option()
    SandboxVars.MilitaryDrop.FultonWindowMinutes = 10
    local alice, bob = makePlayer("alice"), makePlayer("bob")
    call("MissionFulton", alice)
    assertEq(lastFulton(alice).minutesLeft, 10, "option FultonWindowMinutes")
    assertEq(Missions.fultonWindow("C:bob"), nil, "rien pour un autre personnage")
    call("MissionFulton", bob)
    Missions.closeFultonWindow("C:alice")
    assertEq(Missions.fultonWindow("C:alice"), nil, "fermé au lâcher")
    assertTrue(Missions.fultonWindow("C:bob") ~= nil, "celui de bob reste ouvert")
    SandboxVars.MilitaryDrop.FultonWindowMinutes = 1
    call("MissionFulton", alice)
    assertEq(lastFulton(alice).minutesLeft, 5, "5 minutes au moins")
end

function T.fulton_disabled_by_a_zero_scale()
    SandboxVars.MilitaryDrop.FultonValue = 0
    local alice = makePlayer("alice")
    call("MissionFulton", alice)
    assertEq(lastReply(alice).status, "disabled", "source désactivée")
    assertEq(lastFulton(alice), nil, "aucun créneau transmis")
    assertEq(Missions.fultonWindow("C:alice"), nil, "aucun créneau ouvert")
end

function T.fulton_update_forgets_expired_windows()
    local alice, bob = makePlayer("alice"), makePlayer("bob")
    call("MissionFulton", alice)
    wait(0.25)
    call("MissionFulton", bob)
    wait(0.3)
    Missions.update()
    assertEq(STATE.missions.fulton.windows["C:alice"], nil, "échu : oublié")
    assertTrue(STATE.missions.fulton.windows["C:bob"] ~= nil, "encore ouvert : gardé")
end

function T.report_gives_1_once_per_calendar_day()
    local alice = makePlayer("alice")
    call("MissionReport", alice)
    assertEq(Trust.get("C:alice"), 26, "premier rapport : +1")
    assertEq(lastReply(alice).status, "ok", "réponse")
    assertEq(lastReply(alice).lines[1], "IGUI_MilitaryDrop_Reply_Report_1|" .. Teams.callsign("P:alice"),
        "ligne de la base, avec l'indicatif")
    wait(10)
    call("MissionReport", alice)
    assertEq(Trust.get("C:alice"), 26, "même jour calendaire : rien")
    assertEq(lastReply(alice).status, "already", "déjà reçu")
    wait(14)
    call("MissionReport", alice)
    assertEq(Trust.get("C:alice"), 27, "jour suivant : +1")
end

function T.reports_are_personal_even_in_a_faction()
    makeFaction("Rangers", "alice", { "bob" })
    local alice, bob = makePlayer("alice"), makePlayer("bob")
    local team = Trust.idFor(alice)
    call("MissionReport", alice)
    call("MissionReport", bob)
    assertEq(Trust.get(team), 26, "rapport personnel Alice")
    assertEq(Trust.get(Trust.idFor(bob)), 26, "rapport personnel Bob")
    assertEq(lastReply(bob).status, "ok", "chaque personnage peut envoyer son rapport")
end

function T.radio_on_the_wrong_frequency_gets_no_answer()
    local alice = makePlayer("alice", 0, 0, makeRadio(CHANNEL + 200))
    call("MissionReport", alice)
    assertEq(lastReply(alice).status, "noAnswer", "mauvaise fréquence : pas de réponse")
    assertEq(#lastReply(alice).lines, 0, "aucune ligne de la base")
    assertEq(Trust.get("C:alice"), 25, "aucun gain")
end

function T.radio_turned_off_or_not_in_hand_is_refused()
    local alice = makePlayer("alice", 0, 0, makeRadio(CHANNEL, false))
    call("MissionReport", alice)
    assertEq(lastReply(alice).status, "radioOff", "radio éteinte")
    local bob = makePlayer("bob")
    call("MissionReport", bob, { radio = { kind = "item", id = 999 } })
    assertEq(lastReply(bob).status, "noRadio", "radio absente des mains")
    call("MissionReport", bob, { radio = "forged" })
    assertEq(lastReply(bob).status, "noRadio", "référence invalide")
    assertEq(Trust.get("C:bob"), 25, "aucun gain")
end

function T.exchanges_are_rate_limited_per_player()
    local alice = makePlayer("alice")
    call("MissionReport", alice)
    local gain = Trust.get("C:alice")
    MilitaryDrop.Server.onClientCommand("MissionControl", alice, { radio = radioRef(alice), exchangeId = 2 })
    local reply = lastReply(alice)
    assertEq(reply.status, "busy", "second échange dans les 3 s : refusé, avec une réponse")
    assertEq(reply.exchangeId, 2, "l'échange refusé est libéré côté client")
    assertEq(#reply.lines, 0, "aucune ligne de la base (rien sur le canal)")
    assertEq(Trust.get("C:alice"), gain, "rien de compté")
end

function T.cut_line_gets_the_line_cut_answer_and_no_gain()
    local alice = makePlayer("alice")
    STATE.characterTrust = { ["C:alice"] = { value = 10, lockedUntil = WORLD_HOURS + 72 } }
    call("MissionReport", alice)
    assertEq(lastReply(alice).status, "lineCut", "ligne coupée")
    assertEq(Trust.get("C:alice"), 10, "aucun gain")
end

function T.disabled_source_is_refused()
    SandboxVars.MilitaryDrop.ReportGain = 0
    local alice = makePlayer("alice")
    call("MissionReport", alice)
    assertEq(lastReply(alice).status, "disabled", "source désactivée")
    assertEq(Trust.get("C:alice"), 25, "aucun gain")
end

function T.exchange_from_the_team_post_gets_the_bonus_and_is_logged()
    local records = {}
    MilitaryDrop.Post = {
        isTeamPost = function(teamId, object) return teamId == "P:alice" and object ~= nil end,
        record = function(teamId, text) records[#records + 1] = { teamId, text } end,
    }
    local alice = makePlayer("alice")
    call("MissionReport", alice)
    assertEq(Trust.get("C:alice"), 27, "+1 depuis le poste : +50 %, arrondi à 2")
    assertEq(records[1][1], "P:alice", "réponse notée au journal de l'équipe")
end

-- ----------------------------------------------------------------------------
-- Plaques d'identité
-- ----------------------------------------------------------------------------

function T.transmitted_dog_tag_gives_2_is_consumed_and_named_by_the_base()
    local alice = makePlayer("alice")
    local tag = giveTag(alice, 123456789, "John Doe")
    call("MissionDogTags", alice)
    assertEq(Trust.get("C:alice"), 27, "+2")
    assertEq(#alice.tags, 0, "plaque consommée")
    assertEq(REMOVED[1], tag, "retrait transmis aux clients")
    assertEq(STATE.missions.dogtags.ids["123456789"], "C:alice", "identifiant enregistré")
    assertEq(lastReply(alice).status, "ok", "réponse")
    assertEq(lastReply(alice).lines[1], "IGUI_MilitaryDrop_Reply_DogTags|" .. Teams.callsign("P:alice") .. "|John Doe",
        "la base cite le nom")
end

function T.blank_own_and_worn_dog_tags_are_not_transmitted()
    local alice = makePlayer("alice")
    giveTag(alice, 1, nil)
    giveTag(alice, 2, "Alice Smith")
    local worn = giveTag(alice, 3, "John Doe")
    alice.worn[worn] = true
    local pet = giveTag(alice, 4, "Rex")
    pet.tag = nil
    call("MissionDogTags", alice)
    assertEq(lastReply(alice).status, "noTags", "plaque vierge, la sienne, portée, d'animal : rien")
    assertEq(#alice.tags, 4, "tout est gardé")
    assertEq(Trust.get("C:alice"), 25, "aucun gain")
end

function T.a_dog_tag_is_credited_only_once()
    local alice = makePlayer("alice")
    giveTag(alice, 77, "John Doe")
    giveTag(alice, 77, "John Doe")
    call("MissionDogTags", alice)
    assertEq(Trust.get("C:alice"), 27, "doublon : un seul gain")
    assertEq(#alice.tags, 0, "le doublon est remis aussi")
    local lines = lastReply(alice).lines
    assertTrue(string.find(lines[2], "IGUI_MilitaryDrop_Reply_DogTagsKnown", 1, true) == 1, "déjà transmise")
    assertEq(select(2, Missions.creditDogTag(alice, "C:alice", { id = "77" })), "used", "API : déjà transmise")
    assertEq(Missions.isDogTagUsed(77), true, "registre")
end

function T.dog_tag_of_another_player_is_not_counted()
    local alice, bob = makePlayer("alice"), makePlayer("bob")
    giveTag(bob, 5, "John Doe")
    call("MissionDogTags", alice)
    assertEq(lastReply(alice).status, "noTags", "seul l'inventaire du joueur compte")
    assertEq(#bob.tags, 1, "plaque de l'autre joueur intacte")
    assertEq(Trust.get("C:alice"), 25, "aucun gain")
end

function T.dog_tags_are_kept_when_trust_is_already_at_maximum()
    local alice = makePlayer("alice")
    STATE.characterTrust = { ["C:alice"] = { value = 100 } }
    giveTag(alice, 2001, "John Doe")
    call("MissionDogTags", alice)
    assertEq(#alice.tags, 1, "plaque gardée pour plus tard")
    assertEq(STATE.missions.dogtags.ids["2001"], nil, "pas enregistrée")
    local lines = lastReply(alice).lines
    assertTrue(string.find(lines[#lines], "IGUI_MilitaryDrop_Reply_DogTagsFull", 1, true) ~= nil, "la base le dit")
end

function T.daily_cap_keeps_the_remaining_dog_tags()
    SandboxVars.MilitaryDrop.TrustDailyCap = 8
    local alice = makePlayer("alice")
    for i = 1, 6 do
        giveTag(alice, 1000 + i, "Soldier " .. i)
    end
    call("MissionDogTags", alice)
    assertEq(Trust.get("C:alice"), 33, "plafond réglé à 8 par jour")
    assertEq(#alice.tags, 2, "plaques au-delà du plafond gardées")
    local lines = lastReply(alice).lines
    assertTrue(string.find(lines[1], "IGUI_MilitaryDrop_NamesMoreOne|Soldier 1, Soldier 2, Soldier 3", 1, true) ~= nil,
        "trois noms puis « et un autre » : " .. lines[1])
    assertTrue(string.find(lines[#lines], "IGUI_MilitaryDrop_Reply_DogTagsCap", 1, true) ~= nil, "la base le dit")
    wait(24)
    call("MissionDogTags", alice)
    assertEq(Trust.get("C:alice"), 37, "lendemain : le reste est crédité")
    assertEq(#alice.tags, 0, "plus rien")
end

function T.credit_dog_tag_api_for_the_post_mailbox()
    assertEq(Missions.creditDogTag(makePlayer("alice"), "C:alice", { id = "42", name = "John Doe" }, { fromPost = true }), 3,
        "+2 depuis le poste : 3")
    assertEq(Missions.creditDogTag(makePlayer("alice"), "C:alice", { id = "42" }), nil, "jamais deux fois")
    assertEq(select(2, Missions.creditDogTag(makePlayer("alice"), "C:alice", { id = "x" })), "unknown", "identifiant mal formé")
    assertEq(select(2, Missions.creditDogTag(makePlayer("alice"), "C:alice", nil)), "unknown", "rien")
end

function T.trial_state_of_numbered_tags_does_not_break_loading()
    STATE.missions = { dogtags = { a = 5, b = 7, issued = 3, used = { ["12345678"] = "C:alice" } } }
    local alice = makePlayer("alice")
    giveTag(alice, 12345678, "John Doe")
    call("MissionDogTags", alice)
    assertEq(Trust.get("C:alice"), 27, "ancien numéro sans effet sur le nouvel identifiant")
    local tags = STATE.missions.dogtags
    assertEq(tags.used, nil, "ancien registre effacé")
    assertEq(tags.a, nil, "anciens paramètres effacés")
    STATE.missions.dogtags = "corrompu"
    assertEq(Missions.isDogTagUsed(1), false, "état illisible : repris à vide")
end

--- Zombie simulé : tenue, position, tueur, inventaire, tenue persistante.
local function makeZombie(outfit, x, y, killer, outfitId)
    local zombie = { kind = "IsoZombie", modData = {}, items = {}, outfit = outfit, x = x or 0, y = y or 0,
        killer = killer, outfitId = outfitId or 0 }
    function zombie.getModData(self) return self.modData end
    function zombie.getPersistentOutfitID(self) return self.outfitId end
    function zombie.getOutfitName(self) return self.outfit end
    function zombie.getX(self) return self.x end
    function zombie.getY(self) return self.y end
    function zombie.getAttackedBy(self) return self.killer end
    function zombie.getInventory(self)
        return {
            containsType = function(_, fullType)
                for _, item in ipairs(self.items) do
                    if item.fullType == fullType then
                        return true
                    end
                end
                return false
            end,
            AddItem = function(_, item) self.items[#self.items + 1] = item end,
        }
    end
    return zombie
end

function T.dead_soldiers_get_no_mod_dog_tag()
    local soldier = makeZombie("ArmyCamoGreen")
    triggerEvent("OnZombieDead", soldier)
    assertEq(#soldier.items, 0, "les plaques vanilla suffisent")
    assertEq(Missions.dropDogTag, nil, "tirage retiré")
end

-- ----------------------------------------------------------------------------
-- Planification
-- ----------------------------------------------------------------------------

function T.missions_are_scheduled_after_their_interval()
    makePlayer("alice")
    Missions.update()
    assertEq(STATE.missions.open.recon, nil, "rien au premier passage")
    assertEq(STATE.missions.nextHours.recon, WORLD_HOURS + 24, "prochaine reconnaissance après l'intervalle")
    assertEq(STATE.missions.nextHours.control, WORLD_HOURS + 24, "prochain appel de contrôle")
    wait(24)
    Missions.update()
    assertTrue(STATE.missions.open.recon ~= nil, "reconnaissance lancée")
    assertTrue(STATE.missions.open.control ~= nil, "appel de contrôle lancé")
    assertEq(STATE.missions.open.cleanup, nil, "nettoyage : intervalle de 48 h")
    local aired = AIRED[1]
    assertEq(aired[1][1], aired[2][1], "annonce répétée")
    assertTrue(string.find(aired[1][1], "IGUI_MilitaryDrop_Broadcast_Recon|300|400|48", 1, true) == 1,
        "grille et échéance annoncées : " .. aired[1][1])
end

function T.one_mission_of_each_kind_at_a_time()
    makePlayer("alice")
    assertTrue(Missions.launch("recon") ~= nil, "première")
    assertEq(Missions.launch("recon"), nil, "une seule reconnaissance à la fois")
end

function T.recon_announce_carries_the_map_marker_code()
    makePlayer("alice")
    local marked = nil
    MilitaryDrop.Broadcast.reconAnnounced = function(id, x, y)
        marked = { id = id, x = x, y = y }
        return "MDRC"
    end
    local mission = Missions.launch("recon")
    MilitaryDrop.Broadcast.reconAnnounced = nil
    assertEq(marked.id, mission.id, "repère envoyé pour cette mission")
    assertEq(marked.x .. "," .. marked.y, mission.x .. "," .. mission.y, "au point annoncé")
    local lines = AIRED[#AIRED]
    for i = 1, #lines - 1 do
        assertEq(lines[i][2], "MDRC", "ligne de grille " .. i .. " codée")
    end
    assertEq(lines[#lines][2], nil, "fin de transmission sans code")
    Missions.launch("control")
    assertEq(AIRED[#AIRED][1][2], nil, "autres missions sans repère")
end

function T.no_mission_without_players_channel_or_gain()
    assertEq(Missions.launch("control"), nil, "aucun joueur connecté")
    makePlayer("alice")
    MilitaryDrop.Broadcast.channel = nil
    assertEq(Missions.launch("control"), nil, "chaîne militaire absente")
    MilitaryDrop.Broadcast.channel = {}
    SandboxVars.MilitaryDrop.ControlGain = 0
    assertEq(Missions.launch("control"), nil, "source désactivée")
    Missions.update()
    assertEq(STATE.missions.nextHours.control, nil, "rien de planifié")
end

-- ----------------------------------------------------------------------------
-- Point des missions : terre ferme d'après la métagrille
-- ----------------------------------------------------------------------------

--- Carte simulée : eau à l'ouest de x = 1000 (ni bâtiment, ni route), terre à
--- l'est, bâtiments tous les 50 cases ; un trop grand, un construit par un
--- joueur, un souterrain, jamais visés.
local function coastMap()
    local buildings, centers = {}, {}
    for bx = 1000, 1500, 50 do
        for by = 500, 1500, 50 do
            buildings[#buildings + 1] = { x = bx, y = by, w = 12, h = 8 }
            centers[(bx + 6) .. "," .. (by + 4)] = true
        end
    end
    buildings[#buildings + 1] = { x = 1420, y = 980, w = 60, h = 60 }
    buildings[#buildings + 1] = { x = 1020, y = 1020, w = 6, h = 6, userDefined = true }
    buildings[#buildings + 1] = { x = 1030, y = 1030, w = 6, h = 6, basement = true }
    return buildings, centers
end

function T.recon_site_is_never_in_the_water()
    seededRandom(42)
    local buildings, centers = coastMap()
    GRID = makeGrid(buildings)
    makePlayer("alice", 1000, 1000)
    for i = 1, 60 do
        local mission = Missions.launch("recon")
        assertTrue(mission ~= nil, "mission " .. i)
        local key = mission.x .. "," .. mission.y
        assertTrue(mission.x >= 1000, "jamais à l'ouest (eau) : " .. key)
        assertTrue(centers[key], "centre d'un bâtiment visable : " .. key)
        local d = math.sqrt((mission.x - 1000) ^ 2 + (mission.y - 1000) ^ 2)
        assertTrue(d >= 150 - 1 and d <= 400 + 1, "dans l'anneau des largages : " .. d)
        STATE.missions.open.recon = nil
    end
    assertTrue(GRID.cellCalls > 0, "cellules interrogées une à une")
end

function T.recon_site_is_reachable_on_foot()
    -- Bâtiment de 40 × 40 au plus : son centre est à 20 cases de son bord,
    -- la confirmation (25 cases) se fait de l'extérieur.
    assertTrue(Missions.SITE_MAX_BUILDING / 2 < Missions.RECON_RADIUS, "centre à portée du bord")
    seededRandom(7)
    GRID = makeGrid({ { x = 1300, y = 1000, w = 41, h = 10 }, { x = 1200, y = 1000, w = 40, h = 40 } })
    local found = 0
    for _ = 1, 20 do
        local x, y, how = Missions.pickSite("recon", 1000, 1000)
        if how == "building" then
            found = found + 1
            assertEq(x .. "," .. y, "1220,1020", "seul le bâtiment de 40 cases")
        end
    end
    assertTrue(found > 0, "bâtiment trouvé")
end

function T.recon_site_falls_back_to_a_road_then_to_the_drop_point()
    seededRandom(3)
    local roads = {}
    for rx = 700, 1300, 100 do
        roads[#roads + 1] = { type = "Nav", x = rx, y = 0, w = 8, h = 2000 }
    end
    roads[#roads + 1] = { type = "Nav", x = 0, y = 1000, w = 2000, h = 8, polyline = true }
    roads[#roads + 1] = { type = "Forest", x = 0, y = 0, w = 4000, h = 4000 }
    GRID = makeGrid({}, roads)
    for _ = 1, 30 do
        local x, y, how = Missions.pickSite("recon", 1000, 1000)
        assertEq(how, "road", "aucun bâtiment : une route")
        assertTrue(x % 100 < 8 and x >= 700 and x <= 1307 and y >= 0 and y < 2000,
            "sur une route rectangulaire : " .. x .. "," .. y)
    end
    GRID = makeGrid({}, { { type = "Forest", x = 0, y = 0, w = 4000, h = 4000 } })
    local x, y, how = Missions.pickSite("recon", 1000, 1000)
    assertEq(how, "fallback", "ni bâtiment ni route : repli")
    assertEq(x .. "," .. y, "300,400", "point tiré comme un largage")
end

function T.cleanup_zone_is_centred_among_buildings()
    seededRandom(11)
    -- Hameau de 3 maisons au nord-est, maison isolée au sud-est (lac autour).
    local buildings = {
        { x = 1200, y = 800, w = 10, h = 10 }, { x = 1220, y = 810, w = 10, h = 10 },
        { x = 1210, y = 830, w = 10, h = 10 }, { x = 1250, y = 1150, w = 10, h = 10 },
    }
    GRID = makeGrid(buildings)
    local hamlet, isolated = 0, 0
    for _ = 1, 40 do
        local x, y, how = Missions.pickSite("cleanup", 1000, 1000)
        if how == "building" then
            hamlet = hamlet + 1
            assertTrue(x < 1240 and y < 900, "jamais la maison isolée : " .. x .. "," .. y)
        end
        local rx, ry, reconHow = Missions.pickSite("recon", 1000, 1000)
        if reconHow == "building" and rx > 1240 and ry > 1100 then
            isolated = isolated + 1
        end
    end
    assertTrue(hamlet > 0, "le hameau est visé")
    assertTrue(isolated > 0, "la reconnaissance peut viser la maison isolée")
end

function T.cleanup_announce_carries_its_map_marker_code_and_radius()
    makePlayer("alice")
    local marked = nil
    MilitaryDrop.Broadcast.cleanupAnnounced = function(id, x, y, radius)
        marked = { id = id, x = x, y = y, radius = radius }
        return "MDCU"
    end
    local mission = Missions.launch("cleanup")
    assertEq(marked.id, mission.id, "repère envoyé pour cette mission")
    assertEq(marked.x .. "," .. marked.y, mission.x .. "," .. mission.y, "au centre annoncé")
    assertEq(marked.radius, Missions.CLEANUP_RADIUS, "rayon de la zone")
    local lines = AIRED[#AIRED]
    for i = 1, #lines - 1 do
        assertEq(lines[i][2], "MDCU", "ligne de zone " .. i .. " codée")
    end
    assertEq(lines[#lines][2], nil, "fin de transmission sans code")
end

-- ----------------------------------------------------------------------------
-- SRC-03 reconnaissance
-- ----------------------------------------------------------------------------

function T.first_team_on_site_confirms_the_recon()
    local alice = makePlayer("alice", 100, 100)
    local bob = makePlayer("bob", 300, 400)
    Missions.launch("recon")
    call("MissionRecon", alice)
    assertEq(lastReply(alice).status, "tooFar", "loin de la grille")
    assertEq(Trust.get("C:alice"), 25, "aucun gain")
    alice.x, alice.y = 300.5 + 18, 400.5 + 18
    call("MissionRecon", alice)
    assertEq(lastReply(alice).status, "tooFar", "à 25,46 cases : hors du rayon de 25")
    alice.x, alice.y = 300.5 + 15, 400.5 + 20
    call("MissionRecon", alice)
    assertEq(Trust.get("C:alice"), 28, "première équipe à 25 cases : +3")
    call("MissionRecon", bob)
    assertEq(lastReply(bob).status, "noMission", "mission close pour les autres")
    assertEq(Trust.get("C:bob"), 25, "le second ne gagne rien")
    local closing = AIRED[#AIRED][1][1]
    assertTrue(string.find(closing, "IGUI_MilitaryDrop_Broadcast_ReconDone|300|400|", 1, true) == 1,
        "clôture annoncée : " .. closing)
    assertEq(STATE.missions.nextHours.recon, WORLD_HOURS + 24, "suivante après l'intervalle")
end

function T.recon_expires_after_48_hours()
    local alice = makePlayer("alice", 300, 400)
    Missions.launch("recon")
    wait(48)
    call("MissionRecon", alice)
    assertEq(lastReply(alice).status, "noMission", "échéance passée")
    Missions.update()
    assertEq(STATE.missions.open.recon, nil, "close")
    assertEq(STATE.missions.last.recon.outcome, "expired", "expirée")
    assertTrue(string.find(AIRED[#AIRED][1][1], "IGUI_MilitaryDrop_Broadcast_ReconExpired", 1, true) == 1,
        "annulation annoncée")
end

-- ----------------------------------------------------------------------------
-- SRC-04 nettoyage : horde signalée et suivie
-- ----------------------------------------------------------------------------

--- Zombie créé par spawnHorde (simulé) sur la case (x, y) : tenue persistante
--- tirée par NEXT_OUTFIT, ajouté à la liste des zombies de la cellule.
function SPAWN_ZOMBIE(x, y)
    local zombie = makeZombie("Horde", x + 0.3, y + 0.6, nil, NEXT_OUTFIT())
    ZLIST:add(zombie)
    HORDE_SPAWNED[#HORDE_SPAWNED + 1] = zombie
    return zombie
end

--- Zone chargée : carré de demi-côté r autour de (cx, cy).
local function loadArea(cx, cy, r)
    LOADED = function(x, y) return math.abs(x - cx) <= r and math.abs(y - cy) <= r end
end

--- Le joueur approche : la zone de la mission (300, 400) se charge.
local function spawnNow()
    loadArea(300, 400, 60)
    triggerEvent("LoadChunk", {})
    return HORDE_SPAWNED
end

local function hordeZombie(zombie, killer)
    zombie.killer = killer
    return zombie
end

local function cleanup()
    return STATE.missions.open.cleanup
end

local function lastBroadcast()
    return AIRED[#AIRED][1][1]
end

function T.horde_appears_once_when_the_centre_is_loaded()
    SandboxVars.MilitaryDrop.CleanupQuota = 12
    seededRandom(5)
    makePlayer("alice", 0, 0)
    Missions.launch("cleanup")
    assertEq(cleanup().horde, nil, "zone pas chargée : rien")
    loadArea(300 + 100, 400, 50)
    triggerEvent("LoadChunk", {})
    assertEq(cleanup().horde, nil, "chunk voisin chargé, pas le centre : rien")
    local spawned = spawnNow()
    local horde = cleanup().horde
    assertEq(#spawned, 12, "douze zombies")
    assertEq(horde.size, 12, "douze suivis")
    assertEq(horde.dead, 0, "aucun mort")
    local squares = {}
    for _, zombie in ipairs(spawned) do
        local dx, dy = zombie.x - 300.5, zombie.y - 400.5
        assertTrue(dx * dx + dy * dy <= 41 * 41, "dans le rayon de la zone")
        squares[math.floor(zombie.x) .. "," .. math.floor(zombie.y)] = true
    end
    local distinct = 0
    for _ in pairs(squares) do
        distinct = distinct + 1
    end
    assertEq(distinct, 12, "répartis : une case chacun")
    triggerEvent("LoadChunk", {})
    Missions.update()
    wait(1)
    Missions.update()
    assertEq(#HORDE_SPAWNED, 12, "une seule apparition par mission")
    -- Rien de la horde n'est envoyé aux clients.
    for _, sent in ipairs(SENT) do
        assertTrue(sent.command ~= "CleanupState" or sent.args.x == nil, "aucune position transmise")
    end
end

function T.horde_never_appears_among_players()
    SandboxVars.MilitaryDrop.CleanupQuota = 10
    seededRandom(9)
    local alice = makePlayer("alice", 0, 0)
    Missions.launch("cleanup")
    alice.x, alice.y = 300.5, 400.5
    loadArea(300, 400, 10)
    Missions.update()
    assertEq(cleanup().horde, nil, "seules des cases proches du joueur : rien, nouvel essai plus tard")
    loadArea(300, 400, 60)
    triggerEvent("LoadChunk", {})
    assertEq(cleanup().horde.size, 10, "apparue quand des cases éloignées sont chargées")
    for _, zombie in ipairs(HORDE_SPAWNED) do
        local dx, dy = zombie.x - alice.x, zombie.y - alice.y
        assertTrue(dx * dx + dy * dy >= (Missions.HORDE_NEAR - 1) ^ 2, "jamais au milieu des joueurs")
    end
end

function T.horde_waits_when_no_square_is_free()
    makePlayer("alice", 0, 0)
    Missions.launch("cleanup")
    loadArea(300, 400, 60)
    BLOCKED = setmetatable({}, { __index = function() return true end })
    triggerEvent("LoadChunk", {})
    assertEq(cleanup().horde, nil, "eau ou obstacles partout : rien")
    BLOCKED = {}
    Missions.update()
    assertTrue(cleanup().horde ~= nil, "essai suivant (toutes les 10 minutes)")
end

function T.horde_identifiers_survive_virtualization()
    assertEq(Missions.hordeKey(3 * 65536 + 7), "M196615", "tenue de la clé")
    local female = -2147483648 + 3 * 65536 + 7
    assertEq(Missions.hordeKey(female), "F196615", "femme : bit de signe (identifiant négatif)")
    assertEq(Missions.hordeKey(3 * 65536 + 7 + 32768), "M196615", "chapeau tombé : bit retiré")
    assertEq(Missions.hordeKey(female + 32768), Missions.hordeKey(female), "chapeau tombé : même clé")
    assertEq(Missions.hordeKey(0), nil, "sans tenue persistante : non suivi")
    SandboxVars.MilitaryDrop.CleanupQuota = 4
    local ids = { 5 * 65536 + 9, 5 * 65536 + 9, female, 0 }
    NEXT_OUTFIT = function() return table.remove(ids, 1) end
    makePlayer("alice", 0, 0)
    Missions.launch("cleanup")
    spawnNow()
    local horde = cleanup().horde
    assertEq(horde.size, 3, "le zombie sans tenue persistante n'est pas suivi")
    assertEq(horde.ids[Missions.hordeKey(5 * 65536 + 9)], 2, "même tenue, même variante : deux vivants")
    assertEq(horde.ids[Missions.hordeKey(female)], 1, "femme")
    -- Après virtualisation, ModData vidées : seule la tenue reste.
    local back = makeZombie("Horde", 900, 900, makePlayer("bob"), female + 32768)
    Missions.countKill(back)
    assertEq(horde.dead, 1, "reconnu à sa tenue, chapeau tombé, loin de la zone")
    assertEq(horde.ids[Missions.hordeKey(female)], nil, "plus aucun vivant de cette clé")
    Missions.countKill(makeZombie("Horde", 900, 900, makePlayer("carol"), female))
    assertEq(horde.dead, 1, "un autre zombie de même tenue ne compte plus")
end

function T.only_horde_zombies_count()
    SandboxVars.MilitaryDrop.CleanupQuota = 10
    local alice = makePlayer("alice", 0, 0)
    Missions.launch("cleanup")
    Missions.countKill(makeZombie("Tourist", 300, 400, alice, 77 * 65536 + 1))
    local horde = spawnNow()
    Missions.countKill(makeZombie("Tourist", 300, 400, alice, 77 * 65536 + 1))
    assertEq(cleanup().horde.dead, 0, "zombie de la zone hors horde : rien")
    assertEq(cleanup().counts["C:alice"], nil, "rien pour l'équipe")
    local zombie = hordeZombie(horde[1], alice)
    zombie.x, zombie.y = 2000, 2000
    Missions.countKill(zombie)
    Missions.countKill(zombie)
    assertEq(cleanup().horde.dead, 1, "zombie de la horde sorti de la zone : compté, une fois")
    assertEq(cleanup().counts["C:alice"], 1, "pour l'équipe du tueur")
end

function T.horde_deaths_without_a_player_count_only_for_the_rest()
    SandboxVars.MilitaryDrop.CleanupQuota = 10
    local alice = makePlayer("alice", 0, 0)
    Missions.launch("cleanup")
    local horde = spawnNow()
    Missions.countKill(hordeZombie(horde[1], nil))
    Missions.countKill(hordeZombie(horde[2], { kind = "IsoZombie" }))
    STATE.characterTrust = { ["C:alice"] = { value = 10, lockedUntil = WORLD_HOURS + 72 } }
    Missions.countKill(hordeZombie(horde[3], alice))
    assertEq(cleanup().horde.dead, 3, "feu, autre tueur, ligne coupée : comptés pour le reste")
    assertEq(cleanup().counts["C:alice"], nil, "ligne coupée : rien pour l'équipe")
end

function T.ninety_percent_closes_and_the_best_team_wins()
    assertEq(Missions.hordeTarget({ size = 30 }), 27, "30 : 27")
    assertEq(Missions.hordeTarget({ size = 31 }), 28, "31 : 28 (arrondi au supérieur)")
    assertEq(Missions.hordeTarget({ size = 10 }), 9, "10 : 9")
    assertEq(Missions.hordeTarget({ size = 1 }), 1, "1 : 1")
    SandboxVars.MilitaryDrop.CleanupQuota = 10
    local alice, bob = makePlayer("alice", 0, 0), makePlayer("bob", 0, 0)
    Missions.launch("cleanup")
    local horde = spawnNow()
    -- alice atteint 4 avant bob ; une mort par le feu complète les 9.
    local order = { alice, alice, bob, bob, bob, alice, alice, bob }
    for i, killer in ipairs(order) do
        Missions.countKill(hordeZombie(horde[i], killer))
    end
    assertTrue(cleanup() ~= nil, "8 sur 9 : encore ouvert")
    Missions.countKill(hordeZombie(horde[9], nil))
    assertEq(cleanup(), nil, "90 % de la horde morte : clos")
    assertEq(STATE.missions.last.cleanup.outcome, "done", "rempli")
    assertEq(STATE.missions.last.cleanup.character, "C:alice", "égalité 4-4 : la première à 4")
    assertEq(Trust.get("C:alice"), 30, "+5")
    assertEq(Trust.get("C:bob"), 25, "rien pour l'autre")
    assertTrue(string.find(lastBroadcast(), "IGUI_MilitaryDrop_Broadcast_CleanupDone|300|400|"
        .. Trust.name("C:alice"), 1, true) == 1, "clôture annoncée : " .. lastBroadcast())
    Missions.countKill(hordeZombie(horde[10], bob))
    assertEq(Trust.get("C:bob"), 25, "après la clôture : rien")
end

function T.the_character_with_the_most_kills_wins_even_in_the_same_faction()
    SandboxVars.MilitaryDrop.CleanupQuota = 3
    makeFaction("Rangers", "alice", { "bob" })
    local alice, bob = makePlayer("alice", 0, 0), makePlayer("bob", 0, 0)
    Missions.launch("cleanup")
    local horde = spawnNow()
    Missions.countKill(hordeZombie(horde[1], alice))
    Missions.countKill(hordeZombie(horde[2], bob))
    Missions.countKill(hordeZombie(horde[3], bob))
    assertEq(STATE.missions.last.cleanup.character, "C:bob", "deux contre un")
    assertEq(Trust.get("C:bob"), 30, "+5")
    assertEq(Trust.get("C:alice"), 25, "no collective reward")
end

function T.horde_destroyed_without_any_player_kill_closes_without_reward()
    SandboxVars.MilitaryDrop.CleanupQuota = 3
    makePlayer("alice", 0, 0)
    Missions.launch("cleanup")
    local horde = spawnNow()
    for i = 1, 3 do
        Missions.countKill(hordeZombie(horde[i], nil))
    end
    assertEq(cleanup(), nil, "clos")
    assertEq(STATE.missions.last.cleanup.outcome, "destroyed", "sans vainqueur")
    assertEq(Trust.get("C:alice"), 25, "aucune récompense")
    assertEq(lastBroadcast(), "IGUI_MilitaryDrop_Broadcast_CleanupNoWinner|300|400", "annonce sans vainqueur")
end

function T.team_is_frozen_at_the_kill()
    SandboxVars.MilitaryDrop.CleanupQuota = 10
    local faction = makeFaction("Rangers", "alice", { "bob" })
    local alice, bob = makePlayer("alice", 0, 0), makePlayer("bob", 0, 0)
    local team = Trust.idFor(alice)
    Missions.launch("cleanup")
    local horde = spawnNow()
    Missions.countKill(hordeZombie(horde[1], bob))
    faction.players = {}
    NOW_MS = NOW_MS + 5000
    Missions.countKill(hordeZombie(horde[2], bob))
    assertEq(cleanup().counts[team], nil, "Alice ne reçoit pas les morts de Bob")
    assertEq(cleanup().counts["C:bob"], 2, "changer de faction ne change pas le compteur personnel")
end

function T.cleanup_expires_after_72_hours()
    SandboxVars.MilitaryDrop.ReconGain = 0
    SandboxVars.MilitaryDrop.ControlGain = 0
    local alice = makePlayer("alice", 0, 0)
    Missions.launch("cleanup")
    local horde = spawnNow()
    wait(72)
    Missions.countKill(hordeZombie(horde[1], alice))
    Missions.update()
    assertEq(STATE.missions.last.cleanup.outcome, "expired", "expirée")
    assertEq(Trust.get("C:alice"), 25, "aucun gain")
    -- Sans apparition (zone jamais visitée) : expire aussi.
    STATE.missions.nextHours.cleanup = WORLD_HOURS
    LOADED = function() return false end
    Missions.update()
    assertTrue(cleanup() ~= nil and cleanup().horde == nil, "nouveau nettoyage, horde pas apparue")
    wait(72)
    Missions.update()
    assertEq(STATE.missions.last.cleanup.outcome, "expired", "expirée sans apparition")
    assertEq(string.find(lastBroadcast(), "IGUI_MilitaryDrop_Broadcast_CleanupExpired", 1, true), 1, "annoncée")
end

function T.old_cleanup_format_stays_readable()
    local alice = makePlayer("alice", 0, 0)
    STATE.missions = { open = { cleanup = { id = "M7", kind = "cleanup", openedHours = WORLD_HOURS,
        deadline = WORLD_HOURS + 72, text = "ancienne annonce", x = 300, y = 400, radius = 40, quota = 3,
        counts = { ["C:alice"] = 2 } } } }
    Missions.countKill(makeZombie("Army", 300, 400, alice, 65537))
    assertEq(cleanup().counts["C:alice"], nil, "anciens comptes collectifs archivés")
    local list = Missions.listForCharacter("C:alice")
    assertEq(list[1].spotted, false, "horde pas encore repérée")
    assertEq(list[1].progress, 0, "anciens comptes ignorés")
    call("MissionCleanupStatus", alice)
    assertEq(lastReply(alice).lines[1], "IGUI_MilitaryDrop_Reply_CleanupPending|" .. Teams.callsign("P:alice")
        .. "|300|400|40", "rendez-vous à la grille")
    local horde = spawnNow()
    assertEq(#horde, 3, "la horde apparaît à la prochaine arrivée")
    assertEq(cleanup().counts["C:alice"], nil, "comptes remis à zéro")
    Missions.countKill(hordeZombie(horde[1], alice))
    assertEq(cleanup().counts["C:alice"], 1, "seule la horde compte désormais")
end

function T.status_report_before_and_after_the_horde_appears()
    SandboxVars.MilitaryDrop.CleanupQuota = 10
    local alice, bob = makePlayer("alice", 0, 0), makePlayer("bob", 0, 0)
    call("MissionCleanupStatus", alice)
    local callsign = Teams.callsign("P:alice")
    assertEq(lastReply(alice).status, "noMission", "aucun nettoyage")
    assertEq(lastReply(alice).lines[1], "IGUI_MilitaryDrop_Reply_NoCleanup|" .. callsign, "la base le dit")
    Missions.launch("cleanup")
    call("MissionCleanupStatus", alice)
    assertEq(lastReply(alice).status, "ok", "réponse")
    assertEq(lastReply(alice).lines[1], "IGUI_MilitaryDrop_Reply_CleanupPending|" .. callsign .. "|300|400|40",
        "avant l'apparition : grille et rayon")
    local horde = spawnNow()
    Missions.countKill(hordeZombie(horde[1], alice))
    Missions.countKill(hordeZombie(horde[2], alice))
    Missions.countKill(hordeZombie(horde[3], bob))
    Missions.countKill(hordeZombie(horde[4], nil))
    call("MissionCleanupStatus", alice)
    assertEq(lastReply(alice).lines[1], "IGUI_MilitaryDrop_Reply_CleanupStatus|" .. callsign .. "|2|5",
        "deux abattus par la station ; reste 9 - 4 = 5 avant la clôture")
    assertEq(Trust.get("C:alice"), 25, "aucun gain pour faire le point")
    SandboxVars.MilitaryDrop.CleanupGain = 0
    call("MissionCleanupStatus", alice)
    assertEq(lastReply(alice).status, "disabled", "nettoyages désactivés")
end

function T.clients_learn_whether_a_cleanup_is_open()
    local alice = makePlayer("alice", 0, 0)
    local function lastState()
        for i = #SENT, 1, -1 do
            if SENT[i].command == "CleanupState" then
                return SENT[i]
            end
        end
        return nil
    end
    Missions.launch("cleanup")
    assertTrue(lastState().all and lastState().args.open == true, "ouverture annoncée à tous")
    Missions.sync(alice)
    assertTrue(lastState().player == alice and lastState().args.open == true, "à l'arrivée d'un joueur")
    wait(72)
    Missions.update()
    assertTrue(lastState().all and lastState().args.open == false, "clôture annoncée à tous")
end

function T.announce_speaks_of_a_horde_around_the_grid()
    SandboxVars.MilitaryDrop.CleanupQuota = 25
    makePlayer("alice", 0, 0)
    Missions.launch("cleanup")
    assertEq(AIRED[1][1][1], "IGUI_MilitaryDrop_Broadcast_Cleanup|300|400|40|25|72", "grille, rayon, taille, délai")
end

-- ----------------------------------------------------------------------------
-- SRC-05 appel de contrôle
-- ----------------------------------------------------------------------------

function T.every_character_that_answers_the_radio_check_gains_once()
    makeFaction("Rangers", "alice", { "bob" })
    local alice, bob = makePlayer("alice"), makePlayer("bob")
    Missions.launch("control")
    call("MissionControl", alice)
    call("MissionControl", bob)
    assertEq(Trust.get("C:alice"), 26, "première équipe : +1")
    assertEq(Trust.get("C:bob"), 26, "seconde équipe : +1 aussi")
    call("MissionControl", alice)
    assertEq(lastReply(alice).status, "already", "une fois par équipe")
    assertEq(Trust.get("C:alice"), 26, "pas de second gain")
end

function T.radio_check_closes_after_4_hours()
    local alice, bob = makePlayer("alice"), makePlayer("bob")
    Missions.launch("control")
    call("MissionControl", alice)
    wait(4)
    call("MissionControl", bob)
    assertEq(lastReply(bob).status, "noMission", "trop tard")
    assertEq(Trust.get("C:bob"), 25, "aucun gain")
    Missions.update()
    assertEq(AIRED[#AIRED][1][1], "IGUI_MilitaryDrop_Broadcast_ControlClosed|1", "clôture : une station a répondu")
end

function T.list_for_team_gives_open_missions_and_progress()
    SandboxVars.MilitaryDrop.CleanupQuota = 5
    local alice = makePlayer("alice")
    Missions.launch("cleanup")
    Missions.launch("control")
    call("MissionControl", alice)
    wait(1)
    local list = Missions.listForCharacter("C:alice")
    assertEq(#list, 2, "deux missions ouvertes")
    assertEq(list[1].kind, "cleanup", "ordre fixe")
    assertEq(list[1].spotted, false, "horde pas encore repérée")
    assertEq(list[1].progress, 0, "rien d'abattu")
    assertEq(list[1].left, nil, "pas de reste avant l'apparition")
    assertEq(list[1].quota, nil, "plus de quota par équipe")
    assertEq(list[1].deadlineHours, 71, "heures restantes")
    assertEq(list[2].kind, "control", "appel de contrôle")
    assertEq(list[2].progress, 1, "déjà confirmé")
    local horde = spawnNow()
    Missions.countKill(hordeZombie(horde[1], alice))
    list = Missions.listForCharacter("C:alice")
    assertEq(list[1].spotted, true, "horde repérée")
    assertEq(list[1].progress, 1, "abattus par l'équipe")
    assertEq(list[1].left, 4, "reste à abattre : 5 sur 5 (90 %, arrondi au supérieur) moins 1")
    assertEq(list[1].down, 1, "morts de la horde")
    assertEq(list[1].target, 5, "objectif")
    assertEq(#Missions.listForCharacter("C:bob")[1].title > 0, true, "titre")
    assertEq(Missions.listForCharacter("C:bob")[1].progress, 0, "autre équipe : rien")
    assertEq(Missions.listForCharacter("C:bob")[2].progress, 0, "autre équipe : rien")
end

function T.admin_launches_a_mission_on_demand()
    local alice = makePlayer("alice")
    local notices = {}
    local toPlayer, canForce = MilitaryDrop.Net.toPlayer, MilitaryDrop.Server.canForce
    MilitaryDrop.Net.toPlayer = function(player, command, args)
        if command == "Notice" then notices[#notices + 1] = args.key end
        return toPlayer(player, command, args)
    end
    MilitaryDrop.Server.canForce = function() return false end
    assertEq(Missions.adminLaunch(alice, { kind = "cleanup" }), "denied", "non-admin refusé")
    assertEq(STATE.missions and STATE.missions.open.cleanup, nil, "rien de lancé")
    MilitaryDrop.Server.canForce = function() return true end
    assertEq(Missions.adminLaunch(alice, { kind = "boom" }), "invalid", "type inconnu")
    assertEq(Missions.adminLaunch(alice, { kind = "cleanup" }), "launched", "admin : lancée")
    assertTrue(STATE.missions.open.cleanup ~= nil, "mission ouverte comme une mission planifiée")
    assertEq(notices[#notices], "IGUI_MilitaryDrop_AdminMission_Launched", "réponse privée")
    assertEq(Missions.adminLaunch(alice, { kind = "cleanup" }) == "launched", false, "pas deux à la fois")
    assertEq(Missions.adminLaunch(alice, { kind = "cleanup" }), "busy", "cadence d'une seconde")
    NOW_MS = NOW_MS + 5000
    local aired = #AIRED
    assertEq(Missions.adminLaunch(alice, { kind = "cleanup", action = "close" }), "closed", "clôture admin")
    assertEq(STATE.missions.open.cleanup, nil, "plus de nettoyage en cours")
    assertEq(STATE.missions.last.cleanup.outcome, "cancelled", "issue notée")
    assertTrue(#AIRED > aired and string.find(AIRED[#AIRED][1][1], "IGUI_MilitaryDrop_Broadcast_CleanupExpired", 1, true) == 1,
        "annonce d'annulation")
    NOW_MS = NOW_MS + 5000
    assertEq(Missions.adminLaunch(alice, { kind = "cleanup", action = "close" }), "none", "rien à clore")
    MilitaryDrop.Net.toPlayer = toPlayer
    MilitaryDrop.Server.canForce = canForce
end


function T.private_report_payload_never_uses_server_translations()
    local alice = makePlayer("alice")
    getText = function() error("server must not translate private replies") end
    call("MissionReport", alice)
    call("MissionReport", alice)
    local args = SENT[#SENT].args
    assertEq(args.status, "already", "second rapport le même jour")
    assertEq(args.lines[1].key, "IGUI_MilitaryDrop_Reply_ReportAlready", "clé réseau")
    assertEq(args.lines[1].params[1], Teams.callsign("P:alice"), "indicatif conservé")
    getText = function(key, callsign) return "FR: " .. callsign .. " — rapport déjà reçu" end
    assertTrue(MilitaryDrop.Exchange.lineText(args.lines[1]):find("rapport déjà reçu", 1, true) ~= nil,
        "résolution par le client après réception")
end

return T
