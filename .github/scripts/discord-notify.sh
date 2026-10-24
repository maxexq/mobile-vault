#!/usr/bin/env bash
# Turns one GitHub event into a Discord embed and posts it to DISCORD_WEBHOOK_URL.
# Used by .github/workflows/discord-notify.yml. Needs only bash, jq and curl (all on
# ubuntu-latest runners).
#
#   EVENT_NAME   github.event_name (pull_request_target, pull_request_review, status,
#                deployment_status, workflow_run, workflow_dispatch)
#   EVENT_PATH   path to the event JSON (GITHUB_EVENT_PATH)
#   DISCORD_WEBHOOK_URL   repo secret; when empty the script prints a notice and exits 0
#   SKIP_PREVIEW_SUCCESS  "true" = don't post successful Preview deploys (repo variable)
#   DRY_RUN      "1" = print the Discord JSON instead of sending it (local testing)
#
# Local test: DRY_RUN=1 EVENT_NAME=pull_request_target EVENT_PATH=payload.json \
#             bash .github/scripts/discord-notify.sh
set -euo pipefail

EVENT_NAME="${EVENT_NAME:?EVENT_NAME is required}"
EVENT_PATH="${EVENT_PATH:?EVENT_PATH is required}"
REPO="${GITHUB_REPOSITORY:-maxexq/mobile-vault}"

# Discord embed colours (decimal RGB).
GREEN=3066993; RED=15158332; PURPLE=10181046; GREY=9807270; BLUE=3447003; YELLOW=15844367

ev() { jq -r "$1 // empty" "$EVENT_PATH"; }
short() { printf '%s' "$1" | head -c "$2"; }

title=""; url=""; color=$GREY; desc=""; fields="[]"

add_field() { # name value [inline]
  fields=$(jq -c --arg n "$1" --arg v "$2" --argjson i "${3:-true}" \
    '. + [{name: $n, value: $v, inline: $i}]' <<<"$fields")
}

case "$EVENT_NAME" in
  pull_request_target|pull_request)
    action=$(ev .action)
    num=$(ev .pull_request.number); pr_title=$(ev .pull_request.title)
    url=$(ev .pull_request.html_url); actor=$(ev .sender.login)
    head=$(ev .pull_request.head.ref); base=$(ev .pull_request.base.ref)
    case "$action" in
      opened|reopened)
        [ "$(ev .pull_request.draft)" = "true" ] && { echo "Draft PR, skipped"; exit 0; }
        title="🟢 PR #$num เปิดใหม่: $pr_title"; color=$GREEN
        [ "$action" = "reopened" ] && title="🟢 PR #$num เปิดอีกครั้ง: $pr_title"
        desc=$(short "$(ev .pull_request.body)" 350) ;;
      ready_for_review)
        title="🟢 PR #$num พร้อม review: $pr_title"; color=$GREEN ;;
      review_requested)
        who=$(ev '.requested_reviewer.login // .requested_team.name')
        title="👀 PR #$num ขอ review จาก $who: $pr_title"; color=$YELLOW ;;
      closed)
        if [ "$(ev .pull_request.merged)" = "true" ]; then
          title="🟣 PR #$num merge แล้ว: $pr_title"; color=$PURPLE
          actor=$(ev '.pull_request.merged_by.login // .sender.login')
        else
          title="⚫ PR #$num ปิดโดยไม่ merge: $pr_title"; color=$GREY
        fi ;;
      *) echo "pull_request action '$action' not notified"; exit 0 ;;
    esac
    add_field "Branch" "\`$head\` → \`$base\`"
    add_field "โดย" "$actor" ;;

  pull_request_review)
    state=$(ev .review.state); num=$(ev .pull_request.number)
    pr_title=$(ev .pull_request.title); url=$(ev .review.html_url)
    body=$(ev .review.body)
    case "$state" in
      approved)          title="✅ PR #$num approve แล้ว: $pr_title"; color=$GREEN ;;
      changes_requested) title="❌ PR #$num ขอให้แก้: $pr_title"; color=$RED ;;
      commented)
        # Every inline comment also arrives as an empty "commented" review: skip those.
        [ -z "$body" ] && { echo "Empty comment review, skipped"; exit 0; }
        title="💬 PR #$num มี review comment: $pr_title"; color=$BLUE ;;
      *) echo "review state '$state' not notified"; exit 0 ;;
    esac
    desc=$(short "$body" 350)
    add_field "โดย" "$(ev .review.user.login)" ;;

  deployment_status)
    state=$(ev .deployment_status.state); env_name=$(ev .deployment.environment)
    case "$state" in
      success)
        if [ "${SKIP_PREVIEW_SUCCESS:-}" = "true" ] && [[ "$env_name" != *roduction* ]]; then
          echo "Preview success skipped (SKIP_PREVIEW_SUCCESS)"; exit 0
        fi
        title="🚀 Deploy สำเร็จ ($env_name)"; color=$GREEN ;;
      failure|error) title="🔥 Deploy ล้มเหลว ($env_name)"; color=$RED ;;
      *) echo "deployment state '$state' not notified"; exit 0 ;;
    esac
    url=$(ev '.deployment_status.environment_url // .deployment_status.target_url')
    desc=$(short "$(ev .deployment_status.description)" 200)
    ref=$(ev .deployment.ref); sha=$(ev .deployment.sha)
    add_field "Ref" "\`${ref:-${sha:0:7}}\`"
    add_field "Commit" "[\`${sha:0:7}\`](https://github.com/$REPO/commit/$sha)"
    add_field "โดย" "$(ev '.deployment_status.creator.login // .sender.login')" ;;

  status)
    # Vercel reports deploys as a commit status (context "Vercel"), not as GitHub deployments.
    context=$(ev .context); state=$(ev .state)
    [[ "$context" == Vercel* ]] || { echo "status '$context' not notified"; exit 0; }
    branch=$(jq -r '[.branches[].name] | if index("main") then "main" else (.[0] // "") end' "$EVENT_PATH")
    env_name=Preview; [ "$branch" = "main" ] && env_name=Production
    case "$state" in
      success)
        if [ "${SKIP_PREVIEW_SUCCESS:-}" = "true" ] && [ "$env_name" != "Production" ]; then
          echo "Preview success skipped (SKIP_PREVIEW_SUCCESS)"; exit 0
        fi
        title="🚀 Deploy สำเร็จ ($env_name)"; color=$GREEN ;;
      failure|error) title="🔥 Deploy ล้มเหลว ($env_name)"; color=$RED ;;
      *) echo "Vercel state '$state' not notified"; exit 0 ;;
    esac
    url=$(ev .target_url)
    desc=$(short "$(ev .description)" 200)
    sha=$(ev .sha)
    [ -n "$branch" ] && add_field "Branch" "\`$branch\`"
    add_field "Commit" "[\`${sha:0:7}\`](https://github.com/$REPO/commit/$sha)"
    [ "$env_name" = "Production" ] && [ "$state" = "success" ] && \
      add_field "เว็บ" "https://apocarlypse-mobile-vault.vercel.app/" false
    add_field "Commit message" "$(short "$(ev .commit.commit.message | head -n1)" 200)" false ;;

  workflow_run)
    conclusion=$(ev .workflow_run.conclusion); name=$(ev .workflow_run.name)
    # scheduled jobs (Error spike, every 15 min) would flood the feed: only their failures are news
    if [ "$(ev .workflow_run.event)" = "schedule" ] && [ "$conclusion" = "success" ]; then
      echo "Scheduled run '$name' succeeded, not notified"; exit 0
    fi
    case "$conclusion" in
      success)               title="✅ CI ผ่าน: $name"; color=$GREEN ;;
      failure|timed_out|startup_failure) title="❌ CI ไม่ผ่าน: $name ($conclusion)"; color=$RED ;;
      *) echo "workflow conclusion '$conclusion' not notified"; exit 0 ;;
    esac
    url=$(ev .workflow_run.html_url)
    desc=$(short "$(ev .workflow_run.display_title)" 200)
    add_field "Branch" "\`$(ev .workflow_run.head_branch)\`"
    add_field "Event" "$(ev .workflow_run.event)"
    add_field "โดย" "$(ev .workflow_run.actor.login)" ;;

  workflow_dispatch)
    title="🔔 ทดสอบแจ้งเตือน Discord จาก $REPO"; color=$BLUE
    url="https://github.com/$REPO/actions"
    desc="ถ้าเห็นข้อความนี้ แปลว่า webhook ตั้งค่าถูกแล้ว"
    add_field "โดย" "$(ev .sender.login)" ;;

  *) echo "Event '$EVENT_NAME' not handled"; exit 0 ;;
esac

payload=$(jq -n \
  --arg title "$(short "$title" 250)" --arg url "$url" --arg desc "$desc" \
  --argjson color "$color" --argjson fields "$fields" --arg repo "$REPO" \
  '{
    allowed_mentions: {parse: []},
    embeds: [{title: $title, color: $color, footer: {text: $repo}, fields: $fields}
      + (if $url  != "" then {url: $url} else {} end)
      + (if $desc != "" then {description: $desc} else {} end)]}')

if [ "${DRY_RUN:-}" = "1" ]; then
  echo "$payload"; exit 0
fi
if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
  echo "::notice::DISCORD_WEBHOOK_URL secret is not set, nothing sent"; exit 0
fi
curl -sS --fail-with-body --retry 3 -H "Content-Type: application/json" \
  -d "$payload" "$DISCORD_WEBHOOK_URL"
echo "Sent: $title"
