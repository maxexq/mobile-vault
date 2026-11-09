"""MV-741 (Parames 21:14 "make sure there are no small pixel holes, whole vehicle"): fill every enclosed see-through
pocket of <= MAX px with its darkest opaque neighbour, and drop floating single pixels. Used by cleanup.py (shells, last step) and run once on the roof
part stills/strips + lantern still (python3 tools/art/ambulance/pinholes.py), frame by frame for strips."""
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as nd

MAX = 4


def fill(im, max_px=MAX):
    """in place; returns the number of pixels filled"""
    a = np.array(im)[:, :, 3] > 0
    lab, n = nd.label(np.pad(~a, 1, constant_values=True))
    out = lab[0, 0]; px = im.load(); W, H = im.size; done = 0
    for i, sl in enumerate(nd.find_objects(lab)):
        if i + 1 == out:
            continue
        ys, xs = np.nonzero(lab[sl] == i + 1)
        if len(ys) > max_px:
            continue
        pts = [(x + sl[1].start - 1, y + sl[0].start - 1) for y, x in zip(ys, xs)]
        for x, y in pts:
            nb = [px[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if 0 <= x + dx < W and 0 <= y + dy < H and px[x + dx, y + dy][3]]
            if nb:
                px[x, y] = min(nb, key=lambda q: q[0] + q[1] + q[2])[:3] + (255,); done += 1
    return done


def lone(im):
    """remove floating single pixels (no opaque 8-neighbour); returns how many"""
    px = im.load(); W, H = im.size; out = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and not any(px[x + dx, y + dy][3] for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy)
                                       and 0 <= x + dx < W and 0 <= y + dy < H):
                out.append((x, y))
    for x, y in out:
        px[x, y] = (0, 0, 0, 0)
    return len(out)


def clean(im):
    return lone(im) + fill(im)


def fill_strip(path, fw):
    im = Image.open(path).convert("RGBA"); n = im.width // fw; done = 0
    for i in range(n):
        fr = im.crop((i * fw, 0, i * fw + fw, im.height)); done += clean(fr); im.paste(fr, (i * fw, 0))
    im.save(path); return done


def fix_composites(D):
    """after cleanup.py + ambulance_anim.py: a clip frame drawn over its cut-out shell must not leave a pinhole at
    the clip's edge either; such pixels are filled in the frame itself (tools/art/ambulance/roof/<clip>_anim.png).
    Returns the number of pixels added; rerun tools/ambulance_anim.py afterwards to copy the strips."""
    meta = json.load(open(os.path.join(D, "anim.json"))); R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "roof")
    added = 0
    for n, f in meta["floors"].items():
        sh = Image.open(os.path.join(D, f"shell_f{n}.png")).convert("RGBA"); p = sh.load()
        strips = {c: Image.open(os.path.join(R, c + "_anim.png")).convert("RGBA") for c in f.get("clips", {})}
        for c, m in f.get("clips", {}).items():
            x0, y0, w, h = m["rect"]; q = strips[c].load()
            for y in range(h):
                for x in range(w):
                    if q[x, y][3]:
                        p[x0 + x, y0 + y] = (0, 0, 0, 0)
        for c, m in f.get("clips", {}).items():
            x0, y0, w, h = m["rect"]
            for i in range(m["frames"]):
                im = sh.copy()
                for c2, m2 in f["clips"].items():
                    a, b, w2, h2 = m2["rect"]; im.alpha_composite(strips[c2].crop((i * w2, 0, i * w2 + w2, h2)), (a, b))
                before = np.array(im)[:, :, 3] > 0; fill(im); after = np.array(im)[:, :, 3] > 0
                ys, xs = np.nonzero(after & ~before); sp = strips[c].load(); ip = im.load()
                for y, x in zip(ys, xs):
                    if x0 <= x < x0 + w and y0 <= y < y0 + h:
                        sp[i * w + x - x0, y - y0] = ip[x, y]; added += 1
        for c, s in strips.items():
            s.save(os.path.join(R, c + "_anim.png"))
    return added


if __name__ == "__main__":
    HERE = os.path.dirname(os.path.abspath(__file__)); R = os.path.join(HERE, "roof")
    meta = json.load(open(os.path.join(R, "roof.json")))
    for p, m in meta.items():
        st = os.path.join(R, p + "_still.png"); im = Image.open(st).convert("RGBA"); d = clean(im)
        if m.get("frames"):
            im.save(st); w = im.width
            s = Image.open(os.path.join(R, p + "_anim.png")).convert("RGBA"); s.paste(im, (0, 0)); s.save(os.path.join(R, p + "_anim.png"))
            d += fill_strip(os.path.join(R, p + "_anim.png"), w)
        else:
            im.save(st)
        print(p, "filled", d)
    lp = os.path.join(HERE, "lantern_still.png"); im = Image.open(lp).convert("RGBA"); print("lantern", fill(im)); im.save(lp)
    if "--composites" in sys.argv:
        print("composite edge pixels", fix_composites(os.path.join(HERE, "../../../assets/vehicles/ambulance_v3")))
