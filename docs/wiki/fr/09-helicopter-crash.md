# Hélicoptère abattu (Mayday)

[English](../en/09-helicopter-crash.md) · [Sommaire du guide](Home.md) · Précédent : [FAQ](08-faq.md)

Il arrive que l'hélicoptère de ravitaillement n'atteigne jamais le point de largage. Il tombe en route, la base lance un MAYDAY sur la fréquence militaire, et le lieu du crash devient un endroit à fouiller : pièces de l'épave, enregistreur de vol du pilote, parfois des documents. Les morts y sont déjà.

> Capture à faire : l'épave en feu et la queue au sol, zombies de l'équipage à proximité.

## Pourquoi un hélicoptère tombe

- **Panne** : chaque vol normal a une petite chance de s'écraser (5 % par défaut), davantage pendant un orage (+15 points par défaut).
- **Tirs** (désactivés par défaut) : si le serveur l'autorise, tirer sur un hélicoptère en approche peut l'abattre.
- **Ordre d'un admin** : un admin peut faire crasher le prochain hélicoptère (voir [Administration](06-server-admin.md#hélicoptère-abattu-branche-mayday)).

Les largages admin et les leurres ne tombent jamais par panne ni sous les tirs. Un crash n'a aucun effet sur votre confiance.

## Le MAYDAY

Gardez une radio militaire sur la fréquence militaire : la Logistique annonce « MAYDAY, MAYDAY ! Appareil Logistique en chute près de la grille X / Y. Fouillez le secteur. Contact perdu. » La grille est celle du crash. Par défaut, le matériel commandé est perdu avec l'hélicoptère ; le serveur peut choisir de le livrer sur le lieu du crash.

## Le lieu du crash

- Le fuselage et la queue gisent séparés, brûlés. Selon le serveur : feu et fumée, fumée seule, ou rien.
- Le corps du pilote porte l'**enregistreur de vol** et, si le serveur le permet, une note militaire et un carnet de codes. Parfois un [kit Fulton](07-fulton.md) endommagé.
- Deux membres d'équipage se sont relevés dans leur tenue de vol, et le bruit du crash a attiré une horde.

## Récupérer les pièces

Placez-vous près de l'épave (au rez-de-chaussée), clic droit et **Récupérer les pièces de l'épave** : la fenêtre de mécanique du véhicule s'ouvre. Chaque pièce exige un outil dans l'inventaire et un niveau de compétence, et certaines ne se retirent qu'après une autre :

| Pièce | Outil | Compétence | Après |
|---|---|---|---|
| Avionique | tournevis | Électricité 2 | — |
| Baie radio | tournevis | Électricité 1 | Avionique |
| Compartiment moteur | clé | Mécanique 2 | — |
| Moyeu du rotor | clé | Mécanique 1 | Compartiment moteur |
| Panneaux de fuselage | tournevis | Travail des métaux 1 | Moyeu du rotor (fuselage) |

La queue n'a que des panneaux de fuselage. Chaque pièce donne un **lot récupéré** (avionique, mécanique ou métal) et un peu d'expérience. Clic droit sur un lot pour le déballer : il contient plusieurs objets tirés parmi l'électronique, l'entretien des véhicules ou les matériaux métalliques du jeu, objets de vos mods compris. Le serveur revérifie outils, compétences et distance pour chaque pièce.

Une fois toutes les pièces retirées, l'épave se découpe comme en vanilla (**Démonter l'épave**), avec un masque de soudure. Avant cela, l'option reste grisée.

## L'enregistreur de vol

Rapportez l'enregistreur au [poste de liaison](05-liaison-post.md) de votre station : insérez-le dans la baie de lecture, gardez la radio du poste allumée et alimentée pendant 10 minutes de jeu (la lecture s'interrompt sans courant et reprend ensuite), puis **Transmettre à la base**. Le personnage qui le transmet gagne de la confiance, hors plafond quotidien, une fois par lieu de crash.
