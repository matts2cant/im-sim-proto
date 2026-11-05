#!/usr/bin/env bash
# Runs the GdUnit4 suite headless; reports go to reports/.
# Usage: tools/run_tests.sh [res://path]   (default: res://tests)
# Godot binary: $GODOT_BIN, defaulting to the project's standard install path.
set -euo pipefail
cd "$(dirname "$0")/.."

export GODOT_BIN="${GODOT_BIN:-/c/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe}"
target="${1:-res://tests}"

if [ ! -d .godot ]; then
	echo "No .godot/ import cache, importing project first..."
	"$GODOT_BIN" --headless --path . --import
fi

# Keep the editor's filesystem scan (and importer) out of the generated HTML reports.
mkdir -p reports
touch reports/.gdignore

# -c: run all tests instead of stopping at the first failure.
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -rd res://reports -a "$target"
