require "MilitaryDrop/MilitaryDrop_PrintMedia"
local C = MilitaryDrop.Citation or {}
MilitaryDrop.Citation = C
function C.media(name, tier)
    local PM = MilitaryDrop.PrintMedia
    local text = getText("IGUI_MilitaryDrop_CitationText", tostring(name), tostring(tier))
    return PM.media("MilitaryDrop_Citation", getText("IGUI_MilitaryDrop_CitationTitle"),
        { PM.parent(620, 820), PM.texture("paper", { x = 0, y = 0, width = 620, height = 820 }),
          PM.text(text, { x = 50, y = 100, autoWidth = 510, font = "SdfOldRegular",
              scaleX = 0.6, scaleY = 0.6, r = 0.1, g = 0.1, b = 0.1 }) }, text)
end
return C
