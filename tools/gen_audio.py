#!/usr/bin/env python3
"""Procedural sound for Apocarlypse (MV-536): every ambience loop, weather layer and sound effect is synthesised
here from noise, oscillators and simple filters, so no audio is downloaded and the licence is the repo's own.

    python tools/gen_audio.py            # writes assets/audio/{amb,weather,sfx}/*.wav
    python tools/gen_audio.py rain boss  # only the sounds whose name contains one of the words

Stdlib only (no numpy). Mono 16-bit 22050 Hz WAV; Godot imports them with QOA compression (the default), so the
pck stays small. A loop is a seamless cycle followed by its first LOOP_TAIL seconds again (MV-555): Sound plays it
on two players that take turns and overlap over that tail, so the web build keeps loops on browser samples (no
main-thread mixing, no crackle); the cycle's own seam is crossfaded, so there is no click. The random seed is fixed per sound:
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
BED_FC = 2800.0      # MV-538: biome beds roll off above this (lo-fi, cozy)
LOOP_TAIL = 0.5      # MV-555: seconds of the loop repeated after its end (Sound.LOOP_TAIL), the A/B crossfade
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


def retro(x, bits=10, hold=1):
    """MV-555: was crush(), a bit-crusher (8-10 bit steps and an 11 kHz sample-and-hold). Its quantisation grit and
    aliasing were part of the hiss / crackle Parames heard, so the "16-bit" dullness is now a clean low-pass at the
    old hold rate; bits is kept so the call sites still read the same and is ignored."""
    return lp(lp(x, SR / (2.0 * max(1, hold)) * 0.7), SR / (2.0 * max(1, hold)) * 0.7)


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


def write(path, x, loop=False, peak=0.7, fc=6500.0, rms_to=0.10, peak_cap=0.42):
    if loop:
        # filter a doubled copy and keep the second half: the filters are already settled at the seam
        L = len(x)
        x = soften(hp(x + x, 25.0), fc)[L:]
    else:
        x = soften(hp(x, 25.0), fc)       # no DC offset, no harsh top
    if loop:
        # beds are matched by loudness (RMS), not by peak, so a sparse bed is not quieter than a dense one.
        # MV-555: no more tanh on the loud bits (it flattened every raindrop and gust into distortion); a bed whose
        # peaks would pass peak_cap is simply turned down, so bed + weather + engine + effects keep headroom on the
        # web, where browser samples are summed without a limiter.
        rms = math.sqrt(sum(v * v for v in x) / len(x)) or 1.0
        k = rms_to / rms
        m = max(abs(v) for v in x) * k
        if m > peak_cap:
            k *= peak_cap / m
        x = [v * k for v in x]
        # MV-555: the seamless loop plus its first LOOP_TAIL seconds again. Sound plays a loop as two players that
        # take turns and overlap over the tail (identical audio, so the crossfade is exact), which keeps beds on
        # the web's browser samples; the stream fallback loops over the first len - tail samples. No 'smpl' chunk.
        x = x + x[:n(LOOP_TAIL)]
    else:
        x = norm(x, peak)
        fi, fo = n(0.002), n(0.012)       # no click at the start or the cut-off end
        for i in range(min(fi, len(x))):
            x[i] *= i / fi
        for i in range(min(fo, len(x))):
            x[-1 - i] *= i / fo
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = b"".join(struct.pack("<h", max(-32767, min(32767, int(round(v * 32767))))) for v in x)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)
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


def scatter(sec, rnd, per_sec, make, g=(0.3, 1.0), wrap=True):
    x = zeros(sec)
    count = int(sec * per_sec)
    for _ in range(count):
        mix(x, make(rnd), rnd.randrange(len(x)), rnd.uniform(*g), wrap)
    return x


def crackle(sec, rnd, per_sec, fc=3500.0, g=(0.2, 1.0)):
    """sharp pops (demolish debris; cozy() dust when asked). MV-555: no weather loop uses it any more"""
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


def cozy(x, rnd, chord, pad=0.22, wobble=0.0018, dust=0.0):
    """MV-538 lo-fi treatment of a finished loop (exact length, seamless): a soft tonal pad in the biome's chord
    (whole cycles per loop, slow swells), tape wobble and a gentle saturation (MV-555: the vinyl dust is off by
    default; its random pops read as the sound breaking up). write() then rolls the
    top off at BED_FC. Everything wraps around the loop, so the seam stays clean."""
    L = len(x)
    rms = math.sqrt(sum(v * v for v in x) / L) or 1.0
    pd = [0.0] * L
    for m in chord:
        f = round(440.0 * 2 ** ((m - 69) / 12.0) * L / SR) * SR / L          # whole cycles per loop
        sw = rnd.randint(1, 3)                                               # swells per loop
        ph = rnd.uniform(0, math.tau)
        for i in range(L):
            amp = 0.55 + 0.45 * math.sin(math.tau * sw * i / L + ph)
            ang = math.tau * f * i / SR
            pd[i] += (math.sin(ang) + 0.18 * math.sin(2 * ang)) * amp / len(chord)
    prms = math.sqrt(sum(v * v for v in pd) / L) or 1.0
    y = [a + b * pad * rms / prms for a, b in zip(x, pd)]
    if dust > 0.0:
        mix(y, lp(crackle(L / SR, rnd, dust, 900, (0.05, 0.25)), 2500), 0, rms * 1.2)
    out, pos = [], 0.0
    cyc = rnd.randint(2, 4)
    for i in range(L):        # tape wobble: whole cycles over the loop, read with wrap-around
        j = int(pos)
        fr = pos - j
        out.append(y[j % L] * (1 - fr) + y[(j + 1) % L] * fr)
        pos += 1.0 + wobble * math.cos(math.tau * cyc * i / L)
    return [math.tanh(v / rms * 0.35) * rms / 0.35 for v in out]


def soft_mallet(rnd, f, sec=1.6, tau=0.45):
    """a far clank turned into a soft, round mallet knock on a pipe"""
    x = ping(f, sec, tau, 1.0, ((1.0, 1.0), (2.76, 0.25), (5.4, 0.06)))
    return lp(env_mul(x, lambda t: min(1.0, t / 0.006)), 1400)


def amb_industrial(rnd):
    """ruined factories: a warm low breeze, a muffled mains hum, far soft pipe knocks and a slow steam sigh"""
    L, F = 8.0, 0.6
    sec = L + F
    x = lp(wind(sec, rnd, 180, 450, 0.9, (0.3, 0.7)), 900)
    hum = [0.3 * math.sin(math.tau * 100 * i / SR) + 0.12 * math.sin(math.tau * 150 * i / SR) for i in range(n(sec))]
    mix(x, env_mul(hum, slow_lfo(sec, rnd, 2, 0.5, 1.0)), 0, 0.18)
    far = zeros(sec)
    for at, f in ((0.7, 196), (3.1, 262), (4.0, 220), (6.4, 175)):
        mix(far, soft_mallet(rnd, f), n(at), rnd.uniform(0.4, 0.8))
    sigh = env_mul(lp(bp(pink(n(1.8), rnd), 700, 0.8), 1500), lambda t: math.sin(math.pi * t / 1.8) ** 2)
    mix(far, sigh, n(5.2), 0.25)
    mix(x, verb(far, 0.55, 1.5, 0.8), 0, 0.55)
    return cozy(seam(x, F), rnd, [48, 55, 63], 0.22)            # C minor-ish: grey, a little melancholy


def amb_desert(rnd):
    """glass desert: a soft, warm breeze with slow gusts and fused-glass wind chimes far away"""
    L, F = 8.0, 0.8
    sec = L + F
    x = lp(wind(sec, rnd, 300, 800, 0.8, (0.25, 0.9), 0.3), 1300)
    mix(x, lp(bp(pink(n(sec), rnd), 1200, 0.6), 1800), 0, 0.03)      # sand whisper
    glass = zeros(sec)
    for _ in range(7):        # chimes in D pentatonic, round and low
        f = rnd.choice([587.3, 659.3, 740.0, 880.0, 987.8])
        chime = lp(ping(f, 1.6, 0.4, 1.0, ((1.0, 1.0), (2.0, 0.15))), 2000)
        mix(glass, env_mul(chime, lambda t: min(1.0, t / 0.01)), rnd.randrange(n(sec)), rnd.uniform(0.05, 0.1), True)
    mix(x, verb(glass, 0.55, 1.4, 0.8))
    return cozy(seam(x, F), rnd, [50, 57, 62, 66], 0.2)         # D major: warm sun


def amb_forest(rnd):
    """overgrown forest: leaves, a small creek, soft far crickets and a crow far off in the trees"""
    L, F = 8.0, 0.6
    sec = L + F
    x = gain(lp(hp(pink(n(sec), rnd), 250), 1500), 0.22)
    x = env_mul(x, slow_lfo(sec, rnd, 3, 0.3, 1.0, 0.1, 0.5))       # leaves
    creek = bp(brown(n(sec), rnd), lambda t: 500 + 200 * math.sin(t * 1.3), 1.5)
    mix(x, env_mul(creek, slow_lfo(sec, rnd, 3, 0.5, 1.0, 0.3, 0.9)), 0, 0.25)
    insects = zeros(sec)
    for _ in range(10):       # crickets, soft and distant
        c = rnd.uniform(2000, 2400)
        chirp = [math.sin(math.tau * c * i / SR) * (math.sin(math.pi * ((i / SR) * 28 % 1.0)) ** 2)
                 for i in range(n(3 / 28.0))]
        mix(insects, chirp, rnd.randrange(n(sec)), rnd.uniform(0.015, 0.035), True)
    mix(x, lp(verb(insects, 0.4), 2400))
    caw = osc(lambda t: 520 - 180 * t, 0.3, "tri")
    caw = lp(bp(env_mul(caw, lambda t: adsr(t, 0.03, 0.1, 0.3)), 1000, 1.5), 1300)
    mix(x, verb(caw + [0.0] * n(0.8), 0.6, 1.3), n(2.0), 0.06)
    return cozy(seam(x, F), rnd, [53, 60, 64, 69], 0.2)         # F major 7: green, gentle


def amb_swamp(rnd):
    """toxic bayou: slow water, round frog croaks, low plops and the soft hum of an insect swarm"""
    L, F = 8.0, 0.6
    sec = L + F
    x = gain(lp(brown(n(sec), rnd), 260), 0.35)                  # murky water
    for at in (0.4, 0.9, 3.3, 5.0, 5.4, 7.2):       # frogs: a pulsed croak, rounded off
        f0 = rnd.uniform(120, 160)
        croak = osc(f0, 0.38, "tri")
        croak = env_mul(croak, lambda t: (0.5 + 0.5 * math.sin(math.tau * 20 * t)) * adsr(t, 0.03, 0.15, 0.38))
        mix(x, lp(bp(croak, 380, 1.2), 700), n(at), rnd.uniform(0.3, 0.5))
    for _ in range(9):        # plops
        bub = osc(lambda t, f=rnd.uniform(150, 260): f * (1 + 3 * t), 0.09)
        mix(x, env_mul(bub, lambda t: adsr(t, 0.006, 0.025, 0.09)), rnd.randrange(n(sec)), rnd.uniform(0.08, 0.16), True)
    hum = [0.6 * math.sin(math.tau * 165 * i / SR) + 0.4 * math.sin(math.tau * 247.5 * i / SR + 0.7 * math.sin(math.tau * 5.5 * i / SR))
           for i in range(n(sec))]
    mix(x, env_mul(hum, slow_lfo(sec, rnd, 2, 0.0, 1.0, 0.1, 0.3)), 0, 0.03)
    return cozy(seam(x, F), rnd, [45, 52, 60], 0.22)            # A minor: murky, a bit sad


def amb_tundra(rnd):
    """frozen highway: a soft, low wind, faint ice crystals and a slow creak of ice"""
    L, F = 8.0, 0.8
    sec = L + F
    x = lp(wind(sec, rnd, 220, 520, 0.9, (0.3, 0.85), 0.25), 900)
    mix(x, gain(lp(wind(sec, rnd, 500, 900, 2.5, (0.0, 0.6), 0.2), 1200), 0.35))      # a faint, low whistle
    ice = zeros(sec)
    for _ in range(6):        # crystals tinkling in the wind, very soft
        mix(ice, lp(ping(rnd.choice([1047, 1175, 1319, 1568]), 0.8, 0.15), 2200), rnd.randrange(n(sec)), rnd.uniform(0.02, 0.05), True)
    mix(x, verb(ice, 0.6, 1.4, 0.8))
    cr = osc(lambda t, f=rnd.uniform(70, 95): f + 20 * math.sin(t * 30), 0.6, "tri")
    mix(x, lp(env_mul(cr, lambda t: math.sin(math.pi * t / 0.6)), 500), n(5.5), 0.15)
    return cozy(seam(x, F), rnd, [40, 47, 54, 59], 0.2)         # E minor add9: cold but calm


def amb_metro(rnd):
    """signal metropolis: a low city drone, a siren far away and a dead station's soft static and morse"""
    L, F = 8.0, 0.6
    sec = L + F
    x = [0.22 * math.sin(math.tau * 55 * i / SR) + 0.22 * math.sin(math.tau * 110.7 * i / SR)
         + 0.08 * math.sin(math.tau * 166 * i / SR) for i in range(n(sec))]
    mix(x, lp(wind(sec, rnd, 250, 500, 1.0, (0.2, 0.5)), 900), 0, 0.6)
    siren = osc(lambda t: 520 + 120 * math.sin(math.tau * 0.25 * t), sec)
    siren = env_mul(siren, lambda t: 0.5 - 0.5 * math.cos(math.tau * t / sec))
    mix(x, verb(lp(siren, 900), 0.85, 1.6, 0.82), 0, 0.04)
    radio = zeros(sec)
    for at in (1.2, 4.6):     # a dead station: warm static, then slow soft morse
        st = lp(bp(pink(n(0.6), rnd), 900, 0.8), 1500)
        mix(radio, env_mul(st, lambda t: math.sin(math.pi * t / 0.6)), n(at), 0.12)
        b = at + 0.7
        for d in rnd.sample([0.09, 0.09, 0.22, 0.09, 0.22], 5):
            beep = env_mul(osc(523.3, d), lambda t, d=d: min(1.0, t / 0.015, (d - t) / 0.015))
            mix(radio, beep, n(b), 0.045)
            b += d + 0.1
    mix(x, lp(verb(radio, 0.55), 1800))
    return cozy(seam(x, F), rnd, [43, 50, 58, 62], 0.2)         # G minor 7: neon night


# ------------------------------------------------------------------ weather (loops)
# MV-555 rework: rain is made of noise grains (tiny filtered noise bursts with a soft attack), not chirped sine
# droplets; those were 3 ms clicks by the hundred and read as crackle. Every layer has its own body for phone
# speakers and nothing above ~6 kHz is left bright.
def grain(rnd, f, q=1.5, tau=0.004, att=0.0008):
    """one drop / grain of sand: a tiny band of noise with a soft attack and a quick decay"""
    sec = att + tau * 6
    x = env_mul(white(n(sec), rnd), lambda t: min(1.0, t / att) * decay(max(0.0, t - att), tau))
    return bp(x, f, q)


def bubble(rnd, f=None, tau=0.03):
    """a drip into a puddle: a sine whose pitch rises as the bubble closes, with a soft attack (no click)"""
    f = f or rnd.uniform(500, 900)
    sec = tau * 6
    out = []
    for i in range(n(sec)):
        t = i / SR
        out.append(math.sin(math.tau * f * (1.0 + 2.5 * t / sec) * t) * min(1.0, t / 0.0015) * decay(t, tau))
    return out


def rain_bed(sec, rnd, amount=1.0, gust=None):
    """rain on the truck: a soft wash, a muffled roof body, dense fine patter, a few heavier taps on the roof and
    the odd drip; amount scales density and weight, gust (a function of time) swells it"""
    g = gust or slow_lfo(sec, rnd, 3, 0.75, 1.0, 0.04, 0.12)
    wash = lp(lp(hp(pink(n(sec), rnd), 450), 4800), 4800)
    body = lp(hp(pink(n(sec), rnd), 140), 900)          # the roof's drum-like body (phones need 120-400 Hz)
    x = [0.30 * w + 0.22 * amount * bo for w, bo in zip(wash, body)]
    patter = scatter(sec, rnd, 420 * amount, lambda r: grain(r, r.uniform(1800, 5200), 1.4, r.uniform(0.0015, 0.004)),
                     (0.05, 0.16))
    mix(x, lp(patter, 5500))
    taps = scatter(sec, rnd, 5 + 6 * amount, lambda r: grain(r, r.uniform(450, 1000), 3.0, r.uniform(0.012, 0.025),
                                                             0.0015), (0.10, 0.25))
    mix(x, taps)
    mix(x, scatter(sec, rnd, 0.7, lambda r: bubble(r), (0.06, 0.12)))
    return env_mul(x, g)


def w_overcast(rnd):
    """grey sky: a soft, slow breeze and a faint rustle of loose tarp and dry weeds"""
    L, F = 8.0, 0.6
    sec = L + F
    x = lp(wind(sec, rnd, 200, 500, 0.8, (0.3, 0.75)), 1100)
    rustle = env_mul(lp(hp(pink(n(sec), rnd), 700), 2600), slow_lfo(sec, rnd, 3, 0.0, 1.0, 0.1, 0.4))
    mix(x, rustle, 0, 0.05)
    return seam(x, F)


def w_rain(rnd):
    """steady rain on the roof: calm, even, a little ASMR"""
    L, F = 10.0, 0.8
    return seam(rain_bed(L + F, rnd, 1.0), F)


def w_storm(rnd):
    """a downpour pushed by gusts: the rain swells with the wind, the wind howls past the hull, a low rumble under it"""
    L, F = 12.0, 1.0
    sec = L + F
    gust = slow_lfo(sec, rnd, 3, 0.45, 1.0, 0.06, 0.22)
    x = rain_bed(sec, rnd, 1.9, lambda t: 0.6 + 0.4 * gust(t))
    howl = bp(pink(n(sec), rnd), lambda t: 260 + 520 * gust(t), 1.4)
    mix(x, env_mul(howl, lambda t: gust(t) ** 2), 0, 0.55)
    whistle = bp(pink(n(sec), rnd), lambda t: 650 + 380 * gust(t), 7.0)
    mix(x, env_mul(whistle, lambda t: max(0.0, gust(t) - 0.7) * 3.0), 0, 0.25)
    rumble = lp(brown(n(sec), rnd), 110)
    mix(x, rumble, 0, 0.35)
    mix(x, lp(bp(brown(n(sec), rnd), 200, 0.8), 400), 0, 0.25)
    return seam(x, F)


def w_sandstorm(rnd):
    """a wall of sand: a deep roar, sand hissing along the plates and grains rattling on the hull in each gust"""
    L, F = 10.0, 0.8
    sec = L + F
    gust = slow_lfo(sec, rnd, 3, 0.4, 1.0, 0.07, 0.3)
    x = env_mul(lp(brown(n(sec), rnd), 380), lambda t: 0.6 + 0.4 * gust(t))
    roar = bp(pink(n(sec), rnd), lambda t: 300 + 500 * gust(t), 0.8)
    mix(x, env_mul(roar, gust), 0, 0.6)
    hiss = lp(lp(hp(pink(n(sec), rnd), 1800), 5000), 5000)
    mix(x, env_mul(hiss, lambda t: gust(t) ** 1.5), 0, 0.10)
    grains = scatter(sec, rnd, 260, lambda r: grain(r, r.uniform(2200, 4800), 2.0, 0.0015, 0.0005), (0.03, 0.10))
    mix(x, env_mul(lp(grains, 5200), lambda t: gust(t) ** 2))
    gap = bp(pink(n(sec), rnd), lambda t: 900 + 250 * math.sin(t * 0.7), 8.0)      # wind through a hull gap
    mix(x, env_mul(gap, lambda t: max(0.0, gust(t) - 0.75) * 4.0), 0, 0.18)
    return seam(x, F)


def w_snow(rnd):
    """snowfall: hushed, a low soft wind, a faint airy shimmer and now and then a far, lonely gust"""
    L, F = 10.0, 0.8
    sec = L + F
    x = lp(wind(sec, rnd, 200, 450, 0.7, (0.25, 0.6), 0.15), 700)
    air = env_mul(lp(hp(pink(n(sec), rnd), 2500), 5500), slow_lfo(sec, rnd, 2, 0.3, 1.0, 0.05, 0.15))
    mix(x, air, 0, 0.018)
    far = bp(pink(n(sec), rnd), lambda t: 380 + 120 * math.sin(t * 0.5), 3.0)
    mix(x, env_mul(far, slow_lfo(sec, rnd, 2, 0.0, 1.0, 0.05, 0.12)), 0, 0.12)
    return seam(x, F)


def w_fog(rnd):
    """thick fog: almost still air, slow drips off the hull and a foghorn far away"""
    L, F = 10.0, 0.8
    sec = L + F
    x = lp(wind(sec, rnd, 120, 300, 0.7, (0.3, 0.7)), 400)
    mix(x, scatter(sec, rnd, 0.8, lambda r: bubble(r, r.uniform(550, 850), 0.035), (0.15, 0.3)))
    horn = [math.sin(math.tau * 98 * i / SR) + 0.5 * math.sin(math.tau * 147 * i / SR) + 0.25 * math.sin(math.tau * 196 * i / SR)
            for i in range(n(2.6))]
    horn = lp(env_mul(horn, lambda t: math.sin(math.pi * t / 2.6) ** 2), 450)
    mix(x, verb(horn + [0.0] * n(1.5), 0.75, 1.6, 0.8), n(5.0), 0.16, True)
    return seam(x, F)


def w_acid_rain(rnd):
    """acid rain: a lighter rain whose drops sizzle softly on the hot hull, a low simmer and acid pooling"""
    L, F = 10.0, 0.8
    sec = L + F
    x = gain(rain_bed(sec, rnd, 0.7), 0.85)
    simmer = env_mul(bp(pink(n(sec), rnd), 650, 0.9), slow_lfo(sec, rnd, 3, 0.3, 1.0, 0.15, 0.5))
    mix(x, simmer, 0, 0.22)
    def sizzle(r):          # a drop hissing on metal: a short, soft breath of noise that fades away
        d = r.uniform(0.3, 0.6)
        z = env_mul(pink(n(d), r), lambda t: min(1.0, t / 0.02) * decay(t, d / 3))
        return lp(bp(z, r.uniform(1600, 2600), 1.0), 4000)
    mix(x, scatter(sec, rnd, 2.5, sizzle, (0.10, 0.22)))
    mix(x, scatter(sec, rnd, 4, lambda r: bubble(r, r.uniform(260, 420), 0.02), (0.05, 0.10)))
    return seam(x, F)


def w_ashfall(rnd):
    """ash falling: a muffled low wind, a far fire breathing and a few soft ember pops"""
    L, F = 10.0, 0.8
    sec = L + F
    x = lp(wind(sec, rnd, 150, 380, 0.8, (0.3, 0.7)), 600)
    fire = env_mul(lp(brown(n(sec), rnd), 260), slow_lfo(sec, rnd, 3, 0.4, 1.0, 0.2, 0.8))
    mix(x, fire, 0, 0.35)
    pops = scatter(sec, rnd, 3, lambda r: grain(r, r.uniform(700, 1500), 2.0, 0.003, 0.001), (0.10, 0.25))
    mix(x, lp(pops, 2500))
    return seam(x, F)


# ------------------------------------------------------------------ one-shots
def sfx_thunder(rnd, crack=True):
    """MV-555: a near strike is a few rolling cracks (soft attack, nothing above ~3 kHz) into a long low roll with
    body at 200 Hz for phones; a far one is the roll alone"""
    sec = 5.5
    x = zeros(sec)
    if crack:
        at = 0.0
        for k in range(rnd.randint(3, 5)):
            tau = rnd.uniform(0.04, 0.09)
            c = env_mul(white(n(0.5), rnd), lambda t: min(1.0, t / 0.004) * decay(t, tau))
            mix(x, lp(bp(c, rnd.uniform(900, 2000), 0.7), 3000), n(at), 0.8 / (1 + k * 0.4))
            at += rnd.uniform(0.04, 0.12)
    roll = lp(brown(n(sec), rnd), 140)
    mix(roll, lp(bp(brown(n(sec), rnd), 220, 0.8), 450), 0, 0.6)
    lvl = slow_lfo(sec, rnd, 4, 0.25, 1.0, 0.5, 2.2)
    roll = env_mul(roll, lambda t: lvl(t) * adsr(t, 0.12 if crack else 0.5, 1.5, sec))
    mix(x, roll, n(0.05))
    return verb(x, 0.3, 1.6, 0.6)


def sfx_shot(rnd, heavy=False):
    sec = 0.5 if heavy else 0.28
    nz = env_mul(white(n(sec), rnd), lambda t: adsr(t, 0.002, 0.05 if heavy else 0.025, sec))
    nz = bp(nz, lambda t: 1500 * math.exp(-t * 12) + 300, 0.7)
    x = mix(nz, thump(rnd, 140 if heavy else 170, 50, sec, 0.3), 0, 1.0 if heavy else 0.7)
    return retro(lp(x, 3500), 10, 2)


def sfx_energy(rnd):
    x = osc(lambda t: 700 * math.exp(-t * 7) + 200, 0.25, "tri")
    return retro(env_mul(lp(x, 2000), lambda t: adsr(t, 0.004, 0.07, 0.25)), 10, 2)


def sfx_hit(rnd):
    return retro(thump(rnd, 160, 60, 0.18, 0.8), 9, 2)


def sfx_crit(rnd):
    x = thump(rnd, 200, 60, 0.3, 0.8)
    mix(x, env_mul(osc(1200, 0.25), lambda t: adsr(t, 0.003, 0.05, 0.25)), 0, 0.25)
    return retro(x, 10, 2)


def sfx_hit_metal(rnd):
    x = clank(rnd, 330, 0.6, 0.12)
    mix(x, thump(rnd, 120, 60, 0.2, 0.6), 0, 0.7)
    return retro(x, 10, 2)


def sfx_hit_hero(rnd):
    x = thump(rnd, 130, 70, 0.22, 0.5)
    grunt = bp(env_mul(osc(lambda t: 150 - 60 * t, 0.2, "saw"), lambda t: adsr(t, 0.01, 0.05, 0.2)), 700, 2)
    return retro(mix(x, grunt, 0, 0.5), 9, 2)


def sfx_enemy_die(rnd):
    sec = 0.6
    sq = env_mul(white(n(sec), rnd), lambda t: adsr(t, 0.01, 0.12, sec))
    sq = bp(sq, lambda t: 1600 * math.exp(-t * 6) + 150, 2.5)
    groan = bp(env_mul(osc(lambda t: 120 - 60 * t, sec, "saw"), lambda t: adsr(t, 0.03, 0.2, sec)), 500, 2)
    return retro(mix(sq, groan, 0, 0.6), 9, 2)


def sfx_heal(rnd):
    x = zeros(0.6)
    for k, f in enumerate((523.3, 659.3, 784.0, 1046.5)):
        mix(x, env_mul(osc(f, 0.25, "tri"), lambda t: decay(t, 0.08)), n(k * 0.07), 0.5)
    return retro(x, 8, 2)


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
    return retro(x, 10, 2)


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
    return retro(x, 10, 2)


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
    return retro(lp(x, 2500), 9, 2)


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


# ------------------------------------------------------------------ MV-555 cues: resources, road events, expeditions
def bell(f, sec, tau=0.35, vel=1.0):
    """a soft, round tone (sine + a little 2nd / 3rd) with a gentle attack: the cue voice, never shrill"""
    out = []
    for i in range(n(sec)):
        t = i / SR
        a = min(1.0, t / 0.006) * math.exp(-t / tau)
        out.append(vel * a * (math.sin(math.tau * f * t) + 0.25 * math.sin(math.tau * 2 * f * t) * math.exp(-t / (tau * 0.4))
                              + 0.06 * math.sin(math.tau * 3 * f * t)))
    return out


def steps(rnd, count, gap=0.22, start=0.0, sec=None, grow=0.0):
    """boots on gravel: soft bands of noise; grow > 0 makes them come closer, < 0 walk away"""
    sec = sec or start + count * gap + 0.2
    x = zeros(sec)
    for k in range(count):
        st = env_mul(white(n(0.1), rnd), lambda t: min(1.0, t / 0.003) * decay(t, 0.022))
        st = lp(bp(st, rnd.uniform(900, 1400), 0.8), 2500)
        mix(st, thump(rnd, 120, 70, 0.08, 0.2), 0, 0.5)
        lvl = max(0.15, min(1.0, 0.6 + grow * (k - count / 2) / count))
        mix(x, st, n(start + k * gap * rnd.uniform(0.92, 1.08)), 0.45 * lvl)
    return x


def sfx_res_gain(rnd):
    """resources in: a soft wooden pluck and a quiet fifth above (Sound varies the pitch, so it never repeats)"""
    x = bell(659.3, 0.3, 0.07)
    mix(x, bell(987.8, 0.25, 0.06), n(0.045), 0.45)
    mix(x, env_mul(lp(bp(white(n(0.03), rnd), 1800, 1.0), 3000), lambda t: decay(t, 0.006)), 0, 0.15)
    return lp(x, 3200)


def sfx_event_good(rnd):
    """road event went well: a warm rising C - E - G with a soft chord swelling under it"""
    x = zeros(1.4)
    for k, f in enumerate((523.3, 659.3, 784.0)):
        mix(x, bell(f, 1.0, 0.4, 0.55), n(k * 0.09))
    pad = [math.sin(math.tau * 261.6 * i / SR) + 0.6 * math.sin(math.tau * 392.0 * i / SR) for i in range(n(1.3))]
    mix(x, env_mul(pad, lambda t: math.sin(math.pi * min(1.0, t / 1.3)) ** 2), 0, 0.12)
    return lp(verb(x, 0.3, 1.2), 3200)


def sfx_event_bad(rnd):
    """road event went wrong: a muffled thud on the hull and two low notes falling a minor step, without alarm"""
    x = zeros(1.3)
    mix(x, thump(rnd, 120, 50, 0.35, 0.6), 0, 0.7)
    for k, f in enumerate((293.7, 261.6, 220.0)):
        tone = env_mul(osc(f, 0.6, "tri"), lambda t: adsr(t, 0.015, 0.22, 0.6))
        mix(x, lp(tone, 1000), n(0.12 + k * 0.22), 0.4)
    return lp(verb(x, 0.3, 1.3), 2200)


def sfx_exp_start(rnd):
    """team heads out: the hatch clunks open, boots walk away on gravel and a short radio check"""
    x = sfx_door(rnd) + [0.0] * n(1.4)
    mix(x, steps(rnd, 6, 0.2, 0.0, 1.4, -1.2), n(0.35))
    chirp = env_mul(lp(bp(pink(n(0.18), rnd), 1100, 0.9), 2200), lambda t: math.sin(math.pi * t / 0.18))
    mix(x, chirp, n(1.45), 0.35)
    mix(x, env_mul(osc(587.3, 0.09), lambda t: min(1.0, t / 0.006) * decay(t, 0.04)), n(1.6), 0.25)
    return x


def sfx_exp_encounter(rnd):
    """the team finds something: a burst of radio static, two low pulses and a suspended chord that waits"""
    x = zeros(1.6)
    st = env_mul(lp(bp(pink(n(0.3), rnd), 1000, 0.7), 2400), lambda t: math.sin(math.pi * t / 0.3))
    mix(x, st, 0, 0.45)
    for k in range(2):
        mix(x, thump(rnd, 110, 60, 0.25, 0.3), n(0.32 + k * 0.28), 0.55)
    for f in (220.0, 293.7, 329.6):        # A sus4: open, waiting for an answer
        tone = env_mul(osc(f, 1.1, "tri"), lambda t: min(1.0, t / 0.08) * decay(t, 0.45) * (1 - 0.25 * math.sin(math.tau * 6 * t)))
        mix(x, lp(tone, 1200), n(0.45), 0.18)
    return lp(verb(x, 0.3, 1.3), 2600)


def sfx_exp_home(rnd):
    """team back safe: boots coming closer, the hatch, and a warm two-note welcome"""
    x = steps(rnd, 5, 0.2, 0.0, 1.9, 1.2)
    mix(x, sfx_door(rnd), n(1.05), 0.8)
    mix(x, bell(523.3, 0.7, 0.3, 0.45), n(1.25))
    mix(x, bell(784.0, 0.6, 0.3, 0.4), n(1.37))
    return lp(x, 3200)


def sfx_exp_fail(rnd):
    """the mission failed: a slow, falling three-note phrase over a cold gust, then a heavy hatch"""
    x = zeros(1.9)
    gust = env_mul(bp(pink(n(1.4), rnd), lambda t: 500 - 200 * t, 1.2), lambda t: math.sin(math.pi * t / 1.4) ** 2)
    mix(x, gust, 0, 0.25)
    for k, f in enumerate((246.9, 220.0, 174.6)):
        tone = env_mul(osc(f, 0.7, "tri"), lambda t: adsr(t, 0.03, 0.3, 0.7))
        mix(x, lp(tone, 900), n(0.1 + k * 0.3), 0.4)
    mix(x, thump(rnd, 90, 45, 0.4, 0.5), n(1.2), 0.55)
    return lp(verb(x, 0.35, 1.4), 2000)


def sfx_exp_loot(rnd):
    """haul unpacked: a bag dropped on the deck, cans and parts clinking out of it and a small bright sparkle"""
    x = zeros(1.2)
    bag = env_mul(lp(bp(pink(n(0.3), rnd), 900, 0.7), 2000), lambda t: math.sin(math.pi * t / 0.3))
    mix(x, bag, 0, 0.45)
    mix(x, thump(rnd, 100, 60, 0.2, 0.6), n(0.05), 0.5)
    at = 0.22
    for _ in range(4):
        f = rnd.uniform(1100, 1900)
        mix(x, lp(ping(f, 0.25, 0.04, 1.0, ((1.0, 1.0), (2.4, 0.35), (4.1, 0.1))), 3200), n(at), rnd.uniform(0.18, 0.3))
        at += rnd.uniform(0.07, 0.12)
    for k, f in enumerate((1046.5, 1318.5)):
        mix(x, bell(f, 0.45, 0.15, 0.25), n(0.7 + k * 0.07))
    return lp(x, 3400)


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
    # MV-555: no vinyl hiss or dust crackle any more (Parames: it sounded like the speaker breaking up)
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
    out = lp(out, 4200)           # warm, rolled-off top (MV-555: no tanh drive, write() levels it cleanly)
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
    "res_gain": ("sfx", sfx_res_gain, False),
    "event_good": ("sfx", sfx_event_good, False),
    "event_bad": ("sfx", sfx_event_bad, False),
    "exp_start": ("sfx", sfx_exp_start, False),
    "exp_encounter": ("sfx", sfx_exp_encounter, False),
    "exp_home": ("sfx", sfx_exp_home, False),
    "exp_fail": ("sfx", sfx_exp_fail, False),
    "exp_loot": ("sfx", sfx_exp_loot, False),
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
        # MV-538: the biome beds get a warmer top (lo-fi) than effects and weather
        # MV-555: the title music has more peak room than a bed, since it plays alone over a quiet bed
        write(os.path.join(ROOT, folder, name + ".wav"), x, loop,
              fc=BED_FC if folder == "amb" and name != "engine" else 6500.0, peak_cap=0.6 if folder == "music" else 0.42)


if __name__ == "__main__":
    main()
