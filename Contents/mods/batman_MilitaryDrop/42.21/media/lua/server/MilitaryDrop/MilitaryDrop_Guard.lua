-- ============================================================================
-- Military Drop — cadence des commandes (serveur MP ou solo)
--
-- Une commande par joueur et par clé (nom de commande ou famille) toutes les
-- N ms réelles au plus (anti-rafale). Chaque commande a sa propre clé : le
-- rafraîchissement automatique de la console du poste ne consomme pas la
-- cadence d'un dépôt ou d'une transmission. Une commande refusée reçoit une
-- réponse « busy » de son module, avant toute vérification de la radio : elle
-- ne dit rien du canal. Mémoire du serveur seulement.
-- ============================================================================

if isClient() then
    return
end

require "MilitaryDrop/MilitaryDrop_Core"

local Guard = {}
MilitaryDrop.Guard = Guard

-- Cadence des échanges radio avec la base (appel, missions, transmission du poste).
Guard.RADIO_INTERVAL_MS = 3000

-- clé .. "|" .. nom du joueur → dernière commande acceptée (ms réelles).
local lastMs = {}

--- Vrai si la commande key du joueur arrive moins de intervalMs après la
--- précédente acceptée (elle est alors refusée) ; sinon la note et renvoie false.
function Guard.throttled(player, key, intervalMs)
    local id = tostring(key) .. "|" .. tostring(player:getUsername())
    local now = getTimestampMs()
    local last = lastMs[id]
    if last and now >= last and now - last < intervalMs then
        return true
    end
    lastMs[id] = now
    return false
end

return Guard
