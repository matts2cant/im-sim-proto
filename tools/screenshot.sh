#!/usr/bin/env bash
# Renders a scene in a real window for N frames and keeps only the final frame as a PNG.
# Usage: tools/screenshot.sh <res://path/scene.tscn> [frames=15] [out_png]
#   Default output: reports/screenshots/<scene_basename>.png
# Window size: $SHOT_SIZE=WxH (default 1152x648); forced via --resolution.
# Time limit: $SHOT_TIMEOUT seconds (default 60), enforced by tools/run_windowed.sh, which closes
# the window (plain `timeout` would leave it open on Windows).
# Godot binary: $GODOT_BIN, defaulting to the project's standard install path.
set -euo pipefail
cd "$(dirname "$0")/.."

export GODOT_BIN="${GODOT_BIN:-/c/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe}"

if [ $# -lt 1 ]; then
	echo "Usage: tools/screenshot.sh <res://path/scene.tscn> [frames=15] [out_png]" >&2
	exit 2
fi
scene="$1"
frames="${2:-15}"
base="$(basename "$scene" .tscn)"
out="${3:-reports/screenshots/$base.png}"

if [ ! -d .godot ]; then
	echo "No .godot/ import cache, importing project first..."
	"$GODOT_BIN" --headless --path . --import
fi

# Keep the editor's filesystem scan (and importer) out of the generated PNGs.
mkdir -p reports
touch reports/.gdignore

tmp="reports/screenshots/.tmp"
rm -rf "$tmp"
mkdir -p "$tmp"
mkdir -p "$(dirname "$out")"

# Time limit ($SHOT_TIMEOUT seconds, default 60): a scene that never quits has its window closed.
tools/run_windowed.sh "${SHOT_TIMEOUT:-60}" --path . --resolution "${SHOT_SIZE:-1152x648}" --write-movie "$tmp/frame.png" --fixed-fps 30 --quit-after "$frames" "$scene" || true

last="$(find "$tmp" -name 'frame*.png' | sort | tail -n 1)"
if [ -z "$last" ]; then
	rm -rf "$tmp"
	echo "No frames were produced for $scene" >&2
	exit 1
fi

mv -f "$last" "$out"
rm -rf "$tmp"
echo "$out"
