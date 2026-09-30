-- ============================================================================
-- Military Drop — fumée de repérage sur la caisse (serveur MP ou solo)
--
-- Intégration facultative avec Signal Smoke (id batman_SignalSmoke, projet
-- Zomboid\Workshop\SignalSmoke) : si ce mod est actif, une fumée verte marque
-- la caisse quand elle est posée (un joueur approche : la zone vient de se
-- charger). Cause dans le monde : le fumigène fixé à la caisse. Sans Signal
-- Smoke, rien ne se passe : Military Drop reste autonome (aucun require dans
-- mod.info).
--
-- Signal Smoke tient le registre des fumées (ModData globale, transmise aux
-- clients) ; chaque client dessine la fumée, et elle est reprise au
-- chargement. Durée : option CrateSmokeMinutes (0 = aucune fumée).
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"

local Config = MilitaryDrop.Config

local Smoke = {}
MilitaryDrop.Smoke = Smoke

Smoke.MOD_ID = "batman_SignalSmoke"
Smoke.MODULE = "SignalSmoke/SignalSmoke"
Smoke.COLOR = "green"
Smoke.RADIUS = 1

-- nil : pas encore cherché ; false : absent ; sinon le module de Signal Smoke.
local api = nil

--- Le mod est actif dans cette partie (liste Java des IDs, « \ » initial possible).
function Smoke.modActive()
    local mods = getActivatedMods()
    for i = 0, mods:size() - 1 do
        local id = tostring(mods:get(i)):gsub("^\\", "")
        if id == Smoke.MOD_ID then
            return true
        end
    end
    return false
end

--- Module public de Signal Smoke, cherché une fois (require seulement si le mod
--- est actif : sinon, le jeu journaliserait un require manqué).
function Smoke.api()
    if api == nil then
        api = false
        if Smoke.modActive() then
            local module = require(Smoke.MODULE)
            if type(module) == "table" and type(module.start) == "function" then
                api = module
                MilitaryDrop.log("Signal Smoke found: crates are marked with smoke")
            else
                MilitaryDrop.log("Signal Smoke is active but its module could not be loaded", true)
            end
        end
    end
    return api or nil
end

--- Fumée verte sur la caisse posée en (x, y). Renvoie l'identifiant, ou nil.
function Smoke.markCrate(x, y)
    local minutes = tonumber(Config.get("CrateSmokeMinutes")) or 0
    local signalSmoke = minutes > 0 and Smoke.api()
    if not signalSmoke then
        return nil
    end
    local id, err = signalSmoke.start({
        id = "MilitaryDrop:crate:" .. x .. "," .. y,
        x = x, y = y, z = 0,
        color = Smoke.COLOR,
        radius = Smoke.RADIUS,
        minutes = minutes,
        light = true,
        owner = "MilitaryDrop",
    })
    if not id then
        MilitaryDrop.log("crate smoke refused by Signal Smoke: " .. tostring(err), true)
    end
    return id
end

return Smoke
