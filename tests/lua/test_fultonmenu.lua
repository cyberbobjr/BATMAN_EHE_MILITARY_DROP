-- MilitaryDrop_FultonMenu : kit POSÉ AU SOL (décision du 2026-10-07). Menu du
-- kit au sol (monde et liste du sol) ou dans l'inventaire (grisé : « posez-le
-- au sol »), motifs de grisé, confirmation sans chiffre, file d'actions (marche
-- jusqu'au kit, bouteille sortie du sac), action de gonflage qui envoie
-- FultonLaunch avec la case du kit, résultat du serveur.

local T = {}

local function list(values)
    return {
        size = function() return #values end,
        get = function(_, i) return values[i + 1] end,
    }
end

local function item(fullType, tags, name)
    local it = { fullType = fullType, tags = {}, name = name or fullType }
    for _, tag in ipairs(tags or {}) do
        it.tags[tag] = true
    end
    function it.hasTag(self, tag) return self.tags[tag] == true end
    function it.getFullType(self) return self.fullType end
    function it.getDisplayName(self) return self.name end
    function it.getScriptItem(self) return { getDisplayName = function() return self.fullType end } end
    function it.getStashMap() return nil end
    function it.getWorldItem(self) return self.worldItem end
    return it
end

local nextId = 100

local function container(items)
    local c = { items = items or {} }
    function c.getItems(self) return list(self.items) end
    function c.contains(self, it)
        for _, x in ipairs(self.items) do
            if x == it then
                return true
            end
        end
        return false
    end
    function c.getAllTypeRecurse(self, fullType)
        local found = {}
        local function walk(cont)
            for _, x in ipairs(cont.items) do
                if x.fullType == fullType then
                    found[#found + 1] = x
                end
                if x.inner then
                    walk(x.inner)
                end
            end
        end
        walk(self)
        return list(found)
    end
    return c
end

local function withId(it)
    nextId = nextId + 1
    it.id = nextId
    function it.getID(self) return self.id end
    return it
end

local function makeKit(contents)
    local kit = withId(item("MilitaryDrop.FultonKit", {}, "Fulton recovery kit"))
    kit.inner = container(contents)
    function kit.getItemContainer(self) return self.inner end
    return kit
end

local function makeTank(uses)
    local tank = withId(item("MilitaryDrop.HeliumTank"))
    tank.uses = uses
    function tank.getCurrentUses(self) return self.uses end
    return tank
end

--- Case du sol (10, 20, 0) : objets posés.
local function makeGround()
    local sq = { objects = {}, inside = false }
    function sq.isOutside(self) return not self.inside end
    function sq.getTree() return nil end
    function sq.getX() return 10 end
    function sq.getY() return 20 end
    function sq.getZ() return 0 end
    function sq.getWorldObjects(self) return list(self.objects) end
    return sq
end

local function putOnGround(kit)
    local object = { kit = kit }
    function object.getItem(self) return self.kit end
    function object.getSquare() return GROUND end
    GROUND.objects[#GROUND.objects + 1] = object
    kit.worldItem = object
    return object
end

local function makePlayer()
    local p = { inventory = container({}), said = {}, x = 11.5, y = 20.5, z = 0 }
    function p.getPlayerNum() return 0 end
    function p.getUsername() return "alice" end
    function p.getInventory(self) return self.inventory end
    function p.getDescriptor()
        return { getForename = function() return "Alice" end, getSurname = function() return "Martin" end }
    end
    function p.getX(self) return self.x end
    function p.getY(self) return self.y end
    function p.getZ(self) return self.z end
    function p.faceLocation(self, x, y) self.faced = x .. "," .. y end
    function p.Say(self, text) self.said[#self.said + 1] = text end
    function p.SetVariable() end
    function p.getPrimaryHandItem(self) return self.hand end
    function p.getSecondaryHandItem() return nil end
    return p
end

--- Joueur prêt : kit au contenu donné posé au sol à côté, bouteille dans
--- l'inventaire, créneau ouvert.
local function ready(contents)
    local player = makePlayer()
    local kit, tank = makeKit(contents), makeTank(4)
    putOnGround(kit)
    player.inventory.items = { tank }
    PLAYER = player
    FultonClient.onWindow(0, { minutesLeft = 30, dailyLeft = 10 })
    return player, kit, tank
end

--- Menu contextuel simulé : options ajoutées.
local function makeContext()
    local context = { options = {} }
    function context.addOption(self, name, target, fn, param)
        local option = { name = name, target = target, fn = fn, param = param }
        self.options[#self.options + 1] = option
        return option
    end
    return context
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return true end
    isServer = function() return false end
    instanceof = function(object, class)
        if class == "InventoryItem" then
            return type(object) == "table" and object.fullType ~= nil
        end
        return type(object) == "table" and object.kind == class
    end
    ItemTag = { APPLY_OWNER_NAME = "base:applyownername", IDCARD = "base:idcard", HAZMAT_SUIT = "base:hazmatsuit",
        SCBA = "base:scba", GAS_MASK = "base:gasmask", GASMASK_FILTER = "base:gasmaskfilter" }
    getActivatedMods = function() return list({}) end
    HOURS = 1000
    getGameTime = function() return { getWorldAgeHours = function() return HOURS end } end
    getClimateManager = function()
        return { getIsThunderStorming = function() return false end, getWindspeedKph = function() return 5 end }
    end
    getText = function(key, ...)
        local parts = { key }
        for _, value in ipairs({ ... }) do
            parts[#parts + 1] = tostring(value)
        end
        return table.concat(parts, "|")
    end
    QUEUE, SENT, HALO, NOISE, TRANSFERS, WALKS = {}, {}, {}, {}, {}, {}
    GROUND = makeGround()
    EMPTY = {}
    getCell = function()
        return { getGridSquare = function(_, x, y, z)
            if x == 10 and y == 20 and z == 0 then
                return GROUND
            end
            local key = x .. "," .. y .. "," .. z
            EMPTY[key] = EMPTY[key] or { getWorldObjects = function() return list({}) end,
                getX = function() return x end, getY = function() return y end, getZ = function() return z end }
            return EMPTY[key]
        end }
    end
    RADIO_SAID, LATER = {}, {}
    ISBaseTimedAction = {}
    function ISBaseTimedAction.derive(parent, type)
        return setmetatable({ Type = type }, { __index = parent })
    end
    function ISBaseTimedAction.new(class, character)
        local o = setmetatable({}, { __index = class })
        o.character = character
        return o
    end
    function ISBaseTimedAction.perform(self) self.performed = true end
    function ISBaseTimedAction.setActionAnim(self, anim) self.anim = anim end
    ISTimedActionQueue = { add = function(action) QUEUE[#QUEUE + 1] = action end }
    ISInventoryPaneContextMenu = { transferIfNeeded = function(_, it) TRANSFERS[#TRANSFERS + 1] = it end }
    luautils = { walkAdj = function(_, square, keep)
        WALKS[#WALKS + 1] = { square = square, keep = keep }
        return true
    end }
    ISToolTip = { new = function() return { initialise = function() end, setVisible = function() end } end }
    addSound = function(_, x, y, z, radius, volume) NOISE[#NOISE + 1] = { x = x, y = y, radius = radius, volume = volume } end
    HaloTextHelper = { addText = function(_, text) HALO[#HALO + 1] = text end }
    getSpecificPlayer = function() return PLAYER end
    getNumActivePlayers = function() return 1 end
    local noop = { Add = function() end, Remove = function() end }
    Events = setmetatable({}, { __index = function() return noop end })
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    MilitaryDrop.Net = { toServer = function(player, command, args)
        SENT[#SENT + 1] = { player = player, command = command, args = args }
    end }
    MilitaryDrop.Exchange = { REPLY_DELAY_MS = 4000, LINE_DELAY_MS = 3500,
        lineText = function(line) return line.key .. "|" .. table.concat(line.params or {}, "|") end }
    MilitaryDrop.Client = { HANDLERS = {},
        later = function(delay, fn) LATER[#LATER + 1] = delay fn() end,
        radioSay = function(request, text) RADIO_SAID[#RADIO_SAID + 1] = { device = request.device, text = text } end }
    MilitaryDrop.Radio = {
        isInventoryRadio = function(object) return type(object) == "table" and object.radio == true end,
        isMilitary = function(object) return object.military == true end,
    }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Fulton.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonClient.lua")
    FultonClient = MilitaryDrop.FultonClient
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonMenu.lua")
    FultonMenu = MilitaryDrop.FultonMenu
end

function T.reasons_follow_the_launch_conditions()
    local player, kit, tank = ready({ item("Base.Paperwork") })
    assertEq(FultonMenu.reason(player, kit), nil, "kit au sol, tout est prêt")
    GROUND.inside = true
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_NotOutside", "kit à l'intérieur")
    GROUND.inside = false
    tank.uses = 0
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_NoHelium", "bouteille vide")
    tank.uses = 4
    kit.inner.items = {}
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_EmptyKit", "kit vide")
    kit.inner.items = { item("Base.Paperwork") }
    FultonClient.reset()
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_NoWindow", "pas de créneau")
    FultonClient.onWindow(0, { minutesLeft = 30, dailyLeft = 10 })
    kit.worldItem = nil
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_PutOnGround", "kit dans l'inventaire")
    SandboxVars.MilitaryDrop.FultonValue = 0
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_SourceDisabled", "Fulton désactivé")
end

function T.inventory_kit_shows_a_greyed_option_that_explains_what_to_do()
    local player = makePlayer()
    PLAYER = player
    local kit = makeKit({ item("Base.Paperwork") })
    player.inventory.items = { kit, makeTank(4) }
    FultonClient.onWindow(0, { minutesLeft = 30, dailyLeft = 10 })
    local context = makeContext()
    FultonMenu.onFillContextMenu(0, context, { kit })
    assertEq(#context.options, 1, "option visible")
    assertTrue(context.options[1].notAvailable, "grisée")
    assertEq(context.options[1].toolTip.description, "IGUI_MilitaryDrop_Fulton_PutOnGround", "posez-le au sol, dehors")
end

function T.world_right_click_finds_the_kit_on_the_ground()
    local player, kit = ready({ item("Base.Paperwork") })
    local neighbour = getCell():getGridSquare(11, 21, 0)
    local near = makeContext()
    FultonMenu.onFillWorldContextMenu(0, near, { { getSquare = function() return neighbour end } }, false)
    assertEq(near.options[1] and near.options[1].param, kit, "clic sur la case voisine : kit trouvé (rayon d'une case)")
    local far = makeContext()
    local distant = getCell():getGridSquare(13, 20, 0)
    FultonMenu.onFillWorldContextMenu(0, far, { { getSquare = function() return distant end } }, false)
    assertEq(#far.options, 0, "à trois cases : rien")
    local context = makeContext()
    FultonMenu.onFillWorldContextMenu(0, context, { { getSquare = function() return GROUND end } }, false)
    assertEq(#context.options, 1, "une option")
    assertEq(context.options[1].param, kit, "pour le kit posé")
    assertTrue(not context.options[1].notAvailable, "disponible")
    local empty = makeContext()
    FultonMenu.onFillWorldContextMenu(0, empty, { { getSquare = function() return GROUND end } }, true)
    assertEq(#empty.options, 0, "passe de test : rien")
    assertTrue(player ~= nil, "joueur")
end

function T.queue_walks_to_the_kit_and_takes_the_tank_out_of_a_bag()
    local player, kit, tank = ready({ item("Base.Paperwork") })
    local bag = withId(item("Base.Bag_Schoolbag"))
    bag.inner = container({ tank })
    player.inventory.items = { bag }
    assertEq(FultonMenu.reason(player, kit), nil, "bouteille dans un sac porté : acceptée")
    assertTrue(FultonMenu.queueLaunch(player, kit), "mis en file")
    assertEq(WALKS[1].square, GROUND, "marche jusqu'au kit")
    assertEq(WALKS[1].keep, true, "sans vider la file")
    assertEq(TRANSFERS[1], tank, "bouteille vers l'inventaire principal si besoin")
    assertEq(QUEUE[1].Type, "MilitaryDrop.FultonLaunchAction", "puis le gonflage")
end

function T.confirmation_lists_items_and_warns_without_numbers()
    local player, kit = ready({
        item("Base.Paperwork", {}, "Paperwork"),
        item("Base.Note", {}, "Note"),
    })
    local text = FultonMenu.confirmText(player, kit)
    assertTrue(text:find("IGUI_MilitaryDrop_Fulton_ConfirmPaid\n- Paperwork", 1, true) ~= nil, "objets exploités : " .. text)
    assertTrue(text:find("IGUI_MilitaryDrop_Fulton_ConfirmUnpaid\n- Note", 1, true) ~= nil, "objets ignorés")
    assertTrue(text:find("Cap", 1, true) == nil, "sous le plafond : aucun avertissement")
    FultonClient.onWindow(0, { minutesLeft = 30, dailyLeft = 0 })
    assertTrue(FultonMenu.confirmText(player, kit):find("IGUI_MilitaryDrop_Fulton_ConfirmCapReached", 1, true) ~= nil,
        "plafond atteint : prévenu")
    kit.inner.items = { item("Base.HazmatSuit", { "base:hazmatsuit" }) }
    FultonClient.onWindow(0, { minutesLeft = 30, dailyLeft = 3 })
    text = FultonMenu.confirmText(player, kit)
    assertTrue(text:find("IGUI_MilitaryDrop_Fulton_ConfirmCapPartial", 1, true) ~= nil, "dépassement : prévenu")
    assertTrue(not text:find("%d"), "aucun chiffre affiché : " .. text)
end

function T.long_lists_are_shortened()
    local contents = {}
    for i = 1, 9 do
        contents[i] = item("Base.Paperwork", {}, "Paper " .. i)
    end
    local player, kit = ready(contents)
    local text = FultonMenu.confirmText(player, kit)
    assertTrue(text:find("- Paper 6", 1, true) ~= nil, "six noms")
    assertTrue(text:find("- Paper 7", 1, true) == nil, "pas le septième")
    assertTrue(text:find("IGUI_MilitaryDrop_Fulton_ConfirmMore|3", 1, true) ~= nil, "et 3 de plus")
end

function T.action_faces_the_kit_makes_noise_then_sends_its_square()
    local player, kit, tank = ready({ item("Base.Paperwork") })
    local action = MilitaryDrop.FultonLaunchAction.new(nil, player, kit, tank)
    assertTrue(action:isValid(), "valide à côté du kit")
    action:start()
    assertEq(player.faced, "10,20", "face au kit")
    assertEq(NOISE[1].x .. "," .. NOISE[1].y, "10,20", "bruit du gonflage à la case du kit")
    assertEq(NOISE[1].radius, FultonMenu.NOISE_RADIUS, "rayon du bruit")
    action:perform()
    local args = SENT[1].args
    assertEq(SENT[1].command, "FultonLaunch", "commande au serveur")
    assertEq(args.kitId .. "/" .. args.tankId, kit.id .. "/" .. tank.id, "identifiants")
    assertEq(args.x .. "," .. args.y .. "," .. args.z, "10,20,0", "case du kit")
    player.x = 14.5
    assertTrue(not action:isValid(), "trop loin du kit : action annulée")
    player.x = 11.5
    kit.worldItem = nil
    assertTrue(not action:isValid(), "kit ramassé : action annulée")
end

function T.acknowledgement_comes_through_the_radio_in_hand()
    local player = ready({ item("Base.Paperwork") })
    local radio = { radio = true, military = true,
        getDeviceData = function() return { getIsTurnedOn = function() return true end } end }
    player.hand = radio
    FultonMenu.onResult({ username = "alice", status = "ok", lines = {
        { key = "IGUI_MilitaryDrop_Fulton_Received", params = { "BRAVO", "2" } },
        { key = "IGUI_MilitaryDrop_Fulton_CapReached", params = {} } } })
    assertEq(#RADIO_SAID, 2, "deux lignes par la radio")
    assertEq(RADIO_SAID[1].device, radio, "par le talkie en main")
    assertEq(RADIO_SAID[1].text, "IGUI_MilitaryDrop_Fulton_Received|BRAVO|2", "accusé de réception")
    assertEq(LATER[1] .. "," .. LATER[2], "4000,7500", "mêmes délais qu'une réponse d'échange")
    assertEq(#HALO, 0, "pas de texte flottant")
end

function T.result_shows_base_lines_or_the_refusal()
    local player = ready({ item("Base.Paperwork") })
    FultonMenu.onResult({ username = "alice", status = "ok",
        lines = { { key = "IGUI_MilitaryDrop_Fulton_Received", params = { "BRAVO", "1" } } } })
    assertEq(HALO[1], "IGUI_MilitaryDrop_Fulton_Received|BRAVO|1", "sans radio en main : texte au-dessus du personnage")
    assertEq(FultonClient.window(0), nil, "créneau du client fermé")
    FultonMenu.onResult({ username = "alice", status = "noWindow", reason = "IGUI_MilitaryDrop_Fulton_NoWindow" })
    assertEq(player.said[1], "IGUI_MilitaryDrop_Fulton_NoWindow", "refus dit par le personnage")
    FultonMenu.onResult({ username = "alice", status = "x", reason = "UI_Evil" })
    assertEq(player.said[2], "IGUI_MilitaryDrop_CannotCall", "clé étrangère au mod refusée")
end

function T.handler_is_registered()
    assertEq(MilitaryDrop.Client.HANDLERS.FultonResult, FultonMenu.onResult, "gestionnaire FultonResult")
end

return T
