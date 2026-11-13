---
name: ci-targeted-tests
description: RULE MV-779 PRs into staging run only the autotest groups covering changed files (tools/ci_select.py); whole suite nightly 05:00 Bangkok on staging/uat/main
metadata:
  type: project
  modified: 2026-11-13T17:00:00Z
---

2026-11-13 Parames: "test only the part you worked on, run all test cases at 05:00 every day". MV-779, branch mv-779-targeted-tests.
- PR into staging / push to staging: `tools/ci_select.py` maps changed files -> `--only` groups; `tools/ci_autotest.sh` with `ONLY="g1 g2"` runs one Godot process per group (~15 s boot each). PRs into uat/main, push to main, manual runs (unless groups given) = full.
- Selection: tools/test_map.txt rules, group name in path, groups whose tests mention the file, and for tools/autotest.gd the groups that run each changed function (call graph from the `--only` blocks in `_run`). Unmatched game file -> `core` (`--only=core` = boot + core walk up to the marker in `_run`, ~3 min). Full run when: project.godot, save_system.gd, shared helper (_check/wait/shot), test only the full run reaches (e.g. _cloud_test, _inspection_test, _modes_test, _roof_deck_test), or > 14 groups.
- Nightly: `.github/workflows/nightly-autotest.yml` ("Nightly autotest"), cron `0 22 * * *` UTC, matrix staging/uat/main; in discord-notify workflow_run list; Discord only on failure and names failed branch jobs.
- Markers: `autotest-pass-<tree>` = any green run (staging skip), `autotest-full-<tree>` = full run passed (uat/main PRs skip only on this).
- `.github/actions/setup-godot` = shared Godot setup + `.godot/` import cache (import took ~7 min of every run before).
- Before MV-779: full run ~15.5 min autotest + 7 min import (2026-11-12). `--only=settings` used to fall through into the full run (no return): fixed.
**How to apply:** every new feature adds its own `--only=<feature>` block AND its call in the full list; locally run `python3 tools/ci_select.py --explain` and test those groups. Never use paths-ignore (required check).
Related: [[ci-autotest]], [[discord-notify]], [[autotest-count]]
