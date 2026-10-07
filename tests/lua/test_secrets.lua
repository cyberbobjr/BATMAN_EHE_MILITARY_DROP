-- MilitaryDrop_Secrets : graine et code fixe gardés pour un monde qui continue,
-- tirés de nouveau pour un monde neuf (OnLoadRadioScripts, isNewGame), même si
-- un fichier du même nom de partie existe (serveur MP remis à zéro).

local T = {}

local SEED_FILE = "MilitaryDrop/Multiplayer_servertest_seed.txt"
local CODE_FILE = "MilitaryDrop/Multiplayer_servertest_code.txt"

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return true end
    DRAWS = { 1000, 2000, 3000, 4000 }
    ZombRand = function(n)
        local value = table.remove(DRAWS, 1) or 7
        return value % n
    end
    FILES = { [SEED_FILE] = "123456789", [CODE_FILE] = "OLDCODE" }
    getWorld = function()
        return { getGameMode = function() return "Multiplayer" end, getWorld = function() return "servertest" end }
    end
    getFileReader = function(name)
        local value = FILES[name]
        if not value then
            return nil
        end
        return { readLine = function() return value end, close = function() end }
    end
    getFileWriter = function(name)
        return { write = function(_, text) FILES[name] = text end, close = function() end }
    end
    MODDATA = {}
    ModData = { getOrCreate = function(tag)
        MODDATA[tag] = MODDATA[tag] or {}
        return MODDATA[tag]
    end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Secrets.lua")
end

function T.continuing_world_keeps_its_secrets()
    triggerEvent("OnLoadRadioScripts", {}, false)
    local Secrets = MilitaryDrop.Secrets
    assertEq(Secrets.getSeed(), 123456789, "graine du fichier")
    assertEq(Secrets.getFixedCode(), "OLDCODE", "code du fichier")
    assertEq(FILES[SEED_FILE], "123456789", "fichier inchangé")
end

function T.new_world_draws_new_secrets_over_old_files()
    local Secrets = MilitaryDrop.Secrets
    local oldTag = Secrets.privateTag()
    triggerEvent("OnLoadRadioScripts", {}, true)
    local seed = Secrets.getSeed()
    assertTrue(seed ~= 123456789, "graine tirée de nouveau")
    assertEq(FILES[SEED_FILE], string.format("%d", seed), "fichier de graine réécrit")
    assertTrue(Secrets.privateTag() ~= oldTag, "nouvel état privé")
    local code = Secrets.getFixedCode()
    assertTrue(code ~= "OLDCODE", "code fixe tiré de nouveau")
    assertEq(FILES[CODE_FILE], code, "fichier du code réécrit")
    assertEq(Secrets.getSeed(), seed, "stable ensuite")
end

function T.restart_after_a_new_world_keeps_the_renewed_secrets()
    triggerEvent("OnLoadRadioScripts", {}, true)
    local seed = MilitaryDrop.Secrets.getSeed()
    local code = MilitaryDrop.Secrets.getFixedCode()
    -- Redémarrage : monde sauvegardé, Lua rechargé.
    T.setup()
    FILES[SEED_FILE], FILES[CODE_FILE] = string.format("%d", seed), code
    triggerEvent("OnLoadRadioScripts", {}, false)
    assertEq(MilitaryDrop.Secrets.getSeed(), seed, "même graine")
    assertEq(MilitaryDrop.Secrets.getFixedCode(), code, "même code")
end

return T
