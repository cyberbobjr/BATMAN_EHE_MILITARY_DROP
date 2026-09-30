# Suivi de l'implémentation

Tableau de bord de tout ce qui a été décidé pour Military Drop (Build 42.21) : où en est chaque élément, avec ses preuves.
La conception et les décisions sont dans [PLAN.md](PLAN.md) (v1), [PLAN-V2.md](PLAN-V2.md) (v1.1 à v1.5) et [analyses/](analyses/) (idées 3, 8, 10). Les tests en jeu sont dans [TEST-PROTOCOL.md](TEST-PROTOCOL.md).

## Règles de tenue

- Chaque élément a un **identifiant stable** (`FAMILLE-NN`), jamais réutilisé ni renuméroté. Un élément abandonné garde sa ligne, à l'état `abandonné`.
- Le fichier est mis à jour **dans le même commit** que le code, les tests ou la décision qui changent un état. Le commit cite les identifiants concernés.
- **Preuves** : commits (hachage court entre accents graves), fichiers de tests `lupa`, lignes du protocole (`B5`, `E1`…). Un état « testé » sans preuve n'est pas accepté.
- **Reste** : ce qui manque pour l'état suivant. `⚠` signale un point technique à vérifier.
- `tests/run_tests.py` contrôle le fichier : identifiants uniques et bien formés, états connus, commits existants.

### États

| État | Sens |
|---|---|
| `à décider` | Analysé ou proposé, pas encore tranché par l'utilisateur |
| `décidé` | Tranché, conception détaillée à écrire |
| `conçu` | Conception écrite (plan ou analyse), pas de code |
| `codé` | Code écrit, sans test automatique |
| `testé hors jeu` | Tests `lupa` et luacheck au vert |
| `testé solo` | Vérifié en jeu en solo (protocole) |
| `testé MP` | Vérifié sur serveur dédié avec 2 clients |
| `publié` | Dans une version publiée sur le Workshop |
| `bloqué` | Impossible pour l'instant ; la raison est dans « Reste » |
| `abandonné` | Retiré par décision ; la raison est dans « Reste » |

## Vue d'ensemble

| Lot | Contenu | État global |
|---|---|---|
| v1.0 | Parité B41 + code d'authentification | testé solo, MP à faire |
| v1.1 | Largage loin du demandeur | testé hors jeu |
| Phases 7-8 | Tests en jeu, publication | à faire |
| v1.2 | Code chiffré de la semaine (idée 4) | testé solo (parcours nominal), MP à faire |
| v1.3 | Confiance de faction, sources de confiance, poste de commandement (idée 5) | décidé |
| v1.4 | Formulaire de réquisition (idée 6) | conçu |
| v1.5 | Largage leurre (idée 9) | conçu |
| Intégrations | Fumée sur la caisse avec Signal Smoke (facultatif) | testé solo |
| Idée 3 | Balises, détecteur, chasses au trésor | mis de côté |
| Idée 8 | Mayday, épave démontable | à décider |
| Idée 10 | Extraction, pont avec Opération Artemis | à décider |

## v1.0 — Parité B41 et code d'authentification

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| APPEL-01 | Appel par radio militaire : en main, sur le dos, ou posée à 2 cases | PLAN phase 2 | testé solo | `1275061`, `4afeea8`, test_server, B1-B5 | MP |
| APPEL-02 | Code d'authentification (deux mots OTAN + deux chiffres), gardé dans un fichier du serveur | PLAN décisions | testé solo | `1275061`, `d43869e`, test_codes, test_server, B5 | MP : client qui lit la ModData |
| APPEL-03 | Même réponse pour mauvaise fréquence et mauvais code | PLAN phase 2 | testé solo | `d43869e`, test_server, B3-B4 | MP |
| APPEL-04 | Délai global au serveur (sandbox) et cadence de 3 s par joueur | PLAN décisions | testé solo | `1275061`, test_server, B6 | MP |
| APPEL-05 | Largage forcé par un admin, sans radio ni délai | PLAN phase 2 | testé solo | `4afeea8`, test_server, E4 | MP : droits `Capability` |
| NOTE-01 | Notes de service sur zombies militaires et policiers (tenues en sandbox) | PLAN phase 2 | testé solo | `1275061`, `9b7d3db`, test_notes, B7 | MP |
| NOTE-02 | Note remplie à la création, en lecture seule | PLAN phase 1 | testé solo | `4afeea8`, test_notes, A5 | — |
| BUTIN-01 | 4 caisses de ravitaillement et recette d'ouverture | PLAN phase 1 | testé solo | `cdaadf5`, test_loot, A1-A3 | MP |
| BUTIN-02 | Contenu tiré dans les tables du jeu et des mods, aucun nom d'objet | PLAN phase 6 | testé solo | `9b7d3db`, test_loot, A2 | — |
| BUTIN-03 | Arme livrée avec 2 chargeurs et 1 boîte de munitions | PLAN phase 1 | testé solo | `4afeea8`, test_loot, A2 | — |
| BUTIN-04 | Modèles au sol avec leur texture | PLAN phase 1 | testé solo | `4afeea8`, A1 | — |
| HELI-01 | Hélicoptère simulé : son, ombre, flèche, vol stationnaire | PLAN phase 3 | testé solo | `4aee311`, test_heli, test_flight, C1-C4 | C1 à refaire avec la distance v1.1 ; MP |
| HELI-02 | Cohabitation avec HEF : attente de ses événements, 112,2 MHz réservée | PLAN décisions | testé hors jeu | `4aee311`, test_flights, test_core | Partie avec HEF |
| RADIO-01 | Chaîne « Logistique » : départ, coordonnées répétées, fin ; nom caché | PLAN phase 4 | testé solo | `8132d90`, test_broadcast, D1 | D3 (nom caché) ; MP |
| RADIO-02 | Repère de carte pour les seuls auditeurs | PLAN phase 4 | testé solo | `8132d90`, test_announce, D2 | D4 (radio éteinte) ; MP |
| CAISSE-01 | Caisse 3D originale : véhicule sans roues avec coffre | PLAN phase 5 | testé solo | `e6b5ceb`, test_crate, E1-E3 | F2 ; MP |
| CAISSE-02 | Horde (3-30) et bruit au largage | PLAN phase 2 | testé solo | `1275061`, test_server, E2 | MP |
| OPT-01 | Options sandbox traduites EN/FR | PLAN phase 1 | testé solo | `cdaadf5`, `555593e`, test_core, run_tests (traductions) | — |
| QUAL-01 | Espace de noms unique `MilitaryDrop`, luacheck, aucune globale | PLAN phase 6 | testé hors jeu | `d43869e`, run_tests (luacheck) | — |
| PUB-01 | Nom affiché « Military Drop », id `batman_MilitaryDrop` | PLAN décisions | testé solo | `346aaa2` | — |

## v1.1 — Largage loin du demandeur

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| DROP-01 | Point tiré à 150-400 cases (sandbox), sur la carte et hors bâtiment (métagrille) | PLAN-V2 étape 0 | testé hors jeu | `555593e`, test_server | C1 en jeu ; MP |
| DROP-02 | Annonce au passage, pose à l'arrivée d'un joueur, quand la case du point est chargée, à 30 cases au plus | PLAN-V2 étape 0 | testé solo | `555593e`, test_flights, E1 (console du 2026-09-30 : livré en 8041,12035, point annoncé, caisse ouverte) | MP |
| DROP-03 | Repli près du demandeur si aucun point lointain ne convient | PLAN-V2 étape 0 | testé hors jeu | `555593e`, test_server | — |
| DROP-04 | Vol interrompu repris après un redémarrage, renvoyé aux clients | PLAN-V2 étape 0 | testé hors jeu | `555593e`, test_flights | F1 en jeu ; MP (reconnexion) |

## Phases 7 et 8 — Tests en jeu et publication

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| TEST-01 | Protocole solo restant : C1, E1, F1, F2, D3, D4 | TEST-PROTOCOL | décidé | — | Partie solo |
| TEST-02 | Partie avec HEF actif | PLAN phase 7 | décidé | — | Partie solo avec HEF |
| TEST-03 | Serveur dédié, 2 clients : appel, écoute, reconnexion pendant un vol, commande forgée | PLAN phase 7 | décidé | — | `C:\pzserver` |
| PUB-02 | Poster, aperçu et icône définitifs | PLAN phase 8 | décidé | — | Skill `pz-workshop-art` ; les actuels sont provisoires |
| PUB-03 | Suppression de `legacy-b41/` avant la sortie | PLAN phase 8 | décidé | — | — |
| PUB-04 | Nouvel élément Workshop B42, lien depuis la page B41 | PLAN décisions | décidé | — | Après TEST-03 |

## Intégrations facultatives

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| FUM-01 | Fumée verte sur la caisse posée si Signal Smoke (`batman_SignalSmoke`) est actif ; durée en option (`CrateSmokeMinutes`, 60 min, 0 = aucune) ; aucun `require` dans `mod.info` | PLAN-V2 décision 17 | testé solo | test_smoke, test_server, E5, « Signal Smoke found » dans la console (test solo du 2026-09-30 (console : vol vers 9703,13014, caisse au point annoncé)) | MP |

## v1.2 — Code chiffré de la semaine (idée 4)

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| CODE-01 | Code qui change chaque lundi à 00:00 (calendrier du jeu), 24 h de grâce, dérivé d'une graine gardée dans un fichier du serveur | PLAN-V2 §4, décisions 8 et 11 | testé solo | test_codes, test_server, G4 (test solo du 2026-09-30 (console : vol vers 9703,13014, caisse au point annoncé)) | G7 (changement de semaine) ; MP |
| CODE-02 | Station de chiffres toutes les 30 min, ondes courtes 10-25 MHz (fréquence libre tirée de la graine, ou option), nom masqué | PLAN-V2 §4, décision 12 | testé solo | test_station, G2 (test solo du 2026-09-30 (console : vol vers 9703,13014, caisse au point annoncé)) | MP (les clients ne reçoivent que le texte chiffré) |
| CODE-03 | Carnet de codes : **un seul par partie** (table fixe dérivée de la graine, seul le code change), 2 pages écrites par le serveur, sur les zombies militaires et dans les réserves de l'armée | PLAN-V2 §4, décision 15 | testé solo | test_notes, test_codes, G3 (test solo du 2026-09-30 (console : vol vers 9703,13014, caisse au point annoncé)) | G5 (rechargement), G9 (butin de l'armée) ; MP |
| CODE-04 | Option `AuthCode` à 4 choix (aucun, fixe en clair, semaine en clair, semaine chiffré), qui remplace `RequireAuthCode` et `PlainCodeOnNotes` | PLAN-V2 décisions 2 et 9 | testé hors jeu | test_core, test_server, test_notes | G8 en jeu |
| CODE-05 | Notes : fréquence militaire, plus, selon `AuthCode`, le code (fixe, ou de la semaine avec sa date de fin) ou la fréquence de la station | PLAN-V2 §4 | testé solo | test_notes, A5 (test solo du 2026-09-30 (console : vol vers 9703,13014, caisse au point annoncé)) | G8 (autres modes) ; MP |
| CODE-07 | « Noter le message » de la station sur une feuille, avec de quoi écrire | PLAN-V2 décisions 14 et 16 | abandonné | — | Retiré le 2026-09-30 à la demande de l'utilisateur après le test solo : jugé inutile, et l'option ne fonctionnait pas en jeu (cause non identifiée, aucune erreur dans la console) |
| DOC-01 | Note militaire en `printMedia` (« Inspecter ») : mémorandum dactylographié, en-tête et insigne, n° de série, fréquence entourée et annotée à la main, tampon SECRET | PLAN-V2 décision 13 | testé solo | test_notes, `source/print_media/preview.py`, A5 (test solo du 2026-09-30 (console : vol vers 9703,13014, caisse au point annoncé)) | MP |
| DOC-02 | Carnet de codes en `printMedia` : dossier kraft ouvert, étiquette, tampon, trombone, feuille avec la grille « groupe / mot » sur deux colonnes | PLAN-V2 décision 13 | testé solo | test_notes, `source/print_media/preview.py`, G3 (test solo du 2026-09-30 (console : vol vers 9703,13014, caisse au point annoncé)) | MP |
| DOC-03 | Textures originales des documents (papier, kraft, bloc de messages, étiquette, trombone, tampon, insigne, stylo, café) générées par `source/print_media/make_textures.py` | PLAN-V2 décision 13 | testé solo | test_notes (textures présentes), aperçu, A5, G3 (test solo du 2026-09-30 (console : vol vers 9703,13014, caisse au point annoncé)) | — |
| CODE-06 | Silence de la base après 3 codes faux dans la journée de jeu, jusqu'au lendemain : même réponse qu'un mauvais canal, compteur en mémoire du serveur seulement | PLAN-V2 décision 10 | testé hors jeu | test_server | G6 en jeu ; MP ; un redémarrage du serveur remet le compteur à zéro |

## v1.3 — Confiance, sources de confiance, poste de commandement (idée 5)

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| CONF-01 | Note de confiance par faction (par joueur sans faction), 0 à 100, départ à 50 | PLAN-V2 §5, décision 7 | décidé | — | — |
| CONF-02 | Indicatif attribué par le serveur, retrouvé après renommage de la faction | PLAN-V2 décision 7 | décidé | — | Faction vanilla sans identifiant stable |
| CONF-03 | Changement de faction : note emportée plafonnée à 50 ; nouvelle faction = plus basse note des fondateurs | PLAN-V2 décision 7 | décidé | — | — |
| CONF-04 | Largages : récupéré +10, perdu −10, pris par une autre faction −5 | PLAN-V2 §5 | conçu | — | À réécrire en termes de faction |
| CONF-05 | Effets : délai ×1,5 à ×0,6, ligne coupée 3 jours sous 15, répliques radio | PLAN-V2 §5 | conçu | — | — |
| CONF-06 | Code faux répété : −2 | PLAN-V2 §5 | conçu | — | — |
| CONF-07 | Érosion lente vers 50 (option) | PLAN-V2 §5 | conçu | — | — |
| CONF-08 | Plafond de +8 par jour et par faction, hors largages | PLAN-V2 §5 | décidé | — | — |
| SRC-01 | Rapport de situation quotidien : +1 | PLAN-V2 §5 | décidé | — | — |
| SRC-02 | Plaques d'identité, matricule transmis : +2 | PLAN-V2 §5 | décidé | — | — |
| SRC-03 | Reconnaissance publique, 48 h de jeu : +3 à la première faction | PLAN-V2 §5, décision 7 | décidé | — | — |
| SRC-04 | Nettoyage public, 72 h de jeu : +5 à la première faction au quota | PLAN-V2 §5, décision 7 | décidé | — | ⚠ tueur d'un zombie connu du serveur en MP ? |
| SRC-05 | Appel de contrôle, 4 h de jeu : +1 à toutes les factions qui répondent | PLAN-V2 §5, décision 7 | à décider | — | Hypothèse « tous ceux qui répondent » à confirmer |
| SRC-06 | Renseignement : documents militaires transmis, +1 à +3 | PLAN-V2 §5 | décidé | — | Après v1.2 |
| SRC-07 | Largage perdu ou cache retrouvé au détecteur : +5 | PLAN-V2 §5 | décidé | — | Avec l'idée 3 |
| SRC-08 | Enregistreur de vol récupéré dans l'épave : +10 | PLAN-V2 §5 | décidé | — | Avec l'idée 8 |
| AUTH-01 | Un membre qui donne le code authentifie toute la faction jusqu'au changement de code | PLAN-V2 décision 7 | décidé | — | À trancher en v1.3 : les missions exigent-elles le code ? Sinon, sans objet (en v1.2, le code ne sert qu'aux largages) |
| AUTH-02 | Réglage et allumage automatiques de la radio pour une faction authentifiée | maquettes, base commune | à décider | — | Proposé avec les maquettes, pas tranché |
| AUTH-03 | Talkie accroché à la ceinture accepté pour émettre | maquettes, base commune | à décider | — | ⚠ état d'une radio à la ceinture connu du serveur en MP ? |
| POSTE-01 | Talkie-walkie : toutes les fonctions restent possibles | PLAN-V2 décision 7 | décidé | — | — |
| POSTE-02 | Poste de commandement : radio non portable, haut de gamme, émettrice (propriétés, aucun nom) | PLAN-V2 décision 7 | décidé | — | — |
| POSTE-03 | Un poste actif par faction, données gardées par le serveur | PLAN-V2 décision 7 | décidé | — | — |
| POSTE-04 | Console « Poste de liaison » : journal, missions en cours, boîte à courrier | PLAN-V2 décision 7 | décidé | — | Maquette : solution 4 |
| POSTE-05 | Journal : messages reçus poste allumé seulement, sinon « aucune réception » | PLAN-V2 décision 7 | décidé | — | ⚠ usure d'une pile ou d'un groupe hors zone chargée |
| POSTE-06 | Bonus de confiance pour les échanges depuis le poste | PLAN-V2 décision 7 | décidé | — | Valeur à calibrer (proposé : +50 %) |

## v1.4 — Formulaire de réquisition (idée 6)

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| REQ-01 | Formulaire : budget de points selon la confiance, sélection revalidée par le serveur | PLAN-V2 §6 | conçu | — | Ouverture depuis le talkie et la console du poste |
| REQ-02 | 18 lots en 3 paliers (catégories vanilla, aucun nom d'objet) | PLAN-V2 §6, décision 4 | conçu | — | Coûts à calibrer |
| REQ-03 | Budget indicatif : 8 à 20 points selon la confiance | PLAN-V2 §6 | conçu | — | À calibrer |
| REQ-04 | Annonce radio sans le contenu commandé | PLAN-V2 §6 | conçu | — | — |
| REQ-05 | Lot Carburant : récipient déjà plein d'essence | PLAN-V2 §6 | conçu | — | ⚠ faisabilité en 42.21 |
| REQ-06 | Lot Explosifs désactivable | PLAN-V2 §6 | conçu | — | — |
| REQ-07 | Points restants convertis en lot surprise | PLAN-V2 §6 | à décider | — | — |
| REQ-08 | Sans formulaire : caisses aléatoires de la v1 | PLAN-V2 §6 | conçu | — | — |

## v1.5 — Largage leurre (idée 9)

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| LEURRE-01 | Commandé seulement par le formulaire, dans un secteur choisi | PLAN-V2 §9, décision 3 | conçu | — | — |
| LEURRE-02 | Indiscernable : mêmes messages, type jamais envoyé ni stocké en clair | PLAN-V2 §9, décision 3 | conçu | — | — |
| LEURRE-03 | Sirène : bruit serveur si la zone est chargée, son local aux joueurs à portée, arrêt par un joueur ou pile vide | PLAN-V2 §9 | conçu | — | — |
| LEURRE-04 | Effet sur la confiance d'un leurre ouvert par une autre faction | PLAN-V2 §9 | à décider | — | À redéfinir avec la confiance de faction |

## Idées à l'étude

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| BAL-01 | Détecteur directionnel : voyant et bip dont la cadence suit la distance, 12 niveaux | analyses/idee-03, décision 5 | conçu | — | Idée mise de côté |
| BAL-02 | Annonce réduite à un secteur, balise à retrouver | analyses/idee-03 | à décider | — | — |
| BAL-03 | Chasses au trésor aléatoires | analyses/idee-03 | à décider | — | — |
| MAY-01 | Hélicoptère abattu, épave 3D démontable, pilote et documents | analyses/idee-08 | à décider | — | Estimation 11 à 15 jours |
| EXT-01 | Extraction et pont avec Opération Artemis | analyses/idee-10 | à décider | — | Modèle MP d'Artemis à trancher ; coût en confiance de faction |

## Journal

- **2026-09-30** — Troisième test solo validé par l'utilisateur, sans erreur dans la console : A5, G2, G3, G4, E1, E5. CODE-01, CODE-02, CODE-03, CODE-05, DOC-01 à DOC-03 et FUM-01 passent en « testé solo ». Restent les cas limites (G5 à G9) et le multijoueur.
- **2026-09-30** — FUM-01 : fumée de Signal Smoke sur la caisse, intégration facultative (Military Drop reste autonome), testée hors jeu (120 tests `lupa`).
- **2026-09-30** — Second test solo : E1 réussi (DROP-02). Corrections : icônes des documents introuvables (`PaperReport`, `Paperwork` : les noms vanilla finissent par un chiffre), lecture trop longue (5 pages → tag `base:fastread`), fréquence décalée dans son ellipse (aperçu recalé sur une capture). « Noter le message » retiré (CODE-07 abandonné).
- **2026-09-30** — Documents en rendu de journal (DOC-01 à DOC-03) et « Noter le message » (CODE-07) testés hors jeu : 122 tests `lupa`, aperçu des trois documents rendu avec les polices du jeu (`source/print_media/preview.py`). Les notes et carnets d'une partie déjà commencée gardent l'ancien format.
- **2026-09-30** — Test solo : le carnet ne déchiffrait pas la station. Ce n'était pas un défaut de calcul : le carnet trouvé était de l'édition 2 (édition suivante, 1 fois sur 10) et la station diffusait l'édition 1. Décision 15 : un seul carnet par partie, option `CodeEditionWeeks` retirée ; la table unique est celle de l'ancienne édition 1, pour que les carnets déjà trouvés restent justes (CODE-03).
- **2026-09-30** — Défaut du test solo (DROP-02) : caisse et horde posées à 24 et 42 cases du repère. La livraison en attente partait dès qu'un chunk se chargeait à moins de 30 cases du point, sur la case chargée la plus proche, en bordure de la zone chargée. Corrigé : on attend que la case du point soit chargée (test_flights).
- **2026-09-30** — Défaut du test solo : réponse de la base en noir sur une radio posée (surcharge `int` de `IsoWaveSignal:AddDeviceText`), corrigé par des couleurs 0-255 (test_client) ; à revoir en jeu (APPEL-01).
- **2026-09-30** — Premier test solo de la v1.2 (en cours) : note et carnet jugés laids dans la fenêtre d'écriture → DOC-01 à DOC-03 ; groupes de la station pénibles à retenir → CODE-07.
- **2026-09-30** — v1.2 (CODE-01 à CODE-06) testée hors jeu : 110 tests `lupa`. Décisions : code réservé aux largages en v1.2 (AUTH-01 revu en v1.3), option `AuthCode` à 4 choix, silence après 3 codes faux par jour, changement le lundi à 00:00, station en ondes courtes 10-25 MHz.
- **2026-09-30** — Création du suivi. Décisions du jour : confiance par faction avec indicatif, missions publiques et délais (4 h, 48 h, 72 h), poste de commandement (un par faction, journal allumé seulement), code qui authentifie la faction, talkie qui garde toutes les fonctions, 18 lots de réquisition, détecteur visuel et sonore, 8 sources de confiance.
- **2026-09-30** — v1.1 (DROP-01 à DROP-04) testée hors jeu (`555593e`).
- **2026-09-30** — v1.0 validée en solo par l'utilisateur, sauf C1, E1, F1, F2, D3, D4.
