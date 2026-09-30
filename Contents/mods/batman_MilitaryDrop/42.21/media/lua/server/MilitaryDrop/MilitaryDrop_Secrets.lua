-- ============================================================================
-- Military Drop — secrets de la partie (serveur MP ou solo)
--
-- Tout client connecté peut lire une ModData globale (ModData.request,
-- GlobalModData.receiveRequest, 42.21) : les secrets n'y sont jamais. Ils sont
-- gardés dans des fichiers du serveur, propres à la partie :
--   Zomboid/Lua/MilitaryDrop/<mode>_<partie>_code.txt : code fixe (AuthCode 2) ;
--   Zomboid/Lua/MilitaryDrop/<mode>_<partie>_seed.txt : graine des codes de la
--     semaine, des tables du carnet et de la fréquence de la station.
--
-- La graine est lue dès OnLoadRadioScripts (station de chiffres), avant le
-- chargement de la ModData : elle n'en dépend pas.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Codes"

local Codes = MilitaryDrop.Codes

local Secrets = {}
MilitaryDrop.Secrets = Secrets

Secrets.MODDATA_TAG = "MilitaryDrop"

local fixedCode = nil
local seed = nil

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

return Secrets
