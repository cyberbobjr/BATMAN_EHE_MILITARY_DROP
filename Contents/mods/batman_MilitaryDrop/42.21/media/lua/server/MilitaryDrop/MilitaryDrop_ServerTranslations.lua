-- ============================================================================
-- Military Drop — traductions du mod sur un serveur MP (dédié ou hébergé)
--
-- Un serveur MP lit les traductions avant de charger les mods
-- (GameServer.java:637-639, loadMods à :1355) et ne les relit jamais : getText
-- y renvoie les clés du mod brutes. Or la station de chiffres, les notes et les
-- documents sont composés sur le serveur. Quand ce fichier s'exécute, les mods
-- sont chargés (loadMods précède LuaManager.init, :1355-1356) : un
-- rechargement, comme le menu de debug vanilla (ISDebugMenu.lua:283), ajoute
-- leurs traductions. Les textes restent dans la langue du serveur.
-- Solo : traductions déjà présentes, rien à faire.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"

local ServerTranslations = {}
MilitaryDrop.ServerTranslations = ServerTranslations

-- Clé sans paramètre : getTextOrNull ne signale aucun argument manquant.
ServerTranslations.PROBE_KEY = "IGUI_MilitaryDrop_Doc_Letterhead1"

--- Recharge les traductions si celles du mod manquent ; vrai si rechargées.
function ServerTranslations.ensure()
    if getTextOrNull(ServerTranslations.PROBE_KEY) ~= nil then
        return false
    end
    if not (Translator and Translator.loadFiles) then
        MilitaryDrop.log("mod translations missing on the server and Translator.loadFiles unavailable", true)
        return false
    end
    Translator.loadFiles()
    local loaded = getTextOrNull(ServerTranslations.PROBE_KEY) ~= nil
    MilitaryDrop.log(loaded and "mod translations reloaded on the server"
        or "mod translations still missing on the server after reload", true)
    return loaded
end

ServerTranslations.ensure()
