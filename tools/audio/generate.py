#!/usr/bin/env python3
"""Fabrique les bruitages lourds et les musiques d'Oathfall par synthèse.

Aucun échantillon extérieur : tout est calculé ici (cloches par partiels
inharmoniques, impacts par balayage de fréquence, nappes par synthèse
additive, réverbération par réponse impulsionnelle). Les fichiers sortent en
OGG dans assets/audio/. Reproductible : le hasard est fixé.

    python3 tools/audio/generate.py [dossier de sortie]
"""
import os, subprocess, sys, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 32000
RNG = np.random.default_rng(1116)
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")


def tt(seconds):
    return np.arange(int(seconds * SR)) / SR


def noise(seconds):
    return RNG.standard_normal(int(seconds * SR))


def lp(x, fc, order=3):
    return signal.sosfilt(signal.butter(order, fc, "low", fs=SR, output="sos"), x)


def hp(x, fc, order=3):
    return signal.sosfilt(signal.butter(order, fc, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def decay(t, rate):
    return np.exp(-t * rate)


def attack(t, seconds):
    return np.clip(t / max(seconds, 1e-4), 0.0, 1.0)


def fit(x, seconds):
    n = int(seconds * SR)
    return x[:n] if len(x) >= n else np.pad(x, (0, n - len(x)))


def reverb(x, rt=1.8, wet=0.3, predelay=0.012):
    """Réverbération : on convolue avec un bruit qui s'éteint."""
    t = tt(rt * 1.2)
    ir = RNG.standard_normal(len(t)) * np.exp(-t / rt * 6.9)
    ir = lp(ir, 5200, 2)
    ir[: int(predelay * SR)] = 0.0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    tail = signal.fftconvolve(x, ir)
    out = np.pad(x, (0, len(tail) - len(x))) * (1.0 - wet) + tail * wet * 2.2
    return out


def norm(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, ms=6):
    n = int(ms / 1000 * SR)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def bell(f0, dur=3.0, brightness=1.0, strike=0.5):
    """Une cloche : partiels inharmoniques qui s'éteignent à des vitesses différentes."""
    t = tt(dur)
    ratios = [0.5, 1.0, 1.19, 1.5, 2.0, 2.51, 3.0, 4.07, 5.43]
    amps = [1.0, 0.95, 0.55, 0.5, 0.42, 0.3, 0.22, 0.14 * brightness, 0.08 * brightness]
    out = np.zeros_like(t)
    for r, a in zip(ratios, amps):
        rate = 1.3 + 1.1 * r * (2.0 / max(dur, 1.0))
        out += a * np.sin(2 * np.pi * f0 * r * t + RNG.uniform(0, 6.28)) * decay(t, rate)
    tick = bp(noise(dur), 1800, 6000) * decay(t, 90.0) * strike
    return out + tick


def save(path, x, stereo=False, q=4):
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    x = np.nan_to_num(x)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as handle:
        wavfile.write(handle.name, SR, pcm)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", handle.name, "-c:a", "libvorbis", "-q:a", str(q), full + ".ogg"], check=True)
    os.unlink(handle.name)
    print("%-26s %5.1f s  pic %.2f" % (path, len(x) / SR if not stereo else x.shape[0] / SR, float(np.max(np.abs(x)))))


# ------------------------------------------------------------------ bruitages
def sfx():
    # Cloches
    save("sfx/bell_toll", norm(fade(reverb(bell(196.0, 4.5), 2.2, 0.28))))
    save("sfx/bell_small", norm(fade(reverb(bell(523.0, 2.0, 1.2), 1.0, 0.2))))
    big = bell(82.0, 3.2, 0.6, 0.9) + 0.6 * lp(noise(3.2), 2500) * decay(tt(3.2), 3.0)
    save("sfx/bell_crash", norm(fade(reverb(big, 1.8, 0.3))))

    # Impacts
    t = tt(0.9)
    f = 38 + 120 * decay(t, 16)
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * decay(t, 6.5)
    thump += 0.55 * lp(noise(0.9), 420) * decay(t, 18)
    save("sfx/impact_heavy", norm(fade(thump)))
    t = tt(0.28)
    flesh = bp(noise(0.28), 350, 2600) * decay(t, 38) + 0.8 * np.sin(2 * np.pi * 95 * t) * decay(t, 28)
    save("sfx/impact_flesh", norm(fade(flesh), 0.8))
    t = tt(0.7)
    clang = sum(a * np.sin(2 * np.pi * 640 * r * t) * decay(t, k) for r, a, k in
                [(1, 1, 8), (2.76, 0.7, 13), (5.4, 0.45, 19), (8.93, 0.3, 26), (11.3, 0.2, 32)])
    clang += bp(noise(0.7), 2500, 9000) * decay(t, 70) * 0.8
    save("sfx/clang", norm(fade(clang), 0.8))

    # Souffles et élans
    def whoosh(dur, lo, hi, peak):
        t = tt(dur)
        a = bp(noise(dur), lo, lo * 3.0)
        b = bp(noise(dur), hi, hi * 2.4)
        hump1 = np.exp(-((t - dur * (peak - 0.18)) / (dur * 0.22)) ** 2)
        hump2 = np.exp(-((t - dur * (peak + 0.12)) / (dur * 0.22)) ** 2)
        return a * hump1 + b * hump2
    save("sfx/whoosh_light", norm(fade(whoosh(0.28, 600, 2400, 0.5)), 0.7))
    save("sfx/whoosh_heavy", norm(fade(whoosh(0.7, 250, 1100, 0.55)), 0.85))

    # Séisme
    t = tt(2.4)
    rumble = lp(noise(2.4), 110) * attack(t, 0.12) * decay(t, 1.6) * 4
    rumble += 0.8 * np.sin(2 * np.pi * 36 * t) * attack(t, 0.08) * decay(t, 1.5)
    rumble += 0.4 * np.sin(2 * np.pi * 54 * t) * attack(t, 0.15) * decay(t, 2.2)
    crack = hp(noise(2.4), 2000) * decay(t, 18) * 0.4
    save("sfx/quake", norm(fade(rumble + crack), 0.9))

    # Repos, soin, boire
    t = tt(2.6)
    chime = sum(a * np.sin(2 * np.pi * 392 * r * t + 0.4 * np.sin(2 * np.pi * 4.5 * t) * 0.05) * attack(t, 0.18) * decay(t, k)
                for r, a, k in [(1, 1.0, 1.4), (1.5, 0.6, 1.8), (2, 0.5, 2.2), (3, 0.25, 3.0)])
    save("sfx/rest_done", norm(fade(reverb(chime, 2.0, 0.35)), 0.8))
    t = tt(1.0)
    sparkle = np.zeros_like(t)
    for i, fr in enumerate([523.25, 659.25, 783.99, 1046.5]):
        start = int(i * 0.08 * SR)
        seg = np.sin(2 * np.pi * fr * t[: len(t) - start]) * decay(t[: len(t) - start], 5.0)
        sparkle[start:] += seg * (0.9 - 0.12 * i)
    save("sfx/heal", norm(fade(reverb(sparkle, 0.9, 0.2)), 0.75))
    t = tt(0.85)
    gulp = np.zeros_like(t)
    for start in (0.02, 0.27, 0.52):
        s = int(start * SR)
        seg_t = t[: int(0.16 * SR)]
        gulp[s:s + len(seg_t)] += lp(noise(0.16), 700) * np.sin(np.pi * seg_t / 0.16) ** 2 * 1.6
        gulp[s:s + len(seg_t)] += np.sin(2 * np.pi * (220 - 400 * seg_t) * seg_t) * np.sin(np.pi * seg_t / 0.16) * 0.35
    save("sfx/drink", norm(fade(gulp), 0.7))

    # Cris, terre, arc, corde, os
    t = tt(1.7)
    glide = 380 + 380 * np.clip(t / 1.2, 0, 1) ** 1.5 + 22 * np.sin(2 * np.pi * 6.0 * t)
    saw = signal.sawtooth(2 * np.pi * np.cumsum(glide) / SR)
    voice = bp(saw, 600, 1000) + 0.7 * bp(saw, 1500, 2100) + 0.25 * bp(noise(1.7), 1000, 3500)
    voice *= attack(t, 0.25) * np.clip((1.7 - t) / 0.5, 0, 1)
    save("sfx/scream", norm(fade(reverb(lp(voice, 4200), 1.6, 0.35)), 0.85))
    t = tt(0.9)
    soil = lp(noise(0.9), 520) * attack(t, 0.1) * decay(t, 2.5) * 3
    for _ in range(14):
        s = int(RNG.uniform(0, 0.7) * SR)
        soil[s:s + 400] += hp(noise(0.0125), 900)[:400] * RNG.uniform(0.2, 0.7)
    save("sfx/dig", norm(fade(soil), 0.8))
    t = tt(0.55)
    n = int(SR / 330)
    buf = RNG.uniform(-1, 1, n)
    string = np.zeros(len(t))
    for i in range(len(t)):
        string[i] = buf[i % n]
        buf[i % n] = 0.4985 * (buf[i % n] + buf[(i + 1) % n])
    string += bp(noise(0.55), 2500, 7000) * decay(t, 120) * 0.6
    save("sfx/twang", norm(fade(string), 0.75))
    t = tt(0.32)
    snap = hp(noise(0.32), 1400) * decay(t, 55) + 0.7 * np.sin(2 * np.pi * 120 * t) * decay(t, 35)
    save("sfx/rope_snap", norm(fade(snap), 0.8))
    t = tt(0.7)
    rattle = np.zeros_like(t)
    for _ in range(13):
        s = int(RNG.uniform(0.0, 0.45) * SR)
        click = bp(noise(0.12), 1800, 5200) * decay(tt(0.12), 55) * RNG.uniform(0.3, 1.0)
        rattle[s:s + len(click)] += click[: len(rattle) - s]
    rattle += 0.9 * np.sin(2 * np.pi * 72 * t) * decay(t, 14) + 0.5 * lp(noise(0.7), 300) * decay(t, 10)
    save("sfx/bones_fall", norm(fade(rattle), 0.8))
    rise = np.zeros(int(1.0 * SR))
    for k in range(18):
        s = int((0.05 + 0.04 * k) * SR) + int(RNG.uniform(0, 0.02) * SR)
        click = bp(noise(0.1), 1500, 5000) * decay(tt(0.1), 60) * (0.2 + 0.05 * k)
        rise[s:s + len(click)] += click[: len(rise) - s]
    rise += 0.5 * lp(noise(1.0), 400) * attack(tt(1.0), 0.9) * decay(tt(1.0), 3)
    save("sfx/bones_rise", norm(fade(rise), 0.75))

    # Interface
    t = tt(0.07)
    save("sfx/ui_click", norm(fade(np.sin(2 * np.pi * 1500 * t) * decay(t, 70) + 0.5 * np.sin(2 * np.pi * 2250 * t) * decay(t, 90), 2), 0.5))
    t = tt(0.4)
    save("sfx/ui_select", norm(fade(reverb(np.sin(2 * np.pi * 880 * t) * decay(t, 9) + 0.6 * np.sin(2 * np.pi * 1320 * t) * decay(t, 11), 0.6, 0.15)), 0.55))
    notes = [220.0, 261.63, 329.63, 440.0]
    out = np.zeros(int(4.0 * SR))
    for i, fr in enumerate(notes):
        b = bell(fr, 2.2, 0.8)
        s = int(i * 0.38 * SR)
        out[s:s + len(b)] += b[: len(out) - s] * (0.7 + 0.1 * i)
    save("sfx/level_done", norm(fade(reverb(out, 2.4, 0.35)), 0.8))
    t = tt(2.2)
    low = bell(98.0, 2.2, 0.4, 0.2) * 0.9 + 0.5 * lp(noise(2.2), 400) * decay(t, 2.2)
    save("sfx/hero_die", norm(fade(reverb(low * decay(t, 0.8), 1.8, 0.3)), 0.8))
    t = tt(7.0)
    crackle = lp(noise(7.0), 700) * 0.06
    for _ in range(260):
        s = int(RNG.uniform(0, 6.8) * SR)
        pop = bp(noise(0.02), 1500, 7000) * decay(tt(0.02), 120) * RNG.uniform(0.2, 1.0)
        crackle[s:s + len(pop)] += pop[: len(crackle) - s]
    crackle = np.roll(crackle, 0)
    save("sfx/fire_loop", norm(fade(crackle, 20), 0.6))


# ------------------------------------------------------------------ musiques
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name, octave):
    semitone = NOTE[name[0]] + (1 if "#" in name else 0) - (1 if "b" in name[1:] else 0) + 12 * (octave + 1) - 69
    return 440.0 * 2 ** (semitone / 12)


def pad(freqs, dur, shimmer=0.4, bright=4):
    """Une nappe : des sinus désaccordés, harmoniques décroissantes, souffle lent."""
    t = tt(dur)
    left = np.zeros_like(t)
    right = np.zeros_like(t)
    for f in freqs:
        for h in range(1, bright + 1):
            for chan, detune in ((left, -1.0), (right, 1.0)):
                ff = f * h * (1.0 + detune * 0.0016 * h)
                lfo = 0.5 + 0.5 * np.sin(2 * np.pi * RNG.uniform(0.05, 0.18) * t + RNG.uniform(0, 6.28))
                chan += (1.0 / h ** 1.2) * np.sin(2 * np.pi * ff * t + RNG.uniform(0, 6.28)) * (1 - shimmer + shimmer * lfo)
    return np.stack([left, right], axis=1) / max(len(freqs), 1)


def swell(n, rise, hold_fade):
    x = np.ones(n)
    a = int(rise * SR)
    b = int(hold_fade * SR)
    x[:a] = np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    x[-b:] = np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    return x


def place(track, mono_or_stereo, at):
    s = int(at * SR)
    if mono_or_stereo.ndim == 1:
        mono_or_stereo = np.stack([mono_or_stereo, mono_or_stereo], axis=1)
    e = min(len(track), s + len(mono_or_stereo))
    track[s:e] += mono_or_stereo[: e - s]


def wind(dur, level=0.5, lo=250, hi=900):
    t = tt(dur)
    x = bp(noise(dur), lo, hi)
    slow = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t + 1.0)) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.031 * t))
    left = x * slow
    right = np.roll(x, 4000) * np.roll(slow, 9000)
    return np.stack([left, right], axis=1) * level


def finish(name, track, length):
    """Boucle sans couture : la queue (réverbération) est ramenée sur le début."""
    total = len(track)
    n = int(length * SR)
    body = track[:n].copy()
    tail = track[n:]
    body[: len(tail)] += tail[: len(body)]
    left = fit_mean(body)
    peak = np.max(np.abs(left)) + 1e-9
    body = body / peak * 0.8
    save("music/" + name, body, stereo=True, q=3)


def fit_mean(x):
    return x[:, 0]


def music():
    L = 80.0
    pad_len = L + 8.0

    def base():
        return np.zeros((int(pad_len * SR), 2))

    def chords(track, prog, level, bright=4, shimmer=0.4):
        seg = L / len(prog)
        for i, chord in enumerate(prog):
            p = pad(chord, seg + 6.0, shimmer, bright)
            p *= swell(len(p), 4.0, 4.0)[:, None]
            place(track, p * level, i * seg - 1.0 if i else 0.0)

    def with_reverb(track, rt=3.0, wet=0.4):
        return np.stack([reverb(track[:, 0], rt, wet)[: len(track)], reverb(track[:, 1], rt, wet)[: len(track)]], axis=1)

    # Titre : sombre, solennel
    tr = base()
    chords(tr, [[hz("D", 2), hz("A", 2), hz("F", 3)], [hz("Bb", 1), hz("F", 2), hz("D", 3)],
                [hz("G", 1), hz("D", 2), hz("Bb", 2)], [hz("A", 1), hz("E", 2), hz("C#", 3)]], 0.5)
    place(tr, wind(pad_len, 0.14), 0.0)
    for k, (note, octave) in enumerate([("D", 4), ("F", 4), ("A", 4), ("D", 5), ("C", 5), ("A", 4), ("F", 4), ("E", 4)]):
        place(tr, bell(hz(note, octave), 4.0, 0.8, 0.3) * 0.22, 6.0 + k * 9.0)
    finish("title", with_reverb(tr, 3.2, 0.35), L)

    # Carte : éthérée, un peu plus claire
    tr = base()
    chords(tr, [[hz("A", 2), hz("E", 3), hz("C", 4)], [hz("F", 2), hz("C", 3), hz("A", 3)],
                [hz("C", 2), hz("G", 2), hz("E", 3)], [hz("G", 2), hz("D", 3), hz("B", 3)]], 0.42, 5, 0.5)
    place(tr, wind(pad_len, 0.1), 0.0)
    scale = [hz(n, o) for n, o in [("A", 4), ("C", 5), ("D", 5), ("E", 5), ("G", 5), ("A", 5)]]
    for k in range(34):
        f = scale[int(RNG.integers(0, len(scale)))]
        t = tt(1.6)
        pluck = np.sin(2 * np.pi * f * t) * decay(t, 3.2) + 0.4 * np.sin(2 * np.pi * 2 * f * t) * decay(t, 5.0)
        place(tr, pluck * 0.09 * RNG.uniform(0.6, 1.0), 2.0 + k * 2.2)
    finish("map", with_reverb(tr, 3.5, 0.45), L)

    # Cimetière : vent, cloche lointaine, froid
    tr = base()
    chords(tr, [[hz("D", 2), hz("A", 2)], [hz("D", 2), hz("Bb", 2)], [hz("D", 2), hz("A", 2), hz("E", 3)], [hz("C", 2), hz("G", 2)]], 0.4, 3, 0.55)
    place(tr, wind(pad_len, 0.38, 200, 1100), 0.0)
    for at in (9.0, 24.0, 33.0, 49.0, 62.0, 71.0):
        place(tr, bell(hz("D", 3) * RNG.choice([1.0, 0.75, 1.5]), 5.0, 0.5, 0.15) * 0.2, at)
    for k in range(7):
        f = hz("A", 6) * RNG.choice([1.0, 1.125, 1.5])
        t = tt(6.0)
        place(tr, np.sin(2 * np.pi * f * t) * attack(t, 2.0) * decay(t, 0.7) * 0.025, 5.0 + k * 10.5)
    finish("cemetery", with_reverb(tr, 4.0, 0.5), L)

    # Souterrain : sourd, gouttes
    tr = base()
    chords(tr, [[hz("B", 1), hz("F#", 2)], [hz("B", 1), hz("C", 2), hz("F#", 2)], [hz("G", 1), hz("D", 2)], [hz("A", 1), hz("E", 2)]], 0.5, 3, 0.6)
    for k in range(36):
        f = RNG.uniform(1500, 3200)
        t = tt(0.5)
        place(tr, np.sin(2 * np.pi * f * t) * decay(t, 14.0) * 0.1, RNG.uniform(1.0, L - 2.0))
    for at in np.arange(4.0, L - 3.0, 8.0):
        t = tt(1.4)
        place(tr, np.sin(2 * np.pi * (46 + 40 * decay(t, 9)) * t) * decay(t, 3.0) * 0.5, at)
    place(tr, wind(pad_len, 0.07, 120, 400), 0.0)
    finish("underground", with_reverb(tr, 4.2, 0.55), L)

    # Refuge : chaleureux
    tr = base()
    chords(tr, [[hz("F", 2), hz("C", 3), hz("A", 3), hz("E", 4)], [hz("D", 2), hz("A", 2), hz("F", 3), hz("C", 4)],
                [hz("Bb", 1), hz("F", 2), hz("D", 3), hz("A", 3)], [hz("C", 2), hz("G", 2), hz("E", 3), hz("Bb", 3)]], 0.4, 5, 0.35)
    penta = [hz(n, o) for n, o in [("F", 4), ("G", 4), ("A", 4), ("C", 5), ("D", 5), ("F", 5)]]
    for k in range(20):
        f = penta[int(RNG.integers(0, len(penta)))]
        t = tt(2.0)
        pluck = np.sin(2 * np.pi * f * t) * decay(t, 2.6) + 0.3 * np.sin(2 * np.pi * 3 * f * t) * decay(t, 6.0)
        place(tr, pluck * 0.1, 3.0 + k * 3.8 + RNG.uniform(-0.3, 0.3))
    finish("refuge", with_reverb(tr, 2.6, 0.35), L)

    # Boss : tension, cœur qui bat
    tr = base()
    chords(tr, [[hz("D", 2), hz("Eb", 2), hz("A", 2)], [hz("D", 2), hz("Eb", 2), hz("Bb", 2)],
                [hz("C", 2), hz("Db", 2), hz("G", 2)], [hz("D", 2), hz("Eb", 2), hz("A", 2), hz("F#", 3)]], 0.55, 6, 0.25)
    beat = 60.0 / 72.0
    t = tt(0.6)
    thump = (np.sin(2 * np.pi * (52 + 70 * decay(t, 20)) * t) * decay(t, 7.0)) * 0.9
    thump += 0.4 * lp(noise(0.6), 300) * decay(t, 25)
    for k in range(int(L / beat)):
        place(tr, thump * (0.75 if k % 2 == 0 else 0.5), k * beat * 1.0)
    low = signal.sawtooth(2 * np.pi * hz("D", 1) * tt(pad_len))
    low = lp(low, 220) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.6 * tt(pad_len))) * 0.18
    place(tr, low, 0.0)
    for at in np.arange(6.0, L - 4.0, 12.0):
        place(tr, bell(hz("D", 2), 5.0, 0.4, 0.3) * 0.25, at)
    finish("boss", with_reverb(tr, 3.0, 0.3), L)


if __name__ == "__main__":
    which = sys.argv[2] if len(sys.argv) > 2 else "all"
    if which in ("all", "sfx"):
        sfx()
    if which in ("all", "music"):
        music()
