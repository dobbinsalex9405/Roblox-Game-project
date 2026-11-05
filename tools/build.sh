#!/usr/bin/env bash
# Builds one game (or all) into build/<game>.rbxl, stamped with the git commit.
#   tools/build.sh hatchery-heist
#   tools/build.sh all
#   BUILD_ENVIRONMENT=staging tools/build.sh hatchery-heist
#   BUILD_OUT=build/audit-places tools/build.sh all   # another output folder
set -euo pipefail
cd "$(dirname "$0")/.."

commit="${GITHUB_SHA:-$(git rev-parse --verify -q HEAD || echo dev)}"
commit="${commit:0:12}"
# Which experience this build is for: dev (default), staging or production.
# Picks the right game pass and product ids (packages/core/src/Monetization.luau).
environment="${BUILD_ENVIRONMENT:-dev}"
case "$environment" in
	dev | staging | production) ;;
	*) echo "BUILD_ENVIRONMENT must be dev, staging or production, not '$environment'" >&2; exit 2 ;;
esac
out="${BUILD_OUT:-build}"

# Runs in a subshell so the EXIT trap restores this game's stamp file however
# the build ends (success, failure or Ctrl-C), before the next game starts.
build_game() (
	local game="$1"
	local dir="games/$game"
	[[ -f "$dir/default.project.json" ]] || { echo "No such game: $game" >&2; exit 1; }
	local stamp="$dir/src/shared/Build.luau"
	local backup
	backup="$(mktemp)"
	cp "$stamp" "$backup"
	trap 'cp "$backup" "$stamp"; rm -f "$backup"' EXIT
	printf -- '--!strict\n-- Written by tools/build.sh. Do not edit.\nreturn { commit = "%s", environment = "%s" }\n' "$commit" "$environment" > "$stamp"
	mkdir -p "$out"
	rojo build "$dir" --output "$out/$game.rbxl"
	echo "Built $out/$game.rbxl at $commit for $environment"
)

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
