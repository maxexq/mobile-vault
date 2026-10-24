#!/usr/bin/env bash
# Runs the full autotest the way CI does and fails on any FAIL check, script error, crash or hang
# (MV-110). Used by .github/workflows/autotest.yml; works the same in a Linux cloud session.
#   GODOT=godot OUT=/abs/dir TIMEOUT=1200 bash tools/ci_autotest.sh [--only=touch]
# Needs xvfb-run: --headless hangs on frame_post_draw (screenshots), so a virtual X display is used.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
OUT=${OUT:-$PWD/build/autotest}
TIMEOUT=${TIMEOUT:-1200}
LOG="$OUT/autotest.log"
mkdir -p "$OUT"

# first run on a fresh checkout: import assets so res:// textures exist
[ -d .godot/imported ] || "$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1

timeout --kill-after=30 "$TIMEOUT" xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
	--audio-driver Dummy -- --autotest --out="$OUT" "$@" 2>&1 | tee "$LOG"
code=${PIPESTATUS[0]}

passes=$(grep -c '^\[autotest\] PASS' "$LOG")
fails=$(grep -c '^\[autotest\] FAIL' "$LOG")
errors=$(grep -c 'SCRIPT ERROR' "$LOG")
done_line=$(grep -m1 '^\[autotest\] DONE' "$LOG")

status=ok
[ "$code" = 124 ] || [ "$code" = 137 ] && { echo "::error::autotest timed out after ${TIMEOUT}s"; status=fail; }
[ -z "$done_line" ] && { echo "::error::autotest never reached DONE (crash or hang, exit $code)"; status=fail; }
[ "$fails" -gt 0 ] && { echo "::error::$fails autotest check(s) failed"; status=fail; }
[ "$errors" -gt 0 ] && { echo "::error::$errors SCRIPT ERROR(s) in the log"; status=fail; }
[ "$code" != 0 ] && [ "$status" = ok ] && { echo "::error::Godot exited with code $code"; status=fail; }

summary() {
	echo "### Autotest: $([ "$status" = ok ] && echo "✅ passed" || echo "❌ failed")"
	echo
	echo "| PASS | FAIL | SCRIPT ERROR | exit |"
	echo "|---|---|---|---|"
	echo "| $passes | $fails | $errors | $code |"
	if [ "$fails" -gt 0 ] || [ "$errors" -gt 0 ]; then
		echo
		echo '```'
		grep -E '^\[autotest\] FAIL|SCRIPT ERROR' -A2 "$LOG" | head -60
		echo '```'
	fi
}
summary
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && summary >> "$GITHUB_STEP_SUMMARY"
[ "$status" = ok ]
