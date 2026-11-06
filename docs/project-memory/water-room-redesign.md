---
name: water-room-redesign
description: MV-607 water room (Data.ROOMS "water" = WATER PURIFIER, not a bathroom) v2: picked C, L1-L3 + merged 2/3 + anim + hotspots done, In Review
metadata:
  type: project
  modified: 2026-10-29T19:33:31.155Z
---

2026-10-29 (Plane MV-607, Needs Decision): Parames asked for the water room (called ห้องน้ำ in chat, but in the game it is "water" = เครื่องกรองน้ำ / WATER PURIFIER, produces clean water) in the v2 standard, level 1 single slot first.
- gen_water.py (copy of gen_inf.py, generate-image-v2 144x96, style kitchen/k_L1_s1_0.png, seed 7), zones left->right: dirty intake -> filter/treatment -> clean storage (MV-605 rule 3). 3 calls x 4 = 12 candidates, ~25 gens.
- Picks shown: A = out/wt_A_7_2 (layered bucket gravity filter, rain pipe into blue barrel, white drum with tap; lamp ~(65,8)), B = out/wt_B_7_3 (moonshine-style copper still on gas burner, jugs; right crate touches image edge), C = out/wt_C_7_0 (hand pump + valve manifold, tall tank with gauge + cartridge filter, purple UV box ~(124,47)).
- walk_water.py -> wt_L1_<k>_walk.gif (scientist + plant_grower). Dir /mnt/project-files/designs/room-redesign-preview/water/. Artifact Room Redesign Samples v22 top section.
- Asset log: this cloud env now has ASSET_LOG_URL + CF_ACCESS_* and reaches the site; backfill via PR #184's tools/asset_log.py (run from repo tools/ dir, needs pixellab.py beside it) group room-v2-water.
**How to apply:** after the pick do hotspots.json, idle/working/powerout anim (water drips, flame/UV glow), then L2/L3/merged per [[room-redesign-preview]] + [[pixellab-room-gen-rules]]. Related: [[infirmary-redesign]], [[asset-log-site]].
- Round 2 (19:42) Parames picked C, asked L2 + L3 + animation. edit_water.py (edit-images-v2 from wt_C_7_0) picks L2=wt_L2_s1_0, L3=wt_L3_s1_0 (s2 too bright). L3 drums stood in the walkway + cut by edge -> fix_drums.py inpaint-v3 box (121,58,143,95), seed 2 -> out/wt_L3.png.
- anim_water.py (lamps, motes, drips, UV purple pulse, L3 pump/panel LEDs + level-tube bubbles; powerout: UV/LEDs off, drips continue) -> wt_<L1|L2|L3>_<state>.gif. hotspots_water.py -> hotspots.json + hotspots.png; NEW action purify_water (tank station) must be added to tools/hotspots.py ACTIONS in the repo PR. Artifact v23. Plane In Review. No repo PR yet (wait for approval). Merged 2/3 not made.
- Round 3 (20:03) merged L3: GOTCHA edit-images-v2 at 288 wide ALSO zoomed ~1.25x (tanks too big for crew) -> use inpaint-v3 keeping left px pixel-identical (merge2i_water.py SRC SEED [W KEEP]). M2 = keep 96 px of wt_L3, seed 1 (s2 legs hit walkway) -> out/wt_M2.png. M3 = 432, keep 186 px of M2, seed 2 -> corner drum shifted up 6 px by pixel copy (inpaint kept re-adding a drum) -> out/wt_M3.png. Anim keys M2/M3 (screens, tube2), hotspots L3_x2/L3_x3. Artifact v24. ~150 gens this round.
