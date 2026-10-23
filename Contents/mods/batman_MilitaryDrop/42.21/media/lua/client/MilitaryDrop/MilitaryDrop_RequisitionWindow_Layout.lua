-- Military Drop — formulaire de réquisition (client) : mesures et disposition
-- Partie de MilitaryDrop_RequisitionWindow.lua (voir son en-tête).

require "MilitaryDrop/MilitaryDrop_RequisitionWindow"

local RW = MilitaryDrop.RequisitionWindow
local U = RW.util
local measure, fontHeight, BUDGET_KEYS = U.measure, U.fontHeight, U.BUDGET_KEYS

-- ----------------------------------------------------------------------------
-- Mesures et disposition
-- ----------------------------------------------------------------------------

local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

local function monoLanguage()
    -- Translator.getLanguage():name() : même lecture que le vanilla (ISLcdBar.lua:14).
    local language = Translator and Translator.getLanguage()
    local name = language and language:name()
    return name ~= nil and RW.MONO_LANGUAGES[tostring(name)] == true
end

--- Police « machine à écrire » si la langue tient en Latin-1, sinon UIFont.Small.
function RW.typedFont()
    if monoLanguage() and UIFont.CodeSmall then
        return UIFont.CodeSmall
    end
    return UIFont.Small
end

function RW.titleFont()
    if monoLanguage() and UIFont.CodeMedium then
        return UIFont.CodeMedium
    end
    return UIFont.Medium
end

--- Chiffres écrits à la main (police manuscrite du jeu, chiffres universels).
function RW.handFont()
    return UIFont.Handwritten or RW.typedFont()
end

--- Retire le dernier caractère, toujours au moins une unité (Kahlua : chaîne
--- Java en UTF-16, pas en octets UTF-8 ; voir MilitaryDrop.dropLastChar).
local function dropLastChar(text)
    return MilitaryDrop.dropLastChar(text)
end

--- Texte raccourci (« ... ») pour tenir dans maxWidth.
function RW.fit(text, font, maxWidth)
    text = tostring(text or "")
    if measure(text, font) <= maxWidth then
        return text
    end
    while #text > 0 and measure(text .. "...", font) > maxWidth do
        text = dropLastChar(text)
    end
    return text .. "..."
end

--- Blocs (dans l'ordre, { kind = "head"|"lot"|"decoy", section, h }) rangés
--- en colonnes de hauteur limit au plus, premier remplissage : un titre
--- descend avec le bloc qui le suit, une colonne qui commence au milieu d'une
--- section reçoit d'abord son titre répété (head « continued »). Renvoie les
--- colonnes et la hauteur de la dernière.
local function fillColumns(blocks, limit, sectionH)
    local columns, current, height = {}, {}, 0
    local i = 1
    while i <= #blocks do
        local block = blocks[i]
        local items
        if block.kind == "head" then
            items = { block }
            local following = blocks[i + 1]
            if following and following.kind ~= "head" and following.section == block.section then
                items[2] = following
            end
        elseif #current == 0 then
            items = { { kind = "head", section = block.section, h = sectionH, continued = true }, block }
        else
            items = { block }
        end
        local need = 0
        for _, item in ipairs(items) do
            need = need + item.h
        end
        if #current > 0 and height + need > limit then
            columns[#columns + 1] = current
            current, height = {}, 0
        else
            for _, item in ipairs(items) do
                current[#current + 1] = item
                height = height + item.h
                if not item.continued then
                    i = i + 1
                end
            end
        end
    end
    columns[#columns + 1] = current
    return columns, height
end

--- Répartit les blocs en cols colonnes, pied (footerH) sous la dernière,
--- pour que la plus haute soit la plus basse possible (recherche
--- dichotomique de la hauteur limite). Renvoie { [1..cols] = { bloc, … } }.
function RW.distribute(blocks, cols, footerH, sectionH)
    local total = footerH
    for _, block in ipairs(blocks) do
        total = total + block.h
    end
    local function fits(limit)
        local columns, lastH = fillColumns(blocks, limit, sectionH)
        if #columns > cols then
            return nil
        end
        if #columns == cols and lastH + footerH > limit then
            return nil
        end
        return columns
    end
    local columns
    if cols <= 1 then
        columns = fillColumns(blocks, math.huge, sectionH)
    else
        local low, high = math.ceil(total / cols), total + sectionH * cols
        columns = fits(high) or fillColumns(blocks, math.huge, sectionH)
        while low <= high do
            local mid = math.floor((low + high) / 2)
            local found = fits(mid)
            if found then
                columns, high = found, mid - 1
            else
                low = mid + 1
            end
        end
    end
    for c = #columns + 1, math.max(1, cols) do
        columns[c] = {}
    end
    return columns
end

--- Disposition pour un mode (colonnes, serré) ; voir computeLayout. view
--- (facultatif) : une page de la feuille paginée, { ids, decoy, page, pages }.
local function place(form, mode, view)
    local font, title, hand = RW.typedFont(), RW.titleFont(), RW.handFont()
    local fh, ft = fontHeight(font), fontHeight(title)
    local u = math.max(4, math.floor(fh * 0.35))
    local compact = mode.compact
    local L = { mode = mode, cols = mode.cols, compact = compact, font = font, title = title, hand = hand,
        fh = fh, ft = ft, hh = fontHeight(hand), u = u }
    L.box = compact and (fh - 1) or (fh + 2)
    L.rowH = compact and (fh + 2) or (L.box + u)
    L.sectionH = compact and (fh + 2) or (fh + u)
    L.sectorBox = L.box - 2
    L.sectorsH = 3 * L.sectorBox + 4 + (compact and 2 or u)
    L.btnH = fh + (compact and 6 or 2 * u)
    L.gapS = math.max(2, math.floor(u / 2))
    L.colGap = 3 * u
    L.frame = 2 * u + 2
    L.closeSize = fh + 6
    L.pad = compact and 2 * u or 3 * u

    -- Largeurs mesurées : libellés, coûts, contrôles, raisons.
    local labelW = measure(getText("IGUI_MilitaryDrop_ReqColLot"), font)
    local costW = measure(getText("IGUI_MilitaryDrop_ReqColCost"), font)
    local reasonW = 0
    -- Largeurs gardées par texte et police dans le formulaire : la feuille
    -- paginée essaie de nombreuses dispositions des mêmes lots.
    local widths = form.widthCache or {}
    form.widthCache = widths
    local function measureOnce(text)
        local key = tostring(font) .. "|" .. text
        if not widths[key] then
            widths[key] = measure(text, font)
        end
        return widths[key]
    end
    for _, lot in ipairs(form.lots) do
        labelW = math.max(labelW, measureOnce(RW.lotLabel(lot)))
        costW = math.max(costW, measureOnce(RW.costText(lot.cost)))
        if not lot.allowed then
            reasonW = math.max(reasonW, measureOnce(RW.reasonText(lot)))
        end
    end
    if form.decoy then
        labelW = math.max(labelW, L.box + u + measure(getText("IGUI_MilitaryDrop_ReqDecoy"), font))
        costW = math.max(costW, measure(RW.costText(form.decoy.cost), font))
        if not form.decoy.allowed then
            reasonW = math.max(reasonW, measure(RW.reasonText(form.decoy), font))
        end
    end
    -- Libellé trop long (traduction) : raccourci, complet dans l'infobulle.
    L.labelW = math.min(labelW, fh * 15)
    L.costW = costW
    L.numW = math.max(L.box + 4, measure("88", hand) + 4, measure(getText("IGUI_MilitaryDrop_ReqColQty"), font))
    local ctrlW = 2 * L.box + 2 * L.gapS + L.numW
    ctrlW = math.max(ctrlW, 3 * L.sectorBox + 4)
    local spanW = costW + 2 * u + ctrlW
    if reasonW > spanW then
        ctrlW = ctrlW + reasonW - spanW
    end
    L.ctrlW = ctrlW
    local colW = L.labelW + 2 * u + costW + 2 * u + ctrlW
    if RW.namedSectors(form) then
        -- Secteurs nommés : libellé, sélecteur « < nom > » sur toute la
        -- largeur (retrait de la case du leurre), note. La colonne s'élargit
        -- pour le nom le plus long, au plus SECTOR_NAME_EM hauteurs de police
        -- (au-delà, le nom est raccourci).
        L.zones = true
        L.zoneH = (compact and 1 or math.floor(u / 2)) + fh + L.gapS + L.box + L.gapS + fh
            + (compact and 1 or math.ceil(u / 2))
        local nameW = 0
        for _, sector in ipairs(RW.sectorList(form)) do
            nameW = math.max(nameW, measureOnce(sector))
        end
        nameW = math.min(nameW, fh * RW.SECTOR_NAME_EM)
        colW = math.max(colW, L.box + u + 2 * (L.box + L.gapS) + 2 * u + nameW)
        if form.drop then
            -- Champ du largage (ZONE-09) : au pied, sans retrait, libellé
            -- entier si possible (raccourci au-delà de 15 hauteurs de police) ;
            -- le leurre n'a plus de bloc de secteurs sous sa case.
            L.dropField = true
            L.sectorsH = 0
            colW = math.max(colW, math.min(measure(getText("IGUI_MilitaryDrop_ReqSectorLabel"), font), fh * 15))
        else
            L.sectorsH = L.zoneH
        end
    end
    -- Pied : budget (libellé, points de suite, valeur), note, boutons.
    L.budgetLabelW = 0
    for _, key in ipairs(BUDGET_KEYS) do
        L.budgetLabelW = math.max(L.budgetLabelW, measure(getText(key), font))
    end
    L.budgetValueW = measure(RW.costText(888), font)
    colW = math.max(colW, L.budgetLabelW + 3 * u + L.budgetValueW, measure(getText("IGUI_MilitaryDrop_ReqLost"), font))
    local transmitW = measure(getText("IGUI_MilitaryDrop_ReqTransmit"), font) + 4 * u
    local cancelW = measure(getText("IGUI_MilitaryDrop_ReqCancel"), font) + 4 * u
    L.stacked = transmitW + cancelW + u > colW
    if L.stacked then
        colW = math.max(colW, transmitW, cancelW)
    end
    L.footerH = u + 3 * fh + fh + u + L.btnH + (L.stacked and (L.btnH + L.gapS) or 0)
    -- Champ du largage (ZONE-09) : en tête du pied, sur chaque page.
    if L.dropField then
        L.dropH = L.zoneH + u
        L.footerH = L.footerH + L.dropH
    end
    -- Feuille paginée : ligne « < Page 1/2 > » en tête du pied.
    if view then
        L.page, L.pages = view.page, view.pages
        L.pagerH = L.rowH + L.gapS
        L.footerH = L.footerH + L.pagerH
        colW = math.max(colW, 2 * L.box + 2 * u + measure(getText("IGUI_MilitaryDrop_ReqPage", 88, 88), font))
    end

    -- En-tête : titre, service, demandeur et référence ; tampon à droite.
    local stampTitleW = math.max(measure(getText(RW.stampKey(form)), title),
        measure(getText("IGUI_MilitaryDrop_ReqStampExpired"), title))
    L.stampW = math.max(stampTitleW, measure(getText("IGUI_MilitaryDrop_ReqValid", "88:88"), font)) + 3 * u
    L.stampH = ft + fh + u
    local infoW = math.max(measure(getText("IGUI_MilitaryDrop_ReqTitle"), title),
        measure(getText("IGUI_MilitaryDrop_ReqService"), font),
        measure(getText("IGUI_MilitaryDrop_ReqFrom", form.callsign), font) + 2 * u
        + measure(getText("IGUI_MilitaryDrop_ReqRef", "MD-8888"), font))
    local headerNeed = infoW + 3 * u + L.stampW

    -- Colonnes : blocs (titre de section, ligne de lot, leurre avec sa rose
    -- des vents) répartis pour la hauteur la plus faible, pied dans la
    -- dernière colonne. Une longue section continue dans la colonne suivante
    -- sous son titre répété ; un titre n'est jamais seul en bas de colonne.
    local sections = RW.sections(form, view)
    local blocks, lotBlocks = {}, 0
    for _, section in ipairs(sections) do
        blocks[#blocks + 1] = { kind = "head", section = section, h = L.sectionH }
        for _, lot in ipairs(section.lots) do
            blocks[#blocks + 1] = { kind = "lot", lot = lot, section = section, h = L.rowH }
            lotBlocks = lotBlocks + 1
        end
        if section.decoy then
            blocks[#blocks + 1] = { kind = "decoy", section = section, h = L.rowH + L.sectorsH }
            lotBlocks = lotBlocks + 1
        end
    end
    -- Page d'une feuille paginée : toujours le nombre de colonnes du mode
    -- (même largeur d'une page à l'autre).
    local cols = view and mode.cols or math.min(mode.cols, math.max(1, lotBlocks))
    local columnBlocks = RW.distribute(blocks, cols, L.footerH, L.sectionH)
    L.cols = cols
    local contentW = cols * colW + (cols - 1) * L.colGap
    if headerNeed > contentW then
        colW = colW + math.ceil((headerNeed - contentW) / cols)
        contentW = cols * colW + (cols - 1) * L.colGap
    end
    L.colW = colW
    L.contentW = contentW

    -- Planchette et pince.
    L.clipW = math.max(96, math.floor(fh * 5.5))
    L.clipH = math.floor(L.clipW / 2)
    local paperY = math.max(math.floor(L.clipH / 2) + 2, L.closeSize + 6)
    local W = 2 * L.frame + 2 * L.pad + contentW
    L.paper = rect(L.frame, paperY, W - 2 * L.frame, 0)
    L.clip = rect((W - L.clipW) / 2, paperY - math.floor(L.clipH / 2), L.clipW, L.clipH)
    L.close = rect(W - L.frame - L.closeSize, math.max(2, (paperY - L.closeSize) / 2), L.closeSize, L.closeSize)
    local x0 = L.paper.x + L.pad
    local y = paperY + math.max(L.pad, math.ceil(L.clipH / 2) + u)
    L.titleY = y
    L.serviceY = y + ft
    L.infoY = L.serviceY + fh
    L.textX = x0
    L.infoW = contentW - L.stampW - 3 * u
    L.stamp = rect(x0 + contentW - L.stampW, y + math.floor((ft + 2 * fh - L.stampH) / 2), L.stampW, L.stampH)
    y = L.infoY + fh + u
    L.ruleY = y
    y = y + 3 + u
    L.colHeadY = y
    y = y + fh
    L.colRuleY = y
    y = y + (compact and 2 or math.floor(u / 2) + 1)
    L.columnsY = y

    -- Lignes de chaque colonne.
    L.columns, L.sectionsAt, L.rows, L.sectorBoxes = {}, {}, {}, {}
    local bottom = y
    for c = 1, cols do
        local cx = x0 + (c - 1) * (colW + L.colGap)
        L.columns[c] = rect(cx, L.colHeadY, colW, 0)
        local cy = y
        for _, block in ipairs(columnBlocks[c] or {}) do
            local section = block.section
            if block.kind == "head" then
                L.sectionsAt[#L.sectionsAt + 1] = { label = RW.sectionLabel(section.group), x = cx, y = cy, w = colW }
                cy = cy + L.sectionH
            elseif block.kind == "lot" then
                L.rows[block.lot.id] = RW.rowRects(L, cx, cy, colW)
                cy = cy + L.rowH
            else
                local row = RW.rowRects(L, cx, cy, colW)
                row.check = rect(cx, cy + (L.rowH - L.box) / 2, L.box, L.box)
                L.decoyRow = row
                cy = cy + L.rowH
                if L.dropField then
                    -- Secteur du leurre : celui du champ du pied (ZONE-09).
                    cy = cy + L.sectorsH
                elseif L.zones then
                    RW.zoneSectorRects(L, form, cx, cy, colW, L.box + u)
                    cy = cy + L.sectorsH
                else
                    local sb = L.sectorBox
                    local mid = cx + colW - math.floor((3 * sb + 4) / 2)
                    local top = cy + (compact and 1 or math.floor(u / 2))
                    L.sectorsArea = rect(cx, cy, colW, L.sectorsH)
                    L.sectorLabelX = cx + L.box + u
                    L.sectorBoxes.N = rect(mid - sb / 2, top, sb, sb)
                    L.sectorBoxes.W = rect(mid - sb / 2 - sb - 2, top + sb + 2, sb, sb)
                    L.sectorBoxes.E = rect(mid + sb / 2 + 2, top + sb + 2, sb, sb)
                    L.sectorBoxes.S = rect(mid - sb / 2, top + 2 * (sb + 2), sb, sb)
                    L.compassCenter = { x = mid, y = top + sb + 2 + sb / 2 }
                    cy = cy + L.sectorsH
                end
            end
        end
        if c == cols then
            -- Pied : pages (feuille paginée), budget, note, boutons.
            cy = cy + u
            if L.pagerH then
                local by = cy + math.floor((L.rowH - L.box) / 2)
                L.pagePrev = rect(cx, by, L.box, L.box)
                L.pageNext = rect(cx + colW - L.box, by, L.box, L.box)
                L.pageTextX = cx + math.floor(colW / 2)
                L.pageTextY = cy + math.floor((L.rowH - fh) / 2)
                cy = cy + L.pagerH
            end
            if L.dropField then
                RW.zoneSectorRects(L, form, cx, cy, colW, 0)
                cy = cy + L.dropH
            end
            L.budgetY = cy
            L.budget = rect(cx, cy, colW, 3 * fh)
            cy = cy + 3 * fh
            L.lostY = cy
            cy = cy + fh + u
            if L.stacked then
                L.transmit = rect(cx, cy, colW, L.btnH)
                L.cancel = rect(cx, cy + L.btnH + L.gapS, colW, L.btnH)
                cy = cy + 2 * L.btnH + L.gapS
            else
                local cancelSize = cancelW
                L.cancel = rect(cx, cy, cancelSize, L.btnH)
                L.transmit = rect(cx + cancelSize + u, cy, colW - cancelSize - u, L.btnH)
                cy = cy + L.btnH
            end
        end
        bottom = math.max(bottom, cy)
    end
    for c = 1, cols do
        L.columns[c].h = bottom - L.colHeadY
    end
    L.paper.h = bottom + L.pad - paperY
    L.W = math.floor(W)
    L.H = math.floor(L.paper.y + L.paper.h + L.frame)
    return L
end

--- Rectangles d'une ligne de lot : ligne, libellé, coût (bord droit), zone des
--- contrôles (raison), boutons − et +, case de quantité.
function RW.rowRects(L, x, y, colW)
    local row = { row = rect(x, y, colW, L.rowH) }
    local midY = y + (L.rowH - L.box) / 2
    row.label = rect(x, y, L.labelW, L.rowH)
    row.costRight = x + L.labelW + 2 * L.u + L.costW
    row.span = rect(x + L.labelW + 2 * L.u, y, colW - L.labelW - 2 * L.u, L.rowH)
    row.plus = rect(x + colW - L.box, midY, L.box, L.box)
    row.qty = rect(row.plus.x - L.gapS - L.numW, midY, L.numW, L.box)
    row.minus = rect(row.qty.x - L.gapS - L.box, midY, L.box, L.box)
    return row
end

--- Bloc des secteurs nommés (mode zones) en (x, y), largeur colW, sous la
--- ligne du leurre (indent : retrait de sa case) ou au pied (champ du
--- largage, ZONE-09, sans retrait) : libellé, puis sélecteur (flèches < et >
--- aux bords, nom entre elles ; un seul secteur : le nom seul, sans flèche),
--- puis note.
function RW.zoneSectorRects(L, form, x, y, colW, indent)
    local top = y + (L.compact and 1 or math.floor(L.u / 2))
    L.sectorsArea = rect(x, y, colW, L.zoneH)
    L.sectorLabelX = x + (indent or 0)
    L.sectorLabelY = top
    local by = top + L.fh + L.gapS
    local right = x + colW
    if RW.fixedSector(form) then
        L.sectorPrev, L.sectorNext = nil, nil
        L.sectorName = rect(L.sectorLabelX, by, right - L.sectorLabelX, L.box)
    else
        L.sectorPrev = rect(L.sectorLabelX, by, L.box, L.box)
        L.sectorNext = rect(right - L.box, by, L.box, L.box)
        local nameX = L.sectorPrev.x + L.box + L.gapS
        L.sectorName = rect(nameX, by, L.sectorNext.x - L.gapS - nameX, L.box)
    end
    L.sectorNoteY = by + L.box + L.gapS
end

--- Disposition complète du formulaire dans un écran de maxWidth × maxHeight
--- (nil : sans limite) : le premier mode de RW.MODES qui tient, sinon le
--- moins débordant.
--- Si aucun ne tient : feuille paginée (RW.paginate), page page (1 par
--- défaut).
function RW.computeLayout(form, maxWidth, maxHeight, page)
    local best, bestOverflow
    for _, mode in ipairs(RW.MODES) do
        local L = place(form, mode)
        local overflow = math.max(0, L.W - (maxWidth or L.W)) + math.max(0, L.H - (maxHeight or L.H))
        if overflow == 0 then
            return L
        end
        if not best or overflow < bestOverflow then
            best, bestOverflow = L, overflow
        end
    end
    local paging = RW.paginate(form, maxWidth, maxHeight)
    if paging then
        return RW.pageLayout(form, paging, page or 1)
    end
    return best
end

--- Lots de la page p (sur pages), per lots par page, dans l'ordre affiché.
local function pageView(order, per, p, pages)
    local ids = {}
    for i = (p - 1) * per + 1, math.min(#order, p * per) do
        ids[order[i]] = true
    end
    return { ids = ids, decoy = p == pages, page = p, pages = pages }
end

--- Pagination de la feuille : le mode de RW.PAGED_MODES qui met le plus de
--- lots par page en tenant dans maxWidth × maxHeight, toutes pages
--- comprises (écran minuscule : le moins débordant). { mode, per, pages,
--- order, pageOf = { [id] = page }, W, H }, ou nil si elle est inutile.
function RW.paginate(form, maxWidth, maxHeight)
    local order = {}
    for _, section in ipairs(RW.sections(form)) do
        for _, lot in ipairs(section.lots) do
            order[#order + 1] = lot.id
        end
    end
    if #order < 2 or not maxHeight then
        return nil
    end
    -- Toutes les pages pour per lots par page : largeur et hauteur maximales.
    local function measurePages(mode, per)
        local pages = math.ceil(#order / per)
        local W, H = 0, 0
        for p = 1, pages do
            local L = place(form, mode, pageView(order, per, p, pages))
            W, H = math.max(W, L.W), math.max(H, L.H)
        end
        return W, H, pages
    end
    -- Le plus grand nombre de lots par page qui tient dans limitW × limitH
    -- (dichotomie), ou nil.
    local function search(mode, limitW, limitH)
        local found
        local low, high = 1, #order - 1
        while low <= high do
            local per = math.floor((low + high) / 2)
            local W, H, pages = measurePages(mode, per)
            if W <= (limitW or W) and H <= limitH then
                found = { mode = mode, per = per, pages = pages, W = W, H = H }
                low = per + 1
            else
                high = per - 1
            end
        end
        return found
    end
    local best
    for _, mode in ipairs(RW.PAGED_MODES) do
        local found = search(mode, maxWidth, maxHeight)
        if found and (not best or found.per > best.per) then
            best = found
        end
    end
    if not best then
        -- Écran minuscule : même un lot par page déborde. Le mode le moins
        -- débordant, avec le plus de lots par page à débordement égal.
        local chosen, chosenW, chosenH, overflow
        for _, mode in ipairs(RW.PAGED_MODES) do
            local W, H = measurePages(mode, 1)
            local over = math.max(0, W - (maxWidth or W)) + math.max(0, H - maxHeight)
            if not chosen or over < overflow then
                chosen, chosenW, chosenH, overflow = mode, W, H, over
            end
        end
        best = search(chosen, math.max(chosenW, maxWidth or chosenW), math.max(chosenH, maxHeight))
    end
    if not best then
        return nil
    end
    best.order = order
    best.pageOf = {}
    for i, id in ipairs(order) do
        best.pageOf[id] = math.floor((i - 1) / best.per) + 1
    end
    return best
end

--- Disposition d'une page de la feuille paginée : même taille pour toutes
--- les pages (la feuille ne bouge pas en changeant de page).
function RW.pageLayout(form, paging, page)
    page = math.max(1, math.min(paging.pages, page or 1))
    local L = place(form, paging.mode, pageView(paging.order, paging.per, page, paging.pages))
    L.paging = paging
    L.W = math.max(L.W, paging.W)
    L.H = math.max(L.H, paging.H)
    L.paper.h = L.H - L.frame - L.paper.y
    for _, column in ipairs(L.columns) do
        column.h = L.paper.y + L.paper.h - L.pad - L.colHeadY
    end
    return L
end

function RW.measureSize(form, maxWidth, maxHeight)
    local L = RW.computeLayout(form, maxWidth, maxHeight)
    return L.W, L.H
end

return RW
