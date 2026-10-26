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


# ------------------------------------------------------------------ MV-473 equipment slots (approved v1 steel + v3 light)
# One riveted worn-steel frame per tile width (MV-474) and six rarity light loops (MV-475..480). The light is a MASK:
# three grey codes (gray2 / gray4 / gray6 = faint / lit / hot) that the game colours at runtime with the approved
# per-rarity emission and hot colours (UIKit / gear_fx.gdshader), so the atlas keeps the master palette. The masks
# follow the approved preview helper (tools/art/gear_slots/build_preview.py, cell()): same integer paths, five stepped
# pulse levels, phase offset (index + rank*2) % 16, highlight lengths, corner lights, particle counts and the Mythic
# heartbeat, with every edge re-derived for each native width (never a rescaled 32 px animation).
GEAR_WIDTHS = [28, 30, 32, 36, 40]
GEAR_RARITIES = ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
GEAR_PAD = 12          # template padding around the slot in a light-mask cell
GEAR_PHASES = 16
GEAR_HOT = 1.25        # strength of the hot / core colour on the same scale as the base emission


def _gear_suffix(w):
    return "" if w == 32 else "_%d" % w


def ui_gear_slot_frame(w=32):
    """MV-474: the approved steel slot at native width w: clipped corners, ol0 outline, top-left bevel, gunmetal band
    with sparse rust, four bolted corner plates, a dark groove at inset 4 (where the rarity rim lights up) and a dark
    recessed centre around the 16x16 icon area. Drawn per width: whole-pixel plates and bevels, recomputed spans."""
    img = new(w, w)
    rng = random.Random(4730 + w)
    for y in range(w):
        for x in range(w):
            d = min(x, y, w - 1 - x, w - 1 - y)
            corner = min(x, w - 1 - x) + min(y, w - 1 - y)
            if corner < 1:
                continue                                   # clipped corners
            if d == 0 or corner == 1:
                col = "ol0"
            elif d <= 3:
                # band: light from the top-left
                if (x == 1 or y == 1) and corner > 2:
                    col = "gray5"
                elif x == w - 2 or y == w - 2:
                    col = "gray2"
                else:
                    col = "gray4" if (x + y) % 5 else "gray3"
            elif d == 4:
                col = "ol1"                                # the rim groove
            elif d == 5:
                col = "ol0" if (x == 5 or y == 5) else "gray2"
            else:
                col = "gray1"                              # recess
            px(img, x, y, c(col))
    # rust on the band, sparse
    for _ in range(max(4, w // 5)):
        side = rng.randrange(4)
        t = rng.randrange(5, w - 5)
        k = rng.randrange(2, 4)
        x, y = [(t, k), (w - 1 - k, t), (t, w - 1 - k), (k, t)][side]
        px(img, x, y, c("orange1" if rng.random() < 0.6 else "orange2"))
    # four bolted plates
    for bx, by in [(1, 1), (w - 4, 1), (1, w - 4), (w - 4, w - 4)]:
        rect(img, bx, by, 3, 3, c("gray3"))
        px(img, bx + 1, by + 1, c("gray5"))
        px(img, bx + 2, by + 2, c("ol1"))
    return img


def _gear_path(vertices):
    pts = []
    for (x0, y0), (x1, y1) in zip(vertices, vertices[1:] + vertices[:1]):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(steps):
            p = (round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps))
            if not pts or pts[-1] != p:
                pts.append(p)
    return pts


def gear_light(rank, index, w=32, aura=True):
    """light strengths (x, y) -> s for one phase of one rarity at slot width w, in a (w+24)^2 cell with the slot at
    (12,12). The approved cell() with its colours replaced by strengths: tint(color, a) = a, mix(x, hot, t) moves x
    towards GEAR_HOT."""
    px0 = py0 = GEAR_PAD
    lit = {}

    def put(x, y, s):
        lit[(x, y)] = s                     # later draws replace earlier ones, as in the preview

    def mix(a, t):
        return a + (GEAR_HOT - a) * t

    rim = _gear_path([(7, 4), (w - 8, 4), (w - 5, 7), (w - 5, w - 8), (w - 8, w - 5), (7, w - 5), (4, w - 8), (4, 7)])
    outer = _gear_path([(-1, -3), (w, -3), (w + 3, 0), (w + 3, w - 1), (w, w + 2), (-1, w + 2), (-4, w - 1), (-4, 0)])
    corners = [(4, 4), (w - 5, 4), (w - 5, w - 5), (4, w - 5)]
    n = GEAR_PHASES
    phase = (index + rank * 2) % n
    pulse = (1 - math.cos(math.tau * phase / n)) / 2
    pulse = round(pulse * 4) / 4
    if rank == 5:
        pulse = [0.25, 0.5, 1, 0.5, 0.25, 0.5, 0.75, 0.5, 0.25, 0, 0, 0, 0, 0, 0, 0.25][phase]
    if aura:
        reach = [1, 2, 3, 3, 4, 5][rank]
        for ring in range(reach, 0, -1):
            glow = (0.08 + 0.025 * rank + 0.09 * pulse) * (reach - ring + 1) / reach
            v = [(px0 + 3 - ring, py0 + 1 - ring), (px0 + w - 4 + ring, py0 + 1 - ring),
                 (px0 + w - 2 + ring, py0 + 3 - ring), (px0 + w - 2 + ring, py0 + w - 4 + ring),
                 (px0 + w - 4 + ring, py0 + w - 2 + ring), (px0 + 3 - ring, py0 + w - 2 + ring),
                 (px0 + 1 - ring, py0 + w - 4 + ring), (px0 + 1 - ring, py0 + 3 - ring)]
            for i, (x, y) in enumerate(_gear_path(v)):
                if (i + phase + ring) % 3 != 0:
                    put(x, y, glow)
    strength = (0.42 + 0.12 * pulse) if rank == 0 else (0.56 + 0.38 * pulse)
    for x, y in rim:
        put(px0 + x, py0 + y, strength)
    head = (phase * len(rim) // n) % len(rim)
    tails = 3 if rank == 0 else 4 + rank
    for k in range(tails):
        x, y = rim[(head - k) % len(rim)]
        put(px0 + x, py0 + y, mix(strength, (tails - k) / tails * (0.45 if rank == 0 else 0.9)))
    if rank >= 3:
        for k in range(4):
            x, y = rim[(head + len(rim) // 2 - k) % len(rim)]
            put(px0 + x, py0 + y, mix(strength, (4 - k) / 5))
        for k, (x, y) in enumerate(corners):
            put(px0 + x, py0 + y, mix(0.4, 0.25 + 0.55 * ((phase + k * 4) % n) / n))
    if aura and rank > 0:
        count = [0, 1, 2, 3, 4, 6][rank]
        for particle in range(count):
            if rank >= 4:
                age = (phase + particle * 5) % n
                x = px0 + (-3 if particle % 2 == 0 else w + 2) + ((age // 4 + particle) % 2)
                y = py0 + w - 2 - age * 2
                size = 2 if rank == 5 and particle % 3 == 0 else 1
                s = mix(0.35, 1 - age / n)
            else:
                x, y = outer[(phase * len(outer) // n + particle * len(outer) // count) % len(outer)]
                x, y = px0 + x, py0 + y
                size = 1
                s = mix(0.5, 0.35 + 0.45 * ((phase + particle) % 4) / 3)
            for dx in range(size):
                for dy in range(size):
                    put(x + dx, y + dy, s)
        if rank == 5:
            for shift in (0, len(outer) // 2):
                for k in range(7):
                    x, y = outer[(head + shift + k) % len(outer)]
                    if k % 3 != 2:
                        put(px0 + x, py0 + y, mix(1.0, (7 - k) / 9))
    # the item never lights: its 16x16 centre stays empty
    ix = px0 + (w - 16) // 2
    iy = py0 + (w - 16) // 2
    for (x, y) in list(lit):
        if ix <= x < ix + 16 and iy <= y < iy + 16:
            del lit[(x, y)]
    return lit


def gear_mask_code(s):
    """light strength -> mask code: gray2 faint, gray4 lit, gray6 hot (None = dark)"""
    if s < 0.02:
        return None
    if s < 0.45:
        return "gray2"
    if s < 0.9:
        return "gray4"
    return "gray6"


def fx_gear_mask(rank, index, w=32):
    cell = w + 2 * GEAR_PAD
    img = new(cell, cell)
    for (x, y), s in gear_light(rank, index, w).items():
        code = gear_mask_code(s)
        if code and 0 <= x < cell and 0 <= y < cell:
            px(img, x, y, c(code))
    return img


def fx_gear_common(i, w=32):
    return fx_gear_mask(0, i, w)


def fx_gear_uncommon(i, w=32):
    return fx_gear_mask(1, i, w)


def fx_gear_rare(i, w=32):
    return fx_gear_mask(2, i, w)


def fx_gear_epic(i, w=32):
    return fx_gear_mask(3, i, w)


def fx_gear_legendary(i, w=32):
    return fx_gear_mask(4, i, w)


def fx_gear_mythic(i, w=32):
    return fx_gear_mask(5, i, w)


def gen_gear_slots():
    for w in GEAR_WIDTHS:
        add("ui_gear_slot_frame" + _gear_suffix(w), ui_gear_slot_frame(w))
        for rank, name in enumerate(GEAR_RARITIES):
            for i in range(GEAR_PHASES):
                add("fx_gear_%s%s_%d" % (name, _gear_suffix(w), i), fx_gear_mask(rank, i, w))


# ------------------------------------------------------------------ MV-483 trait cards (approved v2 compact + v4 light)
# A quiet compact trait card (MV-484) and twelve light loops (MV-485..496): six beneficial, six trade-off. The light is
# a mask in three grey codes (gray2 faint / gray4 lit / gray6 hot) coloured at runtime (TraitFx), so the atlas keeps
# the master palette. The masks follow the approved preview helper (tools/art/trait_cards/build_preview.py) at native
# scale: phase (index + rank*2) % 16, the stepped pulse / uneven flicker lookups, glint lengths, mote and ember counts,
# integer paths. The canonical card is 160x58 in a 172x70 cell (card at 6,6); the game draws the SAME algorithm for a
# card's real size (scripts/ui/trait_fx.gd, checked against these masks by the autotest).
TRAIT_W, TRAIT_H, TRAIT_PAD = 160, 58, 6
TRAIT_FLICKER = [0.62, 0.70, 0.66, 0.84, 0.73, 0.97, 0.76, 0.82, 0.68, 0.73, 0.92, 0.80, 0.66, 0.71, 0.78, 0.68]
TRAIT_HOT = 1.25


def ui_trait_card_frame():
    """MV-484: charcoal panel, one thin neutral steel outline, a one-pixel corner bevel, a dark 20x20 icon recess.
    No rivets, plates or nested frames. 9-slice with fixed 3 px corners (the game sizes it to the content)."""
    w, h = TRAIT_W, TRAIT_H
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            corner = min(x, w - 1 - x) + min(y, h - 1 - y)
            if corner < 1:
                continue
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d == 0 or corner == 1:
                col = "gray4" if (y == 0 or x == 0) and corner > 1 else "gray3"
            elif d == 1:
                col = "ol0"
            else:
                col = "gray1"
            px(img, x, y, c(col))
    return img


def _trait_path(x0, y0, x1, y1, ch):
    v = [(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch), (x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch), (x0, y0 + ch)]
    pts = []
    for (ax, ay), (bx, by) in zip(v, v[1:] + v[:1]):
        steps = max(abs(bx - ax), abs(by - ay))
        for i in range(steps):
            p = (round(ax + (bx - ax) * i / steps), round(ay + (by - ay) * i / steps))
            if not pts or pts[-1] != p:
                pts.append(p)
    return pts


def trait_light(negative, rank, index, w=TRAIT_W, h=TRAIT_H, still=False):
    """light strengths {(x, y): s} for one phase of one profile, in a (w+12)x(h+12) cell with the card at (6,6).
    still = the static semantic look (no pulse, glint, motes or embers). Mirrors TraitFx.light() in the game."""
    lit = {}
    x0, y0, x1, y1 = TRAIT_PAD, TRAIT_PAD, TRAIT_PAD + w - 1, TRAIT_PAD + h - 1
    rim = _trait_path(x0, y0, x1, y1, 2)
    n = 16
    phase = 0 if still else (index + rank * 2) % n
    # the semantic accent: a two-pixel bar down the left inside edge
    for y in range(y0 + 3, y1 - 2):
        lit[(x0 + 1, y)] = 0.6
        lit[(x0 + 2, y)] = 0.6
    if not negative:
        pulse = round((1 - math.cos(math.tau * phase / n)) * 2) / 4
        s = 0.5 if rank == 0 else 0.3 + 0.7 * pulse
        if still:
            s = 0.5
        for p in rim:
            lit[p] = s
        if rank >= 2 and not still:
            for ring in range(1, min(rank - 1, 2) + 1):
                for i, p in enumerate(_trait_path(x0 - ring, y0 - ring, x1 + ring, y1 + ring, 2 + ring)):
                    if (i + phase + ring) % 3 != 0:
                        lit.setdefault(p, 0.25)
        if not still:
            head = phase * len(rim) // n
            length = round((3 if rank == 0 else 5 + rank) * 1.4)
            for offset in ([0, len(rim) // 2] if rank >= 3 else [0]):
                for k in range(length):
                    lit[rim[(head + offset - k) % len(rim)]] = 0.6 + 0.65 * (length - k) / length
            count = [0, 1, 2, 3, 4, 5][rank]
            orbit = _trait_path(x0 - 3, y0 - 3, x1 + 3, y1 + 3, 5)
            for m in range(count):
                x, y = orbit[(phase * len(orbit) // n + m * len(orbit) // count) % len(orbit)]
                size = 1 if rank < 4 else 2
                for dx in range(size):
                    for dy in range(size):
                        lit[(x + dx, y + dy)] = 0.6 + 0.6 * ((phase + m) % 4) / 3
    else:
        flicker = TRAIT_FLICKER[phase]
        gain = 0.86 + (flicker - 0.75) * (0.35 + rank * 0.13)
        if still:
            gain = 0.86
        for i, p in enumerate(rim):
            if (i * 7 + 3) % 23 < 3:
                continue                               # fixed cracks in the broken edge
            lit[p] = 0.6 * gain
        if rank >= 1 and not still:
            for ring in range(1, min(rank, 2) + 1):
                for i, p in enumerate(_trait_path(x0 - ring, y0 - ring, x1 + ring, y1 + ring, 2 + ring)):
                    if (i + phase * 2 + ring) % 4 == 0:
                        lit.setdefault(p, 0.25)
        if not still:
            head = (phase * len(rim) // n + rank * 15) % len(rim)
            length = round((3 + rank) * 1.4)
            for k in range(length):
                if k % 3 == 2:
                    continue
                lit[rim[(head + k) % len(rim)]] = 1.0 - 0.3 * k / length
            count = [0, 1, 2, 3, 4, 6][rank]
            for m in range(count):
                age = (phase + m * 5) % n
                x = (x0 - 3 if m % 2 == 0 else x1 + 2) + ((age // 4 + m) % 2)
                y = y0 + age * h // n
                size = 2 if rank == 5 and m % 3 == 0 else 1
                for dx in range(size):
                    for dy in range(size):
                        lit[(x + dx, y + dy)] = 0.35 + 0.65 * (n - age) / n
            if rank >= 4:
                bx, by = rim[(rank * 43 + phase // 2 * 6) % len(rim)]
                for dx in range(2):
                    for dy in range(2):
                        lit.pop((bx + dx, by + dy), None)          # a soot-dark break
    # the content never lights
    for (x, y) in list(lit):
        if x0 + 4 <= x < x1 - 3 and y0 + 4 <= y < y1 - 3:
            del lit[(x, y)]
    return lit


def trait_mask_code(s):
    if s < 0.02:
        return None
    if s < 0.45:
        return "gray2"
    if s < 0.9:
        return "gray4"
    return "gray6"


def fx_trait_mask(negative, rank, index):
    cw, ch = TRAIT_W + 2 * TRAIT_PAD, TRAIT_H + 2 * TRAIT_PAD
    img = new(cw, ch)
    for (x, y), s in trait_light(negative, rank, index).items():
        code = trait_mask_code(s)
        if code and 0 <= x < cw and 0 <= y < ch:
            px(img, x, y, c(code))
    return img


TRAIT_TIER_NAMES = ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
TRAIT_MASK_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "trait_cards")


def gen_trait_cards():
    """the frame goes into the atlas; the 192 canonical light masks go into a reference sheet that is NOT shipped
    (tools/art/trait_cards/fx_trait_masks.png + .json): the game draws the same light for each card's real size, and
    the autotest checks its 160x58 output against this sheet pixel for pixel. Keeping them out of the atlas keeps it
    at 2048x2048 on phones."""
    import json
    add("ui_trait_card_frame", ui_trait_card_frame())
    cw, ch = TRAIT_W + 2 * TRAIT_PAD, TRAIT_H + 2 * TRAIT_PAD
    cols = 16
    sheet = new(cw * cols, ch * 12)
    regions = {}
    row = 0
    for negative, kind in ((False, "benefit"), (True, "tradeoff")):
        for rank, name in enumerate(TRAIT_TIER_NAMES):
            for i in range(16):
                key = "fx_trait_%s_%s_%d" % (kind, name, i)
                sheet.paste(fx_trait_mask(negative, rank, i), (i * cw, row * ch))
                regions[key] = [i * cw, row * ch, cw, ch]
            row += 1
    os.makedirs(TRAIT_MASK_DIR, exist_ok=True)
    sheet.save(os.path.join(TRAIT_MASK_DIR, "fx_trait_masks.png"), optimize=True)
    with open(os.path.join(TRAIT_MASK_DIR, "fx_trait_masks.json"), "w") as f:
        json.dump(regions, f, indent=0, sort_keys=True)


# ------------------------------------------------------------------ MV-500 / MV-501..513: seeded world map art
## Native map pieces for the seeded world map screen (approved preview tools/art/micro/previews/seeded-map-v1).
## Every piece uses only its spec's palette names, binary alpha and whole pixels; terrain tiles are 16x16 repeats on
## the preview's 4px cluster grid and wrap seamlessly; roads are drawn by the game (not here). Deterministic: a fixed
## seed per piece, so a full regeneration gives the same pixels.

def _wrap_rect(img, x, y, w, h, col):
    ## a rect that wraps across the 16x16 tile edges (keeps repeat tiles seamless)
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            img.putpixel((xx % 16, yy % 16), col)


def _ground(name, base, clusters, seed):
    ## clusters: [(colour, count, (w, h))] placed on the 4px grid (+0..1 px offset), wrapping
    img = new(16, 16, c(base))
    r = random.Random(seed)
    for col, n, (w, h) in clusters:
        for i in range(n):
            x = r.randrange(0, 16, 4) + r.randrange(0, 2)
            y = r.randrange(0, 16, 4) + r.randrange(0, 2)
            _wrap_rect(img, x, y, w, h, c(col))
    add(name, img)


def ui_map_ground_industrial():
    # soot concrete, a few darker cracks, sparse 2-4px rust roof / wall fragments; no lit windows
    _ground("ui_map_ground_industrial", "gray3", [("gray2", 5, (4, 2)), ("gray4", 3, (2, 2)), ("ol0", 2, (1, 2)),
        ("orange1", 2, (3, 2)), ("orange1", 1, (2, 3))], 501)


def ui_map_ground_desert():
    # dusty sand with a few stepped 1px dune ridges (light over dark), no gold glints
    img = new(16, 16, c("sand2"))
    for (x, y, n) in [(1, 3, 5), (9, 7, 6), (3, 12, 5)]:
        for i in range(n):
            img.putpixel(((x + i) % 16, (y - (i // 2)) % 16), c("sand3"))
            img.putpixel(((x + i) % 16, (y + 1 - (i // 2)) % 16), c("sand1"))
    for (x, y) in [(13, 1), (6, 15), (14, 11)]:
        _wrap_rect(img, x, y, 2, 1, c("sand1"))
    add("ui_map_ground_desert", img)


def ui_map_ground_forest():
    # coarse olive canopy clusters with tiny dark trunks; no bright grass carpet
    img = new(16, 16, c("green1"))
    r = random.Random(503)
    for (x, y) in [(0, 0), (8, 2), (4, 8), (12, 10), (0, 12)]:
        _wrap_rect(img, x + r.randrange(0, 2), y, 4, 3, c("green2"))
        _wrap_rect(img, x + 1, y, 2, 1, c("green3"))
        _wrap_rect(img, x + 2, y + 3, 1, 1, c("wood0"))
    for (x, y) in [(6, 5), (14, 6), (10, 14)]:
        _wrap_rect(img, x, y, 2, 2, c("green0"))
    add("ui_map_ground_forest", img)


def ui_map_ground_swamp():
    # dark oxidised water / moss, sparse reed clusters; no blanket radioactive glow
    img = new(16, 16, c("teal1"))
    for (x, y, w) in [(0, 2, 6), (8, 6, 5), (2, 11, 7), (11, 13, 4)]:
        _wrap_rect(img, x, y, w, 2, c("teal0"))
    for (x, y) in [(5, 0), (13, 4), (7, 9), (1, 14)]:
        _wrap_rect(img, x, y, 3, 2, c("teal2"))
    for (x, y) in [(10, 1), (4, 6), (14, 10)]:
        img.putpixel((x % 16, y % 16), c("teal3"))
        img.putpixel((x % 16, (y + 1) % 16), c("wood0"))
        img.putpixel(((x + 1) % 16, (y + 1) % 16), c("wood0"))
    add("ui_map_ground_swamp", img)


def ui_map_ground_tundra():
    # dirty blue-gray snow with a few stepped rock / ice caps; no bright white surface
    img = new(16, 16, c("snow1"))
    for (x, y, w) in [(1, 1, 5), (9, 5, 4), (3, 9, 6), (12, 13, 4)]:
        _wrap_rect(img, x, y, w, 1, c("snow2"))
    for (x, y) in [(6, 3), (13, 9), (2, 13)]:
        _wrap_rect(img, x, y, 3, 2, c("snow0"))
        _wrap_rect(img, x + 1, y - 1, 1, 1, c("snow3"))
    add("ui_map_ground_tundra", img)


def ui_map_ground_metro():
    # dense, low-contrast ruined roof rectangles with short alley gaps (cooler and tidier than industrial rubble)
    img = new(16, 16, c("gray2"))
    for (x, y, w, h) in [(0, 0, 7, 5), (8, 0, 6, 4), (0, 7, 4, 7), (6, 6, 9, 4), (6, 12, 5, 3), (13, 11, 3, 4)]:
        _wrap_rect(img, x, y, w, h, c("gray3"))
        _wrap_rect(img, x + 1, y + 1, max(1, w - 3), 1, c("sky2"))
    for (x, y) in [(4, 3), (11, 2), (9, 8), (2, 11)]:
        img.putpixel((x, y), c("gray1"))
    for (x, y) in [(15, 5), (5, 15)]:
        img.putpixel((x, y), c("ol0"))
    add("ui_map_ground_metro", img)


def ui_map_fog_dither():
    # 4px stepped dither clusters, alternating opaque / clear, quiet repeat
    img = new(16, 16)
    for gy in range(4):
        for gx in range(4):
            if (gx + gy) % 2 == 0:
                rect(img, gx * 4, gy * 4, 4, 4, c("gray1" if (gx * 3 + gy) % 3 else "gray2"))
    add("ui_map_fog_dither", img, q=False)


def ui_map_landmark_frame():
    # 27x27: 2px soot surround, 1px gray6 rim, dark 23x23 panel at (2,2); the 16x16 icon slot at (5,5) stays panel
    img = new(27, 27)
    rect(img, 0, 0, 27, 27, c("ol0"))
    rect(img, 2, 2, 23, 23, c("gray6"))
    rect(img, 3, 3, 21, 21, c("gray1"))
    add("ui_map_landmark_frame", img, q=False)


def _disc(img, cx, cy, r, col):
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                img.putpixel((x, y), col)


def ui_map_road_stop():
    # stepped 12x12 stop at (2,2) with a 2px soot surround, muted gray5 centre, thin cream3 edge
    img = new(16, 16)
    _disc(img, 8, 8, 8, c("ol0"))
    _disc(img, 8, 8, 6, c("cream3"))
    _disc(img, 8, 8, 5, c("gray5"))
    add("ui_map_road_stop", img, q=False)


def ui_map_selection_ring():
    # 33x33: only the outer 2px stepped amber rim; the central 27x27 stays clear
    img = new(33, 33)
    rect(img, 0, 0, 33, 33, c("yellow0"))
    rect(img, 1, 1, 31, 31, c("lamp1"))
    rect(img, 2, 2, 29, 29, CLEAR)
    for (x, y) in [(0, 0), (32, 0), (0, 32), (32, 32)]:
        img.putpixel((x, y), CLEAR)          # stepped corners
    add("ui_map_selection_ring", img, q=False)


def fx_map_vehicle_marker():
    # 22x16 compact vehicle pictogram (preview drawCar footprint): body, cab, roof, one lamp pixel fixed; only two
    # small wheel tread marks change between frames (frame 0 = parked)
    for f in range(4):
        img = new(22, 16)
        rect(img, 1, 3, 20, 10, c("ol0"))              # soot outline block
        rect(img, 2, 4, 13, 6, c("green1"))            # box body
        rect(img, 3, 5, 11, 1, c("cream1"))            # roof stripe
        rect(img, 15, 6, 5, 4, c("teal1"))             # cab
        rect(img, 16, 7, 2, 1, c("cream1"))            # windscreen
        img.putpixel((19, 9), c("lamp2"))              # headlamp
        rect(img, 2, 10, 18, 2, c("ol0"))              # chassis / wheel line
        for wx in (5, 16):
            rect(img, wx - 1, 11, 3, 2, c("ol0"))
            img.putpixel((wx - 1 + f % 3, 12), c("orange2"))   # the tread mark steps along
        add("fx_map_vehicle_marker_%d" % f, img, q=False)


def fx_map_suspect_ping():
    # 33x33 overlay at 2 fps; central 27x27 clear. 0 dim, 1 upper corner tick, 2 opposite corner tick, 3 dim
    for f in range(4):
        img = new(33, 33)
        for (x, y) in [(0, 0), (32, 0), (0, 32), (32, 32)]:
            img.putpixel((x, y), c("yellow0"))         # dim corner dots (all phases)
        if f == 1:
            rect(img, 0, 0, 3, 1, c("lamp1"))
            rect(img, 0, 0, 1, 3, c("yellow1"))
        elif f == 2:
            rect(img, 30, 32, 3, 1, c("lamp1"))
            rect(img, 32, 30, 1, 3, c("yellow1"))
        add("fx_map_suspect_ping_%d" % f, img, q=False)


def fx_map_event_beacon():
    # 16x16 badge at 2 fps: steady dark-red backing with a stepped amber rim tick that walks round; centre 8x10 clear
    # for the separate steady "!" glyph
    ticks = [(3, 1), (13, 4), (11, 14), (1, 11)]
    for f in range(4):
        img = new(16, 16)
        rect(img, 1, 1, 14, 14, c("ol0"))
        rect(img, 2, 2, 12, 12, c("red0"))
        # the centre 8x10 stays plain backing: the game draws the steady "!" on top
        tx, ty = ticks[f]
        rect(img, tx, ty, 2, 1, c("lamp1"))
        img.putpixel((tx, ty + 1 if ty < 8 else ty - 1), c("yellow1"))
        add("fx_map_event_beacon_%d" % f, img, q=False)


def gen_world_map():
    ui_map_ground_industrial()
    ui_map_ground_desert()
    ui_map_ground_forest()
    ui_map_ground_swamp()
    ui_map_ground_tundra()
    ui_map_ground_metro()
    ui_map_fog_dither()
    ui_map_landmark_frame()
    ui_map_road_stop()
    ui_map_selection_ring()
    fx_map_vehicle_marker()
    fx_map_suspect_ping()
    fx_map_event_beacon()
