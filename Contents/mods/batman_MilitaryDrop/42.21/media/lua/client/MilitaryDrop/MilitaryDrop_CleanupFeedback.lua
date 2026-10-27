require "MilitaryDrop/MilitaryDrop_Core"
require "ISUI/ISPanel"
require "ISUI/ISRichTextPanel"

local Feedback = ISPanel:derive("MilitaryDropCleanupFeedback")
MilitaryDrop.CleanupFeedback = Feedback
Feedback.instances = {}

function Feedback:update()
    ISPanel.update(self)
    if getTimestampMs() >= self.untilMs then
        self:removeFromUIManager()
        if Feedback.instances[self.playerNum] == self then Feedback.instances[self.playerNum] = nil end
    end
end

-- A separate banner keeps success visible even while the radio is speaking.
function Feedback.show(player, text)
    local n = player:getPlayerNum()
    local previous = Feedback.instances[n]
    if previous then previous:removeFromUIManager() end
    local width = math.min(600, getPlayerScreenWidth(n) - 40)
    local x = getPlayerScreenLeft(n) + (getPlayerScreenWidth(n) - width) / 2
    local panel = Feedback:new(x, getPlayerScreenTop(n) + 80, width, 90)
    panel.playerNum, panel.untilMs = n, getTimestampMs() + 8000
    panel.backgroundColor = { r = 0.03, g = 0.12, b = 0.06, a = 0.96 }
    panel.borderColor = { r = 0.25, g = 0.8, b = 0.4, a = 1 }
    panel:initialise(); panel:instantiate()
    local body = ISRichTextPanel:new(12, 8, width - 24, 74)
    body:initialise(); body:instantiate()
    body.background = false
    body.autosetheight = true
    body.text = "<RGB:0.6,1,0.65> " .. text
    body:paginate()
    panel:addChild(body)
    panel:setHeight(body:getHeight() + 16)
    panel:addToUIManager()
    Feedback.instances[n] = panel
    return panel
end

return Feedback
