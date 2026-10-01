-- MilitaryDrop_Decoy : sirène du largage leurre côté serveur (cycle de vie,
-- bruit seulement en zone chargée, position envoyée aux seuls joueurs à
-- portée, resynchronisation, rien dans la ModData publique ni à tous).

local T = {}

local PRIVATE_TAG = "MilitaryDrop_0123456789ab"

--- Joueur simulé (nom, position).
local function makePlayer(name, x, y, z)
    local player = { name = name, x = x, y = y, z = z or 0, notes = {}, dead = false }
    function player.getUsername(this) return this.name end
    function player.getX(this) return this.x end
    function player.getY(this) return this.y end
    function player.getZ(this) return this.z end
    function player.isDead(this) return this.dead end
    function player.transmitHaloNote(this, text) this.notes[#this.notes + 1] = text end
    return player
end

--- Caisse simulée : centre (x, y), couvre les cases x-1..x, y-1..y.
local function makeCrate(x, y)
    local vehicle = { kind = "BaseVehicle", x = x, y = y, z = 0, removed = false }
    function vehicle.getScriptName() return "Base.MilitaryDrop_SupplyCrate" end
    function vehicle.isRemovedFromWorld(this) return this.removed end
    function vehicle.getX(this) return this.x end
    function vehicle.getY(this) return this.y end
    function vehicle.getZ(this) return this.z end
    return vehicle
end

local function javaList(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    SERVER = true
    isClient = function() return false end
    isServer = function() return SERVER end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    MODDATA = {}
    ModData = { getOrCreate = function(tag)
        MODDATA[tag] = MODDATA[tag] or {}
        return MODDATA[tag]
    end }
    NOW = 0
    getTimestampMs = function() return NOW end
    HOURS = 100
    getGameTime = function() return { getWorldAgeHours = function() return HOURS end } end
    getText = function(key) return key end
    -- Monde : cases chargées si LOADED ; caisse CRATE (ou aucune).
    LOADED = true
    CRATE = nil
    getCell = function()
        return { getGridSquare = function(_, x, y)
            if not LOADED then
                return nil
            end
            return { getVehicleContainer = function()
                local c = CRATE
                if c and not c.removed and x >= math.floor(c.x) - 1 and x <= math.floor(c.x)
                    and y >= math.floor(c.y) - 1 and y <= math.floor(c.y) then
                    return c
                end
                return nil
            end }
        end }
    end
    NOISES = {}
    getWorldSoundManager = function()
        return { addSoundRepeating = function(_, source, x, y, z, radius, volume, stressHumans, stressAnimals)
            NOISES[#NOISES + 1] = { source = source, x = x, y = y, z = z, radius = radius, volume = volume,
                stressHumans = stressHumans, stressAnimals = stressAnimals }
        end }
    end
    PLAYERS = {}
    getOnlinePlayers = function() return javaList(PLAYERS) end
    getNumActivePlayers = function() return #PLAYERS end
    getSpecificPlayer = function(i) return PLAYERS[i + 1] end
    -- Envois du serveur : à un joueur (SENT) ou à tous (BROADCAST).
    SENT = {}
    BROADCAST = {}
    sendServerCommand = function(a, b, c, d)
        if type(a) == "table" then
            SENT[#SENT + 1] = { player = a.name, module = b, command = c, args = d }
        else
            BROADCAST[#BROADCAST + 1] = { module = a, command = b, args = c }
        end
    end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Dismantle.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_SirenAction.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    MilitaryDrop.Secrets = { privateState = function() return ModData.getOrCreate(PRIVATE_TAG) end }
    loadMod("server/MilitaryDrop/MilitaryDrop_Decoy.lua")
end

--- Messages envoyés à un joueur (commande facultative).
local function sentTo(name, command)
    local list = {}
    for _, m in ipairs(SENT) do
        if m.player == name and (not command or m.command == command) then
            list[#list + 1] = m
        end
    end
    return list
end

--- Tour de sondage serveur : un OnTick, une seconde réelle plus tard.
local function tick()
    NOW = NOW + 1000
    triggerEvent("OnTick")
end

--- Leurre livré : caisse centrée en (100, 200).
local function deliver(dropId)
    CRATE = makeCrate(100, 200)
    return MilitaryDrop.Decoy.onDelivered(dropId or "D1", 100, 200, 0, CRATE)
end

-- ----------------------------------------------------------------------------
-- Contrat avec la réquisition
-- ----------------------------------------------------------------------------

function T.trunk_holds_only_the_diversion_beacon()
    local contents = MilitaryDrop.Decoy.trunkContents("D1")
    assertEq(#contents, 1, "une seule balise, aucune fourniture")
    assertEq(contents[1].fullType, "MilitaryDrop.DecoyBeacon", "objet du mod")
    assertEq(contents[1].name, "IGUI_MilitaryDrop_DecoyBeaconName", "libellé traduit « DIVERSION »")
end

function T.options_have_defaults()
    local Config = MilitaryDrop.Config
    assertEq(Config.get("DecoyEnabled"), true, "DecoyEnabled")
    assertEq(Config.get("DecoyCost"), 3, "DecoyCost")
    assertEq(Config.get("DecoySirenHours"), 6, "DecoySirenHours")
    assertEq(Config.get("DecoyNoiseRadius"), 120, "DecoyNoiseRadius")
end

-- ----------------------------------------------------------------------------
-- Cycle de vie
-- ----------------------------------------------------------------------------

function T.siren_starts_at_delivery_in_the_private_state()
    local id = deliver("D1")
    assertEq(id, 1, "numéro de sirène")
    local entry = MODDATA[PRIVATE_TAG].sirens.D1
    assertTrue(entry ~= nil, "état privé")
    assertEq(entry.x, 100, "centre de la caisse")
    assertEq(entry.endsHours, 106, "échéance DecoySirenHours")
    assertTrue(entry.crate, "caisse suivie")
    assertEq(listenerCount("OnTick"), 1, "sondage abonné")
    assertEq(MilitaryDrop.Decoy.onDelivered("D1", 100, 200, 0, CRATE), 1, "livraison répétée : même sirène")
    assertEq(MODDATA.MilitaryDrop, nil, "rien dans la ModData publique")
end

function T.zero_hours_means_no_siren()
    SandboxVars.MilitaryDrop.DecoySirenHours = 0
    assertEq(deliver("D1"), nil, "aucune sirène")
    assertEq(listenerCount("OnTick"), 0, "aucun sondage")
end

function T.noise_only_when_the_square_is_loaded()
    deliver("D1")
    LOADED = false
    tick()
    assertEq(#NOISES, 0, "zone non chargée : aucun bruit")
    LOADED = true
    tick()
    assertEq(#NOISES, 1, "zone chargée : bruit")
    local noise = NOISES[1]
    assertEq(noise.x, 100, "x entier")
    assertEq(noise.y, 200, "y entier")
    assertEq(noise.radius, 120, "rayon de l'option")
    assertEq(noise.volume, 60, "volume d'une sirène vanilla")
    assertEq(noise.stressAnimals, true, "comme la sirène d'un véhicule")
    tick()
    assertEq(#NOISES, 2, "répété à chaque seconde")
    NOW = NOW + 200
    triggerEvent("OnTick")
    assertEq(#NOISES, 2, "pas plus d'un tour par POLL_MS")
end

function T.noise_radius_is_at_least_fifty()
    SandboxVars.MilitaryDrop.DecoyNoiseRadius = 10
    deliver("D1")
    tick()
    assertEq(NOISES[1].radius, 50, "zombies virtuels : rayon ≥ 50")
end

function T.siren_stops_at_its_deadline()
    PLAYERS = { makePlayer("alice", 120, 200) }
    deliver("D1")
    tick()
    assertEq(#sentTo("alice", "SirenOn"), 1, "alice entend")
    HOURS = 106
    tick()
    assertEq(#sentTo("alice", "SirenOff"), 1, "SirenOff à l'échéance")
    assertEq(MODDATA[PRIVATE_TAG].sirens.D1, nil, "sirène retirée")
    assertEq(listenerCount("OnTick"), 0, "sondage désabonné")
    local noises = #NOISES
    tick()
    assertEq(#NOISES, noises, "plus aucun bruit")
end

function T.stopped_by_a_player_with_server_checks()
    local alice = makePlayer("alice", 101, 201)
    local far = makePlayer("bob", 110, 200)
    PLAYERS = { alice, far }
    local id = deliver("D1")
    tick()
    local Decoy = MilitaryDrop.Decoy
    assertTrue(not Decoy.stopByPlayer(far, id), "trop loin : refusé")
    assertEq(far.notes[1], "IGUI_MilitaryDrop_SirenCannotStop", "raison au joueur")
    assertTrue(not Decoy.stopByPlayer(alice, 99), "numéro inconnu : refusé")
    alice.z = 1
    assertTrue(not Decoy.stopByPlayer(alice, id), "autre étage : refusé")
    alice.z = 0
    alice.dead = true
    assertTrue(not Decoy.stopByPlayer(alice, id), "joueur mort : refusé")
    alice.dead = false
    assertTrue(Decoy.sirens().D1 ~= nil, "toujours active")
    assertTrue(Decoy.stopByPlayer(alice, id), "à portée : coupée")
    assertEq(alice.notes[#alice.notes], "IGUI_MilitaryDrop_SirenStopped", "note au joueur")
    assertEq(Decoy.sirens().D1, nil, "sirène retirée")
    assertEq(#sentTo("alice", "SirenOff"), 1, "SirenOff à l'auditeur")
    assertEq(#sentTo("bob", "SirenOff"), 1, "SirenOff à l'autre auditeur")
    assertTrue(not Decoy.stopByPlayer(alice, id), "déjà coupée")
end

function T.dismantled_crate_silences_its_siren()
    PLAYERS = { makePlayer("alice", 101, 201) }
    deliver("D1")
    MilitaryDrop.Decoy.onDelivered("D2", 500, 500, 0, makeCrate(500, 500))
    tick()
    assertTrue(not MilitaryDrop.Decoy.onCrateRemoved(makeCrate(300, 300)), "autre caisse : rien")
    assertTrue(MilitaryDrop.Decoy.onCrateRemoved(CRATE), "caisse du leurre")
    assertEq(MilitaryDrop.Decoy.sirens().D1, nil, "sirène de cette caisse coupée")
    assertTrue(MilitaryDrop.Decoy.sirens().D2 ~= nil, "l'autre leurre continue")
    assertEq(#sentTo("alice", "SirenOff"), 1, "SirenOff")
end

function T.dismantle_perform_calls_the_decoy()
    deliver("D1")
    local Dismantle = MilitaryDrop.Dismantle
    -- Démontage réduit à l'essentiel : définitions vanilla simulées.
    Dismantle.check = function() return nil end
    Dismantle.definition = function() return { addToInventory = false } end
    Dismantle.props = function()
        return {
            getScrapItemsList = function() return { usable = {}, unusable = {} } end,
            addAllScrapItemsToSquare = function() return 1 end,
            scrapGiveXp = function() end,
            scrapHaloNoteCheck = function() end,
        }
    end
    CRATE.getSquare = function() return {} end
    CRATE.permanentlyRemove = function(this) this.removed = true end
    local player = makePlayer("alice", 101, 201)
    player.getPrimaryHandItem = function() return nil end
    assertTrue(Dismantle.perform(player, CRATE), "caisse démontée")
    assertEq(MilitaryDrop.Decoy.sirens().D1, nil, "sirène coupée au démontage")
end

function T.missing_crate_stops_the_siren_after_a_grace()
    deliver("D1")
    tick()
    CRATE.removed = true
    tick()
    assertTrue(MilitaryDrop.Decoy.sirens().D1 ~= nil, "absence récente : sirène maintenue")
    for _ = 1, 10 do
        tick()
    end
    CRATE.removed = false
    tick()
    CRATE.removed = true
    for _ = 1, 15 do
        tick()
    end
    assertTrue(MilitaryDrop.Decoy.sirens().D1 ~= nil, "caisse revue : délai remis à zéro")
    for _ = 1, 6 do
        tick()
    end
    assertEq(MilitaryDrop.Decoy.sirens().D1, nil, "caisse disparue : sirène arrêtée")
end

function T.unloaded_area_never_counts_as_missing()
    deliver("D1")
    CRATE.removed = true
    LOADED = false
    for _ = 1, 40 do
        tick()
    end
    assertTrue(MilitaryDrop.Decoy.sirens().D1 ~= nil, "zone non chargée : rien constaté")
end

function T.ground_fallback_keeps_the_siren_without_a_crate()
    MilitaryDrop.Decoy.onDelivered("D1", 100, 200, 0, nil)
    local entry = MilitaryDrop.Decoy.sirens().D1
    assertEq(entry.x, 100.5, "centre de la case")
    assertTrue(not entry.crate, "aucune caisse suivie")
    for _ = 1, 40 do
        tick()
    end
    assertTrue(MilitaryDrop.Decoy.sirens().D1 ~= nil, "seule l'échéance ou un joueur l'arrêtent")
end

-- ----------------------------------------------------------------------------
-- Position envoyée aux seuls joueurs à portée
-- ----------------------------------------------------------------------------

function T.siren_on_only_to_players_in_hearing_range()
    local alice = makePlayer("alice", 150, 200)
    local bob = makePlayer("bob", 1000, 1000)
    PLAYERS = { alice, bob }
    deliver("D1")
    tick()
    local on = sentTo("alice", "SirenOn")
    assertEq(#on, 1, "alice à portée")
    assertEq(on[1].module, "MilitaryDrop", "module")
    assertEq(on[1].args.id, 1, "numéro")
    assertEq(on[1].args.x, 100, "x")
    assertEq(on[1].args.y, 200, "y")
    assertEq(#sentTo("bob"), 0, "bob trop loin : rien")
    tick()
    assertEq(#sentTo("alice", "SirenOn"), 1, "pas de répétition")
    alice.x = 100 + 320
    tick()
    assertEq(#sentTo("alice", "SirenOff"), 0, "marge : pas de va-et-vient")
    alice.x = 100 + 400
    tick()
    assertEq(#sentTo("alice", "SirenOff"), 1, "hors de portée : SirenOff")
    bob.x, bob.y = 100, 250
    alice.x = 200
    tick()
    assertEq(#sentTo("bob", "SirenOn"), 1, "bob s'approche : SirenOn")
    assertEq(#sentTo("alice", "SirenOn"), 2, "alice revient : SirenOn")
end

function T.reconnection_and_sync_resend_the_siren()
    local alice = makePlayer("alice", 120, 200)
    PLAYERS = { alice }
    deliver("D1")
    tick()
    assertEq(#sentTo("alice", "SirenOn"), 1, "première écoute")
    -- Redémarrage ou reconnexion : liste vide, rien n'est décidé.
    PLAYERS = {}
    tick()
    PLAYERS = { alice }
    tick()
    assertEq(#sentTo("alice", "SirenOn"), 1, "liste vide : alice toujours auditrice")
    -- Le client revenu redemande les sirènes (SirenSync).
    triggerEvent("OnClientCommand", "MilitaryDrop", "SirenSync", alice, {})
    assertEq(#sentTo("alice", "SirenOn"), 2, "SirenSync : renvoyée")
    triggerEvent("OnClientCommand", "MilitaryDrop", "SirenSync", alice, {})
    assertEq(#sentTo("alice", "SirenOn"), 2, "cadence : SirenSync en rafale ignoré")
    -- Joueur absent d'une liste non vide : oublié, puis renvoyé à son retour.
    local bob = makePlayer("bob", 5000, 5000)
    PLAYERS = { bob }
    tick()
    PLAYERS = { alice, bob }
    tick()
    assertEq(#sentTo("alice", "SirenOn"), 3, "retour d'alice : renvoyée")
end

function T.sync_of_one_player_keeps_the_other_listeners()
    local alice = makePlayer("alice", 120, 200)
    local bob = makePlayer("bob", 130, 200)
    PLAYERS = { alice, bob }
    deliver("D1")
    tick()
    assertEq(#sentTo("bob", "SirenOn"), 1, "bob auditeur")
    triggerEvent("OnClientCommand", "MilitaryDrop", "SirenSync", alice, {})
    assertEq(#sentTo("alice", "SirenOn"), 2, "SirenSync : alice revue")
    tick()
    assertEq(#sentTo("bob", "SirenOn"), 1, "bob gardé : pas de nouvel SirenOn")
    assertEq(#sentTo("bob", "SirenOff"), 0, "ni de SirenOff")
end

function T.stopped_siren_sends_a_final_siren_off()
    local alice = makePlayer("alice", 120, 200)
    PLAYERS = { alice }
    deliver("D1")
    tick()
    alice.x = 100 + 400
    tick()
    local off = sentTo("alice", "SirenOff")
    assertEq(off[1].args.final, nil, "éloignement : SirenOff simple")
    alice.x = 120
    tick()
    MilitaryDrop.Decoy.stop("D1", "test")
    off = sentTo("alice", "SirenOff")
    assertEq(#off, 2, "sirène tue : SirenOff")
    assertEq(off[2].args.final, true, "marqué final")
end

function T.server_restart_restores_the_siren()
    local alice = makePlayer("alice", 120, 200)
    PLAYERS = { alice }
    deliver("D1")
    tick()
    -- Nouveau Lua (redémarrage) : seule la ModData privée reste.
    Events.OnTick.handlers = {}
    loadMod("server/MilitaryDrop/MilitaryDrop_Decoy.lua")
    triggerEvent("OnInitGlobalModData")
    assertEq(listenerCount("OnTick"), 1, "sondage repris")
    tick()
    assertEq(#sentTo("alice", "SirenOn"), 2, "SirenOn renvoyé après le redémarrage")
end

function T.solo_sends_to_the_local_client()
    SERVER = false
    RECEIVED = {}
    MilitaryDrop.Client = { onServerCommand = function(_, command, args)
        RECEIVED[#RECEIVED + 1] = { command = command, args = args }
    end }
    PLAYERS = { makePlayer("player1", 110, 200), makePlayer("player2", 115, 200) }
    deliver("D1")
    tick()
    assertEq(#RECEIVED, 1, "un seul SirenOn pour les joueurs locaux")
    assertEq(RECEIVED[1].command, "SirenOn", "SirenOn")
    MilitaryDrop.Decoy.stopByPlayer(makePlayer("player1", 101, 200), 1)
    assertEq(RECEIVED[2].command, "SirenOff", "SirenOff")
end

-- ----------------------------------------------------------------------------
-- Rien ne révèle le leurre aux autres
-- ----------------------------------------------------------------------------

--- Vrai si une table (récursive) contient une clé ou une valeur parlante.
local function mentions(value, seen)
    seen = seen or {}
    if type(value) == "string" then
        local s = string.lower(value)
        return s:find("decoy", 1, true) ~= nil or s:find("siren", 1, true) ~= nil
    end
    if type(value) ~= "table" or seen[value] then
        return false
    end
    seen[value] = true
    for k, v in pairs(value) do
        if mentions(k, seen) or mentions(v, seen) then
            return true
        end
    end
    return false
end

function T.nothing_reveals_the_decoy_to_everyone()
    local alice = makePlayer("alice", 101, 201)
    PLAYERS = { alice, makePlayer("bob", 3000, 3000) }
    deliver("D1")
    for _ = 1, 3 do
        tick()
    end
    MilitaryDrop.Decoy.stopByPlayer(alice, 1)
    assertEq(#BROADCAST, 0, "aucun message à tous")
    for tag, data in pairs(MODDATA) do
        if tag ~= PRIVATE_TAG then
            assertTrue(not mentions(data), "ModData publique « " .. tag .. " » sans leurre")
        end
    end
    for _, m in ipairs(SENT) do
        assertEq(m.player, "alice", "seul le joueur à portée reçoit quelque chose")
        for key in pairs(m.args) do
            assertTrue(key == "id" or key == "x" or key == "y" or key == "z" or key == "final",
                "aucun dropId ni type : " .. key)
        end
    end
end

return T
