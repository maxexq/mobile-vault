---
name: room-camera-one-point
description: Parames 2026-10-29: ONE-POINT PERSPECTIVE cutaway is the standard camera for all new v2 rooms (replaces the flat front view); every gen sends the layout guide as reference_images
metadata:
  type: feedback
  modified: 2026-10-29T21:18:08.433Z
---

2026-10-29 21:17 Parames (MV-609 thread): make the one-point perspective camera the guide/standard.
Camera: open front (front wall removed), back wall a centred rectangle (x 30-114, y 8-68 in 144x96), left/right walls + ceiling slant to it, floor lines converge to one central vanishing point, slightly above eye level.
**How to apply:** every new room gen = generate-image-v2 with `reference_images` = the layout guide (/mnt/project-files/designs/room-redesign-preview/armory/guide.png or guide_walk{6,8,10}.png once a walkway width is picked) + style_image = kitchen L1 (palette/outline only, "not its camera"). Kitchen camera (flat back wall, no side walls) is retired for new rooms. Old rooms (kitchen, living, grow, infirmary, water) are still flat; regen (~140 gens each) only when Parames orders it. Merged 288/432 guides not made yet. Spec doc: https://claude.ai/artifact/W3aaAdWtzeUYMgdDAaXLAM. Repo docs/art/room-style-reference-v2.md + CLAUDE.md still say flat front view: update in the next repo PR. Related: [[armory-redesign]], [[room-redesign-preview]], [[pixellab-room-gen-rules]], [[crew-room-blend]].
