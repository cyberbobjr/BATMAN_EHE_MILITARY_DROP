-- MilitaryDrop_Dismantle : démontage de la caisse avec les règles vanilla du bois
-- (ISMoveableDefinitions et ISMoveableSpriteProps du jeu installé, lus tels quels).

local T = {}

-- Sans le jeu installé, les définitions vanilla manquent : tout le fichier est ignoré.
T.skip = (not hasVanilla) and "jeu absent (PZ_MEDIA) : définitions vanilla de démontage indisponibles" or nil

-- Objets désignés par les tags HAMMER et SAW dans ces tests (getItemsTag simulé).
local TAGGED = {
    hammer = { "Base.Hammer", "Base.HammerStone" },
    saw = { "Base.Saw" },
}

local function makeItem(fullType, tags)
    local item = { kind = "InventoryItem", fullType = fullType, tags = tags or {} }
    function item.getType(this) return (this.fullType:gsub("^.-%.", "")) end
    function item.getFullType(this) return this.fullType end
    function item.getDisplayName(this) return "name:" .. this.fullType end
    function item.hasTag(this, tag) return this.tags[tag] == true end
    function item.setUsedDelta() end
    function item.UseAndSync(this) this.used = (this.used or 0) + 1 end
    return item
end

local function makePlayer(opts)
    opts = opts or {}
    local inventory = { items = opts.items or {}, added = {} }
    function inventory.getFirstTypeRecurse(this, fullType)
        for _, item in ipairs(this.items) do
            if item.fullType == fullType then
                return item
            end
        end
        return nil
    end
    function inventory.getFirstTypeEvalRecurse(this, fullType, predicate)
        local item = this:getFirstTypeRecurse(fullType)
        return item and predicate(item) and item or nil
    end
    local player = {
        kind = "IsoPlayer", x = opts.x or 10.5, y = opts.y or 10.5, z = opts.z or 0,
        level = opts.level or 0, cheat = opts.cheat == true, inventory = inventory,
        notes = {}, sounds = {}, xp = {}, primary = opts.primary,
    }
    function player.getInventory(this) return this.inventory end
    function player.getX(this) return this.x end
    function player.getY(this) return this.y end
    function player.getZ(this) return this.z end
    function player.getPerkLevel(this) return this.level end
    function player.isMovablesCheat(this) return this.cheat end
    function player.isTimedActionInstant() return false end
    function player.getUsername() return "alice" end
    function player.getPrimaryHandItem(this) return this.primary end
    function player.transmitHaloNote(this, text) this.notes[#this.notes + 1] = text end
    function player.playSound(this, sound) this.sounds[#this.sounds + 1] = sound; return 1 end
    return player
end

local function makeVehicle(opts)
    opts = opts or {}
    local square = { dropped = {} }
    function square.AddWorldInventoryItem(this, item) this.dropped[#this.dropped + 1] = item.fullType end
    local trunk = { items = opts.items or {} }
    function trunk.isEmpty(this) return #this.items == 0 end
    local parts = {
        { getItemContainer = function() return nil end, getArea = function() return nil end },
        { getItemContainer = function() return trunk end, getArea = function() return "TruckBed" end },
    }
    local vehicle = {
        kind = "BaseVehicle", script = opts.script or "Base.MilitaryDrop_SupplyCrate",
        removed = opts.removed == true, x = 11, y = 11, z = 0, square = square, trunk = trunk,
    }
    function vehicle.getScriptName(this) return this.script end
    function vehicle.isRemovedFromWorld(this) return this.removed end
    function vehicle.getX(this) return this.x end
    function vehicle.getY(this) return this.y end
    function vehicle.getZ(this) return this.z end
    function vehicle.getSquare(this) return this.square end
    function vehicle.getPartCount() return #parts end
    function vehicle.getPartByIndex(_, i) return parts[i + 1] end
    function vehicle.permanentlyRemove(this) this.removed = true; this.removedCount = (this.removedCount or 0) + 1 end
    return vehicle
end

-- Inventaire complet : un marteau (2e type du tag) et une scie.
local function tools()
    return { makeItem("Base.HammerStone", { hammer = true }), makeItem("Base.Saw", { saw = true }) }
end

function T.setup()
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    string.contains = function(s, sub) return string.find(s, sub, 1, true) ~= nil end
    ItemTag = setmetatable({}, { __index = function(_, key) return string.lower(key) end })
    Perks = setmetatable({}, { __index = function(_, key) return key end })
    PerkFactory = { getPerkName = function(perk) return "perk:" .. tostring(perk) end }
    getScriptManager = function()
        return { getItemsTag = function(_, tag)
            local list = TAGGED[tag] or {}
            return {
                size = function() return #list end,
                get = function(_, i) return { getFullName = function() return list[i + 1] end } end,
            }
        end }
    end
    ScriptManager = { instance = { FindItem = function(_, fullType)
        return { getDisplayName = function() return "name:" .. fullType end }
    end } }
    IsoGridSquare = { ignoreBlockingSprites = { add = function() end } }
    -- Énumérations lues au chargement d'ISMoveableSpriteProps (tables de modes).
    IsoFlagType = setmetatable({}, { __index = function(_, key) return key end })
    getCore = function()
        return { getGoodHighlitedColor = function() return {} end, getBadHighlitedColor = function() return {} end }
    end
    IsoThumpable = { GetBreakFurnitureSound = function() return "BreakFurniture" end }
    SandboxVars = { LevelForDismantleXPCutoff = 3 }
    getText = function(key, arg) return arg and (key .. ":" .. tostring(arg)) or key end
    ROLL = 0
    ZombRandFloat = function() return ROLL end
    ZombRand = function(low) return low end
    instanceItem = function(fullType) return makeItem(fullType) end
    XP = {}
    addXp = function(character, perk, amount) XP[#XP + 1] = { character = character, perk = perk, amount = amount } end
    addSound = function() NOISE = true end
    NOISE = false
    ISInventoryPage = { dirtyUI = function() end }
    -- ISBaseTimedAction : derive et new comme ISBaseObject / ISBaseTimedAction.
    ISBaseTimedAction = {}
    function ISBaseTimedAction.derive(parent, type)
        return setmetatable({ Type = type }, { __index = parent })
    end
    function ISBaseTimedAction.new(class, character)
        return setmetatable({ character = character, maxTime = -1 }, { __index = class })
    end
    function ISBaseTimedAction.perform() end
    function ISBaseTimedAction.stop() end
    assertTrue(loadVanilla("shared/Moveables/ISMoveableDefinitions.lua"), "ISMoveableDefinitions vanilla")
    assertTrue(loadVanilla("shared/Moveables/ISMoveableSpriteProps.lua"), "ISMoveableSpriteProps vanilla")
    triggerEvent("OnGameBoot")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Dismantle.lua")
end

-- ----------------------------------------------------------------------------
-- Définition vanilla
-- ----------------------------------------------------------------------------

function T.wood_definition_read_from_vanilla()
    local def = MilitaryDrop.Dismantle.definition()
    assertTrue(def ~= nil, "définition Wood active")
    assertEq(def.perk, "Woodwork", "compétence Menuiserie")
    assertEq(def.baseActionTime, 1000, "durée de base de la définition active (la première l'emporte)")
    assertEq(def.tools[2], "Base.HammerStone", "outils : objets du tag HAMMER")
    assertEq(def.tools2[1], "Base.Saw", "outils 2 : objets du tag SAW")
end

function T.crate_is_recognised_by_its_script()
    local Dismantle = MilitaryDrop.Dismantle
    assertTrue(Dismantle.isCrate(makeVehicle()), "caisse du mod")
    assertTrue(not Dismantle.isCrate(makeVehicle({ script = "Base.Trailer" })), "autre véhicule")
    assertTrue(not Dismantle.isCrate(makeVehicle({ removed = true })), "véhicule retiré")
    assertTrue(not Dismantle.isCrate(nil), "aucun véhicule")
end

function T.script_matches_the_server_crate()
    VehicleDistributions = { {} }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Crate.lua")
    assertEq(MilitaryDrop.Dismantle.SCRIPT, MilitaryDrop.Crate.FULL_SCRIPT, "même script que Crate.spawn")
end

-- ----------------------------------------------------------------------------
-- Contrôles (menu, isValid, complete)
-- ----------------------------------------------------------------------------

function T.check_accepts_empty_crate_with_tools()
    assertEq(MilitaryDrop.Dismantle.check(makePlayer({ items = tools() }), makeVehicle()), nil, "démontage possible")
end

function T.check_requires_an_empty_trunk()
    local vehicle = makeVehicle({ items = { makeItem("MilitaryDrop.AmmoSupplyCase") } })
    assertEq(MilitaryDrop.Dismantle.check(makePlayer({ items = tools() }), vehicle), "notEmpty", "coffre plein")
end

function T.check_requires_both_tool_sets()
    local Dismantle = MilitaryDrop.Dismantle
    local hammerOnly = makePlayer({ items = { makeItem("Base.Hammer", { hammer = true }) } })
    assertEq(Dismantle.check(hammerOnly, makeVehicle()), "noTools", "scie manquante")
    assertEq(Dismantle.check(makePlayer(), makeVehicle()), "noTools", "aucun outil")
    assertEq(Dismantle.check(makePlayer({ cheat = true }), makeVehicle()), nil, "triche des meubles : sans outils")
end

function T.check_distance_and_floor_unless_menu()
    local Dismantle = MilitaryDrop.Dismantle
    local far = makePlayer({ items = tools(), x = 20 })
    assertEq(Dismantle.check(far, makeVehicle()), "tooFar", "trop loin")
    assertEq(Dismantle.check(far, makeVehicle(), { ignoreDistance = true }), nil, "menu : le personnage s'approchera")
    assertEq(Dismantle.check(makePlayer({ items = tools(), z = 1 }), makeVehicle()), "tooFar", "autre étage")
end

function T.check_rejects_other_vehicles()
    local player = makePlayer({ items = tools() })
    assertEq(MilitaryDrop.Dismantle.check(player, makeVehicle({ script = "Base.Trailer" })), "gone", "autre script")
    assertEq(MilitaryDrop.Dismantle.check(player, nil), "gone", "véhicule disparu")
end

function T.duration_follows_the_skill()
    assertEq(MilitaryDrop.Dismantle.duration(makePlayer()), 1000, "niveau 0")
    assertEq(MilitaryDrop.Dismantle.duration(makePlayer({ level = 5 })), 850, "−3 % par niveau")
    assertEq(MilitaryDrop.Dismantle.duration(makePlayer({ cheat = true })), 1, "triche")
end

-- ----------------------------------------------------------------------------
-- Démontage (serveur ou solo)
-- ----------------------------------------------------------------------------

function T.perform_drops_wood_gives_xp_and_removes_the_crate()
    local player = makePlayer({ items = tools() })
    local vehicle = makeVehicle()
    ROLL = 0
    assertTrue(MilitaryDrop.Dismantle.perform(player, vehicle), "caisse démontée")
    assertEq(vehicle.removedCount, 1, "véhicule retiré une fois")
    assertEq(#vehicle.square.dropped, 2, "planche : 1 essai, ×2 pour une grande caisse")
    assertEq(vehicle.square.dropped[1], "Base.Plank", "matériau de la définition")
    assertEq(#XP, 1, "XP donnée")
    assertEq(XP[1].perk, "Woodwork", "XP de Menuiserie")
    assertEq(XP[1].amount, 15, "5 × 3 (grande caisse)")
    assertEq(#player.notes, 0, "aucune note d'échec")
    assertTrue(not NOISE, "son « Hammering » joué par l'animation : aucun bruit pour les zombies")
end

function T.perform_failure_gives_unusable_wood()
    local player = makePlayer({ items = tools() })
    local vehicle = makeVehicle()
    ROLL = 100
    assertTrue(MilitaryDrop.Dismantle.perform(player, vehicle), "caisse démontée quand même")
    assertEq(vehicle.square.dropped[1], "Base.UnusableWood", "objet inutilisable de la définition")
    assertEq(player.notes[1], "IGUI_Moveable_Fail", "note vanilla d'échec")
    assertEq(player.sounds[1], "BreakFurniture", "son de meuble cassé")
end

function T.perform_rechecks_everything()
    local Dismantle = MilitaryDrop.Dismantle
    local full = makeVehicle({ items = { makeItem("MilitaryDrop.AmmoSupplyCase") } })
    local player = makePlayer({ items = tools() })
    assertTrue(not Dismantle.perform(player, full), "coffre plein refusé")
    assertEq(full.removedCount, nil, "caisse intacte")
    assertEq(player.notes[1], "IGUI_MilitaryDrop_DismantleEmptyFirst", "raison au joueur")
    local noTools = makePlayer()
    local vehicle = makeVehicle()
    assertTrue(not Dismantle.perform(noTools, vehicle), "sans outils refusé")
    vehicle.removed = true
    assertTrue(not Dismantle.perform(player, vehicle), "caisse déjà retirée")
    assertEq(#XP, 0, "aucune XP")
end

function T.xp_stops_at_the_sandbox_cutoff()
    MilitaryDrop.Dismantle.perform(makePlayer({ items = tools(), level = 3 }), makeVehicle())
    assertEq(#XP, 0, "niveau ≥ LevelForDismantleXPCutoff")
end

-- ----------------------------------------------------------------------------
-- Action chronométrée
-- ----------------------------------------------------------------------------

function T.action_rebuilt_by_the_server_completes()
    local player = makePlayer({ items = tools() })
    local vehicle = makeVehicle()
    -- Le serveur appelle MilitaryDrop.DismantleAction.new avec nil à la place de la classe.
    local action = MilitaryDrop.DismantleAction.new(nil, player, vehicle)
    assertEq(MilitaryDrop.DismantleAction.Type, "MilitaryDrop.DismantleAction", "type résolu par nom pointé")
    assertEq(action.character, player, "champ character")
    assertEq(action.vehicle, vehicle, "champ vehicle")
    assertEq(action.maxTime, 1000, "durée")
    assertTrue(action:isValid(), "valide")
    assertTrue(action:complete(), "complete")
    assertEq(vehicle.removedCount, 1, "caisse retirée")
    assertTrue(not action:isValid(), "plus valide ensuite")
end

-- ----------------------------------------------------------------------------
-- Menu client
-- ----------------------------------------------------------------------------

local function loadMenu(player, vehicle)
    QUEUE = {}
    EQUIPPED = {}
    getSpecificPlayer = function() return player end
    getMouseXScaled = function() return 0 end
    getMouseYScaled = function() return 0 end
    JoypadState = { players = {} }
    IsoObjectPicker = { Instance = { PickVehicle = function() return vehicle end } }
    ISToolTip = { new = function()
        return { initialise = function() end, setVisible = function() end, setName = function() end }
    end }
    ISTimedActionQueue = { add = function(action) QUEUE[#QUEUE + 1] = action end }
    ISPathFindAction = {
        pathToVehicleArea = function(_, _, _, area) return { path = area } end,
        pathToVehicleAdjacent = function() return { path = "adjacent" } end,
    }
    ISWorldObjectContextMenu = { equip = function(_, _, item, primary)
        EQUIPPED[#EQUIPPED + 1] = { item = item, primary = primary }
        QUEUE[#QUEUE + 1] = { equip = item }
    end }
    player.getVehicle = function() return nil end
    player.getSecondaryHandItem = function() return nil end
    loadMod("client/MilitaryDrop/MilitaryDrop_DismantleMenu.lua")
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

function T.menu_option_greyed_with_reason()
    local player = makePlayer({ items = tools() })
    local vehicle = makeVehicle({ items = { makeItem("MilitaryDrop.AmmoSupplyCase") } })
    loadMenu(player, vehicle)
    local context = makeContext()
    triggerEvent("OnFillWorldObjectContextMenu", 0, context, {}, false)
    assertEq(#context.options, 1, "option ajoutée")
    assertEq(context.options[1].label, "IGUI_MilitaryDrop_Dismantle", "libellé")
    assertTrue(context.options[1].notAvailable, "grisée")
    local text = context.options[1].toolTip.description
    assertTrue(text:find("IGUI_MilitaryDrop_DismantleEmptyFirst", 1, true) ~= nil, "raison dans l'infobulle")
    assertTrue(text:find("name:Base.HammerStone", 1, true) ~= nil, "outil possédé affiché")
end

function T.menu_ignores_other_vehicles()
    local player = makePlayer({ items = tools() })
    loadMenu(player, makeVehicle({ script = "Base.Trailer" }))
    local context = makeContext()
    triggerEvent("OnFillWorldObjectContextMenu", 0, context, {}, false)
    assertEq(#context.options, 0, "aucune option")
end

function T.menu_walks_equips_then_dismantles()
    local player = makePlayer({ items = tools() })
    local vehicle = makeVehicle()
    loadMenu(player, vehicle)
    local context = makeContext()
    triggerEvent("OnFillWorldObjectContextMenu", 0, context, {}, false)
    local option = context.options[1]
    assertTrue(not option.notAvailable, "disponible")
    option.fn(option.target, option.arg)
    assertEq(QUEUE[1].path, "TruckBed", "marche jusqu'à la zone du coffre")
    assertEq(EQUIPPED[1].item.fullType, "Base.HammerStone", "marteau en main principale")
    assertTrue(EQUIPPED[1].primary, "main principale")
    assertEq(EQUIPPED[2].item.fullType, "Base.Saw", "scie en main secondaire")
    assertEq(QUEUE[#QUEUE].vehicle, vehicle, "action de démontage en dernier")
end

return T
