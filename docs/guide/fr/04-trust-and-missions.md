# Confiance et missions

[English](../en/04-trust-and-missions.md) · [Sommaire du guide](README.md) · Précédent : [Formulaire de réquisition](03-requisition-form.md) · Suivant : [Poste de liaison](05-liaison-post.md)

## Votre station

Pour la base, votre groupe est une **station** avec un indicatif, par exemple « Station Kilo-7 ». En multijoueur, une station est une faction ; un joueur sans faction forme une station à lui seul. En solo, vous êtes une station.

La base tient une note de **confiance** pour chaque station, de 0 à 100. Une station neuve part de **25**. Vous ne voyez jamais le chiffre : la base vous le dit en mots, par le ton de ses réponses et sur la console du [poste de liaison](05-liaison-post.md) :

| Confiance | Ce que dit le commandement |
|---|---|
| moins de 25 | Le commandement se méfie de vous |
| 25 à 49 | Le commandement reste prudent |
| 50 à 74 | Le commandement vous fait confiance |
| 75 et plus | Le commandement vous tient en haute estime |

## Ce que change la confiance

- **Attente entre deux largages** : normale à 50, plus longue en dessous (×1,25 au départ, ×1,5 à 0), plus courte au-dessus (×0,6 à 100).
- **Réquisition** : un budget plus gros et les paliers supérieurs (II à 50, III à 75). Voir [Formulaire de réquisition](03-requisition-form.md).
- **Ligne coupée** : sous **15**, la base refuse vos largages pendant **3 jours** de jeu.

## Gagner et perdre de la confiance

| Événement | Confiance |
|---|---|
| Votre station ouvre la première caisse de son largage | +10 |
| Rapport de situation quotidien | +1 |
| Chaque plaque de soldat tombé annoncée | +2 |
| Reconnaissance confirmée la première | +3 |
| Nettoyage : votre station abat le plus de zombies de la horde | +5 |
| Appel de contrôle confirmé à temps | +1 |
| Largage perdu (rien d'ouvert en 48 h) | −10 |
| Largage ouvert d'abord par une autre station | −5 |
| Codes faux répétés (3 dans l'heure) | −2 |

- Tout ce qui n'est pas un largage est limité à **+8 par jour** de jeu.
- Les matricules annoncés depuis votre [poste de liaison](05-liaison-post.md) rapportent 50 % de plus.
- Le serveur peut activer une érosion lente : chaque jour sans échange, la confiance revient d'un point vers 25.

Ces échanges ne demandent **aucun code** : seulement une radio militaire réglée sur la fréquence militaire. Ils sont dans la section **Logistique** de la fenêtre radio (**Options de l'appareil**).

![Section Logistique](../images/radio-logistics-fr.png)

*Rendu hors jeu.*

## Rapport quotidien

**Envoyer un rapport de situation** : une fois par jour de jeu. Un second rapport le même jour est poliment refusé.

## Plaques d'identité

Les zombies militaires laissent les plaques d'identité du jeu, gravées au nom du soldat. **Annoncer les matricules (N)** lit les noms à la base :

- votre propre plaque et les plaques vierges ne comptent pas, ni une plaque portée ou tenue en main ;
- chaque matricule ne compte qu'une fois ; une plaque annoncée est mise de côté ;
- quand la limite du jour est atteinte, la base le dit et vous gardez les autres plaques pour plus tard.

## Missions

De temps en temps, la base donne un ordre à **toutes les stations** sur la fréquence militaire. Les missions sont publiques : toutes les stations qui les entendent peuvent les remplir. Seuls les auditeurs reçoivent le repère sur la carte.

![Missions sur la console et annonce en jeu](../images/ingame-console-missions.png)

*En jeu (version anglaise).*

### Reconnaissance

*« À toutes les stations, ici Logistique. Reconnaissance demandée en grille X / Y. Première station à confirmer sur place dans les 48 heures. »*

Un symbole **œil** bleu marque la grille sur votre carte. Allez-y et appuyez sur **Confirmer la reconnaissance** à **25 cases** au plus du point. La première station gagne +3.

### Nettoyage

*« À toutes les stations, ici Logistique. Horde d'infectés signalée dans un rayon de 40 cases autour de la grille X / Y, environ 30 individus… »*

Un **crâne** rouge marque la zone. La horde apparaît quand le premier joueur approche, hors de sa vue. Vous avez **72 heures** de jeu.

- **Faire le point** demande à la base où en est le nettoyage : zombies de la horde abattus par votre station, et nombre restant.
- Quand **90 %** de la horde est mort, la station qui en a abattu le plus gagne +5. Le feu et les pièges tuent, mais ne créditent personne.

![La horde du nettoyage](../images/ingame-cleanup-horde.png)

![Repères des missions sur la carte](../images/ingame-map-missions.png)

### Appel de contrôle

*« À toutes les stations, ici Logistique. Appel de contrôle. Confirmez la réception sur cette fréquence dans les 4 heures. »*

Appuyez à temps sur **Confirmer réception**. Chaque station qui répond gagne +1.

## Factions (multijoueur)

- Rejoindre une faction : vous prenez sa confiance.
- Quitter une faction : vous gardez sa confiance, plafonnée à 50.
- Une faction nouvelle part de la plus basse confiance de ses fondateurs.
- Renommer une faction garde son indicatif.
