---
name: crew-scale-2-3
description: RULE ref v3 (Parames 2026-11-02): crew drawn ~60 px and shown at 2/3 over rooms (room x3, crew x2, ~40 px tall), every pixel kept
metadata:
  type: feedback
---

2026-11-02 21:04 Parames approved "2/3 scale (keeps every pixel)" as ref v3 (MV-679), after rejecting the 38 px PixelLab-resized crew (too little detail).
Rule: crew sprites are drawn at ~60 px (64 canvas, feet row 63, like Dr. Ren R-01) and displayed at 2/3 of room pixel scale: room x3, crew x2 on screen -> ~40 px tall in room units. Mixed pixel sizes are accepted on purpose; keep both factors integer so nothing blurs.
**Why:** Parames wants the 2.5D detail but the v2 crew height.
**How to apply:** new crew art = ~60 px; previews via designs/medic-25d-walk/mixel.py (crew_blend grade in sprite space, shadow ~15 room px, walk speed x2/3); refs in designs/medic-25d-walk/mixel/approved/README.md. Game impl (render 3x base res, crew scale 2/3, all crew) not done yet; mirror into CLAUDE.md / room style doc in the next repo PR. Related: [[medic-25d-walk]], [[crew-room-blend]], [[crew-v2-detail]], [[room-guide-v3]].
