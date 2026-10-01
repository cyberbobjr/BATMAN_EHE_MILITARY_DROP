-- MilitaryDrop_Siren et MilitaryDrop_SirenAction : boucle locale de la sirène
-- (jamais relayée), arrêts, menu « Couper la sirène » et parcours complet en
-- solo jusqu'au serveur (MilitaryDrop_Decoy).

local T = {}

local function makePlayer(name, x, y, z)
    local player = { name = name, x = x, y = y, z = z or 0, notes = {}, dead = false, num = 0 }
    function player.getUsername(this) return this.name end
    function player.getX(this) return this.x end
    function player.getY(this) return this.y end
    function player.getZ(this) return this.z end
    function player.isDead(this) return this.dead end
    function player.getPlayerNum(this) return this.num end
    function player.getVehicle() return nil end
    function player.isTimedActionInstant() return false end
    function player.faceLocation(this, fx, fy) this.faced = { fx, fy } end
    function player.shouldBeTurning() return false end
    function player.setMetabolicTarget() end
    function player.transmitHaloNote(this, text) this.notes[#this.notes + 1] = text end
    return player
end

--- Émetteur libre simulé : seules les méthodes locales existent (un appel à
--- playSound, relayé en MP, échouerait).
local function makeEmitter(x, y, z)
    local emitter = { x = x, y = y, z = z, playing = {}, stopped = {} }
    function emitter.setPos(this, px, py, pz) this.x, this.y, this.z = px, py, pz end
    function emitter.playSoundLoopedImpl(this, name)
        NEXT_SOUND = NEXT_SOUND + 1
        this.playing[NEXT_SOUND] = name
        PLAYED[#PLAYED + 1] = { name = name, x = this.x, y = this.y, z = this.z }
        return NEXT_SOUND
    end
    function emitter.isPlaying(this, id) return this.playing[id] ~= nil end
    function emitter.stopSoundLocal(this, id)
        this.playing[id] = nil
        STOPPED[#STOPPED + 1] = id
    end
    EMITTERS[#EMITTERS + 1] = emitter
    return emitter
end

local function makeContext()
    local context = { options = {} }
    function context.addOption(this, label, target, fn, arg)
        local option = { label = label, target = target, fn = fn, arg = arg }
        this.options[#this.options + 1] = option
        return option
    end
    return context
end

local function makeSquare(x, y, z)
    return {
        getX = function() return x end, getY = function() return y end, getZ = function() return z or 0 end,
        getVehicleContainer = function() return nil end,
        getObjects = function() return { size = function() return 0 end } end,
    }
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    CLIENT = false
    isClient = function() return CLIENT end
    isServer = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    NOW = 0
    getTimestampMs = function() return NOW end
    getText = function(key) return key end
    NEXT_SOUND = 0
    PLAYED = {}
    STOPPED = {}
    EMITTERS = {}
    getWorld = function() return { getFreeEmitter = function(_, x, y, z) return makeEmitter(x, y, z) end } end
    ALICE = makePlayer("alice", 110, 200)
    PLAYERS = { ALICE }
    getNumActivePlayers = function() return #PLAYERS end
    getSpecificPlayer = function(i) return PLAYERS[i + 1] end
    getCell = function() return { getGridSquare = function(_, x, y, z) return makeSquare(x, y, z) end } end
    COMMANDS = {}
    sendClientCommand = function(player, module, command, args)
        COMMANDS[#COMMANDS + 1] = { player = player, module = module, command = command, args = args }
    end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_Client.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Dismantle.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_SirenAction.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_Siren.lua")
end

local function sirenOn(id, x, y)
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOn", { id = id, x = x or 100, y = y or 200, z = 0 })
end

local function tick()
    NOW = NOW + 1000
    triggerEvent("OnTick")
end

-- ----------------------------------------------------------------------------
-- Boucle locale
-- ----------------------------------------------------------------------------

function T.siren_on_plays_a_local_loop_at_the_position()
    sirenOn(1)
    assertEq(MilitaryDrop.Siren.count(), 1, "sirène reçue")
    assertEq(#PLAYED, 1, "boucle lancée")
    assertEq(PLAYED[1].name, "VehicleSirenWall", "son vanilla de sirène en boucle")
    assertEq(PLAYED[1].x, 100, "x")
    assertEq(PLAYED[1].y, 200, "y")
    sirenOn(1)
    assertEq(#PLAYED, 1, "SirenOn répété : pas de deuxième boucle")
    tick()
    assertEq(#PLAYED, 1, "boucle en cours : rien relancé")
end

function T.siren_off_stops_the_loop_locally()
    sirenOn(1)
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOff", { id = 1, final = true })
    assertEq(MilitaryDrop.Siren.count(), 0, "sirène oubliée")
    assertEq(STOPPED[1], 1, "stopSoundLocal")
    assertEq(listenerCount("OnTick"), 0, "plus de sondage")
end

function T.leaving_player_stops_the_loop_when_alone()
    sirenOn(1)
    ALICE.x = 100 + 400
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOff", { id = 1 })
    assertEq(MilitaryDrop.Siren.count(), 0, "seul joueur local parti : boucle coupée")
end

function T.split_screen_keeps_the_loop_for_the_other_local_player()
    CLIENT = true
    local bob = makePlayer("bob", 130, 200)
    bob.num = 1
    PLAYERS = { ALICE, bob }
    sirenOn(1)
    -- Alice s'éloigne : SirenOff pour elle seule, Bob écoute encore.
    ALICE.x = 100 + 400
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOff", { id = 1 })
    assertEq(MilitaryDrop.Siren.count(), 1, "boucle gardée pour Bob")
    assertEq(#STOPPED, 0, "rien arrêté")
    local last = COMMANDS[#COMMANDS]
    assertEq(last and last.command, "SirenSync", "Bob redemande les sirènes au serveur")
    assertEq(last.player, bob, "au nom de Bob")
    -- La sirène se tait : SirenOff final, coupé même avec Bob à portée.
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOff", { id = 1, final = true })
    assertEq(MilitaryDrop.Siren.count(), 0, "sirène tue : boucle coupée")
    assertEq(#STOPPED, 1, "aucune boucle orpheline")
end

function T.split_screen_stops_when_the_last_listener_leaves()
    CLIENT = true
    local bob = makePlayer("bob", 130, 200)
    bob.num = 1
    PLAYERS = { ALICE, bob }
    sirenOn(1)
    ALICE.x = 100 + 400
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOff", { id = 1 })
    bob.x = 100 + 400
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOff", { id = 1 })
    assertEq(MilitaryDrop.Siren.count(), 0, "plus personne à portée : boucle coupée")
end

function T.stopped_loop_restarts_on_a_new_emitter()
    sirenOn(1)
    EMITTERS[1].playing = {}
    tick()
    assertEq(#PLAYED, 2, "boucle relancée")
    assertEq(#EMITTERS, 2, "émetteur neuf (l'ancien est rendu à la réserve)")
end

function T.out_of_range_stops_locally()
    sirenOn(1)
    ALICE.x = 100 + 330
    tick()
    assertEq(MilitaryDrop.Siren.count(), 1, "dans la marge : le serveur décide")
    ALICE.x = 100 + 400
    tick()
    assertEq(MilitaryDrop.Siren.count(), 0, "trop loin : arrêt local (SirenOff perdu)")
    assertEq(#STOPPED, 1, "boucle arrêtée")
end

function T.disconnect_stops_every_loop()
    sirenOn(1)
    sirenOn(2, 300, 300)
    triggerEvent("OnDisconnect")
    assertEq(MilitaryDrop.Siren.count(), 0, "tout oublié")
    assertEq(#STOPPED, 2, "deux boucles arrêtées")
end

function T.bad_arguments_are_ignored()
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOn", { id = "x", x = 1 })
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOn", { id = 3 })
    assertEq(MilitaryDrop.Siren.count(), 0, "rien joué")
end

function T.game_start_asks_the_server_in_mp_only()
    triggerEvent("OnGameStart")
    local sync = 0
    for _, c in ipairs(COMMANDS) do
        if c.command == "SirenSync" then
            sync = sync + 1
        end
    end
    assertEq(sync, 0, "solo : rien à demander")
    CLIENT = true
    triggerEvent("OnGameStart")
    for _, c in ipairs(COMMANDS) do
        if c.command == "SirenSync" then
            sync = sync + 1
        end
    end
    assertEq(sync, 1, "MP : SirenSync")
end

-- ----------------------------------------------------------------------------
-- Menu « Couper la sirène »
-- ----------------------------------------------------------------------------

local function loadMenu()
    QUEUE = {}
    getMouseXScaled = function() return 0 end
    getMouseYScaled = function() return 0 end
    JoypadState = { players = {} }
    PICKED = nil
    IsoObjectPicker = { Instance = { PickVehicle = function() return PICKED end } }
    ISToolTip = { new = function()
        return { initialise = function() end, setVisible = function() end, setName = function() end }
    end }
    ISTimedActionQueue = { add = function(action) QUEUE[#QUEUE + 1] = action end }
    ISPathFindAction = {
        pathToVehicleArea = function(_, _, _, area) return { path = area } end,
        pathToVehicleAdjacent = function() return { path = "adjacent" } end,
    }
    luautils = { walkAdj = function(_, square)
        QUEUE[#QUEUE + 1] = { walk = square }
        return true
    end }
    ISBaseTimedAction = {}
    function ISBaseTimedAction.derive(parent, type)
        return setmetatable({ Type = type }, { __index = parent })
    end
    function ISBaseTimedAction.new(class, character)
        return setmetatable({ character = character, maxTime = -1 }, { __index = class })
    end
    function ISBaseTimedAction.perform() end
    function ISBaseTimedAction.stop() end
    loadMod("shared/MilitaryDrop/MilitaryDrop_SirenAction.lua")
end

--- Objet du monde simulé sur la case (x, y).
local function worldObject(x, y)
    return { getSquare = function() return makeSquare(x, y, 0) end }
end

function T.menu_appears_only_near_a_received_siren()
    loadMenu()
    local context = makeContext()
    triggerEvent("OnFillWorldObjectContextMenu", 0, context, { worldObject(100, 200) }, false)
    assertEq(#context.options, 0, "aucune sirène reçue : aucune option (pas de nom, pas d'objet)")
    sirenOn(1)
    triggerEvent("OnFillWorldObjectContextMenu", 0, context, { worldObject(110, 210) }, false)
    assertEq(#context.options, 0, "case loin de la sirène : aucune option")
    triggerEvent("OnFillWorldObjectContextMenu", 0, context, { worldObject(101, 199) }, false)
    assertEq(#context.options, 1, "case près de la sirène : option")
    assertEq(context.options[1].label, "IGUI_MilitaryDrop_SirenStop", "libellé")
    assertEq(context.options[1].arg, 1, "numéro de la sirène")
end

function T.menu_picks_the_crate_under_the_mouse()
    loadMenu()
    sirenOn(1)
    PICKED = { getX = function() return 100 end, getY = function() return 200 end, getZ = function() return 0 end }
    local context = makeContext()
    triggerEvent("OnFillWorldObjectContextMenu", 0, context, {}, false)
    assertEq(#context.options, 1, "caisse sous la souris")
end

function T.choosing_the_option_walks_then_queues_the_action()
    loadMenu()
    sirenOn(1)
    local context = makeContext()
    triggerEvent("OnFillWorldObjectContextMenu", 0, context, { worldObject(100, 200) }, false)
    local option = context.options[1]
    option.fn(option.target, option.arg)
    assertTrue(QUEUE[1].walk ~= nil, "marche jusqu'à la sirène")
    local action = QUEUE[2]
    assertEq(action.sirenId, 1, "action sur cette sirène")
    assertEq(action.character, ALICE, "personnage")
    assertEq(action.maxTime, 200, "durée")
    assertEq(MilitaryDrop.SirenAction.Type, "MilitaryDrop.SirenAction", "type résolu par nom pointé")
end

function T.action_is_valid_only_near_a_known_siren()
    loadMenu()
    sirenOn(1)
    ALICE.x, ALICE.y = 101, 201
    local action = MilitaryDrop.SirenAction.new(nil, ALICE, 1)
    assertTrue(action:isValid(), "à portée")
    ALICE.x = 110
    assertTrue(not action:isValid(), "trop loin")
    ALICE.x = 101
    MilitaryDrop.Client.onServerCommand("MilitaryDrop", "SirenOff", { id = 1, final = true })
    assertTrue(not action:isValid(), "sirène coupée entre-temps")
    assertTrue(not MilitaryDrop.SirenAction.new(nil, ALICE, 1):complete(), "client MP : rien sans le serveur")
end

-- ----------------------------------------------------------------------------
-- Parcours complet en solo (serveur et client dans le même Lua)
-- ----------------------------------------------------------------------------

function T.solo_end_to_end()
    loadMenu()
    MODDATA = {}
    ModData = { getOrCreate = function(tag)
        MODDATA[tag] = MODDATA[tag] or {}
        return MODDATA[tag]
    end }
    getGameTime = function() return { getWorldAgeHours = function() return 10 end } end
    NOISES = 0
    getWorldSoundManager = function()
        return { addSoundRepeating = function() NOISES = NOISES + 1 end }
    end
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    MilitaryDrop.Secrets = { privateState = function() return ModData.getOrCreate("MilitaryDrop_private") end }
    loadMod("server/MilitaryDrop/MilitaryDrop_Decoy.lua")
    local id = MilitaryDrop.Decoy.onDelivered("D1", 100, 200, 0, nil)
    tick()
    assertEq(NOISES, 1, "bruit du serveur")
    assertEq(MilitaryDrop.Siren.count(), 1, "le client joue la sirène")
    ALICE.x, ALICE.y = 101, 201
    local action = MilitaryDrop.SirenAction.new(nil, ALICE, id)
    assertTrue(action:isValid(), "action valide")
    assertTrue(action:complete(), "coupée par le serveur")
    assertEq(MilitaryDrop.Siren.count(), 0, "le client l'a arrêtée")
    assertEq(#STOPPED, 1, "boucle arrêtée")
    assertEq(ALICE.notes[1], "IGUI_MilitaryDrop_SirenStopped", "note au joueur")
end

return T
