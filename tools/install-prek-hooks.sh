#!/usr/bin/env bash
# Install the git pre-commit hook via the Bazel-pinned prek (//tools:prek).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Clear legacy core.hooksPath from the old tools/githooks setup if present.
if [[ "$(git config --get core.hooksPath || true)" == "tools/githooks" ]]; then
  git config --unset core.hooksPath
  echo "Cleared legacy core.hooksPath=tools/githooks"
fi

bazel run //tools:prek -- install
echo "Installed: prek git hook (config: .pre-commit-config.yaml)"
