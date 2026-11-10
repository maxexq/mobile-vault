# MV-763: cut the APPROVED ambulance exterior mods (MV-731, /mnt/project-files/designs/vehicle-upgrades/ext/approved/)
# into game layers for ShellMods: assets/vehicles/ambulance_v3/mods/<mod>_L<n>[_f<floors>].png (trimmed RGBA) + mods.json.
# The approved canvases are crops of the 2026-11-09 shell (git 228bdbe) with an opaque backdrop (38,36,42); a part is
# every pixel that differs from that old crop (specks dropped, holes inside a part filled). Positions are shell_f1 pixels;
# "body" parts move down 112 px per floor above 1, "roof" parts stay. RULE (Parames): no part may cover a wheel at any
# floor count, so body layers that reach a wheel get one clipped file per floor count ("<n>@<floors>": [x, y, "file"]).
# Off-road wheels: 48-frame spin strips (perfectly round sprite rotated in code) for AmbulanceMotion + per-floor still
# layers for the v3 interior (behind the body, hub raised so the tyre stands on the road).
#   python3 tools/art/ambulance_mods/build.py [--preview <dir>]
import json, os, subprocess, sys, io
import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
A = "/mnt/project-files/designs/vehicle-upgrades/ext/approved/"
SRC = os.path.join(REPO, "tools/art/ambulance_mods/src/")       # approved canvases copied into the repo
V = os.path.join(REPO, "assets/vehicles/ambulance_v3/")
OUT = V + "mods/"
BG = (38, 36, 42)
OLD = "228bdbe"            # shell the parts were painted on
DECK = 112
FLOORS = (1, 2, 3, 4, 5)
CLEAR = 2.0                # px kept free around every tyre
# id: (approved file stem, crop box of shell_f1 (x0, y0, x1, y1), left pad, anchor, levels, base) ; base "front" = front_stock
PARTS = {
    "spike_ram":    ("spike_ram", (0, 96, 176, 240), 48, "body", (1, 2, 3), "front"),
    "roof_turret":  ("roof_turret", (420, 0, 638, 110), 0, "roof", (1, 2, 3), "shell"),
    "armor_plates": ("armor_plates", (140, 60, 460, 216), 0, "body", (1, 2, 3), "shell"),
    "fuel_tanks":   ("fuel_tanks", (240, 150, 500, 240), 0, "body", (1, 2, 3), "shell"),
    "rad_shield":   ("rad_shield", (0, 80, 160, 210), 0, "body", (1, 2), "shell"),
    "suspension":   ("suspension", (450, 176, 546, 240), 0, "body", (1, 2, 3), "shell"),
}
WHEEL_HUB = (496.5, 217.5)  # the wheel the suspension canvas was drawn on
ROOF_SPLIT = 120            # armor rows above this shell y (f1) are the roof band: they stay on the roof
OFFROAD_R = {1: 23.0, 2: 24.5, 3: 26.0}
SPIN_N = 48
FUEL_FIT = {1: 3, 2: 2, 3: 1, 4: 1, 5: 1}   # tanks that fit between the wheels (README)


def src(name):
    p = SRC + name + ".png"
    if not os.path.exists(p):
        os.makedirs(SRC, exist_ok=True)
        Image.open(A + name + ".png").convert("RGBA").save(p)
    return Image.open(p).convert("RGBA")


def old_shell(n):
    data = subprocess.check_output(["git", "-C", REPO, "show", f"{OLD}:assets/vehicles/ambulance_v3/shell_f{n}.png"])
    return Image.open(io.BytesIO(data)).convert("RGBA")


def canvas_base(box, pad, size, kind):
    if kind == "front":
        return src("front_stock")
    b = Image.new("RGBA", size, BG + (255,))
    b.alpha_composite(old_shell(1).crop(box), (pad, 0))
    return b


def label(m):
    """4-connected components -> (labels array, count)"""
    h, w = m.shape
    lab = np.zeros((h, w), np.int32); n = 0
    for y in range(h):
        for x in range(w):
            if m[y, x] and not lab[y, x]:
                n += 1; st = [(y, x)]; lab[y, x] = n
                while st:
                    cy, cx = st.pop()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        yy, xx = cy + dy, cx + dx
                        if 0 <= yy < h and 0 <= xx < w and m[yy, xx] and not lab[yy, xx]:
                            lab[yy, xx] = n; st.append((yy, xx))
    return lab, n


def part_mask(a, b, tol=30, speck=6):
    pa = np.asarray(a).astype(int); pb = np.asarray(b).astype(int)
    d = np.abs(pa[..., :3] - pb[..., :3]).sum(-1) > tol
    d &= ~(np.abs(pa[..., :3] - np.array(BG)).sum(-1) <= 6)          # backdrop is never part of a part
    lab, n = label(d)
    for i in range(1, n + 1):                                        # drop specks
        if (lab == i).sum() < speck:
            d[lab == i] = False
    # fill holes: non-part pixels not reachable from the canvas border, plus 1 px gaps between part pixels
    lab, n = label(~d)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    for i in range(1, n + 1):
        if i not in border and (lab == i).sum() < 400:
            d[lab == i] = True
    return d


def cut(stem, L, box, pad, kind):
    a = src(f"{stem}_L{L}")
    m = part_mask(a, canvas_base(box, pad, a.size, kind))
    arr = np.asarray(a).copy(); arr[~m] = 0
    return Image.fromarray(arr), (box[0] - pad, box[1])      # canvas origin in shell_f1 px


def wheels(n):
    f = json.load(open(V + "anim.json"))["floors"][str(n)]
    return [tuple(w) for w in f["wheels"]], float(f["wheel_r"])


def clip_wheels(im, ox, oy, n, r_extra=0.0):
    """clear the part's pixels over any tyre disc (+CLEAR) of the n-floor shell; (ox, oy) = layer origin in shell px"""
    ws, r = wheels(n)
    arr = np.asarray(im).copy(); h, w = arr.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    for (cx, cy) in ws:
        dd = np.hypot(xs + ox + 0.5 - cx, ys + oy + 0.5 - cy)
        arr[dd <= r + CLEAR + r_extra] = 0
    return Image.fromarray(arr)


def trim(im, ox, oy):
    bb = im.getbbox()
    if bb is None:
        return None, 0, 0
    return im.crop(bb), ox + bb[0], oy + bb[1]


def lay_out(meta, mid, L, n_variants, save):
    """save per-floor variants; identical clipped layers share one file"""
    files = {}
    for n, (im, x, y) in n_variants.items():
        key = im.tobytes() + bytes(str(im.size), "ascii")
        if key not in files:
            files[key] = f"{mid}_L{L}" if not files else f"{mid}_L{L}_f{n}"
            save(im, files[key])
        stem = files[key]
        meta.setdefault(mid, {})
        if n == 1:
            meta[mid][str(L)] = [x, y] if stem == f"{mid}_L{L}" else [x, y, stem]
        else:
            base = meta[mid][str(L)]
            want = [x, y - (DECK * (n - 1) if meta[mid]["anchor"] == "body" else 0)]
            if stem != f"{mid}_L{L}" or want != base[:2]:
                meta[mid][f"{L}@{n}"] = [x, y] + ([stem] if stem != f"{mid}_L{L}" else [])


def offroad(L):
    """perfectly round approved off-road wheel (64x64, centre 31.5) -> spin strip 64*SPIN_N x 64"""
    w = src(f"offroad_wheels_L{L}")
    strip = Image.new("RGBA", (64 * SPIN_N, 64), (0, 0, 0, 0))
    for i in range(SPIN_N):
        fr = w.rotate(-360.0 * i / SPIN_N, resample=Image.NEAREST, center=(32, 32))
        strip.alpha_composite(fr, (64 * i, 0))
    return w, strip


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png"):
            os.remove(OUT + f)
    meta = {"_deck_h": DECK, "_base_floors": 1}

    def save(im, stem):
        im.save(OUT + stem + ".png", optimize=True)

    for mid, (stem, box, pad, anchor, levels, kind) in PARTS.items():
        for L in levels:
            im, (ox, oy) = cut(stem, L, box, pad, kind)
            if mid == "suspension":
                continue
            if mid == "armor_plates":           # roof band (L3) stays on the roof, the lower plates ride with the body
                arr = np.asarray(im)
                top = arr.copy(); top[ROOF_SPLIT - oy:] = 0
                low = arr.copy(); low[:ROOF_SPLIT - oy] = 0
                t = trim(Image.fromarray(top), ox, oy)
                if t[0] is not None:
                    meta.setdefault("armor_roof", {"anchor": "roof"})
                    save(t[0], f"armor_roof_L{L}"); meta["armor_roof"][str(L)] = [t[1], t[2]]
                im = Image.fromarray(low)
            meta.setdefault(mid, {"anchor": anchor})
            if anchor == "roof":
                t = trim(im, ox, oy); save(t[0], f"{mid}_L{L}"); meta[mid][str(L)] = [t[1], t[2]]
                continue
            if mid == "fuel_tanks":            # never clipped: AmbulanceMods shows only the tanks that fit (FUEL_FIT)
                t = trim(im, ox, oy); save(t[0], f"{mid}_L{L}"); meta[mid][str(L)] = [t[1], t[2]]
                for n in FLOORS:
                    if L <= FUEL_FIT[n]:
                        c = clip_wheels(t[0], t[1], t[2] + DECK * (n - 1), n)
                        assert c.tobytes() == t[0].tobytes(), (mid, L, n, "tank over a wheel")
                continue
            var = {}
            for n in FLOORS:
                dy = DECK * (n - 1)
                t = trim(clip_wheels(im, ox, oy + dy, n), ox, oy + dy)
                var[n] = t
            lay_out(meta, mid, L, var, save)
    # suspension: the approved shock (drawn on the wheel at WHEEL_HUB) copied onto every rear-body wheel
    for L in (1, 2, 3):
        im, (ox, oy) = cut("suspension", L, PARTS["suspension"][1], 0, "shell")
        t = trim(im, ox - WHEEL_HUB[0], oy - WHEEL_HUB[1])        # offset from the hub
        meta.setdefault("suspension", {"anchor": "body"})
        var = {}
        for n in FLOORS:
            ws, r = wheels(n)
            hs = [w for w in ws if w[0] > 200]                   # cab wheel has its own leaf spring + fender
            x0 = int(min(w[0] for w in hs) + t[1]); y0 = int(hs[0][1] + t[2])
            x1 = int(max(w[0] for w in hs) + t[1] + t[0].width)
            lay = Image.new("RGBA", (x1 - x0, t[0].height), (0, 0, 0, 0))
            for (cx, cy) in hs:
                lay.alpha_composite(t[0], (int(cx + t[1]) - x0, 0))
            var[n] = (lay, x0, y0)
        lay_out(meta, "suspension", L, var, save)
    # fuel overflow rack on the rear wall (f2: 1 drum, f3+: 2 drums)
    rk = src("fuel_rack")
    sh3 = old_shell(3); h3 = sh3.height
    b = Image.new("RGBA", rk.size, BG + (255,)); b.alpha_composite(sh3.crop((520, h3 - 150, 638, h3)))
    m = part_mask(rk, b)
    arr = np.asarray(rk).copy(); arr[~m] = 0
    full = Image.fromarray(arr)
    t2 = trim(full, 520, h3 - 150 - DECK * 2)               # f1-relative y
    ys = np.where(np.asarray(t2[0])[..., 3].any(1))[0]
    meta["fuel_rack"] = {"anchor": "body"}
    save(t2[0], "fuel_rack_L2"); meta["fuel_rack"]["2"] = [t2[1], t2[2]]
    one = np.asarray(t2[0]).copy(); one[: one.shape[0] // 2 - 1] = 0     # lower drum only
    t1 = trim(Image.fromarray(one), t2[1], t2[2])
    save(t1[0], "fuel_rack_L1"); meta["fuel_rack"]["1"] = [t1[1], t1[2]]
    # off-road wheels
    meta["offroad_wheels"] = {"anchor": "body", "spin": SPIN_N, "size": 64, "r": {str(k): v for k, v in OFFROAD_R.items()}}
    for L in (1, 2, 3):
        w, strip = offroad(L)
        strip.save(OUT + f"offroad_wheels_L{L}_spin.png", optimize=True)
        # still layer for the v3 interior: every tyre, hub raised by R-22.5 so it stands on the road, behind the body
        var = {}
        for n in FLOORS:
            ws, r = wheels(n)
            lift = OFFROAD_R[L] - r
            shell = Image.open(V + f"shell_f{n}.png").convert("RGBA")
            sa = np.asarray(shell)[..., 3] > 0
            hh, ww = sa.shape; ys_, xs_ = np.mgrid[0:hh, 0:ww]
            tyre = np.zeros_like(sa)
            for (cx, cy) in ws:
                tyre |= np.hypot(xs_ + 0.5 - cx, ys_ + 0.5 - cy) <= r + 0.5
            body = sa & ~tyre
            lay = Image.new("RGBA", (ww, hh), (0, 0, 0, 0))
            for (cx, cy) in ws:
                lay.alpha_composite(w, (int(round(cx - 32)), int(round(cy - lift - 32))))
            la = np.asarray(lay).copy(); la[body] = 0
            var[n] = trim(Image.fromarray(la), 0, 0)
        lay_out(meta, "offroad_wheels", L, var, save)
    meta["roof_turret"]["z"] = 1          # over the animated PixelLab pot row (AmbulanceMotion clip potsR)
    order = ["_deck_h", "_base_floors", "offroad_wheels"]   # wheels first: every other part draws over them
    meta = {k: meta[k] for k in order + [k for k in meta if k not in order]}
    json.dump(meta, open(OUT + "mods.json", "w"), indent=1)
    print(json.dumps({k: (v if k.startswith("_") else list(v.keys())) for k, v in meta.items()}))


if __name__ == "__main__":
    main()
