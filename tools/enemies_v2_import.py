#!/usr/bin/env python3
"""MV-714: copy the approved v2 enemy clips (MV-677/680/703) into assets/enemies_v2.

Each mob gets <mob>_move.png and <mob>_attack.png: 8 frames side by side, art facing LEFT. Both clips of a
mob share one frame size (padded) so one sprite offset fits both. enemies_v2.json stores the frame size,
the body anchor (ground mobs: middle of the feet; flyers: middle of the body) in frame pixels, and the
body size.
The art is drawn at crew v3 density (Dr. Ren 61 px = 1.75 m); the game shows it at
Features "enemies_v2.scale" (0.5 = one art px per screen px with world_2x).

Source: the claude.ai project folder designs/enemies-v2 (not in git). Usage:
    python tools/enemies_v2_import.py <path to designs/enemies-v2>
"""
import json, os, sys
from PIL import Image

# mob id -> (move take dir, attack take dir); takes picked in the Enemies v2 by Biome artifact
PICKS = {
    "rad_rat": ("rad_rat_run_3", "rad_rat_attack_2"),
    "scav_raider": ("scav_raider_walk_3", "scav_raider_attack_2w"),
    "rust_drone": ("rust_drone_move_1", "rust_drone_attack_1"),
    "scorpion": ("scorpion_move_1", "scorpion_attack_2"),
    "sand_raider": ("sand_raider_move_1", "sand_raider_attack_1"),
    "vulture": ("vulture_move_1", "vulture_attack_2"),
    "rad_wolf": ("rad_wolf_move_1", "rad_wolf_attack_1"),
    "vine_crawler": ("vine_crawler_move_1", "vine_crawler_attack_1"),
    "mutant_bug": ("mutant_bug_move_1", "mutant_bug_attack_1"),
    "toxic_toad": ("toxic_toad_move_4", "toxic_toad_attack_1"),
    "bog_walker": ("bog_walker_move_1", "bog_walker_attack_1"),
    "mosquito": ("mosquito_move_1", "mosquito_attack_2"),
    "frost_wolf": ("frost_wolf_move_2", "frost_wolf_attack_2"),
    "yeti": ("yeti_move_1", "yeti_attack_1"),
    "frost_owl": ("frost_owl_move_1", "frost_owl_attack_1"),
    "sentry_bot": ("sentry_bot_move_1", "sentry_bot_attack_2"),
    "mutant_ape": ("mutant_ape_move_2", "mutant_ape_attack_2"),
    "hunter_drone": ("hunter_drone_move_3c", "hunter_drone_attack_3"),
}
# first-batch Industrial clips were made before canvas.json existed: body top-left in the frame
LEGACY = {"rad_rat_run_3": (10, 19), "rad_rat_attack_2": (10, 19), "scav_raider_walk_3": (8, 8),
          "scav_raider_attack_2w": (36, 8), "rust_drone_move_1": (7, 14), "rust_drone_attack_1": (7, 14)}
FRAMES = 8


def main(src: str) -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "assets", "enemies_v2")
    os.makedirs(out, exist_ok=True)
    kinds = {k: v["kind"] for k, v in json.load(open(os.path.join(src, "enemies.json"))).items()}
    sizes = json.load(open(os.path.join(src, "picks", "sizes.json")))
    meta = {}
    for mob, takes in PICKS.items():
        bw, bh = sizes[mob]["w"], sizes[mob]["h"]
        air = kinds[mob] == "air"
        clips = {}
        for clip, take in zip(("move", "attack"), takes):
            d = os.path.join(src, "anim", take)
            if take in LEGACY:
                bx, by = LEGACY[take]
            else:
                c = json.load(open(os.path.join(d, "canvas.json")))
                bx, by = c["front"], c["top"]
            frames = [Image.open(os.path.join(d, f"{i}.png")).convert("RGBA") for i in range(FRAMES)]
            ax, ay = bx + bw // 2, by + (bh // 2 if air else bh)
            clips[clip] = (frames, ax, ay)
        # one frame box around both clips, same anchor
        left = max(ax for _, ax, _ in clips.values())
        top = max(ay for _, _, ay in clips.values())
        right = max(f[0].width - ax for f, ax, _ in clips.values())
        bottom = max(f[0].height - ay for f, _, ay in clips.values())
        fw, fh = left + right, top + bottom
        for clip, (frames, ax, ay) in clips.items():
            sheet = Image.new("RGBA", (fw * FRAMES, fh))
            for i, f in enumerate(frames):
                sheet.paste(f, (i * fw + left - ax, top - ay))
            sheet.save(os.path.join(out, f"{mob}_{clip}.png"))
        meta[mob] = {"w": bw, "h": bh, "air": air, "fw": fw, "fh": fh, "ax": left, "ay": top, "frames": FRAMES}
    json.dump(meta, open(os.path.join(out, "enemies_v2.json"), "w"), indent=1, sort_keys=True)
    print("wrote", len(meta), "mobs to", os.path.normpath(out))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/designs/enemies-v2")
