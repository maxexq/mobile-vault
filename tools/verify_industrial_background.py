#!/usr/bin/env python3
"""Verify MV-369 layer sizes, exact palette, binary alpha, wrap joins and deterministic generation."""
from pathlib import Path
import argparse
import hashlib
import sys
from PIL import Image
from art.common import PALETTE
from art.industrial_bg import generate

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/bg/industrial_live'
SIZES = {'far': (1920, 300), 'mid': (1920, 230), 'near': (2112, 124), 'road': (2304, 64), 'clouds': (1984, 220),
         'sky_dawn': (64, 900), 'sky_day': (64, 900), 'sky_dusk': (64, 900), 'sky_night': (64, 900),
         'sun': (32, 32), 'moon': (32, 32), 'smoke': (64, 20), 'lamp': (24, 16)}


def verify(regenerate=False):
    failures = []
    allowed = set(PALETTE)
    for name, size in SIZES.items():
        with Image.open(OUT / (name + '.png')) as source:
            img = source.convert('RGBA')
            if img.size != size:
                failures.append(name + ': wrong size')
            pixels = set(img.get_flattened_data())
            if {p[:3] for p in pixels if p[3]} - allowed:
                failures.append(name + ': colours outside master palette')
            if {p[3] for p in pixels} - {0, 255}:
                failures.append(name + ': alpha must be binary')
            if name in ['far', 'mid', 'near', 'road', 'clouds']:
                if img.crop((0, 0, 1, img.height)).tobytes() != img.crop((img.width - 1, 0, img.width, img.height)).tobytes():
                    failures.append(name + ': edge columns disagree')
            if name.startswith('sky') and any(p[3] != 255 for p in pixels):
                failures.append(name + ': sky must fill the canvas')
            if name == 'mid' and img.crop((0, 0, img.width, 64)).getbbox() is not None:
                failures.append(name + ': old sky/boundary is baked into the factory layer')
    if regenerate:
        def hashes():
            return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*') if p.suffix in ['.png', '.json']}
        before = hashes()
        generate()
        first = hashes()
        generate()
        if before != first or first != hashes():
            failures.append('generated outputs are stale or nondeterministic')
    for failure in failures:
        print('FAIL', failure)
    print(f'Industrial background: {len(SIZES)} assets, {len(failures)} failures; regeneration check={regenerate}')
    return not failures


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--regenerate-check', action='store_true')
    args = parser.parse_args()
    sys.exit(0 if verify(args.regenerate_check) else 1)
