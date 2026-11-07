---
name: medic-sofa-sleep
description: MV-668 Medic walk -> sit -> lie -> sleep on the Living Room (L3) sofa preview, 2 takes, artifact Medic Sofa Sleep, awaiting pick
metadata:
  type: project
---

2026-11-01 Parames: "make the Medic go sleep on the Living Room sofa, preview". Plane MV-668 (Needs Decision).
- Room = living/out/lv_L3_s1_0.png (MV-597 approved Living Room, sofa x14-75, seat y~57); Medic = ORIGINAL approved medic (crew-anim-preview GIFs via room-redesign-preview/gen.py frames()).
- Folder /mnt/project-files/designs/medic-sofa-sleep/: lie_still.py <seed> (edit-image-pro-flash on last sit frame -> raw/lie_<seed>.png, 5 gens), lie_anim.py <k> <seed> (animate-with-text-v3 first = sit_last, last = lie_k -> raw/down_k_s1, 1 gen), compose.py <take> (walk in, sit with lerp up to seat, lie, 24f code breathing + Z glyphs, crew_blend, TV via anim_lv) -> medic_sofa_sleep_<k>.gif, sleep_loop_<k>.gif, strip_<k>.png.
- Lying frame bottom row 48 (5 px higher than sit row 53); sofa frame centre x=46.
- 12 gens (11430 -> 11418). Artifact "Medic Sofa Sleep" https://claude.ai/artifact/R2GSgQ3ZkXtr1bt2Mrz8ZR (source scratchpad/page, copy in folder page/). Take 1 recommended. Not in game.
Related: [[crew-room-blend]], [[crew-anim-preview]], [[room-redesign-preview]].
