-- ============================================================================
-- Military Drop — caisse de largage (véhicule Base.MilitaryDrop_SupplyCrate)
--
-- Le coffre d'un véhicule est rempli par le serveur à sa création
-- (BaseVehicle.randomizeContainers, 42.21), seulement si le type a une
-- distribution. On en déclare une vide ; le contenu est ajouté par
-- OnFillContainer, qui lit les options sandbox au moment même (pas besoin de
-- relire les tables de butin après leur fusion).
--
-- Serveur MP ou solo seulement : un client ne crée ni ne remplit de véhicule.
--
-- Confiance : chaque caisse de ravitaillement du coffre porte le dropId du
-- largage (ModData MilitaryDrop_dropId). addVehicleDebug remplit le coffre
-- pendant l'appel (addToWorld → createPhysics → randomizeContainers →
-- OnFillContainer, BaseVehicle.java:804-888, 42.21) : le dropId en cours est
-- donc connu de onFillContainer.
--
-- Contenu (Crate.contentsFor) : sans commande, CaseRolls caisses de
-- ravitaillement tirées au hasard ; commande du formulaire (v1.4) : une
-- caisse de réquisition par unité commandée (MilitaryDrop.Requisition.casesFor :
-- lot en ModData, nom composé) ; leurre (v1.5) : ce que fournit
-- MilitaryDrop.Decoy.trunkContents (balise de diversion). Même contenu au sol
-- quand la caisse ne peut pas apparaître (Server.deliver).
--
-- Re-remplissage par un autre mod (retour joueur du 2026-10-06, commande admin
-- livrée en caisses aléatoires) : un mod peut rappeler la distribution d'un
-- véhicule déjà rempli, par exemple setExplored(false) sur chaque conteneur
-- puis vehicle:forceVehicleDistribution(type), quelques secondes après
-- OnSpawnVehicleEnd. Le moteur vide alors le coffre et rappelle
-- OnFillContainer avec le type du véhicule (BaseVehicle.forceVehicleDistribution
-- → randomizeContainer, BaseVehicle.java:9905-9919 et 8039-8051, 42.21), hors
-- de Crate.spawn : sans parade, le coffre recevait CaseRolls caisses au hasard.
-- Parades : (1) marqueur resetedContainers = true dans la ModData de chaque
-- véhicule du mod (Crate.protect), que le mod tiers observé lit avant d'agir
-- (Workshop 3457132019, mods/SpecificLootKI5/42/media/lua/server/Specific
-- Loot/ResetContainers.lua:10, lecture seule) ; (2) dropId rangé dans la
-- ModData du véhicule-caisse : un re-remplissage hors de Crate.spawn rend la
-- commande du largage une fois au plus, jamais des caisses au hasard
-- (Crate.onRefill). Diagnostics « crate contents » toujours écrits : voir
-- Crate.reportDistribution, Crate.reportDelivery, Server.pollCollected.
-- ============================================================================

if isClient() then
    return
end

require "Vehicles/VehicleDistributions"
require "MilitaryDrop/MilitaryDrop_Loot"

local Config = MilitaryDrop.Config
local Loot = MilitaryDrop.Loot

local Crate = {}
MilitaryDrop.Crate = Crate

-- Largage de la caisse en cours de création (Crate.spawn), ou nil.
local fillingDropId = nil
-- Remplissage observé pendant Crate.spawn (Crate.reportDelivery), ou nil :
-- { fills = appels reçus, expected = entrées ajoutées, before = contenu
-- trouvé dans le coffre avant notre ajout (distribution ou autre abonné) }.
local spawnReport = nil
-- Table déclarée par Crate.registerDistribution (comparée au démarrage).
local declaredEntry = nil
local distributionReported = false

Crate.SCRIPT = "MilitaryDrop_SupplyCrate"
Crate.FULL_SCRIPT = "Base." .. Crate.SCRIPT
Crate.TRUNK = "TrailerTrunk"
-- ModData d'objet : largage d'une caisse de ravitaillement (MilitaryDrop_Trust.lua).
-- Même clé dans la ModData du véhicule-caisse (Crate.protect).
Crate.DROP_KEY = "MilitaryDrop_dropId"
-- ModData du véhicule-caisse : commande déjà rendue une fois (Crate.onRefill).
Crate.RESTORED_KEY = "MilitaryDrop_orderRestored"
-- Marqueur lu par un mod tiers qui re-remplit les véhicules de mod : il ne
-- touche pas un véhicule dont la ModData porte resetedContainers == true
-- (ResetContainers.lua:10 du mod Workshop 3457132019, voir l'en-tête).
Crate.REFILL_MARKER = "resetedContainers"
-- Véhicules du mod (caisse, épaves Mayday) : préfixe du script complet.
Crate.VEHICLE_PREFIX = "Base.MilitaryDrop_"
-- Types listés au plus par ligne de journal.
Crate.REPORT_TYPES = 6
-- Caisses de ravitaillement tirées à chaque option CaseRolls.
Crate.CASE_WEIGHTS = {
    "MilitaryDrop.AmmoSupplyCase", 45,
    "MilitaryDrop.WeaponSupplyCase", 25,
    "MilitaryDrop.ArmorSupplyCase", 15,
    "MilitaryDrop.AttachmentSupplyCase", 15,
}

--- Types complets des caisses de ravitaillement d'un largage.
function Crate.rollCases(rand)
    rand = rand or function(total) return ZombRandFloat(0, total) end
    local entries = Loot.toEntries(Crate.CASE_WEIGHTS)
    local cases = {}
    for _ = 1, math.max(1, math.floor(Config.get("CaseRolls"))) do
        local entry = Loot.pickWeighted(entries, rand)
        if entry then
            cases[#cases + 1] = entry.name
        end
    end
    return cases
end

--- Contenu d'un largage : { { fullType, name?, lot? }, … }.
function Crate.contentsFor(dropId)
    local Requisition = MilitaryDrop.Requisition
    local order = dropId and Requisition and Requisition.orderOf(dropId)
    if order and order.decoy then
        local Decoy = MilitaryDrop.Decoy
        local contents = Decoy and Decoy.trunkContents and Decoy.trunkContents(dropId)
        if type(contents) ~= "table" then
            MilitaryDrop.log("decoy " .. tostring(dropId) .. ": no decoy module, empty trunk", true)
            return {}
        end
        return contents
    end
    if order and order.lots then
        return Requisition.casesFor(dropId)
    end
    -- Contenu aléatoire alors qu'un largage était désigné : dossier introuvable
    -- (oublié, état privé perdu), ou sans commande alors que le formulaire est
    -- actif (largage d'avant l'option, ou commande perdue). Toujours journalisé
    -- (retour joueur du 2026-10-06 : commande admin livrée au hasard).
    local Trust = MilitaryDrop.Trust
    if dropId and Trust and Trust.drop then
        local drop = Trust.drop(dropId)
        if not drop then
            MilitaryDrop.log("drop " .. tostring(dropId) .. ": no drop record, random supply cases", true)
        elseif Requisition and Requisition.formEnabled and Requisition.formEnabled() then
            MilitaryDrop.log("drop " .. tostring(dropId) .. ": no order in its record"
                .. (drop.forced and " (admin drop)" or "") .. ", random supply cases", true)
        end
    end
    local entries = {}
    for i, fullType in ipairs(Crate.rollCases()) do
        entries[i] = { fullType = fullType }
    end
    -- Kit Fulton endommagé (FULTON-10) : caisses sans commande seulement.
    local FultonLoot = MilitaryDrop.FultonLoot
    if FultonLoot and FultonLoot.rollCrate() then
        entries[#entries + 1] = { fullType = FultonLoot.DAMAGED_KIT }
    end
    return entries
end

--- Marque un objet créé pour un largage : dropId (confiance), lot d'une
--- caisse de réquisition, nom composé (setName + setCustomName, sauvegardé et
--- transmis au client).
function Crate.applyEntry(item, entry, dropId)
    local modData = item:getModData()
    if dropId then
        modData[Crate.DROP_KEY] = dropId
    end
    if entry.lot and MilitaryDrop.Lots then
        modData[MilitaryDrop.Lots.ITEM_KEY] = entry.lot
    end
    if type(entry.name) == "string" and entry.name ~= "" then
        item:setName(entry.name)
        item:setCustomName(true)
    end
end

-- ----------------------------------------------------------------------------
-- Diagnostics : contenu d'un coffre
-- ----------------------------------------------------------------------------

--- Liste Java des objets d'un conteneur, ou nil.
function Crate.itemsOf(container)
    return container and container.getItems and container:getItems() or nil
end

--- Type complet d'un objet (InventoryItem.getFullType).
local function typeOf(item)
    return item and item.getFullType and item:getFullType() or "?"
end

--- Comptage par type d'une liste Java : { [type] = n }, total.
function Crate.summarize(items)
    local counts, total = {}, 0
    for i = 0, (items and items:size() or 0) - 1 do
        local fullType = typeOf(items:get(i))
        counts[fullType] = (counts[fullType] or 0) + 1
        total = total + 1
    end
    return counts, total
end

--- Comptage par type des entrées de Crate.contentsFor.
local function countEntries(entries)
    local counts, total = {}, 0
    for _, entry in ipairs(entries or {}) do
        counts[entry.fullType] = (counts[entry.fullType] or 0) + 1
        total = total + 1
    end
    return counts, total
end

--- « 3 item(s): A x2, B x1 », borné à REPORT_TYPES types (ordre alphabétique).
function Crate.formatCounts(counts, total)
    if total == 0 then
        return "0 item"
    end
    local types = {}
    for fullType in pairs(counts) do
        types[#types + 1] = fullType
    end
    table.sort(types)
    local parts = {}
    for i, fullType in ipairs(types) do
        if i > Crate.REPORT_TYPES then
            parts[#parts + 1] = "+" .. (#types - Crate.REPORT_TYPES) .. " more type(s)"
            break
        end
        parts[#parts + 1] = fullType .. " x" .. counts[fullType]
    end
    return total .. " item(s): " .. table.concat(parts, ", ")
end

local function sameCounts(a, b)
    for fullType, n in pairs(a) do
        if b[fullType] ~= n then
            return false
        end
    end
    for fullType, n in pairs(b) do
        if a[fullType] ~= n then
            return false
        end
    end
    return true
end

--- Objets d'une liste Java marqués du largage dropId.
local function countTagged(items, dropId)
    local count = 0
    for i = 0, (items and items:size() or 0) - 1 do
        local item = items:get(i)
        if item and item.getModData and item:getModData()[Crate.DROP_KEY] == dropId then
            count = count + 1
        end
    end
    return count
end

--- Coffre (ItemContainer) d'une caisse, ou nil.
function Crate.trunkOf(vehicle)
    local part = vehicle and vehicle.getPartById and vehicle:getPartById(Crate.TRUNK)
    return part and part:getItemContainer() or nil
end

--- Véhicule d'un conteneur de pièce (ItemContainer.getVehiclePart), ou nil.
local function vehicleOf(container)
    local part = container.getVehiclePart and container:getVehiclePart()
    return part and part:getVehicle() or nil
end

local function where(vehicle)
    if not (vehicle and vehicle.getX) then
        return ""
    end
    return string.format(" at %d,%d", math.floor(vehicle:getX()), math.floor(vehicle:getY()))
end

--- Commande d'un largage, pour le journal.
function Crate.describeOrder(dropId)
    if dropId == nil then
        return "no drop id"
    end
    local Requisition = MilitaryDrop.Requisition
    local order = Requisition and Requisition.orderOf and Requisition.orderOf(dropId)
    if order and order.decoy then
        return "decoy"
    elseif order and order.lots then
        return "requisition order"
    end
    return "no order, random supply cases"
end

-- ----------------------------------------------------------------------------
-- Distribution du coffre
-- ----------------------------------------------------------------------------

function Crate.registerDistribution()
    local tables = VehicleDistributions and VehicleDistributions[1]
    if type(tables) ~= "table" then
        MilitaryDrop.log("VehicleDistributions[1] missing: the crate trunk stays empty", true)
        return
    end
    declaredEntry = { Normal = { [Crate.TRUNK] = { rolls = 0, items = {} } } }
    tables[Crate.SCRIPT] = declaredEntry
end

--- Ce que le moteur lira pour remplir le coffre : la table Lua
--- VehicleDistributions[1], relue par ItemPickerJava.Parse
--- (ParseVehicleDistributions, ItemPickerJava.java:287-330) ; la copie Java
--- n'est pas lisible depuis Lua. BaseVehicle.randomizeContainers cherche
--- d'abord <type><skinIndex>, puis <type> (BaseVehicle.java:7974-7979) ; sans
--- entrée, aucun remplissage ni OnFillContainer. Les abonnés d'OnFillContainer
--- (Event.callbacks, liste Java) ne sont pas visibles depuis Lua : la table
--- Events.OnFillContainer ne porte que Add et Remove (Event.register,
--- Event.java:74-78). Renvoie le texte et vrai si l'entrée a changé.
function Crate.describeDistribution()
    local tables = VehicleDistributions and VehicleDistributions[1]
    if type(tables) ~= "table" then
        return "VehicleDistributions[1] missing: the engine fills no vehicle trunk, crates arrive empty", true
    end
    local skins = {}
    for key in pairs(tables) do
        if type(key) == "string" and key ~= Crate.SCRIPT and key:sub(1, #Crate.SCRIPT) == Crate.SCRIPT then
            skins[#skins + 1] = key
        end
    end
    table.sort(skins)
    local entry = tables[Crate.SCRIPT]
    if type(entry) ~= "table" then
        return "entry " .. Crate.SCRIPT .. " missing (removed by another mod?): the engine will not fill the crate"
            .. " trunk and crates arrive empty", true
    end
    local changes = {}
    if entry ~= declaredEntry then
        changes[#changes + 1] = "table replaced"
    end
    local normal = type(entry.Normal) == "table" and entry.Normal or {}
    local trunk = type(normal[Crate.TRUNK]) == "table" and normal[Crate.TRUNK] or nil
    local rolls = trunk and tonumber(trunk.rolls) or 0
    local items = trunk and type(trunk.items) == "table" and math.floor(#trunk.items / 2) or 0
    if not trunk then
        changes[#changes + 1] = Crate.TRUNK .. " list removed"
    end
    if rolls ~= 0 or items > 0 then
        changes[#changes + 1] = string.format("%s rolls %s with %d item(s)", Crate.TRUNK, tostring(rolls), items)
    end
    if trunk and trunk.junk ~= nil then
        changes[#changes + 1] = "junk list added"
    end
    for name in pairs(normal) do
        if name ~= Crate.TRUNK then
            changes[#changes + 1] = "container " .. tostring(name) .. " added"
        end
    end
    if entry.Specific ~= nil or entry.SpecificIDs ~= nil then
        changes[#changes + 1] = "Specific lists added"
    end
    for _, key in ipairs(skins) do
        changes[#changes + 1] = "skin entry " .. key .. " added"
    end
    local text = "entry " .. Crate.SCRIPT .. " present, " .. Crate.TRUNK .. " rolls " .. tostring(rolls)
        .. ", " .. items .. " item(s)"
    if #changes == 0 then
        return text .. ", unchanged since this mod declared it", false
    end
    table.sort(changes)
    return text .. ", CHANGED by another mod (" .. table.concat(changes, "; ") .. "): crates may get extra loot", true
end

--- Une ligne au démarrage (serveur dédié : OnServerStarted ; solo :
--- OnGameStart), après la fusion et ItemPickerJava.Parse (IsoWorld.java:1793-1805).
--- Les mods actifs ne sont pas répétés : le jeu écrit déjà « loading <id> »
--- pour chacun (ZomboidFileSystem.java:623).
function Crate.reportDistribution()
    if distributionReported then
        return
    end
    distributionReported = true
    MilitaryDrop.log("crate contents at start: " .. Crate.describeDistribution()
        .. "; OnFillContainer handlers of other mods: not visible from Lua", true)
end

-- ----------------------------------------------------------------------------
-- Remplissage
-- ----------------------------------------------------------------------------

--- Marque un véhicule du mod contre les re-remplissages tiers (voir l'en-tête) :
--- marqueur resetedContainers, et dropId de la caisse s'il est connu. Même
--- processus que le mod tiers (serveur, ou partie solo) : la ModData qu'il lit
--- est celle-ci, sans transmission aux clients ; il agit 5 s (solo) ou 10 s
--- (MP) après OnSpawnVehicleEnd (ResetContainers.lua:99-109), nous pendant
--- l'événement même. ModData du véhicule sauvegardée avec lui.
function Crate.protect(vehicle, dropId)
    local modData = vehicle:getModData()
    modData[Crate.REFILL_MARKER] = true
    if dropId ~= nil and modData[Crate.DROP_KEY] == nil then
        modData[Crate.DROP_KEY] = dropId
    end
end

--- Premier dropId porté par un objet du coffre (caisse d'une ancienne version).
local function trunkDropId(vehicle)
    local items = Crate.itemsOf(Crate.trunkOf(vehicle))
    for i = 0, (items and items:size() or 0) - 1 do
        local item = items:get(i)
        local dropId = item and item.getModData and item:getModData()[Crate.DROP_KEY]
        if dropId ~= nil then
            return dropId
        end
    end
    return nil
end

--- OnSpawnVehicleEnd (fin de BaseVehicle.createPhysics, BaseVehicle.java:897,
--- après randomizeContainers l. 888) : à la création comme à chaque entrée
--- dans le monde. Marque donc aussi les caisses et épaves des sauvegardes
--- existantes, avant le délai du mod tiers.
function Crate.onSpawnVehicleEnd(vehicle)
    local name = vehicle and vehicle.getScriptName and vehicle:getScriptName()
    if type(name) ~= "string" or name:sub(1, #Crate.VEHICLE_PREFIX) ~= Crate.VEHICLE_PREFIX then
        return
    end
    local dropId = nil
    if name == Crate.FULL_SCRIPT then
        dropId = fillingDropId or trunkDropId(vehicle)
    end
    Crate.protect(vehicle, dropId)
end

local function addEntries(container, entries, dropId)
    for _, entry in ipairs(entries) do
        local item = container:AddItem(entry.fullType)
        if item then
            Crate.applyEntry(item, entry, dropId)
        end
    end
end

--- Le largage peut-il encore recevoir sa commande ? Dossier présent, ni
--- vidé (Server.pollCollected), ni conclu (caisse ouverte, perdue).
local function canRestore(dropId)
    local Trust = MilitaryDrop.Trust
    local drop = Trust and Trust.drop and Trust.drop(dropId)
    return drop ~= nil and not drop.collectedHours and not drop.outcome
end

--- Coffre rempli hors de Crate.spawn : re-remplissage par un autre mod
--- (forceVehicleDistribution vide le coffre avant de le remplir, en solo
--- comme en MP, BaseVehicle.java:9910-9915), ou caisse inconnue. Caisse
--- portant un dropId : sa commande, une fois au plus et seulement si le
--- largage n'est ni vidé ni conclu (pas de doublon à piller) ; rien si le
--- coffre la contient encore. Caisse sans dropId (largage d'avant cette
--- version, coffre vide au chargement) : caisses au hasard, comme avant.
--- En MP, les objets ajoutés ici sur une caisse déjà connue des clients ne
--- leur sont pas envoyés par nous : c'est au mod qui re-remplit de le faire
--- (le mod observé appelle SynchSpawn sur chaque objet, ResetContainers.lua:79-97) ;
--- les envoyer aussi les doublerait chez eux.
function Crate.onRefill(container)
    local vehicle = vehicleOf(container)
    local modData = vehicle and vehicle:getModData()
    local dropId = modData and modData[Crate.DROP_KEY]
    local items = Crate.itemsOf(container)
    local before = Crate.formatCounts(Crate.summarize(items))
    if dropId == nil then
        MilitaryDrop.log("crate contents: supply crate trunk" .. where(vehicle) .. " filled without a drop id"
            .. " (outside Crate.spawn, by the engine or another mod): random supply cases; trunk held " .. before, true)
        addEntries(container, Crate.contentsFor(nil), nil)
        return
    end
    local prefix = "crate container refilled by another mod (forceVehicleDistribution?) for drop "
        .. tostring(dropId) .. where(vehicle) .. ": "
    if countTagged(items, dropId) > 0 then
        MilitaryDrop.log(prefix .. "the order is still there, nothing added; trunk holds " .. before, true)
        return
    end
    if modData[Crate.RESTORED_KEY] or not canRestore(dropId) then
        MilitaryDrop.log(prefix .. "drop already emptied, closed or restored once, nothing added; trunk holds "
            .. before, true)
        return
    end
    modData[Crate.RESTORED_KEY] = true
    local entries = Crate.contentsFor(dropId)
    addEntries(container, entries, dropId)
    MilitaryDrop.log(prefix .. "order restored (" .. Crate.formatCounts(countEntries(entries))
        .. "); the other mod's distribution had put " .. before, true)
end

function Crate.onFillContainer(roomType, _, container)
    if roomType ~= Crate.SCRIPT or not instanceof(container, "ItemContainer") then
        return
    end
    if fillingDropId == nil then
        Crate.onRefill(container)
        return
    end
    local entries = Crate.contentsFor(fillingDropId)
    if spawnReport then
        spawnReport.fills = spawnReport.fills + 1
        if spawnReport.fills == 1 then
            local counts, total = Crate.summarize(Crate.itemsOf(container))
            spawnReport.expected = entries
            spawnReport.before = { counts = counts, total = total }
        end
    end
    addEntries(container, entries, fillingDropId)
end

--- Une ligne par caisse posée, toujours écrite : commande, contenu du coffre
--- juste après addVehicleDebug (distribution du moteur, notre ajout, puis
--- les abonnés d'OnFillContainer inscrits après nous : Event.trigger les
--- appelle dans l'ordre d'inscription, une erreur de l'un n'arrête pas les
--- suivants, Event.java:53-63), et si notre remplissage a eu lieu. Alerte en
--- plus si le contenu diffère de la commande.
function Crate.reportDelivery(vehicle, dropId, report)
    report = report or { fills = 0 }
    local items = Crate.itemsOf(Crate.trunkOf(vehicle))
    local expected, expectedTotal = countEntries(report.expected)
    local found, foundTotal = Crate.summarize(items)
    local fill = report.fills == 1 and "once" or (report.fills == 0 and "NOT RECEIVED" or (report.fills .. " times"))
    local matches = items ~= nil and report.fills == 1 and sameCounts(expected, found)
    MilitaryDrop.log(string.format("crate contents for drop %s%s (%s): %s%s, our OnFillContainer fill: %s",
        tostring(dropId), where(vehicle), Crate.describeOrder(dropId),
        items and Crate.formatCounts(found, foundTotal) or "trunk not readable",
        matches and ", as ordered" or "", fill), true)
    if matches then
        return
    end
    local details = {}
    local before = report.before
    if before and before.total > 0 then
        details[#details + 1] = "before our fill the trunk already held " .. Crate.formatCounts(before.counts, before.total)
    end
    if report.fills == 0 then
        details[#details + 1] = "our fill never ran (crate distribution missing or replaced?)"
    end
    MilitaryDrop.log(string.format("crate contents differ from the order: drop %s, expected %s, found %s%s"
        .. " — another mod may fill vehicle containers", tostring(dropId),
        Crate.formatCounts(expected, expectedTotal),
        items and Crate.formatCounts(found, foundTotal) or "nothing readable",
        #details > 0 and " (" .. table.concat(details, "; ") .. ")" or ""), true)
end

--- Fait apparaître la caisse sur la case (chargée) ; renvoie le véhicule ou nil.
--- dropId : largage, posé sur chaque caisse de ravitaillement du coffre et
--- dans la ModData de la caisse (Crate.protect).
--- addVehicleDebug renvoie le véhicule même quand sa position est refusée
--- (collision avec un autre véhicule), sans l'ajouter au monde : seul un
--- véhicule ajouté reçoit un identifiant de base (VehiclesDB2.addVehicle).
function Crate.spawn(square, dropId)
    if square:getVehicleContainer() then
        return nil
    end
    -- Une erreur Java laisserait fillingDropId posé : seul Crate.spawn crée ce
    -- véhicule, et il le repose à chaque appel.
    fillingDropId = dropId
    spawnReport = { fills = 0 }
    local vehicle = addVehicleDebug(Crate.FULL_SCRIPT, IsoDirections.getRandom(), 0, square)
    fillingDropId = nil
    local report = spawnReport
    spawnReport = nil
    if vehicle and vehicle:getSqlId() ~= -1 then
        -- Déjà fait par Crate.onSpawnVehicleEnd pendant addVehicleDebug ;
        -- repris ici si l'événement n'est pas parvenu.
        Crate.protect(vehicle, dropId)
        Crate.reportDelivery(vehicle, dropId, report)
        return vehicle
    end
    return nil
end

Events.OnPostDistributionMerge.Add(Crate.registerDistribution)
Events.OnFillContainer.Add(Crate.onFillContainer)
Events.OnSpawnVehicleEnd.Add(Crate.onSpawnVehicleEnd)
Events.OnServerStarted.Add(Crate.reportDistribution)
Events.OnGameStart.Add(Crate.reportDistribution)

return Crate
