# Apocarlypse: Mobile Vault — rules for Gemini

You are Gemini (Gemini 4 Argon), working on this repo next to two Claudes (the claude.ai project
and Claude Code CLI on Parames's PC), usually through Antigravity CLI (`agy`). Everyone follows
the same rules, and they live in one place: `CLAUDE.md`, included below. Where it says "Claude"
or "Claude Code CLI", read it as "any agent" and "you" unless a line says it is Claude-only.
Do not copy rules into this file: change `CLAUDE.md` so every agent sees the change.

<!-- Antigravity inlines the next line; Gemini CLI inlines the one after it. -->
@[CLAUDE.md](./CLAUDE.md)
@./CLAUDE.md

## Gemini-only notes

- **Your name in the shared records is `Gemini`.** Run Plane commands with
  `python tools/plane.py --by "Gemini" ...`, end commit messages with the trailer
  `Agent: Gemini (gemini-4-argon)`, and put `Agent: Gemini` in every PR body.
- **Take work only through Plane.** `python tools/plane.py list --state "In Progress"` first;
  start a ticket with `plane.py --by "Gemini" claim MV-<n>` (it refuses a ticket someone
  already has In Progress) or `plane.py --by "Gemini" create "Title" --label ...`.
- The "Opening the PR" section applies to you unchanged (`gh pr create`, never `gh pr merge`,
  never push `main`).
- **Skills:** the project's agent skills are in `.claude/skills/<name>/SKILL.md` (list and
  overrides in `.claude/skills/README.md`). Read the matching `SKILL.md` before working on that
  area, e.g. `godot-gdscript`, `godot-ui-control`, `save-systems`.
- **Godot API facts:** docs.godotengine.org/en/stable is the source of truth. If you cannot open
  it, read the class reference XML for the `4.7.2-stable` tag
  (`https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/<Class>.xml`).
  Never answer an API question from memory.
- **Ask Parames** (stop and wait) before downloading or installing anything, before any paid
  PixelLab batch, and before any step that cannot be undone. A denied command is a rule, not an
  obstacle: do not look for another command that does the same thing.
