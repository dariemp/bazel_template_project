#!/usr/bin/env bash
# Run hooks declared in tools/hooks.yaml (simple YAML subset with sections).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
config="${HOOKS_CONFIG:-$root/tools/hooks.yaml}"

if [[ ! -f "$config" ]]; then
  echo "hooks config not found: $config" >&2
  exit 1
fi

# Parse a constrained YAML of sections → hook lists (id/name/command) via Python
# (stdlib only — no PyYAML). Supports the schema in tools/hooks.yaml.
# Preferred section order: format_lint → tests → build_checks; then any others
# in file order. Legacy top-level `hooks:` is treated as an unnamed section.
eval "$(python3 - "$config" <<'PY'
import re, shlex, sys
path = sys.argv[1]
raw = open(path, encoding="utf-8").read()
lines = []
for line in raw.splitlines():
    if re.match(r"^\s*#", line):
        continue
    lines.append(line)

PREFERRED = ["format_lint", "tests", "build_checks", "hooks"]
sections = {}       # name -> list of hook dicts
section_order = []  # discovery order
current_section = None
current = None

def flush_hook():
    global current
    if current is not None:
        if current_section is None:
            raise SystemExit("hook found outside a section")
        sections[current_section].append(current)
        current = None

for line in lines:
    if not line.strip():
        continue
    # Top-level section key: "name:" at column 0
    m_sec = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*$", line)
    if m_sec:
        flush_hook()
        current_section = m_sec.group(1)
        if current_section not in sections:
            sections[current_section] = []
            section_order.append(current_section)
        continue
    if re.match(r"^\s*-\s+id:\s*", line):
        flush_hook()
        current = {"id": re.sub(r"^\s*-\s+id:\s*", "", line).strip().strip("\"'")}
        continue
    if current is None:
        continue
    if m := re.match(r"^\s*name:\s*(.*)$", line):
        current["name"] = m.group(1).strip().strip("\"'")
    elif m := re.match(r"^\s*command:\s*(.*)$", line):
        current["command"] = m.group(1).strip().strip("\"'")
flush_hook()

# Stable run order: preferred first (if present), then remaining in file order.
ordered = []
seen = set()
for name in PREFERRED:
    if name in sections and name not in seen:
        ordered.append(name)
        seen.add(name)
for name in section_order:
    if name not in seen:
        ordered.append(name)
        seen.add(name)

flat = []
for sec in ordered:
    for h in sections[sec]:
        flat.append((sec, h))

print(f"HOOK_COUNT={len(flat)}")
print(f"SECTION_COUNT={len(ordered)}")
for i, sec in enumerate(ordered):
    print(f"SECTION_{i}_NAME={shlex.quote(sec)}")
    print(f"SECTION_{i}_START={sum(1 for s,_ in flat if ordered.index(s) < i)}")
    print(f"SECTION_{i}_LEN={len(sections[sec])}")

for i, (sec, h) in enumerate(flat):
    for k in ("id", "name", "command"):
        if k not in h or not h[k]:
            raise SystemExit(f"hook #{i} in section {sec!r} missing {k}")
    print(f"HOOK_{i}_SECTION={shlex.quote(sec)}")
    print(f"HOOK_{i}_ID={shlex.quote(h['id'])}")
    print(f"HOOK_{i}_NAME={shlex.quote(h['name'])}")
    print(f"HOOK_{i}_COMMAND={shlex.quote(h['command'])}")
PY
)"

failed=0
prev_section=""
for ((i=0; i<HOOK_COUNT; i++)); do
  sec_var="HOOK_${i}_SECTION"
  id_var="HOOK_${i}_ID"
  name_var="HOOK_${i}_NAME"
  cmd_var="HOOK_${i}_COMMAND"
  sec="${!sec_var}"
  id="${!id_var}"
  name="${!name_var}"
  cmd="${!cmd_var}"
  if [[ "$sec" != "$prev_section" ]]; then
    echo ""
    echo "======== section: $sec ========"
    prev_section="$sec"
  fi
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
echo ""
echo "hooks: all ${HOOK_COUNT} checks passed"
