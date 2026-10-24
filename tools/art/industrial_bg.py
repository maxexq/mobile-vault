"""MV-369: approved industrial panorama split into native, independently looping production layers.

The committed daylight input is the user-reviewed imagegen draft, palette/grid-normalized. Production
generation is deterministic, uses only PAL colours and binary alpha, and never calls an image API.
"""
import json
import os
import random
from PIL import Image
from .common import PAL, BAYER4, OUT_BG, new, c, rect, line, poly, ellipse

HERE = os.path.dirname(__file__)
OUT = os.path.join(OUT_BG, 'industrial_live')
SMOKESTACKS = [[440, 96], [1704, 126], [1732, 116]]
LAMPS = [[282, 202], [784, 194], [1504, 204]]
SKIES = {
    'dawn': ['night1', 'purple1', 'purple2', 'dusk1', 'orange2', 'sand3'],
    'day': ['blue1', 'blue2', 'blue3', 'sky2', 'sky3', 'cream2'],
    'dusk': ['night0', 'purple0', 'purple1', 'red1', 'dusk1', 'dusk2'],
    'night': ['night0', 'night1', 'night2', 'purple0', 'purple1', 'blue1'],
}


def write(name, img):
    img.save(os.path.join(OUT, name + '.png'), optimize=True)


def sky(names):
    img = new(64, 900)
    stops = [0, 430, 590, 710, 815, 899]
    for y in range(900):
        index = next((i for i in range(5) if y <= stops[i + 1]), 4)
        t = (y - stops[index]) / (stops[index + 1] - stops[index])
        # Flat steps with short ordered-dither transitions, not a smooth blended sky.
        mix = max(0, min(1, (t - .63) / .30))
        for x in range(64):
            step = index + int((BAYER4[y % 4][x % 4] + .5) / 16 < mix)
            img.putpixel((x, y), c(names[step]))
    return img


def factories():
    img = Image.open(os.path.join(HERE, 'industrial', 'approved-daylight.png')).convert('RGBA')
    # Sky and distant silhouettes use these colours. Retain small enclosed highlights, but remove
    # large connected background regions so the independent skyline/sky can move behind the trusses.
    background = {c(k) for k in ['blue2', 'blue3', 'blue4', 'sky2', 'sky3', 'gray5', 'gray6', 'cream1', 'cream2', 'cream3']}
    seen = set()
    for y in range(216):
        for x in range(1920):
            if (x, y) in seen or img.getpixel((x, y)) not in background:
                continue
            component, todo = [], [(x, y)]
            seen.add((x, y))
            while todo:
                xx, yy = todo.pop()
                component.append((xx, yy))
                for nx, ny in [(xx - 1, yy), (xx + 1, yy), (xx, yy - 1), (xx, yy + 1)]:
                    if 0 <= nx < 1920 and 0 <= ny < 216 and (nx, ny) not in seen and img.getpixel((nx, ny)) in background:
                        seen.add((nx, ny))
                        todo.append((nx, ny))
            if len(component) > 18 or any(yy == 0 for _, yy in component):
                for p in component:
                    img.putpixel(p, (0, 0, 0, 0))
    out = new(1920, 230)
    out.paste(img.crop((0, 0, 1920, 216)), (0, 0))
    rect(out, 0, 0, 1920, 64, (0, 0, 0, 0))
    rect(out, 0, 216, 1920, 14, c('gray1'))
    # A quiet matching yard at the join: identical columns, no cut-off hero landmark.
    for y in range(230):
        out.putpixel((1919, y), out.getpixel((0, y)))
    return out


def skyline():
    img = new(1920, 300)
    rng = random.Random(369)
    for x in range(36, 1870, 39):
        w, h = rng.randrange(17, 43), rng.randrange(28, 100)
        fill = c('purple1') if x % 3 else c('blue2')
        rect(img, x, 300 - h, w, h, fill)
        if rng.random() < .5:
            poly(img, [(x + w // 2, 299 - h), (x + w, 299 - h), (x + w, 310 - h)], (0, 0, 0, 0))
        if x % 4 == 0:
            rect(img, x + w // 2, 288 - h, 3, 12, fill)
    rect(img, 0, 292, 1920, 8, c('purple1'))
    return img


def foreground():
    img = new(2112, 124)
    rng = random.Random(370)
    for x in [92, 328, 604, 968, 1260, 1572, 1880]:
        if x % 3:
            rect(img, x, 109, 35, 11, c('ol0'))
            rect(img, x + 1, 110, 33, 8, c('gray3'))
            rect(img, x + 3, 111, 28, 2, c('gray4'))
            for xx in range(x + 5, x + 30, 12):
                poly(img, [(xx, 118), (xx + 5, 110), (xx + 9, 110), (xx + 4, 118)], c('yellow0'))
        else:
            for xx in range(x, x + 46, 11):
                rect(img, xx, 100, 2, 20, c('gray2'))
            line(img, x, 104, x + 44, 108, c('gray3'))
        for _ in range(4):
            xx = x + rng.randrange(-10, 49)
            rect(img, xx, 119 - rng.randrange(0, 3), rng.randrange(2, 6), 3, c('gray2'))
    rect(img, 0, 122, 2112, 2, c('ol0'))
    return img


def road():
    img = new(2304, 64, c('gray2'))
    rect(img, 0, 0, 2304, 3, c('gray4'))
    rect(img, 0, 3, 2304, 2, c('gray1'))
    rect(img, 0, 42, 2304, 22, c('gray1'))
    rng = random.Random(371)
    for x in range(24, 2270, 91):
        rect(img, x, 19, rng.randrange(11, 23), 2, c('yellow1'))
        xx, yy = x + rng.randrange(15, 50), rng.randrange(5, 34)
        line(img, xx, yy, xx + 8, yy + 3, c('gray0'))
        line(img, xx + 8, yy + 3, xx + 13, yy + 1, c('gray0'))
        rect(img, x + 48, 45, 9, 3, c('gray3'))
    return img


def clouds():
    img = new(1984, 220)
    for x, y, w in [(96, 78, 124), (420, 130, 100), (790, 42, 168), (1190, 110, 128), (1570, 68, 144)]:
        rect(img, x, y, w, 3, c('sky1'))
        rect(img, x + 18, y - 3, w - 36, 3, c('sky1'))
        rect(img, x + 34, y + 3, w - 50, 2, c('sky0'))
    return img


def celestial(moon=False):
    img = new(32, 32)
    ellipse(img, 3, 3, 26, 26, c('ol0'))
    ellipse(img, 4, 4, 24, 24, c('cream2') if moon else c('lamp1'))
    ellipse(img, 5, 5, 20, 19, c('cream3') if moon else c('lamp2'))
    if moon:
        for x, y, w in [(9, 10, 4), (19, 16, 3), (12, 22, 3)]:
            rect(img, x, y, w, 2, c('cream1'))
    else:
        for y in [20, 24]:
            rect(img, 4, y, 24, 1, (0, 0, 0, 0))
    return img


def smoke():
    sheet = new(64, 20)
    for f in range(4):
        for x, y, w, h, shade in [(4, 14, 6, 6, 'sky0'), (2, 8, 10, 7, 'sky1'), (5, 3, 10, 6, 'sky0')]:
            rect(sheet, f * 16 + x + (f % 2), y, min(w, 15 - x), h, c(shade))
        for y in range(20):
            for x in range(16):
                if BAYER4[y % 4][x % 4] < f * 3:
                    sheet.putpixel((f * 16 + x, y), (0, 0, 0, 0))
    return sheet


def lamp():
    img = new(24, 16)
    for y in range(3, 16):
        for x in range(24):
            if abs(x - 12) < y * .7 and BAYER4[y % 4][x % 4] < max(1, 7 - y // 3):
                img.putpixel((x, y), c('yellow0' if y > 8 else 'lamp0'))
    rect(img, 10, 0, 4, 2, c('ol0'))
    rect(img, 11, 1, 2, 1, c('lamp1'))
    return img


def generate():
    os.makedirs(OUT, exist_ok=True)
    for name, names in SKIES.items():
        write('sky_' + name, sky(names))
    for name, img in [('far', skyline()), ('mid', factories()), ('near', foreground()), ('road', road()), ('clouds', clouds()), ('sun', celestial()), ('moon', celestial(True)), ('smoke', smoke()), ('lamp', lamp())]:
        write(name, img)
    manifest = {'native': True, 'sky_height': 900, 'smokestacks': SMOKESTACKS, 'lamps': LAMPS,
                'source': 'user-approved wide industrial daylight draft; palette/grid-normalized imagegen input',
                'layers': {'far': [1920, 300], 'mid': [1920, 230], 'near': [2112, 124], 'road': [2304, 64], 'clouds': [1984, 220]}}
    with open(os.path.join(OUT, 'manifest.json'), 'w') as file:
        json.dump(manifest, file, indent=2)


if __name__ == '__main__':
    generate()
