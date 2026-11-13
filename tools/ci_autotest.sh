#!/usr/bin/env bash
# Runs the autotest the way CI does and fails on any FAIL check, script error, crash or hang
# (MV-110). Used by .github/workflows/autotest.yml and nightly-autotest.yml; works the same in a
# Linux cloud session.
#   GODOT=godot OUT=/abs/dir TIMEOUT=1200 bash tools/ci_autotest.sh                 # the whole autotest
#   ONLY="core threat touch" bash tools/ci_autotest.sh                             # those groups (MV-779)
#   ONLY="$(python3 tools/ci_select.py)" bash tools/ci_autotest.sh                 # what this branch needs
#   bash tools/ci_autotest.sh --only=touch                                         # extra args go to Godot
# ONLY runs one Godot process per --only=<group>, one after the other, each with its own log in
# $OUT/<group>/; TIMEOUT is per process. ONLY=full or empty = the whole autotest, ONLY=none = nothing.
# Needs xvfb-run: --headless hangs on frame_post_draw (screenshots), so a virtual X display is used.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
OUT=${OUT:-$PWD/build/autotest}
TIMEOUT=${TIMEOUT:-1200}
ONLY=${ONLY:-}
mkdir -p "$OUT"

if [ "$ONLY" = none ]; then
	echo "ONLY=none: no game change, nothing to run"
	[ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "### Autotest: ⏭️ nothing to run" >> "$GITHUB_STEP_SUMMARY"
	exit 0
fi

# first run on a fresh checkout: import assets so res:// textures exist
[ -d .godot/imported ] || "$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1

rows=()        # one summary row per Godot process
failed_logs=() # logs to quote in the summary
status=ok

# run_one <name> <out dir> [godot user args...]
run_one() {
	local name=$1 dir=$2
	shift 2
	mkdir -p "$dir"
	local log="$dir/autotest.log" start=$SECONDS
	echo "::group::autotest $name"
	timeout --kill-after=30 "$TIMEOUT" xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
		--audio-driver Dummy -- --autotest --out="$dir" "$@" 2>&1 | tee "$log"
	local code=${PIPESTATUS[0]}
	echo "::endgroup::"
	local passes fails errors done_line ok=ok
	passes=$(grep -c '^\[autotest\] PASS' "$log")
	fails=$(grep -c '^\[autotest\] FAIL' "$log")
	errors=$(grep -c 'SCRIPT ERROR' "$log")
	done_line=$(grep -m1 '^\[autotest\] DONE' "$log")
	{ [ "$code" = 124 ] || [ "$code" = 137 ]; } && { echo "::error::autotest $name timed out after ${TIMEOUT}s"; ok=fail; }
	[ -z "$done_line" ] && { echo "::error::autotest $name never reached DONE (crash or hang, exit $code)"; ok=fail; }
	[ "$fails" -gt 0 ] && { echo "::error::autotest $name: $fails check(s) failed"; ok=fail; }
	[ "$errors" -gt 0 ] && { echo "::error::autotest $name: $errors SCRIPT ERROR(s) in the log"; ok=fail; }
	[ "$code" != 0 ] && [ "$ok" = ok ] && { echo "::error::autotest $name: Godot exited with code $code"; ok=fail; }
	[ "$ok" = ok ] || { status=fail; failed_logs+=("$log"); }
	rows+=("| $name | $([ "$ok" = ok ] && echo ✅ || echo ❌) | $passes | $fails | $errors | $code | $((SECONDS - start)) s |")
}

if [ -z "$ONLY" ] || [ "$ONLY" = full ]; then
	mode="full run"
	run_one full "$OUT" "$@"
else
	mode="only: $ONLY"
	for g in $ONLY; do
		run_one "$g" "$OUT/$g" --only="$g" "$@"
	done
fi

summary() {
	echo "### Autotest: $([ "$status" = ok ] && echo "✅ passed" || echo "❌ failed") ($mode)"
	echo
	echo "| run | result | PASS | FAIL | SCRIPT ERROR | exit | time |"
	echo "|---|---|---|---|---|---|---|"
	printf '%s\n' "${rows[@]}"
	for log in "${failed_logs[@]}"; do
		echo
		echo "\`${log#"$OUT"/}\`"
		echo '```'
		grep -E '^\[autotest\] FAIL|SCRIPT ERROR' -A2 "$log" | head -60
		echo '```'
	done
}
summary
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && summary >> "$GITHUB_STEP_SUMMARY"
[ "$status" = ok ]
