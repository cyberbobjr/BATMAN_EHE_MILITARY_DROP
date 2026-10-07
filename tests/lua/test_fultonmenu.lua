-- MilitaryDrop_FultonMenu : menu du kit (motifs de grisé), confirmation sans
-- chiffre, file d'actions (mains, sacs), action de gonflage qui envoie
-- FultonLaunch, résultat du serveur (accusé en texte, refus dit par le joueur).

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
    function c.getItemWithIDRecursiv(self, id)
        for _, x in ipairs(self.items) do
            if x.id == id then
                return x
            end
            if x.inner then
                local found = x.inner:getItemWithIDRecursiv(id)
                if found then
                    return found
                end
            end
        end
        return nil
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

local function makePlayer()
    local p = { inventory = container({}), equipped = {}, said = {}, outside = true }
    function p.getPlayerNum() return 0 end
    function p.getUsername() return "alice" end
    function p.getInventory(self) return self.inventory end
    function p.isEquipped(self, it) return self.equipped[it] == true end
    function p.getDescriptor()
        return { getForename = function() return "Alice" end, getSurname = function() return "Martin" end }
    end
    function p.getCurrentSquare(self)
        local outside = self.outside
        return { isOutside = function() return outside end, getTree = function() return nil end,
            getX = function() return 1 end, getY = function() return 2 end, getZ = function() return 0 end }
    end
    function p.Say(self, text) self.said[#self.said + 1] = text end
    function p.SetVariable() end
    return p
end

--- Joueur prêt : kit au contenu donné et bouteille dans l'inventaire, créneau ouvert.
local function ready(contents)
    local player = makePlayer()
    local kit, tank = makeKit(contents), makeTank(4)
    player.inventory.items = { kit, tank }
    PLAYER = player
    FultonClient.onWindow(0, { minutesLeft = 30, dailyLeft = 10 })
    return player, kit, tank
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return true end
    isServer = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
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
    QUEUE, SENT, HALO, NOISE, TRANSFERS = {}, {}, {}, {}, {}
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
    ISUnequipAction = { new = function(_, character, it) return { unequip = it } end }
    ISInventoryPaneContextMenu = { transferIfNeeded = function(_, it) TRANSFERS[#TRANSFERS + 1] = it end }
    addSound = function(source, x, y, z, radius, volume) NOISE[#NOISE + 1] = { radius = radius, volume = volume } end
    HaloTextHelper = { addText = function(_, text) HALO[#HALO + 1] = text end }
    getSpecificPlayer = function() return PLAYER end
    getNumActivePlayers = function() return 1 end
    local noop = { Add = function() end, Remove = function() end }
    Events = setmetatable({}, { __index = function() return noop end })
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    MilitaryDrop.Net = { toServer = function(player, command, args)
        SENT[#SENT + 1] = { player = player, command = command, args = args }
    end }
    MilitaryDrop.Exchange = { lineText = function(line) return line.key .. "|" .. table.concat(line.params or {}, "|") end }
    MilitaryDrop.Client = { HANDLERS = {} }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Fulton.lua")
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonClient.lua")
    FultonClient = MilitaryDrop.FultonClient
    loadMod("client/MilitaryDrop/MilitaryDrop_FultonMenu.lua")
    FultonMenu = MilitaryDrop.FultonMenu
end

function T.reasons_follow_the_launch_conditions()
    local player, kit, tank = ready({ item("Base.Paperwork") })
    assertEq(FultonMenu.reason(player, kit), nil, "tout est prêt")
    player.outside = false
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_NotOutside", "à l'intérieur")
    player.outside = true
    tank.uses = 0
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_NoHelium", "bouteille vide")
    tank.uses = 4
    kit.inner.items = {}
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_EmptyKit", "kit vide")
    kit.inner.items = { item("Base.Paperwork") }
    FultonClient.reset()
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_NoWindow", "pas de créneau")
    FultonClient.onWindow(0, { minutesLeft = 30, dailyLeft = 10 })
    player.inventory.items = { tank }
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_Fulton_NoKit", "kit hors de l'inventaire")
    SandboxVars.MilitaryDrop.FultonValue = 0
    assertEq(FultonMenu.reason(player, kit), "IGUI_MilitaryDrop_SourceDisabled", "Fulton désactivé")
end

function T.tank_in_a_bag_is_accepted_and_moved_before_the_launch()
    local player = makePlayer()
    PLAYER = player
    local kit, tank = makeKit({ item("Base.Paperwork") }), makeTank(4)
    local bag = withId(item("Base.Bag_Schoolbag"))
    bag.inner = container({ tank })
    player.inventory.items = { kit, bag }
    player.equipped[kit] = true
    FultonClient.onWindow(0, { minutesLeft = 30, dailyLeft = 10 })
    assertEq(FultonMenu.reason(player, kit), nil, "bouteille dans un sac porté : acceptée")
    assertTrue(FultonMenu.queueLaunch(player, kit), "mis en file")
    assertEq(QUEUE[1].unequip, kit, "kit retiré des mains d'abord")
    assertEq(TRANSFERS[1], kit, "kit vers l'inventaire principal si besoin")
    assertEq(TRANSFERS[2], tank, "bouteille aussi")
    assertEq(QUEUE[2].Type, "MilitaryDrop.FultonLaunchAction", "puis le gonflage")
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

function T.action_makes_noise_then_sends_the_launch()
    local player, kit, tank = ready({ item("Base.Paperwork") })
    local action = MilitaryDrop.FultonLaunchAction.new(nil, player, kit, tank)
    assertTrue(action:isValid(), "valide")
    action:start()
    assertEq(NOISE[1].radius, FultonMenu.NOISE_RADIUS, "bruit du gonflage pour les zombies")
    action:perform()
    assertEq(SENT[1].command, "FultonLaunch", "commande au serveur")
    assertEq(SENT[1].args.kitId, kit.id, "identifiant du kit")
    assertEq(SENT[1].args.tankId, tank.id, "identifiant de la bouteille")
    player.outside = false
    assertTrue(not action:isValid(), "rentré à l'intérieur : action annulée")
end

function T.result_shows_base_lines_or_the_refusal()
    local player = ready({ item("Base.Paperwork") })
    FultonMenu.onResult({ username = "alice", status = "ok",
        lines = { { key = "IGUI_MilitaryDrop_Fulton_Received", params = { "BRAVO", "1" } } } })
    assertEq(HALO[1], "IGUI_MilitaryDrop_Fulton_Received|BRAVO|1", "accusé de réception au-dessus du personnage")
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
