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
