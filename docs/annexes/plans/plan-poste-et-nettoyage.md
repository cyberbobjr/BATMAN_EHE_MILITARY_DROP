# Plan de correction du poste de liaison et des missions de nettoyage

Date : 2026-10-26. Référence : Military Drop 0.7.0, variante `42.21`.

## Portée et statut

**Mise en œuvre autorisée le 2026-10-26** : objectif maintenu à 90 %, progression commune et récompense au meilleur contributeur. Architecture et migration consignées dans [developpement.md](../../developpement.md). Version 0.7.1 publiée à la demande de l'utilisateur ; résultats et limites de validation suivis dans [SUIVI.md](SUIVI.md).

Plan demandé à la suite de deux retours de joueur : impossibilité de transmettre un rapport quotidien ou de répondre au contrôle depuis une radio fixe ; nettoyage qui expire malgré de nombreux zombies ambiants abattus dans la zone. La demande autorise la conception, y compris un changement de règle. Les choix ci-dessous constituent la proposition à présenter avant développement.

Deux lots : rétablir les échanges dans la console du poste, puis adopter un comptage mixte pour les nettoyages. Les validations et la documentation accompagnent chaque lot. Aucune version de sortie n'est engagée.

## Diagnostic de référence

Constats **confirmés statiquement** dans le code local :

- `RadioModule.isPostRadio` et `Panel:layout` remplacent les commandes usuelles par le bouton du poste pour une radio fixe éligible.
- `PostWindow:actions` traite les plaques et les enregistreurs, mais ne propose aucune action pour les missions ; `PostWindow.affairs` n'ajoute pas de rapport quotidien. Le largage possède son propre bouton.
- `Exchange.checkRadio`, `Radio.resolve` et le contexte de `Missions.begin` acceptent déjà une radio militaire posée à proximité. Le bonus du poste est déjà prévu côté serveur.
- `Missions.countKill` reconnaît la horde par des signatures de tenue persistante. Les autres zombies ne comptent pas ; un zombie reconnu compte où qu'il meure. L'objectif est de 90 % de la taille effectivement suivie, arrondis au supérieur.
- `Missions.cleanupStatus` annonce la progression et le reste ; les rappels conservent les coordonnées initiales, sans localisation mobile des survivants.

La dispersion et le mélange décrits par le joueur sont une **hypothèse compatible avec ces règles**, sans reproduction de sa partie ni journal de sa session.

Référence de diagnostic hors jeu du 2026-10-26 : `test_missions.lua` 60 succès, `test_radiomodule.lua` 15, `test_postwindow.lua` 20, `test_exchange.lua` 30 ; total 125, code de sortie 0, API simulée. Ces résultats décrivent l'existant, pas la validation des corrections futures.

## Architecture proposée pour les deux lots

Conserver une architecture modulaire à autorité serveur, décrite dans [architecture.md](../../architecture.md), avec les responsabilités et dépendances suivantes :

| Partie | Responsabilité | Dépendances autorisées |
|---|---|---|
| Client : `PostWindow`, ses parties et `ExchangeMenu` | Affaires, actions, saisie, raisons de grisé, rendu et rafraîchissement | Contrats partagés et `Exchange` ; jamais d'accès direct à l'état serveur en MP |
| Partagé : `Exchange`, `Radio`, `Net` | Contrat des commandes, référence de l'appareil, action radio et transport | API de radio commune et helpers partagés |
| Autorité : `Missions` | Éligibilité des morts, progression, attribution, clôture et migration | `Guard`, `Exchange`/`Radio`, `Trust`, `Post`, `Broadcast`, `Net` et état privé existants |
| Autorité : `Post` | Vérification du poste, journal et données utiles à la console | Services métier existants ; aucune dépendance au rendu client |

Les fenêtres appellent les services par les commandes existantes. Le serveur revérifie appareil, distance, canal, cadence, source activée, personnage, échéance et ligne coupée ; le client ne déclare jamais un total de morts faisant autorité. Réutiliser le chemin d'échange chronométré et ses réponses, sans deuxième circuit de paiement.

Le pattern ci-dessus et la migration additive du lot 2 ont été retenus par la demande d'implémentation, puis documentés dans `docs/developpement.md`, conformément à l'interdiction de créer un `AGENTS.md` de projet.

## Lot 1 — Échanges depuis le poste de liaison

### Comportement proposé

Conserver le tableau des affaires et ses deux actions au maximum par fiche.

| Affaire | Action proposée | Règle |
|---|---|---|
| Rapport quotidien | Transmettre le rapport | Une fois par jour et par personnage, avec le bonus existant du poste |
| Contrôle radio ouvert | Répondre au contrôle | Disponible pendant le créneau ; une réponse par personnage |
| Reconnaissance ouverte | Confirmer la reconnaissance | Conserver la présence physique dans la zone : un poste éloigné ne permet pas de confirmer à distance |
| Nettoyage ouvert | Faire le point | Réponse radio avec progression globale, contribution personnelle et objectif restant |
| Passage Fulton | Demander un passage | Réutiliser les conditions et le créneau de l'échange existant |
| Plaques, enregistreur et largage | Actions actuelles | Régression à contrôler sur le même poste |

La présence de Fulton complète la parité des échanges actuellement masqués par le mode poste. Aucune nouvelle mission n'est créée. Les affaires de rapport et de passage sont présentes lorsque leur source est activée ; les missions viennent de la liste ouverte envoyée par le serveur.

### Mise en œuvre

1. Ajouter les affaires et actions dans `PostWindow_Affairs`, `PostWindow:actions` et le dessin du volet. Partager la sélection des options, les répliques et les raisons de grisé avec `ExchangeMenu` plutôt que les recopier.
2. Envoyer par `Exchange.send` avec la radio du poste ; traiter la réponse de la base puis rafraîchir journal, progression et disponibilité des actions. Si nécessaire, transmettre un état personnel minimal pour le rapport et le créneau Fulton via `PostData`, sans secret.
3. Afficher les refus utiles et l'état après réussite ; désactiver les actions pendant l'envoi. Le serveur protège aussi les répétitions entre console et talkie, les commandes simultanées et les réponses arrivant après expiration.
4. Couvrir clavier, souris et manette ; conserver le comportement de fermeture lorsque le joueur quitte la portée du poste. Vérifier les libellés longs et les huit langues.

### Acceptation

- Un personnage sans radio portable transmet son rapport et répond au contrôle depuis son poste fixe.
- Un deuxième rapport le même jour ou une deuxième réponse ne paie rien, y compris depuis un autre appareil.
- Radio éteinte, canal incorrect, poste trop éloigné, ligne coupée et source désactivée suivent les refus existants.
- Une reconnaissance hors zone reste refusée ; un poste réellement situé dans la zone peut servir.
- Bonus personnel, plafond quotidien, journal et reconnexion restent cohérents ; les actions de plaques, d'enregistreur et de largage fonctionnent encore.

## Lot 2 — Comptage mixte du nettoyage

### Nouvelle règle proposée

Après apparition effective de la horde et avant l'échéance, une mort contribue si **au moins une** de ces conditions est satisfaite :

1. Le zombie est reconnu par le suivi existant de la horde de mission, même hors du cercle.
2. Le zombie meurt à l'intérieur du cercle fixe annoncé, au niveau du sol, même s'il appartient à la population ambiante.

Compter chaque mort une seule fois, y compris lorsqu'elle remplit les deux conditions ou que l'événement est répété. Une mort ambiante hors du cercle ne compte pas. Pour la zone, utiliser le centre `(mission.x + 0.5, mission.y + 0.5)`, le rayon de la mission (actuellement 40 cases), la distance au carré avec bord inclus et `z = 0`. Le joueur peut tirer depuis l'extérieur ; c'est la position du zombie qui détermine l'éligibilité géographique.

L'objectif reste **fixe à 90 % de la horde effectivement suivie**, arrondis au supérieur. Exemple : pour 30 zombies suivis, 27 morts admissibles suffisent ; 10 de la horde et 17 ambiants dans le cercle terminent la mission. Les zombies supplémentaires n'augmentent jamais l'objectif. Avant apparition, aucune mort ne constitue un crédit rétroactif.

Toutes les causes de mort admissibles avancent le nettoyage, comme aujourd'hui pour la horde. Le crédit personnel suit les règles existantes d'attribution au tueur et de ligne coupée. Le personnage avec le plus de crédits gagne la récompense actuelle, soumise au plafond ; égalité et absence de gagnant gardent leur traitement existant. Aucune prime supplémentaire par zombie.

Le cercle reste une zone d'opération fixe. Le suivi dynamique des survivants n'est pas nécessaire pour corriger ce cas : le joueur peut atteindre l'objectif en nettoyant les zombies présents. Le texte doit annoncer cet objectif de neutralisations, sans prétendre que tous les zombies de la zone ont disparu.

### Mise en œuvre et migration

1. Factoriser le calcul de progression pour `countKill`, le seuil de clôture, `hordeLeft`, la réponse radio et `listForCharacter`. Tous affichent et utilisent le même total admissible.
2. Conserver `horde.dead` et les signatures de suivi existantes ; ajouter un compteur des morts locales non déjà créditées au titre du suivi (nom proposé : `nearbyDead`) et un marqueur de schéma. Le total vaut `horde.dead + nearbyDead`.
3. Appliquer le marqueur de dédoublonnage existant aux deux chemins avant tout compteur et récompense. Pour une signature reconnue, consommer au plus son crédit disponible ; pour une autre mort locale, avancer uniquement le compteur local.
4. Migration additive et idempotente : initialiser le nouveau compteur à zéro pour une mission en cours, conserver morts déjà comptées, contributions, classement, cible et échéance. Ne pas recompter d'anciens cadavres ni rouvrir les missions closes. Tester les sauvegardes sans horde apparue et les anciens formats effectivement présents.
5. Adapter les annonces d'ouverture, les rappels, le statut et la console : zone fixe, morts admissibles, contribution du personnage, reste avant clôture. Mettre à jour les traductions et les guides EN/FR.

**Limite connue du suivi existant :** la signature de tenue persistante n'est pas un identifiant unique de zombie. Le critère « reconnu » reste donc approximatif, notamment hors zone. Vérifier les collisions avec des zombies ambiants et documenter la limite ; ne pas présenter la nouvelle règle comme un suivi individuel exact. Une refonte de cette identité n'est pas nécessaire au comptage géographique et ne doit pas introduire une dépendance à des références Java recyclées ou à des ModData perdues par virtualisation.

### Acceptation

- Horde mélangée à une population ambiante beaucoup plus importante : objectif atteint avec les morts admissibles, sans devoir retrouver chaque survivant initial.
- Zombie reconnu hors cercle : compte ; zombie ambiant hors cercle ou à un autre étage : ne compte pas. Tester le bord exact du cercle.
- Zombie reconnu dans le cercle et événement de mort répété : un seul crédit.
- Mort avant apparition ou après échéance : aucun crédit ; apparition partielle : cible calculée sur la taille réellement suivie.
- Deux joueurs, contributions différentes, égalité, feu sans tueur, ligne coupée : un seul résultat et une seule récompense selon les règles prévues.
- Sauvegarde, redémarrage et reconnexion pendant la mission : progression conservée ; migration répétée sans effet supplémentaire.

## Ordre de réalisation et validation

1. Valider l'architecture et les règles proposées, puis consigner la décision et les contrats.
2. Réaliser le lot 1 avec tests ciblés : affaires, actions réellement déclenchées et échanges serveur, pas seulement présence des libellés.
3. Réaliser le lot 2 avec tests de comptage, limites de zone, double événement, attribution et migration. Remplacer le test qui impose l'exclusion de toute mort ambiante par les cas de la nouvelle règle.
4. Exécuter `python tests/run_tests.py` depuis le projet, avec luacheck disponible, puis les contrôles `pz-autotest` après lecture de son README.
5. Ajouter des scénarios ciblés au dispositif existant : poste sans portable, contrôle et rapport par les actions de la console ; nettoyage avec zombies suivis et ambiants, puis redémarrage. Exécuter le solo et le MP avec serveur dédié et deux clients réels, `--client-run` et `--wait-idle 3600`. Les deux joueurs doivent réellement participer au scénario d'attribution.
6. Vérifier la Build du journal et des sources pour chaque passage. Archiver code de sortie, ligne `summary` et dossier `runs/...`. Contrôler manuellement lisibilité, voix/répliques radio, clavier et manette ; les assertions automatiques seules ne prouvent pas le rendu.
7. Mettre à jour spécifications, wiki EN/FR, suivi et changelog avec les preuves obtenues. Préparer une version corrective cohérente, sans commit, push ni publication tant qu'ils ne sont pas demandés.

Le plan est terminé lorsque chaque lot possède ses critères satisfaits et ses limites de validation explicitement consignées. Un test d'API simulée ne vaut pas validation en jeu ou sur serveur Linux ; prévoir un passage Linux pour la casse des ressources et le fonctionnement du serveur cible si l'environnement est accessible.
