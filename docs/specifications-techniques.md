# Spécifications techniques de Military Drop

Contrats précis du mod, relevés dans le code de la version 0.5.4 (2026-10-21). Organisation générale : [architecture.md](architecture.md). Comportement vu par le joueur : [specifications-fonctionnelles.md](specifications-fonctionnelles.md).

`lua/` désigne `Contents/mods/batman_MilitaryDrop/42.21/media/lua/`, `scripts/` le dossier `media/scripts/` de la même variante.

## Version et dépendances

| Élément | Valeur |
|---|---|
| Build cible | 42.21 (`versionMin=42.21`, variante unique `42.21/`) |
| `id` | `batman_MilitaryDrop` (Workshop 3811752923) |
| `require` | `\batman_BeltRadio,\batman_SignalSmoke` : Belt Walkie-Talkie (Workshop 3817018338), qui exige TooltipLib (3694097672), et Signal Smoke (Workshop 3811010882, fumée sur la caisse ; prérequis depuis le 2026-10-21, gardes de détection conservées) |
| Facultatifs détectés | HEF (`HTT.Server.state`, lecture seule), `ZVirusVaccine42BETA` (barème Fulton) |
| Globale Lua | `MilitaryDrop` uniquement (`BatmanRadioSupport` est lue, fournie par Belt Walkie-Talkie) |

## Objets et scripts

Module de script `MilitaryDrop` pour les objets et recettes ; modèles, sons et véhicules dans `Base`.

| Type complet | Catégorie / type | Rôle | Fichier |
|---|---|---|---|
| `MilitaryDrop.AmmoSupplyCase`, `WeaponSupplyCase`, `ArmorSupplyCase`, `AttachmentSupplyCase` | Container / normal | Caisses de ravitaillement d'un largage sans commande ; ModData `MilitaryDrop_dropId` | `MilitaryDrop_items.txt` |
| `MilitaryDrop.RequisitionCase` | Container / normal | Caisse d'un lot commandé ; ModData `MilitaryDrop_lot`, `MilitaryDrop_dropId` | `MilitaryDrop_items.txt` |
| `MilitaryDrop.MilitaryMemo` | Literature / literature, tag `base:fastread` | Note militaire `printMedia` ; `OnCreate = MilitaryDrop.Memo.onCreate` | `MilitaryDrop_items.txt` |
| `MilitaryDrop.Codebook` | Literature / literature, tag `base:fastread` | Carnet de codes ; `OnCreate = MilitaryDrop.Memo.onCreateCodebook` | `MilitaryDrop_items.txt` |
| `MilitaryDrop.DecoyBeacon` | Electronics / normal | Balise de diversion du coffre d'un leurre | `MilitaryDrop_decoy.txt` |
| `MilitaryDrop.AvionicsSalvage`, `MechanicalSalvage`, `MetalSalvage` | Container / normal | Lots récupérés sur l'épave | `MilitaryDrop_salvage.txt` |
| `MilitaryDrop.FlightRecorder` | Electronics / normal | Enregistreur de vol (ModData `MilitaryDrop_crashSite`) | `MilitaryDrop_salvage.txt` |
| `MilitaryDrop.FultonKit` | Tool / container | Kit d'extraction Fulton | `MilitaryDrop_Fulton.txt` |
| `MilitaryDrop.FultonKitDamaged`, `FultonBalloonFolded`, `FultonHarnessBag` | Material / normal | Kit endommagé et pièces | `MilitaryDrop_Fulton.txt` |
| `MilitaryDrop.HeliumTank` | Material / drainable, tags `base:hasmetal`, `base:smeltablesteellarge` | Bouteille d'hélium | `MilitaryDrop_Fulton.txt` |
| `MilitaryDrop.FultonPrototypeBalloon`, `FultonPrototypeBag` | Material / normal | Objets du prototype visuel (menu de test) | `MilitaryDrop_FultonPrototype.txt` |

Recettes (`craftRecipe`) :

| Nom | Entrées | Sortie / effet |
|---|---|---|
| `OpenMilitarySupplyCase` | 1 caisse de ravitaillement ou de réquisition | `OnCreate = MilitaryDrop.Recipe.openSupplyCase` (serveur ou solo) |
| `OpenMilitaryAvionicsSalvage`, `OpenMilitaryMechanicalSalvage`, `OpenMilitaryMetalSalvage` | 1 lot récupéré | `OnCreate = MilitaryDrop.Salvage.open` (`SalvageRolls` objets) |
| `SewFultonBalloon` | `Base.Tarp`, 6 `tags[base:thread]`, 2 `Base.Glue`, aiguille et ciseaux gardés | `FultonBalloonFolded` |
| `MakeFultonHarnessBag` | `Base.EmptySandbag` vide, `tags[base:rope]`, 2 `Base.DuctTape`, ciseaux gardés | `FultonHarnessBag` |
| `AssembleFultonKit` | enveloppe, sac, 3 `Base.Wire`, pince gardée | `FultonKit` |
| `RepairFultonKit` | kit endommagé, 4 fils, 2 rubans adhésifs, 2 `Base.Wire`, aiguille et pince gardées | `FultonKit` |
| `SalvageHeliumTank` | bouteille vide (détruite), 2 `Base.BlowTorch`, masque de soudure gardé | 4 `Base.SmallSheetMetal`, 2 `Base.SteelChunk` |

Véhicules (`scripts/vehicles/`) : `Base.MilitaryDrop_SupplyCrate` (caisse sans roues avec coffre), `Base.MilitaryDrop_HeliWreckBurnt` (fuselage : pièces `Avionics`, `RadioRack`, `EngineBay`, `RotorHub`, `SkinPanels`), `Base.MilitaryDrop_HeliTailBurnt` (queue : `SkinPanels`). Sons (`Base`) : `MilitaryDropBayInsert`, `MilitaryDropBayRead`, `MilitaryDropBayDone`, `MilitaryDropFultonFlyby`. Modèles au sol des quatre caisses : `MilitaryDrop_<Ammo|Weapon|Armor|Attachment>Case_Ground`.

Pièces d'épave (`lua/shared/MilitaryDrop/MilitaryDrop_Salvage.lua`, `Salvage.PARTS`) :

| Pièce | Lot | Outil (tag) | Compétence | Après |
|---|---|---|---|---|
| `Avionics` | électronique | `base:screwdriver` | Electricity 2 | — |
| `RadioRack` | électronique | `base:screwdriver` | Electricity 1 | `Avionics` |
| `EngineBay` | mécanique | `base:wrench` | Mechanics 2 | — |
| `RotorHub` | métal | `base:wrench` | Mechanics 1 | `EngineBay` |
| `SkinPanels` | métal | `base:screwdriver` | MetalWelding 1 | `RotorHub` |

Contrôles serveur (`WreckParts`) : véhicule d'épave, personnage vivant au niveau 0 à 7 cases au plus, outil par tag dans l'inventaire, niveau, pièce précédente retirée ; l'installation de pièces est refusée ; la découpe vanilla exige toutes les pièces retirées et un masque de soudure.

Le contenu des caisses et des lots n'utilise **aucun nom d'objet vanilla** : il est tiré des tables `ProceduralDistributions` fusionnées et filtré par catégorie d'affichage, propriétés ou tags (`MilitaryDrop_Loot.lua`, `MilitaryDrop_Lots.lua`, 18 lots dans `Lots.DEFAULTS`).

## Commandes réseau

Module `MilitaryDrop` (`MilitaryDrop.Net.MODULE`). En MP : `sendClientCommand` et `sendServerCommand` ; en solo, `Net` appelle directement le gestionnaire de l'autre côté, si bien que les réponses arrivent pendant l'envoi. Toute commande arrive dans `Server.onClientCommand`, qui appelle `Server.COMMANDS[nom](player, args)` ; un `args` qui n'est pas une table devient `{}`. La cadence (`MilitaryDrop.Guard.throttled`, par joueur et par clé, en millisecondes réelles, en mémoire du serveur) répond `busy` avant toute vérification de radio.

Les radios sont désignées par une référence (`Radio.makeRef`) : `{ kind = "item", id }` ou `{ kind = "world", x, y, z, index }`, résolue et revérifiée par le serveur (`Radio.resolve`, `Radio.status`).

### Client vers serveur

| Commande | Arguments | Gestionnaire | Contrôles serveur |
|---|---|---|---|
| `Request` | `requestId`, `radio`, `force`, `code` | `Server.handleRequest` | Cadence 3 s ; `force` exige `Capability.MakeEventsAlarmGunshot` ; radio militaire à portée, allumée ; canal et code (même réponse `noAnswer` pour les deux) ; silence après 3 codes faux par journée de jeu ; ligne coupée ; délai global multiplié par le facteur de confiance. Statuts : `accepted`, `form`, `busy`, `denied`, `invalid`, `noRadio`, `radioOff`, `notMilitary`, `noAnswer`, `lineCut`, `cooldown` (avec `hours`), `noSite`. |
| `Sync` | — | `Server.COMMANDS.Sync` | Renvoie identité, vols actifs, état des missions. |
| `RequisitionOrder` | `requestId`, `radio`, `order` (lot vers quantité), `decoy`, `sector` | `Requisition.handleOrder` | Cadence 3 s ; autorisation en attente de ce joueur, même `requestId`, non expirée ; radio, canal (sans code), ligne, délai ; lots permis au palier, quantités entières positives, budget ; leurre seul et secteur revalidé ; feuille admin : droit revérifié. |
| `RequisitionCancel` | `requestId` | `Requisition.handleCancel` | Efface l'autorisation si le `requestId` correspond. |
| `ReloadLots` | — | `Requisition.handleReload` | `checkPermissions(player, Capability.ChangeAndReloadServerOptions)` ; cadence 3 s. Réponse `ReloadLotsReply`. |
| `MissionReport`, `MissionDogTags`, `MissionRecon`, `MissionControl`, `MissionCleanupStatus`, `MissionFulton` | `exchangeId`, `radio`, données propres à la source | `Missions.*` | Cadence « exchange » 3 s ; radio militaire allumée sur la fréquence militaire (en main, posée à 2 cases ou poste) ; équipe au moment de l'échange ; ligne coupée ; source activée (gain > 0) ; échéances ; objets possédés (plaques). Réponse `ExchangeReply`. |
| `AdminMission` | `kind` (`recon`, `cleanup`, `control`), `action` (`close` ou absent) | `Missions.adminLaunch` | `Server.canForce` ; cadence 1 s ; réponse `Notice`. |
| `AdminCrashNext` | — | `Flights.adminCrashNext` | `Server.canForce` ; cadence 1 s ; drapeau `nextCrash` de l'état privé. |
| `GroundFire` | — | `Flights.groundFire` | Option `CrashGunfire` ; joueur vivant au niveau 0 ; cadence 500 ms ; arme à feu en main ; vol en approche à 80 cases au plus, devant le joueur ; ni leurre ni largage forcé ; tirage `CrashGunfireChance`. |
| `PostInstall`, `PostOpen`, `PostQuery`, `PostDeposit` (`items`), `PostRecorderInsert` (`item`), `PostRecorderEject` | `radio`, plus le champ indiqué | `Post.*` | Cadence 300 ms par commande ; radio posée éligible (non portable, haut de gamme, émettrice), équipe propriétaire, distance. |
| `PostTransmit`, `PostRecorderTransmit` | `radio` | `Post.transmit`, `Post.transmitRecorder` | Cadence 3 s ; mêmes contrôles, plus radio allumée et alimentée sur le canal militaire. |
| `PostSync` | — | `Post.sync` | Renvoie `PostInfo` (sans cadence). |
| `ZoneList`, `ZoneAdd`, `ZoneUpdate`, `ZoneSetEnabled`, `ZoneDelete`, `ZoneReload` | `requestId`, champs de zone (`id`, `sector`, `name`, `x1`, `y1`, `x2`, `y2`, `weight`, `enabled`, `map`) | `Zones.handleCommand` | `Capability.ChangeAndReloadServerOptions` ; cadence 500 ms ; validation des champs (bornes, côté de 300 cases au plus, coordonnées finies). Réponses `ZoneReply` puis `ZoneListReply`, à l'appelant seulement. |
| `FultonLaunch` | `kitId`, `tankId`, `x`, `y`, `z` | `FultonServer.launch` | Cadence 3 s ; case du kit à `Fulton.REACH` cases et au même étage ; kit trouvé au sol (identifiant et type) ; bouteille non vide dans l'inventaire principal ; ligne ouverte ; source activée ; créneau ouvert ; case extérieure sans arbre ; météo ; hors zone non-PvP et refuge ; kit non vide. |
| `SirenSync` | — | `Decoy.onClientCommand` | Cadence 3 s ; renvoie les sirènes à portée d'écoute. |

Module distinct `MilitaryDropFultonFlight` (menu de test du ballon) : `Sync`, `Start`, `Stop`, `Pause` ; `Start`, `Stop` et `Pause` exigent `Capability.MakeEventsAlarmGunshot` ; serveur MP seulement ; réponse `Snapshot`.

Les actions chronométrées partagées `MilitaryDrop.SirenAction` et `MilitaryDrop.DismantleAction` sont reconstruites par le serveur (actions réseau de la B42) ; leur `complete()` revérifie tout (`Decoy.stopByPlayer`, `Dismantle`). `MilitaryDrop.ExchangeAction` et l'action de lâcher Fulton restent côté client et n'agissent que par leur commande.

### Serveur vers client

| Commande | Destinataires | Arguments | Effet client |
|---|---|---|---|
| `Result` | joueur | `requestId`, `status`, `hours`, `tier`, `callsign`, données du formulaire | Réponse de la base ; `form` ouvre le formulaire. |
| `Dropped` | joueur | `requestId`, `x`, `y` | Coordonnées privées d'un largage forcé. |
| `Notice` | joueur | `key`, `username`, paramètres | Message traduit côté client. |
| `CharacterIdentity` | joueur | `id` (`C:…`), `username`, `index` | Copie l'identifiant du personnage dans sa ModData locale. |
| `ReloadLotsReply` | joueur | résumé, nombre de lots, problèmes | Retour de `ReloadLots`. |
| `ExchangeReply` | joueur | clés et paramètres, `status`, `exchangeId`, `fulton` | Réplique de la base par la radio ; créneau Fulton. |
| `FlightStart`, `FlightSync`, `FlightEnd`, `FlightCrash` | tous (`FlightStart` aussi à un joueur qui arrive) | `Flight.toArgs` : `id`, `sx`, `sy`, `tx`, `ty`, `ex`, `ey`, `elapsed`, `crash` ; `FlightSync` : `id`, `elapsed` ; `FlightCrash` : `id`, `x`, `y` | Hélicoptère local (`Heli`). |
| `DropAnnounce`, `MaydayAnnounce`, `ReconAnnounce`, `CleanupAnnounce` | tous | `x`, `y` ou `grids` ; `id` ; `radius` | Repère de carte, posé seulement si une radio du client reçoit la ligne correspondante (`OnDeviceText`). |
| `CleanupState` | joueur ou tous | état du nettoyage | Grisé de « Faire le point ». |
| `SirenOn`, `SirenOff` | joueurs à portée | `id`, `x`, `y`, `z` ; `final` | Boucle de sirène locale. |
| `PostInfo`, `PostStatus`, `PostData`, `PostResult` | joueur | position du poste ; état de la radio ; données de console ; résultat | Console du poste. |
| `BaySound` | joueurs à portée | `x`, `y`, `z`, `event`, `reading` | Sons de la baie de lecture. |
| `ZoneReply`, `ZoneListReply` | admin appelant | `ok`, `action`, `error`, `requestId` ; liste des zones | Outil des zones. |
| `FultonResult` | joueur | résultat du lâcher | Menu du kit. |
| `WreckSmoke` | tous | `id`, `x`, `y` | Fumée locale de l'épave. |

## Persistance

### ModData globales

| Table | Visibilité | Contenu |
|---|---|---|
| `MilitaryDrop` (`Server.MODDATA_TAG`) | lisible par tout client (`ModData.request`) | `lastDropHours`, `flights` (vols en cours), `pending` (livraisons en attente). Ancien champ `code` effacé à la lecture. |
| `MilitaryDrop_<12 hex>` (`Secrets.privateTag`, dérivé de la graine) | serveur seulement | `drops[dropId]` (`character`, `recoveryFaction`, `requester`, `forced`, `requestedHours`, `order`, `decoy`, `zone`…), `characterTrust[characterId]`, `teams`, `teamPlayers`, `missions` (`reports`, `open`, `nextHours`, `last`, `dogtags.ids`, `fulton.windows`, `characterSchema`, `legacyTeamProgress`), `posts`, `postLogs`, `postMail`, `postBays`, `recorderReads`, `recorderReadsFraction`, `sirens`, `wrecks`, `nextCrash`. |

La ModData globale est relue à chaque usage (`ModData.getOrCreate`) : le moteur la vide et la relit juste avant `OnInitGlobalModData`.

### Nettoyage et état personnel du poste (0.7.1)

`missions.open.cleanup.horde` conserve `ids`, `size`, `dead` (morts reconnues par le suivi), `hours` et ajoute `nearbyDead` (autres morts admissibles dans le cercle) et `cleanupSchema = 2`. La migration initialise `nearbyDead` à zéro sans effacer contributions, signatures, cible ni échéance. La progression commune est `dead + nearbyDead` ; l'objectif fixe est `ceil(size * 0.9)` (au moins 1).

Après apparition et avant échéance : un zombie reconnu par le suivi compte partout ; sinon sa mort compte si `z = 0` et si sa distance au centre `(x + 0.5, y + 0.5)` est au plus le rayon de la mission. `MilitaryDrop_cleanup` dédoublonne les deux chemins. Les morts sans joueur attribuable avancent le total sans contribution personnelle. Récompense unique au meilleur contributeur, égalité au premier à ce compte, selon les règles existantes de ligne coupée et de plafond.

`PostData.exchanges = { reportDone, fultonOpen }` ne concerne que le personnage consultant la console. Les actions utilisent les commandes `Mission*` et le transport `Exchange` existants ; `ExchangeReply` du statut de nettoyage contient contribution personnelle, reste, total commun et cible. La référence par tenue reste non unique, comme avant ; le comptage géographique ne dépend pas de cette reconnaissance.

### ModData d'objets

| Clé | Objet | Valeur |
|---|---|---|
| `MilitaryDrop_dropId` | caisses de ravitaillement et de réquisition, véhicule caisse | identifiant du largage |
| `resetedContainers` | véhicule caisse, épaves | `true` : protège le coffre contre le re-remplissage par d'autres mods |
| `MilitaryDrop_orderRestored` | véhicule caisse | commande déjà restaurée une fois |
| `MilitaryDrop_lot` | caisse de réquisition | identifiant du lot |
| `printMedia` | note, carnet | `{ id, title, info, text }` écrits par le serveur dans sa langue |
| `MilitaryDrop_note`, `MilitaryDrop_codebook` | zombie | tirage déjà fait pour ce zombie |
| `MilitaryDrop_cleanup` | zombie | identifiant de la mission de nettoyage qui l'a compté |
| `MilitaryDrop_postUid` | radio posée du poste | uid du poste |
| `MilitaryDrop_crashSite` | pièces d'épave, enregistreur, corps, zombies d'équipage | identifiant du site |
| `MilitaryDrop_crashX`, `MilitaryDrop_crashY`, `MilitaryDrop_crashClock` | enregistreur de vol | lieu et date du crash |
| `MilitaryDrop_crashSmoke` | `IsoFire` de fumée | identifiant du site |
| `MilitaryDrop_characterId` | `IsoPlayer` | `C:…`, identifiant persistant du personnage (réputation) |

### Fichiers

Tous sous `Zomboid/Lua/` (`getFileReader` et `getFileWriter` ; le moteur limite les extensions à `ini`, `cfg`, `txt`, `log` et `json`).

| Fichier | Côté | Portée | Contenu |
|---|---|---|---|
| `MilitaryDrop/<mode>_<partie>_seed.txt` | serveur ou solo | partie (nom du serveur en MP) | graine (1 à 2^31 − 2) : codes périodiques, table du carnet, fréquences libres, nom de l'état privé. Tirée de nouveau pour un monde neuf (`OnLoadRadioScripts`, second argument). |
| `MilitaryDrop/<mode>_<partie>_code.txt` | serveur ou solo | partie | code fixe (`AuthCode` 2). |
| `MilitaryDrop/requisition.txt` | serveur ou solo | compte système (toutes les parties) | lots du formulaire : table Lua (`version`, `lots`) lue par un analyseur de données sans exécution ; créé au premier démarrage avec les 18 lots par défaut. |
| `MilitaryDrop/dropzones.txt` | serveur ou solo | compte système | zones `{ id, sector, name, x1, y1, x2, y2, weight, enabled, map }`, même lecteur, `version`. |
| `MilitaryDrop/code_<mp ou sp>_<partie>_<compte>_<personnage>.txt` | client | personnage | dernier code saisi (préremplissage, jamais transmis hors appel). |

Format et règles des deux fichiers d'admin : [wiki, Server admin](wiki/en/06-server-admin.md).

### Migrations

- Réputation : passage des notes collectives (v1.3) à la réputation personnelle ; ancienne table `trust` conservée sans transfert ; progression collective des missions rangée dans `missions.legacyTeamProgress` (`characterSchema = 1`).
- Enregistreur de vol : heures acquises converties en fraction (`recorderReadsFraction = 1`).
- Registre des plaques numérotées des essais v1.3 effacé (`dogtags.a`, `b`, `issued`, `used`).
- Épaves : `crewVersion = 1` dans chaque site.

## Traductions

Huit langues : `CN`, `DE`, `EN`, `ES`, `FR`, `PT`, `PTBR`, `RU`, sous `lua/shared/Translate/<LANGUE>/`, en JSON seulement (Build 42.21). L'anglais est la référence : `tests/run_tests.py` exige les mêmes clés et les mêmes paramètres dans chaque langue, et `%%` pour un `%` littéral.

| Fichier | Préfixes de clés | Nombre (EN) |
|---|---|---|
| `IG_UI.json` | `IGUI_MilitaryDrop_*`, `IGUI_VehicleNameMilitaryDrop_*`, `IGUI_VehiclePart<Pièce>` | 523 |
| `Sandbox.json` | `Sandbox_MilitaryDrop`, `Sandbox_MilitaryDrop_<Option>`, `_tooltip`, `_option<N>` | 151 |
| `ItemName.json` | type complet de l'objet (`MilitaryDrop.FultonKit`…) | 19 |
| `Recipes.json` | nom de la recette | 9 |
| `Tooltip.json` | `Tooltip_MilitaryDrop_*` | 13 |
| `GameSound.json` | `GameSound_MilitaryDropBay*` | 3 |

Les textes composés sur le serveur (station de chiffres, notes, documents, journal du poste) le sont dans la langue du serveur ; `ServerTranslations` recharge les traductions sur un serveur MP, qui lit les traductions avant les mods. Les répliques de la base et les messages (`Notice`, `ExchangeReply`, `PostResult`) voyagent en clés et paramètres, traduits par chaque client. Les messages de console sont en anglais, préfixés `[MilitaryDrop]`.

## API Lua et compatibilité

- Points d'extension : `MilitaryDrop.Server.COMMANDS`, `MilitaryDrop.Client.HANDLERS`, `MilitaryDrop.Exchange.HANDLERS`, `MilitaryDrop.Config.onChange(key, names, fn)`, `MilitaryDrop.Loot.CASES[type].sources` (sources de butin remplaçables).
- Fonctions vanilla enveloppées (original toujours appelé) : `ISRadioWindow.createChildren`, `ISAdminPanelUI:create` et `updateButtons`, `ISDebugMenu` (onglet Main), `ISVehicleMenu.FillMenuOutsideVehicle`, `ISUninstallVehiclePart.complete`, `ISInstallVehiclePart.complete`, `ISRemoveBurntVehicle.isValid` et `complete` (sans effet hors des scripts d'épave du mod).
- Compatibilités vérifiées dans le code : Belt Walkie-Talkie, Signal Smoke, HEF (départ retardé, bruits modérés), mods qui re-remplissent les coffres de véhicules (marqueur `resetedContainers`), objets des mods de butin (tirés des tables fusionnées).

## Options du bac à sable

Page `MilitaryDrop`, noms complets `MilitaryDrop.<Option>`, lues à chaque usage (`Config.get` : options Java puis `SandboxVars`) ; un changement en cours de partie est détecté chaque minute de jeu (`Config.poll`). Tableau généré depuis `sandbox-options.txt` et `Translate/FR/Sandbox.json` (64 options).

| Option | Type | Défaut | Bornes / valeurs | Libellé FR | Effet (infobulle FR) |
|---|---|---|---|---|---|
| `CooldownHours` | integer | 168 | 1 à 8760 | Heures entre deux largages | Nombre minimal d'heures de jeu entre deux largages, pour tout le serveur. |
| `Frequency` | double | 0.0 | 0.0 à 1000.0 | Fréquence militaire (MHz) | 0 : une fréquence libre entre 120 et 170 MHz, tirée par le serveur pour cette partie et écrite sur les notes militaires (à trouver par les joueurs). Une valeur fixe est visible par tous les joueurs. Arrondie au pas de réglage des radios (0,2 MHz). 112,2 MHz est réservée. (redémarrage requis) |
| `DropMinDistance` | integer | 150 | 0 à 3000 | Distance minimale du largage | Distance minimale en cases entre le joueur qui appelle et le point de largage, tiré au hasard. |
| `DropMaxDistance` | integer | 400 | 0 à 3000 | Distance maximale du largage | Distance maximale en cases entre le joueur qui appelle et le point de largage. |
| `DropRepeatHours` | integer | 6 | 0 à 168 | Rappel de la grille toutes les (heures) | Heures de jeu entre deux rappels, sur la fréquence militaire, de la grille d'un largage dont aucune caisse de ravitaillement n'a été ouverte. Les rappels cessent quand une caisse est ouverte, ou après les heures pour récupérer un largage. 0 = aucun rappel. |
| `DropPlacement` | enum | 1 | 1 Près du demandeur; 2 Zones de largage; 3 Zones si l'une est proche | Placement des largages | Près du demandeur : un point tiré entre les distances minimale et maximale. Zones de largage : dans une zone tracée par l'admin (Zomboid/Lua/MilitaryDrop/dropzones.txt, ou l'outil d'admin) ; sans zone utilisable, une ville vanilla, sinon près du demandeur. Zones si l'une est proche : une zone plus proche que la portée des zones ci-dessous, sinon près du demandeur. |
| `DropZoneChoice` | enum | 1 | 1 Le plus proche du demandeur; 2 Au hasard; 3 Choisi par le joueur | Secteur des zones de largage | Quel secteur (groupe de zones, en général une ville) reçoit le largage : le plus proche du demandeur, un secteur au hasard, ou celui que le joueur choisit sur le formulaire de réquisition (champ « Secteur de largage » ; sans formulaire de réquisition, le plus proche). Une zone de ce secteur est ensuite tirée au hasard, selon son poids. |
| `DropZoneMinDistance` | integer | 0 | 0 à 5000 | Distance minimale des zones de largage | Les zones à moins de ce nombre de cases du demandeur sont écartées : personne ne peut appeler depuis une zone pour se servir aussitôt. Si toutes les zones sont plus proches, le secteur le plus proche est retenu. 0 : aucune distance minimale. |
| `DropZoneMaxDistance` | integer | 1500 | 100 à 20000 | Portée des zones de largage | Avec « Zones si l'une est proche » : seules les zones à moins de ce nombre de cases du demandeur sont utilisées ; s'il n'y en a aucune, la caisse tombe près du demandeur. |
| `DropZoneAnnounceName` | boolean | true | — | Annoncer le nom de la zone | L'annonce radio et ses rappels donnent le nom de la zone de largage avant la grille. Désactivé : la grille seule, comme près du demandeur. |
| `AuthCode` | enum | 4 | 1 Aucun; 2 Code fixe, en clair sur les notes; 3 Code périodique, en clair sur les notes; 4 Code périodique, chiffré (station de chiffres et carnet) | Code d'authentification | Ce que les joueurs doivent donner à la radio pour obtenir un largage. Un code périodique change chaque semaine, toutes les deux semaines ou chaque mois (option Changement du code, calendrier du jeu) et le précédent reste accepté pendant 24 heures. Après 3 codes faux dans la journée, la base ignore l'appelant jusqu'au lendemain. |
| `CodePeriod` | enum | 1 | 1 Chaque semaine (lundi); 2 Toutes les deux semaines (un lundi sur deux); 3 Chaque mois (le 1er) | Changement du code | Quand le code périodique (en clair ou chiffré) change, selon le calendrier du jeu : chaque lundi à 00:00, un lundi sur deux à 00:00, ou le 1er de chaque mois à 00:00. Le précédent reste accepté pendant 24 heures. Sur les serveurs où les jours de jeu passent vite, le changement mensuel évite de chercher un nouveau code chaque jour réel. |
| `NumbersStationFrequency` | double | 0.0 | 0.0 à 1000.0 | Fréquence de la station de chiffres (MHz) | 0 : une fréquence libre des ondes courtes, entre 10 et 25 MHz, choisie pour cette partie (radios militaires, radios de radioamateur et meilleur talkie-walkie civil). Jamais la fréquence militaire ni 112,2 MHz. Code périodique chiffré seulement. (redémarrage requis) |
| `MinZombies` | integer | 3 | 0 à 1000 | Zombies au largage (minimum) | Si le minimum et le maximum valent 0, aucun zombie n'apparaît. |
| `MaxZombies` | integer | 30 | 0 à 1000 | Zombies au largage (maximum) | Nombre maximal de zombies qui apparaissent autour de la caisse. |
| `CaseRolls` | integer | 6 | 1 à 100 | Caisses par largage | Nombre de tirages de butin pour la caisse : chaque tirage peut ajouter une caisse de ravitaillement. |
| `NoteDropRate` | enum | 4 | 1 Extrêmement rare (1/1000); 2 Très rare (1/500); 3 Rare (1/100); 4 Normale (1/50); 5 Courante (1/25); 6 Débogage (1/2) | Fréquence des notes militaires | Chance qu'un zombie mort porte une note avec la fréquence militaire et, selon l'option du code, le code ou la fréquence de la station de chiffres. |
| `NotesOnlyArmyPolice` | boolean | true | — | Notes seulement sur les zombies militaires et policiers | Seuls les zombies dont la tenue correspond à la liste ci-dessous peuvent porter les notes. |
| `NoteOutfits` | string | Army;Police;Sheriff | — | Tenues qui portent les notes | Mots cherchés dans le nom de la tenue du zombie, séparés par ; (reconnaît aussi les tenues des autres mods). |
| `NoteOutfitsExcluded` | string | Stripper | — | Tenues exclues | Les tenues qui contiennent un de ces mots ne portent jamais de note, séparés par ;. |
| `CodebookDropRate` | enum | 3 | 1 ?; 2 ?; 3 ?; 4 ?; 5 ?; 6 ? | Fréquence des carnets de codes | Chance qu'un zombie militaire mort porte un carnet de codes ; règle aussi leur fréquence dans les réserves de l'armée. Code périodique chiffré seulement. |
| `CodebookOutfits` | string | Army | — | Tenues qui portent les carnets | Mots cherchés dans le nom de la tenue du zombie, séparés par ;. Les tenues exclues s'appliquent aussi. |
| `CrateSmokeMinutes` | integer | 60 | 0 à 1440 | Fumée sur la caisse (minutes) | Nécessite le mod Signal Smoke : une fumée verte marque la caisse posée pendant ce nombre de minutes de jeu. 0 : aucune fumée. Sans Signal Smoke, cette option n'a aucun effet. |
| `TrustDailyCap` | integer | 10 | 0 à 100 | Plafond quotidien de confiance | Confiance maximale gagnée par chaque personnage par jour de jeu, hors largages. 0 : seuls les largages font varier la confiance. |
| `TrustPostBonus` | integer | 50 | 0 à 500 | Bonus du poste de liaison (pour cent) | Confiance supplémentaire, en pourcentage et arrondie, pour les échanges faits depuis le poste de liaison de la station. Toujours limitée par le plafond quotidien. 0 : aucun bonus. |
| `TrustLineCutDays` | integer | 3 | 0 à 30 | Ligne coupée (jours) | Nombre de jours pendant lesquels la base refuse un personnage dont la confiance passe sous 15. Les autres personnages ne sont pas affectés. 0 : jamais coupée. |
| `TrustDropLostHours` | integer | 48 | 1 à 720 | Heures pour récupérer un largage | Heures de jeu après la pose de la caisse. Si aucune caisse de ravitaillement du largage n'a été ouverte d'ici là, le largage est perdu et la station qui l'a demandé perd de la confiance. |
| `TrustErosion` | boolean | false | — | Érosion de la confiance | Chaque jour de jeu sans aucun échange avec la base, la confiance d'une station revient d'un point vers sa valeur de départ (25). |
| `ReportGain` | integer | 1 | 0 à 20 | Confiance : rapport de situation quotidien | Confiance pour le premier rapport quotidien de chaque personnage. 0 désactive les rapports. |
| `DogTagGain` | integer | 2 | 0 à 20 | Confiance : matricule annoncé | Confiance gagnée pour chaque plaque de soldat tombé annoncée à la base (le jeu y inscrit son nom). Chaque matricule ne compte qu'une fois et la plaque est mise de côté ; votre propre plaque et les plaques vierges ne comptent pas. 0 désactive les plaques. |
| `ReconGain` | integer | 3 | 0 à 20 | Confiance : reconnaissance | Confiance gagnée par la première station qui confirme une reconnaissance depuis la grille annoncée (25 cases au plus). 0 désactive les reconnaissances. |
| `ReconHours` | integer | 48 | 1 à 720 | Échéance de la reconnaissance (heures) | Heures de jeu pour confirmer une reconnaissance. |
| `ReconIntervalHours` | integer | 24 | 1 à 720 | Heures entre deux reconnaissances | Heures de jeu après la clôture d'une reconnaissance avant la suivante (à 25 pour cent près). |
| `CleanupGain` | integer | 5 | 0 à 20 | Confiance : nettoyage | Gain au meilleur contributeur à l'objectif commun, selon le comptage mixte décrit plus haut. 0 désactive les nettoyages. |
| `CleanupHours` | integer | 72 | 1 à 720 | Échéance du nettoyage (heures) | Heures de jeu pour atteindre l'objectif commun. |
| `CleanupQuota` | integer | 30 | 1 à 1000 | Taille de la horde du nettoyage | Horde déployée à l'arrivée. Objectif fixe à 90 pour cent de la taille réelle, arrondis au supérieur ; les morts ambiantes au sol dans le cercle comptent aussi. |
| `CleanupIntervalHours` | integer | 48 | 1 à 720 | Heures entre deux nettoyages | Heures de jeu après la clôture d'un nettoyage avant le suivant (à 25 pour cent près). |
| `ControlGain` | integer | 1 | 0 à 20 | Confiance : appel de contrôle | Confiance pour chaque personnage qui confirme à temps un appel de contrôle, une fois par personnage. 0 désactive les appels de contrôle. |
| `ControlHours` | integer | 4 | 1 à 72 | Durée de l'appel de contrôle (heures) | Heures de jeu pour confirmer la réception. |
| `ControlIntervalHours` | integer | 24 | 1 à 720 | Heures entre deux appels de contrôle | Heures de jeu après la clôture d'un appel de contrôle avant le suivant (à 25 pour cent près). |
| `RequisitionForm` | boolean | true | — | Formulaire de réquisition | Après un appel valide, le demandeur remplit un formulaire de réquisition et choisit ses fournitures avec un budget de points. Désactivé : caisses de ravitaillement aléatoires, comme avant. Les largages admin n'utilisent jamais le formulaire. |
| `RequisitionBudget` | integer | 100 | 10 à 300 | Budget de réquisition (pour cent) | Ajuste le budget de points du formulaire. À 100 : 8 points à la confiance 25, 12 à 50, 16 à 75, 20 à 100. Les points non dépensés sont perdus. |
| `RequisitionCostMultiplier` | integer | 100 | 10 à 300 | Coûts de réquisition (pour cent) | Ajuste le coût de chaque lot, arrondi, au moins 1 point. |
| `RequisitionTier2` | integer | 50 | 0 à 100 | Confiance des lots du deuxième palier | Confiance nécessaire pour commander munitions, armes de mêlée, protection, mécanique, transmissions, semences, instruction et paquetage. |
| `RequisitionTier3` | integer | 75 | 0 à 100 | Confiance des lots du troisième palier | Confiance nécessaire pour commander armes à feu, accessoires d'armes, explosifs et carburant. |
| `RequisitionExplosives` | boolean | true | — | Explosifs en réquisition | Permet de commander des explosifs dans le formulaire de réquisition. |
| `DecoyEnabled` | boolean | true | — | Largage leurre | Le formulaire de réquisition propose un largage leurre : une caisse à sirène qui attire les morts dans un secteur choisi. Rien ne le distingue d'un vrai largage. |
| `DecoyCost` | integer | 3 | 1 à 20 | Coût du leurre (points) | Points de réquisition dépensés pour un largage leurre. |
| `DecoySirenHours` | integer | 6 | 1 à 72 | Durée de la sirène du leurre (heures) | Heures de jeu pendant lesquelles la sirène du leurre hurle après la pose de la caisse, jusqu'à l'épuisement de ses piles. Un joueur peut la couper avant. |
| `DecoyNoiseRadius` | integer | 120 | 50 à 300 | Portée du bruit de la sirène (cases) | Distance à laquelle les zombies entendent la sirène du leurre. Seulement quand la zone autour de la caisse est chargée. |
| `DebugLog` | boolean | false | — | Journal de débogage | Écrire les messages détaillés de Military Drop dans le journal de la console. |
| `CrashChance` | integer | 5 | 0 à 100 | Risque de crash | Probabilité en pourcentage par vol de ravitaillement. 0 désactive les pannes aléatoires ; vols admin et leurres exclus. |
| `CrashStormBonus` | integer | 15 | 0 à 100 | Bonus de crash en cas d’orage | Points de pourcentage supplémentaires pendant un orage ; total plafonné à 100. |
| `CrashGunfire` | boolean | false | — | Hélicoptères abattables par les joueurs | Désactivé par défaut. Les tirs proches dirigés vers un hélicoptère de ravitaillement peuvent l’abattre. Le serveur vérifie arme, distance et cadence. |
| `CrashGunfireChance` | integer | 10 | 0 à 100 | Risque de crash sous les tirs | Probabilité en pourcentage par signalement de tir plausible, si les tirs sont activés. |
| `CrashFire` | enum | 3 | 1 Aucun; 2 Fumée; 3 Feu et fumée | Effets du crash | Aucun effet, fumée, ou feu et fumée. Le feu respecte les options du monde et peut se propager. |
| `CrashSmokeMinutes` | integer | 60 | 0 à 1440 | Fumée du crash (minutes) | Minutes de jeu pendant lesquelles la fumée est renouvelée pour les arrivants. 0 désactive la fumée. |
| `CrashCrates` | boolean | false | — | Ravitaillement survivant au crash | Désactivé par défaut. Livre les fournitures commandées sur le site du crash ; sinon seule la récupération d’épave reste. Un crash ne pénalise jamais la réputation. |
| `SalvageRolls` | integer | 3 | 1 à 20 | Objets par lot de récupération | Objets tirés dans le jeu et les mods par lot ouvert : électronique, mécanique ou métal. |
| `PilotOutfits` | string | Army | — | Mots des tenues du pilote | Fragments de noms de tenues séparés par des points-virgules. Aucun résultat : tenue aléatoire. |
| `PilotDocuments` | boolean | true | — | Documents sur le pilote | Ajoute une note militaire et le carnet de codes de la partie sur le corps du pilote. |
| `FultonValue` | integer | 100 | 0 à 500 | Fulton : récompense (pour cent) | Confiance payée pour le renseignement et le matériel envoyés par Fulton, en pourcentage du barème. Toujours limitée par le plafond quotidien, sauf le remède (Zombie Virus Vaccine). 0 : extractions Fulton désactivées. |
| `FultonWindowMinutes` | integer | 30 | 5 à 240 | Fulton : créneau de passage (minutes) | Minutes de jeu pendant lesquelles un Fulton peut être lâché après une demande de passage par radio. |
| `FultonLootRate` | integer | 100 | 0 à 500 | Fulton : fréquence dans le butin (pour cent) | Fréquence des bouteilles d'hélium et des kits Fulton endommagés dans le monde, les épaves et les caisses de largage. 0 : aucun. |
