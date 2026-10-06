-- ============================================================================
-- Military Drop — espace de noms, journal et options sandbox
--
-- Seule globale du mod : la table MilitaryDrop. Les scripts la désignent par
-- nom (OnCreate = MilitaryDrop.Recipe.openSupplyCase), elle doit donc exister
-- dans l'environnement global.
--
-- Les options sont lues à chaque appel, jamais au chargement du fichier : sur
-- un client MP, SandboxVars n'est reçu du serveur qu'après le chargement du Lua.
--
-- Options changées en cours de partie (à chaud) : Config.get lit d'abord les
-- options Java (getSandboxOptions), que tout changement met à jour, puis
-- SandboxVars. En solo, l'éditeur d'options (menu de debug « Options bac à
-- sable ») fait seulement getSandboxOptions():set(...) : la table SandboxVars
-- reste périmée jusqu'au prochain chargement (ISServerSandboxOptionsUI.lua:738-740,
-- SandboxOptions.java:550-559). En MP, « Appliquer » envoie les options au
-- serveur, qui les recopie dans SandboxVars (toLua), les enregistre et les
-- renvoie à tous les clients, qui font de même (GameServer.java:1633-1646,
-- GameClient.java:2649-2657). Aucun événement Lua ne suit : Config.poll compare
-- les valeurs à chaque minute de jeu et prévient les abonnés de Config.onChange
-- (recalculs ciblés : chaîne de la station, carnet dans le butin, lots).
-- ============================================================================

MilitaryDrop = MilitaryDrop or {}

-- Rechargement de ce fichier : un seul abonné au sondage (Events.X.Add ne
-- dédoublonne pas).
local previousPoll = MilitaryDrop.Config and MilitaryDrop.Config.poll

local Config = {}
MilitaryDrop.Config = Config
Config.PAGE = "MilitaryDrop"

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
    -- 0 : fréquence libre tirée par le serveur (MilitaryDrop_Broadcast.lua), secrète.
    Frequency = 0,
    MinZombies = 3,
    MaxZombies = 30,
    NoteDropRate = 4,
    NotesOnlyArmyPolice = true,
    NoteOutfits = "Army;Police;Sheriff",
    NoteOutfitsExcluded = "Stripper",
    CaseRolls = 6,
    DropMinDistance = 150,
    DropMaxDistance = 400,
    -- Rappel de la grille d'un largage non ouvert toutes les N heures de jeu (0 = aucun).
    DropRepeatHours = 6,
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

--- Valeur courante d'une option sandbox par son nom complet (« MilitaryDrop.X »,
--- ou vanilla : « GeneratorTileRange »), lue dans les options Java, à jour
--- après un changement en cours de partie ; nil si l'option est inconnue.
--- getValue : nombre (entier, flottant, enum), booléen ou chaîne.
function Config.sandboxValue(fullName)
    local options = getSandboxOptions and getSandboxOptions()
    local option = options and options.getOptionByName and options:getOptionByName(fullName)
    if option == nil then
        return nil
    end
    return option:getValue()
end

--- Valeur d'une option sandbox (page MilitaryDrop) : options Java, sinon
--- SandboxVars, sinon sa valeur par défaut.
function Config.get(name)
    local value = Config.sandboxValue(Config.PAGE .. "." .. name)
    if value == nil then
        local vars = SandboxVars and SandboxVars.MilitaryDrop
        value = vars and vars[name]
    end
    if value == nil then
        return DEFAULTS[name]
    end
    return value
end

-- Abonnés aux changements d'options, par clé (un fichier rechargé remplace son
-- abonné au lieu d'en ajouter un second) : { key, names, fn }.
Config.listeners = {}
-- Dernière valeur vue de chaque option suivie ; known[name] : déjà lue une fois.
local lastValues, known = {}, {}

--- fn(changed) est appelée quand l'une des options names change en cours de
--- partie (changed : noms changés, triés). Même clé : abonné remplacé.
function Config.onChange(key, names, fn)
    for _, listener in ipairs(Config.listeners) do
        if listener.key == key then
            listener.names, listener.fn = names, fn
            return
        end
    end
    Config.listeners[#Config.listeners + 1] = { key = key, names = names, fn = fn }
end

--- Compare les options connues (valeurs par défaut des modules chargés et
--- options des abonnés) à la lecture précédente ; journalise les changements et
--- appelle les abonnés concernés. La première lecture d'une option sert de
--- référence, sans appel. Renvoie la liste des options changées.
function Config.poll()
    local changed, checked = {}, {}
    local function check(name)
        if checked[name] then
            return
        end
        checked[name] = true
        local value = Config.get(name)
        if not known[name] then
            known[name] = true
            lastValues[name] = value
        elseif lastValues[name] ~= value then
            lastValues[name] = value
            changed[#changed + 1] = name
        end
    end
    for name in pairs(DEFAULTS) do
        check(name)
    end
    for _, listener in ipairs(Config.listeners) do
        for _, name in ipairs(listener.names) do
            check(name)
        end
    end
    if #changed == 0 then
        return changed
    end
    table.sort(changed)
    MilitaryDrop.log("sandbox options changed: " .. table.concat(changed, ", "), true)
    local isChanged = {}
    for _, name in ipairs(changed) do
        isChanged[name] = true
    end
    for _, listener in ipairs(Config.listeners) do
        for _, name in ipairs(listener.names) do
            if isChanged[name] then
                listener.fn(changed)
                break
            end
        end
    end
    return changed
end

--- Valeurs par défaut des options d'un module (sans écraser celles déjà connues).
function Config.addDefaults(values)
    for name, value in pairs(values) do
        if DEFAULTS[name] == nil then
            DEFAULTS[name] = value
        end
    end
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
    local steps = math.floor((tonumber(mhz) or 0) * 1000 / Config.CHANNEL_STEP + 0.5)
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

--- Fréquence militaire fixée par l'option Frequency (> 0) : publique, car les
--- options sandbox sont envoyées à tous les clients.
function Config.isFixedFrequency()
    return (tonumber(Config.get("Frequency")) or 0) > 0
end

--- Canal militaire de la partie (kHz). Chaîne déjà créée (serveur ou solo) :
--- sa fréquence, jusqu'au redémarrage, même si l'option Frequency change en
--- cours de partie (une chaîne garde la fréquence de sa création :
--- RadioChannel.java:45-55, aucun mutateur). Sinon, option Frequency > 0 : ce
--- canal fixe. Option à 0 : fréquence libre tirée par le serveur à partir de
--- la graine secrète (MilitaryDrop.Broadcast.freeChannel, fichier serveur). Un
--- client MP ne la connaît jamais : nil (aucun code client n'en a besoin).
function Config.getChannel()
    local Broadcast = MilitaryDrop.Broadcast
    if Broadcast and Broadcast.frequency then
        return Broadcast.frequency
    end
    if Config.isFixedFrequency() then
        return Config.toChannel(Config.get("Frequency"))
    end
    if Broadcast and Broadcast.freeChannel then
        return Broadcast.freeChannel()
    end
    return nil
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

-- ----------------------------------------------------------------------------
-- Chaînes : caractères entiers
--
-- Kahlua 42.21 manipule des chaînes Java : un « octet » y est une unité UTF-16
-- (string.byte renvoie son code, StringLib.java:637-662 ; string.char accepte
-- tout code, StringLib.java:672-678), pas un octet UTF-8 ; # compte ces
-- unités. Le Lua 5.1 des tests (lupa), lui, voit des octets UTF-8. Les deux
-- fonctions ci-dessous gardent des caractères entiers dans les deux cas, et
-- dropLastChar raccourcit toujours un texte non vide (boucles de troncature).
-- ----------------------------------------------------------------------------

-- Vrai sous Kahlua (unités UTF-16), faux sous un Lua à octets.
local WIDE_CHARS = pcall(string.char, 256)

local function isContinuation(code)
    return code ~= nil and code >= 128 and code < 192
end

--- Texte sans son dernier caractère ("" pour un texte d'un caractère ou vide).
--- Kahlua : une paire de substitution (caractère hors du plan de base) part
--- entière ; Lua à octets : les octets de suite UTF-8 partent avec leur octet
--- de tête. Toujours plus court qu'un texte non vide.
function MilitaryDrop.dropLastChar(text)
    text = tostring(text or "")
    local n = #text
    if n <= 1 then
        return ""
    end
    local last = text:byte(n)
    if WIDE_CHARS then
        local prev = text:byte(n - 1)
        if last >= 0xDC00 and last <= 0xDFFF and prev >= 0xD800 and prev <= 0xDBFF then
            return text:sub(1, n - 2)
        end
        return text:sub(1, n - 1)
    end
    local i = n
    while i > 1 and isContinuation(text:byte(i)) do
        i = i - 1
    end
    return text:sub(1, i - 1)
end

--- Les max premières unités du texte, sans couper un caractère (voir plus haut).
function MilitaryDrop.cutText(text, max)
    text = tostring(text or "")
    if #text <= max then
        return text
    end
    if max <= 0 then
        return ""
    end
    if WIDE_CHARS then
        local last = text:byte(max)
        if last >= 0xD800 and last <= 0xDBFF then
            return text:sub(1, max - 1)
        end
        return text:sub(1, max)
    end
    if not isContinuation(text:byte(max + 1)) then
        return text:sub(1, max)
    end
    -- Coupé au milieu d'un caractère UTF-8 : il est retiré.
    local i = max
    while i > 1 and isContinuation(text:byte(i)) do
        i = i - 1
    end
    return text:sub(1, i - 1)
end

-- Sondage des options : chaque minute de jeu, sur le serveur, le client MP et
-- le solo (un seul état Lua : un seul passage pour les abonnés client et serveur).
if previousPoll then
    Events.EveryOneMinute.Remove(previousPoll)
end
Events.EveryOneMinute.Add(Config.poll)

return MilitaryDrop
