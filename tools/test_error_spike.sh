#!/usr/bin/env bash
# Tests for the error spike alerts (MV-171), run by the Autotest workflow and by hand on Linux:
#   bash tools/test_error_spike.sh
# 1. .github/scripts/error-spike.sh with saved answers (DRY_RUN, nothing sent).
# 2. supabase/migrations/0005_log_alerts.sql on a throwaway local PostgreSQL (needs postgresql 14+;
#    skipped when initdb isn't there). Applies 0001-0006 on a stub `auth` schema, then
#    tools/tests/log_alerts_test.sql, then 0006_anticheat.sql (MV-174) with tools/tests/anticheat_test.sql.
set -euo pipefail
cd "$(dirname "$0")/.."
S=.github/scripts/error-spike.sh
FIX=tools/tests/error_spike_check.json
fails=0
check() { # name condition-output expected-substring
  if grep -qF -- "$3" <<<"$2"; then echo "PASS $1"; else echo "FAIL $1: wanted '$3' in:"; echo "$2"; fails=$((fails+1)); fi
}
run() { env -u DISCORD_WEBHOOK_URL -u DISCORD_ALERTS_WEBHOOK_URL -u SUPABASE_SERVICE_KEY DRY_RUN=1 "$@" bash "$S" 2>&1; }

bash -n "$S"
out=$(run CHECK_JSON=$FIX SUPABASE_URL=https://abcd1234.supabase.co)
check "spike embed" "$out" '"title": "🚨 Error พุ่ง: 26 ครั้งใน 60 นาที (2 ผู้เล่น)"'
check "new embed" "$out" '"title": "🆕 Error ใหม่ 2 แบบ (ไม่เคยเจอใน 7 วันก่อน)"'
check "dashboard link" "$out" 'https://supabase.com/dashboard/project/abcd1234/sql/new'
check "no pings by default" "$out" '"parse": []'
check "fallback channel" "$out" 'would go to dev-feed'
out=$(run CHECK_JSON=$FIX DISCORD_ALERTS_WEBHOOK_URL=https://example.invalid/x ERROR_SPIKE_MENTION='<@&123>' ERROR_SPIKE_NEW_DAYS=3)
check "alerts channel" "$out" 'would go to alerts'
check "mention" "$out" '"content": "<@&123> ดู log'
check "new_days in title" "$out" 'ไม่เคยเจอใน 3 วันก่อน'
out=$(run CHECK_JSON=$FIX ERROR_SPIKE_NEW_ALERTS=false)
check "new alerts off" "$out" 'spike=true new=0'
tmp=$(mktemp); jq '.spike = false | .new = []' "$FIX" >"$tmp"
out=$(run CHECK_JSON="$tmp"); rm -f "$tmp"
check "quiet" "$out" 'No alert'
out=$(run MODE=test)
check "test message" "$out" '🧪 ทดสอบ'
out=$(run SUPABASE_URL=)
check "no secrets = no-op" "$out" 'not set: SUPABASE_URL (variable) SUPABASE_SERVICE_KEY (secret), nothing checked'
out=$(run SUPABASE_URL=https://abcd1234.supabase.co)
check "names the missing one" "$out" 'not set: SUPABASE_SERVICE_KEY (secret), nothing checked'

PG_BIN="${PG_BIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -n1)}"
if [ -z "$PG_BIN" ] || [ ! -x "$PG_BIN/initdb" ]; then
  echo "SKIP sql: no PostgreSQL (set PG_BIN)"
else
  D=$(mktemp -d); as=()
  if [ "$(id -u)" = 0 ]; then chown postgres "$D"; as=(runuser -u postgres --); fi
  "${as[@]}" "$PG_BIN/initdb" -D "$D/data" -U postgres -A trust >/dev/null
  "${as[@]}" "$PG_BIN/pg_ctl" -D "$D/data" -o "-k $D -p 5491 -c listen_addresses=" -l "$D/log" -w start >/dev/null
  trap '"${as[@]}" "$PG_BIN/pg_ctl" -D "$D/data" -m immediate stop >/dev/null; rm -rf "$D"' EXIT
  Q=(env PGOPTIONS="-c client_min_messages=warning" psql -h "$D" -p 5491 -U postgres -v ON_ERROR_STOP=1 -qX)
  "${Q[@]}" -c "create role anon; create role authenticated; create role service_role; create schema auth;
    create table auth.users (id uuid primary key, email text, is_anonymous boolean default false);
    create function auth.uid() returns uuid language sql as \$\$ select null::uuid \$\$;"
  for f in supabase/migrations/0*.sql; do "${Q[@]}" -f "$f"; done
  if out=$("${Q[@]}" -f tools/tests/log_alerts_test.sql 2>&1); then
    echo "PASS sql"
  else
    echo "FAIL sql:"; echo "$out"; fails=$((fails+1))
  fi
  if out=$("${Q[@]}" -f tools/tests/anticheat_test.sql 2>&1); then
    echo "PASS sql anticheat (MV-174)"
  else
    echo "FAIL sql anticheat:"; echo "$out"; fails=$((fails+1))
  fi
  if out=$("${Q[@]}" -f tools/tests/sentry_forward_test.sql 2>&1); then
    echo "PASS sql Sentry outbox"
  else
    echo "FAIL sql Sentry outbox:"; echo "$out"; fails=$((fails+1))
  fi
fi

[ "$fails" = 0 ] && echo "error spike tests: all passed" || { echo "error spike tests: $fails failed"; exit 1; }
