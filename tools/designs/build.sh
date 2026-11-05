#!/usr/bin/env bash
# Rebuilds the design viewer with every design in it.
#   tools/designs/build.sh                 # -> /mnt/project-files/design-viewer (cloud) or build/design-viewer
#   tools/designs/build.sh --skip-games    # reuse build/designs/game-models.json (only dropped designs changed)
#   DESIGNS_DIR=/path/to/designs DESIGN_VIEWER_OUT=/path/to/out tools/designs/build.sh
# See tools/designs/README.md.
set -euo pipefail
cd "$(dirname "$0")/../.."

drops="${DESIGNS_DIR:-/mnt/project-files/designs}"
if [[ -n "${DESIGN_VIEWER_OUT:-}" ]]; then
	out="$DESIGN_VIEWER_OUT"
elif [[ -d /mnt/project-files ]]; then
	out=/mnt/project-files/design-viewer
else
	out=build/design-viewer
fi

if [[ "${1:-}" != "--skip-games" ]]; then
	tools/build.sh all
	lune run tools/designs/export all
fi
node tools/designs/build.mjs --drops "$drops" --out "$out"
