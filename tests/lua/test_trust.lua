-- MilitaryDrop_Trust : note 0-100 par équipe, plafond quotidien hors largages,
-- bonus du poste, ligne coupée, paliers et facteur du délai, largages
-- récupérés / pris / perdus, codes faux répétés, érosion, solo.

local T = {}

local function arrayList(values)
    return {
        size = function() return #values end,
        get = function(_, i) return values[i + 1] end,
    }
end

local function makeFaction(name, owner, players)
    local faction = { name = name, owner = owner, players = players }
    function faction.getName(self) return self.name end
    function faction.getOwner(self) return self.owner end
    function faction.getPlayers(self) return arrayList(self.players) end
    FACTIONS[#FACTIONS + 1] = faction
    return faction
end

local function makePlayer(name)
    local data = { MilitaryDrop_characterId = "C:" .. name }
    return { getUsername = function() return name end,
        getModData = function() return data end, getDescriptor = function() return nil end }

end

--- Caisse de ravitaillement simulée (ModData d'objet).
local function makeCase(dropId)
    local item = { modData = {} }
    function item.getModData(self) return self.modData end
    MilitaryDrop.Trust.tagItem(item, dropId)
    return item
end

function T.announced_drops_keep_their_grid_until_opened_or_found()
    local real = Trust.registerDrop("C:alice", "alice", false)
    local decoy = Trust.registerDrop("C:alice", "alice", false, { untracked = true })
    Trust.onDropAnnounced(real, 10, 20)
    WORLD_HOURS = WORLD_HOURS + 1
    Trust.onDropAnnounced(decoy, 30, 40)
    Trust.onDropAnnounced("D999", 1, 2)
    local list = Trust.announcedDrops()
    assertEq(#list, 2, "deux largages annoncés")
    assertEq(list[1].id, real, "le plus ancien d'abord")
    assertEq(list[1].drop.x .. "," .. list[1].drop.y, "10,20", "grille gardée")
    assertTrue(not Trust.markFound(real), "un vrai largage ne se clôt qu'à l'ouverture d'une caisse")
    assertTrue(Trust.markFound(decoy), "leurre trouvé")
    assertEq(STATE.drops[decoy].outcome, "opened", "clos comme une caisse ouverte")
    assertEq(#Trust.announcedDrops(), 1, "plus de rappel pour le leurre")
    assertEq(Trust.get("C:alice"), Trust.START, "sans effet sur la confiance")
end

function T.setup()
    SandboxVars = { MilitaryDrop = {} }
    isClient = function() return false end
    isServer = function() return true end
    STATE = {}
    WORLD_HOURS = 1000
    -- Horloge du calendrier (heures) : jour = floor(CLOCK / 24).
    CLOCK = 24 * 100 + 12
    getGameTime = function() return { getWorldAgeHours = function() return WORLD_HOURS end } end
    NOW_MS = 0
    getTimestampMs = function() return NOW_MS end
    ZombRand = function() return 0 end
    FACTIONS = {}
    Faction = { getFactions = function() return arrayList(FACTIONS) end }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Core.lua")
    -- État privé (ModData au nom tiré de la graine, jamais transmise).
    PUBLIC = {}
    MilitaryDrop.Secrets = { privateState = function() return STATE end }
    MilitaryDrop.Server = {
        -- État public (lisible par les clients) : rien de la v1.3 n'y va.
        getState = function() return PUBLIC end,
        clock = function() return CLOCK end,
    }
    loadMod("server/MilitaryDrop/MilitaryDrop_Teams.lua")
    loadMod("server/MilitaryDrop/MilitaryDrop_Trust.lua")
    Trust = MilitaryDrop.Trust
    Teams = MilitaryDrop.Teams
end

--- Avance le temps de jeu (heures) et le calendrier d'autant.
local function wait(hours)
    WORLD_HOURS = WORLD_HOURS + hours
    CLOCK = CLOCK + hours
    NOW_MS = NOW_MS + 1000
end

local function setNote(teamId, value)
    Trust.add(teamId, value - Trust.get(teamId), "drop")
end

function T.new_team_starts_at_25()
    assertEq(Trust.get("C:alice"), 25, "départ à 25")
    assertEq(Trust.isLineCut("C:alice"), false, "ligne ouverte")
end

function T.new_team_delay_factor_is_1_25_and_1_at_50()
    assertEq(Trust.get("C:alice"), 25, "équipe neuve à 25")
    assertTrue(math.abs(Trust.factor("C:alice") - 1.25) < 1e-9, "délai ×1,25 au départ : " .. Trust.factor("C:alice"))
    setNote("C:alice", 50)
    assertTrue(math.abs(Trust.factor("C:alice") - 1) < 1e-9, "délai ×1 à 50 : " .. Trust.factor("C:alice"))
end

function T.tiers_follow_the_note()
    local cases = { { 0, 1 }, { 24, 1 }, { 25, 2 }, { 49, 2 }, { 50, 3 }, { 74, 3 }, { 75, 4 }, { 100, 4 } }
    for _, case in ipairs(cases) do
        setNote("C:alice", case[1])
        assertEq(Trust.tier("C:alice"), case[2], "palier à " .. case[1])
    end
end

function T.delay_factor_is_linear_from_1_5_to_0_6()
    local cases = { { 0, 1.5 }, { 25, 1.25 }, { 50, 1 }, { 75, 0.8 }, { 100, 0.6 } }
    for _, case in ipairs(cases) do
        STATE.characterTrust = STATE.characterTrust or {}
        STATE.characterTrust.T = { value = case[1] }
        assertTrue(math.abs(Trust.factor("T") - case[2]) < 1e-9, "facteur à " .. case[1] .. " : " .. Trust.factor("T"))
    end
end

function T.note_is_bounded_0_to_100()
    assertEq(Trust.add("C:alice", 80, "drop"), 75, "gain tronqué à 100")
    assertEq(Trust.get("C:alice"), 100, "maximum")
    assertEq(Trust.add("C:alice", -150, "drop"), -100, "perte tronquée à 0")
    assertEq(Trust.get("C:alice"), 0, "minimum")
end

function T.daily_cap_limits_other_sources_to_8()
    assertEq(Trust.add("C:alice", 5, "report"), 5, "premier gain")
    assertEq(Trust.add("C:alice", 5, "dogtag"), 3, "plafond commun : 8 par jour")
    assertEq(Trust.add("C:alice", 1, "control"), 0, "plafond atteint")
    assertEq(Trust.get("C:alice"), 33, "note")
    wait(24)
    assertEq(Trust.add("C:alice", 2, "report"), 2, "lendemain : plafond remis à zéro")
end

function T.drops_are_outside_the_cap()
    Trust.add("C:alice", 8, "report")
    assertEq(Trust.add("C:alice", 10, "drop"), 10, "largage : hors plafond")
    assertEq(Trust.get("C:alice"), 43, "note")
end

function T.cap_is_an_option()
    SandboxVars.MilitaryDrop.TrustDailyCap = 3
    assertEq(Trust.add("C:alice", 5, "report"), 3, "option TrustDailyCap")
end

function T.post_bonus_is_rounded_and_inside_the_cap()
    assertEq(Trust.add("C:alice", 2, "dogtag", { fromPost = true }), 3, "+50 % depuis le poste")
    assertEq(Trust.add("C:alice", 1, "report", { fromPost = true }), 2, "1,5 arrondi à 2")
    assertEq(Trust.add("C:alice", 2, "recon", { fromPost = true }), 3, "encore 3 sous le plafond")
    assertEq(Trust.add("C:alice", 2, "recon", { fromPost = true }), 0, "plafond de 8 atteint, bonus compris")
    SandboxVars.MilitaryDrop.TrustPostBonus = 0
    wait(24)
    assertEq(Trust.add("C:alice", 2, "recon", { fromPost = true }), 2, "bonus désactivé")
end

function T.falling_under_15_cuts_the_line_for_3_days()
    setNote("F1", 20)
    Trust.add("F1", -10, "drop")
    assertEq(Trust.get("F1"), 10, "sous 15")
    assertTrue(Trust.isLineCut("F1"), "ligne coupée")
    wait(71.9)
    assertTrue(Trust.isLineCut("F1"), "encore coupée avant 3 jours")
    wait(0.2)
    assertEq(Trust.isLineCut("F1"), false, "rétablie après 3 jours de jeu")
end

function T.gains_under_15_do_not_cut_the_line()
    STATE.characterTrust = { F1 = { value = 5 } }
    Trust.add("F1", 10, "drop")
    assertEq(Trust.isLineCut("F1"), false, "remontée : pas de coupure")
end

function T.line_cut_duration_is_an_option()
    SandboxVars.MilitaryDrop.TrustLineCutDays = 1
    setNote("F1", 16)
    Trust.add("F1", -2, "code")
    wait(24.1)
    assertEq(Trust.isLineCut("F1"), false, "option TrustLineCutDays")
end

--- Largage livré pour l'équipe team, demandé par requester.
local function deliveredDrop(team, requester)
    local dropId = Trust.registerDrop(team, requester, false,
        { recoveryFaction = Teams.factionIdFor(makePlayer(requester)) })
    Trust.onDropDelivered(dropId)
    return dropId
end

function T.recovered_drop_gives_10_once()
    makeFaction("Rangers", "alice", { "bob" })
    local team = Trust.idFor(makePlayer("alice"))
    local dropId = deliveredDrop(team, "alice")
    Trust.onCaseOpened(makeCase(dropId), makePlayer("alice"))
    assertEq(Trust.get(team), 35, "ouverte par un membre de l'équipe du demandeur : +10")
    assertEq(STATE.drops[dropId].outcome, "recovered", "largage clos")
    Trust.onCaseOpened(makeCase(dropId), makePlayer("alice"))
    assertEq(Trust.get(team), 35, "une seule fois par largage")
end

function T.drop_taken_by_another_team_costs_5()
    makeFaction("Rangers", "alice", {})
    local team = Trust.idFor(makePlayer("alice"))
    local dropId = deliveredDrop(team, "alice")
    Trust.onCaseOpened(makeCase(dropId), makePlayer("mallory"))
    assertEq(Trust.get(team), 20, "prise par une autre équipe : −5 au demandeur")
    assertEq(Trust.get(Trust.idFor(makePlayer("mallory"))), 25, "le preneur ne gagne rien")
    Trust.onCaseOpened(makeCase(dropId), makePlayer("alice"))
    assertEq(Trust.get(team), 20, "largage déjà clos")
end

function T.requester_who_left_still_recovers_for_the_calling_team()
    local faction = makeFaction("Rangers", "alice", { "bob" })
    local team = Trust.idFor(makePlayer("bob"))
    local dropId = deliveredDrop(team, "bob")
    faction.players = {}
    wait(1)
    Trust.onCaseOpened(makeCase(dropId), makePlayer("bob"))
    assertEq(Trust.get(team), 35, "le demandeur compte pour l'équipe de l'appel")
end

function T.unopened_drop_is_lost_after_48_hours()
    local dropId = deliveredDrop("C:alice", "alice")
    wait(47.9)
    triggerEvent("EveryHours")
    assertEq(Trust.get("C:alice"), 25, "avant l'échéance")
    wait(0.1)
    triggerEvent("EveryHours")
    assertEq(Trust.get("C:alice"), 15, "rien d'ouvert à l'échéance : −10")
    assertEq(STATE.drops[dropId].outcome, "lost", "largage perdu")
    triggerEvent("EveryHours")
    assertEq(Trust.get("C:alice"), 15, "compté une fois")
    Trust.onCaseOpened(makeCase(dropId), makePlayer("alice"))
    assertEq(Trust.get("C:alice"), 15, "ouverture tardive : rien")
end

function T.undelivered_drop_has_no_deadline()
    Trust.registerDrop("C:alice", "alice")
    wait(500)
    Trust.checkDrops()
    assertEq(Trust.get("C:alice"), 25, "échéance comptée depuis la pose")
end

function T.closed_drops_are_forgotten_after_a_week()
    local dropId = deliveredDrop("C:alice", "alice")
    Trust.onCaseOpened(makeCase(dropId), makePlayer("alice"))
    wait(Trust.CLOSED_DROP_KEEP_HOURS + 1)
    Trust.checkDrops()
    assertEq(STATE.drops[dropId], nil, "oublié")
end

function T.forced_drop_has_no_effect_on_trust()
    local dropId = Trust.registerDrop("C:alice", "alice", true)
    Trust.onDropDelivered(dropId)
    Trust.onCaseOpened(makeCase(dropId), makePlayer("mallory"))
    assertEq(Trust.get("C:alice"), 25, "largage admin ouvert par un autre : rien")
    local other = Trust.registerDrop("C:alice", "alice", true)
    Trust.onDropDelivered(other)
    wait(100)
    Trust.checkDrops()
    assertEq(Trust.get("C:alice"), 25, "largage admin perdu : rien")
end

function T.decoy_drop_is_untracked()
    -- Leurre (LEURRE-04) : ni +10, ni −5, ni −10.
    local dropId = Trust.registerDrop("C:alice", "alice", false, { untracked = true, decoy = { sector = "N" } })
    assertEq(STATE.drops[dropId].character, nil, "aucune équipe suivie")
    assertEq(STATE.drops[dropId].decoy.sector, "N", "type gardé dans l'état privé")
    Trust.onDropDelivered(dropId)
    Trust.onCaseOpened(makeCase(dropId), makePlayer("alice"))
    assertEq(Trust.get("C:alice"), 25, "ouvert par le demandeur : rien")
    local other = Trust.registerDrop("C:alice", "alice", false, { untracked = true })
    Trust.onDropDelivered(other)
    Trust.onCaseOpened(makeCase(other), makePlayer("mallory"))
    local lost = Trust.registerDrop("C:alice", "alice", false, { untracked = true })
    Trust.onDropDelivered(lost)
    wait(100)
    Trust.checkDrops()
    assertEq(Trust.get("C:alice"), 25, "pris par un autre ou perdu : rien")
end

function T.requisition_order_is_kept_with_the_drop()
    local dropId = Trust.registerDrop("C:alice", "alice", false, { order = { lots = { rations = 2 } } })
    assertEq(STATE.drops[dropId].character, "C:alice", "commande suivie normalement")
    assertEq(STATE.drops[dropId].order.lots.rations, 2, "commande dans l'état privé")
    assertEq(PUBLIC.drops, nil, "rien dans l'état public")
end

function T.case_without_drop_id_is_ignored()
    local item = { modData = {} }
    function item.getModData(self) return self.modData end
    Trust.onCaseOpened(item, makePlayer("alice"))
    item.modData[Trust.ITEM_KEY] = "D999"
    Trust.onCaseOpened(item, makePlayer("alice"))
    assertEq(Trust.get(Trust.idFor(makePlayer("alice"))), 25, "caisse hors largage ou inconnue")
end

function T.three_wrong_codes_in_an_hour_cost_2_at_the_next_hour()
    local team = Trust.idFor(makePlayer("alice"))
    Trust.onFailedCode(makePlayer("alice"))
    Trust.onFailedCode(makePlayer("alice"))
    triggerEvent("EveryHours")
    assertEq(Trust.get(team), 25, "deux codes faux : rien")
    Trust.onFailedCode(makePlayer("alice"))
    assertEq(Trust.get(team), 25, "pas sur-le-champ : la ModData trahirait le canal")
    triggerEvent("EveryHours")
    assertEq(Trust.get(team), 23, "−2 au changement d'heure")
    for _ = 1, 3 do
        Trust.onFailedCode(makePlayer("alice"))
    end
    triggerEvent("EveryHours")
    assertEq(Trust.get(team), 23, "une fois par heure")
    wait(1)
    for _ = 1, 3 do
        Trust.onFailedCode(makePlayer("alice"))
    end
    triggerEvent("EveryHours")
    assertEq(Trust.get(team), 21, "heure suivante : de nouveau")
end

function T.wrong_codes_spread_over_more_than_an_hour_are_not_penalized()
    local team = Trust.idFor(makePlayer("alice"))
    Trust.onFailedCode(makePlayer("alice"))
    wait(0.6)
    Trust.onFailedCode(makePlayer("alice"))
    wait(0.6)
    Trust.onFailedCode(makePlayer("alice"))
    triggerEvent("EveryHours")
    assertEq(Trust.get(team), 25, "trois codes faux sur 1 h 12")
end

function T.wrong_codes_are_separate_within_a_faction()
    makeFaction("Rangers", "alice", { "bob", "carol" })
    local team = Trust.idFor(makePlayer("alice"))
    Trust.onFailedCode(makePlayer("alice"))
    Trust.onFailedCode(makePlayer("bob"))
    Trust.onFailedCode(makePlayer("carol"))
    triggerEvent("EveryHours")
    assertEq(Trust.get(team), 25, "les codes faux de trois personnages ne se cumulent pas")
end

function T.erosion_is_off_by_default()
    setNote("C:alice", 70)
    wait(24 * 5)
    triggerEvent("EveryHours")
    assertEq(Trust.get("C:alice"), 70, "aucune érosion par défaut")
end

function T.erosion_moves_one_point_a_day_toward_25_without_exchange()
    SandboxVars.MilitaryDrop.TrustErosion = true
    setNote("C:alice", 70)
    setNote("C:bob", 20)
    Trust.touch("C:carol")
    setNote("C:carol", 70)
    wait(30)
    Trust.touch("C:carol")
    triggerEvent("EveryHours")
    assertEq(Trust.get("C:alice"), 69, "vers 25 par le haut")
    assertEq(Trust.get("C:bob"), 21, "vers 25 par le bas")
    assertEq(Trust.get("C:carol"), 70, "échange récent : pas d'érosion")
    wait(1)
    triggerEvent("EveryHours")
    assertEq(Trust.get("C:alice"), 69, "un point par jour")
    wait(24)
    triggerEvent("EveryHours")
    assertEq(Trust.get("C:alice"), 68, "jour suivant")
end

function T.solo_successor_does_not_inherit_the_old_drop()
    isServer = function() return false end
    local team = Trust.idFor(makePlayer("JohnDoe"))
    local dropId = deliveredDrop(team, "JohnDoe")
    Trust.onCaseOpened(makeCase(dropId), makePlayer("JaneRoe"))
    assertEq(Trust.get(team), 20, "le nouveau personnage ne récupère pas pour le précédent")
    assertEq(Trust.get(Trust.idFor(makePlayer("JaneRoe"))), 25, "nouveau personnage à 25")
end

function T.debug_print_lists_teams_and_open_drops()
    local lines = {}
    print = function(text) lines[#lines + 1] = text end
    makeFaction("Rangers", "alice", {})
    deliveredDrop(Trust.idFor(makePlayer("alice")), "alice")
    Trust.debugPrint()
    local text = table.concat(lines, "\n")
    assertTrue(text:find("alice", 1, true) ~= nil, "équipe listée : " .. text)
    assertTrue(text:find("drop D1", 1, true) ~= nil, "largage ouvert listé")
end

--- Ouverture par la recette (Recipe.openSupplyCase) : la confiance est prévenue.
function T.opening_recipe_notifies_trust()
    MilitaryDrop.Loot = {
        CASES = { ["MilitaryDrop.AmmoSupplyCase"] = true },
        roll = function() return {} end,
        weaponExtras = function() return {} end,
    }
    loadMod("shared/MilitaryDrop/MilitaryDrop_Recipe.lua")
    local dropId = deliveredDrop(Trust.idFor(makePlayer("alice")), "alice")
    local case = makeCase(dropId)
    case.getFullType = function() return "MilitaryDrop.AmmoSupplyCase" end
    local recipeData = { getAllConsumedItems = function() return arrayList({ case }) end }
    MilitaryDrop.Recipe.openSupplyCase(recipeData, makePlayer("alice"))
    assertEq(Trust.get(Trust.idFor(makePlayer("alice"))), 35, "caisse ouverte : largage récupéré")
end

function T.faction_changes_never_transfer_or_cap_personal_reputation()
    local alice, bob = makePlayer("alice"), makePlayer("bob")
    local a, b = Trust.idFor(alice), Trust.idFor(bob)
    Trust.add(a, 65, "drop")
    Trust.add(b, -20, "drop")
    local faction = makeFaction("Rangers", "alice", { "bob" })
    Teams.refresh()
    assertEq(Trust.get(a), 90, "founder retains own note")
    assertEq(Trust.get(b), 5, "joining member retains own note")
    assertTrue(Trust.isLineCut(b), "personal suspension retained")
    faction.players = {}
    wait(1)
    Teams.refresh()
    assertEq(Trust.get(a), 90, "owner unaffected by departure")
    assertEq(Trust.get(b), 5, "departing member unaffected")
    assertTrue(Trust.isLineCut(b), "suspension remains personal")
end

function T.fellow_faction_member_recovers_only_for_the_requesting_character()
    makeFaction("Rangers", "alice", { "bob" })
    local a, b = Trust.idFor(makePlayer("alice")), Trust.idFor(makePlayer("bob"))
    local drop = deliveredDrop(a, "alice")
    Trust.onCaseOpened(makeCase(drop), makePlayer("bob"))
    assertEq(Trust.get(a), 30, "same faction recovers for requester: +5")
    assertEq(Trust.get(b), 25, "opener earns nothing")
    assertEq(STATE.drops[drop].outcome, "recovered", "drop recovered")
    Trust.onCaseOpened(makeCase(drop), makePlayer("alice"))
    assertEq(Trust.get(a), 30, "only once per drop")
end

function T.faction_member_who_left_cannot_recover_for_the_requester()
    local faction = makeFaction("Rangers", "alice", { "bob" })
    local a, b = Trust.idFor(makePlayer("alice")), Trust.idFor(makePlayer("bob"))
    local drop = deliveredDrop(a, "alice")
    faction.players = {}
    wait(1)
    Trust.onCaseOpened(makeCase(drop), makePlayer("bob"))
    assertEq(Trust.get(a), 20, "former member is now outside the calling faction")
    assertEq(Trust.get(b), 25, "opener earns nothing")
end

return T
