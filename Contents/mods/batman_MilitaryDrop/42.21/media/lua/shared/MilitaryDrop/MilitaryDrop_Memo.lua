-- ============================================================================
-- Military Drop — remplissage d'une note militaire à sa création
--
-- OnCreate de l'objet MilitaryDrop.MilitaryMemo : toute note créée (cadavre,
-- liste d'objets du debug, AddItem en console, butin d'un autre mod) reçoit un
-- texte avec la fréquence et le code, sinon le jeu la tient pour vide
-- (Literature.isEmptyPages → « Ne contient rien d'intéressant »).
--
-- Serveur ou solo seulement : le code n'existe que là. Sur un client MP, la
-- note arrive déjà remplie par le serveur. OnCreate est aussi appelé juste
-- avant la relecture d'une note sauvegardée : le texte tiré ici est alors
-- remplacé par les pages sauvegardées.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Memo = {}
MilitaryDrop.Memo = Memo

function Memo.onCreate(item)
    if isClient() or not MilitaryDrop.Notes or not item or not item:isEmptyPages() then
        return
    end
    MilitaryDrop.Notes.fillMemo(item, ZombRand(MilitaryDrop.Notes.TEXT_COUNT) + 1)
end

return Memo
