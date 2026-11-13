# Icons v4 (MV-775): 16 px icons at the v3 room pixel size

One PNG per icon (`<name>.png`, or `set_<piece>.png` for gear set pieces), 16x16, made with PixelLab Pro
`generate-image-v2` directly at 16x16 (v3 room props as style image, the icons v2 art as reference), then
stray edge bits removed and a closed 1 px soot outline added. Picks, prompts and scripts live in the project
folder `designs/icons-v4/` (gen.py, desc.json, pick.py + picks_fix.json, outline.py, review.py).
`python3 tools/icons16_import.py` bakes these into `assets/icons16/icons16.png`; an icon without a file here
falls back to the code reduction of its icons v2 art.

Mood faces (happy, neutral, sad, stressed, broken) are not PixelLab: `moods.py` draws them in code on one
shared 16 px circle (black outline, flat orange, black features) so every face has the same round shape
(Parames 2026-11-13). Run `python3 tools/art/icons16/moods.py` then `python3 tools/icons16_import.py`.
