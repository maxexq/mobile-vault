---
name: biome-bosses-hd
description: MV-704 boss HD redraw so boss pixels = Crew v3 (B2-2 in-scene), pipeline, per-boss status, Boss Pixel Size artifact
metadata:
  type: project
---
Key fact: bosses were drawn at crew density, so under ref v3 (world x3, crew x2) they belong at x2. Parames 2026-11-04 picked B2-2: redraw at 1.5x and repaint inside the biome dusk scene, show at x2 (same screen size as old x3, pixels = Dr. Ren).
Pipeline (/mnt/project-files/designs/bosses-v2/): hires/edit.py <boss> 2 (env SCALE, edit-image-pro-flash, 9 gens) -> hires/incontext.py <boss> <png> dusk 2 (inpaint-image-pro-flash, max 256x256, mask = silhouette, 9 gens) -> anim/start/<boss>_hd.png (feet bottom, 6 px right) -> START=... TAG=hd [LOOP=1|OPEN=1] anim.py (5-8 gens) -> no-FX: anim/nofx_hd.py <boss> (env SRC) + despeck.py (diff vs still + FX colour, 0 gens) -> grade/hd_all.py <boss> -> grade/out/hd_<boss>_{still,move,attack,nofx,combo}. Saved approved/<boss>_hd/{still,move,attack,attack_nofx}+README.
- Foreman HD APPROVED (HD-M1 + HD-A1 + smash-only, approved/junk_foreman_hd).
- 2026-11-04 "ไปต่อ": other 5 done (Claude picks); ALL 6 APPROVED by Parames 2026-11-11, READMEs marked, MV-704 Done. Bog move = HD hop (keys/leap_hd_2, hop2_hd.py, arc x1.5). Cryo at 1.19x not 1.5x (1.5x = 308 px > 256 limit), smash redone as shoulder-height swing (smashlow s3), eyes restored in code, no-FX drops impact frame. 183 gens; balance 2298 after.
- Light is baked for dusk only; other times = code grade on top or a repaint per time (not done).
- Artifact Boss Pixel Size https://claude.ai/artifact/4LDkM7VK1G7UxpNEhebh9z v5, source in session scratchpad bosspx/ (copy of grade/page_pixel/; republish from a scratchpad copy).
Related: [[biome-bosses-v2]], [[crew-scale-2-3]].
- 2026-11-08 Parames: put them in game replacing the old bosses -> MV-718, PR #198 (stacked on #195, base mv-714-enemies-v2). Switch bosses_v2, tunes bosses_v2.scale 0.5 / bosses_v2.fx (0 = strike no-FX clip); Combat.BOSSES_V2 names merged by boss_def (stats/mech unchanged); BossesV2 + assets/bosses_v2 via tools/bosses_v2_import.py; GOD Dev.bosses_v2_preview; autotest --only=bosses_v2; enemy_size test turns bosses_v2 off. Game artifact v61 = staging + #195 #196 #197 #198 (no cloud_config, web/ not committed). Light baked dusk only.
- 2026-11-08 20:03 PR #198 MERGED to staging; MV-718 Awaiting Verify.
- 2026-11-11: Parames asked to replace old bosses; already done on staging (#198, switch on, web export has 18 sheets). uat/main (Oct) lack it until a promotion PR. 8 WAVE_BOSSES still old art (never redesigned).
- 2026-11-11 MV-772: Parames "keep only the new-design bosses": switch bosses_v2_only (default on) retires the 8 WAVE_BOSSES, boss waves = this biome's new boss (Combat.pick_wave_boss / new_bosses_only), GOD Dev.new_bosses_only, test _bosses_v2_only_part in --only=bosses_v2.
