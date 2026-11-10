#!/usr/bin/env python3
"""MV-711: copy the approved / in-review v3 room art and the ref v3 crew into the game (assets/v3/).

    python3 tools/v3_import.py [--src /mnt/project-files/designs]

Rooms (144x96 per cell, Room guide v3): every level image L1..L3 (grow room: + growth stages, empty cell: 3 build
stages), the format 2 hotspots (walk floor, stand points, tap rects), an "idle" micro-animation overlay cut from the
room's idle GIF (only the pixels that change, so GIF palette noise never shows; no crew is baked into idle GIFs) and
the colours the crew blend needs (room tint, darkest colour). Crew: one sheet per character, 64x64 frames, one row
per clip (frames[1:-1] already dropped in the approved folders). Writes assets/v3/rooms.json + assets/v3/crew.json.
Re-run after any art change (no auto sync), then open the editor once (or `godot --import`) so .import files exist.
"""
import argparse, glob, json, os, shutil, sys
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "v3")
RP = "room-redesign-preview/"
LV = ("L1", "L2", "L3")

# game room type -> source set. status: approved = Parames approved / Done, review = finished set still In Review
ROOMS = {
    "quarters":    dict(status="approved", ticket="MV-614", files=[RP + "rest/out/rs_B_7_0.png", RP + "rest/out/rs_L2_s1_0.png", RP + "rest/out/rs_L3_s1_0.png"]),
    "kitchen":     dict(status="approved", ticket="MV-620", files=[RP + "kitchen_v3/out/kv3_L%d.png"], hot=RP + "kitchen_v3/hotspots.json", idle=RP + "kitchen_v3/kv3_L%d_idle.gif"),
    "medical":     dict(status="approved", ticket="MV-617", files=[RP + "infirmary_v3/out/inf3_A_7_1.png", RP + "infirmary_v3/out/inf3_L2_s1_0.png", RP + "infirmary_v3/out/inf3_L3_s1_0.png"], hot=RP + "infirmary_v3/hotspots.json", idle=RP + "infirmary_v3/inf3_L%d_idle.gif"),
    "armory":      dict(status="approved", ticket="MV-609", files=[RP + "armory/out/ar_L1shabby_s2_0.png", RP + "armory/out/ar_L2_s1_0.png", RP + "armory/out/ar_L3_s2_0.png"], hot=RP + "armory/hotspots.json", idle=RP + "armory/ar_L%d_idle.gif"),
    "hydroponics": dict(status="review", ticket="MV-619", files=[RP + "grow3/final/grow_L%d.png"], stages=RP + "grow3/final/grow_L%d_stage%d.png", hot=RP + "grow3/hotspots.json", idle=RP + "grow3/gr3_L%d_idle.gif"),
    "water":       dict(status="review", ticket="MV-618", files=[RP + "water_v3/out/wv_L%d.png"], hot=RP + "water_v3/hotspots.json", idle=RP + "water_v3/wv_L%d_idle.gif"),
    "science":     dict(status="review", ticket="MV-625", files=[RP + "science_v3/out/sci3_L%d.png"], hot=RP + "science_v3/hotspots.json", idle=RP + "science_v3/sci3_L%d_idle.gif"),
    "radio":       dict(status="review", ticket="MV-623", files=[RP + "radio_v3/final/radio_L%d.png"], hot=RP + "radio_v3/hotspots.json", idle=RP + "radio_v3/rad3_L%d_idle.gif"),
    "refinery":    dict(status="review", ticket="MV-626", files=[RP + "distill_v3/final/refinery_L%d.png"], hot=RP + "distill_v3/hotspots.json", idle=RP + "distill_v3/ds3_L%d_idle.gif"),
    "workshop":    dict(status="review", ticket="MV-624", files=[RP + "workshop_v3/final/workshop_L%d.png"], hot=RP + "workshop_v3/hotspots.json", idle=RP + "workshop_v3/ws3_L%d_idle.gif"),
    # MV-716: rear gunner post (MV-705 art), the default rear room; idle overlay from the crew-free idle render (_room.gif)
    "rear_gunner": dict(status="approved", ticket="MV-705", files=[RP + "gunner_v3/final/gunner_L%d.png"], hot=RP + "gunner_v3/final/hotspots.json", idle=RP + "gunner_v3/gunner3_L%d_idle_room.gif"),
}
EMPTY = dict(status="review", ticket="MV-621", files=[RP + "empty3/final/empty_stage%d.png"], hot=RP + "empty3/hotspots.json", idle=RP + "empty3/em3_s%d_idle.gif")

# ref v3 crew (MV-669..700, all approved): id -> folder; Ren has no idle clip (his still is the idle)
CREW = {"ren": "medic-25d-walk/approved", "clara": "clara-25d/approved"}
for _c in ("bit", "wan", "sorn", "lin", "tham", "fah", "krai", "ploy", "noi"):
    CREW[_c] = "lore-crew-3/approved/" + _c
# MV-722: approved v3 portraits (MV-708, 64x64 busts, v2 portrait style) -> assets/v3/portraits/<id>.png
PORTRAITS = "crew-portraits-v3/approved"
# MV-735: approved mood faces <id>_<mood>.png -> assets/v3/portraits/<id>_<mood>.png, crew.json "portrait_moods"
MOODS_DIR = "crew-portraits-v3/expr/approved"
MOODS = ("happy", "stressed", "injured", "surprised", "angry", "sad", "scared", "thinking", "talking", "tired", "sick",
         "point_left", "point_right", "point_up", "finger_up")
CLIPS = ["idle", "walk", "work", "construct", "eat", "drink", "talk", "carrywalk", "shoot"]   # shoot: MV-716 gunner post
CLIP_FPS = {"idle": 6, "walk": 10, "work": 8, "construct": 8, "eat": 6, "drink": 6, "talk": 6, "carrywalk": 10, "shoot": 10}
IDLE_FRAMES = 36          # idle overlay frames kept (of 96-144), played at IDLE_FPS
IDLE_COLS = 6


def src_path(src, pat, *a):
    p = os.path.join(src, pat % a if "%" in pat else pat)
    if not os.path.exists(p):
        sys.exit("missing source: " + p)
    return p


def colours(im):
    """room tint (mean colour / its grey, for the crew multiply) + darkest colour (crew outline) + brightest x (lamp)"""
    a = np.asarray(im.convert("RGB")).astype(float)
    mean = a.reshape(-1, 3).mean(0)
    tint = mean / max(mean.mean(), 1.0)
    tint = tint / tint.max()
    luma = a @ [0.299, 0.587, 0.114]
    flat = a.reshape(-1, 3)[np.argsort(luma.reshape(-1))[: max(1, luma.size // 200)]].mean(0)
    upper = luma[:60]
    lamp_x = int(np.argmax(np.convolve(upper.max(0), np.ones(9) / 9, "same")))
    return [round(float(v), 3) for v in tint], [int(v) for v in flat], lamp_x


def idle_overlay(gif, still, out_png):
    st = np.asarray(still.convert("RGBA")).astype(int)
    im = Image.open(gif)
    n = im.n_frames
    idx = [int(i * n / IDLE_FRAMES) for i in range(IDLE_FRAMES)]
    frames = []
    for i in idx:
        im.seek(i)
        f = np.asarray(im.convert("RGBA").resize(still.size, Image.NEAREST)).astype(int)
        f[..., 3] = np.where(np.abs(f[..., :3] - st[..., :3]).max(2) > 40, 255, 0)
        frames.append(f)
    mask = np.zeros(st.shape[:2], bool)
    for f in frames:
        mask |= f[..., 3] > 0
    if not mask.any():
        return None
    ys, xs = np.where(mask)
    x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    w, h = x1 - x0, y1 - y0
    rows = (len(frames) + IDLE_COLS - 1) // IDLE_COLS
    sheet = Image.new("RGBA", (w * IDLE_COLS, h * rows), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        sheet.paste(Image.fromarray(f[y0:y1, x0:x1].astype("uint8"), "RGBA"), ((k % IDLE_COLS) * w, (k // IDLE_COLS) * h))
    sheet.save(out_png)
    dur = float(im.info.get("duration", 80)) / 1000.0
    return {"file": os.path.basename(out_png), "rect": [x0, y0, w, h], "n": len(frames), "cols": IDLE_COLS,
            "fps": round(len(frames) / (n * dur), 3)}


def norm_floor(hs_img):
    fl = dict(hs_img.get("floor", {}))
    fl.setdefault("walk", [[0, 95], [0, 86], [143, 86], [143, 95]])
    fl.setdefault("walkway", [89, 95])
    return fl


DEFAULT_FLOOR = {"walk": [[0, 95], [0, 86], [143, 86], [143, 95]], "walkway": [89, 95], "depth": [86, 95]}


def room_entry(rtype, cfg, src, keys):
    d = os.path.join(OUT, "rooms", rtype)
    os.makedirs(d, exist_ok=True)
    hot = json.load(open(src_path(src, cfg["hot"]))) if cfg.get("hot") else {"images": {}}
    images = hot.get("images", {})
    levels = {}
    for i, key in enumerate(keys):
        n = i + 1
        pat = cfg["files"][i] if len(cfg["files"]) > 1 else cfg["files"][0]
        im = Image.open(src_path(src, pat, n)).convert("RGBA")
        if im.size != (144, 96):
            sys.exit("%s %s is %s, not 144x96" % (rtype, key, im.size))
        im.save(os.path.join(d, key + ".png"))
        tint, dark, lamp_x = colours(im)
        hs = images.get(key, {})
        e = {"file": key + ".png", "tint": tint, "dark": dark, "lamp_x": lamp_x,
             "floor": norm_floor(hs) if hs else DEFAULT_FLOOR,
             "hotspots": [{k: h[k] for k in ("id", "label", "rect", "kind", "action", "stand", "face", "needs_power") if k in h}
                          for h in hs.get("hotspots", [])]}
        if cfg.get("stages"):
            e["stages"] = []
            for s in (1, 2):
                Image.open(src_path(src, cfg["stages"], n, s)).convert("RGBA").save(os.path.join(d, "%s_stage%d.png" % (key, s)))
                e["stages"].append("%s_stage%d.png" % (key, s))
            e["stages"].append(key + ".png")   # the level image is the fully grown stage
        if cfg.get("idle"):
            g = os.path.join(src, cfg["idle"] % n)
            if os.path.exists(g):
                ov = idle_overlay(g, im, os.path.join(d, key + "_idle.png"))
                if ov:
                    e["idle"] = ov
        levels[key] = e
    return {"status": cfg["status"], "ticket": cfg["ticket"], "levels": levels}


def crew_entry(cid, folder, src):
    base = os.path.join(src, folder)
    clips, sheets = {}, []
    for c in CLIPS:
        fr = sorted(glob.glob(os.path.join(base, c, "*.png")), key=lambda p: int(os.path.splitext(os.path.basename(p))[0]))
        if not fr and c == "idle":
            fr = [os.path.join(base, "still.png")]
        if not fr:
            continue
        clips[c] = {"row": len(sheets), "n": len(fr), "fps": CLIP_FPS[c]}
        sheets.append([Image.open(p).convert("RGBA") for p in fr])
    w = max(len(s) for s in sheets) * 64
    if w > 4096:
        sys.exit("crew sheet too wide for WebGL2: " + cid)
    sheet = Image.new("RGBA", (w, 64 * len(sheets)), (0, 0, 0, 0))
    for r, s in enumerate(sheets):
        for k, f in enumerate(s):
            sheet.paste(f, (k * 64, r * 64))
    os.makedirs(os.path.join(OUT, "crew"), exist_ok=True)
    sheet.save(os.path.join(OUT, "crew", cid + ".png"))
    still = Image.open(os.path.join(base, "still.png")).convert("RGBA")
    still.save(os.path.join(OUT, "crew", cid + "_still.png"))
    return {"file": cid + ".png", "still": cid + "_still.png", "clips": clips}


def portraits(crew, src):
    """MV-722: copy each character's approved portrait and point crew.json at it (missing file = no portrait)"""
    os.makedirs(os.path.join(OUT, "portraits"), exist_ok=True)
    for cid, e in crew.items():
        p = os.path.join(src, PORTRAITS, cid + ".png")
        if not os.path.exists(p):
            e.pop("portrait", None)
            continue
        im = Image.open(p).convert("RGBA")
        if im.size != (64, 64):
            sys.exit("portrait must be 64x64: " + p)
        im.save(os.path.join(OUT, "portraits", cid + ".png"))
        e["portrait"] = "portraits/" + cid + ".png"
        moods = {}
        for m in MOODS:
            mp = os.path.join(src, MOODS_DIR, "%s_%s.png" % (cid, m))
            if not os.path.exists(mp):
                continue
            mi = Image.open(mp).convert("RGBA")
            if mi.size != (64, 64):
                sys.exit("portrait must be 64x64: " + mp)
            mi.save(os.path.join(OUT, "portraits", "%s_%s.png" % (cid, m)))
            moods[m] = "portraits/%s_%s.png" % (cid, m)
        if moods:
            e["portrait_moods"] = moods
        else:
            e.pop("portrait_moods", None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/mnt/project-files/designs")
    ap.add_argument("--portraits-only", action="store_true", help="only refresh the portraits in crew.json (MV-722)")
    a = ap.parse_args()
    if a.portraits_only:
        cj = os.path.join(OUT, "crew.json")
        data = json.load(open(cj))
        portraits(data["crew"], a.src)
        json.dump(data, open(cj, "w"), indent=1)
        print("portraits:", ", ".join(c for c, e in data["crew"].items() if "portrait" in e))
        return
    if os.path.isdir(os.path.join(OUT, "rooms")):
        shutil.rmtree(os.path.join(OUT, "rooms"))
    rooms = {t: room_entry(t, c, a.src, LV) for t, c in ROOMS.items()}
    empty = room_entry("empty", EMPTY, a.src, ("stage1", "stage2", "stage3"))
    json.dump({"note": "MV-711 generated by tools/v3_import.py, do not hand-edit", "cell": [144, 96],
               "rooms": rooms, "empty": empty}, open(os.path.join(OUT, "rooms.json"), "w"), indent=1)
    crew = {c: crew_entry(c, f, a.src) for c, f in CREW.items()}
    portraits(crew, a.src)
    json.dump({"note": "MV-711 generated by tools/v3_import.py; 64x64 frames, feet at row 63, shown at 2/3",
               "frame": [64, 64], "crew": crew}, open(os.path.join(OUT, "crew.json"), "w"), indent=1)
    print("rooms:", ", ".join("%s(%s)" % (t, r["status"]) for t, r in rooms.items()), "+ empty")
    print("crew:", ", ".join(crew))


if __name__ == "__main__":
    main()
