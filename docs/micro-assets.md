# Micro-asset tickets (Codex plans, Claude builds)

A **micro asset** is one small art piece: a prop, decal, overlay, effect, icon or a short
animation strip (up to 32 frames, up to 400x400 px, usually far smaller). Big art jobs
("make the medical room feel like a clinic") are broken into many micro assets so each one
can be drawn, checked and merged on its own.

Who does what:

| Step | Who | Tool |
|---|---|---|
| Read code, atlas and art style; pick what to add | Codex CLI (art analyst, `AGENTS.md`) | `micro_asset.py ref`, `sheet` |
| Write one spec per asset, validate it | Codex | `micro_asset.py new`, `check` |
| Post it as a Plane ticket (Todo, labels `micro-asset` + `art`) | Codex, after Parames approves the network call | `micro_asset.py post` |
| Build it, wire it in game, test, PR | Claude (cloud thread or Claude Code CLI) | `micro_asset.py queue`, `pull`, `verify` |

## The spec (format `micro-asset/1`)

A JSON file. `python tools/micro_asset.py new <id> --parent <sprite>` writes a blank one to
`tools/art/micro/drafts/<id>.json` (git-ignored). Full example:
[`docs/micro-assets/example_prop_med_iv_drip.json`](micro-assets/example_prop_med_iv_drip.json).

| Field | Meaning | Rules (checked by `check`) |
|---|---|---|
| `spec` | format version | `"micro-asset/1"` |
| `id` | atlas sprite name; frames become `<id>_0..n-1` | snake_case, 3-48 chars, unused in `assets/atlas/atlas.json` unless `replace` |
| `title`, `why` | one line each: what it is, what it adds for the player | required |
| `parent` | what it sits on: an atlas sprite (`room_medical`, `veh_...`) or `screen` / `ui` (360x640) / `world` (560x320) | must exist |
| `kind` | `prop` `decal` `overlay` `fx` `anim` `icon` `ui` `portrait` `bg` | enum |
| `size` | `[w, h]` in native art pixels (no scaling in game, 1 art px = 1 design px) | 1-400 |
| `frames` | `{"count": 1}` or `{"count": 3, "fps": 3, "loop": true}` | 1-32, fps 0-24 |
| `palette` | master palette names (`ol0`, `orange2`, `lamp1` ...) from `micro_asset.py ref` | every name must exist; aim 4-8 colours; saturated colour only for light sources |
| `outline` | outline colour name or `null` | must also be in `palette` |
| `light` | `none` `top-left` `top` `top-right` `lamp` (room bulb) `emissive` | enum |
| `layer` | `behind_parent` `on_parent` `above_dwellers` `fx` `ui` | enum |
| `anchor` | `{"x", "y", "pivot"}` in the parent's pixels; pivot `bottom-center` for things standing on a floor | inside the parent; warns if the box sticks out |
| `generator` | `{"method": "drawn", "module": "tools/art/rooms.py", "function": "prop_iv_drip"}`; `pixellab` costs credits, `hand` = Parames draws it | module must exist |
| `feature` | `Features` key that gates it, or `null` for art-only changes | |
| `replace` | `true` when redrawing an existing sprite | size must stay the same |
| `refs` | repo paths or URLs that show the look | warns if missing |
| `acceptance` | 2+ checkable bullets: pixel sizes, palette, motion, what must stay visible | required |
| `notes`, `priority`, `author` | optional | |

Group a set of assets under an epic ticket: create the epic with
`python tools/plane.py create "Art: medical room details" --label art --state Todo`, then
`micro_asset.py post <spec> --epic MV-<n>`.

## Analyst loop (Codex)

```
python tools/micro_asset.py ref --prefix room_          # palette + sprite sizes
python tools/micro_asset.py sheet room_medical          # tools/art/micro/sheets/room_medical_x8.png
python tools/micro_asset.py new prop_med_iv_drip --parent room_medical
python tools/micro_asset.py check tools/art/micro/drafts/*.json
python tools/micro_asset.py post tools/art/micro/drafts/prop_med_iv_drip.json --dry-run
python tools/micro_asset.py post tools/art/micro/drafts/prop_med_iv_drip.json
```

The sheet is the sprite at x8 with a 1 px grid and a bright line every 8 px, so pixel
coordinates for `anchor` can be read off it. Attach it when starting Codex:
`codex --image tools/art/micro/sheets/room_medical_x8.png`.

## Builder loop (Claude)

```
python tools/micro_asset.py queue                       # Todo micro-asset tickets
python tools/plane.py move MV-<n> "In Progress"         # claim it
python tools/micro_asset.py pull MV-<n>                 # spec -> tools/art/micro/drafts/<id>.json
# draw it in generator.module with only the spec palette names, add("<id>", img) / add("<id>_<i>", img)
python tools/generate_pixel_art.py
python tools/micro_asset.py verify MV-<n>               # atlas size, frame count, colours within palette
# place it in game at anchor/layer, Features gate if feature is set, autotest, web export, PR
```

Several micro assets of one epic can go in one PR; link every ticket to it. If a spec
cannot be built as written (wrong anchor, not readable at 1x), comment on the ticket and move
it to **Needs Decision** instead of guessing.

## Setting up Codex CLI (Parames's PC)

Checked on the official Codex docs (learn.chatgpt.com/codex, 2026-10-24). Ask before installing:
this is new software on the PC (CLAUDE.md hard rule).

- Install (Windows, new PowerShell window), either one:
  `powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"` or
  `npm install -g @openai/codex`.
- First run: pick **Sign in with ChatGPT**. That uses the plan's included usage. Signing in with
  an API key bills standard API rates instead, so don't.
- Models with ChatGPT sign-in: Plus/Pro/Business get **GPT-6.1 Sol** (`gpt-6.1-sol`, the
  recommended one) and GPT-6 Luna. Free/Go only list GPT-6 Luna (desktop app, rolling out), and
  the docs don't confirm CLI access for Free/Go. Plus allows about 15-160 local GPT-6.1 Sol
  messages per 5 hours (weekly limits may apply); Pro has no 5-hour limit.
- Start it in the repo folder: `cd C:\Users\param\Downloads\mobile-vault` then `codex`.
  Codex reads `AGENTS.md` at the repo root by itself (32 KiB limit, this file is far below).
  The default sandbox (`workspace-write`, native Windows sandbox in PowerShell) with approvals
  `on-request` is right: Codex can write drafts in the repo and asks before going further,
  for example the network call in `micro_asset.py post`. Don't use `danger-full-access`.
- Plane key: the same git-ignored `.plane-api-key` Claude Code CLI already uses.
- Attach a sprite sheet or screenshot: `codex --image tools/art/micro/sheets/room_medical_x8.png`,
  or paste an image into the prompt.

Example first prompt: "Break the medical room into micro assets that make it read as a clinic
at 1x: at most 6 assets, look at room_medical and tools/art/rooms.py, write the specs, check
them and show me the list before posting."
