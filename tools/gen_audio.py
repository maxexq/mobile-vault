#!/usr/bin/env python3
"""Procedural sound for Apocarlypse (MV-536): every ambience loop, weather layer and sound effect is synthesised
here from noise, oscillators and simple filters, so no audio is downloaded and the licence is the repo's own.

    python tools/gen_audio.py            # writes assets/audio/{amb,weather,sfx}/*.wav
    python tools/gen_audio.py rain boss  # only the sounds whose name contains one of the words

Stdlib only (no numpy). Mono 16-bit 22050 Hz WAV; Godot imports them with QOA compression (the default), so the
pck stays small. Loops carry a RIFF 'smpl' chunk with a forward loop over the whole file (Godot's importer reads it,
loop_mode "Detect from WAV"); the loop seam is crossfaded, so there is no click. The random seed is fixed per sound:
re-running gives the same bytes. Phone speakers barely play below ~120 Hz, so every low sound also has body
between 120 and 400 Hz.
"""
import math
import os
import random
import struct
import sys
import wave
import zlib

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


# ------------------------------------------------------------------ basics
def n(sec):
    return int(sec * SR)


def zeros(sec):
    return [0.0] * n(sec)


def white(count, rnd):
    return [rnd.uniform(-1.0, 1.0) for _ in range(count)]


def brown(count, rnd, leak=0.995):
    out, y = [], 0.0
    for _ in range(count):
        y = y * leak + rnd.uniform(-1.0, 1.0) * 0.08
        out.append(y)
    return norm(out, 1.0)


def pink(count, rnd):
    b0 = b1 = b2 = 0.0
    out = []
    for _ in range(count):
        w = rnd.uniform(-1.0, 1.0)
        b0 = 0.99765 * b0 + w * 0.0990460
        b1 = 0.96300 * b1 + w * 0.2965164
        b2 = 0.57000 * b2 + w * 1.0526913
        out.append(b0 + b1 + b2 + w * 0.1848)
    return norm(out, 1.0)


def norm(x, peak=0.9):
    m = max((abs(v) for v in x), default=0.0)
    if m < 1e-9:
        return x
    k = peak / m
    return [v * k for v in x]


def gain(x, g):
    return [v * g for v in x]


def mix(dst, src, at=0, g=1.0, wrap=False):
    """adds src into dst at sample `at`; wrap=True folds the overflow to the start (for loops)"""
    L = len(dst)
    for i, v in enumerate(src):
        j = at + i
        if j >= L:
            if not wrap:
                break
            j %= L
        dst[j] += v * g
    return dst


def lp(x, fc):
    a = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
    y, out = 0.0, []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def hp(x, fc):
    low = lp(x, fc)
    return [a - b for a, b in zip(x, low)]


def _bp_coefs(f, q):
    w = 2.0 * math.pi * min(f, SR * 0.45) / SR
    al = math.sin(w) / (2.0 * q)
    a0 = 1.0 + al
    return (al / a0, 0.0, -al / a0, -2.0 * math.cos(w) / a0, (1.0 - al) / a0)


def bp(x, f, q=1.0):
    """RBJ band-pass (0 dB peak); f may be a number or a function of the time in seconds (swept every 32 samples)"""
    out = []
    x1 = x2 = y1 = y2 = 0.0
    fn = f if callable(f) else None
    c = _bp_coefs(f if fn is None else fn(0.0), q)
    for i, v in enumerate(x):
        if fn is not None and i % 32 == 0:
            c = _bp_coefs(max(20.0, fn(i / SR)), q)
        b0, b1, b2, a1, a2 = c
        y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, y
        out.append(y)
    return out


def env_mul(x, fn):
    return [v * fn(i / SR) for i, v in enumerate(x)]


def decay(t, tau):
    return math.exp(-t / tau)


def adsr(t, a, d_tau, length):
    if t < a:
        return t / a
    if t > length:
        return 0.0
    return math.exp(-(t - a) / d_tau)


def crush(x, bits=10, hold=1):
    """16-bit console flavour: fewer amplitude steps and sample-and-hold (hold=2 -> 11 kHz)"""
    q = float(2 ** (bits - 1))
    out, last = [], 0.0
    for i, v in enumerate(x):
        if i % hold == 0:
            last = round(v * q) / q
        out.append(last)
    return out


def osc(freq, sec, shape="sine", phase=0.0):
    """freq: number or function of time; shapes: sine, square, saw, tri"""
    out, ph = [], phase
    fn = freq if callable(freq) else None
    for i in range(n(sec)):
        f = fn(i / SR) if fn else freq
        ph += f / SR
        p = ph % 1.0
        if shape == "sine":
            out.append(math.sin(2 * math.pi * p))
        elif shape == "square":
            out.append(1.0 if p < 0.5 else -1.0)
        elif shape == "saw":
            out.append(2.0 * p - 1.0)
        else:
            out.append(4.0 * abs(p - 0.5) - 1.0)
    return out


def ping(freq, sec, tau, amp=1.0, partials=((1.0, 1.0),)):
    """struck object: decaying sines; partials = (ratio, level)"""
    out = []
    for i in range(n(sec)):
        t = i / SR
        s = sum(l * math.sin(2 * math.pi * freq * r * t) * math.exp(-t / (tau / (0.6 + r * 0.4))) for r, l in partials)
        out.append(s * amp)
    return out


def verb(x, wet=0.3, size=1.0, fb=0.72):
    """small Schroeder reverb (4 combs + 2 all-passes) for distance; returns a new list the same length"""
    combs = [int(d * size) for d in (1116, 1188, 1277, 1356)]
    out = [0.0] * len(x)
    for d in combs:
        buf = [0.0] * d
        k, lpz = 0, 0.0
        for i, v in enumerate(x):
            y = buf[k]
            lpz = y * 0.6 + lpz * 0.4
            buf[k] = v + lpz * fb
            out[i] += y * 0.25
            k = (k + 1) % d
    for d in (225, 556):
        buf = [0.0] * d
        k = 0
        for i, v in enumerate(out):
            b = buf[k]
            y = -v + b
            buf[k] = v + b * 0.5
            out[i] = y
            k = (k + 1) % d
    return [a * (1.0 - wet) + b * wet for a, b in zip(x, out)]


def seam(x, fade_sec):
    """turns len+fade samples into a seamless loop of len samples: the tail is crossfaded into the head"""
    F = n(fade_sec)
    body = x[:-F]
    tail = x[-F:]
    for i in range(F):
        a = i / F
        body[i] = body[i] * a + tail[i] * (1.0 - a)
    return body


def slow_lfo(sec, rnd, parts=3, lo=0.4, hi=1.0, fmin=0.05, fmax=0.3):
    """smooth random level between lo and hi made of a few slow sines"""
    comps = [(rnd.uniform(fmin, fmax), rnd.uniform(0, math.tau)) for _ in range(parts)]
    def f(t):
        s = sum(math.sin(math.tau * fr * t + ph) for fr, ph in comps) / parts
        return lo + (hi - lo) * (0.5 + 0.5 * s)
    return f


def soften(x, fc=6500.0):
    """MV-536 ear check: a gentle 2-pole roll-off on everything, so nothing is shrill on phone speakers"""
    return lp(lp(x, fc), fc)


def write(path, x, loop=False, peak=0.85, fc=6500.0):
    if loop:
        # filter a doubled copy and keep the second half: the filters are already settled at the seam
        L = len(x)
        x = soften(hp(x + x, 25.0), fc)[L:]
    else:
        x = soften(hp(x, 25.0), fc)       # no DC offset, no harsh top
    if loop:
        # beds are matched by loudness (RMS), not by peak, so a sparse bed is not quieter than a dense one;
        # tanh catches the odd peak above full scale. Loops keep their crossfaded seam (no fade).
        rms = math.sqrt(sum(v * v for v in x) / len(x)) or 1.0
        x = [math.tanh(v * 0.14 / rms * 1.6) / 1.6 for v in x]
    else:
        x = norm(x, peak)
        fi, fo = n(0.002), n(0.012)       # no click at the start or the cut-off end
        for i in range(min(fi, len(x))):
            x[i] *= i / fi
        for i in range(min(fo, len(x))):
            x[-1 - i] *= i / fo
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = b"".join(struct.pack("<h", max(-32767, min(32767, int(v * 32767)))) for v in x)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)
    if loop:
        # RIFF 'smpl' chunk: one forward loop over the whole file (start, end inclusive)
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        with open(path, "r+b") as f:
            f.seek(0, 2)
            f.write(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
            size = f.tell() - 8
            f.seek(4)
            f.write(struct.pack("<I", size))
    print("  %-34s %5.2f s %s" % (os.path.relpath(path, ROOT), len(x) / SR, "loop" if loop else ""))


# ------------------------------------------------------------------ building blocks
def wind(sec, rnd, lo=300.0, hi=900.0, q=1.2, gust=(0.35, 1.0), fmax=0.25):
    sweep = slow_lfo(sec, rnd, 3, lo, hi, 0.03, fmax)
    level = slow_lfo(sec, rnd, 3, gust[0], gust[1], 0.04, fmax)
    x = bp(pink(n(sec), rnd), sweep, q)
    return env_mul(x, level)


def clank(rnd, base=None, sec=1.4, tau=0.35):
    """distant struck metal: inharmonic partials"""
    f = base or rnd.uniform(160.0, 420.0)
    parts = ((1.0, 1.0), (2.76, 0.6), (5.40, 0.35), (8.93, 0.2))
    x = ping(f, sec, tau, 1.0, parts)
    hit = lp(white(n(0.02), rnd), 3000)
    return mix(x, hit, 0, 0.6)


def droplet(rnd, f=None, tau=None):
    f = f or rnd.uniform(1200.0, 3800.0)
    tau = tau or rnd.uniform(0.003, 0.012)
    out = []
    for i in range(n(tau * 6)):
        t = i / SR
        out.append(math.sin(math.tau * f * (1.0 + t * 8.0) * t) * math.exp(-t / tau))
    return out


def scatter(sec, rnd, per_sec, make, g=(0.3, 1.0), wrap=True):
    x = zeros(sec)
    count = int(sec * per_sec)
    for _ in range(count):
        mix(x, make(rnd), rnd.randrange(len(x)), rnd.uniform(*g), wrap)
    return x


def rain_layer(sec, rnd, density=260, heavy=False):
    """calm rain on a metal roof: soft wash + many fine droplets + a few tinks on the sheet metal + gutter drips"""
    L = sec
    wash = hp(lp(pink(n(L), rnd), 2000 if not heavy else 2600), 180)
    wash = env_mul(wash, slow_lfo(L, rnd, 2, 0.7, 1.0, 0.05, 0.15))
    x = gain(wash, 0.35 if not heavy else 0.55)
    mix(x, scatter(L, rnd, density, lambda r: droplet(r), (0.04, 0.22)), 0, 1.0)
    tinks = scatter(L, rnd, 7 if not heavy else 14,
                    lambda r: ping(r.uniform(800, 1700), 0.12, 0.03, 1.0, ((1.0, 1.0), (2.3, 0.3))), (0.04, 0.12))
    mix(x, tinks)
    drips = scatter(L, rnd, 0.8, lambda r: droplet(r, r.uniform(700, 1100), 0.025), (0.15, 0.3))
    mix(x, drips)
    return x


def crackle(sec, rnd, per_sec, fc=3500.0, g=(0.2, 1.0)):
    def pop(r):
        return hp(env_mul(white(n(0.006), r), lambda t: decay(t, 0.0015)), fc)
    return scatter(sec, rnd, per_sec, pop, g)


def thump(rnd, f0=110.0, f1=55.0, sec=0.25, noise=0.5):
    body = osc(lambda t: f1 + (f0 - f1) * math.exp(-t / 0.04), sec)
    body = env_mul(body, lambda t: decay(t, sec / 4))
    nz = lp(env_mul(white(n(sec), rnd), lambda t: decay(t, 0.02)), 900)
    return mix(body, nz, 0, noise)


# ------------------------------------------------------------------ ambience (loops)
def amb_engine(rnd):
    """armoured diesel at cruise: firing pulses + block rattle; Audio scales pitch for idle / driving"""
    L, F = 4.0, 0.4
    sec = L + F
    fire = 27.0           # firing pulses / s
    x = zeros(sec)
    t, k = 0.0, 0
    pulse = env_mul(osc(lambda t: 95 - 40 * t, 0.06, "saw"), lambda t: decay(t, 0.012))
    while t < sec:
        mix(x, pulse, int(t * SR), (1.0 if k % 4 == 0 else 0.7) * rnd.uniform(0.85, 1.0))
        t += 1.0 / fire * rnd.uniform(0.97, 1.03)
        k += 1
    x = lp(x, 420)
    hum = osc(fire * 2, sec, "tri")
    mix(x, gain(lp(hum, 300), 0.25))
    rumble = lp(brown(n(sec), rnd), 160)
    mix(x, rumble, 0, 0.6)
    rattle = bp(white(n(sec), rnd), 1400, 2.5)
    rattle = env_mul(rattle, lambda t: 0.5 + 0.5 * math.sin(math.tau * fire * t) ** 8)
    mix(x, rattle, 0, 0.08)
    return seam(x, F)


def amb_industrial(rnd):
    L, F = 8.0, 0.6
    sec = L + F
    x = wind(sec, rnd, 250, 700, 1.0, (0.3, 0.8))
    hum = [0.3 * math.sin(math.tau * 100 * i / SR) + 0.15 * math.sin(math.tau * 150 * i / SR) for i in range(n(sec))]
    mix(x, env_mul(hum, slow_lfo(sec, rnd, 2, 0.5, 1.0)), 0, 0.25)
    far = zeros(sec)
    for at in (0.7, 3.1, 4.0, 6.4):
        mix(far, clank(rnd), n(at), rnd.uniform(0.4, 1.0))
    hiss = env_mul(hp(white(n(1.6), rnd), 2500), lambda t: math.sin(math.pi * t / 1.6) ** 2)
    mix(far, hiss, n(5.2), 0.15)
    mix(x, lp(verb(far, 0.6, 1.4, 0.8), 2400), 0, 0.5)
    return seam(x, F)


def amb_desert(rnd):
    L, F = 8.0, 0.8
    sec = L + F
    x = wind(sec, rnd, 450, 1300, 0.9, (0.2, 1.0), 0.35)
    mix(x, bp(pink(n(sec), rnd), 1800, 0.7), 0, 0.04)     # sand hiss
    glass = zeros(sec)
    for _ in range(6):        # wind chimes of fused glass
        f = rnd.choice([1047, 1175, 1319, 1568, 1760])
        mix(glass, ping(f, 1.0, 0.25, 1.0, ((1.0, 1.0), (2.01, 0.3), (3.7, 0.1))), rnd.randrange(n(sec)), rnd.uniform(0.03, 0.07), True)
    mix(x, verb(glass, 0.5, 1.2))
    return seam(x, F)


def amb_forest(rnd):
    L, F = 8.0, 0.6
    sec = L + F
    x = gain(hp(lp(pink(n(sec), rnd), 2200), 300), 0.25)
    x = env_mul(x, slow_lfo(sec, rnd, 3, 0.3, 1.0, 0.1, 0.6))      # leaves
    insects = zeros(sec)
    for _ in range(14):       # cricket chirps: 4 kHz carrier, 3-4 pulses
        c = rnd.uniform(2500, 3100)
        pulses = rnd.randint(3, 4)
        chirp = [math.sin(math.tau * c * i / SR) * (math.sin(math.pi * ((i / SR) * 32 % 1.0)) ** 2)
                 for i in range(n(pulses / 32.0))]
        mix(insects, chirp, rnd.randrange(n(sec)), rnd.uniform(0.025, 0.06), True)
    mix(x, insects)
    for at in (1.8, 2.3, 6.1):      # crow caws far away
        caw = osc(lambda t: 620 - 220 * t, 0.32, "saw")
        caw = bp(env_mul(caw, lambda t: adsr(t, 0.02, 0.12, 0.32)), 1300, 2.0)
        mix(x, verb(caw + [0.0] * n(0.6), 0.5), n(at), 0.12)
    return seam(x, F)


def amb_swamp(rnd):
    L, F = 8.0, 0.6
    sec = L + F
    x = gain(lp(brown(n(sec), rnd), 300), 0.35)                   # murky water
    for at in (0.4, 0.9, 3.3, 5.0, 5.4, 7.2):       # frogs: a pulsed croak
        f0 = rnd.uniform(140, 190)
        croak = osc(f0, 0.38, "saw")
        croak = env_mul(croak, lambda t: (0.5 + 0.5 * math.sin(math.tau * 22 * t)) * adsr(t, 0.02, 0.15, 0.38))
        mix(x, lp(bp(croak, 420, 1.5), 900), n(at), rnd.uniform(0.25, 0.45))
    for _ in range(10):       # bubbles: low, round plops
        bub = osc(lambda t, f=rnd.uniform(160, 300): f * (1 + 4 * t), 0.08)
        mix(x, env_mul(bub, lambda t: adsr(t, 0.004, 0.02, 0.08)), rnd.randrange(n(sec)), rnd.uniform(0.08, 0.18), True)
    # the insect swarm (MV-536 ear check): a soft, low hum that swells and fades instead of a buzzing saw
    hum = [0.6 * math.sin(math.tau * 165 * i / SR) + 0.4 * math.sin(math.tau * 247.5 * i / SR + 0.7 * math.sin(math.tau * 5.5 * i / SR))
           for i in range(n(sec))]
    mix(x, env_mul(hum, slow_lfo(sec, rnd, 2, 0.0, 1.0, 0.1, 0.3)), 0, 0.035)
    return seam(x, F)


def amb_tundra(rnd):
    L, F = 8.0, 0.8
    sec = L + F
    x = gain(wind(sec, rnd, 450, 1000, 3.0, (0.2, 1.0), 0.3), 0.6)       # whistling, low and soft
    mix(x, wind(sec, rnd, 200, 500, 0.8, (0.3, 0.8)), 0, 0.9)
    for at in (2.5, 6.7):     # ice creak
        cr = osc(lambda t, f=rnd.uniform(70, 110): f + 30 * math.sin(t * 40) + rnd.uniform(-8, 8), 0.5, "saw")
        mix(x, bp(env_mul(cr, lambda t: math.sin(math.pi * t / 0.5)), 600, 3), n(at), 0.2)
    return seam(x, F)


def amb_metro(rnd):
    L, F = 8.0, 0.6
    sec = L + F
    x = [0.25 * math.sin(math.tau * 55 * i / SR) + 0.25 * math.sin(math.tau * 110.7 * i / SR)
         + 0.12 * math.sin(math.tau * 166 * i / SR) for i in range(n(sec))]
    mix(x, wind(sec, rnd, 300, 600, 1.0, (0.2, 0.5)), 0, 0.7)
    siren = osc(lambda t: 700 + 180 * math.sin(math.tau * 0.25 * t), sec)
    siren = env_mul(siren, lambda t: 0.5 - 0.5 * math.cos(math.tau * t / sec))
    mix(x, verb(lp(siren, 1200), 0.8, 1.5, 0.82), 0, 0.06)
    radio = zeros(sec)
    for at in (1.2, 4.6):     # a dead station: static burst then morse-ish beeps
        st = lp(bp(pink(n(0.5), rnd), 1000, 0.8), 2000)
        mix(radio, env_mul(st, lambda t: math.sin(math.pi * t / 0.5)), n(at), 0.15)
        b = at + 0.6
        for d in rnd.sample([0.08, 0.08, 0.2, 0.08, 0.2], 5):        # soft sine beeps, not a square
            beep = env_mul(osc(660, d), lambda t, d=d: min(1.0, t / 0.01, (d - t) / 0.01))
            mix(radio, beep, n(b), 0.06)
            b += d + 0.08
    mix(x, lp(verb(radio, 0.5), 2200))
    return seam(x, F)


# ------------------------------------------------------------------ weather (loops)
def w_overcast(rnd):
    L, F = 6.0, 0.6
    return seam(wind(L + F, rnd, 200, 500, 0.8, (0.3, 0.7)), F)


def w_rain(rnd):
    L, F = 8.0, 0.5
    return seam(rain_layer(L + F, rnd), F)


def w_storm(rnd):
    L, F = 8.0, 0.6
    sec = L + F
    x = rain_layer(sec, rnd, 520, True)
    mix(x, wind(sec, rnd, 200, 700, 0.9, (0.3, 1.0), 0.4), 0, 0.6)
    mix(x, lp(brown(n(sec), rnd), 120), 0, 0.3)
    return seam(x, F)


def w_sandstorm(rnd):
    L, F = 8.0, 0.6
    sec = L + F
    x = wind(sec, rnd, 250, 750, 0.7, (0.5, 1.0), 0.5)
    mix(x, bp(pink(n(sec), rnd), 1500, 0.6), 0, 0.08)               # blowing sand, no white hiss
    mix(x, lp(crackle(sec, rnd, 70, 900, (0.1, 0.4)), 3000))         # grit on the hull, dull ticks
    return seam(x, F)


def w_snow(rnd):
    L, F = 8.0, 0.6
    sec = L + F
    x = lp(wind(sec, rnd, 250, 600, 0.7, (0.2, 0.6)), 900)
    mix(x, hp(lp(pink(n(sec), rnd), 6000), 3000), 0, 0.03)
    return seam(x, F)


def w_fog(rnd):
    L, F = 8.0, 0.6
    sec = L + F
    x = lp(wind(sec, rnd, 120, 300, 0.7, (0.3, 0.8)), 400)
    mix(x, scatter(sec, rnd, 0.6, lambda r: droplet(r, r.uniform(600, 900), 0.03), (0.2, 0.35)))
    horn = osc(110, 2.4, "saw")
    horn = lp(env_mul(horn, lambda t: math.sin(math.pi * t / 2.4) ** 2), 500)
    mix(x, verb(horn + [0.0] * n(1.5), 0.7, 1.6, 0.8), n(4.5), 0.18, True)
    return seam(x, F)


def w_acid_rain(rnd):
    L, F = 8.0, 0.5
    sec = L + F
    # MV-536 rework: thick, slow drops that hiss softly on the hot hull and a low simmer, not a high fizz
    x = gain(rain_layer(sec, rnd, 110), 0.8)
    simmer = env_mul(bp(pink(n(sec), rnd), 700, 0.9), slow_lfo(sec, rnd, 3, 0.3, 1.0, 0.15, 0.5))
    mix(x, simmer, 0, 0.25)
    def hiss(r):           # a drop sizzling on metal: a short, warm breath of noise
        d = r.uniform(0.25, 0.5)
        return lp(bp(env_mul(pink(n(d), r), lambda t: math.sin(math.pi * t / d) ** 2), r.uniform(900, 1500), 1.2), 2200)
    mix(x, scatter(sec, rnd, 2.2, hiss, (0.15, 0.35)))
    bubbles = scatter(sec, rnd, 5, lambda r: env_mul(osc(lambda t, f=r.uniform(220, 380): f * (1 + 3 * t), 0.07),
                                                       lambda t: adsr(t, 0.004, 0.02, 0.07)), (0.05, 0.12))
    mix(x, bubbles)                 # acid pooling in the gutters
    return seam(x, F)


def w_ashfall(rnd):
    L, F = 8.0, 0.6
    sec = L + F
    x = lp(wind(sec, rnd, 150, 400, 0.8, (0.3, 0.7)), 600)
    embers = crackle(sec, rnd, 9, 1500, (0.2, 0.7))
    mix(x, lp(embers, 5000))
    return seam(x, F)


# ------------------------------------------------------------------ one-shots
def sfx_thunder(rnd, crack=True):
    sec = 5.0
    x = zeros(sec)
    if crack:
        c = hp(env_mul(white(n(0.4), rnd), lambda t: decay(t, 0.07)), 800)
        mix(x, c, 0, 0.6)
    roll = lp(brown(n(sec), rnd), 160)
    lvl = slow_lfo(sec, rnd, 4, 0.2, 1.0, 0.6, 2.5)
    roll = env_mul(roll, lambda t: lvl(t) * adsr(t, 0.15, 1.3, sec))
    mix(x, roll, n(0.05))
    return verb(x, 0.3, 1.6, 0.6)


def sfx_shot(rnd, heavy=False):
    sec = 0.5 if heavy else 0.28
    nz = env_mul(white(n(sec), rnd), lambda t: adsr(t, 0.002, 0.05 if heavy else 0.025, sec))
    nz = bp(nz, lambda t: 1500 * math.exp(-t * 12) + 300, 0.7)
    x = mix(nz, thump(rnd, 140 if heavy else 170, 50, sec, 0.3), 0, 1.0 if heavy else 0.7)
    return crush(lp(x, 3500), 10, 2)


def sfx_energy(rnd):
    x = osc(lambda t: 700 * math.exp(-t * 7) + 200, 0.25, "tri")
    return crush(env_mul(lp(x, 2000), lambda t: adsr(t, 0.004, 0.07, 0.25)), 10, 2)


def sfx_hit(rnd):
    return crush(thump(rnd, 160, 60, 0.18, 0.8), 9, 2)


def sfx_crit(rnd):
    x = thump(rnd, 200, 60, 0.3, 0.8)
    mix(x, env_mul(osc(1200, 0.25), lambda t: adsr(t, 0.003, 0.05, 0.25)), 0, 0.25)
    return crush(x, 10, 2)


def sfx_hit_metal(rnd):
    x = clank(rnd, 330, 0.6, 0.12)
    mix(x, thump(rnd, 120, 60, 0.2, 0.6), 0, 0.7)
    return crush(x, 10, 2)


def sfx_hit_hero(rnd):
    x = thump(rnd, 130, 70, 0.22, 0.5)
    grunt = bp(env_mul(osc(lambda t: 150 - 60 * t, 0.2, "saw"), lambda t: adsr(t, 0.01, 0.05, 0.2)), 700, 2)
    return crush(mix(x, grunt, 0, 0.5), 9, 2)


def sfx_enemy_die(rnd):
    sec = 0.6
    sq = env_mul(white(n(sec), rnd), lambda t: adsr(t, 0.01, 0.12, sec))
    sq = bp(sq, lambda t: 1600 * math.exp(-t * 6) + 150, 2.5)
    groan = bp(env_mul(osc(lambda t: 120 - 60 * t, sec, "saw"), lambda t: adsr(t, 0.03, 0.2, sec)), 500, 2)
    return crush(mix(sq, groan, 0, 0.6), 9, 2)


def sfx_heal(rnd):
    x = zeros(0.6)
    for k, f in enumerate((523.3, 659.3, 784.0, 1046.5)):
        mix(x, env_mul(osc(f, 0.25, "tri"), lambda t: decay(t, 0.08)), n(k * 0.07), 0.5)
    return crush(x, 8, 2)


def sfx_skill(rnd):
    sec = 0.4
    x = bp(pink(n(sec), rnd), lambda t: 250 + 1500 * (t / sec), 1.2)
    return env_mul(x, lambda t: math.sin(math.pi * t / sec))


def sfx_boss_roar(rnd):
    sec = 2.0
    base = osc(lambda t: 85 - 30 * t / sec + 8 * math.sin(t * 37) + rnd.uniform(-6, 6), sec, "saw")
    f1 = bp(base, 420, 2.0)
    f2 = bp(base, 950, 3.0)
    breath = bp(white(n(sec), rnd), 700, 0.8)
    x = [a + 0.6 * b + 0.3 * c for a, b, c in zip(f1, f2, breath)]
    x = env_mul(x, lambda t: adsr(t, 0.15, 0.7, sec))
    mix(x, lp(brown(n(sec), rnd), 140), 0, 0.5)
    return verb(x, 0.35, 1.3)


def sfx_alarm(rnd):
    """boss warning: a low two-tone horn, not a square klaxon"""
    x = zeros(1.6)
    for k in range(3):
        for j, f in enumerate((294, 370)):
            tone = env_mul(osc(f, 0.22, "tri"), lambda t: min(1.0, t / 0.02, (0.22 - t) / 0.03))
            mix(x, tone, n(k * 0.5 + j * 0.24), 0.5)
    return lp(x, 1400)


def sfx_build(rnd):
    x = zeros(0.95)
    for k in range(3):
        mix(x, clank(rnd, 520 + 40 * k, 0.4, 0.06), n(k * 0.22), 0.8)
    for k in range(6):        # ratchet
        mix(x, hp(env_mul(white(n(0.01), rnd), lambda t: decay(t, 0.002)), 2000), n(0.7 + k * 0.035), 0.6)
    return crush(x, 10, 2)


def sfx_build_done(rnd):
    x = ping(880, 0.9, 0.25, 1.0, ((1.0, 1.0), (2.0, 0.25), (3.0, 0.08)))
    mix(x, ping(1318.5, 0.7, 0.2, 0.45), n(0.09))
    return lp(x, 3000)


def sfx_demolish(rnd):
    sec = 1.3
    x = lp(env_mul(brown(n(sec), rnd), lambda t: adsr(t, 0.005, 0.3, sec)), 900)
    for k in range(5):
        mix(x, clank(rnd, rnd.uniform(200, 500), 0.5, 0.08), n(0.05 + k * rnd.uniform(0.08, 0.18)), 0.5)
    mix(x, crackle(sec, rnd, 40, 2000, (0.2, 0.6)), 0, 0.6)
    return crush(x, 10, 2)


def sfx_loot(rnd):
    x = ping(1175, 0.3, 0.05)
    mix(x, ping(1568, 0.25, 0.05), n(0.06), 0.7)
    return lp(x, 3000)


def sfx_loot_rare(rnd):
    x = zeros(1.0)
    for k, f in enumerate((784, 988, 1175, 1568, 1976)):
        mix(x, ping(f, 0.6, 0.12, 1.0, ((1.0, 1.0), (2.0, 0.15))), n(k * 0.07), 0.45)
    return lp(verb(x, 0.3), 3200)


def sfx_engine_start(rnd):
    sec = 2.2
    x = zeros(sec)
    for k in range(10):       # starter crank
        mix(x, bp(env_mul(white(n(0.06), rnd), lambda t: decay(t, 0.02)), 500, 1.5), n(k * 0.08), 0.6)
        mix(x, thump(rnd, 120, 70, 0.07, 0.2), n(k * 0.08), 0.5)
    run = amb_engine(random.Random(7))[:n(1.4)]
    run = env_mul(run, lambda t: min(1.0, t / 0.15) * (1.0 if t < 1.0 else max(0.0, 1.0 - (t - 1.0) / 0.4)))
    mix(x, run, n(0.8), 1.0)
    return x


def sfx_engine_stall(rnd):
    sec = 1.6
    x = zeros(sec)
    t, gap = 0.0, 0.05
    while t < 1.2:
        mix(x, thump(rnd, 110, 55, 0.08, 0.5), n(t), rnd.uniform(0.5, 1.0))
        t += gap
        gap *= 1.18
    hiss = hp(env_mul(white(n(0.6), rnd), lambda t: decay(t, 0.2)), 2000)
    mix(x, hiss, n(1.0), 0.2)
    return lp(x, 2500)


def sfx_radio(rnd):
    """road event: a short, soft radio squelch and two low beeps"""
    x = env_mul(lp(bp(pink(n(0.3), rnd), 1000, 0.8), 2000), lambda t: math.sin(math.pi * t / 0.3))
    x = gain(x, 0.5) + [0.0] * n(0.5)
    for at, f in ((0.38, 523.3), (0.53, 659.3)):
        mix(x, env_mul(osc(f, 0.12), lambda t: min(1.0, t / 0.008) * decay(t, 0.05)), n(at), 0.4)
    return lp(x, 2500)


def sfx_door(rnd):
    x = thump(rnd, 90, 50, 0.4, 0.8)
    mix(x, clank(rnd, 700, 0.25, 0.04), n(0.03), 0.4)
    return x


def sfx_depart(rnd):
    x = sfx_door(rnd) + [0.0] * n(0.9)
    for k in range(4):        # boots on gravel
        step = bp(env_mul(white(n(0.09), rnd), lambda t: decay(t, 0.025)), 1200, 0.8)
        mix(x, step, n(0.45 + k * 0.2), 0.4 - k * 0.07)
    return x


def sfx_horn(rnd):
    sec = 0.9
    x = [a + b for a, b in zip(osc(330, sec, "saw"), osc(415, sec, "saw"))]
    x = bp(env_mul(x, lambda t: (1.0 if t < 0.28 or 0.4 < t < 0.75 else 0.0) * 0.8), 900, 1.0)
    return crush(lp(x, 2500), 9, 2)


def sfx_return(rnd):
    x = sfx_horn(rnd) + [0.0] * n(0.4)
    return mix(x, sfx_door(rnd), n(0.85), 0.8)


def sfx_checkpoint(rnd):
    sec = 2.0
    x = osc(lambda t: 160 + 30 * math.sin(math.pi * t / 1.0), 1.0, "saw")
    x = lp(env_mul(x, lambda t: adsr(t, 0.1, 0.5, 1.0)), 900) + [0.0] * n(sec - 1.0)
    mix(x, clank(rnd, 140, 0.9, 0.25), n(1.0), 0.9)
    mix(x, thump(rnd, 100, 45, 0.5, 0.8), n(1.0), 0.8)
    return verb(x, 0.25)


def sfx_knock(rnd):
    x = zeros(0.8)
    for k in range(3):
        mix(x, clank(rnd, 260, 0.2, 0.03), n(k * 0.18), 0.8)
        mix(x, thump(rnd, 140, 80, 0.08, 0.3), n(k * 0.18), 0.6)
    return x


def sfx_wreck(rnd):
    x = sfx_demolish(rnd) + [0.0] * n(1.0)
    mix(x, sfx_thunder(rnd, False)[:n(2.0)], 0, 0.6)
    return x


def ui_tap(rnd):
    """a soft wooden tick"""
    x = env_mul(osc(lambda t: 700 - 2000 * t, 0.04), lambda t: min(1.0, t / 0.002) * decay(t, 0.008))
    return lp(x, 2000)


def ui_confirm(rnd):
    x = env_mul(osc(523.3, 0.07, "tri"), lambda t: min(1.0, t / 0.004) * decay(t, 0.03))
    x += env_mul(osc(784, 0.12, "tri"), lambda t: min(1.0, t / 0.004) * decay(t, 0.045))
    return lp(x, 2200)


def ui_cancel(rnd):
    x = env_mul(osc(392, 0.07, "tri"), lambda t: min(1.0, t / 0.004) * decay(t, 0.03))
    x += env_mul(osc(294, 0.12, "tri"), lambda t: min(1.0, t / 0.004) * decay(t, 0.045))
    return lp(x, 1800)


def ui_open(rnd):
    sec = 0.14
    x = bp(pink(n(sec), rnd), lambda t: 1300 - 4500 * t, 1.5)
    return lp(env_mul(x, lambda t: math.sin(math.pi * t / sec)), 2200)


def toast_good(rnd):
    x = env_mul(osc(659.3, 0.14), lambda t: min(1.0, t / 0.005) * decay(t, 0.05))
    x += env_mul(osc(880, 0.16), lambda t: min(1.0, t / 0.005) * decay(t, 0.06))
    return x


def toast_bad(rnd):
    x = zeros(0.36)
    for k in range(2):
        mix(x, env_mul(osc(147, 0.12, "tri"), lambda t: adsr(t, 0.008, 0.06, 0.12)), n(k * 0.17), 0.6)
    return lp(x, 1200)


# ------------------------------------------------------------------ music (loops)
def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def ep_note(f, sec, vel=1.0):
    """electric piano: soft attack, a little 2nd harmonic, slow decay and tremolo (Rhodes-ish)"""
    out = []
    for i in range(n(sec)):
        t = i / SR
        a = min(1.0, t / 0.012) * math.exp(-t / 1.6) * (1.0 - 0.12 * math.sin(math.tau * 4.2 * t))
        v = math.sin(math.tau * f * t) + 0.22 * math.sin(math.tau * 2 * f * t) * math.exp(-t / 0.3) \
            + 0.06 * math.sin(math.tau * 3 * f * t) * math.exp(-t / 0.15)
        out.append(v * a * vel)
    return out


def music_title(rnd):
    """MV-536 title BGM: cozy lo-fi, 72 BPM, 8 bars (Fmaj9 Em7 Dm9 G9sus, twice), seamless loop"""
    bpm = 72.0
    beat = 60.0 / bpm
    bars = 8
    L = n(bars * 4 * beat)
    keys, bass, drums, mel = [0.0] * L, [0.0] * L, [0.0] * L, [0.0] * L
    at = lambda b: int(b * beat * SR)
    chords = [  # (bass midi, chord midis)
        (41, [53, 57, 60, 64, 67]),     # Fmaj9
        (40, [52, 55, 59, 62, 67]),     # Em7
        (38, [53, 57, 60, 62, 64]),     # Dm9
        (43, [53, 57, 60, 62, 65]),     # G9sus
    ]
    for bar in range(bars):
        root, notes = chords[bar // 2 % 4]          # two bars per chord
        b0 = bar * 4
        for k, m in enumerate(notes):          # chord on 1, strummed
            mix(keys, ep_note(midi(m), 2.6, 0.32), at(b0) + n(0.018 * k), 1.0, True)
        if bar % 2 == 1:                       # a soft re-hit on the "and" of 3
            for k, m in enumerate(notes[1:4]):
                mix(keys, ep_note(midi(m), 1.4, 0.18), at(b0 + 2.5) + n(0.015 * k), 1.0, True)
        for bb, dur, v in ((0, 1.6, 1.0), (2.5, 1.0, 0.7)):     # bass
            note = [math.sin(math.tau * midi(root) * i / SR) + 0.3 * math.sin(math.tau * 2 * midi(root) * i / SR)
                    for i in range(n(dur))]
            note = env_mul(note, lambda t, d=dur: min(1.0, t / 0.01) * math.exp(-t / 0.7) * min(1.0, (d - t) / 0.05))
            mix(bass, note, at(b0 + bb), 0.5 * v, True)
        # drums: kick 1 / 2.75 / 3.5, snare 2 and 4, swung 8th hats
        for kb in (0, 1.75, 2.5):
            kick = env_mul(osc(lambda t: 48 + 50 * math.exp(-t / 0.03), 0.3), lambda t: math.exp(-t / 0.09))
            mix(drums, kick, at(b0 + kb), 0.8, True)
        for sb in (1, 3):
            sn = env_mul(bp(white(n(0.25), rnd), 1500, 0.7), lambda t: math.exp(-t / 0.06))
            mix(sn, env_mul(osc(190, 0.25), lambda t: math.exp(-t / 0.03)), 0, 0.4)
            mix(drums, lp(sn, 3000), at(b0 + sb), 0.35, True)
        for h in range(8):
            hb = h * 0.5 + (0.12 if h % 2 else 0.0)                 # swing
            hat = env_mul(hp(white(n(0.05), rnd), 4000), lambda t: math.exp(-t / 0.012))
            mix(drums, lp(hat, 7000), at(b0 + hb), 0.06 if h % 2 else 0.09, True)
    # a small pentatonic melody, two-bar phrases, bell-soft
    phrase = [(0, 72), (1.5, 76), (2, 79), (3, 76), (4.5, 74), (6, 72)]
    alt = [(0, 76), (1, 79), (2.5, 81), (4, 79), (5.5, 76), (6.5, 74)]
    for p in range(bars // 2):
        for b, m in (phrase if p % 2 == 0 else alt):
            tone = env_mul(osc(midi(m), 1.2), lambda t: min(1.0, t / 0.02) * math.exp(-t / 0.45))
            mix(mel, tone, at(p * 8 + b), 0.12, True)
    mel = verb(mel, 0.35, 1.3)
    x = [k + b + d + m for k, b, d, m in zip(lp(keys, 3200), lp(bass, 400), drums, mel)]
    # vinyl: soft hiss and dust crackle
    mix(x, gain(hp(lp(pink(L, rnd), 3000), 900), 0.012))
    mix(x, lp(crackle(L / SR, rnd, 7, 1200, (0.05, 0.2)), 3500))
    # tape wobble: read the loop at a gently varying speed (whole cycles over the loop, so it still loops)
    cyc = 3
    out = []
    pos = 0.0
    for i in range(L):
        v0 = x[int(pos) % L]
        v1 = x[(int(pos) + 1) % L]
        fr = pos - int(pos)
        out.append(v0 * (1 - fr) + v1 * fr)
        pos += 1.0 + 0.0025 * math.cos(math.tau * cyc * i / L)
    out = [math.tanh(v * 1.4) for v in lp(out, 4200)]           # warm, rolled-off top
    return out


SOUNDS = {
    # name: (folder, builder, loop)
    "engine": ("amb", amb_engine, True),
    "industrial": ("amb", amb_industrial, True),
    "desert": ("amb", amb_desert, True),
    "forest": ("amb", amb_forest, True),
    "swamp": ("amb", amb_swamp, True),
    "tundra": ("amb", amb_tundra, True),
    "metro": ("amb", amb_metro, True),
    "overcast": ("weather", w_overcast, True),
    "rain": ("weather", w_rain, True),
    "storm": ("weather", w_storm, True),
    "sandstorm": ("weather", w_sandstorm, True),
    "snow": ("weather", w_snow, True),
    "fog": ("weather", w_fog, True),
    "acid_rain": ("weather", w_acid_rain, True),
    "ashfall": ("weather", w_ashfall, True),
    "thunder_1": ("sfx", lambda r: sfx_thunder(r, True), False),
    "thunder_2": ("sfx", lambda r: sfx_thunder(r, False), False),
    "shot": ("sfx", sfx_shot, False),
    "shot_heavy": ("sfx", lambda r: sfx_shot(r, True), False),
    "shot_energy": ("sfx", sfx_energy, False),
    "hit": ("sfx", sfx_hit, False),
    "hit_crit": ("sfx", sfx_crit, False),
    "hit_metal": ("sfx", sfx_hit_metal, False),
    "hit_hero": ("sfx", sfx_hit_hero, False),
    "enemy_die": ("sfx", sfx_enemy_die, False),
    "heal": ("sfx", sfx_heal, False),
    "skill": ("sfx", sfx_skill, False),
    "boss_roar": ("sfx", sfx_boss_roar, False),
    "alarm": ("sfx", sfx_alarm, False),
    "build": ("sfx", sfx_build, False),
    "build_done": ("sfx", sfx_build_done, False),
    "demolish": ("sfx", sfx_demolish, False),
    "loot": ("sfx", sfx_loot, False),
    "loot_rare": ("sfx", sfx_loot_rare, False),
    "engine_start": ("sfx", sfx_engine_start, False),
    "engine_stall": ("sfx", sfx_engine_stall, False),
    "radio": ("sfx", sfx_radio, False),
    "depart": ("sfx", sfx_depart, False),
    "return": ("sfx", sfx_return, False),
    "checkpoint": ("sfx", sfx_checkpoint, False),
    "knock": ("sfx", sfx_knock, False),
    "wreck": ("sfx", sfx_wreck, False),
    "toast_good": ("sfx", toast_good, False),
    "toast_bad": ("sfx", toast_bad, False),
    "title_lofi": ("music", music_title, True),
    "tap": ("ui", ui_tap, False),
    "confirm": ("ui", ui_confirm, False),
    "cancel": ("ui", ui_cancel, False),
    "open": ("ui", ui_open, False),
}


def main():
    words = sys.argv[1:]
    for name, (folder, fn, loop) in SOUNDS.items():
        if words and not any(w in name for w in words):
            continue
        rnd = random.Random(zlib.crc32(name.encode()))
        x = fn(rnd)
        write(os.path.join(ROOT, folder, name + ".wav"), x, loop)


if __name__ == "__main__":
    main()
