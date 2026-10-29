# Crew gun animations (MV-594)

Design-time tools that made the approved clips in
`docs/art/crew-style-reference/approved/gun_animations/` (see the crew style reference, "Gun animations").
Run them from a work folder that holds `<character>/` sub-folders; PixelLab auth comes from the
proxy/network secret, never from a key in this repo. Every PixelLab call spends generations: edit = 5, animate = 1.

- `char.py <name> <opt> <preset> <shots> "<gun>" "<action>" [seed]`: start frame -> hold pose (edit) -> v3 shoot clip -> effects.
- `fx.py <clip> <preset> <shots> <out> [aim] [drop]`: removes PixelLab's own flashes, draws muzzle flash + casings
  from the `GUNS` presets in master-palette colours, writes `muzzle.json`. `HOLD=<hold.png>` also strips stray
  PixelLab casings; `SNAP=1` snaps to the master palette (medic only). Shot `4b` = the second gun of a two-gun pose.
- `recoil.py`: code recoil for the up/down aims (PixelLab v3 drifts back to a level aim). `BODY=1` moves the whole
  figure above the ankles instead of cutting at the waist (backpacks, long hair tear otherwise).
- `lockfeet.py`: pins the legs to frame 0 when PixelLab makes the character step.
- `erase.py`: clears a box of PixelLab artefacts in every frame.
- `declutter.py`: drops off-palette pixels (PixelLab speed lines) left of a column.
- `hairfx.py`: draws strand lines, a highlight and underside shade on flat hair in every frame.
- `fx.py` presets also include `airpuff` (net/dart guns), `*_smoke` variants, and `BORE2=1` for a flash on a 2 px barrel.
- `rebuild.sh` re-renders every kept clip, `export.py` copies them into the reference and writes the manifest.
