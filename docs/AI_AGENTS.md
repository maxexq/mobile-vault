# AI agents on this repo

Three agents work on Mobile Vault with the same rules (`CLAUDE.md`):

| Agent | Where | Reads rules from | Plane name |
|-------|-------|------------------|------------|
| Claude (claude.ai project) | cloud threads | project memory + `CLAUDE.md` | `Claude (claude.ai)` |
| Claude Code CLI | Parames's PC | `CLAUDE.md`, `.claude/settings.json` | `Claude Code CLI` |
| Gemini 4 Argon | Parames's PC, Antigravity CLI `agy` | `GEMINI.md` → includes `CLAUDE.md` | `Gemini` |

They split work through Plane: an In Progress ticket belongs to whoever claimed it
(`python tools/plane.py --by "<name>" claim MV-<n>`), every agent works on its own `mv-<n>-…`
branch, opens a PR with `Agent: <name>` in the body, and only Parames merges.

## Gemini setup: Antigravity CLI (recommended, uses the Google AI Pro plan)

Gemini CLI's "Sign in with Google" no longer works for personal accounts ("This client is no
longer supported for Gemini Code Assist for individuals"); Google moved it to Antigravity.
Docs: https://antigravity.google/docs/getting-started/

1. Install the Antigravity CLI with the Windows installer from the Quickstart page, then check
   `agy --version`.
2. Run `agy` in `C:\Users\param\Downloads\mobile-vault`, sign in with the Google account that has
   AI Pro, and confirm workspace trust. Pick **Gemini 4 Argon** in the model menu
   (Pro gets it in the Antigravity CLI and app; Argon has its own weekly quota).
3. Rules: `agy` reads `GEMINI.md` at the workspace root by itself; it inlines `CLAUDE.md` through
   `@[CLAUDE.md](./CLAUDE.md)`.
4. Hard limits: open `%USERPROFILE%\.gemini\antigravity-cli\settings.json` and merge in
   `tools/gemini/agy-settings.json` (or add the same rules with `/permissions`). It denies
   `gh pr merge`, pushes to `main` and force pushes, and asks before a PixelLab generation.
   Antigravity only reads permissions from this user file, not from the repo.
5. `gh` must be logged in (`gh auth status`), same as for Claude Code CLI.

## Alternative: Gemini CLI with an API key (pay per use)

`npm install -g @google/gemini-cli` (Node.js 20+), copy `.gemini/.env.example` to `.gemini/.env`
with `GEMINI_API_KEY`, copy `tools/gemini/mobile-vault.toml` to `%USERPROFILE%\.gemini\policies\`,
run `gemini`, trust the folder. It reads the same `GEMINI.md` (via `@./CLAUDE.md`) and
`.gemini/settings.json`.

## Giving Gemini a task

```
cd C:\Users\param\Downloads\mobile-vault
git checkout main && git pull
agy "Work on MV-<n>. Follow GEMINI.md."
```

or pick from the backlog: "Take the next Todo ticket labelled bug that nobody has In Progress".
Gemini claims the ticket, works on a branch, runs the autotest, opens the PR and moves the
ticket to In Review. The claude.ai project then updates the playable artifact after merge.
