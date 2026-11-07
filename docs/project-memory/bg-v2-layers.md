---
name: bg-v2-layers
description: CANCELLED - layered v2 backgrounds (MV-163, PR #45 closed unmerged): tools/art/bg2.py real-scale 8 layers, long strips, per-biome palette, bg_v2 switch, lazy biome loading; industrial done, 5 biomes left
metadata:
  type: project
---

2026-10-24: Parames asked for a background revamp: more layers, prettier (>32-bit), things/buildings in realistic proportion, loop long enough not to feel repeated. Approved art-rule exception for backgrounds (also in CLAUDE.md).
- PR maxexq/mobile-vault#45 (branch mv-163-bg-revamp, Plane MV-163). Industrial converted; desert/forest/swamp/tundra/metro still v1 (fallback automatic).
- `tools/art/bg2.py`: scale rule 20 px = 1.75 m (PPM 11.4) x layer speed; layers clouds_hi .02, clouds_lo .045, far .07 (1440), far2 .13 (1920), mid .25 (2880), mid2 .40 (2880), near .60 (3840), road 1.0 (1920); ground line = HORIZON(ROAD_Y-40) + 40*speed; 96-colour median-cut palette per biome; output assets/bg/v2/<biome>_*.png + <biome>.json + _thumb.png.
- PixelLab kit: tools/art/pixellab/kit.json + kit/*.png via `pixellab.py kit all --prefix ind_ --yes` (10 trial gens; trial left 19 on 2026-10-24). kit.json `trim_bottom` removes PixelLab's pavement slabs.
- background.gd: v2_layout(id) static, builds only current biome (+fading), frees others; Features.changed rebuilds. GOD world tab: skip +30 s/+2 min, bg_v2 toggle. Autotest `--only=bg`.
- Portrait shows mostly sky: far layer needed 60-95 storey high-rises to fill it.
**How to apply:** next biomes = add BIOMES entry + layer recipes + kit items (~10 gens each, ask before spending). Related: [[pixellab-api]], [[feature-flags-design]], [[god-mode]].

- 2026-10-24 08:22 CANCELLED by Parames: keep the original backgrounds; PR #45 closed, branch mv-163-bg-revamp kept. Quota goes to rooms instead.
