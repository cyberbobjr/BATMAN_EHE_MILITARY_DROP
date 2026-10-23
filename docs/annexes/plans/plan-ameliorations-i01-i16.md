# Plan des améliorations I01 à I16 sélectionnées

Date : 2026-10-23. Base : Military Drop 0.7.0, variante `42.21`.

## Portée et statut

Plan demandé pour **I01, I02, I04, I05, I09, I10, I11, I12, I13, I14, I15 et I16** du [catalogue](../../ameliorations-et-idees.md). La demande autorise la planification ; elle ne déclenche ni développement, ni publication. Les réglages ci-dessous sont des propositions de conception, sauf l'exigence explicite I01 : **le bruit attire les zombies existants et le spawn reste systématiquement prévu**, indépendamment de la population locale. Les bornes et options de création du jeu continuent de s'appliquer.

I03, I06, I08 et I17 à I20 restent hors périmètre ; I07 est déjà réalisé. C11 reste écarté. Aucune version de livraison ni date de sortie n'est engagée.

## Constats qui orientent le plan

Lecture statique du code local ; aucune nouvelle fonctionnalité testée en jeu.

- `MilitaryDrop_Flights.lua:60-64,240,293-296` émet déjà un bruit de rotor toutes les **3 secondes**, rayon **60**, volume **40**, et un bruit de largage rayon **150**, volume **100**, côté autorité et à `z=0`. I01/I02 doivent compléter et paramétrer ce chemin, sans doubler ses émissions. Le bruit du vol précède la pose effective si la case n'est pas chargée.
- `MilitaryDrop_Trust.lua:321` (`markCollected`) arrête déjà les rappels à la récupération physique ; `onCaseOpened` distingue demandeur, faction et tiers et attribue déjà la récompense. I13 ajoute une confirmation, sans remplacer cette clôture automatique ni payer une seconde récupération.
- `MilitaryDrop_FultonServer.lua:192-198` évalue et paie au lâcher. I09 doit utiliser le même instant de référence pour le calcul et le paiement, sans déplacer celui-ci à l'enlèvement visuel du ballon.
- I04 mentionne I03 comme dépendance dans le catalogue ; techniquement, un essai autonome peut reprendre `FultonRender` et `Render3DItem`, sans développer le parachute.
- I15 dépend dans le catalogue du filtrage serveur C11, écarté par l'utilisateur. Son étude est retenue ; sa réalisation reste conditionnée à une solution compatible ou à une nouvelle décision explicite.
- Le journal local `C:/Users/cyber/Zomboid/console.txt:60` indique `42.21.0`. Les sources décompilées `E:/pz-decompiled/42.21.0/java` sont présentes. Cela identifie les références de travail, sans valider les comportements futurs. Avant chaque essai, relever à nouveau le journal et la version des sources/installations réellement employées.

Les noms courts de modules ci-dessous désignent `MilitaryDrop_<nom>.lua`, sous `Contents/mods/batman_MilitaryDrop/42.21/media/lua/{shared,client,server}/MilitaryDrop/`. Les futurs noms de modules, commandes, clés et options restent à contractualiser.

## Architecture et prérequis

Conserver comme base de conception l'[organisation actuelle](../../architecture.md) : client pour les interactions et le rendu ; modules partagés pour les calculs purs et contrats ; serveur/solo pour les décisions, inventaires, confiance, état persistant et émissions de bruit. Le transport reste `Net`, avec contrôle des commandes via `Guard` et validation métier côté serveur. Ne pas faire croître `Server`, `Missions` ou les fenêtres avec toute la nouvelle logique : isoler les responsabilités lorsque nécessaire.

**Avant toute implémentation serveur**, faire valider explicitement le pattern d'architecture et, si nécessaire, la stratégie de migration, puis les documenter dans un `AGENTS.md` du projet (absent lors de cette lecture) : couches/modules, responsabilités, dépendances autorisées. La description existante dans `architecture.md` ne prouve pas cette validation. Ce prérequis ne bloque pas le présent travail documentaire et n'est pas une décision à prendre implicitement pendant le codage.

Pour chaque lot : préciser les commandes et contrôles, schémas de persistance, migrations additives/idempotentes, bornes et défauts des options ; mettre ensuite à jour les spécifications. Garder les états privés côté autorité, transmettre seulement les données utiles à leur destinataire. Préserver les identifiants persistants et les fichiers administrateur existants. Les options désactivées doivent conserver le comportement antérieur ; une désactivation ne doit pas laisser de mission ou commande irrésoluble.

## Découpage et ordre

| Lot | Idées | Livrable et condition de passage | Effort relatif |
|---|---|---|---|
| P0 | Transversal | Pattern validé et documenté avant code serveur ; contrats et protocole par lot | S |
| P1 | I01 + I02 | Bruits existants configurables, attraction et spawn conservé ; référence de densité et de coût | S–M |
| P2 | I13 + I11 | Confirmation unique et citations persistantes, sans double récompense | M |
| P3 | I09 + I10 | Besoins hebdomadaires et reconnaissance active, plafonds et dédoublonnage | M |
| P4 | I12 | Tableau de bord et actions contrôlées pour observer les systèmes suivants | M |
| P5 | I05 | Cycle complet panne/réparation/reprise sur site valide | L |
| P6 | I16 puis I14 | Demande spéciale stable, puis restrictions compatibles avec les commandes engagées | M–L |
| P7 | I04 | Essai visuel, puis intégration si le rendu est viable | L |
| P8 | I15 | Étude de faisabilité et arbitrage C11 ; développement conditionnel | M–L |

P7 et l'étude P8 peuvent être traités indépendamment après P0 ; I04 n'attend pas I03. Les efforts incluent contrats, traductions et vérifications ; ce ne sont pas des durées calendaires. Réévaluer I14 (initialement S) : les autorisations de réquisition et les caisses déjà livrées rendent son intégration plus large qu'un simple multiplicateur.

## I01 — Attraction avec spawn maintenu

**Comportement retenu** : conserver l'apparition de la horde du largage via l'aide issue de C01, selon les options existantes. Ne pas la remplacer par l'attraction, ni la conditionner à une zone vide. Les nombres configurés à zéro et les refus de création du moteur restent respectés.

Travail : relier explicitement bruit d'approche, bruit de largage et pose effective. Si la pose est différée, prévoir une impulsion à la pose, unique par livraison, sans rejouer celle du passage. Conserver l'aide de spawn et les gardes contre l'eau ; ne pas ajouter une seconde horde. Les réglages de bruit sont distincts des quantités de spawn. Le leurre garde sa sirène, le crash son cycle propre.

Modules : `Flights`, `Server` (livraison et `spawnHordeAround`), `Core`, options sandbox. État minimal si une impulsion de pose doit survivre à une sauvegarde.

Acceptation : en secteur peuplé, attraction **et** même demande de spawn qu'avant ; secteur vide, spawn toujours demandé ; bruit désactivé, spawn intact ; pose tardive, restauration et double callback sans double horde. Vérifier près de l'eau et quand la création de zombies est désactivée. En jeu, observer la convergence sans promettre un nombre exact de zombies attirés.

## I02 — Intensité du rotor configurable

Conserver la trajectoire autoritaire et la cadence actuelle de 3 s comme référence. Proposer une intensité bornée dont **0 désactive le bruit d'attraction du rotor**, sans couper l'audio local ; valeur nominale correspondant au rayon 60/volume 40 actuels. Le bruit du largage est réglé séparément. Préciser les plafonds après mesure ; ne pas copier le rayon 500 du vanilla par défaut.

Modules : `Flights`, `Flight`, `Core`, options sandbox ; pas de bruit logique émis par les clients. Reprendre les émissions existantes, sans nouveau réseau applicatif pour chaque impulsion.

Acceptation : bruit aux positions successives, cadence stable quel que soit le nombre de clients ou le framerate, aucun rattrapage en rafale après pause, arrêt en fin de vol ; vérifier la transition vers le crash et la cohabitation HEF. Mesurer le coût avec plusieurs vols et l'impact combiné I01/I02 sur la densité.

## I13 — Confirmer une réception

Ajouter l'échange radio au demandeur après ouverture reconnue d'une caisse de son largage ; conserver la récupération par faction selon les règles actuelles. Proposition : une seule confirmation par largage, récompense faible soumise au plafond journalier, indépendante du gain de récupération existant. Un tiers ne peut pas confirmer au nom du demandeur. Pas de confirmation pour un leurre, un largage expiré ou un crash.

Modules : `Trust`, `Server`, `Exchange`, `ExchangeMenu`, `RadioModule`, éventuellement `Post`. Conserver une preuve privée de réception et un marqueur de confirmation pendant une durée explicite, y compris lorsque le dossier clos est purgé. Ne pas dépendre d'un dossier déjà supprimé ni réactiver ses rappels. Garder l'arrêt automatique actuel ; la confirmation doit pouvoir appeler la clôture de façon idempotente.

Acceptation : ouverture ≠ simple coffre consulté ; propriétaire et faction admis selon le contrat ; tiers refusé ; double clic, reconnexion et redémarrage sans second gain ; confirmation possible après la clôture automatique pendant sa période de validité. Le vol des fournitures conserve son traitement actuel.

## I11 — Citations aux paliers de confiance

Enregistrer les paliers atteints pour la première fois, puis joindre la citation au prochain largage personnel admissible. Une baisse puis remontée ne produit pas de doublon. Proposition : une lettre par palier, conservée en attente si aucun largage n'a lieu ; honneur du palier IV par une plaque nominative existante, sous réserve d'un type vanilla vérifié. Un insigne cosmétique n'est pas créé sans ressource adaptée.

Modules : `Trust`, `Crate`, `Documents`, `PrintMedia`, scripts et traductions. Le serveur décide le bénéficiaire, le palier et l'émission ; le client peut composer le rendu à partir des paramètres. Retenir le nom du personnage au moment de l'attribution. Prévoir une règle pour les personnages existants : proposition, mémoriser leur palier courant sans distribuer rétroactivement toutes les citations.

Acceptation : franchissement multiple, objets livrés une seule fois, crash avant livraison (citation reste en attente), caisse déjà livrée non modifiée après coup, personnage renommé et reconnexion ; vérifier en jeu lecture, accents et mise en page dans les 8 langues. La citation ne doit pas créer une nouvelle source de gains Fulton répétables.

## I09 — Besoins Fulton hebdomadaires

Choisir côté serveur une liste bornée de catégories du barème pour la semaine, avec bonus, dates et identifiant de période persistants. Reprendre le calendrier du changement de code, sans dériver ni exposer son secret. Afficher les besoins au poste et les annoncer une fois à la bascule ; un joueur de retour peut consulter la liste sans nouvelle annonce globale.

Modules : `Fulton` (évaluation), `FultonServer` (paiement), `Codes` (référence calendrier), `Broadcast`, `Post`. Le serveur recalcule la prime au lâcher. Le devis client indique la semaine ; un changement entre devis et lâcher exige un nouveau devis avant consommation. Proposition : bonus sur la part plafonnée seulement ; la récompense spéciale du remède garde sa règle. Exclure les catégories d'intégrations absentes, sans rendre Zombie Virus Vaccine obligatoire.

Acceptation : lundi, sauvegarde/reprise, semaine sautée hors ligne, catégorie absente, plafond atteint, lâcher à la bascule ; deux clients voient la même liste et aucun paiement ne se duplique.

## I10 — Signaler une concentration

Ajouter un échange radio sans coordonnées ni quantité imposées par le client. Le serveur compte les zombies réels vivants dans un rayon borné autour de la position autoritaire ; afficher un refus compréhensible si le seuil n'est pas atteint. Le résultat décrit une concentration locale chargée, pas la population virtuelle de toute la cellule.

Modules : `ExchangeMenu`, `Missions`, `Guard`, `Trust`, `Broadcast`. Définir seuil, rayon, cadence et petit gain plafonné. Persister un dédoublonnage spatial/temporel commun aux joueurs : plusieurs rapports proches de la même concentration ne créent ni plusieurs primes ni plusieurs missions. Une mission de nettoyage peut être proposée si le planificateur a une place, sans récompenser une seconde fois le seul signalement. Borne de taille et purge du registre.

Acceptation : seuil juste insuffisant/atteint, cadavres exclus, positions falsifiées ignorées, joueurs voisins simultanés, reconnexion, redémarrage, absence de créneau de mission. Mesurer le coût sur une liste importante, sans parcours global à chaque tick ; tester le comptage réel sur serveur dédié.

## I12 — Tableau de bord administrateur

Étendre l'outil des zones avec vues largages, vols, épaves, missions et personnages connectés. Utiliser des résumés paginés et rafraîchis à la demande. Actions prévues : lever une ligne coupée, clore un largage bloqué, relancer une annonce. Une clôture manuelle doit expliciter son effet sur les fournitures en attente et les pénalités ; proposition, aucune pénalité de confiance.

Modules : `ZonesAdmin`, `ZonesWindow`, nouvelle vue dédiée si nécessaire ; gestionnaires serveur appelant les API métier existantes. Revérifier à chaque lecture et mutation la capacité actuelle `ChangeAndReloadServerOptions`, la cadence et l'identifiant de l'entité. Ne transmettre ni graine ni code secret. Journal serveur en anglais avec auteur, cible et résultat.

Acceptation : accès et commandes forgées refusés à un joueur ordinaire, droits retirés pendant la fenêtre, cible disparue, double action, grand nombre d'entrées ; seule la personne autorisée reçoit les données. Les annulations suivent les chemins métier et nettoient les repères clients concernés.

## I05 — Remettre un relais en service

Concevoir un cycle persistant : opérationnel → panne annoncée → réparation disponible → opérationnel. Déclencheur observable : orage ou transition de coupure électrique, avec délai de réarmement pour éviter une panne immédiate après réparation. Proposition de premier lot : appels refusés pendant la panne, avec message et objectif ; définir ensuite le périmètre exact (largages, Fulton, échanges) avant code. Les vols déjà engagés continuent.

Modules : responsabilité relais isolée côté serveur, intégrée à `Missions`, `Server`, `Post`, `Broadcast` et aux échanges. Site vanilla candidat à revalider : relais vers 4827,6277 ; prévoir une position configurée et un contrôle du site pour les cartes modifiées. Si aucun site valide n'existe, désactiver cette mission avec diagnostic, sans bloquer durablement la logistique.

La réparation exige proximité, pièces électroniques et générateur alimenté/actif vérifiés sur l'autorité. Ne pas créer aveuglément un générateur par chargement : reconnaître l'installation et son identifiant ; lire l'état à son chargement, sans supposer les cases distantes disponibles. Définir qui installe/possède le générateur et quelles ressources sont consommées. Proposition : composants consommés une fois, récompense au réparateur dans le plafond, reprise du service publique ; pas de paiement répété aux témoins.

Acceptation : coupure/orage persistant, site déchargé, réparation simultanée, manque de carburant ou composants, redémarrage en panne, option désactivée en mission, carte sans relais. Vérifier les appels depuis poste et talkie, ainsi que la réception du diagnostic malgré la panne.

## I16 — Demande spéciale ciblée

Ajouter au formulaire un choix de catégorie fine réservé au palier IV, coûteux et limité en quantité. L'intitulé I16 ne promet pas un `fullType` arbitraire : le serveur résout une demande admissible parmi les objets disponibles. Pour les munitions, relire l'arme tenue et son `getAmmoType`, puis valider le type réellement chargé ; aucune chaîne de type libre venant du client.

Modules : `Lots`, `LotsFile`, `Requisition`, `RequisitionWindow_Form`, `Loot`, `Crate`. Étendre le format de `requisition.txt` de façon rétrocompatible, sans écraser les personnalisations. Devis serveur avec choix, coût, quantité et durée ; tout revalider à la commande. Fixer le choix accepté dans le dossier privé pour que changement d'arme, rechargement du catalogue ou I14 ne transforme pas le contenu après acceptation. Refus explicite si la catégorie ne peut fournir d'objet.

Acceptation : palier insuffisant, budget falsifié, demande périmée, arme changée, type fourni par un mod puis retiré, ancien fichier administrateur et ancienne caisse ; pas de paiement sans commande acceptée et pas de tirage non ciblé silencieux.

## I14 — Raréfaction progressive

Option désactivée par défaut. Définir un calendrier serveur monotone fondé sur l'âge du monde, avec seuils configurables et annonces uniques. Proposer trois étapes : logistique normale, restrictions, moyens réduits. Le dernier pont aérien reste une extension explicitement activée, jamais un arrêt définitif implicite. Les coupures peuvent être des conditions supplémentaires observables, pas des changements silencieux de configuration globale.

Modules : calcul pur de politique, état privé serveur, `Requisition`, `Lots`, `Server` (délai), `Broadcast`, `Notes`/`Documents`, `Post`. Calculer des valeurs effectives sans réécrire les options sandbox ni `requisition.txt`. Les commandes acceptées gardent leur contrat ; les autorisations non engagées sont invalidées et rouvertes à la nouvelle politique. Les caisses livrées gardent leur contenu. I16 doit rester compréhensible si certaines catégories disparaissent.

Acceptation : monde ancien activant l'option, semaines sautées, redémarrage, réglages changés à chaud, désactivation, calendrier ramené en arrière ; pas de double annonce ni commande rendue impossible après acceptation. Expliquer les restrictions au joueur avant sa dépense. Revalider la signature et la référence temporelle de l'API d'âge du monde en 42.21.

## I04 — Silhouette d'hélicoptère en vol

Commencer par un essai local isolé à partir de `FultonRender` : modèle intact dérivé de l'épave, orientation, altitude apparente, profondeur, toitures et zoom. I03 n'est pas requis. Le modèle doit suivre la trajectoire partagée `Flight`, sans objet physique ni autorité de jeu côté client.

Modules : `Heli`, rendu dédié si l'essai aboutit, scripts de modèle et ressources dans `common`. Garder son, ombre et flèche comme repli si le rendu est impossible ou désactivé. Vérifier l'orientation modulo 360, les chunks absents et la jonction vers l'épave au crash ; aucune réplication de transformation à chaque image.

Acceptation préalable au travail complet sur les ressources : visibilité et profondeur convaincantes à plusieurs zooms/étages, jour/nuit ; pause et synchronisation MP cohérentes. Puis tester reconnexion pendant un vol, écran partagé, plusieurs vols et coût de rendu. Si la caméra coupe le modèle, consigner l'échec de l'essai et garder le repli, sans annoncer I04 livré.

## I15 — Brouilleur PvP : étude conditionnelle

Étudier deux portées distinctes : brouillage de confort sur clients standards (messages, repères, poste, réceptions BeltRadio) ; confidentialité effective contre un client modifié. Le premier ne garantit pas le second : les coordonnées déjà diffusées restent lisibles. Ne pas réintroduire C11 sous un autre nom.

L'étude doit suivre **tous** les chemins : chaîne radio vanilla, `DropAnnounce`, synchronisations de missions et vols, repères persistants, poste, commandes au retour d'un joueur. Vérifier si une interception locale propre des messages vanilla est possible sans casser les autres chaînes. Si le périmètre voulu exige le filtrage serveur écarté, présenter le contrat et demander une nouvelle décision avant développement. Aucun filtre client ne sera présenté comme une protection PvP contre la triche.

Si une variante est retenue : option désactivée par défaut, appareil posé identifiable, alimentation et fréquence vérifiées sur le serveur, activation par interaction/recette électronique, rayon borné, limites de nombre et cadence de recherche. Réindexation au chargement ; retrait à destruction/extinction ; pas de son radio supposé suffisant pour le brouillage. Définir le devenir des anciens repères : proposition, aucune suppression des coordonnées déjà connues, seulement blocage des nouvelles réceptions dans la zone.

Acceptation de l'étude : tableau des canaux couverts/non couverts et décision explicite sur C11. Acceptation du futur code : entrée/sortie de zone, radios portées/posées/ceinture/autoradio, appareil sans énergie, redémarrage, destruction et deux clients de part et d'autre du rayon ; une seule annonce d'interférences par période, sans révéler les secrets de la base.

## Validation et livraison de chaque lot

1. Stabiliser le contrat et les choix de gameplay du lot ; compléter les spécifications techniques et fonctionnelles sans présenter le futur comme livré.
2. Tests hors jeu ciblés dans les suites existantes : idempotence, calendrier, autorité, plafonds, rétrocompatibilité et migrations. Exécuter les contrôles du dépôt ; la compilation Lua ne prouve pas la compatibilité Java.
3. Redémarrage complet en solo puis serveur dédié avec deux clients. Tester l'action nouvelle, un parcours voisin existant, sauvegarde/reprise et reconnexion. Pour I04, validation visuelle humaine ; pour I01/I02, observation de la convergence et mesure de charge ; pour I15, vérification de chaque canal.
4. Vérifier nouvelles clés dans les 8 langues, textes longs et manette pour les fenêtres ; logs en anglais. Mettre à jour guides EN/FR, protocole et suivi seulement selon les preuves acquises.
5. Préparer une livraison distincte pour chaque lot cohérent, sans publier automatiquement. Le numéro de version et les notes ne sont fixés qu'après validation du lot.

Le [suivi](SUIVI.md) porte les états de réalisation. Ce plan est la source unique de conception pour cette sélection ; le catalogue garde les idées, les spécifications décrivent les contrats effectivement retenus.
