---
name: pixellab-art
description: Mobile Vault's own visual workflow. Use for ANY visual task in this repo - UX/UI look (windows, buttons, panels, HUD, icons, fonts), sprites, rooms, vehicles, crew, creatures, backgrounds, effects, micro animations, art review or style questions - and whenever PixelLab is mentioned. Covers the house style, palette, sizes, the PixelLab dry-run -> OK -> gen -> snap -> accept loop and the review checklist. Overrides the generic create-game-assets / game-ui-ux advice where they differ.
---

# PixelLab art workflow (Mobile Vault)

Every visual change in this repo goes through this skill: the house style first, then the
cheapest way to get the pixels (drawn code, PixelLab redraw, or a micro-asset ticket), then
the same deterministic checks. PixelLab is the AI pixel-art generator; its output is a draft
until it is snapped to the grid and palette and Parames approves it.

## 1. House style (never break these)

- **True 16-bit pixel art, dark post-apocalyptic.** Soot-black one-pixel outlines (`ol0`),
  rust, grime, bone, smog. Saturated colour only on light sources and emissive accents
  (lamp amber, radioactive green, warning red). No smooth gradients, antialiasing, bloom,
  blur, isometric views or high-resolution scratch texture.
- **One master palette:** `tools/art/common.py` `RAMPS` / `PAL`. Print names and sprite sizes
  with `python tools/micro_asset.py ref [--prefix room_]`. Every texture is snapped to it.
- **Native sizes, Nearest filter, integer scale only.** 1 art px = 1 design px (portrait
  360x640, landscape 560x320). No rotation or fractional scaling: pre-draw frames instead.
- **Rooms:** 64x52, three per floor, crew feet on y=46, 4 px ceiling strip, 6 px floor band,
  one ceiling bulb (default centre `(32,7)`). Follow
  [`docs/art/room-style-reference.md`](../../../docs/art/room-style-reference.md) and use an
  existing `room_*` sprite as the actual visual input. Every new furnished room gets its own
  2-4 frame micro animation.
- **Crew:** the chibi field medic in
  [`docs/art/crew-style-reference.md`](../../../docs/art/crew-style-reference.md) is the
  approved model for crew art style and animation: 2D side view, about 20x40 px on a 48x48
  canvas, snapped to the master palette. That doc has the PixelLab design -> character ->
  animation steps. In-game crew stay 14x20 `dw_*` until moving to that scale is decided.
- **UI:** rusted riveted-steel windows with a red title plate, soot-black panels, bone text,
  amber accents, 9-slice frames in `assets/ui`, button faces 24x24 with 6 px caps
  (`UIKit.button_style()`, `tools/art/ui.py:gen_button_skins()`), CRT mood shader. Fonts:
  Chakra Petch (UI text) and Silkscreen (pixel numbers). Thai text must wrap: `ChoiceButton`,
  `ModalPanel.media_layout`.
- **Atlas:** everything lands in `assets/atlas/` through `python tools/generate_pixel_art.py`
  (deterministic). Approved hand/AI art lives as committed source files (`tools/art/v2/`,
  `tools/art/pixellab/overrides/`, `docs/art/room-style-reference/approved/`) so a full
  regeneration never reverts it.
- **32-bit is NOT approved.** Stay 16-bit until Parames says otherwise.

Read the README section of the system you touch first: section 4c (pixel pipeline, UI),
section 8 (replacing art, micro assets, PixelLab).

## 2. Pick the route

| Task | Route |
|---|---|
| Better look for an existing atlas sprite (room, icon, enemy, landmark, vehicle part) | PixelLab redraw, section 3 |
| New sprite that has no atlas entry yet | Draw a placeholder in its `tools/art/*.py` generator at the final size, regenerate, then PixelLab redraw it |
| Many small pieces ("make the clinic feel alive") | Micro-asset specs (`docs/micro-assets.md`); `"method": "pixellab"` only after Parames OKs the cost |
| UI frames / buttons in `assets/ui` (not in the atlas) | Draw in `tools/art/ui.py`; `pixellab.py` cannot target them. Use PixelLab only on a temporary atlas copy if Parames wants AI drafts |
| `dw_*` crew strips (20 frames of 14x20), sprites over 400 px, long backgrounds | Not supported by `pixellab.py`; ask Parames whether to extend it (character/animation endpoints) before trying |
| Layout, spacing, hit areas, readability | No new art: Control/theme code (`godot-ui-control`, `game-ui-ux` skills), then the review checklist |

## 3. PixelLab loop (costs money)

```
python tools/pixellab.py balance                               # credits left
python tools/pixellab.py list room_                            # sizes, * = already overridden
python tools/pixellab.py gen <sprite> --seeds 3 --dry-run      # prompt, payload, cost; nothing sent
# show Parames the dry-run cost, wait for an explicit OK
python tools/pixellab.py gen <sprite> --seeds 3 --budget 0.05 --yes
# open tools/art/pixellab/candidates/<sprite>/preview.png, show it to Parames
python tools/pixellab.py accept <sprite> <seed>                # -> tools/art/pixellab/overrides/
python tools/generate_pixel_art.py                             # rebuild the atlas with it
python tools/pixellab.py reject <sprite>                       # undo: back to the drawn sprite
```

- **Never run `gen ... --yes` without Parames's OK on that batch's dry-run cost** (CLAUDE.md
  hard rule). One OK covers one batch, not the session. Always pass `--budget`.
- Prompts: `tools/art/pixellab/prompts.json` (shared `style` + `negative`, per-prefix
  template, per-sprite text). Add a per-sprite line rather than a long `--prompt`, so the
  next redraw is reproducible. Describe objects and materials, not "16-bit" or "nice".
- Keep the old sprite as the init image (default) so layout and hardcoded coordinates stay.
  `--strength` higher keeps more of the original (default 300); `--no-init` only for a fresh
  idea. For family consistency use `--endpoint bitforge --style <reference sprite>`.
- The candidate is already snapped to size and master palette by `tools/art/pixelize.py`;
  still review it at 1x and nearest 4x. Candidates and `usage.jsonl` (cost log) are
  git-ignored; only accepted overrides are committed.
- **Asset log (MV-584):** when `.asset-log.json` is set up, `gen --yes` also uploads the batch to the private
  web app (`tools/asset-log/README.md`). Point Parames at its Review tab instead of a local preview, then run
  `python tools/asset_log.py pull` to turn approvals into overrides. Never commit `.asset-log.json`.
  Scripts that call PixelLab directly (144x96 rooms, pets, crew animations, vehicles, inpaint) bypass that
  sync: finish every such batch with `python tools/asset_log.py backfill <output folder>` (MV-606).
- Key: env `PIXELLAB_API_KEY` or `.pixellab-api-key` (git-ignored). Never print or commit it.
  If neither exists on this PC, ask Parames to add one; do not paste it into chat.

## 4. Review checklist (before showing Parames, and for "look at the UI/art" requests)

1. **Size and grid:** exact native size, binary alpha, no half pixels, no scaled blur.
2. **Palette:** only master palette colours (`micro_asset.py verify` / `tools/verify_icons.py`
   for icons); saturated colours only on light sources.
3. **Family match:** side by side with its reference sprite at the same integer scale
   (`python tools/micro_asset.py sheet <sprite>` for an x8 grid). Same pixel cluster size,
   outline weight, light direction (top-left, or the room bulb).
4. **Readability on a phone:** icons read at 16 px, the crew aisle stays clear, text never
   sits on noisy art, buttons keep their hit areas and pressed/disabled states.
5. **In game:** run the relevant autotest group (`--only=buttons`, `--only=scene_art`,
   `--only=ambience`, `--only=background`, `--only=fonts`) and look at it in GOD MODE
   (Icons tab, UI TEXT preview, screen presets) before calling it done.
6. **Provenance:** prompt, seed, reference sprite and source file recorded (prompts.json,
   overrides folder, or the relevant `manifest.json`).

When reviewing existing UI/art, report findings as a short list: what, where (file / sprite
name), why it breaks the style or readability, and the fix route from section 2 with a cost
estimate when PixelLab is involved. Do not spend credits during a review.

## 5. Definition of done still applies

Art that changes the game follows CLAUDE.md: Features switch if behaviour or motion changes
(art-only redraws may skip it), GOD MODE preview where useful, autotest green, web export,
README section updated, branch + PR into `staging`, Plane ticket moved. Show Parames the
before/after preview in the PR.
