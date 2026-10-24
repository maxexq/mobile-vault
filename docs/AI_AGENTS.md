# AI agents on this repo

Three agents work on Mobile Vault with the same rules (`CLAUDE.md`):

| Agent | Where | Reads rules from | Plane name |
|-------|-------|------------------|------------|
| Claude (claude.ai project) | cloud threads | project memory + `CLAUDE.md` | `Claude (claude.ai)` |
| Claude Code CLI | Parames's PC | `CLAUDE.md`, `.claude/settings.json` | `Claude Code CLI` |
| Gemini CLI (`gemini-4-argon`) | Parames's PC | `GEMINI.md` → imports `CLAUDE.md`, `.gemini/settings.json` | `Gemini CLI` |

They split work through Plane: an In Progress ticket belongs to whoever claimed it
(`python tools/plane.py --by "<name>" claim MV-<n>`), every agent works on its own `mv-<n>-…`
branch, opens a PR with `Agent: <name>` in the body, and only Parames merges.

## Gemini CLI setup (once, on Windows)

1. Install Gemini CLI (needs Node.js 20+): `npm install -g @google/gemini-cli`
   (https://github.com/google-gemini/gemini-cli/blob/main/docs/get-started/installation.mdx).
2. Key and model: copy `.gemini/.env.example` to `.gemini/.env` and fill `GEMINI_API_KEY`
   (same key as `ai/.env`). `GEMINI_MODEL=gemini-4-argon` picks the model; `/model` in the CLI
   shows what is really in use.
3. Hard limits: copy `tools/gemini/mobile-vault.toml` to `%USERPROFILE%\.gemini\policies\`.
   It denies pushes to `main`, force pushes and `gh pr merge`, and asks before a paid PixelLab
   batch. (Gemini CLI ignores project-level policy folders, so it has to live in your user
   folder.)
4. `gh` must be logged in (`gh auth status`), same as for Claude Code CLI.
5. In the repo folder run `gemini`, answer **Trust folder** (project settings only load in a
   trusted folder), then `/memory show` should list `GEMINI.md` and the `CLAUDE.md` rules.

## Giving Gemini a task

```
cd C:\Users\param\Downloads\mobile-vault
git checkout main && git pull
gemini
> Work on MV-<n>. Follow GEMINI.md.
```

or pick from the backlog: "Take the next Todo ticket labelled bug that nobody has In Progress".
Gemini claims the ticket, works on a branch, runs the autotest, opens the PR and moves the
ticket to In Review. The claude.ai project then updates the playable artifact after merge.
