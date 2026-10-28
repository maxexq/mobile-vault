# Project agent skills

Agent skills (Claude Code `.claude/skills/` format) selected from
[gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)
at commit `38a4c2500eeb5ff9ac084336b8f66108069d2f8d` (2026-10-22). Licensed Apache-2.0;
see `_upstream/LICENSE` and `_upstream/NOTICE`. Files are copied unchanged except that
`agents/openai.yaml` (Codex-only metadata) was dropped.

Upstream targets **Godot 4.7** and was last checked against **4.7.2**, matching this project.
They were copied by hand; the upstream `npx skills add` installer was not used.

## Included

| Skill | Why it is here |
|-------|----------------|
| `godot-gdscript` | Typed GDScript 2.0, lifecycle, signals, `await` |
| `godot-gdscript-headless-testing` | `godot --headless --script` runners with real exit codes (matches `tools/autotest.gd`) |
| `godot-export` | Web preset, headless CLI export |
| `godot-nodes-scenes` | Scene tree, instancing, autoloads |
| `godot-signals-groups` | Decoupled signal architecture |
| `godot-resources` | Custom `Resource` data (items, rooms, recipes) |
| `godot-ui-control` | Control layout, anchors, theming for portrait mobile |
| `godot-animation` | AnimationPlayer, Tween |
| `godot-audio` | Audio buses, players, SFX/music mixing |
| `godot-tilemap` | TileMapLayer / TileSet for pixel-art rooms |
| `godot-shaders` | CanvasItem shaders for dark post-apocalyptic effects |
| `save-systems` | Versioned saves and migration (matches `tools/migrate_test.gd`) |
| `game-ui-ux` | HUD, menus, readability and flow |
| `game-feel` | Juice and feedback for taps and rewards |
| `performance-optimization` | Profiling and budgets for mobile browsers |
| `create-game-assets` | Art direction, pixel-art pipeline, asset manifest and provenance |
| `survival-crafting` | Needs, resources, crafting loops |

## Project-owned skills

| Skill | Why it is here |
|-------|----------------|
| `pixellab-art` | Written for this repo (MV-583), not upstream: the default for every visual task (UX/UI look, sprites, rooms, icons, backgrounds, art review). House style, PixelLab dry-run -> OK -> gen -> accept loop, review checklist. Wins over `create-game-assets` / `game-ui-ux` where they differ. |

Left out: 3D, C#, multiplayer, physics/movement, other engines, Steam/itch publishing,
genres that do not fit, and the upstream `router` (its paths assume the full catalog).

## Project rules that override the skills

- **Godot 4.7.2-stable only.** Never use beta/rc/dev builds or templates. Confirm APIs on
  docs.godotengine.org/en/stable before using them.
- **Web export is single-threaded** (`variant/thread_support=false` in `export_presets.cfg`)
  and hosted on Vercel (`vercel.json`). The COOP/COEP header advice in `godot-export` only
  applies to threaded builds, so do not switch to threads without a decision.
- **Ask before downloading or installing software.** That includes Godot addons, the
  `skills` npm CLI, and `pip install -r create-game-assets/scripts/requirements.txt` (Pillow).
- The bundled Python helpers (`godot-nodes-scenes/scripts/check_godot_project.py`,
  `create-game-assets/scripts/*.py`) are read-only checkers with no network access. Running
  them is optional, and only the asset scripts need Pillow.
- Art is true 16-bit pixel art, dark post-apocalyptic, with 3 rooms per vehicle floor. In
  `create-game-assets`, treat generated images as drafts and enforce the grid and palette.
- Every feature must pass the autotests, export for web, update the artifact, and push to GitHub.
