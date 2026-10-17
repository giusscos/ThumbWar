#!/usr/bin/env python3
"""Synthesizes ThumbWar's cartoon sound effects into ThumbWar/Sounds/*.wav.

Pure standard library, so it runs anywhere:
    python3 Tools/make_sounds.py

Every sound is a small recipe of sine sweeps, filtered noise and envelopes.
Tweak a recipe, re-run, rebuild the app.
"""

import array
import math
import os
import random
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "ThumbWar", "Sounds")
random.seed(7)


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(*tracks, offsets=None):
    offsets = offsets or [0] * len(tracks)
    n = max(int(o * RATE) + len(t) for t, o in zip(tracks, offsets))
    out = [0.0] * n
    for t, o in zip(tracks, offsets):
        start = int(o * RATE)
        for i, v in enumerate(t):
            out[start + i] += v
    return out


def tone(seconds, freq, harmonics=((1, 1.0),), attack=0.005, decay=None, vibrato=(0, 0), gain=1.0):
    """Sine (plus harmonics) with a frequency function `freq(t)` or a constant."""
    n = int(seconds * RATE)
    f = freq if callable(freq) else (lambda t, c=freq: c)
    vib_rate, vib_depth = vibrato
    decay = decay if decay is not None else seconds / 4
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        hz = f(t) * (1 + vib_depth * math.sin(2 * math.pi * vib_rate * t))
        phase += 2 * math.pi * hz / RATE
        env = min(1.0, t / attack) * math.exp(-t / decay) if decay > 0 else min(1.0, t / attack)
        env *= min(1.0, (seconds - t) / 0.01)  # click-free tail
        out.append(gain * env * sum(a * math.sin(phase * k) for k, a in harmonics))
    return out


def noise(seconds, cutoff=lambda t: 2000, attack=0.002, decay=0.05, gain=1.0):
    """White noise through a one-pole low-pass whose cutoff can sweep."""
    n = int(seconds * RATE)
    out, y = [], 0.0
    for i in range(n):
        t = i / RATE
        a = 1 - math.exp(-2 * math.pi * cutoff(t) / RATE)
        y += a * (random.uniform(-1, 1) - y)
        env = min(1.0, t / attack) * math.exp(-t / decay)
        env *= min(1.0, (seconds - t) / 0.01)
        out.append(gain * env * y)
    return out


def sweep(f0, f1, seconds, curve=1.0):
    return lambda t: f0 + (f1 - f0) * min(1.0, t / seconds) ** curve


def bell(freq, seconds=0.4, gain=1.0):
    return tone(seconds, freq, harmonics=((1, 1), (2, 0.25), (3, 0.12)), decay=seconds / 3, gain=gain)


def save(name, samples, peak=0.85):
    top = max(1e-9, max(abs(s) for s in samples))
    data = array.array("h", (int(s / top * peak * 32767) for s in samples))
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"  {name}.wav  {len(samples) / RATE:.2f}s")


# --- Countdown: three puffy "boing-pops" climbing C-E-G, then a big chord ----

def chant_pop(base):
    body = tone(0.32, lambda t: base * (0.75 + 0.25 * min(1, t / 0.04)) * (1 + 0.04 * math.sin(t * 60)),
                harmonics=((1, 1), (2, 0.35), (3, 0.1)), attack=0.004, decay=0.12)
    click = noise(0.03, cutoff=lambda t: 5000, decay=0.006, gain=0.4)
    return mix(body, click)


def chant_go():
    notes = [523.25, 659.25, 783.99, 1046.5]
    chord = mix(*[tone(1.0, f, harmonics=((1, 1), (2, 0.5), (3, 0.3), (4, 0.15)), attack=0.01,
                       decay=0.45, vibrato=(6, 0.004), gain=0.5) for f in notes])
    thump = tone(0.25, sweep(160, 50, 0.2), decay=0.08, gain=1.2)
    whoosh = noise(0.35, cutoff=sweep(400, 6000, 0.3), attack=0.2, decay=0.2, gain=0.6)
    return mix(whoosh, chord, thump, offsets=[0, 0.15, 0.15])


# --- Fight ---------------------------------------------------------------------

def slam():
    swoosh = noise(0.16, cutoff=sweep(5000, 600, 0.16), attack=0.03, decay=0.08)
    low = tone(0.16, sweep(300, 120, 0.16), decay=0.06, gain=0.4)
    return mix(swoosh, low)


def jump():
    # Springy "hup!" going up, then a short swish as it drops.
    hup = tone(0.18, sweep(300, 900, 0.14, curve=0.6), harmonics=((1, 1), (2, 0.35)), decay=0.09)
    swish = noise(0.14, cutoff=sweep(6000, 900, 0.14), attack=0.02, decay=0.06, gain=0.5)
    return mix(hup, swish, offsets=[0, 0.12])


def land():
    thud = tone(0.22, sweep(150, 55, 0.12), decay=0.07, gain=1.0)
    soft = noise(0.08, cutoff=lambda t: 700, decay=0.02, gain=0.6)
    return mix(thud, soft)


def bump():
    # "Doiing": a rubbery wobble that settles.
    return tone(0.4, lambda t: 210 * (1 + 0.25 * math.exp(-t * 9) * math.sin(t * 2 * math.pi * 18)),
                harmonics=((1, 1), (2, 0.3)), decay=0.14)


def pin():
    hit = tone(0.4, sweep(120, 40, 0.3), decay=0.12, gain=1.2)
    crunch = noise(0.15, cutoff=lambda t: 2500, decay=0.04, gain=0.7)
    squish = tone(0.35, sweep(700, 180, 0.3, curve=0.6), harmonics=((1, 1), (2, 0.4)),
                  vibrato=(30, 0.05), decay=0.15, gain=0.5)
    return mix(hit, crunch, squish)


def tick(freq):
    return tone(0.09, freq, harmonics=((1, 1), (1.5, 0.5)), attack=0.001, decay=0.02)


def mash():
    return tone(0.06, sweep(380, 950, 0.05), attack=0.001, decay=0.025)


def escape():
    up = tone(0.3, sweep(250, 1300, 0.25, curve=0.7), harmonics=((1, 1), (2, 0.3)), decay=0.12)
    air = noise(0.25, cutoff=sweep(800, 7000, 0.25), attack=0.05, decay=0.1, gain=0.4)
    return mix(up, air)


def tired():
    # Deflating balloon.
    sigh = tone(0.5, sweep(520, 140, 0.5, curve=0.7), harmonics=((1, 1), (2, 0.4)),
                vibrato=(22, 0.04), decay=0.25, gain=0.7)
    air = noise(0.45, cutoff=lambda t: 1800, attack=0.02, decay=0.2, gain=0.5)
    return mix(sigh, air)


# --- Results ---------------------------------------------------------------------

def point():
    notes = [659.25, 783.99, 1046.5]
    return mix(*[bell(f, 0.35) for f in notes], offsets=[0, 0.08, 0.16])


def win():
    run = [523.25, 659.25, 783.99, 1046.5]
    arp = mix(*[bell(f, 0.3, 0.8) for f in run], offsets=[0, 0.1, 0.2, 0.3])
    final = mix(*[tone(1.0, f, harmonics=((1, 1), (2, 0.4), (3, 0.2)), attack=0.01, decay=0.5,
                       vibrato=(5, 0.005), gain=0.45) for f in [523.25, 659.25, 783.99, 1046.5]])
    return mix(arp, final, offsets=[0, 0.42])


def lose():
    # Sad "wah wah wah wahhh".
    notes = [(392.0, 0.3), (370.0, 0.3), (349.2, 0.3), (329.6, 0.8)]
    parts, offsets, at = [], [], 0.0
    for f, d in notes:
        parts.append(tone(d, f, harmonics=((1, 1), (2, 0.5), (3, 0.25)), attack=0.03, decay=d,
                          vibrato=(6 if d > 0.5 else 0, 0.02), gain=0.7))
        offsets.append(at)
        at += d * 0.95
    return mix(*parts, offsets=offsets)


def draw():
    return mix(bell(523.25, 0.4), bell(523.25, 0.5), offsets=[0, 0.18])


def ui_tap():
    return tone(0.07, sweep(500, 800, 0.04), attack=0.001, decay=0.02)


if __name__ == "__main__":
    print("Writing sounds to", os.path.normpath(OUT))
    save("chant_1", chant_pop(523.25))
    save("chant_2", chant_pop(659.25))
    save("chant_3", chant_pop(783.99))
    save("chant_go", chant_go())
    save("slam", slam())
    save("jump", jump())
    save("land", land())
    save("bump", bump())
    save("pin", pin())
    save("tick", tick(1200))
    save("tick_high", tick(1700))
    save("mash", mash())
    save("escape", escape())
    save("tired", tired())
    save("point", point())
    save("win", win())
    save("lose", lose())
    save("draw", draw())
    save("ui_tap", ui_tap())
