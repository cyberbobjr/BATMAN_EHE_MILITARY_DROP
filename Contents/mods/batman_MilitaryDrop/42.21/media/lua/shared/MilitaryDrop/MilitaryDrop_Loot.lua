-- ============================================================================
-- Military Drop — contenu des caisses de ravitaillement
--
-- Aucun nom d'objet n'est écrit ici. Chaque caisse tire ses objets des tables
-- de butin du jeu (ProceduralDistributions), telles qu'elles sont après la
-- fusion de tous les mods actifs, et les reconnaît par leur catégorie :
--   * arme : arme à feu (script : ItemType WEAPON, isRanged et dégâts > 0, ce
--     qui écarte les pistolets à amorces, jouets sans dégâts) ;
--   * munitions : chargeur ou boîte de munitions d'une arme à feu existante
--     (lus sur l'arme : getMagazineType, getAmmoBox) ;
--   * équipement : vêtement qui protège des balles (getBulletDefense > 0) ;
--   * accessoire : pièce d'arme (ItemType WEAPON_PART).
-- Une caisse lit d'abord la table de l'armée correspondante ; si elle manque
-- ou ne donne rien (mod qui la vide), toutes les tables, filtrées par la
-- catégorie. Les poids des tables sont conservés (additionnés d'une table à
-- l'autre).
--
-- Un nom de table sans module est cherché dans tous les modules (le
-- ScriptManager ne cherche que dans Base : ScriptBucketCollection, 42.21).
-- Les listes calculées sont gardées en mémoire, vides comprises : les tables
-- ne changent plus après le chargement. Loot.warm calcule plusieurs caisses
-- d'un seul passage sur toutes les tables (~34 000 entrées en 42.21) et
-- n'appelle le filtre d'une caisse qu'une fois par type d'objet ; un filtre
-- teste d'abord le script (catégorie, propriétés, tags) et n'instancie un
-- objet qu'en dernier recours.
--
-- Extension : MilitaryDrop.Loot.CASES[type].sources est remplaçable par un
-- mod de compatibilité.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Loot = {}
MilitaryDrop.Loot = Loot

-- Avec chaque arme à feu : ses chargeurs et une boîte de ses munitions.
Loot.MAGAZINES_PER_WEAPON = 2
Loot.AMMO_BOXES_PER_WEAPON = 1

local scriptCache = {}
local candidateCache = {}
local firearmSupplies = nil
local armorCache = {}

--- Script d'objet d'un nom de table (« Module.Objet » ou « Objet »), ou nil.
function Loot.resolve(name)
    if scriptCache[name] ~= nil then
        return scriptCache[name] or nil
    end
    local manager = getScriptManager()
    local script = manager:FindItem(name)
    if not script and not string.find(name, ".", 1, true) then
        local found = manager:getItemsByType(name)
        script = found and found:size() > 0 and found:get(0) or nil
    end
    scriptCache[name] = script or false
    return script
end

-- ----------------------------------------------------------------------------
-- Catégories (reconnues par le jeu, sans liste de noms)
-- ----------------------------------------------------------------------------

function Loot.isFirearm(script)
    return script:getItemType() == ItemType.WEAPON and script:isRanged() and script:getMaxDamage() > 0
end

function Loot.isWeaponPart(script)
    return script:getItemType() == ItemType.WEAPON_PART
end

function Loot.isNotContainer(script)
    return script:getItemType() ~= ItemType.CONTAINER
end

--- Chargeurs et boîtes de munitions de toutes les armes à feu du jeu.
function Loot.firearmSupplies()
    if firearmSupplies then
        return firearmSupplies
    end
    firearmSupplies = {}
    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local script = scripts:get(i)
        if Loot.isFirearm(script) then
            local weapon = instanceItem(script:getFullName())
            if weapon and instanceof(weapon, "HandWeapon") then
                for _, fullType in ipairs({ weapon:getMagazineType() or "", weapon:getAmmoBox() or "" }) do
                    if fullType ~= "" then
                        firearmSupplies[fullType] = true
                    end
                end
            end
        end
    end
    return firearmSupplies
end

function Loot.isAmmo(script)
    return Loot.firearmSupplies()[script:getFullName()] == true
end

--- Vêtement qui protège des balles (lu sur un exemplaire, gardé en mémoire).
function Loot.isArmor(script)
    if script:getItemType() ~= ItemType.CLOTHING then
        return false
    end
    local fullType = script:getFullName()
    if armorCache[fullType] == nil then
        local item = instanceItem(fullType)
        armorCache[fullType] = item ~= nil and instanceof(item, "Clothing") and item:getBulletDefense() > 0
    end
    return armorCache[fullType]
end

-- ----------------------------------------------------------------------------
-- Tables de butin
-- ----------------------------------------------------------------------------

local function proceduralLists()
    return ProceduralDistributions and ProceduralDistributions.list or {}
end

--- Tables nommées (nil = toutes), sous forme de listes { nom, poids, … }.
function Loot.tables(names)
    local lists = proceduralLists()
    local result = {}
    if names then
        for _, name in ipairs(names) do
            local entry = lists[name]
            if entry and entry.items then
                result[#result + 1] = entry.items
            end
        end
    else
        for _, entry in pairs(lists) do
            if type(entry) == "table" and entry.items then
                result[#result + 1] = entry.items
            end
        end
    end
    return result
end

--- Sources de chaque caisse, dans l'ordre : la première qui donne au moins un
--- objet est utilisée. tables = nil : toutes les tables du jeu.
Loot.CASES = {
    ["MilitaryDrop.AmmoSupplyCase"] = {
        picks = 5,
        sources = {
            -- Les sacs de munitions de la table arrivent vides hors du
            -- remplissage des conteneurs : seulement les boîtes et chargeurs.
            { tables = { "ArmyStorageAmmunition" }, accept = Loot.isNotContainer },
            { accept = Loot.isAmmo },
        },
    },
    ["MilitaryDrop.WeaponSupplyCase"] = {
        picks = 1,
        sources = {
            { tables = { "ArmyStorageGuns" }, accept = Loot.isFirearm },
            { accept = Loot.isFirearm },
        },
    },
    ["MilitaryDrop.ArmorSupplyCase"] = {
        picks = 5,
        sources = {
            { tables = { "ArmyStorageOutfit" } },
            { accept = Loot.isArmor },
        },
    },
    ["MilitaryDrop.AttachmentSupplyCase"] = {
        picks = 5,
        sources = {
            { accept = Loot.isWeaponPart },
        },
    },
}

--- Liste { {name, weight}, … } à partir d'une table { nom, poids, nom, poids… },
--- sans les poids nuls, négatifs ou illisibles.
function Loot.toEntries(flat)
    local entries = {}
    for i = 1, #flat - 1, 2 do
        local name, weight = flat[i], tonumber(flat[i + 1])
        if type(name) == "string" and weight and weight > 0 then
            entries[#entries + 1] = { name = name, weight = weight }
        end
    end
    return entries
end

--- Tire une entrée selon les poids (décimaux permis). rand(total) doit
--- renvoyer un nombre dans [0, total[.
function Loot.pickWeighted(entries, rand)
    local total = 0
    for _, entry in ipairs(entries) do
        total = total + entry.weight
    end
    if total <= 0 then
        return nil
    end
    local point = rand(total)
    local sum = 0
    for _, entry in ipairs(entries) do
        sum = sum + entry.weight
        if point < sum then
            return entry
        end
    end
    return entries[#entries]
end

local function gameRand(total)
    return ZombRandFloat(0, total)
end

--- Un seul passage sur des listes { nom, poids, … } pour plusieurs sources :
--- objets acceptés par chacune, poids additionnés par type complet. Le filtre
--- d'une source n'est appelé qu'une fois par type complet.
local function collectMany(flats, sources)
    local results, byType = {}, {}
    for i = 1, #sources do
        results[i], byType[i] = {}, {}
    end
    -- nom de table → type complet (false : objet inconnu) ; type → sources qui l'acceptent.
    local fullTypes, verdicts = {}, {}
    for _, flat in ipairs(flats) do
        for _, entry in ipairs(Loot.toEntries(flat)) do
            local fullType = fullTypes[entry.name]
            local script = nil
            if fullType == nil then
                script = Loot.resolve(entry.name)
                fullType = script and script:getFullName() or false
                fullTypes[entry.name] = fullType
            end
            if fullType then
                local accepted = verdicts[fullType]
                if not accepted then
                    script = script or Loot.resolve(entry.name)
                    accepted = {}
                    for i, source in ipairs(sources) do
                        if not source.accept or source.accept(script) then
                            accepted[#accepted + 1] = i
                        end
                    end
                    verdicts[fullType] = accepted
                end
                for _, i in ipairs(accepted) do
                    local known = byType[i][fullType]
                    if known then
                        known.weight = known.weight + entry.weight
                    else
                        known = { name = entry.name, fullType = fullType, weight = entry.weight }
                        byType[i][fullType] = known
                        results[i][#results[i] + 1] = known
                    end
                end
            end
        end
    end
    return results
end

--- Calcule et garde les candidats de plusieurs caisses (clés de Loot.CASES).
--- Source par source (la première non vide gagne) ; à chaque rang, toutes les
--- sources « toutes les tables » partagent un seul passage. Un résultat vide
--- est gardé aussi, sauf si le jeu n'a encore aucune table (avant la fusion
--- des distributions).
function Loot.warm(caseTypes)
    local waiting, queued = {}, {}
    for _, caseType in ipairs(caseTypes or {}) do
        if candidateCache[caseType] == nil and not queued[caseType] then
            queued[caseType] = true
            waiting[#waiting + 1] = caseType
        end
    end
    if #waiting == 0 then
        return
    end
    local keepEmpty = #Loot.tables() > 0
    local rank = 1
    while #waiting > 0 do
        local still, shared, sharedKeys = {}, {}, {}
        local function settle(caseType, result)
            if #result > 0 then
                candidateCache[caseType] = result
            else
                still[#still + 1] = caseType
            end
        end
        for _, caseType in ipairs(waiting) do
            local case = Loot.CASES[caseType]
            local source = case and case.sources and case.sources[rank]
            if not source then
                if keepEmpty then
                    candidateCache[caseType] = {}
                end
            elseif source.tables then
                settle(caseType, collectMany(Loot.tables(source.tables), { source })[1])
            else
                shared[#shared + 1] = source
                sharedKeys[#sharedKeys + 1] = caseType
            end
        end
        if #shared > 0 then
            local results = collectMany(Loot.tables(), shared)
            for i, caseType in ipairs(sharedKeys) do
                settle(caseType, results[i])
            end
        end
        waiting = still
        rank = rank + 1
    end
end

--- Toutes les caisses connues (Loot.CASES), d'un seul passage par rang.
function Loot.warmAll()
    local keys = {}
    for caseType in pairs(Loot.CASES) do
        keys[#keys + 1] = caseType
    end
    Loot.warm(keys)
end

--- Oublie les listes calculées (mod de compatibilité qui change les sources).
--- prefix (facultatif) : seulement les caisses dont la clé commence par lui
--- (les lots de réquisition, « lot: »), les autres restent calculées.
function Loot.clearCache(prefix)
    if type(prefix) ~= "string" then
        candidateCache = {}
        return
    end
    local stale = {}
    for caseType in pairs(candidateCache) do
        if type(caseType) == "string" and caseType:sub(1, #prefix) == prefix then
            stale[#stale + 1] = caseType
        end
    end
    for _, caseType in ipairs(stale) do
        candidateCache[caseType] = nil
    end
end

--- Entrées valides pour un type de caisse (première source non vide).
function Loot.candidates(caseType)
    if candidateCache[caseType] == nil then
        Loot.warm({ caseType })
    end
    return candidateCache[caseType] or {}
end

--- Types complets des objets à créer pour une caisse ouverte.
function Loot.roll(caseType, rand)
    local case = Loot.CASES[caseType]
    local results = {}
    if not case then
        return results
    end
    local entries = Loot.candidates(caseType)
    if #entries == 0 then
        MilitaryDrop.log("no valid loot for " .. tostring(caseType), true)
        return results
    end
    for _ = 1, case.picks do
        local entry = Loot.pickWeighted(entries, rand or gameRand)
        if entry then
            results[#results + 1] = entry.fullType
        end
    end
    return results
end

--- Types complets à ajouter avec une arme (HandWeapon) : chargeurs et boîte de
--- munitions, s'ils existent dans le jeu.
function Loot.weaponExtras(weapon)
    local extras = {}
    if not instanceof(weapon, "HandWeapon") then
        return extras
    end
    local function add(fullType, count)
        if type(fullType) == "string" and fullType ~= "" and Loot.resolve(fullType) then
            for _ = 1, count do
                extras[#extras + 1] = fullType
            end
        end
    end
    add(weapon:getMagazineType(), Loot.MAGAZINES_PER_WEAPON)
    add(weapon:getAmmoBox(), Loot.AMMO_BOXES_PER_WEAPON)
    return extras
end

return Loot
