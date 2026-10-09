-- SOURCE COMMUNE : MilitaryDrop/source/radio/lua ; copies générées par sync_radio.py.
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
