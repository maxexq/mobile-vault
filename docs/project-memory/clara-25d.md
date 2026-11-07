---
name: clara-25d
description: MV-683 Clara (field doctor, v2 'medic', opens Ren's pod in Act 1) redrawn 2.5D ~60 px per ref v3, CF-4 approved + all clips approved incl. idle CI-3, Done
metadata:
  type: project
---

2026-11-02 21:25 Parames: "create Clara field doctor per ref v3". Plane MV-683 (Needs Decision).
- Folder /mnt/project-files/designs/clara-25d/: ref_medic_idle.png (original medic idle via room-redesign-preview/gen_deep.frames), gen.py <faithful|field> <seed> = Pro generate-image-v2 64 (16 imgs, 10 gens): ref1 original medic (identity), ref2 Dr. Ren approved still (stance/size/detail only), style armory L3. Worked first try: black bob, brown skin, cream coat, satchels, 2.5D stance ~62 px.
- Picks C-1 faithful_61_1 (rec), C-2 faithful_61_14 (med kit), C-3 faithful_61_4, C-4 field_61_0, C-5 field_61_6, C-6 field_61_9. compose.py -> picks/ (solo + armory at 2/3 next to Ren, reuses medic-25d-walk/mixel.py frame()).
- 20 gens (balance 9578 after). Section on artifact Medic 2.5D Walk v9.
**How to apply:** after the pick, build idle/walk/eat/drink/work/construct/talk like Ren ([[medic-25d-walk]]): edit-image-pro-flash prop poses + animate-with-text-v3, skin.py match, mixel preview. Related: [[crew-scale-2-3]], [[dr-ren-lore]].
- 21:32 Parames: C-1 but more feminine figure (bust, waist, hips). fem.py <seed> <a|b> (edit-image-pro-flash on raw/faithful_61_1, 5 gens each, 4 calls = 20 gens) -> fem/{a,b}_{71,72}; CF-1..CF-4 = a_71,a_72,b_71,b_72, CF-4 recommended. Artifact v10. Awaiting pick.
- 21:40 Parames PICKED CF-4 (fem/b_72) -> approved/still.png. MV-683 Done. Animations (walk/eat/drink/work/construct/talk like Ren, ~45-50 gens) offered, not started.
- 21:41 Parames OK'd anims (Plane MV-685). anim/pose via pose.py <walk|eat|drink|work|construct> <seed> (edit-image-pro-flash on approved/still; work=notebook, construct=sledgehammer to match Ren's picks), anim.py <k> <pose|still> <seed> (walk 8f, others 12f), skin.py (hue/sat skin mask rows<=30 mapped to the still's own ramp; red cross excluded via s<0.62), render.py -> anim/gif. Takes CW/CE/CD/CK/CC/CT-1,2; rec CW-1, CE-1, CD-1, CK-1, CC-1, CT-2. 42 gens (balance 9286 after). Artifact v12. Awaiting picks.
- 21:53 Parames PICKED CT-2, CC-1, CK-2, CD-1, CE-2, CW-2 -> approved/<clip>/. Idle takes CI-1..3 (anim/clips/idle_still_s*, frames 1..15 used), awaiting pick. MV-685 Needs Decision.
- GOTCHA (all animate-v3 clips): frame 0 is the exact input still and differs ~3000 px from frame 1 (palette re-render) -> visible flicker once per loop. Fixed 2026-11-02: frame 0 dropped from every approved Ren + Clara clip (originals in approved/<clip>_orig/), GIFs re-rendered. Always use frames[1:-1].
- 22:18 Parames PICKED idle CI-3 -> approved/idle (+ gif/idle.gif). MV-685 Done. Expedition clips: see [[expedition-25d]].
