-- ============================================================================
-- Military Drop — mise en page des documents (rendu printMedia du jeu)
--
-- Un objet de lecture dont modData.printMedia = { id, title, info, text }
-- s'ouvre, par « Inspecter », dans la fenêtre des journaux vanilla
-- (ISReadABook:displayPrintMedia, PZAPI/ui/organisms/PrintMedia.lua) :
--   * info : mise en page « <type:texture, x:…, …><type:text, …>contenu… » ;
--   * title : titre de la fenêtre ;
--   * text : transcription en texte simple (bouton en bas de la fenêtre).
-- Chaque champ passe par getText : une chaîne qui n'est pas une clé revient
-- telle quelle. Le serveur y écrit donc des textes déjà traduits et
-- paramétrés (fréquences, code, table), dans sa langue.
--
-- Analyseur vanilla : il découpe sur « < », « > », puis les paramètres sur
-- « , » et « : ». Un contenu ne doit donc contenir ni « < » ni « > » ; « ^ »
-- y fait un saut de ligne ; autoWidth fait passer à la ligne en justifiant
-- (unités avant scaleX). Les valeurs numériques passent par tonumber.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local PrintMedia = {}
MilitaryDrop.PrintMedia = PrintMedia

PrintMedia.TEXTURES = "media/textures/printMedia/MilitaryDrop/"

-- Ordre d'écriture des paramètres (une sortie stable facilite les tests).
local KEYS = {
    "texture", "font", "x", "y", "width", "height", "pivotX", "pivotY", "scaleX", "scaleY",
    "angle", "r", "g", "b", "a", "autoWidth", "textLeading",
}

--- Nombre sans exposant ni zéros inutiles : 12, 0.35, -1.5.
function PrintMedia.number(value)
    if value == math.floor(value) then
        return string.format("%d", value)
    end
    return (string.format("%.3f", value):gsub("0+$", ""))
end

--- Contenu sûr pour l'analyseur : sans « < » ni « > », « % » retiré (le
--- texte repasse par getText), retours à la ligne en « ^ ».
function PrintMedia.clean(text)
    local s = tostring(text or "")
    s = s:gsub("[<>%%]", "")
    s = s:gsub("\r", ""):gsub("\n", "^")
    return s
end

--- Élément de type kind avec ses paramètres (table), suivi de son contenu.
function PrintMedia.element(kind, params, content)
    local parts = { "type:" .. kind }
    for _, key in ipairs(KEYS) do
        local value = params[key]
        if value ~= nil then
            if type(value) == "number" then
                value = PrintMedia.number(value)
            else
                -- Chemins et noms de police : jamais de séparateur.
                value = tostring(value):gsub("[,:<>]", "")
            end
            parts[#parts + 1] = key .. ":" .. value
        end
    end
    return "<" .. table.concat(parts, ", ") .. ">" .. (content and PrintMedia.clean(content) or "")
end

function PrintMedia.parent(width, height)
    return PrintMedia.element("parent", { width = width, height = height })
end

--- Texture du mod (nom de fichier sans extension) ou rectangle de couleur (nil).
function PrintMedia.texture(name, params)
    local p = {}
    for k, v in pairs(params) do
        p[k] = v
    end
    if name then
        p.texture = PrintMedia.TEXTURES .. name .. ".png"
    end
    return PrintMedia.element("texture", p)
end

function PrintMedia.text(content, params)
    return PrintMedia.element("text", params, content)
end

--- Couleur { r, g, b } recopiée dans des paramètres.
function PrintMedia.color(params, color, alpha)
    params.r, params.g, params.b = color[1], color[2], color[3]
    params.a = alpha or params.a or 1
    return params
end

--- Table printMedia à poser dans modData.
function PrintMedia.media(id, title, elements, transcript)
    return {
        id = id,
        title = PrintMedia.clean(title),
        info = table.concat(elements),
        text = transcript or "",
    }
end

return PrintMedia
