-- Sites de crash : chaque composant attend son chunk, puis n'est posé qu'une fois.
if isClient() then return end
require "MilitaryDrop/MilitaryDrop_Server"
require "MilitaryDrop/MilitaryDrop_Crash"
require "MilitaryDrop/MilitaryDrop_WreckParts"
require "MilitaryDrop/MilitaryDrop_Notes"
require "MilitaryDrop/MilitaryDrop_WreckSmoke"

local Wreck = {}
MilitaryDrop.Wreck = Wreck
local Crash, Config = MilitaryDrop.Crash, MilitaryDrop.Config
local Server, Net = MilitaryDrop.Server, MilitaryDrop.Net
Wreck.SITE_KEY = "MilitaryDrop_crashSite"
Wreck.PILOT_OUTFIT = "ArmyCamoGreen"
Wreck.FIRE_ENERGY, Wreck.FIRE_LIFE = 40, 1800

local function sites()
    local s = MilitaryDrop.Secrets.privateState()
    s.wrecks = s.wrecks or {}
    return s.wrecks
end

-- Une enveloppe carrée couvre les pales, les rotations et le jitter ±0,2 rad.
function Wreck.footprint(x, y, radius)
    local cell = getCell()
    local loaded, free = true, true
    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(x + dx, y + dy, 0)
            if not square then
                loaded = false
            elseif not square:isOutside() or square:isWaterSquare() or not square:isFree(false)
                or square:getVehicleContainer() then
                free = false
            end
        end
    end
    return loaded, free
end

local function component(site, key, fn)
    if site.done[key] then return true end
    -- Écrit avant l'appel Java. Une pose interrompue est signalée et jamais rejouée à l'aveugle.
    site.done[key] = "placing"
    local result = fn()
    site.done[key] = result and "done" or nil
    return result
end

function Wreck.pickSpot(site, x, y, radius)
    local loaded = Wreck.footprint(x, y, radius)
    if not loaded then return nil, false end
    for along = 0, 24, 4 do
        for _, across in ipairs({ 0, -4, 4, -8, 8 }) do
            local sx, sy = Crash.offset({ x = x, y = y, dx = site.dx, dy = site.dy }, -along, across)
            local ready, free = Wreck.footprint(sx, sy, radius)
            if ready and free then return getCell():getGridSquare(sx, sy, 0), true end
        end
    end
    return nil, true
end

function Wreck.spawnVehicle(site, key, script, x, y, radius)
    if site.done[key] then return true end
    local square, ready = Wreck.pickSpot(site, x, y, radius)
    if not ready then return false end
    if not square then
        site.done[key] = "skipped"
        MilitaryDrop.log("crash " .. site.id .. ": no space for " .. key .. "; salvage left on ground", true)
        return true
    end
    -- Fixer les coordonnées AVANT la pose permet de diagnostiquer une interruption.
    site.positions[key] = { x = square:getX(), y = square:getY() }
    local result = component(site, key, function()
        local vehicle = addVehicleDebug(script, IsoDirections[Crash.direction(site)], 0, square)
        if not vehicle or vehicle:getSqlId() == -1 then
            return false
        end
        local part = vehicle:getPartByIndex(0)
        if part then
            part:getModData()[Wreck.SITE_KEY] = site.id
            vehicle:transmitPartModData(part)
        end
        return true
    end)
    if not result then site.done[key] = "skipped" end
    return true
end

local function groundItem(square, fullType, site)
    local item = instanceItem(fullType)
    if not item then return false end
    item:getModData()[Wreck.SITE_KEY] = site.id
    square:AddWorldInventoryItem(item, 0.5, 0.5, 0, true)
    return true
end

function Wreck.pilot(site, square)
    return component(site, "pilot", function()
        local outfit = site.outfit
        local body = RandomizedWorldBase.createRandomDeadBody(square, IsoDirections.getRandom(), 5, 0, outfit)
        if not body then return false end
        body:setFakeDead(false)
        body:setReanimateTime(-1)
        body:getModData()[Wreck.SITE_KEY] = site.id
        local container = body:getContainer()
        local recorder = container:AddItem("MilitaryDrop.FlightRecorder")
        if recorder then
            -- Site, point et horloge du crash : la baie de lecture du poste les affiche.
            local data = recorder:getModData()
            data[Wreck.SITE_KEY] = site.id
            data.MilitaryDrop_crashX, data.MilitaryDrop_crashY, data.MilitaryDrop_crashClock = site.x, site.y, site.c
            sendAddItemToContainer(container, recorder)
        end
        if site.documents then
            local memo = MilitaryDrop.Notes.createMemo(1)
            local book = MilitaryDrop.Notes.createCodebook()
            for _, item in ipairs({ memo, book }) do
                container:AddItem(item)
                sendAddItemToContainer(container, item)
            end
        end
        return true
    end)
end

-- Deux pilotes vivants, séparés du cadavre et de la horde attirée par le bruit.
-- Chaque pose est suivie individuellement pour ne pas doubler le premier si
-- le second attend une case chargée ou si le moteur refuse sa création.
function Wreck.pilotZombies(site)
    if site.crewVersion ~= 1 then return true end -- Ne pas repeupler les anciens crashs.
    if not site.done.main then return false end
    if IsoWorld.getZombiesDisabled() and not isDebugEnabled() then
        site.done.pilotZombie1 = site.done.pilotZombie1 or "skipped"
        site.done.pilotZombie2 = site.done.pilotZombie2 or "skipped"
        return true
    end
    local ready = true
    local origin = site.positions.main or site
    for i, across in ipairs({ -5, 5 }) do
        local key = "pilotZombie" .. i
        if not site.done[key] then
            local x, y = Crash.offset({ x = origin.x, y = origin.y, dx = site.dx, dy = site.dy }, -2, across)
            local square
            for radius = 0, 3 do
                for dx = -radius, radius do
                    for dy = -radius, radius do
                        local loaded, free = Wreck.footprint(x + dx, y + dy, 0)
                        if loaded and free then
                            square = getCell():getGridSquare(x + dx, y + dy, 0)
                            break
                        end
                    end
                    if square then break end
                end
                if square then break end
            end
            if square then
                component(site, key, function()
                    local zombies = addZombiesInOutfit(square:getX(), square:getY(), 0, 1, Wreck.PILOT_OUTFIT, 50)
                    if not zombies or zombies:size() == 0 then return false end
                    zombies:get(0):getModData()[Wreck.SITE_KEY] = site.id
                    return true
                end)
            end
        end
        ready = ready and site.done[key] ~= nil
    end
    return ready
end

-- Les particules suivent le fuselage réellement posé, même si la recherche
-- de place l'a déplacé. Deux cases distinctes : un feu bloque StartSmoke
-- sur sa propre case via CanAddSmoke.
function Wreck.effectSquare(site, across)
    if not site.done.main then return nil end
    local origin = site.positions.main or site
    local x, y = Crash.offset({ x = origin.x, y = origin.y, dx = site.dx, dy = site.dy }, 0, across)
    local square = getCell():getGridSquare(x, y, 0)
    if square and square:isOutside() and not square:isWaterSquare() then return square end
    return nil
end

function Wreck.smoke(site)
    if site.fire < 2 or getGameTime():getWorldAgeHours() >= site.smokeUntil then return end
    local square = Wreck.effectSquare(site, -2)
    if not square then return end
    local now = getTimestampMs()
    if not site.lastSmoke or now - site.lastSmoke >= 10000 then
        local args = { id = site.id, x = square:getX(), y = square:getY() }
        -- StartSmoke MP empile des objets client à chaque paquet. Le helper
        -- local garde une seule fumée et renouvelle aussi les arrivants.
        if isServer() then Net.toAll("WreckSmoke", args) else MilitaryDrop.WreckSmoke.show(args) end
        site.lastSmoke = now
    end
end

function Wreck.effects(site, square)
    component(site, "horde", function()
        addSound(nil, square:getX(), square:getY(), 0, 200, 100)
        if site.zombies > 0 then
            spawnHorde(site.x - 15, site.y - 15, site.x + 15, site.y + 15, 0, site.zombies)
        end
        return true
    end)
    if site.fire == 3 then
        local fireSquare = Wreck.effectSquare(site, 2)
        if not site.done.fire and not fireSquare then return false end
        component(site, "fire", function()
            -- Un seul petit foyer initial ; les règles NoFire, safehouse et
            -- FireSpread restent appliquées par le moteur 42.21.
            IsoFireManager.StartFire(getCell(), fireSquare, true, Wreck.FIRE_ENERGY, Wreck.FIRE_LIFE)
            return true
        end)
    end
    return true
end

function Wreck.trySite(site)
    -- OnInitGlobalModData (restore, Flights.restore -> add) précède la création
    -- de la cellule : getCell() vaut nil, LoadChunk reprendra la pose.
    local cell = getCell()
    if not cell then return false end
    local square = cell:getGridSquare(site.x, site.y, 0)
    if not square then return false end
    square = Server.findOpenGroundNear(site.x, site.y)
    if not square then return false end
    -- Repli si le point a changé depuis l'annonce (construction, eau).
    site.x, site.y = square:getX(), square:getY()
    local main = Wreck.spawnVehicle(site, "main", "Base.MilitaryDrop_HeliWreckBurnt", site.x, site.y, 5)
    local tx, ty = Crash.offset(site, 12, 2)
    local tail = Wreck.spawnVehicle(site, "tail", "Base.MilitaryDrop_HeliTailBurnt", tx, ty, 3)
    Wreck.pilot(site, square)
    local crewReady = Wreck.pilotZombies(site)
    local effectsReady = Wreck.effects(site, square)
    for i, across in ipairs({ -4, 4, -7 }) do
        local dx, dy = Crash.offset(site, -i * 3, across)
        local debris = Server.findOpenGroundNear(dx, dy)
        if debris then
            component(site, "debris" .. i, function() return groundItem(debris, "MilitaryDrop.MetalSalvage", site) end)
        end
    end
    local fallbackReady = true
    if site.done.main == "skipped" then
        for id, spec in pairs(MilitaryDrop.Salvage.PARTS) do
            local done = component(site, "fallback" .. id, function()
                return groundItem(square, MilitaryDrop.Salvage.TYPES[spec.kind], site)
            end)
            fallbackReady = fallbackReady and done
        end
    end
    if site.done.tail == "skipped" then
        fallbackReady = component(site, "fallbackTail", function()
            return groundItem(square, MilitaryDrop.Salvage.TYPES.metal, site)
        end) and fallbackReady
    end
    if site.crates then
        component(site, "supplies", function()
            return Server.deliver(site.x, site.y, site.requester, site.dropId, { crash = true })
        end)
    end
    Wreck.smoke(site)
    site.complete = main and tail and fallbackReady and crewReady and effectsReady and site.done.pilot and site.done.horde
        and (not site.crates or site.done.supplies) and site.done.debris1 and site.done.debris2 and site.done.debris3
    return site.complete
end

function Wreck.add(flight)
    local registry = sites()
    local id = "W" .. flight.id
    if registry[id] then return registry[id] end
    local impact = flight.crash
    if not flight.mayday then MilitaryDrop.Broadcast.mayday(flight.id, impact.x, impact.y) end
    local outfits = getAllOutfits(false)
    local matches, words = {}, Config.getList("PilotOutfits")
    for i = 0, outfits:size() - 1 do
        local name = outfits:get(i)
        for _, word in ipairs(words) do
            if string.find(string.lower(name), word, 1, true) then matches[#matches + 1] = name break end
        end
    end
    registry[id] = {
        id = id, x = math.floor(impact.x), y = math.floor(impact.y), dx = impact.dx, dy = impact.dy,
        c = Server.clock(),
        requester = flight.requester, dropId = flight.dropId, cause = impact.cause,
        done = {}, positions = {}, crewVersion = 1, crates = Config.get("CrashCrates") == true,
        fire = Config.get("CrashFire"), smokeUntil = getGameTime():getWorldAgeHours()
            + math.max(0, Config.get("CrashSmokeMinutes")) / 60,
        zombies = Server.hordeSize(), documents = Config.get("PilotDocuments") == true,
        outfit = #matches > 0 and matches[ZombRand(#matches) + 1] or nil,
    }
    -- Le crash n'est pas un échec du demandeur : aucun malus de largage perdu.
    -- Fournitures attendues : le dossier (commande) reste jusqu'à leur livraison.
    if MilitaryDrop.Trust.onCrash then MilitaryDrop.Trust.onCrash(flight.dropId, registry[id].crates) end
    Net.toAll("FlightCrash", { id = flight.id, x = impact.x, y = impact.y })
    MilitaryDrop.log("flight " .. flight.id .. " crashed (" .. tostring(impact.cause) .. ")", true)
    Wreck.trySite(registry[id])
    return registry[id]
end

function Wreck.update()
    for _, site in pairs(sites()) do
        if not site.complete or (site.fire >= 2 and getGameTime():getWorldAgeHours() < site.smokeUntil) then
            Wreck.trySite(site)
        end
    end
end

function Wreck.restore()
    for _, site in pairs(sites()) do
        site.lastSmoke = nil
        for key, value in pairs(site.done) do
            if value == "placing" then
                MilitaryDrop.log("crash " .. site.id .. ": interrupted " .. key .. "; inspect the site", true)
                -- Préférer une pièce manquante à la duplication de véhicules/objets sauvegardés.
                site.done[key] = "interrupted"
            end
        end
    end
    Wreck.update()
end

Events.LoadChunk.Add(Wreck.update)
Events.EveryOneMinute.Add(Wreck.update)
Events.OnInitGlobalModData.Add(Wreck.restore)
return Wreck
