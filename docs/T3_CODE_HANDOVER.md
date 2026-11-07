# Handover: continue Mobile Vault in T3 Code (MV-712)

Written 2026-11-06 when work moved from the claude.ai project (cloud threads) to **T3 Code**, a
local app that drives Claude Code CLI or Codex CLI on a folder of this repo. Everything an agent
needs is in the repo: rules in `CLAUDE.md` / `AGENTS.md`, the game in `README.md` and
`docs/PROJECT_CONTEXT.md`, and the decisions and history from the claude.ai project memory in
[`docs/project-memory/`](project-memory/INDEX.md).

## สรุปสำหรับ Parames (ภาษาไทย)

1. `git pull` ทั้ง `staging` และ `main` ในโฟลเดอร์ repo ที่มีอยู่ (Windows `C:\Users\param\Downloads\mobile-vault` หรือ Mac `~/Documents/Dev/mobile-vault`)
2. ติดตั้ง/ล็อกอิน Claude Code CLI (`claude`) และ/หรือ Codex CLI (`codex`) แล้วเพิ่มโปรเจกต์ใน T3 Code ชี้ไปที่โฟลเดอร์นั้น
3. ตั้ง secrets ตามตารางด้านล่าง (ไฟล์ local ที่ git-ignore อยู่แล้ว หรือ env) ห้าม commit
4. ถ้าจะทำงานกราฟิกต่อ ให้ดาวน์โหลดโฟลเดอร์ `designs/*/approved/` จาก Library ของโปรเจกต์ claude.ai มาเก็บไว้นอก repo
5. เปิด thread แรกใน T3 Code ด้วยประโยค: "อ่าน docs/T3_CODE_HANDOVER.md และ docs/project-memory/INDEX.md ก่อนเริ่มงาน"

## 1. Local setup

| Need | How | Notes |
|---|---|---|
| Repo | `git fetch origin && git checkout staging && git pull` | Feature work branches from `staging` (CLAUDE.md "Git workflow"). |
| Godot | Official **4.7.2-stable** editor + export templates from the godotengine GitHub release `4.7.2-stable`, SHA-512 checked | Standing permission (memory [godot-download-approval](project-memory/godot-download-approval.md)). Set `MV_GODOT_BIN` if `godot` is not on PATH. |
| Python 3 + Pillow | Art tools, `tools/plane.py`, `tools/pixellab.py`, `tools/release.py` | Ask Parames before installing anything else. |
| GitHub CLI | `gh auth login` once | CLAUDE.md "Opening the PR". Never merge; Parames merges. |
| Claude Code CLI | Reads `CLAUDE.md` and `.claude/skills/` automatically | `.claude/settings.json` already allows `plane.py`, `gh pr create/view`, denies push to protected branches and `gh pr merge`. |
| Codex CLI | Reads `AGENTS.md` (art analyst role: micro-asset Plane tickets only) | ChatGPT sign-in, no API key (memory [codex-art-analyst](project-memory/codex-art-analyst.md)). If Codex should also write code in T3 Code, Parames must say so; `AGENTS.md` currently forbids it. |
| Node (optional) | Only for `npx wrangler` (Cloudflare R2 engine upload, `docs/hosting-cloudflare.md`) and `tools/asset-log` | Ask first. |

Autotest on Windows/macOS: `godot --path . --rendering-driver opengl3 -- --autotest --out=<abs dir>`;
on Linux `bash tools/ci_autotest.sh`. CI runs the same on every PR.

## 2. Secrets and keys (names only, never values)

In the claude.ai cloud the network proxy injected Plane and PixelLab keys, so cloud threads needed
none. Locally every key has to be provided. All the local files below are already in `.gitignore`.

| Service | Where to put it locally | Used by | Where to get it |
|---|---|---|---|
| Plane (workspace `mobile-vault`, project `MV`) | env `PLANE_API_KEY` or one line in `.plane-api-key` | `tools/plane.py`, `tools/micro_asset.py` | app.plane.so → Profile settings → API tokens |
| PixelLab | env `PIXELLAB_API_KEY` or `.pixellab-api-key` | `tools/pixellab.py` and any PixelLab script | pixellab.ai account → API token. Costs money: dry-run + OK first. |
| Supabase (cloud save) | `cloud_config.json` at repo root, shape = `cloud_config.example.json` (`prod` + `test` projects, publishable keys only) | Web export (packed into `web/index.pck`) | Supabase dashboard → Project settings → API. Or recover it from the committed `web/index.pck`. Without it the export ships with cloud save OFF. Prod project ref is in [backend-database-choice](project-memory/backend-database-choice.md). |
| GameAnalytics | `analytics.prod/test.game_key` inside `cloud_config.json` | Web export | GameAnalytics dashboard. Secret keys stay in Vercel env `GA_SECRET_PROD` / `GA_SECRET_TEST`. |
| Asset log (Cloudflare Access) | `.asset-log.json`, or env `ASSET_LOG_URL` + `CF_ACCESS_CLIENT_ID` + `CF_ACCESS_CLIENT_SECRET` | `tools/asset_log.py` (every PixelLab image must be logged) | Cloudflare Zero Trust → Access → Service tokens. Memory [asset-log-site](project-memory/asset-log-site.md). |
| Cloudflare R2 / Pages | `npx wrangler login` | Engine wasm upload after a Godot upgrade | `docs/hosting-cloudflare.md` |
| LangGraph assistant (optional) | `ai/.env` (`ANTHROPIC_API_KEY`, `GEMINI_API_KEY`/`GOOGLE_API_KEY`) | `ai/` | Memory [langgraph-ai-setup](project-memory/langgraph-ai-setup.md) |
| GitHub Actions secrets | Already set in GitHub → Settings → Secrets and variables → Actions: `DISCORD_WEBHOOK_URL`, `DISCORD_ALERTS_WEBHOOK_URL`, `SUPABASE_SERVICE_KEY`, var `SUPABASE_URL`, `SENTRY_DSN` (sentry-forward) | CI workflows | Nothing to do locally. Never put `SUPABASE_SERVICE_KEY` in game code. |

## 3. What did NOT come with the repo

- **Project memory** → exported to [`docs/project-memory/`](project-memory/INDEX.md) (139 files,
  snapshot 2026-11-06). From now on it is the memory: when you learn a lasting fact or Parames
  gives a new rule, update the matching `docs/project-memory/<subject>.md` (or add one and a line in
  `INDEX.md`) in the same PR. New standing rules also go into `CLAUDE.md` (and `AGENTS.md` when
  they concern art specs).
- **Design work files** (`/mnt/project-files/designs/`, ~2.3 GB): PixelLab raw takes, generator
  scripts and every `approved/` set (rooms v3, crew 2.5D, bosses, parallax biomes, icons, events,
  expedition interiors...). They live in the claude.ai project's shared folder (Library), not in
  git. Download at least the `approved/` folders before art work; memory files name each folder
  (e.g. `room-redesign-preview/vault_v3/approved/`). Keep them outside the repo or in a git-ignored
  folder; only the assets that go into the game get committed (`assets/`).
- **Other shared-folder items**: `plane/` (seed script and idea backlogs), `videos/` (trailer),
  `research/`, `screens/`, `patches/`, `supabase/`.
- **Artifacts and Claude Docs** (sample pages, design plans, lore docs) are on claude.ai and are
  read-only from T3 Code. Main links:
  - Playable build: https://claude.ai/artifact/XZt7RMvDG7TFXjdH5MYmAU (locally use the staging
    Vercel/Pages URL from `config/environments.json` instead; T3 Code cannot update artifacts)
  - Art readiness v5: https://claude.ai/artifact/J95HDkDGd1PMv5P3uLPhb2
  - Event Art Samples: https://claude.ai/artifact/DfS8rEuCbCwQsHtNiiNKNR
  - Biome Parallax Preview: https://claude.ai/artifact/QNMzL5sSSobED3sqVKBBzY
  - Room sample pages: index https://claude.ai/artifact/SpjgTwP7hzkvF64zc3Hcww (one page per room)
  - Crew v3 Portraits: https://claude.ai/artifact/BRaMVGdncUG3aLYj4umpeB
  - Gear Sets v1: https://claude.ai/artifact/48ycCAGrBUuEsjeKZpftmi
  - Road Train Samples: https://claude.ai/artifact/VPwAQzYcBTvzLLBeMuSrKq
  - Engine Bay v3: https://claude.ai/artifact/F497YgTisFHRbwNfm3Td4P
  - Other URLs are in the matching memory file.
- **Room guide v3** and the Dr. Ren lore are Claude Docs; the memory files
  [room-guide-v3](project-memory/room-guide-v3.md) and [dr-ren-lore](project-memory/dr-ren-lore.md)
  summarise them. Export them from claude.ai (Markdown) into `docs/` if agents need the full text.

## 4. Open work on 2026-11-06

Check Plane first (`python tools/plane.py list --state "In Progress"` etc.); this list goes stale.

**Open PRs**
- #192 `mv-710-parallax-v2` → `staging`: parallax v2 for all 6 biomes (MV-710, In Review).
- #193 `mv-711-rooms-crew-v3` → stacked on #192: v3 rooms + v3 crew in game (MV-711, In Review).
  Web export still pending because the cloud had no `cloud_config.json`.

**Needs Decision (waiting on Parames)**
- MV-702 Art readiness for big visual upgrade (v5), MV-689 Gear sets v1, MV-707 Engine bay v3 +
  engine types, MV-703 Enemy animations per biome, MV-616 Crew animation/style fixes.

**In Review (art/design done, waiting for OK)**
- MV-704 biome bosses (HD, 5 of 6 awaiting OK), MV-705 rear gunner room v3, MV-706 clean
  sun/moon, MV-709 Dr. Ren ambulance 2/3-floor.

**In Progress** — MV-708 Crew v3 portraits (awaiting OK), MV-712 this handover.

Other pending picks recorded in memory: world v2 scale ([world-v2-scale-plan](project-memory/world-v2-scale-plan.md)),
game modes, threat director, road train design picks, scale-1000 hosting plan, AI audio tools,
metro parallax concept, 32-bit upgrade. Search `docs/project-memory/` for "pending" or "awaiting".

## 5. Rules that change outside claude.ai

- Plane ticket for every task (start → waiting → done with PR/artifact links) still applies.
- After every PixelLab use, report what for, which model/endpoint, gens used and balance left
  (`GET /v2/balance`; memory [pixellab-usage-report](project-memory/pixellab-usage-report.md)).
- "pl" in a message from Parames means "use PixelLab".
- The "update the artifact" step of the definition of done becomes: web export committed in
  `web/`, check it on the staging URL after merge, and say in the PR that the claude.ai artifact
  was not updated.
