require "MilitaryDrop/MilitaryDrop_Client"
require "MilitaryDrop/MilitaryDrop_Admin"
require "MilitaryDrop/MilitaryDrop_AdminTools"
require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISRichTextPanel"
local C, A = { windows = {} }, MilitaryDrop.Admin
if MilitaryDrop.AdminDashboard then
    for _, window in pairs(MilitaryDrop.AdminDashboard.windows or {}) do window:request("exit") end
end
MilitaryDrop.AdminDashboard = C
C.allowed = A.allowed
local Panel = ISPanelJoypad:derive("MilitaryDropAdminDashboard")
local Confirm = ISPanelJoypad:derive("MilitaryDropAdminConfirmation")
local INK, MUTED, ACCENT = { 0.93, 0.95, 0.93 }, { 0.65, 0.73, 0.78 }, { 0.94, 0.71, 0.46 }
local function text(panel, value, x, y, color, font)
    panel:drawText(value, x, y, color[1], color[2], color[3], 1, font or UIFont.Small)
end
local function fit(value, width, font)
    font = font or UIFont.Small
    if getTextManager():MeasureStringX(font, value) <= width then return value end
    while #value > 0 do
        local start = #value
        while start > 1 and value:byte(start) >= 128 and value:byte(start) < 192 do start = start - 1 end
        value = value:sub(1, start - 1)
        if getTextManager():MeasureStringX(font, value .. "...") <= width then return value .. "..." end
    end
    return "..."
end
local function rich(parent, x, y, w, h)
    local r = ISRichTextPanel:new(x, y, w, h)
    r:initialise()
    r.autosetheight, r.clip, r.background = false, true, false
    r.marginLeft, r.marginRight, r.marginTop, r.marginBottom = 0, 14, 2, 2
    r.defaultFont = UIFont.Small
    r:addScrollBars()
    parent:addChild(r)
    return r
end
local function setRich(panel, value)
    panel:setText(value)
    panel:paginate()
end
local function button(parent, x, y, w, h, label, callback)
    local b = ISButton:new(x, y, w, h, label, parent, callback)
    b:initialise()
    parent:addChild(b)
    return b
end
local function location(row)
    if not row or not row.x then return A.text("noLocation") end
    return string.format("%d, %d, %d", row.x, row.y, row.z or 0)
end
local function phase(row) return A.text("Phase_" .. row.phase) end
local function opName(op) return A.text("Op_" .. op) end
local function description(op) return A.text("Desc_" .. op) end

function Panel:new(player)
    local w = math.min(1180, getCore():getScreenWidth() - 32)
    local h = math.min(740, getCore():getScreenHeight() - 32)
    local o = ISPanelJoypad.new(self, math.floor((getCore():getScreenWidth() - w) / 2),
        math.floor((getCore():getScreenHeight() - h) / 2), w, h)
    o.player, o.group, o.page, o.requestId = player, "mission", 1, 0
    o.moveWithMouse = true
    o.backgroundColor = { r = 0.06, g = 0.09, b = 0.12, a = 0.99 }
    o.listX, o.listW = 176, math.min(330, math.floor(w * 0.28))
    o.detailX = o.listX + o.listW + 20
    o.detailW = w - o.detailX - 20
    o.infoH = math.max(130, h - 500)
    return o
end
function Panel:createChildren()
    ISPanelJoypad.createChildren(self)
    self.nav, self.actionButtons, self.actionDescriptions = {}, {}, {}
    for i, kind in ipairs(A.GROUPS) do
        local b = button(self, 14, 86 + (i - 1) * 45, 146, 36, A.text("Group_" .. kind),
            function(panel, clicked) panel:selectGroup(clicked.kind) end)
        b.kind = kind
        self.nav[kind] = b
    end
    self.nav.tools = button(self, 14, 86 + #A.GROUPS * 45, 146, 36, A.text("Group_tools"),
        function(panel) panel:selectGroup("tools") end)
    self.search = ISTextEntryBox:new("", self.listX, 96, self.listW, 26)
    self.search:initialise()
    self.search:instantiate()
    self.search.tooltip = A.text("SearchTip")
    self:addChild(self.search)
    self.filter = ISComboBox:new(self.listX, 128, self.listW, 26, self, function(panel)
        panel.page = 1; panel:request("list")
    end)
    self.filter:initialise()
    for _, name in ipairs({ "All", "Active", "Closed" }) do self.filter:addOption(A.text(name)) end
    self:addChild(self.filter)
    self.list = ISScrollingListBox:new(self.listX, 164, self.listW, self.height - 250)
    self.list:initialise()
    self.list.itemheight, self.list.font = 76, UIFont.Small
    self.list.backgroundColor = { r = 0.09, g = 0.14, b = 0.18, a = 1 }
    self.list.doDrawItem = function(list, y, item)
        if list.selected == item.index then
            list:drawRect(0, y, list.width, 76, 1, 0.16, 0.23, 0.28)
            list:drawRect(0, y, 3, 76, 1, ACCENT[1], ACCENT[2], ACCENT[3])
        end
        text(list, fit(A.title(item.item), list.width - 28), 12, y + 9, INK)
        text(list, fit(phase(item.item), list.width - 28), 12, y + 30, ACCENT)
        text(list, fit(item.item.id .. " | " .. location(item.item), list.width - 28), 12, y + 51, MUTED)
        return y + 76
    end
    self.list:setOnMouseDownFunction(self, function(panel, row) panel:selectRow(row) end)
    self:addChild(self.list)
    self.info = rich(self, self.detailX, 104, self.detailW, self.infoH)
    self.beneficiary = ISComboBox:new(self.detailX, 114 + self.infoH, self.detailW, 26, self, function(panel)
        if panel.receiving then return end
        local selected = panel.beneficiary.selected
        panel.beneficiaryId = panel.recipients and panel.recipients[selected - 1] and panel.recipients[selected - 1].id
        panel:request("list")
    end)
    self.beneficiary:initialise()
    self:addChild(self.beneficiary)
    for i = 1, 3 do
        local y = 154 + self.infoH + (i - 1) * 68
        self.actionDescriptions[i] = rich(self, self.detailX, y, self.detailW - 206, 62)
        local b = button(self, self.detailX + self.detailW - 192, y + 6, 192, 38, "", function(panel, clicked)
            panel:preview(clicked.operation)
        end)
        self.actionButtons[i] = b
    end
    self.feedback = rich(self, self.detailX, self.height - 112, self.detailW, 62)
    self.prev = button(self, self.listX, self.height - 72, 36, 26, "<", function(panel)
        panel.page = math.max(1, panel.page - 1); panel:request("list")
    end)
    self.next = button(self, self.listX + 42, self.height - 72, 36, 26, ">", function(panel)
        panel.page = panel.page + 1; panel:request("list")
    end)
    button(self, self.width - 292, 18, 146, 30, A.text("Refresh"), function(panel) panel:request("list") end)
    button(self, self.width - 134, 18, 114, 30, A.text("Close"), function(panel) panel:request("exit") end)
    self.lastSearch = ""
    self:showRow()
end
function Panel:selectGroup(kind)
    setRich(self.feedback, "")
    self.group, self.page, self.selectedId, self.row, self.beneficiaryId = kind, 1, nil, nil, nil
    self.receiving = true; self.search:setText(""); self.receiving = false
    self.lastSearch = ""
    self.filter:setVisible(kind ~= "tools" and kind ~= "radio")
    self:request("list")
end
function Panel:selectRow(row)
    if row and row.id ~= self.selectedId then setRich(self.feedback, "") end
    self.row, self.selectedId = row, row and row.id
    self:showRow()
end
function Panel:showRow()
    if not self.info then return end
    local row = self.row
    self.beneficiary:setVisible(row ~= nil and row.kind == "mission" and row.missionKind ~= "cleanup" and row.phase == "active")
    if not row then
        setRich(self.info, A.text("Empty"))
    else
        local lines = { "<RGB:0.94,0.71,0.46> " .. A.clean(A.title(row)) .. " <LINE> <RGB:0.85,0.89,0.91> "
            .. phase(row) .. " | " .. row.id, A.text("Location") .. ": " .. location(row) }
        if row.phase == "waiting" then lines[#lines + 1] = A.text("WaitingExplanation") end
        if row.deadline and self.data then
            lines[#lines + 1] = A.text("HoursLeft", string.format("%.1f", math.max(0, row.deadline - self.data.hours)))
        end
        if row.kind == "mission" then
            if row.quota then lines[#lines + 1] = A.text("Progress", tostring(row.progress), tostring(row.quota)) end
            for _, contributor in ipairs(row.contributors or {}) do
                lines[#lines + 1] = A.clean(contributor.name ~= "" and contributor.name or contributor.id)
                    .. ": " .. tostring(contributor.count)
            end
            if row.beneficiary then
                lines[#lines + 1] = A.text("Reward", A.clean(row.beneficiaryName), tostring(row.reward), tostring(row.baseGain))
            elseif row.phase == "active" then lines[#lines + 1] = A.text("noBeneficiary") end
        elseif row.kind == "character" then
            lines[#lines + 1] = A.text("Standing", tostring(row.value))
        elseif row.kind == "relay" then lines[#lines + 1] = A.text("Repairs", tostring(row.repairs)) end
        if row.kind == "radio" then
            lines = { A.text("RadioPrivate"), A.text("CurrentCode") .. ": "
                .. (row.codeRequired and A.clean(row.code) or A.text("NoCode")) }
            for _, entry in ipairs({ { "MilitaryFrequency", row.militaryChannel },
                { "NumbersFrequency", row.numbersChannel } }) do
                lines[#lines + 1] = A.text(entry[1]) .. ": " .. (entry[2]
                    and MilitaryDrop.Config.formatChannel(entry[2]) .. " MHz" or A.text("RadioInactive"))
            end
        end
        setRich(self.info, table.concat(lines, " <LINE> "))
    end
    for i = 1, 3 do
        local action = row and row.actions and row.actions[i]
        local b, desc = self.actionButtons[i], self.actionDescriptions[i]
        b:setVisible(action ~= nil); desc:setVisible(action ~= nil)
        if action then
            local localTeleport = action.op == "teleport" and isClient() and self.player:getPlayerNum() ~= 0
            b.operation = action.op
            b:setTitle(fit(opName(action.op), 174))
            b.tooltip = opName(action.op) .. "\n" .. description(action.op)
            b:setEnable(action.enabled and not localTeleport and not self.pending)
            b.borderColor = action.op == "succeed" and { r = 0.94, g = 0.71, b = 0.46, a = 1 }
                or { r = 0.34, g = 0.43, b = 0.49, a = 1 }
            setRich(desc, "<RGB:0.93,0.95,0.93> " .. opName(action.op) .. " <LINE> <RGB:0.65,0.73,0.78> "
                .. (localTeleport and A.text("mainPlayerOnly")
                    or (action.enabled and description(action.op) or A.text(action.reason or "invalid"))))
        end
    end
end
function Panel:request(action, extra)
    if action == "exit" then
        if self.confirmation then self.confirmation:close() end
        self:setVisible(false); self:removeFromUIManager()
        C.windows[self.player:getPlayerNum()] = nil
        return
    end
    if not A.allowed(self.player) then self:request("exit"); return end
    if self.group == "tools" and action == "list" then
        local rows = {}
        local query = self.search:getText():lower()
        for _, row in ipairs(MilitaryDrop.AdminTools.rows(self.player)) do
            if query == "" or A.title(row):lower():find(query, 1, true) then rows[#rows + 1] = row end
        end
        self.lastRequest = getTimestampMs()
        self:receive({ rows = rows, page = 1, total = #rows, recipients = {}, group = "tools",
            counts = self.data and self.data.counts or {},
            stamp = self.lastRequest, hours = getGameTime():getWorldAgeHours() })
        return
    end
    self.requestId = self.requestId + 1
    local args = { action = action, group = self.group, page = self.page, beneficiary = self.beneficiaryId,
        query = self.search:getText(),
        filter = self.group == "radio" and "all" or ({ "all", "active", "closed" })[self.filter.selected],
        requestId = self.requestId }
    for key, value in pairs(extra or {}) do args[key] = value end
    self.lastRequest = getTimestampMs()
    MilitaryDrop.Net.toServer(self.player, "AdminDashboard", args)
end
function Panel:preview(op)
    if not self.row then return end
    if self.row.kind == "tool" then
        if op == "forceDrop" or op == "crashNext" then
            self.confirmation = Confirm:new(self, { row = self.row, operation = op, localTool = true })
            self.confirmation:initialise(); self.confirmation:addToUIManager()
        else self:executeTool(self.row, op) end
        return
    end
    self.pending = true; self:showRow()
    self:request("preview", { kind = self.row.kind, id = self.row.id, operation = op })
end
function Panel:executeTool(row, op)
    local ok = MilitaryDrop.AdminTools.execute(self.player, row.id, op)
    self:request("list")
    setRich(self.feedback, A.text(ok and "toolSent" or "toolUnavailable"))
end
function Panel:receive(args)
    if self.group == "tools" and args.requestId then return end
    if args.requestId and args.requestId ~= self.requestId then return end
    if args.busy then
        self.pending = false
        setRich(self.feedback, A.text("busy"))
        self:showRow()
        return
    end
    self.pending, self.receiving = false, true
    local oldId = self.selectedId
    self.data, self.page, self.total, self.recipients = args, args.page, args.total, args.recipients
    self.beneficiary:clear(); self.beneficiary:addOption(A.text("ChooseBeneficiary"))
    for i, recipient in ipairs(args.recipients or {}) do
        self.beneficiary:addOption(recipient.name)
        if recipient.id == self.beneficiaryId then self.beneficiary.selected = i + 1 end
    end
    self.list:clear()
    local selected = 1
    for i, row in ipairs(args.rows or {}) do
        self.list:addItem(A.title(row), row, A.title(row))
        if row.id == oldId then selected = i end
    end
    self.list.selected = selected
    self.row = self.list.items[selected] and self.list.items[selected].item
    self.selectedId = self.row and self.row.id
    self.receiving = false
    if args.status then
        local context = args.target and (opName(args.operation) .. " | " .. A.title(args.target)
            .. " (" .. args.target.id .. ") <LINE> ") or ""
        setRich(self.feedback, context .. A.text(args.status))
    elseif oldId and oldId ~= self.selectedId then setRich(self.feedback, A.text("SelectionChanged")) end
    if args.preview then
        if self.confirmation then self.confirmation:close() end
        self.confirmation = Confirm:new(self, args.preview)
        self.confirmation:initialise(); self.confirmation:addToUIManager()
    end
    self.prev:setEnable(self.page > 1)
    self.next:setEnable(self.page < math.ceil(self.total / A.PAGE_SIZE))
    for kind, b in pairs(self.nav) do
        b:setTitle(A.text("Group_" .. kind) .. (kind == "tools" and "" or " (" .. tostring(args.counts[kind] or 0) .. ")"))
    end
    self:showRow()
end
function Panel:prerender()
    ISPanelJoypad.prerender(self)
    if not A.allowed(self.player) then self:request("exit"); return end
    text(self, A.text("Title"), 18, 15, INK, UIFont.Medium)
    text(self, A.text(isClient() and "MPMode" or "SPMode"), 18, 43, MUTED)
    self:drawRect(self.detailX - 12, 74, 1, self.height - 94, 1, 0.22, 0.28, 0.32)
    text(self, A.text("Search"), self.listX, 76, MUTED)
    text(self, A.text("Details"), self.detailX, 76, ACCENT)
    if self.data then
        text(self, A.text("Page", tostring(self.page), tostring(math.max(1, math.ceil(self.total / A.PAGE_SIZE))),
            tostring(self.total)), self.listX, self.height - 38, MUTED)
        text(self, A.text("Freshness", tostring(math.max(0, math.floor((getTimestampMs() - self.data.stamp) / 1000)))),
            18, self.height - 38, MUTED)
    end
    for kind, b in pairs(self.nav) do
        b.backgroundColor = kind == self.group and { r = 0.19, g = 0.27, b = 0.33, a = 1 }
            or { r = 0.09, g = 0.14, b = 0.18, a = 1 }
    end
    local query = self.search:getText()
    if query ~= self.lastSearch then self.lastSearch, self.searchAt = query, getTimestampMs() end
    if self.searchAt and getTimestampMs() - self.searchAt > 400 and not self.pending and not self.confirmation then
        self.searchAt, self.page = nil, 1; self:request("list")
    elseif not self.pending and not self.confirmation and getTimestampMs() - (self.lastRequest or 0) > 5000 then
        self:request("list")
    end
    if self.pending and getTimestampMs() - self.lastRequest > 7000 then
        self.pending = false; setRich(self.feedback, A.text("timeout")); self:showRow()
    end
end
function Confirm:new(owner, preview)
    local h = math.min(480, getCore():getScreenHeight() - 40)
    local o = ISPanelJoypad.new(self, math.floor((getCore():getScreenWidth() - 620) / 2),
        math.floor((getCore():getScreenHeight() - h) / 2), 620, h)
    o.owner, o.preview, o.moveWithMouse = owner, preview, true
    o.backgroundColor = { r = 0.09, g = 0.14, b = 0.18, a = 1 }
    return o
end
function Confirm:createChildren()
    ISPanelJoypad.createChildren(self)
    local row, op = self.preview.row, self.preview.operation
    local content = { A.clean(A.title(row)) .. " | " .. row.id, description(op),
        A.text("Location") .. ": " .. location(row) }
    if op == "succeed" then
        content[#content + 1] = A.text("Reward", A.clean(row.beneficiaryName), tostring(row.reward), tostring(row.baseGain))
        content[#content + 1] = A.text("NoPostBonus")
    end
    self.info = rich(self, 20, 64, 580, self.height - 232)
    setRich(self.info, table.concat(content, " <LINE> <LINE> "))
    self.reason = ISTextEntryBox:new("", 20, self.height - 116, 580, 28)
    self.reason:initialise(); self.reason:instantiate(); self:addChild(self.reason)
    self.reason:setVisible(not self.preview.localTool)
    button(self, 20, self.height - 52, 160, 32, A.text("Back"), function(panel) panel:close() end)
    self.confirm = button(self, 326, self.height - 52, 274, 32, A.text("ConfirmAction"), function(panel)
        local owner, ticket, reason = panel.owner, panel.preview.token, panel.reason:getText()
        local preview = panel.preview
        panel:close()
        if preview.localTool then owner:executeTool(preview.row, preview.operation); return end
        owner.pending = true; owner:showRow()
        owner:request("commit", { ticket = ticket, reason = reason })
    end)
end
function Confirm:close()
    self.owner.confirmation = nil
    self:setVisible(false); self:removeFromUIManager()
end
function Confirm:prerender()
    ISPanelJoypad.prerender(self)
    if not A.allowed(self.owner.player) then self:close(); return end
    text(self, opName(self.preview.operation), 20, 18, ACCENT, UIFont.Medium)
    if not self.preview.localTool then text(self, A.text("Reason"), 20, self.height - 143, MUTED) end
    self.confirm:setEnable(self.preview.localTool or self.preview.operation == "teleport"
        or self.reason:getText():find("%S") ~= nil)
end
function C.open(player)
    if not A.allowed(player) then return end
    local old = C.windows[player:getPlayerNum()]
    if old then old:request("exit") end
    local panel = Panel:new(player)
    panel:initialise(); panel:addToUIManager()
    C.windows[player:getPlayerNum()] = panel
    panel:request("list")
    return panel
end
MilitaryDrop.Client.HANDLERS.AdminDashboard = function(args)
    for _, panel in pairs(C.windows) do
        if panel.player:getUsername() == args.username then
            if args.denied then panel:request("exit") else panel:receive(args) end
            return
        end
    end
end
MilitaryDrop.Client.HANDLERS.AdminTeleport = function(args)
    for _, panel in pairs(C.windows) do
        local player = panel.player
        if player:getUsername() == args.username and A.canTeleport(player) then
            if isClient() then
                if player:getPlayerNum() == 0 then
                    SendCommandToServer(string.format("/teleportto %d,%d,%d", args.x, args.y, args.z))
                end
            else player:teleportTo(args.x, args.y, args.z) end
            return
        end
    end
end
return C
