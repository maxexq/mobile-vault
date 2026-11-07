---
name: ci-autotest
description: Autotest on GitHub Actions (PR #37, MV-110, also fixes MV-41 flaky); tools/ci_autotest.sh, required check "autotest" set by Parames
metadata:
  type: project
  modified: 2026-10-24T00:49:49.926Z
---

2026-10-24 MERGED: PR maxexq/mobile-vault#37 (branch mv-110-ci-autotest, MV-110 + MV-41 Done) adds `.github/workflows/autotest.yml` (workflow name **Autotest**, job `autotest`) + `tools/ci_autotest.sh`.
- Godot 4.7.2-stable linux zip downloaded from the GitHub release, SHA-512 checked (pin in workflow env), cached; `--import` then xvfb-run opengl3 + `--audio-driver Dummy`. Full run ~4 min, 488 checks (2026-10-24).
- Fails on `[autotest] FAIL`, `SCRIPT ERROR`, no `[autotest] DONE`, or 20-min hang. autotest.gd `_finish()` now quits with exit 1 on fails.
- MV-41 flaky fixes: `Dev.process_priority = 1000` (invincible refill runs after Combat/Game), `Lore.pick_line` falls back to a different line if equal to the previous.
- docs.godotengine.org is blocked by the proxy in cloud; read the engine's own `doc/classes/*.xml` at tag 4.7.2-stable on raw.githubusercontent.com instead (same text as the docs).
- Making `autotest` a required check (ruleset on main) is Parames's job in repo settings.
Related: [[discord-notify]] (workflow_run already lists Autotest), [[claude-cli-handover]]
- 2026-10-24 PR #57 (MV-173, MERGED 2026-10-24): docs-only PRs (all files *.md except CHANGELOG.md, or docs/ / .claude/) skip the Godot steps via a "Docs-only PR?" step (`steps.scope.outputs.godot`); the job still reports success. Never switch to paths-ignore: the required check would stay pending. Local quick runs: `--only=touch|large|ambience|version|thai`.
- 2026-10-24 PR #62 (MV-172, MERGED + Done): flaky fixes. combat check = fixed Lv1 wave via Combat.debug_spawn (random Lv21 raid wiped 17/300 seeds); touch tap waits `_scroll_settled` (ScrollContainer fling length depends on FPS); main.gd reframes on Features.changed (was 20-frame poll -> "view: switch off -> old framing" flaky); --only=touch sets 1280x640 (405x720 = UI scale 1, pinch had no levels). Stress trick: isolated HOME/XDG_DATA_HOME per run lets 3 full runs go in parallel (~4 cores).
- 2026-10-24 PR #63 (MV-40): flaky "deck: reserve heals while resting" fixed by clearing infection/rads and topping food/water before measuring (leftover infection drained more hp than the Lv1 deck heal). Export-only conflicts (web/index.pck, index.html) on every PR after another merges: merge main, take either side, re-stamp + re-export from the merge commit, commit export separately. Shallow clones need `git config --add remote.origin.fetch` for the branch or the stop hook reports unpushed commits.
- 2026-10-24 PR #69 (MV-178) conflict fix in cloud: same export-only pattern after MV-188. Godot+web templates download from GitHub in ~1 min; extract only templates/web* to save disk. Main's pck holds a FLAT cloud_config (url/anon_key/site_url) recoverable via `strings web/index.pck`. Full autotest 713 PASS. Artifact publish to the existing URL is refused once (unviewed live version); resend unchanged after confirming it's the same tool's output.
