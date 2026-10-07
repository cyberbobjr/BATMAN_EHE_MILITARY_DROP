# Extraction Fulton

[English](../en/08-fulton.md) · [Sommaire](README.md) · Précédent : [FAQ](07-faq.md)

Le commandement veut du renseignement et du matériel venus de la zone infectée. Rangez-les dans un **kit d'extraction Fulton**, gonflez son ballon à l'hélium, et un avion l'accroche au passage. Le commandement vous paie en [confiance](04-trust-and-missions.md).

> En développement (branche prototype) : pas encore dans une version publiée.

## Obtenir un kit

Le kit est à usage unique : il part avec le ballon.

**Le fabriquer en trois étapes**

| Recette | Consomme | Conserve | Compétence |
|---|---|---|---|
| Coudre un ballon Fulton (donne l'enveloppe de ballon, une pièce) | 1 bâche, 6 utilisations de fil, 2 de colle | aiguille, ciseaux | Couture 3 |
| Fabriquer un sac à harnais Fulton | 1 sac de sable **vide**, 1 corde, 2 utilisations de ruban adhésif | ciseaux | — |
| Assembler un kit d'extraction Fulton | ballon plié, sac à harnais, 3 utilisations de fil de fer | pince | — |

**Ou réparer un kit endommagé**

Un kit endommagé est une trouvaille rare : réserves de l'armée, pilote d'un hélicoptère abattu, ou caisse larguée sans commande. Réparez-le avec 4 utilisations de fil, 2 de ruban adhésif et 2 de fil de fer (aiguille et pince conservées, Couture 1).

**L'hélium**

Une **bouteille d'hélium** permet quatre gonflages. Cherchez dans les magasins de cadeaux et de jouets, et dans les réserves de l'armée. La bouteille vide est conservée ; découpez-la au chalumeau (masque de soudure conservé) pour 4 petites tôles et 2 morceaux d'acier.

## Envoyer un Fulton

1. **Demandez un passage.** Avec une radio militaire sur la fréquence militaire (en main, ou posée à 2 cases au plus), ouvrez la section **Logistique** de la radio et choisissez **Demander un passage Fulton**. Vous disposez alors de **30 minutes** de jeu. Redemander rappelle le temps restant. Laisser passer le créneau ne coûte rien.
2. **Posez le kit au sol, dehors**, à ciel ouvert, sans arbre sur sa case. Pas par orage ni grand vent, ni dans une zone non-PvP ou un refuge.
3. **Remplissez-le** comme n'importe quel sac au sol (capacité 10). Seuls les objets posés directement dans le kit comptent ; un sac rangé dans le kit est perdu. Le ballon est déjà dans le kit : il n'y a rien à accrocher.
4. Clic droit sur le kit au sol : **Gonfler et lâcher le Fulton** (il faut une bouteille d'hélium dans l'inventaire). L'option est grisée, avec le motif, s'il manque quelque chose ; dans l'inventaire, elle vous dit de poser le kit au sol. Une confirmation liste ce qui intéresse le commandement et ce qu'il ignorera, et vous prévient si le crédit du jour est épuisé.
5. Le personnage va jusqu'au kit et le gonfle : une dizaine de secondes, et du bruit qui attire les morts. Le gonflage s'arrête si vous bougez ou êtes attaqué.
6. Le ballon monte, l'avion passe et l'emporte. Le commandement confirme combien d'objets il a pu exploiter.

**Tout le monde l'entend.** Le passage est bruyant, et la chaîne militaire annonce le secteur de 50 cases à toutes les stations. Choisissez votre endroit.

## Ce que paie le commandement

Le chiffre n'est jamais affiché en jeu. Les valeurs ci-dessous sont celles par défaut (option serveur `FultonValue`).

| Envoi | Confiance |
|---|---|
| Carte d'identité, passeport, badge de journaliste ou badge au nom de quelqu'un d'autre | +3 |
| Paperasse, document | +1 |
| Carte-cachette | +4 |
| Combinaison hazmat | +6 |
| Masque à gaz ou NRBC (filtre posé ou non), SCBA | +2 |
| Filtre de masque à gaz | +1 |

Tout le reste part avec le ballon et est perdu : votre propre carte, une carte volée ou vierge, les cartes ordinaires, les respirateurs, les masques bricolés, les masques sans filtre.

Ces gains partagent le **plafond quotidien** (10 par défaut) avec les rapports, les plaques et les missions. Ce qui dépasse le plafond est perdu : la confirmation vous prévient.

**Avec le mod Zombie Virus Vaccine** : échantillons de sang +1, liquide cérébral +2 / +3 / +4 selon la qualité, cerveaux +3 (ni pourris ni brûlés), vaccins +5 / +7 / +10. **Le remède vaut +25, hors plafond quotidien.**

## Multijoueur

Le serveur revérifie tout au lâcher : kit au sol à 2 cases au plus, bouteille dans l'inventaire principal, créneau ouvert, lieu, météo, zones protégées. C'est lui aussi qui paie et retire le kit pour tout le monde. Chaque joueur proche du point de lâcher voit le ballon et entend l'avion. Le vol va à son terme même si vous mourez ou vous déconnectez.
