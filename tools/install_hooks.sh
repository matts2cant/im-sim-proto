#!/usr/bin/env bash
# Points git at the versioned hooks in tools/hooks.
set -euo pipefail
cd "$(dirname "$0")/.."
git config core.hooksPath tools/hooks
echo "core.hooksPath -> tools/hooks"
