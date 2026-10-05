-- ============================================================================
-- Military Drop — fichier des lots de réquisition (v1.4, serveur MP ou solo)
--
-- L'admin définit les lots du formulaire dans un fichier :
-- Zomboid/Lua/MilitaryDrop/requisition.txt. getFileReader et getFileWriter
-- résolvent ce chemin dans getCacheDir()/Lua (LuaManager.getLuaCacheDir,
-- LuaManager.java:1261-1262), le dossier Zomboid du compte système qui lance
-- le jeu ou le serveur (ou celui de l'option -cachedir) : le fichier est
-- commun à TOUTES les parties solo et à TOUS les serveurs lancés par ce
-- compte, pas propre à une partie. Écrit au premier démarrage avec les 18
-- lots par défaut (MilitaryDrop.Lots.DEFAULTS) et une notice en anglais
-- (seulement, demande de l'utilisateur du 2026-10-01), qui le dit.
--
-- Extension : getFileWriter refuse toute extension hors ini, cfg, txt, log et
-- json (LuaManager.java:1045 ALLOWED_FILE_EXTENSIONS, 5535-5540) : un fichier
-- « .lua » ne pourrait pas être créé par le mod. Le contenu garde la syntaxe
-- d'une table Lua.
--
-- Lecture : aucune exécution. loadstring existe dans Kahlua 42.21
-- (LuaCompiler.java:31-35, 72-83, enregistré par J2SEPlatform.java:62) et
-- setfenv aussi (BaseLib.java:168-193), mais un environnement vide
-- n'empêcherait ni une boucle infinie ni les méthodes des chaînes : le fichier
-- est lu par un petit analyseur de données (chaînes, nombres, booléens, nil,
-- tables), qui refuse tout nom, opérateur ou appel.
--
-- Validation : une erreur de syntaxe garde les 18 lots par défaut ; un lot
-- invalide garde le lot par défaut de même identifiant (un lot ajouté est
-- écarté) ; un lot par défaut absent du fichier est gardé (enabled = false
-- pour le retirer). Chaque problème est écrit au journal ([MilitaryDrop],
-- toujours). Les options sandbox (budget, coûts, paliers, explosifs)
-- s'appliquent ensuite comme aux lots par défaut.
--
-- Chargement : avant le premier usage des lots (Lots.loader, démarrage du
-- serveur ou de la partie, premier formulaire, ouverture d'une caisse).
-- Rechargement par l'admin : MilitaryDrop.Requisition.reload().
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"
require "MilitaryDrop/MilitaryDrop_Lots"

local Lots = MilitaryDrop.Lots

local LotsFile = {}
MilitaryDrop.LotsFile = LotsFile

LotsFile.PATH = "MilitaryDrop/requisition.txt"
LotsFile.VERSION = 1
-- Garde-fous de lecture.
LotsFile.MAX_LINES = 4000
LotsFile.MAX_CHARS = 131072
LotsFile.MAX_DEPTH = 6
-- Total des lots, défauts compris (valeur citée dans LotsFile.NOTICE).
LotsFile.MAX_LOTS = 40
-- Bornes des champs d'un lot.
LotsFile.MAX_ID = 32
LotsFile.MAX_COST = 99
LotsFile.MAX_COUNT = 20
LotsFile.MAX_LIST = 64
LotsFile.MAX_WEIGHT = 1000
LotsFile.MAX_LABEL = 48
LotsFile.MAX_DESC = 240

local loaded = false
-- Dernier chargement : { source = "file"|"created"|"defaults", lots = n, problems = { … } }.
local lastReport = nil

-- ----------------------------------------------------------------------------
-- Analyseur de données (sous-ensemble de la syntaxe des tables Lua)
-- ----------------------------------------------------------------------------

local function isSpace(c)
    return c == " " or c == "\t" or c == "\r" or c == "\n" or c == "\f" or c == "\v"
end

local function isDigit(c)
    return c ~= "" and c >= "0" and c <= "9"
end

local function isNameStart(c)
    return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")
end

local function isNameChar(c)
    return isNameStart(c) or isDigit(c)
end

local function newParser(text)
    return { s = text, i = 1, n = #text, line = 1, err = nil }
end

local function peek(p, offset)
    local at = p.i + (offset or 0)
    return p.s:sub(at, at)
end

local function fail(p, message)
    if not p.err then
        p.err = "line " .. p.line .. ": " .. message
    end
    return nil
end

--- Avance de count caractères en comptant les lignes.
local function advance(p, count)
    for _ = 1, count do
        if peek(p) == "\n" then
            p.line = p.line + 1
        end
        p.i = p.i + 1
    end
end

--- Niveau d'un crochet long « [==[ » à la position courante, ou nil.
local function longBracketLevel(p)
    if peek(p) ~= "[" then
        return nil
    end
    local level = 0
    while peek(p, level + 1) == "=" do
        level = level + 1
    end
    if peek(p, level + 1) == "[" then
        return level
    end
    return nil
end

--- Lit un crochet long (commentaire ou chaîne) ; renvoie son contenu.
local function readLong(p, level)
    advance(p, level + 2)
    -- Sans string.rep (écrit en Lua dans stdlib.lua, Kahlua 42.21 : lent).
    local close = "]"
    for _ = 1, level do
        close = close .. "="
    end
    close = close .. "]"
    local stop = p.s:find(close, p.i, true)
    if not stop then
        return fail(p, "unfinished long string or comment")
    end
    local content = p.s:sub(p.i, stop - 1)
    advance(p, stop - p.i + #close)
    -- Un saut de ligne juste après l'ouverture est ignoré (comme en Lua).
    if content:sub(1, 1) == "\r" then
        content = content:sub(2)
    end
    if content:sub(1, 1) == "\n" then
        content = content:sub(2)
    end
    return content
end

--- Espaces et commentaires.
local function skipBlank(p)
    while p.i <= p.n and not p.err do
        local c = peek(p)
        if isSpace(c) then
            advance(p, 1)
        elseif c == "-" and peek(p, 1) == "-" then
            advance(p, 2)
            local level = longBracketLevel(p)
            if level then
                readLong(p, level)
            else
                while p.i <= p.n and peek(p) ~= "\n" do
                    p.i = p.i + 1
                end
            end
        else
            return
        end
    end
end

local ESCAPES = { n = "\n", t = "\t", r = "\r", a = "\a", b = "\b", f = "\f", v = "\v",
    ["\\"] = "\\", ['"'] = '"', ["'"] = "'", ["\n"] = "\n" }

local function readString(p)
    local quote = peek(p)
    advance(p, 1)
    local parts = {}
    while true do
        if p.i > p.n then
            return fail(p, "unfinished string")
        end
        local c = peek(p)
        if c == quote then
            advance(p, 1)
            return table.concat(parts)
        elseif c == "\n" then
            return fail(p, "unfinished string (end of line)")
        elseif c == "\\" then
            local e = peek(p, 1)
            if ESCAPES[e] then
                parts[#parts + 1] = ESCAPES[e]
                advance(p, 2)
            elseif isDigit(e) then
                local digits = e
                advance(p, 2)
                while #digits < 3 and isDigit(peek(p)) do
                    digits = digits .. peek(p)
                    advance(p, 1)
                end
                local code = tonumber(digits)
                if code > 255 then
                    return fail(p, "bad escape \\" .. digits)
                end
                parts[#parts + 1] = string.char(code)
            else
                return fail(p, "bad escape \\" .. e)
            end
        else
            parts[#parts + 1] = c
            advance(p, 1)
        end
    end
end

local function readNumber(p, negative)
    local start = p.i
    while p.i <= p.n do
        local c = peek(p)
        if isNameChar(c) or c == "." or ((c == "+" or c == "-") and (peek(p, -1) == "e" or peek(p, -1) == "E")) then
            p.i = p.i + 1
        else
            break
        end
    end
    local token = p.s:sub(start, p.i - 1)
    local mantissa, exponent = token:match("^([%d%.]+)([eE]?[%+%-]?%d*)$")
    local value = mantissa and (mantissa:match("^%d+%.?%d*$") or mantissa:match("^%.%d+$"))
        and (exponent == "" or exponent:match("^[eE][%+%-]?%d+$")) and tonumber(token)
    if not value then
        return fail(p, "bad number " .. token)
    end
    return negative and -value or value
end

local function readName(p)
    local start = p.i
    while p.i <= p.n and isNameChar(peek(p)) do
        p.i = p.i + 1
    end
    return p.s:sub(start, p.i - 1)
end

local readTable

--- Valeur : nil, booléen, nombre, chaîne ou table. Rien d'autre.
local function readValue(p, depth)
    skipBlank(p)
    if p.err then
        return nil
    end
    local c = peek(p)
    if c == "{" then
        return readTable(p, depth + 1)
    elseif c == '"' or c == "'" then
        return readString(p)
    elseif c == "[" and longBracketLevel(p) then
        return readLong(p, longBracketLevel(p))
    elseif isDigit(c) or (c == "." and isDigit(peek(p, 1))) then
        return readNumber(p, false)
    elseif c == "-" then
        advance(p, 1)
        skipBlank(p)
        if isDigit(peek(p)) or (peek(p) == "." and isDigit(peek(p, 1))) then
            return readNumber(p, true)
        end
        return fail(p, "only data is allowed: unexpected '-'")
    elseif isNameStart(c) then
        local name = readName(p)
        if name == "true" then
            return true
        elseif name == "false" then
            return false
        elseif name == "nil" then
            return nil
        end
        return fail(p, "only data is allowed: unexpected name '" .. name .. "'")
    elseif c == "" then
        return fail(p, "unexpected end of file")
    end
    return fail(p, "only data is allowed: unexpected '" .. c .. "'")
end

--- Table : { valeur, nom = valeur, ["clé"] = valeur, … } (séparateurs , ou ;).
function readTable(p, depth)
    if depth > LotsFile.MAX_DEPTH then
        return fail(p, "tables nested too deep")
    end
    advance(p, 1)
    local result, index = {}, 0
    while true do
        skipBlank(p)
        if p.err then
            return nil
        end
        local c = peek(p)
        if c == "}" then
            advance(p, 1)
            return result
        end
        local key, value
        if c == "[" and not longBracketLevel(p) then
            advance(p, 1)
            key = readValue(p, depth)
            skipBlank(p)
            if p.err then
                return nil
            end
            if type(key) ~= "string" and type(key) ~= "number" then
                return fail(p, "a key must be a string or a number")
            end
            if peek(p) ~= "]" then
                return fail(p, "']' expected")
            end
            advance(p, 1)
            skipBlank(p)
            if peek(p) ~= "=" then
                return fail(p, "'=' expected")
            end
            advance(p, 1)
            value = readValue(p, depth)
        elseif isNameStart(c) then
            -- Nom suivi de « = » : clé ; sinon valeur (true, false, nil).
            local save, saveLine = p.i, p.line
            local name = readName(p)
            skipBlank(p)
            if peek(p) == "=" and peek(p, 1) ~= "=" then
                advance(p, 1)
                key = name
                value = readValue(p, depth)
            else
                p.i, p.line = save, saveLine
                value = readValue(p, depth)
                index = index + 1
                key = index
            end
        else
            value = readValue(p, depth)
            index = index + 1
            key = index
        end
        if p.err then
            return nil
        end
        if value ~= nil then
            result[key] = value
        end
        skipBlank(p)
        c = peek(p)
        if c == "," or c == ";" then
            advance(p, 1)
        elseif c ~= "}" then
            if c == "" then
                return fail(p, "'}' expected before the end of file")
            end
            return fail(p, "',' or '}' expected, found '" .. c .. "'")
        end
    end
end

--- Table de données d'un texte « [return] { … } », ou nil et l'erreur
--- (« line N: … »). Aucun code n'est exécuté.
function LotsFile.parse(text)
    if type(text) ~= "string" then
        return nil, "no text"
    end
    -- Marque d'ordre d'octets UTF-8 (éditeurs Windows) : octets ou caractère.
    if text:sub(1, 3) == "\239\187\191" then
        text = text:sub(4)
    elseif text:byte(1) == 65279 then
        text = text:sub(2)
    end
    local p = newParser(text)
    skipBlank(p)
    if isNameStart(peek(p)) then
        local save = p.i
        if readName(p) ~= "return" then
            p.i = save
        end
        skipBlank(p)
    end
    if peek(p) ~= "{" then
        fail(p, "the file must contain one table: return { ... }")
        return nil, p.err
    end
    local data = readTable(p, 1)
    if p.err then
        return nil, p.err
    end
    skipBlank(p)
    if p.err then
        return nil, p.err
    end
    if p.i <= p.n then
        fail(p, "only one table is allowed: unexpected text after it")
        return nil, p.err
    end
    return data
end

-- ----------------------------------------------------------------------------
-- Validation d'un lot
-- ----------------------------------------------------------------------------

local BASE_FIELDS = { id = true, enabled = true, group = true, cost = true, count = true, extras = true, texts = true }
local FILTER_FIELDS = {}
for _, name in ipairs(Lots.FILTER_FIELDS) do
    FILTER_FIELDS[name] = true
end

local function isInteger(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end

local function isNumber(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high
end

--- Liste de chaînes (une chaîne seule est acceptée) dont chaque élément
--- respecte le motif ; nil et l'erreur sinon.
local function stringList(value, field, pattern, maxLength)
    if type(value) == "string" then
        value = { value }
    end
    if type(value) ~= "table" then
        return nil, field .. " must be a list of strings"
    end
    local list, count = {}, 0
    for _ in pairs(value) do
        count = count + 1
    end
    if count == 0 or count ~= #value or count > LotsFile.MAX_LIST then
        return nil, field .. " must be a non-empty list of strings (1-" .. LotsFile.MAX_LIST .. ")"
    end
    for i, item in ipairs(value) do
        if type(item) ~= "string" or #item > maxLength or not item:match(pattern) then
            return nil, field .. " #" .. i .. " is not valid: " .. tostring(item)
        end
        list[i] = item
    end
    return list
end

--- Texte affiché d'un lot ajouté : sans caractère de contrôle ni balise de
--- texte enrichi, espaces resserrés.
local function cleanText(text, maxLength)
    local cleaned = text:gsub("%c", " "):gsub("[<>]", ""):gsub("%s+", " ")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
    -- Borne en caractères (chaîne Java sous Kahlua), sans couper un caractère.
    return MilitaryDrop.cutText(cleaned, maxLength)
end

local function validateTexts(value)
    if type(value) ~= "table" then
        return nil, "texts must be a table { EN = { label = ..., desc = ... }, ... }"
    end
    local texts, any = {}, false
    for language, entry in pairs(value) do
        if type(language) ~= "string" or not language:match("^%u[%u%d_]*$") or #language > 8 then
            return nil, "texts: bad language code " .. tostring(language) .. " (EN, FR, ...)"
        end
        if type(entry) ~= "table" or type(entry.label) ~= "string" then
            return nil, "texts." .. language .. " must be { label = \"...\", desc = \"...\" }"
        end
        if entry.desc ~= nil and type(entry.desc) ~= "string" then
            return nil, "texts." .. language .. ".desc must be a string"
        end
        for key in pairs(entry) do
            if key ~= "label" and key ~= "desc" then
                return nil, "texts." .. language .. ": unknown field " .. tostring(key)
            end
        end
        local label = cleanText(entry.label, LotsFile.MAX_LABEL)
        if label == "" then
            return nil, "texts." .. language .. ".label is empty"
        end
        texts[language] = { label = label, desc = cleanText(entry.desc or "", LotsFile.MAX_DESC) }
        any = true
    end
    if not any then
        return nil, "texts has no language"
    end
    return texts
end

local function copyList(list)
    if not list then
        return nil
    end
    local copy = {}
    for i, value in ipairs(list) do
        copy[i] = value
    end
    return copy
end

--- Champs de filtre d'une entrée, validés ; nil et l'erreur sinon.
local function validateFilter(entry, def)
    local err
    if entry.items ~= nil then
        for name in pairs(FILTER_FIELDS) do
            if entry[name] ~= nil and name ~= "items" and name ~= "fluid" then
                return nil, "items replaces the filter: remove " .. name
            end
        end
        def.items, err = stringList(entry.items, "items", "^[%w_%-]+%.[^%s]+$", 128)
        if not def.items then
            return nil, err
        end
    end
    if entry.categories ~= nil then
        def.categories, err = stringList(entry.categories, "categories", "^[%w_]+$", 64)
        if not def.categories then
            return nil, err
        end
    end
    for _, field in ipairs({ "tags", "notTags" }) do
        if entry[field] ~= nil then
            def[field], err = stringList(entry[field], field, "^[%w_%.%-/:]+$", 128)
            if not def[field] then
                return nil, err
            end
        end
    end
    for _, field in ipairs({ "minWeight", "maxWeight" }) do
        if entry[field] ~= nil then
            if not isNumber(entry[field], 0, LotsFile.MAX_WEIGHT) then
                return nil, field .. " must be a number from 0 to " .. LotsFile.MAX_WEIGHT
            end
            def[field] = entry[field]
        end
    end
    if def.minWeight and def.maxWeight and def.minWeight > def.maxWeight then
        return nil, "minWeight is above maxWeight"
    end
    if entry.kind ~= nil then
        if type(entry.kind) ~= "string" or not Lots.KINDS[entry.kind] then
            return nil, "kind must be one of: " .. table.concat(Lots.KIND_NAMES, ", ")
        end
        def.kind = entry.kind
    end
    if entry.fluid ~= nil then
        if type(entry.fluid) ~= "string" or not entry.fluid:match("^%a+$") then
            return nil, "fluid must be a fluid name (Water, Petrol)"
        end
        def.fluid = entry.fluid
    end
    for _, field in ipairs({ "minLiters", "maxLiters" }) do
        if entry[field] ~= nil then
            if not def.fluid or def.items then
                return nil, field .. " needs a fluid filter"
            end
            if not isNumber(entry[field], 0, LotsFile.MAX_WEIGHT) then
                return nil, field .. " must be a number from 0 to " .. LotsFile.MAX_WEIGHT
            end
            def[field] = entry[field]
        end
    end
    if def.minLiters and def.maxLiters and def.minLiters > def.maxLiters then
        return nil, "minLiters is above maxLiters"
    end
    if not (def.items or def.categories or def.tags or def.kind) then
        return nil, "the filter needs categories, tags, kind or items"
    end
    return def
end

--- Définition validée d'une entrée du fichier (copie, champs manquants d'un
--- lot par défaut repris de lui), ou nil et l'erreur.
function LotsFile.validate(entry)
    if type(entry) ~= "table" then
        return nil, "a lot must be a table { id = ..., ... }"
    end
    local id = entry.id
    if type(id) ~= "string" or #id > LotsFile.MAX_ID or not id:match("^[%a_][%w_]*$") then
        return nil, "id must be a name (letters, digits, _; " .. LotsFile.MAX_ID .. " characters at most)"
    end
    for key in pairs(entry) do
        if not BASE_FIELDS[key] and not FILTER_FIELDS[key] then
            return nil, "unknown field " .. tostring(key)
        end
    end
    local default = Lots.defaultOf(id)
    local def = { id = id }
    if entry.enabled ~= nil and type(entry.enabled) ~= "boolean" then
        return nil, "enabled must be true or false"
    end
    def.enabled = entry.enabled ~= false
    local bounds = { group = { 1, 3 }, cost = { 1, LotsFile.MAX_COST }, count = { 1, LotsFile.MAX_COUNT } }
    for _, field in ipairs({ "group", "cost", "count" }) do
        local value = entry[field]
        if value == nil and default then
            value = default[field]
        end
        if value == nil then
            return nil, field .. " is missing (added lot)"
        end
        if not isInteger(value, bounds[field][1], bounds[field][2]) then
            return nil, field .. " must be a whole number from " .. bounds[field][1] .. " to " .. bounds[field][2]
        end
        def[field] = value
    end
    if entry.extras ~= nil and type(entry.extras) ~= "boolean" then
        return nil, "extras must be true or false"
    end
    if entry.texts ~= nil and default then
        -- Les ids par défaut gardent leurs traductions (notice du fichier).
        return nil, "texts is only for added lots: the default id " .. id
            .. " keeps its translated name and description (remove texts, or use a new id)"
    elseif entry.texts ~= nil then
        local texts, err = validateTexts(entry.texts)
        if not texts then
            return nil, err
        end
        def.texts = texts
    elseif not default then
        return nil, "texts is missing (added lot): texts = { EN = { label = ..., desc = ... } }"
    end
    local hasFilter = false
    for name in pairs(FILTER_FIELDS) do
        hasFilter = hasFilter or entry[name] ~= nil
    end
    if hasFilter then
        local _, err = validateFilter(entry, def)
        if err then
            return nil, err
        end
    elseif default then
        for _, name in ipairs(Lots.FILTER_FIELDS) do
            local value = default[name]
            def[name] = type(value) == "table" and copyList(value) or value
        end
    else
        return nil, "the filter needs categories, tags, kind or items"
    end
    if entry.extras ~= nil then
        def.extras = entry.extras
    elseif default then
        def.extras = default.extras
    end
    return def
end

-- ----------------------------------------------------------------------------
-- Liste des lots
-- ----------------------------------------------------------------------------

--- Liste compilée (ordre du fichier) d'une table lue, et les problèmes
--- relevés ({ "…", … }). Sans liste de lots valide : les défauts.
function LotsFile.build(data)
    local problems, list, seen = {}, {}, {}
    local function add(def)
        list[#list + 1] = Lots.compile(def)
        seen[def.id] = true
    end
    local lots = type(data) == "table" and data.lots
    if type(lots) ~= "table" then
        problems[#problems + 1] = "no lots = { ... } table: default lots used"
        return Lots.defaultList(), problems
    end
    for key in pairs(data) do
        if key ~= "lots" and key ~= "version" then
            problems[#problems + 1] = "unknown top-level field " .. tostring(key) .. " ignored"
        end
    end
    local count = 0
    for _ in pairs(lots) do
        count = count + 1
    end
    if count ~= #lots then
        problems[#problems + 1] = "lots must be a plain list: entries with keys ignored"
    end
    -- MAX_LOTS borne le total, lots par défaut compris : ceux-ci sont toujours
    -- gardés (du fichier, ou ajoutés à la fin s'ils y manquent), donc leur
    -- place est réservée et seuls les lots ajoutés au-delà sont écartés.
    local added = 0
    for i, entry in ipairs(lots) do
        local id = type(entry) == "table" and type(entry.id) == "string" and entry.id or nil
        local def, err = LotsFile.validate(entry)
        if def and seen[def.id] then
            def, err = nil, "duplicate id"
        end
        if def and not Lots.defaultOf(def.id) then
            if added + #Lots.DEFAULTS >= LotsFile.MAX_LOTS then
                def, err = nil, "more than " .. LotsFile.MAX_LOTS .. " lots in all (default lots included)"
            else
                added = added + 1
            end
        end
        if def then
            add(def)
        else
            local where = "lot #" .. i .. (id and (" (" .. id .. ")") or "")
            if id and not seen[id] and Lots.defaultOf(id) then
                add(Lots.defaultOf(id))
                problems[#problems + 1] = where .. ": " .. err .. "; default lot kept"
            else
                problems[#problems + 1] = where .. ": " .. err .. "; lot ignored"
            end
        end
    end
    for _, def in ipairs(Lots.DEFAULTS) do
        if not seen[def.id] then
            add(def)
            problems[#problems + 1] = "default lot " .. def.id .. " missing from the file: kept"
                .. " (set enabled = false to remove it)"
        end
    end
    return list, problems
end

-- ----------------------------------------------------------------------------
-- Fichier par défaut
-- ----------------------------------------------------------------------------

local function formatNumber(value)
    if value == math.floor(value) then
        return string.format("%d", value)
    end
    local text = string.format("%.4f", value):gsub("0+$", "")
    return text
end

local function quote(text)
    return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
end

local function formatValue(value)
    if type(value) == "number" then
        return formatNumber(value)
    elseif type(value) == "string" then
        return quote(value)
    elseif type(value) == "table" then
        local parts = {}
        for i, item in ipairs(value) do
            parts[i] = formatValue(item)
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return tostring(value)
end

--- Une définition en deux lignes : réglages, puis filtre.
local function formatLot(def)
    local head = { "id = " .. quote(def.id), "enabled = true" }
    for _, field in ipairs({ "group", "cost", "count" }) do
        head[#head + 1] = field .. " = " .. formatValue(def[field])
    end
    local filter = {}
    for _, field in ipairs(Lots.FILTER_FIELDS) do
        if def[field] ~= nil then
            filter[#filter + 1] = field .. " = " .. formatValue(def[field])
        end
    end
    if def.extras then
        filter[#filter + 1] = "extras = true"
    end
    return "    {\n        " .. table.concat(head, ", ") .. ",\n        " .. table.concat(filter, ", ") .. ",\n    },\n"
end

LotsFile.NOTICE = [[
-- ============================================================================
-- Military Drop - requisition lots
-- ============================================================================
--
-- Lots offered by the requisition form. This file lives in the Zomboid/Lua
-- folder of the system account that runs the game or the server: it is
-- shared by EVERY single-player save and EVERY server started by this account
-- (not by one save only). It was written with the 18 default lots: edit it,
-- then restart or reload (see below). Delete it to get the default file back
-- at the next start.
--
-- Only data is read: one table, no code (functions, names and operators are
-- refused). A syntax error keeps all the default lots. An invalid lot keeps
-- the default lot of the same id; an invalid added lot is skipped. A default
-- lot missing from this file is kept: set enabled = false to remove it.
-- Problems are written to the server console (console.txt), "[MilitaryDrop]".
-- The sandbox options still apply: budget, cost multiplier, tiers, explosives.
--
-- Fields of a lot:
--   id        name (letters, digits, _). The 18 default ids keep their
--             translated name and description.
--   enabled   true or false (false: not offered).
--   group     tier 1, 2 or 3 (options RequisitionTier2, RequisitionTier3).
--   cost      points per case, 1-99 (before RequisitionCostMultiplier).
--   count     items drawn when a requisition case is opened, 1-20.
-- Filter: every given field must match; a list matches any of its values.
--   categories  display categories of the item scripts (DisplayCategory):
--               Food, Tool, Material, Cooking, Literature, Clothing...
--   tags        item tags, at least one of them ("base:petrol").
--   notTags     item tags the item must not have.
--   minWeight, maxWeight   item weight bounds.
--   kind        item family recognised by the mod: ration, firearm, melee,
--               ammo, armor, attachment, pack.
--   fluid       container that accepts this fluid (Water, Petrol), delivered
--               full; minLiters, maxLiters bound its capacity.
--   extras      true: each firearm comes with 2 magazines and 1 ammo box.
-- Candidates: the items of all the loot tables (game and active mods),
-- weighted by their loot weight. Filter fields given for a default id
-- replace its whole default filter.
--
-- Added lot: a new id with group, cost, count, a filter and its texts. The
-- form shows the player's language, else English, else the first language:
--   {
--       id = "kitchen", enabled = true, group = 1, cost = 2, count = 3,
--       categories = { "Cooking" }, maxWeight = 3,
--       texts = { EN = { label = "Kitchen", desc = "Pots, pans and cutlery." },
--                 FR = { label = "Cuisine", desc = "Casseroles, poêles et couverts." } },
--   },
-- texts is only for added lots (a default id with texts is refused). At most
-- 40 lots in all, the 18 default lots included.
-- To withdraw an added lot, set enabled = false rather than deleting it:
-- requisition cases already delivered keep its id, and a case whose lot is
-- no longer in this file cannot be opened (it is given back, closed) until
-- the lot is back.
--
-- Admin option, never used by default: items = { "Module.Type", ... } draws
-- only these items, at equal weight, even outside the loot tables. It
-- replaces the filter (only fluid may be added).
--
-- Reload without restarting (admin):
--   single player, debug console:  MilitaryDrop.Requisition.reload()
--   multiplayer, admin's debug console:
--     sendClientCommand(getPlayer(), "MilitaryDrop", "ReloadLots", {})
--   (admin role only; once every few seconds for the whole server; the
--   summary and the problems are printed in the admin's console)
]]

--- Texte du fichier par défaut : notice, puis les 18 lots.
function LotsFile.defaultText()
    local parts = { LotsFile.NOTICE, "return {\n    version = " .. LotsFile.VERSION .. ",\n    lots = {\n" }
    for _, def in ipairs(Lots.DEFAULTS) do
        parts[#parts + 1] = formatLot(def):gsub("\n    ", "\n        "):gsub("^    ", "        ")
    end
    parts[#parts + 1] = "    },\n}\n"
    return table.concat(parts)
end

-- ----------------------------------------------------------------------------
-- Lecture, écriture, chargement
-- ----------------------------------------------------------------------------

--- Texte du fichier ; nil s'il n'existe pas ; false et l'erreur s'il est trop
--- long. path (facultatif) : autre fichier du dossier Lua lu avec les mêmes
--- garde-fous (zones de largage, MilitaryDrop_ZonesFile.lua).
function LotsFile.readText(path)
    local reader = getFileReader(path or LotsFile.PATH, false)
    if not reader then
        return nil
    end
    local lines, chars = {}, 0
    while true do
        local line = reader:readLine()
        if line == nil then
            break
        end
        lines[#lines + 1] = line
        chars = chars + #line + 1
        if #lines > LotsFile.MAX_LINES or chars > LotsFile.MAX_CHARS then
            reader:close()
            return false, "file too long (" .. LotsFile.MAX_LINES .. " lines, "
                .. LotsFile.MAX_CHARS .. " characters at most)"
        end
    end
    reader:close()
    return table.concat(lines, "\n")
end

--- Écrit le fichier par défaut ; vrai s'il a pu être écrit.
function LotsFile.writeDefault()
    local writer = getFileWriter(LotsFile.PATH, true, false)
    if not writer then
        MilitaryDrop.log("cannot write " .. LotsFile.PATH .. ": default requisition lots used", true)
        return false
    end
    writer:write(LotsFile.defaultText())
    writer:close()
    MilitaryDrop.log("requisition lots written to Zomboid/Lua/" .. LotsFile.PATH .. " (default lots)", true)
    return true
end

--- Lit le fichier (le crée s'il manque) et installe la liste des lots.
--- Renvoie le rapport { source, lots, problems }.
function LotsFile.load()
    loaded = true
    local report = { problems = {} }
    local text, readError = LotsFile.readText()
    local list
    if text == nil then
        LotsFile.writeDefault()
        report.source = "created"
        list = Lots.defaultList()
    elseif text == false then
        report.source = "defaults"
        report.problems[1] = readError .. ": default lots used"
        list = Lots.defaultList()
    else
        local data, parseError = LotsFile.parse(text)
        if data then
            report.source = "file"
            list, report.problems = LotsFile.build(data)
        else
            report.source = "defaults"
            report.problems[1] = "syntax error, " .. tostring(parseError) .. ": default lots used"
            list = Lots.defaultList()
        end
    end
    Lots.setList(list)
    report.lots = #list
    for _, problem in ipairs(report.problems) do
        MilitaryDrop.log(LotsFile.PATH .. ": " .. problem, true)
    end
    MilitaryDrop.log("requisition lots: " .. report.lots .. " from " .. report.source
        .. ", " .. #report.problems .. " problem(s)", true)
    lastReport = report
    return report
end

--- Charge le fichier une fois (premier usage).
function LotsFile.ensureLoaded()
    if not loaded then
        LotsFile.load()
    end
end

--- Relit le fichier (commande d'admin) ; renvoie le rapport. Les listes des
--- lots (Lots.register) et les propriétés lues sur des exemplaires
--- (Lots.clearCaches) sont recalculées ; les autres caisses de Loot gardent
--- les leurs.
function LotsFile.reload()
    Lots.clearCaches()
    return LotsFile.load()
end

--- Rapport du dernier chargement, ou nil.
function LotsFile.lastReport()
    return lastReport
end

--- Oublie le chargement (tests) : la liste par défaut revient.
function LotsFile.reset()
    loaded = false
    lastReport = nil
    Lots.setList(Lots.defaultList())
end

Lots.loader = LotsFile.ensureLoaded

return LotsFile
