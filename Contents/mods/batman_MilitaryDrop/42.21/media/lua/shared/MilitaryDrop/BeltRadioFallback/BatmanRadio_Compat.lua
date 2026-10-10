-- Copie de secours de Belt Walkie-Talkie (batman_BeltRadio 1.0.0), générée par
-- BeltRadio/tools/sync_fallback.py depuis media/lua/shared/BatmanRadio/BatmanRadio_Compat.lua :
-- ne pas modifier ici. Elle ne fait rien si batman_BeltRadio est activé (le mod
-- commun s'en charge) ; sinon elle garde les globales BatmanRadioSupport et
-- BatmanBeltRadioBattery, si bien que deux copies de secours (deux mods sans
-- batman_BeltRadio) se remplacent au lieu de s'additionner.
local beltRadioActive = false
do
    local mods = getActivatedMods and getActivatedMods()
    for i = 0, (mods and mods:size() or 0) - 1 do
        if string.gsub(mods:get(i), "^\\", "") == "batman_BeltRadio" then beltRadioActive = true end
    end
end
if beltRadioActive then return end

-- Belt Walkie-Talkie (batman_BeltRadio), source unique du récepteur commun BatmanRadio.
-- Adaptation de nos scénarios à BWT, sans modifier ses fichiers ni sa VOIP.
local Compat = {}

function Compat.hasBWT()
    local mods = getActivatedMods and getActivatedMods()
    if not mods then return false end
    for i = 0, mods:size() - 1 do
        local id = mods:get(i):gsub("^\\", "")
        if id == "BetterWalkieTalkies" or id == "BetterWalkieTalkiesDev" then return true end
    end
    return false
end

-- Politique commune, réévaluée à l'appel : l'installation ou une globale
-- laissée par un rechargement ne prouvent pas l'activation du mod.
function Compat.features()
    local active = Compat.hasBWT()
    local client, server = isClient(), isServer()
    local bwt = active and client and not server and BetterWalkieTalkies
    local bridge = bwt and bwt.RadioTextBridgeHandler
    return {
        bwtActive = active,
        -- Respecter BatteryDrain même désactivé : BWT reste propriétaire.
        beltBattery = not server and not active,
        -- BWT ne remplace pas la réception des stations à la ceinture en solo.
        scenarioReception = not client and not server,
        -- Bulle MP d'une radio non tenue (BatmanRadio_Core.onDeviceTextMP).
        -- BWT n'affiche aucune ligne de chaîne (ni AddDeviceText ni bulle dans
        -- ses Lua 42.20) mais garde ses radios en MP : rien d'ajouté avec lui.
        mpBubble = client and not server and not active,
        -- La fonction peut apparaître après le chargement de notre module.
        radioTextBridge = type(bridge) == "function" and bridge or nil,
    }
end

function Compat.microphoneAvailable(data)
    if not data:getMicIsMuted() then return true end
    local bridge = Compat.features().radioTextBridge
    if type(bridge) ~= "function" then return false end
    -- Le bridge BWT sait distinguer son silence PTT d'un micro volontairement
    -- coupé. Une requête sans parole suffit ; il protège la VOIP et restaure
    -- les micros. Ne pas ignorer globalement getMicIsMuted avec BWT installé.
    return bridge(function() return not data:getMicIsMuted() end, nil)
end

function Compat.say(player, text)
    local function speak(message) return player:Say(message) end
    local bridge = Compat.features().radioTextBridge
    if type(bridge) == "function" then return bridge(speak, text) end
    return speak(text)
end

return Compat
