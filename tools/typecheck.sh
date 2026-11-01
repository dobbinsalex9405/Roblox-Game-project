#!/usr/bin/env bash
# Strict type check of all Roblox-side code with luau-lsp, using Roblox's API
# types and each game's Rojo sourcemap so instance requires resolve.
# Lune-only test files are checked by running them, not here.
set -euo pipefail
cd "$(dirname "$0")/.."

LUAU_LSP_TAG="1.70.1" # keep in step with rokit.toml
defs="globalTypes.d.luau"
if [[ ! -f "$defs" ]]; then
	curl -fsSL -o "$defs" "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$LUAU_LSP_TAG/scripts/globalTypes.d.luau"
fi

status=0
for dir in games/*/; do
	game="$(basename "$dir")"
	echo "Type checking $game"
	rojo sourcemap "$dir" --output sourcemap.json
	luau-lsp analyze \
		--definitions="$defs" \
		--sourcemap=sourcemap.json \
		--base-luaurc=.luaurc \
		--ignore="**/tests/**" \
		--ignore="**/ServerPackages/**" \
		--ignore="**/Packages/**" \
		packages/core/src packages/core/server packages/core/client "$dir/src" "$dir/config" || status=1
done
exit $status
