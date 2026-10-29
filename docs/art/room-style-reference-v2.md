# Room style reference v2 (new crew scale)

Parames approved the mess kitchen as the reference for every future room on 2026-10-29
(MV-593, MV-595). It was drawn for the new crew characters in the
[crew style reference](crew-style-reference.md), which are about 38 px tall. The old
[64x52 room reference](room-style-reference.md) still describes the art that is in the game
today. Putting v2 rooms in the game needs the larger room size below, so it is a separate
decision (see MV-595).

Preview with animations: https://claude.ai/artifact/SpjgTwP7hzkvF64zc3Hcww

![levels](room-style-reference-v2/levels-preview.png)
![merged](room-style-reference-v2/merged-preview.png)

## Art contract

- **144x96 native pixels per room slot**, three slots per floor. Merged rooms are 288x96 (2 slots)
  and 432x96 (3 slots), one continuous room with no dividing wall or pillar.
- **Camera:** front view of a room cross-section, slightly above eye level, so the floor is a
  visible deep plane of floor plates that recedes to the back wall. Every room uses this same
  camera. No flat side-scroller floor strip, no isometric view.
- **Crew feet on y≈90** in a single room. Leave an open walkway along the front of the floor across
  the whole width, so crew walk on the floor in front of the furniture and never look like they
  float over it. Merged rooms put feet on y=94 in front of stools and tables.
- Dark post-apocalyptic, muted desaturated colours, crisp dark outlines, warm lamp light as the
  saturated accent. Nearest filter, binary alpha.
- People, pets, light, steam and other moving things are not baked into the background; they are
  drawn on top (see Animation states).

## Room levels

Each room has three levels, and the art must change visibly at every level:

| Level | Kitchen example | Rule |
|---|---|---|
| 1 | camp burner on a crate, cooler box, one crooked shelf, trash on the floor | makeshift, scavenged, poor |
| 2 | two-burner stove, old fridge, tiled wall, fuller shelves | a working room, still worn |
| 3 | cooking range with oven and hood, microwave, water filter, clean fridge, tidy shelves | **cleaner and more equipment** |

All three levels keep the same layout (L1 and L3 are edits of L2), so object anchors move little.

## Merged rooms

- Rooms can only merge at **level 3**, so merged art always looks upgraded and clean.
- A 2-slot merge keeps the L3 room on the left and adds a second purpose on the right
  (kitchen: a clean bar counter with stools, bottle shelves, coffee machine, menu board).
- A 3-slot merge keeps what the 2-slot room had, moved over and made bigger and better
  (kitchen: a longer bar with six stools, beer tap, lit bottle wall, big menu, standing table).

## Animation states

Every room has three states, drawn in code on top of the background:

- **Empty (idle):** lamp glow with a slow pulse and rare flicker, dust motes in the lamp light,
  plus room-specific micro animation (kitchen: steam from the pot, one low gas flame,
  L3 device LEDs).
- **Working:** crew at the room's work spot using their `work` clip, others walking the aisle;
  stronger effects (kitchen: every burner lit, more steam).
- **Power out:** room darkened to ~30 % with a blue tint, a slow red emergency light in the top-left
  corner, the lamp flickering back on now and then, only self-powered light left
  (kitchen: the gas flame).

The preview implementation and the anchor coordinates of every kitchen image are in
`room-style-reference-v2/tools/anim.py` (`ROOMS`).

## How the kitchen was made (PixelLab)

Sources are in `room-style-reference-v2/kitchen/`; the scripts in `tools/` are the exact ones used
(they read and write a scratch `out/` folder).

1. **L2 base:** `POST /v2/generate-image-v2`, `image_size` 144x96 (returns 4 candidates),
   `style_image` = the approved medic idle frame 0 (64x64, transparent),
   `style_options.color_palette` false, seed 7. Prompt in `gen.py` + camera text in `gen_deep.py`.
2. **L1 / L3:** `POST /v2/edit-images-v2` (`edit_with_text`) on the L2 image (`edit.py`), so the
   layout stays.
3. **2-slot merge:** L3 + its mirror on a 288x96 canvas, then `edit-images-v2` with the bar prompt.
4. **3-slot merge:** `POST /v2/inpaint-v3` on a 432x96 canvas: left 200 px of the 2-slot room kept,
   x 186-431 masked and redrawn as the bigger bar (`inpaint3.py`).
   Do not use `edit-images-v2` above ~300 px wide: it zooms in and crops the scene.

Cost on the subscription: about 10 generations per `generate-image-v2` call and 10-15 per edit or
inpaint call.

| File | SHA-256 (first 16) |
|---|---|
| kitchen/kitchen_L1.png | 87762585af5d979e |
| kitchen/kitchen_L2.png | fa092d12b974f521 |
| kitchen/kitchen_L3.png | 7820237e2221babf |
| kitchen/kitchen_L3_x2.png | e98d7050343d5fff |
| kitchen/kitchen_L3_x3.png | d1621d4495b3b696 |

## Second reference: living room (MV-597)

Parames approved a living room made to the same contract on 2026-10-29. Use it as the starting
point for rooms people rest or hang out in (living quarters, lounge, recreation or common rooms),
the same way the kitchen is the starting point for work rooms.

![living levels](room-style-reference-v2/living-levels-preview.png)
![living merged](room-style-reference-v2/living-merged-preview.png)

| Level | Living room | |
|---|---|---|
| 1 | torn sofa patched with tape, crate coffee table, broken CRT TV on a crate, bare bulb, scrap rug | makeshift |
| 2 | repaired sofa with cushions, wooden coffee table with a table lamp, working CRT TV on a stand, clock, framed photo, small bookshelf | cosier, still worn |
| 3 | clean leather sofa, flat-screen TV on a cabinet with a game console (green LED), wall lamp, plant, full bookshelf | clean, more equipment |
| L3 x2 | L3 living room on the left, game corner on the right: pool table, record player, dartboard, second bookshelf | second purpose |
| L3 x3 | the game corner made bigger: large pool table under a hanging lamp, cue rack, score board, long shelf of books and board games, reading armchair with floor lamp at the far right | bigger and better |

Rules this room added:

- **Screens are animated.** A TV or monitor that is on shows a moving picture: a few colour
  "channels" with a moving shape or scrolling lines, scanlines, a short burst of static on each
  channel change (about every 3 s), and a cold blue glow on the room. In the living room the
  flat-screen TV (L3, x2, x3) is on in the empty and working states and **goes dark when the power
  is out**. `anim_lv.py`: `screen_mask()` finds the screen (dark pixels connected to a seed point,
  eroded 2 px so the bezel stays) and `tv_frame()` draws the picture.
- The working state shows two crew walking the front strip; the power-out state shows one crew
  idle in the dark.

How it was made (all scripts in `room-style-reference-v2/tools/`):

1. **L1:** `generate-image-v2` 144x96, seed 7, `style_image` = the approved **kitchen L1**
   (144x96) with `style_options.color_palette` true (`gen_living.py`, option A). Using an approved
   room as the style image keeps the camera, floor and palette closer than the medic frame did.
2. **L2 / L3:** `edit-images-v2` on L1 (`edit_lv.py`), seed 1, so the sofa, table and TV stay put.
3. **L3 x2:** L3 + mirror on 288x96, `edit-images-v2`, seed 2 (`merge_lv.py m2`). Seed 1 left a
   pillar in the middle and was rejected.
4. **L3 x3:** `inpaint-v3` on 432x96 from the x2 room, mask x 186-431, seed 1 (`merge_lv.py m3`).
5. PixelLab outputs end with a white bottom row (y=95); the scripts copy row 94 over it.

Cost: 30 generations for the 12 L1 candidates (3 calls), about 109 for L2, L3, x2 and x3.
Anchors for every image are in `anim_lv.py` (`ROOMS`).

| File | SHA-256 (first 16) |
|---|---|
| living/living_L1.png | 7a346a4b44722f05 |
| living/living_L2.png | b774d5561d163aeb |
| living/living_L3.png | f95da710fce68dde |
| living/living_L3_x2.png | 99828d8caccd5a0a |
| living/living_L3_x3.png | 136834e9e8300ec8 |
