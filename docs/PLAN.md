# Portage B42.21 — plan de travail

Décisions prises le 2026-09-30. L'analyse complète (prérequis EHE, API, HEF) est dans
`docs/third-party-helicopter-mods.md` ; l'hélicoptère vanilla dans
`.claude/pz-knowledge/staging-effects.md` du dossier `Zomboid\Workshop`.

## Décisions

| Sujet | Choix |
|---|---|
| Dépendances | Aucune. Mod **autonome**, sans Expanded Helicopter Events : EHE B42 n'est pas public et sa licence TEHE interdit de réutiliser son code ou ses ressources, même partiellement. |
| Hélicoptère | Visible **à la manière d'EHE** : son 3D qui se déplace, ombre de rotor animée au sol et marqueur de direction. Le serveur calcule la trajectoire ; chaque client dessine l'hélicoptère. Écrit à partir des API du jeu, sans reprendre le code d'EHE. |
| HEF (3672792485) | **Cohabitation propre**, sans intégration : espaces de noms, sons, commandes réseau et ModData distincts. Pas deux hélicoptères au même endroit, pas de bruits cumulés. HEF utilise 112,2 MHz pour son drone : cette fréquence est interdite ici. |
| Workshop | **Nouvel élément B42**, `id=batman_MilitaryDrop`. La page B41 (3259615085, `batman_HTC_EHE_MilitaryDrop`) reste intacte et renverra vers la nouvelle. |
| Caisse | **Modèle et texture originaux** (décidé le 2026-09-30), créés par script (`source/supply_crate/`). La texture B41 `legacy-b41/media/textures/vehicles/EHE/Vehicle_MilitarySupplyDrop*.png` est une **copie à l'octet près** de `Vehicle_FEMASupplyDrop(_mask).png` d'EHE (SHA-256 identique) : la licence TEHE interdit de la réutiliser, de même que le maillage `Vehicle_FEMASupplyDrop`. |
| Délai | **Global au serveur**, stocké côté serveur (ModData globale), durée réglable en sandbox. |
| Contenu v1 | Parité B41 sûre en MP **+ code d'authentification** : les notes donnent la fréquence et un code, exigé lors de l'appel. |

Aucune migration de sauvegarde : les parties B41 ne se chargent pas en B42. Les noms (`HTC`, `HTC_EHE_*`) peuvent donc changer librement.

## Phases

- [x] **0. Cadrage** : projet `Zomboid\Workshop\MilitaryDrop` (branche `b42`), structure `Contents/mods/batman_MilitaryDrop/{common,42.21}`, `workshop.txt` (privé), tests et CI, sources B41 déplacées dans `legacy-b41/` (non publiées, à supprimer avant la sortie).
- [ ] **1. Socle 42.21 en solo** : traductions JSON UTF-8 (EN, FR), objets et `craftRecipe`, options sandbox, aucune surcharge de fichier vanilla. *Code écrit et testé hors jeu (2026-09-30) ; test en jeu à faire.*
  - Quatre caisses `MilitaryDrop.{Ammo,Weapon,Armor,Attachment}SupplyCase` (icônes et modèles des étuis militaires vanilla), recette `OpenMilitarySupplyCase` (menu contextuel), contenu tiré dans `OnCreate` (`MilitaryDrop_Recipe.lua`, solo ou serveur).
  - Butin : tables `ArmyStorage*` filtrées par `ItemType` (armes seules dans la caisse d'armes, sans sacs vides dans celle de munitions), accessoires 42.21, tirage aux poids décimaux (`MilitaryDrop_Loot.lua`). La compatibilité Arsenal et VFE de la B41 est abandonnée : un mod peut remplacer `MilitaryDrop.Loot.CASES[type].source`.
  - Options sandbox lues à l'appel (`MilitaryDrop_Core.lua`) ; fréquence ramenée au pas de 0,2 MHz des radios, bornée à 0,2-1 000 MHz, 112,2 MHz (HEF) décalée.
  - Réparation du talkie-walkie militaire reprise de la B41, puis supprimée le 2026-09-30 (aucun nom d'objet codé en dur).
- [ ] **2. Autorité serveur** : le client envoie une demande ; le serveur vérifie radio, allumage, fréquence (arrondie au pas de 200 du talkie), code, délai global et droits admin, puis crée la caisse, le butin et la horde. Notes tirées côté serveur (ou solo). Branche solo sans commande réseau. *Code écrit et testé hors jeu (2026-09-30) ; test en jeu à faire.*
  - `MilitaryDrop_Net.lua` : `toServer`/`toPlayer`, appel direct en solo (où `sendServerCommand` ne fait rien).
  - `MilitaryDrop_Radio.lua` : radio militaire = `getIsHighTier` (talkie et poste nomade en main ou sur le dos, radio posée à 2 cases au plus). Le serveur résout lui-même la référence envoyée par le client.
  - `MilitaryDrop_Server.lua` : ordre des contrôles admin (`Capability.MakeEventsAlarmGunshot`, comme `/chopper`), radio, allumage, canal et code (même réponse en cas d'erreur), délai global (ModData « MilitaryDrop »). Code dans un fichier du serveur (voir phase 6). Le délai n'est révélé qu'après un canal et un code justes. Une demande toutes les 3 s par joueur au plus. Largage admin sans délai ni contrôle de radio.
  - **Livraison provisoire** : caisses posées au sol sur une case extérieure libre à 15-30 cases de la radio, et horde dans un rayon de 4 cases. Elle sera remplacée aux phases 3 et 5.
  - `MilitaryDrop_Notes.lua` : note `MilitaryDrop.MilitaryMemo` (une page verrouillée, donc « Lire » seulement) ; tenues `army`, `police`, `sheriff` ; tirage mémorisé et note remise après un second `OnZombieDead`. Le texte est dans la langue du serveur.
  - `MilitaryDrop_Client.lua` : menus contextuels (inventaire et monde), saisie du code (`ISTextBox`), réponses de la base par la radio après 5 s, coordonnées après 12 s. La fréquence n'est jamais vérifiée côté client, pour qu'on ne puisse pas la trouver en balayant les canaux.
- [ ] **3. Hélicoptère** : trajectoire côté serveur, envoi aux clients ; son, ombre et marqueur côté client ; reprise après reconnexion. *Code écrit et testé hors jeu (2026-09-30) ; test en jeu à faire.*
  - `MilitaryDrop_Flight.lua` (partagé, calcul pur) : ligne droite depuis 600 cases à 12 cases/s (environ 50 s), 8 s de vol stationnaire au-dessus du point, largage 3 s après l'arrivée, départ sur 600 cases dans le même cap. La position ne dépend que du temps écoulé.
  - `MilitaryDrop_Flights.lua` (serveur) : avance les vols sur `OnTick` (arrêté pendant une pause solo, pas limité à 0,25 s), prévient les clients (`FlightStart`, `FlightSync` toutes les 5 s, `FlightEnd`) et fait du bruit (rayon 60 toutes les 3 s, 150 au largage). Il retarde le départ tant qu'un événement HEF est actif à moins de son rayon + 300 cases (5 min au plus). Une livraison dont la case n'est pas chargée attend `LoadGridsquare`. Au redémarrage, un vol interrompu devient une livraison en attente, sans hélicoptère.
  - `MilitaryDrop_Heli.lua` (client) : son vanilla `Helicopter` sur un émetteur libre local, 20 niveaux plus haut pour ne pas être étouffé ; ombre `circle_shadow` pulsée ; flèche `dir_arrow_up` pour chaque joueur local entre 25 et 400 cases. Un vol sans `FlightEnd` est retiré 10 s après sa fin prévue. Un client qui (re)vient demande les vols en cours (`Sync`).
  - Les coordonnées sont annoncées 4 s après le largage réel.
- [ ] **4. Annonces** : chaîne radio dynamique sur la fréquence sandbox (fin du balayage de cellule) ; marqueur de carte pour les joueurs à l'écoute seulement. *Code écrit et testé hors jeu (2026-09-30) ; test en jeu à faire.*
  - `MilitaryDrop_Broadcast.lua` (serveur) : chaîne `DynamicRadioChannel` « Military Logistics » (catégorie Military) créée à `OnLoadRadioScripts`. Son nom est retiré des noms connus pour que le panneau de la radio ne révèle pas la fréquence ; si la fréquence est déjà prise, un avertissement est journalisé et il n'y a pas d'annonce. Au départ de l'hélicoptère : « en route », sans coordonnées. Au largage : coordonnées répétées 3 fois avec le code `MDRP`, puis fin.
  - `MilitaryDrop_Announce.lua` (client) : coordonnées reçues de tous (`DropAnnounce`), mais symbole « Target » ajouté à la carte seulement si une radio du joueur reçoit une ligne `MDRP` (`OnDeviceText` : en main, ou posée à 5 cases au plus). Un seul symbole par largage, sans doublon.
  - Le demandeur n'a plus de message privé de coordonnées (il est sur la chaîne), sauf pour un largage admin.
- [ ] **5. Caisse 3D** : modèle Blender, script de véhicule 42.21 (`frontEndDurability`…), coffre rempli par le serveur. *Modèle, texture, script et Lua écrits (2026-09-30), testés hors jeu ; rendu, échelle et collisions à vérifier en jeu.*
  - Modèle et texture **originaux** : `source/supply_crate/make_texture.py` (atlas 1024 : contreplaqué olive, pochoirs « U.S. ARMY », flèches « THIS SIDE UP », étoile, palette, sangles, boucles ; masque noir) et `build_supply_crate.py` (Blender sans interface : palette, caisse, couvercle, quatre sangles et boucles, 208 sommets, 1,10 × 1,10 × 0,88 m ; export FBX, aperçus, `supply_crate.blend`). Aperçu : `source/supply_crate/preview_se.png`.
  - FBX : sommets en centimètres, Y vers le haut, sans transformation de nœud (`bake_space_transform`). Script de modèle `scale = 0.01`, véhicule `scale = 1.0` : valeurs du script en mètres.
  - `scripts/vehicles/MilitaryDrop_SupplyCrate.txt` : véhicule `Base.MilitaryDrop_SupplyCrate` sans roues, sur le modèle de la remorque vanilla, coffre `TrailerTrunk` (sans clé, capacité 150), textures de salissure et de dégâts vanilla.
  - `MilitaryDrop_Crate.lua` (serveur) : distribution vide pour le coffre, remplie par `OnFillContainer` avec `CaseRolls` caisses de ravitaillement tirées au moment du largage. Caisse créée par `addVehicleDebug` sur la case d'atterrissage, qui doit être sans véhicule. En repli, les caisses de ravitaillement sont posées au sol.
  - À vérifier en jeu : taille et orientation du modèle, caisse posée au sol (ni enfoncée ni flottante), ouverture du coffre, contenu, nom affiché « Caisse de largage militaire ».
- [x] **6. Qualité** : espace de noms `MilitaryDrop`, aucune globale, traces de debug sous option, luacheck, tests `lupa` (tirage pondéré, délai, fréquence, code). *Fait le 2026-09-30 : 67 tests, règle luacheck « aucune globale hors `MilitaryDrop` », relecture indépendante du code.*
  - Corrections issues de la relecture :
    - le code d'authentification n'est plus dans la ModData globale, que tout client peut demander (`ModData.request`). Il est dans un fichier du serveur, `Zomboid/Lua/MilitaryDrop/<mode>_<partie>_code.txt`, avec reprise d'un ancien code ;
    - mauvais canal et mauvais code donnent la même réponse (grésillements), pour qu'on ne trouve pas la fréquence en appelant chaque canal ;
    - la radio doit être en main ou sur le dos : en solo, une radio rangée dans l'inventaire n'entend pas la chaîne ;
    - la caisse est vérifiée comme réellement ajoutée au monde (`getSqlId() ~= -1`). Elle occupe les quatre cases autour du coin nord-ouest de la case visée, qui doivent être libres ; au largage, la case est revérifiée et déplacée au besoin, avec repli au sol ;
    - les livraisons différées (redémarrage, zone non chargée) attendent `LoadChunk` au lieu de `LoadGridsquare`, puis sont revérifiées et annoncées ;
    - sans chaîne militaire (fréquence prise), le demandeur reçoit les coordonnées en privé ;
    - deux annonces proches s'enchaînent sur la même diffusion au lieu de s'écraser ;
    - zone d'accès au coffre portée à 2,5 × 2,5 m ; requêtes terminées retirées côté client.
  - **Compromis accepté** : les coordonnées d'un largage (`DropAnnounce`) partent vers tous les clients, qui ne marquent leur carte que s'ils entendent l'annonce. Un client modifié peut donc les connaître sans écouter la radio. Les réserver aux auditeurs demanderait au serveur de connaître l'état de toutes les radios de chaque joueur.
- [ ] **7. Tests** : solo, hébergé, serveur dédié (`C:\pzserver`) avec 2 clients, reconnexion, commande forgée, partie avec HEF.
  - **Solo, 2026-09-30** (protocole `docs/TEST-PROTOCOL.md`, console surveillée) : options sandbox, recette, B1 à B7, C1 à C4, D1, D2, E1 à E3 **réussis**. Aucune erreur du mod dans la console. La chaîne est créée sur 151,4 MHz, le code est écrit dans son fichier, la caisse 3D est bien posée et son coffre contient 6 caisses.
  - Défauts trouvés, corrigés le même jour, à retester :
    - caisses de ravitaillement posées au sol affichées en damier : les modèles vanilla n'ont pas de texture sans `ClothingItem` → modèles propres (`MilitaryDrop_models.txt`) ;
    - note ajoutée par la console vide (« rien d'intéressant ») → remplie par l'`OnCreate` de l'objet ;
    - armes sans chargeur → 2 chargeurs et 1 boîte de munitions par arme ;
    - largage admin refusé avec une radio rangée → radio facultative pour l'admin.
  - Retest solo du 2026-09-30 : largage admin avec radio rangée, caisses d'armes, de munitions et d'accessoires ouvertes sans erreur, option MaxZombies respectée (46 zombies).
  - Pas encore testés : D3 (nom de la chaîne masqué), D4, F (sauvegarde), multijoueur.
- [x] **Aucun nom d'objet codé en dur** (demande du 2026-09-30) :
  - `MilitaryDrop_Loot.lua` reconnaît les objets par leur catégorie de jeu : arme à feu (`isRanged` et dégâts > 0, ce qui écarte les pistolets à amorces), munitions (chargeur ou boîte d'une arme à feu existante), équipement de protection (`getBulletDefense` > 0), accessoire (`WeaponPart`). Chaque caisse lit la table de l'armée, puis toutes les tables du jeu si elle manque ou ne donne rien. Les accessoires viennent de toutes les tables, poids additionnés. Les noms sans module sont cherchés dans tous les modules (`getItemsByType`).
  - Vérifié sur les données vanilla 42.21 (tables et scripts réels) : 4 armes, 9 munitions, 26 équipements et 10 accessoires en temps normal. Avec les tables de l'armée absentes, le repli donne 20 armes à feu, 13 munitions et 35 protections, sans jouet.
  - Tenues qui portent les notes : options sandbox `NoteOutfits` (`Army;Police;Sheriff`) et `NoteOutfitsExcluded` (`Stripper`), pour suivre aussi les tenues des mods.
  - Réparation du talkie-walkie militaire **supprimée** (elle nommait deux objets vanilla).
  - Restent écrits dans le mod : ses propres objets (caisses, note, véhicule) et les noms des tables de butin de l'armée, qui sont des sources et non des objets.
- [ ] **8. Publication** : art (skill `pz-workshop-art`), suppression de `legacy-b41/`, nouvel élément Workshop, lien depuis la page B41.

## Défauts B41 à ne pas reproduire

Relevés dans `legacy-b41/` (numéros de ligne de ces fichiers).

- `server/HTC_EHE_ServerHandler.lua:70-92` : la commande `CallMilitaryDrop` n'est pas validée (fréquence, délai, admin vérifiés sur le client seulement).
- `client/HTC_EHE_ClientHandler.lua:26-56` : délai dans la ModData du joueur côté client (trichable, par joueur, non synchronisé).
- `shared/HTC_EHE_NoteDrop.lua` : tirage des notes sur le client et le serveur ; nom sans `setCustomName` ; `outfitName` nil contourne l'option « militaires ou policiers » ; `print` à chaque mort de zombie ; globales.
- `client/HTC_EHE_ClientHandler.lua:204` : variable `i` inexistante (plantage avec un talkie en inventaire).
- `shared/HTC_EHE_preset.lua:37` : `sendServerCommand` inopérant en solo (aucune annonce ni marqueur).
- `client/HTC_EHE_ClientHandler.lua:89-118` : balayage de toute la cellule sur tous les niveaux.
- `client/HTC_EHE_ClientHandler.lua:68` : `setIsTurnedOn` côté client, non synchronisé.
- `client/RadioCom/ISRadioWindow.lua` : copie B41 d'un fichier vanilla (casse l'interface radio B42).
- `shared/lua_timers.lua` : globale `timer`, chemin partagé avec d'autres mods, `os.time` à la seconde.
- `server/HTC_EHE_ServerHandler.lua:78-88` : `forceUnlaunchTime` mélange `getNightsSurvived` et l'âge du monde ; `HOUR > 24` au lieu de `>= 24`.
- `shared/HTC_EHE_preset.lua:53-83` : tirage pondéré tronqué pour les poids décimaux ; IDs de compatibilité Arsenal et VFE de B41.
- Traductions FR en ANSI ; `Tooltip_EN.txt` déclare `Tooltip_FR` ; libellés sandbox FR non traduits.

## Idées pour après la v1

Reprises de `legacy-b41/TODO (oneday).txt` et de l'analyse :
- autres types de largage (médical, outils, semences), une fréquence par type ;
- fréquence tirée au hasard par partie, diffusée à la télévision ;
- zone de largage choisie au fumigène ou à la fusée éclairante ;
- consommation de pile, risque d'interception de l'annonce.
