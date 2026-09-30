-- MilitaryDrop_Codes : tirage et comparaison du code d'authentification.

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

return T
