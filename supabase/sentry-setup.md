# Sentry player support logs (MV-569)

Sentry project: [apocarlypse-mobile-vault](https://tomorrowismonday.sentry.io/settings/projects/apocarlypse-mobile-vault/)
in the existing `tomorrowismonday` organization (EU). Logging and Error Monitoring
are enabled. Platform **Python** describes the server-side forwarding script;
no Sentry addon, SDK package or credential is bundled with Godot.

## Data path and controls

`Activity.record → Trace category activity → existing Telemetry/rpc_log → Supabase logs → durable outbox → tools/sentry_forward.py → Sentry Logs`

- Client switch `activity_cloud` defaults **off** in the build. The staging remote
  config enables it after test-server setup; regular staging URLs work without
  temporary `?ff=` overrides. UAT and production remain off by default.
  It also requires `activity_log`, `cloud_logs`, and the player's telemetry setting.
  Disabling telemetry stops new activity from entering the upload queue.
- Existing diagnostics in category `error` are eligible for forwarding. Session,
  save, GOD and per-frame/sample trace categories are excluded by the server queue.
- Sentry can search public `player_id`, `user.id`, `session_id`, `event.name`,
  `event.category`, `sentry.release`, `sentry.environment` and selected `game.*`
  attributes. Known events include `loot.received`, `loot.salvaged`, `crew.arrived`,
  `crew.stressed`, `crew.recovered`, `resources.changed`, and `monitoring.test`.
- Engine/script errors also create Sentry Issues. Gameplay warnings such as stressed
  crew and low resources remain log warnings. The relay preserves diagnostic text;
  it does not invent symbolicated Godot stack traces or attach session recordings.
- Only allowlisted attributes are forwarded: no Supabase auth UUID, email, arbitrary
  JSON save, account/session credentials, service keys or DSN attributes.
- Source environment is explicitly configured by the server job. Production and
  test use separate Supabase credentials. Client-reported environment is a separate
  `game.environment` attribute (staging/UAT share the test database).
- The outbox is disabled initially, has no historical backfill, uses per-row leases
  and only acknowledges successful sends. Failures/429 retain rows for retry.
  Delivery is **at least once**: a crash after Sentry accepts but before DB ack may
  duplicate a log; `source.log_id` identifies duplicates. Error event IDs are stable.
- The game-side queue still has Trace's existing bounds (800 memory / 400 persisted).
  Extended offline play can exceed these bounds; this is support telemetry, not an
  authoritative inventory ledger. The server outbox protects rows already received.

## Deployment (owner/admin)

1. Apply `supabase/migrations/0007_sentry_forward.sql` to the **test** project first.
   Run the SQL tests on a disposable database, not on player databases. Migration
   creates the service-role-only queue/RPCs; forwarding remains off.
2. In GitHub repository **Actions secrets**, set `SENTRY_DSN` using the existing
   project's **Client Keys (DSN)**. Keep the value out of chat, source and screenshots.
   The DSN is an ingestion key, not a Sentry account/API token. Do not create broader
   personal/organization API tokens for forwarding.
3. Configure each source deliberately:

   | Source | URL variable or secret | Service key secret |
   |---|---|---|
   | production | `SUPABASE_URL` | `SUPABASE_SERVICE_KEY` |
   | test (staging/UAT/dev) | `SUPABASE_TEST_URL` | `SUPABASE_TEST_SERVICE_KEY` |

   Existing production error-alert credentials can be reused server-side. Missing
   source configuration skips that source and never falls back to another database.
4. On the test project's SQL Editor, enable enqueueing of **new** rows:

   ```sql
   update public.sentry_forward_config set enabled = true where singleton;
   ```

5. After the workflow/relay code is merged into the repository's default branch, set
   `SENTRY_FORWARD_ENABLED=true` and `SENTRY_FORWARD_TEST_ENABLED=true` only after reviewing
   the runner usage and Sentry quota. Leave `SENTRY_FORWARD_PRODUCTION_ENABLED` unset/false
   throughout test setup; the production job will not contact its database even if old
   production credentials already exist. Workflow **Sentry forward** batches every five
   minutes (GitHub scheduling can be delayed). Client upload normally adds up to 60 s.
   This is not a seconds-latency live stream. For that, run the same script in an
   existing server worker more frequently; never run it on player devices.
6. Reload the staging game to fetch `features.staging.json` (`activity_cloud=true`).
   Enable the player telemetry setting and check that cloud sign-in succeeds.
   GOD → LOG/เซฟ → **ทดสอบส่งกิจกรรมไป Sentry** generates `monitoring.test` and uses
   the normal opt-in upload. In Sentry Explore → Logs, search
   `event.name:monitoring.test` and environment **test**. Verify a real player ID,
   a loot event, a morale transition, and the player opt-out before production.
7. Apply/enable the migration and feature in production only after that check, then
   explicitly set `SENTRY_FORWARD_PRODUCTION_ENABLED=true`.

Pause forwarding with `SENTRY_FORWARD_ENABLED=false`; also set the DB config to false
to stop enqueueing. Keep retained rows for later retry. Client `activity_cloud=false`
stops new activity telemetry while the in-game local feed keeps working.

## Verification without credentials

```sh
python -m unittest discover -s tools/tests -p test_sentry_forward.py
python tools/sentry_forward.py --dry-run
bash tools/test_error_spike.sh  # includes outbox SQL checks when local PostgreSQL exists
godot --path . --rendering-driver opengl3 -- --autotest --only=activity --out=<isolated-dir>
```

Use an isolated APPDATA on Windows: autotest wipes its local save. No test calls a
real Supabase instance. To verify Sentry alone, set `SENTRY_DSN` in the server process
and run `python tools/sentry_forward.py --demo`; this sends one synthetic
`DEMO-PLAYER` record in environment **setup-test**, never player data.

The stdlib relay implements Sentry's documented [log envelope wire format](https://develop.sentry.dev/sdk/telemetry/logs/),
uses no third-party packages, rejects redirects, and caps each envelope at 100 logs.
Offline tests verify formatting, field allowlisting, acknowledgements and retry handling.
