---
name: kitchen-v3
description: MV-620 kitchen redone per Room guide v3 (one-point, L1-L3 single cell only, picks delegated), files designs/room-redesign-preview/kitchen_v3/, page Kitchen v3 Samples
metadata:
  type: project
---

2026-10-30 Parames asked kitchen, grow, infirmary, water as v3, L1-L3 only, "decide yourself". Kitchen = MV-620 (Done).
- Folder /mnt/project-files/designs/room-redesign-preview/kitchen_v3/: gen_kitchen.py <A|B|C> <seed> (generate-image-v2, guide = armory/guide.png, style = armory L1 makeshift, makeshift asked in round 1), edit_kitchen.py L2|L3 <seed> [src] (edit-images-v2 via living/kitchen_edit.py), anim_kitchen.py (run from ../kitchen; ROOMS L1-L3 with fire rect, hot plates, pots, tap, stand points), hotspots_kitchen.py -> hotspots.json format 2 + hotspots_levels.png.
- Picks: L1 = out/kv3_B_7_0.png (= out/kv3_L1.png; oil-drum fire grill + tin-can stovepipe -> plank counter on cinder blocks + basin -> doorless fridge pantry, sacks), L2 = kv3_L2_s2_0 (= kv3_L2.png; iron wood stove, firewood, strapped fridge, lamp), L3 = kv3_L3_s2_0 (= kv3_L3.png; electric range + hood, steel counter, sink, microwave, LED fridge).
- States (emergency lamp via shared ../emergency_light.py at (6,6), dull when powered, pulsing in power-out, Parames v3 rule 2026-10-30): wood fire keeps L1/L2 cooking during a power-out; L3 range/LEDs die, cook waits by a lantern (upgrade trade-off). Crew street_cook + teen_scrap_runner.
- Hotspot ids stable: stove, pot, prep_table, sink (new action wash_food), fridge, pans + per-level extras. L1 sacks and L2 firewood sit in the front strip (walk polygon allows rows 93-95 only there).
- ~70 gens (balance 5206 -> 4913 incl. sibling threads). Page https://claude.ai/artifact/1XiCSBcvCqpdRHVjTckpEm (source in scratchpad kv3page/), card on index v39. Asset log group room-v3-kitchen (repo staging sparse clone tools/asset_log.py).
**How to apply:** merged 2/3 not made (out of scope); if asked, follow [[room-guide-v3]] from L3. Related: [[room-sample-pages]], [[room-redesign-preview]].
