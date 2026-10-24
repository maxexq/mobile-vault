#!/usr/bin/env sh
# Writes res://build_info.json (git commit, branch, UTC build time) so Settings > About can show
# which build is running, and web/version.json (committed with the export, MV-188). Run right before a web
# export; build_info.json is git-ignored.
cd "$(dirname "$0")/.." || exit 1
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo dev)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
DIRTY=false
[ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ] && DIRTY=true
BUILT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"commit": "%s", "branch": "%s", "built": "%s", "dirty": %s}\n' "$COMMIT" "$BRANCH" "$BUILT" "$DIRTY" > build_info.json
cat build_info.json
# MV-188: the live build's stamp for players already in the game (Announce polls it -> "new version" strip)
VERSION=$(sed -n 's/^const GAME_VERSION := "\(.*\)"/\1/p' scripts/build_info.gd)
mkdir -p web
printf '{"version": "%s", "commit": "%s", "built": "%s"}\n' "$VERSION" "$COMMIT" "$BUILT" > web/version.json
cat web/version.json
