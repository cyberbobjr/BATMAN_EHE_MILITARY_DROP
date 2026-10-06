# Administration

[English](../en/06-server-admin.md) · [Sommaire du guide](README.md) · Précédent : [Poste de liaison](05-liaison-post.md) · Suivant : [FAQ](07-faq.md)

## Options du bac à sable

Toutes les options sont sur la page **Military Drop** des options du bac à sable. Heures et jours sont en temps de jeu.


### Largages

| Option | Clé | Défaut | Effet |
|---|---|---|---|
| Heures entre deux largages | `CooldownHours` | 168 | Attente minimale entre deux largages, pour tout le serveur. Multipliée par le facteur de confiance de l'appelant (×1,5 à ×0,6). |
| Fréquence militaire (MHz) | `Frequency` | 0 | 0 : fréquence libre tirée au hasard entre 120 et 170 MHz, écrite sur les notes. Une valeur fixe est visible par tous les joueurs. 112,2 MHz est réservée. |
| Distance minimale du largage | `DropMinDistance` | 150 | Cases au minimum entre l'appelant et le point de largage. |
| Distance maximale du largage | `DropMaxDistance` | 400 | Cases au maximum entre l'appelant et le point de largage. |
| Rappel de la grille toutes les (heures) | `DropRepeatHours` | 6 | Heures de jeu entre deux rappels de la grille d'un largage dont aucune caisse de ravitaillement n'a été ouverte, pendant `TrustDropLostHours` au plus. 0 = aucun rappel. |
| Zombies au largage (minimum) | `MinZombies` | 3 | 0 et 0 : aucun zombie. |
| Zombies au largage (maximum) | `MaxZombies` | 30 | Zombies qui apparaissent autour de la caisse. |
| Caisses par largage | `CaseRolls` | 6 | Tirages de butin quand le formulaire est désactivé. |
| Fumée sur la caisse (minutes) | `CrateSmokeMinutes` | 60 | Nécessite Signal Smoke. Fumée verte sur la caisse. 0 : aucune. |

### Code, notes et carnets

| Option | Clé | Défaut | Effet |
|---|---|---|---|
| Code d'authentification | `AuthCode` | Code de la semaine, chiffré | Aucun / Code fixe, en clair sur les notes / Code de la semaine, en clair sur les notes / Code de la semaine, chiffré (station de chiffres et carnet). 3 codes faux dans la journée : la base ignore l'appelant jusqu'au lendemain. |
| Fréquence de la station de chiffres (MHz) | `NumbersStationFrequency` | 0 | 0 : fréquence libre des ondes courtes tirée au hasard, de 10 à 25 MHz. Mode chiffré seulement. |
| Fréquence des notes militaires | `NoteDropRate` | Normale (1/50) | Extrêmement rare 1/1000, Très rare 1/500, Rare 1/100, Normale 1/50, Courante 1/25, Débogage 1/2. |
| Notes seulement sur les zombies militaires et policiers | `NotesOnlyArmyPolice` | vrai | Seules les tenues de la liste ci-dessous portent des notes. |
| Tenues qui portent les notes | `NoteOutfits` | `Army;Police;Sheriff` | Mots cherchés dans le nom de la tenue (reconnaît aussi les tenues des mods). |
| Tenues exclues | `NoteOutfitsExcluded` | `Stripper` | Tenues qui ne portent jamais de note ni de carnet. |
| Fréquence des carnets de codes | `CodebookDropRate` | Rare (1/100) | Même échelle. Règle aussi leur fréquence dans les réserves de l'armée. |
| Tenues qui portent les carnets | `CodebookOutfits` | `Army` | Mots cherchés dans le nom de la tenue. |

### Confiance

| Option | Clé | Défaut | Effet |
|---|---|---|---|
| Plafond quotidien de confiance | `TrustDailyCap` | 8 | Confiance maximale gagnée par jour, hors largages. 0 : seuls les largages comptent. |
| Bonus du poste de liaison (pour cent) | `TrustPostBonus` | 50 | Confiance en plus pour les échanges faits depuis le poste de liaison. |
| Ligne coupée (jours) | `TrustLineCutDays` | 3 | Jours sans largage quand la confiance passe sous 15. 0 : jamais coupée. |
| Heures pour récupérer un largage | `TrustDropLostHours` | 48 | Passé ce délai, un largage non ouvert est perdu (−10). |
| Érosion de la confiance | `TrustErosion` | faux | Chaque jour sans échange, la confiance revient d'un point vers sa valeur de départ. |
| Confiance : rapport de situation quotidien | `ReportGain` | 1 | 0 désactive les rapports. |
| Confiance : matricule annoncé | `DogTagGain` | 2 | 0 désactive les plaques. |
| Confiance : reconnaissance | `ReconGain` | 3 | 0 désactive les reconnaissances. |
| Échéance de la reconnaissance (heures) | `ReconHours` | 48 | |
| Heures entre deux reconnaissances | `ReconIntervalHours` | 24 | Après la clôture de la précédente, à 25 % près. |
| Confiance : nettoyage | `CleanupGain` | 5 | 0 désactive les nettoyages. |
| Échéance du nettoyage (heures) | `CleanupHours` | 72 | |
| Taille de la horde du nettoyage | `CleanupQuota` | 30 | Ordre rempli quand 90 % de la horde est morte. |
| Heures entre deux nettoyages | `CleanupIntervalHours` | 48 | À 25 % près. |
| Confiance : appel de contrôle | `ControlGain` | 1 | 0 désactive les appels de contrôle. |
| Durée de l'appel de contrôle (heures) | `ControlHours` | 4 | |
| Heures entre deux appels de contrôle | `ControlIntervalHours` | 24 | À 25 % près. |

### Réquisition et leurre

| Option | Clé | Défaut | Effet |
|---|---|---|---|
| Formulaire de réquisition | `RequisitionForm` | vrai | Désactivé : caisses de ravitaillement aléatoires, comme dans le mod Build 41. |
| Budget de réquisition (pour cent) | `RequisitionBudget` | 100 | À 100 : 8 points à la confiance 25, 12 à 50, 16 à 75, 20 à 100. |
| Coûts de réquisition (pour cent) | `RequisitionCostMultiplier` | 100 | Ajuste chaque coût, arrondi, au moins 1 point. |
| Confiance des lots du deuxième palier | `RequisitionTier2` | 50 | |
| Confiance des lots du troisième palier | `RequisitionTier3` | 75 | |
| Explosifs en réquisition | `RequisitionExplosives` | vrai | |
| Largage leurre | `DecoyEnabled` | vrai | Propose le leurre à sirène dans le formulaire. |
| Coût du leurre (points) | `DecoyCost` | 3 | |
| Durée de la sirène du leurre (heures) | `DecoySirenHours` | 6 | |
| Portée du bruit de la sirène (cases) | `DecoyNoiseRadius` | 120 | Seulement quand la zone autour de la caisse est chargée. |

### Hélicoptère abattu (branche Mayday)

| Option | Clé | Défaut | Effet |
|---|---|---|---|
| Risque de crash (%) | `CrashChance` | 5 | Probabilité par départ normal ; largages admin et leurres exclus. |
| Bonus d’orage | `CrashStormBonus` | 15 | Points de probabilité ajoutés pendant un orage, maximum total 100 %. |
| Tirs pouvant abattre l’appareil | `CrashGunfire` | faux | Signal client revérifié pour plausibilité au serveur : arme chargée, distance et direction. |
| Chance par tir plausible (%) | `CrashGunfireChance` | 10 | Approche seulement, largages admin et leurres exclus. |
| Effets au sol | `CrashFire` | Feu et fumée | Aucun / fumée / feu et fumée ; un seul foyer initial près du fuselage, règles d’incendie du jeu appliquées. Les sauvegardes conservent leur réglage existant. |
| Durée de la fumée (minutes) | `CrashSmokeMinutes` | 60 | Minutes de jeu ; réémise pour les nouveaux arrivants. Aucun besoin de Signal Smoke. |
| Ravitaillement au crash | `CrashCrates` | vrai | Livraison des caisses au site ; crash sans effet sur la réputation. |
| Objets par lot récupéré | `SalvageRolls` | 3 | Tirages parmi les catégories/tags du jeu et des mods. |
| Tenues du cadavre | `PilotOutfits` | `Army` | Mots recherchés dans les noms de tenue, séparés par `;`. Les deux pilotes zombies supplémentaires portent leur combinaison de vol militaire dédiée. |
| Documents du pilote | `PilotDocuments` | vrai | Note et carnet dans le corps ; l’enregistreur reste récupérable. |

Le MAYDAY annonce un secteur approximatif sur la fréquence militaire. Le clic droit sur l’épave ouvre la récupération des pièces ; après retrait de toutes les pièces, la découpe finale suit les règles vanilla. L’enregistreur de vol se lit dans la baie de lecture du poste de liaison (10 minutes de jeu, radio du poste allumée et alimentée ; pause en cas de coupure), puis se transmet à la base sur la fréquence militaire : +10 de réputation au personnage qui le transmet, hors plafond quotidien, une fois par site de crash (crashs admin compris).

### Débogage

| Option | Clé | Défaut | Effet |
|---|---|---|---|
| Journal de débogage | `DebugLog` | faux | Lignes `[MilitaryDrop]` détaillées dans `console.txt`. |

## Fichier des lots de réquisition

Les lots du formulaire sont définis dans `Zomboid/Lua/MilitaryDrop/requisition.txt`, dans le dossier Zomboid du compte système qui lance le jeu ou le serveur. Le fichier est créé au premier démarrage avec les 18 lots par défaut et une notice en anglais.

> Ce fichier est commun à **toutes** les parties solo et à **tous** les serveurs lancés par ce compte.

- Chaque lot a `id`, `enabled`, `group` (palier 1 à 3), `cost` (1 à 99), `count` (objets par caisse, 1 à 20) et un filtre : `categories` (catégories d'affichage des objets), `tags`, `notTags`, `minWeight`, `maxWeight`, `kind` (`ration`, `firearm`, `melee`, `ammo`, `armor`, `attachment`, `pack`), `fluid` (`Water`, `Petrol`), `extras`.
- Pour retirer un lot, mettez `enabled = false`. Ne supprimez pas un lot ajouté : les caisses déjà livrées gardent son identifiant et ne s'ouvrent pas sans lui.
- Vous pouvez ajouter des lots (40 au total au plus), avec leurs textes :

```lua
{
    id = "kitchen", enabled = true, group = 1, cost = 2, count = 3,
    categories = { "Cooking" }, maxWeight = 3,
    texts = { EN = { label = "Kitchen", desc = "Pots, pans and cutlery." },
              FR = { label = "Cuisine", desc = "Casseroles, poêles et couverts." } },
},
```

- Seules des données sont lues, jamais du code. Une erreur de syntaxe garde les 18 lots par défaut ; chaque problème est écrit dans `console.txt` avec son numéro de ligne.
- Supprimez le fichier pour retrouver le fichier par défaut au démarrage suivant.

Recharger sans redémarrer :

- solo, console de débogage : `MilitaryDrop.Requisition.reload()`
- multijoueur, depuis la console de débogage d'un admin : `sendClientCommand(getPlayer(), "MilitaryDrop", "ReloadLots", {})` (rôle admin seulement ; le résumé s'affiche dans la console de l'admin)

## Zones de largage

Par défaut, une caisse tombe entre 150 et 400 cases de l'appelant. Sur un serveur PvP qui a des zones protégées, ce point tombe souvent dans une zone protégée, et la caisse annoncée se ramasse sans aucun risque. Les **zones de largage** permettent à l'admin de choisir où tombent les caisses : des rectangles regroupés en **secteurs** (en général une ville), par exemple un parc, un centre commercial et un immeuble à Louisville. Chaque largage tire une zone au hasard : personne ne peut camper le point exact.

Rien ne change tant que **Placement des largages** n'est pas modifié : la valeur par défaut reste « Près du demandeur ».

### Options

| Option | Clé | Défaut | Effet |
|---|---|---|---|
| Placement des largages | `DropPlacement` | Près du demandeur | **Près du demandeur** : un point tiré entre les distances minimale et maximale du largage, comme avant. **Zones de largage** : dans une zone de l'admin ; sans zone utilisable, une ville vanilla, sinon près du demandeur (voir [Repli](#repli)). **Zones si l'une est proche** : seules les zones plus proches que la portée des zones sont utilisées ; s'il n'y en a aucune, près du demandeur. |
| Secteur des zones de largage | `DropZoneChoice` | Le plus proche du demandeur | **Le plus proche du demandeur** ou **Au hasard**. Une zone de ce secteur est ensuite tirée au hasard, selon son poids. |
| Distance minimale des zones de largage | `DropZoneMinDistance` | 0 | Cases, de 0 à 5000. Les zones plus proches du demandeur sont écartées : personne ne peut appeler depuis une zone pour se servir aussitôt. Si toutes les zones sont plus proches, le secteur le plus proche est retenu. 0 : aucune distance minimale. |
| Portée des zones de largage | `DropZoneMaxDistance` | 1500 | Cases, de 100 à 20000. Sert seulement à « Zones si l'une est proche ». |
| Annoncer le nom de la zone | `DropZoneAnnounceName` | vrai | L'annonce et ses rappels donnent le nom de la zone avant la grille. Désactivé : la grille seule. |

Les distances vont du demandeur au bord le plus proche d'une zone (0 à l'intérieur). En mode zones, `DropMinDistance` et `DropMaxDistance` ne servent que lorsque le largage revient près du demandeur, et pour les largages de l'admin. Les largages de l'admin (**Forcer un largage**, direct ou par le formulaire admin) ignorent les zones : ils tombent toujours près de l'admin, quel que soit le **Placement des largages**.

### Le fichier `dropzones.txt`

Les zones sont gardées dans `Zomboid/Lua/MilitaryDrop/dropzones.txt`, à côté de `requisition.txt`. Le fichier est créé au premier démarrage, sans zone, avec une notice en anglais.

> Comme le fichier des lots, il est commun à **toutes** les parties solo et à **tous** les serveurs lancés par ce compte. Le champ `map` lie les zones à une carte.

Vous pouvez tracer les zones avec l'[outil en jeu](#outil-en-jeu) ou les écrire à la main :

```lua
return {
    version = 1,
    map = "Muldraugh, KY",
    zones = {
        { id = "z1", sector = "Louisville", name = "Central Park", x1 = 12900, y1 = 2100, x2 = 12980, y2 = 2160 },
        { id = "z2", sector = "Louisville", name = "Mall", x1 = 13200, y1 = 2300, x2 = 13290, y2 = 2380, weight = 2 },
        { id = "z3", sector = "Riverside", name = "Main Street", x1 = 6400, y1 = 5380, x2 = 6480, y2 = 5440, enabled = false },
    },
}
```

Les coordonnées ci-dessus sont des exemples : relevez les vôtres en jeu, ou tracez les zones avec l'outil (il affiche les coins et la taille).

| Champ | Contenu |
|---|---|
| `map` | Cartes pour lesquelles les zones sont tracées : noms de dossiers de cartes séparés par `;`, comme dans la ligne `Map=` du serveur (carte vanilla : `Muldraugh, KY`). Facultatif. Une zone peut porter son propre `map`. |
| `id` | Nom unique : lettres, chiffres, `_` et `-`, 16 caractères au plus. L'outil numérote ses zones `z1`, `z2`... |
| `sector` | Groupe de zones, en général une ville. 32 caractères au plus, sans `<` ni `>`. |
| `name` | Nom de la zone, lu dans l'annonce radio. Mêmes limites. |
| `x1`, `y1`, `x2`, `y2` | Rectangle au rez-de-chaussée. Les deux coins font partie de la zone ; de 1 à 300 cases de côté. |
| `weight` | De 1 à 100, 1 par défaut. Une zone de poids 2 est tirée deux fois plus souvent qu'une zone de poids 1 du même secteur. |
| `enabled` | `true` ou `false`, `true` par défaut. |

- **Carte attendue** : une zone dont la carte n'est pas chargée dans la partie en cours est ignorée, avec une ligne dans `console.txt`. L'outil l'affiche « carte non chargée ». Quand le fichier n'a pas de `map`, l'outil y écrit la carte de la partie à sa première modification.
- Seules des données sont lues, jamais du code. Une erreur de syntaxe désactive **toutes** les zones (voir [Repli](#repli)) ; le numéro de ligne est écrit dans `console.txt`. Une zone invalide est écartée (`zone #3 (z3): ...`). 200 zones au plus.
- À chaque chargement, le serveur contrôle chaque zone et écrit ses avertissements dans `console.txt` et dans la liste de l'outil : **aucune route** (les caisses tombent seulement au pied des bâtiments), **ni route ni bâtiment** (aucune caisse ne peut y tomber : les données de la carte ne connaissent pas l'eau), **chevauche une zone non-PvP** ou **un refuge** (aucune caisse dans cette partie), **hors de la carte**, **carte non chargée**.

Recharger sans redémarrer : le bouton **Rafraîchir** de l'outil, ou depuis la console de débogage d'un admin : `sendClientCommand(getPlayer(), "MilitaryDrop", "ZoneReload", {})`.

> Après une modification à la main, **rechargez avant d'utiliser l'outil**. L'outil réécrit tout le fichier à partir de la dernière version lue : les modifications non rechargées seraient perdues, de même que vos propres commentaires. Il refuse d'écrire tant que le fichier contient une erreur de syntaxe, pour ne jamais écraser une modification à la main.

### Outil en jeu

Qui le voit : en multijoueur, les rôles qui peuvent modifier et recharger les options du serveur (admin, et tout rôle doté de la capacité `ChangeAndReloadServerOptions` ; l'hôte d'une partie coop aussi). En solo, le mode debug seulement. Le serveur revérifie : la commande de tout autre joueur est refusée et notée au journal.

Où l'ouvrir :

- **Multijoueur** : bouton **Zones de largage** du panneau d'admin du jeu.
- **Solo, mode debug** : **Zones de largage** dans le menu de debug du jeu (onglet **Main**), ou depuis la console de débogage : `MilitaryDrop.ZonesWindow.open(getPlayer())`.

La fenêtre **Zones de largage (admin)** reprend le panneau des zones d'animaux du jeu. En tête : la carte attendue, le mode de placement et le nombre de zones utilisables. La liste montre les zones groupées par secteur, avec leur état (active, désactivée, carte non chargée), leurs coins, leur taille, leur poids et leurs avertissements, puis les premiers problèmes du fichier. La zone sélectionnée est surlignée au sol, sur votre écran seulement et seulement fenêtre ouverte : vert active, gris désactivée, orange carte non chargée. Les messages de l'outil (zone ajoutée, refus, fichier rechargé) s'affichent dans la fenêtre, jamais au-dessus de votre personnage : les joueurs proches ne voient rien.

Boutons :

- **Ajouter une zone** : tracer une nouvelle zone (ci-dessous).
- **Modifier** : changer le nom, le secteur ou le poids de la zone sélectionnée, ou la retracer (ci-dessous).
- **Retirer** : demande d'abord « Voulez-vous vraiment retirer ... ? ».
- **Activer** / **Désactiver**.
- **Se téléporter sur la zone** : au centre de la zone, au rez-de-chaussée. Demande le droit de téléportation (capacité `TeleportToCoordinates` en multijoueur).
- **Rafraîchir** : relit `dropzones.txt`.
- **Fermer** (ou Échap).

Manette : croix haut et bas pour choisir une zone, A modifie, X active ou désactive, Y ajoute, B ferme.

#### Ajouter une zone

1. Appuyez sur **Ajouter une zone**. La liste se masque et un éditeur s'ouvre en haut à gauche de l'écran.
2. Tracez le rectangle au sol avec le **clic gauche** : appuyez, faites glisser et relâchez, ou cliquez un coin puis le coin opposé. Pendant le tracé, les clics ne servent qu'à tracer : ni attaque, ni déplacement, ni porte ouverte, ni menu contextuel. Les cases sont prises au rez-de-chaussée, quel que soit votre étage. L'éditeur affiche les coins, la **Largeur** et la **Longueur**, en rouge au-delà de 300 cases.
3. Après le second coin, le rectangle est figé. Clic droit ou Échap annule le tracé en cours ; un second Échap ferme l'éditeur.
4. Remplissez **Nom de la zone**, **Secteur** (un secteur connu, ou **Nouveau secteur...** et son nom dans **Nouveau secteur**) et **Poids (1-100)**, puis appuyez sur **Ajouter une zone**.
5. Le serveur contrôle la zone et répond dans l'éditeur : « Zone de largage z4 ajoutée. », avec ses avertissements, ou un refus (trop grande, hors de la carte, chevauchement d'une zone non-PvP ou d'un refuge, déjà 200 zones, fichier avec une erreur de syntaxe). Il écrit `dropzones.txt` et le recharge. En cas de succès, l'éditeur se ferme et la nouvelle zone est sélectionnée dans la liste. **Annuler** revient à la liste.

Manette : la croix déplace la case visée (en partant de la vôtre), A fixe le premier coin puis le second, B annule le tracé. Une fois le rectangle tracé, la croix parcourt le formulaire et B annule.

#### Modifier une zone

Sélectionnez la zone et appuyez sur **Modifier**. Changez son **Nom de la zone**, son **Secteur** ou son **Poids**, ou appuyez sur **Retracer** et tracez-la de nouveau : l'ancien rectangle reste surligné en gris jusqu'au nouveau tracé, et revient si vous annulez. **Enregistrer** n'envoie que les champs modifiés, avec les mêmes contrôles qu'une nouvelle zone (« Rien à enregistrer. » si rien n'a changé). Tant que `dropzones.txt` contient une erreur de syntaxe, la modification est refusée et rien n'est écrit.

### Ce que voient les joueurs

- L'annonce et ses rappels nomment la zone : « Caisse de ravitaillement livrée sur la zone Central Park, grille 12937 / 2125. » Avec **Annoncer le nom de la zone** désactivé, ils donnent la grille seule. Le repère de carte ne change pas.
- La liste des zones n'est jamais envoyée aux joueurs, et les contours des zones ne s'affichent que sur l'écran de l'admin, outil ouvert. Les joueurs découvrent les zones par les annonces.
- **Leurre** : en mode zones, le formulaire propose un sélecteur de secteur (« < Louisville > », flèches, ou gauche et droite à la manette) au lieu de N, E, S et O. Avec un seul secteur, il est sélectionné d'office et affiché, sans choix. Le leurre tombe dans une zone de ce secteur, comme un vrai largage, avec la même annonce. Près du demandeur, et sur le formulaire admin, le leurre garde N, E, S et O.
- La confiance ne change pas : un joueur extérieur qui ouvre la caisse coûte toujours 5 points au demandeur.

### Repli

Avec **Zones de largage** et aucune zone utilisable (aucune zone, toutes désactivées, carte non chargée, ou erreur de syntaxe) :

1. **Villes vanilla**, seulement si la carte vanilla (`Muldraugh, KY`) est chargée : Louisville, Valley Station, West Point, Muldraugh, Riverside, Brandenburg, Ekron, Irvington, Echo Creek, March Ridge, Fallas Lake et Rosewood. Chaque ville est un secteur d'une seule zone, de 150 cases autour de son centre, choisi avec les mêmes règles (le plus proche ou au hasard, distance minimale).
2. Sinon, **près du demandeur**, comme avant. Le serveur écrit un avertissement dans `console.txt`, et les admins connectés reçoivent le message « Aucune zone de largage utilisable : la caisse tombe près du demandeur. Vérifiez les zones de largage. »

Avec **Zones si l'une est proche**, un appel loin de toute zone tombe simplement près du demandeur, sans avertissement. Une carte de mod sans zone revient près du demandeur.

### Ce que le mod ne fait jamais

- **Une caisse dans l'eau.** Les données de la carte ne connaissent pas l'eau : le point est donc toujours une route ou le pied d'un bâtiment dans la zone, jamais une case quelconque du rectangle. À la livraison, les quatre cases sous la caisse sont revérifiées.
- **Une caisse hors de sa zone.** Si aucune case de la zone tirée ne convient, le serveur essaie une autre zone du même secteur, puis répond à l'appelant « aucune zone de largage sûre » : le largage ne part pas et le formulaire reste ouvert. À la livraison, la caisse n'est posée que sur une case sèche et libre de la zone ; sinon la livraison attend.
- **Une caisse dans une zone non-PvP ou un refuge**, même créé après la zone.
- **Envoyer la liste des zones aux joueurs.**

### Limites

- Rectangles au rez-de-chaussée seulement, 300 cases de côté au plus, 200 zones en tout.
- Une zone tracée sur un lac ou sur l'Ohio, ou sans route ni bâtiment, peut ne donner aucun largage (« aucune zone de largage sûre »), jamais une caisse dans l'eau. Vérifiez les avertissements de la liste.
- Les villes vanilla ne sont connues que pour la carte vanilla. Sur une carte de mod, tracez vos propres zones.
- Avec un seul secteur et beaucoup de joueurs, la zone devient un lieu de rendez-vous régulier : c'est voulu sur un serveur PvP, à équilibrer avec **Heures entre deux largages**.
- En mode zones, tout le monde sait déjà où regarder : un leurre surprend moins. Il ressemble pourtant à un vrai largage jusqu'à ce qu'on entende sa sirène ou qu'on ouvre sa caisse.

## Outils d'admin en jeu

Clic droit sur une radio militaire (dans l'inventaire ou posée) :

- **Forcer un largage (admin)** : ouvre le formulaire tamponné **ADMIN**, avec tous les lots et 20 points. Ni code, ni contrôle de la radio, ni attente. Les coordonnées vous sont envoyées en privé, le largage ne compte pas pour la confiance et l'attente entre deux largages ne démarre pas. Formulaire désactivé : le largage part aussitôt avec des caisses aléatoires. Il tombe toujours près de vous, même avec des zones de largage, et le leurre de ce formulaire garde N, E, S et O.
- **Missions (admin)** : **Lancer une reconnaissance**, **Lancer un nettoyage**, **Lancer un appel de contrôle**, ou clore la mission en cours (**Clore … en cours**). Une mission close est annoncée comme annulée, sans récompense.
- **Faire crasher le prochain hélicoptère** : programme un seul crash au prochain départ du mod, y compris un largage forcé ou un leurre. Confirmation privée, ordre conservé avec la sauvegarde ; cliquer plusieurs fois ne cumule pas les crashes. Un vol déjà parti continue et une attente HEF ne consomme pas l’ordre. Pour essayer : activer l’option, puis forcer un largage et valider le formulaire.

Qui les voit : en solo, le mode debug seulement. En multijoueur, les rôles qui peuvent déclencher des événements (admin, et tout rôle doté de la capacité `MakeEventsAlarmGunshot`). Le serveur revérifie.

Les zones de largage ont leur propre outil, dans le panneau d'admin du jeu : voir [Outil en jeu](#outil-en-jeu).

## Fichiers gardés par le mod

| Fichier | Contenu |
|---|---|
| `Zomboid/Lua/MilitaryDrop/requisition.txt` | Lots de réquisition (ci-dessus). |
| `Zomboid/Lua/MilitaryDrop/dropzones.txt` | Zones de largage (ci-dessus). |
| `Zomboid/Lua/MilitaryDrop/<mode>_<partie>_seed.txt` | Graine secrète de la partie : codes de la semaine, table du carnet, fréquences tirées au hasard. Serveur seulement. |
| `Zomboid/Lua/MilitaryDrop/<mode>_<partie>_code.txt` | Code fixe (mode code fixe). Serveur seulement. |
| `Zomboid/Lua/MilitaryDrop/code_<sp ou mp>_<partie>_<joueur>.txt` | Code saisi par un joueur, gardé sur son ordinateur. |

Ne partagez ni ne supprimez jamais la graine en cours de partie : les notes et carnets déjà trouvés ne correspondraient plus. Confiance, stations, missions et postes sont sauvegardés avec le monde, dans des données que les clients ne peuvent pas lire.

## Console de débogage (solo ou hôte)

```lua
print(MilitaryDrop.Server.getCode())                                       -- code en vigueur
print(MilitaryDrop.Config.formatChannel(MilitaryDrop.Config.getChannel())) -- fréquence militaire
print(MilitaryDrop.NumbersStation.frequency)                               -- station de chiffres, en kHz
MilitaryDrop.Trust.debugPrint()                                            -- confiance de chaque personnage
MilitaryDrop.Trust.add(MilitaryDrop.Trust.idFor(getPlayer()), 30, "drop")                                 -- donner de la confiance (station du solo)
MilitaryDrop.Missions.launch("recon")                                      -- "recon", "cleanup" ou "control"
getPlayer():getInventory():AddItem("MilitaryDrop.MilitaryMemo")
getPlayer():getInventory():AddItem("MilitaryDrop.Codebook")
```

Ces commandes lisent la mémoire du serveur : elles marchent en solo, pas depuis un client multijoueur.

## Notes pour le multijoueur

- Le serveur décide et vérifie tout ; les clients ne reçoivent jamais la fréquence tirée au hasard ni le code (seules les notes et la station de chiffres les donnent).
- Un talkie-walkie doit être en main pour émettre : le mod le prend en main automatiquement.
- Trois codes faux d'un joueur ne font pas taire la base pour les autres.
