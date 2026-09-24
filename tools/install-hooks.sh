#!/usr/bin/env bash
# Point git at tools/githooks (repo-native hooks; no Python pre-commit package).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
git config core.hooksPath tools/githooks
echo "Installed: git core.hooksPath=tools/githooks"
echo "Hooks read tools/hooks.yaml via tools/run-hooks.sh"
