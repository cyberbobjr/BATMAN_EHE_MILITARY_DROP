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
| v1.3 | Confiance de faction, sources de confiance, poste de commandement (idée 5) | testé solo, sauf H3, H5, H8, H10 ; MP à faire ([PLAN-V13.md](PLAN-V13.md)) |
| v1.4 | Formulaire de réquisition (idée 6) | testé hors jeu ([PLAN-V14.md](PLAN-V14.md)) |
| v1.5 | Largage leurre (idée 9) | testé hors jeu ([PLAN-V14.md](PLAN-V14.md)) |
| Intégrations | Fumée sur la caisse avec Signal Smoke (facultatif) | testé solo |
| Idée 3 | Balises, détecteur, chasses au trésor | mis de côté |
| Idée 8 | Mayday, épave démontable | à décider |
| Idée 10 | Extraction, pont avec Opération Artemis | à décider |

## v1.0 — Parité B41 et code d'authentification

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| APPEL-01 | Appel par radio militaire : en main, sur le dos, ou posée à 2 cases | PLAN phase 2 | testé solo | `1275061`, `4afeea8`, test_server, B1-B5 | MP : radio d'inventaire exigée en main (dos refusé en MP, 2026-09-30, test_server) ; prise en main automatique avec AUTH-03 |
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
| BUTIN-05 | Démonter la caisse larguée vide, avec les règles vanilla du bois (marteau et scie, Menuiserie, durée, planches lues dans les définitions du jeu) ; le serveur revérifie tout | Demande du test solo du 2026-10-01 | testé solo | test_dismantle, H14 (validé par l'utilisateur (test solo du 2026-10-01, second passage)) | MP (caisse retirée chez tous, deux joueurs en même temps) |
| HELI-01 | Hélicoptère simulé : son, ombre, flèche, vol stationnaire | PLAN phase 3 | testé solo | `4aee311`, test_heli, test_flight, C1-C4 | C1 à refaire avec la distance v1.1 ; MP |
| HELI-02 | Cohabitation avec HEF : attente de ses événements, 112,2 MHz réservée | PLAN décisions | testé hors jeu | `4aee311`, test_flights, test_core | Partie avec HEF |
| RADIO-01 | Chaîne « Logistique » : départ, coordonnées répétées, fin ; nom caché | PLAN phase 4 | testé solo | `8132d90`, test_broadcast, D1 | D3 (nom caché) ; MP |
| RADIO-03 | Fréquence militaire tirée au hasard par défaut (120-170 MHz, dérivée de la graine du serveur) ; une valeur fixée en option est publique | PLAN-V2 décision 23 | testé solo | test_broadcast, test_core, test_notes, H12 (test solo du 2026-10-01) | MP (fréquence absente du client) |
| RADIO-02 | Repère de carte pour les seuls auditeurs | PLAN phase 4 | testé solo | `8132d90`, test_announce, D2 | D4 (radio éteinte) ; MP |
| RADIO-04 | Talkie accroché à la ceinture : « Options de l'appareil », reste allumé quand sa fenêtre est ouverte, entend en solo les messages du mod (base, missions, largages, station de chiffres) ; les autres chaînes restent vanilla | Retour du test solo du 2026-10-01 | testé solo | test_beltradio, test_client, H13 (validé par l'utilisateur (test solo du 2026-10-01, second passage)) | MP (un client reçoit déjà à la ceinture : aucune ligne en double) |
| RADIO-05 | Repère de carte de la reconnaissance (symbole « Eye » bleu) pour les seuls auditeurs de l'annonce | Retour du test solo du 2026-10-01 | testé solo | test_announce, test_broadcast, test_missions, H4 (validé par l'utilisateur (test solo du 2026-10-01, second passage)) | MP |
| CAISSE-01 | Caisse 3D originale : véhicule sans roues avec coffre | PLAN phase 5 | testé solo | `e6b5ceb`, test_crate, E1-E3 | F2 ; MP |
| CAISSE-02 | Horde (3-30) et bruit au largage | PLAN phase 2 | testé solo | `1275061`, test_server, E2 | MP |
| OPT-01 | Options sandbox traduites EN/FR | PLAN phase 1 | testé solo | `cdaadf5`, `555593e`, test_core, run_tests (traductions) | — |
| QUAL-01 | Espace de noms unique `MilitaryDrop`, luacheck, aucune globale | PLAN phase 6 | testé hors jeu | `d43869e`, run_tests (luacheck) | — |
| PUB-01 | Nom affiché « Military Drop », id `batman_MilitaryDrop` | PLAN décisions | testé solo | `346aaa2` | — |

## v1.1 — Largage loin du demandeur

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| DROP-01 | Point tiré à 150-400 cases (sandbox), sur la terre ferme : route (zone « Nav »), sinon pied d'un bâtiment (la métagrille ne connaît pas l'eau) | PLAN-V2 étape 0 | testé hors jeu | `555593e`, test_server, test_server (drop_point_lands_on_a_road_never_in_open_water) | Corrigé le 2026-10-01 après un largage dans l'eau : à rejouer (largage forcé près d'un lac) ; C1 ; MP |
| DROP-02 | Annonce au passage, pose à l'arrivée d'un joueur, quand la case du point est chargée, à 30 cases au plus | PLAN-V2 étape 0 | testé solo | `555593e`, test_flights, E1 (console du 2026-09-30 : livré en 8041,12035, point annoncé, caisse ouverte) | MP |
| DROP-03 | Repli près du demandeur si aucun point lointain ne convient | PLAN-V2 étape 0 | testé hors jeu | `555593e`, test_server | — |
| DROP-04 | Vol interrompu repris après un redémarrage, renvoyé aux clients | PLAN-V2 étape 0 | testé hors jeu | `555593e`, test_flights | F1 en jeu ; MP (reconnexion) |

## Phases 7 et 8 — Tests en jeu et publication

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| TEST-01 | Protocole solo restant : C1, E1, F1, F2, D3, D4 | TEST-PROTOCOL | décidé | — | Partie solo |
| TEST-02 | Partie avec HEF actif | PLAN phase 7 | décidé | — | Partie solo avec HEF |
| TEST-03 | Serveur dédié, 2 clients : appel, écoute, reconnexion pendant un vol, commande forgée | PLAN phase 7 | décidé | — | `C:\pzserver` |
| PUB-02 | Poster, aperçu et icône définitifs | PLAN phase 8 | codé | `poster.png`, `preview.png`, `icon.png` (Codex, validés par l'utilisateur) | Vérifier le poster et l'icône dans le sélecteur de mods du jeu |
| PUB-03 | Suppression de `legacy-b41/` avant la sortie | PLAN phase 8 | décidé | — | — |
| PUB-04 | Nouvel élément Workshop B42, lien depuis la page B41 | PLAN décisions | publié | Workshop `3811752923` (privé), `workshop.txt` | Passer en public après TEST-03 ; lien depuis la page B41 |
| PUB-05 | Mod multilingue : DE, ES, PT, PTBR, RU, CN en plus de EN/FR (jeu et description Steam) | demande utilisateur | testé hors jeu | run_tests (clés, paramètres, balises, tailles) | Largeur des libellés longs (DE, PT) à voir en jeu ; documents en anglais en CN (polices SDF sans CJK) |
| PUB-06 | Illustrations d'en-tête de la description Steam (bannière + 6 sections), hébergées sur GitHub | demande utilisateur | codé | `docs/guide/images/steam-*.png` | Validation par l'utilisateur |

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
| CODE-06 | Silence de la base après 3 codes faux dans la journée de jeu, jusqu'au lendemain : même réponse qu'un mauvais canal, compteur en mémoire du serveur seulement | PLAN-V2 décision 10 | testé solo | test_server, G6 (test solo du 2026-10-01, 5e passage) | MP |

## v1.3 — Confiance, sources de confiance, poste de commandement (idée 5)

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| CONF-01 | Note de confiance par faction (par joueur sans faction), 0 à 100, départ à 25 (révisé le 2026-10-01 : 50 rendait le départ trop facile) | PLAN-V2 §5, décision 7 | testé solo | test_trust, test_teams, H9 (test solo du 2026-10-01, 3e passage) | MP (serveur dédié, 2 clients) |
| CONF-02 | Indicatif attribué par le serveur, retrouvé après renommage de la faction | PLAN-V2 décision 7 | testé hors jeu | test_teams | Solo : une seule équipe « SOLO » (le nom du joueur change avec chaque personnage) ; MP : renommage, changement de propriétaire, dissolution |
| CONF-03 | Changement de faction : note emportée plafonnée à 50 ; nouvelle faction = plus basse note des fondateurs | PLAN-V2 décision 7 | testé hors jeu | test_teams | Protocole H en solo ; MP (serveur dédié, 2 clients) |
| CONF-04 | Largages : récupéré +10, perdu −10, pris par une autre faction −5 | PLAN-V13, Confiance | testé solo | test_trust, test_crate, test_flights, H9 (test solo du 2026-10-01) | Caisse perdue (48 h) ou prise par une autre faction ; MP |
| CONF-05 | Effets : délai ×1,5 à ×0,6, ligne coupée 3 jours sous 15, répliques radio | PLAN-V2 §5 | testé hors jeu | test_trust, test_server, test_client | Protocole H en solo ; MP (serveur dédié, 2 clients) |
| CONF-06 | Code faux répété : −2 | PLAN-V2 §5 | testé hors jeu | test_trust, test_server | Un appel sur une mauvaise fréquence compte aussi (la note ne doit pas révéler le canal) ; protocole H ; MP |
| CONF-07 | Érosion lente vers 50 (option) | PLAN-V2 §5 | testé hors jeu | test_trust | Protocole H en solo ; MP (serveur dédié, 2 clients) |
| CONF-08 | Plafond de +8 par jour et par faction, hors largages | PLAN-V2 §5 | testé hors jeu | test_trust | Protocole H en solo ; MP (serveur dédié, 2 clients) |
| SRC-01 | Rapport de situation quotidien : +1 | PLAN-V2 §5 | testé solo | test_missions, test_exchange, H1 (test solo du 2026-10-01) | MP (serveur dédié, 2 clients) |
| SRC-02 | Plaques d'identité vanilla des soldats tombés (tag du jeu, nom du soldat, ni la sienne ni une plaque vierge), transmises une fois : +2 | PLAN-V2 §5 | testé solo | test_missions, test_exchange, test_post, H2 (validé par l'utilisateur (test solo du 2026-10-01, second passage)) | MP (plaque retirée chez les autres clients) |
| SRC-03 | Reconnaissance publique, 48 h de jeu : +3 à la première faction | PLAN-V2 §5, décision 7 | testé solo | test_missions, H4 (validé par l'utilisateur (test solo du 2026-10-01, second passage)) | Point corrigé (centre d'un bâtiment, sinon route, jamais l'eau) : H4 à rejouer ; MP |
| SRC-04 | Nettoyage public, 72 h de jeu : horde signalée (taille en option, 30) qui apparaît à l'arrivée du premier joueur, zombies suivis ; à 90 % de la horde morte, +5 à l'équipe qui en a abattu le plus ; « Faire le point » par radio | PLAN-V13, SRC-04 | testé hors jeu | test_missions, test_post, test_radiomodule | H5 à rejouer (horde, « Faire le point », 90 %) ; MP |
| SRC-05 | Appel de contrôle, 4 h de jeu : +1 à toutes les factions qui répondent | PLAN-V13, SRC-05 | testé solo | test_missions, H3 (test solo du 2026-10-01, 3e passage) | MP |
| SRC-09 | Missions à la demande pour un admin : clic droit d'une radio militaire → « Missions (admin) » → lancer ou clore une reconnaissance, un nettoyage ou un appel de contrôle (clôture : annonce d'annulation, sans récompense) ; même mission que la planification (annonce, repère, quota, échéance), droit revérifié par le serveur | Demande de l'utilisateur du 2026-10-01 | testé solo | test_missions, test_client, H15 (test solo du 2026-10-01, 5e passage) | MP (refus d'un non-admin) |
| SRC-06 | Renseignement : documents militaires transmis, +1 à +3 | PLAN-V2 §5 | décidé | — | Reporté après la v1.3 (2026-09-30) : attend de nouveaux documents (idée 8) |
| SRC-07 | Largage perdu ou cache retrouvé au détecteur : +5 | PLAN-V2 §5 | décidé | — | Avec l'idée 3 |
| SRC-08 | Enregistreur de vol récupéré dans l'épave : +10 | PLAN-V2 §5 | décidé | — | Avec l'idée 8 |
| AUTH-01 | Un membre qui donne le code authentifie toute la faction jusqu'au changement de code | PLAN-V13 décisions | abandonné | — | Sans objet (2026-09-30) : le code de la semaine ne sert qu'aux largages ; rapports, plaques, missions et poste se font sans code |
| AUTH-02 | Réglage et allumage automatiques de la radio pour une faction authentifiée | PLAN-V13 décisions | abandonné | — | Abandonné (2026-09-30) : le joueur règle sa radio ; un réglage automatique révélerait la fréquence |
| AUTH-03 | Talkie accroché à la ceinture accepté pour émettre | PLAN-V13 décisions | testé solo | test_exchange, test_server, B2, H1, H10 (test solo du 2026-10-01, 3e passage) | MP (prise en main synchronisée) |
| POSTE-01 | Talkie-walkie : toutes les fonctions restent possibles | PLAN-V2 décision 7 | testé hors jeu | test_exchange | Protocole H en solo ; MP (serveur dédié, 2 clients) |
| POSTE-02 | Poste de commandement : radio non portable, haut de gamme, émettrice (propriétés, aucun nom) | PLAN-V2 décision 7 | testé solo | test_post, H6 (test solo du 2026-10-01) | MP (serveur dédié, 2 clients) |
| POSTE-03 | Un poste actif par faction, données gardées par le serveur | PLAN-V2 décision 7 | testé solo | test_post, H6, H7 (test solo du 2026-10-01) | MP : autre faction refusée |
| POSTE-07 | Radio fixe éligible : la section de la fenêtre radio devient un bouton « Poste de liaison » (installe, ouvre, ou transfère le poste après confirmation) ; le menu contextuel « Installer le poste » et « Poste de liaison » disparaît ; la console reçoit un champ du code conservé comme celui du talkie | Demande de l'utilisateur du 2026-10-01 | testé solo | test_post, test_radiomodule, test_postwindow, test_client, H6 (test solo du 2026-10-01, 5e passage) | K9, K10 (code conservé, champ de la console) ; MP |
| POSTE-04 | Console « Poste de liaison » au style d'un poste radio militaire : journal sur écran à phosphore, voyants, ordres de mission avec échéance, plaques de l'équipe à annoncer (« Annoncer les matricules », plus de notion de courrier), confiance en toutes lettres | PLAN-V2 décision 7 | testé solo | test_post, test_postwindow, H6, H7, H11 (test solo du 2026-10-01, 3e passage) | MP |
| POSTE-05 | Journal : messages reçus poste allumé seulement, sinon « aucune réception » | PLAN-V2 décision 7 | testé solo | test_post, H8 (test solo du 2026-10-01, 3e passage) | MP |
| POSTE-06 | Bonus de confiance pour les échanges depuis le poste | PLAN-V2 décision 7 | testé hors jeu | test_post, test_trust | Protocole H en solo ; MP (serveur dédié, 2 clients) |

## v1.4 — Formulaire de réquisition (idée 6)

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| REQ-01 | Formulaire de réquisition après un appel accepté (talkie, radio posée ou console du poste) : budget selon la confiance, sélection revalidée par le serveur (autorisation de 5 min, radio, ligne, délai, paliers, budget) | PLAN-V14 | testé solo | test_requisition, test_requisitionwindow, test_client, test_postwindow, I1-I4, I7 (test solo du 2026-10-01, 3e passage), I8 (test solo du 2026-10-01, 4e passage), I9 (test solo du 2026-10-01, 5e passage) | I10 (palier I au départ) ; MP |
| REQ-02 | 18 lots en 3 paliers (catégories vanilla, aucun nom d'objet) | PLAN-V2 §6, décision 4 | testé solo | test_lots, test_requisition, I2, I5 (test solo du 2026-10-01, 3e passage) | Coûts à calibrer ; MP |
| REQ-03 | Budget : (4 + note × 0,16) × option, soit 8 points au départ (25) à 20 à 100 ; paliers : I dès le départ, II à 50, III à 75 (options) | PLAN-V2 §6 | testé solo | test_requisition, I2 (test solo du 2026-10-01, 3e passage) | Départ à 25 et palier II à 50 (décision du 2026-10-01) ; à calibrer en jeu |
| REQ-04 | Annonce radio sans le contenu commandé | PLAN-V2 §6 | testé solo | test_requisition, test_server, I3 (test solo du 2026-10-01, 3e passage) | MP |
| REQ-05 | Lots Eau potable et Carburant : récipient vidé puis rempli à sa capacité (`Fluid` du moteur), sans nom d'objet | PLAN-V2 §6 | testé solo | test_lots, test_requisition, I5 (test solo du 2026-10-01, 3e passage) | MP |
| REQ-06 | Lot Explosifs désactivable | PLAN-V2 §6 | testé hors jeu | test_lots | — |
| REQ-07 | Points restants convertis en lot surprise | PLAN-V14 décisions | testé solo | test_requisitionwindow, test_requisition, I2 (test solo du 2026-10-01, 3e passage) | — |
| REQ-08 | Sans formulaire : caisses aléatoires de la v1 | PLAN-V2 §6 | testé solo | test_requisition, test_server, I6 (test solo du 2026-10-01, 3e passage) | — |
| REQ-09 | Lots définis dans un fichier du serveur (`Zomboid/Lua/MilitaryDrop/requisition.txt`, commun aux parties, créé avec les 18 lots) : filtres déclaratifs, lots désactivés ou ajoutés (textes EN/FR), lecteur de données sans exécution de code, repli sur les lots par défaut, rechargement admin | Demande de l'utilisateur du 2026-10-01 | testé solo | test_lotsfile, test_lots, test_requisition, K6 (test solo du 2026-10-01, 4e passage) | K7, K8 non joués (l'utilisateur s'en remet aux tests hors jeu) ; notice en anglais seulement (demande du 2026-10-01) ; MP (`ReloadLots` admin) |

## v1.5 — Largage leurre (idée 9)

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| LEURRE-01 | Commandé seulement par le formulaire, exclusif, dans un secteur N, E, S ou O (point tiré dans le quart de cercle) | PLAN-V2 §9, décision 3 | testé solo | test_requisition, test_requisitionwindow, J1 (test solo du 2026-10-01, 4e passage) | MP |
| LEURRE-02 | Indiscernable : mêmes messages, type jamais envoyé ni stocké en clair | PLAN-V2 §9, décision 3 | testé solo | test_decoy, test_requisition, J1, J2 (test solo du 2026-10-01, 4e passage) | MP (l'autre joueur ne distingue rien avant le coffre) |
| LEURRE-03 | Sirène à la pose : bruit serveur répété (modèle de la sirène de véhicule) si la case est chargée, boucle locale pour les joueurs à 300 cases, échéance en option ; coupée par un joueur (action revérifiée) ou au démontage | PLAN-V2 §9 | testé solo | test_decoy, test_siren, test_dismantle, J2-J4 (test solo du 2026-10-01, 4e passage) | MP (portée, reconnexion) |
| LEURRE-04 | Effet sur la confiance d'un leurre ouvert par une autre faction | PLAN-V14 décisions | testé solo | test_trust, test_requisition, J4 (test solo du 2026-10-01, 4e passage) | — |

## Idées à l'étude

| ID | Élément | Réf. | État | Preuves | Reste |
|---|---|---|---|---|---|
| BAL-01 | Détecteur directionnel : voyant et bip dont la cadence suit la distance, 12 niveaux | analyses/idee-03, décision 5 | conçu | — | Idée mise de côté |
| BAL-02 | Annonce réduite à un secteur, balise à retrouver | analyses/idee-03 | à décider | — | — |
| BAL-03 | Chasses au trésor aléatoires | analyses/idee-03 | à décider | — | — |
| MAY-01 | Hélicoptère abattu, épave 3D démontable, pilote et documents | analyses/idee-08 | à décider | — | Estimation 11 à 15 jours |
| EXT-01 | Extraction et pont avec Opération Artemis | analyses/idee-10 | à décider | — | Modèle MP d'Artemis à trancher ; coût en confiance de faction |
| RADIO-06 | Module « Logistique » dans la fenêtre radio du jeu (radio militaire) : saisie du code, largage, rapport, matricules, reconnaissance, contrôle, dernière réponse de la base ; la feuille de réquisition s'ouvre collée à la fenêtre radio | Décision de l'utilisateur du 2026-10-01 | testé solo | test_radiomodule, test_client, test_requisitionwindow, `source/radio_module/preview.py`, B1, B2, K1-K4 (test solo du 2026-10-01, 3e passage) | K5 (manette, pas de manette pour le test) ; MP ; code saisi gardé d'une session à l'autre, par personnage (demande du 2026-10-01, en cours) |

## Journal

- **2026-10-02** — Première mise en ligne en privé : élément Workshop `3811752923`, version 0.1.0, descriptions dans les 8 langues publiées, aucune capture touchée (PUB-04).
- **2026-10-02** — Poster validé par l'utilisateur et installé (poster du sélecteur, aperçu Workshop 512 px) ; icône 64 px générée par Codex à partir du poster (caisse sous parachute), fond blanc enfermé entre les sangles retiré au détourage (PUB-02).
- **2026-10-02** — Préparation de la publication : six langues ajoutées par des sous-agents (PUB-05, 470 clés chacune, descriptions Steam traduites avec la mention « multijoueur conçu mais non testé ») ; bannière et six illustrations de section générées par Codex dans le style maison, insérées dans les 8 descriptions et `workshop.txt` (PUB-06) ; poster généré (PUB-02, à valider).
- **2026-10-01** — Largage forcé tombé dans l'eau (test de l'utilisateur) : le point de largage était encore tiré au hasard sur la métagrille, qui ne connaît pas l'eau (les missions étaient déjà corrigées). Il vise maintenant une route (zone « Nav »), sinon le pied d'un bâtiment, avec le secteur du leurre respecté ; la caisse se pose ensuite sur la case libre la plus proche.
- **2026-10-01** — Cinquième test solo : bouton « Poste de liaison » (POSTE-07), silence après 3 codes faux (CODE-06), largage et missions de l'admin (SRC-09, I9) réussis. Guide public (`docs/guide/`, EN/FR) et descriptions Steam EN/FR rédigés ; `b42` fusionnée dans `main`.
- **2026-10-01** — Confiance de départ abaissée à 25 (palier I seulement, délai ×1,25, 8 points de réquisition) ; palier II de nouveau à 50, palier III à 75 ; le délai reste ×1 à 50. Notes internes déplacées de `docs/` vers `dev/` ; guide public en préparation dans `docs/guide/`.
- **2026-10-01** — Console du poste : elle reste ouverte quand on clique sur ses boutons (« Demander un largage » la fermait pour laisser la place au formulaire ; la feuille s'ouvre maintenant collée à elle) ; une réponse « trop loin » du serveur ne la ferme plus ; chaque fermeture est notée au journal avec sa cause.

- **2026-10-01** — Nettoyage par horde suivie (apparition à l'arrivée, zombies suivis par leur tenue persistante, 90 % et meilleur tireur, « Faire le point »), code saisi conservé dans un fichier client par partie et personnage (la ModData du joueur n'est pas sauvegardée côté client en MP et serait vue des voisins), radio fixe : bouton « Poste de liaison » (installer, ouvrir, transférer avec confirmation), champ du code dans la console. 533 tests `lupa`.
- **2026-10-01** — SRC-04 révisé : le nettoyage ne compte plus tout zombie de la zone (quota parfois impossible, aucun retour au joueur) mais une horde signalée et suivie ; victoire à 90 % de la horde morte pour l'équipe qui en a abattu le plus ; échange « Faire le point » dans la section Logistique. Commit `16a67fb` (clôture admin des missions).
- **2026-10-01** — SRC-09 : missions lancées à la demande par un admin (sous-menu « Missions (admin) »), commit `5b72d23` pour les corrections précédentes.
- **2026-10-01** — Quatrième test solo : I8, J1-J4, K6 réussis ; K7 et K8 non joués (confiance dans les tests hors jeu). Notice de `requisition.txt` en anglais seulement, à la demande de l'utilisateur.
- **2026-10-01** — Corrections après le 3e test solo : missions sur un bâtiment ou une route (jamais dans l'eau), repère de carte du nettoyage, formulaire au largage forcé de l'admin (tous les lots, 20 points, délai non consommé), palier II à 60. 510 tests `lupa`.
- **2026-10-01** — Troisième test solo de l'utilisateur : B1, B2, H1-H3, H6-H14, I1-I7, K1-K4 réussis ; K5 non joué (pas de manette). Échecs ou manques : H4 (reconnaissance tirée dans l'eau), H5 (pas de repère pour le nettoyage) ; le largage forcé de l'admin n'ouvre pas le formulaire, ce qui a empêché I8, J et K6-K8 (délai entre largages). Corrections confiées à un sous-agent.
- **2026-10-01** — v1.4 et v1.5 committées (`397fe78`). RADIO-06 (module « Logistique » dans la fenêtre radio du jeu, code mémorisé pendant la session, feuille collée à la fenêtre) et REQ-09 (fichier de lots `requisition.txt` du serveur, `.txt` car `getFileWriter` refuse `.lua`) codés par deux sous-agents, testés hors jeu : 472 tests `lupa`. Pages de présentation fusionnées en une seule. Relecture indépendante corrigée (talkie à la ceinture qui restait allumé pendant sa prise en main, cache des fluides, langue de repli, lot retiré du fichier, `ReloadLots` réservé aux admins avec réponse, feuille paginée au-delà de ce que l'écran affiche, troncatures sûres en Kahlua, manette). Le module remplace le menu contextuel « Logistique » et « Demander un largage » (décision de l'utilisateur) ; seul le largage forcé de l'admin reste au clic droit.
- **2026-10-01** — v1.4 et v1.5 codées par trois sous-agents (réquisition serveur, formulaire client, leurre) et intégrées : 18 lots tirés des catégories du jeu, budget selon la confiance, formulaire papier militaire (aussi depuis la console du poste), caisses de réquisition ouvertes comme les caisses de ravitaillement, eau et essence remplies à la création ; leurre à sirène exclusif, par secteur, indiscernable jusqu'au coffre, sans effet sur la confiance. 426 tests `lupa`, 44 options. Relecture indépendante, sans bloquant, corrigée : formulaire précalculé au démarrage en un seul passage des tables (au lieu de 18, sans instancier pour le carburant) ; sirène : resynchronisation qui n'efface plus les autres auditeurs, écran partagé ; repli au sol nommé avant l'envoi aux clients ; lot Paquetage limité aux vrais sacs et contenants de transport ; leurre sans point dans le secteur : la feuille se rouvre sans rappeler. Limite documentée : nom des caisses dans la langue du serveur. 444 tests.
- **2026-10-01** — v1.4 et v1.5 lancées d'un bloc par trois sous-agents (réquisition serveur, formulaire client, leurre), spécification [PLAN-V14.md](PLAN-V14.md). Décisions : REQ-07 points non dépensés perdus ; LEURRE-04 aucun effet sur la confiance. v1.3 committée (`4b96f44`).

- **2026-10-01** — Test solo de la v1.3 (H1, H2, H4 en main, H6, H7, H9, H11, H12) : RADIO-03, SRC-01, CONF-04, POSTE-02 et POSTE-03 passent en « testé solo ». Corrections demandées, faites par quatre sous-agents puis intégrées : talkie à la ceinture (RADIO-04), repère de la reconnaissance (RADIO-05), plaques vanilla seulement (SRC-02 révisé, option `DogTagDropRate` retirée), console du poste redessinée (POSTE-04), démontage de la caisse (BUTIN-05). Le démontage suit la définition vanilla active du bois, qui demande aussi une scie. Retour suivant de l'utilisateur : le talkie à la ceinture n'entendait pas la station de chiffres (seule la chaîne militaire était suivie) ; corrigé, les deux chaînes du mod sont suivies. Retour sur la console (POSTE-04) : heure du journal collée au texte (espaces avalés par `ISRichTextPanel`, corrigé par `<SPACE>`) ; écusson de confiance jugé peu clair, remplacé à la demande de l'utilisateur par du texte seul (phrase du commandement et effet sur les largages). Le reste du test est validé par l'utilisateur. Relecture indépendante, corrigée : brouillage de l'orage appliqué au talkie à la ceinture (sinon coordonnées en clair et repère posé), enveloppe de la fenêtre radio reposée après rechargement, plaques gardées quand la confiance est au maximum, dépôt au poste refusé si les plaques sont désactivées ou la ligne coupée, console de chaque joueur en écran partagé et fermée quand le poste n'est plus le sien. Limites connues : la pile d'un talkie à la ceinture ne baisse qu'à sa reprise en main (règle vanilla) ; un joueur qui arrive après l'annonce d'une reconnaissance n'a pas son repère. 338 tests `lupa`.
- **2026-10-01** — Relecture indépendante de la v1.3 et corrections : état de la v1.3 (équipes, confiance, largages, missions, postes, courrier) déplacé de la ModData publique vers une table privée au nom tiré de la graine (la position des postes ne fuit plus) ; fréquence militaire tirée au hasard par défaut (RADIO-03, décision 23) ; un joueur réduit au silence compte encore pour CONF-06 ; cadence de 3 s sur la transmission du courrier et réponses « occupé » (POSTE-04) ; resynchronisation des radios d'inventaire en MP (AUTH-03) ; factions relues au démarrage (CONF-02) ; console du poste en écran partagé. Silence après balayage des fréquences écarté : la triche par client modifié n'est pas une priorité (serveur entre amis, mode debug réservé aux admins). 280 tests `lupa`.
- **2026-10-01** — v1.3 (CONF-01 à CONF-08, SRC-01 à SRC-05, AUTH-03, POSTE-01 à POSTE-06) codée par trois sous-agents (équipes et confiance ; sources et missions ; poste de commandement) et testée hors jeu : 257 tests `lupa`. Revue du coordinateur : fuite de la fréquence par la note de confiance corrigée (CONF-06), branchements explicites entre modules (`Client.HANDLERS`, journal du poste appelé par la chaîne militaire), contrôle des clés de traduction et des options citées ajouté à `run_tests.py`.
- **2026-09-30** — v1.3 conçue ([PLAN-V13.md](PLAN-V13.md)), développée d'un bloc par sous-agents. Décisions : AUTH-01 et AUTH-02 abandonnés, AUTH-03 (talkie pris en main), SRC-05 (toutes les factions à temps), SRC-06 reporté. Vérifications du moteur : tueur d'un zombie connu du serveur ; état d'une radio d'inventaire appliqué par le serveur en main seulement (radio sur le dos refusée en MP).
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
