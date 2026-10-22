"""Icons (16x16), gear icons, particles, combat props and the rusted-steel UI frames."""
import math, os, random
from PIL import ImageDraw
from .common import *

ru = random.Random(5)

# old generator colour names -> master palette (keeps the icon code readable)
P = {
    "ol": OL, "ol2": OL2,
    "m0": c("gray1"), "m1": c("gray2"), "m2": c("gray3"), "m3": c("gray5"), "m4": c("gray6"),
    "r0": c("orange0"), "r1": c("orange1"), "r2": c("orange2"), "r3": c("orange3"), "r4": c("yellow3"),
    "c0": c("sand1"), "c1": c("sand2"), "c2": c("sand3"), "c3": c("cream3"),
    "b0": c("blue0"), "b1": c("blue1"), "b2": c("blue2"), "b3": c("blue3"), "b4": c("blue4"),
    "g0": c("green0"), "g1": c("green0"), "g2": c("green2"), "g3": c("green3"), "g4": c("green4"), "g5": c("green4"),
    "sk": c("skin3"), "sk2": c("skin2"), "sk3": c("skin1"),
    "a0": c("green0"), "a1": c("green1"), "a2": c("green1"), "a3": c("green2"),
    "w0": c("gray5"), "w1": c("gray6"), "w2": c("gray6"),
    "y0": c("orange1"), "y1": c("yellow2"), "y2": c("yellow2"), "y3": c("gray6"),
    "red0": c("red0"), "red": c("red2"), "red2": c("red3"),
    "pk0": c("purple1"), "pk": c("pink1"), "pk2": c("pink3"),
    "cy": c("teal2"), "cy2": c("teal3"), "gr": c("green3"), "gr2": c("green4"),
    "wd0": c("wood1"), "wd1": c("wood2"), "wd2": c("wood3"), "wd3": c("wood4"),
    "white": c("gray6"), "clear": CLEAR,
}


def icon(name, fn):
    img = new(16, 16)
    fn(img)
    add("ic_" + name, outline_alpha(img))


def ic_power(i):
    poly(i, [(9, 1), (3, 9), (7, 9), (5, 15), (12, 6), (8, 6), (10, 1)], P["y2"]); px(i, 9, 2, P["y3"])
def ic_water(i):
    poly(i, [(8, 1), (3, 9), (4, 12), (7, 14), (10, 14), (12, 12), (13, 9)], P["b2"]); px(i, 6, 9, P["b4"]); px(i, 6, 10, P["b4"])
def ic_food(i):
    rect(i, 3, 4, 10, 11, P["m3"]); rect(i, 3, 7, 10, 5, P["red"]); hline(i, 3, 4, 10, P["m4"]); hline(i, 3, 14, 10, P["m2"]); rect(i, 5, 8, 3, 2, P["y2"])
def ic_scrap(i):
    poly(i, [(2, 9), (8, 4), (14, 7), (9, 13)], P["m3"]); poly(i, [(2, 9), (9, 13), (9, 15), (2, 11)], P["m2"]); line(i, 5, 8, 10, 6, P["m4"]); px(i, 11, 8, P["r3"])
def ic_people(i):
    ellipse(i, 3, 2, 5, 5, P["b3"]); rect(i, 2, 8, 7, 6, P["b2"]); ellipse(i, 9, 3, 5, 5, P["red2"]); rect(i, 8, 9, 7, 5, P["red"])
def ic_happy(i):
    ellipse(i, 1, 1, 14, 14, P["y2"]); px(i, 5, 6, P["ol"]); px(i, 10, 6, P["ol"]); hline(i, 5, 10, 6, P["ol"]); px(i, 4, 9, P["ol"]); px(i, 11, 9, P["ol"])
def ic_sad(i):
    ellipse(i, 1, 1, 14, 14, P["r3"]); px(i, 5, 6, P["ol"]); px(i, 10, 6, P["ol"]); hline(i, 5, 10, 6, P["ol"]); px(i, 4, 11, P["ol"]); px(i, 11, 11, P["ol"])
def ic_hammer(i):
    line(i, 4, 13, 10, 7, P["wd2"], 2); poly(i, [(7, 3), (11, 1), (15, 5), (13, 7)], P["m3"]); px(i, 12, 3, P["m4"])
def ic_map(i):
    rect(i, 1, 3, 14, 11, P["c2"]); vline(i, 6, 3, 11, P["c0"]); vline(i, 10, 3, 11, P["c0"]); line(i, 2, 11, 7, 6, P["g3"]); line(i, 8, 8, 13, 5, P["red"])
def ic_chest(i):
    rect(i, 1, 6, 14, 8, P["wd2"]); rect(i, 1, 3, 14, 4, P["wd3"]); hline(i, 1, 7, 14, P["wd0"]); rect(i, 7, 6, 2, 3, P["y1"])
def ic_up(i):
    poly(i, [(8, 1), (2, 8), (6, 8), (6, 14), (10, 14), (10, 8), (14, 8)], P["gr"]); px(i, 8, 3, P["gr2"])
def ic_wrench(i):
    line(i, 3, 13, 10, 6, P["m3"], 2); ellipse(i, 9, 1, 6, 6, P["m3"]); rect(i, 11, 2, 2, 2, P["clear"])
def ic_skull(i):
    ellipse(i, 3, 1, 10, 10, P["w2"]); rect(i, 5, 10, 6, 4, P["w2"]); rect(i, 5, 5, 2, 2, P["ol"]); rect(i, 9, 5, 2, 2, P["ol"]); px(i, 7, 12, P["ol"]); px(i, 9, 12, P["ol"])
def ic_gear(i):
    for k in range(8):
        a = k / 8 * math.tau; rect(i, int(7 + 6 * math.cos(a)), int(7 + 6 * math.sin(a)), 2, 2, P["m3"])
    ellipse(i, 3, 3, 10, 10, P["m3"]); ellipse(i, 6, 6, 4, 4, P["clear"])
def ic_medkit(i):
    rect(i, 2, 4, 12, 10, P["w2"]); rect(i, 6, 2, 4, 3, P["w1"]); rect(i, 7, 6, 2, 6, P["red"]); rect(i, 5, 8, 6, 2, P["red"])
def ic_radaway(i):
    rect(i, 5, 1, 6, 3, P["m3"]); rect(i, 4, 4, 8, 11, P["y1"]); rect(i, 5, 7, 6, 4, P["ol"]); px(i, 8, 8, P["y2"]); px(i, 6, 10, P["y2"]); px(i, 10, 10, P["y2"])
def ic_stimpack(i):
    line(i, 2, 14, 11, 5, P["w1"], 3); line(i, 11, 5, 14, 2, P["m3"]); rect(i, 5, 9, 3, 3, P["red"])
def ic_rifle(i):
    rect(i, 1, 6, 14, 2, P["ol2"]); rect(i, 1, 8, 4, 3, P["wd1"]); rect(i, 8, 8, 2, 4, P["ol2"]); hline(i, 4, 5, 6, P["m2"])
def ic_pistol(i):
    rect(i, 2, 5, 11, 3, P["m2"]); rect(i, 3, 8, 3, 5, P["wd1"]); hline(i, 2, 5, 11, P["m3"])
def ic_ammo(i):
    for k in range(3):
        rect(i, 2 + k * 4, 5, 3, 9, P["y1"]); rect(i, 2 + k * 4, 3, 3, 3, P["r3"]); vline(i, 2 + k * 4, 6, 7, P["y2"])
def ic_armor(i):
    poly(i, [(3, 2), (6, 2), (8, 4), (10, 2), (13, 2), (14, 6), (12, 7), (12, 14), (4, 14), (4, 7), (2, 6)], P["a2"]); rect(i, 6, 8, 4, 4, P["a1"])
def ic_meat(i):
    ellipse(i, 2, 3, 11, 9, P["red"]); ellipse(i, 4, 5, 6, 4, P["red2"]); rect(i, 11, 10, 4, 2, P["w2"])
def ic_can(i):
    rect(i, 4, 4, 8, 10, P["m3"]); rect(i, 4, 7, 8, 4, P["red"]); hline(i, 4, 4, 8, P["m4"])
def ic_seed(i):
    ellipse(i, 3, 6, 10, 8, P["wd2"]); line(i, 8, 6, 8, 2, P["g3"]); px(i, 9, 2, P["g4"]); px(i, 7, 3, P["g4"])
def ic_fuel(i):
    rect(i, 3, 3, 10, 12, P["red"]); rect(i, 9, 1, 3, 3, P["m3"]); line(i, 5, 6, 10, 12, P["red0"]); line(i, 10, 6, 5, 12, P["red0"])
def ic_hull(i):
    poly(i, [(8, 1), (14, 4), (13, 10), (8, 15), (3, 10), (2, 4)], P["m3"]); poly(i, [(8, 3), (12, 5), (11, 9), (8, 12)], P["m2"])
def ic_sun(i):
    ellipse(i, 4, 4, 8, 8, P["y2"])
    for k in range(8):
        a = k / 8 * math.tau; px(i, int(8 + 6.5 * math.cos(a)), int(8 + 6.5 * math.sin(a)), P["y1"])
def ic_rain(i):
    ellipse(i, 2, 2, 12, 7, P["m3"]); ellipse(i, 5, 1, 7, 6, P["m4"])
    for x in (4, 8, 12):
        line(i, x, 10, x - 1, 13, P["b3"])
def ic_storm(i):
    ellipse(i, 2, 2, 12, 7, P["m2"]); poly(i, [(8, 8), (5, 12), (8, 12), (6, 15), (11, 10), (8, 10), (10, 8)], P["y2"])
def ic_snow(i):
    for a in range(3):
        ang = a * math.pi / 3; line(i, int(8 - 6 * math.cos(ang)), int(8 - 6 * math.sin(ang)), int(8 + 6 * math.cos(ang)), int(8 + 6 * math.sin(ang)), P["w2"])
def ic_sand(i):
    for k, y in enumerate((4, 8, 12)):
        line(i, 2 + k, y, 14, y - 1, P["y0"] if k % 2 else P["r4"])
def ic_fog(i):
    for y in (4, 8, 12):
        hline(i, 2, y, 12, P["w1"])
def ic_moon(i):
    ellipse(i, 3, 2, 11, 11, P["c3"]); ellipse(i, 6, 1, 10, 10, P["clear"])
def ic_str(i):
    rect(i, 3, 6, 10, 5, P["sk"]); rect(i, 5, 3, 4, 4, P["sk"]); rect(i, 9, 5, 4, 3, P["sk2"])
def ic_int(i):
    ellipse(i, 2, 2, 12, 11, P["pk2"]); line(i, 8, 3, 8, 12, P["pk"]); line(i, 4, 7, 12, 7, P["pk"])
def ic_agi(i):
    poly(i, [(2, 12), (8, 4), (8, 8), (14, 2), (9, 12), (9, 8)], P["cy"])
def ic_explore(i):
    poly(i, [(3, 14), (6, 4), (8, 1), (10, 4), (13, 14), (8, 10)], P["r3"]); px(i, 8, 5, P["y2"])
def ic_lock(i):
    rect(i, 3, 7, 10, 8, P["y1"]); ImageDraw.Draw(i).rectangle([5, 2, 10, 8], outline=P["m3"]); rect(i, 7, 10, 2, 3, P["ol"])
def ic_pause(i):
    rect(i, 3, 2, 4, 12, P["w2"]); rect(i, 9, 2, 4, 12, P["w2"])
def ic_play(i):
    poly(i, [(4, 2), (13, 8), (4, 14)], P["gr"])
def ic_close(i):
    line(i, 3, 3, 12, 12, P["red2"], 2); line(i, 12, 3, 3, 12, P["red2"], 2)
def ic_rad(i):
    ellipse(i, 1, 1, 14, 14, P["y1"]); ellipse(i, 6, 6, 4, 4, P["ol"])
    d = ImageDraw.Draw(i)
    for k in range(3):
        a = k * math.tau / 3 - math.pi / 2
        d.pieslice([2, 2, 13, 13], math.degrees(a) - 25, math.degrees(a) + 25, fill=P["ol"])
    ellipse(i, 6, 6, 4, 4, P["y1"]); px(i, 7, 7, P["ol"]); px(i, 8, 8, P["ol"])
def ic_xp(i):
    poly(i, [(8, 1), (10, 6), (15, 6), (11, 9), (13, 15), (8, 11), (3, 15), (5, 9), (1, 6), (6, 6)], P["y2"])
def ic_acid(i):
    ellipse(i, 2, 1, 12, 7, c("toxic1")); ellipse(i, 5, 0, 7, 6, c("toxic2"))
    for x in (4, 8, 12):
        line(i, x, 9, x - 1, 12, c("toxic3")); px(i, x - 1, 14, c("toxic3"))
def ic_ash(i):
    ellipse(i, 2, 2, 12, 7, c("gray2")); ellipse(i, 5, 1, 7, 6, c("gray3"))
    for (x, y) in ((4, 11), (8, 13), (11, 10), (6, 14), (13, 13)):
        px(i, x, y, c("gray5"))
def ic_book(i):
    rect(i, 2, 2, 12, 12, c("orange2")); rect(i, 4, 3, 9, 10, c("cream3")); vline(i, 3, 2, 12, c("orange0"))
    for y in (5, 7, 9):
        hline(i, 6, y, 5, c("sand1"))
    rect(i, 9, 1, 2, 5, c("red3"))
def ic_chat(i):
    rect(i, 1, 2, 14, 9, c("green4")); poly(i, [(4, 11), (4, 14), (7, 11)], c("green4"))
    for x in (4, 7, 10):
        px(i, x + 1, 6, OL)
def ic_dog(i):
    rect(i, 4, 7, 9, 4, c("wood3")); rect(i, 1, 5, 5, 4, c("wood3")); px(i, 2, 4, c("wood2")); px(i, 2, 6, OL)
    for x in (5, 11):
        vline(i, x, 11, 3, c("wood2"))
    line(i, 13, 7, 15, 4, c("wood3"))
def ic_backpack_slot(i):
    pass
def ic_dodge(i):
    for k in range(3):
        line(i, 2 + k * 2, 13 - k, 8 + k * 2, 3 + k, c("teal2") if k == 2 else c("teal1"))
def ic_supply(i):
    rect(i, 2, 7, 6, 7, c("red2")); hline(i, 2, 7, 6, c("gray6")); rect(i, 9, 5, 5, 9, c("blue2")); rect(i, 10, 3, 3, 2, c("gray5"))
def ic_flee(i):
    poly(i, [(1, 8), (7, 3), (7, 6), (14, 6), (14, 10), (7, 10), (7, 13)], c("yellow2"))
def ic_signal(i):
    vline(i, 8, 6, 9, c("gray5")); px(i, 8, 5, c("red3"))
    for r in (3, 6):
        ImageDraw.Draw(i).arc([8 - r, 5 - r, 8 + r, 5 + r], 200, 340, fill=c("green4"))


def ic_pill(i):
    rect(i, 4, 1, 8, 3, c("gray5")); rect(i, 3, 4, 10, 11, c("sky3")); rect(i, 3, 7, 10, 5, c("gray6"))
    rect(i, 6, 8, 4, 3, c("red2")); vline(i, 4, 5, 9, c("gray6"))
def ic_blueprint(i):
    rect(i, 1, 2, 14, 12, c("blue2")); vline(i, 3, 2, 12, c("blue1"))
    for x in range(5, 15, 3):
        vline(i, x, 3, 10, c("blue3"))
    for y in range(4, 13, 3):
        hline(i, 4, y, 10, c("blue3"))
    rect(i, 6, 6, 6, 4, c("gray6")); rect(i, 7, 7, 4, 2, c("blue2"))
def ic_thermo(i):
    rect(i, 6, 1, 4, 10, c("gray6")); ellipse(i, 4, 9, 8, 7, c("red2")); vline(i, 7, 4, 7, c("red2")); px(i, 6, 11, c("red4"))


ICONS = dict(pill=ic_pill, blueprint=ic_blueprint, thermo=ic_thermo, power=ic_power, water=ic_water, food=ic_food, scrap=ic_scrap, people=ic_people, happy=ic_happy, sad=ic_sad,
             hammer=ic_hammer, map=ic_map, chest=ic_chest, up=ic_up, wrench=ic_wrench, skull=ic_skull, gear=ic_gear,
             medkit=ic_medkit, radaway=ic_radaway, stimpack=ic_stimpack, rifle=ic_rifle, pistol=ic_pistol, ammo=ic_ammo,
             armor=ic_armor, meat=ic_meat, can=ic_can, seed=ic_seed, fuel=ic_fuel, hull=ic_hull, sun=ic_sun, rain=ic_rain,
             storm=ic_storm, snow=ic_snow, sand=ic_sand, fog=ic_fog, moon=ic_moon, str=ic_str, int=ic_int, agi=ic_agi,
             explore=ic_explore, lock=ic_lock, pause=ic_pause, play=ic_play, close=ic_close, rad=ic_rad, xp=ic_xp,
             acid=ic_acid, ash=ic_ash, book=ic_book, chat=ic_chat, dog=ic_dog, dodge=ic_dodge, supply=ic_supply,
             flee=ic_flee, signal=ic_signal)


def _armor_shape(i, a, b, cc=None):
    poly(i, [(3, 2), (6, 2), (8, 4), (10, 2), (13, 2), (14, 6), (12, 7), (12, 14), (4, 14), (4, 7), (2, 6)], a); rect(i, 6, 8, 4, 4, b)
    if cc:
        hline(i, 4, 11, 8, cc); px(i, 7, 5, cc); px(i, 8, 5, cc)


def _helmet(i, a, b, visor=None, mask=False):
    ellipse(i, 2, 3, 12, 10, a); rect(i, 2, 8, 12, 3, a); hline(i, 1, 10, 14, b); px(i, 5, 5, P["m4"])
    if visor:
        rect(i, 4, 8, 8, 2, visor); px(i, 5, 8, P["white"])
    if mask:
        ellipse(i, 3, 4, 10, 10, P["m1"]); ellipse(i, 4, 6, 3, 3, c("green3")); ellipse(i, 9, 6, 3, 3, c("green3"))
        rect(i, 6, 11, 4, 4, P["m2"]); hline(i, 6, 13, 4, P["ol"])


def _boot(i, a, b, flame=False):
    rect(i, 5, 2, 6, 9, a); rect(i, 3, 10, 11, 4, a); hline(i, 3, 13, 11, b); hline(i, 5, 4, 6, b)
    if flame:
        rect(i, 6, 14, 4, 2, c("yellow2")); px(i, 7, 15, c("gray6"))


def _pack(i, a, b, frame_=False, roll=None):
    rect(i, 3, 3, 10, 12, a); rect(i, 4, 8, 8, 4, b); hline(i, 3, 3, 10, blend(a, P["white"], 0.3)); rect(i, 6, 1, 4, 2, b)
    if roll:
        rect(i, 2, 0, 12, 3, roll)
    if frame_:
        vline(i, 1, 1, 15, P["m3"]); vline(i, 14, 1, 15, P["m3"]); hline(i, 1, 15, 14, P["m3"])


GEAR_ICONS = {
    "shotgun": lambda i: (rect(i, 1, 6, 14, 3, P["m2"]), rect(i, 1, 9, 5, 3, P["wd1"]), hline(i, 6, 6, 9, P["m3"]), rect(i, 9, 9, 3, 2, P["wd2"])),
    "smg": lambda i: (rect(i, 3, 5, 11, 3, P["ol2"]), rect(i, 6, 8, 2, 6, P["m2"]), rect(i, 3, 8, 2, 3, P["m1"]), hline(i, 3, 5, 11, P["m2"])),
    "laser": lambda i: (rect(i, 1, 6, 13, 3, P["w1"]), rect(i, 2, 9, 4, 3, P["m2"]), hline(i, 4, 7, 9, P["cy"]), px(i, 14, 7, P["cy2"]), px(i, 15, 7, P["cy2"])),
    "jacket": lambda i: _armor_shape(i, P["r2"], P["r1"]),
    "mail": lambda i: _armor_shape(i, P["m2"], P["m1"], P["m3"]),
    "riot": lambda i: _armor_shape(i, P["b1"], P["b0"], P["b3"]),
    "powerframe": lambda i: _armor_shape(i, P["y0"], P["m1"], P["y2"]),
    "chip": lambda i: (rect(i, 3, 3, 10, 10, P["g2"]), rect(i, 5, 5, 6, 6, P["ol2"]), [vline(i, x, 1, 2, P["y1"]) for x in (5, 8, 11)], [vline(i, x, 13, 2, P["y1"]) for x in (5, 8, 11)], px(i, 7, 7, P["red2"])),
    "charm": lambda i: (line(i, 8, 1, 8, 5, P["m3"]), ellipse(i, 3, 5, 10, 10, P["g3"]), ellipse(i, 5, 7, 6, 6, P["g4"]), px(i, 7, 9, P["white"])),
    "turret": lambda i: (rect(i, 2, 10, 12, 4, P["m1"]), orect(i, 3, 4, 8, 7, P["a2"]), rect(i, 10, 6, 6, 2, P["ol2"])),
    "harpoon": lambda i: (rect(i, 2, 10, 12, 4, P["m1"]), orect(i, 3, 4, 8, 7, P["r2"]), rect(i, 10, 7, 4, 1, P["m3"]), poly(i, [(13, 5), (15, 7), (13, 9)], P["m4"])),
    "tesla": lambda i: (rect(i, 4, 11, 8, 4, P["m1"]), vline(i, 8, 3, 8, P["b2"]), ellipse(i, 5, 0, 7, 6, P["cy"]), px(i, 3, 6, P["cy2"]), px(i, 13, 4, P["cy2"])),
    "plates": lambda i: (orect(i, 1, 3, 7, 10, P["m2"]), orect(i, 8, 3, 7, 10, P["m3"]), px(i, 3, 5, P["m4"]), px(i, 10, 5, P["m4"]), px(i, 3, 10, P["m4"]), px(i, 12, 10, P["m4"])),
    "engine": lambda i: (orect(i, 2, 5, 12, 9, P["m2"]), rect(i, 4, 2, 3, 4, P["m3"]), rect(i, 9, 2, 3, 4, P["m3"]), hline(i, 3, 9, 10, P["red2"]), rect(i, 0, 8, 2, 3, P["m1"])),
    "spikes": lambda i: ([poly(i, [(2, 2 + k * 4), (14, 4 + k * 4), (2, 6 + k * 4)], P["m3"]) for k in range(3)], vline(i, 2, 1, 14, P["m1"])),
    "saw": lambda i: ([rect(i, int(7 + 6 * math.cos(k / 8 * math.tau)), int(7 + 6 * math.sin(k / 8 * math.tau)), 2, 2, P["m3"]) for k in range(8)], ellipse(i, 2, 2, 12, 12, P["m4"]), ellipse(i, 6, 6, 4, 4, P["m1"])),
    "plow": lambda i: (poly(i, [(2, 2), (12, 4), (14, 14), (2, 14)], P["y1"]), [line(i, 3, y, 12, y + 1, P["y0"]) for y in (6, 9, 12)]),
    "cog": lambda i: ([rect(i, int(7 + 6 * math.cos(k / 6 * math.tau)), int(7 + 6 * math.sin(k / 6 * math.tau)), 2, 2, P["r3"]) for k in range(6)], ellipse(i, 3, 3, 10, 10, P["r3"]), ellipse(i, 6, 6, 4, 4, P["r1"])),
    "sword": lambda i: (line(i, 3, 13, 12, 4, P["m4"], 2), line(i, 2, 10, 6, 14, P["y1"], 2), px(i, 13, 2, P["white"])),
    "shield": lambda i: (poly(i, [(8, 1), (14, 3), (13, 10), (8, 15), (3, 10), (2, 3)], P["b2"]), poly(i, [(8, 3), (12, 4), (11, 9), (8, 12)], P["b3"])),
    "crown": lambda i: (poly(i, [(1, 13), (1, 4), (5, 8), (8, 2), (11, 8), (15, 4), (15, 13)], P["y1"]), hline(i, 1, 12, 15, P["y0"]), px(i, 8, 9, P["red2"])),
    "heal": lambda i: (rect(i, 6, 2, 4, 12, P["gr"]), rect(i, 2, 6, 12, 4, P["gr"]), px(i, 7, 3, P["gr2"])),
    "fist": lambda i: (rect(i, 3, 5, 10, 7, P["sk"]), hline(i, 3, 7, 10, P["sk2"]), rect(i, 3, 12, 6, 3, P["sk2"])),
    # helmets
    "hardhat": lambda i: _helmet(i, c("yellow2"), c("orange1")),
    "gasmask": lambda i: _helmet(i, c("green1"), c("green1"), mask=True),
    "helmet": lambda i: _helmet(i, c("green2"), c("green1")),
    "visor": lambda i: _helmet(i, c("gray4"), c("gray2"), visor=c("teal2")),
    # boots
    "boots": lambda i: _boot(i, c("sand2"), c("gray6")),
    "workboots": lambda i: _boot(i, c("wood3"), c("wood1")),
    "tacboots": lambda i: _boot(i, c("gray2"), c("green1")),
    "jetboots": lambda i: _boot(i, c("gray4"), c("red2"), flame=True),
    # backpacks
    "backpack": lambda i: _pack(i, c("red2"), c("red1")),
    "hikingpack": lambda i: _pack(i, c("blue2"), c("blue1"), roll=c("yellow2")),
    "ruck": lambda i: _pack(i, c("green2"), c("green1"), roll=c("green1")),
    "framepack": lambda i: _pack(i, c("orange2"), c("orange0"), frame_=True, roll=c("green2")),
}


def gen_icons():
    for k, fn in ICONS.items():
        icon(k, fn)
    for k, fn in GEAR_ICONS.items():
        icon(k, fn)


def gen_particles():
    p = new(1, 4); rect(p, 0, 0, 1, 4, c("blue4")); add("pt_rain", p)
    p = new(1, 4); rect(p, 0, 0, 1, 4, c("toxic3")); add("pt_acid", p)
    p = new(2, 2); rect(p, 0, 0, 2, 2, c("gray6")); add("pt_snow", p)
    p = new(2, 2); rect(p, 0, 0, 2, 2, c("gray4")); px(p, 1, 1, c("gray2")); add("pt_ash", p)
    p = new(3, 3); rect(p, 0, 1, 3, 1, c("sand2")); rect(p, 1, 0, 1, 3, c("sand2")); add("pt_dust", p)
    p = new(2, 1); rect(p, 0, 0, 2, 1, c("sand3")); add("pt_sand", p)
    p = new(6, 6); ellipse(p, 0, 0, 6, 6, c("gray5")); px(p, 1, 1, c("gray6")); px(p, 2, 1, c("gray6")); add("pt_smoke", p)
    p = new(2, 2); rect(p, 0, 0, 2, 2, c("gray6")); add("pt_spark", p)
    p = new(3, 2); rect(p, 0, 0, 3, 2, c("green3")); px(p, 0, 0, c("green4")); add("pt_leaf", p)
    p = new(3, 3); rect(p, 0, 0, 3, 3, c("orange0")); px(p, 1, 1, c("orange1")); add("pt_mud", p)
    p = new(1, 1); rect(p, 0, 0, 1, 1, c("gray6")); add("pt_px", p)
    p = new(40, 16)
    for y in range(16):
        for x in range(40):
            d = ((x - 20) / 20) ** 2 + ((y - 8) / 8) ** 2
            if d < 1 and (1 - d) * 2.2 > bayer(x, y):
                px(p, x, y, c("gray6"))
    add("pt_fog", p)


def gen_combat_props():
    ch = new(12, 10)
    orect(ch, 0, 3, 12, 7, c("gray6"))
    orect(ch, 0, 0, 12, 4, c("gray6"))
    rect(ch, 5, 2, 2, 4, c("gray6"))
    hline(ch, 1, 6, 10, c("gray5"))
    add("chest", ch)
    ring = new(24, 24)
    ImageDraw.Draw(ring).ellipse([1, 1, 22, 22], outline=c("gray6"), width=1)
    add("ring", ring)
    sl = new(48, 8)   # slam shockwave
    for x in range(48):
        h = int(3 + 3 * math.sin(x / 47 * math.pi))
        vline(sl, x, 8 - h, h, c("yellow3") if x % 3 else c("gray6"))
    add("slam", sl)
    e = new(24, 24)
    ellipse(e, 0, 0, 24, 24, OL); ellipse(e, 2, 2, 20, 20, c("green2")); ellipse(e, 5, 5, 14, 14, c("yellow2")); ellipse(e, 8, 8, 8, 8, c("green1"))
    add("emblem", e)


# ------------------------------------------------------------------ grim rusted-steel UI frames (assets/ui)
BR = c("ol0")
ST = c("gray3")         # steel border
ST_HI = c("gray4")
ST_LO = c("gray2")
RUST = c("orange1")
IN = hx("141416")       # window interior
IN2 = hx("1c1c20")      # card interior


def _save_ui(img, name):
    img.save(os.path.join(OUT_UI, name + ".png"))


def _cut(img, r=1):
    w, h = img.size
    for (x, y) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        px(img, x, y, CLEAR)


def gen_ui_frames():
    # window: 16x16, margin 5 -- soot outline, riveted steel border with rust, inner bevel, near-black inside
    p = new(16, 16)
    rect(p, 0, 0, 16, 16, BR)
    rect(p, 1, 1, 14, 14, ST)
    hline(p, 1, 1, 14, ST_HI)
    vline(p, 1, 1, 14, ST_HI)
    hline(p, 1, 14, 14, ST_LO)
    vline(p, 14, 1, 14, ST_LO)
    for (x, y) in ((2, 2), (13, 2), (2, 13), (13, 13)):
        px(p, x, y, c("gray5"))
    for (x, y) in ((7, 1), (8, 14), (1, 9), (14, 6)):
        px(p, x, y, RUST)
    rect(p, 3, 3, 10, 10, BR)
    rect(p, 4, 4, 8, 8, IN)
    hline(p, 4, 4, 8, hx("1e1e22"))
    _cut(p)
    _save_ui(p, "panel")
    # title strip (10x10, margin 3): rust-red painted plate
    t = new(10, 10)
    rect(t, 0, 0, 10, 10, BR)
    rect(t, 1, 1, 8, 8, c("red1"))
    hline(t, 1, 1, 8, c("red2"))
    hline(t, 1, 8, 8, c("red0"))
    _cut(t)
    _save_ui(t, "title")
    # card: 8x8 margin 2
    p = new(8, 8)
    rect(p, 0, 0, 8, 8, c("gray2"))
    rect(p, 1, 1, 6, 6, IN2)
    _cut(p)
    _save_ui(p, "card")

    # buttons 10x10 (margin 3): metal plate with a painted face, bevel + 1px dark lip
    def btn(fill, hi, lo, name, line=BR):
        b = new(10, 10)
        rect(b, 0, 0, 10, 10, line)
        rect(b, 1, 1, 8, 8, fill)
        hline(b, 1, 1, 8, hi)
        vline(b, 1, 1, 7, hi)
        hline(b, 1, 8, 8, lo)
        vline(b, 8, 2, 7, lo)
        _cut(b)
        _save_ui(b, name)

    def ramp(r, i, hover=False):
        n = len(RAMPS[r]) - 1
        j = min(i + (1 if hover else 0), n)
        return c(f"{r}{j}"), c(f"{r}{min(j + 1, n)}"), c(f"{r}{max(j - 1, 0)}")
    btn(*ramp("green", 2), "btn")
    btn(*ramp("green", 2, True), "btn_hover")
    btn(c("gray1"), c("gray0"), c("gray2"), "btn_pressed")
    btn(hx("1a1a1c"), hx("222224"), hx("121214"), "btn_disabled", line=c("gray2"))
    btn(*ramp("yellow", 1), "btn_amber")
    btn(*ramp("yellow", 1, True), "btn_amber_hover")
    btn(*ramp("gray", 2), "btn_gray")
    btn(*ramp("gray", 2, True), "btn_gray_hover")
    btn(*ramp("blue", 2), "btn_cyan")
    btn(*ramp("blue", 2, True), "btn_cyan_hover")
    btn(*ramp("red", 1), "btn_red")
    btn(*ramp("red", 1, True), "btn_red_hover")
    # tab on / off (8x8, bottom open)
    t = new(8, 8)
    rect(t, 0, 0, 8, 8, BR)
    rect(t, 1, 1, 6, 7, c("gray3"))
    hline(t, 1, 1, 6, c("yellow2"))
    _cut(t)
    _save_ui(t, "tab_on")
    t = new(8, 8)
    rect(t, 0, 0, 8, 8, c("gray2"))
    rect(t, 1, 1, 6, 6, IN2)
    hline(t, 0, 7, 8, ST)
    _cut(t)
    _save_ui(t, "tab_off")
    # gear tile: white frame tinted by rarity via modulate, dark translucent centre (8x8, margin 2)
    t = new(8, 8)
    rect(t, 0, 0, 8, 8, hx("ffffff"))
    rect(t, 1, 1, 6, 6, hx("101012", 230))
    frame(t, 1, 1, 6, 6, hx("707070"))
    _cut(t)
    _save_ui(t, "tile")
    # speech bubble 9-slice (7x7, margin 3) + tail
    b = new(7, 7)
    rect(b, 0, 0, 7, 7, c("gray4"))
    rect(b, 1, 1, 5, 5, hx("141416"))
    _cut(b)
    _save_ui(b, "bubble")
    t = new(5, 4)
    poly(t, [(0, 0), (4, 0), (1, 3)], hx("141416"))
    line(t, 0, 0, 1, 3, c("gray4"))
    line(t, 4, 0, 1, 3, c("gray4"))
    _save_ui(t, "bubble_tail")
    t = new(4, 4); rect(t, 0, 0, 4, 4, c("gray2")); rect(t, 1, 1, 2, 2, hx("0c0c0e")); _save_ui(t, "bar_bg")
    t = new(4, 1); px(t, 0, 0, c("gray3")); px(t, 1, 0, c("gray3")); _save_ui(t, "dash")
