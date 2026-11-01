#!/usr/bin/env bash
# Builds one game (or all) into build/<game>.rbxl, stamped with the git commit.
#   tools/build.sh hatchery-heist
#   tools/build.sh all
set -euo pipefail
cd "$(dirname "$0")/.."

commit="${GITHUB_SHA:-$(git rev-parse --verify -q HEAD || echo dev)}"
commit="${commit:0:12}"

build_game() {
	local game="$1"
	local dir="games/$game"
	[[ -f "$dir/default.project.json" ]] || { echo "No such game: $game" >&2; exit 1; }
	local stamp="$dir/src/shared/Build.luau"
	local original
	original="$(cat "$stamp")"
	# Restore the stamp file however this script exits.
	trap 'printf "%s\n" "$original" > "$stamp"' RETURN
	printf -- '--!strict\n-- Written by tools/build.sh. Do not edit.\nreturn { commit = "%s" }\n' "$commit" > "$stamp"
	mkdir -p build
	rojo build "$dir" --output "build/$game.rbxl"
	echo "Built build/$game.rbxl at $commit"
}

if [[ "${1:-}" == "all" ]]; then
	for dir in games/*/; do
		build_game "$(basename "$dir")"
	done
elif [[ -n "${1:-}" ]]; then
	build_game "$1"
else
	echo "usage: tools/build.sh <game>|all" >&2
	exit 2
fi
