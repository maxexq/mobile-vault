#!/usr/bin/env python3
"""MV-775 icons B: every icon at the pixel size of the objects in the v3 rooms (switch icons_room16).

Icons v2 (MV-694) are 32 px drawn into 16 px slots, so their pixels are twice as fine as the v3 room art next to them.
This bakes each icon down to a native 16 px icon in the look of the furniture in the v3 rooms:
  - 2x2 box average (premultiplied) with a little contrast put back, alpha cut at half coverage;
  - pulled toward the rooms' muted light (saturation x0.82, value x0.94);
  - 8 colours per icon (median cut), so the shading reads as flat steps like the room objects;
  - a 1 px soot outline round the silhouette.
Sources: the 95 `ic2_*` regions of assets/atlas/atlas.png and the 20 gear set icons in assets/gear64/icons.png.
Writes assets/icons16/icons16.png (16 px cells, 16 per row) + icons16.json {"cell": 16, "cols": 16,
"icons": {"<name>": index}} where name is the icon name ("medkit") or "set_<piece>" ("set_hunter_weapon").
Hand-fixed or redrawn icons go in tools/art/icons16/<name>.png (16x16): they replace the converted one as they are.
Deterministic; re-run after any icons v2 / set icon change:  python3 tools/icons16_import.py [--sheet out.png]
"""
import colorsys, json, os, sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "icons16")
SOOT = (20, 17, 17, 255)
COLS = 16


def lum(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def room16(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    # premultiplied box average (no dark fringes from transparent pixels), alpha cut at half coverage
    pm = Image.new("RGBA", im.size)
    sp, pp = im.load(), pm.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = sp[x, y]
            pp[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)
    sm = pm.resize((16, 16), Image.BOX)
    out = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    o, q0 = out.load(), sm.load()
    for y in range(16):
        for x in range(16):
            r, g, b, a = q0[x, y]
            if a < 128:
                continue
            r, g, b = [min(255, int(t * 255 / a)) for t in (r, g, b)]
            h, sa, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            v = min(1.0, max(0.0, (v - 0.45) * 1.25 + 0.45))   # a little contrast back after the average
            r, g, b = [int(t * 255) for t in colorsys.hsv_to_rgb(h, min(1.0, sa * 0.9), v * 0.95)]
            o[x, y] = (r, g, b, 255)
    q = out.convert("RGB").quantize(8, method=Image.MEDIANCUT).convert("RGB").load()
    for y in range(16):
        for x in range(16):
            if o[x, y][3]:
                o[x, y] = q[x, y] + (255,)
    a = out.copy().load()
    for y in range(16):
        for x in range(16):
            if a[x, y][3] == 0:
                continue
            edge = any(not (0 <= x + dx < 16 and 0 <= y + dy < 16) or a[x + dx, y + dy][3] == 0
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge and lum(a[x, y]) > 45:
                o[x, y] = SOOT
    return out


def sources() -> list:
    atlas = Image.open(os.path.join(ROOT, "assets", "atlas", "atlas.png")).convert("RGBA")
    regions = json.load(open(os.path.join(ROOT, "assets", "atlas", "atlas.json")))
    src = []
    for k in sorted(regions):
        if k.startswith("ic2_"):
            x, y, w, h = regions[k]
            src.append((k[4:], atlas.crop((x, y, x + w, y + h))))
    g64 = os.path.join(ROOT, "assets", "gear64")
    sets = Image.open(os.path.join(g64, "icons.png")).convert("RGBA")
    for i, piece in enumerate(json.load(open(os.path.join(g64, "gear64.json")))["icons"]):
        src.append(("set_" + piece, sets.crop((32 * i, 0, 32 * i + 32, 32))))
    return src


def main() -> None:
    src = sources()
    rows = (len(src) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (16 * COLS, 16 * rows), (0, 0, 0, 0))
    index = {}
    fixed = os.path.join(ROOT, "tools", "art", "icons16")
    for i, (name, im) in enumerate(src):
        f = os.path.join(fixed, name + ".png")
        ic = Image.open(f).convert("RGBA") if os.path.exists(f) else room16(im)
        sheet.alpha_composite(ic, (16 * (i % COLS), 16 * (i // COLS)))
        index[name] = i
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "icons16.png"))
    json.dump({"cell": 16, "cols": COLS, "icons": index}, open(os.path.join(OUT, "icons16.json"), "w"), indent=1)
    print("ok", len(index), sheet.size)
    if "--sheet" in sys.argv:
        # review sheet: before (32 px into 16) over after (16 px), x4
        path = sys.argv[sys.argv.index("--sheet") + 1]
        n = len(src)
        per = 12
        rv = Image.new("RGBA", (per * 72 + 8, ((n + per - 1) // per) * 150 + 8), (26, 24, 28, 255))
        for i, (name, im) in enumerate(src):
            x, y = 8 + (i % per) * 72, 8 + (i // per) * 150
            rv.alpha_composite(im.resize((64, 64), Image.NEAREST), (x, y))
            rv.alpha_composite(room16(im).resize((64, 64), Image.NEAREST), (x, y + 70))
        rv.save(path)
        print("review", path)


if __name__ == "__main__":
    main()
