# Contraintes de développement

## Architecture validée le 2026-10-26

La demande d'implémentation du correctif poste et nettoyage valide son architecture modulaire à autorité serveur et sa migration additive. Le périmètre est `batman_MilitaryDrop` ; les dépendances Belt Walkie-Talkie et Signal Smoke sont préservées.

- Client (`PostWindow`, `ExchangeMenu`) : interactions, rendu et état reçu ; les actions passent par `Exchange.send`, jamais par une mutation directe du métier serveur.
- Partagé (`Exchange`, `Radio`, `Net`) : commandes, référence de l'appareil, action chronométrée et transport ; dépendances aux helpers partagés et à l'API radio commune.
- Autorité (`Missions`) : règles, progression, attribution, échéances, migration et clôture ; dépendances aux services existants `Guard`, `Trust`, `Post`, `Broadcast`, `Exchange`/`Radio`, `Net` et état privé.
- Autorité (`Post`) : poste, journal et projection personnelle de la console ; dépendances aux services métier, aucune dépendance au rendu client.

Le serveur revérifie les commandes ; le client ne fournit jamais un total de morts faisant autorité. La migration conserve les morts suivies, contributions, cible et échéance, et initialise à zéro le compteur des morts locales supplémentaires. Aucun changement de pattern ni déplacement d'autorité n'est requis.

## Extension des dix améliorations autorisée le 2026-10-27

Le périmètre initial comprenait dix idées. Révision utilisateur : I04 est abandonnée et son implémentation retirée ; restent I01, I02, I05, I09, I10, I11, I12, I13 et I15. La première version I12 a été refusée ; sa refonte est validée puis implémentée selon le cadrage ci-dessous, sans changement de pattern.
Les services supplémentaires du principal conservent les mêmes couches : formules et
contrats partagés, interactions et rendu clients, règles et persistance sur l’autorité.
La migration est additive ; aucun pattern n’est remplacé.

La demande d'implémentation du plan conserve le pattern modulaire à autorité serveur décrit dans la conception I15. Le sous-mod facultatif dépend du principal uniquement. Client : menus/fenêtre et projection reçue ; partagé : transport et calculs purs ; serveur : résolution des objets, inventaires, énergie, persistance et gardes métier. Aucune dépendance serveur vers une fenêtre client. Le principal expose des registres génériques d'extensions, sans charger les ressources du sous-mod. Migration additive : nouveau registre privé versionné, aucun changement aux radios ou sauvegardes existantes. Branche de travail : `feature/planned-improvements-testing`.

Tests hors jeu : `python tests/run_tests.py --require-luacheck`. Scénarios en jeu via `autotest.json` et les hooks du projet, selon le README de l'outil commun.

## Refonte I12 validée le 2026-10-27

La maquette et le cadrage de la console administrative sont
validés par l’utilisateur : solo debug uniquement, multijoueur administrateurs autorisés.
Le pattern reste modulaire à autorité serveur. Le client présente, confirme et transporte
les intentions ; le service administratif résout les cibles et délègue les mutations à
`Missions`, `Trust`, `Flights` et `RelayServer`. Les services métier ne dépendent pas
de la fenêtre. Récompenses et clôtures idempotentes, droits et état revérifiés à chaque
intervention. Les nouvelles informations sont des projections, sans migration des objets
persistants existants.

Les variantes de configuration de tests sont rangées dans `autotest/scenarios/`, leurs
hooks dans `autotest/`. Seul le point d’entrée standard `autotest.json` reste à la racine.
Les chemins des variantes sont relatifs au dossier du JSON ; les résultats vont dans `runs/`.


## Accès administratif révisé le 2026-10-27

Décision utilisateur : bouton Military Drop Admin Menu dans la liste Debug/Main en solo ; unique entrée au clic droit du monde en MP admin. Aucune dépendance à une radio. AdminAccess enveloppe setupButtons une seule fois, conserve les autres boutons et revérifie les droits au clic. AdminTools réutilise les gestionnaires existants et leurs permissions ; les zones de largage restent dans leurs menus actuels.

La projection administrative privée inclut une rubrique Communications, seulement sur demande d’un admin autorisé : code en vigueur et fréquences actives. Aucune modification des synchronisations publiques ni des secrets persistants. Le serveur vérifie le droit avant de produire ces valeurs ; elles ne sont pas journalisées. Le pattern et la migration additive restent inchangés.


Lancement manuel de relais : la console délègue à RelayServer, sans déplacer l’autorité. Récupération du boîtier après transmission : Post conserve la mutation d’inventaire et le verrou recordersUsed. La recette de démontage utilise le système natif de craft, sans nouveau gestionnaire réseau ni changement du pattern validé.

Le poste agrège la projection publique de RelayServer avec les missions existantes. Recorders partagé ne contient que les identifiants et les lecteurs gardés de métadonnées ; Post reste seul responsable du marquage serveur et de son rattrapage depuis recordersUsed. Clients : filtrage des affaires et fournisseur TooltipLib uniquement. La nouvelle propriété d’objet est facultative et additive, sans migration destructive des sauvegardes.

Retour de réussite du nettoyage validé le 2026-10-27 : notification personnelle, historique du poste et coche verte pendant une heure de jeu. Missions conserve la clôture, les récompenses et l'historique privé borné ; Post ne reçoit qu'une projection personnelle. Client et Announce assurent le rendu et la carte à partir des messages serveur. Migration additive sans modification du pattern ni reconstruction des anciennes clôtures dépourvues de coordonnées/contributions.

## Publication Steam

Le changelog reste technique. La note anglaise destinée aux joueurs est conservée à la racine dans `workshop-changenote.md`, fichier requis par le lanceur `tools/publish_workshop.py`. Celui-ci délègue les contrôles et l'envoi au publieur commun, conserve les captures de la page et vérifie que les versions de la note, du changelog et des mods concordent.

Simulation : `python tools/publish_workshop.py`. Publication autorisée : `python tools/publish_workshop.py --submit --tag`. Le wiki se synchronise après le push de main avec `python tools/wiki_sync.py --push --prune`.

Publication 0.8.0 réalisée le 2026-10-27 après validation utilisateur : fusion `221e8fd` sur main, note anglaise séparée, huit descriptions publiées et 17 captures additionnelles conservées. Le tag `v0.8.0` désigne le contenu envoyé. L'API publique confirme la date de mise à jour avancée, la visibilité publique et les deux Mod ID dans la description. Wiki EN/FR synchronisé après le push de main. Aucun lancement du jeu pendant cette livraison ; le dernier correctif de reconnexion garde sa validation hors jeu et les limites consignées dans le changelog.

Publication 0.8.1 réalisée le 2026-10-29 sur demande utilisateur : commit `b579455` poussé sur main, note anglaise dédiée avec en-tête Version 0.8.1, huit descriptions publiées et 17 captures additionnelles conservées. Le tag `v0.8.1` désigne le contenu envoyé. L'API publique confirme la date de mise à jour avancée, la visibilité publique, la version 0.8.1 et les deux Mod ID ; la page des changements confirme la note et les nouveaux taux. La description française a aussi été vérifiée. Wiki EN/FR synchronisé après le push de main. Validation hors jeu : 984 tests Lua réussis, aucun avertissement luacheck, 88 fichiers Lua compilés. Aucun lancement du jeu pendant cette livraison.
