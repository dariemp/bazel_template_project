#!/usr/bin/env bash
# Fail if any Go file (tracked or untracked, excluding ignored paths) needs gofmt.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mapfile -t files < <(git ls-files -c -o --exclude-standard '*.go')
if ((${#files[@]} == 0)); then
  echo "check-gofmt: no Go files"
  exit 0
fi
bad="$(gofmt -l "${files[@]}")"
if [[ -n "${bad}" ]]; then
  echo "gofmt needed on:"
  echo "${bad}"
  exit 1
fi
echo "check-gofmt: ok (${#files[@]} files)"
