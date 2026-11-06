---
name: room-guide-v3
description: Claude Doc "Room guide v3 (armory reference)" = the standard for making new rooms (one-point, 144/296/448, I-beam walls, merged-room consistency, ~215 gens/room)
metadata:
  type: reference
  modified: 2026-10-30T02:10:53.469Z
---

2026-10-30 Parames asked to turn the armory (MV-609) into the guide for v3 rooms. Doc: https://claude.ai/artifact/22nXsMMv5di9u1iEsdEsZR (Thai). Sections: overview + picked files, camera/sizes/vehicle (8 px I-beam, 16 px rear ladder shaft, 480 px floor), levels (L1 makeshift), step table with scripts/endpoints/gens, merged 2/3 rules + working methods (no fresh 448 gen; extend x2 via inpaint or code scaffold gen_x3n.py), anim/powerout/crew blend/hotspots format 2, gen budget (~215 per new room) + don'ts, per-room checklist + open questions.
**How to apply:** follow it for every new or redone room; it supersedes the older "Room creation spec v2" doc (https://claude.ai/artifact/W3aaAdWtzeUYMgdDAaXLAM) where they differ. Related: [[armory-redesign]], [[room-merged-widths]], [[room-camera-one-point]], [[room-l1-makeshift]], [[crew-room-blend]], [[pixellab-usage-report]].
Rule added 2026-10-30: every v3 room's emergency light is the shared red lamp at (6,6), emergency_light.py (lit in power-out). Guide rev 10.
