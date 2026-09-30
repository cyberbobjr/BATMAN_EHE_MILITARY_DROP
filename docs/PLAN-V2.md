# Military Drop v2 — plan d'implémentation (idées 4, 5, 6, 9)

Rédigé le 2026-09-30, après le test solo de la v1. Idées retenues par l'utilisateur :
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

**Principe** : une note de confiance **par joueur** (décision du 2026-09-30), c'est-à-dire par compte en MP. Elle vaut de 0 à 100 et part de 50.

**Ce qui la fait varier (côté serveur)**
- **Largage récupéré** : une caisse du largage est ouverte par le demandeur **ou par un membre de sa faction vanilla** (confirmé le 2026-09-30, pour ne pas pénaliser le jeu en équipe). Les caisses portent en ModData l'identifiant du largage et le nom du demandeur, posés au remplissage du coffre. L'ouverture passe déjà par l'`OnCreate` de la recette, sur le serveur. **+10** pour le demandeur, une fois par largage.
- **Largage perdu** : rien d'ouvert après 48 h de jeu (option). **−10**
- **Largage pris par un autre joueur** (hors de la faction du demandeur) avant le demandeur : **−5** pour le demandeur. Le preneur ne gagne rien.
- **Code faux répété** : 3 échecs dans l'heure. **−2**, un anti-force-brute qui s'ajoute à la cadence déjà limitée.
- Érosion lente vers 50 si le groupe n'appelle pas (option).

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
| **v1.3** | Idée 5 (confiance par joueur) | ModData des largages | M |
| **v1.4** | Idée 6 (réquisition) | idée 5 | M-L |
| **v1.5** | Idée 9 (leurre) | étape 0, idée 6 (pour la commande) | S-M |

Chaque lot se termine par les tests `lupa`, un test en solo, puis un test sur serveur dédié avec 2 clients : appel, écoute par l'autre joueur, reconnexion pendant un vol, commande forgée.

## Décisions de l'utilisateur (2026-09-30)

1. Idée 5 : confiance **par joueur**. L'ouverture par un membre de sa faction vanilla compte comme récupérée pour le demandeur.
2. Idée 4 : chiffrement par défaut, avec l'option sandbox `PlainCodeOnNotes` pour écrire le code en clair sur les notes.
3. Idée 9 : commande **seulement dans le formulaire**. L'annonce et toutes les données envoyées à tous ne doivent **jamais révéler le type de largage**.
