---
name: json-int-float-ids
description: Save is JSON, so ids come back as floats; Array.find/has with int ids silently fail after load (Godot 4.7.2)
metadata:
  type: project
  modified: 2026-10-22T17:18:21.718Z
---

The save (`Game.s`) round-trips through JSON, so every int id (squad slots, team ids, dweller ids) is a float after load. In Godot 4.7.2 `Array.find()` / `has()` never match int vs float (`JSON.parse_string("[1]").find(1)` == -1, verified 2026-10-22). Always compare with `int(x) == id` in a loop.

**Why:** this caused the bug where defence squad members sent on an expedition stayed in the squad (PR #5, `Game.squad_role`).
**How to apply:** when touching code that looks up ids in arrays from `Game.s`, never use find/has with an int; autotest can simulate with `JSON.parse_string(JSON.stringify(arr))`. Also autotest runs headful via `xvfb-run -a ... --rendering-driver opengl3 -- --autotest --out=DIR` (130 checks as of PR #5). Related: [[godot-download-approval]]
