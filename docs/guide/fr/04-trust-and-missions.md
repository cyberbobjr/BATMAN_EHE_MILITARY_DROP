# Confiance et missions

[English](../en/04-trust-and-missions.md) · [Sommaire du guide](README.md) · Précédent : [Formulaire de réquisition](03-requisition-form.md) · Suivant : [Poste de liaison](05-liaison-post.md)

## Breaking change en 0.1.2

**BREAKING CHANGE — 0.1.2 :** Réputation par personnage, indépendante du compte et de la faction. Les anciennes notes collectives ne sont pas transférées : les personnages existants commencent à 25. Les anciens largages ne modifient pas ces nouvelles notes. Progression des missions et plafonds deviennent personnels. Postes et indicatifs restent partagés.

## Votre station

Pour la base, votre groupe est une **station** avec un indicatif, par exemple « Station Kilo-7 ». En multijoueur, une station est une faction ; un joueur sans faction forme une station à lui seul. En solo, vous êtes une station.

La base tient une note de **confiance personnelle** pour chaque personnage, de 0 à 100. Un nouveau personnage part de **25**, même sur le même compte. Sa note reste la même après sauvegarde, reconnexion ou changement de faction. Vous ne voyez jamais le chiffre : la base vous le dit en mots, par le ton de ses réponses et sur la console du [poste de liaison](05-liaison-post.md) :

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

Valeurs par défaut et durées en jeu.

| Cause | Personnage concerné | Gain / perte |
|---|---|---|
| Le demandeur ouvre la première caisse | Demandeur uniquement | +10 |
| Un autre membre de la faction de l’appel ouvre la première caisse | Demandeur uniquement | +5 |
| Un personnage extérieur ouvre la première caisse | Demandeur uniquement | −5 |
| Aucune caisse ouverte dans les 48 h après livraison | Demandeur uniquement | −10 |
| Premier rapport de situation du jour | Émetteur | +1 |
| Chaque plaque nominative valide et inédite | Émetteur | +2 |
| Première reconnaissance confirmée à 25 cases / sous 48 h | Premier à confirmer | +3 |
| Plus de victimes dans la horde de nettoyage, morte à 90 % | Personnage ayant le plus de victimes | +5 |
| Contrôle confirmé sous 4 h, une fois par personnage | Chaque répondant, une fois | +1 |
| 3 codes faux / appels sur mauvaise fréquence en 1 h | Auteur des appels | −2 |
| Érosion optionnelle après 24 h sans contact | Personnage sans contact | −1 / +1 |

- Seule la première caisse de ravitaillement ouverte compte par largage. Un autre ouvreur reçoit **0** ; son appartenance est vérifiée à l’ouverture dans la faction enregistrée lors de l’appel.
- Les gains positifs hors largages partagent un plafond de **+8/jour/personnage**. La note reste entre **0 et 100**.
- Depuis le poste, le bonus de 50 % est arrondi : rapport **+2**, plaque **+3**, reconnaissance **+5**, contrôle **+2**. Ces gains restent plafonnés. Le nettoyage reste à **+5**.
- Trois appels avec code faux ou mauvaise fréquence en moins d’une heure entraînent **−2**, au prochain changement d’heure, au maximum une fois par heure.
- L’érosion est **désactivée par défaut**. Après 24 h sans contact, elle rapproche la note de 25 d’un point par jour (−1 au-dessus, +1 en dessous, 0 à 25).
- Missions expirées, largages forcés par un admin et leurres : variation **0**. Un changement de faction donne aussi **0**. Un nouveau personnage part de **25**.

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

*« À toutes les stations, ici Logistique. Reconnaissance demandée en grille X / Y. Premier survivant à confirmer sur place dans les 48 heures. »*

Un symbole **œil** bleu marque la grille sur votre carte. Allez-y et appuyez sur **Confirmer la reconnaissance** à **25 cases** au plus du point. Le premier personnage gagne +3.

### Nettoyage

*« À toutes les stations, ici Logistique. Horde d'infectés signalée dans un rayon de 40 cases autour de la grille X / Y, environ 30 individus… »*

Un **crâne** rouge marque la zone. La horde apparaît quand le premier joueur approche, hors de sa vue. Vous avez **72 heures** de jeu.

- **Faire le point** demande à la base où en est le nettoyage : zombies de la horde abattus par votre personnage, et nombre restant.
- Quand **90 %** de la horde est mort, le personnage qui en a abattu le plus gagne +5. Le feu et les pièges tuent, mais ne créditent personne.


Symboles des missions sur la carte : <img src="../images/map-symbol-recon.png" width="32" alt="Œil bleu"> reconnaissance, <img src="../images/map-symbol-clearance.png" width="32" alt="Tête de mort rouge"> nettoyage (voir [Symboles sur la carte](02-calling-a-drop.md#symboles-sur-la-carte)).

### Appel de contrôle

*« À toutes les stations, ici Logistique. Appel de contrôle. Confirmez la réception sur cette fréquence dans les 4 heures. »*

Appuyez à temps sur **Confirmer réception**. Chaque personnage qui répond gagne +1.

## Personnages et factions

- La réputation appartient au personnage, pas à son compte ni à sa faction.
- Rejoindre, quitter, créer ou dissoudre une faction ne transfère aucune confiance.
- Un nouveau personnage repart à 25 ; les anciens largages et sanctions restent rattachés au précédent.
- Les factions conservent leur indicatif et leur poste de liaison partagé. La console affiche la confiance du personnage qui l'utilise.
- Mise à jour depuis l'ancien système : les notes collectives sont conservées dans les anciennes données, sans transfert ; chaque personnage commence à 25. Les largages antérieurs ne modifient pas les nouvelles notes.
