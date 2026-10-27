"""MV-548: approved Industrial Ruins panels, separate clock skies and bounded pixel effects.

The committed native panels are the user-reviewed, palette/grid-normalized art. Production
generation is deterministic, uses only PAL colours and binary alpha, and never calls an image API.
"""
import json
import os
import hashlib
from pathlib import Path
from PIL import Image
from .common import BAYER4, OUT_BG, new, c, rect, ellipse

HERE = os.path.dirname(__file__)
OUT = os.path.join(OUT_BG, 'industrial_live')
SOURCE = Path(HERE) / 'industrial' / 'source'
KEY = (255, 0, 255)
SKIES = {
    'dawn': ['night1', 'purple1', 'purple2', 'dusk1', 'orange2', 'sand3'],
    'day': ['blue1', 'blue2', 'blue3', 'sky2', 'sky3', 'cream2'],
    'dusk': ['night0', 'purple0', 'purple1', 'red1', 'dusk1', 'dusk2'],
    'night': ['night0', 'night1', 'night2', 'purple0', 'purple1', 'blue1'],
}


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


def approved_layers():
    """Reconstruct accepted native pixels exactly; only the magenta key changes."""
    manifest = json.loads((SOURCE / 'manifest.json').read_text())
    result = {}
    for layer in manifest['layers']:
        strip = Image.new('RGB', tuple(layer['strip_size']))
        width, height = layer['panel_size']
        for index, panel in enumerate(layer['panels']):
            path = SOURCE / panel['file']
            if hashlib.sha256(path.read_bytes()).hexdigest() != panel['sha256']:
                raise ValueError('Approved panel changed: ' + panel['file'])
            with Image.open(path) as image:
                if image.size != (width, height):
                    raise ValueError('Wrong native size: ' + panel['file'])
                strip.paste(image.convert('RGB'), (index * width, 0))
        if hashlib.sha256(strip.tobytes()).hexdigest() != layer['approved_rgb_sha256']:
            raise ValueError('Approved master changed: ' + layer['name'])
        pixels = list(strip.get_flattened_data())
        if layer['name'] == 'road' and KEY in pixels:
            raise ValueError('Road must be opaque')
        rgba = Image.new('RGBA', strip.size)
        rgba.putdata([(0, 0, 0, 0) if rgb == KEY else (*rgb, 255) for rgb in pixels])
        result[layer['name']] = rgba
    return result, manifest


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


def generate(out=OUT):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    layers, source_manifest = approved_layers()
    for name, names in SKIES.items():
        sky(names).save(out / ('sky_' + name + '.png'), optimize=True)
    layers.update(sun=celestial(), moon=celestial(True), smoke=smoke(), lamp=lamp())
    for name, image in layers.items():
        image.save(out / (name + '.png'), optimize=True)
    manifest = {'native': True, 'ticket': 'MV-548', 'sky_height': 900,
                'source': 'tools/art/industrial/source/manifest.json',
                'effect_anchors': source_manifest['effect_anchors'],
                'layers': {layer['name']: layer['strip_size'] for layer in source_manifest['layers']}}
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    generate()
