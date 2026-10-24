#!/usr/bin/env python3
"""Validate MV-275's shipped atlas icons against their reviewed art contracts.

Run after generate_pixel_art.py. --preview writes an integer-enlarged contact
sheet for review; it never modifies game resources.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
import micro_asset
from art import ui
from art.common import new, outline_alpha

ROOT = Path(__file__).resolve().parent.parent


def verify(preview=None):
    contracts = json.loads((ROOT / 'tools/art/icon_contracts.json').read_text(encoding='utf-8'))['icons']
    regions = micro_asset.atlas()
    palette = micro_asset.palette()
    actual = {name for name in regions if name.startswith('ic_')}
    failures = []
    if actual != set(contracts):
        failures.append(f'icon names changed: missing={set(contracts)-actual}, extra={actual-set(contracts)}')
    images = []
    samples = 0
    renderers = {**ui.ICONS, **ui.GEAR_ICONS}
    with Image.open(ROOT / 'assets/atlas/atlas.png') as atlas:
        atlas = atlas.convert('RGBA')
        for name, spec in contracts.items():
            if name not in regions:
                continue
            x, y, width, height = regions[name]
            if [width, height] != spec['size']:
                failures.append(f'{name}: expected {spec["size"]}, found {width}x{height}')
            image = atlas.crop((x, y, x + width, y + height))
            source = new(16, 16)
            renderers[name.removeprefix('ic_')](source)
            if outline_alpha(source).tobytes() != image.tobytes():
                failures.append(f'{name}: atlas is stale relative to its deterministic drawing source')
            colors = set(image.getdata())
            allowed = {tuple(bytes.fromhex(palette[c])) for c in spec['palette']}
            extra = {c[:3] for c in colors if c[3]} - allowed
            if extra:
                failures.append(f'{name}: colors outside ticket palette: {extra}')
            if {c[3] for c in colors} - {0, 255}:
                failures.append(f'{name}: alpha must be binary')
            if not any(c[3] == 0 for c in colors):
                failures.append(f'{name}: transparent surroundings missing')
            if not any(c[:3] == (12, 10, 10) and c[3] for c in colors):
                failures.append(f'{name}: soot outline missing')
            digest = hashlib.sha256(image.tobytes()).hexdigest()
            if digest == spec['original_rgba_sha256']:
                failures.append(f'{name}: old art remains unchanged')
            if spec.get('approved_rgba_sha256'):
                if digest != spec['approved_rgba_sha256']:
                    failures.append(f'{name}: pixels differ from the reviewed native sample')
                else:
                    samples += 1
            images.append((name, image))
    if preview:
        # Exact integer enlargement, quiet UI background, no rasterized labels.
        sheet = Image.new('RGBA', (240, 24 * ((len(images) + 9) // 10)), (36, 40, 44, 255))
        for index, (_, image) in enumerate(images):
            sheet.alpha_composite(image, ((index % 10) * 24 + 4, (index // 10) * 24 + 4))
        path = Path(preview)
        path.parent.mkdir(parents=True, exist_ok=True)
        sheet.resize((sheet.width * 6, sheet.height * 6), Image.Resampling.NEAREST).save(path)
    for failure in failures:
        print('FAIL', failure)
    print(f'Icons: {len(images)}/92; reviewed pixel matches: {samples}/12; failures: {len(failures)}')
    return not failures and len(images) == 92 and samples == 12


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview')
    args = parser.parse_args()
    raise SystemExit(0 if verify(args.preview) else 1)
