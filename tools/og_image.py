"""Social share preview (Open Graph / Twitter card) for the web build.

Composes the real game art (desert parallax layers + the armoured bus from the atlas + walkers)
on a 600x315 pixel canvas, then scales it x2 with nearest-neighbour to 1200x630 so every pixel
stays crisp. Text is drawn without anti-aliasing for the same reason.

    python3 tools/og_image.py            # -> web/og-image.png

Deterministic: rerun after art changes (generate_pixel_art.py) and commit the PNG.
"""
import json, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BG = os.path.join(ROOT, "assets", "bg")
FONTS = os.path.join(ROOT, "assets", "fonts")
OUT = os.path.join(ROOT, "web", "og-image.png")
W, H, SCALE = 600, 315, 2
GROUND = 292                     # road surface line on the small canvas

AMBER = (216, 174, 68)           # yellow3: hazard paint / lamp amber
BONE = (178, 168, 138)           # cream3
SOOT = (12, 10, 10)              # ol0
TOXIC = (168, 216, 56)           # toxic3
BLOOD = (212, 82, 60)            # UIKit.C_RED: the CAR in the logo


def layer(name):
    return Image.open(os.path.join(BG, name)).convert("RGBA")


def tile_x(dst, img, y, off=0):
    x = -off
    while x < W:
        dst.alpha_composite(img, (x, y))
        x += img.width


def atlas():
    with open(os.path.join(ROOT, "assets", "atlas", "atlas.json")) as f:
        rects = json.load(f)
    sheet = Image.open(os.path.join(ROOT, "assets", "atlas", "atlas.png")).convert("RGBA")

    def get(key):
        x, y, w, h = rects[key]
        return sheet.crop((x, y, x + w, y + h))
    return get


def text(draw, xy, s, font, fill, shadow=SOOT):
    x, y = xy
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1), (2, 2)):
        draw.text((x + dx, y + dy), s, font=font, fill=shadow)
    draw.text((x, y), s, font=font, fill=fill)


def main():
    img = Image.new("RGBA", (W, H), (6, 6, 8, 255))
    sky = layer("desert_sky.png").resize((W, H), Image.NEAREST)
    img.alpha_composite(sky)
    img.alpha_composite(layer("desert_sun.png"), (242, 14))
    tile_x(img, layer("desert_clouds.png"), 6, 40)
    tile_x(img, layer("desert_far.png"), GROUND - 300 + 26, 120)
    tile_x(img, layer("desert_mid.png"), GROUND - 230 + 18, 60)
    tile_x(img, layer("desert_near.png"), GROUND - 130 + 6, 10)
    road = layer("desert_road.png")
    tile_x(img, road, GROUND - 8)

    # dusk grade: darken the left so the title reads, like the in-game CanvasModulate
    shade = Image.new("RGBA", (W, H))
    sd = ImageDraw.Draw(shade)
    for x in range(W):
        a = int(max(0, 170 - x * 0.42))
        sd.line([(x, 0), (x, H)], fill=(6, 6, 10, a))
    img.alpha_composite(shade)

    get = atlas()
    bus = get("ext_bus")
    bx, by = W - 292, GROUND - 300 + 16 - 8          # wheels sit on the road
    img.alpha_composite(bus, (bx, by))
    for cx, cy in ((34, 284), (214, 284)):          # Data.VEHICLES.bus.wheels (sprite centres)
        img.alpha_composite(get("wheel_0"), (bx + cx - 16, by + cy - 16))
    for key, x in (("en_walker_0", 214), ("en_runner_0", 246), ("en_walker_1", 262)):
        spr = get(key)
        spr = spr.resize((spr.width * 2, spr.height * 2), Image.NEAREST)
        img.alpha_composite(spr, (x, GROUND - spr.height + 2))

    d = ImageDraw.Draw(img)
    d.fontmode = "1"                                  # no anti-aliasing: hard pixel edges
    title = ImageFont.truetype(os.path.join(FONTS, "Silkscreen-Regular.ttf"), 32)
    sub = ImageFont.truetype(os.path.join(FONTS, "Silkscreen-Regular.ttf"), 16)
    small = ImageFont.truetype(os.path.join(FONTS, "Silkscreen-Regular.ttf"), 8)
    thai = ImageFont.truetype(os.path.join(FONTS, "ChakraPetch-Bold.ttf"), 22)
    thai_s = ImageFont.truetype(os.path.join(FONTS, "ChakraPetch-SemiBold.ttf"), 13)

    # logo: APO|CAR|LYPSE, the CAR pun lit up in blood red with a bar under it (same as UIKit.logo)
    x = 24
    for part, col in (("APO", BONE), ("CAR", BLOOD), ("LYPSE", BONE)):
        text(d, (x, 18), part, title, col)
        w = int(d.textlength(part, font=title))
        if part == "CAR":
            d.rectangle([x, 56, x + w - 4, 58], fill=BLOOD)
        x += w
    emblem = get("emblem").resize((32, 32), Image.NEAREST)
    img.alpha_composite(emblem, (22, 64))
    text(d, (60, 70), "MOBILE VAULT", sub, AMBER)
    text(d, (24, 112), "เอาชีวิตรอดบนรถป้อมเหล็ก", thai, BONE)
    text(d, (24, 142), "idle survival · สร้างห้อง จ้างผู้รอดชีวิต", thai_s, BONE)
    text(d, (24, 160), "ยิงซอมบี้ แล้วขับฝ่าดินแดนรกร้าง", thai_s, BONE)
    d.rectangle([24, 186, 130, 200], fill=SOOT)
    d.rectangle([25, 187, 129, 199], fill=(46, 30, 20))
    text(d, (30, 189), "PLAY FREE ON WEB", small, TOXIC)

    out = img.convert("RGB").resize((W * SCALE, H * SCALE), Image.NEAREST)
    out.save(OUT, optimize=True)
    print("wrote", OUT, out.size, os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    main()
