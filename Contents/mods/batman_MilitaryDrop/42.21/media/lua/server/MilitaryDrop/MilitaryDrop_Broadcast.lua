-- ============================================================================
-- Military Drop — chaîne radio militaire (serveur MP ou solo)
--
-- Une chaîne dynamique sur la fréquence militaire, créée à chaque chargement
-- du monde (OnLoadRadioScripts, avant OnInitGlobalModData). Tout
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
-- Fréquence : option Frequency > 0, fixe (publique : les options sandbox sont
-- envoyées à tous les clients) ; 0 (défaut), fréquence libre secrète de la
-- bande BAND_MIN-BAND_MAX (120-170 MHz, pas de 0,2 MHz : radios militaires),
-- dérivée de la graine (MilitaryDrop_Secrets.lua), donc stable d'un
-- chargement à l'autre sans ModData. Les canaux sont essayés dans l'ordre
-- jusqu'à ce que AddChannel réussisse (fréquence déjà prise par une autre
-- chaîne : la suivante). Jamais une fréquence réservée (HEF) ni celle de la
-- station de chiffres (10-25 MHz, ou son option). Seuls le serveur et le solo
-- la connaissent (Broadcast.freeChannel) ; les notes l'écrivent.
--
-- Textes écrits par le serveur : en MP dédié, dans la langue du serveur.
-- Une diffusion n'est pas sauvegardée (DynamicRadioChannel.LoadAiringBroadcast
-- est vide) : rien à restaurer, les annonces sont ponctuelles.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Net"
require "MilitaryDrop/MilitaryDrop_Codes"
require "MilitaryDrop/MilitaryDrop_Secrets"

local Config = MilitaryDrop.Config
local Net = MilitaryDrop.Net
local Codes = MilitaryDrop.Codes

local Broadcast = {}
MilitaryDrop.Broadcast = Broadcast

Broadcast.CHANNEL_NAME = "Military Logistics"
Broadcast.CHANNEL_UUID = "batman_MilitaryDrop-Logistics"
-- Code de 4 caractères : le vanilla ignore les jetons de 4 caractères ou
-- moins (ISRadioInteractions.lua), il ne sert qu'à ce mod.
Broadcast.CODE = "MDRP"
-- Annonce d'une reconnaissance (SRC-03) : repère « Eye » chez qui l'entend
-- (MilitaryDrop.Announce.RECON_CODE, même valeur).
Broadcast.RECON_CODE = "MDRC"
-- Annonce d'un nettoyage (SRC-04) : repère « Skull » chez qui l'entend
-- (MilitaryDrop.Announce.CLEANUP_CODE, même valeur).
Broadcast.CLEANUP_CODE = "MDCU"
Broadcast.REPEATS = 3
-- Rappel de la grille d'un largage en attente (Broadcast.pending).
Broadcast.PENDING_REPEATS = 2
Broadcast.COLOR = { r = 0.45, g = 0.85, b = 0.45 }
-- Bande de la fréquence libre (kHz, comme DeviceData:getChannel()).
Broadcast.BAND_MIN = 120000
Broadcast.BAND_MAX = 170000

local serial = 0

--- Canal de la station de chiffres fixé par son option, ou nil (sa bande
--- libre, 10-25 MHz, ne recoupe pas celle de la chaîne militaire).
local function stationOption()
    local configured = tonumber(Config.get("NumbersStationFrequency")) or 0
    if configured > 0 then
        return Config.toChannel(configured)
    end
    return nil
end

--- Canaux candidats de la fréquence libre, dans l'ordre d'essai : la bande
--- BAND_MIN-BAND_MAX à partir d'un point tiré de la graine, sans les canaux
--- réservés ni celui de la station de chiffres.
function Broadcast.candidates(seed)
    local station = stationOption()
    local list = {}
    local count = math.floor((Broadcast.BAND_MAX - Broadcast.BAND_MIN) / Config.CHANNEL_STEP) + 1
    local start = Codes.newRandom(seed, Codes.USE_MILITARY_CHANNEL)(count)
    for i = 0, count - 1 do
        local channel = Broadcast.BAND_MIN + ((start + i) % count) * Config.CHANNEL_STEP
        if channel ~= station and not Config.RESERVED_CHANNELS[channel] then
            list[#list + 1] = channel
        end
    end
    return list
end

--- Fréquence libre de la partie (option Frequency à 0) : celle de la chaîne
--- créée, ou, avant sa création (ou si aucune n'a pu l'être), le premier
--- candidat.
function Broadcast.freeChannel()
    if Broadcast.frequency then
        return Broadcast.frequency
    end
    return Broadcast.candidates(MilitaryDrop.Secrets.getSeed())[1]
end

function Broadcast.onLoadRadioScripts(scriptManager)
    Broadcast.channel = nil
    Broadcast.frequency = nil
    local list
    if Config.isFixedFrequency() then
        list = { Config.getChannel() }
    else
        list = Broadcast.candidates(MilitaryDrop.Secrets.getSeed())
    end
    for _, frequency in ipairs(list) do
        scriptManager:AddChannel(DynamicRadioChannel.new(Broadcast.CHANNEL_NAME, frequency, ChannelCategory.Military,
            Broadcast.CHANNEL_UUID), false)
        local channel = scriptManager:getRadioChannel(Broadcast.CHANNEL_UUID)
        if channel then
            getZomboidRadio():removeChannelName(frequency)
            Broadcast.channel = channel
            Broadcast.frequency = frequency
            MilitaryDrop.log("radio channel on " .. Config.formatChannel(frequency) .. " MHz")
            return
        end
    end
    MilitaryDrop.log("radio channel not created: frequency " .. Config.formatChannel(list[1] or 0)
        .. " MHz already used", true)
end

--- Diffuse des lignes { texte, codes } sur la chaîne militaire, à la suite
--- d'une diffusion en cours (deux largages proches : aucune ligne perdue).
function Broadcast.air(lines)
    if not Broadcast.channel then
        return false
    end
    local bc = Broadcast.channel:getAiringBroadcast()
    local airing = bc ~= nil
    if not airing then
        serial = serial + 1
        bc = RadioBroadCast.new("MDRP-" .. serial, -1, -1)
    end
    local c = Broadcast.COLOR
    for _, line in ipairs(lines) do
        bc:AddRadioLine(RadioLine.new(line[1], c.r, c.g, c.b, line[2]))
    end
    if not airing then
        Broadcast.channel:setAiringBroadcast(bc)
    end
    return true
end

--- Ligne ajoutée aussi au journal des postes de commandement qui la reçoivent
--- (MilitaryDrop_Post.lua), si la chaîne existe.
local function toPostLogs(text)
    if Broadcast.channel and MilitaryDrop.Post then
        MilitaryDrop.Post.record(nil, text)
    end
end

--- L'hélicoptère décolle : annonce sans coordonnées.
function Broadcast.inbound()
    local text = getText("IGUI_MilitaryDrop_BroadcastInbound")
    Broadcast.air({ { text } })
    toPostLogs(text)
end

--- Position approchée (secteur de 50 cases), repère seulement pour les auditeurs.
function Broadcast.mayday(id, x, y)
    x, y = math.floor(x / 50) * 50 + 25, math.floor(y / 50) * 50 + 25
    Net.toAll("MaydayAnnounce", { id = tostring(id), x = x, y = y })
    local text = getText("IGUI_MilitaryDrop_BroadcastMayday", tostring(x), tostring(y))
    Broadcast.air({ { text, "MDAY" }, { text, "MDAY" } })
    toPostLogs(text)
end

--- Le nom de la zone de largage (idée 11) est lu dans l'annonce : nom
--- donné et option DropZoneAnnounceName vraie (défaut).
function Broadcast.announcesZone(zoneName)
    return type(zoneName) == "string" and zoneName ~= "" and Config.get("DropZoneAnnounceName") ~= false
end

--- Largage effectué : coordonnées répétées, et repère de carte pour les
--- joueurs qui entendent la ligne (MilitaryDrop_Announce.lua). zoneName
--- (facultatif) : nom de la zone de largage, lu avant la grille (« LZ … ») ;
--- le repère et le message aux clients ne changent pas.
function Broadcast.dropped(x, y, zoneName)
    Net.toAll("DropAnnounce", { x = x, y = y })
    local lines = {}
    local text
    if Broadcast.announcesZone(zoneName) then
        text = getText("IGUI_MilitaryDrop_BroadcastDroppedZone", zoneName, tostring(x), tostring(y))
    else
        text = getText("IGUI_MilitaryDrop_BroadcastDropped", tostring(x), tostring(y))
    end
    for i = 1, Broadcast.REPEATS do
        lines[i] = { text, Broadcast.CODE }
    end
    lines[#lines + 1] = { getText("IGUI_MilitaryDrop_BroadcastOut") }
    Broadcast.air(lines)
    toPostLogs(text)
end

--- Rappel de la base (Server.repeatGrids) : grille de chaque largage dont
--- aucune caisse n'a été ouverte, avec le code du repère. Toutes les grilles
--- partent aux clients dans un seul message (DropAnnounce { grids }), avant
--- les lignes qui les annoncent. grid.zoneName (facultatif) : nom de la zone
--- de largage, dans le texte seulement (jamais envoyé à tous les clients).
function Broadcast.pending(grids)
    if type(grids) ~= "table" or #grids == 0 then
        return false
    end
    local marks = {}
    for i, grid in ipairs(grids) do
        marks[i] = { x = grid.x, y = grid.y }
    end
    Net.toAll("DropAnnounce", { grids = marks })
    local lines = {}
    for _, grid in ipairs(grids) do
        local text
        if Broadcast.announcesZone(grid.zoneName) then
            text = getText("IGUI_MilitaryDrop_BroadcastPendingZone", grid.zoneName, tostring(grid.x), tostring(grid.y))
        else
            text = getText("IGUI_MilitaryDrop_BroadcastPending", tostring(grid.x), tostring(grid.y))
        end
        for _ = 1, Broadcast.PENDING_REPEATS do
            lines[#lines + 1] = { text, Broadcast.CODE }
        end
        toPostLogs(text)
    end
    lines[#lines + 1] = { getText("IGUI_MilitaryDrop_BroadcastOut") }
    return Broadcast.air(lines)
end

--- Reconnaissance lancée (MilitaryDrop_Missions.lua) : grille envoyée à tous
--- (ReconAnnounce), repère posé par le client seulement si l'une de ses radios
--- entend une ligne portant le code renvoyé (MilitaryDrop_Announce.lua). À
--- appeler AVANT de diffuser l'annonce, dont chaque ligne de grille porte ce
--- code (Missions.announce(texte, répétitions, code)). La diffusion, le texte
--- et le journal des postes restent à l'appelant.
function Broadcast.reconAnnounced(missionId, x, y)
    Net.toAll("ReconAnnounce", { id = tostring(missionId), x = x, y = y })
    return Broadcast.RECON_CODE
end

--- Nettoyage lancé (MilitaryDrop_Missions.lua) : même principe que
--- reconAnnounced, avec le rayon de la zone (CleanupAnnounce { id, x, y,
--- radius }). Renvoie le code des lignes de l'annonce.
function Broadcast.cleanupAnnounced(missionId, x, y, radius)
    Net.toAll("CleanupAnnounce", { id = tostring(missionId), x = x, y = y, radius = radius })
    return Broadcast.CLEANUP_CODE
end

Events.OnLoadRadioScripts.Add(Broadcast.onLoadRadioScripts)

return Broadcast
