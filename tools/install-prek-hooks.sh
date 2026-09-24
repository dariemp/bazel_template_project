#!/usr/bin/env bash
# Install the git pre-commit hook via prek (reads .pre-commit-config.yaml).
# Requires prek on PATH. Install prek first, e.g.:
#   curl --proto '=https' --tlsv1.2 -LsSf \
#     https://github.com/j178/prek/releases/download/v0.5.3/prek-installer.sh | sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if ! command -v prek >/dev/null 2>&1; then
  echo "prek not found on PATH. Install v0.5.3 (or newer) first:" >&2
  echo "  curl --proto '=https' --tlsv1.2 -LsSf \\" >&2
  echo "    https://github.com/j178/prek/releases/download/v0.5.3/prek-installer.sh | sh" >&2
  exit 1
fi

# Clear legacy core.hooksPath from the old tools/githooks setup if present.
if [[ "$(git config --get core.hooksPath || true)" == "tools/githooks" ]]; then
  git config --unset core.hooksPath
  echo "Cleared legacy core.hooksPath=tools/githooks"
fi

prek install
echo "Installed: prek git hook (config: .pre-commit-config.yaml)"
