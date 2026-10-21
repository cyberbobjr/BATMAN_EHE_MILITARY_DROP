# Idée 12 — Fulton : conception détaillée

Conception du 2026-10-07 pour la Build 42.21, à partir des décisions de l'utilisateur ([idee-12-fulton.md](idee-12-fulton.md), §5 et §6) et de quatre relevés en lecture seule : sons, prototype, butin, détection des objets vanilla, échanges radio et confiance.
- **[C]** : confirmé statiquement (fichier:ligne) ;
- **[P]** : proposition de conception, qui ne vient pas d'une décision de l'utilisateur ;
- **⚠** : point à vérifier pendant le codage.

**Rien n'est codé au-delà de FULTON-02 à FULTON-05** (objets et recettes).

Chemins abrégés :
- `M/` = `Contents/mods/batman_MilitaryDrop/42.21/media/` ;
- `V/` = dossier `media` du jeu installé.

## 1. Parcours du joueur

1. **Préparer.** Le joueur fabrique ou répare un kit d'extraction Fulton, puis le remplit comme un sac avec ce qu'il veut envoyer. Il emporte aussi une bouteille d'hélium non vide.
2. **Demander un passage.** Dans le module « Logistique » d'une radio militaire (en main, ou posée à 2 cases au plus), il choisit « Demander un passage Fulton ». La base ouvre un **créneau immédiat de 30 minutes de jeu** pour ce personnage.
3. **Lâcher.** Pendant le créneau, il se place dehors, à ciel ouvert, puis choisit « Gonfler et lâcher le Fulton » sur le kit. Une fenêtre de confirmation affiche :
   - la valeur estimée de l'envoi ;
   - le plafond qui reste pour la journée ;
   - les objets qui ne seront pas payés.
4. **Gonfler.** L'action dure environ 10 s et fait du bruit (sifflement). Une attaque l'interrompt.
5. **Enlèvement.** Le ballon monte (animation du prototype, 3 s), puis l'avion l'accroche (1,5 s) avec le son de passage. La chaîne militaire annonce le passage et son secteur.
6. **Paiement.** Le serveur détruit le kit et son contenu, consomme une charge d'hélium et crédite la confiance. La base accuse réception par radio : gain, objets non payés, plafond atteint.

## 2. Objets admis et barème (FULTON-08, FULTON-09)

Toutes les valeurs sont multipliées par l'option `FultonValue` (§7). Seuls les objets **directement** dans le kit comptent. Un conteneur imbriqué et son contenu sont détruits sans gain **[P]**. Tout part avec le kit : un objet envoyé ne peut pas être renvoyé, donc aucun registre d'unicité n'est nécessaire. C'est une différence avec les plaques (SRC-02), qui sont transmises par radio et que l'on garde.

### 2.1 Renseignement vanilla

| Objet | Règle de reconnaissance | Valeur |
|---|---|---|
| Pièce d'identité nominative | Tag `base:applyownername`, et soit le tag `base:idcard`, soit l'un des types d'identité `Base.Passport`, `Base.PressID`, `Base.Badge`, `Base.KeyRing_SecurityPass`. Le nom affiché (`getDisplayName`) diffère du nom du script, et le nom qui suit le séparateur n'est pas celui du joueur qui envoie (prénom et nom de son descripteur, comme `Exchange.isDogTag`, `M/lua/shared/MilitaryDrop/MilitaryDrop_Exchange.lua:158-192`) | +3 |
| Papiers | Types `Base.Paperwork` et `Base.OfficialDocument`. Aucun tag n'existe pour eux **[C]** (`V/scripts/generated/items/literature.txt:4788`, `:4880`) | +1 |
| Carte-cachette | `item:getStashMap() ~= nil`, champ posé par `StashSystem.doStashItem` et sauvegardé **[C]** (`StashSystem.java:149-180`, `InventoryItem.java:1609-1611`) | +4 |

**Exclusions confirmées**
- **Carte volée** : `IDcard_Stolen` n'a pas `applyownername` **[C]** (`literature.txt:4812`).
- **Carte vierge** : `IDcard_Blank` n'a pas `base:idcard` **[C]** (`literature.txt:4823`).
- **Carte ordinaire** : non payée. Les annotations d'un joueur ne sont pas lisibles côté serveur **[C]** (`MapItem.getSymbols` est `@HiddenFromLua`, `MapItem.java:149-152`) ; décision du 2026-10-07.

**Limites**
- **Origine de la carte** : le jeu ne distingue pas une carte prise sur un mort (renommée par `nameAfterDescriptor`, `InventoryItem.java:4768-4775`) d'une carte de butin nommée au hasard (`ItemCodeOnCreate.onCreateIDCard`, `ItemCodeOnCreate.java:103-121`). Les deux sont acceptées.
- ⚠ **Séparateur du nom** : il dépend de la langue pour une carte de butin (EN `%1: %2`, FR `%1 ("%2")`). Pour exclure le nom du joueur, chercher son nom complet dans le nom affiché plutôt que découper le texte.
- ⚠ **`KeyRing_SecurityPass`** est un conteneur (`container.txt:4455`). Il faut vérifier qu'il peut entrer dans un autre conteneur. Si ce n'est pas le cas, le retirer de la liste.

### 2.2 Matériel NRBC militaire

L'ordre des tests compte : `HazmatSuit` porte aussi `base:scba` **[C]** (`clothing.txt:19612`).

| Tag | Objets vanilla [C] | Valeur |
|---|---|---|
| `base:hazmatsuit` | `HazmatSuit` | +6 |
| `base:scba` | `SCBA` | +2 [P] |
| `base:gasmask` | `Hat_GasMask`, `Hat_NBCmask` (avec ou sans filtre posé) | +2 |
| `base:gasmaskfilter` | `GasmaskFilter`, `GasmaskFilterCrafted` | +1 |

**Exclus** (décision du 2026-10-07) :
- `base:gasmasknofilter` ;
- `base:respirator`, `base:respiratorfilter` ;
- `base:improvisedgasmask`.

La valeur de l'ARI (`SCBA`, +2) n'a pas été décidée : à confirmer.

### 2.3 Zombie Virus Vaccine (compatibilité facultative)

- **Activation** : `getActivatedMods():contains("ZVirusVaccine42BETA")`, puis existence de chaque type (`getScriptManager():FindItem`). Si le mod est absent, la table est vide.
- **Noms de types** : relevés dans la variante 42.20 du mod (Workshop 3615135168, `LabItems.txt`), en lecture seule. ⚠ À revérifier au codage et après chaque mise à jour du mod.

| Types `LabItems.*` | Valeur |
|---|---|
| `MatInfectedBlood`, `MatTaintedBlood`, `CmpSyringe[Reusable]WithBlood`, `CmpSyringe[Reusable]WithTaintedBlood` | +1 |
| `CmpSyringe[Reusable]WithBrainFluidLow` / `Mid` / `High` | +2 / +3 / +4 |
| `HumanBrainLow`, `HumanBrainMid`, `HumanBrainHigh` | +3 |
| `RottenHumanBrain`, `BurntHumanBrain` | 0 |
| `CmpSyringe[Reusable]WithPlainVaccine` / `QualityVaccine` / `AdvancedVaccine` | +5 / +7 / +10 |
| `CmpSyringe[Reusable]WithCure` | **+25 hors plafond** |

### 2.4 Plafond

- Les gains plafonnés passent par **une seule** source `fulton`, ce qui donne un seul écrêtage au plafond (`TrustDailyCap`, 10 par défaut).
- Le remède passe par une source exemptée `fultonCure`. Aujourd'hui, la liste des sources hors plafond est écrite en dur (`source ~= "drop" and source ~= "recorder"`, `M/lua/server/MilitaryDrop/MilitaryDrop_Trust.lua:212`) **[C]**. On la remplace par une table `Trust.UNCAPPED = { drop, recorder, fultonCure }`, sans changer le comportement existant.
- **Bonus du poste** (`opts.fromPost`) : il ne s'applique pas. Le lâcher se fait dehors, loin du poste **[P]**.
- **Valeur perdue** : ce qui dépasse le plafond est perdu, puisque les objets partent. La confirmation (§1, étape 3) l'annonce avant le lâcher.

## 3. Rendez-vous radio (FULTON-06)

**Nouvelle source d'échange `fulton`**
- `Exchange.COMMANDS.fulton = "MissionFulton"` (`MilitaryDrop_Exchange.lua:55-62`).
- Une source sans option de gain est considérée comme désactivée (`Exchange.isEnabled`, l.96-106) **[C]**. C'est pourquoi `FultonValue` est déclarée dans `Exchange.GAIN_OPTIONS`.
- Côté client, une entrée dans `Menu.OPTIONS` (`M/lua/client/MilitaryDrop/MilitaryDrop_ExchangeMenu.lua:45-59`) ajoute le bouton au module « Logistique ». Le module ne l'affiche pas en mode poste (`MilitaryDrop_RadioModule.lua:431-435`) : depuis le poste, on utilise sa radio en mode normal **[P]**.

**Côté serveur, `Missions.fulton(player, args)`** dans `MilitaryDrop_Missions.lua`
- Elle réutilise `begin()`, qui fait les contrôles communs :
  - cadence ;
  - radio militaire allumée, en main ou posée ;
  - ligne coupée ;
  - source désactivée.
- Puis :
  - **aucun créneau ouvert** : `state().fulton.windows[characterId] = { opened, deadline = now + FultonWindowMinutes/60, teamId }`, puis la réponse `Reply_FultonOpen` (passage possible pendant %1 minutes) ;
  - **créneau déjà ouvert** : la réponse `Reply_FultonPending` donne le temps restant ;
  - **dans les deux cas**, la réponse transmet au client `deadline` et le plafond restant (`dailyLeft`) pour l'infobulle et la confirmation.
- **Fin du créneau** :
  - à l'échéance, contrôlée paresseusement au lâcher ;
  - par un nettoyage sur `EveryOneMinute`. `EveryTenMinutes` serait trop grossier pour 30 minutes.
  - Un créneau perdu n'entraîne aucune pénalité.
- **Persistance** : `MilitaryDrop.Secrets.privateState()`, relu à chaque usage (`MilitaryDrop_Secrets.lua:118-123`) **[C]**.
- **Journal du poste de l'équipe** : il suit `reply()` (`MilitaryDrop_Missions.lua:209-215`).

## 4. Le lâcher (FULTON-07)

### 4.1 Le kit devient un conteneur

- `FultonKit` passe en `ItemType = base:container` (capacité 10 **[P]**, aucune réduction de poids).
- ⚠ Relever les clés `Capacity` et `WeightReduction` sur un sac vanilla 42.21.
- Aucune sauvegarde n'est concernée : l'objet n'a jamais été publié.
- Le kit endommagé reste un objet simple.

### 4.2 Côté client

**Menu.** Clic droit sur un `FultonKit` de l'inventaire principal → « Gonfler et lâcher le Fulton ». L'entrée est grisée, avec une infobulle qui donne la raison, dans ces cas :
- aucun créneau ouvert, ou créneau expiré ;
- pas dehors, ou case couverte (`square:isOutside()`, ⚠ toit et étage) ;
- arbre sur la case (`square:getTree()`) ;
- orage ou vent violent (⚠ API `getClimateManager()` 42.21 à relever : intensité du vent, orage en cours) ;
- kit vide ;
- aucune bouteille d'hélium non vide dans l'inventaire.

**Confirmation** (modale du jeu) :
- valeur calculée par la fonction partagée de classement ;
- plafond restant reçu au rendez-vous ;
- liste des objets non payés.

**Action chronométrée `MilitaryDrop.FultonLaunchAction`** :
- environ 10 s, animation de manipulation ;
- son de sifflement local et bruit pour les zombies (`addSound`, rayon 15 **[P]**, ⚠ son de fuite de gaz vanilla à relever) ;
- en fin d'action : `Net.toServer(player, "FultonLaunch", { kitId = kit:getID(), tankId })`.

### 4.3 Côté serveur

`Server.COMMANDS.FultonLaunch` (`MilitaryDrop_Server.lua:953-974`) **[C]**, contrôlé par `Guard.throttled`, revérifie tout :
- le kit et la bouteille sont dans l'inventaire du joueur (`getItemById`) ;
- le créneau du personnage est ouvert ;
- la ligne n'est pas coupée ;
- dehors, sans arbre, météo ;
- hors zone non-PvP et hors refuge (`ZonesFile.overlapsNonPvp` et `overlapsSafehouse` sur la case, `MilitaryDrop_ZonesFile.lua:412-432`) **[C]**.

Il classe ensuite le contenu, puis :
1. consomme une charge d'hélium (`Use()` sur l'autorité, `syncItemFields`) ;
2. retire le kit et son contenu (`container:Remove`, `sendRemoveItemFromContainer`, comme `consume`, `MilitaryDrop_Missions.lua:355-363`) ;
3. crédite `Trust.add(id, plafonné, "fulton")` et, s'il y a lieu, `Trust.add(id, remède, "fultonCure")` ;
4. ferme le créneau ;
5. lance le vol (§5) et l'annonce ;
6. répond `Reply_FultonReceived` (gain, objets non payés, plafond).

Les objets ne sont pas posés au sol : aucun doublon possible quand une case se décharge.

## 5. Vol, annonce et son

**Vol** (reprise du prototype)
- La création d'un vol est extraite de `Server.onClientCommand` (`MilitaryDrop_FultonPrototypeServer.lua:322-365`) dans une fonction `startFlight(x, y, z)`, **attachée à une position** et non plus au joueur. Le vol survit ainsi à la déconnexion ou à la mort.
- La diffusion `Snapshot` et le rendu client sont repris tels quels.
- En solo, un gestionnaire `Client.HANDLERS.FultonFlight` démarre le vol local par le même chemin (`Net.toAll`).
- Le menu de test du prototype n'est disponible qu'en mode `-debug`.

**Annonce**
- Nouvelle fonction `Broadcast.fulton(x, y)` sur le modèle de `Broadcast.mayday` (position arrondie à 50 cases, `MilitaryDrop_Broadcast.lua:167`).
- Texte `IGUI_MilitaryDrop_BroadcastFulton` : « passage d'extraction, grille %1/%2 ». En mode zones, si le point est dans une zone, son nom de zone est ajouté. Il n'existe pas aujourd'hui de texte d'annonce « secteur » **[C]**.
- Marqueur de carte pour ceux qui entendent, comme `DropAnnounce` **[P]**.

**Son**
- Aucun son d'avion vanilla **[C]** : le seul son aérien est `Helicopter` (`V/scripts/generated/sounds/sounds_meta.txt:3-10`).
- Décision de l'utilisateur : un son libre de droits trouvé en ligne. Source retenue : « ATR 72 (AT72) plane flyby at 300 m altitude », par Hoscalegeek, Freesound 315660, licence **CC0**, bimoteur à hélices, WAV stéreo 44,1 kHz de 78 s.
  - **Fait le 2026-10-07** : l'utilisateur a copié l'aperçu Freesound (`source/sound/originals/315660_2506497-lq.mp3`, MP3 24 kHz, 78,7 s). L'analyse place le passage au plus près à 44,1 s, avec un effet Doppler (135 Hz → 110 Hz).
  - `source/sound/make_fulton_sound.py` extrait 40,35 → 58 s (17,65 s, mono, passe-haut à 40 Hz, pic à -1 dBFS, fondus de 1,5 et 4 s). Le pic du passage tombe à 3,8 s, au milieu de la phase d'accroche, **à condition que le son démarre avec le vol**.
  - Le son est déclaré sous le nom `MilitaryDropFultonFlyby` (catégorie `World`, `distanceMax = 400`), dans `common/media/sound/MilitaryDrop/`. Crédit dans `source/sound/CREDITS.md`.
- **Lecture** : chez chaque client, sur un émetteur placé haut (z = 20, comme `MilitaryDrop_Heli.lua:24-25, 49-57`), au début de la phase d'accroche. Utiliser `playSoundImpl` local, jamais `playSound` relayé (`MilitaryDrop_Heli.lua:225-227`) **[C]**.
- **Zombies** : bruit de passage (`addSound`, rayon 40 **[P]**) au point de lâcher. L'extraction est un risque.

## 6. Butin (FULTON-10)

**Insertion dans les listes**
- Sur le modèle du carnet de codes : insertion sans doublon dans les listes procédurales sur `OnInitGlobalModData`, puis `ItemPickerJava.Parse()` (`M/lua/server/MilitaryDrop/MilitaryDrop_Notes.lua:58, 246-279, 356`) **[C]**.
- Poids multipliés par `FultonLootRate`.

| Objet | Liste (vanilla 42.21) [C] | Poids [P] |
|---|---|---|
| Bouteille d'hélium | `GiftStoreToys` : magasins de cadeaux et de jouets, et leurs réserves. Il n'existe aucune salle de magasin de fêtes | 1,5 |
| | `ArmyStorageMedical` : contient déjà `Oxygen_Tank` à 1 | 1 |
| | `ArmyBunkerStorage` | 0,5 |
| Kit endommagé | `ArmyStorageElectronics` | 0,3 |
| | `ArmyBunkerStorage` | 0,3 |

- **Liste à éviter** : `ArmyHangarTools`, `ArmyHangarMechanics` et `ArmyHangarOutfit` ne sont citées par aucune salle. Y insérer un objet n'aurait aucun effet **[C]**.
- ⚠ **Poids de la bouteille** : avec 6 kg, un objet trop lourd peut interrompre le remplissage d'un conteneur (`.claude/pz-knowledge/loot-distributions.md`, objet trop lourd). Mesurer en jeu.

**Épave Mayday**
- Un kit endommagé avec une chance de 25 % **[P]**, dans le conteneur du pilote (`Wreck.pilot`, `MilitaryDrop_Wreck.lua:105-135`).
- Rendu idempotent par une clé `component(site, "fulton", …)`.

**Caisses de largage**
- Sans commande seulement, et pas pour une réquisition ni un leurre.
- 5 % **[P]** de chance d'ajouter un kit endommagé au coffre (`Crate.contentsFor`, `MilitaryDrop_Crate.lua:105`).

## 7. Options sandbox (8 langues)

| Option | Type | Défaut | Rôle |
|---|---|---|---|
| `FultonValue` | entier, en % | 100 | Multiplie le barème. 0 désactive la source et le bouton radio. |
| `FultonWindowMinutes` | entier, en minutes de jeu | 30 | Durée du créneau. |
| `FultonLootRate` | entier, en % | 100 | Multiplie les poids de butin, l'épave et les caisses. 0 : aucun objet Fulton dans le monde. |

Ces options sont lues à chaud par `Config.get` (OPT-02). Le butin est rafraîchi comme pour le carnet de codes (`refreshCodebookLoot`).

## 8. Fichiers prévus

| Fichier | Contenu |
|---|---|
| `M/lua/shared/MilitaryDrop/MilitaryDrop_Fulton.lua` | Classement et barème, compatibilité Vaccine, conditions de lâcher partagées. Fonctions pures, testables. |
| `M/lua/server/MilitaryDrop/MilitaryDrop_FultonServer.lua` | Commande `FultonLaunch`, paiement, vols (reprise de `FultonPrototypeServer`), butin |
| `M/lua/client/MilitaryDrop/MilitaryDrop_FultonMenu.lua` | Menu du kit, confirmation, action chronométrée |
| `M/lua/client/MilitaryDrop/MilitaryDrop_Fulton.lua` | Rendu, renommé depuis `FultonPrototype`, et son de passage |
| `MilitaryDrop_Missions.lua`, `MilitaryDrop_Exchange.lua`, `MilitaryDrop_ExchangeMenu.lua` | Source radio `fulton` |
| `MilitaryDrop_Trust.lua` | Table `UNCAPPED` |
| `MilitaryDrop_Broadcast.lua` | Fonction `Broadcast.fulton` |
| `MilitaryDrop_Wreck.lua`, `MilitaryDrop_Crate.lua` | Butin rare |
| `scripts/MilitaryDrop_Fulton.txt`, `MilitaryDrop_sounds.txt`, `sandbox-options.txt`, traductions | Kit en conteneur, son, options, textes |

## 9. Tests

**Tests `lupa`**
- **Classement** :
  - chaque catégorie ;
  - exclusions : carte du joueur, carte volée, carte vierge, carte ordinaire, masque sans filtre, respirateur, masque bricolé, cerveau pourri ;
  - Vaccine absent ;
  - `HazmatSuit` compté une seule fois ;
  - conteneur imbriqué.
- **Paiement** :
  - écrêtage au plafond ;
  - remède hors plafond ;
  - `FultonValue` à 0 et à 200.
- **Créneau** :
  - ouverture et redemande ;
  - échéance ;
  - lâcher hors créneau refusé ;
  - persistance au rechargement.
- **Lâcher** :
  - kit absent ou appartenant à un autre joueur ;
  - kit vide ;
  - bouteille vide ;
  - case couverte ;
  - zone protégée ;
  - charge consommée ;
  - kit et contenu retirés ;
  - un seul paiement en cas de double envoi.
- **Butin** : insertion sans doublon, rafraîchissement, taux à 0.
- **Multijoueur** : extension de `tests/check_fulton_multiplayer.py` (vol attaché à une position, déconnexion du lanceur).

**Protocole en jeu** (nouvelles lignes F1 à F8, solo puis MP) :
1. recettes ;
2. demande radio ;
3. lâcher nominal ;
4. confirmation et plafond ;
5. annonce et son ;
6. refus (intérieur, arbre, hors créneau) ;
7. butin observé en debug ;
8. Vaccine actif.

## 10. Ordre de livraison proposé

1. Classement, barème, options et table `UNCAPPED` (tests `lupa`).
2. Rendez-vous radio.
3. Kit conteneur, action et commande serveur.
4. Vol attaché à une position, annonce et son.
5. Butin.
6. Compatibilité Vaccine.
7. Traductions, guides, CHANGELOG, protocole.

## 11. Points ouverts

**Valeurs [P] à confirmer**
- ARI +2 ;
- capacité 10 ;
- rayons de bruit 15 et 40 ;
- poids de butin ;
- 25 % sur l'épave ;
- 5 % dans les caisses.

**À relever (⚠)**
- API météo 42.21 ;
- son de sifflement vanilla ;
- toit et étages avec `isOutside` ;
- clés de conteneur ;
- `KeyRing_SecurityPass` dans un conteneur ;
- poids de la bouteille dans le butin.

**Son** : fichier prêt (§5). Il reste à le jouer depuis le client et à l'écouter en jeu.

## 12. Écarts du lot 3 (2026-10-07)

- **Confirmation sans chiffre** (décision de l'utilisateur) : la règle du mod est de ne jamais afficher la confiance en chiffres. La confirmation liste les objets utiles à la base et ceux qu'elle ignore (6 noms au plus, puis « et N de plus »). Elle prévient **en mots** quand le plafond du jour est atteint ou sera dépassé. L'accusé de réception donne le **nombre d'objets** exploités, jamais de points.
- **Accusé de réception** : il s'affiche en texte au-dessus du personnage (`HaloTextHelper.addText`) et il est noté au journal du poste de l'équipe. Il ne passe pas par la radio, que le joueur n'a pas forcément en main au moment du lâcher. Un refus est dit par le personnage.
- **Inventaire principal** : le serveur n'accepte le kit et la bouteille que dans l'inventaire principal, pas dans un sac, et pas portés ni en main. Le client les y place avant le gonflage, avec les actions vanilla (`ISUnequipAction`, `transferIfNeeded`). Ces transferts sont des transactions du serveur en MP.
- **Son du gonflage** : aucun sifflement vanilla trouvé ; seul le bruit pour les zombies est émis (`addSound` depuis l'action côté client, relayé au serveur comme `ISBarricadeAction`).
- **Vent** : refus au-delà de 60 km/h (`ClimateManager:getWindspeedKph`), et par orage (`getIsThunderStorming`) **[P]**.

## 13. Écarts du lot 4 (2026-10-07)

- **Secteur annoncé** : la grille est arrondie au secteur de 50 cases, comme le MAYDAY (`Broadcast.fulton`). Le nom de la zone de largage n'est pas ajouté, faute de fonction « zone contenant ce point » dans `MilitaryDrop_Zones.lua`. Aucun repère de carte n'est créé : l'annonce est seulement entendue et notée au journal des postes.
- **Point de départ** : centre de la case du lanceur. Le prototype partait 1,5 case en diagonale, mais cette case n'est pas contrôlée (dehors, arbre).
- **Vol réel** : `FultonPrototypeServer.startFlight(x, y, z)` crée un vol sans propriétaire, attaché à une position et marqué `real`. Il continue si le lanceur meurt ou se déconnecte. En solo, `FultonPrototype.startAt` crée le même vol localement.
- **Son** : chaque client joue le passage une seule fois, quand il découvre un vol réel de moins d'une seconde. Un client qui arrive plus tard voit le ballon, sans le son. Émetteur placé haut (z = 20), `playSoundImpl(nom, false, nil)`.
- **Bruit du passage** pour les zombies : rayon 40, volume 40 **[P]**, sur le serveur ou en solo.
- **Menu de test du prototype** : seulement en mode debug.

## 14. Premier essai en jeu et simplification (2026-10-07)

Retour de l'utilisateur : parcours incompréhensible. Le kit posé au sol ne pouvait pas être gonflé (« le kit doit être dans mon inventaire »), et le ballon plié semblait devoir être accroché au kit. Décisions de l'utilisateur :
- **Kit au sol seulement** : le kit se pose dehors, se remplit comme un sac au sol, puis clic droit sur le kit au sol (dans le monde ou dans la liste du sol) → « Gonfler et lâcher le Fulton ». Dans l'inventaire, l'option reste visible mais grisée, avec le motif « Posez le kit au sol, dehors, pour le gonfler ». Le personnage marche jusqu'au kit (`luautils.walkAdj`) ; la bouteille sort du sac si besoin.
- **Serveur** : `FultonLaunch { kitId, tankId, x, y, z }`. Le kit est cherché parmi les objets au sol de la case désignée, qui doit être à `Fulton.REACH` (2) cases au plus et au même étage. La case du kit sert aux contrôles (dehors, arbre, zones protégées). Le kit est retiré par `transmitRemoveItemFromSquare` (solo et MP, comme `ISBuildIsoEntity`). Le vol part de la case du kit.
- **Créneau radio gardé**, avec un message qui dit où le demander (section Logistique d'une radio militaire).
- **Confirmation gardée**, toujours affichée.
- **Objets qui s'expliquent** : le ballon plié devient « Enveloppe de ballon Fulton (pièce) » et le sac « Sac à harnais Fulton (pièce) », avec des infobulles « pièce de fabrication, pas encore un Fulton ». L'infobulle du kit donne les 3 étapes.
- ⚠ **Sac au sol et doublons** : un sac rempli au sol, sur une case déchargée puis rechargée, peut voir son contenu dédoublé (comportement vanilla, `.claude/pz-knowledge/world-placement.md`). Le lâcher a lieu joueur présent, donc case chargée. Le risque d'exploitation est jugé faible (serveur entre amis).

