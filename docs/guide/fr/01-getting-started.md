# Démarrer

[English](../en/01-getting-started.md) · [Sommaire du guide](README.md) · Suivant : [Appeler un largage](02-calling-a-drop.md)

Military Drop permet d'appeler l'armée par radio pour obtenir un largage de ravitaillement. Un hélicoptère passe, largue une caisse loin de vous et annonce le point de chute à tous ceux qui écoutent. Le bruit attire les morts.

![Une caisse de ravitaillement entourée de zombies](../images/ingame-decoy-crate.png)

## Installation

1. Abonnez-vous à **Military Drop** sur le Workshop Steam (Build 42.21).
2. Dans la liste des mods du jeu, activez **Military Drop** (identifiant `batman_MilitaryDrop`).
3. Lancez une partie. Les réglages sont sur la page **Military Drop** des options du bac à sable.

Aucun autre mod n'est nécessaire. Vous pouvez ajouter le mod à une partie en cours : les notes et carnets militaires apparaissent sur les zombies tués après son activation.

## Ce qu'il vous faut

- **Une radio militaire.** Elles seules peuvent appeler la base :
  - Talkie-Walkie de l'Armée américaine (en main, à la ceinture, dans un sac ou posé au sol) ;
  - Poste radio nomade de l'Armée américaine ;
  - Radioamateur de l'Armée américaine (posé). Il peut aussi devenir votre [poste de liaison](05-liaison-post.md).
- **La fréquence militaire.** Elle est écrite sur les notes de service portées par les zombies militaires et policiers. Elle change à chaque partie.
- **Le code d'authentification**, qui change chaque lundi. Par défaut, une station de chiffres le diffuse chiffré et un carnet de codes militaire permet de le déchiffrer. Voir [Appeler un largage](02-calling-a-drop.md).
- **Des piles**, et de quoi affronter la horde qui accompagne chaque largage.

## Votre premier largage, en bref

1. Tuez des zombies militaires ou policiers jusqu'à trouver une **Note de service militaire**. Clic droit, **Inspecter** : relevez la fréquence entourée et celle de la station de chiffres.
2. Écoutez la station de chiffres, trouvez un **Carnet de codes militaire** et déchiffrez le code de la semaine.
3. Réglez votre radio militaire sur la fréquence militaire. Clic droit, **Options de l'appareil**, ouvrez la section **Logistique**, tapez le code et appuyez sur **Demander un largage**.
4. Remplissez le [formulaire de réquisition](03-requisition-form.md) et transmettez-le.
5. Rejoignez la grille annoncée, abattez la horde, ouvrez la caisse.

Ensuite, gardez la base de votre côté : la [confiance et les missions](04-trust-and-missions.md) raccourcissent l'attente entre deux largages et ouvrent de meilleures fournitures.

## Solo et multijoueur

Le mod fonctionne dans les deux modes. En multijoueur, le serveur décide de tout :

- l'attente entre deux largages est commune à **tout le serveur** (une semaine de jeu par défaut) ;
- chaque faction est une **station**, avec son indicatif et sa confiance (un joueur sans faction forme une station à lui seul) ;
- pour émettre, votre personnage prend automatiquement le talkie-walkie en main ;
- les coordonnées du largage sont diffusées à tous ceux qui écoutent la fréquence. D'autres joueurs peuvent atteindre votre caisse avant vous.

## Compatibilité

- **HEF - Helicopter Event Framework** : conçu pour cohabiter. L'hélicoptère de ravitaillement attend tant qu'un événement HEF est actif près de sa cible, et le mod n'utilise jamais 112,2 MHz (réservée par HEF).
- **Signal Smoke** (facultatif) : quand il est actif, une fumée verte signale la caisse pendant 60 minutes de jeu.
- **Mods d'objets et d'armes** : le contenu des caisses vient des tables de butin du jeu, y compris les objets ajoutés par vos autres mods.
- **Expanded Helicopter Events** n'est pas nécessaire. Military Drop est une réécriture autonome du mod Build 41 « Drop Military Cargo ».
