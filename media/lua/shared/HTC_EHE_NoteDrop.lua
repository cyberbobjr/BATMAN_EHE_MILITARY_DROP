function containsPoliceOrArmy(outfitName)
    -- Convertir la chaîne en minuscules pour une comparaison non sensible à la casse
    local lowerOutfitName = string.lower(outfitName)

    -- Vérifier si la chaîne contient "police" ou "army"
    if string.find(lowerOutfitName, "police") or string.find(lowerOutfitName, "army") then
        return true
    else
        return false
    end
end
function getNoteDropRate()
    -- 1/1000
    if SandboxVars.HTC_EHE_MilitaryDrop.noteDropRate == 1 then
        return 1000
        -- 1/500
    elseif SandboxVars.HTC_EHE_MilitaryDrop.noteDropRate == 2 then
        return 500
        -- 1/100
    elseif SandboxVars.HTC_EHE_MilitaryDrop.noteDropRate == 3 then
        return 100
        -- 1/50 (default)
    elseif SandboxVars.HTC_EHE_MilitaryDrop.noteDropRate == 4 then
        return 50
        -- 1/25
    elseif SandboxVars.HTC_EHE_MilitaryDrop.noteDropRate == 5 then
        return 25
        -- 1/50
    elseif SandboxVars.HTC_EHE_MilitaryDrop.noteDropRate == 6 then
        return 2
        -- 1/1 (debug)
    else
        return 50
    end

    if isServer() then
        print("HTC - EHE:  Set note drop rate 1/" .. SandboxVars.HTC_EHE_MilitaryDrop.noteDropRate)
    end

end

function HTC_OnZombieDead(zombie)
    local outfitName = zombie:getOutfitName()
    if outfitName then
        print("HTC - EHE: HTC_OnZombieDead " .. outfitName)
        if SandboxVars.HTC_EHE_MilitaryDrop.onlyArmyAndPoliceCorpse then
            if not containsPoliceOrArmy(outfitName) then
                return
            end
        end
    end

    local noteDropRate = getNoteDropRate()

    local myLot = ZombRand(1, noteDropRate + 1)

    if myLot == 1 then
        local inv = zombie:getInventory();
        local newJournal = inv:AddItem("Base.Notebook")
        local pageCount = 1

        local noteRandomIndex = ZombRand(8) + 1
        local selectedNoteRandomKey = "IGUI_HTC_EHE_note" .. noteRandomIndex
        local selectedNoteRandom = getText(selectedNoteRandomKey)

        newJournal:setName(getText("IGUI_HTC_EHE_note_title"))
        newJournal:addPage(pageCount, string.format(selectedNoteRandom, SandboxVars.HTC_EHE_MilitaryDrop.Frequency))
    end
end
Events.OnZombieDead.Add(HTC_OnZombieDead)