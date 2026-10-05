import subprocess, numpy as np
SR = 44100
def load(path, start, dur, filters=None):
    af = ["-af", filters] if filters else []
    cmd = ["ffmpeg","-v","error","-ss",str(start),"-t",str(dur),"-i",path,"-ac","1","-ar",str(SR)]+af+["-f","f32le","-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, dtype=np.float32).copy()
def save(x, path):
    subprocess.run(["ffmpeg","-v","error","-y","-f","f32le","-ar",str(SR),"-ac","1","-i","-","-c:a","libvorbis","-q:a","5",path],
                   input=x.astype(np.float32).tobytes(), check=True)
def fade(x, fin, fout):
    a, b = int(fin*SR), int(fout*SR)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x
def peak(x, db):
    return x * (10**(db/20) / max(1e-9, np.max(np.abs(x))))
# 1. Insertion : déclic du lecteur de cassette.
ins = fade(load("tapedeck.ogg", 0.1, 1.1), 0.01, 0.25)
save(peak(ins, -3), "MilitaryDrop_BayInsert.ogg")
# 2. Lecture : porteuse modem Bell 103, filtrée haut-parleur, bouclée sans couture.
xf = 0.5
seg = load("bell103_part.ogg", 10, 6 + xf, "highpass=f=350,lowpass=f=2800")
n, m = int(6*SR), int(xf*SR)
loop = seg[:n].copy()
w = np.linspace(0, 1, m)
loop[:m] = seg[n:n+m]*(1-w) + seg[:m]*w   # la fin du segment se fond dans son début
rms_target = 10**(-20/20)
loop = loop * (rms_target / np.sqrt(np.mean(loop**2)))
loop = np.clip(loop, -0.98, 0.98)
save(loop, "MilitaryDrop_BayRead.ogg")
# 3. Fin : double déclic d'interrupteur.
done = fade(load("clickick.ogg", 0, 0.68), 0.005, 0.15)
save(peak(done, -3), "MilitaryDrop_BayDone.ogg")
for f in ["MilitaryDrop_BayInsert.ogg","MilitaryDrop_BayRead.ogg","MilitaryDrop_BayDone.ogg"]:
    print(f, subprocess.run(["ffprobe","-v","error","-show_entries","format=duration,size","-of","compact",f],capture_output=True,text=True).stdout.strip())
# Raccord de la boucle : écart entre dernier et premier échantillon.
y = load("MilitaryDrop_BayRead.ogg", 0, 7)
print("loop seam jump", abs(float(y[-1]-y[0])), "rms dB", 20*np.log10(np.sqrt(np.mean(y**2))))
