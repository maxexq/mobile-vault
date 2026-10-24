#!/usr/bin/env python3
"""Sprites for the loading page's driving scene (tools/web_shell.html) -> web/boot/.

Godot doesn't export loose PNGs for the HTML shell, so these are committed in web/boot/ like
web/logo.png. Rerun after regenerating the atlas or the desert backdrop:

    python3 tools/boot_art.py
"""
import json
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "web", "boot")
SCENE_H = 112  # logical height of the scene canvas in the shell


def atlas_sprite(atlas, frames, key):
    x, y, w, h = frames[key]
    return atlas.crop((x, y, x + w, y + h))


def shrink(img, factor):
    """Box-downscale, then snap back to the source palette and a hard alpha edge (stays true pixel)."""
    img = img.crop(img.getbbox())
    small = img.resize((img.width // factor, img.height // factor), Image.BOX)
    pal = img.convert("RGB").quantize(colors=48, dither=Image.Dither.NONE)
    out = small.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
    out.putalpha(small.getchannel("A").point(lambda v: 255 if v > 110 else 0))
    return out


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    atlas = Image.open(os.path.join(ROOT, "assets/atlas/atlas.png")).convert("RGBA")
    frames = json.load(open(os.path.join(ROOT, "assets/atlas/atlas.json")))
    # the Mobile Vault itself, a third of its in-game size (wheels are drawn by the shell)
    shrink(atlas_sprite(atlas, frames, "ext_bus"), 3).save(os.path.join(OUT, "bus.png"))
    # walker zombie, two frames side by side (native 12x20)
    w0, w1 = atlas_sprite(atlas, frames, "en_walker_0"), atlas_sprite(atlas, frames, "en_walker_1")
    sheet = Image.new("RGBA", (w0.width + w1.width, max(w0.height, w1.height)))
    sheet.paste(w0, (0, 0))
    sheet.paste(w1, (w0.width, 0))
    sheet.save(os.path.join(OUT, "walker.png"))
    # desert backdrop: sky band from dusk to horizon, layers trimmed to their content
    sky = Image.open(os.path.join(ROOT, "assets/bg/desert_sky.png")).convert("RGBA")
    sky.crop((0, 900 - 3 * SCENE_H, 1, 900)).save(os.path.join(OUT, "sky.png"))
    for name in ("sun", "far", "mid", "near", "road"):
        img = Image.open(os.path.join(ROOT, f"assets/bg/desert_{name}.png")).convert("RGBA")
        bb = img.getbbox()
        img.crop((0, bb[1], img.width, bb[3])).save(os.path.join(OUT, f"{name}.png"))
    for f in sorted(os.listdir(OUT)):
        print(f, Image.open(os.path.join(OUT, f)).size)


if __name__ == "__main__":
    main()
