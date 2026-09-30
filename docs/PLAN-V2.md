# Military Drop v2 — plan d'implémentation (idées 4, 5, 6, 9)

Rédigé le 2026-09-30, après le test solo de la v1. État d'avancement de chaque élément : [SUIVI.md](SUIVI.md). Idées retenues par l'utilisateur :
- 4 : code chiffré qui change chaque semaine ;
- 5 : confiance de la base ;
- 6 : formulaire de réquisition ;
- 9 : largage leurre.

Les idées 3, 8 et 10 ont leur propre analyse d'impact :
- idée 3, balises, détecteur et chasses au trésor : `docs/analyses/idee-03-balises.md` (9 à 11 jours) ;
- idée 8, hélicoptère abattu et carcasse démontable : `docs/analyses/idee-08-mayday.md` (11 à 15 jours) ;
- idée 10, extraction compatible avec Opération Artemis : `docs/analyses/idee-10-extraction.md`.

## Règles communes (priorité 1 : le multijoueur)

- **Le serveur décide de tout** : tirages, codes, confiance, budgets, contenu, position. Le client affiche et envoie des demandes, qui sont toutes revalidées (types, bornes, cadence).
- **Solo = cas particulier** : même code, avec un appel direct à la place du réseau (`MilitaryDrop_Net`).
- **Secrets hors de la ModData globale**, que tout client peut lire (`ModData.request`) : fichier du serveur, comme le code actuel. La confiance et les délais peuvent rester en ModData, car ils ne sont pas secrets.
- **Aucun nom d'objet vanilla** : catégories, tags, propriétés et tables du jeu.
- **Chaque effet a une cause dans le monde**, par exemple une annonce radio, un document trouvé ou un bruit.
- Textes produits par le serveur (radio, documents) : langue du serveur. Les textes d'interface sont traduits côté client. Les documents sont écrits en chiffres et en mots OTAN pour rester indépendants de la langue.
- Tests `lupa` pour chaque règle du serveur ; test en jeu en solo, puis sur un serveur dédié avec 2 clients.

---

## Étape 0 — Largage loin du demandeur (prérequis, demandé le 2026-09-30)

*Fait le 2026-09-30 (80 tests `lupa`), à tester en jeu.* Écarts avec la conception ci-dessous :
- le point est validé par la métagrille : `isValidSquare`, cellule présente, `getBuildingAt` nul ;
- une livraison en attente est retentée à chaque `LoadChunk` situé à 30 cases ou moins, tant qu'aucune case ne convient ; il n'y a pas de second tirage à 50 cases ;
- repli si aucun point lointain ne convient : près du demandeur, comme en v1 ;
- un vol interrompu par un redémarrage **reprend** (il n'est plus converti en livraison sans hélicoptère), et il est renvoyé aux clients au premier tick.

**Constat vérifié** : le point est aujourd'hui tiré à **15-30 cases** de la radio (`Server.LANDING_MIN/MAX_DISTANCE`), car sa case doit être chargée pour être validée. La zone chargée autour d'un joueur ne fait que 48 à 79 cases (`IsoChunkMap.java:131-139`).

**Conception**
- Options sandbox `DropMinDistance` (150 par défaut) et `DropMaxDistance` (400), en cases. Le point est tiré au hasard dans cet anneau autour du **demandeur**, **sans exiger que la case soit chargée**, et reste dans les bornes de la carte (métagrille).
- Au largage (l'hélicoptère au-dessus du point) :
  - **annonce immédiate** des coordonnées et du repère de carte ;
  - si la zone est chargée, la caisse est posée tout de suite ;
  - sinon, livraison en attente : `LoadChunk` existe déjà, avec revalidation et déplacement vers la case libre la plus proche.
- Case d'arrivée dans l'eau ou sans place : recherche d'une case libre dans un rayon élargi (30 cases). À défaut, nouveau point tiré à 50 cases, en journalisant les cas limites.
- La horde apparaît quand la caisse est posée, donc à l'arrivée des joueurs dans la zone : c'est cohérent (le bruit du largage a attiré les zombies).
- **MP** : le serveur charge les chunks autour de chaque joueur, et `LoadChunk` s'y déclenche. Le vol vers un point lointain ne coûte rien (hélicoptère simulé).

**Tests** : tirage dans l'anneau et dans la carte, annonce avant la pose, pose différée puis revalidée, repli dans l'eau. **Effort : S.**

---

## Idée 4 — Code chiffré : station de chiffres et carnet de codes

*Fait le 2026-09-30 (110 tests `lupa`), à tester en jeu (protocole G).* Écarts avec la conception ci-dessous, décidés le même jour (décisions 8 à 12) :
- le code ne sert qu'aux largages ; la base ne garde pas en mémoire qui l'a donné (AUTH-01, revu en v1.3) ;
- une seule option `AuthCode` à 4 choix remplace `RequireAuthCode`, `WeeklyCode` et `PlainCodeOnNotes` : aucun code, code fixe en clair sur les notes, code de la semaine en clair (daté), code de la semaine chiffré (défaut). Carnet et station n'existent qu'avec le dernier ;
- le code change le **lundi à 00:00** du calendrier du jeu ;
- **un seul carnet par partie** (décision 15) : la table est fixe, dérivée de la graine ; seul le code change chaque semaine. Les éditions, d'abord codées, ont été retirées après le test solo ;
- station en **ondes courtes, 10-25 MHz** : fréquence libre dérivée de la graine (la ModData n'est pas chargée à `OnLoadRadioScripts`), ou option `NumbersStationFrequency` ; une diffusion par demi-heure de jeu : appel, trois fois le groupe « 17-04-58 », fin. Le groupe « 22-11 » de l'exemple est abandonné ;
- **parade à la force brute** : 676 codes seulement quand les chiffres sont connus. Après 3 codes faux dans la journée, la base ignore l'appelant jusqu'au lendemain, avec la même réponse qu'un mauvais canal ; le compteur reste en mémoire du serveur, car dans la ModData il distinguerait un mauvais code d'un mauvais canal ;
- carnet : deux pages (mode d'emploi, puis table triée par nombre), sur les tenues de l'option `CodebookOutfits` (`Army`) et dans `ArmyBunkerLockers`, `ArmyStorageElectronics`, `ArmyStorageOutfit`, ajouté à `OnInitGlobalModData` puis `ItemPickerJava.Parse()` ;
- générateur reproductible Park-Miller, exact en flottants (Lua 5.1 n'a pas d'opérateurs binaires) ; graine dans `Zomboid/Lua/MilitaryDrop/<mode>_<partie>_seed.txt`.

**Principe**
- Le code d'authentification **change chaque semaine de jeu**. Le code de la semaine précédente reste accepté pendant 24 h de jeu.
- Une **station de chiffres** (chaîne radio dédiée, fréquence propre) diffuse périodiquement le code chiffré : « ÉDITION 3 — 17-04 — 22-11 — 58 ».
- Un **carnet de codes militaire** (objet du mod, une édition donnée) contient la table qui déchiffre les groupes : 17 → BRAVO, 04 → KILO. Les deux derniers chiffres passent en clair. Code de la semaine : BRAVO-KILO-58.
- Chaque édition couvre plusieurs semaines (option). Il faut donc retrouver le carnet de l'édition en cours.

**Données du serveur (secrètes, fichier)** : graine de la partie, tables de chaque édition (mots OTAN permutés par édition), et code de chaque semaine, dérivé de la graine et du numéro de semaine (reproductible, sans stockage).

**Monde**
- La note militaire actuelle donne la fréquence militaire **et** celle de la station ; elle ne donne plus le code.
- Le carnet se trouve sur les cadavres militaires (plus rare que les notes) et dans le butin militaire : ajout de notre objet aux tables de l'armée, sans nommer d'objet vanilla.
- **Page du carnet** : écrite par le serveur à la création de l'objet (`OnCreate`, comme la note), pour l'édition en cours ou tirée au hasard parmi les éditions proches. Verrouillée, donc lecture seule.
- Fréquence de la station : option sandbox (par défaut, une fréquence libre tirée à la création de la partie et gardée). Même protections que la chaîne militaire : nom masqué, fréquences HEF réservées.

**MP** : diffusion reçue par tous les auditeurs. Le carnet est un objet ordinaire, créé par le serveur. Le déchiffrement se fait de tête, par le joueur : aucune donnée secrète n'est envoyée aux clients.

**Options** : `WeeklyCode` (activé), `CodeEditionWeeks` (4), `NumbersStationFrequency`, `CodebookDropRate`, et **`PlainCodeOnNotes`** (désactivé ; décision du 2026-09-30). Activée, elle écrit le code de la semaine en clair sur les notes pour les serveurs qui ne veulent pas du chiffrement. Le carnet et la station restent alors facultatifs.

**Fichiers** : `MilitaryDrop_Codes.lua` (dérivation, chiffrement), `MilitaryDrop_NumbersStation.lua` (serveur), objet et `OnCreate` du carnet, notes modifiées, traductions (EN/FR).

**Tests** : code identique pour une même semaine et différent la semaine suivante, grâce de 24 h, chiffrement puis déchiffrement par la table de l'édition, table jamais présente en ModData. **Effort : M.**

---

## Idée 5 — Confiance de la base (« Logistics »)

**Principe** : une note de confiance **par faction** vanilla, et par joueur pour un joueur sans faction (décision du 2026-09-30, qui remplace « par joueur »). Elle vaut de 0 à 100 et part de 50. Tous les gains, pertes, budgets et plafonds s'appliquent à la faction.

**Ce qui la fait varier (côté serveur)**
- **Largage récupéré** : une caisse du largage est ouverte par le demandeur **ou par un membre de sa faction vanilla** (confirmé le 2026-09-30, pour ne pas pénaliser le jeu en équipe). Les caisses portent en ModData l'identifiant du largage et le nom du demandeur, posés au remplissage du coffre. L'ouverture passe déjà par l'`OnCreate` de la recette, sur le serveur. **+10** pour le demandeur, une fois par largage.
- **Largage perdu** : rien d'ouvert après 48 h de jeu (option). **−10**
- **Largage pris par un autre joueur** (hors de la faction du demandeur) avant le demandeur : **−5** pour le demandeur. Le preneur ne gagne rien.
- **Code faux répété** : 3 échecs dans l'heure. **−2**, un anti-force-brute qui s'ajoute à la cadence déjà limitée.
- Érosion lente vers 50 si le groupe n'appelle pas (option).

**Autres sources de confiance** (les 8 retenues par l'utilisateur le 2026-09-30, pour ne pas dépendre des seuls largages). Toutes vérifiées par le serveur, chacune avec une cause dans le monde :

| # | Source | Gain | Vérification serveur | Lot |
|---|---|---|---|---|
| 1 | **Rapport de situation** : appel quotidien avec le code | +1, une fois par jour de jeu | code, radio, dernier rapport | v1.3 |
| 2 | **Plaques d'identité** : objet du mod sur les soldats zombies, numéro tiré par le serveur ; « Transmettre le matricule » par radio | +2, plaque consommée | plaque dans l'inventaire, numéro jamais utilisé, plafond par jour | v1.3 |
| 3 | **Reconnaissance** : la base diffuse « confirmez l'état de la zone en grille X/Y » ; le premier qui appelle depuis ce point avant l'échéance | +3 | position du joueur, échéance ; point tiré comme l'étape 0 | v1.3 |
| 4 | **Nettoyage** : la base signale une horde dans une zone ; quota de morts atteint avant l'échéance | +5 pour chaque membre de la faction ayant participé | morts comptées dans la zone ; **à vérifier** : identification du tueur côté serveur en MP | v1.3 ou après |
| 5 | **Appel de contrôle** : « toutes stations, confirmez réception » ; réponse dans les 10 min | +1 | radio allumée sur la fréquence, délai de réponse | v1.3 |
| 6 | **Renseignement** : documents militaires transmis (notes périmées) | +1 à +3 selon la rareté | document dans l'inventaire, consommé | après v1.2 |
| 7 | **Largage perdu ou cache retrouvé** au détecteur, puis ouvert | +5 | ouverture sur le serveur | avec l'idée 3 |
| 8 | **Enregistreur de vol** récupéré dans l'épave et transmis | +10 | objet dans l'inventaire, consommé | avec l'idée 8 |

- Plafond commun proposé : **+8 par jour de jeu** pour toutes ces sources réunies, pour que les largages restent la source principale (option sandbox).
- Chaque source est activable séparément en sandbox, avec son gain.
- Annonces des missions (3, 4, 5) sur la chaîne militaire : textes du serveur, traduits dans sa langue.

**Effets**
- Délai entre deux largages multiplié par un facteur entre ×1,5 (confiance basse) et ×0,6 (confiance haute).
- Budget de réquisition (idée 6).
- Catégories débloquées (idée 6).
- Sous 15 : **ligne coupée** pendant 3 jours de jeu, la base ne répond plus.

**Retour au joueur** : la base le dit à la radio, avec des répliques par palier (« Your unit's record is excellent »…). Rien n'est affiché en chiffres, pour garder l'immersion. Un admin peut la lire en console debug.

**Données** : ModData « MilitaryDrop » → `trust[nomDuJoueur] = { value, lastCall, lockedUntil }`, et `drops[id] = { requester, openedBy, deadline }`. Rien de secret.

**MP**
- Joueur identifié par le serveur (nom de compte), jamais par une donnée du client.
- Le délai reste **global au serveur**, décision v1. La confiance du demandeur module ce délai global.

**Tests** : gains et pertes par joueur, ouverture par un membre de la faction ou par un autre joueur, facteur de délai, ligne coupée, échéance d'un largage, pas de double gain. **Effort : M.**

---

## Idée 6 — Formulaire de réquisition

**Principe** : après le code, une **fenêtre de réquisition** s'ouvre sur le client. Le joueur répartit un **budget de points**, qui dépend de la confiance, entre des **catégories d'objets**. La base livre ce que le budget couvre, avec une part d'aléatoire.

**Catégories, sans nom d'objet**
- Construites par le serveur au premier usage, à partir des objets présents dans **toutes les tables de butin**, regroupés par `getDisplayCategory()` : premiers soins, nourriture, outils, munitions, armes, vêtements… Libellés vanilla traduits (`IGUI_ItemCat_*`, 86 catégories en FR).
- Liste blanche **par option sandbox** (`RequisitionCategories`, par défaut les catégories utiles), sans nom d'objet.
- Coût d'une catégorie calculé à partir de la rareté moyenne de ses objets dans les tables (poids), ajustable par option.
- Les armes à feu et les munitions restent reconnues comme dans la v1 (dégâts > 0, chargeur ou boîte d'une arme).

**Lots proposés** (2026-09-30, retenus par l'utilisateur ; coûts et budgets indicatifs, à calibrer en jeu). Chaque lot regroupe des catégories d'objet vanilla (`DisplayCategory`, libellés `IGUI_ItemCat_*`) ou une propriété, jamais un nom d'objet : les objets des mods rejoignent leur lot seuls.

| Palier | Lot | Source dans le jeu | Coût |
|---|---|---|---|
| I (toute confiance) | Rations | `Food`, filtré sur la durée avant péremption | 1 |
| I | Eau potable | récipients qui contiennent de l'eau | 1 |
| I | Soins | `FirstAid`, `Bandage` | 2 |
| I | Outils | `Tool`, `ToolWeapon` | 2 |
| I | Matériaux | `Material` | 1 |
| I | Bivouac | `Camping`, `FireSource`, `Fishing`, `Trapping` | 2 |
| II (confiance ≥ 50) | Munitions | `Ammo`, chargeurs et boîtes des armes à feu connues | 2 |
| II | Armes de mêlée | `Weapon` sans tir, dégâts > 0 (hors `WeaponCrafted`, `*Weapon` improvisées) | 3 |
| II | Protection | `ProtectiveGear`, vêtements avec `getBulletDefense() > 0` | 3 |
| II | Mécanique | `VehicleMaintenance` | 2 |
| II | Transmissions | `Electronics`, `Communications`, `LightSource` | 2 |
| II | Semences | `Gardening` | 1 |
| II | Instruction | `SkillBook` | 2 |
| II | Paquetage | `Bag`, `Container` | 2 |
| III (confiance ≥ 75) | Armes à feu | `Weapon` à tir, dégâts > 0, + 2 chargeurs et 1 boîte | 5 |
| III | Accessoires d'armes | `WeaponPart` | 3 |
| III | Explosifs (option, désactivable) | `Explosives` | 5 |
| III | Carburant (**à vérifier** : créer un récipient déjà plein d'essence en 42.21) | récipients qui contiennent de l'essence | 3 |
| Spécial (v1.5) | Leurre à sirène | voir idée 9 | 3 |

- Budget indicatif : 8 points à la confiance 25, 12 à 50, 16 à 75, 20 à 100 ; aucun formulaire sous 15 (ligne coupée).
- Lots, paliers et multiplicateur de coût réglables en sandbox.
- Idée à valider : les points non dépensés deviennent un lot surprise tiré parmi les lots permis.
- L'annonce radio ne révèle jamais le contenu commandé.

**Déroulé MP**
1. Le client demande le formulaire (code juste). Le serveur répond avec les catégories permises pour ce groupe et leurs coûts, **sans le contenu des tables**.
2. Le client envoie une sélection `{ catégorie = quantité }`. Le serveur **revalide** : catégories permises, budget, bornes, délai.
3. Au largage, le coffre reçoit une **caisse de réquisition par catégorie** (objet du mod ; catégorie en ModData, nom composé avec le libellé traduit de la catégorie). Le contenu est tiré à l'ouverture, sur le serveur, comme aujourd'hui.
- Sans formulaire (option désactivée, manette sans interface) : caisses aléatoires de la v1.

**Interface** : fenêtre `ISPanel` avec les catégories, leurs coûts, des boutons + et −, le budget restant, puis Valider ou Annuler. Largeurs mesurées selon la langue (piège connu : `ui-windows.md`). Prévoir le focus manette.

**Tests** : construction des catégories sur des tables simulées, coûts, validation du serveur (dépassement de budget, catégorie interdite, quantité négative), contenu par catégorie. **Effort : M-L** (l'interface représente la moitié).

---

## Idée 9 — Largage leurre (sirène)

**Principe** : **seulement dans le formulaire de réquisition** (décision du 2026-09-30), le joueur peut commander un **largage de diversion**. Il ne livre aucune fourniture : c'est une **balise-sirène**, larguée **au hasard dans un secteur que le joueur choisit** (N, E, S ou O) à la distance de l'étape 0. Elle hurle plusieurs heures et **attire les hordes**. Elle sert à vider une zone avant une expédition.

**Monde**
- La balise est une variante de la caisse-véhicule, avec la même chaîne 3D ; seule la texture change (« DIVERSION »).
- **Cause du bruit** : la sirène elle-même. Un joueur peut l'arrêter (menu contextuel, action chronométrée validée par le serveur). Elle s'arrête aussi seule quand ses piles s'épuisent, après une durée réglable en option.
- **Indiscernable d'un vrai largage** (décision du 2026-09-30) : même annonce radio (« caisse livrée en grille… »), même hélicoptère, même repère de carte, même aspect de loin. Les équipes adverses ne peuvent pas savoir qu'elles vont vers un leurre.
  - Côté réseau : le type n'apparaît dans **aucun** message envoyé à tous (`FlightStart`, `DropAnnounce`), pour qu'un client modifié ne puisse pas le lire. Seul le demandeur reçoit en privé la confirmation de sa commande.
  - Côté stockage : la ModData globale est lisible par tout client (`ModData.request`). Le type d'un largage (leurre ou non) n'y est donc **jamais écrit en clair**. Il va dans le fichier du serveur, ou dans la ModData masquée par la clé du serveur (mécanisme proposé par l'analyse de l'idée 3, `docs/analyses/idee-03-balises.md`).
  - La caisse leurre garde **la même texture** que la vraie. Le marquage « DIVERSION » n'est visible que dans son coffre ou en l'examinant de près.
  - La sirène ne se déclenche **qu'une fois la caisse posée**, c'est-à-dire quand un joueur est dans la zone. Rien ne la trahit à distance avant l'arrivée.

**Mécanique MP**
- **Bruit** : sur le serveur, `addSound` répété à la position de la balise, avec rayon et volume réglables (option), tant qu'elle est active **et** que son chunk est chargé.
- **Hors zone chargée** : pas de simulation. Les zombies virtuels ne suivent pas un bruit non chargé ; c'est une limite du moteur, à documenter.
- **Son audible** : chaque client joue une boucle de sirène locale (son vanilla d'alarme, même principe que le son de l'hélicoptère). Le serveur n'envoie la position d'une sirène active **qu'aux joueurs à portée d'écoute** (quelques centaines de cases), qui la redemandent à la reconnexion. Un client éloigné ne reçoit rien.
- **Coût et confiance** : prix en points (idée 6). Un leurre ouvert ou coupé par un autre joueur ne coûte pas de confiance au demandeur, puisque c'était son but.

**Tests** : cycle de vie (activation, durée, arrêt par un joueur, fin), bruit seulement quand le chunk est chargé, **messages identiques à un vrai largage** (vérifiés par le test), position de la sirène envoyée aux seuls joueurs à portée, synchronisation à la reconnexion, secteur respecté. **Effort : S-M.**

---

## Ordre proposé et dépendances

| Lot | Contenu | Dépend de | Effort |
|---|---|---|---|
| **v1.1** | Étape 0 (largage lointain) | aucune | S |
| **v1.2** | Idée 4 (code chiffré) | étape 0 | M |
| **v1.3** | Idée 5 (confiance de faction) | ModData des largages | M |
| **v1.4** | Idée 6 (réquisition) | idée 5 | M-L |
| **v1.5** | Idée 9 (leurre) | étape 0, idée 6 (pour la commande) | S-M |

Chaque lot se termine par les tests `lupa`, un test en solo, puis un test sur serveur dédié avec 2 clients : appel, écoute par l'autre joueur, reconnexion pendant un vol, commande forgée.

## Décisions de l'utilisateur (2026-09-30)

1. Idée 5 : confiance **par joueur** ; l'ouverture par un membre de sa faction vanilla compte comme récupérée. *Remplacé le 2026-09-30 (point 7 ci-dessous) : confiance par faction.*
2. Idée 4 : chiffrement par défaut, avec l'option sandbox `PlainCodeOnNotes` pour écrire le code en clair sur les notes.
3. Idée 9 : commande **seulement dans le formulaire**. L'annonce et toutes les données envoyées à tous ne doivent **jamais révéler le type de largage**.
4. Idée 6 : les 18 lots de réquisition proposés sont retenus (tableau de l'idée 6).
5. Idée 3 : le détecteur a un indicateur **visuel et sonore** : voyant et bip dont la cadence suit la distance (modèle : détecteurs de caches de S.T.A.L.K.E.R. GAMMA).
6. Idée 5 : les **8 autres sources de confiance** sont toutes retenues (tableau de l'idée 5).
7. Échanges avec la base : **poste de commandement** retenu (solution 4 des maquettes « Liaison Logistique », 2026-09-30), jugé plus réaliste. Une radio posée dans la base devient un poste de liaison : journal des transmissions, missions en cours, boîte à courrier. Les missions laissent le temps de recevoir l'ordre à la base, d'aller sur place, puis de confirmer au retour ou par talkie-walkie. Zones grises en cours de discussion.
   - Point 1 tranché : **le talkie-walkie permet tout** (missions, courrier, rapports, largage). Le poste apporte le confort (journal des transmissions, missions en cours, boîte à courrier commune) et un **petit bonus de confiance** pour les échanges faits depuis la base.
     Proposition à calibrer : +50 % sur les gains obtenus depuis le poste, dans la limite du plafond quotidien.
   - Point 6 tranché : **toutes les missions sont publiques** (« à toutes les stations ») et la première équipe qui les remplit gagne. Hypothèse à confirmer : l'appel de contrôle récompense tous ceux qui répondent à temps (il mesure l'écoute, pas la vitesse) ; reconnaissance et nettoyage vont au premier.
   - Point 5 tranché : **un poste actif par faction** (ou par joueur sans faction), enregistré à son nom. Journal, missions et état sont gardés par le serveur au nom de la faction, pas dans l'objet : déplacer, perdre ou voir brûler la radio ne fait rien perdre, il suffit d'en installer une autre. Un joueur d'une autre faction ne peut pas utiliser le poste.
   - Point 7 tranché : **la confiance devient une note de faction** (par joueur pour un joueur sans faction). Le courrier commun crédite donc la faction, sans avoir à savoir qui a déposé quoi. Le plafond quotidien s'applique à la faction : un joueur seul progresse au même rythme qu'une grande équipe.
     Contrainte vérifiée : une faction vanilla n'a pas d'identifiant stable, seulement un nom et un propriétaire modifiables (`Faction.java:255-269`). Le serveur attribue donc à chaque faction un **indicatif** (« Station Kilo-7 ») qui porte la note, et le retrouve après un renommage par le propriétaire ou la majorité des membres.
   - Changements de faction tranchés : un joueur qui part, ou dont la faction est dissoute, **emporte la note de son ancienne faction plafonnée à 50** (il ne garde pas une excellente réputation mais n'échappe pas à une mauvaise) ; une ligne coupée le suit. Un joueur qui rejoint une faction adopte sa note. Une faction nouvelle part de la **plus basse note de ses fondateurs**. Le serveur détecte ces mouvements en comparant, à chaque échange et périodiquement, les membres mémorisés de chaque indicatif avec `Faction.getPlayers()`.
   - Point 3 tranché : le journal du poste n'enregistre que ce que le poste **reçoit** : allumé, alimenté (réseau, groupe ou pile) et réglé sur la fréquence au moment de la diffusion. Sinon, une ligne « aucune réception » marque le trou.
     Limite technique à traiter : quand personne n'est à la base, le chunk du poste n'est pas chargé et le serveur ne peut pas lire la radio. Règle proposée : garder le dernier état observé au déchargement (personne ne peut le modifier entre-temps), en tenant compte de la coupure du réseau à sa date. Consommation d'un groupe ou d'une pile hors chargement : **à vérifier** dans le moteur.
   - Point 4 tranché : délais en **heures de jeu**, réglables en sandbox : appel de contrôle **4 h**, reconnaissance **48 h**, nettoyage **72 h**. Les « 10 minutes » de l'appel de contrôle sont abandonnées. En MP, le temps tourne pendant qu'un joueur est déconnecté (sauf serveur en pause quand il est vide) : ses missions peuvent expirer en son absence.
   - Point 8 tranché : un membre qui donne le bon code **authentifie tout l'indicatif de sa faction** jusqu'au changement de code (la semaine en v1.2). Plus de saisie du code pour les autres membres pendant cette période.
   - Retenus par défaut, sauf avis contraire : poste = radio **non portable, haut de gamme et capable d'émettre** (propriétés `DeviceData`, aucun nom d'objet ; exclut le talkie posé et la radio bricolée) ; console ouverte par une entrée « Poste de liaison » du menu contextuel, sans remplacer la fenêtre radio vanilla.
8. Idée 4 (2026-09-30) : en v1.2, le code sert **seulement aux largages**. La mémoire de la base (AUTH-01) est revue en v1.3, avec la question : les missions exigent-elles le code ?
9. Idée 4 : une **liste à 4 choix** (`AuthCode`) remplace les cases à cocher : aucun, fixe en clair sur les notes, de la semaine en clair sur les notes, de la semaine chiffré (station et carnet, défaut).
10. Idée 4 : **silence après 3 codes faux** dans la journée de jeu : la base ignore l'appelant jusqu'au lendemain, sans le trahir.
11. Idée 4 : le code change le **lundi à 00:00** du calendrier du jeu.
12. Idée 4 : station de chiffres en **ondes courtes (10-25 MHz)** : radios militaires, radios de radioamateur et meilleur talkie civil.
13. Documents (test solo du 2026-09-30) : la note et le carnet passent de la fenêtre d'écriture au rendu `printMedia` des journaux vanilla. Note : mémorandum dactylographié annoté à la main. Carnet : **dossier kraft ouvert**. Textures originales générées par script.
14. Idée 4 (test solo du 2026-09-30) : **« Noter le message »** pendant la diffusion de la station, avec stylo et papier, crée une feuille manuscrite « Message intercepté », vérifiée par le serveur.
15. Idée 4 (test solo du 2026-09-30) : **un seul carnet de codes par partie**, sans éditions : la table est fixe, seul le code change chaque semaine. La conception initiale ci-dessous (éditions, option `CodeEditionWeeks`) est abandonnée.
16. Documents (second test solo du 2026-09-30) : **« Noter le message » est retiré** (jugé inutile ; il ne fonctionnait pas en jeu). Les documents s'ouvrent vite (tag `base:fastread`).
17. Intégration (2026-09-30) : **fumée de Signal Smoke sur la caisse larguée**, facultative : active seulement si le mod `batman_SignalSmoke` l'est, sans `require` dans `mod.info` (Military Drop reste autonome, décision v1). Fumée verte au moment où la caisse est posée, durée en option.
