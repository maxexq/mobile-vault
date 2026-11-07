---
name: room-lineup-v3
description: MV-622 lineup preview Kitchen > Infirmary > Water Purifier v3 in one vehicle floor with frame + I-beam walls + rear ladder (no gens), artifact + lineup_v3/lineup.py
metadata:
  type: project
  modified: 2026-10-30T10:09:38.693Z
---

2026-10-30 Parames: "เรียงห้อง Kitchen > Infirmary > Water Purifier แบบมีโครง+บันได ให้ดู". Plane MV-622 (In Review).
- /mnt/project-files/designs/room-redesign-preview/lineup_v3/lineup.py: reuses armory/floor_armory.py shell + armory wall2 (8 px I-beam) / wall5 (16 px ladder shaft) strips, same method as armory/floor_ladder.py. Outputs floor_L{1,2,3}.png (4x), floor_L*_{working,powerout}.webp (1x lossless anim from each room's 144-frame gifs), stack_3f(.png/_working.webp), stack_mixed.png. Room order/sources in ORDER/STILL/INF dicts; rerun after any room art change.
- Artifact "Kitchen · Infirmary · Water Lineup" https://claude.ai/artifact/VFgNZxjkHqpSKLtHsciVz4 (page source copy lineup_v3/page_index.html; images published as files). 0 PixelLab gens.
- Observed: infirmary L3 reads much brighter/colder than neighbours; can tone-grade in code if Parames wants.
**How to apply:** for other room combos, edit ORDER in lineup.py. Related: [[kitchen-v3]], [[infirmary-v3]], [[water-room-v3]], [[room-merged-widths]], [[world-v2-scale-plan]].
