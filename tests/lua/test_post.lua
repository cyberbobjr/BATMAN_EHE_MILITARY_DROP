-- MilitaryDrop_Post : poste de liaison. Éligibilité par propriétés, un poste
-- par équipe (déplacement), désinstallation d'une radio disparue, autre équipe
-- refusée, journal reçu ou « aucune réception » selon l'état réel ou
-- l'instantané (secteur, générateur projeté, pile figée), borne de 200
-- entrées, boîte à courrier (plaques vanilla renommées : dépôt, transmission,
-- noms cités au journal, état v1.3 d'essai), aucune donnée d'une autre
-- équipe, annonces de la chaîne militaire au journal.

local T = {}

local CHANNEL = 151400

local function arrayList(values)
    return {
        size = function() return #values end,
        get = function(_, i) return values[i + 1] end,
        indexOf = function(_, value)
            for i, v in ipairs(values) do
                if v == value then
                    return i - 1
                end
            end
            return -1
        end,
    }
end

local function key(x, y, z)
    return x .. "," .. y .. "," .. z
end

--- Case simulée : secteur et pièce par défaut, sans générateur.
local function makeSquare(x, y, z)
    local square = { x = x, y = y, z = z or 0, objects = {}, grid = true, room = true, elec = false, chunk = "A" }
    function square.getX(self) return self.x end
    function square.getY(self) return self.y end
    function square.getZ(self) return self.z end
    function square.getObjects(self) return arrayList(self.objects) end
    function square.hasGridPower(self) return self.grid end
    function square.getRoom(self) return self.room and {} or nil end
    function square.haveElectricity(self) return self.elec end
    function square.getChunk(self) return self.chunk end
    SQUARES[key(x, y, square.z)] = square
    return square
end

--- Radio posée simulée ; par défaut éligible (fixe, haut de gamme, émettrice),
--- allumée sur le canal militaire, sur secteur.
local function makeRadio(square, overrides)
    local data = { on = true, channel = CHANNEL, portable = false, high = true, twoWay = true,
        battery = false, power = 1, powered = true }
    for name, value in pairs(overrides or {}) do
        data[name] = value
    end
    local device = {}
    function device.getIsTurnedOn() return data.on end
    function device.getChannel() return data.channel end
    function device.getIsPortable() return data.portable end
    function device.getIsHighTier() return data.high end
    function device.getIsTwoWay() return data.twoWay end
    function device.getIsBatteryPowered() return data.battery end
    function device.getPower() return data.power end
    function device.canBePoweredHere() return data.battery or data.powered end
    local radio = { kind = "IsoWaveSignal", data = data, modData = {}, square = square }
    function radio.getDeviceData() return device end
    function radio.getModData(self) return self.modData end
    function radio.getSquare(self) return self.square end
    function radio.getObjectIndex(self)
        for i, object in ipairs(self.square.objects) do
            if object == self then
                return i - 1
            end
        end
        return -1
    end
    function radio.transmitModData() end
    table.insert(square.objects, radio)
    return radio
end

local function removeObject(object)
    local objects = object.square.objects
    for i = #objects, 1, -1 do
        if objects[i] == object then
            table.remove(objects, i)
        end
    end
end

local function makeGenerator(square, fuel, rate)
    local generator = { kind = "IsoGenerator", fuel = fuel, rate = rate, active = true, square = square }
    function generator.isActivated(self) return self.active end
    function generator.getFuel(self) return self.fuel end
    function generator.getTotalPowerUsing(self) return self.rate end
    function generator.getSquare(self) return self.square end
    table.insert(square.objects, generator)
    return generator
end

--- Objet simulé ; soldier : plaque vanilla (tag base:dogtag) renommée par
--- nameAfterDescriptor, false : plaque vierge, nil : autre objet.
local function makeItem(id, soldier)
    local item = { id = id, tag = soldier ~= nil and "base:dogtag" or nil,
        name = soldier and ("Dog Tags: " .. soldier) or "Dog Tags" }
    function item.getID(self) return self.id end
    function item.hasTag(self, itemTag) return self.tag == itemTag end
    function item.getDisplayName(self) return self.name end
    function item.getScriptItem() return { getDisplayName = function() return "Dog Tags" end } end
    function item.getContainer(self) return self.container end
    return item
end

local function makeInventory(items)
    local inventory = { items = {} }
    function inventory.getItemWithIDRecursiv(self, id)
        for _, item in ipairs(self.items) do
            if item.id == id then
                return item
            end
        end
        return nil
    end
    function inventory.AddItem(self, item)
        item.container = self
        self.items[#self.items + 1] = item
        return item
    end
    function inventory.Remove(self, item)
        for i = #self.items, 1, -1 do
            if self.items[i] == item then
                table.remove(self.items, i)
                item.container = nil
            end
        end
    end
    for _, item in ipairs(items or {}) do
        item.container = inventory
        inventory.items[#inventory.items + 1] = item
    end
    return inventory
end

local function makePlayer(name, x, y, z, items)
    local player = { name = name, x = x, y = y, z = z or 0, inventory = makeInventory(items), equipped = {} }
    function player.getUsername(self) return self.name end
    function player.getX(self) return self.x end
    function player.getY(self) return self.y end
    function player.getZ(self) return self.z end
    function player.getInventory(self) return self.inventory end
    function player.isEquipped(self, item) return self.equipped[item] == true end
    function player.isAttachedItem() return false end
    function player.isDead() return false end
    function player.getDescriptor()
        return { getForename = function() return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) end,
            getSurname = function() return "Smith" end }
    end
    PLAYERS[name] = player
    function player.getModData(self)
        self.characterData = self.characterData or { MilitaryDrop_characterId = "C:" .. self:getUsername() }
        return self.characterData
    end
    return player
end

local function makeFaction(name, owner, players)
    local faction = { name = name, owner = owner, players = players }
    function faction.getName(self) return self.name end
    function faction.getOwner(self) return self.owner end
    function faction.getPlayers(self) return arrayList(self.players) end
    FACTIONS[#FACTIONS + 1] = faction
    return faction
end

function T.setup()
    SandboxVars = { MilitaryDrop = { Frequency = 151.4 } }
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    STATE = {}
    WORLD_HOURS = 1000
    CLOCK = 24 * 100 + 12
    getGameTime = function() return { getWorldAgeHours = function() return WORLD_HOURS end } end
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
    ZombRand = function() return 0 end
    FACTIONS = {}
    Faction = { getFactions = function() return arrayList(FACTIONS) end }
    SQUARES = {}
    LOADED = true
    getCell = function()
        return { getGridSquare = function(_, x, y, z)
            if not LOADED then
                return nil
            end
            return SQUARES[key(x, y, z)]
        end }
    end
    GRID = true
    getSandboxOptions = function() return { doesPowerGridExist = function() return GRID end } end
    getText = function(k, a, b) return k .. "|" .. tostring(a) .. "|" .. tostring(b) end
    PLAYERS = {}
    SENT = {}
    sendServerCommand = function(player, module, command, args)
        SENT[#SENT + 1] = { player = player, command = command, args = args }
    end
    sendRemoveItemFromContainer = function() end
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function() return PLAYERS.alice end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    ItemTag = { DOG_TAG = "base:dogtag" }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Exchange.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    -- État privé (ModData au nom tiré de la graine, jamais transmise).
    PUBLIC = {}
    MilitaryDrop.Secrets = { privateState = function() return STATE end }
    MilitaryDrop.Server = {
        -- État public (lisible par les clients) : rien de la v1.3 n'y va.
        getState = function() return PUBLIC end,
        clock = function() return CLOCK end,
        findPlayer = function(name) return PLAYERS[name] end,
        COMMANDS = {},
    }
    -- Solo : Net.toPlayer appelle le client directement.
    MilitaryDrop.Client = { onServerCommand = function(_, command, args)
        SENT[#SENT + 1] = { command = command, args = args }
    end }
    AIRED = {}
    MilitaryDrop.Broadcast = {
        channel = {},
        inbound = function() AIRED[#AIRED + 1] = "inbound" end,
        dropped = function(x, y) AIRED[#AIRED + 1] = "dropped " .. x .. "," .. y end,
    }
    loadMod("server/MilitaryDrop/MilitaryDrop_Teams.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Post.lua")
    Post = MilitaryDrop.Post
    Teams = MilitaryDrop.Teams
    COMMANDS = MilitaryDrop.Server.COMMANDS
    SQUARE = makeSquare(100, 100, 0)
    RADIO = makeRadio(SQUARE)
    ALICE = makePlayer("alice", 101, 100, 0)
end

--- Commande d'un client (après l'intervalle anti-rafale, 3 s pour une transmission).
local function command(name, player, args)
    NOW_MS = NOW_MS + 3000
    COMMANDS[name](player, args or {})
end

local function ref(object)
    return MilitaryDrop.Radio.makeRef(object)
end

local function lastSent(commandName, player)
    for i = #SENT, 1, -1 do
        local sent = SENT[i]
        if sent.command == commandName and (player == nil or sent.player == nil or sent.player == player) then
            return sent.args
        end
    end
    return nil
end

local function install(player, radio)
    command("PostInstall", player, { radio = ref(radio) })
    return lastSent("PostResult", player)
end

local function log(teamId)
    return STATE.postLogs and STATE.postLogs[teamId] or {}
end

local function lastEntry(teamId)
    local lines = log(teamId)
    return lines[#lines] or {}
end

local function wait(hours)
    WORLD_HOURS = WORLD_HOURS + hours
    CLOCK = CLOCK + hours
    NOW_MS = NOW_MS + 1000
end

--- Mode MP (serveur dédié) : alice et bob dans une faction, mallory seule.
local function multiplayer()
    isServer = function() return true end
    makeFaction("Rangers", "alice", { "bob" })
end

-- ----------------------------------------------------------------------------
-- Éligibilité et installation
-- ----------------------------------------------------------------------------

function T.eligibility_uses_device_properties_only()
    assertTrue(Post.isEligible(RADIO), "fixe, haut de gamme, émettrice")
    local square = makeSquare(50, 50, 0)
    assertEq(Post.isEligible(makeRadio(square, { portable = true })), false, "talkie posé : portable")
    assertEq(Post.isEligible(makeRadio(square, { high = false })), false, "radio civile")
    assertEq(Post.isEligible(makeRadio(square, { twoWay = false })), false, "récepteur seul")
    local item = { kind = "Radio", getDeviceData = RADIO.getDeviceData }
    assertEq(Post.isEligible(item), false, "radio d'inventaire")
end

function T.install_registers_the_team_post()
    local result = install(ALICE, RADIO)
    assertEq(result.status, "installed", "installé")
    local post = STATE.posts.SOLO
    assertEq(post.x, 100, "x")
    assertEq(post.z, 0, "z")
    assertEq(RADIO.modData[Post.UID_KEY], post.uid, "uid dans la ModData de l'objet")
    assertTrue(Post.isTeamPost("SOLO", RADIO), "poste de l'équipe")
    assertEq(lastSent("PostInfo").x, 100, "position envoyée aux membres")
    assertEq(lastEntry("SOLO").sys, "installed", "entrée système au journal")
    assertEq(install(ALICE, RADIO).status, "already", "déjà le poste")
end

function T.installing_elsewhere_moves_the_single_post()
    install(ALICE, RADIO)
    local square = makeSquare(102, 100, 0)
    local other = makeRadio(square)
    assertEq(install(ALICE, other).status, "moved", "déplacé")
    assertEq(STATE.posts.SOLO.x, 102, "un seul poste, à la nouvelle place")
    assertEq(RADIO.modData[Post.UID_KEY], nil, "l'ancienne radio n'est plus le poste")
    assertEq(Post.isTeamPost("SOLO", RADIO), false, "ancienne radio")
    assertTrue(Post.isTeamPost("SOLO", other), "nouvelle radio")
end

function T.ineligible_or_distant_radio_is_refused()
    local square = makeSquare(99, 100, 0)
    assertEq(install(ALICE, makeRadio(square, { portable = true })).status, "notEligible", "talkie posé")
    ALICE.x = 110
    assertEq(install(ALICE, RADIO).status, "tooFar", "trop loin")
    assertEq((STATE.posts or {}).SOLO, nil, "rien d'installé")
end

function T.forged_reference_is_refused()
    command("PostInstall", ALICE, { radio = { kind = "world", x = 100, y = 100, z = 0, index = 7 } })
    assertEq(lastSent("PostResult").status, "tooFar", "index hors de la case")
    command("PostInstall", ALICE, { radio = "n'importe quoi" })
    assertEq(lastSent("PostResult").status, "tooFar", "référence invalide")
    assertEq((STATE.posts or {}).SOLO, nil, "rien d'installé")
end

-- ----------------------------------------------------------------------------
-- Désinstallation
-- ----------------------------------------------------------------------------

function T.picked_up_radio_uninstalls_the_post()
    install(ALICE, RADIO)
    removeObject(RADIO)
    assertEq(Post.isTeamPost("SOLO", RADIO), false, "objet retiré (getObjectIndex = -1)")
    triggerEvent("EveryOneMinute")
    assertEq(STATE.posts.SOLO, nil, "désinstallé à la vérification")
    assertEq(lastEntry("SOLO").sys, "lost", "trou expliqué au journal")
    assertTrue(lastSent("PostInfo").none, "les membres l'apprennent")
end

function T.replaced_radio_on_the_same_square_is_not_the_post()
    install(ALICE, RADIO)
    removeObject(RADIO)
    makeRadio(SQUARE)
    Post.record(nil, "ligne")
    assertEq(STATE.posts.SOLO, nil, "nouvelle radio sans uid : poste désinstallé à l'usage")
end

function T.unloaded_post_is_not_uninstalled()
    install(ALICE, RADIO)
    LOADED = false
    triggerEvent("EveryOneMinute")
    Post.record(nil, "ligne")
    assertTrue(STATE.posts.SOLO ~= nil, "case déchargée : rien à constater")
end

function T.chunk_load_checks_the_posts_it_contains()
    install(ALICE, RADIO)
    removeObject(RADIO)
    triggerEvent("LoadChunk", "B")
    assertTrue(STATE.posts.SOLO ~= nil, "autre chunk : rien")
    triggerEvent("LoadChunk", "A")
    assertEq(STATE.posts.SOLO, nil, "chunk du poste chargé sans la radio : désinstallé")
end

-- ----------------------------------------------------------------------------
-- Autre équipe
-- ----------------------------------------------------------------------------

function T.other_team_cannot_install_on_or_use_the_post()
    multiplayer()
    install(ALICE, RADIO)
    local team = Teams.idFor("alice")
    Post.record(team, "Ligne privée de la station")
    local tag = makeItem(7, "11-111")
    local mallory = makePlayer("mallory", 99, 100, 0, { tag })
    local before = #SENT
    assertEq(install(mallory, RADIO).status, "otherTeam", "installation refusée")
    command("PostOpen", mallory, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult", mallory).status, "otherTeam", "console refusée")
    command("PostDeposit", mallory, { radio = ref(RADIO), items = { 7 } })
    command("PostTransmit", mallory, { radio = ref(RADIO) })
    assertEq(#mallory.inventory.items, 1, "sa plaque reste dans son inventaire")
    for i = before + 1, #SENT do
        local sent = SENT[i]
        if sent.player == mallory then
            assertEq(sent.command, "PostResult", "seulement des refus")
            assertEq(sent.args.lines, nil, "aucun journal")
            assertEq(sent.args.mail, nil, "aucun courrier")
            assertEq(sent.args.callsign, nil, "aucun indicatif")
        end
    end
    assertEq(STATE.posts[team].uid, RADIO.modData[Post.UID_KEY], "le poste reste à l'équipe")
end

function T.team_member_uses_the_post_of_the_faction()
    multiplayer()
    install(ALICE, RADIO)
    local bob = makePlayer("bob", 100, 101, 0)
    command("PostOpen", bob, { radio = ref(RADIO) })
    local data = lastSent("PostData", bob)
    assertTrue(data ~= nil, "console ouverte pour un membre")
    assertEq(data.callsign, Teams.callsign(Teams.idFor("alice")), "indicatif de la faction")
end

function T.position_is_sent_only_to_team_members()
    multiplayer()
    makePlayer("bob", 0, 0, 0)
    local mallory = makePlayer("mallory", 0, 0, 0)
    install(ALICE, RADIO)
    for _, sent in ipairs(SENT) do
        if sent.command == "PostInfo" then
            assertTrue(sent.player ~= mallory, "mallory ne reçoit pas la position")
        end
    end
    assertTrue(lastSent("PostInfo", PLAYERS.bob) ~= nil, "bob la reçoit")
end

-- ----------------------------------------------------------------------------
-- Journal : poste chargé
-- ----------------------------------------------------------------------------

function T.loaded_post_records_what_it_receives()
    install(ALICE, RADIO)
    Post.record(nil, "Annonce 1")
    assertEq(lastEntry("SOLO").t.text, "Annonce 1", "reçue")
    RADIO.data.on = false
    Post.record(nil, "Annonce 2")
    Post.record(nil, "Annonce 3")
    assertEq(lastEntry("SOLO").gap, 2, "éteint : une entrée « aucune réception » regroupée")
    RADIO.data.on = true
    Post.record(nil, "Annonce 4")
    assertEq(lastEntry("SOLO").t.text, "Annonce 4", "rallumé")
end

function T.loaded_post_needs_channel_power_and_battery()
    install(ALICE, RADIO)
    RADIO.data.channel = CHANNEL + 200
    Post.record(nil, "a")
    assertEq(lastEntry("SOLO").gap, 1, "autre canal")
    RADIO.data.channel = CHANNEL
    RADIO.data.powered = false
    Post.record(nil, "b")
    assertEq(lastEntry("SOLO").gap, 2, "sans courant")
    RADIO.data.battery = true
    RADIO.data.power = 0
    Post.record(nil, "c")
    assertEq(lastEntry("SOLO").gap, 3, "pile vide (canBePoweredHere toujours vrai sur pile)")
    RADIO.data.power = 0.3
    Post.record(nil, "d")
    assertEq(lastEntry("SOLO").t.text, "d", "pile chargée")
end

function T.same_line_recorded_twice_is_kept_once()
    install(ALICE, RADIO)
    Post.record(nil, "Coordonnées")
    Post.record(nil, "Coordonnées")
    assertEq(#log("SOLO"), 2, "entrée système + une ligne")
    wait(1)
    Post.record(nil, "Coordonnées")
    assertEq(#log("SOLO"), 3, "même texte plus tard : nouvelle ligne")
end

function T.journal_is_bounded_to_200_entries()
    install(ALICE, RADIO)
    for i = 1, 250 do
        Post.record(nil, "ligne " .. i)
    end
    local lines = log("SOLO")
    assertEq(#lines, 200, "200 entrées")
    assertEq(lines[1].t.text, "ligne 51", "les plus anciennes sont oubliées")
    assertEq(lines[200].t.text, "ligne 250", "la plus récente est gardée")
end

function T.team_line_goes_only_to_that_team()
    multiplayer()
    install(ALICE, RADIO)
    local mallory = makePlayer("mallory", 201, 200, 0)
    install(mallory, makeRadio(makeSquare(200, 200, 0)))
    local rangers, alone = Teams.idFor("alice"), Teams.idFor("mallory")
    Post.record(rangers, "Pour les Rangers")
    assertEq(lastEntry(rangers).t.text, "Pour les Rangers", "équipe visée")
    assertEq(lastEntry(alone).sys, "installed", "l'autre équipe n'a rien")
    Post.record(nil, "À toutes les stations")
    assertEq(lastEntry(alone).t.text, "À toutes les stations", "toutes les stations")
end

function T.team_without_post_gets_nothing()
    Post.record("SOLO", "rien")
    Post.record(nil, "rien")
    assertEq(STATE.postLogs == nil or STATE.postLogs.SOLO == nil, true, "pas de journal sans poste")
end

-- ----------------------------------------------------------------------------
-- Journal : poste hors de la zone chargée
-- ----------------------------------------------------------------------------

function T.unloaded_mains_post_follows_the_global_grid()
    install(ALICE, RADIO)
    LOADED = false
    Post.record(nil, "réseau en service")
    assertEq(lastEntry("SOLO").t.text, "réseau en service", "secteur : réseau global en service")
    GRID = false
    Post.record(nil, "réseau coupé")
    assertEq(lastEntry("SOLO").gap, 1, "réseau global coupé depuis")
end

function T.unloaded_post_keeps_the_last_snapshot_state()
    install(ALICE, RADIO)
    RADIO.data.on = false
    triggerEvent("EveryOneMinute")
    LOADED = false
    RADIO.data.on = true
    Post.record(nil, "a")
    assertEq(lastEntry("SOLO").gap, 1, "éteint à la dernière observation")
end

function T.unloaded_generator_post_projects_its_fuel()
    SQUARE.grid = false
    SQUARE.elec = true
    makeGenerator(makeSquare(105, 100, 0), 1, 0.1)
    install(ALICE, RADIO)
    assertEq(STATE.posts.SOLO.snapshot.source, "generator", "source : générateur")
    LOADED = false
    wait(5)
    Post.record(nil, "5 h plus tard")
    assertEq(lastEntry("SOLO").t.text, "5 h plus tard", "carburant projeté : 0,5")
    wait(6)
    Post.record(nil, "11 h plus tard")
    assertEq(lastEntry("SOLO").gap, 1, "carburant projeté épuisé")
end

function T.generator_out_of_range_is_ignored()
    SQUARE.grid = false
    SQUARE.elec = true
    makeGenerator(makeSquare(130, 100, 0), 10, 0.1)
    install(ALICE, RADIO)
    assertEq(STATE.posts.SOLO.snapshot.source, "none", "au-delà de 20 cases")
end

function T.unloaded_battery_post_keeps_its_frozen_charge()
    RADIO.data.battery = true
    RADIO.data.power = 0.4
    install(ALICE, RADIO)
    LOADED = false
    GRID = false
    wait(500)
    Post.record(nil, "toujours")
    assertEq(lastEntry("SOLO").t.text, "toujours", "pile figée hors chargement")
end

function T.unloaded_empty_battery_post_receives_nothing()
    RADIO.data.battery = true
    RADIO.data.power = 0
    install(ALICE, RADIO)
    LOADED = false
    Post.record(nil, "rien")
    assertEq(lastEntry("SOLO").gap, 1, "pile vide")
end

-- ----------------------------------------------------------------------------
-- Annonces de la chaîne militaire
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- Console et boîte à courrier
-- ----------------------------------------------------------------------------

function T.console_data_has_labels_but_no_trust_number()
    WORLD_HOURS = 1000
    MilitaryDrop.Missions = { listForCharacter = function(teamId)
        assertEq(teamId, "C:alice", "missions du personnage")
        -- Format du module des missions : deadline absolue, deadlineHours restantes.
        return { { kind = "cleanup", title = "Nettoyage", text = "Zone", deadline = 1030, deadlineHours = 30,
            progress = 12, hours = 72, x = 300.5, y = 400, spotted = true, left = 9, down = 18, target = 27 },
            { kind = "control", title = "Contrôle", deadlineHours = 2 } }
    end }
    install(ALICE, RADIO)
    command("PostOpen", ALICE, { radio = ref(RADIO) })
    local data = lastSent("PostData")
    assertEq(data.callsign, Teams.callsign("SOLO"), "indicatif")
    assertEq(data.channel, CHANNEL, "fréquence du poste")
    assertEq(data.power, "grid", "alimentation")
    assertEq(data.tier, 2, "palier d'une équipe neuve à 25 (libellé côté client)")
    assertEq(data.value, nil, "aucune note chiffrée")
    assertEq(data.receiving, nil, "rien ne dit si le canal est le bon")
    assertEq(data.missions[1].remaining, 30, "échéance restante")
    assertEq(data.missions[1].progress, 12, "abattus par l'équipe")
    assertEq(data.missions[1].spotted, true, "horde repérée")
    assertEq(data.missions[1].left .. "/" .. data.missions[1].down .. "/" .. data.missions[1].target, "9/18/27",
        "reste, morts et objectif de la horde")
    assertEq(data.missions[2].spotted, nil, "rien de la horde pour l'appel de contrôle")
    assertEq(data.missions[2].remaining, 2, "sans échéance absolue : heures restantes")
    assertEq(data.missions[1].hours, 72, "durée totale (barre de temps)")
    assertEq(data.missions[1].x .. "," .. data.missions[1].y, "300,400", "grille annoncée, en cases entières")
    assertEq(data.missions[2].x, nil, "pas de grille pour l'appel de contrôle")
    assertEq(data.battery, nil, "poste sur secteur : pas de charge envoyée")
    assertEq(data.lines[1].sys, "installed", "journal")
end

function T.dog_tags_are_deposited_then_transmitted()
    CREDITS = {}
    MilitaryDrop.Missions = {
        creditDogTag = function(player, teamId, tag, opts)
            CREDITS[#CREDITS + 1] = { player = player, teamId = teamId, tag = tag, fromPost = opts.fromPost }
            return 2
        end,
        dogTagReplyLines = function(callsign, credited)
            return { "merci " .. table.concat(credited, ", ") }
        end,
    }
    local tag1 = makeItem(1, "12-345")
    local tag2 = makeItem(2, "Soldier 678")
    local worn = makeItem(3, "99-999")
    local other = makeItem(4, nil)
    local blank = makeItem(5, false)
    ALICE.inventory = makeInventory({ tag1, tag2, worn, other, blank })
    ALICE.equipped[worn] = true
    install(ALICE, RADIO)
    command("PostDeposit", ALICE, { radio = ref(RADIO), items = { 1, 2, 2, 3, 4, 5, 99, "x" } })
    assertEq(lastSent("PostResult").status, "deposited", "dépôt")
    assertEq(lastSent("PostResult").count, 2, "deux plaques valables")
    assertEq(#ALICE.inventory.items, 3, "retirées de l'inventaire par le serveur")
    local mail = STATE.postMail.SOLO
    assertEq(mail[1].id, "1", "identifiant de l'objet")
    assertEq(mail[1].name, "12-345", "nom du soldat")
    assertEq(mail[2].name, "Soldier 678", "nom du soldat")
    assertEq(mail[1].by, "alice", "déposée par")
    local sent = lastSent("PostData").mail
    assertEq(#sent, 2, "console rafraîchie")
    assertEq(sent[1].id, "1", "contrat : id")
    assertEq(sent[1].name, "12-345", "contrat : name")
    assertEq(sent[1].by, "alice", "contrat : by")
    assertEq(sent[1].c, nil, "contrat : rien d'autre")

    command("PostTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "transmitted", "transmis")
    assertEq(#CREDITS, 2, "chaque plaque créditée")
    assertEq(CREDITS[1].teamId, "SOLO", "équipe")
    assertEq(CREDITS[1].tag.id, "1", "identifiant transmis")
    assertEq(CREDITS[1].tag.name, "12-345", "nom transmis")
    assertEq(CREDITS[1].fromPost, true, "bonus du poste (POSTE-06)")
    assertEq(#STATE.postMail.SOLO, 0, "boîte vidée")
    local journal = log("SOLO")
    assertEq(journal[#journal].t.text, "merci 12-345, Soldier 678", "la base cite les noms au journal")
    command("PostTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "emptyMail", "boîte vide")
end

function T.refused_tags_wait_or_are_consumed_by_reason()
    MilitaryDrop.Missions = { creditDogTag = function(_, _, tag)
        if tag.name == "cap" then
            return nil, "dailyCap"
        elseif tag.name == "used" then
            return nil, "used"
        end
        return 0
    end }
    ALICE.inventory = makeInventory({ makeItem(1, "cap"),
        makeItem(2, "used"), makeItem(3, "ok") })
    install(ALICE, RADIO)
    command("PostDeposit", ALICE, { radio = ref(RADIO), items = { 1, 2, 3 } })
    command("PostTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "transmitted", "transmis")
    assertEq(lastSent("PostResult").count, 2, "plaque créditée (gain nul compris) et plaque déjà transmise")
    assertEq(#STATE.postMail.SOLO, 1, "plafond du jour : la plaque attend")
    assertEq(STATE.postMail.SOLO[1].name, "cap", "celle du plafond")
    command("PostTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "held", "toujours retenue")
end

function T.transmission_needs_a_working_radio_on_the_channel()
    MilitaryDrop.Missions = { creditDogTag = function() return 1 end }
    ALICE.inventory = makeInventory({ makeItem(1, "1") })
    install(ALICE, RADIO)
    command("PostDeposit", ALICE, { radio = ref(RADIO), items = { 1 } })
    RADIO.data.on = false
    command("PostTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "radioOff", "éteinte")
    RADIO.data.on = true
    RADIO.data.channel = CHANNEL + 200
    command("PostTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "noAnswer", "autre canal : pas de réponse, fréquence non trahie")
    assertEq(#STATE.postMail.SOLO, 1, "courrier gardé")
end

function T.transmission_waits_for_the_missions_module()
    MilitaryDrop.Missions = nil
    ALICE.inventory = makeInventory({ makeItem(1, "1") })
    install(ALICE, RADIO)
    command("PostDeposit", ALICE, { radio = ref(RADIO), items = { 1 } })
    command("PostTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "unavailable", "module absent")
    assertEq(#STATE.postMail.SOLO, 1, "courrier gardé")
end

function T.mail_survives_the_loss_of_the_radio()
    ALICE.inventory = makeInventory({ makeItem(1, "1") })
    install(ALICE, RADIO)
    command("PostDeposit", ALICE, { radio = ref(RADIO), items = { 1 } })
    removeObject(RADIO)
    triggerEvent("EveryOneMinute")
    local other = makeRadio(makeSquare(101, 101, 0))
    install(ALICE, other)
    assertEq(#STATE.postMail.SOLO, 1, "courrier à l'équipe, pas à l'objet")
    assertTrue(#log("SOLO") >= 3, "journal conservé")
end

function T.commands_are_rate_limited_with_a_busy_answer()
    install(ALICE, RADIO)
    COMMANDS.PostOpen(ALICE, { radio = ref(RADIO) })
    local count = #SENT
    COMMANDS.PostOpen(ALICE, { radio = ref(RADIO) })
    assertEq(#SENT, count + 1, "rafale : une seule réponse")
    assertEq(SENT[#SENT].command, "PostResult", "réponse")
    assertEq(SENT[#SENT].args.status, "busy", "statut « busy »")
    assertEq(SENT[#SENT].args.lines, nil, "aucune donnée")
end

function T.console_refresh_does_not_use_the_cadence_of_other_commands()
    MilitaryDrop.Missions = { creditDogTag = function() return 1 end }
    ALICE.inventory = makeInventory({ makeItem(1, "1") })
    install(ALICE, RADIO)
    NOW_MS = NOW_MS + 5000
    -- Rafraîchissement automatique, puis dépôt et transmission dans la même seconde.
    COMMANDS.PostOpen(ALICE, { radio = ref(RADIO) })
    COMMANDS.PostDeposit(ALICE, { radio = ref(RADIO), items = { 1 } })
    assertEq(lastSent("PostResult").status, "deposited", "dépôt : sa propre cadence")
    COMMANDS.PostTransmit(ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "transmitted", "transmission : sa propre cadence")
end

function T.transmissions_are_limited_to_one_every_3_seconds()
    MilitaryDrop.Missions = { creditDogTag = function() return 1 end }
    ALICE.inventory = makeInventory({ makeItem(1, "1"), makeItem(2, "2") })
    install(ALICE, RADIO)
    command("PostDeposit", ALICE, { radio = ref(RADIO), items = { 1 } })
    command("PostTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "transmitted", "première transmission")
    NOW_MS = NOW_MS + 500
    COMMANDS.PostDeposit(ALICE, { radio = ref(RADIO), items = { 2 } })
    NOW_MS = NOW_MS + 1000
    COMMANDS.PostTransmit(ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "busy", "1,5 s après : refusée (anti-rafale)")
    assertEq(#STATE.postMail.SOLO, 1, "courrier gardé")
    NOW_MS = NOW_MS + 1500
    COMMANDS.PostTransmit(ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "transmitted", "3 s après : acceptée")
end

function T.console_receives_only_the_last_60_journal_lines()
    install(ALICE, RADIO)
    for i = 1, 150 do
        Post.record(nil, "ligne " .. i)
    end
    command("PostOpen", ALICE, { radio = ref(RADIO) })
    local lines = lastSent("PostData").lines
    assertEq(#lines, Post.LOG_SEND_MAX, "60 lignes envoyées")
    assertEq(lines[1].t.text, "ligne 91", "les plus récentes")
    assertEq(lines[60].t.text, "ligne 150", "jusqu'à la dernière")
    assertEq(#log("SOLO"), 151, "le serveur garde tout (200 au plus)")
end

function T.post_state_stays_out_of_the_public_mod_data()
    MilitaryDrop.Missions = { creditDogTag = function() return 1 end }
    ALICE.inventory = makeInventory({ makeItem(1, "1") })
    install(ALICE, RADIO)
    Post.record(nil, "ligne")
    command("PostDeposit", ALICE, { radio = ref(RADIO), items = { 1 } })
    for _, name in ipairs({ "posts", "postLogs", "postMail", "nextPostUid", "teams", "teamPlayers", "trust" }) do
        assertEq(PUBLIC[name], nil, name .. " absent de l'état public")
    end
    assertTrue(STATE.posts.SOLO ~= nil and STATE.postMail.SOLO[1] ~= nil, "dans l'état privé")
end

function T.results_name_the_player_they_answer()
    install(ALICE, RADIO)
    assertEq(lastSent("PostResult").username, "alice", "nom du joueur dans la réponse")
end

-- ----------------------------------------------------------------------------
-- Console (client)
-- ----------------------------------------------------------------------------

--- Charge la fenêtre du poste avec un client simulé (solo).
local function loadWindow()
    BASE_COMMANDS = {}
    MilitaryDrop.Client = { HANDLERS = {} }
    -- Même aiguillage que MilitaryDrop_Client.lua : gestionnaires inscrits d'abord.
    MilitaryDrop.Client.onServerCommand = function(_, name, args)
        local handler = MilitaryDrop.Client.HANDLERS[name]
        if handler then
            handler(args)
            return
        end
        BASE_COMMANDS[#BASE_COMMANDS + 1] = name
    end
    ISPanelJoypad = { derive = function(self, name)
        return setmetatable({ Type = name }, { __index = self })
    end }
    UIFont = { Small = "Small", Medium = "Medium", CodeSmall = "CodeSmall" }
    getTextManager = function()
        return { getFontHeight = function() return 14 end, MeasureStringX = function(_, _, s) return #s * 7 end }
    end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_PostWindow.lua")
    return MilitaryDrop.PostWindow
end

function T.console_takes_its_commands_in_solo()
    local PostWindow = loadWindow()
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostInfo", { x = 100, y = 100, z = 0 })
    assertEq(PostWindow.myPost.x, 100, "position du poste reçue")
    assertTrue(PostWindow.isOwnPost(RADIO), "menu : poste de l'équipe")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostInfo", { none = true })
    assertEq(PostWindow.myPost, nil, "poste perdu")
    assertEq(#BASE_COMMANDS, 0, "commandes du poste non transmises au client de base")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "Result", { requestId = 1 })
    assertEq(BASE_COMMANDS[1], "Result", "les autres commandes y passent toujours")
end

function T.console_closes_at_the_server_range()
    local PostWindow = loadWindow()
    assertEq(PostWindow.CLOSE_DISTANCE, MilitaryDrop.Radio.MAX_WORLD_DISTANCE + 0.5, "même portée que Radio.isNear")
end

function T.post_answers_speak_through_the_right_player_and_resync_the_post()
    loadWindow()
    local said = {}
    local function localPlayer(name)
        return { getUsername = function() return name end, Say = function(_, text) said[#said + 1] = name .. ":" .. text end }
    end
    local first, second = localPlayer("alice"), localPlayer("bob")
    getNumActivePlayers = function() return 2 end
    getSpecificPlayer = function(i) return i == 0 and first or second end
    local synced = {}
    MilitaryDrop.Net.toServer = function(player, commandName) synced[#synced + 1] = player:getUsername() .. ":" .. commandName end
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostResult", { status = "already", username = "bob" })
    assertEq(said[1], "bob:IGUI_MilitaryDrop_PostResult_already|0|nil", "le joueur concerné parle (écran partagé)")
    assertEq(synced[1], "bob:PostSync", "déjà installé : position du poste redemandée (nouveau membre)")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostResult", { status = "notPost" })
    assertEq(said[2], "alice:IGUI_MilitaryDrop_PostResult_notPost|0|nil", "sans nom : joueur 0")
    assertEq(synced[2], "alice:PostSync", "pas le poste : position redemandée")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostResult", { status = "busy", username = "alice" })
    assertEq(#said, 2, "cadence : rien à dire")
end

function T.console_texts_are_escaped_and_without_trust_number()
    local PostWindow = loadWindow()
    -- Mercredi 14 juillet 1993, 14 h 30 (horloge du calendrier, Codes.clockHours).
    local clock = MilitaryDrop.Codes.clockHours(1993, 6, 13, 14.5)
    assertEq(PostWindow.stamp(clock), "IGUI_MilitaryDrop_PostTime|14|07", "jour, mois (et heure en %3)")
    local text = PostWindow.journalText({ { c = clock, t = { text = "a <LINE> b" } }, { c = clock, gap = 3 } })
    assertTrue(not text:find("a <LINE> b", 1, true), "texte de la base échappé")
    assertTrue(text:find("IGUI_MilitaryDrop_PostGap|3", 1, true) ~= nil, "trou regroupé")
    assertEq(PostWindow.trustText({ tier = 4 }), "IGUI_MilitaryDrop_PostTrust4|nil|nil", "libellé par palier")
    assertEq(PostWindow.trustText({ tier = 4, lineCut = true }), "IGUI_MilitaryDrop_PostLineCut|nil|nil",
        "ligne coupée d'abord")
end

function T.own_and_blank_dog_tags_are_not_deposited()
    ALICE.inventory = makeInventory({ makeItem(1, "Alice Smith"), makeItem(2, false), makeItem(3, "John Doe") })
    install(ALICE, RADIO)
    command("PostDeposit", ALICE, { radio = ref(RADIO), items = { 1, 2, 3 } })
    assertEq(lastSent("PostResult").count, 1, "seule la plaque d'un autre, renommée")
    assertEq(STATE.postMail.SOLO[1].name, "John Doe", "nom du soldat")
    assertEq(#ALICE.inventory.items, 2, "la sienne et la vierge restent")
end

function T.no_deposit_while_the_line_is_cut()
    ALICE.inventory = makeInventory({ makeItem(3, "John Doe") })
    install(ALICE, RADIO)
    STATE.characterTrust = STATE.characterTrust or {}
    STATE.characterTrust["C:alice"] = { value = 10, lockedUntil = WORLD_HOURS + 72 }
    command("PostDeposit", ALICE, { radio = ref(RADIO), items = { 3 } })
    assertEq(lastSent("PostResult").status, "lineCut", "dépôt refusé")
    assertEq(#ALICE.inventory.items, 1, "la plaque reste à son porteur")
end

function T.console_data_names_its_player()
    install(ALICE, RADIO)
    command("PostOpen", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostData").username, ALICE:getUsername(), "écran partagé : console du bon joueur")
end

function T.trial_mail_entries_without_id_are_dropped()
    install(ALICE, RADIO)
    STATE.postMail.SOLO = { { serial = "12345678", by = "alice", c = 1 }, { id = "9", name = "John Doe", by = "bob" } }
    command("PostOpen", ALICE, { radio = ref(RADIO) })
    local mail = lastSent("PostData").mail
    assertEq(#mail, 1, "ancienne plaque numérotée retirée")
    assertEq(mail[1].name, "John Doe", "entrée valable gardée")
end

function T.console_data_sends_the_battery_charge_of_a_battery_post()
    RADIO.data.battery = true
    RADIO.data.power = 0.4
    install(ALICE, RADIO)
    command("PostOpen", ALICE, { radio = ref(RADIO) })
    local data = lastSent("PostData")
    assertEq(data.power, "battery", "poste sur pile")
    assertEq(data.battery, 0.4, "charge pour la jauge")
end

-- ----------------------------------------------------------------------------
-- Bouton « Poste de liaison » de la fenêtre radio
-- ----------------------------------------------------------------------------

local function queryStatus(player, radio)
    command("PostQuery", player, { radio = ref(radio) })
    return lastSent("PostStatus", player)
end

function T.radio_status_answers_the_radio_window_button()
    multiplayer()
    local status = queryStatus(ALICE, RADIO)
    assertEq(status.status, "none", "pas de poste")
    assertEq(status.x .. "," .. status.y .. "," .. status.z, "100,100,0", "radio désignée renvoyée")
    install(ALICE, RADIO)
    assertEq(queryStatus(ALICE, RADIO).status, "own", "poste de l'équipe")
    local other = makeRadio(makeSquare(102, 100, 0))
    assertEq(queryStatus(ALICE, other).status, "elsewhere", "poste sur une autre radio")
    local mallory = makePlayer("mallory", 101, 101, 0)
    assertEq(queryStatus(mallory, RADIO).status, "otherTeam", "poste d'une autre équipe")
    assertEq(queryStatus(mallory, other).status, "none", "radio libre pour mallory")
    local talkie = makeRadio(makeSquare(100, 101, 0), { portable = true })
    assertEq(queryStatus(ALICE, talkie).status, "notEligible", "talkie posé")
    ALICE.x = 120
    assertEq(queryStatus(ALICE, RADIO).status, "tooFar", "trop loin")
end

--- Console client avec envois et confirmation simulés.
local function windowWorld()
    local PostWindow = loadWindow()
    local w = { toServer = {}, modals = {}, said = {} }
    MilitaryDrop.Net.toServer = function(_, commandName, args)
        w.toServer[#w.toServer + 1] = { command = commandName, args = args }
    end
    ALICE.getPlayerNum = function() return 0 end
    ALICE.Say = function(_, text) w.said[#w.said + 1] = text end
    getSpecificPlayer = function() return ALICE end
    JoypadState = { players = {} }
    ISModalDialog = { new = function(_, x, y, width, height, text, yesno, target, onclick, player, p1, p2)
        local modal = { text = text, yesno = yesno, onclick = onclick, player = player, p1 = p1, p2 = p2 }
        function modal.initialise() end
        function modal.addToUIManager() end
        w.modals[#w.modals + 1] = modal
        return modal
    end }
    return PostWindow, w
end

local function lastCommand(w)
    return w.toServer[#w.toServer] and w.toServer[#w.toServer].command
end

function T.post_button_installs_then_opens_the_console()
    local PostWindow, w = windowWorld()
    assertEq(listenerCount("OnFillWorldObjectContextMenu"), 0, "plus de menu contextuel du poste")
    assertEq(PostWindow.radioStatus(RADIO), "none", "aucun poste connu")
    assertEq(PostWindow.useTooltip(RADIO), "IGUI_MilitaryDrop_PostInstallTooltip", "infobulle : installation")
    assertEq(PostWindow.useRadio(ALICE, RADIO), "install", "installation")
    assertEq(lastCommand(w), "PostInstall", "demandée au serveur")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostResult", { status = "installed", username = "alice" })
    assertEq(lastCommand(w), "PostOpen", "puis la console")
    assertEq(w.said[1], "IGUI_MilitaryDrop_PostResult_installed|0|nil", "le personnage le dit")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostResult", { status = "installed", username = "alice" })
    assertEq(#w.toServer, 2, "une seule ouverture")
end

function T.post_button_opens_the_own_post_and_confirms_a_transfer()
    local PostWindow, w = windowWorld()
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostInfo", { x = 100, y = 100, z = 0 })
    assertEq(PostWindow.radioStatus(RADIO), "own", "deviné : poste de l'équipe")
    assertEq(PostWindow.useRadio(ALICE, RADIO), "open", "console")
    assertEq(lastCommand(w), "PostOpen", "ouverture")
    local other = makeRadio(makeSquare(101, 101, 0))
    assertEq(PostWindow.radioStatus(other), "elsewhere", "poste ailleurs")
    assertEq(PostWindow.useTooltip(other), "IGUI_MilitaryDrop_PostTransferTooltip", "infobulle : transfert")
    local sent = #w.toServer
    assertEq(PostWindow.useRadio(ALICE, other), "confirm", "confirmation d'abord")
    assertEq(#w.toServer, sent, "rien d'envoyé avant la réponse")
    local modal = w.modals[1]
    assertEq(modal.text, "IGUI_MilitaryDrop_PostTransferConfirm|nil|nil", "« Transférer le poste de liaison ici ? »")
    assertTrue(modal.yesno, "oui / non")
    modal.onclick(nil, { internal = "NO" }, modal.p1, modal.p2)
    assertEq(#w.toServer, sent, "non : rien")
    modal.onclick(nil, { internal = "YES" }, modal.p1, modal.p2)
    assertEq(lastCommand(w), "PostInstall", "oui : transfert")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostResult", { status = "moved", username = "alice" })
    assertEq(lastCommand(w), "PostOpen", "puis la console")
end

function T.post_button_is_greyed_on_another_team_post()
    local PostWindow, w = windowWorld()
    PostWindow.queryStatus(ALICE, RADIO)
    assertEq(lastCommand(w), "PostQuery", "état demandé au serveur")
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostStatus", { status = "otherTeam", x = 100, y = 100, z = 0 })
    assertEq(PostWindow.useReason(ALICE, RADIO), "IGUI_MilitaryDrop_PostResult_otherTeam", "grisé avec la raison")
    assertEq(PostWindow.useRadio(ALICE, RADIO), nil, "rien")
    ALICE.x = 110
    assertEq(PostWindow.useReason(ALICE, RADIO), "IGUI_MilitaryDrop_TooFar", "trop loin")
    -- Poste installé ou déplacé : états oubliés, redemandés.
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "PostInfo", { none = true })
    assertEq(PostWindow.radioStatus(RADIO), "none", "état redeviné")
end

function T.shared_post_shows_the_acting_characters_personal_standing()
    isServer = function() return true end
    makeFaction("Rangers", "alice", { "bob" })
    local bob = makePlayer("bob", 100, 101, 0)
    install(ALICE, RADIO)
    local a, b = MilitaryDrop.Trust.idFor(ALICE), MilitaryDrop.Trust.idFor(bob)
    MilitaryDrop.Trust.add(a, 65, "drop")
    MilitaryDrop.Trust.add(b, -20, "drop")
    local team = Teams.idFor(ALICE)
    local aliceData = Post.consoleData(team, RADIO, ALICE)
    local bobData = Post.consoleData(team, RADIO, bob)
    assertEq(aliceData.tier, 4, "Alice has high esteem")
    assertEq(bobData.tier, 1, "Bob has low standing")
    assertTrue(bobData.lineCut and not aliceData.lineCut, "only Bob is suspended")
end

-- ----------------------------------------------------------------------------
-- Baie de lecture des enregistreurs de vol (SRC-08)
-- ----------------------------------------------------------------------------

local function makeRecorder(id, site, extra)
    local item = { id = id, fullType = "MilitaryDrop.FlightRecorder", modData = { MilitaryDrop_crashSite = site } }
    for name, value in pairs(extra or {}) do
        item.modData[name] = value
    end
    function item.getID(self) return self.id end
    function item.getFullType(self) return self.fullType end
    function item.getModData(self) return self.modData end
    function item.getContainer(self) return self.container end
    function item.hasTag() return false end
    function item.getDisplayName() return "Flight recorder" end
    return item
end

local function insertRecorder(player, id)
    command("PostRecorderInsert", player, { radio = ref(RADIO), item = id })
    return lastSent("PostResult", player)
end

local function sysEntries(teamId, kind)
    local found = {}
    for _, entry in ipairs(log(teamId)) do
        if entry.sys == kind then
            found[#found + 1] = entry
        end
    end
    return found
end

local function trustOf(player)
    return MilitaryDrop.Trust.get(MilitaryDrop.Trust.idFor(player))
end

function T.recorder_is_read_while_powered_then_credited_once_out_of_the_daily_cap()
    -- Plafond du jour déjà atteint : le gain de l'enregistreur passe quand même.
    SandboxVars.MilitaryDrop.TrustDailyCap = 0
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3",
        { MilitaryDrop_crashX = 1570, MilitaryDrop_crashY = 5941, MilitaryDrop_crashClock = CLOCK - 2 }) })
    install(ALICE, RADIO)
    assertEq(insertRecorder(ALICE, 7).status, "recorderIn", "insérée")
    assertEq(#ALICE.inventory.items, 0, "retiré de l'inventaire par le serveur")
    assertEq(sysEntries("SOLO", "recorderIn")[1].site, "W3", "journal : enregistreur inséré")
    local bay = lastSent("PostData").bay
    assertEq(bay.site, "W3", "baie envoyée à la console")
    assertEq(bay.progress, 0, "lecture à zéro")
    assertEq(bay.minutesLeft, math.ceil(Post.READ_HOURS * 60), "durée totale en minutes de jeu")
    assertEq(bay.cx .. "/" .. bay.cy .. "/" .. bay.cc, "1570/5941/" .. (CLOCK - 2), "point et heure du crash")
    command("PostRecorderTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "notRead", "pas avant la fin de la lecture")
    wait(Post.READ_HOURS / 2)
    Post.refreshAll()
    assertTrue(math.abs(Post.bayView("SOLO").progress - 0.5) < 1e-9, "la moitié à mi-temps")
    wait(Post.READ_HOURS)
    Post.refreshAll()
    local view = Post.bayView("SOLO")
    assertTrue(view.done and view.progress == 1 and view.minutesLeft == 0, "lu, sans dépassement")
    assertEq(#sysEntries("SOLO", "recorderRead"), 1, "journal : lecture terminée, une fois")
    Post.refreshAll()
    assertEq(#sysEntries("SOLO", "recorderRead"), 1, "pas de doublon ensuite")
    local before = trustOf(ALICE)
    command("PostRecorderTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "recorderSent", "transmis")
    assertEq(trustOf(ALICE), before + 10, "+10 hors plafond quotidien")
    assertEq(STATE.recordersUsed.W3, "C:alice", "crédit noté pour le site")
    assertEq(Post.bayView("SOLO"), nil, "baie vide")
    assertTrue(MilitaryDrop.Exchange.lineText(lastEntry("SOLO").t):find("IGUI_MilitaryDrop_Reply_Recorder", 1, true) ~= nil,
        "réponse de la base au journal")
    -- Même site une seconde fois : refusé, l'objet reste au joueur.
    ALICE.inventory = makeInventory({ makeRecorder(8, "W3") })
    assertEq(insertRecorder(ALICE, 8).status, "recorderUsed", "un crédit par site")
    assertEq(#ALICE.inventory.items, 1, "gardé")
end

function T.recorder_reading_pauses_without_power_then_resumes()
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3") })
    install(ALICE, RADIO)
    insertRecorder(ALICE, 7)
    RADIO.data.on = false
    wait(Post.READ_HOURS * 0.4)
    Post.refreshAll()
    assertEq(Post.bayView("SOLO").progress, 0, "éteinte : rien de lu")
    assertTrue(Post.bayView("SOLO").paused, "en pause")
    assertEq(#sysEntries("SOLO", "recorderPaused"), 1, "coupure notée")
    wait(Post.READ_HOURS * 0.2)
    Post.refreshAll()
    assertEq(#sysEntries("SOLO", "recorderPaused"), 1, "une seule fois")
    RADIO.data.on = true
    RADIO.data.channel = CHANNEL + 200
    wait(Post.READ_HOURS * 0.2)
    Post.refreshAll()
    assertEq(#sysEntries("SOLO", "recorderResumed"), 1, "reprise notée")
    assertTrue(math.abs(Post.bayView("SOLO").progress - 0.2) < 1e-9, "reprise où elle en était, canal indifférent")
    assertTrue(not Post.bayView("SOLO").paused, "plus en pause")
end

function T.console_receives_the_exact_reading_between_two_game_minutes()
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3") })
    install(ALICE, RADIO)
    insertRecorder(ALICE, 7)
    -- Aucun passage de minute : l'envoi fait avancer la lecture lui-même.
    wait(Post.READ_HOURS * 0.2)
    command("PostOpen", ALICE, { radio = ref(RADIO) })
    assertTrue(math.abs(lastSent("PostData").bay.progress - 0.2) < 1e-9, "progression exacte à l'envoi")
    Post.refreshAll()
    assertTrue(math.abs(Post.bayView("SOLO").progress - 0.2) < 1e-9, "pas comptée deux fois")
    RADIO.data.on = false
    wait(Post.READ_HOURS * 0.2)
    command("PostOpen", ALICE, { radio = ref(RADIO) })
    local bay = lastSent("PostData").bay
    assertTrue(bay.paused and math.abs(bay.progress - 0.2) < 1e-9, "coupure vue à l'envoi, lecture figée")
    assertEq(#sysEntries("SOLO", "recorderPaused"), 1, "coupure notée une fois")
end

function T.unloaded_post_keeps_reading_on_its_snapshot()
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3") })
    install(ALICE, RADIO)
    insertRecorder(ALICE, 7)
    LOADED = false
    wait(Post.READ_HOURS)
    Post.refreshAll()
    assertTrue(Post.bayView("SOLO").done, "secteur toujours là : lecture finie hors chargement")
    LOADED = true
end

function T.removed_recorder_comes_back_with_its_progress()
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3",
        { MilitaryDrop_crashX = 10, MilitaryDrop_crashY = 20, MilitaryDrop_crashClock = 5 }) })
    install(ALICE, RADIO)
    insertRecorder(ALICE, 7)
    wait(Post.READ_HOURS / 2)
    Post.refreshAll()
    local created = {}
    instanceItem = function(fullType)
        local item = makeRecorder(100 + #created, nil)
        item.fullType = fullType
        created[#created + 1] = item
        return item
    end
    command("PostRecorderEject", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "recorderOut", "retiré")
    local back = ALICE.inventory.items[1]
    assertEq(back:getFullType(), "MilitaryDrop.FlightRecorder", "rendu au joueur")
    assertEq(back.modData.MilitaryDrop_crashSite, "W3", "même site")
    assertEq(back.modData.MilitaryDrop_crashX .. "/" .. back.modData.MilitaryDrop_crashY, "10/20", "même point")
    assertEq(Post.bayView("SOLO"), nil, "baie vide")
    insertRecorder(ALICE, back.id)
    assertTrue(math.abs(Post.bayView("SOLO").progress - 0.5) < 1e-9, "lecture acquise conservée")
end

function T.recorder_transmission_needs_the_channel_and_an_open_line()
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3") })
    install(ALICE, RADIO)
    insertRecorder(ALICE, 7)
    wait(Post.READ_HOURS)
    Post.refreshAll()
    RADIO.data.channel = CHANNEL + 200
    command("PostRecorderTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "noAnswer", "autre canal : pas de réponse")
    RADIO.data.channel = CHANNEL
    RADIO.data.on = false
    command("PostRecorderTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "radioOff", "éteinte")
    RADIO.data.on = true
    STATE.characterTrust = STATE.characterTrust or {}
    STATE.characterTrust["C:alice"] = { value = 10, lockedUntil = WORLD_HOURS + 72 }
    command("PostRecorderTransmit", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "lineCut", "ligne coupée")
    assertTrue(Post.bayView("SOLO").done, "enregistreur gardé dans la baie")
end

function T.bay_refuses_other_objects_and_a_second_recorder()
    local dogTag = makeItem(5, "John Doe")
    function dogTag.getFullType() return "Base.Necklace_DogTag" end
    function dogTag.getModData() return {} end
    ALICE.inventory = makeInventory({ dogTag, makeRecorder(7, "W3"), makeRecorder(8, "W4"), makeRecorder(9, nil) })
    install(ALICE, RADIO)
    assertEq(insertRecorder(ALICE, 5).status, "notRecorder", "une plaque n'est pas un enregistreur")
    assertEq(insertRecorder(ALICE, 9).status, "notRecorder", "enregistreur sans site")
    assertEq(insertRecorder(ALICE, 99).status, "notRecorder", "objet absent")
    assertEq(insertRecorder(ALICE, 7).status, "recorderIn", "le premier entre")
    assertEq(insertRecorder(ALICE, 8).status, "bayBusy", "une baie, un enregistreur")
    assertEq(#ALICE.inventory.items, 3, "les autres restent")
    instanceItem = function(fullType)
        local item = makeRecorder(50, nil)
        item.fullType = fullType
        return item
    end
    command("PostRecorderEject", ALICE, { radio = ref(RADIO) })
    command("PostRecorderEject", ALICE, { radio = ref(RADIO) })
    assertEq(lastSent("PostResult").status, "bayEmpty", "rien à retirer")
end

function T.recorder_keys_match_the_wreck_module()
    local source = readModFile("server/MilitaryDrop/MilitaryDrop_Wreck.lua")
    assertTrue(source:find('Wreck.SITE_KEY = "' .. Post.SITE_KEY .. '"', 1, true) ~= nil, "même clé de site")
    for _, name in ipairs({ Post.CRASH_X_KEY, Post.CRASH_Y_KEY, Post.CRASH_CLOCK_KEY }) do
        assertTrue(source:find("data." .. name, 1, true) ~= nil, name .. " posé par l'épave")
    end
    assertTrue(source:find('container:AddItem("' .. Post.RECORDER_TYPE .. '")', 1, true) ~= nil, "même objet")
end

-- ----------------------------------------------------------------------------
-- Sons de la baie (SRC-10)
-- ----------------------------------------------------------------------------

local function baySounds(from)
    local out = {}
    for i = from or 1, #SENT do
        if SENT[i].command == "BaySound" then
            local a = SENT[i].args
            out[#out + 1] = (a.event or "-") .. "/" .. tostring(a.reading)
        end
    end
    return table.concat(out, " ")
end

function T.bay_sounds_follow_insertion_reading_pause_and_end()
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3") })
    install(ALICE, RADIO)
    local mark = #SENT + 1
    insertRecorder(ALICE, 7)
    assertEq(baySounds(mark), "insert/nil -/true", "déclic d'insertion puis boucle de lecture")
    local args
    for i = mark, #SENT do
        if SENT[i].command == "BaySound" then args = SENT[i].args end
    end
    assertEq(args.x .. "," .. args.y .. "," .. args.z, "100,100,0", "case du poste")
    mark = #SENT + 1
    wait(Post.READ_HOURS * 0.2)
    Post.refreshAll()
    assertEq(baySounds(mark), "-/true", "rappel chaque minute de jeu (arrivants)")
    mark = #SENT + 1
    RADIO.data.on = false
    wait(Post.READ_HOURS * 0.2)
    Post.refreshAll()
    assertEq(baySounds(mark), "-/false", "coupure : boucle arrêtée, pas de rappel en pause")
    mark = #SENT + 1
    RADIO.data.on = true
    wait(Post.READ_HOURS * 0.2)
    Post.refreshAll()
    assertEq(baySounds(mark), "-/true -/true", "reprise, puis rappel")
    mark = #SENT + 1
    wait(Post.READ_HOURS)
    Post.refreshAll()
    assertEq(baySounds(mark), "done/false", "double déclic de fin, boucle arrêtée")
    mark = #SENT + 1
    Post.refreshAll()
    assertEq(baySounds(mark), "", "plus rien une fois lu")
end

function T.bay_sounds_reach_only_players_near_the_post()
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3") })
    install(ALICE, RADIO)
    insertRecorder(ALICE, 7)
    ALICE.x = 100 + Post.SOUND_RANGE + 2
    local mark = #SENT + 1
    Post.refreshAll()
    assertEq(baySounds(mark), "", "trop loin : rien")
    ALICE.x = 101
    ALICE.z = 1
    Post.refreshAll()
    assertEq(baySounds(mark), "", "autre étage : rien")
    ALICE.z = 0
    Post.refreshAll()
    assertEq(baySounds(mark), "-/true", "de retour à portée : la boucle reprend")
end

function T.removed_recorder_stops_the_loop_on_a_post_without_power()
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3") })
    install(ALICE, RADIO)
    RADIO.data.on = false
    local mark = #SENT + 1
    insertRecorder(ALICE, 7)
    assertEq(baySounds(mark), "insert/nil -/false", "inséré sans courant : déclic, pas de boucle")
    instanceItem = function(fullType)
        local item = makeRecorder(50, nil)
        item.fullType = fullType
        return item
    end
    mark = #SENT + 1
    command("PostRecorderEject", ALICE, { radio = ref(RADIO) })
    assertEq(baySounds(mark), "-/false", "retrait : arrêt")
end

function T.reading_saved_in_hours_before_is_converted_once()
    -- Sauvegarde d'avant : 0,18 h lues sur une lecture de 30 minutes (36 %).
    STATE.recorderReads = { W1 = 0.18 }
    ALICE.inventory = makeInventory({ makeRecorder(7, "W1") })
    install(ALICE, RADIO)
    insertRecorder(ALICE, 7)
    local view = Post.bayView("SOLO")
    assertTrue(math.abs(view.progress - 0.36) < 1e-9 and not view.done, "reprend à 36 %, pas lu d'office")
    assertEq(STATE.recorderReadsFraction, 1, "conversion notée")
    wait(Post.READ_HOURS * 0.64)
    Post.refreshAll()
    assertTrue(Post.bayView("SOLO").done, "fini après le reste de la nouvelle durée")
    STATE.recorderReads.W9 = 0.5
    Post.refreshAll()
    assertEq(STATE.recorderReads.W9, 0.5, "jamais reconvertie")
end

function T.changed_reading_length_keeps_the_part_already_read()
    STATE.recorderReads, STATE.recorderReadsFraction = { W3 = 0.5 }, 1
    local saved = Post.READ_HOURS
    Post.READ_HOURS = 1
    ALICE.inventory = makeInventory({ makeRecorder(7, "W3") })
    install(ALICE, RADIO)
    insertRecorder(ALICE, 7)
    local view = Post.bayView("SOLO")
    Post.READ_HOURS = saved
    assertTrue(view.progress == 0.5 and not view.done, "durée allongée : toujours à mi-lecture")
    assertEq(view.minutesLeft, 30, "minutes restantes selon la nouvelle durée")
end


function T.translatable_journal_entries_keep_parameters_and_deduplicate_by_content()
    install(ALICE, RADIO)
    local E = MilitaryDrop.Exchange
    local before = #log("SOLO")
    Post.record("SOLO", E.line("IGUI_MilitaryDrop_Reply_DogTags", "Alpha",
        E.namesLine({ "A", "B", "C", "D" })))
    Post.record("SOLO", E.line("IGUI_MilitaryDrop_Reply_DogTags", "Alpha",
        E.namesLine({ "A", "B", "C", "D" })))
    assertEq(#log("SOLO"), before + 1, "tables distinctes de même contenu regroupées")
    local line = lastEntry("SOLO").t
    assertEq(line.key, "IGUI_MilitaryDrop_Reply_DogTags", "clé persistante")
    assertEq(line.params[2].key, "IGUI_MilitaryDrop_NamesMoreOne", "paramètre imbriqué persistant")
    local W = loadWindow()
    getText = function(translationKey, a, b)
        if translationKey == "IGUI_MilitaryDrop_NamesMoreOne" then return a .. " et un autre" end
        return "Merci " .. a .. ": " .. b
    end
    assertTrue(W.journalText({ { c = 0, t = line } }):find("Merci Alpha: A, B, C et un autre", 1, true) ~= nil,
        "journal traduit à l'affichage")
    local receivedKey = W.lastReceivedKey({ lines = { { c = 0, t = line } } })
    local copy = E.line("IGUI_MilitaryDrop_Reply_DogTags", "Alpha", E.namesLine({ "A", "B", "C", "D" }))
    assertEq(W.lastReceivedKey({ lines = { { c = 0, t = copy } } }), receivedKey,
        "rafraîchissement réseau identique : pas de faux clignotement")
end

return T
