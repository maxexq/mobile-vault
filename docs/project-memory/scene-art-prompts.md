---
name: scene-art-prompts
description: MV-177 prompt kit for redrawing all 49 scene images with external GPT image (gpt-6.1-sol); scene inventory, sizes, crew bible, refs in designs/scene-prompts/
metadata:
  type: project
  modified: 2026-10-24T18:11:35.209Z
---

2026-10-24, Plane MV-177 (Done): Parames asked for prompts to give "GPT Sol 6.1" (ChatGPT gpt-6.1-sol image) to redraw every scene, matching the PixelLab room art, crew based on the real roster. No game code changed.
- Kit: /mnt/project-files/designs/scene-prompts/ — scenes.py (source of truth: STYLE guide, character bible, per-scene prompts), build_prompts.py <repo> renders scene-prompts.md + scene-prompts.html (artifact https://claude.ai/artifact/HwZ1TLNf5QPaXpNk6hXu9c), refs/ (rooms, palette, named crew, outfits, pets/enemies, vehicle screenshot, current_* contact sheets).
- Scene inventory (repo main): 21 road events assets/events/<image>.png 160x80 (Data.EVENTS image key, e.g. stray_dog -> dog.png); 6 encounters enc_*.png 160x80; 2 story images story_sos/story_command 160x80 (Meta.STORIES); 7 expedition interiors assets/exp/exp_<kind>.png 256x100, seamless horizontal tile, feet line y=86, no people (ExpeditionFeed.KIND maps 13 sites to 7 kinds); 13 stops = atlas lm_* sprites, 100 wide, varying height, transparent, door centred x=30, bottom row = road.
- Named crew (game.gd + lore.gd): Mark dw_army_brown, Leo dw_scav_brown, Ton dw_jumpsuit_black, Bob dw_chef_gray, Clara dw_medic_red, Bruno dw_army_black. Pets Khao Tang dog, Som Jeed cat, Khai Dao 2-headed hen.
**How to apply:** when Parames sends back GPT images, run tools/art/pixelize.py (--size, --keep-lines 0.2) per scene, key #FF00FF for stops, then lm_* need an atlas override path (they are not standalone PNGs). Gate behind a Features switch per [[feature-flags-design]]. Related: [[pixellab-api]], [[codex-art-analyst]], [[event-window-layout]].
- 2026-10-25 MV-377 (Done): parallax kit /mnt/project-files/designs/parallax-prompts/ (parallax.py + build_parallax.py, imports scene-prompts/scenes.py palette + build_prompts CSS; artifact https://claude.ai/artifact/DLoccVUZ2jbrs1ZjcRoXdh). Format copies the merged wide industrial set assets/bg/industrial_live/ (MV-369, PR #77, IndustrialBackdrop, Features industrial_parallax): clouds 1984x220, far 1920x300, mid 1920x230, near 2112x124, road 2304x64, sun/moon 32x32, sky_<night|dawn|day|dusk> 64x900 made in code; layer bottoms on ROAD_Y. GPT makes each layer as 4 panels on #FF00FF; Claude keys, pixelizes, stitches, fixes the loop seam.
