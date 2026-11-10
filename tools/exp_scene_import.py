#!/usr/bin/env python3
"""MV-758: copy the 7 approved expedition interior scenes (MV-678 / MV-682) into the game (assets/exp/v2/).

    python3 tools/exp_scene_import.py [--src /mnt/project-files/designs]

Per kind (hospital, store, bunker, plant, lab, mine, ruins), from designs/exp-interior-<kind>/approved/:
- exp_<kind>.png      the 1536x200 still strip (loops horizontally, floor lip y=160, walkway y 146-159)
- exp_<kind>_amb.png  the ambient loop (lamp flicker, dust, sparks, drips ...) as an overlay atlas: only the pixels that
                      change in the approved 48-frame GIF, cut into small regions, one frame grid per region
- scenes.json         strip size, floor, hotspots (format 2: rect, action, stand, face, risk, yields) and the
                      overlay regions [x, y, w, h] in strip px + where each region's frame grid sits in the atlas
Re-run after any art change, then `godot --import` so the .import files exist.
"""
import argparse, json, os, sys
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "exp", "v2")
KINDS = ("hospital", "store", "bunker", "plant", "lab", "mine", "ruins")
THR = 10            # a pixel counts as animated in a frame when it differs from its resting colour by more than this
GAP = 8             # changed pixels closer than this join one overlay region
MAX_W = 4096        # WebGL2-safe atlas width
HOT_KEYS = ("id", "label", "rect", "action", "yields", "face", "risk", "kind", "stand")


def runs(v, gap):
    idx = np.where(v)[0]
    out = []
    if len(idx) == 0:
        return out
    s = p = int(idx[0])
    for i in idx[1:]:
        i = int(i)
        if i - p > gap:
            out.append((s, p + 1))
            s = i
        p = i
    out.append((s, p + 1))
    return out


def xy_cut(mask, x0, y0, x1, y1, out, axis=0, tried=0):
    """recursive XY cut: split on empty columns / rows (wider than GAP) until neither axis splits, so scattered dust
    and particles end up in small boxes instead of one huge one"""
    sub = mask[y0:y1, x0:x1]
    r = runs(sub.any(0) if axis == 0 else sub.any(1), GAP)
    if len(r) == 1:
        a, b = r[0]
        nx0, ny0, nx1, ny1 = (x0 + a, y0, x0 + b, y1) if axis == 0 else (x0, y0 + a, x1, y0 + b)
        if tried >= 1:
            out.append([nx0, ny0, nx1 - nx0, ny1 - ny0])
            return
        xy_cut(mask, nx0, ny0, nx1, ny1, out, 1 - axis, tried + 1)
        return
    for a, b in r:
        if axis == 0:
            xy_cut(mask, x0 + a, y0, x0 + b, y1, out, 1, 0)
        else:
            xy_cut(mask, x0, y0 + a, x1, y0 + b, out, 0, 0)


def gif_frames(gif_path):
    g = Image.open(gif_path)
    frames = []
    for i in range(g.n_frames):
        g.seek(i)
        frames.append(np.asarray(g.convert("RGB")).astype(np.int16))
    return frames, float(g.info.get("duration", 80)) / 1000.0


def amb_frames(src, strip, effects):
    """render the approved effects again with designs/exp-interior/amb.py (exact pixels, no GIF palette noise)"""
    sys.path.insert(0, os.path.join(src, "exp-interior"))
    import amb
    base = strip.convert("RGB")
    return [np.asarray(amb.render(base, effects, f)).astype(np.int16) for f in range(amb.T)], 1.0 / amb.FPS


def ambience(frames, dur, out_png):
    F = np.stack(frames)
    rest = np.median(F, axis=0)
    changed = np.abs(F - rest[None]).max(3) > THR          # (n, H, W)
    union = changed.any(0)
    regions = []
    xy_cut(union, 0, 0, union.shape[1], union.shape[0], regions)
    n = len(frames)
    # lay each region out as a grid of n frames, regions stacked top to bottom
    blocks, ay = [], 0
    for x, y, w, h in regions:
        cols = max(1, min(n, MAX_W // w))
        rows = (n + cols - 1) // cols
        blocks.append({"rect": [x, y, w, h], "at": [0, ay], "cols": cols})
        ay += rows * h
    aw = max(b["cols"] * b["rect"][2] for b in blocks) if blocks else 1
    atlas = np.zeros((max(1, ay), aw, 4), np.uint8)
    for b in blocks:
        x, y, w, h = b["rect"]
        for f in range(n):
            cx = (f % b["cols"]) * w
            cy = b["at"][1] + (f // b["cols"]) * h
            m = changed[f, y:y + h, x:x + w]
            atlas[cy:cy + h, cx:cx + w, :3] = F[f, y:y + h, x:x + w].astype(np.uint8)
            atlas[cy:cy + h, cx:cx + w, 3] = np.where(m, 255, 0)
    if atlas.shape[0] > MAX_W:
        raise SystemExit("ambience atlas too tall for WebGL2: " + out_png)
    Image.fromarray(atlas, "RGBA").save(out_png, optimize=True)
    return {"file": os.path.basename(out_png), "n": n, "fps": round(1.0 / dur, 3), "regions": blocks}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/mnt/project-files/designs")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    scenes = {}
    for k in KINDS:
        d = os.path.join(a.src, "exp-interior-%s" % k, "approved")
        strip = Image.open(os.path.join(d, "exp_%s_strip.png" % k)).convert("RGBA")
        strip.save(os.path.join(OUT, "exp_%s.png" % k), optimize=True)
        hs = json.load(open(os.path.join(d, "hotspots.json")))
        spec = json.load(open(os.path.join(d, "ambience.json")))
        particles = []
        if "effects" in spec:
            # MV-682 generic effects: whole-scene falling dust / ash is drawn by the game (ExpeditionFeedV2), the rest
            # becomes the overlay atlas
            particles = [e for e in spec["effects"] if e["type"] == "particles"]
            frames, dur = amb_frames(a.src, strip, [e for e in spec["effects"] if e["type"] != "particles"])
        else:
            frames, dur = gif_frames(os.path.join(d, "exp_%s_anim.gif" % k))   # hospital: own anim.py, GIF is exact enough
        amb = ambience(frames, dur, os.path.join(OUT, "exp_%s_amb.png" % k))
        amb["particles"] = [{q: e[q] for q in ("area", "n", "v", "col", "a", "seed") if q in e} for e in particles]
        fl = hs.get("floor", {})
        scenes[k] = {"file": "exp_%s.png" % k, "size": list(strip.size), "walkway": fl.get("walkway", [146, 159]),
                     "hotspots": [{q: h[q] for q in HOT_KEYS if q in h} for h in hs.get("hotspots", [])],
                     "amb": amb}
        print(k, strip.size, "hotspots", len(scenes[k]["hotspots"]), "amb regions", len(amb["regions"]))
    json.dump({"note": "MV-758 generated by tools/exp_scene_import.py, do not hand-edit", "scenes": scenes},
              open(os.path.join(OUT, "scenes.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
