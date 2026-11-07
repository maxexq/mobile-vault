---
name: halloween-rest-room
description: MV-615 Halloween festival rest room (guide v3, single cell only, L1-L3 + anims + hotspots), all picks made by Claude, Done 2026-10-30
metadata:
  type: project
  modified: 2026-10-30T02:59:07.965Z
---

2026-10-30 Parames: Halloween-themed rest room as a special festival room per [[room-guide-v3]], "pick everything yourself up to L3, no 2/3-room versions". Plane MV-615 (Done).
- Folder /mnt/project-files/designs/room-redesign-preview/halloween/: gen_hw.py <A|B|C> <seed> (generate-image-v2, layout = armory/guide.png, style = rest/out/rs_B_7_0.png), edit_hw.py L2|L3 <seed> [src], anim_hw.py (idle/working/powerout, crew_blend), hotspots_hw.py (format 2, imports armory overlay), walk_lv.py.
- Picks: L1 = out/hw_C_7_2.png (haunted campfire: taped sofa + witch hat, pumpkin pile, pallet candy table + skull candle, oil-drum fire, jack-o-lantern shelf, sheet ghost, skeleton garland), L2 = out/hw_L2_s2_0.png (orange string lights, iron stove), L3 = out/hw_L3_s1_0.png (purple sofa, green cauldron, electric fireplace, LED pumpkin display, chest).
- Power-out uses shared ../emergency_light.py (red lamp at (6,6), dull when powered). Electric stuff dies but candle pumpkins/real fire keep burning, ghost eyes glow green.
- hotspots.json adds NEW action open_festival_menu (candy table) -> add to tools/hotspots.py ACTIONS in the repo PR. Ties to the Festival framework in [[festival-minigame-plan]].
- 70 gens (L1 30, L2 20, L3 20; edits = 10 each). Page "Halloween Rest Room" https://claude.ai/artifact/UTbeLJ9Sop9iYJCSC2csnk (source in scratchpad; read before republishing), card on index v37. Asset log group room-v2-halloween (cloud env vars work for backfill).
**How to apply:** if Parames wants changes, rerun the scripts above; not in the game yet (waits for world_v2 + Festival framework). Related: [[rest-room-v3]], [[room-sample-pages]].
