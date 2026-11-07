---
name: biome-bosses-v2
description: MV-704 six lore-tied biome bosses: concepts, anims, picks, code light grade; folders, artifacts, PixelLab lessons
metadata:
  type: project
---
2026-11-03 Parames: "Design boss ใหญ่ของแต่ละ Biome". Plane MV-704 (In Review). Lore versions replace the 6 checkpoint warlords: Foreman (industrial, OVERSEER loader LDR-07), Glass King (desert, Ember Fall city on back), Mossback Alpha (forest, AURORA collar), Bog Mother (swamp, egg sac), Cryo Titan (tundra, cryo pod in chest = lore hook), Warden-9 (metro, runs TRIAGE-9). 8 wave bosses untouched.
- Folder /mnt/project-files/designs/bosses-v2/: bosses.json, gen.py (generate-image-v2, 15 gens/4 takes), compose.py, page.py+tpl.html, plane.py (set <id> <state> <html>, MV-704 id bb9465f2-52c4-4165-b8be-2b8ecf841d44), fix/cables.py, anim/anim.py <boss> <clip> <seed> (env LOOP/OPEN/N/HEAD/START/TAG), approved.py.
- PICKS 2026-11-04 12:08 (approved/<boss>/ + picks.json): Foreman IN-6 move_2L attack_2; Glass King DS-3 M-1 A-1; Mossback FO-3 M-1 A-1; Bog SW-6 HOP hopH1 A-1; Cryo TU-5A M-1 smash_2; Warden MT-2 M-1 A-1.
- Code light grade (biome x time x weather, 0 gens): grade/ (bgshot.js, grade.py, scene.py, page.py). Artifact Boss Lighting https://claude.ai/artifact/CrhqZq27sq9D8P7wkd1pym. Concepts artifact Biome Bosses v2 https://claude.ai/artifact/5JoXzRbgi1AfG7mXx3kCYg (15.1 MB, at limit).
- HD pixel-size rollout: see [[biome-bosses-hd]].
Lessons: read gens from job usage (balance diff polluted by other threads). Give headroom (cables clip). first+last = still kills limb motion; use first-frame-only or an edit-image-pro-flash key pose then animate. Hop = leap key + takeoff/land clips + arc in code. v3 draws FX even when told not to: remove in code. Artifact root must be under scratchpad.
Related: [[enemies-v2-per-biome]], [[dr-ren-lore]], [[pixellab-usage-report]], [[crew-scale-2-3]].
