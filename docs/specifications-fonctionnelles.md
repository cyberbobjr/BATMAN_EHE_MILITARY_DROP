# Spécifications fonctionnelles de Military Drop

Ce que fait le mod du point de vue du joueur et de l'administrateur, version 0.5.4, Build 42.21, solo et multijoueur. Les guides détaillés, avec captures, sont dans le [wiki](wiki/fr/Home.md) ; les contrats techniques (commandes, données, valeurs des options) dans [specifications-techniques.md](specifications-techniques.md). L'état de chaque élément (codé, testé, publié) est suivi dans [annexes/plans/SUIVI.md](annexes/plans/SUIVI.md) ; la colonne « Suivi » renvoie à ses familles d'identifiants.

Règles communes : le serveur décide de tout et revérifie chaque action ; aucun chiffre de confiance n'est affiché au joueur ; aucun objet vanilla n'est nommé dans le code, le contenu vient des tables de butin du jeu et des mods actifs.

## Liste des fonctionnalités

| Id | Fonctionnalité | Suivi | Guide |
|---|---|---|---|
| F01 | Fréquence militaire et chaîne « Logistique » | RADIO | [Appeler un largage](wiki/fr/02-calling-a-drop.md) |
| F02 | Code d'authentification, notes, carnet et station de chiffres | CODE, NOTE, DOC, AUTH | [Appeler un largage](wiki/fr/02-calling-a-drop.md) |
| F03 | Appel de largage depuis la section « Logistique » de la radio | APPEL, RADIO-06 | [Appeler un largage](wiki/fr/02-calling-a-drop.md) |
| F04 | Formulaire de réquisition | REQ | [Formulaire de réquisition](wiki/fr/03-requisition-form.md) |
| F05 | Vol de l'hélicoptère, annonce de la grille et repère de carte | HELI, DROP, RADIO-02 | [Appeler un largage](wiki/fr/02-calling-a-drop.md) |
| F06 | Caisse de largage, horde, caisses de ravitaillement, démontage | CAISSE, BUTIN, FUM | [Appeler un largage](wiki/fr/02-calling-a-drop.md) |
| F07 | Largage leurre à sirène | LEURRE | [Formulaire de réquisition](wiki/fr/03-requisition-form.md) |
| F08 | Réputation personnelle et équipes | CONF | [Confiance et missions](wiki/fr/04-trust-and-missions.md) |
| F09 | Sources de confiance et missions publiques | SRC | [Confiance et missions](wiki/fr/04-trust-and-missions.md) |
| F10 | Poste de liaison | POSTE | [Poste de liaison](wiki/fr/05-liaison-post.md) |
| F11 | Talkie-walkie à la ceinture | RADIO-04, RADIO-08 | [Démarrer](wiki/fr/01-getting-started.md) |
| F12 | Zones de largage des serveurs PvP | ZONE | [Administration](wiki/fr/06-server-admin.md) |
| F13 | Extraction Fulton | FULTON | [Extraction Fulton](wiki/fr/07-fulton.md) |
| F14 | Hélicoptère abattu (Mayday), épave et enregistreur de vol | MAY | [Hélicoptère abattu](wiki/fr/09-helicopter-crash.md) |
| F15 | Outils d'administration | APPEL-05, MAY-04, ZONE-03 | [Administration](wiki/fr/06-server-admin.md) |
| F16 | Options du bac à sable et changements en cours de partie | OPT | [Administration](wiki/fr/06-server-admin.md) |

## Détail

### F01 — Fréquence militaire et chaîne « Logistique »

Une chaîne radio dynamique émet sur la fréquence militaire : départ de l'hélicoptère, grille du largage, rappels, MAYDAY, missions. Par défaut, la fréquence est tirée pour la partie entre 120 et 170 MHz (pas de 0,2 MHz) et n'apparaît que sur les notes militaires ; le nom de la chaîne est masqué pour qu'on ne la trouve pas en balayant les canaux. Seules les radios militaires (talkie militaire, radio de manœuvre, radio amateur haut de gamme : « haut de gamme » du jeu) servent aux échanges. Options : `Frequency`.

### F02 — Code, notes, carnet et station de chiffres

Selon `AuthCode` : aucun code, code fixe écrit en clair sur les notes, code périodique en clair, ou (par défaut) code périodique chiffré, diffusé toutes les 30 minutes de jeu par une station de chiffres en ondes courtes et déchiffré avec le carnet de codes. Le code change chaque lundi, un lundi sur deux ou le 1er du mois (`CodePeriod`) ; l'ancien reste accepté 24 h. Les notes militaires tombent sur certains zombies (militaires et policiers par défaut), le carnet sur les militaires et dans le butin de l'armée ; ils s'ouvrent par « Inspecter » comme les journaux du jeu. Trois codes faux dans la journée : la base ne répond plus à ce personnage jusqu'au lendemain. Options : `AuthCode`, `CodePeriod`, `NumbersStationFrequency`, `NoteDropRate`, `NotesOnlyArmyPolice`, `NoteOutfits`, `NoteOutfitsExcluded`, `CodebookDropRate`, `CodebookOutfits`.

### F03 — Appel de largage

Clic droit sur une radio militaire, « Options de l'appareil », section « Logistique » : saisie du code, bouton « Demander un largage », dernière réponse de la base. La radio doit être en main ou posée à proximité, allumée ; un talkie à la ceinture reçoit mais n'émet pas. Le personnage parle, la base répond par la radio : refus sans réponse (mauvais canal ou mauvais code, indiscernables), ligne coupée, délai restant, ou accord avec l'indicatif de la station. Le délai entre deux largages est global au serveur (`CooldownHours` heures), multiplié par un facteur qui dépend de la confiance du personnage qui appelle. Options : `CooldownHours`.

### F04 — Formulaire de réquisition

Avec `RequisitionForm` (par défaut), un appel accepté ouvre une feuille dactylographiée : 18 lots en trois paliers (rations, eau, soins, outils… jusqu'aux armes à feu, accessoires, explosifs, carburant), un budget qui dépend de la confiance, les points non dépensés perdus. Chaque unité commandée devient une caisse de réquisition, ouverte par une recette ; son contenu est tiré à l'ouverture. Un admin peut redéfinir les lots dans `Zomboid/Lua/MilitaryDrop/requisition.txt` et les recharger. Options : `RequisitionForm`, `RequisitionBudget`, `RequisitionCostMultiplier`, `RequisitionTier2`, `RequisitionTier3`, `RequisitionExplosives`.

### F05 — Vol, annonce et repère

L'hélicoptère vient de loin, survole le point (150 à 400 cases du demandeur par défaut), largue la caisse et repart ; chaque joueur le voit et l'entend localement (son, ombre au sol, flèche de direction). Les coordonnées sont annoncées sur la chaîne militaire ; seul un joueur dont une radio reçoit vraiment la ligne obtient un repère sur sa carte. La grille est répétée tant qu'aucune caisse n'est ouverte. Options : `DropMinDistance`, `DropMaxDistance`, `DropRepeatHours`.

### F06 — Caisse, horde et contenu

La caisse est un objet 3D (véhicule sans roues avec coffre) posée dès que sa zone est chargée, sur une case libre, extérieure, hors de l'eau ; une horde l'entoure (3 à 30 zombies). Sans commande, le coffre contient des caisses de ravitaillement (munitions, armes, équipement, accessoires) tirées dans les tables de l'armée et des mods ; une arme arrive avec deux chargeurs et une boîte de munitions. Vide, la caisse se démonte au marteau et à la scie selon les règles vanilla du bois. Avec Signal Smoke, une fumée verte la signale. Options : `MinZombies`, `MaxZombies`, `CaseRolls`, `CrateSmokeMinutes`.

### F07 — Leurre à sirène

« Commande spéciale » du formulaire, exclusive : même hélicoptère, même annonce, mais le coffre ne contient qu'une balise de diversion et une sirène hurle quelques heures pour attirer les hordes dans un secteur choisi (N, E, S, O, ou secteur nommé des zones de largage). Un joueur peut la couper sur place. Sans effet sur la confiance. Options : `DecoyEnabled`, `DecoyCost`, `DecoySirenHours`, `DecoyNoiseRadius`.

### F08 — Réputation personnelle et équipes

Chaque personnage a sa propre note (départ 25 sur 100), jamais affichée en chiffres : la base la traduit en paliers (ton des répliques, budget, délai entre largages, de ×1,5 à ×0,6). Elle monte par les largages récupérés et les sources de confiance (plafond quotidien), baisse par les largages perdus ou pris par d'autres et les codes faux ; sous 15, la ligne est coupée quelques jours. Les factions vanilla forment les équipes (indicatif, poste partagé) sans toucher aux notes. Options : `TrustDailyCap`, `TrustPostBonus`, `TrustLineCutDays`, `TrustDropLostHours`, `TrustErosion`.

### F09 — Sources de confiance et missions

Nettoyage : après apparition, les morts au sol dans le cercle et les membres suivis de la horde tués hors cercle alimentent un objectif commun fixe à 90 % de la horde réelle, arrondis au supérieur. Une mort ne compte qu'une fois ; le meilleur contributeur reçoit le gain existant. Les missions en cours conservent leur progression lors de la mise à jour.

Par la section « Logistique » d'une radio militaire, sans code : rapport de situation quotidien, transmission des plaques d'identité vanilla des morts, confirmation d'une reconnaissance (grille annoncée à tous, premier arrivé), nettoyage d'une horde annoncée (quota de zombies abattus), réponse à un appel de contrôle. Chaque source a son gain, désactivable à 0. Options : `ReportGain`, `DogTagGain`, `ReconGain`, `ReconHours`, `ReconIntervalHours`, `CleanupGain`, `CleanupHours`, `CleanupQuota`, `CleanupIntervalHours`, `ControlGain`, `ControlHours`, `ControlIntervalHours`.

### F10 — Poste de liaison

La console permet de transmettre le rapport quotidien, répondre à un contrôle, confirmer une reconnaissance, faire le point sur un nettoyage et demander un passage Fulton, sans radio portable. Ces échanges gardent leurs vérifications et bonus existants ; une reconnaissance exige toujours la présence du personnage dans sa zone. Le rapport déjà envoyé et le contrôle déjà confirmé sont désactivés pour ce personnage.

Une radio militaire fixe (posée, haut de gamme, émettrice) devient la console de la station, une par équipe : voyants, indicatif, journal des messages reçus par le poste (même en zone déchargée, selon son alimentation), ordres de mission, casier des plaques, galons de confiance, appel de largage, baie de lecture de l'enregistreur de vol. Bonus de confiance du poste (`TrustPostBonus`).

### F11 — Talkie à la ceinture

Avec Belt Walkie-Talkie (requis), un talkie accroché à la ceinture garde ses « Options de l'appareil », reste allumé et entend les messages du mod, y compris en solo ; pour émettre, le personnage le prend en main (automatiquement depuis un sac, refus explicite depuis la ceinture).

### F12 — Zones de largage

Pour les serveurs PvP : l'admin trace des zones (secteur, nom, poids, carte attendue) dans `dropzones.txt` ou avec l'outil en jeu ; les caisses ne tombent que dedans, hors bâtiment, hors de l'eau connue, hors zones non-PvP et refuges. Secteur le plus proche, au hasard ou choisi par le joueur sur le formulaire ; repli sur les villes vanilla puis la proximité. Options : `DropPlacement`, `DropZoneChoice`, `DropZoneMinDistance`, `DropZoneMaxDistance`, `DropZoneAnnounceName`.

### F13 — Extraction Fulton

Un kit Fulton (fabriqué, réparé ou trouvé) se remplit de renseignements et de matériel (pièces d'identité nominatives, papiers, cartes-cachettes, remède s'il existe…), se pose au sol dehors, puis se gonfle à l'hélium après une demande de passage par radio ; un avion l'emporte et la base paie en confiance selon le contenu (plafond quotidien, remède hors plafond). Refus visibles : pas de créneau, kit vide, intérieur, arbre, orage, vent. Options : `FultonValue`, `FultonWindowMinutes`, `FultonLootRate`.

### F14 — Hélicoptère abattu (Mayday)

Un vol normal peut tomber (panne, orage, tirs si autorisés, ordre d'un admin) : MAYDAY sur la chaîne militaire, deux épaves 3D, corps du pilote avec l'enregistreur de vol (et documents en option), deux membres d'équipage relevés, horde, feu ou fumée. Les pièces se récupèrent par la mécanique du véhicule (outils, compétences, ordre), donnent des lots d'objets ; l'épave se découpe ensuite à la manière vanilla. L'enregistreur, lu au poste de liaison puis transmis, rapporte de la confiance une fois par site. Options : `CrashChance`, `CrashStormBonus`, `CrashGunfire`, `CrashGunfireChance`, `CrashFire`, `CrashSmokeMinutes`, `CrashCrates`, `SalvageRolls`, `PilotOutfits`, `PilotDocuments`.

### F15 — Outils d'administration

Droits du jeu : capacité « événements » (`MakeEventsAlarmGunshot`, comme `/chopper`) pour le largage forcé, le lancement ou la clôture d'une mission et le crash du prochain hélicoptère ; capacité « options du serveur » (`ChangeAndReloadServerOptions`) pour recharger les lots et gérer les zones. En solo, ces outils passent par le mode debug. Le largage forcé suit les mêmes règles de placement qu'un joueur et peut ouvrir une feuille de réquisition « ADMIN ».

### F16 — Options et changements à chaud

64 options sur la page « Military Drop » du bac à sable (liste complète, valeurs et effets : [specifications-techniques.md](specifications-techniques.md#options-du-bac-à-sable)). Elles sont lues à chaque usage : une nouvelle valeur vaut pour l'appel, le largage ou la mission suivants ; quelques changements sont appliqués dans la minute de jeu (chaîne de la station, carnet dans le butin, lots). `DebugLog` ajoute des traces à la console.

## Solo et multijoueur

- En solo, client et serveur partagent le même Lua : les mêmes contrôles s'appliquent, les commandes sont des appels directs.
- En MP, seul le serveur lit les secrets (graine, code fixe, fréquence libre, état privé) ; les clients ne reçoivent que des clés de traduction, des positions publiques et leurs propres données.
- Les sons (hélicoptère, sirène, baie de lecture) et les repères sont joués localement par chaque client ; seul le bruit pour les zombies est émis par le serveur.

## Limites connues

- Un point de largage lointain est tiré sans charger la carte : l'eau d'une cellule jamais approchée est inconnue ; la livraison attend alors une case sèche (jamais de caisse dans l'eau).
- Le bruit de la sirène n'atteint les zombies que si sa zone est chargée (limite du moteur).
- `requisition.txt` et `dropzones.txt` sont communs à toutes les parties du compte système qui lance le jeu ou le serveur.
- Le mod a surtout été testé en solo ; plusieurs parcours MP restent à valider (voir [annexes/tests/test-protocol.md](annexes/tests/test-protocol.md) et [annexes/plans/SUIVI.md](annexes/plans/SUIVI.md)).
