-- MilitaryDrop_ServerTranslations : rechargement des traductions sur un serveur
-- MP qui les a lues avant de charger les mods (clés brutes).

local T = {}

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return true end
    LOADED = false
    RELOADS = 0
    getTextOrNull = function(key)
        if LOADED and key == "IGUI_MilitaryDrop_Doc_Letterhead1" then
            return "DEPARTMENT OF THE ARMY"
        end
        return nil
    end
    Translator = { loadFiles = function()
        RELOADS = RELOADS + 1
        LOADED = true
    end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
end

function T.missing_mod_translations_are_reloaded_at_load()
    loadMod("server/MilitaryDrop/MilitaryDrop_ServerTranslations.lua")
    assertEq(RELOADS, 1, "un rechargement au chargement du fichier")
    assertEq(MilitaryDrop.ServerTranslations.ensure(), false, "déjà présentes : rien à refaire")
    assertEq(RELOADS, 1, "pas de second rechargement")
end

function T.present_translations_are_not_reloaded()
    LOADED = true
    loadMod("server/MilitaryDrop/MilitaryDrop_ServerTranslations.lua")
    assertEq(RELOADS, 0, "solo ou traductions déjà lues : aucun rechargement")
end

function T.client_does_nothing()
    isClient = function() return true end
    loadMod("server/MilitaryDrop/MilitaryDrop_ServerTranslations.lua")
    assertEq(RELOADS, 0, "client : rien")
    assertEq(MilitaryDrop.ServerTranslations, nil, "module absent côté client")
end

return T
