---
name: crew-portraits-v3
description: MV-708 v3 crew portraits 64x64 in v2 portrait style, all 11 APPROVED 2026-11-08 in designs/crew-portraits-v3/approved/ (README), Done
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
- 2026-11-08 Parames picked Clara C-4 -> approved/clara.png. Generic variant "own" (DESC + own outfit, STYLE_USE angle/framing only). Bit seed 131 own: B-1/2/3 = bit_own_131_{2,4,7} (r2/bit_options.png), awaiting pick. Next: wan, sorn, lin, tham, fah, krai, ploy, noi.
- Bit B-1 approved -> approved/bit.png. Wan seed 141 own: W-1/2/3 = wan_own_141_{0,3,8}, awaiting pick.
- Wan W-3 approved -> approved/wan.png. Sorn seed 151 own: S-1/2/3 = sorn_own_151_{0,5,12}, awaiting pick.
- Sorn S-1 approved -> approved/sorn.png. Lin seed 161 own: L-1/2/3 = lin_own_161_{1,0,10}, awaiting pick.
- Lin L-1 approved -> approved/lin.png. Tham seed 171 own: T-1/2/3 = tham_own_171_{5,0,7}, awaiting pick.
- Tham T-1 approved -> approved/tham.png. Fah: 'own' came out male + Ren turtleneck -> use variant 'ownf' for women (feminine face + no turtleneck/lab coat). F-1/2/3 = fah_ownf_182_{4,0,6}, awaiting pick. Use ownf for Ploy + Noi too.
- Fah F-1 approved -> approved/fah.png. Krai seed 191 own: K-1/2/3 = krai_own_191_{0,2,11}, awaiting pick.
- Krai K-1 approved -> approved/krai.png. Ploy seed 201 ownf: P-1/2/3 = ploy_ownf_201_{0,3,9}, awaiting pick.
- Thread hit 24-attachment limit: from Ploy on, options go on the artifact page via page/build2.py <k> <P> <stem> <i,i,i> <out=scratchpad/portraits.html> + republish (tpl2.html: current options, approved wall, all 16).
- Ploy P-1 approved -> approved/ploy.png. Noi seed 211 ownf: N-1/2/3 = noi_ownf_211_{0,3,6}, awaiting pick (last one).
- 2026-11-08 18:35 Noi N-1 -> ALL 11 APPROVED. approved/<k>.png + README (source table + recipe) + lineup.png. Plane MV-708 Done, artifact v4 = approved wall. Round-1 dark picks (picks/) are superseded. Game impl not started.
- 2026-11-08 18:37 Parames: put them in the game -> MV-722 (branch mv-722-crew-portraits-v3): switch crew_portraits_v3, UIKit.portrait(variant, big, d) shows V3Art.portrait_tex(V3Art.crew_for(d)) in a 32 px slot (64 big), tools/v3_import.py --portraits-only -> assets/v3/portraits/, GOD CREW "PORTRAITS v3", autotest --only=crew_portraits_v3.
