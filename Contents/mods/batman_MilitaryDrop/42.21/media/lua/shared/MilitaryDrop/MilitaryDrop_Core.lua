-- ============================================================================
-- Military Drop — espace de noms, journal et options sandbox
--
-- Seule globale du mod : la table MilitaryDrop. Les scripts la désignent par
-- nom (OnCreate = MilitaryDrop.Recipe.openSupplyCase), elle doit donc exister
-- dans l'environnement global.
--
-- Les options sont lues à chaque appel, jamais au chargement du fichier : sur
-- un client MP, SandboxVars n'est reçu du serveur qu'après le chargement du Lua.
-- ============================================================================

MilitaryDrop = MilitaryDrop or {}

local Config = {}
MilitaryDrop.Config = Config

-- Pas de réglage des radios (RWMChannel.lua : pas de 0,2 MHz) et bornes des
-- radios militaires vanilla (WalkieTalkie5, HamRadio2, ManPackRadio :
-- MinChannel 200, MaxChannel 1000000), en kHz comme DeviceData:getChannel().
Config.CHANNEL_STEP = 200
Config.MIN_CHANNEL = 200
Config.MAX_CHANNEL = 1000000
-- Fréquence du drone de HEF - Helicopter Event Framework (Workshop 3672792485,
-- HTT_ServerUAVScan.lua) : jamais utilisée par ce mod.
Config.RESERVED_CHANNELS = { [112200] = true }

local DEFAULTS = {
    CooldownHours = 168,
    Frequency = 151.4,
    MinZombies = 3,
    MaxZombies = 30,
    NoteDropRate = 4,
    NotesOnlyArmyPolice = true,
    NoteOutfits = "Army;Police;Sheriff",
    NoteOutfitsExcluded = "Stripper",
    CaseRolls = 6,
    DropMinDistance = 150,
    DropMaxDistance = 400,
    -- 1 aucun, 2 fixe en clair, 3 de la semaine en clair, 4 de la semaine chiffré
    -- (MilitaryDrop.Codes.MODE_*).
    AuthCode = 4,
    -- 0 : fréquence libre tirée dans la bande de la station (MilitaryDrop_NumbersStation.lua).
    NumbersStationFrequency = 0,
    CodebookDropRate = 3,
    CodebookOutfits = "Army",
    -- Fumée verte sur la caisse posée, si Signal Smoke est actif (0 = aucune).
    CrateSmokeMinutes = 60,
    DebugLog = false,
}

--- Valeur d'une option sandbox (page MilitaryDrop), ou sa valeur par défaut.
function Config.get(name)
    local vars = SandboxVars and SandboxVars.MilitaryDrop
    local value = vars and vars[name]
    if value == nil then
        return DEFAULTS[name]
    end
    return value
end

--- Mode du code d'authentification (MilitaryDrop.Codes.MODE_*), borné à 1-4.
function Config.codeMode()
    local mode = math.floor(tonumber(Config.get("AuthCode")) or DEFAULTS.AuthCode)
    return math.max(1, math.min(4, mode))
end

--- Liste d'une option texte « a;b;c » : mots en minuscules, sans vides.
function Config.getList(name)
    local words = {}
    for word in string.gmatch(tostring(Config.get(name) or ""), "[^;]+") do
        word = string.lower((word:gsub("^%s+", ""):gsub("%s+$", "")))
        if word ~= "" then
            words[#words + 1] = word
        end
    end
    return words
end

--- Canal radio (kHz) correspondant à une fréquence en MHz : arrondi au pas de
--- réglage des radios, borné, et décalé d'un pas s'il est réservé.
function Config.toChannel(mhz)
    local steps = math.floor((tonumber(mhz) or DEFAULTS.Frequency) * 1000 / Config.CHANNEL_STEP + 0.5)
    local channel = steps * Config.CHANNEL_STEP
    if channel < Config.MIN_CHANNEL then
        channel = Config.MIN_CHANNEL
    elseif channel > Config.MAX_CHANNEL then
        channel = Config.MAX_CHANNEL
    end
    while Config.RESERVED_CHANNELS[channel] do
        channel = channel + Config.CHANNEL_STEP
    end
    return channel
end

--- Canal militaire de la partie (kHz).
function Config.getChannel()
    return Config.toChannel(Config.get("Frequency"))
end

--- Texte affiché d'un canal : 151400 → "151.4".
function Config.formatChannel(channel)
    local text = string.format("%.1f", channel / 1000)
    return (text:gsub("%.0$", ""))
end

--- Journal du mod : toujours pour les avertissements, sinon seulement avec
--- l'option DebugLog.
function MilitaryDrop.log(message, always)
    if always or Config.get("DebugLog") then
        print("[MilitaryDrop] " .. tostring(message))
    end
end

return MilitaryDrop
