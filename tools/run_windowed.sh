#!/usr/bin/env bash
# Runs Godot (normally a windowed run: screenshots, review shots) with a time limit that really
# closes the window. Plain `timeout` only kills the `_console.exe` wrapper on Windows: the Godot
# window it started stays open. When the limit expires this kills the whole process tree
# (taskkill /T) and exits with 124, like `timeout`.
# Usage: tools/run_windowed.sh <seconds> <godot args...>
#   e.g. tools/run_windowed.sh 60 --path . res://tests/ui/lockpick/fixtures/lockpick_shots.tscn -- shot=master
# Godot binary: $GODOT_BIN, defaulting to the project's standard install path.
set -uo pipefail

export GODOT_BIN="${GODOT_BIN:-/c/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe}"

if [ $# -lt 2 ]; then
	echo "Usage: tools/run_windowed.sh <seconds> <godot args...>" >&2
	exit 2
fi
limit="$1"
shift

"$GODOT_BIN" "$@" &
pid=$!
winpid="$(cat "/proc/$pid/winpid" 2>/dev/null || true)"
flag="$(mktemp)"
rm -f "$flag"

(
	sleep "$limit"
	if kill -0 "$pid" 2>/dev/null; then
		touch "$flag"
		echo "run_windowed: no exit after ${limit} s, closing Godot (PID $pid, Windows PID ${winpid:-?})" >&2
		if [ -n "$winpid" ]; then
			taskkill //PID "$winpid" //T //F >/dev/null 2>&1 || true
		fi
		kill -9 "$pid" 2>/dev/null || true
	fi
) &
watch=$!

wait "$pid"
status=$?
kill "$watch" 2>/dev/null || true
wait "$watch" 2>/dev/null || true
if [ -e "$flag" ]; then
	rm -f "$flag"
	exit 124
fi
exit "$status"
