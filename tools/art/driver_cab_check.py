"""MV-519 driving cabs: check the baked shells against the pre-change sprites (tools/art/driver_cab_ref/before).

  python tools/art/driver_cab_check.py

veh_<tier> / ext_<tier> must match the before sprites outside the cab footprint (the van: outside its window
polygon), the decal and its idle frames must stay in the spec palette with binary alpha (opaque except the van's
glass mask), and the baked window must equal the decal. Exits 1 on any failure.
"""
import json, os, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from art.common import PAL                                  # noqa: E402
from art.vehicles import DRIVER_CAB, VAN_GLASS              # noqa: E402

REF = os.path.join(ROOT, "tools", "art", "driver_cab_ref")
SPEC_EXTRA = {"van": ["blue2", "blue4"], "train": ["gray4"]}
BASE = ["ol0", "skin1", "skin3", "gray1", "gray3", "gray5", "snow0", "snow2", "cream2", "blue1", "wood1", "lamp1"]


def main():
    atlas = Image.open(os.path.join(ROOT, "assets", "atlas", "atlas.png")).convert("RGBA")
    regions = json.load(open(os.path.join(ROOT, "assets", "atlas", "atlas.json")))

    def sprite(name):
        x, y, w, h = regions[name]
        return atlas.crop((x, y, x + w, y + h))

    bad = 0
    for tier, d in DRIVER_CAB.items():
        ax, ay = d["at"]
        w, h = d["size"]
        mask = Image.new("L", (w, h), 255)
        if tier == "van":
            mask = Image.new("L", (w, h), 0)
            ImageDraw.Draw(mask).polygon(VAN_GLASS, fill=255)
        allowed = {tuple(int(PAL[n][i]) for i in range(3)) for n in BASE + SPEC_EXTRA.get(tier, [])}
        base = f"decal_{tier}_driver_cockpit"
        frames = [base] + [f"{base}_idle_{i}" for i in (1, 2, 3)]
        dec = sprite(base)
        for name in frames:
            im = sprite(name)
            cols = set()
            for yy in range(h):
                for xx in range(w):
                    p = im.getpixel((xx, yy))
                    want = 255 if mask.getpixel((xx, yy)) else 0
                    if p[3] != want:
                        print(f"FAIL {name}: alpha {p[3]} at {xx},{yy} (want {want})")
                        bad += 1
                    if p[3]:
                        cols.add(p[:3])
            if im.size != (w, h) or not cols <= allowed:
                print(f"FAIL {name}: size {im.size} / colours outside the spec palette {cols - allowed}")
                bad += 1
        for kind in ("veh", "ext"):
            now = sprite(f"{kind}_{tier}")
            was = Image.open(os.path.join(REF, "before", f"{kind}_{tier}.png")).convert("RGBA")
            diff = 0
            for yy in range(now.height):
                for xx in range(now.width):
                    lx, ly = xx - ax, yy - ay
                    inside = 0 <= lx < w and 0 <= ly < h and mask.getpixel((lx, ly))
                    if inside:
                        if now.getpixel((xx, yy)) != dec.getpixel((lx, ly)):
                            diff += 1
                    elif now.getpixel((xx, yy)) != was.getpixel((xx, yy)):
                        diff += 1
            if diff or now.size != (280, 300):
                print(f"FAIL {kind}_{tier}: {diff} pixels differ (size {now.size})")
                bad += 1
        print(f"{tier}: checked {', '.join(frames)} and veh/ext_{tier}")
    print("ok" if not bad else f"{bad} failures")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
