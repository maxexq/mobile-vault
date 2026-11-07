---
name: event-vehicle-facing
description: RULE event art with the vehicle: cab must face east/west toward the encounter; fix = flip crop + inpaint-v3 seams (raiders done)
metadata:
  type: feedback
---

2026-10-30 Parames: "ถ้าในเหตุการณ์มีรถ รถต้องหันหน้า east, west ให้ถูกตามเหตุการณ์ที่กำลังเจอ".
**Why:** the ambulance driving away from the threat reads wrong; the scene must show it meeting the encounter.
**How to apply:** decide which side the encounter sits on before gen (put it in the prompt); if a pick faces wrong, flip only the vehicle crop and inpaint the seams/old lights. Headlights point the same way. Also in [[event-art-rogue-bot]] approved/README.md. Status: rogue_bot, cultists OK; raiders fixed (rev 2 anim: code-drawn searchlight head turns with its beam, headlight cones east); signal faces west while the tower is east, offered fix, awaiting answer. Page [[event-samples-page]].
- 2026-10-30 15:20 raiders rev 3 ("pl"): PixelLab rig via inpaint-v3 (rev3/spot.py; seed 4 filled the mask bg cream fffee2 -> keyed back to base, still usable), drum head cut to rev3/head.png and rotated 0-40 deg in code; animate-with-text-v3 on a 56x64 crop (1 gen/take, 16 frames) gives fire + gang idle, pasted only in per-figure rects so the bg doesn't drift.
- 2026-10-30 15:14 Parames APPROVED raiders rev 3; MV-641 Done.
- 15:45 Parames: put a crew v2 character (cast in docs/art/crew-style-reference/approved/cast, 48x48) in the event instead of a generic figure, same angle, keep identity. Recipe in event-art-survivor/v2char/; see [[survivor-spot-ref]]. Picked teen_scrap_runner.
- 15:55 woman version: motorbike_courier (gen-v2 came out facing right -> mirror the pick so the figure faces the truck), courier/ subfolder. Then 16:05 lounge_singer version (singer/).
- 20:30 wolves (MV-657): designs/event-art-wolves/, frozen highway dusk snowstorm, pick raw/wolves_1 (gen-v2 drew it facing WEST: zoom on the cab of every pick), mirrored + 2 inpaints; pack anim pack_8 one-shot,
- 20:40 wolves rev 2: Parames saw the front wolf headless (animate crop started at x 88 and cut the head; also the paste window excluded the head rows) + 2 rear wheels missing after the mirror. Fix: inpaint wheels, re-animate on a crop that includes every figure's full body, paste window must cover where the figure MOVES.
- wolves, acid (MV-658) Done; Parames checks wheels on every truck. bunker (MV-659): designs/event-art-bunker/; gen-v2 drew the modules in reference order but with the cab on the other end (orange next to the cab): check module order too (mirrored C = cab right, cross module next to cab, orange at far left/rear); fixed by mirroring only the module span x14-71.
- 21:25 bunker Done. radstorm (MV-660): prompt that spells out the module order (cab right, cross box behind cab, cream, orange far-left rear, 4 wheels) gave a correct truck first try -> use that wording in every new gen.
- bridge (MV-661) redo: Parames wants the truck ON the bridge at the broken edge (raw2/bridge_1). bridge Done. trader (MV-662) round 1 rejected; round 2 = real caravan (wagon, ox, fire), truck right first try with 'directly behind the cab' wording; figure rises + waves in ONE animate-with-text-v3 take (Parames: no stepping; stitched clips jump), legs locked while waving; trader Done. frozen (MV-663) Done. sandstorm (MV-664): gen-v2 drew 3/4 view in all 4 (desert prompt), Done. plane (MV-665): 'flat side view' + 'seen exactly from the side' in the prompt gave side views; round 2 (cab visible, wreck apart) Done. gas (MV-666): night pick had near-invisible wheels -> code wheels. gas Done. gambler (MV-667) shake loop + throw one-shot. Left: bugs, cache, cat, dog, hen. inpaint-v3 wheels at 160x80 come out oversized.
