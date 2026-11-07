---
name: empty-cell-v2
description: MV-603 empty vehicle cell (before a room is built) in v2 room style, picked A + building materials (empty_A_mat.png), In Review
metadata:
  type: project
---

2026-10-29 (MV-603, Needs Decision): Parames asked for the empty slot before building a room, 3 options, static (no animation yet).
- Made with generate-image-v2 144x96, style_image = kitchen/k_L1_s1_0.png, color_palette true (same recipe as living L1). Script + picks: /mnt/project-files/designs/room-redesign-preview/empty/ (gen_empty.py, out/em_{A,B,C}_7_{0-3}.png, empty_{A,B,C}.png with white bottom row fixed). 3 calls, balance 1822 -> 1786 (36 gens).
- A bare steel shell (hanging cables, capped pipe, unlit bulb) / B construction-ready (hazard tape, planks, toolbox, work lamp) / C gutted abandoned (torn insulation, tarp, cold window light, a bit bluer). B candidates 1-3 had a chalk body outline (crime-scene look), avoid.
- Shown at top of Room Redesign Samples artifact v20 incl. floor strips kitchen L1 | empty | living L1.
- 2026-10-29 Parames picked A and asked to add crates + construction materials: edit_empty.py (edit-images-v2 from empty_A.png, 3 seeds), used seed 3 -> empty/empty_A_mat.png (front floor clear, pipe kept). Artifact v21. PixelLab balance now 1742.
**How to apply:** after pick, likely needs a construction-in-progress state + hotspots; add to world-v2 art list ([[world-v2-scale-plan]]). Related: [[room-redesign-preview]], [[pixellab-api]].
