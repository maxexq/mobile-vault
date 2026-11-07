---
name: crew-gun-anim
description: MV-594 hold-gun + shoot clip per crew (PixelLab), one character at a time, 2 options each; pipeline + effects-in-code
metadata:
  type: project
  modified: 2026-10-29T01:31:01.395Z
---

2026-10-29 (Plane MV-594): Parames wants a hold-gun + shoot clip for all 25 crew, gun fitting each personality, one character at a time (2 options, iterate until approved). Casings + muzzle flash per gun type. Aims up/level/down only for the medic so far.
- Pipeline (scripts in /mnt/project-files/designs/crew-gun-anim/: pl.py, edit_hold.py, anim.py, fx.py, prev.py): 1) POST /v2/edit-image-pro-flash on the 60x60 approved work/0 frame -> "holding <gun>" pose (5 gens, palette correction on, no_background). 2) POST /v2/characters/animations mode v3, east, frame_count 8, custom_start_frame = hold pose, action says "no muzzle flash, no smoke" (1 gen). 3) fx.py snaps to master palette, strips PixelLab's own flash pixels + stray components, overlays code-drawn flash + casings per GUNS table (pistol/smg/shotgun/revolver/rifle/flare), muzzle = rightmost opaque pixel in gun rows.
- Parames 01:32: medic gets BOTH guns + 3 aims (up/level/down). v3 animate (even with end_frame = start) always drifts back to level aim mid-clip, so aims are built as: 1 edit per aim from the level hold pose ("only arms, hands and gun change"), then recoil.py code recoil (upper body -1 px, arms+gun -1 px more; pattern pistol 02100210 shots 1,5, smg 021212100 shots 1,3,5), then fx.py <aim>; grid.py makes the 2x3 review GIF. ~15 gens per gun per character.
- Medic: A pistol (seed 1, shots frames 1,5, 9 fps) vs B SMG (anim seed 3, frame 8 dropped because hair turned grey, shots 2,3,4, 12 fps). Medic total 41 gens (3313->3272). APPROVED 01:46: level = PixelLab clips (option_A_pistol / option_B_smg), up/down = code recoil; final medic/medic_final_3_aims.gif.
- Shoot canvas is 72x60 (fx.norm): PixelLab returns wider frames (72) when the gun nears the edge, padded evenly; 60-wide start sits at x=0. Cast start = work/0 figure re-placed on 60x60 (centre x30, feet row 48), char.py does start->hold->anim->fx. First anim seed often fails (gun swaps hands / points up): retry with 'stays pointing straight forward in every frame'.
- Per-character takes, seeds, gens and approvals: [[crew-gun-anim-log]].
- COLOURS: approved cast clips on staging are raw PixelLab colours (not snapped); snapping greys skin and hides eyes. fx.py keeps raw colours and strips PixelLab flashes by flashy() (saturated yellow or near-white); medic only uses SNAP=1 (its coat = flash colour, approved snapped). rebuild.sh re-renders every kept clip.
- Approved: see [[crew-gun-anim-log]] (level only except medic up/down). Files /mnt/project-files/designs/crew-gun-anim/<char>/fx_*. Balance is shared with other threads: count gens from own calls (edit 5, anim 1).
- Robust anim wording: 'standing still, hand(s) keep the gun level and pointing straight forward in every frame, small recoil..., then back to the same aim'.
- 2026-10-29 09:20: 8 approved chars (22 clips) exported (export.py CLIPS list -> approved/gun_animations/<char>/<clip>/ + manifest gun_animations with muzzle per frame) to DRAFT PR #179 (branch mv-594-crew-gun-anims -> staging); add each newly approved char to CLIPS, rebuild, export, push. Tools mirrored in repo tools/art/crew_gun/. Set PYTHONDONTWRITEBYTECODE=1 (tools/art/__pycache__ is tracked).
- Thread hit the 24-attachment cap: review GIFs now go on artifact 'Crew Gun Review' https://claude.ai/artifact/WoT92KDmcyj8UdFZ5dpPX8 (source <scratchpad>/review/index.html + g/*.gif; scratchpad path is now /tmp/claude-0/-home-user-mobile-vault/...). Review page also lists all approved clips (generated from manifest gun_animations).
- recoil.py tears the sprite at the waist (WAIST 34 row cut) on characters with backpacks/long hair: Parames saw it as 'half the body tearing'. Use BODY=1 (whole figure above row 44 moves) and an eased pattern like 012121210.
Related: [[pixellab-api]], [[crew-anim-preview]], [[plane-setup]].
