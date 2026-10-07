"""Passage d'avion du Fulton (FULTON-06) à partir de l'ATR 72 de Freesound 315660 (CC0).

    python make_fulton_sound.py

Source : originals/315660_2506497-lq.mp3 (aperçu Freesound, MP3 24 kHz stéréo, 78,7 s).
Analyse (2026-10-07) : passage au plus près à 44,1 s (niveau maximal, note des hélices
qui descend de 135 Hz à l'approche à 110 Hz à l'éloignement : effet Doppler).
L'extrait est calé pour que ce pic tombe à PEAK_AT secondes : le ballon monte 3 s, puis
l'avion l'accroche pendant 1,5 s (MilitaryDrop_FultonPrototypeFlight.lua) ; le son
démarre avec le vol. Mono pour le rendu 3D sur un émetteur, passe-haut à 40 Hz,
pic normalisé à -1 dBFS, fondus d'entrée et de sortie.
"""

import subprocess
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "originals" / "315660_2506497-lq.mp3"
TARGET = HERE.parents[1] / "Contents/mods/batman_MilitaryDrop/common/media/sound/MilitaryDrop/MilitaryDrop_FultonFlyby.ogg"
SR = 44100
SOURCE_PEAK = 44.1   # passage au plus près dans l'enregistrement
PEAK_AT = 3.75       # milieu de la phase d'accroche, depuis le début du vol
END = 58.0           # avion presque inaudible (environ -29 dB)
FADE_IN, FADE_OUT = 1.5, 4.0


def load(start, duration):
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start), "-t", str(duration), "-i", str(SOURCE),
           "-ac", "1", "-ar", str(SR), "-af", "highpass=f=40", "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, dtype=np.float32).copy()


def main():
    start = SOURCE_PEAK - PEAK_AT
    x = load(start, END - start)
    a, b = int(FADE_IN * SR), int(FADE_OUT * SR)
    x[:a] *= np.linspace(0, 1, a) ** 2
    x[-b:] *= np.linspace(1, 0, b) ** 2
    x *= 10 ** (-1 / 20) / max(1e-9, float(np.max(np.abs(x))))
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "4", str(TARGET)], input=x.tobytes(), check=True)
    w = int(0.2 * SR)
    peak = max(range(0, len(x) - w, w // 2), key=lambda i: float(np.mean(x[i:i + w] ** 2))) / SR
    print(f"{TARGET.name}: {len(x) / SR:.2f} s, pic de passage à {peak:.2f} s, {TARGET.stat().st_size} octets")


if __name__ == "__main__":
    main()
