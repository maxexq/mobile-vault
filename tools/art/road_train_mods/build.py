#!/usr/bin/env python3
"""MV-762: cut the APPROVED road train exterior mods (MV-748, /mnt/project-files/designs/road-train-mods/approved/, see its
README) into game layers for ShellMods (MV-760): assets/vehicles/road_train_v3/mods/<id>_L<n>.png (trimmed RGBA) + mods.json.

Coordinates are shell pixels at 2 decks (_base_floors 2). The tractor + chassis are bottom-aligned, so "body" parts move
112 px per deck (a "<n>@1" override covers the 1-deck body); the roofs keep the same rows at every deck count ("roof").
Ids: body shell  spike_ram, armor_plates (cab), armor_rail (L2-3, lead trailer side rail), fuel_tanks, solar_covers,
                 rad_shield, heater, suspension (drawn behind the tyres by AmbulanceMotion, not by ShellMods)
     trailer     roof_turret (rear of the roof, stock tyres + cans cleared: "_clear_turret"), solar_covers_t, suspension_t
     both        offroad_wheels_spin_L<n>.png = 48-frame tyre strips replacing wheel_spin.png (MV-759 base).
Opaque design canvases (ram, armour, solar) are cut by diffing against the same crop of the stock shell.
  python3 tools/art/road_train_mods/build.py
"""
import json, os
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SH = os.path.join(REPO, "assets/vehicles/road_train_v3/")
OUT = SH + "mods/"
A = "/mnt/project-files/designs/road-train-mods/approved/"
BG = (38, 36, 42, 255)
F1_TO_F2 = 112                                     # body_f1 -> body_f2 rows (bottom-aligned tractor/chassis)


def stock(f, box, pad=0):
    sh = Image.open(SH + f).convert("RGBA")
    c = Image.new("RGBA", (box[2] - box[0] + pad, box[3] - box[1]), BG); c.alpha_composite(sh.crop(box), (pad, 0)); return c


def diff(path, base):
    """pixels of an opaque design canvas that differ from the stock canvas -> trimmed layer + its offset in the canvas"""
    im = Image.open(path).convert("RGBA"); a, b = im.load(), base.load(); out = Image.new("RGBA", im.size); o = out.load()
    for y in range(im.height):
        for x in range(im.width):
            if a[x, y][:3] != b[x, y][:3] and a[x, y][3]:
                o[x, y] = a[x, y][:3] + (255,)
    bb = out.getbbox(); return out.crop(bb), bb[0], bb[1]


def trim(path):
    im = Image.open(path).convert("RGBA"); bb = im.getbbox(); return im.crop(bb), bb[0], bb[1]


meta = {"_deck_h": 112, "_base_floors": 2,
        "_clear_turret": [386, 20, 83, 52]}       # trailer rows of the stock tyre stack + jerry cans hidden under the turret


def put(mid, lv, im, x, y, anchor):
    im.save(OUT + f"{mid}_L{lv}.png")
    m = meta.setdefault(mid, {"anchor": anchor}); m[str(lv)] = [x, y]
    if anchor == "body":
        m[f"{lv}@1"] = [x, y - F1_TO_F2]
    print(mid, lv, im.size, (x, y))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ram0 = stock("body_f1.png", (0, 112, 176, 268), pad=48)
    arm0 = stock("body_f1.png", (10, 125, 210, 246))
    for L in (1, 2, 3):
        im, x, y = diff(A + f"spike_ram_L{L}.png", ram0); put("spike_ram", L, im, x - 48, y + 112 + F1_TO_F2, "body")
        im, x, y = diff(A + f"armor_plates_cab_L{L}.png", arm0); put("armor_plates", L, im, x + 10, y + 125 + F1_TO_F2, "body")
        im, x, y = trim(A + f"fuel_tanks_L{L}.png"); put("fuel_tanks", L, im, 386 + x, 240 + y + F1_TO_F2, "body")
        im, x, y = trim(A + f"heavy_suspension_body_L{L}.png"); put("suspension", L, im, x, y, "body")
        im, x, y = trim(A + f"heavy_suspension_trailer_L{L}.png"); put("suspension_t", L, im, x, y, "body")
        im, x, y = trim(A + f"roof_turret_L{L}.png"); put("roof_turret", L, im, 484 - im.width + x, 72 - im.height + y, "roof")
        Image.open(A + f"offroad_wheels_spin_L{L}.png").convert("RGBA").save(OUT + f"offroad_wheels_spin_L{L}.png")
    for L, (x0, y0) in ((2, (380, 213)), (3, (362, 212))):
        im, x, y = trim(A + f"armor_plates_rail_L{L}.png"); put("armor_rail", L, im, x0 + x, y0 + y + F1_TO_F2, "body")
    for L in (1, 2):
        im, x, y = trim(A + f"rad_shield_L{L}.png"); put("rad_shield", L, im, 100 + x, 88 + y + F1_TO_F2, "body")
        im, x, y = trim(A + f"heater_L{L}.png"); put("heater", L, im, 195 + x, 25 + y, "roof")
    im, x, y = diff(A + "solar_shutters_body.png", stock("body_f1.png", (236, 40, 406, 98))); put("solar_covers", 1, im, 236 + x, 40 + y, "roof")
    im, x, y = diff(A + "solar_shutters_trailer.png", stock("trailer_f2.png", (195, 20, 370, 76))); put("solar_covers_t", 1, im, 195 + x, 20 + y, "roof")
    json.dump(meta, open(OUT + "mods.json", "w"), indent=1)
