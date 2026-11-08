#!/usr/bin/env python3
"""MV-718: copy the approved HD biome bosses into assets/bosses_v2.

Six checkpoint bosses (MV-704, art approved in the Boss Pixel Size artifact): The Foreman, Glass King,
Mossback Alpha, Bog Mother, Cryo Titan, Warden-9. Each one was redrawn at 1.5x crew density (Cryo Titan
1.19x, PixelLab's 256 px limit) and repainted inside its biome's dusk scene, so at the same on-screen pixel
size as crew v3 / enemies v2 it is about 1.5x its design size.

Per boss, three clips side by side, art facing LEFT, all in one frame size (bottom aligned, feet on the last
row of the still) so one sprite offset fits every clip:
    <boss>_walk.png    move loop (Bog Mother: the hop, takeoff + land, arc already in the frames)
    <boss>_attack.png  attack with its own FX (beam, acid, muzzle flash, impact)
    <boss>_strike.png  the same attack without FX (removed in code), for when the game draws the hit itself
bosses_v2.json stores frame size, frame count per clip, the feet anchor (middle of the still's body,
bottom row) and the body size.

Source: the claude.ai project folder designs/bosses-v2/approved (not in git). Usage:
    python tools/bosses_v2_import.py <path to designs/bosses-v2>
"""
import json, os, sys
from PIL import Image

# biome -> (art key, approved folder, no-FX clip folder inside it)
BOSSES = {
    "industrial": ("junk_foreman", "junk_foreman_hd", "smash"),
    "desert": ("glass_scorpion", "glass_scorpion_hd", "attack_nofx"),
    "forest": ("mossback_alpha", "mossback_alpha_hd", "attack_nofx"),
    "swamp": ("bog_mother", "bog_mother_hd", "attack_nofx"),
    "tundra": ("cryo_titan", "cryo_titan_hd", "attack_nofx"),
    "metro": ("overseer_warden", "overseer_warden_hd", "attack_nofx"),
}


def clip(d: str) -> list:
    n = len([f for f in os.listdir(d) if f.endswith(".png") and f[:-4].isdigit()])
    return [Image.open(os.path.join(d, f"{i}.png")).convert("RGBA") for i in range(n)]


def main(src: str) -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "assets", "bosses_v2")
    os.makedirs(out, exist_ok=True)
    meta = {}
    for biome, (key, folder, nofx) in BOSSES.items():
        d = os.path.join(src, "approved", folder)
        still = Image.open(os.path.join(d, "still.png")).convert("RGBA")
        clips = {"walk": clip(os.path.join(d, "move")), "attack": clip(os.path.join(d, "attack")),
                 "strike": clip(os.path.join(d, nofx))}
        fw = max([still.width] + [c[0].width for c in clips.values()])
        fh = max([still.height] + [c[0].height for c in clips.values()])
        for name, frames in clips.items():
            sheet = Image.new("RGBA", (fw * len(frames), fh))
            for i, f in enumerate(frames):   # right + bottom aligned: every clip shares the still's feet line and right margin
                sheet.paste(f, (i * fw + fw - f.width, fh - f.height))
            sheet.save(os.path.join(out, f"{key}_{name}.png"))
        bb = still.getbbox()
        dx, dy = fw - still.width, fh - still.height
        meta[biome] = {"key": key, "fw": fw, "fh": fh, "w": bb[2] - bb[0], "h": bb[3] - bb[1],
                       "ax": dx + (bb[0] + bb[2]) // 2, "ay": dy + bb[3],
                       "frames": {k: len(v) for k, v in clips.items()}}
        print(biome, key, fw, fh, meta[biome]["frames"])
    json.dump(meta, open(os.path.join(out, "bosses_v2.json"), "w"), indent=1, sort_keys=True)
    print("wrote", len(meta), "bosses to", os.path.normpath(out))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/designs/bosses-v2")
