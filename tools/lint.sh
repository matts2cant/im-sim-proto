#!/usr/bin/env bash
# Format check + lint for project GDScript (addons/, .godot/ and .venv/ excluded).
# Usage: tools/lint.sh [--fix]   --fix reformats files in place before linting.
set -euo pipefail
cd "$(dirname "$0")/.."

bin_dir=.venv/Scripts
[ -d "$bin_dir" ] || bin_dir=.venv/bin
if [ ! -x "$bin_dir/gdlint" ] && [ ! -x "$bin_dir/gdlint.exe" ]; then
	echo "gdtoolkit not found in .venv. Run: py -3.12 -m venv .venv && .venv/Scripts/pip install -r tools/requirements-dev.txt" >&2
	exit 1
fi

mapfile -t files < <(find . \( -path ./addons -o -path ./.godot -o -path ./.venv -o -path ./.git \) -prune \
	-o -name '*.gd' -print | sort)
if [ ${#files[@]} -eq 0 ]; then
	echo "No GDScript files to lint."
	exit 0
fi

if [ "${1:-}" = "--fix" ]; then
	"$bin_dir/gdformat" "${files[@]}"
	# gdformat writes CRLF on Windows; the repo is LF-only.
	sed -i 's/\r$//' "${files[@]}"
fi
"$bin_dir/gdformat" --check "${files[@]}"
"$bin_dir/gdlint" "${files[@]}"
