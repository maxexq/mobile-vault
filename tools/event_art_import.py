#!/usr/bin/env python3
"""Copy the approved 320x160 road event art (MV-674/675, no vehicle) into the game (MV-730).

Source (claude.ai project files): designs/event-art-<folder>/hd/novan/<name>_novan_story_sheet.png
= 80 frames of 320x160 in a 10 x 8 grid, 10 fps, the story's last frame held 1.6 s (same as the GIF).
Writes assets/events/v2/ev_<image>_anim.png (the sheet) and ev_<image>.png (the last frame = the
story's outcome beat, used on the result screen). <image> is Data.EVENTS[id].image.

    python3 tools/event_art_import.py /mnt/project-files/designs
"""
import glob
import os
import sys

from PIL import Image

# event-art folder -> game image id (Data.EVENTS[..].image)
EVENTS = {
    "acid": "acid", "bridge": "bridge", "bugs": "bugs", "bunker": "bunker", "cache": "cache",
    "cultists": "cult", "frozen": "frozen", "gambler": "gambler", "gas": "gas", "mutant-hen": "hen",
    "plane": "plane", "radstorm": "radstorm", "raiders": "raiders", "rogue-bot": "robot",
    "sandstorm": "sandstorm", "signal": "signal", "stray-cat": "cat", "stray-dog": "dog",
    "survivor": "survivor", "trader": "trader", "wolves": "wolves",
}
W, H, COLS, ROWS = 320, 160, 10, 8


def main(src: str) -> None:
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "events", "v2")
    os.makedirs(out, exist_ok=True)
    for folder, image in EVENTS.items():
        sheets = glob.glob(os.path.join(src, f"event-art-{folder}", "hd", "novan", "*_novan_story_sheet.png"))
        if len(sheets) != 1:
            sys.exit(f"{folder}: expected one story sheet, found {sheets}")
        sh = Image.open(sheets[0]).convert("RGBA")
        if sh.size != (W * COLS, H * ROWS):
            sys.exit(f"{folder}: sheet is {sh.size}, expected {(W * COLS, H * ROWS)}")
        last = COLS * ROWS - 1
        still = sh.crop(((last % COLS) * W, (last // COLS) * H, (last % COLS + 1) * W, (last // COLS + 1) * H))
        sh.convert("RGB").save(os.path.join(out, f"ev_{image}_anim.png"), optimize=True)
        still.convert("RGB").save(os.path.join(out, f"ev_{image}.png"), optimize=True)
        print(f"{folder:12s} -> ev_{image}.png + ev_{image}_anim.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/designs")
