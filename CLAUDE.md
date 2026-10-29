# Apocarlypse: Mobile Vault — rules for Claude

Idle survival game on an armoured vehicle after the apocalypse, for mobile web.
Two Claudes work on this repo: the claude.ai project (cloud threads) and Claude Code CLI on
Parames's PC. Both follow this file. Codex CLI (`AGENTS.md`) is the art analyst: it only writes
micro-asset specs as Plane tickets, which Claude builds (see "Micro-asset tickets" below). The game itself is described in `README.md` and
`docs/PROJECT_CONTEXT.md`; read the relevant README section before touching a system.

## Hard rules

- **Godot 4.7.2-stable only.** Never beta/rc/dev editors, templates or addons. Addons must
  support 4.7.2. Confirm every engine API on https://docs.godotengine.org/en/stable/ before
  using it; do not guess signatures.
- **Ask Parames before downloading or installing any software** (addons, npm/pip packages,
  tools, MCP servers). Standing exception: the official Godot 4.7.2-stable editor and export
  templates from the godotengine GitHub release `4.7.2-stable` (check SHA-512).
- **Art:** true 16-bit pixel art, dark post-apocalyptic, 3 rooms per vehicle floor, Nearest
  filter, everything in `assets/atlas/`. AI images are drafts: enforce grid and palette.
  (A 32-bit upgrade is proposed but not approved; keep 16-bit until told otherwise.)
- **Future rooms:** follow the approved [room style reference](docs/art/room-style-reference.md).
  Use an actual existing room sprite as the visual input, keep its coarse 64x52 pixel style,
  and include a distinctive small micro-animation for each new furnished room.
- **Room style v2 (approved 2026-10-29, MV-595):** the mess kitchen in
  [room style reference v2](docs/art/room-style-reference-v2.md) is the standard for every future room
  drawn at the new crew scale: 144x96 per slot, deep-floor camera, 3 visibly different levels (L3 cleaner
  with more equipment), merging only at L3, an open walkway in front, and idle / working / power-out
  animation states. The game still runs 64x52 rooms until the move to the new scale is decided.
- **Crew characters:** the chibi field medic in the [crew style reference](docs/art/crew-style-reference.md)
  is the approved model for every new crew character's art style and animation (2D side view).
  It is ~2x the current 14x20 `dw_*` scale; moving the game to it is a separate decision.
- **PixelLab API costs money:** `tools/pixellab.py gen ... --yes` spends Parames's credits. Show the
  `--dry-run` cost estimate and get an OK before every paid batch (README "Redrawing sprites with PixelLab").
- **Web export is single-threaded** (Compatibility renderer, no COOP/COEP), served by Vercel
  from `web/`, and by Cloudflare Pages in parallel while it is being verified (MV-499,
  `docs/hosting-cloudflare.md`: the engine wasm comes from R2; a Godot upgrade needs a new R2 upload).
- Never commit secrets: `cloud_config.json`, `.plane-api-key`, `ai/.env` are git-ignored.
- PR, review, CI and Vercel deploy events post to Discord (`.github/workflows/discord-notify.yml`,
  secret `DISCORD_WEBHOOK_URL`). A new CI workflow must be added to its `workflow_run.workflows` list.
  Player error spikes go to a separate alerts channel (`.github/workflows/error-spike.yml`, secret
  `DISCORD_ALERTS_WEBHOOK_URL`, falls back to the dev feed). Never put `SUPABASE_SERVICE_KEY` in game code.

## Definition of done for every feature

1. Gated by a Features switch: key in `Features.FEATURES` + `config/features.json`, entry point
   guarded with `Features.on(key)`, tunable numbers in `Features.TUNE` (README "Feature switches, event windows & remote config").
2. GOD MODE: a `Dev.*` action in `scripts/autoload/dev.gd`, a button in the matching tab of
   `scripts/ui/god_panel.gd`, and the README "Tester tools: GOD MODE" table updated.
3. Autotest check in `tools/autotest.gd`, and the whole autotest passes:
   `godot --path . --rendering-driver opengl3 -- --autotest --out=<abs dir>`
   (on Linux CI/cloud run it under `xvfb-run -a`; `--headless` hangs on frame_post_draw).
   `--only=<name>` runs one group, e.g. `--only=touch`, `--only=large`.
   CI (workflow **Autotest**) runs it on every PR and must be green before merge; on Linux
   `bash tools/ci_autotest.sh` does exactly what CI does.
   CI skips the Godot run when no game file changed (`tools/ci_scope.sh`: docs, `api/`, `web/`,
   Python tooling...) or when the exact same tree already passed, e.g. the push after a merge
   (MV-173, MV-549); anything else gets the full run. While working, `--only=<name>` is enough.
4. Web export: `sh tools/stamp_build.sh` then
   `godot --headless --path . --export-release "Web" web/index.html`, commit `web/`.
   `cloud_config.json` must exist first or the build ships with cloud save OFF
   (copy `cloud_config.example.json`, or recover it from the committed `web/index.pck`). It holds a
   `prod` and a `test` project (MV-112); an old flat file only works on the production host.
5. Branch + PR into `staging` (see Git workflow), README updated, Plane ticket moved (below).
6. The claude.ai playable artifact is updated by the project side after the PR; CLI sessions
   just say in the PR/ticket that the artifact still needs updating.

## Git workflow

Environments (MV-112, `docs/environments.md`): `staging` = internal test, `uat` = open test,
`main` = production (only what players have). Each branch deploys its own Vercel URL; one build
serves all of them and picks its environment from the host name (`config/environments.json`).

- **Feature work branches from and PRs into `staging`** (the default branch since MV-421).
- `git pull origin staging` before starting. Never push to `staging`, `uat` or `main` directly: a
  GitHub ruleset (MV-421) blocks it anyway. All three need a PR, a green **autotest** check and a
  branch that is up to date with its base; no force push or deletion; `main` and `uat` accept merge
  commits only. Merged branches are deleted automatically.
- **Alpha / beta testers play on `uat`** (its Vercel URL, test Supabase). `main` is production.
- Promotion is a PR `staging` → `uat`, then `uat` → `main`, merged with a merge commit (not
  squash). Only when Parames asks; Parames merges them.
- Hotfix: branch from `main`, PR into `main`, then PRs `main` → `uat` → `staging` so the fix
  flows back down.
- Branch name starts with the ticket: `mv-<n>-short-name` (e.g. `mv-91-local-squad`).
- PR title/body mention `MV-<n>`; one feature per PR. The version is semver in
  `BuildInfo.GAME_VERSION` (`4.7.0-alpha.1`; `-alpha.N`/`-beta.N`/`-rc.N` = test channel). Change it
  only with `python tools/release.py bump <alpha|beta|rc|stable|patch|minor|major>`, which also
  updates the web shell and `CHANGELOG.md`; add a line under `[Unreleased]` in `CHANGELOG.md` for
  player-visible changes. Releases: Actions → Release → Run workflow on main (README "Versioning & releases").
  Version bumps belong in promotion PRs, never in feature PRs: `alpha` / `beta` in the PR
  `staging` → `uat` (what testers get), `rc` / `stable` in the PR `uat` → `main`.

### Opening the PR (Claude Code CLI)

Open the PR yourself with the GitHub CLI (`gh`, logged in once with `gh auth login`).
When the work is committed and the autotest passed:

```
git fetch origin staging && git rebase origin/staging   # branch you created; resolve conflicts
git push -u origin mv-<n>-short-name
gh pr create --base staging --title "MV-<n>: <what changed>" --assignee @me --body-file <tmp file>
python tools/plane.py link MV-<n> <PR url> "PR #<number>"
python tools/plane.py move MV-<n> "In Review"
```

- PR body sections: **What** (bullet list of changes), **Testing** (autotest result, web
  export done or why not, what you checked in the browser), `Plane: MV-<n>`, and a line
  `Artifact: needs update` when the game changed. Write the body to a temp file outside the
  repo (Thai text and backticks break inline `--body` quoting on Windows).
- Use `gh pr view --web` to show Parames the PR. Never merge it yourself: Parames merges.
- After a merge into `staging`: `python tools/plane.py move MV-<n> "Awaiting Verify"` (check it on
  the staging URL), then `git checkout staging && git pull`. **Done** once it reached `main`
  (or right away when Parames says so).
- If `gh` is missing or not logged in, push the branch and give Parames the link
  `https://github.com/maxexq/mobile-vault/compare/staging...<branch>?expand=1`. Do not install
  `gh` yourself (ask first, see Hard rules).

## Plane tickets (workspace `mobile-vault`, project `MV`)

Every task has a ticket that matches reality, from start to done. Use `tools/plane.py`
(stdlib Python, works on Windows):

```
python tools/plane.py list --state "In Progress"     # check nobody else is on it
python tools/plane.py create "Title" --label feature --desc "..."   # starts In Progress
python tools/plane.py move MV-12 "In Review"
python tools/plane.py link MV-12 https://github.com/maxexq/mobile-vault/pull/40 "PR #40"
python tools/plane.py comment MV-12 "waiting for Parames to pick option B"
```

- Start: create the ticket or move an existing one to **In Progress** before writing code.
  If a ticket is already In Progress, someone else (cloud or CLI) owns it: don't take it.
- Waiting on a decision: **Needs Decision**. PR open: **In Review** + PR link.
  Merged but needs a real-device/web check: **Awaiting Verify**. Delivered: **Done** + links.
- States: Backlog, Needs Decision, Todo, In Progress, In Review, Awaiting Verify, Done, Cancelled.
  Labels: feature, bug, design, art, infra, balance, ui, marketing, tooling, micro-asset, v4.3–v4.7.
- API key: env `PLANE_API_KEY` or one line in `.plane-api-key` at the repo root (git-ignored).
  In claude.ai cloud sessions the proxy adds the key, so none is needed there.

## Micro-asset tickets (from Codex)

Tickets titled `[micro] <id>: ...` with label `micro-asset` carry a JSON spec (size, frames,
palette names, parent, layer, anchor, generator, acceptance). Format and loop: `docs/micro-assets.md`.

```
python tools/micro_asset.py queue            # Todo micro-asset tickets
python tools/micro_asset.py pull MV-<n>      # spec -> tools/art/micro/drafts/<id>.json
python tools/micro_asset.py verify MV-<n>    # after generate_pixel_art.py: size, frames, palette
```

- Build exactly the spec: only its palette names, its size, its anchor. If it cannot work as
  written, comment on the ticket and move it to **Needs Decision**; don't silently change it.
- The normal definition of done still applies when the asset is placed in game (Features gate if
  `feature` is set, autotest, web export, PR). `"method": "pixellab"` needs Parames's OK first.

## Gotchas that already cost bugs

- The save (`Game.s`) is JSON, so int ids come back as floats. `Array.find/has` with an int
  never matches on 4.7.2: compare `int(x) == id` in a loop.
- `Game.resources_changed` fires every frame: never rebuild buttons on it (taps die); update
  labels in place.
- Choice buttons with wrapping Thai text: `ChoiceButton`; popups with art:
  `ModalPanel.media_layout`. `include_text_server_data=true` must stay on (Thai wrap on web).
- Touch: finger releases are booked in `Main._input`; controls inside `ScrollContainer` are
  switched STOP→PASS by `UIKit.touch_pass`. Extend `_touch_test` for new gestures/lists.
- `Time.get_unix_time_from_datetime_string` ignores timezone suffixes on 4.7.2.
- New progress data goes in `Game.s` (cloud-synced); no new localStorage keys for progress.
  Test runners never touch the real Supabase (autotest uses `tools/cloud_fake.gd`).
- Game name lives in `BuildInfo.GAME_NAME`; repo, save keys and domain keep `mobile-vault`.

## Skills

Project agent skills are in `.claude/skills/`; `.claude/skills/README.md` lists them and the
project rules that override them.
Any visual work (UX/UI look, sprites, rooms, icons, backgrounds, art review, PixelLab) starts
with the `pixellab-art` skill.
