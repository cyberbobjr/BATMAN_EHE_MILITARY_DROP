# Sons de la baie de lecture (SRC-10) — sources et licences

Trois sons courts, découpés et mixés par `make_bay_sounds.py` (ffmpeg, numpy) à
partir d'enregistrements libres de Wikimedia Commons. Aucun n'impose de clause non
commerciale ; tous peuvent être redistribués dans le mod.

| Fichier du mod | Usage | Source | Auteur | Licence |
|---|---|---|---|---|
| `MilitaryDrop_BayInsert.ogg` | Enregistreur inséré dans la baie (déclic du lecteur, 0,1 à 1,2 s) | [Car stereo tapedeck.ogg](https://commons.wikimedia.org/wiki/File:Car_stereo_tapedeck.ogg) | stephan | Domaine public |
| `MilitaryDrop_BayRead.ogg` | Boucle pendant la lecture (porteuse modem 300 bauds, 10 à 16 s, filtrée 350-2800 Hz, raccord fondu de 0,5 s) | [Bell103-300Baud-Psalm118Jpg.ogg](https://commons.wikimedia.org/wiki/File:Bell103-300Baud-Psalm118Jpg.ogg) | HamRadioOperator73 | CC0 1.0 |
| `MilitaryDrop_BayDone.ogg` | Fin de lecture (double déclic d'interrupteur) | [Clickick switch.ogg](https://commons.wikimedia.org/wiki/File:Clickick_switch.ogg) | stephan | Domaine public |

`originals/` garde les deux fichiers courts d'origine. L'original de la porteuse
(83 Mo, 4 h 30) n'est pas conservé : `make_bay_sounds.py` en lit les 2 premiers Mo
(`curl -r 0-2000000`), suffisants pour l'extrait.

Recréer les sons : placer `tapedeck.ogg`, `clickick.ogg` et `bell103_part.ogg` à
côté du script, puis `python make_bay_sounds.py`.

## Passage d'avion du Fulton (FULTON-06)

| Fichier du mod | Usage | Source | Auteur | Licence |
|---|---|---|---|---|
| `MilitaryDrop_FultonFlyby.ogg` | Avion qui accroche le ballon (17,65 s, mono, extrait de 40,35 à 58 s, pic du passage à 3,8 s) | [ATR 72 (AT72) plane flyby at 300 m altitude landing towards airport](https://freesound.org/people/Hoscalegeek/sounds/315660/) | Hoscalegeek | CC0 1.0 |

`originals/315660_2506497-lq.mp3` est l'aperçu Freesound (MP3 24 kHz stéréo, 78,7 s), copié par l'utilisateur le 2026-10-07. Recréer le son : `python make_fulton_sound.py` (ffmpeg, numpy).
