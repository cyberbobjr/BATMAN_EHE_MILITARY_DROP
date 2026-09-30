-- ============================================================================
-- Military Drop — code d'authentification
--
-- Un code par partie, tiré par le serveur (ModData globale, jamais envoyée aux
-- clients) et écrit sur les notes militaires : deux mots de l'alphabet OTAN et
-- deux chiffres, par exemple BRAVO-KILO-42. La saisie du joueur est comparée
-- sans tenir compte de la casse, des espaces ni des tirets.
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

return Codes
