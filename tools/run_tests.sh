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
# Output is streamed and kept in reports/test_output.log so script errors can be checked afterwards.
log=reports/test_output.log
rc=0
bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -rd res://reports -a "$target" 2>&1 | tee "$log" || rc=${PIPESTATUS[0]}

# GdUnit4 can pass while Godot prints script errors from project code: fail on those.
# Offending = SCRIPT ERROR:/ERROR: lines whose block (the line plus its indented "at:" line) mentions
# a res:// path outside res://addons/, minus tools/test_error_allowlist.txt regexes.
allow="tools/test_error_allowlist.txt"
patterns="$(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$allow" 2>/dev/null | tr -d '' || true)"
tr -d '' < "$log" | awk '
	/^(SCRIPT )?ERROR:/ { if (blk != "") print blk; blk = $0; next }
	/^[[:space:]]+at:/ && blk != "" { blk = blk " " $0; next }
	{ if (blk != "") print blk; blk = "" }
	END { if (blk != "") print blk }
' | grep -E 'res://' | grep -vE 'res://addons/' > reports/.project_errors.tmp || true
if [ -n "$patterns" ]; then
	grep -vEf <(printf '%s
' "$patterns") reports/.project_errors.tmp > reports/project_errors.log || true
else
	cp reports/.project_errors.tmp reports/project_errors.log
fi
rm -f reports/.project_errors.tmp
if [ -s reports/project_errors.log ]; then
	echo "FAIL: script errors from project code in test output:" >&2
	cat reports/project_errors.log >&2
	[ "$rc" -eq 0 ] && rc=1
fi
exit "$rc"
