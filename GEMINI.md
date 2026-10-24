# Apocarlypse: Mobile Vault — rules for Gemini CLI

You are Gemini (model `gemini-4-argon`), working on this repo next to two Claudes (the claude.ai
project and Claude Code CLI on Parames's PC). Everyone follows the same rules, and they live in
one place: `CLAUDE.md`, imported below. Where it says "Claude" or "Claude Code CLI", read it as
"any agent" and "you" unless a line says it is Claude-only. Do not copy rules into this file:
change `CLAUDE.md` so every agent sees the change.

@./CLAUDE.md

## Gemini-only notes

- **Your name in the shared records is `Gemini CLI`.** Run Plane commands with
  `python tools/plane.py --by "Gemini CLI" ...` (or set `MV_AGENT=Gemini CLI` in `.gemini/.env`),
  end commit messages with the trailer `Agent: Gemini CLI (gemini-4-argon)`, and put
  `Agent: Gemini CLI` in every PR body.
- **Take work only through Plane.** `python tools/plane.py list --state "In Progress"` first;
  start a ticket with `plane.py --by "Gemini CLI" claim MV-<n>` (it refuses a ticket someone
  already has In Progress) or `plane.py --by "Gemini CLI" create "Title" --label ...`.
- **Your tools:** run commands with `run_shell_command`; read files with `read_file` before
  editing. Commands in the "Opening the PR (Claude Code CLI)" section apply to you unchanged
  (`gh pr create`, never `gh pr merge`, never push `main`).
- **Skills:** the project's agent skills are in `.claude/skills/<name>/SKILL.md` (list and
  overrides in `.claude/skills/README.md`). Read the matching `SKILL.md` before working on that
  area, e.g. `godot-gdscript`, `godot-ui-control`, `save-systems`.
- **Godot API facts:** docs.godotengine.org/en/stable is the source of truth. If you cannot open
  it, read the class reference XML for the `4.7.2-stable` tag
  (`https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/<Class>.xml`).
  Never answer an API question from memory.
- **Ask Parames** (stop and wait) before downloading or installing anything, before any paid
  PixelLab batch, and before any step that cannot be undone. A `deny` from the policy file is a
  rule, not an obstacle: do not look for another command that does the same thing.
