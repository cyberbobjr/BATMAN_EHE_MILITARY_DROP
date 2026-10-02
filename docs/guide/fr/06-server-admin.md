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
| Effets au sol | `CrashFire` | Fumée | Aucun / fumée / feu et fumée ; règles d’incendie du jeu appliquées. |
| Durée de la fumée (minutes) | `CrashSmokeMinutes` | 60 | Minutes de jeu ; réémise pour les nouveaux arrivants. Aucun besoin de Signal Smoke. |
| Ravitaillement au crash | `CrashCrates` | vrai | Livraison des caisses au site ; crash sans effet sur la réputation. |
| Objets par lot récupéré | `SalvageRolls` | 3 | Tirages parmi les catégories/tags du jeu et des mods. |
| Tenues du pilote | `PilotOutfits` | `Army` | Mots recherchés dans les noms de tenue, séparés par `;`. |
| Documents du pilote | `PilotDocuments` | vrai | Note et carnet dans le corps ; l’enregistreur reste récupérable. |

Le MAYDAY annonce un secteur approximatif sur la fréquence militaire. Le clic droit sur l’épave ouvre la récupération des pièces ; après retrait de toutes les pièces, la découpe finale suit les règles vanilla. L’enregistreur n’a pas encore d’échange ni de récompense à la base.

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

## Outils d'admin en jeu

Clic droit sur une radio militaire (dans l'inventaire ou posée) :

- **Forcer un largage (admin)** : ouvre le formulaire tamponné **ADMIN**, avec tous les lots et 20 points. Ni code, ni contrôle de la radio, ni attente. Les coordonnées vous sont envoyées en privé, le largage ne compte pas pour la confiance et l'attente entre deux largages ne démarre pas. Formulaire désactivé : le largage part aussitôt avec des caisses aléatoires.
- **Missions (admin)** : **Lancer une reconnaissance**, **Lancer un nettoyage**, **Lancer un appel de contrôle**, ou clore la mission en cours (**Clore … en cours**). Une mission close est annoncée comme annulée, sans récompense.
- **Faire crasher le prochain hélicoptère** : programme un seul crash au prochain départ du mod, y compris un largage forcé ou un leurre. Confirmation privée, ordre conservé avec la sauvegarde ; cliquer plusieurs fois ne cumule pas les crashes. Un vol déjà parti continue et une attente HEF ne consomme pas l’ordre. Pour essayer : activer l’option, puis forcer un largage et valider le formulaire.

Qui les voit : en solo, le mode debug seulement. En multijoueur, les rôles qui peuvent déclencher des événements (admin, et tout rôle doté de la capacité `MakeEventsAlarmGunshot`). Le serveur revérifie.

## Fichiers gardés par le mod

| Fichier | Contenu |
|---|---|
| `Zomboid/Lua/MilitaryDrop/requisition.txt` | Lots de réquisition (ci-dessus). |
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
