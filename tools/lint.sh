#!/usr/bin/env bash
# Format check + lint for project GDScript (addons/ and hidden folders such as .godot/, .venv/ and
# .claude/ agent worktrees excluded).
# Usage: tools/lint.sh [--fix]   --fix reformats files in place before linting.
set -euo pipefail
cd "$(dirname "$0")/.."

# In a git worktree without its own .venv, use the main checkout's (never link it into the worktree:
# removing the worktree could delete the linked venv).
venv=.venv
if [ ! -d "$venv" ]; then
	common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
	[ -n "$common_dir" ] && [ -d "$(dirname "$common_dir")/.venv" ] && venv="$(dirname "$common_dir")/.venv"
fi
bin_dir=$venv/Scripts
[ -d "$bin_dir" ] || bin_dir=$venv/bin
if [ ! -x "$bin_dir/gdlint" ] && [ ! -x "$bin_dir/gdlint.exe" ]; then
	echo "gdtoolkit not found in .venv. Run: py -3.12 -m venv .venv && .venv/Scripts/pip install -r tools/requirements-dev.txt" >&2
	exit 1
fi

mapfile -t files < <(find . \( -path ./addons -o -path './.*' \) -prune -o -name '*.gd' -print | sort)
if [ ${#files[@]} -eq 0 ]; then
	echo "No GDScript files to lint."
	exit 0
fi

# Files go in batches: one command line with every path passes Windows' 32 K character limit.
batched() {
	printf '%s\0' "${files[@]}" | xargs -0 -n 300 "$@"
}

if [ "${1:-}" = "--fix" ]; then
	batched "$bin_dir/gdformat"
	# gdformat writes CRLF on Windows; the repo is LF-only.
	batched sed -i 's/\r$//'
fi
batched "$bin_dir/gdformat" --check
batched "$bin_dir/gdlint"
