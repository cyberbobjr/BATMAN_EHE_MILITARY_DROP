-- ============================================================================
-- Military Drop — code d'authentification (calcul pur, sans état)
--
-- Code : deux mots de l'alphabet OTAN et deux chiffres, par exemple
-- BRAVO-KILO-42. La saisie du joueur est comparée sans tenir compte de la
-- casse, des espaces ni des tirets.
--
-- Option AuthCode (MODE_*) :
--   * code fixe : tiré une fois par partie (fichier du serveur) ;
--   * code de la semaine : dérivé d'une graine secrète du serveur et du
--     numéro de semaine ; il change chaque lundi à 00:00 (calendrier du jeu)
--     et l'ancien reste accepté pendant GRACE_HOURS ;
--   * chiffré : une station de chiffres diffuse « 17-04-58 » ; le carnet de
--     codes donne la table qui déchiffre les deux mots (17 → BRAVO,
--     04 → KILO). Les chiffres passent en clair. Un seul carnet par partie
--     (décision du 2026-09-30) : la table est fixe, seul le code change.
--
-- Tout est reproductible depuis la graine : rien d'autre n'est stocké. La
-- graine n'existe que sur le serveur (fichier) : ces fonctions ne servent
-- donc qu'au serveur et au solo, et aux tests.
--
-- Kahlua n'a pas d'opérateurs binaires : le générateur est un Park-Miller
-- (multiplicateur 48271, module 2^31 - 1), exact en flottants doubles.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Codes = {}
MilitaryDrop.Codes = Codes

Codes.WORDS = {
    "ALPHA", "BRAVO", "CHARLIE", "DELTA", "ECHO", "FOXTROT", "GOLF", "HOTEL", "INDIA",
    "JULIET", "KILO", "LIMA", "MIKE", "NOVEMBER", "OSCAR", "PAPA", "QUEBEC", "ROMEO",
    "SIERRA", "TANGO", "UNIFORM", "VICTOR", "WHISKEY", "XRAY", "YANKEE", "ZULU",
}
-- Au-delà, une saisie est refusée sans être comparée.
Codes.MAX_INPUT_LENGTH = 40

-- Valeurs de l'option sandbox AuthCode.
Codes.MODE_NONE = 1
Codes.MODE_FIXED = 2
Codes.MODE_WEEKLY_PLAIN = 3
Codes.MODE_WEEKLY_CIPHER = 4

Codes.HOURS_PER_WEEK = 168
Codes.GRACE_HOURS = 24
-- Nombres de la table d'une édition : 00 à 99, un par mot.
Codes.TABLE_SIZE = 100

Codes.MODULUS = 2147483647
Codes.MULTIPLIER = 48271

local WORD_INDEX = {}
for i, word in ipairs(Codes.WORDS) do
    WORD_INDEX[word] = i
end

--- Nouveau code. rand(n) doit renvoyer un entier dans [0, n[ (ZombRand).
function Codes.generate(rand)
    rand = rand or ZombRand
    local first = Codes.WORDS[rand(#Codes.WORDS) + 1]
    local second = Codes.WORDS[rand(#Codes.WORDS) + 1]
    return string.format("%s-%s-%02d", first, second, rand(100))
end

--- Forme comparable : majuscules, lettres et chiffres seulement.
function Codes.normalize(text)
    if type(text) ~= "string" then
        return ""
    end
    return (string.upper(text):gsub("[^%w]", ""))
end

function Codes.matches(input, code)
    if type(input) ~= "string" or #input > Codes.MAX_INPUT_LENGTH or type(code) ~= "string" then
        return false
    end
    local expected = Codes.normalize(code)
    return expected ~= "" and Codes.normalize(input) == expected
end

--- La saisie correspond à l'un des codes de la liste.
function Codes.matchesAny(input, codes)
    for _, code in ipairs(codes) do
        if Codes.matches(input, code) then
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------------------
-- Générateur reproductible
-- ----------------------------------------------------------------------------

--- Graine valable (entier de 1 à MODULUS - 1), ou nil.
function Codes.validSeed(value)
    local seed = tonumber(value)
    if seed and seed == math.floor(seed) and seed >= 1 and seed < Codes.MODULUS then
        return seed
    end
    return nil
end

--- rand(n) → entier dans [0, n[, entièrement déterminé par la graine et les
--- entiers positifs donnés (usage, semaine, édition…).
function Codes.newRandom(seed, ...)
    local m = Codes.MODULUS
    local state = seed % m
    local function step()
        state = (state * Codes.MULTIPLIER) % m
        return state
    end
    for _, value in ipairs({ ... }) do
        state = (state + value * 7919 + 1) % m
        if state == 0 then
            state = 1
        end
        step()
        step()
    end
    if state == 0 then
        state = 1
    end
    return function(n)
        return math.floor(step() / m * n)
    end
end

-- ----------------------------------------------------------------------------
-- Calendrier : semaines du lundi 00:00
-- ----------------------------------------------------------------------------

--- Jours depuis le 1970-01-01 (mois 1 à 12, jour 1 à 31 ; calendrier grégorien).
function Codes.daysFromCivil(y, m, d)
    if m <= 2 then
        y = y - 1
    end
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = math.floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

--- Date (année, mois 1 à 12, jour 1 à 31) d'un nombre de jours depuis le 1970-01-01.
function Codes.civilFromDays(days)
    local z = days + 719468
    local era = math.floor(z / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local d = doy - math.floor((153 * mp + 2) / 5) + 1
    local m = mp < 10 and mp + 3 or mp - 9
    local y = yoe + era * 400
    if m <= 2 then
        y = y + 1
    end
    return y, m, d
end

--- Horloge en heures depuis le lundi 1969-12-29 00:00, d'après le calendrier
--- du jeu (GameTime : mois et jour comptés depuis 0).
function Codes.clockHours(year, month0, day0, timeOfDay)
    -- Le 1970-01-01 est un jeudi : 3 jours après le lundi.
    return (Codes.daysFromCivil(year, month0 + 1, day0 + 1) + 3) * 24 + (timeOfDay or 0)
end

--- Horloge de la date courante d'un GameTime.
function Codes.gameClock(gameTime)
    return Codes.clockHours(gameTime:getYear(), gameTime:getMonth(), gameTime:getDay(), gameTime:getTimeOfDay())
end

function Codes.weekOf(clock)
    return math.floor(clock / Codes.HOURS_PER_WEEK)
end

--- Jour (depuis le 1970-01-01) du lundi qui ouvre la semaine.
function Codes.weekStartDay(week)
    return week * 7 - 3
end

--- Semaines dont le code est accepté : la semaine en cours, et la précédente
--- pendant les GRACE_HOURS qui suivent le changement.
function Codes.acceptedWeeks(clock)
    local week = Codes.weekOf(clock)
    if clock - week * Codes.HOURS_PER_WEEK < Codes.GRACE_HOURS then
        return { week, week - 1 }
    end
    return { week }
end

-- ----------------------------------------------------------------------------
-- Code de la semaine et chiffrement
-- ----------------------------------------------------------------------------

-- Usages distincts du générateur, pour que code et table ne se recoupent pas.
Codes.USE_WEEKLY_CODE = 1
Codes.USE_CIPHER_TABLE = 2
-- Numéro fixe mêlé à la graine pour la table : 1, celui de l'ancienne
-- « édition 1 », pour que les carnets déjà écrits restent justes.
Codes.CIPHER_TABLE_ID = 1
Codes.USE_STATION = 3
-- Fréquence militaire libre (option Frequency à 0) et nom de la ModData privée.
Codes.USE_MILITARY_CHANNEL = 4
Codes.USE_PRIVATE_STATE = 5

function Codes.weeklyCode(seed, week)
    return Codes.generate(Codes.newRandom(seed, Codes.USE_WEEKLY_CODE, week))
end

--- Table de la partie : numbers[i] = nombre (0 à 99) du mot Codes.WORDS[i],
--- tous différents.
function Codes.cipherTable(seed)
    local rand = Codes.newRandom(seed, Codes.USE_CIPHER_TABLE, Codes.CIPHER_TABLE_ID)
    local pool = {}
    for i = 1, Codes.TABLE_SIZE do
        pool[i] = i - 1
    end
    -- Mélange de Fisher-Yates.
    for i = Codes.TABLE_SIZE, 2, -1 do
        local j = rand(i) + 1
        pool[i], pool[j] = pool[j], pool[i]
    end
    local numbers = {}
    for i = 1, #Codes.WORDS do
        numbers[i] = pool[i]
    end
    return numbers
end

--- « BRAVO-KILO-58 » → « 17-04-58 » avec la table, ou nil si le code est mal formé.
function Codes.encrypt(code, numbers)
    local first, second, digits = string.match(tostring(code), "^(%a+)-(%a+)-(%d%d)$")
    local a, b = WORD_INDEX[first], WORD_INDEX[second]
    if not a or not b then
        return nil
    end
    return string.format("%02d-%02d-%s", numbers[a], numbers[b], digits)
end

--- « 17-04-58 » → « BRAVO-KILO-58 » avec la table, ou nil.
function Codes.decrypt(cipher, numbers)
    local x, y, digits = string.match(tostring(cipher), "^(%d%d)-(%d%d)-(%d%d)$")
    local words = {}
    for i, number in ipairs(numbers) do
        words[number] = Codes.WORDS[i]
    end
    local first, second = words[tonumber(x)], words[tonumber(y)]
    if not first or not second then
        return nil
    end
    return first .. "-" .. second .. "-" .. digits
end

return Codes
