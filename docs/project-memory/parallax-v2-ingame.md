---
name: parallax-v2-ingame
description: MV-710 approved 5-layer parallax bgs for all 6 biomes in the game (PR #192 to staging), switch parallax_v2, ParallaxV2Backdrop, world_2x render switch
metadata:
  type: project
  modified: 2026-11-04T13:13:11.830Z
---

2026-11-04 MV-710 (In Review), PR maxexq/mobile-vault#192 (branch mv-710-parallax-v2 -> staging), playable artifact v57.
- Assets: assets/bg/v2/<biome>/ copied from designs/bg-parallax-<biome>/approved + page (far/mid 1x, near/road/props/decals 2x density, sky_{night,dawn,day,dusk}, sun/low/moon_sheet 64x64x8 frames, clouds/, biome.json = Y overrides + flags + spots).
- Code: scripts/world/parallax_v2_backdrop.gd (class ParallaxV2Backdrop). Background._build_group adds groups[id].v2; v2 wins over legacy + modern (industrial/desert) when Features "parallax_v2" on; Background.backdrop_kind(id).
- Tune parallax_v2.<layer>_speed, parallax_v2.cloud_wind. GOD world tab "PARALLAX V2" rows; Dev.parallax_v2_preview(tod).
- Autotest _parallax_v2_test (--only=parallax_v2); old industrial/desert tests force parallax_v2 off.
- 2026-11-04 Parames picked world 2x: main.gd world_vp renders render_k=2 px per art px via size_2d_override (+stretch); coords stay art px; main.vp_size() = art size; switch world_2x (tune view.world_render), 1x when world_scale < 2. Use vp_size(), never world_vp.size, for art-space math.
- Preview art changes must be re-copied into assets/bg/v2 (no auto sync).
Related: [[biome-parallax-ref]], [[celestial-clean-disc]]
