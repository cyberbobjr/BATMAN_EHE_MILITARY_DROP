# Brouilleur radio RJ-93

[English](../en/10-radio-jammer.md) · [Sommaire](Home.md) · [Administration](06-server-admin.md)

Fonction de la **0.8.0 en essai local, non publiée**. Le RJ-93 appartient au sous-mod **facultatif** `batman_MilitaryDropJammer`, fourni dans le même projet. Activez-le en plus de `batman_MilitaryDrop` si vous voulez du brouillage ; le principal seul n'en ajoute pas. Sur serveur, ajoutez cet ID à `Mods=` ; aucun autre abonnement Workshop.

## Fabrication

La recette **Fabriquer un brouilleur RJ-93**, catégorie Électricité, exige **Électricité 3**.

| Élément | Quantité | Usage |
|---|---|---|
| Déchets électroniques | 20 | Consommés |
| Ferraille (`Base.ScrapMetal`) | 4 | Consommée |
| Fil électrique (`Base.ElectricWire`) | 2 | Consommé |
| Ruban adhésif (`Base.DuctTape`) | 2 | Consommé |
| Tournevis en état | 1 | Conservé |

Le résultat est un `MilitaryDropJammer.RJ93`. La pile n'est pas fournie par la recette.

## Insérer la pile et allumer

1. Posez le RJ-93 **au sol** ; un appareil transporté n'émet pas.
2. Restez près de lui, au même étage, puis clic droit → **Contrôler le brouilleur**.
3. Choisissez une pile compatible de votre inventaire et **Insérer une pile**.
4. Vérifiez sa charge et utilisez **Allumer**. La fenêtre affiche l'état, la charge restante et la portée.
5. **Éteindre** interrompt l'émission sans retirer la pile. **Retirer la pile** la rend avec sa charge restante et arrête le brouillage. Fermer la fenêtre laisse l'appareil fonctionner ; le ramasser arrête son émission.

À charge pleine, la pile dure **24 heures de jeu** par défaut ; une pile usagée dure moins longtemps. Une pile vide ne peut pas alimenter l'émission. Charge et état sont conservés lors des sauvegardes/reconnexions. Les actions simultanées de plusieurs joueurs sont arbitrées par le serveur : une seule pile peut être insérée ou rendue.

## Comprendre le brouillage

Le rayon est de **100 cases** par défaut. Il concerne aussi le poseur, ses alliés et les étages supérieurs : pas de filtre de faction ni d'étage. Il bloque les nouvelles demandes et transmissions **de Military Drop**, pas toutes les radios du jeu. Les annonces publiques de la base restent audibles ; les vols déjà partis continuent.

Le joueur affecté reçoit un grésillement, le message **« Liaison indisponible : brouillage radio détecté »** et le statut **Liaison brouillée**. Éloignez-vous, éteignez l'appareil ou retirez sa pile. Un appel bloqué par le brouillage ne consomme pas de crédit et n'ajoute ni attente ni sanction de confiance. La fin du brouillage est signalée.

Les options de la page **Brouilleur radio RJ-93** (`MilitaryDropJammer`) règlent l'activation, la portée et l'autonomie : voir [Administration](06-server-admin.md). En solo sans cette mécanique, laissez simplement le sous-mod désactivé.
