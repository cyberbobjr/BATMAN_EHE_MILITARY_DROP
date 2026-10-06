-- ============================================================================
-- Military Drop — station de chiffres (serveur MP ou solo, AuthCode 4)
--
-- Une chaîne dynamique diffuse toutes les 30 minutes de jeu le code de la
-- semaine chiffré avec la table de la partie : « 17-04-58 » (x3). Le carnet
-- de codes déchiffre les deux premiers groupes (MilitaryDrop_Codes.lua) ;
-- aucun secret n'est envoyé aux clients, qui ne reçoivent que le texte chiffré.
--
-- Fréquence : option NumbersStationFrequency, ou 0 pour une fréquence libre
-- des ondes courtes (BAND_MIN-BAND_MAX : radios militaires, radioamateur et
-- meilleur talkie civil), dérivée de la graine secrète, donc stable d'un
-- chargement à l'autre sans ModData (pas encore chargée à OnLoadRadioScripts).
-- Jamais la fréquence militaire ni une fréquence réservée (HEF). Le nom est
-- retiré des noms connus : le panneau de la radio affiche « chaîne inconnue ».
--
-- Une diffusion n'est pas sauvegardée : rien à restaurer, la suivante part à
-- la demi-heure.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Codes"
require "MilitaryDrop/MilitaryDrop_Secrets"

local Config = MilitaryDrop.Config
local Codes = MilitaryDrop.Codes
local Secrets = MilitaryDrop.Secrets

local Station = {}
MilitaryDrop.NumbersStation = Station

Station.CHANNEL_NAME = "Numbers"
Station.CHANNEL_UUID = "batman_MilitaryDrop-Numbers"
Station.BAND_MIN = 10000
Station.BAND_MAX = 25000
Station.REPEATS = 3
Station.INTERVAL_MINUTES = 30
Station.COLOR = { r = 0.85, g = 0.75, b = 0.45 }

local serial = 0
local lastSlot = nil

--- Canaux candidats, dans l'ordre d'essai : l'option, ou la bande des ondes
--- courtes à partir d'un point tiré de la graine.
function Station.candidates(seed)
    local military = Config.getChannel()
    local list = {}
    local function add(channel)
        if channel ~= military and not Config.RESERVED_CHANNELS[channel] then
            list[#list + 1] = channel
        end
    end
    local configured = tonumber(Config.get("NumbersStationFrequency")) or 0
    if configured > 0 then
        local channel = Config.toChannel(configured)
        if channel == military then
            channel = Config.toChannel((channel + Config.CHANNEL_STEP) / 1000)
        end
        add(channel)
        return list
    end
    local count = math.floor((Station.BAND_MAX - Station.BAND_MIN) / Config.CHANNEL_STEP) + 1
    local start = Codes.newRandom(seed, Codes.USE_STATION)(count)
    for i = 0, count - 1 do
        add(Station.BAND_MIN + ((start + i) % count) * Config.CHANNEL_STEP)
    end
    return list
end

function Station.onLoadRadioScripts(scriptManager)
    Station.channel = nil
    Station.frequency = nil
    if Config.codeMode() ~= Codes.MODE_WEEKLY_CIPHER then
        return
    end
    for _, frequency in ipairs(Station.candidates(Secrets.getSeed())) do
        scriptManager:AddChannel(DynamicRadioChannel.new(Station.CHANNEL_NAME, frequency, ChannelCategory.Military,
            Station.CHANNEL_UUID), false)
        local channel = scriptManager:getRadioChannel(Station.CHANNEL_UUID)
        if channel then
            getZomboidRadio():removeChannelName(frequency)
            Station.channel = channel
            Station.frequency = frequency
            MilitaryDrop.log("numbers station on " .. Config.formatChannel(frequency) .. " MHz")
            return
        end
    end
    MilitaryDrop.log("numbers station not created: no free frequency", true)
end

--- Groupes chiffrés du code de la semaine : « 74-46-74 ».
function Station.cipher(clock)
    local seed = Secrets.getSeed()
    return Codes.encrypt(Codes.weeklyCode(seed, Codes.weekOf(clock)), Codes.cipherTable(seed))
end

--- Lignes du message pour cette heure du calendrier : appel, puis code chiffré répété.
function Station.message(clock)
    local cipher = Station.cipher(clock)
    local lines = { getText("IGUI_MilitaryDrop_Numbers_Open") }
    for _ = 1, Station.REPEATS do
        lines[#lines + 1] = getText("IGUI_MilitaryDrop_Numbers_Group", cipher)
    end
    lines[#lines + 1] = getText("IGUI_MilitaryDrop_Numbers_End")
    return lines
end

--- Diffuse le message, sauf si le précédent n'est pas fini.
function Station.air(clock)
    local channel = Station.channel
    if not channel or channel:getAiringBroadcast() then
        return false
    end
    serial = serial + 1
    local bc = RadioBroadCast.new("MDNS-" .. serial, -1, -1)
    local c = Station.COLOR
    for _, text in ipairs(Station.message(clock)) do
        bc:AddRadioLine(RadioLine.new(text, c.r, c.g, c.b))
    end
    channel:setAiringBroadcast(bc)
    return true
end

--- Option AuthCode passée au mode 4 en cours de partie : la station, absente
--- si la partie a été chargée dans un autre mode, est créée comme au
--- chargement (AddChannel n'est pas réservé à OnLoadRadioScripts : il range la
--- chaîne dans la table que ZomboidRadio met à jour à chaque image,
--- RadioScriptManager.java:94-103, 119-123 ; une chaîne de serveur suffit en
--- MP, comme la chaîne militaire). Hors mode 4, elle se tait (onEveryTenMinutes).
--- Sa fréquence reste celle de sa création jusqu'au redémarrage.
function Station.onOptionsChanged()
    if Station.channel or Config.codeMode() ~= Codes.MODE_WEEKLY_CIPHER then
        return false
    end
    local radio = getZomboidRadio and getZomboidRadio()
    local manager = radio and radio:getScriptManager()
    if not manager then
        return false
    end
    Station.onLoadRadioScripts(manager)
    return Station.channel ~= nil
end

--- Une diffusion par tranche de INTERVAL_MINUTES, au premier passage dans la
--- tranche (GameTime:getMinutes tronque un flottant : 30 peut devenir 29).
function Station.onEveryTenMinutes()
    if not Station.channel or Config.codeMode() ~= Codes.MODE_WEEKLY_CIPHER then
        return
    end
    local clock = Codes.gameClock(getGameTime())
    local slot = math.floor(clock * 60 / Station.INTERVAL_MINUTES + 0.001)
    if slot ~= lastSlot and Station.air(clock) then
        lastSlot = slot
    end
end

Events.OnLoadRadioScripts.Add(Station.onLoadRadioScripts)
Events.EveryTenMinutes.Add(Station.onEveryTenMinutes)
Config.onChange("NumbersStation", { "AuthCode" }, Station.onOptionsChanged)

return Station
