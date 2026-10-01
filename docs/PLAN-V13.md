# Military Drop v1.3 — confiance de faction, sources, missions, poste de commandement

Spécification d'implémentation, rédigée le 2026-09-30. Conception d'origine : [PLAN-V2.md](PLAN-V2.md) §5 et décision 7 ; état de chaque élément : [SUIVI.md](SUIVI.md). Ce document fait foi en cas d'écart avec PLAN-V2.

## Décisions de l'utilisateur (2026-09-30, v1.3)

- La v1.3 est livrée **d'un seul bloc**, développée par des sous-agents.
- **AUTH-01 sans objet** : le code de la semaine ne sert **qu'aux largages**. Rapports, plaques, missions et poste se font sans code, sur la fréquence militaire.
- **AUTH-02 abandonné** : le joueur règle et allume sa radio lui-même.
- **AUTH-03** : si le talkie est à la ceinture ou sur le dos, le personnage **le prend en main** pour émettre (action vanilla), puis le garde en main. Raison technique : en MP, le serveur n'applique l'état d'une radio d'inventaire que si elle est **en main** (`GameServer.java:3499-3519`). Cela corrige aussi l'appel de largage en MP (APPEL-01).
- **SRC-05** : l'appel de contrôle récompense **toutes les factions** qui répondent dans les 4 h, une fois chacune.
- **SRC-06 reporté** après la v1.3 (nouveaux documents avec l'idée 8). SRC-07 et SRC-08 restent liés aux idées 3 et 8 : hors v1.3.

## Règles communes

Celles de PLAN-V2 (« Règles communes ») s'appliquent : le serveur décide de tout, le client n'est jamais cru, solo = appel direct (`MilitaryDrop.Net`), aucun nom d'objet vanilla, une seule globale `MilitaryDrop`, pas de `next`, garde `if isClient() then return end` en tête des fichiers serveur, textes de la base dans la langue du serveur, chaque effet a une cause dans le monde, tests `lupa` pour chaque règle du serveur, `python tests/run_tests.py` au vert.

Données : *révisé le 2026-10-01 après relecture* : la ModData publique « MilitaryDrop » est lisible par tout client et révélait la position des postes (qu'un client peut alors éteindre à distance, `GameServer.java:3480-3498`) et des indices sur la fréquence. Tout l'état de la v1.3 (`teams`, `trust`, `drops`, `missions`, `posts`, journaux, plaques déposées) va dans une table **privée** dont le nom dérive de la graine secrète (`Secrets.privateState()`), jamais transmise. La fréquence militaire est tirée au hasard par défaut (décision 23 de PLAN-V2). Aucune donnée n'est envoyée à un client qui n'en a pas besoin (journal et missions d'une faction : à ses seuls membres).

Heures : `getGameTime():getWorldAgeHours()` pour les délais et échéances ; jour calendaire `math.floor(MilitaryDrop.Server.clock() / 24)` pour « une fois par jour ».

## Équipe et indicatif (module A : `server/MilitaryDrop/MilitaryDrop_Teams.lua`)

- **Équipe** = faction vanilla, ou le joueur seul sans faction, ou le joueur en solo (pas de factions en solo). Identifiant stable `teamId` (chaîne) attribué par le serveur et mémorisé dans `state.teams[teamId] = { callsign, name, owner, members = {username = true}, faction = true|false, dissolved = false }`.
- Membres d'une faction : `{f:getOwner()} ∪ f:getPlayers()` (`getPlayers` n'inclut pas le propriétaire). Aucun événement serveur : sondage de `Faction.getFactions()` (toutes les 10 minutes de jeu et avant chaque décision).
- Rattachement d'une faction vivante à un `teamId` existant, dans l'ordre : même propriétaire ; sinon recouvrement majoritaire des membres (Jaccard ≥ 0,5) ; sinon même nom s'il est unique ; sinon nouvel identifiant. Mettre à jour nom et membres ensuite.
- **Indicatif** : « Station » + mot OTAN + « - » + nombre (ex. « Station Kilo-7 »), unique, tiré à la création.
- Mouvements (CONF-03) : un joueur qui quitte sa faction (ou dont la faction est dissoute) repart en équipe individuelle avec la note de l'ancienne faction **plafonnée à 50**, et une ligne coupée le suit ; un joueur qui rejoint une faction adopte sa note ; une faction nouvelle part de la **plus basse note de ses fondateurs**.
- API : `Teams.idFor(player)` → teamId (crée ou rattache) ; `Teams.callsign(teamId)` ; `Teams.members(teamId)` → liste de noms ; `Teams.refresh()` ; `Teams.isMember(teamId, username)`.

## Confiance (module A : `server/MilitaryDrop/MilitaryDrop_Trust.lua`)

- `state.trust[teamId] = { value = 0..100 (départ 50), lockedUntil (heures), day, dayGain, lastCallHours }`.
- `Trust.get(teamId)`, `Trust.add(teamId, amount, source, opts)` : `source` = "drop" (hors plafond) ou une source (`report`, `dogtag`, `recon`, `cleanup`, `control`), soumise au **plafond quotidien** (option, +8) ; `opts.fromPost` applique le **bonus du poste** (option, +50 %, arrondi, dans le plafond). Borné 0-100. Passage sous 15 → **ligne coupée** 3 jours de jeu (option).
- Largages (CONF-04, par équipe du demandeur au moment de l'appel) :
  - chaque largage reçoit un `dropId` ; `state.drops[dropId] = { team, requester, deliveredHours, deadline, outcome }` ; les caisses de ravitaillement créées (coffre ou repli au sol) portent `dropId` en ModData (`MilitaryDrop_dropId`) ;
  - première caisse ouverte (`Recipe.openSupplyCase`, serveur) par un membre de l'équipe du demandeur → **+10**, une fois ; par une autre équipe d'abord → **−5** au demandeur, largage clos ; rien d'ouvert **48 h** (option) après la pose → **−10**.
- Code faux répété (CONF-06) : 3 codes faux dans l'heure de jeu → **−2**, une fois par heure (en plus du silence de la journée, CODE-06).
- Érosion (CONF-07, option, désactivée par défaut) : vers 50, d'un point par jour sans échange.
- Effets (CONF-05) : délai global du largage × facteur de l'équipe qui appelle (linéaire : 0 → ×1,5, 50 → ×1, 100 → ×0,6) ; ligne coupée → statut `lineCut`, révélé seulement après un canal et un code justes (comme `cooldown`) ; réponses de la base choisies par palier (`<25`, `<50`, `<75`, `≥75`) : jamais de chiffre affiché.
- Console debug : `MilitaryDrop.Trust.debugPrint()` (admin).

## Sources et missions (module B : `server/MilitaryDrop/MilitaryDrop_Missions.lua`, `shared/MilitaryDrop/MilitaryDrop_Exchange.lua`, `client/MilitaryDrop/MilitaryDrop_ExchangeMenu.lua`)

Tous les échanges passent par une radio militaire sur la fréquence militaire, en main (talkie pris en main si besoin, AUTH-03) ou posée à 2 cases (ou le poste, module C). Le serveur revérifie la radio (`Radio.resolve` + `Radio.status`), l'équipe, l'échéance, et répond par une ligne radio privée au joueur (et au journal du poste).

- **SRC-01 Rapport de situation** : +1 par jour calendaire et par équipe.
- **SRC-02 Plaques d'identité** (*révisé le 2026-10-01 après le test solo*) : les plaques **vanilla** (tag `base:dogtag`), que le jeu renomme au nom du soldat à la mort d'un zombie. Transmissible : plaque renommée, qui n'est pas celle du joueur, ni portée ni en main. Clé d'unicité : l'identifiant de l'objet, registre dans l'état privé ; plaque consommée, +2 ; la base lit les noms. L'objet du mod `MilitaryDrop.DogTag` et l'option `DogTagDropRate` sont retirés (doublon avec la plaque vanilla).
- **SRC-03 Reconnaissance** (publique, première équipe) : diffusion « à toutes les stations » d'une grille X/Y (point tiré comme `Server.pickDropPoint`, autour d'un joueur connecté au hasard) ; échéance 48 h ; « Confirmer la reconnaissance » à 25 cases au plus du point → +3 à la première équipe, annonce de clôture.
- **SRC-04 Nettoyage** (publique, première équipe au quota) : zone (centre, rayon 40) et quota (option, 30) ; `OnZombieDead` côté serveur, zombie dans la zone, tueur `zombie:getAttackedBy()` s'il est un `IsoPlayer` (feu et pièges non attribués), équipe figée à la mort, un zombie compté une fois ; première équipe au quota avant 72 h → +5, annonce de clôture.
- **SRC-05 Appel de contrôle** : « toutes stations, confirmez réception » ; « Confirmer réception » dans les 4 h → +1 à chaque équipe, une fois.
- Planification : une mission de chaque type au plus à la fois ; nouvelle mission tirée à intervalle réglable (options) quand la précédente est close ; annonces sur la chaîne militaire (`MilitaryDrop.Broadcast.air`), textes du serveur.
- Chaque source : gain en option (0 = désactivée).

## Poste de commandement (module C : `server/MilitaryDrop/MilitaryDrop_Post.lua`, `client/MilitaryDrop/MilitaryDrop_PostWindow.lua`)

- Poste = radio **posée** (`IsoWaveSignal`) **non portable, haut de gamme, capable d'émettre** (propriétés `DeviceData` : `getIsPortable() == false`, `getIsHighTier()`, `getIsTwoWay()`), aucun nom d'objet. « Installer le poste de liaison » (menu contextuel, membre de l'équipe) : **un poste actif par équipe**, enregistré par le serveur `state.posts[teamId] = { x, y, z, uid, snapshot }` ; installer ailleurs déplace le poste ; ramasser ou détruire la radio le désinstalle (constaté au chargement de la case ou à l'usage). Les données (journal, missions) sont à l'équipe, pas à l'objet.
- **Journal** (POSTE-05) : toute ligne que la base adresse à l'équipe ou à toutes les stations est ajoutée au journal de l'équipe **si le poste la reçoit** : chargé → état réel (allumé, canal militaire, `canBePoweredHere`, pile > 0) ; déchargé → dernier instantané (allumé, canal) et source : secteur → réseau global actuel, générateur → carburant projeté > 0, pile → charge figée. Sinon, une ligne « aucune réception » (regroupée) marque le trou. Borne : 200 lignes par équipe.
- **Console « Poste de liaison »** (POSTE-04, maquette « solution 4 ») : fenêtre client ouverte par le menu contextuel du poste, pour les membres de l'équipe : journal, missions en cours (échéances, progression du nettoyage), **plaques à annoncer** (déposées par les membres, puis annoncées à la radio d'un bouton « Annoncer les matricules » ; pas de notion de courrier, 2026-10-01). Données demandées au serveur (`PostOpen`), jamais celles d'une autre équipe. Largeurs mesurées selon la langue, focus manette.
- **Bonus** (POSTE-06) : échanges faits depuis le poste → `opts.fromPost` (+50 % en option).
- Un joueur d'une autre équipe ne peut ni installer sur un poste existant ni l'utiliser.

## Intégration (coordinateur)

- `Server.onClientCommand` devient un aiguillage `Server.COMMANDS[nom] = function(player, args)` : chaque module inscrit ses commandes dans son propre fichier.
- Options sandbox, traductions EN/FR, `SUIVI.md`, protocole de test et pages de présentation : fusionnés par le coordinateur à partir des rapports des sous-agents.

## Corrections après le test solo (2026-10-01)

- Talkie à la ceinture (RADIO-04) : réglage, reste allumé, écoute des messages du mod en solo ; les autres chaînes restent vanilla.
- Repère de carte de la reconnaissance (RADIO-05).
- Console du poste au style « poste radio militaire » (POSTE-04).
- Démontage de la caisse vide selon les règles vanilla du bois (BUTIN-05).
