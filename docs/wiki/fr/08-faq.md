# FAQ

[English](../en/08-faq.md) · [Sommaire du guide](Home.md) · Précédent : [Extraction Fulton](07-fulton.md) · Suivant : [Hélicoptère abattu](09-helicopter-crash.md)

**Personne ne répond, seulement des grésillements.**
La fréquence ou le code est faux, et la base ne dit pas lequel. Vérifiez la fréquence entourée sur une note, redéchiffrez le code de la semaine (il change chaque lundi à 00:00), et assurez-vous d'utiliser une radio militaire. Après 3 codes faux dans la journée, la base se tait jusqu'au lendemain.

**Je ne trouve aucune note.**
Les notes sont portées par les zombies militaires et policiers, environ 1 sur 50 par défaut. Cherchez du côté des barrages, des commissariats et des sites de l'armée. L'administrateur peut augmenter la fréquence ou choisir un code écrit en clair.

**La note ne donne pas de code.**
Avec les réglages par défaut, le code est diffusé chiffré par la station de chiffres indiquée sur la note, et se déchiffre avec un carnet. Voir [Appeler un largage](02-calling-a-drop.md).

**Combien de temps entre deux largages ?**
Une semaine de jeu par défaut, pour tout le serveur, plus ou moins selon votre confiance. La base vous dit combien d'heures il reste.

**Ma radio est grisée, ou la section Logistique n'apparaît pas.**
Seules les radios militaires ont cette section (talkie-walkie, poste radio nomade et radioamateur de l'Armée américaine). Elle doit être allumée. Un radioamateur de l'armée posé n'affiche que le bouton **Poste de liaison**.

**J'ai manqué l'annonce. Où est la caisse ?**
Le repère n'apparaît que sur la carte des joueurs dont la radio était **allumée et réglée sur la fréquence militaire** à ce moment. C'est le piège le plus courant : enregistrez la fréquence avec **Ajouter un préréglage** et gardez une radio allumée. Restez à l'écoute : la base répète la grille toutes les 6 heures par défaut, jusqu'à ce qu'une caisse de ravitaillement soit ouverte (48 heures au plus). Si vous l'avez manquée, demandez à quelqu'un qui écoutait, ou lisez le journal de votre [poste de liaison](05-liaison-post.md) s'il était allumé.

**Il n'y a pas de symbole de reconnaissance ou de nettoyage sur ma carte.**
Même règle que pour les largages : le symbole n'apparaît que si votre radio entend l'annonce. Les ordres ouverts sont répétés toutes les 6 heures par défaut, et **Confirmer la reconnaissance** trop loin (ou **Faire le point** avant que la horde soit repérée) vous donne aussi la grille et le symbole.

**Je suis à la grille, mais il n'y a pas de caisse.**
La caisse est posée quand quelqu'un arrive et que la zone est chargée, jusqu'à 30 cases du point annoncé. Cherchez autour.

**Mon formulaire s'est fermé ou a expiré.**
Le formulaire est valable 5 minutes réelles. Rien n'a été dépensé : rappelez.

**D'autres joueurs peuvent-ils voler mon largage ?**
Oui. Tous ceux qui écoutent la fréquence militaire entendent la grille. Si un autre membre de la faction de l'appel ouvre votre caisse en premier, votre personnage gagne 5 de confiance. Si l'ouvreur est extérieur, votre personnage perd 5. L'ouvreur ne gagne rien.

**Les autres joueurs savent-ils que c'est un leurre ?**
Non. Un leurre est identique à un vrai largage jusqu'à l'ouverture du coffre.

**Le mod marche-t-il avec les mods d'armes et d'objets ?**
Oui. Les caisses puisent dans les tables de butin du jeu, objets de vos mods compris.

**Faut-il Expanded Helicopter Events ?**
Non. Military Drop est une réécriture autonome : il exige seulement Belt Walkie-Talkie (avec TooltipLib) et Signal Smoke. HEF est un compagnon facultatif.

**Où signaler un bug ?**
Sur la page du Workshop Steam ou dans les [issues GitHub](https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/issues). Joignez `Zomboid/console.txt` et, si possible, activez l'option **Journal de débogage** du bac à sable.

## Pourquoi la base refuse-t-elle mon appel en 0.8.0 ?

- **Relais en panne** : rejoindre l'armoire annoncée avec des déchets électroniques ; aucun générateur requis. La liaison de secours revient après 72 h de jeu.
- **Liaison brouillée** : le sous-mod RJ-93 est actif. Éloignez-vous du brouilleur, éteignez-le ou retirez sa pile. Recevoir une annonce ne signifie pas pouvoir transmettre.
- **Attente, code ou confiance** : suivez la raison donnée par la base ; réparer un relais ne supprime pas ces règles.

Pour jouer sans brouillage, laissez `batman_MilitaryDropJammer` désactivé. [Guide du RJ-93](10-radio-jammer.md).
