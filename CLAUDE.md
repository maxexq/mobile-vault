# Apocarlypse: Mobile Vault — rules for every AI agent

Idle survival game on an armoured vehicle after the apocalypse, for mobile web.
Three agents work on this repo: the claude.ai project (cloud threads), Claude Code CLI on
Parames's PC, and Gemini 4 Argon via Antigravity CLI (`agy`) on Parames's PC, which loads this file through
`GEMINI.md`. All of them follow this file, so a new standing rule goes here (not in `GEMINI.md`).
The game itself is described in `README.md` and `docs/PROJECT_CONTEXT.md`; read the relevant
README section before touching a system. Setup for each agent: `docs/AI_AGENTS.md`.

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
- **PixelLab API costs money:** `tools/pixellab.py gen ... --yes` spends Parames's credits. Show the
  `--dry-run` cost estimate and get an OK before every paid batch (README "Redrawing sprites with PixelLab").
- **Web export is single-threaded** (Compatibility renderer, no COOP/COEP), served by Vercel
  from `web/`.
- Never commit secrets: `cloud_config.json`, `.plane-api-key`, `ai/.env` are git-ignored.
- PR, review, CI and Vercel deploy events post to Discord (`.github/workflows/discord-notify.yml`,
  secret `DISCORD_WEBHOOK_URL`). A new CI workflow must be added to its `workflow_run.workflows` list.

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
4. Web export: `sh tools/stamp_build.sh` then
   `godot --headless --path . --export-release "Web" web/index.html`, commit `web/`.
   `cloud_config.json` must exist first or the build ships with cloud save OFF
   (copy `cloud_config.example.json`, or recover it from the committed `web/index.pck`).
5. Branch + PR into `main`, README updated, Plane ticket moved (below).
6. The claude.ai playable artifact is updated by the project side after the PR; CLI sessions (Claude or Gemini)
   just say in the PR/ticket that the artifact still needs updating.

## Working alongside the other agents

- Plane is the lock. One agent per ticket: start with `plane.py --by "<you>" claim MV-<n>` (or
  `create`), which refuses a ticket that is already In Progress. Names: `Claude (claude.ai)`,
  `Claude Code CLI`, `Gemini`. If two tickets need the same files, say so in a Plane comment
  and let the second one wait or rebase after the first PR merges.
- Never commit to, rebase or push another agent's branch; leave a PR review comment or a Plane
  comment instead. Reviewing each other's PRs is welcome (comments only; Parames merges).
- Every PR body has a line `Agent: <you>` so Parames and Discord show who made it.

## Git workflow

- `git pull origin main` before starting. Never push to `main` directly.
- Branch name starts with the ticket: `mv-<n>-short-name` (e.g. `mv-91-local-squad`).
- PR title/body mention `MV-<n>`; one feature per PR. The version is semver in
  `BuildInfo.GAME_VERSION` (`4.7.0-alpha.1`; `-alpha.N`/`-beta.N`/`-rc.N` = test channel). Change it
  only with `python tools/release.py bump <alpha|beta|rc|stable|patch|minor|major>`, which also
  updates the web shell and `CHANGELOG.md`; add a line under `[Unreleased]` in `CHANGELOG.md` for
  player-visible changes. Releases: Actions → Release → Run workflow on main (README "Versioning & releases").

### Opening the PR (Claude Code CLI and Gemini)

Open the PR yourself with the GitHub CLI (`gh`, logged in once with `gh auth login`).
When the work is committed and the autotest passed:

```
git fetch origin main && git rebase origin/main      # branch you created; resolve conflicts
git push -u origin mv-<n>-short-name
gh pr create --base main --title "MV-<n>: <what changed>" --assignee @me --body-file <tmp file>
python tools/plane.py link MV-<n> <PR url> "PR #<number>"
python tools/plane.py move MV-<n> "In Review"
```

- PR body sections: **What** (bullet list of changes), **Testing** (autotest result, web
  export done or why not, what you checked in the browser), `Plane: MV-<n>`, `Agent: <you>`, and a line
  `Artifact: needs update` when the game changed. Write the body to a temp file outside the
  repo (Thai text and backticks break inline `--body` quoting on Windows).
- Use `gh pr view --web` to show Parames the PR. Never merge it yourself: Parames merges.
- After a merge: `python tools/plane.py move MV-<n> Done` (or "Awaiting Verify" when it still
  needs a real phone/web check), then `git checkout main && git pull`.
- If `gh` is missing or not logged in, push the branch and give Parames the link
  `https://github.com/maxexq/mobile-vault/compare/main...<branch>?expand=1`. Do not install
  `gh` yourself (ask first, see Hard rules).

## Plane tickets (workspace `mobile-vault`, project `MV`)

Every task has a ticket that matches reality, from start to done. Use `tools/plane.py`
(stdlib Python, works on Windows):

```
python tools/plane.py list --state "In Progress"     # check nobody else is on it
python tools/plane.py --by "Claude Code CLI" claim MV-12      # take an existing ticket
python tools/plane.py --by "Claude Code CLI" create "Title" --label feature --desc "..."   # starts In Progress
python tools/plane.py move MV-12 "In Review"
python tools/plane.py link MV-12 https://github.com/maxexq/mobile-vault/pull/40 "PR #40"
python tools/plane.py comment MV-12 "waiting for Parames to pick option B"
```

- Start: create the ticket or move an existing one to **In Progress** before writing code.
  If a ticket is already In Progress, someone else (cloud or CLI) owns it: don't take it.
- Waiting on a decision: **Needs Decision**. PR open: **In Review** + PR link.
  Merged but needs a real-device/web check: **Awaiting Verify**. Delivered: **Done** + links.
- States: Backlog, Needs Decision, Todo, In Progress, In Review, Awaiting Verify, Done, Cancelled.
  Labels: feature, bug, design, art, infra, balance, ui, marketing, tooling, v4.3–v4.7.
- API key: env `PLANE_API_KEY` or one line in `.plane-api-key` at the repo root (git-ignored).
  In claude.ai cloud sessions the proxy adds the key, so none is needed there.

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
