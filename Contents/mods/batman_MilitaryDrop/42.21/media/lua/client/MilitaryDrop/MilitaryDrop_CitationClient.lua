require "MilitaryDrop/MilitaryDrop_Citation"
require "TimedActions/ISReadABook"
local C = MilitaryDrop.Citation
if not C.readHook then
    C.readHook = true
    local previous = ISReadABook.displayPrintMedia
    function ISReadABook:displayPrintMedia(...)
        local data = self.item:getModData()
        local citation = data.MilitaryDropCitation
        if self.item:getFullType() == "MilitaryDrop.CommandCitation" and type(citation) == "table" then
            data.printMedia = C.media(citation.name, citation.tier)
        end
        return previous(self, ...)
    end
end
