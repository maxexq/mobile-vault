---
name: plane-setup
description: Plane (app.plane.so) task tracker setup for Mobile Vault: seed script, structure, project MV seeded 2026-10-23, auth via proxy network secret
metadata:
  type: project
  modified: 2026-10-23T12:10:52.716Z
---

2026-10-23: Parames wants Plane (app.plane.so) as the task/ticket/planning tool, with past work backfilled as Done tickets.
- No Plane MCP connector exists in the registry; use REST API v1 (`https://api.plane.so/api/v1`, header `X-API-Key`, 60 req/min, work items at `/projects/{id}/work-items/`). Docs mirror: git clone github.com/makeplane/developer-docs (developers.plane.so is blocked by the proxy).
- Cloud env blocks api.plane.so by default: Parames must add it to Allowed domains and store the token as env var `PLANE_API_KEY` (never paste in chat, never save in memory). Workspace slug: `mobile-vault`.
- Seed script: /mnt/project-files/plane/seed_plane.py (idempotent via external_source `mobile-vault-seed` + external_id keys like `pr-21`, `bl-modes-2`; `--dry-run` works offline). Structure summary: /mnt/project-files/plane/plane-structure.md. Project identifier `MV`, extra states Needs Decision / In Review / Awaiting Verify, 12 modules per game system, weekly cycles.
- 2026-10-23 SEEDED: workspace `mobile-vault`, project "Mobile Vault" id c18b3b42-dee2-4767-9a63-b278a184f125 (pre-existing sample project, identifier changed MOBIL -> MV). 68 work items created; Plane's onboarding sample content deleted (Parames approved).
- Auth: Parames added a Network secret (host api.plane.so, header X-API-Key) so requests from this cloud env get the key via the proxy; no env var needed, script works without PLANE_API_KEY.
- 2026-10-23 Parames standing rule: EVERY task gets a Plane ticket kept in sync start->done with links (In Progress when starting, Done when delivered). Quick create: POST /workspaces/mobile-vault/projects/<id>/work-items/ via urllib with no key (proxy injects), external_source mobile-vault-seed. Example MV-76 (Drawdy systems map).
**How to apply:** new feature threads should add/move a Plane ticket once seeding is done; add new items to ISSUES in the script with a new external_id and re-run. Related: [[god-mode]], [[feature-flags-design]].
- 2026-10-23: RAG ideas logged as Todo: parent MV-77 + sub-items MV-78 (balance assistant, recommended first, builds on MV-76) to MV-82; external_ids rag-*.
- 2026-10-23: Cloud save fix + Guest/Google login ticket created In Progress (external_id cloud-save-login), worked in another thread.
