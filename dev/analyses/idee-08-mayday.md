# Idée 8 — Mayday (hélicoptère abattu, carcasse démontable) : analyse d'impact et plan

Analyse du 2026-09-30, en lecture seule (sous-agent). **[C]** = confirmé dans les sources ; **[S]** = supposé ou à vérifier en jeu. **Rien n'a été testé en jeu.**

## Implémentation du 2026-10-02

Autorisée par l’utilisateur, sur `feature/mayday-wreck`. Les sections suivantes restent l’analyse d’origine ; les choix réalisés sont précisés ici.

- Crash décidé une fois par le serveur et sauvé dans le vol ; MAYDAY cinq secondes avant l’impact, secteur de 50 cases marqué seulement pour ceux qui entendent la radio. Pas de modèle volant : ombre vacillante, flèche rouge et sons vanilla.
- Fuselage et queue sont deux véhicules sans roues/sièges, avec des modèles originaux arrondis. Enveloppes libres et entièrement chargées de 11 × 11 et 7 × 7 cases, couvrant rotations et pales. Recherche à proximité ; absence de place : lots de récupération au sol.
- Clic droit « Récupérer les pièces de l’épave » : mécanique du véhicule. Avionique puis baie radio ; moteur puis moyeu puis panneaux. Outils et compétences revérifiés à la fin de l’action serveur ; réinstallation interdite. Le maillage est conservé jusqu’à la découpe finale vanilla, disponible une fois toutes les pièces retirées. Les lots s’ouvrent par leurs recettes contextuelles et utilisent les catégories/tags du jeu et des mods.
- Pilote définitivement mort, note, carnet et enregistreur récupérables. L’enregistreur est un objet de collection ; son envoi à la base et une récompense ne font pas partie de cette implémentation.
- Dix options : `CrashChance` (5 %), `CrashStormBonus` (+15 points), `CrashGunfire` (faux), `CrashGunfireChance` (10 %), `CrashFire` (fumée), `CrashSmokeMinutes` (60), `CrashCrates` (vrai), `SalvageRolls` (3), `PilotOutfits` (`Army`), `PilotDocuments` (vrai). Horde selon les options existantes. Pas de gain/perte de réputation pour un crash, même avec du ravitaillement récupéré.
- Les largages forcés et leurres sont exclus des crashes aléatoires/tirs. Le menu admin « Faire crasher le prochain hélicoptère » impose toutefois le prochain départ du mod, y compris forcé ou leurre. Même droit que `/chopper`, réponse privée ; pas de radio en main exigée. L’ordre persiste dans les données privées, ne s’empile pas, et attend la fin de l’attente HEF ; aucun effet sur les appareils déjà partis.
- Après redémarrage, un appareil condamné déjà parti devient un site en attente ; un départ encore en attente reste en attente. Le registre de chaque composant est écrit avant sa pose. Une interruption marquée `placing` est journalisée et ne relance pas aveuglément la pose : elle peut laisser un composant manquant, à inspecter.
- Les tirs facultatifs dépendent d’un signal client. Le serveur vérifie option, cadence, arme, munitions, direction, distance et phase du vol ; il ne peut pas prouver qu’une détonation a réellement eu lieu. Option désactivée par défaut.

Validation hors jeu : `tests/run_tests.py --require-luacheck`, `tests/check_mayday_assets.py`, aperçus Blender. Source installée : `projectzomboid.jar` SHA256 `E1A69EB743EDE60B213A0FE7F8B83D4FCAB773036D256CC4543A336F3B058A33`, identique au relevé des sources décompilées 42.21.0 ; journal `console.txt` : `version=42.21.0 4a0e9546ec`. Cela confirme la version inspectée, pas une exécution du nouveau code en jeu. Protocole M1-M8 dans [TEST-PROTOCOL.md](../TEST-PROTOCOL.md).

## Révision du 2026-10-04

- Visuels de l'épave corrigés : normales extérieures, UV, peinture usée et ombres transparentes projetées depuis les deux FBX livrés ; voir [sources des modèles](../../source/heli_wreck/README.md).
- Cadavre conservé avec les documents et l'enregistreur ; deux pilotes militaires zombies ajoutés aux **nouveaux** crashs, chacun suivi indépendamment. La première tenue mod, `MilitaryDrop_ArmyPilot`, préfixait ses GUID vanilla par l'id du mod : aucune pièce n'était résolue, les zombies apparaissaient en sous-vêtements. Ils utilisent désormais la tenue vanilla `ArmyCamoGreen`, inscrite pour homme et femme dans les sources installées. Le démembrage du cadavre n'est pas réalisé : aucune API native de cadavre démembré confirmée dans les sources installées, représentation spécifique nécessaire.
- Navigation corrigée : le `VehiclePoly` vanilla bloque un rectangle dérivé de `extents.x/z`, indépendamment des formes physiques ; l'ancienne boîte 7,86 × 6,24 m incluait l'envergure entière des pales. Les extents de collision passent à 2,8 × 5,8 m, autour du fuselage et des patins ; le FBX et l'ombre gardent leurs dimensions visuelles.
- Un seul petit foyer initial et la fumée sont placés près du fuselage **réellement posé**, après la recherche d'une zone libre, et non au point annoncé si l'épave a été déplacée. Les cases du feu et de la fumée sont distinctes : `CanAddSmoke` refuse une case déjà en feu. Le foyer n'est pas rallumé après extinction.
- `CrashFire` passe par défaut à « Feu et fumée » (3) pour les nouveaux réglages. Un monde existant à « Fumée » (2) garde ce choix : sélectionner « Feu et fumée » avant de provoquer un nouveau crash. NoFire/safehouses/FireSpread restent appliqués ; « petit » décrit le foyer initial, pas une garantie d'absence de propagation.
- Fumée durable en solo et MP : helper local, un seul objet par case, renouvelé avant le stade invisible. Commande serveur `WreckSmoke`, réémise pendant la durée sandbox pour les arrivants ; ne pas empiler les paquets natifs `StartSmoke` côté client et ne pas supprimer les feux d'autres systèmes.
- Vérifications hors jeu : suite Lua simulée, luacheck, assets et tenues XML. Journal et empreinte des sources toujours 42.21.0. Les visuels, le feu, la fumée et les pilotes de cette révision restent à confirmer en jeu et en MP. Les sons sont traités dans une autre session.

## Révision du 2026-10-05

- L'interface de mécanique vanilla n'affichait aucune carcasse : le script n'avait pas d'entrée dans `ISCarMechanicsOverlay.CarList` et aucun masque par pièce. `MilitaryDrop_WreckMenu.lua` enregistre désormais le fuselage et la queue, avec des images et zones de survol dédiées pour les composants de récupération.
- Les huit masques 263 × 600 sont générés par `source/heli_wreck/make_mechanics_overlays.py` sous `common/media/ui/vehicles/mechanic overlay/`. La passe de finition ajoute des panneaux et détails de coque et étend la hitbox de la queue aux stabilisateurs. Les PNG ont été inspectés statiquement ; aucun affichage après cette passe n'a encore été vérifié en jeu.

## 1. Faisabilité

**La carcasse est un véhicule sans roues, dans la continuité de la caisse.**
- **Physique** : on peut ajouter des `physics box/sphere` à `physicsChassisShape` (`VehicleScript.java:484, 717-760`). Le tableau envoyé au moteur physique compte 200 flottants (`:696`), soit **18 formes au plus** sans roues **[C]**. Le fuselage, la poutre de queue et le mât peuvent donc être modélisés par des boîtes séparées.
- **Taille** : les véhicules vanilla font au plus environ 4,8 m. Des mods B42 en ont de bien plus grands, comme une semi-remorque de 13,8 m **[C]**. Rien n'est testé en 42.21 **[S]**.
- **Pose** : `addVehicleDebug` ne vérifie que la case centrale et les collisions avec d'autres véhicules ; il ne voit ni les murs ni les arbres (`IsoChunk.java:1248-1270`) **[C]**. Le mod doit vérifier lui-même toute l'empreinte, en comptant l'écart aléatoire de ±0,2 rad. Il faut une zone libre d'environ 12 × 5 cases, chargée en entier.
- **Nom du script** : un nom qui contient `Burnt` ou `Smashed` active l'option vanilla « Démonter l'épave » (`ISVehicleMenu.lua:617`, `ISRemoveBurntVehicle.lua` : chalumeau, masque de soudeur, métal déposé sur la case, puis `permanentlyRemove`) **[C]**. Il active aussi le menu de remorquage, qui exige des attaches `trailer` ; sans attache, pas de remorquage **[S]**. Recommandation : `MilitaryDrop_HeliWreckBurnt`, pour que la découpe finale soit une mécanique vanilla, dont les noms d'objets restent dans le code vanilla.
- **Effet de bord** : quand le script d'un véhicule manque, le moteur le remplace au hasard par un script sans roues (`BaseVehicle.java:1518-1583`) **[C]**. La caisse ou l'épave peut donc remplacer l'épave d'un mod retiré.

**Démontage progressif par pièces de véhicule désinstallables.**
- Le bloc `uninstall` accepte des outils par tag (`tags = base:screwdriver`, `base:wrench`…), `skills`, `recipes`, `traits` et `requireUninstalled` pour imposer un ordre (`Vehicles.lua:932-957`) **[C]**.
- `ISUninstallVehiclePart:complete` s'exécute sur le serveur, sans rejouer le test des outils : notre `complete` doit les revérifier **[C]**.
- Pièces proposées : `Avionics`, `RadioRack`, `EngineBay`, `RotorHub`, `SkinPanels`. Chacune donne un « lot de récupération » propre au mod, qu'une `craftRecipe` sans sortie ouvre ensuite par `OnCreate`.
- L'état persiste et se synchronise par l'objet installé dans chaque pièce (`transmitPartItem`). `BaseVehicle` n'a pas de `transmitModData`, seulement `transmitPartModData` **[C]**.

**Matériaux sans nom codé en dur [C]** :
- métal : `DisplayCategory = Material` avec le tag `base:hasmetal`, ou les familles `base:smeltable*`, `base:scrapaluminum`, `base:wire`, `base:metalpiece` ;
- électronique : `DisplayCategory = Electronics` ;
- pièces : `DisplayCategory = VehicleMaintenance`.

Le tirage parcourt `getScriptManager():getAllItems()`, avec toute la catégorie `Material` en repli.

**Fumée et feu.**
- `IsoFireManager.StartFire` (serveur ou solo) respecte `NoFire`, `safehouseAllowFire` et `fireSpread` **[C]**. La propagation est un vrai risque : option sandbox.
- `StartSmoke`, sur un serveur, se contente d'envoyer un paquet aux clients proches, sans objet côté serveur (`IsoFireManager.java:209-235`) **[C]**. Un joueur qui arrive plus tard ne voit rien : il faut la réémettre **[S]**.
- Traînée en vol : impossible (pas de modèle volant). On la remplace par une ombre qui vacille, une flèche rouge et un son **[S]**.

**Pilote.**
- `RandomizedWorldBase.createRandomDeadBody(sq, dir, sang, 0, tenue)` est exposé et envoie le corps aux clients (`RandomizedWorldBase.java:444-507`) **[C]**.
- Aucune tenue « pilote » vanilla : tenue choisie par un mot de l'option sandbox.
- Documents : `body:getContainer():AddItem`, puis `sendAddItemToContainer`, puis `setFakeDead(false)`.

**Causes et probabilité.**
- **Orage** : `isThunderStorm()`, `getWindIntensity()` **[C]**.
- **Horde** : on ne peut compter que les zombies réels chargés, donc cause faible **[S]**.
- **Tirs de joueurs** : le serveur ne reçoit rien pour un tir qui ne touche personne. Il faut un signal du client, revérifié par le serveur, et un joueur peut alors abattre le largage d'un autre. Cause désactivée par défaut.
- **Décision prise par le serveur au lancement** et enregistrée dans le vol : un redémarrage ne relance pas le tirage.

**Son, horde, radio.**
- Sons vanilla joués par le client sur un émetteur libre : `BurnedObjectExploded`, `PipeBombExplode` (portée 1 000), `VehicleCrash` **[C]**. `playServerSound` n'a qu'un rayon de 5 : envoyer plutôt une commande `FlightCrash` aux clients.
- `addSound` (rayon d'au moins 50), puis `spawnHorde` au point de chute.
- Radio : lignes « MAYDAY » sur la chaîne existante, avec le code `MDAY` et une position approchée.

## 2. Chaîne de production 3D

- Script `source/heli_wreck/`, sur le modèle de la caisse.
  - `make_texture.py` : atlas 2048, peinture olive mate, panneaux et rivets, suie, verrière brisée, pochoir « ARMY » et numéro fictif, masque noir.
  - `build_heli_wreck.py` : fuselage générique **original** de 9 à 10 m (cabine, patins tordus, verrière brisée, mât avec deux pales affaissées) ; poutre de queue avec rotor en second maillage.
  - Export FBX en cm, Y vers le haut, `bake_space_transform` ; `scale 0.01 / 1.0`.
- Deux véhicules :
  - `HeliWreckBurnt` : fuselage, 3 à 5 `physics box` ;
  - `HeliTailBurnt` : environ 4 m, démontable, posé plus loin sur la ligne de débris.
- Effort : modèle 2 à 3 j, texture 1 j, calibrage 0,5 à 1 j.

## 3. Conception

**Fichiers à créer :**
- `shared/MilitaryDrop_Crash.lua` (calcul pur) : décision, point de chute, ligne de débris, empreinte tournée ;
- `shared/MilitaryDrop_Salvage.lua` : matériaux par catégorie et tag, avec repli ;
- `server/MilitaryDrop_Wreck.lua` : pose des pièces, feu et fumée, corps, `uninstall.complete` ;
- `scripts/vehicles/MilitaryDrop_HeliWreck.txt` ;
- objets (lots de récupération, carnet du pilote), recette `OpenSalvageBundle`, traductions.

**Fichiers à modifier :**
- `Flight` : phase `crash` ;
- `Flights` : chute et livraisons en attente par pièce ;
- `Broadcast` : `mayday()` ;
- `Heli` : effets de chute et son ;
- `Announce` : code `MDAY` ;
- `sandbox-options.txt`.

**Réseau** : `FlightCrash {id, x, y, t}`, `DropAnnounce` étendu. Commande client facultative : `GroundFire`.

**Options sandbox** : `CrashChance`, `CrashStormBonus`, `CrashGunfire` (désactivée par défaut), `CrashFire` (aucun / fumée / feu), `CrashCrates`, `SalvageRolls`, `PilotOutfits`, `PilotDocuments`.

**Persistance** : le vol enregistre `crash = {t, x, y, heading, cause}`. Au chargement, un vol condamné devient un **site de chute en attente**. Chaque pièce devient une entrée en attente, livrée au `LoadChunk` de son chunk ; l'épave attend en plus que toute son empreinte soit chargée. Le registre anti-doublon est écrit **avant** chaque pose.

## 4. Risques et limites

- Il faut une zone libre de 12 × 5 cases. En forêt ou en ville, chercher le long de la trajectoire. Sans place : pas d'épave, seulement débris et caisses.
- L'empreinte peut chevaucher des chunks non chargés, surtout sur un petit écran.
- Incendie qui se propage, fumée non persistante, coût d'un `LoadChunk` supplémentaire.
- La physique d'un grand véhicule en MP (qui la calcule, poussée par une voiture) n'est pas vérifiée **[S]**.
- Retrait du mod : l'épave est remplacée par un script sans roues pris au hasard.
- À tester en jeu :
  - rendu, échelle et collisions ;
  - démontage en MP et découpe vanilla ;
  - corps et documents ;
  - fumée vue par un joueur qui arrive ;
  - redémarrage en plein vol ;
  - `NoFire` actif ;
  - coexistence avec HEF.

## 5. Plan par étapes

1. **Décision et trajectoire** (1 j) : `Crash.lua` pur, phase `crash`, persistance. Tests : probabilité et bornes, bonus d'orage, point sur le segment d'approche, même résultat après restauration.
2. **Site sans 3D** (1,5 j) : caisse et repli au sol, ligne de débris, horde, bruit, MAYDAY, `FlightCrash`. Tests : restauration, attentes par chunk, lignes `MDAY`, empreinte tournée.
3. **Corps et documents** (0,5 à 1 j) : tenue par option, carnet (idée 4). Tests : filtre de tenues, repli.
4. **Modèle 3D et script de l'épave** (3,5 à 5 j) : contrôle de l'export, test en jeu solo.
5. **Démontage** (2 j) : pièces `uninstall` avec outils par tag et ordre imposé, revérification serveur, lots et recette, découpe vanilla. Tests : sélection des matériaux (tags, catégories, exclusions, repli), validation des outils.
6. **Feu et fumée** (1 j) : options, `NoFire`, réémission de la fumée.
7. **Tirs de joueurs, facultatif** (1 j) : plausibilité, cadence, commandes forgées refusées.
8. **Tests MP** (1 à 2 j) : serveur dédié, deux clients, reconnexion, redémarrage.

**Total** : environ 11 à 15 jours. Ne reprendre ni le code ni les ressources d'EHE (on peut seulement citer qu'EHE fait des épaves).
