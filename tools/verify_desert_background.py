"""Verify MV-539 source preservation, keying, dimensions, seams and reproducibility."""
import argparse
import hashlib
import json
import tempfile
from pathlib import Path
from PIL import Image
from art.common import PAL
from art.desert_bg import SOURCE, OUT, KEY, generate


def verify():
    manifest = json.loads((SOURCE / "manifest.json").read_text())
    palette = {tuple(value[:3]) for value in PAL.values()}
    for layer in manifest["layers"]:
        name = layer["name"]
        width, height = layer["panel_size"]
        source_pixels = [[] for _ in range(height)]
        for panel in layer["panels"]:
            path = SOURCE / panel["file"]
            assert hashlib.sha256(path.read_bytes()).hexdigest() == panel["sha256"], path
            with Image.open(path) as source:
                assert source.size == (width, height), path
                source = source.convert("RGB")
                for y in range(height):
                    source_pixels[y].extend(list(source.crop((0, y, width, y + 1)).getdata()))
        approved = [rgb for row in source_pixels for rgb in row]
        assert hashlib.sha256(bytes(v for rgb in approved for v in rgb)).hexdigest() == layer["approved_rgb_sha256"], name
        with Image.open(OUT / (name + ".png")) as image:
            assert image.mode == "RGBA" and image.size == tuple(layer["strip_size"]), name
            pixels = list(image.getdata())
            for source, result in zip(approved, pixels):
                if source == KEY:
                    assert result == (0, 0, 0, 0), (name, "magenta key/fringe")
                else:
                    assert source in palette and result == (*source, 255), (name, "RGB changed")
            for x in [width, 2 * width, 3 * width, 4 * width]:
                assert image.crop((x - 1, 0, x, height)).tobytes() == image.crop((x % image.width, 0, x % image.width + 1, height)).tobytes(), (name, x, "seam")
            if name == "road":
                assert image.getchannel("A").getextrema() == (255, 255), "Road alpha"
            if name == "clouds":
                assert image.getchannel("A").crop((0, height - 40, image.width, height)).getextrema() == (0, 0), "Cloud clearance"
        print("PASS", name, tuple(layer["strip_size"]), "exact approved pixels, binary alpha, all joins + wrap")
    skies = list(OUT.glob("sky_*.png"))
    assert len(skies) == 4
    for path in skies:
        with Image.open(path) as image:
            assert image.size == (64, 900)
            assert all(rgba[3] == 255 and rgba[:3] in palette for rgba in image.convert("RGBA").getdata()), path
    print("PASS four opaque palette-only clock skies")


def regenerate_check():
    before = {path.name: path.read_bytes() for path in OUT.glob("*.png")}
    assert len(before) == 9
    for _ in range(2):
        with tempfile.TemporaryDirectory() as temp:
            generate(temp)
            after = {path.name: path.read_bytes() for path in Path(temp).glob("*.png")}
            assert before == after, "Regeneration changed committed PNG bytes"
    print("PASS two clean regenerations match all nine committed PNGs byte for byte")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--regenerate-check", action="store_true")
    args = parser.parse_args()
    verify()
    if args.regenerate_check:
        regenerate_check()
