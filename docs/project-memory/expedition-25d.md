---
name: expedition-25d
description: MV-686 Ren + Clara expedition clips (gun walk, flashlight walk, carry walk, shoot, search) APPROVED picks saved to approved/, beam from lens + lock_feet fix, Done
metadata:
  type: project
---

2026-11-02 21:54 Parames: add walk-with-gun, walk-with-flashlight, walk-carrying (for expedition), shoot, and (21:56) search, for both Ren and Clara. Plane MV-686 (Needs Decision).
- Folder /mnt/project-files/designs/expedition-25d/: pose.py <ren|clara> <kind> <seed> (edit-image-pro-flash; walk kinds edit the 3/4 walk key: Ren keys/edit_12, Clara anim/pose/walk_82; shoot/search edit the still). Ren gun = dart tranquilizer pistol (lore: Ren doesn't kill), Clara = worn pistol. Ren flashlight needed "big chunky yellow-and-black utility flashlight" wording (seed 93) or it reads as a pistol.
- anim.py <stem> <seed> (animate-with-text-v3, walk/shoot 8f, search 12f). render.py: frames[1:-1], muzzle flash pixels on shoot frames 1+4 (rightmost opaque pixel rows 10-32), flashlight cone drawn in room space, 2/3 armory via medic-25d-walk/mixel.py frame(). Takes RX1..5-1/2 and CX1..5-1/2 on artifact Medic 2.5D Walk v13.
- PixelLab: 12 edits (60) + 20 anims (20) = 80 gens, + Clara idle 3 -> balance 8958 after.
Related: [[medic-25d-walk]], [[clara-25d]], [[crew-scale-2-3]].
- 22:18 Parames PICKED RX1-2, RX2-1, RX3-2, RX4-1, RX5-2 / CX1-2, CX2-2, CX3-1, CX4-2, CX5-2 -> medic-25d-walk/approved/<clip> and clara-25d/approved/<clip> (clips gunwalk, torchwalk, carrywalk, shoot, search; table in expedition-25d/APPROVED.md). MV-686 Done, artifact v14.
- Fixes asked: flashlight beam must start AT the lens -> render.py lens() (rightmost opaque column rows 12-30, middle of its run, start height = lens height). RX4-1 lost boot sole row 63 on frames 2-5 -> lock_feet() copies rows 62-63 from frame 0 when legs didn't move (shoot clips). In game, anchor light cone per frame to the lens point.
- 22:25 Parames asked a wall-interact clip for expedition interiors. MV-688 (Needs Decision). pose.py kind "wall" (3/4 back view, both hands up at head height, no shelf drawn), anim.py "wall" 12f, render.py lock_feet for wall too; render.py takes an optional stem filter. Picked keys ren_wall_102 / clara_wall_101; takes WR-1/2, WC-1/2. wall_scene.py previews at hospital hotspots med_cabinet (Ren) / pharmacy_a (Clara), reusing exp-interior/medic-walk/walk.py grade. 24 gens (balance 8719 after, others spent too). Artifact v16. Use for hotspots with face "back".
- 22:46 Parames PICKED WR-2 (ren_wall_102_s2) + WC-1 (clara_wall_101_s1) -> approved/wall (+ gif/wall, room_wall, hosp_wall). MV-688 Done.
