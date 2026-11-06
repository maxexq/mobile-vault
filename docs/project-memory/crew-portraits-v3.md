---
name: crew-portraits-v3
description: MV-708 bust portraits 64x64 for all 11 ref v3 crew (Ren, Clara + 9 lore crew), Claude picks, artifact Crew v3 Portraits, awaiting OK
metadata:
  type: project
---

2026-11-03 15:02 Parames: "ทำ portrait ตัวละคร v3". Plane MV-708 (Needs Decision).
- Folder /mnt/project-files/designs/crew-portraits-v3/: gen.py <k> <seed> = Pro generate-image-v2 64x64 (16 imgs, ~10 gens/call), ref = character's approved v3 still (identity), style armory L3, prompt = head+shoulders bust, 3/4 view right, no bg. Seed 91 worked first try for all 11 (DESC pulls lore-crew-3/gen.py C tables).
- picks.json (Claude picks, index into raw/<k>_91_<i>.png) -> picks/<k>.png, lineup.png; page/build.py + tpl.html -> page/index.html. plane.py = tiny Plane helper (create/state/link/comment).
- Artifact Crew v3 Portraits https://claude.ai/artifact/BRaMVGdncUG3aLYj4umpeB (publish copy from scratchpad). ~110 gens (2902 -> 2792).
- The 16 takes per character already vary expression (smile/angry/thinking), a free source for mood portraits. Game still uses 20x20 pt_ portraits; v3 portraits not in game.
Related: [[lore-crew-3]], [[crew-scale-2-3]], [[crew-roster-20]].
- 2026-11-04 Parames asked for the old portrait ref: = 25 approved crew v2 portraits 64x64 in designs/crew-v2-roster/src/approved/portraits/ (sheet: crew-portraits-v3/old_ref/v2_portraits_sheet.png). Brighter, anime-leaning, slightly front-facing vs the darker v3 busts.
- 2026-11-04 13:05 Parames: redraw ONE character at a time using the v2 medic portrait as ref, approve each before the next. r2/gen2.py <k> <seed> (style_image = crew-v2-roster/.../portraits/medic.png 64, ref = v3 still), ~16 gens/call. Style pulls skin toward the medic's tan -> r2/skin.py <src> <out> <r,g,b> (HSV shift to still's skin, Ren = 184,163,135). Ren: options R-1 = ren_101_0_skin, R-2 = ren_101_6_skin (r2/ren_options.png), awaiting pick. Order after Ren: clara, bit, wan, sorn, lin, tham, fah, krai, ploy, noi.
- 15:21 Parames: younger Dr. Ren face (lore body age 26). gen2.py ren <seed> young (DESC override: early-mid 20s, clean shaven) -> r2/raw/ren_young_111_*; Y-1 = ren_young_111_0_skin (r2/ren_young_option.png vs R-1). Awaiting verdict.
- 15:24 Parames approved young Ren -> approved/ren.png = STYLE ref for the rest (env STYLE=approved/ren.png python3 r2/gen2.py <k> <seed> [variant]). Clara: plain DESC came out masculine (Ren-like); "fem" variant (feminine face, bob with bangs) worked: C-1/2/3 = clara_fem_122_{1,6,5}, awaiting pick. Mount lag: raw files can appear ~10 s after the script ends.
- 16:51 Parames RULE: each portrait keeps the character's OWN outfit from its still; from the Ren ref take only face angle + framing. gen2.py variant sets STYLE_USE (style_image usage = angle/framing/pixel density only, not clothes) and DESC spells out the still's outfit. Clara fem2 seed 123 -> C-4/5/6 = clara_fem2_123_{0,8,11}, awaiting pick.
