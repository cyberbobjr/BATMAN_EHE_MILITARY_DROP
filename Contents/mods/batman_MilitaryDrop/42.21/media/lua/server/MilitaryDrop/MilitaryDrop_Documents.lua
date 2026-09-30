-- ============================================================================
-- Military Drop — mises en page des documents (serveur MP ou solo)
--
-- Deux documents, affichés comme les journaux du jeu (MilitaryDrop_PrintMedia) :
--   * memo : note de service dactylographiée (en-tête, insigne, tampon,
--     fréquence entourée et annotée à la main) ;
--   * codebook : dossier kraft ouvert (étiquette, tampon SECRET, trombone,
--     feuille avec la table en grille « groupe | mot »).
-- Les fonctions reçoivent des données déjà prêtes (textes traduits dans la
-- langue du serveur, table, fréquences) et rendent la table printMedia.
-- Textures : source/print_media/make_textures.py.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_PrintMedia"

local PM = MilitaryDrop.PrintMedia

local Documents = {}
MilitaryDrop.Documents = Documents

Documents.INK = { 0.10, 0.10, 0.12 }
Documents.NAVY = { 0.13, 0.16, 0.25 }
Documents.RED = { 0.62, 0.10, 0.12 }
Documents.BLUE = { 0.10, 0.20, 0.55 }
Documents.WHITE = { 1, 1, 1 }

local function text(content, params, color, alpha)
    return PM.text(content, PM.color(params, color or Documents.INK, alpha))
end

local function rect(x, y, width, height, color, alpha)
    return PM.texture(nil, PM.color({ x = x, y = y, width = width, height = height }, color, alpha))
end

local function t(key, ...)
    return getText("IGUI_MilitaryDrop_Doc_" .. key, ...)
end

--- En-tête commun : insigne et deux lignes, puis un filet.
local function letterhead(list, x, y, width, sealSize)
    list[#list + 1] = PM.texture("seal", { x = x, y = y, width = sealSize, height = sealSize, a = 0.92 })
    local tx = x + sealSize + 14
    list[#list + 1] = text(t("Letterhead1"), { x = tx, y = y + 6, scaleX = 0.5, scaleY = 0.5, font = "SdfOldBold" })
    list[#list + 1] = text(t("Letterhead2"), { x = tx, y = y + 36, scaleX = 0.38, scaleY = 0.38, font = "SdfOldRegular" })
    list[#list + 1] = rect(x, y + sealSize + 10, width, 2, Documents.INK, 0.85)
end

-- ----------------------------------------------------------------------------
-- Note de service
-- ----------------------------------------------------------------------------

--- data : serial, date, body, frequency (texte, ex. « 151.4 »), hand
--- (annotation manuscrite), stain (tache de café).
function Documents.memo(data)
    local W, H = 620, 820
    local list = { PM.parent(W, H) }
    list[#list + 1] = rect(10, 10, W - 10, H - 10, { 0, 0, 0 }, 0.3)
    list[#list + 1] = PM.texture("paper", { x = 0, y = 0, width = W - 10, height = H - 10 })
    if data.stain then
        list[#list + 1] = PM.texture("coffee", { x = 390, y = 590, width = 190, height = 190, a = 0.5 })
    end
    letterhead(list, 38, 36, 534, 84)
    list[#list + 1] = text(t("Memo_Date", data.date), { x = 38, y = 146, scaleX = 0.42, scaleY = 0.42, font = "SdfOldRegular" })
    list[#list + 1] = text(t("Memo_Serial", data.serial),
        { x = 572, y = 146, pivotX = 1, scaleX = 0.42, scaleY = 0.42, font = "SdfOldBold" })
    list[#list + 1] = text(t("Memo_Title"), { x = 38, y = 180, scaleX = 0.72, scaleY = 0.72, font = "SdfOldBold" })
    list[#list + 1] = text(t("Memo_Subject"), { x = 38, y = 226, scaleX = 0.42, scaleY = 0.42, font = "SdfOldBold" })
    list[#list + 1] = text(data.body, { x = 38, y = 264, scaleX = 0.44, scaleY = 0.44, autoWidth = 1210,
        textLeading = 3, font = "SdfOldRegular" })
    -- Fréquence dactylographiée, entourée et annotée au stylo.
    list[#list + 1] = text(data.frequency .. " MHz", { x = 100, y = 448, scaleX = 0.66, scaleY = 0.66, font = "SdfOldBold" })
    list[#list + 1] = PM.texture("pen_circle", { x = 36, y = 396, width = 250, height = 94, angle = -3, a = 0.9 })
    list[#list + 1] = text(data.hand, { x = 300, y = 450, scaleX = 0.8, scaleY = 0.8, angle = -4, font = "SdfCaveat" },
        Documents.BLUE, 0.92)
    list[#list + 1] = PM.texture("stamp_secret", { x = 318, y = 594, width = 250, height = 84, angle = -9, a = 0.88 })
    list[#list + 1] = text(t("Memo_SignFor"), { x = 38, y = 640, scaleX = 0.42, scaleY = 0.42, font = "SdfOldRegular" })
    list[#list + 1] = text("R. Hale", { x = 62, y = 662, scaleX = 1.0, scaleY = 1.0, angle = -5, font = "SdfCaveat" },
        Documents.BLUE, 0.9)
    list[#list + 1] = text(t("Memo_SignName"), { x = 38, y = 716, scaleX = 0.38, scaleY = 0.38, font = "SdfOldRegular" })
    list[#list + 1] = text(t("Memo_Footer"), { x = 305, y = 770, pivotX = 0.5, scaleX = 0.34, scaleY = 0.34,
        font = "SdfOldBold" }, Documents.RED)
    local transcript = table.concat({
        t("Letterhead1"), t("Memo_Title") .. " - " .. t("Memo_Serial", data.serial), t("Memo_Date", data.date), "",
        t("Memo_Subject"), "", data.body, "", data.frequency .. " MHz - " .. data.hand,
    }, "\n")
    return PM.media("MilitaryDrop_Memo", t("Memo_WindowTitle", data.serial), list, transcript)
end

-- ----------------------------------------------------------------------------
-- Carnet de codes : dossier kraft ouvert
-- ----------------------------------------------------------------------------

Documents.TABLE_ROWS = 13
Documents.TABLE_ROW_HEIGHT = 25

--- data : entries = liste triée de { number, word }.
function Documents.codebook(data)
    local W, H = 1040, 720
    local list = { PM.parent(W, H) }
    list[#list + 1] = rect(10, 8, W - 10, H - 8, { 0, 0, 0 }, 0.35)
    list[#list + 1] = PM.texture("kraft", { x = 0, y = 0, width = W - 10, height = H - 8 })

    -- Volet gauche : étiquette, tampon, note manuscrite, tache.
    local tilt = -1.2
    list[#list + 1] = PM.texture("label", { x = 66, y = 92, width = 384, height = 214, angle = tilt })
    list[#list + 1] = text(t("Secret"), { x = 96, y = 124, scaleX = 0.52, scaleY = 0.52, angle = tilt, font = "SdfOldBold" },
        Documents.WHITE)
    list[#list + 1] = text(t("Codebook_LabelTitle"), { x = 96, y = 172, scaleX = 0.8, scaleY = 0.8, angle = tilt,
        font = "SdfOldBold" }, Documents.NAVY)
    list[#list + 1] = text(t("Codebook_LabelSub"), { x = 98, y = 218, scaleX = 0.44, scaleY = 0.44, angle = tilt,
        font = "SdfOldRegular" }, Documents.NAVY)
    list[#list + 1] = text(t("Codebook_LabelUnit"), { x = 99, y = 252, scaleX = 0.4, scaleY = 0.4, angle = tilt,
        font = "SdfOldRegular" }, Documents.NAVY)
    list[#list + 1] = PM.texture("stamp_secret", { x = 92, y = 392, width = 330, height = 110, angle = -9, a = 0.85 })
    list[#list + 1] = PM.texture("coffee", { x = 300, y = 500, width = 170, height = 170, a = 0.45 })
    list[#list + 1] = text(t("Codebook_Hand"), { x = 70, y = 560, scaleX = 0.85, scaleY = 0.85, angle = -4,
        font = "SdfCaveat" }, Documents.BLUE, 0.9)

    -- Volet droit : feuille agrafée avec la table.
    local px, py, pw, ph = 540, 26, 452, 646
    list[#list + 1] = rect(px + 8, py + 8, pw, ph, { 0, 0, 0 }, 0.25)
    list[#list + 1] = PM.texture("paper", { x = px, y = py, width = pw, height = ph, angle = 0.4 })
    list[#list + 1] = PM.texture("paperclip", { x = px + 36, y = py - 22, width = 40, height = 100 })
    letterhead(list, px + 24, py + 30, pw - 48, 60)
    list[#list + 1] = text(t("Codebook_Title"), { x = px + 24, y = py + 124, scaleX = 0.56, scaleY = 0.56,
        font = "SdfOldBold" })
    list[#list + 1] = text(t("Codebook_Instructions"), { x = px + 24, y = py + 162, scaleX = 0.34, scaleY = 0.34,
        autoWidth = 1180, textLeading = 2, font = "SdfOldRegular" })

    local top = py + 256
    local colX = { px + 30, px + 238 }
    for c = 1, 2 do
        list[#list + 1] = text(t("Codebook_ColGroup"), { x = colX[c], y = top + 4, scaleX = 0.32, scaleY = 0.32,
            font = "SdfOldBold" })
        list[#list + 1] = text(t("Codebook_ColWord"), { x = colX[c] + 64, y = top + 4, scaleX = 0.32, scaleY = 0.32,
            font = "SdfOldBold" })
    end
    local rowTop = top + 24
    list[#list + 1] = rect(px + 24, rowTop - 3, pw - 48, 2, Documents.INK, 0.8)
    list[#list + 1] = rect(px + pw / 2 - 2, top - 2, 1.5, Documents.TABLE_ROWS * Documents.TABLE_ROW_HEIGHT + 30,
        Documents.INK, 0.5)
    for i, entry in ipairs(data.entries) do
        local c = i <= Documents.TABLE_ROWS and 1 or 2
        local row = (i - 1) % Documents.TABLE_ROWS
        local y = rowTop + row * Documents.TABLE_ROW_HEIGHT
        if row % 2 == 0 then
            list[#list + 1] = rect(colX[c] - 6, y, 196, Documents.TABLE_ROW_HEIGHT, Documents.NAVY, 0.06)
        end
        list[#list + 1] = text(string.format("%02d", entry.number), { x = colX[c], y = y + 9, scaleX = 0.5,
            scaleY = 0.5, font = "SdfOldBold" })
        list[#list + 1] = text(entry.word, { x = colX[c] + 64, y = y + 10, scaleX = 0.46, scaleY = 0.46,
            font = "SdfOldRegular" })
    end
    list[#list + 1] = text(t("Codebook_Footer"), { x = px + pw / 2, y = py + ph - 22, pivotX = 0.5, scaleX = 0.3,
        scaleY = 0.3, font = "SdfOldBold" }, Documents.RED)

    local lines = { t("Codebook_Title"), "", t("Codebook_Instructions"), "" }
    for _, entry in ipairs(data.entries) do
        lines[#lines + 1] = string.format("%02d  %s", entry.number, entry.word)
    end
    return PM.media("MilitaryDrop_Codebook", t("Codebook_WindowTitle"), list, table.concat(lines, "\n"))
end

return Documents
