# Military Drop — améliorations de code et idées de fonctionnalités

- **Mod** : Military Drop (`id=batman_MilitaryDrop`, Workshop 3811752923), version **0.5.4** (`mod.info`, `modversion=0.5.4`, `versionMin=42.21`, `require=\batman_BeltRadio`).
- **Date** : 2026-10-21.
- **Périmètre** : code chargé `Contents/mods/batman_MilitaryDrop/42.21` et `common` (Lua client, serveur et partagé, scripts, traductions des 8 langues), `README.md`, `CHANGELOG.md`, guide `docs/wiki/`, notes de développement et analyses (déplacées pendant cette analyse de `dev/` vers `docs/annexes/plans/` et `docs/annexes/recherches/` : les chemins cités ci-dessous sont les nouveaux), tests `tests/`. `legacy-b41/` ignoré.
- **Méthode** : lecture statique, comparaison avec le Java décompilé 42.21.0 (`E:\pz-decompiled\42.21.0\java`) et la base `.claude/pz-knowledge`. **Rien n'a été testé en jeu** pour ce document. Chaque constat porte la mention « confirmé statiquement » ou « à vérifier en jeu ».
- **Constat général** : le code est d'une qualité nettement au-dessus de la moyenne des mods : autorité serveur systématique, cadence par commande (`MilitaryDrop_Guard`), secrets hors de la ModData publique, retraits après `pairs`, abonnés uniques au rechargement, traductions serveur rechargées (`MilitaryDrop_ServerTranslations.lua`), 48 fichiers de tests `lupa`. Les 718 clés de traduction sont présentes dans les 8 langues, sans clé manquante ni orpheline (contrôle par script : les 12 clés « absentes » relevées sont des clés vanilla ou des préfixes dynamiques comme `IGUI_MilitaryDrop_AckTier<n>_<m>`). Les constats ci-dessous sont donc surtout des cas limites, de la dette de structure et des écarts de documentation.

---

## Partie 1 — Améliorations de code

### C01 — `spawnHorde` s'arrête au premier zombie impossible : horde du largage et du crash incomplète près de l'eau

- **Problème** : `spawnHorde` (Java) tire chaque case au hasard dans le rectangle, puis appelle `createRealZombieAlways` et **sans contrôle** `zombie.dressInRandomOutfit()`. Or `createZombieOutsideWorld` rend `null` pour une case d'eau, si la création de zombies est désactivée, ou si le serveur n'a plus d'identifiant de zombie. La NPE est rattrapée par `MethodCaller` (journalisée, aucune erreur Lua) **et la boucle Java s'arrête** : les zombies restants ne sont jamais créés.
- **Preuves** :
  - `E:\pz-decompiled\42.21.0\java\zombie\Lua\LuaManager.java:4395-4406` (boucle, `dressInRandomOutfit` sans test) ; `zombie\VirtualZombieManager.java:247-261` (`return null` pour `isWaterSquare`, `doZombieCreation`) et `:215-221` (`onlineId == -1`).
  - Appels : `MilitaryDrop_Server.lua:679` (horde du largage, carré de 9 × 9 autour de la caisse), `MilitaryDrop_Wreck.lua:217` (carré de 31 × 31 autour de l'épave).
  - Base : `kahlua-lua.md`, « Exception d'une méthode Java exposée : journalisée, `nil` rendu, aucune erreur Lua ».
- **Conséquence secondaire** : le `pcall` de `MilitaryDrop_Missions.lua:944-949` ne protège rien (le commentaire suppose une erreur Lua) ; la mission reste correcte grâce au contrôle de la taille de la liste qui suit.
- **Risque** : horde plus petite que l'option `MinZombies`/`MaxZombies` sur les zones au bord de l'eau (Riverside, rives de l'Ohio, lacs) et trace Java `NullPointerException` dans `console.txt` à chaque largage concerné, qui brouille le diagnostic. Aucune duplication : la livraison continue.
- **Correction** : tirer les cases en Lua (case chargée, `not isWaterSquare()`, `isFree(false)`, hors bâtiment) puis appeler `spawnHorde` case par case comme `Missions.spawnOne` (`MilitaryDrop_Missions.lua:944-960`), dans une aide commune (`MilitaryDrop.Horde.spawnAround(x, y, r, n)`) utilisée par le largage, l'épave et le nettoyage. Retirer le `pcall` inutile et corriger son commentaire.
- **Statut** : confirmé statiquement ; fréquence réelle à vérifier en jeu (largage sur une plage). **Priorité haute, effort S.**
- **Statut : corrigé (commit 6c62913), à vérifier en jeu** — aide commune `Server.spawnHordeAround` (`MilitaryDrop_Server.lua`) pour le largage et l'épave ; `pcall` de la mission retiré.

### C02 — Copie de secours de Belt Walkie-Talkie devenue du code mort

- **Problème** : depuis 0.5.1, `mod.info:8` déclare `require=\batman_BeltRadio`. Le jeu active alors toujours `batman_BeltRadio` (ou refuse de charger Military Drop s'il manque) ; la copie de secours `BeltRadioFallback/` (≈ 830 lignes : `BatmanRadio_Core.lua` 542, `BatmanRadio_Support.lua` 117, `BatmanRadio_BeltBattery.lua` 98, `BatmanRadio_Compat.lua` 69) sort dès sa première ligne (`BatmanRadio_Compat.lua:7-14`) et ne s'exécute plus jamais.
- **Preuves** : `mod.info:8` ; `shared/MilitaryDrop/BeltRadioFallback/BatmanRadio_Compat.lua:7-14` ; CHANGELOG 0.5.1 ; base `mod-loading.md` (« `require` qui active en silence un mod absent de `Mods=` »).
- **Risque** : maintenabilité (copie générée par `BeltRadio/tools/sync_fallback.py` depuis la version 1.0.0, qui diverge du mod commun), tests à entretenir (`tests/lua/test_beltradio_fallback.lua`), confusion lors d'un diagnostic (deux implémentations du même récepteur dans l'arbre).
- **Correction** : retirer `BeltRadioFallback/` et son test, simplifier `MilitaryDrop_RadioLib.lua` (plus de choix entre mod commun et copie), garder seulement le contrôle de version d'API (`MilitaryDrop_RadioLib.lua:55`). À ne faire que si le retour à une dépendance facultative est exclu (décision 0.5.0 → 0.5.1 à confirmer par l'utilisateur).
- **Statut** : confirmé statiquement. **Priorité moyenne, effort S.**
- **Statut : décidé et fait — corrigé (commit d820c24), à vérifier en jeu** — décision de l'utilisateur du 2026-10-21 : Belt Walkie-Talkie reste prérequis ; `BeltRadioFallback/` et `test_beltradio_fallback.lua` retirés, `RadioLib` charge toujours `BatmanRadio/…` (contrôle de version gardé), tests radio sur le vrai récepteur `../BeltRadio`.

### C03 — Les vrais vols Fulton passent par des fichiers « prototype » avec menu de debug en français codé en dur

- **Problème** : le rendu et la synchronisation des extractions Fulton réelles (FULTON-07) vivent dans `MilitaryDrop_FultonPrototype.lua`, `MilitaryDrop_FultonPrototypeServer.lua` et `MilitaryDrop_FultonPrototypeFlight.lua`, avec des objets `FultonPrototypeBalloon/Bag` dans `MilitaryDrop_FultonPrototype.txt`. Le menu de test (debug seulement depuis 0.5.4) garde des libellés français non traduits et sans accents, et chaque changement de phase de chaque vol est écrit dans la console de **tous** les clients.
- **Preuves** : `server/MilitaryDrop/MilitaryDrop_FultonServer.lua:38, 219-224` (dépendance du vrai lancement au module prototype) ; `client/MilitaryDrop/MilitaryDrop_FultonPrototype.lua:269-282` (« Fulton - prototype visuel », « Lancer la montee du ballon »…) ; `:125` (`print("[MilitaryDrop Fulton prototype] " .. id .. " " .. phase)`).
- **Risque** : maintenabilité (un « prototype » qu'on n'ose plus retirer), bruit dans `console.txt` en production, règle du projet sur les textes joueur (libellés hors traduction, même en debug).
- **Correction** : renommer en `MilitaryDrop_FultonRender*` / module `FultonFlight` (les objets visuels peuvent garder leur nom de script pour ne pas toucher aux sauvegardes : ils ne sont jamais dans un inventaire), déplacer le menu de test dans un fichier `*_Debug.lua` chargé seulement si `isDebugEnabled()`, passer ses libellés en clés `IGUI_` ou en anglais, et conditionner le `print` de phase à `isDebugEnabled()`.
- **Statut** : confirmé statiquement. **Priorité moyenne, effort S-M.**
- **Statut : corrigé en partie (commit 498f0d1), à vérifier en jeu** — libellés du menu de test en anglais, `print` de phase seulement en mode debug ; renommage des fichiers « prototype » et menu dans un fichier `*_Debug.lua` restent à faire.

### C04 — Guide : plafond quotidien de confiance « +8/jour » alors que la valeur par défaut est 10

- **Problème** : le CHANGELOG 0.4.0 a porté `TrustDailyCap` de 8 à 10, mais la page joueur « Confiance et missions » annonce toujours **+8/jour/personnage**, alors que la page admin dit 10.
- **Preuves** : `docs/wiki/fr/04-trust-and-missions.md:47` et `docs/wiki/en/04-trust-and-missions.md:47` ; `42.21/media/sandbox-options.txt:147-150` (`default = 10`) ; `server/MilitaryDrop/MilitaryDrop_Trust.lua:47` (`TrustDailyCap = 10`) ; `docs/wiki/fr/06-server-admin.md:59` ; `CHANGELOG.md:87`.
- **Risque** : documentation joueur fausse (et descriptions Steam si elles reprennent le tableau : à contrôler dans les 8 `README.steam*`).
- **Correction** : écrire « plafond réglable (`TrustDailyCap`, 10 par défaut) » dans les deux langues du guide et les descriptions Steam, puis lancer `tools/wiki_sync.py`.
- **Statut** : confirmé statiquement. **Priorité haute (coût nul), effort XS.**
- **Statut : corrigé (commit d03ee87), à vérifier en jeu** — guide EN/FR corrigé ; les `README.steam*` ne citent pas ce chiffre ; wiki GitHub à resynchroniser.

### C05 — Silence après 3 codes faux : clé de personnage, et commentaire qui parle de « nom du joueur »

- **Problème** : `failedCodes` est indexé par l'identifiant de **personnage** (`Trust.idFor`), alors que le commentaire de la table parle du nom du joueur. Un nouveau personnage repart donc sans silence ; un redémarrage du serveur aussi (ce second point est assumé dans l'en-tête).
- **Preuves** : `server/MilitaryDrop/MilitaryDrop_Server.lua:120` (commentaire), `:173`, `:193` (`local name = MilitaryDrop.Trust.idFor(player)`).
- **Risque** : faible sur un serveur entre amis (contournement coûteux : mourir). Surtout un écart doc/code qui trompera un futur diagnostic.
- **Correction** : corriger le commentaire (« identifiant de personnage → { day, count } »). Option, si l'utilisateur le souhaite : clé `getUsername()` pour le silence seulement (la perte de confiance reste par personnage). Ne pas ajouter de persistance (le commentaire d'en-tête explique pourquoi la ModData trahirait la fréquence).
- **Statut** : confirmé statiquement. **Priorité basse, effort XS.**

### C06 — Registres privés qui ne rétrécissent jamais : épaves et personnages morts

- **Problème** :
  - les sites d'épave (`privateState().wrecks`) sont créés à chaque crash et jamais retirés, même `complete` et sans fumée ; `Wreck.update` les parcourt tous à **chaque** `LoadChunk` et chaque minute de jeu ;
  - `characterTrust` garde une entrée par personnage créé (un nouveau personnage après chaque mort, `C:<uuid>`), parcourue chaque heure par `Trust.erode` quand l'érosion est active.
- **Preuves** : `server/MilitaryDrop/MilitaryDrop_Wreck.lua:17-21` (registre), `:298-306` (création), `:316-322` (parcours), `:338-339` (`LoadChunk` + `EveryOneMinute`) ; `server/MilitaryDrop/MilitaryDrop_Trust.lua:83-95` (`entry`), `:98-122` (`idFor`), `:492-514` (`erode`). À comparer avec `Trust.checkDrops` (`:424-450`), qui oublie bien les largages clos après `CLOSED_DROP_KEEP_HOURS`.
- **Risque** : croissance lente de la ModData privée sauvegardée (`global_mod_data.bin`) et du coût de `LoadChunk` sur un serveur qui tourne des mois. Faible à court terme (quelques crashs par semaine).
- **Correction** : marquer un site « clos » quand toutes ses étapes sont faites, la fumée finie et les pièces récupérées (ou après N jours), le sortir du registre parcouru (`wrecksClosed` compact : `id`, `x`, `y` pour la lecture d'enregistreur par site) ; pour la confiance, oublier une entrée à la note de départ, sans verrou et sans contact depuis 30 jours (elle se recrée à l'identique au prochain appel).
- **Statut** : confirmé statiquement (croissance) ; coût réel à mesurer en jeu. **Priorité basse, effort S.**

### C07 — Six copies de « joueurs connectés ou locaux »

- **Problème** : la même boucle `isServer() and getOnlinePlayers() or getSpecificPlayer(0..n)` est réécrite dans six modules serveur, avec de petites différences (morts filtrés ou non, `nil` filtré ou non).
- **Preuves** : `MilitaryDrop_Server.lua:607-625` (`findPlayer`), `MilitaryDrop_Decoy.lua:130-146`, `MilitaryDrop_Missions.lua:517-535` (`livePlayers`), `MilitaryDrop_Post.lua:581-602` (`listeners`), `MilitaryDrop_Teams.lua:445-458` (`members`), `MilitaryDrop_Zones.lua:377-388`.
- **Risque** : maintenabilité ; une correction (par exemple liste vide pendant une reconnexion, base `multiplayer.md`) devra être faite six fois.
- **Correction** : `MilitaryDrop.Net.players({ alive = true })` et `Net.findPlayer(username)` dans `MilitaryDrop_Net.lua`, avec un test `lupa` unique.
- **Statut** : confirmé statiquement. **Priorité basse, effort S.**

### C08 — Fenêtres géantes : `PostWindow` (2 591 lignes) et `RequisitionWindow` (2 341 lignes)

- **Problème** : deux fichiers client concentrent mise en page, état, rendu, navigation manette et logique d'affichage des réponses. `MilitaryDrop_Missions.lua` (1 240), `MilitaryDrop_Post.lua` (1 208) et `MilitaryDrop_Server.lua` (1 022) suivent.
- **Preuves** : `wc -l` du dossier `42.21/media/lua` (27 995 lignes au total).
- **Risque** : maintenabilité, conflits lors des modifications parallèles, temps de lecture d'un agent ou d'un contributeur.
- **Correction** : découper sans changer le comportement, par exemple `PostWindow` en `PostWindow_Layout`, `PostWindow_Affairs` (liste de gauche), `PostWindow_Detail`, `PostWindow_Log` ; `RequisitionWindow` en `Req_Lots`, `Req_Budget`, `Req_Sector`. Les tests `test_postwindow`/`test_requisitionwindow` servent de filet. À faire seulement à l'occasion d'une évolution de ces fenêtres.
- **Statut** : confirmé statiquement. **Priorité basse, effort M.**

### C09 — Commentaire dépassé : le rayon du nettoyage peut être dessiné sur la carte

- **Problème** : le commentaire affirme que l'API des symboles n'a « ni cercle ni échelle réglable » ; le symbole vanilla `Circle` agrandi par `setScale` couvre pourtant `20 × échelle` cases à tout zoom.
- **Preuves** : `client/MilitaryDrop/MilitaryDrop_Announce.lua:28-33` ; base `world-map.md`, « Tracer une zone (cercle) à l'échelle du monde avec un symbole » (2026-10-11, `WorldMapBaseSymbol.java:43, 210-219`, `MapSymbolDefinitions.addTexture`).
- **Risque** : aucun bug ; une amélioration joueur ratée (voir I07).
- **Correction** : corriger le commentaire ; implémentation éventuelle dans I07.
- **Statut** : confirmé statiquement (non testé en jeu dans la base). **Priorité basse, effort XS.**

### C10 — Repères de carte jamais retirés

- **Problème** : chaque annonce entendue ajoute un symbole (`Target`, `Eye`, `Skull`) sauvegardé comme une note du joueur ; aucun n'est retiré quand le largage est récupéré, échu ou la mission close. Après quelques semaines, la carte se couvre de cibles périmées.
- **Preuves** : `client/MilitaryDrop/MilitaryDrop_Announce.lua:10-12` (« sauvegardé comme une note du joueur, qui peut l'effacer »), `:151` (`addTexture`), aucun `removeSymbol` dans le fichier.
- **Risque** : confort de jeu ; confusion entre grilles anciennes et nouvelles.
- **Correction** : signer les symboles du mod par un alpha choisi (par exemple 0,8) et une couleur précise, puis retirer à la réception d'un message de clôture (`DropClosed { x, y }`, `MissionClosed { id }`) ou à l'expiration locale ; méthode décrite dans `world-map.md` (même entrée que C09, `removeSymbolByIndex` en indices décroissants). Option joueur (`PZAPI.ModOptions`) pour garder l'historique.
- **Statut** : confirmé statiquement. **Priorité moyenne, effort S.**

### C11 — Coordonnées exactes envoyées à tous les clients avant le filtrage par la radio

- **Problème** : `DropAnnounce { x, y }`, `ReconAnnounce`, `CleanupAnnounce` et `FlightStart` (cible du vol) partent à toutes les connexions ; seul le client décide d'afficher le repère s'il entend la ligne. Le vol en cours (`flights`, avec sa cible) est aussi dans la ModData publique « MilitaryDrop ».
- **Preuves** : `server/MilitaryDrop/MilitaryDrop_Broadcast.lua:200, 229, 254, 262` ; `server/MilitaryDrop/MilitaryDrop_Flights.lua:225, 231, 343, 374` ; constat déjà noté dans `docs/annexes/recherches/idee-03-balises.md` §1 (« Secret à protéger »).
- **Risque** : un client modifié connaît la grille sans radio. Sur un serveur entre amis, **ne pas corriger au prix du jeu** (préférence de l'utilisateur) ; à garder en tête seulement si un serveur PvP public le demande.
- **Correction (si demandée)** : n'envoyer `DropAnnounce` qu'aux joueurs dont une radio reçoit la chaîne (le serveur connaît la radio tenue ou posée), et retirer la cible de `FlightStart` (le client n'a besoin que de la trajectoire visible).
- **Statut** : confirmé statiquement. **Priorité basse, effort M.**

### C12 — Livraison en attente sans fin si aucune case ne convient

- **Problème** : une livraison en attente est retentée à chaque `LoadChunk` et chaque minute tant que sa case est chargée, sans limite ni échéance ; le dossier de largage correspondant n'a pas d'échéance (`deadline` posée seulement par `Trust.onDropDelivered`) et n'est jamais oublié.
- **Preuves** : `server/MilitaryDrop/MilitaryDrop_Flights.lua:110-150` ; `server/MilitaryDrop/MilitaryDrop_Trust.lua:295-310` et `:424-450` (oubli seulement après `outcome`) ; `MilitaryDrop_Server.lua:654-657` (« no ground near … yet: delivery waits »).
- **Risque** : faible (la proximité vise une route ou un bâtiment, la zone a un second passage `findLandingInBounds`) ; cas d'une zone mal dessinée entièrement sur l'eau ou couverte de véhicules : ligne de journal répétée et dossier éternel.
- **Correction** : compter les essais et, après N essais sur case chargée (ou N jours), livrer au sol sur la case sèche la plus proche sans borne de zone, ou clore le dossier `expired` avec une ligne `WARN` pour l'admin.
- **Statut** : confirmé statiquement ; occurrence à vérifier en jeu. **Priorité basse, effort S.**

### C13 — Campagne de tests MP en retard sur le code publié

- **Problème** : la plupart des lots publiés sont « testé hors jeu » ou « testé solo, MP à faire » (v1.0, v1.2, v1.3, v1.4, v1.5, idées 8, 11 et 12), alors que le mod se présente comme multijoueur et serveur-autoritaire.
- **Preuves** : `docs/annexes/plans/SUIVI.md`, tableau « Vue d'ensemble » ; `docs/annexes/tests/test-protocol.md` (protocoles M1-M8, Z13-Z14…).
- **Risque** : bugs MP découverts par les joueurs (historique : 0.3.3, 0.4.2, 0.4.3 ont corrigé des clés brutes et des états périmés propres au MP).
- **Correction** : outiller les parcours nominaux avec `pz-autotest` (`--mp`, serveur dédié + 2 clients) : appel, annonce entendue par l'un seulement, ouverture de caisse par l'autre (confiance), Fulton, crash et récupération ; la règle de l'utilisateur fait d'une suite MP automatisée verte la preuve « testé MP ».
- **Statut** : **outillé (commit dedd363) : parcours nominal `pz-autotest` sp/mp (`autotest.json`, `autotest/md_hooks.lua`), suites non lancées, à vérifier en jeu.** Reste : second client qui écoute, ouverture par un autre joueur, Fulton complet, crash. **Priorité haute, effort M.**

### C14 — `Post.onLoadChunk` relit chaque poste à chaque chunk chargé

- **Problème** : à chaque `LoadChunk`, le serveur interroge `getGridSquare` pour **tous** les postes de toutes les équipes, puis compare le chunk. Sur un serveur dédié, des dizaines de chunks se chargent par seconde quand des joueurs roulent.
- **Preuves** : `server/MilitaryDrop/MilitaryDrop_Post.lua:707-721`.
- **Risque** : faible (un poste par équipe) ; à surveiller si les équipes se multiplient.
- **Correction** : indexer les postes par clé de chunk (`floor(x / 8)`, `floor(y / 8)`, z) et ne lire que l'entrée du chunk chargé (`chunk:getWx()`, `getWy()`).
- **Statut** : confirmé statiquement ; coût à mesurer. **Priorité basse, effort XS.**

---

## Partie 2 — Idées de fonctionnalités

Rappels : les idées déjà analysées ne sont pas reproposées à l'identique.
- Idée 3 (balises, détecteur, chasses au trésor) : `docs/annexes/recherches/idee-03-balises.md`, **mise de côté** (BAL-01 à BAL-03).
- Idée 8 (Mayday, épave démontable) : `idee-08-mayday.md`, codée.
- Idée 10 (extraction du personnage, pont Opération Artemis) : `idee-10-extraction.md`, **à décider** (EXT-01).
- Idées 11 et 12 (zones de largage, Fulton) : codées et publiées.

Chaque effet proposé a une cause visible dans le monde et s'appuie de préférence sur une mécanique vanilla.

### I01 — Horde attirée par le bruit plutôt qu'apparue autour de la caisse

- **Description** : option `HordeMode` : « Apparition » (actuel) ou « Bruit ». En mode bruit, l'atterrissage de la caisse (choc, rotor en vol stationnaire) émet un vrai bruit vanilla qui attire les zombies **déjà présents**, plus quelques zombies apparus hors de vue seulement si la zone est vide.
- **Intérêt joueur** : la horde a une cause lisible (le bruit), le joueur voit les zombies converger et peut anticiper ; plus de zombies « sortis de nulle part » à côté de lui.
- **Faisabilité** : `getWorldSoundManager():addSound(nil, x, y, 0, rayon, volume)` (source `nil`, sinon les zombies ignorent un bruit dont la source est un zombie) ; base `staging-effects.md` « attirer des zombies avec un bruit » (étage × 3, 16 mises à jour, zombies virtuels sourds sous un rayon de 50) et `sounds-and-noise.md` (formule d'attrait). Le leurre fait déjà la même chose avec `addSoundRepeating` (`MilitaryDrop_Decoy.lua:234`).
- **Impact MP** : bruit posé par le serveur seulement ; aucun paquet nouveau.
- **Dépendances** : C01 (aide commune d'apparition) pour le complément hors de vue.
- **Effort** : S.

### I02 — Bruit du rotor le long de la trajectoire

- **Description** : l'hélicoptère de ravitaillement attire les zombies sous sa route, comme l'hélicoptère vanilla, avec une option de force (0 = aucun).
- **Intérêt joueur** : un largage coûte quelque chose à tout le quartier survolé ; les autres stations repèrent l'appareil et ses conséquences.
- **Faisabilité** : bruit serveur périodique (`addSound` toutes les 2-3 s à la position calculée par `Flight.position`), comme la sirène de véhicule (`staging-effects.md`) ; rayon borné pour ne pas vider les villes.
- **Impact MP** : serveur seulement ; coût d'un `addSound` toutes les quelques secondes par vol.
- **Dépendances** : aucune.
- **Effort** : S.

### I03 — Caisse visible pendant la descente sous parachute

- **Description** : quelques secondes avant la pose, chaque client dessine la caisse qui descend sous un parachute à l'aplomb du point, puis le véhicule-caisse apparaît au sol.
- **Intérêt joueur** : le moment le plus attendu devient visible ; on repère la caisse de loin sans la carte.
- **Faisabilité** : même technique que le ballon Fulton (rendu local mobile `Render3DItem` à hauteur flottante, base `staging-effects.md` ; `docs/annexes/recherches/idee-12-fulton-rendu.md`) ; modèle de parachute à créer (skill `pz-blender-assets`) ou réutiliser la bâche/ballon. Uniquement visuel : le serveur garde l'heure de pose.
- **Impact MP** : aucun paquet nouveau (le client connaît déjà le vol et son point de largage par `FlightStart`).
- **Dépendances** : refonte C03 (module de rendu commun au Fulton).
- **Effort** : M.

### I04 — Silhouette 3D de l'hélicoptère en vol

- **Description** : remplacer l'ombre seule par un modèle 3D simplifié (réutiliser le maillage de l'épave du Mayday en version intacte) rendu localement au-dessus des toits.
- **Intérêt joueur** : spectaculaire et cohérent avec l'épave ; aide à suivre la trajectoire.
- **Faisabilité** : à vérifier (hypothèse) ; le rendu à grande hauteur peut être coupé par la caméra isométrique. Commencer par un essai avec la technique du Fulton. Aujourd'hui : ombre `circle_shadow`, son et flèche (`client/MilitaryDrop/MilitaryDrop_Heli.lua:5-13`).
- **Impact MP** : aucun.
- **Dépendances** : I03, C03.
- **Effort** : L.

### I05 — Panne de relais radio : mission « Remettre le relais en service »

- **Description** : de temps en temps (orage, coupure du réseau électrique), la base annonce une **panne du relais** (station relais vanilla de Knox, voir `knox-geography.md`). Tant qu'il n'est pas réparé, les appels ont une portée réduite ou ne passent plus. Mission publique : aller au relais, faire tourner un générateur (carburant vanilla) et réparer l'émetteur avec des composants électroniques (`ElectronicsScrap`), comme la réparation vanilla d'un générateur.
- **Intérêt joueur** : objectif concret dans un lieu réel, conséquence directe sur le mod, travail d'équipe en MP.
- **Faisabilité** : générateur posé par script et lecture de son état (`power-and-lights.md` : `isActivated`, carburant, `getRoom():getLightSwitches()`), coupure du réseau sondée par `doesPowerGridExist` (même fichier) ; cause du début : orage (`getIsThunderStorming`) ou coupure du réseau, jamais un tirage invisible.
- **Impact MP** : état serveur ; annonce sur la chaîne existante ; réparation validée par le serveur (distance, objets retirés).
- **Dépendances** : missions existantes (SRC-03 à SRC-05).
- **Effort** : M-L.

### I06 — Largage retardé par la météo

- **Description** : la base refuse ou retarde un largage pendant un orage, un blizzard ou un brouillard épais, en le disant (« Plafond trop bas, nouvelle tentative dans 2 heures »), et le relance automatiquement à l'éclaircie.
- **Intérêt joueur** : la météo vanilla prend du sens ; la contrepartie du risque de crash par orage (déjà simulé, `Flight` + `getIsThunderStorming`) devient un choix (« forcer quand même » = risque de crash accru).
- **Faisabilité** : lecture serveur de la météo (`api-42-21.md` : orage, tempête tropicale, blizzard via `WeatherPeriod` ; brouillard dépendant du réglage graphique côté client : ne lire que les données serveur).
- **Impact MP** : serveur seulement ; une réponse de plus dans `Exchange`.
- **Dépendances** : aucune.
- **Effort** : S.

### I07 — Zone du nettoyage tracée sur la carte, et repères qui s'effacent

- **Description** : le nettoyage dessine un cercle à son rayon réel ; les repères de largage récupéré, échu ou de mission close disparaissent (ou passent en gris) chez qui les avait.
- **Intérêt joueur** : carte lisible, plus de navigation à l'aveugle autour du crâne.
- **Faisabilité** : C09 et C10 (symbole `Circle` mis à l'échelle, signature par alpha).
- **Impact MP** : un message de clôture à tous (sans coordonnées nouvelles).
- **Dépendances** : C09, C10.
- **Effort** : S.

### I08 — Noter une grille dans un carnet vanilla

- **Description** : comme « Noter le message » de la station de chiffres, un bouton de la section Logistique écrit la dernière grille entendue (et l'heure) dans un carnet ou une feuille tenus, avec un crayon ou un stylo.
- **Intérêt joueur** : garder une trace sans carte, la donner à un coéquipier, jouer « à l'ancienne » ; utile aux illettrés de la carte (symboles sans texte).
- **Faisabilité** : écriture de page de document vanilla (`quest-building-blocks.md` : `addPage`, 15 lignes par page ; tags de stylo dans `clothing-and-character-state.md`).
- **Impact MP** : écriture faite par le serveur sur l'objet de l'inventaire, `syncItemFields`.
- **Dépendances** : aucune.
- **Effort** : S.

### I09 — Primes Fulton de la semaine

- **Description** : la base diffuse chaque lundi (même horloge que le code) une courte liste de **besoins** : catégorie d'objets parmi le barème Fulton (pièces d'identité, cartes-cachettes, matériel NRBC, échantillons Zombie Virus Vaccine) avec un bonus temporaire. Les postes de liaison l'affichent.
- **Intérêt joueur** : objectif hebdomadaire, raison de fouiller des lieux précis (commissariats, hôpitaux, bases militaires).
- **Faisabilité** : barème déjà par catégorie (FULTON-08) ; diffusion sur la chaîne militaire ; aucun nouvel objet.
- **Impact MP** : état serveur, une ligne de la console du poste.
- **Dépendances** : Fulton.
- **Effort** : S.

### I10 — Signaler une horde à la base

- **Description** : nouvel échange « Signaler une concentration » : le joueur, à moins de N cases d'un groupe de zombies, le signale ; le serveur compte les zombies réels autour de lui et crédite un petit gain plafonné si le seuil est atteint. La base peut en tirer une mission de nettoyage à cet endroit.
- **Intérêt joueur** : la reconnaissance devient active ; lien naturel avec les missions existantes.
- **Faisabilité** : comptage serveur dans `getCell():getZombieList()` autour de la position du joueur (zone chargée autour de lui), cadence par `Guard` ; aucun texte libre à interpréter.
- **Impact MP** : validation serveur complète (position, distance, cadence) ; pas de position fournie par le client.
- **Dépendances** : `Missions` (SRC-04).
- **Effort** : S-M.

### I11 — Citation officielle au changement de palier

- **Description** : quand un personnage franchit un palier de confiance vers le haut, le prochain largage contient une lettre de félicitations du commandement (document `printMedia` du mod, au nom du personnage) et, au palier IV, un insigne cosmétique vanilla ou une plaque nominative « honoraire ».
- **Intérêt joueur** : la progression invisible (aucun chiffre affiché) devient tangible et racontable.
- **Faisabilité** : `MilitaryDrop_Documents.lua` et `MilitaryDrop_PrintMedia.lua` savent déjà composer des documents ; ajout au contenu de la caisse (`Crate.contentsFor`). Cause : la caisse elle-même.
- **Impact MP** : document composé côté client (paramètres envoyés, base `api-42-21.md` sur `printMedia` paramétré).
- **Dépendances** : aucune.
- **Effort** : S.

### I12 — Tableau de bord admin en jeu

- **Description** : un onglet dans la fenêtre « Zones de largage » (même capacité d'admin) liste les largages ouverts, vols, épaves, missions, et la confiance des personnages connectés, avec quelques actions (lever une ligne coupée, clore un largage bloqué, relancer une annonce).
- **Intérêt joueur** : pour l'admin, diagnostic sans console serveur (aujourd'hui `Trust.debugPrint`, `MilitaryDrop_Trust.lua:528`).
- **Faisabilité** : réutilise la fenêtre et la vérification de capacité de ZONE-03 ; données envoyées à l'admin seulement.
- **Impact MP** : commande admin revérifiée (`checkPermissions` + `getRole():hasCapability`, base `multiplayer.md`).
- **Dépendances** : C12 (action « clore »).
- **Effort** : M.

### I13 — Accusé de réception de caisse

- **Description** : après avoir ouvert sa caisse, le demandeur peut « Confirmer la réception » à la radio : petit gain (dans le plafond) et la base cesse aussitôt les rappels pour tous.
- **Intérêt joueur** : boucle radio complète (appel, livraison, confirmation), satisfaction de « clore » l'opération.
- **Faisabilité** : `Trust.markCollected` existe ; l'ouverture est déjà connue du serveur (`Trust.onCaseOpened`).
- **Impact MP** : aucun risque nouveau ; la confirmation n'est acceptée que si l'ouverture a eu lieu.
- **Dépendances** : aucune.
- **Effort** : XS.

### I14 — Raréfaction progressive des moyens de la base

- **Description** : option : au fil des mois de jeu, la base annonce des restrictions (délai plus long, budget de réquisition réduit, lots retirés) puis, éventuellement, un dernier pont aérien. Chaque palier est annoncé à la radio et sur les mémos trouvés.
- **Intérêt joueur** : arc narratif sur la durée, cohérent avec l'effondrement vanilla (coupures d'eau et d'électricité).
- **Faisabilité** : lecture de l'âge du monde (`getWorldAgeDaysSinceBegin`) et de la coupure d'électricité ou d'eau (`power-and-lights.md`) comme déclencheurs ; paliers dans `Lots` et `CooldownHours`.
- **Impact MP** : serveur seulement.
- **Dépendances** : aucune.
- **Effort** : S.

### I15 — Brouilleur radio (PvP, facultatif)

- **Description** : une radio posée, alimentée et réglée sur la fréquence militaire peut être mise en mode « brouillage » par une recette d'électronique ; les annonces de grille ne sont plus entendues dans un rayon autour d'elle, et la base signale « interférences dans le secteur X ».
- **Intérêt joueur** : contre-jeu pour les serveurs PvP qui ont demandé les zones (idée 11) ; objet visible et destructible.
- **Faisabilité** : dépend de C11 (filtrage serveur des annonces par auditeur) ; radio posée lue par le serveur (`power-and-lights.md`, `IsoRadio`/`IsoWaveSignal`).
- **Impact MP** : fort (logique d'écoute côté serveur).
- **Dépendances** : C11.
- **Effort** : M-L.

### I16 — Commande d'un objet précis contre un gros coût

- **Description** : dans le formulaire, un lot « Demande spéciale » au palier IV : le joueur choisit **une catégorie fine** (par exemple antibiotiques, munitions d'une arme qu'il porte) au lieu d'un tirage, pour un coût élevé.
- **Intérêt joueur** : la confiance maximale sert enfin à quelque chose de ciblé.
- **Faisabilité** : `Lots` tire déjà par catégorie, tag et propriété (« aucun nom d'objet vanilla ») ; munitions de l'arme tenue par `getAmmoType` (base `api-42-21.md`).
- **Impact MP** : le serveur relit l'arme dans l'inventaire serveur.
- **Dépendances** : `requisition.txt` (nouvelle forme de lot, rétrocompatible).
- **Effort** : M.

### I17 — Partage d'un largage avec une autre station

- **Description** : « Ouvrir le largage à la station Kilo-7 » : la récupération par cette station compte comme une récupération par la faction (+5 au demandeur au lieu de −5).
- **Intérêt joueur** : coopération entre groupes sans fusionner les factions.
- **Faisabilité** : `recoveryFaction` existe déjà dans le dossier (`MilitaryDrop_Trust.lua:276`, `:413-415`) ; il suffit d'une liste de stations autorisées.
- **Impact MP** : noms de faction instables (base `multiplayer.md` : faction sans identifiant stable) : stocker l'indicatif de station du mod, pas le nom de faction.
- **Dépendances** : aucune.
- **Effort** : S.

### I18 — Ravitaillement du poste de liaison

- **Description** : une équipe dont le poste est installé peut demander une « livraison au poste » (petite caisse, moins de contenu, horde moindre) qui tombe à proximité de son poste plutôt qu'à 150-400 cases, contre plus de confiance.
- **Intérêt joueur** : valorise l'installation du poste et la base fortifiée ; alternative moins risquée et plus chère.
- **Faisabilité** : position du poste connue du serveur (`Post`) ; même chaîne de livraison avec un autre centre. En mode zones (idée 11), refuser ou ignorer (les admins PvP veulent des zones disputées).
- **Impact MP** : serveur seulement ; l'annonce publique reste (cause : la radio).
- **Dépendances** : `DropPlacement`.
- **Effort** : S.

### I19 — Pilote survivant blessé (variante du Mayday)

- **Description** : avec une faible probabilité, l'un des pilotes du crash n'est pas un zombie mais un **cadavre récent** porteur d'un journal de bord écrit (dernier message, position d'un second objectif) ; la base paie la remise de ses plaques et du journal.
- **Intérêt joueur** : variation narrative du Mayday sans PNJ (impossibles proprement en 42.21).
- **Faisabilité** : cadavre en tenue nommée (`world-placement.md` : `createRandomDeadBody`, tenue des deux sexes), document écrit (`quest-building-blocks.md`), plaque nommée d'après le mort (`api-42-21.md`).
- **Impact MP** : objet ajouté au cadavre côté serveur (`sendAddItemToContainer`, `world-placement.md`).
- **Dépendances** : idée 8.
- **Effort** : S-M.

### I20 — Fumée ou fusée fournies dans la caisse pour marquer une future zone

- **Description** : une caisse peut contenir un fumigène de signalisation ; s'il est allumé dehors pendant l'approche d'un **prochain** largage, la base vise ce point (dans les bornes de distance et de zone autorisées).
- **Intérêt joueur** : geste naturel (allumer un fumigène) au lieu d'un menu ; contrôle partiel du point de chute.
- **Faisabilité** : Signal Smoke (mod de l'utilisateur, prérequis depuis le 2026-10-21, déjà intégré pour marquer la caisse) ; détection serveur de la grenade (`OnThrowableExplode`, base `staging-effects.md`) ; repli : fusée vanilla absente, donc fonction facultative.
- **Impact MP** : position lue par le serveur (objet lancé), pas fournie par le client.
- **Dépendances** : Signal Smoke (prérequis) ; respect de `DropPlacement` (en mode zones, seulement à l'intérieur d'une zone).
- **Effort** : M.

---

## Partie 3 — Priorisation

Les cinq actions les plus rentables (gain pour les joueurs ou la fiabilité, rapporté à l'effort) :

1. **C04** — corriger « +8/jour » dans le guide et les descriptions Steam (XS, information joueur fausse).
2. **C01** — aide commune d'apparition des zombies hors de l'eau (S, hordes complètes près des rives, journal propre ; prépare I01).
3. **C13** — suite MP automatisée des parcours nominaux avec `pz-autotest` (M, la plupart des lots publiés ne sont pas « testé MP »).
4. **C10 + I07** — repères de carte qui s'effacent et cercle du nettoyage (S, gain de lisibilité immédiat pour tous les joueurs).
5. **I01** — horde attirée par le bruit en option (S, une cause visible à l'effet le plus artificiel du mod, mécanique vanilla).

Ensuite : C03 (renommer le « prototype » Fulton, couper le bruit de console), C02 (retirer la copie de secours si la dépendance obligatoire est définitive), I06 et I13 (petits efforts, boucle radio plus riche).

---

*Document de proposition : aucune de ces améliorations ni fonctionnalités n'est implémentée. Chacune attend la validation explicite de l'utilisateur avant tout code, et les idées retenues entreront dans `docs/annexes/plans/SUIVI.md` avec leur identifiant.*
