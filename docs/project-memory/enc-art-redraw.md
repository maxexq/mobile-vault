---
name: enc-art-redraw
description: MV-717 expedition encounter art x6 APPROVED 2026-11-08 (designs/enc-art/approved/), in game via EncArt + switch enc_art_v2 (branch mv-717-encounter-art-v2)
metadata:
  type: project
---

2026-11-08 Parames asked if the expedition "special encounter / meet people" images were redone (no: all 6 enc_* still old 160x80; road event survivor MV-642 is separate) then "start, show a sample before deciding".
- Folder /mnt/project-files/designs/enc-art/: gen.py (A <enc> <seed> = inpaint-v3 into <enc>/bgA.png with maskA.png; B = generate-image-v2 320x160 style bgA), flash.py (code flashlight: dark scene, warm dithered cone from left edge (0,112), sweeps from floor to target, 48 frames), page/ (artifact https://claude.ai/artifact/QkFnSxuk9fDn8rwYkgbEzG).
- No crew drawn in encounter art (flashlight from the left edge stands for whoever is on the expedition). 320x160 like new road events.
- survivor: before_x2.png cut from scene-prompts/refs/current_events.png (5,373). A bg = hospital strip crop (280,20,600,180), picks raw/A_2 (shields eyes behind wheelchair), raw/B_1 (behind overturned desk, cold dark). 40 gens (4 x 10). Parames picked A for all.
- All 6 done 2026-11-08 (picks: survivor A_2 hospital x280; wounded A_1 store x560; cry bunker x330: A_1 figure removed (raw/empty_1, inpaint) + crew v3 Krai silhouette 60 px pasted via cry/sil.py (Parames: silhouettes = crew v3 size) + HELP/red pulse fx; vault A_1 ruins x1020 + pebbles; floor A_1 plant x330 + dust; toxic A_1 hospital x960 + fumes). Outputs <enc>/final.gif/_x2/_still. Page rebuilt by page/build.py (v2). 100 gens for 5. Plane MV-717 In Review. Not in game: EncounterPopup needs 320x160 + animated texture.
- 2026-11-08 RULE (Parames): people/silhouettes in encounter art = crew v3 size (60 px); cry fixed with Krai silhouette.
- 2026-11-08 Parames "save all into the game": approved/README.md + approved/game/ sheets (8x6 cells, 10 fps, sweep once then loop 18-47). Repo: assets/events/v2/, scripts/ui/enc_art.gd, popup uses EncArt.anim_texture/still, Dev.enc_art_v2 + GOD โลก toggle, autotest --only=enc_art_v2. Web export not done in cloud (no cloud_config.json).
Related: [[exp-interior-redraw]], [[event-art-320]], [[expedition-encounters]].
