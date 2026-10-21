# Fulton — faisabilité du ballon qui s'élève

Recherche du 2026-10-06, complément à [l'idée 12](idee-12-fulton.md). **Aucune mécanique ni ressource ajoutée au mod ; aucun test en jeu effectué.**

## Conclusion

**Oui : le code 42.21 permet de dessiner une représentation locale à une hauteur flottante qui évolue.** L'hypothèse de la note initiale (« modèle fixe puis disparition ») ne constitue pas une limite du moteur. Il n'est pas nécessaire de déplacer un véritable objet sauvegardé entre les étages pour montrer une ascension.

La première piste à essayer est un **modèle Blender rendu par `Render3DItem`**, comme le flotteur de pêche vanilla. Une tuile Blender reste possible pour l'installation au sol ; son sprite peut aussi servir à un effet 2D. Le choix final entre ces rendus dépend du test d'occultation et de lisibilité, encore à effectuer.

## Version et provenance

- Journal `C:/Users/cyber/Zomboid/console.txt:59` : `version=42.21.0 4a0e9546ec`.
- Sources décompilées : `E:/pz-decompiled/42.21.0/java/`.
- SHA-256 du JAR installé `D:/SteamLibrary/steamapps/common/ProjectZomboid/projectzomboid.jar`, comparé au fichier `E:/pz-decompiled/42.21.0/projectzomboid.jar.sha256` : `e1a69eb743ede60b213a0fe7f8b83d4fcab773036d256cc4543a336f3b058a33`, identique.
- Références Java ci-dessous relatives à ce dossier de sources ; références Lua/scripts relatives au `media/` de l'installation. Confirmation **statique**, pas validation visuelle.

## 1. Piste prioritaire : modèle 3D mobile dessiné depuis Lua

### Exemple vanilla

`lua/shared/Fishing/Bobber.lua:31-38` crée un objet de rendu avec `instanceItem(ItemKey.Normal.BOBBER)`, puis inscrit une fermeture dans `Events.RenderOpaqueObjectsInWorld`. Cette fermeture appelle :

```lua
Render3DItem(bobberItem, o.sq, o:getX(), o:getY(), 0, 0)
```

Le flotteur se déplace par mise à jour de ses coordonnées Lua (`Bobber.lua:217-219`) ; la fermeture est retirée lors de sa destruction (`:248-256`). Cet objet n'est pas ajouté à l'inventaire ni posé dans une case pour obtenir ce rendu.

Le script d'objet fournit `StaticModel` et `WorldStaticModel` (`scripts/generated/items/normal.txt:5688-5697`), avec son modèle dans `scripts/generated/models_items.txt:8810-8820`.

### Hauteur réellement utilisée

`Lua/LuaManager.java:9377-9385` expose la globale :

```text
Render3DItem(InventoryItem item, IsoGridSquare sq,
             float xoffset, float yoffset, float zoffset, float rotation)
```

Les noms `*offset` sont trompeurs : ce sont ici des **coordonnées du monde**, comme le confirment les appels vanilla et le passage à `WorldItemModelDrawer.renderMain`.

- `core/skinnedmodel/model/WorldItemModelDrawer.java:48-79` transmet `z` au renderer avec un minuscule décalage anti-intersection. Aucun rabattement sur l'étage de `sq` dans ce passage.
- `ItemModelRenderer.java:376-439` conserve `worldX/worldY/worldZ`, utilise la case pour l'éclairage et calcule la profondeur à la position du modèle.
- `ItemModelRenderer.java:790-797` transmet les coordonnées à `Core.DoPushIsoStuff` ; `core/Core.java:2777` utilise la hauteur avec un facteur `2.44949`.
- `ItemModelRenderer.java:508-519` active le test de profondeur `GL_LEQUAL`. Ce chemin est donc mieux fondé pour un rendu intégré au décor qu'une simple image d'interface ; la justesse visuelle reste à tester.

Principe du prototype, **pas code prêt à intégrer** :

```lua
-- itemVisuel créé une fois ; squareSol chargée et vérifiée avant le rendu.
-- x/y/z calculés par l'état de vol, jamais à partir de la case sous le curseur.
Render3DItem(itemVisuel, squareSol, x, y, zSol + hauteur, rotation)
```

Faire varier `hauteur` graduellement permet une montée continue. La case au sol sert de contexte : aucune case aérienne n'est demandée par cette fonction. Relire la case chargée avant chaque rendu plutôt que conserver une ancienne référence après déchargement.

### Limites précises

- L'événement est appelé chaque image du chemin FBO après le rendu des chunks (`iso/fboRenderChunk/FBORenderCell.java:1014-1039`). `core/PerformanceSettings.java:139` active ce chemin par défaut.
- **Il dépend du curseur** : `FBORenderCell.java:3306-3325` quitte si aucun `UIManager.getPickedTile()` n'existe à la souris, ou si la case de construction est invalide. À la manette il utilise la position du personnage. Vérifier les survols d'interface et la sortie du curseur ; ne pas promettre un appel inconditionnel.
- Le modèle ne s'affiche en 3D que si l'option des objets 3D au sol est active (`WorldItemModelDrawer.java:54-56`). `Render3DItem` a alors un repli vers une texture (`LuaManager.java:9387-9438`) : préparer une icône lisible, ou un rendu 2D propre si ce repli est insuffisant.
- La case source fournit l'éclairage et éventuellement l'alpha d'un meuble support (`ItemModelRenderer.java:427-434`, `iso/objects/IsoWorldInventoryObject.java:710-728`). Préférer un point extérieur dégagé, et tester de nuit.
- Ne pas annoncer une hauteur illimitée : projection, clipping et profondeur sont à tester. Une montée visible de quelques niveaux, terminée par un fondu ou une sortie du cadre, suffit à l'effet envisagé.
- `InventoryItem.setWorldAlpha` existe (`inventory/InventoryItem.java:5048-5053`) et multiplie l'alpha du modèle (`ItemModelRenderer.java:434`). Le repli texture de `Render3DItem` utilise cependant un alpha constant de 1 (`LuaManager.java:9438`) : le fondu n'y est pas équivalent.

## 2. Variante avec les sprites d'une tuile Blender

`IsoSprite` et `IsoSpriteInstance` sont exposés à Lua (`LuaManager.java:2100-2101`). `IsoSpriteInstance.render` accepte `float x/y/z` (`iso/sprite/IsoSpriteInstance.java:130-139`) ; `IsoSprite.prepareToRenderSprite` projette cette hauteur (`IsoSprite.java:1216-1218`). Taille et opacité ont des méthodes publiques (`IsoSpriteInstance.java:142-150,221-224`).

Il est donc possible d'essayer le sprite du ballon à une position aérienne variable. Prévoir un sprite indépendant du câble et du sac, et sa profondeur B42 propre si le chemin de rendu utilise la profondeur des tuiles. Les appels directs aux sprites, leur ancrage et leur contexte FBO restent à prototyper.

**À éviter comme preuve de fluidité :** `RenderGhostTile*` reçoit des coordonnées entières (`IsoSprite.java:508-520`). Sa surcharge avec décalage vertical peut déplacer l'image, mais ce chemin est celui des aperçus fantômes et désactive le test de profondeur (`:534-545,705-706`).

**Autre possibilité :** dessiner un PNG Blender après le monde via `OnPostRender` (`gameStates/IngameState.java:1247-1252`), en projetant sa hauteur par `IsoUtils.YToScreen` (`iso/IsoUtils.java:104-108`). Une hauteur d'un niveau déplace la projection de `96 * Core.tileScale` pixels vers le haut avant zoom. Il faut gérer le viewport, le zoom et les joueurs locaux. Un calque 2D simple ne fournit pas l'occultation du décor : ne pas l'annoncer comme équivalent au rendu 3D.

`OnPostFloorLayerDraw` n'est pas le premier crochet à retenir en 42.21 : il est présent dans l'ancien rendu d'`IsoCell` (`:872`), mais n'est pas déclenché dans le fichier du renderer FBO examiné.

## 3. Câble et séquence Fulton

La globale `renderIsoLine(x,y,z,tx,ty,tz,thickness,r,g,b,a)` existe (`LuaManager.java:8146-8155`). Elle projette les deux extrémités et tient compte de la correction de caméra. Elle permet d'essayer un câble qui s'allonge entre le sac et le ballon ; ce tracé de ligne écran ne prouve pas une occultation 3D du câble. Pour une occultation complète, un maillage de câble nécessitera un prototype distinct.

Séquence proposée, à distinguer des faits moteur :

1. Sac/installateur immobile au sol, ballon gonflé qui monte, câble qui se tend.
2. Ballon en attente à hauteur limitée, léger déplacement latéral visuel.
3. Passage de l'appareil : récupération décidée par le serveur ; le sac et le ballon partent ensemble, avec déplacement horizontal et vertical, puis disparaissent.

La représentation cliente ne contient jamais le butin réel. Son déplacement ou son arrêt de rendu ne doit pas déclencher le gain de confiance. Le serveur conserve les états et valide/consomme le contenu une seule fois ; chaque client reçoit l'identifiant, la phase et le temps écoulé et reconstruit le visuel. Réutiliser le principe de vol de `MilitaryDrop_Heli.lua`, sans considérer son altitude sonore de 20 niveaux comme une altitude visuelle validée.

## 4. Ressources Blender à prévoir

- **Bouteille d'hélium** : objet d'inventaire du mod, modèle FBX texturé et icône 64 × 64 rendue dans Blender. La recherche insensible à la casse dans tous les scripts installés ne trouve toujours aucun `helium`. Une bouteille consommable peut suivre le type `base:drainable` du propane (`scripts/generated/items/drainable.txt:1578-1593`), avec ses propres usages/poids/recette ; ces paramètres restent à concevoir.
- **Ballon** : une recette Blender réutilisable, conservée avec le `.blend`. Export FBX pour la première piste ; rendus isométriques pour la tuile d'installation ou la variante 2D. Le ballon doit être séparé du sac et du câble pour que leurs déplacements soient indépendants.
- Une tuile persistante demande `.pack`, `.tiles`, identifiant libre et profondeur propre. Le visuel 3D temporaire par `Render3DItem` ne demande pas, à lui seul, de tuile ni de `tiledef`.

## 5. Validation avant intégration

1. Dans une partie de test 42.21, dessiner d'abord un objet vanilla avec modèle, par exemple `Base.Bobber` agrandi, via `RenderOpaqueObjectsInWorld`. Lui faire franchir graduellement des hauteurs fractionnaires et plusieurs niveaux, en conservant une case source au sol. Ne pas ajouter cet objet à un conteneur.
2. Vérifier visibilité et clipping en terrain ouvert, devant/derrière un arbre et un bâtiment, depuis un étage et de nuit ; vérifier le zoom et le déplacement de caméra.
3. Déplacer le curseur sur l'inventaire et hors du monde ; essayer une manette et l'écran partagé. Comparer avec un crochet `OnPostRender` si l'événement manque, sans dessiner deux fois le même visuel et sans supposer que la profondeur y est identique.
4. Désactiver les objets 3D au sol et vérifier le repli ; tester le fondu et l'arrêt complet des callbacks.
5. Après réussite du prototype vanilla, remplacer le modèle par le ballon Blender et calibrer dimensions, origine et rotation.
6. Pour la mécanique ultérieure : pause, déchargement de case, reconnexion et deux clients observant la même extraction ; vérifier séparément la consommation unique du butin et le plafond de confiance.

**État à la fin de cette recherche :** API et chemin vertical confirmés dans les sources 42.21.0 ; ascension du ballon, comportement du câble et intégration multijoueur non reproduits en jeu. Le plan d'origine reste conservé comme note d'idée.
