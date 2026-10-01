# Military Drop v1.4 et v1.5 — formulaire de réquisition, largage leurre

Spécification d'implémentation, rédigée le 2026-10-01. Conception d'origine : [PLAN-V2.md](PLAN-V2.md) idées 6 et 9 ; état de chaque élément : [SUIVI.md](SUIVI.md). Ce document fait foi en cas d'écart avec PLAN-V2.

## Décisions de l'utilisateur (2026-10-01)

- v1.4 et v1.5 livrées d'un bloc, par sous-agents ; l'utilisateur teste quand tout est terminé.
- **REQ-07** : les points non dépensés sont **perdus** (pas de lot surprise, pas de report).
- **LEURRE-04** : un leurre n'a **aucun effet sur la confiance** (ni +10, ni −5, ni −10) : il sort du suivi des largages.
- Les 18 lots de PLAN-V2 (idée 6) sont retenus ; le leurre est le lot spécial de la v1.5, commandé seulement par le formulaire.

## Règles communes

Celles de PLAN-V2 et PLAN-V13 : serveur qui décide et revérifie tout, client jamais cru, solo = appel direct (`MilitaryDrop.Net`), aucun nom d'objet vanilla (catégories `DisplayCategory`, tags, propriétés, tables de butin, registres du moteur comme `Fluid`), une seule globale `MilitaryDrop`, pas de `next`, garde serveur, état privé dans `MilitaryDrop.Secrets.privateState()`, textes EN/FR, chaque effet a une cause dans le monde, tests `lupa`.

## Parcours d'une réquisition

1. Le joueur appelle la base comme aujourd'hui (talkie ou radio posée, code). Commande `Request`.
2. Le serveur évalue comme aujourd'hui (`Server.evaluate`). Si l'appel est accepté, que ce n'est pas un largage admin (`force`) et que l'option `RequisitionForm` est vraie, il **n'envoie pas l'hélicoptère** : il ouvre une autorisation en attente et répond `Result { status = "form", … }` (contrat ci-dessous). Le délai global n'est pas encore consommé.
3. Le client ouvre le **formulaire de réquisition**. Le joueur répartit son budget (boutons + et −), ou choisit le leurre et son secteur, puis valide (`RequisitionOrder`) ou annule (`RequisitionCancel`).
4. Le serveur revalide **tout** : autorisation en attente de ce joueur, non expirée (5 minutes réelles), même `requestId` ; radio toujours utilisable et sur le canal (comme `evaluate`, sans redemander le code) ; ligne non coupée ; délai global toujours libre (un autre joueur a pu appeler entre-temps) ; lots permis au palier de l'équipe et non vides ; quantités entières ≥ 0 ; somme des coûts ≤ budget ; au moins un lot, ou le leurre seul (le leurre ne se combine pas avec des lots). Puis il lance le vol exactement comme aujourd'hui (`Flights.launch`), en rangeant la commande dans l'état privé du largage. Réponse `Result { status = "accepted", … }` comme aujourd'hui, ou un refus (`orderInvalid`, `expired`, `cooldown`, `lineCut`, `noAnswer`, `radioOff`…).
5. Points non dépensés : perdus. Annonce radio, hélicoptère, repère : **identiques** à un largage normal (REQ-04, LEURRE-02).
6. Sans formulaire (option fausse) : caisses aléatoires de la v1 (REQ-08). Largage admin : inchangé.

## Contrats réseau (v1.4)

`Result` de forme « form » (serveur → demandeur seulement) :

```lua
{ requestId = n, status = "form", callsign = "Station Kilo-7", tier = 1..4,
  budget = n,                       -- points entiers
  expiresMs = 300000,               -- durée de validité, en ms réelles
  lots = { { id = "rations", group = 1, cost = 1, allowed = true,
             reason = nil,          -- "tier" | "empty" | "disabled" si allowed = false
             label = "IGUI_MilitaryDrop_Lot_rations",
             desc = "IGUI_MilitaryDrop_LotDesc_rations" }, … },  -- ordre d'affichage
  decoy = { cost = 3, allowed = true, reason = nil, sectors = { "N", "E", "S", "W" } } }  -- nil si v1.5 désactivée
```

`RequisitionOrder` (client → serveur) : `{ requestId = n, radio = <référence comme Request>, order = { [lotId] = quantité }, decoy = "N"|"E"|"S"|"W"|nil }`.
`RequisitionCancel` (client → serveur) : `{ requestId = n }`. Le serveur oublie l'autorisation ; rien n'est consommé.

Aucun de ces messages ne part vers les autres joueurs. Le contenu des tables de butin n'est jamais envoyé.

## Lots (REQ-02) — module `shared/MilitaryDrop/MilitaryDrop_Lots.lua`

Table ordonnée des 18 lots (PLAN-V2 idée 6) : `id`, `group` (1, 2, 3), `cost`, `count` (objets tirés par caisse de réquisition), clés de texte, et un filtre sur le script d'objet (catégorie d'affichage, propriétés). Les candidats d'un lot sont les objets présents dans **toutes les tables de butin** (comme `Loot`), pondérés par leur poids ; un lot sans candidat est refusé (`reason = "empty"`). Cas particuliers : Armes à feu = une arme + `Loot.weaponExtras` (2 chargeurs, 1 boîte) ; Eau potable et Carburant = récipient vide qui accepte un fluide, rempli à la création (`Fluid` du moteur, à vérifier en 42.21 : REQ-05) ; Explosifs désactivable (`RequisitionExplosives`, REQ-06).

Paliers : groupe 1 toujours ; groupe 2 si la note ≥ `RequisitionTier2` (50 ; une équipe démarre à 25 depuis le 2026-10-01, donc au palier I) ; groupe 3 si ≥ `RequisitionTier3` (75). Budget (REQ-03) : `floor((4 + note × 0,16) × RequisitionBudget / 100)` (8 à la note 25, 12 à 50, 16 à 75, 20 à 100). Coût effectif : `max(1, round(coût × RequisitionCostMultiplier / 100))`. Ligne coupée : aucun formulaire.

## Livraison (v1.4)

- Commande rangée dans l'état privé du largage (`drops[dropId].order`), jamais dans la ModData publique ni dans un message à tous.
- À la création de la caisse, le coffre reçoit **une caisse de réquisition par unité commandée** (objet du mod `MilitaryDrop.RequisitionCase`, lot en ModData, nom composé avec le libellé du lot, `setName` + `setCustomName`, `dropId` en ModData comme les caisses de ravitaillement). Contenu tiré **à l'ouverture**, sur le serveur, comme les caisses de ravitaillement (recette d'ouverture du mod).
- Repli au sol (caisse impossible) : mêmes caisses de réquisition, posées au sol.

## v1.5 — Leurre à sirène — module `server/MilitaryDrop/MilitaryDrop_Decoy.lua`

- Commandé par le formulaire seulement (lot spécial, coût `DecoyCost`, 3), dans un secteur N, E, S ou O choisi : point tiré à la distance habituelle, dans le quart de cercle du secteur (`Server.pickDropPoint(cx, cy, sector)`).
- **Indiscernable** (LEURRE-02) : même hélicoptère, même annonce, même repère, même caisse (même véhicule, même texture). Le type n'est dans **aucun** message à tous ni dans la ModData publique : seul l'état privé le connaît (`drops[dropId].decoy = { sector }`). Le demandeur reçoit la même réponse `accepted` qu'un largage normal.
- **Coffre** : une seule balise de diversion (objet du mod `MilitaryDrop.DecoyBeacon`, marquée « DIVERSION »), aucune fourniture. Le joueur qui ouvre le coffre comprend que c'est un leurre.
- **Sirène** (LEURRE-03) : démarre quand la caisse est posée (`Server.deliver` appelle `MilitaryDrop.Decoy.onDelivered(dropId, x, y, z)` si le largage est un leurre). Tant qu'elle est active : bruit serveur (`addSound`, rayon et volume en option) répété si la case est chargée ; la position n'est envoyée qu'aux joueurs à portée d'écoute (`SirenOn`/`SirenOff`), qui jouent une boucle locale ; resynchronisation à la connexion et à l'approche. Elle s'arrête : à l'échéance (`DecoySirenHours`), quand un joueur la coupe (menu contextuel sur la caisse, action chronométrée validée par le serveur), ou quand la caisse est démontée ou disparaît.
- **Confiance** : aucune (LEURRE-04). Le largage est enregistré sans équipe suivie.
- Hors zone chargée : pas de bruit (les zombies virtuels ne suivent pas un bruit non chargé) ; limite du moteur, documentée.

## Options sandbox

| Option | Défaut | Module |
|---|---|---|
| `RequisitionForm` | vrai | réquisition |
| `RequisitionBudget` (%) | 100 | réquisition |
| `RequisitionCostMultiplier` (%) | 100 | réquisition |
| `RequisitionTier2` | 50 (une équipe neuve démarre à 25 : palier I seulement, décision du 2026-10-01) | réquisition |
| `RequisitionTier3` | 75 | réquisition |
| `RequisitionExplosives` | vrai | réquisition |
| `DecoyEnabled` | vrai | leurre |
| `DecoyCost` | 3 | leurre |
| `DecoySirenHours` | 6 | leurre |
| `DecoyNoiseRadius` (cases) | 120 | leurre |

## Répartition (sous-agents)

- **A — réquisition côté serveur** : `MilitaryDrop_Lots.lua`, `server/MilitaryDrop/MilitaryDrop_Requisition.lua`, branchements dans `MilitaryDrop_Server.lua` (étape « form », `RequisitionOrder`, `RequisitionCancel`, `pickDropPoint` par secteur, appel `Decoy.onDelivered`), `MilitaryDrop_Crate.lua` (contenu du coffre selon la commande, ou `Decoy.trunkContents`), `MilitaryDrop_Recipe.lua` et scripts (caisse de réquisition), `MilitaryDrop_Trust.lua` (largage non suivi).
- **B — formulaire côté client** : `client/MilitaryDrop/MilitaryDrop_RequisitionWindow.lua` (formulaire papier militaire, même soin que la console du poste, manette, largeurs mesurées), réponse « form » dans `MilitaryDrop_Client.lua`, bouton « Demander un largage » dans la console du poste, aperçu hors jeu.
- **C — leurre** : `server/MilitaryDrop/MilitaryDrop_Decoy.lua`, `client/MilitaryDrop/MilitaryDrop_Siren.lua`, action « Couper la sirène », `scripts/MilitaryDrop_decoy.txt` (balise), sons.
- Coordinateur : options sandbox, traductions, suivi, protocole, pages de présentation, relecture.
