# Contraintes de développement

## Architecture validée le 2026-10-26

La demande d'implémentation du plan [poste et nettoyage](annexes/plans/plan-poste-et-nettoyage.md) valide son architecture modulaire à autorité serveur et sa migration additive. Le périmètre est `batman_MilitaryDrop` ; les dépendances Belt Walkie-Talkie et Signal Smoke sont préservées.

- Client (`PostWindow`, `ExchangeMenu`) : interactions, rendu et état reçu ; les actions passent par `Exchange.send`, jamais par une mutation directe du métier serveur.
- Partagé (`Exchange`, `Radio`, `Net`) : commandes, référence de l'appareil, action chronométrée et transport ; dépendances aux helpers partagés et à l'API radio commune.
- Autorité (`Missions`) : règles, progression, attribution, échéances, migration et clôture ; dépendances aux services existants `Guard`, `Trust`, `Post`, `Broadcast`, `Exchange`/`Radio`, `Net` et état privé.
- Autorité (`Post`) : poste, journal et projection personnelle de la console ; dépendances aux services métier, aucune dépendance au rendu client.

Le serveur revérifie les commandes ; le client ne fournit jamais un total de morts faisant autorité. La migration conserve les morts suivies, contributions, cible et échéance, et initialise à zéro le compteur des morts locales supplémentaires. Aucun changement de pattern ni déplacement d'autorité n'est requis.

## Validation des corrections

Tests hors jeu : `python tests/run_tests.py --require-luacheck`. Scénarios en jeu via `autotest.json` et les hooks du projet, selon le README de l'outil commun ; critères détaillés dans le plan.
