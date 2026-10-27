#!/usr/bin/env bash
# Does a change need the Godot autotest? (MV-173, MV-549) Reads changed paths, one per line, on stdin
# and prints "true" or "false". Used by .github/workflows/autotest.yml; try it by hand with
#   git diff --name-only origin/staging... | bash tools/ci_scope.sh
# Everything counts as the game unless it is on the list below, so a new folder gets the full run
# until someone adds it here. The autotest reads a few files inside the skipped folders (web shell,
# boot sprites, release tool): those come first and stay game. No paths at all also means "true".
godot=false
seen=0
while IFS= read -r f; do
	[ -n "$f" ] || continue
	seen=1
	case "$f" in
		CHANGELOG.md|tools/release.py|tools/web_shell.html|web/boot/*|web/logo.png|web/og-image.png|\
		.github/workflows/autotest.yml|.github/workflows/release.yml|tools/ci_autotest.sh|tools/ci_scope.sh)
			godot=true ;;
		# docs (MV-173)
		*.md|docs/*|.claude/*|.agents/*) ;;
		# server side and hosting: checked by the fast steps (GA proxy, error spike, engine wasm)
		api/*|functions/*|supabase/*|ai/*|vercel.json|.github/*) ;;
		# the web export: the autotest runs the project, not web/index.pck
		web/*) ;;
		# Python / Node tooling and the art generators (their output lands in assets/, which is game)
		tools/*.py|tools/*.mjs|tools/tests/*|tools/stamp_build.sh|tools/test_error_spike.sh) ;;
		*) godot=true ;;
	esac
done
[ "$seen" = 1 ] || godot=true
echo "$godot"
