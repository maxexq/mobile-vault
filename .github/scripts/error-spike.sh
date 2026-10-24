#!/usr/bin/env bash
# Error spike alerts from the player logs (MV-171). Asks Supabase public.log_alert_check()
# (supabase/migrations/0005_log_alerts.sql) whether errors in public.logs jumped or a never-seen
# error appeared, posts it to Discord, then records it with log_alert_ack() so it isn't posted twice.
# Used by .github/workflows/error-spike.yml. Needs only bash, jq and curl.
#
#   SUPABASE_URL           https://<ref>.supabase.co (repo variable)
#   SUPABASE_SERVICE_KEY   service_role or sb_secret_ key (repo secret); when empty: notice, exit 0
#   DISCORD_ALERTS_WEBHOOK_URL   alerts channel (repo secret); falls back to DISCORD_WEBHOOK_URL (dev feed)
#   ERROR_SPIKE_WINDOW_MIN / _MIN_ERRORS / _MIN_PLAYERS / _RATIO / _BASELINE_HOURS / _COOLDOWN_MIN /
#   _NEW_DAYS / _KINDS (comma list) / _NEW_ALERTS (false = spikes only) / _MENTION (e.g. <@&role id>)
#                          thresholds (repo variables); empty = the defaults below
#   INCLUDE_TEST           "true" = count GOD "ส่ง error ทดสอบ" errors too (manual runs)
#   MODE                   check (default) | test  (test = post a sample alert, nothing read or recorded)
#   DRY_RUN                "1" = print the Discord JSON, send nothing, record nothing
#   CHECK_JSON             path to a saved log_alert_check() answer, used instead of calling Supabase
#
# Local test: DRY_RUN=1 CHECK_JSON=tools/tests/error_spike_check.json bash .github/scripts/error-spike.sh
set -euo pipefail

MODE="${MODE:-check}"
REPO="${GITHUB_REPOSITORY:-maxexq/mobile-vault}"
WEBHOOK="${DISCORD_ALERTS_WEBHOOK_URL:-${DISCORD_WEBHOOK_URL:-}}"
CHANNEL=alerts; [ -z "${DISCORD_ALERTS_WEBHOOK_URL:-}" ] && CHANNEL=dev-feed
RED=15158332; ORANGE=15105570; BLUE=3447003

num() { [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] && echo "$1" || echo "$2"; }
WINDOW=$(num "${ERROR_SPIKE_WINDOW_MIN:-}" 60)
MIN_ERRORS=$(num "${ERROR_SPIKE_MIN_ERRORS:-}" 20)
MIN_PLAYERS=$(num "${ERROR_SPIKE_MIN_PLAYERS:-}" 2)
RATIO=$(num "${ERROR_SPIKE_RATIO:-}" 3)
BASELINE=$(num "${ERROR_SPIKE_BASELINE_HOURS:-}" 24)
COOLDOWN=$(num "${ERROR_SPIKE_COOLDOWN_MIN:-}" 60)
NEW_DAYS=$(num "${ERROR_SPIKE_NEW_DAYS:-}" 7)
KINDS="${ERROR_SPIKE_KINDS:-error,script,shader}"
NEW_ALERTS="${ERROR_SPIKE_NEW_ALERTS:-true}"
MENTION="${ERROR_SPIKE_MENTION:-}"
INCLUDE_TEST="${INCLUDE_TEST:-false}"; [ "$INCLUDE_TEST" = "true" ] || INCLUDE_TEST=false

dashboard=""
if [[ "${SUPABASE_URL:-}" =~ ^https://([a-z0-9]+)\.supabase\.co ]]; then
  dashboard="https://supabase.com/dashboard/project/${BASH_REMATCH[1]}/sql/new"
fi

rpc() { # name json-body
  local auth=()
  # legacy service_role keys are JWTs and go in Authorization too; new sb_secret_ keys only in apikey
  [[ "$SUPABASE_SERVICE_KEY" == eyJ* ]] && auth=(-H "Authorization: Bearer $SUPABASE_SERVICE_KEY")
  curl -sS --fail-with-body --retry 3 -X POST "${SUPABASE_URL%/}/rest/v1/rpc/$1" \
    -H "apikey: $SUPABASE_SERVICE_KEY" "${auth[@]}" -H "Content-Type: application/json" -d "$2"
}

post() { # payload
  if [ "${DRY_RUN:-}" = "1" ]; then echo "$1"; return 0; fi
  if [ -z "$WEBHOOK" ]; then
    echo "::warning::DISCORD_ALERTS_WEBHOOK_URL and DISCORD_WEBHOOK_URL are not set, alert not sent"; return 1
  fi
  curl -sS --fail-with-body --retry 3 -H "Content-Type: application/json" -d "$1" "$WEBHOOK" >/dev/null
}

# one row of an error list: `message` ×n · players · version
rows='map("• `" + ((.msg // .fp) | gsub("`"; "'"'"'") | .[0:150]) + "` ×\(.n) · \(.players) คน"
          + (if .game_version then " · " + .game_version else "" end)) | join("\n")'

if [ "$MODE" = "test" ]; then
  check='{"spike":true,"window_min":60,"errors":42,"players":5,"baseline_per_window":3.5,"baseline_hours":24,
    "ratio":12,"versions":{"4.7.0-alpha.1":42},"new":[],"test":true,
    "top":[{"fp":"ตัวอย่าง: Invalid get index (x.gd:# f)","msg":"ตัวอย่าง: Invalid get index (x.gd:12 f)","n":42,"players":5}]}'
elif [ -n "${CHECK_JSON:-}" ]; then
  check=$(cat "$CHECK_JSON")
else
  if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_SERVICE_KEY:-}" ]; then
    echo "::notice::SUPABASE_URL variable or SUPABASE_SERVICE_KEY secret is not set, nothing checked"; exit 0
  fi
  body=$(jq -n --argjson w "$WINDOW" --argjson e "$MIN_ERRORS" --argjson p "$MIN_PLAYERS" \
    --argjson r "$RATIO" --argjson b "$BASELINE" --argjson c "$COOLDOWN" --argjson d "$NEW_DAYS" \
    --arg k "$KINDS" --argjson t "$INCLUDE_TEST" \
    '{p_window_min: $w, p_min_errors: $e, p_min_players: $p, p_ratio: $r, p_baseline_hours: $b,
      p_cooldown_min: $c, p_new_days: $d, p_kinds: ($k | split(",") | map(gsub("^ +| +$"; ""))),
      p_include_test: $t}')
  check=$(rpc log_alert_check "$body")
fi

spike=$(jq -r '.spike == true' <<<"$check")
new=$(jq -c 'if .new then .new else [] end' <<<"$check")
[ "$NEW_ALERTS" = "false" ] && new='[]'
echo "Checked: $(jq -c '{errors, players, window_min, baseline_per_window, ratio, spike, new: (.new // [] | length)}' <<<"$check")"

if [ "$spike" != "true" ] && [ "$new" = "[]" ]; then
  echo "No alert"; exit 0
fi

embeds='[]'
if [ "$spike" = "true" ]; then
  embeds=$(jq -c --argjson color "$RED" --arg dash "$dashboard" --arg repo "$REPO" '[{
    title: ((if .test then "🧪 ทดสอบ · " else "" end)
      + "🚨 Error พุ่ง: \(.errors) ครั้งใน \(.window_min) นาที (\(.players) ผู้เล่น)"),
    color: $color,
    description: ("Error ที่เจอบ่อยสุด:\n" + (.top | '"$rows"')),
    fields: [
      {name: "ปกติ", value: "~\(.baseline_per_window) ต่อ \(.window_min) นาที (เฉลี่ย \(.baseline_hours) ชม.)", inline: true},
      {name: "เพิ่มขึ้น", value: (if .ratio then "×\(.ratio)" else "จากศูนย์" end), inline: true},
      {name: "เวอร์ชัน", value: (.versions | to_entries | sort_by(-.value) | map("\(.key) (\(.value))") | join(", ") | if . == "" then "-" else .[0:200] end), inline: true}
    ],
    footer: {text: ($repo + " · public.logs")}
  } + (if $dash != "" then {url: $dash} else {} end)]' <<<"$check")
fi
if [ "$new" != "[]" ]; then
  embeds=$(jq -c --argjson color "$ORANGE" --arg dash "$dashboard" --arg repo "$REPO" --argjson new "$new" --arg days "$NEW_DAYS" '. + [{
    title: "🆕 Error ใหม่ \($new | length) แบบ (ไม่เคยเจอใน \($days) วันก่อน)",
    color: $color,
    description: ($new | '"$rows"'),
    footer: {text: ($repo + " · public.logs")}
  } + (if $dash != "" then {url: $dash} else {} end)]' <<<"$embeds")
fi

payload=$(jq -n --argjson embeds "$embeds" --arg mention "$MENTION" '{
  embeds: $embeds,
  allowed_mentions: (if $mention != "" then {parse: ["roles", "users"]} else {parse: []} end)
} + (if $mention != "" then {content: ($mention + " ดู log: select * from public.log_errors_recent;")} else {} end)')

post "$payload"
echo "Posted to $CHANNEL: spike=$spike new=$(jq length <<<"$new")"

# record it, so the next run doesn't post the same spike (cooldown) or the same new error again
if [ "$MODE" = "test" ] || [ -n "${CHECK_JSON:-}" ] || [ "${DRY_RUN:-}" = "1" ]; then exit 0; fi
ack=$(jq -n --argjson s "$spike" --argjson new "$new" --argjson check "$check" \
  '{p_spike: $s, p_new_fps: ($new | map(.fp)), p_detail: ($check | del(.new))}')
echo "Recorded: $(rpc log_alert_ack "$ack")"
