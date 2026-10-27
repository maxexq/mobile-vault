"""MV-539: reproducible production layers from the approved native Glass Desert panels.

Never resample or quantize these inputs: exact magenta becomes binary transparency;
all other RGB pixels survive unchanged. No network or image-generation API is used.
Run from the repo root: python -m tools.art.desert_bg
"""
import hashlib
import json
from pathlib import Path
from PIL import Image
from .common import OUT_BG
from .industrial_bg import sky

SOURCE = Path(__file__).parent / "desert" / "source"
OUT = Path(OUT_BG) / "desert_live"
KEY = (255, 0, 255)
SKIES = {
    "night": ["night0", "night1", "night2", "blue1", "sand0", "sand1"],
    "dawn": ["night1", "purple1", "dusk1", "orange1", "sand2", "cream2"],
    "day": ["cream2", "cream2", "cream3", "cream3", "cream3", "cream3"],
    "dusk": ["night0", "dusk0", "dusk1", "dusk2", "orange2", "sand2"],
}


def generate(out=OUT):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((SOURCE / "manifest.json").read_text())
    for layer in manifest["layers"]:
        strip = Image.new("RGB", tuple(layer["strip_size"]))
        width, height = layer["panel_size"]
        for index, panel in enumerate(layer["panels"]):
            source = SOURCE / panel["file"]
            if hashlib.sha256(source.read_bytes()).hexdigest() != panel["sha256"]:
                raise ValueError("Approved source changed: " + panel["file"])
            with Image.open(source) as image:
                if image.size != (width, height):
                    raise ValueError("Wrong panel dimensions: " + panel["file"])
                strip.paste(image.convert("RGB"), (index * width, 0))
        if hashlib.sha256(strip.tobytes()).hexdigest() != layer["approved_rgb_sha256"]:
            raise ValueError("Approved strip pixels changed: " + layer["name"])
        pixels = list(strip.getdata())
        if layer["name"] == "road" and KEY in pixels:
            raise ValueError("Road must be fully opaque")
        rgba = Image.new("RGBA", strip.size)
        rgba.putdata([(0, 0, 0, 0) if rgb == KEY else (*rgb, 255) for rgb in pixels])
        rgba.save(out / (layer["name"] + ".png"), optimize=True)
    for name, ramp in SKIES.items():
        sky(ramp).save(out / ("sky_" + name + ".png"), optimize=True)


if __name__ == "__main__":
    generate()
    print("Glass Desert: five native RGBA strips and four clock skies generated")
