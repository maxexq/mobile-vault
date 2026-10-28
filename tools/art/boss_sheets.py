"""MV-558: pack an approved 128px biome boss (90 frames: chase / attack / death) into one game sheet.

Source: a character folder of the monster-roster-42 delivery (git-ignored, under tools/art/micro/previews/
monster-roster-42-v1/characters/<id>/) with frames/{chasing,attacking,died}/NN.png and manifest.json.
Output: assets/atlas/bosses/<id>.png (30 columns x 3 rows, one row per animation) + <id>.json read by
scripts/world/boss_art.gd. Every frame is cropped to the union bounding box of all 90 frames, so the
pivot (the feet on the road) stays the same pixel in every cell. Pixels are copied, never resampled.

    python tools/art/boss_sheets.py industrial_junk_colossus
    python tools/art/boss_sheets.py industrial_junk_colossus --src <character folder>
"""
import argparse, json, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "art", "micro", "previews", "monster-roster-42-v1", "characters")
OUT = os.path.join(ROOT, "assets", "atlas", "bosses")
# game animation name <- delivery action name
ANIMS = (("walk", "chasing"), ("attack", "attacking"), ("death", "died"))


def pack(char_id, src_dir):
    man = json.load(open(os.path.join(src_dir, "manifest.json"), encoding="utf-8"))
    frames = {}
    box = None
    for anim, action in ANIMS:
        a = man["animations"][action]
        imgs = [Image.open(os.path.join(src_dir, f["file"])).convert("RGBA") for f in a["frames"]]
        frames[anim] = (imgs, a)
        for im in imgs:
            alpha = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
            b = alpha.getbbox()
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    px, py = man["pivot"]
    box = (box[0], box[1], box[2], max(box[3], py))     # the cell always reaches the feet row
    cw, ch = box[2] - box[0], box[3] - box[1]
    cols = max(len(v[0]) for v in frames.values())
    sheet = Image.new("RGBA", (cw * cols, ch * len(ANIMS)), (0, 0, 0, 0))
    meta = {"id": char_id, "cell": [cw, ch], "pivot": [px - box[0], py - box[1]], "anims": {}}
    for row, (anim, _action) in enumerate(ANIMS):
        imgs, a = frames[anim]
        for i, im in enumerate(imgs):
            cell = im.crop(box)
            # binary alpha: the delivery is already binary, this only guards against stray soft pixels
            cell.putalpha(cell.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
            sheet.paste(cell, (i * cw, row * ch))
        d = a["durations_ms"]
        meta["anims"][anim] = {"row": row, "count": len(imgs), "fps": round(1000.0 / d[0], 3),
                               "loop": bool(a["loop"]), "hold_ms": int(d[-1]) if a.get("hold_last") else 0}
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, char_id + ".png"), optimize=True)
    with open(os.path.join(OUT, char_id + ".json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)
    print("%s: %dx%d cells, sheet %dx%d, pivot %s" % (char_id, cw, ch, sheet.width, sheet.height, meta["pivot"]))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("char_id")
    ap.add_argument("--src", help="character folder (default: the monster-roster-42-v1 delivery)")
    args = ap.parse_args()
    pack(args.char_id, args.src or os.path.join(SRC, args.char_id))
