-- MilitaryDrop_Requisition : formulaire de réquisition côté serveur (v1.4) —
-- budget et paliers, réponse « form », autorisation en attente, revalidation
-- complète de la commande, leurre exclusif, secteurs, contenu du coffre et du
-- repli au sol, secret de la commande (ni ModData publique, ni message à tous).

local T = {}

-- Carte simulée : par défaut, une route couvre toute la carte (le point tiré
-- est donc retenu tel quel). ROADS (liste { x, y, w, h }) remplace ce réseau ;
-- les bâtiments : aucun.
local function stubList(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end
function TEST_ZONES(x, y, w, h)
    local roads = ROADS or { { x = 0, y = 0, w = 100000, h = 100000 } }
    local found = {}
    for _, r in ipairs(roads) do
        if r.x < x + w and x < r.x + r.w and r.y < y + h and y < r.y + r.h then
            found[#found + 1] = {
                getType = function() return "Nav" end, isRectangle = function() return true end,
                getX = function() return r.x end, getY = function() return r.y end,
                getWidth = function() return r.w end, getHeight = function() return r.h end,
            }
        end
    end
    return stubList(found)
end

local CHANNEL = 151400
local CODE = "BRAVO-KILO-07"

-- ----------------------------------------------------------------------------
-- Objets et tables de butin simulés (un objet par lot)
-- ----------------------------------------------------------------------------

local ITEMS = {
    ["Base.TinnedBeans"] = { cat = "Food" },
    ["Base.WaterBottle"] = { cat = "Water", fluid = 1 },
    ["Base.Bandage"] = { cat = "Bandage" },
    ["Base.Hammer"] = { cat = "Tool" },
    ["Base.Plank"] = { cat = "Material" },
    ["Base.Matches"] = { cat = "FireSource" },
    ["Base.Bullets9mmBox"] = { cat = "Ammo" },
    ["Base.Machete"] = { cat = "Weapon", itemType = "Weapon", damage = 2 },
    ["Base.Hat_Helmet"] = { cat = "ProtectiveGear", itemType = "Clothing" },
    ["Base.CarBattery"] = { cat = "VehicleMaintenance" },
    ["Base.WalkieTalkie"] = { cat = "Communications" },
    ["Base.Seeds"] = { cat = "Gardening" },
    ["Base.BookAiming1"] = { cat = "SkillBook" },
    ["Base.Bag_ALICE"] = { cat = "Bag", itemType = "Container" },
    ["Base.Pistol"] = { cat = "Weapon", itemType = "Weapon", ranged = true, damage = 1, ammoBox = "Base.Bullets9mmBox" },
    ["Base.RedDot"] = { cat = "WeaponPart", itemType = "WeaponPart" },
    ["Base.PipeBomb"] = { cat = "Explosives" },
    ["Base.PetrolCan"] = { cat = "VehicleMaintenance", fluid = 10, petrol = true },
}

local function list(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end

local function makeScript(fullType)
    local data = ITEMS[fullType]
    return {
        getItemType = function() return data.itemType or "Normal" end,
        getFullName = function() return fullType end,
        isRanged = function() return data.ranged == true end,
        getMaxDamage = function() return data.damage or 0 end,
        getDisplayCategory = function() return data.cat end,
        getActualWeight = function() return 1 end,
        getDaysTotallyRotten = function() return 1000000000 end,
        hasTag = function(_, tag) return tag == "Petrol" and data.petrol == true end,
    }
end

local function makeWorldItem(name)
    local item = { fullType = name, modData = {} }
    function item.getModData(self) return self.modData end
    function item.setName(self, text) self.name = text end
    function item.setCustomName(self, value) self.customName = value end
    return item
end

local function setupLoot()
    ItemType = { CONTAINER = "Container", WEAPON = "Weapon", WEAPON_PART = "WeaponPart", CLOTHING = "Clothing" }
    Fluid = { Water = "Water", Petrol = "Petrol" }
    ItemTag = { PETROL = "Petrol", get = function(location) return location == "base:petrol" and "Petrol" or nil end }
    ResourceLocation = { of = function(id) return string.lower(id) end }
    INSTANCED = 0
    instanceItem = function(fullType)
        local data = ITEMS[fullType]
        if not data then
            -- Objets du mod (caisses de réquisition, balise) : repli au sol.
            return string.find(fullType, "MilitaryDrop.", 1, true) == 1 and makeWorldItem(fullType) or nil
        end
        INSTANCED = INSTANCED + 1
        local item = { fullType = fullType, kind = data.itemType == "Weapon" and "HandWeapon" or
            (data.itemType == "Clothing" and "Clothing" or "InventoryItem") }
        item.getMagazineType = function() return nil end
        item.getAmmoBox = function() return data.ammoBox end
        item.getBulletDefense = function() return 0 end
        item.hasTag = function(_, tag) return tag == "Petrol" and data.petrol == true end
        local fc = data.fluid and { capacity = data.fluid } or nil
        if fc then
            function fc.getCapacity(self) return self.capacity end
            function fc.Empty() end
            function fc.canAddFluid() return true end
            function fc.addFluid() end
        end
        item.getFluidContainer = function() return fc end
        return item
    end
    getScriptManager = function()
        return {
            FindItem = function(_, name)
                local fullType = string.find(name, ".", 1, true) and name or ("Base." .. name)
                return ITEMS[fullType] and makeScript(fullType) or nil
            end,
            getItemsByType = function() return list({}) end,
            getAllItems = function()
                local all = {}
                for fullType in pairs(ITEMS) do
                    all[#all + 1] = makeScript(fullType)
                end
                return list(all)
            end,
        }
    end
    local flat = {}
    for fullType in pairs(ITEMS) do
        flat[#flat + 1] = fullType:match("%.(.+)$")
        flat[#flat + 1] = 1
    end
    ProceduralDistributions = { list = { Everything = { items = flat } } }
end

-- ----------------------------------------------------------------------------
-- Jeu simulé (comme test_server.lua)
-- ----------------------------------------------------------------------------

local function makeRadio(on, channel)
    local data = {
        getIsHighTier = function() return true end,
        getIsPortable = function() return true end,
        getIsTurnedOn = function() return on end,
        getChannel = function() return channel end,
    }
    return {
        kind = "Radio",
        getID = function() return 7 end,
        getDeviceData = function() return data end,
        getContainer = function() return nil end,
    }
end

local function makePlayer(radio, name)
    local player = {
        getUsername = function() return name or "tester" end,
        getX = function() return 100.5 end,
        getY = function() return 200.5 end,
        getPrimaryHandItem = function() return radio end,
        getSecondaryHandItem = function() return nil end,
        getClothingItem_Back = function() return nil end,
    }
    function player.getModData(self)
        self.characterData = self.characterData or { MilitaryDrop_characterId = "C:" .. self:getUsername() }
        return self.characterData
    end
    function player.getDescriptor() return nil end
    return player
end

function T.setup()
    SandboxVars = { MilitaryDrop = { CooldownHours = 168, AuthCode = 2, Frequency = 151.4,
        MinZombies = 0, MaxZombies = 0, CaseRolls = 2, DecoyEnabled = true, DecoyCost = 3 } }
    isClient = function() return false end
    isServer = function() return false end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    Capability = { MakeEventsAlarmGunshot = "MakeEventsAlarmGunshot" }
    checkPermissions = function() return true end
    MODDATA = {}
    ModData = { getOrCreate = function(tag)
        MODDATA[tag] = MODDATA[tag] or {}
        return MODDATA[tag]
    end }
    ZombRand = function() return 0 end
    ZombRandFloat = function(low) return low end
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
    WORLD_HOURS = 1000
    getGameTime = function()
        return {
            getWorldAgeHours = function() return WORLD_HOURS end,
            getYear = function() return 1993 end,
            getMonth = function() return 6 end,
            getDay = function() return 13 end,
            getTimeOfDay = function() return 12 end,
        }
    end
    PLACED_ITEMS = {}
    LANDING = {
        getX = function() return 115 end, getY = function() return 200 end,
        isOutside = function() return true end, isFree = function() return true end,
        isWaterSquare = function() return false end,
        getVehicleContainer = function() return nil end,
        AddWorldInventoryItem = function(_, item, _, _, _, transmit)
            assert(type(item) == "table" and transmit == true, "objet déjà créé, transmis à la pose")
            -- Marqué avant la pose : la pose le transmet aux clients.
            item.placedName = item.name
            PLACED_ITEMS[#PLACED_ITEMS + 1] = item
            return item
        end,
    }
    getCell = function() return { getGridSquare = function() return LANDING end } end
    spawnHorde = function() end
    addSound = function() end
    getText = function(key, a) return a and (key .. "(" .. tostring(a) .. ")") or key end
    FILES = { ["MilitaryDrop/Sandbox_Test_Save_code.txt"] = CODE }
    getWorld = function()
        return {
            getGameMode = function() return "Sandbox" end,
            getWorld = function() return "Test Save" end,
            getMetaGrid = function()
                return {
                    isValidSquare = function(_, x, y) return not (OFF_MAP and OFF_MAP(x, y)) end,
                    getCellData = function() return { getBuildingsIntersecting = function() end } end,
                    getBuildingAt = function() return nil end,
                    getZonesIntersecting = function(_, x, y, _z, w, h) return TEST_ZONES(x, y, w, h) end,
                }
            end,
        }
    end
    -- Lecture ligne à ligne (BufferedReader.readLine : nil à la fin).
    getFileReader = function(name)
        local value = FILES[name]
        if not value then
            return nil
        end
        local lines = {}
        for line in string.gmatch(value .. "\n", "([^\n]*)\n") do
            lines[#lines + 1] = line
        end
        local index = 0
        return { readLine = function() index = index + 1 return lines[index] end, close = function() end }
    end
    getFileWriter = function(name)
        return { write = function(_, text) FILES[name] = text end, close = function() end }
    end
    getActivatedMods = function() return { size = function() return 0 end } end
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function() return PLAYER end
    VehicleDistributions = { {} }
    IsoDirections = { getRandom = function() return "N" end }
    addVehicleDebug = function() return nil end
    setupLoot()
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Net.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Radio.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Loot.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Lots.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Flight.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Crate.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Guard.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Smoke.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Server.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Teams.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Broadcast.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Flights.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_LotsFile.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Requisition.lua")
    -- Module leurre (agent C) simulé : contrat seulement.
    DELIVERED = {}
    MilitaryDrop.Decoy = {
        trunkContents = function() return { { fullType = "MilitaryDrop.DecoyBeacon", name = "DIVERSION" } } end,
        onDelivered = function(dropId, x, y, z, vehicle)
            DELIVERED[#DELIVERED + 1] = { dropId = dropId, x = x, y = y, z = z, vehicle = vehicle }
        end,
    }
    -- Réponses privées et messages à tous, séparés.
    SENT, BROADCAST = {}, {}
    MilitaryDrop.Client = { onServerCommand = function() end }
    MilitaryDrop.Net.toPlayer = function(_, command, args) SENT[#SENT + 1] = { command = command, args = args } end
    MilitaryDrop.Net.toAll = function(command, args) BROADCAST[#BROADCAST + 1] = { command = command, args = args } end
    PLAYER = makePlayer(makeRadio(true, CHANNEL))
end

local function call(player)
    MilitaryDrop.Server.handleRequest(player or PLAYER, { requestId = 1, radio = { kind = "item", id = 7 }, code = CODE })
    return SENT[#SENT].args
end

local function order(lots, decoy, player, requestId, sector)
    NOW_MS = NOW_MS + 5000
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", "RequisitionOrder", player or PLAYER,
        { requestId = requestId or 1, radio = { kind = "item", id = 7 }, order = lots, decoy = decoy, sector = sector })
    return SENT[#SENT].args
end

local function flights()
    return MilitaryDrop.Server.getState().flights or {}
end

local function setNote(value)
    local team = MilitaryDrop.Trust.idFor(PLAYER)
    MilitaryDrop.Trust.add(team, value - MilitaryDrop.Trust.get(team), "drop")
end

local function fly()
    local flight = flights()[1]
    for _ = 1, math.ceil((MilitaryDrop.Flight.dropTime(flight) + 0.5) / 0.25) do
        MilitaryDrop.Flights.advance(flight, 0.25)
    end
end

--- Toutes les clés et valeurs d'une table, à plat.
local function flatten(t, out)
    out = out or {}
    for k, v in pairs(t) do
        out[#out + 1] = tostring(k)
        if type(v) == "table" then
            flatten(v, out)
        else
            out[#out + 1] = tostring(v)
        end
    end
    return out
end

-- ----------------------------------------------------------------------------
-- Budget, paliers, coûts
-- ----------------------------------------------------------------------------

function T.budget_follows_trust_and_option()
    local R = MilitaryDrop.Requisition
    assertEq(R.budget(25), 8, "note 25")
    assertEq(R.budget(50), 12, "note 50")
    assertEq(R.budget(75), 16, "note 75")
    assertEq(R.budget(100), 20, "note 100")
    SandboxVars.MilitaryDrop.RequisitionBudget = 50
    assertEq(R.budget(50), 6, "option RequisitionBudget")
end

function T.costs_and_tiers_follow_options()
    local R = MilitaryDrop.Requisition
    SandboxVars.MilitaryDrop.RequisitionCostMultiplier = 150
    assertEq(R.cost(5), 8, "5 × 1,5 arrondi")
    SandboxVars.MilitaryDrop.RequisitionCostMultiplier = 10
    assertEq(R.cost(2), 1, "au moins 1 point")
    assertEq(R.maxGroup(49), 1, "sous 50 : groupe 1")
    assertEq(R.maxGroup(50), 2, "dès 50 : groupe 2")
    assertEq(R.maxGroup(75), 3, "dès 75 : groupe 3")
    SandboxVars.MilitaryDrop.RequisitionTier2 = 20
    assertEq(R.maxGroup(20), 2, "option RequisitionTier2")
end

-- ----------------------------------------------------------------------------
-- Réponse « form »
-- ----------------------------------------------------------------------------

function T.accepted_call_opens_the_form_without_launching()
    local reply = call()
    assertEq(reply.status, "form", "formulaire")
    assertEq(reply.requestId, 1, "même requestId")
    assertEq(reply.budget, 8, "budget à la note de départ 25")
    assertEq(reply.tier, 2, "palier des répliques")
    assertEq(reply.callsign, MilitaryDrop.Teams.callsign(MilitaryDrop.Teams.idFor(PLAYER)), "indicatif")
    assertEq(reply.expiresMs, 300000, "5 minutes réelles")
    assertEq(#reply.lots, 18, "18 lots")
    assertEq(reply.lots[1].id, "rations", "ordre d'affichage")
    assertEq(reply.lots[1].label, "IGUI_MilitaryDrop_Lot_rations", "clé du libellé")
    assertEq(reply.lots[1].desc, "IGUI_MilitaryDrop_LotDesc_rations", "clé de la description")
    assertEq(reply.lots[1].allowed, true, "palier I permis")
    for _, lot in ipairs(reply.lots) do
        if lot.group == 3 then
            assertEq(lot.allowed, false, lot.id .. " refusé à 25")
            assertEq(lot.reason, "tier", "motif palier")
        end
    end
    assertEq(reply.decoy.cost, 3, "leurre : coût DecoyCost")
    assertEq(table.concat(reply.decoy.sectors, ","), "N,E,S,W", "secteurs")
    assertEq(#flights(), 0, "pas d'hélicoptère")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, nil, "délai global non consommé")
    assertEq(#BROADCAST, 0, "rien envoyé à tous")
end

function T.new_team_has_only_tier_one()
    assertEq(MilitaryDrop.Trust.get(MilitaryDrop.Trust.idFor(PLAYER)), MilitaryDrop.Trust.START, "équipe neuve")
    assertEq(MilitaryDrop.Trust.START, 25, "confiance de départ : 25")
    for _, lot in ipairs(call().lots) do
        if lot.group == 1 then
            assertEq(lot.allowed, true, lot.id .. " : palier I permis")
        else
            assertEq(lot.allowed, false, lot.id .. " : palier " .. lot.group .. " fermé à 25")
            assertEq(lot.reason, "tier", lot.id .. " : motif palier")
        end
    end
    setNote(50)
    NOW_MS = NOW_MS + 5000
    for _, lot in ipairs(call().lots) do
        if lot.group == 2 then
            assertEq(lot.allowed, true, lot.id .. " : palier II ouvert à 50")
        elseif lot.group == 3 then
            assertEq(lot.allowed, false, lot.id .. " : palier III encore fermé à 50")
        end
    end
end

function T.form_marks_empty_and_disabled_lots()
    setNote(80)
    ProceduralDistributions.list.Everything.items = { "Hammer", 1, "PipeBomb", 1 }
    SandboxVars.MilitaryDrop.RequisitionExplosives = false
    local reasons = {}
    for _, lot in ipairs(call().lots) do
        reasons[lot.id] = tostring(lot.reason)
    end
    assertEq(reasons.tools, "nil", "outils permis")
    assertEq(reasons.seeds, "empty", "aucune semence dans les tables")
    assertEq(reasons.explosives, "disabled", "explosifs désactivés")
end

function T.decoy_is_absent_when_disabled()
    SandboxVars.MilitaryDrop.DecoyEnabled = false
    assertEq(call().decoy, nil, "v1.5 désactivée")
end

function T.form_option_off_keeps_random_cases()
    SandboxVars.MilitaryDrop.RequisitionForm = false
    assertEq(call().status, "accepted", "appel accepté directement")
    assertEq(#flights(), 1, "vol lancé")
    fly()
    assertEq(#PLACED_ITEMS, 2, "CaseRolls caisses aléatoires")
    assertTrue(PLACED_ITEMS[1].fullType ~= "MilitaryDrop.RequisitionCase", "caisses de ravitaillement")
end

-- ----------------------------------------------------------------------------
-- Largage forcé de l'admin : feuille « admin »
-- ----------------------------------------------------------------------------

local function forceCall(player)
    NOW_MS = NOW_MS + 5000
    MilitaryDrop.Server.handleRequest(player or PLAYER, { requestId = 2, force = true })
    return SENT[#SENT].args
end

function T.admin_drop_opens_the_admin_form_with_every_lot_and_the_max_budget()
    -- Radio éteinte, délai en cours, confiance basse : rien de cela ne compte.
    PLAYER = makePlayer(makeRadio(false, CHANNEL))
    MilitaryDrop.Server.getState().lastDropHours = WORLD_HOURS
    setNote(30)
    local reply = forceCall()
    assertEq(reply.status, "form", "la feuille s'ouvre")
    assertEq(reply.forced, true, "feuille marquée admin")
    assertEq(reply.budget, MilitaryDrop.Requisition.budget(MilitaryDrop.Trust.MAX), "budget d'une confiance 100")
    assertEq(reply.budget, 20, "20 points")
    for _, lot in ipairs(reply.lots) do
        assertTrue(lot.reason ~= "tier", lot.id .. " : aucun palier fermé")
    end
    local allowed = {}
    for _, lot in ipairs(reply.lots) do
        allowed[lot.id] = lot.allowed
    end
    assertEq(allowed.firearms, true, "palier III permis")
    assertEq(allowed.ammo, true, "palier II permis")
    assertEq(reply.decoy and reply.decoy.allowed, true, "leurre compris")
    assertEq(#flights(), 0, "pas encore d'hélicoptère")
    assertEq(MilitaryDrop.Requisition.pendingFor("tester").forced, true, "autorisation marquée forcée")
    -- Feuille d'un appel ordinaire : rien de marqué.
    PLAYER = makePlayer(makeRadio(true, CHANNEL))
    MilitaryDrop.Server.getState().lastDropHours = nil
    setNote(50)
    NOW_MS = NOW_MS + 5000
    local normal = call()
    assertEq(normal.status, "form", "appel ordinaire")
    assertEq(normal.forced, nil, "pas de marque admin")
    assertEq(MilitaryDrop.Requisition.pendingFor("tester").forced, nil, "autorisation ordinaire")
end

function T.admin_order_launches_a_forced_drop_without_cooldown_or_trust()
    PLAYER = makePlayer(nil)
    setNote(10)
    MilitaryDrop.Server.getState().lastDropHours = WORLD_HOURS - 1
    forceCall()
    local reply = order({ firearms = 2, ammo = 3, rations = 4 }, nil, PLAYER, 2)
    assertEq(reply.status, "accepted", "sans radio, ligne coupée, délai en cours : accepté")
    assertEq(#flights(), 1, "vol lancé")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, WORLD_HOURS - 1, "délai global non consommé")
    local flight = flights()[1]
    local drop = MilitaryDrop.Secrets.privateState().drops[flight.dropId]
    assertEq(drop.forced, true, "largage forcé")
    assertEq(drop.team, nil, "hors suivi de confiance")
    assertEq(drop.order.lots.firearms, 2, "commande gardée")
    assertEq(MilitaryDrop.Requisition.pendingFor("tester"), nil, "autorisation consommée")
    assertEq(order({ rations = 1 }, nil, PLAYER, 2).status, "expired", "une seule commande")
end

function T.admin_order_respects_the_max_budget()
    forceCall()
    assertEq(order({ firearms = 5 }, nil, PLAYER, 2).status, "orderInvalid", "25 points sur 20")
    assertEq(order({ firearms = 4 }, nil, PLAYER, 2).status, "accepted", "20 points sur 20")
end

function T.admin_decoy_order_is_a_forced_untracked_decoy()
    forceCall()
    local reply = order({}, "E", PLAYER, 2)
    assertEq(reply.status, "accepted", "leurre accepté")
    local drop = MilitaryDrop.Secrets.privateState().drops[flights()[1].dropId]
    assertEq(drop.decoy.sector, "E", "secteur")
    assertEq(drop.forced, true, "forcé")
    assertEq(drop.team, nil, "hors suivi")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, nil, "délai non consommé")
end

function T.admin_rights_are_checked_again_at_the_order()
    forceCall()
    checkPermissions = function() return false end
    local reply = order({ rations = 1 }, nil, PLAYER, 2)
    assertEq(reply.status, "denied", "droit retiré entre-temps")
    assertEq(#flights(), 0, "aucun vol")
    assertEq(MilitaryDrop.Requisition.pendingFor("tester"), nil, "autorisation oubliée")
end

function T.non_admin_gets_no_admin_form()
    checkPermissions = function() return false end
    local reply = forceCall()
    assertEq(reply.status, "denied", "largage forcé refusé")
    assertEq(MilitaryDrop.Requisition.pendingFor("tester"), nil, "aucune autorisation")
    -- Une feuille ordinaire ne devient pas admin par la commande.
    NOW_MS = NOW_MS + 5000
    assertEq(call().status, "form", "appel ordinaire")
    local args = { requestId = 1, radio = { kind = "item", id = 7 }, order = { firearms = 1 }, force = true }
    NOW_MS = NOW_MS + 5000
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", "RequisitionOrder", PLAYER, args)
    assertEq(SENT[#SENT].args.status, "orderInvalid", "palier III refusé à la note de départ 25")
    assertEq(#flights(), 0, "aucun vol")
end

function T.admin_drop_skips_the_form_when_the_form_is_off()
    SandboxVars.MilitaryDrop.RequisitionForm = false
    assertEq(forceCall().status, "accepted", "largage admin direct")
    assertEq(#flights(), 1, "vol lancé")
end

-- ----------------------------------------------------------------------------
-- Commande valide
-- ----------------------------------------------------------------------------

function T.valid_order_launches_and_delivers_requisition_cases()
    call()
    local reply = order({ rations = 2, medical = 1, tools = 0 })
    assertEq(reply.status, "accepted", "commande acceptée")
    assertEq(reply.requestId, 1, "requestId de l'appel")
    assertEq(reply.tier, 2, "même réponse qu'un appel accepté")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, WORLD_HOURS, "délai consommé")
    assertEq(#flights(), 1, "un vol")
    local dropId = flights()[1].dropId
    local drop = MilitaryDrop.Secrets.privateState().drops[dropId]
    assertEq(drop.order.lots.rations, 2, "commande dans l'état privé")
    assertEq(drop.character, MilitaryDrop.Trust.idFor(PLAYER), "largage suivi par la confiance")
    assertEq(MilitaryDrop.Requisition.pendingFor("tester"), nil, "autorisation consommée")
    fly()
    assertEq(#PLACED_ITEMS, 3, "une caisse par unité (repli au sol)")
    local lots = {}
    for _, item in ipairs(PLACED_ITEMS) do
        assertEq(item.fullType, "MilitaryDrop.RequisitionCase", "caisse de réquisition")
        assertEq(item.modData.MilitaryDrop_dropId, dropId, "dropId")
        assertEq(item.customName, true, "nom personnalisé")
        lots[#lots + 1] = item.modData.MilitaryDrop_lot
    end
    assertEq(table.concat(lots, ","), "rations,rations,medical", "lots dans l'ordre")
    assertEq(PLACED_ITEMS[1].name, "IGUI_MilitaryDrop_RequisitionCaseName(IGUI_MilitaryDrop_Lot_rations)",
        "nom composé avec le libellé du lot")
    assertEq(#DELIVERED, 0, "pas de sirène")
end

function T.trunk_receives_the_ordered_cases()
    call()
    order({ water = 1, camping = 2 })
    local container = { kind = "ItemContainer", items = {} }
    function container.AddItem(self, fullType)
        local item = makeWorldItem(fullType)
        self.items[#self.items + 1] = item
        return item
    end
    local vehicle = { getSqlId = function() return 5 end }
    addVehicleDebug = function()
        triggerEvent("OnFillContainer", "MilitaryDrop_SupplyCrate", "TrailerTrunk", container)
        return vehicle
    end
    fly()
    assertEq(#container.items, 3, "trois caisses dans le coffre")
    assertEq(container.items[3].modData.MilitaryDrop_lot, "camping", "lot en ModData")
    assertEq(#PLACED_ITEMS, 0, "rien au sol")
end

function T.unspent_points_are_lost()
    call()
    assertEq(order({ rations = 1 }).status, "accepted", "1 point sur 8")
    assertEq(MilitaryDrop.Requisition.pendingFor("tester"), nil, "rien de reporté")
end

-- ----------------------------------------------------------------------------
-- Revalidation
-- ----------------------------------------------------------------------------

function T.invalid_orders_are_refused()
    setNote(50)
    call()
    local cases = {
        { { rations = 13 }, "dépassement du budget" },
        { { medical = 7 }, "14 points sur 12" },
        { { firearms = 1 }, "lot du palier III à la note 50" },
        { { rations = -1 }, "quantité négative" },
        { { rations = 1.5 }, "quantité non entière" },
        { { rations = "2" }, "quantité textuelle" },
        { { rations = 0 / 0 }, "NaN" },
        { { gold = 1 }, "lot inconnu" },
        { {}, "commande vide" },
        { "rations", "commande illisible" },
    }
    for _, case in ipairs(cases) do
        assertEq(order(case[1]).status, "orderInvalid", case[2])
    end
    assertEq(#flights(), 0, "aucun vol")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, nil, "délai intact")
    assertEq(order({ rations = 12 }).status, "accepted", "l'autorisation reste valable")
end

function T.empty_or_disabled_lot_is_refused()
    setNote(80)
    ProceduralDistributions.list.Everything.items = { "Hammer", 1, "PipeBomb", 1 }
    SandboxVars.MilitaryDrop.RequisitionExplosives = false
    call()
    assertEq(order({ seeds = 1 }).status, "orderInvalid", "lot vide")
    assertEq(order({ explosives = 1 }).status, "orderInvalid", "lot désactivé")
    assertEq(order({ tools = 1 }).status, "accepted", "lot permis")
end

function T.authorization_expires_after_five_minutes()
    call()
    NOW_MS = NOW_MS + 300000
    assertEq(order({ rations = 1 }).status, "expired", "après 5 minutes réelles")
    assertEq(MilitaryDrop.Requisition.pendingFor("tester"), nil, "autorisation oubliée")
    assertEq(#flights(), 0, "aucun vol")
end

function T.authorization_belongs_to_its_player_and_request()
    call()
    local other = makePlayer(makeRadio(true, CHANNEL), "other")
    assertEq(order({ rations = 1 }, nil, other).status, "expired", "autorisation d'un autre joueur")
    assertEq(order({ rations = 1 }, nil, PLAYER, 9).status, "expired", "autre requestId")
    assertEq(order({ rations = 1 }).status, "accepted", "le demandeur garde la sienne")
end

function T.cooldown_consumed_meanwhile_refuses_the_order()
    call()
    -- Un autre joueur a obtenu un largage entre-temps.
    MilitaryDrop.Server.getState().lastDropHours = WORLD_HOURS
    local reply = order({ rations = 1 })
    assertEq(reply.status, "cooldown", "délai déjà consommé")
    assertEq(reply.hours, 210, "heures restantes : 168 × 1,25 à la note de départ 25")
    assertEq(#flights(), 0, "aucun vol")
end

function T.line_cut_meanwhile_refuses_the_order()
    call()
    setNote(10)
    assertEq(order({ rations = 1 }).status, "lineCut", "ligne coupée entre-temps")
end

function T.radio_is_checked_again_without_the_code()
    call()
    PLAYER = makePlayer(makeRadio(false, CHANNEL))
    assertEq(order({ rations = 1 }).status, "radioOff", "radio éteinte")
    PLAYER = makePlayer(makeRadio(true, 107400))
    assertEq(order({ rations = 1 }).status, "noAnswer", "autre canal")
    PLAYER = makePlayer(nil)
    assertEq(order({ rations = 1 }).status, "noRadio", "radio lâchée")
    PLAYER = makePlayer(makeRadio(true, CHANNEL))
    assertEq(order({ rations = 1 }).status, "accepted", "radio reprise : autorisation gardée")
end

function T.order_burst_gets_busy()
    call()
    order({ firearms = 1 })
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", "RequisitionOrder", PLAYER,
        { requestId = 1, radio = { kind = "item", id = 7 }, order = { rations = 1 } })
    assertEq(SENT[#SENT].args.status, "busy", "deuxième commande en moins de 3 s")
end

function T.cancel_forgets_the_authorization()
    call()
    MilitaryDrop.Server.onClientCommand("MilitaryDrop", "RequisitionCancel", PLAYER, { requestId = 1 })
    assertEq(MilitaryDrop.Requisition.pendingFor("tester"), nil, "oubliée")
    assertEq(order({ rations = 1 }).status, "expired", "commande après annulation")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, nil, "rien de consommé")
end

-- ----------------------------------------------------------------------------
-- Leurre (v1.5)
-- ----------------------------------------------------------------------------

function T.decoy_is_exclusive_and_untracked()
    call()
    assertEq(order({ rations = 1 }, "N").status, "orderInvalid", "leurre et lots")
    assertEq(order(nil, "X").status, "orderInvalid", "secteur inconnu")
    assertEq(order({ rations = 0 }, "N").status, "accepted", "leurre seul (quantités nulles permises)")
    local dropId = flights()[1].dropId
    local drop = MilitaryDrop.Secrets.privateState().drops[dropId]
    assertEq(drop.decoy.sector, "N", "secteur dans l'état privé")
    assertEq(drop.team, nil, "hors suivi de confiance (LEURRE-04)")
    assertEq(MilitaryDrop.Requisition.orderOf(dropId).decoy, "N", "orderOf")
    assertTrue(flights()[1].ty < 200, "point au nord (y décroissant)")
end

function T.decoy_delivery_starts_the_siren_with_its_trunk()
    call()
    order(nil, "E")
    local dropId = flights()[1].dropId
    fly()
    assertEq(#PLACED_ITEMS, 1, "repli au sol : la balise seule")
    assertEq(PLACED_ITEMS[1].fullType, "MilitaryDrop.DecoyBeacon", "contenu fourni par le module leurre")
    assertEq(PLACED_ITEMS[1].name, "DIVERSION", "nom de la balise")
    assertEq(#DELIVERED, 1, "Decoy.onDelivered appelé")
    assertEq(DELIVERED[1].dropId, dropId, "avec le dropId")
    assertEq(DELIVERED[1].z, 0, "au sol")
end

function T.decoy_needs_the_budget()
    SandboxVars.MilitaryDrop.DecoyCost = 13
    call()
    assertEq(order(nil, "S").status, "orderInvalid", "leurre plus cher que le budget")
end

function T.sector_points_follow_the_compass()
    ZombRandFloat = function(low, high) return (low + high) / 2 end
    local Server = MilitaryDrop.Server
    local x, y = Server.pickDropPoint(100, 200, "N")
    assertTrue(x == 100 and y < 200, "nord : y décroissant")
    x, y = Server.pickDropPoint(100, 200, "S")
    assertTrue(x == 100 and y > 200, "sud")
    x, y = Server.pickDropPoint(100, 200, "E")
    assertTrue(x > 100 and y == 200, "est")
    x, y = Server.pickDropPoint(100, 200, "W")
    assertTrue(x < 100 and y == 200, "ouest")
end

function T.decoy_sector_off_map_is_refused_not_moved()
    call()
    OFF_MAP = function(_, y) return y < 200 end
    local reply = order(nil, "N")
    assertEq(reply.status, "noSite", "secteur hors carte : refus")
    assertEq(reply.sector, "N", "secteur rappelé au client")
    assertEq(#flights(), 0, "aucune sirène ailleurs ni près du demandeur")
    assertEq(MilitaryDrop.Server.getState().lastDropHours, nil, "rien de consommé")
    assertTrue(MilitaryDrop.Requisition.pendingFor("tester") ~= nil, "autorisation gardée")
    assertEq(order(nil, "S").status, "accepted", "autre secteur sans rappeler")
    assertTrue(flights()[1].ty > 200, "point au sud")
end

function T.lots_are_ready_at_start_in_one_pass()
    local passes = 0
    local toEntries = MilitaryDrop.Loot.toEntries
    MilitaryDrop.Loot.toEntries = function(flat)
        passes = passes + 1
        return toEntries(flat)
    end
    triggerEvent("OnServerStarted")
    assertEq(passes, 1, "une table : un seul passage pour les 18 lots")
    triggerEvent("OnGameStart")
    assertEq(call().status, "form", "formulaire")
    assertEq(passes, 1, "formulaire servi depuis la mémoire")
end

function T.first_form_collects_lots_lazily_in_one_pass()
    local passes = 0
    local toEntries = MilitaryDrop.Loot.toEntries
    MilitaryDrop.Loot.toEntries = function(flat)
        passes = passes + 1
        return toEntries(flat)
    end
    call()
    assertEq(passes, 1, "repli paresseux : un seul passage")
    MilitaryDrop.Server.getState().lastDropHours = nil
    NOW_MS = NOW_MS + 5000
    call()
    assertEq(passes, 1, "deuxième formulaire : mémoire")
end

function T.ground_cases_are_marked_before_being_placed()
    call()
    order({ rations = 1 })
    fly()
    assertEq(PLACED_ITEMS[1].placedName, "IGUI_MilitaryDrop_RequisitionCaseName(IGUI_MilitaryDrop_Lot_rations)",
        "nom posé avant la transmission")
    assertEq(PLACED_ITEMS[1].modData.MilitaryDrop_lot, "rations", "lot en ModData")
end

-- ----------------------------------------------------------------------------
-- Secret de la commande
-- ----------------------------------------------------------------------------

function T.order_never_reaches_public_mod_data_or_broadcasts()
    call()
    order({ medical = 3 })
    fly()
    -- Un autre joueur commande un leurre au délai suivant.
    MilitaryDrop.Server.getState().lastDropHours = nil
    call(makePlayer(makeRadio(true, CHANNEL), "other"))
    order(nil, "W", makePlayer(makeRadio(true, CHANNEL), "other"))
    local public = table.concat(flatten(MilitaryDrop.Server.getState()), "|")
    for _, word in ipairs({ "medical", "decoy", "order", "lots", "sector", "RequisitionCase" }) do
        assertTrue(public:find(word, 1, true) == nil, word .. " absent de la ModData publique")
    end
    local broadcast = table.concat(flatten(BROADCAST), "|")
    for _, word in ipairs({ "medical", "decoy", "order", "lots", "sector", "form" }) do
        assertTrue(broadcast:find(word, 1, true) == nil, word .. " absent des messages à tous")
    end
    assertTrue(#BROADCAST > 0, "les vols sont bien annoncés à tous")
end

function T.successor_cannot_use_the_previous_characters_authorization()
    MilitaryDrop.Requisition.openForm(PLAYER, 42, false)
    local successor = makePlayer(makeRadio(true, CHANNEL))
    successor:getModData().MilitaryDrop_characterId = "C:successor"
    SENT = {}
    MilitaryDrop.Requisition.handleOrder(successor, { requestId = 42, order = { lots = { rations = 1 } } })
    assertEq(SENT[#SENT].args.status, "expired", "same account does not share an authorization")
end

-- ----------------------------------------------------------------------------
-- Options changées en cours de partie (à chaud)
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- Secteur du largage choisi par le joueur (ZONE-09) : contrat de la réponse
-- et de la commande, module des zones simulé (placement réel : test_zones.lua)
-- ----------------------------------------------------------------------------

--- Module des zones simulé : sectors proposés (nil : choix 1 ou 2, ou
--- proximité) ; choosePoint note le secteur demandé et rend une case de zone.
local function stubZones(sectors)
    CHOSEN = {}
    MilitaryDrop.Zones = {
        decoySectors = function() return sectors end,
        playerSectors = function() return sectors end,
        choosePoint = function(_, _, sector)
            CHOSEN[#CHOSEN + 1] = tostring(sector)
            return true, 1001, 201, { zoneId = "z1", zoneName = "Alpha Park", sector = sector, source = "zone",
                x1 = 1000, y1 = 200, x2 = 1050, y2 = 250 }
        end,
    }
end

function T.validate_requires_a_drop_sector_only_when_offered()
    local R = MilitaryDrop.Requisition
    local offer = { budget = 10, lots = { { id = "rations", group = 1, cost = 1, allowed = true } },
        decoy = { cost = 3, allowed = true, zones = true, sectors = { "Alpha", "Bravo" } },
        drop = { zones = true, sectors = { "Alpha", "Bravo" } } }
    local ok, why = R.validate({ rations = 1 }, nil, offer)
    assertEq(ok, nil, "lots sans secteur refusés")
    assertEq(why, "no drop sector", "motif")
    ok = R.validate({ rations = 1 }, nil, offer, "Bravo")
    assertEq(ok.sector, "Bravo", "secteur gardé")
    assertEq(ok.lots.rations, 1, "lots gardés")
    _, why = R.validate({ rations = 1 }, nil, offer, "Charlie")
    assertEq(why, "bad drop sector", "secteur inconnu")
    _, why = R.validate({ rations = 1 }, nil, offer, { "Alpha" })
    assertEq(why, "bad drop sector", "secteur non textuel")
    _, why = R.validate(nil, "Bravo", offer, "Alpha")
    assertEq(why, "decoy with drop sector", "leurre avec un secteur de largage")
    ok = R.validate(nil, "Bravo", offer)
    assertEq(ok.decoy, "Bravo", "leurre seul : son secteur")
    assertEq(ok.sector, nil, "leurre : pas de secteur de largage")
    offer.drop = nil
    _, why = R.validate({ rations = 1 }, nil, offer, "Alpha")
    assertEq(why, "bad drop sector", "secteur sans champ proposé")
    ok = R.validate({ rations = 1 }, nil, offer)
    assertTrue(ok ~= nil and ok.sector == nil, "sans champ : lots seuls")
end

function T.form_carries_the_drop_sectors_and_the_order_its_sector()
    stubZones({ "Alpha", "Bravo" })
    local reply = call()
    assertEq(reply.status, "form", "formulaire")
    assertEq(reply.drop.zones, true, "champ du secteur de largage")
    assertEq(table.concat(reply.drop.sectors, ","), "Alpha,Bravo", "secteurs proposés")
    assertEq(order({ rations = 1 }).status, "orderInvalid", "secteur exigé")
    assertEq(order({ rations = 1 }, nil, PLAYER, 1, "Charlie").status, "orderInvalid", "secteur forgé")
    assertEq(#CHOSEN, 0, "aucun point tiré pour une commande refusée")
    assertEq(order({ rations = 1 }, nil, PLAYER, 1, "Bravo").status, "accepted", "secteur proposé")
    assertEq(CHOSEN[1], "Bravo", "point tiré dans le secteur choisi")
    local drop = MilitaryDrop.Secrets.privateState().drops[flights()[1].dropId]
    assertEq(drop.order.lots.rations, 1, "commande de lots")
    assertEq(drop.zone.sector, "Bravo", "zone rangée dans l'état privé")
    -- Feuille admin (décision du 2026-10-06) : même champ ; choix 1 ou 2 : aucun.
    local adminOffer = MilitaryDrop.Requisition.offer("C:tester", true, PLAYER)
    assertEq(table.concat(adminOffer.drop.sectors, ","), "Alpha,Bravo", "feuille admin : même champ")
    stubZones(nil)
    assertEq(MilitaryDrop.Requisition.offer("C:tester", nil, PLAYER).drop, nil, "choix 1 ou 2")
    stubZones({})
    assertEq(MilitaryDrop.Requisition.offer("C:tester", nil, PLAYER).drop, nil, "aucun secteur : aucun champ")
end

function T.without_the_zones_module_a_drop_sector_is_refused()
    SandboxVars.MilitaryDrop.DropZoneChoice = 3
    local reply = call()
    assertEq(reply.status, "form", "formulaire")
    assertEq(reply.drop, nil, "pas de zones : pas de champ")
    assertEq(order({ rations = 1 }, nil, PLAYER, 1, "Alpha").status, "orderInvalid", "secteur refusé")
    assertEq(order({ rations = 1 }).status, "accepted", "lots seuls, comme avant")
end

--- Options Java de la partie, copiées de SandboxVars, qui reste périmé (solo :
--- l'éditeur d'options du menu de debug ne change que les options Java).
local function javaOptions()
    local values = {}
    for name, value in pairs(SandboxVars.MilitaryDrop) do
        values["MilitaryDrop." .. name] = value
    end
    return useJavaSandboxOptions(values)
end

function T.form_budget_and_cost_options_changed_during_the_game_apply_at_once()
    local java = javaOptions()
    local R = MilitaryDrop.Requisition
    java["MilitaryDrop.RequisitionForm"] = false
    assertEq(call().status, "accepted", "formulaire désactivé : caisses aléatoires")
    MilitaryDrop.Server.getState().lastDropHours = nil
    MilitaryDrop.Server.getState().flights = {}
    java["MilitaryDrop.RequisitionForm"] = true
    NOW_MS = NOW_MS + 5000
    assertEq(call().status, "form", "réactivé : formulaire dès l'appel suivant")
    assertEq(R.budget(50), 12, "budget à 100 %")
    java["MilitaryDrop.RequisitionBudget"] = 50
    assertEq(R.budget(50), 6, "budget à 50 % tout de suite")
    java["MilitaryDrop.RequisitionCostMultiplier"] = 150
    assertEq(R.cost(5), 8, "coûts × 1,5 tout de suite")
    java["MilitaryDrop.RequisitionTier2"] = 20
    assertEq(R.maxGroup(20), 2, "palier 2 tout de suite")
    java["MilitaryDrop.DecoyEnabled"] = false
    MilitaryDrop.Server.getState().lastDropHours = nil
    NOW_MS = NOW_MS + 5000
    assertEq(call().decoy, nil, "leurre retiré du formulaire suivant")
end

function T.form_enabled_during_the_game_prepares_the_lots_at_the_next_minute()
    local java = javaOptions()
    java["MilitaryDrop.RequisitionForm"] = false
    local passes = 0
    local toEntries = MilitaryDrop.Loot.toEntries
    MilitaryDrop.Loot.toEntries = function(flat)
        passes = passes + 1
        return toEntries(flat)
    end
    triggerEvent("OnServerStarted")
    triggerEvent("EveryOneMinute")
    assertEq(passes, 0, "formulaire désactivé : rien de précalculé")
    java["MilitaryDrop.RequisitionForm"] = true
    triggerEvent("EveryOneMinute")
    assertEq(passes, 1, "activé en cours de partie : lots précalculés en un passage")
    assertEq(call().status, "form", "formulaire")
    assertEq(passes, 1, "servi depuis la mémoire")
end

return T
