---
name: water-room-v3
description: MV-618 water purifier redone per Room guide v3 (one-point, L1-L3 single cell, Claude picked all), states + hotspots format 2 done, In Review; files designs/room-redesign-preview/water_v3/
metadata:
  type: project
  modified: 2026-10-30T03:25:39.962Z
---

2026-10-30 Parames: "make kitchen, grow, infirmary, water as v3, L1-L3 only, decide yourself" (sibling threads did the other rooms). Plane MV-618 (In Review).
- Folder /mnt/project-files/designs/room-redesign-preview/water_v3/: gen_wv3.py <A|B|C> <seed> (generate-image-v2 144x96, reference armory/guide.png, style armory L1 makeshift; equipment from v2 option C), edit_wv3.py L2|L3 <seed>, anim_wv3.py (wv_L{1,2,3}_{idle,working,powerout}.gif; bus_mechanic at pump stand (44,90), scientist tank -> UV; powerout: L1/L2 hand pump + lantern keep going, UV off; L3 all electric dead except battery LED; red emergency dot at (6,6) per v3 rule), hotspots_wv3.py -> hotspots.json format 2 + hotspots_levels.png.
- Picks: L1 = out/wv_A_7_0.png (copied out/wv_L1.png), L2 = wv_L2_s1_0 (wv_L2.png), L3 = wv_L3_s2_0 cool grey (wv_L3.png). Row C candidates had white borders.
- Hotspot ids match v2 water (hand_pump, manifold, tank=purify_water, filter, uv_box, bench, lamp + L3 panel). Barrel base (left) and jerry cans (right) touch the walkway, so floor.walk excludes those corners.
- Page "Water Purifier v3 Samples" https://claude.ai/artifact/FpfpmY1ApYPWA746dccXLK (source scratchpad of that session; read with Artifact read before republishing), card on index v40. Asset log group room-v3-water (backfill via staging tools/asset_log.py, sparse clone).
- ~70 gens mine (3 gen calls + 4 edits); balance 5206 -> 4903 incl. sibling threads.
**How to apply:** merged x2/x3 not made (not asked). On approval: repo PR with images + hotspots.json. Related: [[room-guide-v3]], [[water-room-redesign]], [[rest-room-v3]].
