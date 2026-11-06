---
name: godot-download-approval
description: Standing approval to download Godot 4.7.2-stable editor + export templates in any thread of this project
metadata:
  type: feedback
---

Parames chose "Allow for all threads" on 2026-10-22: any thread may download Godot_v4.7.2-stable_linux.x86_64.zip and Godot_v4.7.2-stable_export_templates.tpz from the official godotengine GitHub releases (tag 4.7.2-stable) without asking again.

**Why:** every feature must pass autotest + web export, and each thread runs on a fresh cloud container with no Godot.
**How to apply:** download only those official 4.7.2-stable files (verify SHA-512 from the release's SHA512-SUMS.txt). Any OTHER software still needs permission first. Related: [[construction-tutorial-integration]]
