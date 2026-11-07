---
name: pets-preview
description: MV-601 vehicle pets (3 dogs, 3 cats, 3 chickens) PixelLab art; REALISTIC size approved + saved in approved-realistic/, pipeline + costs
metadata:
  type: project
  modified: 2026-10-29T13:36:56.982Z
---

2026-10-29 (Plane MV-601, In Review): Parames asked to see 3 dogs, 3 cats, 3 chickens matching the new crew (proportions, palette, style). Preview only, no game code.
- Artifact "Vehicle Pets Preview" https://claude.ai/artifact/HZ4YGcnpF2aX1vABHU2KMp (source site/index.html + g/*.gif). Files: /mnt/project-files/designs/pets-preview/ (gen.py, anim.py, scene.py, pick/, anim/, candidates/).
- Static: POST /v2/generate-image-v2 at tiny sizes (<=32 px -> 64 candidates per call, 10 gens), style_image = medic walk frame 0 (64x64 transparent), color_palette true, no_background true. Canvas size sets animal scale: 32 -> dog 27-31 px tall, 24 -> cat/rooster ~20-24, 20 -> hen ~20. Smaller "realistic" round (reference_images = first pick, 16-30 px canvas) lost detail; preview uses the bigger set, comparison shown in artifact.
- Animation: POST /v2/animate-with-text-v3 with first_frame = 64x64 pick (feet row 53), 1 gen per take, returns frame_count+1 frames (frame 0 = start). Say 'strict side profile facing right, never turns toward the camera' or the dog turns 3/4. Walk loop = frames 1..8, idle = ping-pong.
- GOTCHA: PixelLab Tier 2 allows max 11 concurrent background jobs across ALL threads (429 otherwise): run <=5 in parallel.
- Picks: names dog_mutt/dog_shepherd/dog_terrier/cat_ginger/cat_black/cat_tabby/hen_brown/hen_white/rooster; take ids in scene.py PICK. Black cat too dark on dark rooms (suggest rim light). ~220 gens (balance 2077 before, shared).
- 14:17 Parames: add sleep pose to terrier, mutt, ginger cat, tabby, brown hen. Done as lie-down (animate-with-text-v3 8 frames from pick) + sleep loop (6 frames, first_frame = lie-down last frame); takes in scene.py SLEEP. Plain 'lies down' shrank the tabby/hen, so used 'curls into a round ball' / 'sits flat like a fluffy feather ball, body keeps the same size'. Artifact v2.
- 15:01 Parames: try realistic size walking in 1/2/3-cell rooms. Small picks in picks/ (16-24 px), walk takes anim/s<name>/walk*_21, rooms kitchen L3 / B2 / B3 via scene_small.py (artifact v3). Small brown hen at 16x16 canvas came out broken (two birds/grid); 18x18 with 'one bird only' fixed it (s2_hen_brown_23_0). Small set has no idle/sleep yet. Awaiting size pick.
- 2026-10-29 16:16 APPROVED: Parames chose and saved the REALISTIC (small) size. Saved to /mnt/project-files/designs/pets-preview/approved-realistic/<pet>/still.png + walk/0-7.png + manifest.json (+ room GIFs). Plane MV-601 Done. Big 'readable' set and its idle/sleep are superseded; realistic set still lacks idle + sleep (redo from picks/ if asked). Not in the repo yet.
Related: [[pixellab-api]], [[crew-anim-preview]], [[room-redesign-preview]].
