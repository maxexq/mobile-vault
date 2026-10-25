"""Icons (16x16), gear icons, particles, combat props and the rusted-steel UI frames."""
import math, os, random
from PIL import ImageDraw
from .common import *
from . import icon_details

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
    icon_details.draw(i, "power")
def ic_water(i):
    icon_details.draw(i, "water")
def ic_food(i):
    icon_details.draw(i, "food")
def ic_scrap(i):
    icon_details.draw(i, "scrap")
def ic_people(i):
    icon_details.draw(i, "people")
def ic_happy(i):
    icon_details.draw(i, "happy")
def ic_sad(i):
    icon_details.draw(i, "sad")
def ic_hammer(i):
    icon_details.draw(i, "hammer")
def ic_map(i):
    icon_details.draw(i, "map")
def ic_chest(i):
    icon_details.draw(i, "chest")
def ic_up(i):
    icon_details.draw(i, "up")
def ic_wrench(i):
    icon_details.draw(i, "wrench")
def ic_skull(i):
    icon_details.draw(i, "skull")
def ic_gear(i):
    icon_details.draw(i, "gear")
def ic_medkit(i):
    icon_details.draw(i, "medkit")
def ic_radaway(i):
    icon_details.draw(i, "radaway")
def ic_stimpack(i):
    icon_details.draw(i, "stimpack")
def ic_rifle(i):
    icon_details.draw(i, "rifle")
def ic_pistol(i):
    icon_details.draw(i, "pistol")
def ic_ammo(i):
    icon_details.draw(i, "ammo")
def ic_armor(i):
    icon_details.draw(i, "armor")
def ic_meat(i):
    icon_details.draw(i, "meat")
def ic_can(i):
    icon_details.draw(i, "can")
def ic_seed(i):
    icon_details.draw(i, "seed")
def ic_fuel(i):
    icon_details.draw(i, "fuel")
def ic_hull(i):
    icon_details.draw(i, "hull")
def ic_sun(i):
    icon_details.draw(i, "sun")
def ic_rain(i):
    icon_details.draw(i, "rain")
def ic_storm(i):
    icon_details.draw(i, "storm")
def ic_snow(i):
    icon_details.draw(i, "snow")
def ic_sand(i):
    icon_details.draw(i, "sand")
def ic_fog(i):
    icon_details.draw(i, "fog")
def ic_moon(i):
    icon_details.draw(i, "moon")
def ic_str(i):
    icon_details.draw(i, "str")
def ic_int(i):
    icon_details.draw(i, "int")
def ic_agi(i):
    icon_details.draw(i, "agi")
def ic_explore(i):
    icon_details.draw(i, "explore")
def ic_lock(i):
    icon_details.draw(i, "lock")
def ic_pause(i):
    icon_details.draw(i, "pause")
def ic_play(i):
    icon_details.draw(i, "play")
def ic_close(i):
    icon_details.draw(i, "close")
def ic_rad(i):
    icon_details.draw(i, "rad")
def ic_xp(i):
    icon_details.draw(i, "xp")
def ic_acid(i):
    icon_details.draw(i, "acid")
def ic_ash(i):
    icon_details.draw(i, "ash")
def ic_book(i):
    icon_details.draw(i, "book")
def ic_chat(i):
    icon_details.draw(i, "chat")
def ic_dog(i):
    icon_details.draw(i, "dog")
def ic_backpack_slot(i):
    pass
def ic_dodge(i):
    icon_details.draw(i, "dodge")
def ic_supply(i):
    icon_details.draw(i, "supply")
def ic_flee(i):
    icon_details.draw(i, "flee")
def ic_signal(i):
    icon_details.draw(i, "signal")


def ic_pill(i):
    icon_details.draw(i, "pill")
def ic_blueprint(i):
    icon_details.draw(i, "blueprint")
def ic_thermo(i):
    icon_details.draw(i, "thermo")


def ic_eye(i):
    icon_details.draw(i, "eye")
def ic_zoom(i):
    icon_details.draw(i, "zoom")


ICONS = dict(eye=ic_eye, zoom=ic_zoom, pill=ic_pill, blueprint=ic_blueprint, thermo=ic_thermo, power=ic_power, water=ic_water, food=ic_food, scrap=ic_scrap, people=ic_people, happy=ic_happy, sad=ic_sad,
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
    "shotgun": lambda i: icon_details.draw(i, "shotgun"),
    "smg": lambda i: icon_details.draw(i, "smg"),
    "laser": lambda i: icon_details.draw(i, "laser"),
    "jacket": lambda i: icon_details.draw(i, "jacket"),
    "mail": lambda i: icon_details.draw(i, "mail"),
    "riot": lambda i: icon_details.draw(i, "riot"),
    "powerframe": lambda i: icon_details.draw(i, "powerframe"),
    "chip": lambda i: icon_details.draw(i, "chip"),
    "charm": lambda i: icon_details.draw(i, "charm"),
    "turret": lambda i: icon_details.draw(i, "turret"),
    "harpoon": lambda i: icon_details.draw(i, "harpoon"),
    "tesla": lambda i: icon_details.draw(i, "tesla"),
    "plates": lambda i: icon_details.draw(i, "plates"),
    "engine": lambda i: icon_details.draw(i, "engine"),
    "spikes": lambda i: icon_details.draw(i, "spikes"),
    "saw": lambda i: icon_details.draw(i, "saw"),
    "plow": lambda i: icon_details.draw(i, "plow"),
    "cog": lambda i: icon_details.draw(i, "cog"),
    "sword": lambda i: icon_details.draw(i, "sword"),
    "shield": lambda i: icon_details.draw(i, "shield"),
    "crown": lambda i: icon_details.draw(i, "crown"),
    "heal": lambda i: icon_details.draw(i, "heal"),
    "fist": lambda i: icon_details.draw(i, "fist"),
    "hardhat": lambda i: icon_details.draw(i, "hardhat"),
    "gasmask": lambda i: icon_details.draw(i, "gasmask"),
    "helmet": lambda i: icon_details.draw(i, "helmet"),
    "visor": lambda i: icon_details.draw(i, "visor"),
    "boots": lambda i: icon_details.draw(i, "boots"),
    "workboots": lambda i: icon_details.draw(i, "workboots"),
    "tacboots": lambda i: icon_details.draw(i, "tacboots"),
    "jetboots": lambda i: icon_details.draw(i, "jetboots"),
    "backpack": lambda i: icon_details.draw(i, "backpack"),
    "hikingpack": lambda i: icon_details.draw(i, "hikingpack"),
    "ruck": lambda i: icon_details.draw(i, "ruck"),
    "framepack": lambda i: icon_details.draw(i, "framepack"),
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


# MV-418: the reviewed worn-steel faces. These are nine-slice textures, not
# larger controls: UIKit keeps the original content margins and hit areas.
BUTTON_FAMILIES = {
    "btn": ("green2", "green3", "green1"),
    "btn_amber": ("yellow1", "yellow2", "yellow0"),
    "btn_gray": ("gray2", "gray3", "gray1"),
    "btn_cyan": ("blue1", "blue2", "blue0"),
    "btn_red": ("red1", "red2", "red0"),
}


def button_skin(stem, state):
    """24x24, 6 px nine-slice caps; wear never enters the stretched centre."""
    face, hi, lo = BUTTON_FAMILIES[stem]
    if state == "hover":
        face, hi = hi, "gray5"
    elif state == "pressed":
        face, hi = lo, "ol0"
    elif state == "disabled":
        face, hi, lo = "gray1", "gray2", "ol0"
    b = new(24, 24)
    rect(b, 0, 0, 24, 24, c("ol0"))
    rect(b, 1, 1, 22, 22, c("gray3"))
    rect(b, 2, 2, 20, 20, c("ol0"))
    rect(b, 3, 3, 18, 18, c(face))
    hline(b, 3, 3, 18, c(hi))
    hline(b, 3, 20, 18, c(lo))
    hline(b, 1, 1, 22, c("gray6" if state == "hover" else "gray4"))
    for x in (3, 18):
        for y in (3, 18):
            rect(b, x, y, 3, 3, c("ol0"))
            rect(b, x, y, 2, 2, c("gray3" if state == "disabled" else "gray4"))
            if state != "disabled":
                px(b, x, y, c("gray6"))
    if state != "disabled":
        px(b, 5, 1, c("orange2"))
        hline(b, 18, 22, 2, c("orange1"))
        px(b, 20, 21, c("orange2"))
    for x, y in ((0, 0), (1, 0), (0, 1), (23, 0), (22, 0), (23, 1),
                 (0, 23), (1, 23), (0, 22), (23, 23), (22, 23), (23, 22)):
        px(b, x, y, CLEAR)
    return b


def gen_button_skins():
    for stem in BUTTON_FAMILIES:
        for state in ("normal", "hover", "pressed"):
            _save_ui(button_skin(stem, state), stem + ("" if state == "normal" else "_" + state))
    # The disabled face is identical for every family.
    _save_ui(button_skin("btn", "disabled"), "btn_disabled")


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

    gen_button_skins()
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
