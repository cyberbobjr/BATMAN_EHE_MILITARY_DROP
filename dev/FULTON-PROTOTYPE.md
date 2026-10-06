# Tester la montée Fulton

Branche `prototype/fulton-ascent`. Prototype visuel local uniquement, pour Build 42.21.
Le ballon et le sac sont des modèles Blender propres au mod. Aucun butin, recette,
objet persistant, extraction serveur ou gain de confiance n'est implémenté.

## Dans Project Zomboid

1. Redémarrer complètement le jeu pour charger les nouveaux scripts et modèles.
2. Activer la copie locale de Military Drop de ce projet. Le jeu peut charger
   directement `Workshop/MilitaryDrop/Contents/mods` ; aucune publication n'est nécessaire.
3. Ouvrir une partie de test, se placer dehors sur un terrain dégagé.
4. Clic droit dans le monde → **Fulton - prototype visuel** → **Lancer la montee du ballon**.

Le dispositif apparaît à environ deux cases devant le personnage dans la projection.
Le ballon monte pendant 10 secondes jusqu'à 2,5 niveaux (environ 6,12 m d'élévation),
reste en attente 20 secondes, puis sac et ballon partent ensemble pendant 4 secondes.
Le rendu est retiré automatiquement à la fin. Le câble est un tracé écran expérimental.

Le même menu permet de figer/reprendre l'animation, de masquer le câble et d'arrêter
immédiatement le test. Sans `-debug`, le menu reste disponible sur cette branche.

### Comparer les rendus

- **Automatique** : `RenderOpaqueObjectsInWorld`, avec secours dans `OnPostRender`
  si le premier événement manque. Un seul dessin par image du joueur concerné.
- **Monde uniquement** : reproduit le crochet du flotteur vanilla. Tester le curseur
  sur l'inventaire, sur le menu et hors du monde pour observer ses limites.
- **Après le monde uniquement** : même modèle et même mouvement, crochet différent.
  Comparer l'occultation près des arbres et des bâtiments.
- **Flotteur vanilla** : remplace le ballon par `Base.Bobber` agrandi pour séparer
  un problème de modèle du comportement du renderer. Le sac reste celui du prototype.

Observer aussi les transitions d'étage, le zoom, la nuit et l'option des objets 3D
au sol désactivée. Le repli texture de `Render3DItem` ne respecte pas le fondu du modèle.
Une case source déchargée ou un personnage mort arrête le prototype. Le visuel reste
sur le client qui l'a lancé ; la synchronisation multijoueur n'est pas testée ici.

### Console Lua debug (facultative)

```lua
MilitaryDrop.FultonPrototype.start(0)
MilitaryDrop.FultonPrototype.start(0, {height=4, duration=15, hold=60, mode="world"})
MilitaryDrop.FultonPrototype.togglePause()
MilitaryDrop.FultonPrototype.setMode("post")
local s = MilitaryDrop.FultonPrototype.status(); print(s.phase, s.height, s.lastRenderer, s.worldFrames, s.postFrames)
MilitaryDrop.FultonPrototype.stop()
```

`height` est en niveaux du monde, `duration` et `hold` en secondes réelles.
`status()` fournit les compteurs des deux crochets ; les changements de phase sont
journalisés avec le préfixe `[MilitaryDrop Fulton prototype]`.

## Dans Blender

La scène dédiée **MilitaryDrop - Fulton ascent preview** contient l'animation de
présentation : montée, attente, récupération du sac. Elle est visible dans l'instance
Blender ouverte, sans suppression des scènes précédentes. Espace pour lire/arrêter.

- `source/fulton_prototype/fulton_prototype.blend` : les modèles statiques exportés.
- `source/fulton_prototype/fulton_ascent_preview.blend` : scène animée indépendante.
- `source/fulton_prototype/build_fulton_prototype.py` : recette de génération/export.
- `source/fulton_prototype/preview_live.py` : ouverture dans une nouvelle scène et animation.

L'animation Blender illustre le déplacement ; elle ne prouve pas le rendu du moteur.
La recette demeure la source des modèles, textures et icônes du mod.

## Validation

Les tests Lua simulés vérifient la trajectoire, la pause, le secours sans double dessin,
le retrait des callbacks, les relancements et le rechargement Lua. Ils ne simulent pas
OpenGL ni les signatures Java réelles. La montée dans Project Zomboid reste à tester.

Vérifié le 2026-10-06 : `python tests/run_tests.py` passe (luacheck, Lua 5.1,
scripts, traductions et tests). Les deux FBX ont un seul canal UV et une échelle
de nœud 100, compensée par `scale = 0.01`. Les icônes et l'aperçu ont les mêmes
pixels après régénération sans interface. La scène animée a été observée dans
Blender 5.2.2 ; aucun lancement du prototype dans Project Zomboid n'est revendiqué.
