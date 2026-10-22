#!/usr/bin/env sh
# Writes res://build_info.json (git commit, branch, UTC build time) so Settings > About can show
# which build is running. Run right before a web export; the file is git-ignored.
cd "$(dirname "$0")/.." || exit 1
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo dev)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
DIRTY=false
[ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ] && DIRTY=true
BUILT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"commit": "%s", "branch": "%s", "built": "%s", "dirty": %s}\n' "$COMMIT" "$BRANCH" "$BUILT" "$DIRTY" > build_info.json
cat build_info.json
