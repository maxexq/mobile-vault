---
name: infirmary-redesign
description: MV-600 infirmary v2 APPROVED (Done): A ward L1-L3 + merged 2/3 with B surgery corner, hotspots (treat_patient), PR #180
metadata:
  type: project
  modified: 2026-10-29T11:54:41.598Z
---

2026-10-29 (Plane MV-600, Needs Decision): Parames asked for the infirmary (ห้องพยาบาล) in the v2 room standard, 2 level-1 single-cell options first, same flow as [[grow-room-redesign]].
- gen_inf.py (copy of gen_grow.py: generate-image-v2 144x96, style_image kitchen/k_L1_s1_0.png, color_palette true), seed 7, 2 calls x 4 candidates, ~20 gens (balance 2575 before).
- Picks: A = out/inf_A_7_0.png (sick bay: cot, IV stand, wall medicine cabinet, oxygen tank, painted red cross, caged bulb at ~(65,12)); B = out/inf_B_7_2.png (field surgery: door-on-trestles table, hanging surgery lamp ~(74,22), supply shelves, tool cart with boiling pot, stretcher, curtain).
- walk_inf.py -> inf_L1_A/B_walk.gif (medic + scientist), sheet.png. Dir /mnt/project-files/designs/room-redesign-preview/infirmary/. Artifact Room Redesign Samples v15 top section.
**How to apply:** after the pick, do hotspots.json ([[room-hotspots]]), states anim (idle/working/powerout), then L2/L3/merged per [[room-redesign-preview]] rules; ask before big credit spends ([[pixellab-api]]).
- Round 2 (12:17) Parames: A is the main design, merged 2 rooms mixes in B; also make A L2 + L3. edit_inf.py (edit-images-v2 from inf_A_7_0): picks L2=inf_L2_s1_0, L3=inf_L3_s1_0 (dark, s2 bright clinical = alt). merge_inf.py: base = L3 left + B right (inf_m2_base), prompt "SAME wall panels, no seam"; pick inf_M2L3_s2_0 (s3 cropped the bed). Don't fire 4 PixelLab calls at once: 429 Too Many Requests.
- anim_inf.py (lamps, motes, IV drip, ECG trace box (87,45,97,53) at L3/M2, dark at power-out) -> inf_<L1|L2|L3|M2>_<state>.gif. hotspots_inf.py -> ../hotspots/infirmary_hotspots.json + overlays; uses new action treat_patient (bed, op_table) which must be added to the tools/hotspots.py whitelist in the repo PR. Artifact v17. Plane MV-600 In Review. No repo PR yet (wait for approval, like grow).
- Round 3 (12:40, asked in grow thread via coordinator): merged 3 slots L3 = merge3_inf.py (inpaint-v3 432x96, keep left 200 px of inf_M2L3_s2_0, mask x186-431), pick inf_M3_s2_0 (scrub sink, op table, big surgery lamp, anaesthesia monitor ecg2 (324,34,334,41), recovery bed behind curtain). anim key M3, hotspots key L3_x3. Artifact v18.
- 2026-10-29 12:49 APPROVED (Parames: save). PR #180 mv-600-infirmary-ref stacked on #178: infirmary/ (L1, L2, L3, L3_x2, L3_x3, option_b_L1), hotspots.json, tools/*_infirmary.py, doc section 'Fourth reference', CLAUDE.md line, treat_patient added to hotspots.py ACTIONS. Plane Done.
