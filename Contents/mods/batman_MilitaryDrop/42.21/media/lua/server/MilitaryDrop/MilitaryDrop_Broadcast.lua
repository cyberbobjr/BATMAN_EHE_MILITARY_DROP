-- ============================================================================
-- Military Drop — chaîne radio militaire (serveur MP ou solo)
--
-- Une chaîne dynamique sur la fréquence de l'option sandbox, créée à chaque
-- chargement du monde (OnLoadRadioScripts, avant OnInitGlobalModData). Tout
-- joueur à l'écoute entend l'approche de l'hélicoptère puis les coordonnées
-- du largage (lignes portant le code CODE, que le client repère par
-- OnDeviceText pour marquer sa carte).
--
-- Le nom de la chaîne est retiré de la liste des noms connus : le panneau de
-- la radio (RWMGeneral.lua) affiche le nom de la chaîne réglée, ce qui
-- révélerait la fréquence en balayant les canaux, alors qu'elle doit se
-- trouver sur les notes. La diffusion ne dépend pas de ce nom, et la fréquence
-- reste réservée contre les stations tirées au hasard (knownFrequencies).
--
-- Textes écrits par le serveur : en MP dédié, dans la langue du serveur.
-- Une diffusion n'est pas sauvegardée (DynamicRadioChannel.LoadAiringBroadcast
-- est vide) : rien à restaurer, les annonces sont ponctuelles.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Net"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net

local Broadcast = {}
MilitaryDrop.Broadcast = Broadcast

Broadcast.CHANNEL_NAME = "Military Logistics"
Broadcast.CHANNEL_UUID = "batman_MilitaryDrop-Logistics"
-- Code de 4 caractères : le vanilla ignore les jetons de 4 caractères ou
-- moins (ISRadioInteractions.lua), il ne sert qu'à ce mod.
Broadcast.CODE = "MDRP"
Broadcast.REPEATS = 3
Broadcast.COLOR = { r = 0.45, g = 0.85, b = 0.45 }

local serial = 0

function Broadcast.onLoadRadioScripts(scriptManager)
    local channel = DynamicRadioChannel.new(Broadcast.CHANNEL_NAME, Config.getChannel(), ChannelCategory.Military,
        Broadcast.CHANNEL_UUID)
    scriptManager:AddChannel(channel, false)
    Broadcast.channel = scriptManager:getRadioChannel(Broadcast.CHANNEL_UUID)
    if Broadcast.channel then
        getZomboidRadio():removeChannelName(Config.getChannel())
        MilitaryDrop.log("radio channel on " .. Config.formatChannel(Config.getChannel()) .. " MHz")
    else
        MilitaryDrop.log("radio channel not created: frequency "
            .. Config.formatChannel(Config.getChannel()) .. " MHz already used", true)
    end
end

--- Diffuse des lignes { texte, codes } sur la chaîne militaire.
function Broadcast.air(lines)
    if not Broadcast.channel then
        return false
    end
    serial = serial + 1
    local bc = RadioBroadCast.new("MDRP-" .. serial, -1, -1)
    local c = Broadcast.COLOR
    for _, line in ipairs(lines) do
        bc:AddRadioLine(RadioLine.new(line[1], c.r, c.g, c.b, line[2]))
    end
    Broadcast.channel:setAiringBroadcast(bc)
    return true
end

--- L'hélicoptère décolle : annonce sans coordonnées.
function Broadcast.inbound()
    Broadcast.air({ { getText("IGUI_MilitaryDrop_BroadcastInbound") } })
end

--- Largage effectué : coordonnées répétées, et repère de carte pour les
--- joueurs qui entendent la ligne (MilitaryDrop_Announce.lua).
function Broadcast.dropped(x, y)
    Net.toAll("DropAnnounce", { x = x, y = y })
    local lines = {}
    local text = getText("IGUI_MilitaryDrop_BroadcastDropped", tostring(x), tostring(y))
    for i = 1, Broadcast.REPEATS do
        lines[i] = { text, Broadcast.CODE }
    end
    lines[#lines + 1] = { getText("IGUI_MilitaryDrop_BroadcastOut") }
    Broadcast.air(lines)
end

Events.OnLoadRadioScripts.Add(Broadcast.onLoadRadioScripts)

return Broadcast
