#!/usr/bin/env python3
"""Verify MV-548 native source reconstruction, keying, palette, wraps and reproducibility."""
import argparse
import hashlib
import json
import tempfile
from pathlib import Path
from PIL import Image
from art.common import PALETTE
from art.industrial_bg import SOURCE, OUT, KEY, generate

SIZES = {'clouds': (1984, 220), 'far': (1920, 300), 'mid': (1920, 230),
         'near': (2112, 124), 'road': (2304, 64),
         **{'sky_' + name: (64, 900) for name in ['dawn', 'day', 'dusk', 'night']},
         'sun': (32, 32), 'moon': (32, 32), 'smoke': (64, 20), 'lamp': (24, 16)}


def verify(regenerate=False):
    manifest = json.loads((SOURCE / 'manifest.json').read_text())
    allowed = set(PALETTE)
    for layer in manifest['layers']:
        name = layer['name']
        width, height = layer['panel_size']
        master = Image.new('RGB', tuple(layer['strip_size']))
        for i, panel in enumerate(layer['panels']):
            path = SOURCE / panel['file']
            assert hashlib.sha256(path.read_bytes()).hexdigest() == panel['sha256'], path
            with Image.open(path) as image:
                assert image.mode == 'RGB' and image.size == (width, height), path
                master.paste(image, (i * width, 0))
        # A continuous master naturally changes across internal seams. Compare every pixel,
        # including all three seam pairs, instead of incorrectly requiring identical columns.
        assert hashlib.sha256(master.tobytes()).hexdigest() == layer['approved_rgb_sha256'], name
        with Image.open(Path(OUT) / (name + '.png')) as image:
            assert image.mode == 'RGBA' and image.size == SIZES[name], name
            expected = [(0, 0, 0, 0) if p == KEY else (*p, 255) for p in master.get_flattened_data()]
            assert list(image.get_flattened_data()) == expected, (name, 'approved pixels or seams changed')
            assert image.crop((0, 0, 1, height)).tobytes() == image.crop((image.width-1, 0, image.width, height)).tobytes(), (name, 'wrap')
            if name == 'clouds':
                assert image.getchannel('A').crop((0, height-40, image.width, height)).getextrema() == (0, 0), 'Cloud clearance'
            else:
                assert image.getchannel('A').crop((0, height-1, image.width, height)).getextrema() == (255, 255), (name, 'ground line')
            if name == 'road':
                assert image.getchannel('A').getextrema() == (255, 255), 'Road alpha'
        print('PASS', name, 'exact native panels/master pixels, keying, internal joins and wrap')
    for name, size in SIZES.items():
        with Image.open(Path(OUT) / (name + '.png')) as image:
            assert image.size == size and image.mode == 'RGBA', name
            pixels = set(image.get_flattened_data())
            assert not {p[:3] for p in pixels if p[3]} - allowed, (name, 'palette')
            assert not {p[3] for p in pixels} - {0,255}, (name, 'alpha')
            assert all(p == (0,0,0,0) for p in pixels if not p[3]), (name, 'transparent RGB')
            if name.startswith('sky_'):
                assert image.getchannel('A').getextrema() == (255,255), name
    anchors = manifest['effect_anchors']
    for effect in anchors.values():
        with Image.open(Path(OUT) / (effect['layer'] + '.png')) as image:
            for x,y in effect['points']:
                assert image.crop((x-2,y-2,x+3,y+3)).getbbox(), ('Effect anchor misses artwork', x,y)
    runtime = (SOURCE.parents[3] / 'scripts/world/industrial_backdrop.gd').read_text()
    for effect in anchors.values():
        for x,y in effect['points']:
            assert 'Vector2(%d, %d)' % (x,y) in runtime, ('Stale runtime anchor',x,y)
    print('PASS 13 assets: master palette, binary alpha, effect anchor provenance')
    if regenerate:
        before = {p.name:p.read_bytes() for p in Path(OUT).iterdir() if p.suffix in ['.png','.json']}
        for _ in range(2):
            with tempfile.TemporaryDirectory() as directory:
                generate(directory)
                after = {p.name:p.read_bytes() for p in Path(directory).iterdir()}
                assert before == after, 'Nondeterministic or stale production output'
        print('PASS two clean regenerations match every production PNG and manifest byte for byte')
    return True


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--regenerate-check',action='store_true')
    verify(parser.parse_args().regenerate_check)
