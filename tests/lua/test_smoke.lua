-- MilitaryDrop_Smoke : fumée verte sur la caisse posée, seulement si Signal
-- Smoke est actif (intégration facultative, aucun require sans le mod).

local T = {}

--- Liste Java simulée des mods actifs.
local function modList(ids)
    return {
        size = function() return #ids end,
        get = function(_, i) return ids[i + 1] end,
    }
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return false end
    ACTIVE = {}
    getActivatedMods = function() return modList(ACTIVE) end
    STARTED = {}
    REQUIRED = {}
    SIGNAL_SMOKE = { start = function(opts)
        STARTED[#STARTED + 1] = opts
        return opts.id
    end }
    require = function(name)
        REQUIRED[#REQUIRED + 1] = name
        return name == "SignalSmoke/SignalSmoke" and SIGNAL_SMOKE or nil
    end
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Smoke.lua")
    -- Seuls comptent les require faits après le chargement du fichier.
    REQUIRED = {}
end

function T.no_smoke_and_no_require_without_signal_smoke()
    ACTIVE = { "batman_MilitaryDrop" }
    assertEq(MilitaryDrop.Smoke.markCrate(10, 20), nil, "pas de fumée")
    assertEq(#REQUIRED, 0, "aucun require : pas d'avertissement « require failed » au journal")
end

function T.green_smoke_on_the_crate_with_signal_smoke()
    ACTIVE = { "batman_MilitaryDrop", "\\batman_SignalSmoke" }
    local id = MilitaryDrop.Smoke.markCrate(10, 20)
    assertEq(id, "MilitaryDrop:crate:10,20", "identifiant stable (appel idempotent)")
    local opts = STARTED[1]
    assertEq(opts.x, 10, "x de la caisse")
    assertEq(opts.y, 20, "y de la caisse")
    assertEq(opts.z, 0, "au sol")
    assertEq(opts.color, "green", "vert")
    assertEq(opts.minutes, 60, "durée par défaut")
    assertEq(opts.owner, "MilitaryDrop", "propriétaire")
end

function T.option_zero_disables_the_smoke()
    ACTIVE = { "batman_SignalSmoke" }
    SandboxVars.MilitaryDrop.CrateSmokeMinutes = 0
    assertEq(MilitaryDrop.Smoke.markCrate(10, 20), nil, "option à 0")
    assertEq(#STARTED, 0, "rien demandé à Signal Smoke")
    SandboxVars.MilitaryDrop.CrateSmokeMinutes = 15
    MilitaryDrop.Smoke.markCrate(10, 20)
    assertEq(STARTED[1].minutes, 15, "durée de l'option")
end

function T.module_is_looked_up_once()
    ACTIVE = { "batman_SignalSmoke" }
    MilitaryDrop.Smoke.markCrate(1, 2)
    MilitaryDrop.Smoke.markCrate(3, 4)
    assertEq(#REQUIRED, 1, "un seul require")
    assertEq(#STARTED, 2, "deux fumées")
end

function T.broken_module_is_ignored()
    ACTIVE = { "batman_SignalSmoke" }
    SIGNAL_SMOKE = nil
    require = function() return nil end
    assertEq(MilitaryDrop.Smoke.markCrate(10, 20), nil, "module absent : pas d'erreur")
end

return T
