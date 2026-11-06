---
name: room-v3-emergency-light
description: RULE Parames 2026-10-30: every v3 room power-out shows the same red emergency dot lamp at top-left pixel (6,6) with a blinking red glow
metadata:
  type: feedback
---

2026-10-30 03:41 Parames (grow v3 thread): move the power-out emergency light to the left of the screen at pixel (6,6), a red dot like an emergency lamp, identical in every v3 room.
**Why:** one consistent power-out signal across all rooms reads instantly as "power is out".
**How to apply:** use the shared module /mnt/project-files/designs/room-redesign-preview/emergency_light.py (grow thread, 03:50), which replaces the bare 2x2 dot. Call `emergency_light.draw(px,W,H,t,lit)` after darken (needs kitchen/ on sys.path for anim). It draws a dark bracket + 5x4 red dome at x3-9 y1-7 that is ALWAYS visible (dull red with power on). With lit=True (power-out), it adds the glow first and then the bright dome pulsing at 0.5 Hz. Used in grow3/anim_grow3.py; the coordinator told the other v3 threads to match it. The game's RoomAmbience power-out should draw the same fixture. Code only, 0 gens. Related: [[room-guide-v3]], [[infirmary-v3]], [[grow-room-v3]].
