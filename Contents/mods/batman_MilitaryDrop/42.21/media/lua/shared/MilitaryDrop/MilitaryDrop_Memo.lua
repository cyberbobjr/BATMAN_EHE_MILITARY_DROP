-- ============================================================================
-- Military Drop — remplissage d'une note militaire ou d'un carnet à sa création
--
-- OnCreate des objets MilitaryDrop.MilitaryMemo et MilitaryDrop.Codebook :
-- tout objet créé (cadavre, butin, liste d'objets du debug, AddItem en
-- console, butin d'un autre mod) reçoit son texte, sinon le jeu le tient pour
-- vide. Le document (modData.printMedia) s'ouvre par « Inspecter ».
--
-- Serveur ou solo seulement : codes et graine n'existent que là. Sur un
-- client MP, l'objet arrive déjà rempli par le serveur. OnCreate est aussi
-- appelé juste avant la relecture d'un objet sauvegardé : le document tiré ici
-- est alors remplacé par les ModData sauvegardées.
-- ============================================================================

require "MilitaryDrop/MilitaryDrop_Core"

local Memo = {}
MilitaryDrop.Memo = Memo

function Memo.onCreate(item)
    if isClient() or not MilitaryDrop.Notes or not item or item:getModData().printMedia then
        return
    end
    MilitaryDrop.Notes.fillMemo(item, ZombRand(MilitaryDrop.Notes.TEXT_COUNT) + 1)
end

function Memo.onCreateCodebook(item)
    if isClient() or not MilitaryDrop.Notes or not item or item:getModData().printMedia then
        return
    end
    MilitaryDrop.Notes.fillCodebook(item)
end

return Memo
