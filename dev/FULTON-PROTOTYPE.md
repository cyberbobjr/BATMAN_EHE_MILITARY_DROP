# Tester la montée Fulton

Branche `prototype/fulton-ascent`. Prototype visuel solo et synchronisé en MP, pour Build 42.21.
Le ballon et le sac sont des modèles Blender propres au mod. Aucun butin, recette,
objet persistant, extraction serveur ou gain de confiance n'est implémenté.

## Dans Project Zomboid

1. Redémarrer complètement le jeu pour charger les nouveaux scripts et modèles.
2. Activer la copie locale de Military Drop de ce projet. Le jeu peut charger
   directement `Workshop/MilitaryDrop/Contents/mods` ; aucune publication n'est nécessaire.
3. Ouvrir une partie de test, se placer dehors sur un terrain dégagé.
4. Clic droit dans le monde → **Fulton - prototype visuel** → **Lancer la montee du ballon**.

Le dispositif apparaît à environ deux cases devant le personnage dans la projection.
Le ballon monte dès le lâcher, à vitesse constante pendant **3 secondes** jusqu'à
2,5 niveaux (environ 6,12 m d'élévation), puis sac et ballon partent ensemble
**immédiatement**, pendant **1,5 seconde**. Aucune attente au sommet : cycle complet
de **4,5 secondes**. L'attente précédente de 20 secondes est supprimée.
L'ancienne montée durait 10 secondes
avec une accélération progressive ; l'ancien départ final durait 4 secondes.
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
En solo, une case source déchargée ou un personnage mort arrête le prototype.
En MP, une case déchargée masque seulement le rendu local : le vol continue sur le serveur.

### Multijoueur : serveur et observateurs

Le client demande le lancement ; **le serveur fixe la position depuis le personnage
réel et décide du temps de vol**. Les clients reçoivent des états complets à chaque
commande et toutes les 0,5 seconde pendant un vol. L'horloge moteur synchronisée
`GameTime.getServerTimeMills()` compense le temps de transit. Aucun modèle ne doit
être dessiné sur le serveur dédié. Chaque observateur dessine les mêmes modèles
Blender à partir du même état, sans créer d'objet persistant ni d'inventaire.

- Les clients reçoivent tous les vols actifs ; le rendu exige une case source
  chargée et un observateur vivant à moins de 120 cases de cette source.
- Une demande d'état à l'entrée en partie permet de rejoindre un vol déjà commencé.
- Un numéro de révision empêche un ancien état reçu après un arrêt de rétablir le vol.
- Chaque joueur peut lancer un vol à la fois (8 vols simultanés au maximum), et
  arrêter ou figer seulement le sien. La pause est alors visible par tous.
- Mort ou déconnexion du lanceur : retrait du vol sur le serveur et chez les clients.
- Rechargement Lua client : aucun arrêt envoyé au serveur, état récupéré à la prochaine
  diffusion. Redémarrage serveur : aucun vol restauré, ce prototype reste temporaire.

Test réel à réaliser avec deux clients, sans publier la branche :

1. Installer **la même version de cette branche** sur le serveur et les deux clients,
   activer `batman_MilitaryDrop`, puis redémarrer complètement serveur et clients.
2. A et B se placent côte à côte dehors. A lance le ballon ; B vérifie une montée
   continue en 3 secondes, la même hauteur et le départ immédiat du sac au sommet.
3. A fige/reprend/arrête le vol ; B doit voir les mêmes transitions. B lance aussi
   son ballon : chacun doit voir les deux, et arrêter seulement le sien.
4. Relancer avec une attente longue (`hold=60`). B se reconnecte pendant le vol et
   doit retrouver la hauteur courante. B s'éloigne pour décharger la zone, revient
   avant la fin et retrouve le vol s'il est encore actif.
5. Déconnecter A pendant son vol : disparition chez B. Relever les premières erreurs
   de chargement et toute erreur `Fulton` dans les journaux serveur et clients.

Ce protocole vérifie aussi le transport réseau et le rendu Java/OpenGL réels, que
les tests automatisés hors jeu ne peuvent pas confirmer.

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
`hold` vaut **0 par défaut** ; une attente explicite reste disponible en console
uniquement pour faciliter l'inspection et les tests de reconnexion.
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

L'utilisateur a confirmé le bon fonctionnement du premier prototype solo dans le jeu.
La nouvelle vitesse et la synchronisation MP n'ont pas encore été reproduites en jeu.

Les tests Lua vérifient la trajectoire, la pause, le secours sans double dessin,
le retrait des callbacks, les relancements et le rechargement Lua.
`tests/check_fulton_multiplayer.py` exécute les vrais scripts dans trois VM Lua 5.1
isolées (serveur et deux clients) avec un transport simulé : observateur distant,
retard de paquets, entrée en cours de vol, case déchargée, rechargement client,
commandes/états reçus dans le désordre, deux vols, propriété de la pause, arrêt,
déconnexion/mort et fin de vol après une longue frame serveur. Les charges réseau
contiennent uniquement des tables et valeurs primitives sérialisables.
Ces tests ne simulent pas OpenGL, RakNet ni les signatures Java réelles.

Vérifié le 2026-10-06 : `python tests/run_tests.py` passe (luacheck, Lua 5.1,
scripts, traductions et tests). Les deux FBX ont un seul canal UV et une échelle
de nœud 100, compensée par `scale = 0.01`. Les icônes et l'aperçu ont les mêmes
pixels après régénération sans interface. La scène animée a été observée dans
Blender 5.2.2, puis accélérée en direct (109 images à 24 fps, soit 4,5 secondes).
Sources Java 42.21.0 et journal du jeu 42.21.0 contrôlés ; aucun test MP réel
à deux clients n'est revendiqué.
