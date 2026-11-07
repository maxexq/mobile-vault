---
name: rear-gunner-v3
description: MV-705 rear gunner room v3 (crew shoot from inside, no turret) L1-L3 per Room guide v3 + anim + hotspots fmt 2, page Rear Gunner Room v3, In Review
metadata:
  type: project
  modified: 2026-11-03T11:31:43.219Z
---

2026-11-03 Parames: "Design ห้องสำหรับให้ crew ไว้ยิงมอน/บอส ที่ท้ายรถ". Same day design decision (other thread): turrets DROPPED, combat = crew shoot from inside rooms. Plane MV-705 (id 5ff03bee-e529-4e68-9029-143201dcb246) In Review. Builds on [[rear-gunner-offcenter]] (MV-629) but uses the standard centred one-point camera.
- Folder /mnt/project-files/designs/room-redesign-preview/gunner_v3/: guide_gunner.py (armory guide + firing hatch cut into the RIGHT side wall = vehicle rear; gen-v2 followed it 8/8), gen_gunner3.py A <seed>, edit_gunner3.py L2|L3 <seed>, grid.py, anim_gunner3.py (soldier fires MG bursts out of hatch, muzzle flash/tracers/casings, monsters + red-eyed boss silhouettes clipped to the hatch sky mask, hunter at spotter slit, truck_driver ammo runner; power-out: manual gun keeps firing), hotspots_gunner3.py (room "gunner", new actions man_gun, spot_targets, load_ammo; gun not needs_power), page_gunner_v3.html, plane_mv.py.
- Picks: L1 out/gunner3_A_7_0, L2 gunner3_L2_s1_0, L3 gunner3_L3_s1_0 (gamma 0.97/0.88 -> luma 40/40/42). final/gunner_L{1,2,3}.png + hotspots.json.
- 6 PixelLab calls (generate-image-v2 x2, edit-images-v2 x4); balance 3500 -> 3219 in the window, other threads spending concurrently.
- Page https://claude.ai/artifact/VtGEtKFqNLSYxzfqUjDsGT (scratchpad gunner_site/), not on room index yet.
- Open: rear 16 px ladder shaft collides with the hatch wall; crew have no "shoot" clip (uses idle + recoil jitter).
**How to apply:** Related: [[room-guide-v3]], [[room-hotspots]], [[room-v3-emergency-light]], [[crew-room-blend]].
