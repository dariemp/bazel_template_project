#!/usr/bin/env bash
# Run hooks declared in tools/hooks.yaml (simple YAML subset).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
config="${HOOKS_CONFIG:-$root/tools/hooks.yaml}"

if [[ ! -f "$config" ]]; then
  echo "hooks config not found: $config" >&2
  exit 1
fi

# Parse a constrained YAML list of hooks with id/name/command fields via Python
# (stdlib only — no PyYAML). Supports the schema in tools/hooks.yaml.
eval "$(python3 - "$config" <<'PY'
import re, shlex, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
# Strip comments
lines = []
for line in text.splitlines():
    if re.match(r"^\s*#", line):
        continue
    lines.append(line)
text = "\n".join(lines)

hooks = []
current = None
for line in text.splitlines():
    if re.match(r"^\s*-\s+id:\s*", line):
        if current:
            hooks.append(current)
        current = {"id": re.sub(r"^\s*-\s+id:\s*", "", line).strip().strip("\"'")}
    elif current is None:
        continue
    elif m := re.match(r"^\s*name:\s*(.*)$", line):
        current["name"] = m.group(1).strip().strip("\"'")
    elif m := re.match(r"^\s*command:\s*(.*)$", line):
        current["command"] = m.group(1).strip().strip("\"'")
if current:
    hooks.append(current)

print(f"HOOK_COUNT={len(hooks)}")
for i, h in enumerate(hooks):
    for k in ("id", "name", "command"):
        if k not in h or not h[k]:
            raise SystemExit(f"hook #{i} missing {k}")
    print(f"HOOK_{i}_ID={shlex.quote(h['id'])}")
    print(f"HOOK_{i}_NAME={shlex.quote(h['name'])}")
    print(f"HOOK_{i}_COMMAND={shlex.quote(h['command'])}")
PY
)"

failed=0
for ((i=0; i<HOOK_COUNT; i++)); do
  id_var="HOOK_${i}_ID"
  name_var="HOOK_${i}_NAME"
  cmd_var="HOOK_${i}_COMMAND"
  id="${!id_var}"
  name="${!name_var}"
  cmd="${!cmd_var}"
  echo "==> [$id] $name"
  echo "    $ $cmd"
  if bash -lc "$cmd"; then
    echo "    ok"
  else
    echo "    FAILED" >&2
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "hooks: one or more checks failed" >&2
  exit 1
fi
echo "hooks: all ${HOOK_COUNT} checks passed"
