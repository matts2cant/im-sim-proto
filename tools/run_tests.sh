#!/usr/bin/env bash
# Runs the GdUnit4 suite headless; reports go to reports/.
# Usage: tools/run_tests.sh [res://path]   (default: res://tests)
# Godot binary: $GODOT_BIN, defaulting to the project's standard install path.
set -euo pipefail
cd "$(dirname "$0")/.."

export GODOT_BIN="${GODOT_BIN:-/c/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe}"
target="${1:-res://tests}"

# Keep the editor's filesystem scan (and importer) out of the generated HTML reports.
mkdir -p reports
touch reports/.gdignore

# Always import: a stale global class cache (new class_names after a merge) makes tests
# fail with "Could not find base class" and segfault Godot.
if ! "$GODOT_BIN" --headless --path . --import > reports/import.log 2>&1; then
	echo "Godot import failed; last 20 lines of reports/import.log:" >&2
	tail -n 20 reports/import.log >&2
	exit 1
fi

# -c: run all tests instead of stopping at the first failure.
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -rd res://reports -a "$target"
