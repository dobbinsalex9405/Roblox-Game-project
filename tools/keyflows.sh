#!/usr/bin/env bash
# Key-flow check: plays each game's main loop headless (playtests/<game>/checks.luau)
# and fails if any check reports a bug. Every game must have one.
#   tools/keyflows.sh depthbound
#   tools/keyflows.sh all
set -euo pipefail
cd "$(dirname "$0")/.."

run_game() {
	local game="$1"
	local script="playtests/$game/checks.luau"
	if [[ ! -f "$script" ]]; then
		echo "No key-flow checks for $game: add $script (see playtests/README.md)" >&2
		return 1
	fi
	echo "== $game key flows"
	lune run "$script"
}

status=0
if [[ "${1:-all}" == "all" ]]; then
	for dir in games/*/; do
		run_game "$(basename "$dir")" || status=1
	done
else
	run_game "$1" || status=1
fi
exit $status
