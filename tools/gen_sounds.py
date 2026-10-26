#!/usr/bin/env python3
"""Synthesises the placeholder sound effects in assets/audio/sfx.

Every sound is generated from noise and oscillators, so no third-party
recordings are involved. They are deliberately plain placeholders: they
can be replaced one by one with recorded effects of the same file name.
No voices are generated here (dialogue voice tracks are recorded assets).

Usage:  python3 tools/gen_sounds.py      (needs numpy)
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
rng = np.random.default_rng(1985)


def t(sec):
    return np.arange(int(RATE * sec)) / RATE


def noise(sec):
    return rng.uniform(-1.0, 1.0, int(RATE * sec))


def lowpass(x, hz):
    a = np.exp(-2.0 * np.pi * hz / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, hz):
    return x - lowpass(x, hz)


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def env(n, attack, release, total=None):
    """Linear attack / exponential-ish release envelope of n samples."""
    e = np.ones(n)
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    e[:a] = np.linspace(0.0, 1.0, a)
    e[-r:] *= np.linspace(1.0, 0.0, r) ** 2
    return e


def pad(x, sec):
    return np.concatenate([x, np.zeros(int(sec * RATE))])


def at(base, clip, sec):
    """Mixes clip into base starting at sec (base grows if needed)."""
    i = int(sec * RATE)
    if i + len(clip) > len(base):
        base = np.concatenate([base, np.zeros(i + len(clip) - len(base))])
    base[i:i + len(clip)] += clip
    return base


def loopable(x, fade=0.25):
    """Crossfades the tail into the head so the clip loops without a click."""
    f = int(fade * RATE)
    head = x[:f].copy()
    tail = x[-f:]
    w = np.linspace(0.0, 1.0, f)
    x = x[:-f].copy()
    x[:f] = head * w + tail * (1.0 - w)
    return x


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = np.clip(x / m * peak, -1.0, 1.0)
    data = (x * 32767).astype("<i2").tobytes()
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("%-18s %5.2f s" % (name, len(x) / RATE))


def click(sec=0.012, hz=2500.0):
    n = noise(sec) * np.exp(-t(sec) * 400.0)
    return bandpass(n, hz * 0.5, hz * 2.0)


# --- Room ambience ---------------------------------------------------------------

def generator_hum():
    s = t(4.0)
    x = 0.6 * np.sin(2 * np.pi * 50 * s) + 0.35 * np.sin(2 * np.pi * 100 * s) + 0.12 * np.sin(2 * np.pi * 150 * s)
    x *= 1.0 + 0.08 * np.sin(2 * np.pi * 0.5 * s)
    x += 0.25 * lowpass(noise(4.0), 180.0)
    return loopable(x)


def fluorescent():
    s = t(3.0)
    x = 0.4 * np.sign(np.sin(2 * np.pi * 100 * s)) * 0.3 + 0.2 * np.sin(2 * np.pi * 200 * s)
    x = lowpass(x, 1800.0) + 0.05 * highpass(noise(3.0), 3000.0)
    return loopable(x)


def static_loop():
    x = bandpass(noise(3.0), 300.0, 4500.0)
    x *= 0.7 + 0.3 * lowpass(noise(3.0), 6.0) * 4.0
    return loopable(x)


def radio_burst():
    """Squelch opening, static with a faint warbling carrier, squelch tail."""
    s = t(2.2)
    x = bandpass(noise(2.2), 300.0, 4000.0)
    x *= 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 3.3 * s))
    x += 0.15 * np.sin(2 * np.pi * (900 + 40 * np.sin(2 * np.pi * 5 * s)) * s)
    x *= env(len(x), 0.01, 0.2)
    x = at(x, 2.5 * click(0.03, 1800.0), 0.0)
    return x


# --- Signals --------------------------------------------------------------------------

def phone_ring():
    """One electromechanical ring burst (bell struck at 20 Hz), 2 s."""
    s = t(2.0)
    bell = np.sin(2 * np.pi * 1180 * s) + 0.6 * np.sin(2 * np.pi * 1420 * s) + 0.25 * np.sin(2 * np.pi * 2550 * s)
    strike = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 20 * s))
    x = bell * strike * env(len(s), 0.01, 0.15)
    return pad(x, 0.1)


def printer():
    """Teleprinter: motor start, a run of hammer strikes, line feeds."""
    s = t(3.0)
    motor = 0.25 * np.sin(2 * np.pi * 60 * s) + 0.15 * lowpass(noise(3.0), 400.0)
    motor *= np.clip(s * 3.0, 0, 1) * np.clip((3.0 - s) * 4.0, 0, 1)
    x = motor
    k = 0.35
    while k < 2.6:
        x = at(x, click(0.02, 3000.0 + rng.uniform(-600, 600)) * rng.uniform(0.5, 1.0), k)
        k += rng.choice([0.07, 0.08, 0.09, 0.2])
        if rng.random() < 0.07:                      # carriage return / line feed
            x = at(x, 0.6 * lowpass(noise(0.12), 900.0) * env(int(0.12 * RATE), 0.005, 0.08), k)
            k += 0.18
    return x


def crt_alert():
    s = t(0.16)
    tone = np.sign(np.sin(2 * np.pi * 1250 * s)) * env(len(s), 0.005, 0.03)
    x = np.zeros(1)
    for k in (0.0, 0.24):
        x = at(x, lowpass(tone, 3500.0), k)
    return pad(x, 0.1)


def crt_power():
    """Degauss thump plus a rising flyback whine."""
    s = t(1.6)
    thump = lowpass(noise(1.6), 120.0) * np.exp(-s * 5.0) * 3.0
    whine = 0.1 * np.sin(2 * np.pi * (6000 + 9000 * np.clip(s, 0, 1)) * s) * np.clip(s * 2.0, 0, 1) * np.exp(-s * 1.5)
    buzz = 0.3 * np.sin(2 * np.pi * 60 * s) * np.exp(-s * 3.0)
    return thump + whine + buzz


def switch_click():
    x = at(click(0.015, 2200.0), 0.6 * click(0.02, 900.0), 0.0)
    return pad(x, 0.05)


def ui_select():
    s = t(0.06)
    return pad(np.sign(np.sin(2 * np.pi * 880 * s)) * env(len(s), 0.002, 0.02) * 0.5, 0.02)


def paper():
    x = highpass(noise(0.45), 1500.0) * env(int(0.45 * RATE), 0.03, 0.2)
    x *= 0.6 + 0.4 * np.abs(lowpass(noise(0.45), 25.0)) * 6.0
    return x


# --- Vices -------------------------------------------------------------------------------------

def beer_open():
    """Crown cap levered off: click, pop, carbonation hiss."""
    s = t(1.4)
    pop = lowpass(noise(0.05), 1500.0) * np.exp(-t(0.05) * 90.0) * 3.0
    fizz = highpass(noise(1.4), 4000.0) * np.exp(-s * 2.2) * 0.4
    fizz *= 0.5 + 0.5 * (rng.random(len(s)) > 0.7)
    x = at(fizz, pop, 0.0)
    return at(x, 1.5 * click(0.01, 3500.0), 0.0)


def gulp():
    x = np.zeros(1)
    for k in (0.1, 0.55, 1.0):
        n = int(0.16 * RATE)
        s = np.arange(n) / RATE
        g = np.sin(2 * np.pi * (180 - 300 * s) * s) * np.sin(np.pi * s / s[-1])
        x = at(x, lowpass(g + 0.3 * noise(0.16), 600.0), k)
    return pad(x, 0.1)


def bottle_set():
    s = t(0.6)
    ring = (np.sin(2 * np.pi * 1900 * s) + 0.5 * np.sin(2 * np.pi * 3150 * s)) * np.exp(-s * 12.0) * 0.4
    knock = lowpass(noise(0.6), 500.0) * np.exp(-s * 60.0) * 2.0
    return ring + knock


def lighter():
    """Flint wheel scratch, spark, soft flame rush."""
    scratch = bandpass(noise(0.12), 2000.0, 7000.0) * env(int(0.12 * RATE), 0.01, 0.05)
    flame = lowpass(noise(1.1), 700.0) * env(int(1.1 * RATE), 0.08, 0.6) * 0.7
    x = at(np.zeros(1), scratch, 0.0)
    x = at(x, 0.8 * click(0.01, 5000.0), 0.11)
    return at(x, flame, 0.14)


def inhale():
    x = bandpass(noise(1.6), 500.0, 2500.0) * env(int(1.6 * RATE), 0.5, 0.6) * 0.5
    # Faint crackle of the burning paper.
    for k in np.arange(0.2, 1.2, 0.09):
        x = at(x, 0.25 * click(0.006, 6000.0), k + rng.uniform(0, 0.05))
    return x


def exhale():
    """A slow breath out through the teeth."""
    x = bandpass(noise(1.5), 300.0, 2200.0) * env(int(1.5 * RATE), 0.15, 0.9) * 0.6
    return x


def bottle_lift():
    s = t(0.25)
    return (np.sin(2 * np.pi * 2300 * s) * np.exp(-s * 30.0) * 0.25) + lowpass(noise(0.25), 400.0) * np.exp(-s * 40.0)


def retch():
    """Non-graphic: two dry heaves (low throat noise) and a cough."""
    x = np.zeros(1)
    for k, d in ((0.0, 0.55), (0.75, 0.7)):
        n = int(d * RATE)
        s = np.arange(n) / RATE
        heave = lowpass(noise(d), 260.0) * np.sin(np.pi * s / d) ** 2 * 2.2
        heave += 0.25 * np.sin(2 * np.pi * (110 - 30 * s / d) * s) * np.sin(np.pi * s / d)
        x = at(x, heave, k)
    cough = bandpass(noise(0.18), 250.0, 1800.0) * np.exp(-t(0.18) * 18.0) * 1.4
    x = at(x, cough, 1.75)
    x = at(x, 0.7 * cough, 2.05)
    return pad(x, 0.2)


# --- Facility / events ------------------------------------------------------------------------

def door_heavy():
    """Heavy latch thrown, then a slow hinge groan."""
    s = t(2.4)
    latch = lowpass(noise(0.18), 800.0) * np.exp(-t(0.18) * 25.0) * 2.0
    groan = np.sin(2 * np.pi * (95 + 25 * np.sin(2 * np.pi * 0.7 * s)) * s) * 0.4
    groan = lowpass(groan + 0.2 * noise(2.4), 900.0) * env(len(s), 0.3, 0.6)
    x = at(groan, latch, 0.0)
    return at(x, 1.2 * click(0.03, 600.0), 0.05)


def gunshot_far():
    """Single shot heard through walls: low thump and a long room tail."""
    s = t(2.0)
    crack = lowpass(noise(2.0), 600.0) * np.exp(-s * 18.0) * 3.0
    tail = lowpass(noise(2.0), 250.0) * np.exp(-s * 2.5) * 0.6
    return crack + tail


def gunshot_near():
    s = t(1.6)
    crack = noise(1.6) * np.exp(-s * 45.0) * 3.0
    body = lowpass(noise(1.6), 900.0) * np.exp(-s * 6.0)
    return crack + body


def footsteps():
    x = np.zeros(1)
    for i, k in enumerate((0.0, 0.62, 1.22, 1.86)):
        step = lowpass(noise(0.12), 500.0 + 150.0 * (i % 2)) * np.exp(-t(0.12) * 40.0)
        x = at(x, step * (0.6 + 0.12 * i), k)
    return pad(x, 0.2)


def knock():
    x = np.zeros(1)
    for k in (0.0, 0.32, 0.64):
        x = at(x, lowpass(noise(0.08), 700.0) * np.exp(-t(0.08) * 60.0), k)
    return pad(x, 0.2)


def launch_rumble():
    s = t(6.0)
    x = lowpass(noise(6.0), 90.0) * 5.0 + 0.3 * lowpass(noise(6.0), 400.0)
    x *= np.clip(s / 0.6, 0, 1) * np.clip((6.0 - s) / 3.0, 0, 1)
    return x


def park():
    """Outdoor ambience: wind in leaves and a few distant birds."""
    s = t(8.0)
    wind = lowpass(highpass(noise(8.0), 200.0), 1200.0) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * s) ** 2)
    x = wind * 0.5
    for k in (0.8, 1.1, 3.9, 4.15, 4.4, 6.6):
        n = int(0.09 * RATE)
        c = np.arange(n) / RATE
        chirp = np.sin(2 * np.pi * (3200 + 1800 * c / c[-1]) * c) * np.sin(np.pi * c / c[-1])
        x = at(x, chirp * 0.25, k)
    return loopable(x, 0.5)


def drone():
    """Menu bed: a slow, dark two-note pad (procedural placeholder music)."""
    s = t(12.0)
    x = np.zeros_like(s)
    for hz, a in ((55.0, 0.5), (82.4, 0.3), (110.0, 0.2), (164.8, 0.08)):
        x += a * np.sin(2 * np.pi * hz * s + np.sin(2 * np.pi * 0.07 * s) * 2.0)
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * s / 12.0)
    x += 0.04 * lowpass(noise(12.0), 300.0)
    return loopable(lowpass(x, 900.0), 1.0)


def typewriter():
    x = np.zeros(1)
    k = 0.0
    while k < 1.2:
        x = at(x, click(0.018, 2600.0 + rng.uniform(-400, 400)), k)
        k += rng.uniform(0.06, 0.13)
    return pad(x, 0.1)


if __name__ == "__main__":
    save("generator_hum", generator_hum(), 0.6)
    save("fluorescent", fluorescent(), 0.4)
    save("static_loop", static_loop(), 0.5)
    save("radio_burst", radio_burst())
    save("phone_ring", phone_ring(), 0.7)
    save("printer", printer())
    save("crt_alert", crt_alert(), 0.5)
    save("crt_power", crt_power())
    save("switch_click", switch_click())
    save("ui_select", ui_select(), 0.4)
    save("paper", paper(), 0.5)
    save("beer_open", beer_open())
    save("gulp", gulp(), 0.6)
    save("bottle_set", bottle_set(), 0.6)
    save("lighter", lighter())
    save("inhale", inhale(), 0.4)
    save("door_heavy", door_heavy())
    save("gunshot_far", gunshot_far(), 0.9)
    save("gunshot_near", gunshot_near(), 0.95)
    save("footsteps", footsteps())
    save("knock", knock())
    save("launch_rumble", launch_rumble(), 0.9)
    save("park", park(), 0.5)
    save("drone", drone(), 0.5)
    save("typewriter", typewriter(), 0.5)
    # Added later: keep at the end so earlier sounds stay byte-identical.
    save("exhale", exhale(), 0.35)
    save("bottle_lift", bottle_lift(), 0.35)
    save("retch", retch(), 0.6)
