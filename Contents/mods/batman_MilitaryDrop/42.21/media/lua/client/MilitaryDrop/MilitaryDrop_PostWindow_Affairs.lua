-- Military Drop — console du poste de liaison (client) : affaires (liste de gauche)
-- Partie de MilitaryDrop_PostWindow.lua (voir son en-tête).

require "MilitaryDrop/MilitaryDrop_PostWindow"

local PostWindow = MilitaryDrop.PostWindow

-- ----------------------------------------------------------------------------
-- Affaires de la console (fonctions pures, testées hors jeu)
-- ----------------------------------------------------------------------------

local icons = {}

--- Icône d'un type d'objet du jeu, sans instance (Item.getNormalTexture), ou nil.
function PostWindow.itemIcon(fullType)
    local icon = icons[fullType]
    if icon == nil then
        local manager = getScriptManager and getScriptManager()
        local script = manager and manager:getItem(fullType)
        icon = script and script:getNormalTexture() or false
        icons[fullType] = icon
    end
    return icon or nil
end

--- Site d'épave d'un enregistreur de vol, ou nil pour un autre objet.
function PostWindow.recorderSite(item)
    return MilitaryDrop.Recorders.site(item)
end

--- Enregistreurs de vol de l'inventaire (sacs compris), ni en main ni
--- accrochés, un par site.
function PostWindow.recorders(player)
    local found, seen = {}, {}
    local items = player:getInventory():getAllEvalRecurse(function(item)
        return PostWindow.recorderSite(item) ~= nil and not MilitaryDrop.Recorders.isTransmitted(item)
    end, ArrayList.new())
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local site = PostWindow.recorderSite(item)
        if not seen[site] and not player:isEquipped(item) and not player:isAttachedItem(item) then
            seen[site] = true
            found[#found + 1] = item
        end
    end
    return found
end

--- État de la lecture en toutes lettres et couleur du voyant ; progress :
--- progression affichée (PostWindow:bayProgress), sinon celle du serveur.
function PostWindow.bayStatus(bay, progress)
    if bay.done then
        return getText("IGUI_MilitaryDrop_PostRecorderDone"), "green"
    elseif bay.paused then
        return getText("IGUI_MilitaryDrop_PostRecorderPaused"), "red"
    end
    local percent = math.floor(math.max(0, math.min(1, tonumber(progress or bay.progress) or 0)) * 100)
    return getText("IGUI_MilitaryDrop_PostRecorderReading", tostring(percent)), "amber"
end

--- Liste des affaires : en-têtes, puis lignes sélectionnables { kind, key,
--- title, sub, icon (type d'objet), lamp }. recorders : objets de
--- l'inventaire (PostWindow.recorders) ; tagCount : plaques sur soi.
function PostWindow.affairs(data, recorders, tagCount)
    local list = { { kind = "header", text = getText("IGUI_MilitaryDrop_PostTodo") } }
    local bay = data and data.bay
    if type(bay) == "table" and bay.site then
        local sub, lamp = PostWindow.bayStatus(bay)
        list[#list + 1] = { kind = "bay", key = "bay", site = tostring(bay.site), icon = PostWindow.RECORDER_TYPE,
            title = getText("IGUI_MilitaryDrop_PostRecorderName", tostring(bay.site)), sub = sub, lamp = lamp }
    end
    for _, item in ipairs(recorders or {}) do
        local site = PostWindow.recorderSite(item)
        if site and not MilitaryDrop.Recorders.isTransmitted(item) and not (bay and bay.site == site) then
            local modData = item:getModData()
            list[#list + 1] = { kind = "recorder", key = "rec:" .. site, site = site, itemId = item:getID(),
                icon = PostWindow.RECORDER_TYPE, title = getText("IGUI_MilitaryDrop_PostRecorderName", site),
                sub = getText("IGUI_MilitaryDrop_PostRecorderInInventory"),
                cx = tonumber(modData.MilitaryDrop_crashX), cy = tonumber(modData.MilitaryDrop_crashY),
                cc = tonumber(modData.MilitaryDrop_crashClock) }
        end
    end
    local mail = data and #(data.mail or {}) or 0
    list[#list + 1] = { kind = "tags", key = "tags", icon = PostWindow.DOG_TAG_TYPE,
        title = getText("IGUI_MilitaryDrop_PostTagsRow"),
        sub = getText("IGUI_MilitaryDrop_PostTagsCount", tostring(mail), tostring(tagCount or 0)),
        lamp = mail > 0 and "green" or nil }
    list[#list + 1] = { kind = "header", text = getText("IGUI_MilitaryDrop_PostOrders") }
    local missions = data and data.missions or {}
    if #missions == 0 then
        list[#list + 1] = { kind = "empty", text = getText("IGUI_MilitaryDrop_PostNoMission") }
    end
    for i, mission in ipairs(missions) do
        local view = PostWindow.missionView(mission)
        list[#list + 1] = { kind = "mission", key = "mission:" .. tostring(mission.kind or i), mission = mission,
            title = view.title, sub = view.sub ~= "" and view.sub or view.due, due = view.due,
            lamp = view.done and "green" or ((view.bar and view.bar.urgent) and "red" or nil) }
    end
    for _, source in ipairs({ "report", "fulton" }) do
        if MilitaryDrop.Exchange.isEnabled(source) then
            local option = MilitaryDrop.ExchangeMenu.optionFor(source)
            local states = data and data.exchanges or {}
            local done = source == "report" and states.reportDone or source == "fulton" and states.fultonOpen
            local doneKey = source == "report" and "IGUI_MilitaryDrop_PostReportDone" or "IGUI_MilitaryDrop_PostFultonOpen"
            list[#list + 1] = { kind = "exchange", key = "exchange:" .. source, source = source,
                title = getText(option.label), sub = getText(done and doneKey or option.tooltip),
                lamp = done and "green" or nil }
        end
    end
    local completed = data and data.completedMissions
    if type(completed) == "table" and #completed > 0 then
        list[#list + 1] = { kind = "header", text = getText("IGUI_MilitaryDrop_PostCompletedMissions") }
        for _, mission in ipairs(completed) do
            local view = PostWindow.missionView(mission)
            list[#list + 1] = { kind = "mission", key = "completed:" .. tostring(mission.id), mission = mission,
                title = view.title, sub = view.sub, due = view.due, lamp = view.success and "green" or "red" }
        end
    end
    return list
end

--- Ligne sélectionnable de clé key, sinon la première.
function PostWindow.pickAffair(list, key)
    local first
    for _, entry in ipairs(list) do
        if entry.key then
            if entry.key == key then
                return entry
            end
            first = first or entry
        end
    end
    return first
end

return PostWindow
