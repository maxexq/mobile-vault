---
name: biome-parallax-ref
description: RULE Industrial 5-layer parallax road background APPROVED as reference for all biomes (designs/bg-parallax-industrial/approved/README.md); next biomes follow it
metadata:
  type: feedback
---

2026-11-02 Parames approved Industrial (MV-684 Done): ambulance, PixelLab sun/moon, 24 h slider.
**Why:** look, sizes, loops and anim approach approved.
**How to apply:** every biome = concept still pick -> far 1x 1280x170 / mid 1x 1600x130 / near 2x 3200x160 / road 2x 1280x128 strips (inpaint outpaint, 1 seed per ext) + code anim + cloud/prop/decal sheets; sun/moon: Parames 2026-11-02 wants each biome to get its OWN PixelLab sun/low-sun/moon ("ทำ sun and moon ด้วยนะ แบบ biome แรก"). Order after industrial: desert (MV-690), forest, swamp, tundra, metro. Details + gotchas in approved/README.md; plan history in [[bg-parallax-5layer-plan]].

Desert (MV-690, APPROVED + Done, saved bg-parallax-desert/approved/): concept B. Lessons: far lock_src=band.png + palette recolour fixes far drift; crop road strip off near/road seg1; skies are code-made banded gradients (page stretches column 0).
Combined preview (all biomes, biome selector, before/after): page source designs/bg-parallax-page/ (template.html + build.py + spots_<biome>.json), published at the old Industrial URL https://claude.ai/artifact/QNMzL5sSSobED3sqVKBBzY. New biome = add SRC entry in build.py + BIO entry in template + spots json.
Forest (MV-693, APPROVED + Done 2026-11-03 08:55, saved bg-parallax-forest/approved/): concept A; designs/bg-parallax-forest/ (pb.py, near1/road1/clouds/sheet.py, celestial/, helper fixes clearpale.py / seamblend.py / ramp.py / topfade.py), page/a. Tall trees cut by strip top: Parames 2026-11-03 asked for real crowns instead of the fade -> mid made 56 px taller (1600x186, top y112, BIO midY) and crowns outpainted with midtop.py (inpaint-v3 5 chunks x15 + redo chunk 0, 90 gens) + floating-blob cleanup; near also extended 72 px (3200x232, top y174, BIO nearY) via tops.py (generic: any layer, chunk list, wrap ctx both sides, 15 gens/chunk) + floating cleanup + carve.py (scalloped tops/flat-bottom shelves); props keep base y 210; inpaint seam patches came out saturated (wasted 45 gens), code seam fixes better. New page features: glow spot type (night mushrooms), leaves, fireflies (BIO flags). Gap/cut-edge pass (2026-11-03): near now 3200x256 (nearY 162: near is 2x density so +24 image px = +12 game px; nearY 150 left a gap above the road, +24 headroom so crowns never touch row 0), rect inpaint via patch2.py (canvas capped 160 rows = 10 gens, layer near|mid) + carve_rects2.py (carves top/left/right/bottom patch edges); generic edgecarve.py was too weak/chewed vines, prefer targeted patches. PixelLab balance also dropped by other work in parallel; report only own usage + note the gap.

Swamp = TOXIC BAYOU (MV-696, APPROVED + Done 2026-11-03 09:43, saved approved/): concept A; designs/bg-parallax-swamp/ (chain.sh = ext+join per layer, run with `bash`, mount has no exec bit). Built with headroom from the start: mid 1600x146 (midY 152), near 3200x184 2x (nearY 198); template glow/drip accept colour fields c1/c2/c. ~436 gens. LESSON: template edits by string splice must keep the tail (template got truncated once, recovered from artifact read).
Tundra = FROZEN HIGHWAY (MV-699, APPROVED + Done 2026-11-03 10:36): concept A; designs/bg-parallax-tundra/approved/README.md has files + lessons (opaque seg1 reject, road layout prompt, exact colour fix). ~481 gens.

- 2026-11-03 car light per biome: template.html CARL[bio][tod] + carSheet() (cached grade), v15. New biome = add CARL entry.
- Metro = RUINED METRO (MV-701, APPROVED + Done 2026-11-03 11:24, saved approved/): concept B; designs/bg-parallax-metro/. New BIO farY (far raised to 112), mid 146 tall (+16 px headroom, midY 152), pb.py lock_band option locks road dash rows; road seg3 drew a sidewalk twice -> replaced by seg2 in code. ~456 gens.
