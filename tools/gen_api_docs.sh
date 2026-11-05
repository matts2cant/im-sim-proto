#!/usr/bin/env bash
# Dumps the engine API reference (class XML) for the local Godot version into .api-docs/.
# Usage: tools/gen_api_docs.sh
# Godot binary: $GODOT_BIN, defaulting to the project's standard install path.
set -euo pipefail
cd "$(dirname "$0")/.."

export GODOT_BIN="${GODOT_BIN:-/c/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe}"

rm -rf .api-docs
mkdir -p .api-docs
# Keep the editor's filesystem scan (and importer) out of the dumped XML.
touch .api-docs/.gdignore

# --doctool writes doc/, modules/, platform/ into the current directory.
(cd .api-docs && "$GODOT_BIN" --headless --doctool .)

count=$(find .api-docs -name '*.xml' | wc -l)
if [ "$count" -eq 0 ]; then
	echo "No class XML files were produced in .api-docs/" >&2
	exit 1
fi
echo "Wrote $count class XML files to .api-docs/"
