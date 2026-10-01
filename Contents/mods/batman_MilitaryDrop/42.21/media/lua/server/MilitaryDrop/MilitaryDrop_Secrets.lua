-- ============================================================================
-- Military Drop — secrets de la partie (serveur MP ou solo)
--
-- Tout client connecté peut lire une ModData globale (ModData.request,
-- GlobalModData.receiveRequest, 42.21) : les secrets n'y sont jamais. Ils sont
-- gardés dans des fichiers du serveur, propres à la partie :
--   Zomboid/Lua/MilitaryDrop/<mode>_<partie>_code.txt : code fixe (AuthCode 2) ;
--   Zomboid/Lua/MilitaryDrop/<mode>_<partie>_seed.txt : graine des codes de la
--     semaine, des tables du carnet, des fréquences libres (station de
--     chiffres, chaîne militaire) et du nom de l'état privé.
--
-- La graine est lue dès OnLoadRadioScripts (station de chiffres, chaîne
-- militaire), avant le chargement de la ModData : elle n'en dépend pas.
--
-- État privé de la v1.3 (équipes, confiance, largages, missions, plaques,
-- postes de liaison) : une table de ModData globale dont le nom est tiré de la
-- graine (Secrets.privateTag). ModData.request ne rend une table qu'à qui en
-- donne le nom exact (GlobalModData.receiveRequest, 42.21), et le serveur ne
-- publie jamais la liste de ses tables : ce nom ne quitte pas le serveur,
-- la table n'est jamais transmise. Elle est sauvegardée avec la partie comme
-- toute ModData globale. La table publique « MilitaryDrop »
-- (MilitaryDrop.Server.getState) ne garde que les vols, les livraisons en
-- attente et le délai global.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Codes"

local Codes = MilitaryDrop.Codes

local Secrets = {}
MilitaryDrop.Secrets = Secrets

Secrets.MODDATA_TAG = "MilitaryDrop"

Secrets.PRIVATE_PREFIX = "MilitaryDrop_"

local fixedCode = nil
local seed = nil
local privateTag = nil

--- Fichier propre à la partie (dossier Lua du serveur ou du joueur).
function Secrets.file(suffix)
    local world = getWorld()
    local key = tostring(world:getGameMode()) .. "_" .. tostring(world:getWorld())
    return "MilitaryDrop/" .. key:gsub("[^%w_%-]", "_") .. "_" .. suffix .. ".txt"
end

local function readLine(file)
    local reader = getFileReader(file, false)
    if not reader then
        return nil
    end
    local line = reader:readLine()
    reader:close()
    if type(line) == "string" and line ~= "" then
        return line
    end
    return nil
end

local function writeLine(file, text, what)
    local writer = getFileWriter(file, true, false)
    if writer then
        writer:write(text)
        writer:close()
        MilitaryDrop.log(what .. " stored in " .. file)
    else
        MilitaryDrop.log("cannot write " .. file .. ": the " .. what .. " will change at the next restart", true)
    end
end

--- Code fixe de la partie, tiré à la première lecture.
function Secrets.getFixedCode()
    if fixedCode then
        return fixedCode
    end
    local file = Secrets.file("code")
    local state = ModData.getOrCreate(Secrets.MODDATA_TAG)
    fixedCode = readLine(file)
    if not fixedCode then
        -- Reprise d'une version de développement qui le gardait en ModData.
        fixedCode = type(state.code) == "string" and state.code ~= "" and state.code or Codes.generate()
        writeLine(file, fixedCode, "authentication code")
    end
    state.code = nil
    return fixedCode
end

--- Graine secrète de la partie (entier de 1 à 2^31 - 2), tirée à la première lecture.
function Secrets.getSeed()
    if seed then
        return seed
    end
    local file = Secrets.file("seed")
    seed = Codes.validSeed(readLine(file))
    if not seed then
        -- ZombRand est borné aux entiers Java : deux tirages combinés.
        seed = ZombRand(46340) * 46340 + ZombRand(46340) + 1
        writeLine(file, string.format("%d", seed), "code seed")
    end
    return seed
end

--- Nom de la table de ModData privée : « MilitaryDrop_ » et 12 chiffres
--- hexadécimaux tirés de la graine (stable pour une même partie).
function Secrets.privateTag()
    if not privateTag then
        local rand = Codes.newRandom(Secrets.getSeed(), Codes.USE_PRIVATE_STATE)
        privateTag = Secrets.PRIVATE_PREFIX .. string.format("%04x%04x%04x", rand(65536), rand(65536), rand(65536))
    end
    return privateTag
end

--- État privé de la partie (jamais transmis aux clients). Relu à chaque usage :
--- la ModData globale est vidée puis relue juste avant OnInitGlobalModData
--- (GlobalModData.init), une table gardée d'avant serait perdue.
function Secrets.privateState()
    return ModData.getOrCreate(Secrets.privateTag())
end

return Secrets
