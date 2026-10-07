# Idée 12 — Extraction de butin par Fulton : note d'idée

Note du 2026-10-05, en lecture seule. **[C]** signale ce qui est confirmé dans les sources, **[S]** ce qui est supposé ou reste à vérifier en jeu. **Rien n'est conçu ni testé.**

- **Origine** : discussion Discord des 4 et 5 octobre 2026. *Mr.Mushroom* a proposé l'idée et *batman-fr* l'a ajoutée à sa liste de travail.
- **Suivi** : FULTON-01 dans [SUIVI.md](../SUIVI.md), à l'état `à décider`. L'idée sera conçue après les zones de largage ([idée 11](idee-11-zones-de-largage.md)).

## 1. Proposition

Les autorités à l'extérieur ont besoin d'informations et d'échantillons venus de la zone infectée. Le joueur leur envoie des objets de renseignement :
- des documents médicaux, policiers ou militaires ;
- des échantillons prélevés sur des zombies.

Pour cela, il utilise un **système de récupération Fulton** : un ballon gonflé à l'hélium, relié par un câble d'acier à un sac, est accroché au passage par un appareil. En échange, le joueur reçoit du « crédit ».

Précisions de Mr.Mushroom :
- l'équipement est à **usage unique** ;
- on le trouve dans les largages ou les lieux militaires, ou on le **fabrique** : une bâche pour le ballon, une bouteille d'hélium trouvée dans les maisons, un câble d'acier et un sac.

## 2. Liens avec l'existant

- **Transmission** : SRC-06 (« documents militaires transmis », `décidé`) et SRC-08 (enregistreur de vol) sont déjà des sources de confiance. Fulton serait un **autre moyen de transmission** pour des objets physiques, avec la même grille de valeurs.
- **Monnaie** : la confiance, qui donne le budget de réquisition (REQ-03). On n'ajoute pas de crédit séparé. Le plafond journalier CONF-08 s'applique.
- **Récupération** : le passage de l'appareil réutilise l'hélicoptère simulé (HELI-01 : son, ombre, flèche). Une récupération annoncée expose le point d'envoi, comme une caisse.
- **Idée 10** : l'idée 10 extrait le **personnage**, Fulton extrait des **objets**. Les deux mécanismes sont distincts, mais ils peuvent partager l'appareil et la zone d'attente.
- **Idée 11** : sur un serveur en mode zones, la récupération pourrait être limitée aux zones de largage. À trancher.

## 3. Points techniques à vérifier

- **[C] Hélium** : aucun script de `media/scripts` 42.21 ne contient « helium » (relevé du 2026-10-05). Seule la bâche (`Tarp`) existe. Il faut un objet du mod, ou une autre cause dans le monde.
- **[S] Ballon** : l'ascension d'un ballon ne peut sans doute pas être rendue avec un objet du monde. Il faudrait une tuile ou un modèle fixe, puis le faire disparaître au passage de l'appareil.
- **Contenu du sac** : le serveur le valide (objets admis par tag ou par catégorie, aucun nom d'objet vanilla), puis le détruit après le passage.
- **Sac posé au sol** : il ne doit pas être dupliqué si la case est déchargée pendant l'attente (`.claude/pz-knowledge/world-placement.md`, objets rangés dans un sac au sol).

## 4. Questions à poser au moment de la conception

- Valeur de chaque catégorie d'objet, et fourchette de confiance gagnée.
- Recette de fabrication : objets requis par tag ou propriété, compétences.
- Annonce publique de la récupération, ou appareil discret.
- Récupération limitée aux zones de largage en mode zones, ou possible partout.

## 5. Décisions du 2026-10-07 (objets et recettes)

- **Fabrication en plusieurs pièces** : ballon plié (bâche, fil, colle ; aiguille, ciseaux ; Couture 3), sac à harnais (sac de sable vide, corde, ruban adhésif ; ciseaux), assemblage (ballon, sac, fil de fer ; pince). Le **fil de fer vanilla remplace le câble d'acier** : aucun objet câble dans le mod.
- **Kits endommagés à réparer** (fil, ruban adhésif, fil de fer ; aiguille, pince ; Couture 1), trouvés dans le monde.
- **Hélium** : bouteille du mod à 4 gonflages, conservée vide ; seul le kit part avec le colis.
- Restent à décider : lieux des kits endommagés et des bouteilles d'hélium, déploiement du kit (action, contenu du sac, appareil), valeur en confiance. Suivi : FULTON-02 à FULTON-05.

## 6. Décisions du 2026-10-07 (utilisation en jeu et missions)

- **Rendez-vous radio** : le joueur demande un passage sur la fréquence militaire ; le créneau s'ouvre **immédiatement** et dure **30 minutes de jeu**. Hors créneau, le lâcher est refusé. Créneau manqué : perdu, sans pénalité (proposition).
- **Annonce** : la chaîne militaire annonce le passage **avec son secteur**, comme une caisse (l'expéditeur est exposé).
- **Lieu** : partout, y compris en mode zones (l'idée 11 ne restreint pas le Fulton). Refus proposés : à l'intérieur, sous un toit ou un arbre, par orage ou vent violent, en zone non-PvP ou dans un refuge.
- **Chargement** : le kit devient un **sac à remplir** (conteneur, environ 10 de capacité). Au lâcher, le serveur valide le contenu, détruit le kit et les objets, puis verse la confiance. Une charge d'hélium est consommée. Aucun sac ne reste au sol (aucune attente).
- **Paiement** : barème par catégorie, à **valeurs élevées**. Plafond quotidien CONF-08 appliqué. Les objets sans valeur sont détruits sans gain.
- **Objets admis**, uniquement vanilla, sans nouvel objet du mod :
  - **renseignement** : cartes d'identité nominatives des morts (tag `base:idcard`, nom posé par le jeu ; pas celle du joueur ni une carte vierge), cartes annotées ou cartes-cachettes, `Paperwork` ;
  - **matériel NRBC** : masques à gaz, filtres, combinaisons hazmat.
- **Barème validé** : carte d'identité nominative +3, Paperwork +1, carte annotée ou cachette +4 ; masque à gaz +2, filtre +1, combinaison hazmat +6. Zombie Virus Vaccine : sang infecté ou contaminé +1, liquide cérébral basse/moyenne/haute +2/+3/+4, cerveau +3 (pourri ou brûlé : 0) ; vaccin simple +5, de qualité +7, avancé +10 (sous plafond), remède +25 hors plafond (comme SRC-08). Plafond quotidien : option `TrustDailyCap`, 10 par défaut depuis le 2026-10-07.
- **Compatibilité Zombie Virus Vaccine** (Workshop 3615135168, `id=ZVirusVaccine42BETA`, module `LabItems`, variante 42.20 non testée en 42.21) : facultative, détectée par la liste des mods actifs puis par l'existence de chaque objet. Sont payés les échantillons (sang infecté ou contaminé, seringues de liquide cérébral selon leur qualité basse, moyenne ou haute, cerveaux) et les vaccins (simple < qualité < avancé), ainsi que le remède, très cher. Valeurs à fixer.
- **Kits endommagés** : épaves Mayday, lieux militaires vanilla, et plus rarement les caisses de largage.
- **Bouteilles d'hélium** : magasins (fêtes, cadeaux, jouets) et lieux militaires vanilla, sans lot de réquisition.
- **Missions concernées en premier** : renseignement (A) et matériel NRBC (C). Échantillons (B), commande inverse (D), extraction contestée (E) : plus tard.
- ⚠ À vérifier : son d'avion vanilla ; salles et listes de butin 42.21 des magasins de fêtes et des lieux militaires ; repérage d'une carte annotée (symboles de la carte) ; tags des masques, filtres et combinaisons.
- **Conception détaillée** : [idee-12-fulton-conception.md](idee-12-fulton-conception.md). Écarts décidés le même jour : la carte annotée est illisible côté serveur, donc seules les cartes-cachettes paient ; les pièces d'identité nominatives incluent passeports, cartes de presse et badges ; les papiers sont `Paperwork` et `OfficialDocument` ; le matériel NRBC se limite au militaire.
