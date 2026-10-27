"""Original synthetic jammer sounds. Requires ffmpeg on PATH; no third-party samples."""
import math
from pathlib import Path
import random
import shutil
import struct
import subprocess
import tempfile
import wave

MEDIA = Path(__file__).resolve().parents[2] / 'Contents/mods/batman_MilitaryDropJammer/common/media/sound'
rate = 22050
ffmpeg = shutil.which('ffmpeg')
if not ffmpeg:
    raise SystemExit('ffmpeg is required')
MEDIA.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='mdj-sounds-') as temp:
    for name, duration in [('MDJ_Static', 0.32), ('MDJ_Hum', 1.0)]:
        rng = random.Random(93)
        samples = []
        for index in range(round(rate * duration)):
            t = index / rate
            if name == 'MDJ_Static':
                envelope = min(1, t / 0.025, (duration - t) / 0.04)
                value = rng.uniform(-0.3, 0.3) * envelope
            else:
                value = 0.18 * math.sin(2 * math.pi * 90 * t) + 0.04 * math.sin(2 * math.pi * 180 * t)
            samples.append(struct.pack('<h', round(value * 32767)))
        source = Path(temp) / (name + '.wav')
        with wave.open(str(source), 'wb') as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(rate)
            audio.writeframes(b''.join(samples))
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(source),
            '-c:a', 'libvorbis', '-q:a', '4', str(MEDIA / (name + '.ogg'))], check=True)
