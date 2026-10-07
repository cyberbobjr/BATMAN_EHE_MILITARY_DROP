-- MilitaryDrop_FultonServer : lâcher d'un kit Fulton POSÉ AU SOL (FULTON-07,
-- décision du 2026-10-07). Le serveur retrouve le kit sur la case désignée, à
-- portée du joueur, revérifie tout, consomme une charge d'hélium, retire le kit
-- du sol pour tous, paie la confiance (plafond, remède hors plafond), ferme le
-- créneau et répond au joueur sans chiffre.

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

--- Conteneur simulé : liste d'objets.
local function container(items)
    local c = { items = items or {} }
    function c.getItems(self) return list(self.items) end
    function c.getItemWithID(self, id)
        for _, it in ipairs(self.items) do
            if it.id == id then
                return it
            end
        end
        return nil
    end
    return c
end

local function makeKit(id, contents)
    local kit = item("MilitaryDrop.FultonKit")
    kit.id = id
    kit.inner = container(contents)
    function kit.getID(self) return self.id end
    function kit.getItemContainer(self) return self.inner end
    return kit
end

local function makeTank(id, uses)
    local tank = item("MilitaryDrop.HeliumTank")
    tank.id, tank.uses = id, uses
    function tank.getID(self) return self.id end
    function tank.getCurrentUses(self) return self.uses end
    function tank.UseAndSync(self) self.uses = self.uses - 1 end
    return tank
end

--- Case du sol (100, 200, 0) : objets au sol, retrait transmis.
local function makeGround()
    local sq = { objects = {}, inside = false, tree = nil }
    function sq.isOutside(self) return not self.inside end
    function sq.getTree(self) return self.tree end
    function sq.getX() return 100 end
    function sq.getY() return 200 end
    function sq.getZ() return 0 end
    function sq.getWorldObjects(self) return list(self.objects) end
    function sq.transmitRemoveItemFromSquare(self, object)
        for i = #self.objects, 1, -1 do
            if self.objects[i] == object then
                table.remove(self.objects, i)
                REMOVED[#REMOVED + 1] = object
            end
        end
    end
    return sq
end

local function putOnGround(kit)
    local object = { kit = kit }
    function object.getItem(self) return self.kit end
    GROUND.objects[#GROUND.objects + 1] = object
    return object
end

local function makePlayer(name)
    local data = { MilitaryDrop_characterId = "C:" .. name }
    local p = { name = name, inventory = container({}), equipped = {}, x = 101.5, y = 201.5, z = 0 }
    function p.getUsername(self) return self.name end
    function p.getModData() return data end
    function p.getDescriptor()
        return { getForename = function() return "Alice" end, getSurname = function() return "Martin" end }
    end
    function p.getInventory(self) return self.inventory end
    function p.isEquipped(self, it) return self.equipped[it] == true end
    function p.isAttachedItem() return false end
    function p.getX(self) return self.x end
    function p.getY(self) return self.y end
    function p.getZ(self) return self.z end
    return p
end

--- Joueur prêt : kit (contenu donné) posé au sol à côté de lui, bouteille à 4
--- charges dans l'inventaire, créneau ouvert.
local function ready(contents)
    local player = makePlayer("alice")
    local kit = makeKit(11, contents)
    local tank = makeTank(12, 4)
    putOnGround(kit)
    player.inventory.items = { tank }
    WINDOWS["C:alice"] = { deadline = 2000 }
    return player, kit, tank
end

local function launch(player, kit, tank, x, y)
    NOW_MS = NOW_MS + 5000
    return FultonServer.launch(player, { kitId = kit and kit.id, tankId = tank and tank.id,
        x = x or 100, y = y or 200, z = 0 })
end

local function lastResult()
    return RESULTS[#RESULTS]
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return true end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    ItemTag = { APPLY_OWNER_NAME = "base:applyownername", IDCARD = "base:idcard", HAZMAT_SUIT = "base:hazmatsuit",
        SCBA = "base:scba", GAS_MASK = "base:gasmask", GASMASK_FILTER = "base:gasmaskfilter" }
    ACTIVE_MODS = { "ZVirusVaccine42BETA" }
    getActivatedMods = function() return list(ACTIVE_MODS) end
    STATE, WINDOWS, RESULTS, REMOVED, POST, LAUNCHED = {}, {}, {}, {}, {}, {}
    WORLD_HOURS, CLOCK, NOW_MS = 1000, 24 * 100 + 12, 0
    getGameTime = function() return { getWorldAgeHours = function() return WORLD_HOURS end } end
    getTimestampMs = function() return NOW_MS end
    ZombRand = function() return 0 end
    WIND, STORM = 10, false
    getClimateManager = function()
        return { getIsThunderStorming = function() return STORM end, getWindspeedKph = function() return WIND end }
    end
    GROUND = makeGround()
    getCell = function()
        return { getGridSquare = function(_, x, y, z)
            if x == 100 and y == 200 and z == 0 then
                return GROUND
            end
            return nil
        end }
    end
    FACTIONS = {}
    Faction = { getFactions = function() return list(FACTIONS) end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    MilitaryDrop.Secrets = { privateState = function() return STATE end }
    MilitaryDrop.Server = { COMMANDS = {}, clock = function() return CLOCK end, getState = function() return {} end }
    MilitaryDrop.Net = { toPlayer = function(player, command, args)
        RESULTS[#RESULTS + 1] = { player = player, command = command, args = args }
    end }
    MilitaryDrop.Exchange = { line = function(key, ...) return { key = key, params = { ... } } end }
    MilitaryDrop.Missions = {
        fultonWindow = function(id) return WINDOWS[id] end,
        closeFultonWindow = function(id) WINDOWS[id] = nil end,
    }
    PROTECTED = false
    MilitaryDrop.ZonesFile = {
        overlapsNonPvp = function() return PROTECTED end,
        overlapsSafehouse = function() return false end,
    }
    MilitaryDrop.Post = { record = function(teamId, line) POST[#POST + 1] = { teamId = teamId, line = line } end }
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Teams.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Fulton.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_FultonServer.lua")
    FultonServer = MilitaryDrop.FultonServer
    Trust = MilitaryDrop.Trust
    DEFAULT_ON_LAUNCHED = FultonServer.onLaunched
    FultonServer.onLaunched = function(player, x, y, z) LAUNCHED[#LAUNCHED + 1] = { player = player, x = x, y = y, z = z } end
end

function T.nominal_launch_pays_consumes_removes_and_answers_without_numbers()
    local player, kit, tank = ready({
        item("Base.IDcard", { "base:idcard", "base:applyownername" }, "ID Card: John Smith"), -- 3
        item("Base.Hat_GasMask", { "base:gasmask" }),                                         -- 2
        item("Base.Note"),
    })
    assertEq(launch(player, kit, tank), "ok", "lâcher accepté")
    assertEq(tank.uses, 3, "une charge d'hélium")
    assertEq(#GROUND.objects, 0, "kit retiré du sol")
    assertEq(REMOVED[1].kit, kit, "retrait transmis à tous (transmitRemoveItemFromSquare)")
    assertEq(#player.inventory.items, 1, "bouteille gardée")
    assertEq(Trust.get("C:alice"), 30, "+5 plafonnés")
    assertEq(WINDOWS["C:alice"], nil, "créneau fermé")
    local result = lastResult()
    assertEq(result.command, "FultonResult", "réponse au joueur")
    assertEq(result.args.status, "ok", "statut")
    assertEq(result.args.lines[1].key, "IGUI_MilitaryDrop_Fulton_Received", "accusé de réception")
    assertEq(result.args.lines[1].params[2], "2", "nombre d'objets exploités, pas de points")
    assertEq(#result.args.lines, 1, "ni plafond ni remède")
    assertEq(#POST, 1, "noté au journal du poste")
    assertEq(LAUNCHED[1].x .. "," .. LAUNCHED[1].y .. "," .. LAUNCHED[1].z, "100,200,0", "vol depuis la case du kit")
end

function T.cure_is_uncapped_and_cap_overflow_is_announced()
    Trust.add("C:alice", 8, "report")
    local player, kit, tank = ready({
        item("Base.HazmatSuit", { "base:hazmatsuit", "base:scba" }), -- 6
        item("LabItems.CmpSyringeWithCure"),                         -- 25 hors plafond
    })
    assertEq(launch(player, kit, tank), "ok", "lâcher accepté")
    assertEq(Trust.get("C:alice"), 25 + 8 + 2 + 25, "2 sous le plafond, remède entier")
    local keys = {}
    for _, line in ipairs(lastResult().args.lines) do
        keys[#keys + 1] = line.key
    end
    assertEq(table.concat(keys, " "),
        "IGUI_MilitaryDrop_Fulton_Received IGUI_MilitaryDrop_Fulton_Cure IGUI_MilitaryDrop_Fulton_CapReached",
        "remède et plafond annoncés en mots")
end

function T.worthless_kit_still_flies_and_says_so()
    local player, kit, tank = ready({ item("Base.Note") })
    assertEq(launch(player, kit, tank), "ok", "lâcher accepté")
    assertEq(lastResult().args.lines[1].key, "IGUI_MilitaryDrop_Fulton_ReceivedNothing", "rien d'exploitable")
    assertEq(Trust.get("C:alice"), 25, "aucun gain")
    assertEq(tank.uses, 3, "hélium consommé quand même")
end

--- Le refus ne touche à rien : kit au sol, hélium, confiance, vol.
local function assertUntouched(tank, message, uses)
    assertEq(tank.uses, uses or 4, message .. " : hélium intact")
    assertEq(#GROUND.objects, 1, message .. " : kit toujours au sol")
    assertEq(#REMOVED, 0, message .. " : rien retiré")
    assertEq(Trust.get("C:alice"), 25, message .. " : confiance inchangée")
    assertEq(#LAUNCHED, 0, message .. " : pas de vol")
end

function T.refusals_change_nothing()
    local cases = {
        { "noKit", function(_, kit) kit.id = 99 end },
        { "noKit", function(p) p.x = 104.5 end },
        { "noKit", function(p) p.z = 1 end },
        { "noHelium", function(_, _, tank) tank.uses = 0 end, nil, 0 },
        { "noWindow", function() WINDOWS["C:alice"] = nil end },
        { "disabled", function() SandboxVars.MilitaryDrop.FultonValue = 0 end },
        { "site", function() GROUND.inside = true end, "IGUI_MilitaryDrop_Fulton_NotOutside" },
        { "site", function() GROUND.tree = {} end, "IGUI_MilitaryDrop_Fulton_Tree" },
        { "site", function() STORM = true end, "IGUI_MilitaryDrop_Fulton_Storm" },
        { "site", function() WIND = 61 end, "IGUI_MilitaryDrop_Fulton_Wind" },
        { "protected", function() PROTECTED = true end },
        { "emptyKit", function(_, kit) kit.inner.items = {} end },
    }
    for n, case in ipairs(cases) do
        T.setup()
        local player, kit, tank = ready({ item("Base.Paperwork") })
        case[2](player, kit, tank)
        local kitId = kit.id
        kit.id = 11
        NOW_MS = NOW_MS + 5000
        assertEq(FultonServer.launch(player, { kitId = kitId, tankId = tank.id, x = 100, y = 200, z = 0 }),
            case[1], "cas " .. n)
        if case[3] then
            assertEq(lastResult().args.reason, case[3], "cas " .. n .. " : motif")
        end
        assertEq(lastResult().args.status, case[1], "cas " .. n .. " : statut transmis")
        assertUntouched(tank, "cas " .. n, case[4])
    end
end

function T.forged_coordinates_are_refused()
    local player, kit, tank = ready({ item("Base.Paperwork") })
    assertEq(launch(player, kit, tank, 300, 200), "noKit", "case désignée hors de portée")
    NOW_MS = NOW_MS + 5000
    assertEq(FultonServer.launch(player, { kitId = kit.id, tankId = tank.id }), "noKit", "sans coordonnées")
    assertEq(#GROUND.objects, 1, "kit intact")
end

function T.line_cut_refuses()
    local player, kit, tank = ready({ item("Base.Paperwork") })
    Trust.add("C:alice", -15, "drop")
    assertEq(launch(player, kit, tank), "lineCut", "ligne coupée")
    assertEq(tank.uses, 4, "hélium intact")
end

function T.tank_in_a_bag_is_refused_by_the_server()
    local player, kit, tank = ready({ item("Base.Paperwork") })
    player.inventory.items = {}
    assertEq(launch(player, kit, tank), "noHelium", "le client doit d'abord la sortir du sac")
    assertEq(#GROUND.objects, 1, "kit intact")
end

function T.rapid_second_launch_is_throttled()
    local player, kit, tank = ready({ item("Base.Paperwork") })
    assertEq(launch(player, kit, tank), "ok", "premier lâcher")
    NOW_MS = NOW_MS + 1000
    putOnGround(makeKit(13, { item("Base.Paperwork") }))
    WINDOWS["C:alice"] = { deadline = 2000 }
    assertEq(FultonServer.launch(player, { kitId = 13, tankId = 12, x = 100, y = 200, z = 0 }), "busy",
        "moins de 3 s après")
end

function T.solo_launch_also_removes_the_kit()
    isServer = function() return false end
    local player, kit, tank = ready({ item("Base.Paperwork") })
    assertEq(launch(player, kit, tank), "ok", "solo")
    assertEq(#GROUND.objects, 0, "kit retiré du sol")
end

function T.default_hook_starts_the_flight_noise_and_announcement()
    local calls = {}
    MilitaryDrop.FultonPrototypeServer = {
        startFlight = function(x, y, z) calls[#calls + 1] = "mp " .. x .. "," .. y .. "," .. z end,
    }
    MilitaryDrop.FultonPrototype = { startAt = function(x, y, z) calls[#calls + 1] = "solo " .. x .. "," .. y .. "," .. z end }
    MilitaryDrop.Broadcast = { fulton = function(x, y) calls[#calls + 1] = "broadcast " .. x .. "," .. y end }
    getWorldSoundManager = function()
        return { addSound = function(_, source, x, y, z, radius, volume)
            calls[#calls + 1] = "noise " .. tostring(source) .. " " .. radius .. "/" .. volume
        end }
    end
    DEFAULT_ON_LAUNCHED(nil, 100, 200, 0)
    assertEq(table.concat(calls, " | "), "mp 100.5,200.5,0 | noise nil 40/40 | broadcast 100,200",
        "serveur MP : vol à tous les clients, bruit, annonce")
    calls = {}
    isServer = function() return false end
    DEFAULT_ON_LAUNCHED(nil, 100, 200, 0)
    assertEq(calls[1], "solo 100.5,200.5,0", "solo : vol local")
end

function T.command_is_registered()
    assertTrue(MilitaryDrop.Server.COMMANDS.FultonLaunch ~= nil, "commande FultonLaunch")
end

return T
