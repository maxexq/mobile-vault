"""MV-189: approved V2 scene art -> clean native production inputs in tools/art/v2/ (run by hand, not by
generate_pixel_art.py).

    python -I tools/art/v2_native.py <extracted handoff dir> [<id> ...]   # rebuild tools/art/v2/
    python -I tools/art/v2_native.py --verify                             # check the art contract

The handoff (v2-art-handoff.zip + v2-art-references-*.zip, extracted together) holds manifest.json, the
approved retro/ drafts and specs/. For every asset:
  * the high-resolution draft is snapped to that spec's master-palette names (nearest, no blending) and each
    native cell takes its most common colour from the inner part of the cell, so edges stay crisp;
  * isolated single pixels are folded into their neighbours;
  * interiors (256x100) are made to tile: the right edge is blended into the left one before snapping;
  * landmarks are fitted into the original sprite's bounding box (door x=30 and ground contact unchanged)
    and get the one-pixel ol0 rim back;
  * events/encounters get the generator's own crew / pet / enemy sprites and the player's mini truck pasted
    back at their original positions, so people keep the in-game 14x20 anatomy and the truck stays the
    crisp, readable subject instead of the draft's blurred figures.
The outputs are committed; generate_pixel_art.py uses them in place of the old procedural scenes
(common.v2_art), so a full regeneration can't bring the old art back.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from PIL import Image, ImageFilter
from art.common import PAL, V2_DIR, c, outline_alpha, quantize

BLUR = 0.33         # pre-blur of the draft, in native cells: evens out its texture so flat skies don't speckle
ALIGN = (8, 6)      # how far (x, y) a pasted sprite may move to sit on the draft's own drawing of it
# scenes where the draft's own creatures stay: it redrew and regrouped them, pasting the old ones doubles them
KEEP_DRAFT_CHARACTERS = {"bugs"}
SEAM_COLS = 6       # native columns blended at the right edge of an interior so it repeats cleanly


def palette_image(names):
    flat = []
    for n in names:
        flat += list(PAL[n][:3])
    img = Image.new("P", (1, 1))
    img.putpalette(flat + flat[:3] * (256 - len(names)))
    return img


def cell_mode(ref, w, h, names):
    rgba = ref.convert("RGBA")
    rgb = rgba.convert("RGB").filter(ImageFilter.GaussianBlur(BLUR * rgba.width / w))
    q = rgb.quantize(palette=palette_image(names), dither=Image.Dither.NONE)
    al = rgba.getchannel("A")
    W, H = q.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = out.load()
    for y in range(h):
        y0, y1 = y * H / h, (y + 1) * H / h
        for x in range(w):
            x0, x1 = x * W / w, (x + 1) * W / w
            bx0, by0 = int(x0 + (x1 - x0) * 0.2), int(y0 + (y1 - y0) * 0.2)
            box = (bx0, by0, max(bx0 + 1, int(x1 - (x1 - x0) * 0.2)), max(by0 + 1, int(y1 - (y1 - y0) * 0.2)))
            ac = al.crop(box).getcolors(1 << 16)
            if sum(n for n, v in ac if v >= 128) * 2 < sum(n for n, v in ac):
                continue
            i = max(q.crop(box).getcolors(1 << 16))[1] % len(names)
            px[x, y] = tuple(PAL[names[i]][:3]) + (255,)
    return out


def despeckle(img):
    """a pixel unlike all four neighbours, where three or more of them agree, takes their colour"""
    w, h = img.size
    src = img.copy().load()
    px = img.load()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            p = src[x, y]
            if p[3] == 0:
                continue
            ns = [src[x + 1, y], src[x - 1, y], src[x, y + 1], src[x, y - 1]]
            if p in ns:
                continue
            for q in ns:
                if ns.count(q) >= 3 and q[3]:
                    px[x, y] = q
                    break
    return img


def seamless(ref, w):
    """blend the right edge of the draft toward a copy of its left edge so the tile repeats"""
    ref = ref.convert("RGB")
    W, H = ref.size
    edge = round(W / w)            # some drafts have a dark frame line down their outer columns: drop it
    ref = ref.crop((edge, 0, W - edge, H))
    W = ref.width
    band = int(SEAM_COLS * W / w)
    left = ref.crop((0, 0, band, H))
    tail = ref.crop((W - band, 0, W, H))
    mask = Image.linear_gradient("L").rotate(90, expand=True).resize((band, H))   # 0 at left -> 255 at right
    mask = mask.transpose(Image.FLIP_LEFT_RIGHT)
    ref.paste(Image.composite(left, tail, mask), (W - band, 0))
    return ref


def fit_landmark(ref, orig):
    ob = orig.getchannel("A").point(lambda v: 255 if v else 0).getbbox()
    rb = ref.getchannel("A").point(lambda v: 255 if v > 127 else 0).getbbox()
    part = ref.crop(rb)
    canvas = Image.new("RGBA", orig.size, (0, 0, 0, 0))
    # scale the draft's footprint onto the original's: the cell sampler works on any source size
    return part, ob, canvas


def landmark(ref, orig, names):
    part, ob, canvas = fit_landmark(ref.convert("RGBA"), orig)
    body = cell_mode(part, ob[2] - ob[0], ob[3] - ob[1], [n for n in names if n != "ol0"])
    canvas.paste(body, (ob[0], ob[1]), body)
    canvas = despeckle(canvas)
    w, h = canvas.size
    m = canvas.getchannel("A").load()
    inner = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    src, dst = canvas.load(), inner.load()
    for y in range(h):
        for x in range(w):
            if m[x, y] and all(0 <= x + dx < w and 0 <= y + dy < h and m[x + dx, y + dy]
                               for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[x, y] = src[x, y]
    return outline_alpha(inner, c("ol0"))


# ------------------------------------------------------------------ character layer from the old generators
def record_characters():
    """run the scene generators with paste/save intercepted: {event file name: [(sprite, x, y), ...]}"""
    from art import common, events, encounters, extra
    found, cur = {}, []

    def rec_paste(dst, src, x, y):
        cur.append((src.copy(), int(x), int(y)))
        common.paste(dst, src, x, y)

    real_truck = events.mini_truck

    def rec_truck(img, x, y):
        # the player's truck is drawn straight onto the scene: draw it on its own layer and keep that
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        real_truck(layer, x, y)
        box = layer.getbbox()
        cur.append((layer.crop(box), box[0], box[1]))
        real_truck(img, x, y)

    def rec_save(img, path, q=True):
        found[os.path.splitext(os.path.basename(path))[0]] = list(cur)
        cur.clear()

    mods = (events, encounters, extra)
    keep = [(m, m.paste, getattr(m, "save", None)) for m in mods]
    try:
        events.mini_truck = rec_truck
        for m in mods:
            m.paste = rec_paste
            if hasattr(m, "save"):
                m.save = rec_save
        events.gen_events()
        encounters.gen_encounters()
        extra.gen_events_extra()
    finally:
        events.mini_truck = real_truck
        for m, p, s in keep:
            m.paste = p
            if s is not None:
                m.save = s
    return found


def align(img, spr, x, y):
    """the offset within ALIGN where the sprite's colours best match what the draft drew there"""
    sp, ip = spr.load(), img.load()
    pts = [(i, j, sp[i, j]) for j in range(spr.height) for i in range(spr.width) if sp[i, j][3]]
    best = None
    for dy in range(-ALIGN[1], ALIGN[1] + 1):
        for dx in range(-ALIGN[0], ALIGN[0] + 1):
            cost = 0
            for i, j, p in pts:
                X, Y = x + dx + i, y + dy + j
                if 0 <= X < img.width and 0 <= Y < img.height:
                    q = ip[X, Y]
                    cost += 2 * (p[0] - q[0]) ** 2 + 4 * (p[1] - q[1]) ** 2 + 3 * (p[2] - q[2]) ** 2
                else:
                    cost += 10 ** 6
            cost += (dx * dx + dy * dy) * len(pts) * 40      # prefer the original spot when it's a near tie
            if best is None or cost < best[0]:
                best = (cost, x + dx, y + dy)
    return best[1], best[2]


def build(entry, spec, ex, chars):
    w, h = entry["size"]
    names = spec["palette"]
    ref = Image.open(os.path.join(ex, entry["reference"]))
    if entry["category"] == "landmark":
        orig = Image.open(os.path.join(ex, entry["original"])).convert("RGBA")
        return landmark(ref, orig, names)
    if entry["category"] == "interior":
        ref = seamless(ref, w)
    img = despeckle(cell_mode(ref, w, h, names))
    name = os.path.splitext(os.path.basename(entry["target"]))[0]
    if name not in KEEP_DRAFT_CHARACTERS:
        drawn = img.copy()
        for spr, x, y in chars.get(name, []):
            spr = spr.convert("RGBA")
            img.paste(spr, align(drawn, spr, x, y), spr)
    return img.convert("RGB")


def colour_names(img):
    rev = {tuple(v[:3]): k for k, v in PAL.items()}
    return {rev.get(c[:3], str(c[:3])) for n, c in img.convert("RGBA").getcolors(1 << 16) if c[3]}


def convert(ex, only):
    man = json.load(open(os.path.join(ex, "manifest.json"), encoding="utf-8"))
    chars = record_characters()
    os.makedirs(V2_DIR, exist_ok=True)
    path = os.path.join(V2_DIR, "manifest.json")
    out = {e["id"]: e for e in json.load(open(path, encoding="utf-8"))} if os.path.exists(path) else {}
    for entry in man:
        if only and entry["id"] not in only:
            continue
        spec = json.load(open(os.path.join(ex, "specs", entry["id"] + ".json"), encoding="utf-8"))
        img = quantize(build(entry, spec, ex, chars).convert("RGBA"))   # exactly what generate_pixel_art.py writes
        img.save(os.path.join(V2_DIR, entry["id"] + ".png"), optimize=True)
        # colours outside the spec palette can only come from the original sprites pasted back on top
        extra = sorted(colour_names(img) - set(spec["palette"]))
        out[entry["id"]] = {"id": entry["id"], "category": entry["category"], "target": entry["target"],
                            "size": entry["size"], "reference_sha256": entry["reference_sha256"],
                            "palette": spec["palette"], "sprite_colours": extra}
        if entry["category"] == "landmark":
            # the old sprite's lowest row: some stand on the last row, some one above it
            orig = Image.open(os.path.join(ex, entry["original"])).convert("RGBA")
            out[entry["id"]]["ground_y"] = orig.getchannel("A").getbbox()[3] - 1
        print(entry["id"], img.size, ("+ sprite colours " + ", ".join(extra)) if extra else "")
    with open(path, "w", encoding="utf-8") as f:
        json.dump([out[k] for k in sorted(out)], f, indent=1)


def verify():
    """the art contract for the 49 integrated images; exits 1 on any failure"""
    from art.common import ROOT
    root = ROOT
    man = json.load(open(os.path.join(V2_DIR, "manifest.json"), encoding="utf-8"))
    regions = json.load(open(os.path.join(root, "assets", "atlas", "atlas.json")))
    atlas = Image.open(os.path.join(root, "assets", "atlas", "atlas.png")).convert("RGBA")
    fails = 0
    for e in man:
        errs = []
        img = Image.open(os.path.join(V2_DIR, e["id"] + ".png")).convert("RGBA")
        w, h = e["size"]
        if img.size != (w, h):
            errs.append(f"size {img.size}")
        alphas = {c[3] for n, c in img.getcolors(1 << 16)}
        if e["category"] == "landmark":
            if not alphas <= {0, 255}:
                errs.append(f"alpha not binary {sorted(alphas)}")
            g = e["ground_y"]
            if img.getchannel("A").getbbox()[3] - 1 != g:
                errs.append(f"ground contact moved off row {g}")
            if not any(img.getpixel((30, y))[3] for y in range(g - 5, g + 1)):
                errs.append("nothing at the door column x=30")
            x, y, rw, rh = regions[e["id"]][:4]
            game = atlas.crop((x, y, x + rw, y + rh))
        else:
            if alphas != {255}:
                errs.append(f"not opaque {sorted(alphas)}")
            game = Image.open(os.path.join(root, e["target"])).convert("RGBA")
        bad = colour_names(img) - set(e["palette"]) - set(e["sprite_colours"])
        if bad:
            errs.append(f"colours outside the palette {sorted(bad)}")
        if game.tobytes() != img.tobytes():
            errs.append(f"{e['target']} differs from tools/art/v2 (run generate_pixel_art.py)")
        if e["category"] == "interior":
            # the right edge must lead into the left one about as smoothly as neighbouring columns do
            def col_diff(a, b):
                return sum(sum(abs(p - q) for p, q in zip(img.getpixel((a, y))[:3], img.getpixel((b, y))[:3])) for y in range(h))
            steps = sorted(col_diff(x, x + 1) for x in range(w - 1))
            if col_diff(w - 1, 0) > steps[len(steps) * 9 // 10]:
                errs.append("visible seam where the tile repeats")
        fails += bool(errs)
        print(("FAIL " if errs else "ok   ") + e["id"] + (": " + "; ".join(errs) if errs else ""))
    print(f"{len(man)} images, {fails} failed")
    sys.exit(1 if fails else 0)


def main():
    if sys.argv[1:2] == ["--verify"]:
        verify()
    else:
        convert(sys.argv[1], set(sys.argv[2:]))


if __name__ == "__main__":
    main()
