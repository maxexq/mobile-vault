#!/usr/bin/env python3
"""MV-740 Road train micro animations: anchors + tyre spin strip for the road train on the road (world v2).

Same format as tools/ambulance_anim.py (read by AmbulanceMotion with dir RT_DIR), written next to the shells:
  anim.json       "floors" = the body (tractor + lead trailer) per deck count, "trailer" = the container trailer per
                  deck count; each: wheel centres, landing legs (the inner leg + foot that cranks up / down),
                  headlight, tail / clearance lamps, searchlight, mast tip
  wheel_spin.png  24-frame strip (47x47 each) of one tyre rolling west (the cab faces west)
Run after designs/road-train/game/shell.py + tools/art/road_train/cleanup.py; the autotest checks anim.json against
the shell sizes. Code only, no PixelLab.
"""
import importlib.util, json, math, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DIR = os.path.join(ROOT, "assets", "vehicles", "road_train_v3")
spec = importlib.util.spec_from_file_location("amb", os.path.join(ROOT, "tools", "ambulance_anim.py"))
amb = importlib.util.module_from_spec(spec); spec.loader.exec_module(amb)
SIZE, SPIN_N, R = amb.SIZE, amb.SPIN_N, amb.WHEEL_R
CY = 22.5                          # tyre centre row = shell height - CY (contact patch on the bottom row)
# 2-deck shell px; rows of the chassis shift with the deck count (bottom-aligned), roof rows stay
BODY = {"wheels": (80.0, 252.0, 303.5, 556.5, 600.5, 643.5),
        "legs": [(336, 367, 22, 13)],              # lead trailer landing leg: inner leg + foot under the housing
        "head": (17.0, 320.0), "roof_lamps": [(325.0, 101.0), (432.5, 101.0), (562.5, 101.0), (671.0, 101.0)]}
TRAILER = {"wheels": (331.5, 377.5, 421.5),
           "legs": [(109, 365, 20, 15)],
           "tails": [(487.0, 296.5), (486.5, 342.5)], "search": (147.0, 41.0), "mast": (32.0, 1.0)}


def unit(kind, n, d):
    im = Image.open(os.path.join(DIR, f"{kind}_f{n}.png")); W, H = im.size
    dy = H - 380                                   # chassis rows move with the deck count
    s = {"size": [W, H], "wheels": [[x, H - CY] for x in d["wheels"]], "wheel_r": R,
         "legs": [[x, y + dy, w, h] for x, y, w, h in d["legs"]],
         "tails": [[x, y + dy] for x, y in d.get("tails", [])]}
    if "head" in d:
        s["head"] = [d["head"][0], d["head"][1] + dy]
    if "roof_lamps" in d:
        s["roof_lamps"] = [list(p) for p in d["roof_lamps"]]
    if "search" in d:
        s["search"] = list(d["search"]); s["mast"] = list(d["mast"])
    return s


def spin_strip():
    im = Image.open(os.path.join(DIR, "body_f2.png")).convert("RGBA")
    cx, cy = 643.5, 380 - CY                       # the last tyre of the lead trailer: only the mudflap behind it
    c = SIZE / 2
    src = im.crop((int(cx - c), int(cy - c), int(cx - c) + SIZE, int(cy - c) + SIZE)); sp = src.load()
    disc = Image.new("RGBA", (SIZE, SIZE)); dp = disc.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if (x + 0.5 - c) ** 2 + (y + 0.5 - c) ** 2 <= R ** 2:
                # the top of the tyre hides under the chassis rail: mirror the clean lower tread up there
                q = sp[x, SIZE - 1 - y] if y < c - 13 else sp[x, y]
                dp[x, y] = q[:3] + (255,) if q[3] else (20, 18, 18, 255)
    out = Image.new("RGBA", (SIZE * SPIN_N, SIZE)); k = 8
    up = disc.resize((SIZE * k, SIZE * k), Image.NEAREST)
    for i in range(SPIN_N):
        rot = up.rotate(360.0 * i / SPIN_N, resample=Image.NEAREST, center=(SIZE * k / 2, SIZE * k / 2)).load()
        fr = Image.new("RGBA", (SIZE, SIZE)); fp = fr.load()
        for y in range(SIZE):
            for x in range(SIZE):
                if not dp[x, y][3]:
                    continue
                if math.hypot(x + 0.5 - c, y + 0.5 - c) > R - 1.5:
                    fp[x, y] = dp[x, y]; continue
                votes = {}
                for yy in range(y * k + 1, y * k + k, 2):
                    for xx in range(x * k + 1, x * k + k, 2):
                        q = rot[xx, yy]
                        if q[3]:
                            votes[q] = votes.get(q, 0) + 1
                fp[x, y] = max(votes, key=votes.get) if votes else dp[x, y]
        out.paste(fr, (SIZE * i, 0))
    out.save(os.path.join(DIR, "wheel_spin.png"))


if __name__ == "__main__":
    meta = {"wheel_size": SIZE, "spin_frames": SPIN_N, "floors": {}, "trailer": {}}
    for n in (1, 2, 3):
        meta["floors"][str(n)] = unit("body", n, BODY)
    for n in (2, 3):
        meta["trailer"][str(n)] = unit("trailer", n, TRAILER)
    json.dump(meta, open(os.path.join(DIR, "anim.json"), "w"), indent=1)
    spin_strip()
    print("wrote anim.json + wheel_spin.png")
