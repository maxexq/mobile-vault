---
name: error-spike-alerts
description: MV-171 player error spike / new-error alerts from Supabase public.logs to a separate Discord #alerts channel (PR #54)
metadata:
  type: project
  modified: 2026-10-24T13:33:39.531Z
---

2026-10-24 MV-171, PR #54 + follow-up #55 MERGED (#55: Error spike successes never posted to dev-feed, SUPABASE_URL accepted as secret or variable), Plane Awaiting Verify (Parames still has to run 0005 SQL + set secrets + test run).
- Parames asked whether to split from dev-feed; answer given: yes, separate #alerts channel, secret `DISCORD_ALERTS_WEBHOOK_URL`, falls back to `DISCORD_WEBHOOK_URL` when unset.
- `supabase/migrations/0005_log_alerts.sql`: `log_alert_check()` (spike vs baseline + new error fingerprints, digits -> #) and `log_alert_ack()` -> `public.log_alerts`; service_role only.
- Workflow **Error spike** (cron every 15 min) + `.github/scripts/error-spike.sh`; thresholds = optional repo vars `ERROR_SPIKE_*`; needs secret `SUPABASE_SERVICE_KEY` + var `SUPABASE_URL` (Parames sets them; no-op notice until then).
- discord-notify mutes successful *scheduled* workflow_run events (else dev-feed spam every 15 min).
- Tests: `bash tools/test_error_spike.sh` (also a step in Autotest), spins up a throwaway local PostgreSQL (container has PG16 at /usr/lib/postgresql/16/bin; as root use runuser -u postgres).
Related: [[discord-notify]], [[backend-database-choice]], [[ci-autotest]]
