# Approved reference for all future rooms

Parames approved this direction on 2026-10-26 and asked that it be the reference
for future rooms. Use the actual in-game room sprites as visual inputs before
designing any new room. The approved ten-room expansion is in
[`room-style-reference/approved-room-previews.png`](room-style-reference/approved-room-previews.png).
The paired examples are in
[`room-style-reference/reference-versus-new.png`](room-style-reference/reference-versus-new.png).

## Art contract

- **64x52 native pixels**, one room slot, three slots per floor. Crew feet are on
  **y=46**. Preserve the existing 4-pixel ceiling strip and 6-pixel floor band.
- Match the original room family's large square pixel clusters, one-pixel
  soot-black outlines and simple, readable furniture silhouettes. Review at 1x
  and nearest 4x; use nearest sampling throughout.
- Use `tools/art/common.py` `RAMPS`. Preserve the reference room's material
  ramps; a complete room can need more colours than a small prop. Keep saturated
  accents on lamps, powered indicators or other physical light sources.
- Use the original wall and floor finishes: stained wallpaper and wood, grimy
  tile, worn steel, mossy panels or brick. Do not replace every room with an
  identical heavy steel box. No thick exterior frame, isometric perspective,
  smooth shading, antialiasing, bloom or high-resolution scratch texture.
- Keep one small ceiling bulb and its restrained dithered light. Default lamp
  centre is `(32,7)`; the engine-style reference uses `(24,7)`. Read the actual
  room art and `rooms.py` / `room_ambience.gd` before placing a light.
- Keep the foreground crew aisle readable. People, pets, UI, text and activity
  effects are separate from the static room background.

## Reference workflow

1. Pick the closest existing `room_*` atlas sprite. Record its name and exact crop.
2. Use that sprite as the actual visual edit/reference input; words such as
   "16-bit" by themselves are insufficient.
3. Preserve its pixel scale, wall/floor structure, material finish and lighting.
   Change the furniture needed for the new room's purpose.
4. Save source image, prompt, reference names and hashes beside the draft.
5. Enforce size, master palette and binary alpha deterministically. Show the new
   room beside its existing reference at the same integer scale before approval.
6. Keep approved native source files in a tracked reference/source folder with
   `.gdignore` when appropriate. A generator must reproduce the accepted sprite;
   a full art regeneration must not revert it to a different design.

## Micro-animation contract

Every new furnished room gets at least one distinctive small animation in
addition to the shared lamp/dust ambience. Use two to four deliberate frames,
usually 1-4 fps, with one-pixel steps. The animation must read at native size.

Place it in the room's local coordinates, below the crew, and gate it with the
room's feature switch and `room_ambience`. Give each instance a phase offset.
Use bounded sprite/frame pools; no per-frame node spawning. Pause when the game
is paused, the tab is hidden or the room is not visible. Hold the specified rest
frame when unpowered or inactive. Respect existing reduced-effects settings.

When a moving object is already drawn into the static background, remove only
that object's pixels from the production background and reproduce them in the
animation's rest frame. The combined rest image must match the approved room;
never draw a moving copy over an unchanged baked copy.

## Approved ten-room family

| New room | Existing visual reference |
|---|---|
| Salvagers' Saloon | `room_quarters` |
| Scout Dispatch | `room_radio` |
| Decontamination Bay | `room_water` |
| Companion Den | `room_hydroponics` |
| Jury-Rig Drone Dock | `room_workshop` |
| Battery Reserve | `room_engine` |
| Stormwatch Station | `room_science` |
| Wasteland Barter Counter | `room_kitchen` |
| Scrapyard Training Cage | `room_armory` |
| Relic & Memory Room | `room_radio` |

The detailed palettes, approved native files, original reference crops, prompts
and provenance are recorded in `room-style-reference/manifest.json`.
The earlier detailed, thick-framed v1 concept paintings are superseded.
