---
name: celestial-clean-disc
description: RULE parallax sun/low sun/moon = clean disc with nothing over it (clouds are their own layer), effect = code halo; MV-706
metadata:
  type: feedback
---

2026-11-03 Parames: "ปรับดวงอาทิตย์ และ ดวงจันทร์ของทุก Biome เอาพวก เมฆหรืออะไรที่บังออก เหลือแค่ effect ของมันเอง เพราะ เมฆ...ถูกแยก layer ไว้แล้ว".
**Why:** clouds, smog and trees already live in their own parallax layers, so anything painted over the disc doubles up.
**How to apply:** prompts for sun/low/moon must say "single clean disc, nothing in front: no clouds, bands, stripes, smoke, branches, buildings". Don't use animate-with-text for drifting clouds. Animation = code effect (designs/bg-parallax-page/celestial_clean/sheet.py: dithered halo breathing over 8 frames, 64x512 sheets). A moon's own surface features (craters, desert cracks) are fine.
Done for all 6 biomes (MV-706, artifact v17): gen.py, generate-image-v2 64x64, 10 gens per 16 variants, 180 gens; PICK dict in sheet.py; old sheets in celestial_clean/old/. Approved/ folders of the earlier biomes still hold the old sheets: copy the new ones in once approved. Related: [[biome-parallax-ref]]
