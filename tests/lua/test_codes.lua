-- MilitaryDrop_Codes : tirage et comparaison du code, calendrier, code de la
-- semaine et chiffrement par la table d'une édition.

local T = {}

function T.setup()
    SandboxVars = {}
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    loadMod("shared/MilitaryDrop/MilitaryDrop_Codes.lua")
end

--- rand(n) qui rend les valeurs données, dans l'ordre.
local function sequence(...)
    local values, i = { ... }, 0
    return function()
        i = i + 1
        return values[i]
    end
end

function T.generate_uses_two_words_and_two_digits()
    assertEq(MilitaryDrop.Codes.generate(sequence(1, 10, 7)), "BRAVO-KILO-07", "format MOT-MOT-NN")
    assertEq(MilitaryDrop.Codes.generate(sequence(25, 0, 99)), "ZULU-ALPHA-99", "bornes")
end

function T.matches_ignores_case_spaces_and_dashes()
    local matches = MilitaryDrop.Codes.matches
    assertTrue(matches("bravo kilo 07", "BRAVO-KILO-07"), "minuscules et espaces")
    assertTrue(matches(" Bravo-Kilo-07 ", "BRAVO-KILO-07"), "tirets et espaces autour")
    assertTrue(not matches("BRAVO-KILO-08", "BRAVO-KILO-07"), "mauvais chiffres")
    assertTrue(not matches("BRAVOKILO", "BRAVO-KILO-07"), "code incomplet")
end

function T.matches_rejects_bad_input()
    local matches = MilitaryDrop.Codes.matches
    assertTrue(not matches(nil, "BRAVO-KILO-07"), "nil")
    assertTrue(not matches(42, "BRAVO-KILO-07"), "nombre")
    assertTrue(not matches("", ""), "code vide jamais accepté")
    assertTrue(not matches(string.rep("A", 41), string.rep("A", 41)), "saisie trop longue")
end

function T.matches_any_of_the_accepted_codes()
    local codes = { "BRAVO-KILO-07", "ALPHA-ZULU-99" }
    assertTrue(MilitaryDrop.Codes.matchesAny("alpha zulu 99", codes), "second code (grâce)")
    assertTrue(not MilitaryDrop.Codes.matchesAny("ALPHA-ZULU-98", codes), "aucun")
    assertTrue(not MilitaryDrop.Codes.matchesAny("x", {}), "liste vide")
end

function T.civil_calendar_round_trip()
    local Codes = MilitaryDrop.Codes
    assertEq(Codes.daysFromCivil(1970, 1, 1), 0, "époque")
    assertEq(Codes.daysFromCivil(2000, 3, 1), 11017, "après un 29 février séculaire")
    assertEq((Codes.daysFromCivil(1993, 7, 12) + 3) % 7, 0, "12 juillet 1993 : un lundi")
    for days = Codes.daysFromCivil(1991, 12, 20), Codes.daysFromCivil(1996, 3, 10) do
        local y, m, d = Codes.civilFromDays(days)
        assertEq(Codes.daysFromCivil(y, m, d), days, "aller-retour " .. y .. "-" .. m .. "-" .. d)
    end
    local y, m, d = Codes.civilFromDays(Codes.daysFromCivil(1992, 2, 29))
    assertEq(y * 10000 + m * 100 + d, 19920229, "année bissextile")
end

function T.week_changes_on_monday_midnight()
    local Codes = MilitaryDrop.Codes
    -- GameTime : mois et jours comptés depuis 0 (juillet = 6).
    local sunday = Codes.clockHours(1993, 6, 10, 23.9)
    local monday = Codes.clockHours(1993, 6, 11, 0)
    assertEq(Codes.weekOf(monday), Codes.weekOf(sunday) + 1, "lundi 00:00 : nouvelle semaine")
    assertEq(Codes.weekOf(Codes.clockHours(1993, 6, 17, 23.9)), Codes.weekOf(monday), "jusqu'au dimanche soir")
    local y, m, d = Codes.civilFromDays(Codes.weekStartDay(Codes.weekOf(sunday)))
    assertEq(y * 10000 + m * 100 + d, 19930705, "la semaine du dimanche 11 commence le lundi 5")
end

function T.previous_week_accepted_for_24_hours()
    local Codes = MilitaryDrop.Codes
    local monday = Codes.clockHours(1993, 6, 11, 0)
    local week = Codes.weekOf(monday)
    local accepted = Codes.acceptedWeeks(monday + 23.9)
    assertEq(#accepted, 2, "grâce : deux semaines")
    assertEq(accepted[2], week - 1, "la précédente")
    assertEq(#Codes.acceptedWeeks(monday + 24), 1, "fin de la grâce")
    assertEq(#Codes.acceptedWeeks(monday + 100), 1, "milieu de semaine")
end

function T.weekly_period_matches_the_week_functions()
    local Codes = MilitaryDrop.Codes
    local clock = Codes.clockHours(1993, 6, 13, 14.5)
    local week = Codes.weekOf(clock)
    assertEq(Codes.periodOf(clock, Codes.PERIOD_WEEK), week, "même numéro de semaine")
    assertEq(Codes.periodCode(777, week, Codes.PERIOD_WEEK), Codes.weeklyCode(777, week),
        "même code qu'avant l'option : parties en cours inchangées")
    assertEq(Codes.periodLastDay(week, Codes.PERIOD_WEEK), Codes.weekStartDay(week) + 6, "dimanche")
end

function T.two_week_code_changes_every_other_monday()
    local Codes = MilitaryDrop.Codes
    local P = Codes.PERIOD_TWO_WEEKS
    local changes = 0
    for k = 0, 9 do
        local monday = Codes.clockHours(1993, 6, 4 + 7 * k, 0) -- lundis à partir du 5 juillet (jours depuis 0)
        local index = Codes.periodOf(monday, P)
        changes = changes + (index ~= Codes.periodOf(monday - 0.1, P) and 1 or 0)
        assertEq(Codes.periodOf(monday + 6 * 24 + 23.9, P), index, "inchangé jusqu'au dimanche soir")
    end
    assertEq(changes, 5, "un lundi sur deux")
    local index = Codes.periodOf(Codes.clockHours(1993, 6, 13, 12), P)
    local y, m, d = Codes.civilFromDays(math.floor(Codes.periodStartClock(index, P) / 24) - 3)
    assertEq(y * 10000 + m * 100 + d, 19930712, "quinzaine du mercredi 14 : lundi 12 juillet")
    y, m, d = Codes.civilFromDays(Codes.periodLastDay(index, P))
    assertEq(y * 10000 + m * 100 + d, 19930725, "jusqu'au dimanche 25")
    local start = Codes.periodStartClock(index, P)
    assertEq(#Codes.acceptedPeriods(start + 23.9, P), 2, "grâce de 24 h")
    assertEq(#Codes.acceptedPeriods(start + 7 * 24 + 1, P), 1, "lundi du milieu : pas de changement")
    assertTrue(Codes.periodCode(777, index, P) ~= Codes.periodCode(777, index + 1, P), "nouveau code")
    assertTrue(Codes.periodCode(777, index, P) ~= Codes.periodCode(777, index, Codes.PERIOD_WEEK),
        "tirage distinct du code de la semaine")
end

function T.month_changes_on_the_first_at_midnight()
    local Codes = MilitaryDrop.Codes
    local P = Codes.PERIOD_MONTH
    local lastJuly = Codes.clockHours(1993, 6, 30, 23.9)
    local firstAugust = Codes.clockHours(1993, 7, 0, 0)
    assertEq(Codes.periodOf(firstAugust, P), Codes.periodOf(lastJuly, P) + 1, "1er août 00:00 : nouveau mois")
    assertEq(Codes.periodOf(Codes.clockHours(1993, 6, 0, 0), P), Codes.periodOf(lastJuly, P), "tout juillet")
    assertEq(Codes.periodStartClock(Codes.periodOf(lastJuly, P), P), Codes.clockHours(1993, 6, 0, 0), "début de juillet")
    local y, m, d = Codes.civilFromDays(Codes.periodLastDay(Codes.periodOf(lastJuly, P), P))
    assertEq(y * 10000 + m * 100 + d, 19930731, "dernier jour : 31 juillet")
    y, m, d = Codes.civilFromDays(Codes.periodLastDay(Codes.periodOf(Codes.clockHours(1992, 1, 3, 0), P), P))
    assertEq(y * 10000 + m * 100 + d, 19920229, "février bissextile")
    local dec = Codes.periodOf(Codes.clockHours(1993, 11, 20, 0), P)
    assertEq(Codes.periodOf(Codes.clockHours(1994, 0, 0, 0), P), dec + 1, "changement d'année")
end

function T.previous_month_accepted_for_24_hours()
    local Codes = MilitaryDrop.Codes
    local P = Codes.PERIOD_MONTH
    local first = Codes.clockHours(1993, 7, 0, 0)
    local accepted = Codes.acceptedPeriods(first + 23.9, P)
    assertEq(#accepted, 2, "grâce : deux mois")
    assertEq(accepted[2], Codes.periodOf(first, P) - 1, "le précédent")
    assertEq(#Codes.acceptedPeriods(first + 24, P), 1, "fin de la grâce")
    assertEq(#Codes.acceptedPeriods(Codes.clockHours(1993, 7, 9, 0), P), 1, "milieu du mois, même un lundi")
end

function T.monthly_code_is_stable_then_changes()
    local Codes = MilitaryDrop.Codes
    local P = Codes.PERIOD_MONTH
    local month = Codes.periodOf(Codes.clockHours(1993, 6, 13, 12), P)
    assertEq(Codes.periodCode(777, month, P), Codes.periodCode(777, month, P), "même mois, même code")
    local changes = 0
    for m = month, month + 19 do
        local code = Codes.periodCode(777, m, P)
        assertTrue(code:match("^%u+%-%u+%-%d%d$") ~= nil, "format MOT-MOT-NN : " .. code)
        changes = changes + (code ~= Codes.periodCode(777, m + 1, P) and 1 or 0)
    end
    assertEq(changes, 20, "le code change chaque mois")
end

function T.random_is_reproducible_and_bounded()
    local Codes = MilitaryDrop.Codes
    local a, b, c = Codes.newRandom(12345, 1, 7), Codes.newRandom(12345, 1, 7), Codes.newRandom(12346, 1, 7)
    local same, differs = true, false
    for _ = 1, 50 do
        local x, y, z = a(100), b(100), c(100)
        same = same and x == y
        differs = differs or x ~= z
        assertTrue(x >= 0 and x < 100 and x == math.floor(x), "entier dans [0, 100[ : " .. x)
    end
    assertTrue(same, "même graine, mêmes tirages")
    assertTrue(differs, "autre graine, autres tirages")
    assertEq(Codes.validSeed("12345"), 12345, "graine lue d'un fichier")
    assertEq(Codes.validSeed("0"), nil, "zéro refusé")
    assertEq(Codes.validSeed("1.5"), nil, "non entière refusée")
    assertEq(Codes.validSeed(Codes.MODULUS), nil, "hors bornes")
end

function T.weekly_code_is_stable_then_changes()
    local Codes = MilitaryDrop.Codes
    assertEq(Codes.weeklyCode(777, 1225), Codes.weeklyCode(777, 1225), "même semaine, même code")
    local changes = 0
    for week = 1225, 1244 do
        local code = Codes.weeklyCode(777, week)
        assertTrue(code:match("^%u+%-%u+%-%d%d$") ~= nil, "format MOT-MOT-NN : " .. code)
        if code ~= Codes.weeklyCode(777, week + 1) then
            changes = changes + 1
        end
    end
    assertEq(changes, 20, "le code change chaque semaine")
    assertTrue(Codes.weeklyCode(777, 1225) ~= Codes.weeklyCode(778, 1225), "dépend de la graine")
end

function T.cipher_table_maps_each_word_to_a_distinct_number()
    local Codes = MilitaryDrop.Codes
    local numbers = Codes.cipherTable(777)
    assertEq(#numbers, 26, "un nombre par mot")
    local seen = {}
    for _, number in ipairs(numbers) do
        assertTrue(number >= 0 and number <= 99, "00 à 99")
        assertTrue(not seen[number], "nombres distincts")
        seen[number] = true
    end
    local again = Codes.cipherTable(777)
    local other = Codes.cipherTable(778)
    local differs = false
    for i = 1, 26 do
        assertEq(again[i], numbers[i], "table fixe pour la partie")
        differs = differs or numbers[i] ~= other[i]
    end
    assertTrue(differs, "table propre à chaque partie (graine)")
end

function T.cipher_table_keeps_the_former_edition_1()
    -- Graine d'une partie de test du 2026-09-30 : ses carnets d'édition 1
    -- donnaient FOXTROT = 74 et XRAY = 46 ; ils doivent rester justes.
    local numbers = MilitaryDrop.Codes.cipherTable(1650289923)
    assertEq(numbers[6], 74, "FOXTROT")
    assertEq(numbers[24], 46, "XRAY")
end

function T.encrypt_then_decrypt_with_the_cipher_table()
    local Codes = MilitaryDrop.Codes
    local numbers = Codes.cipherTable(777)
    for i, word in ipairs(Codes.WORDS) do
        local code = word .. "-" .. Codes.WORDS[27 - i] .. "-0" .. (i % 10)
        local cipher = Codes.encrypt(code, numbers)
        assertTrue(cipher:match("^%d%d%-%d%d%-%d%d$") ~= nil, "trois groupes de deux chiffres : " .. cipher)
        assertEq(cipher:sub(-2), code:sub(-2), "chiffres en clair")
        assertEq(Codes.decrypt(cipher, numbers), code, "déchiffrement")
    end
    assertEq(Codes.encrypt("BRAVO-NOPE-01", numbers), nil, "mot inconnu")
    assertEq(Codes.decrypt("xx-04-58", numbers), nil, "groupe illisible")
end

return T
