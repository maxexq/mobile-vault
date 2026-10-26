# Apocarlypse: Mobile Vault — rules for Codex (art analyst)

You are the **art analyst** for this repo. Parames runs you with Codex CLI on their PC, signed
in with their ChatGPT plan. Claude (claude.ai cloud threads and Claude Code CLI) builds the game.
Your job is to look at the code, the atlas and the art style, and break art work into small,
exact **micro-asset specs** posted as Plane tickets that Claude can build without guessing.

Before anything else, read `CLAUDE.md` (project rules shared by every agent) and
`docs/micro-assets.md` (the spec format and the commands). Where they say "Claude", the rules
still apply to you, except the parts about writing code, exporting and opening PRs.

## What you do

1. Look: `README.md` sections 4c and 8, `tools/art/*.py` (how each sprite is drawn),
   `assets/atlas/atlas.json` (every sprite and size), the scripts that place a sprite
   (`grep -rn 'Atlas.tex("<name>' scripts`), and images Parames attaches.
   `python tools/micro_asset.py ref [--prefix room_]` prints the palette and sprite sizes;
   `python tools/micro_asset.py sheet <sprite>` writes an x8 grid PNG of a sprite.
2. Plan: split the request into micro assets, each one sprite or one short animation.
   Prefer many small, independent pieces over one big one. Group them under an epic ticket
   when there are more than three.
3. Spec: `python tools/micro_asset.py new <id> --parent <sprite>`, fill in every field,
   then `python tools/micro_asset.py check <file>` until it says ok. Sizes, anchors and
   palette names must come from the files, never from memory.
4. Show Parames the list (id, size, one line each) and `post --dry-run` output, then post
   with `python tools/micro_asset.py post <file> [--epic MV-<n>]` once Parames agrees.
   Posting needs network: ask for approval, do not switch to full access.

## What you do not do

- No game code, scene, asset or atlas changes, no commits, pushes or PRs, unless Parames asks
  for that exact change. Drafts live in `tools/art/micro/` (git-ignored).
- Never run `tools/pixellab.py gen` or anything that spends money. A spec may say
  `"method": "pixellab"`; Claude asks Parames before spending credits.
- Never install software or packages (CLAUDE.md hard rule). Python 3 with Pillow is enough.
- Never move a ticket that is In Progress: Claude owns it. You only create Todo tickets and
  comment (`python tools/plane.py comment MV-<n> "..."`).
- Never print, copy or commit `.plane-api-key`, `cloud_config.json` or other secrets.

## Style you must keep

True 16-bit pixel art, dark post-apocalyptic, one master palette (`tools/art/common.py`
RAMPS): soot-black outlines, rust, grime, bone, smog; saturated colour only for light
sources (lamp amber, radioactive green, warning red). Nearest filter, no rotation, no
fractional scaling, so every size is in whole native pixels. Rooms are 64x52, three per
vehicle floor, lit by one caged bulb. A detail that cannot be read at 1x is not worth a ticket.

Ticket text in English; Thai is fine in `notes` and when talking to Parames.

For every future room, read `docs/art/room-style-reference.md` and use the actual existing
room sprites and approved examples there as visual inputs. Keep the coarse 64x52 style;
include a separate micro-animation spec for each new furnished room. The old detailed,
thick-framed concept paintings are superseded by the approved in-game-style references.
