# Protocole de test en jeu (phase 7)

Chaque étape donne l'action, puis le résultat attendu. Noter tout écart et garder `C:\Users\cyber\Zomboid\console.txt` (surveillé en direct par `.claude/tools/pzwatch.py` avec `PZWATCH_MOD_RE='MilitaryDrop'`).

## Préparation (solo)

1. Lancer le jeu en mode debug (`-debug` dans les options de lancement Steam).
2. Mods : activer **Military Drop** (id `batman_MilitaryDrop`) seul (HEF désactivé pour ce premier passage).
3. Nouvelle partie « bac à sable ». Page **Military Drop** des options :
   - vérifier les 44 options et leurs libellés en français ;
   - **Heures entre deux largages** : 1 ; **Fréquence des notes militaires** : Débogage (1/2) ; **Fréquence des carnets de codes** : Débogage (1/2) ; **Journal de débogage** : activé ; le reste par défaut (**Fréquence radio** : 0 = tirée au hasard, **Code d'authentification** : code de la semaine chiffré).
4. En jeu, se placer **dehors**, dans un endroit dégagé.

Commandes utiles (console Lua du mode debug, touche F11 puis onglet Lua, ou `~`) :

```lua
-- Matériel
getPlayer():getInventory():AddItem("Base.WalkieTalkie5")
getPlayer():getInventory():AddItem("Base.Battery")
getPlayer():getInventory():AddItem("MilitaryDrop.MilitaryMemo")
-- Code en vigueur (solo seulement : le code du serveur est dans le même Lua)
print(MilitaryDrop.Server.getCode())
-- Fréquence militaire de la partie (MHz, tirée au hasard ; solo seulement)
print(MilitaryDrop.Config.formatChannel(MilitaryDrop.Config.getChannel()))
-- Fréquence de la station de chiffres (kHz) et carnet de codes
print(MilitaryDrop.NumbersStation.frequency)
getPlayer():getInventory():AddItem("MilitaryDrop.Codebook")
-- Caisses de ravitaillement
getPlayer():getInventory():AddItem("MilitaryDrop.AmmoSupplyCase")
```

## A. Objets et recette (phase 1)

| # | Action | Attendu |
|---|---|---|
| A1 | Ajouter les 4 caisses `MilitaryDrop.*SupplyCase`, puis les poser au sol | Noms « Caisse de ravitaillement militaire (…) », icônes d'étuis militaires, infobulle ; au sol, étuis verts texturés (pas de damier) |
| A2 | Clic droit sur chaque caisse, dans l'inventaire | « Ouvrir la caisse de ravitaillement » ; munitions ×5, 1 arme **avec 2 chargeurs (si elle en prend) et 1 boîte de munitions**, équipement ×5, accessoires ×5 |
| A5 | Ajouter une note par la console (`AddItem("MilitaryDrop.MilitaryMemo")`), clic droit | Icône de rapport (pas de « ? ») ; « Inspecter » s'ouvre en une seconde environ ; fenêtre de journal : note de service dactylographiée, en-tête, n° de série, 151.4 MHz entourée au stylo, annotation manuscrite avec la fréquence de la station, tampon SECRET ; bouton du bas : transcription en texte simple |
| A3 | Poser une caisse au sol et l'ouvrir par clic droit | Même résultat, sans erreur |

## B. Appel radio (phase 2)

Depuis le 2026-10-01 (RADIO-06), tout passe par la section « Logistique » de la fenêtre radio (clic droit → « Options de l'appareil ») : le menu contextuel « Logistique » et « Demander un largage » n'existent plus (seul le largage forcé de l'admin reste au clic droit).

| # | Action | Attendu |
|---|---|---|
| B1 | Talkie militaire **éteint**, en main : « Options de l'appareil », section « Logistique » | « Demander un largage » grisé, infobulle « La radio doit être allumée. » ; au clic droit, plus d'option « Demander un largage » ni de menu « Logistique » |
| B2 | Talkie militaire dans un sac porté : clic droit → « Options de l'appareil » | Le personnage le prend en main et sa fenêtre s'ouvre aussitôt, allumée, avec la section « Logistique » |
| B3 | Talkie allumé en main, réglé sur **150,0 MHz**, appel avec le code juste | Le personnage parle, puis après ~5 s : « …grésillements. Personne ne répond… » |
| B4 | Régler la **fréquence militaire** (celle de la note), appel avec un **code faux** | Même réponse qu'en B3 (grésillements) : on ne peut pas distinguer fréquence et code |
| B5 | Même chose avec le **code juste** (`print(MilitaryDrop.Server.getCode())`, en minuscules, avec espaces) | Réponse d'accord de la base après ~5 s |
| B6 | Rappeler aussitôt avec le code juste | « Je ne peux pas les joindre… dans 1 heures » |
| B7 | Tuer quelques zombies policiers ou militaires | Une « Note de service militaire » sur certains cadavres ; clic droit : **Inspecter** ; même document qu'en A5 |

## C. Hélicoptère (phase 3) — après B5

| # | Action | Attendu |
|---|---|---|
| C1 | Écouter et regarder | Son d'hélicoptère qui passe au loin ; flèche de direction à moins de 400 cases de l'hélicoptère. Le point de largage est **entre 150 et 400 cases** du joueur (options « Distance minimale/maximale du largage ») |
| C2 | Au passage | Ombre qui passe au sol, vol stationnaire ~8 s au-dessus du point |
| C3 | Départ | L'hélicoptère repart, le son décroît puis s'arrête ; plus d'ombre ni de flèche |
| C4 | Pause (Échap) pendant un vol | L'hélicoptère s'arrête aussi |

## D. Annonces et carte (phase 4)

| # | Action | Attendu |
|---|---|---|
| D1 | Garder le talkie allumé sur la fréquence militaire | « À toutes les stations, ici Logistique… » au départ, puis les coordonnées répétées au largage, puis « terminé » |
| D2 | Ouvrir la carte | Symbole « cible » vert au point de largage, un seul |
| D3 | Panneau de la radio réglée sur la fréquence militaire | Chaîne affichée comme inconnue (pas « Military Logistics ») |
| D4 | Nouvel appel (attendre 1 h de jeu), radio **éteinte** au moment du largage | Pas de nouveau symbole |

## E. Caisse (phase 5)

| # | Action | Attendu |
|---|---|---|
| E1 | Aller au point de largage (repère de carte) | En arrivant, la caisse 3D (palette, caisse olive, sangles, « U.S. ARMY ») apparaît au point annoncé ou à moins de 30 cases, posée au sol, ni enfoncée ni flottante |
| E2 | Horde | Zombies autour de la caisse (3 à 30 par défaut) |
| E3 | Ouvrir le coffre (clic droit / menu véhicule) | Coffre « Caisse de largage militaire » avec 6 caisses de ravitaillement |
| E4 | Largage admin (« Forcer un largage ») sur une radio éteinte, rangée dans l'inventaire | Accepté ; coordonnées en message privé ; délai non modifié |
| E5 | Avec le mod **Signal Smoke** actif : aller au point de largage | Fumée verte sur la caisse, visible en approchant, pendant 60 minutes de jeu ; sans Signal Smoke, aucune fumée et aucune erreur |

## F. Sauvegarde

| # | Action | Attendu |
|---|---|---|
| F1 | Sauvegarder et quitter **pendant un vol**, recharger | L'hélicoptère reprend son vol (son, ombre) et largue normalement |
| F2 | Recharger une partie avec une caisse déjà posée | Caisse toujours là, contenu conservé |

## G. Code de la semaine chiffré (v1.2)

Options par défaut (code de la semaine chiffré), notes et carnets en Débogage (1/2). Le parcours nominal d'abord (G1-G5), les cas limites ensuite.

| # | Action | Attendu |
|---|---|---|
| G1 | Lire une note (cadavre militaire ou console) | Fréquence militaire, égale à `print(MilitaryDrop.Config.formatChannel(MilitaryDrop.Config.getChannel()))`, et fréquence de la station, entre 10 et 25 MHz, égale à `print(MilitaryDrop.NumbersStation.frequency)` / 1000 ; aucun code |
| G2 | Talkie militaire (ou radio HAM) allumé en main, réglé sur la fréquence de la station ; attendre au plus 30 min de jeu | « Attention. Attention. Message. », trois fois « Groupe : NN-NN-NN », puis « Fin du message » ; panneau de la radio : chaîne inconnue |
| G3 | Tuer un zombie militaire (ou `AddItem("MilitaryDrop.Codebook")`) et **Inspecter** le carnet | Icône de liasse de papiers ; ouverture en une seconde environ ; dossier kraft ouvert : étiquette « Carnet de codes », tampon SECRET, trombone ; feuille avec la grille « groupe / mot » (2 × 13 lignes), sans texte coupé ; zoom à la molette ; deux carnets ont la même table |
| G4 | Déchiffrer le groupe entendu en G2 avec la grille du carnet, puis appeler la fréquence militaire avec ce code | Le code obtenu est celui de `print(MilitaryDrop.Server.getCode())` ; la base accepte |
| G5 | Sauvegarder, quitter, recharger ; relire la note et le carnet | Textes identiques ; la station diffuse le même groupe |
| G6 | Cas limite : 3 appels avec un code faux sur la fréquence militaire, puis un appel avec le bon code | Grésillements les 4 fois ; console : `3 wrong codes today` ; le lendemain (après minuit), le bon code est accepté |
| G7 | Cas limite : avancer au lundi 00:00 (console debug, heure), puis `print(MilitaryDrop.Server.getCode())` | Nouveau code ; l'ancien reste accepté jusqu'au lundi 24:00, puis refusé |
| G8 | Cas limite : nouvelles parties avec **Code d'authentification** sur Aucun, Code fixe, Code de la semaine en clair | Aucun : pas de saisie, notes sans code ; fixe : code sur les notes ; semaine en clair : code et date de fin (dimanche) sur les notes ; aucune station ni carnet dans ces trois modes |
| G9 | Cas limite : fouiller des casiers et réserves d'une base militaire | Des carnets de codes (Débogage : assez fréquents) |

## H. Confiance, sources, missions, poste (v1.3)

Solo d'abord (une seule équipe, « SOLO »), puis serveur dédié à 2 clients dans deux factions. Console debug utile :

```lua
MilitaryDrop.Trust.debugPrint()          -- notes des équipes (admin)
MilitaryDrop.Missions.launch("recon")    -- lancer une mission : "recon", "cleanup", "control"
-- Plaque de soldat tombé (solo : renommée comme à la mort d'un zombie)
local t = getPlayer():getInventory():AddItem("Base.Necklace_DogTag"); t:setName(t:getScriptItem():getDisplayName() .. ": John Doe")
-- Démontage : outils
getPlayer():getInventory():AddItem("Base.Hammer"); getPlayer():getInventory():AddItem("Base.Saw")
```

| # | Action | Attendu |
|---|---|---|
| H1 | Talkie militaire accroché à la ceinture, réglé sur la fréquence militaire et allumé : « Options de l'appareil » → section **Logistique** → « Envoyer un rapport de situation » | Le personnage prend le talkie en main, parle, puis la base répond avec l'indicatif ; un second rapport le même jour : la base le refuse poliment |
| H2 | Tuer des zombies militaires | Une seule plaque par soldat, la plaque vanilla à son nom (plus de plaque du mod) ; « Annoncer les matricules » : plaques consommées, la base cite les noms et remercie ; une plaque déjà annoncée ne rapporte rien |
| H3 | `Missions.launch("control")` puis « Confirmer réception » | Annonce « toutes stations » sur la fréquence militaire ; réponse acceptée une fois |
| H4 | `Missions.launch("recon")` (plusieurs fois, dont près d'un lac ; journal « mission site … (building) ») en écoutant la fréquence militaire, ouvrir la carte, aller à la grille annoncée, « Confirmer la reconnaissance » | Symbole « œil » bleu au point annoncé, posé une seule fois ; refusée loin du point, acceptée à 25 cases ; annonce de clôture |
| H5 | « Missions (admin) » → « Lancer un nettoyage » en écoutant la fréquence ; « Faire le point » ; aller à la grille ; abattre la horde ; « Faire le point » de nouveau | Annonce « horde dans un rayon de 40 cases » et crâne rouge ; avant l'arrivée : « rendez-vous en grille… » ; la horde apparaît hors de vue, une seule fois (même après sauvegarde et rechargement) ; « N abattus, encore R » ; à 90 % : clôture et +5 au meilleur tireur |
| H6 | Radio HAM militaire posée : « Options de l'appareil » → bouton « Poste de liaison » ; puis la même chose sur une autre radio HAM | Première fois : poste installé et console ouverte ; ensuite : ouverture ; autre radio : « Transférer le poste de liaison ici ? », oui → transfert et console ; plus d'entrée « poste » au clic droit |
| H7 | « Déposer mes plaques », puis « Annoncer les matricules » | Plaques retirées de l'inventaire et listées au poste ; le personnage annonce les matricules, la base cite les noms et remercie |
| H8 | Éteindre le poste, faire diffuser une annonce (largage ou mission), rallumer | Le journal marque « aucune réception » pour le trou |
| H9 | Largage : ouvrir une caisse | Réplique de la base plus chaleureuse au largage suivant (palier) ; `Trust.debugPrint()` montre +10 |
| H10 | Talkie dans le sac à dos, puis « Envoyer un rapport de situation » | Le personnage le prend en main (en solo, une radio sur le dos est aussi acceptée) |
| H11 | Pendant l'annonce, cliquer de nouveau « Annoncer les matricules » | Le second clic est ignoré : chaque matricule n'est compté qu'une fois (`Trust.debugPrint()`) |
| H13 | Talkie militaire à la ceinture : clic droit → « Options de l'appareil », l'allumer sur la fréquence militaire, laisser la fenêtre ouverte ; puis lancer un largage ; enfin la régler sur la station de chiffres et attendre la demi-heure | La radio reste allumée ; le code chiffré de la station s'affiche à la demi-heure ; les lignes de la base s'affichent au-dessus du personnage (une seule fois si un autre talkie est en main) et le repère du largage apparaît |
| H14 | Caisse larguée vidée, marteau et scie dans l'inventaire : clic droit → « Démonter la caisse » ; essayer aussi caisse pleine et sans scie | Grisée avec la raison si pleine ou sans outil ; sinon animation, planches (ou bois inutilisable) au sol, XP de Menuiserie, caisse disparue |
| H15 | Admin (solo debug) : clic droit sur une radio militaire → « Missions (admin) » → « Lancer un nettoyage », radio allumée sur la fréquence militaire ; puis relancer le même | Le personnage confirme le lancement ; la base annonce le nettoyage à toutes les stations et le crâne rouge apparaît ; le second lancement répond qu'une mission de ce type est déjà en cours ; « Clore le nettoyage en cours » : annonce d'annulation, puis un nouveau lancement est possible |
| H12 | Nouvelle partie avec **Fréquence radio** à 0 : lire une note | Fréquence militaire entre 120 et 170 MHz, différente d'une partie à l'autre, et la même après un rechargement de la partie |

## I. Formulaire de réquisition (v1.4)

Options par défaut (formulaire actif). Confiance réglable pour les essais : `MilitaryDrop.Trust.add("SOLO", 30, "drop")` (console Lua, solo).

| # | Action | Attendu |
|---|---|---|
| I1 | Appel de largage avec le bon code (talkie ou radio posée) | La base répond « transmettez votre réquisition », puis la feuille s'ouvre avec le budget, le délai qui décroît et les lots par palier |
| I2 | Remplir avec + et − jusqu'à épuiser le budget | « + » grisé quand le budget ne suffit plus ; paliers II et III grisés selon la confiance, avec la raison ; « points non utilisés perdus » |
| I3 | « Transmettre la réquisition » | Le personnage annonce sa réquisition, la base accepte, puis l'hélicoptère et l'annonce habituelle (sans le contenu) |
| I4 | Annuler, Échap, ou s'éloigner d'une radio posée ; puis rappeler | Rien n'est consommé, le délai entre largages n'est pas déclenché |
| I5 | Ouvrir les caisses de réquisition du coffre (2 Rations, 1 Eau potable, 1 Carburant si permis) | Une caisse nommée par lot commandé ; contenu du lot ; bouteille pleine d'eau propre, bidon plein d'essence |
| I6 | Option « Formulaire de réquisition » désactivée, nouvel appel | Largage direct avec les caisses aléatoires de la v1 |
| I7 | Console du poste : « Demander un largage » | Saisie du code, puis la feuille |
| I9 | Clic droit sur une radio militaire → « Largage forcé (admin) » | Feuille tamponnée ADMIN : tous les lots et le leurre, 20 points ; elle reste ouverte loin de la radio ; après commande, coordonnées en privé et un appel normal juste après n'est pas bloqué par le délai |
| I10 | Nouvelle partie, premier appel ; `MilitaryDrop.Trust.debugPrint()` | Confiance 25 : seul le palier I est permis (8 points) ; le palier II affiche « confiance 50+ », le III « confiance 75+ » |
| I8 | Console au démarrage : chercher `requisition lots ready in` ; puis leurre vers un secteur hors de la carte (bord de carte) | Durée de préparation des lots notée au journal ; pour le leurre, la base dit qu'aucun point n'existe dans ce secteur et la feuille se rouvre |

## J. Largage leurre (v1.5)

| # | Action | Attendu |
|---|---|---|
| J1 | Formulaire : « Leurre à sirène », secteur Nord, transmettre | Les autres lots se désactivent ; même réponse, même hélicoptère, même annonce qu'un vrai largage ; point annoncé au nord |
| J2 | Aller à la caisse | Sirène audible en approchant, zombies attirés ; le coffre ne contient qu'une balise « DIVERSION » |
| J3 | Clic droit sur la caisse → « Couper la sirène » | Action de quelques secondes, puis silence |
| J4 | Nouveau leurre : attendre l'échéance (6 h de jeu), ou démonter la caisse | La sirène s'arrête ; la confiance ne change pas (`Trust.debugPrint()`) |

## K. Module radio et fichier de lots (RADIO-06, REQ-09)

| # | Action | Attendu |
|---|---|---|
| K1 | Ouvrir les options d'un talkie militaire, puis d'une radio civile | Section « Logistique » sur la radio militaire seulement ; les autres sections du jeu inchangées |
| K2 | Code vide, puis taper le code et « Demander un largage » | Bouton grisé avec sa raison tant que le code manque ; puis la feuille s'ouvre collée à droite de la fenêtre radio (à gauche si la fenêtre est au bord droit de l'écran) |
| K3 | Rapport, matricules, contrôle depuis la section | Mêmes échanges qu'au menu ; la dernière réponse de la base s'affiche dans la section |
| K9 | Saisir le code, quitter la partie, la recharger | Code prérempli dans la section Logistique et dans la console du poste |
| K10 | Console du poste : champ « Code », puis « Demander un largage » ; puis « Déposer mes plaques » et « Annoncer les matricules » | Champ prérempli ; bouton grisé tant que le code manque ; appel sans boîte de saisie ; la console **reste ouverte** pour tous les boutons, la feuille de réquisition s'ouvre à côté. Si elle se ferme quand même : chercher `post console closed:` dans `console.txt` (option Journal de débogage) |
| K4 | Refermer et rouvrir la fenêtre radio, nouvel appel | Code prérempli (mémorisé pendant la session, pas sauvegardé) |
| K5 | Manette : entrer dans la section, saisir le code au clavier à l'écran | Navigation haut et bas, A valide, B ressort |
| K6 | Premier démarrage : dossier `Zomboid/Lua/MilitaryDrop/` | `requisition.txt` créé, notice en anglais ; journal « requisition lots: 18 » |
| K7 | Mettre `enabled = false` sur un lot, ajouter le lot d'exemple de la notice, recharger (`MilitaryDrop.Requisition.reload()` en solo) | Le lot disparaît du formulaire ; le lot ajouté apparaît avec ses textes ; ses caisses portent son nom |
| K8 | Introduire une erreur de syntaxe, recharger | Journal avec le numéro de ligne ; les 18 lots par défaut restent |

## Plus tard : multijoueur (hébergé, puis serveur dédié `C:\pzserver`)

- Deux joueurs : l'un appelle, l'autre écoute la fréquence (annonce et symbole) sans avoir appelé.
- Déconnexion et reconnexion pendant un vol : l'hélicoptère réapparaît à sa position.
- Joueur non admin : pas d'option « Forcer un largage » ; commande forgée refusée (journal serveur).
- v1.4 : commande forgée refusée ; un autre joueur qui appelle pendant qu'une feuille est ouverte consomme le délai, la commande est alors refusée (« délai »). v1.5 : l'autre joueur n'entend la sirène qu'à portée, et ne distingue pas le leurre avant d'ouvrir le coffre ; reconnexion près d'une sirène.
- v1.3 : un client ne connaît pas la fréquence militaire tirée au hasard (seules les notes la donnent) ; deux factions ; indicatif conservé après un renommage ; appel de contrôle crédité aux deux ; reconnaissance et nettoyage à la première ; un joueur de l'autre faction ne peut ni installer ni ouvrir le poste ; talkie à la ceinture : prise en main puis échange accepté par le serveur.
- Code de la semaine : les deux clients entendent la station et lisent le même carnet ; la graine et le code restent absents de la ModData (`ModData.request("MilitaryDrop")` côté client) ; 3 codes faux d'un joueur ne font pas taire la base pour l'autre.
- Avec HEF actif : départ retardé si un événement HEF est proche.


## Mayday — branche feature/mayday-wreck (à valider en jeu)

Redémarrer complètement le jeu avec cette version locale, sur une partie de test. Aucun cas ci-dessous n’a encore été joué. Vérifier `version=42.21.0` dans le journal de cette session.

| Cas | Action et attendu |
|---|---|
| M1 | Solo debug : clic droit sur une radio militaire, « Faire crasher le prochain hélicoptère », puis « Forcer un largage (admin) » et commander. Confirmation privée, arrivée, MAYDAY, impact au lieu du largage normal ; appel suivant forcé normal. Réarmer deux fois ne programme qu’un crash. |
| M2 | Écouter la fréquence militaire jusqu’au MAYDAY : secteur orange « ? » sur carte. Radio éteinte/autre fréquence : aucun repère. Aller au secteur : fuselage et queue arrondis à la bonne échelle, débris, horde, absence de collisions avec murs/eau ; zone trop petite : lots au sol. |
| M3 | Fouiller le corps : pilote mort, enregistreur, note et carnet. Clic droit sur les deux épaves → récupération : avionique Électricité 2/tournevis, radio Électricité 1 après avionique ; moteur Mécanique 2/clé, moyeu Mécanique 1 après moteur ; panneaux Soudure 1/tournevis après moyeu. Queue : panneaux seuls. Sans outil/niveau : refus. Lots ouverts par recette, puis découpe vanilla au chalumeau/masque seulement après retrait complet. |
| M4 | Essayer aucun effet, fumée, puis feu et fumée. Fumée présente à l’arrivée tardive, cesse après sa durée ; pas de feu quand `NoFire` l’interdit. `CrashCrates=false` : pas de ravitaillement ; `PilotDocuments=false` : pas de note/carnet. |
| M5 | Avec chance et bonus à 0 : vols normaux. Chance à 100 : crashes normaux ; largages admin et leurres restent normaux sauf ordre explicite. Réputation du demandeur conservée après le crash et récupération des caisses ; aucun rappel de grille de largage perdu. |
| M6 | Sauvegarder/quitter après armement et avant départ : ordre conservé. Refaire avec vol en attente HEF : attente conservée, ordre consommé au départ. Sauvegarder en vol condamné : site en attente au retour, jamais deuxième pilote/horde/épave. S’approcher progressivement des chunks pour vérifier que chaque épave attend toute son enveloppe. |
| M7 | Serveur dédié + deux clients : non-admin sans option et commande forgée refusée ; admin armé, crash visible et audible par les voisins. Deux joueurs désinstallent la même pièce : un seul lot. Reconnexion/redémarrage : mêmes pièces retirées, même corps et matériel, fumée si durée non expirée. Voiture poussant l’épave : contrôler stabilité et collisions. |
| M8 | Tirs désactivés : aucun crash causé par tir. Activés/chance 100 : arme à feu chargée, proche et orientée vers un appareil en approche → MAYDAY. Arme vide, mêlée, dos tourné ou éloignement : refus. Vérifier le comportement du dernier tir du chargeur et l’absence d’erreur réseau. |
| M9 | Station de liaison (maquette C) : liste des affaires à gauche avec les icônes des objets du jeu (enregistreur, plaque), volet à droite. Avec l’enregistreur du pilote : sa ligne « dans mon inventaire », fiche du crash (date, grille), « Insérer dans la baie » ; barre de lecture qui avance (10 min de jeu), journal « dans la baie », puis « entièrement lu ». Éteindre la radio : pause notée, barre figée ; rallumer : reprise au même point. « Transmettre à la base » (fréquence militaire) : +10 de confiance, réponse de la base au journal ; un second enregistreur du même site est refusé. « Retirer de la baie » rend l’objet avec sa lecture acquise. Manette : haut/bas choisit l’affaire, A et X les deux boutons, LB le journal. Sons (SRC-10) : déclic à l’insertion, porteuse discrète pendant la lecture (audible console fermée, à quelques cases ; muette au-delà de ~12 cases ou à un autre étage), coupée pendant la pause et reprise ensuite, double déclic à la fin ; curseur « Effets sonores » respecté. |

## Réputation personnelle — 0.1.2 (à valider en jeu)

Redémarrage complet requis. Ces cas n'ont pas encore été exécutés en jeu.
En solo, lire l'identité et la note dans la console de débogage :

```lua
local id = MilitaryDrop.Trust.idFor(getSpecificPlayer(0))
print(id, MilitaryDrop.Trust.get(id))
```

| Cas | Attendu |
|---|---|
| Partie existante avec l'ancien mod, premier contact | Nouvelle note à 25 ; anciennes notes conservées sans transfert ; largages antérieurs sans effet sur les nouvelles notes |
| Gagner des points, sauvegarder, quitter complètement et relancer | Même identité, même note, même plafond quotidien et même suspension éventuelle |
| Mort puis nouveau personnage sur la même sauvegarde, avec le même nom | Nouvelle identité, note 25 ; aucune sanction ni aucun gain du personnage précédent |
| MP : déconnexion, redémarrage serveur, reconnexion du même personnage | Identité et note conservées ; tester aussi après modification des favoris d'inventaire (ModData vanilla) |
| MP : deux personnages dans la même faction, rapport et contrôle chacun | Récompense personnelle pour chacun ; plafond de +8 séparé |
| Créer, rejoindre, quitter et dissoudre une faction | Identité et note de chaque personnage inchangées |
| Poste partagé, deux personnages avec des notes différentes | Même poste et indicatif, confiance et progression propres au personnage qui ouvre la console |
| Demander un largage puis ouvrir sa première caisse | +10 au demandeur, une seule fois |
| Un autre membre de la faction de l'appel ouvre la caisse | +5 au personnage demandeur uniquement, une seule fois ; aucun gain pour l'ouvreur |
| Un personnage extérieur à la faction de l'appel ouvre la caisse, y compris un successeur sans faction | −5 au demandeur d'origine ; aucun gain ni aucune perte pour l'ouvreur |
| MP : nettoyage partagé entre deux membres de faction | Comptes séparés ; +5 seulement au personnage ayant le plus de morts de la horde |
| Écran partagé, second personnage ajouté après le démarrage | Identités et réputations séparées ; synchronisation de l'identité du second joueur |

## Batterie des talkies accrochés — 2026-10-03

Le module `client/BatmanRadio/BatmanRadio_BeltBattery.lua` est commun à Artemis
et MilitaryDrop, livré avec des copies identiques au même chemin relatif.
Il appelle `DeviceData.update(false, true)` à l'allumage puis chaque minute de
jeu pour les radios à pile accrochées, hors main/dos. Le compteur de temps
vanilla avance avec la consommation : aucun deuxième décompte à la reprise
en main. La synchronisation utilise les paquets vanilla pour une radio
d'inventaire identifiée par son ID (sources 42.21.0, `4a0e9546ec`).

Un seul handler, même avec les deux mods. Si BetterWalkieTalkies est actif,
notre gestionnaire lui laisse toujours la batterie ; son option `BatteryDrain`
est respectée même désactivée. Aucune option BWT à désactiver pour la cohabitation.
Sans BWT, le gestionnaire commun applique la consommation vanilla à la ceinture.
Le test de cohérence des copies est dans les lanceurs MilitaryDrop et Artemis.

Validation automatisée : 13 tests batterie, 22 tests ceinture MilitaryDrop,
13 tests radio Artemis, suite complète MilitaryDrop et luacheck sans échec.
API Java simulées ; aucun test en jeu effectué. Redémarrage complet requis.

| Cas à confirmer en 42.21 | Attendu |
|---|---|
| MilitaryDrop seul, talkie allumé à la ceinture dix minutes de jeu | Charge qui baisse chaque minute au débit vanilla |
| Artemis seul, puis les deux mods actifs | Même débit, sans cumul des deux modules |
| Reprise en main après dix minutes à la ceinture | Pas de nouvelle chute pour la période déjà consommée |
| Radio éteinte, volume à zéro, puis pile presque vide | Éteinte : pas de consommation ; volume zéro : consommation ; pile vide : extinction |
| MP : ceinture, reprise en main, sauvegarde/reconnexion | Charge et extinction cohérentes sur le client et le serveur |

## Compatibilité Better Walkie Talkies et code commun — 2026-10-03

La source unique des fonctions de ceinture, batterie et compatibilité se trouve
dans `source/radio/lua`. `python source/radio/sync_radio.py` génère les copies
embarquées dans les deux projets ; `--check` vérifie leur égalité. Ces copies
identiques permettent à chaque mod de fonctionner indépendamment, sans ajouter
une dépendance chargeable ni entretenir deux implémentations. Artemis inscrit
sa chaîne par UUID ; MilitaryDrop inscrit ses deux chaînes et son ouverture des
radios rangées. Un seul menu, wrapper et récepteur solo est installé.

La réception ajoutée couvre le registre des stations radio en **solo** :
vanilla, AEBS et chaînes des scénarios, à la fréquence réglée de l'appareil.
En **MP**, elle est laissée au vanilla/BWT : pas de doublon ajouté par nos mods.
Si BWT est actif, il conserve seul la batterie, la VOIP et les réglages PTT.
Le risque de double décompte interne de sa batterie n'est pas corrigé ici.

`BatmanRadio_Compat.features()` centralise les décisions. L'activation vient
de `getActivatedMods()` et des IDs exacts `BetterWalkieTalkies` ou
`BetterWalkieTalkiesDev`, avec ou sans le préfixe `\` de Build 42. Le dossier
Workshop installé, les anciennes options sandbox et une globale BWT laissée
en mémoire ne suffisent pas. Le bridge texte est utilisé seulement sur un
client MP, si BWT est actif et si sa fonction est disponible. La détection
est réévaluée à l'appel pour supporter son initialisation après notre module.

| Fonction commune | BWT désactivé | BWT actif |
|---|---|---|
| Batterie à la ceinture, solo/client | Mise à jour native par notre module | Notre module s'efface ; option BWT respectée |
| Réception des stations radio en solo | Récepteur commun | Récepteur commun, toujours nécessaire |
| Réception en MP | Pas de récepteur supplémentaire | Pas de récepteur supplémentaire |
| Phrases scriptées en MP | `player:Say` direct | Bridge texte BWT lorsqu'il est prêt |
| Menu appareil et fenêtre à la ceinture | Support commun | Support commun, BWT ne remplace pas ces fonctions |

Le serveur dédié n'exécute ni notre consommation locale ni notre réception
locale ; aucun bridge vocal client n'est utilisé côté serveur.

`RadioPTT` = **Radio Push-to-Talk** : maintenir une touche pour transmettre
sa voix par radio, en MP. Les phrases scriptées des scénarios ne sont pas une
captation du microphone. BWT met le micro radio en silence au repos ; nos
appels utilisent son `RadioTextBridgeHandler` pour transmettre le texte et
restaurer les réglages. Artemis distingue ainsi le silence automatique PTT
d'un micro volontairement coupé, qui reste refusé.

Validation locale : **53 tests radio/batterie/BWT réussis**, dont 7 exécutent
les vrais modules `RadioPTT.lua` et `PortableRadioBattery.lua` de la copie
Workshop lue seulement (`3779480293`, variante `42.20`). Suite complète
MilitaryDrop et luacheck sans échec. Les interfaces Java, la capture audio et
le réseau sont simulés : aucune certification de VOIP réelle en 42.21.
Six tests supplémentaires couvrent la politique d'activation sans BWT installé,
et un test de coexistence vérifie les deux scénarios solo avec BWT actif.
Quatorze tests couvrent aussi le registre vanilla, l'écoute déclarée, les segments,
le changement de fréquence et les émissions reprises depuis une sauvegarde.

| Essai en jeu après redémarrage complet | Attendu |
|---|---|
| Solo : Artemis seul, MilitaryDrop seul, les deux, avec/sans BWT | Une option appareil et une seule occurrence des lignes de scénario à la ceinture |
| BWT actif, consommation activée puis désactivée | BWT reste seul responsable ; option désactivée respectée |
| MP, PTT activé, touche relâchée : appel Artemis et échange MilitaryDrop | Appels possibles malgré le silence automatique du micro ; mode vocal restauré |
| Micro volontairement coupé avant activation du PTT | Artemis refuse l'appel ; aucun déverrouillage permanent du micro |
| Deux clients : VOIP proche puis radio à distance, talkies à la ceinture | Voix entendue sur la bonne fréquence ; relâcher la touche arrête la transmission |
| Client émetteur en véhicule, puis sortie / retour à proximité | Pas de disparition ou de doublon de joueur ; VOIP retrouvée |
| Batterie à la ceinture, reprise en main, déconnexion/reconnexion | Vérifier consommation, éventuelle seconde chute propre à BWT et charge sauvegardée |

## Stations vanilla à la ceinture en solo — 2026-10-03

Le récepteur lit `RadioScriptManager:getChannelsList()` plutôt qu'une liste
figée de fréquences. Les chaînes TV sont exclues et les fournisseurs de
scénarios sont dédoublonnés avec le registre. La fréquence aléatoire de l'AEBS
est donc prise dans la partie chargée. Une radio accrochée allumée déclare
`PlayerListensChannel(fréquence, true, false)` : les émissions scriptées
démarrent et leur horaire reste géré par le moteur. Aucun message `false`
n'est envoyé, afin de ne pas interrompre l'écoute d'un autre appareil.

L'affichage utilise la surcharge native `AddDeviceText(player, ...)`, comme
`DistributeToPlayerInternal`, pour conserver ChatManager, le traitement du
trait sourd, les parasites et OnDeviceText. Les filtres de fréquence, volume,
pile, média et radio équipée sont conservés ; `getDisableBroadcasting()`
est respecté. Le récepteur n'avance aucun compteur de diffusion. Lors d'une
reprise au milieu d'une émission, les lignes sauvegardées ne sont pas rejouées.

Sources vérifiées : jeu et journal **42.21.0, révision 4a0e9546ec**. Le SHA256
du JAR installé correspond à celui des sources décompilées
`E:\pz-decompiled\42.21.0` :
`e1a69eb743ede60b213a0fe7f8b83d4fcab773036d256cc4543a336f3b058a33`.
API et comportement relevés dans `RadioScriptManager.java:47-91`,
`RadioChannel.java:150-262`, `RadioBroadCast.java:81-109`,
`ZomboidRadio.java:568-608` et `WaveSignalDevice.java:50-79`.

**Limites : ce n'est pas une reproduction à 100 % de la transmission Java.**
Les publicités pré/post et pauses sont suivies par `getLastAiredLine()` parce
qu'elles n'avancent pas le compteur des lignes principales. Leurs métadonnées
et compteurs propres restent privés : texte en gris sans codes, et deux
publicités identiques consécutives ne peuvent pas être distinguées.
Le brouillage scénarisé de Louisville (stations 93,2 / 98,0 / 101,2 MHz)
n'est pas reproduit par ce récepteur Lua : le texte brut peut être reçu
alors que la radio équipée reçoit une version brouillée. L'état réel de ce
brouillage n'a pas de getter ; la valeur exposée du champ statique est une
copie faite à l'initialisation Lua, pas une lecture dynamique. La réflexion
sur les champs privés est réservée au mode debug ; aucun contournement ni
changement du JAR n'est ajouté. Les transmissions directes hors du registre
des émissions ne sont pas interceptées. Le brouillage météo est traité,
mais son tirage aléatoire n'est pas partagé avec la transmission native.

| Essai supplémentaire après redémarrage complet, Artemis seul puis MilitaryDrop seul | Attendu |
|---|---|
| Hitz FM (89,4 MHz), talkie à la ceinture à l'horaire d'une émission | Lignes diffusées une fois, selon volume et charge |
| AEBS, fréquence relevée dans cette partie, ceinture puis main | Bulletin sur la fréquence réelle ; aucun doublon à la reprise en main |
| Éteindre ou changer de fréquence pendant un bulletin, puis revenir | Pas de rejeu des lignes déjà diffusées |
| Sauvegarder/recharger au milieu d'un bulletin | Suite de l'émission, pas tout son historique |
| Publicités avant/après et pause `~` | Texte reçu ; noter la limite de couleur et les répétitions identiques |
| Joueur sourd et casque audio, volume zéro, pile vide | Vérifier le comportement natif du texte et des sons ; aucun apprentissage via codes inaudibles |

Les **53 tests** restent des simulations Lua 5.1. La suite complète MilitaryDrop
et luacheck passent ; les essais radio/audio interactifs en 42.21 restent à faire.

Protection de la radio en main : aucune livraison de texte ni mise à jour de
pile par le patch de ceinture. Si la radio équipée reçoit déjà cette fréquence,
le patch n'ajoute ni écoute déclarée ni brouillage météo : aucun tirage aléatoire
ni changement de l'état radio interne pour une réception déjà native.
Trois régressions supplémentaires vérifient l'état main/ceinture transitoire,
la présence de deux radios sur la même fréquence et une station de mod créée
pendant la partie sans fournisseur spécifique BatmanRadio.

Les nouvelles stations utilisant `RadioScriptManager:AddChannel()` ou le
chargement radio XML standard sont automatiquement couvertes en solo. Une
station qui diffuse uniquement via un système privé ou des appels directs
`SendTransmission`, sans émission observable dans ce registre, ne l'est pas.

## Zones de largage — branche feature/drop-zones (à valider en jeu)

ZONE-01 à ZONE-09 (idée 11 ; ZONE-09 : secteur choisi par le joueur, Z26 et Z27). Aucun cas n'a encore été joué. Redémarrer complètement le jeu et vérifier `version=42.21.0` dans le journal de la session. Guide : `docs/guide/fr/06-server-admin.md`, section « Zones de largage ». Outil refondu le 2026-10-06 (l'ancien menu contextuel « Military Drop (admin) › Zones de largage › Coin 1 ici / Coin 2 ici » n'existe plus) : en solo debug, clic droit au sol › **Debug** › **Main** › **Zones de largage** (ou fenêtre de debug, icône insecte, onglet **Main**) (ou console : `MilitaryDrop.ZonesWindow.open(getPlayer())`) ; en MP, panneau d'admin › bouton **Zones de largage**.

Préparation :

1. **Sauvegarder puis supprimer** `C:\Users\cyber\Zomboid\Lua\MilitaryDrop\dropzones.txt` : le fichier est commun à toutes les parties et à tous les serveurs du compte.
2. Solo en mode debug, nouvelle partie sur la carte vanilla. Page **Military Drop** : **Placement des largages** : Zones de largage ; **Heures entre deux largages** : 1 ; **Journal de débogage** : activé.
3. Un talkie militaire allumé sur la fréquence militaire, et le code (commandes de la préparation générale) : les cas de zones passent par un **appel normal** (section « Logistique »), car le largage forcé de l'admin ignore les zones (Z21). Entre deux appels, attendre le délai (1 h, ×1,5 au plus selon la confiance). Pour changer une option pendant la session seulement (non sauvegardée) : `SandboxVars.MilitaryDrop.DropPlacement = 3`, `SandboxVars.MilitaryDrop.DropZoneAnnounceName = false`, `SandboxVars.MilitaryDrop.DropZoneMinDistance = 300`.

### Parcours nominal, solo

| # | Action | Attendu |
|---|---|---|
| Z1 | Démarrer la partie, ouvrir les options du bac à sable | `dropzones.txt` créé (notice anglaise, `zones = {}`) ; `console.txt` : « drop zones: 0 (0 active) from created » ; 5 options nouvelles, libellés et infobulles en français |
| Z2 | À Louisville : clic droit au sol › **Debug** › **Main** › **Zones de largage** ; fenêtre **Zones de largage (admin)** › **Ajouter une zone** ; au clic gauche, appuyer sur un coin, faire glisser jusqu'au coin opposé et relâcher ; **Secteur** › **Nouveau secteur...** › « Louisville », **Nom de la zone** « Parc », **Poids** 1 › **Ajouter une zone** | La liste se masque, l'éditeur s'ouvre en haut à gauche ; pourtour bleu éclairé au sol qui suit la souris pendant le tracé, sans clignoter, largeur et longueur affichées ; rectangle figé au relâchement (la souris ne le déplace plus) ; « Zone de largage z1 ajoutée. » ; l'éditeur se ferme, la liste revient avec `z1` sélectionnée (rien au sol tant que **Surbrillance** n'est pas cochée) ; fichier réécrit avec `map = "Muldraugh, KY"` et la zone `z1` |
| Z3 | Ajouter une 2e zone à Louisville **en deux clics** (un clic sur un coin, un clic sur l'autre ; secteur « Louisville » proposé dans la liste), puis une zone à West Point (nouveau secteur). Pendant un tracé, faire un clic droit, puis Échap, puis Échap encore | Ids `z2`, `z3` ; le clic droit et le premier Échap annulent le tracé en cours (l'éditeur reste ouvert), le second Échap ferme l'éditeur et rend la liste ; aucun menu contextuel |
| Z4 | Dans la liste : sélectionner chaque zone, **Désactiver** puis **Activer**, **Se téléporter sur la zone**, **Modifier** `z2` (nom « Centre commercial », poids 3, **Retracer** puis tracer ailleurs) › **Enregistrer** ; **Retirer** `z3` › Non, puis **Retirer** › Oui ; fermer la fenêtre | Zones groupées par secteur, en-tête « Carte attendue : Muldraugh, KY (chargée) », « Placement : zones », « 3 zones, 3 utilisables » ; rien au sol (**Surbrillance** décochée) ; téléportation au centre ; pendant **Retracer**, l'ancien rectangle reste en gris ; « Zone de largage z2 enregistrée. », fichier avec le nouveau nom, le poids 3 et les nouveaux coins ; **Enregistrer** sans changement : « Rien à enregistrer. » ; « Voulez-vous vraiment retirer … ? », Non ne change rien, Oui retire `z3` ; messages dans la fenêtre, aucune bulle au-dessus du personnage ; fenêtre fermée : plus aucun surlignage au sol |
| Z23 | Surbrillance (refonte du 2026-10-06 : l'ancien surlignage clignotait) : rouvrir la fenêtre, cocher **Surbrillance** ; regarder le sol 30 s sans bouger, zoomer puis dézoomer ; sélectionner `z2` et la **Désactiver** ; **Modifier** `z1` › **Retracer** ailleurs › **Enregistrer** ; courir vers une zone hors de vue ; décocher, recocher, fermer la fenêtre, la rouvrir | Case décochée à la première ouverture de la session ; cochée : les cases du pourtour de chaque zone s'éclairent en continu (vert, zone sélectionnée plus marquée), **sans aucun clignotement ni variation d'intensité**, intérieur non éclairé ; la marque suit la sélection ; `z2` passe au gris ; pendant l'édition (liste masquée), les zones restent éclairées et le pourtour bleu du tracé suit la souris sans clignoter, l'ancien rectangle en gris ; après l'enregistrement, ancien pourtour de `z1` effacé (sol normal), nouveau éclairé ; en courant, les cases des chunks chargés s'éclairent en 1 s environ ; décochée : plus rien au sol ; fermée : plus rien ; rouverte : case toujours cochée, zones de nouveau éclairées ; pas d'erreur dans `console.txt` |
| Z5 | Près de Louisville : appel normal avec le code, valider le formulaire | `console.txt` : « drop point x,y in zone z1 (Louisville) » (ou `z2`) ; annonce « Caisse de ravitaillement livrée sur la zone Parc, grille X / Y » ; la caisse se pose dans le rectangle, sur la terre ferme, avec sa horde |
| Z6 | Près de West Point : appel normal avec le code, puis attendre un rappel de grille | Caisse dans la zone de West Point ; le rappel nomme la zone. Avec `DropZoneAnnounceName = false` : grille seule, repère de carte inchangé |
| Z7 | Appel suivant, cocher le leurre | Sélecteur « < Louisville > » au lieu de N/E/S/O ; choisir West Point : leurre dans une zone de West Point, même annonce, sirène à la pose |
| Z8 | Modifier le fichier à la main (`weight = 5` sur `z2`), **Rafraîchir** dans la fenêtre ; puis casser la syntaxe, **Rafraîchir**, essayer d'ajouter une zone puis de modifier `z1` | « dropzones.txt rechargé. », poids 5 dans la liste ; erreur : problème affiché en bas de la liste, numéro de ligne dans `console.txt`, ajout et modification refusés (« dropzones.txt contient une erreur… »), fichier non écrasé ; corriger et rafraîchir |
| Z9 | Désactiver toutes les zones, appel normal | Repli sur une ville vanilla : « drop point … in town town:<ville> », annonce « zone <ville> » |
| Z10 | `DropPlacement = 3` : appeler à plus de 1500 cases de toute zone, puis près d'une zone | Loin : caisse à 150-400 cases, sans message ; près : caisse dans la zone |
| Z11 | Sauvegarder et quitter avant d'atteindre une caisse de zone, relancer, y aller | Caisse posée dans la zone ; rappel avec le nom de la zone |
| Z26 | Secteur choisi par le joueur (ZONE-09) : menu de debug › **Options bac à sable** › **Secteur des zones de largage** : *Choisi par le joueur* (appliqué à chaud), zones actives à Louisville et West Point. Près de Louisville : appel normal ; d'abord commander 1 lot sans toucher au champ, puis choisir **West Point** (flèches, clic sur le nom, puis à la manette : dernière ligne, gauche et droite) et transmettre. Appel suivant : choisir Louisville, cocher le leurre, transmettre | Champ « Secteur de largage : » au-dessus du budget, sélecteur « < … > » en pointillés et note rouge « choisir un secteur » ; **Transmettre** grisé, infobulle « choisir un secteur » ; une fois choisi, nom à l'encre bleue souligné, note « point exact choisi par la Logistique », infobulle du champ avec le nom complet ; aucun nom de zone affiché nulle part ; `console.txt` : « drop point x,y in zone … (West Point) », caisse dans une zone de West Point (jamais Louisville, pourtant plus proche). Leurre coché : pas de sélecteur sous la case du leurre, le champ du pied garde Louisville, lots grisés ; leurre dans une zone de Louisville |

### Parcours nominal, MP (serveur dédié `C:\pzserver`, 2 clients, PvP actif, une zone non-PvP)

| # | Action | Attendu |
|---|---|---|
| Z12 | Démarrer le serveur avec un `dropzones.txt` contenant une zone qui chevauche la zone non-PvP | `console.txt` du serveur : zones lues au démarrage, ligne « note: zone #… overlaps a non-PvP zone … (nonPvp) » pour cette zone, sans le mot « warning » (listes non-PvP remplies sur le serveur dédié) ; dans l'outil, le constat est sur la ligne de la zone, rien sous l'en-tête rouge des problèmes du fichier |
| Z13 | Admin : panneau d'admin du jeu › bouton **Zones de largage** ; ajouter une zone PvP ; essayer d'en ajouter une sur la zone non-PvP ; modifier le nom de la première (`ZoneUpdate`) | Bouton rangé avec ceux du panneau vanilla ; fichier écrit côté serveur ; **Surbrillance** cochée : zones éclairées chez l'admin seulement (rien chez l'autre client) ; seconde zone refusée (« chevauche une zone non-PvP », affiché dans l'éditeur) ; modification enregistrée ; aucune bulle visible du client 2 placé à côté de l'admin |
| Z14 | Client 1 appelle ; client 2 écoute la fréquence, rejoint la caisse et l'ouvre | Caisse dans la zone PvP ; annonce avec le nom de la zone chez les deux ; −5 au demandeur (CONF-04) |
| Z15 | Client 2 non admin | Pas de bouton **Zones de largage** (ni de panneau d'admin) ; commandes forgées `ZoneAdd` et `ZoneUpdate` refusées (« refused for … : not an admin » au journal serveur) |

### Cas limites

| # | Action | Attendu |
|---|---|---|
| Z16 | Riverside : tracer une zone qui couvre la berge et l'Ohio, la laisser seule dans son secteur, appeler au moins 5 fois depuis Riverside (appels normaux) | Jamais de caisse dans l'eau ni hors zone : points tirés sur la berge (eau de Riverside connue de la métagrille une fois la ville approchée) ; un point tiré sur l'eau (cellule jamais approchée) est déplacé à la livraison sur la case sèche la plus proche de la zone |
| Z24 | Règle du 2026-10-06 : tracer une zone sur un champ sans route ni bâtiment, puis une sur une plage ou un chemin de terre, chacune seule dans son secteur ; appel normal pour chacune | Aucun avertissement à la création (plus de « ni route ni bâtiment »), rien sous l'en-tête rouge des problèmes, message vert « Zone de largage zN ajoutée. » seul ; largage accepté ; caisse posée dans le rectangle, sur la terre ferme (champ, sable, chemin), jamais dans un bâtiment ; `console.txt` : « drop point x,y in zone … » |
| Z25 | Tracer une zone entièrement couverte par un grand bâtiment (centre commercial), seule dans son secteur, appel normal | Avertissement « aucun terrain libre » sur la ligne de la zone (note au journal) ; « aucune zone de largage sûre » ; aucune caisse dans le bâtiment |
| Z17 | Tracer une zone entièrement sur un plan d'eau (lac de Fallas Lake), seule dans son secteur, après s'en être approché ; appel normal. Puis, si possible, une zone sur un lac d'une cellule jamais approchée dans cette partie | Lac approché : avertissement « aucun terrain libre » à la création, « aucune zone de largage sûre » à chaque appel. Lac jamais approché : aucun avertissement, largage annoncé, mais aucune caisse ne tombe (livraison en attente, « no ground near … » au journal en mode DebugLog), jamais dans l'eau ni hors zone |
| Z18 | Solo sans mode debug, puis MP client non admin | Aucune entrée ni bouton des zones (menu de debug, panneau d'admin) ; `MilitaryDrop.ZonesWindow.open(getPlayer())` n'ouvre rien ; aucune liste reçue |
| Z19 | Laisser un seul secteur actif, commander un leurre | Le secteur est affiché et sélectionné d'office, sans flèches ; leurre dans une zone de ce secteur. Sans case possible : refus sans proposer d'autre secteur |
| Z20 | Divers : rectangle de plus de 300 cases (largeur ou longueur en rouge, ajout refusé) ; tracé depuis l'étage (cases prises au rez-de-chaussée) ; zone d'une carte absente du fichier (`map = "Autre"` : surbrillance orange, « carte non chargée ») ; `DropZoneMinDistance = 300` en appelant depuis une zone ; nom de secteur de 32 caractères et grande police (boutons et champs lisibles) ; **Se téléporter sur la zone** en écran partagé ; manette : croix pour viser, A fixe les coins, B annule le tracé, puis B ferme ; largage dans une zone de 300 × 300 | Comportements décrits dans le guide ; pas de saccade notable ; pas d'erreur dans `console.txt` |
| Z21 | Largage admin hors zones (§2.1) : `DropPlacement = 2`, zones actives à Louisville et West Point, se placer à Muldraugh (loin de toute zone). **Forcer un largage (admin)** et valider le formulaire ; puis forcer un 2e largage, cocher le leurre dans la feuille ADMIN | Caisse à 150-400 cases de l'admin, hors de toute zone ; ni « in zone » ni « in town » dans `console.txt`, pas de message « aucune zone utilisable » ; annonce sans nom de zone. Feuille ADMIN : leurre avec N/E/S/O (pas de sélecteur de secteur), leurre dans le quart choisi |
| Z22 | Clics consommés (cause de la refonte du 2026-10-06) : **Ajouter une zone**, puis pendant le tracé, une arme en main, cliquer (gauche) sur une porte fermée, puis sur un zombie, puis sur une case libre loin du personnage ; recommencer en deux clics en posant le second coin sur une porte ; après le second coin, faire un clic droit sur le rectangle figé | Rien ne se passe dans le monde : porte non ouverte, ni attaque ni swing, personnage immobile, aucun menu contextuel, aucune surbrillance d'objet ; seuls les coins se fixent ; le clic droit sur le rectangle figé ne déplace pas ses coins ; après le tracé, les clics reviennent au jeu normalement (la molette zoome pendant tout le tracé) |
| Z24 | Surbrillance, cas limites : passer le curseur d'une action vanilla qui surligne le sol (pose d'un meuble, construction) sur une case éclairée ; mettre le jeu en pause (vitesse 0) puis modifier une zone ; meubles, murs, clôtures et végétation sur des cases du pourtour ; écran partagé (2e joueur à la manette) ; 50 zones ou plus autour de soi ; mourir fenêtre ouverte, case cochée | La case retrouve sa couleur de zone dans la seconde qui suit le passage du curseur ; en pause, la surbrillance suit la modification ; objets du pourtour dessinés normalement (ni doublés, ni assombris, ni par-dessus les personnages) ; seul l'écran de l'admin voit la surbrillance ; pas de chute d'images notable ; après la mort, plus rien au sol |
| Z27 | Secteur choisi par le joueur, cas limites : un seul secteur actif ; `DropZoneMinDistance = 300` en appelant depuis une zone de Louisville ; feuille ouverte, repasser l'option à *Le plus proche du demandeur* puis transmettre ; **Forcer un largage (admin)** ; une zone de West Point entièrement sur un lac approché, seule dans son secteur, puis choisir West Point ; nom de secteur de 32 caractères, grande police, anglais puis français ; écran partagé avec beaucoup de lots (feuille paginée) | Secteur unique imprimé sans flèches, choisi d'office, **Transmettre** actif dès qu'un lot est choisi ; Louisville absent de la liste (trop proche) ; option changée : « Réquisition non conforme, rien ne part. Rappelez », l'appel suivant n'a plus de champ ; feuille ADMIN sans champ, caisse près de l'admin ; lac : « Aucun point de largage dans ce secteur. Choisissez un autre secteur », feuille rouverte remplie, autre secteur accepté sans rappeler (secteur unique : « … pour l'instant. Rappelez plus tard ») ; nom raccourci « ... » dans le champ, complet dans l'infobulle, libellé et note lisibles ; champ au pied de chaque page, la manette ne change pas de page sur la ligne des secteurs |
