require "MilitaryDrop/MilitaryDrop_Core"
local R = { TYPE = "MilitaryDrop.FlightRecorder", SITE_KEY = "MilitaryDrop_crashSite",
    SENT_KEY = "MilitaryDrop_recorderTransmitted" }
MilitaryDrop.Recorders = R
function R.site(item)
    if not item or item:getFullType() ~= R.TYPE then return nil end
    local data = item:getModData()
    local site = type(data) == "table" and data[R.SITE_KEY] or nil
    return type(site) == "string" and site ~= "" and site or nil
end
function R.isTransmitted(item)
    if not item or item:getFullType() ~= R.TYPE then return false end
    local data = item:getModData()
    -- Legacy saves have no SENT_KEY. Only an explicit boolean true marks a sent recorder.
    return type(data) == "table" and data[R.SENT_KEY] == true
end
return R
