#!/usr/bin/env bash
# Static ratchet: optional root gate scripts must be probed before execution.
#
# The fork (agents-playground #70, row 5a) guards every direct call to a gate
# script under ${SCHOLAR_SKILL_DIR:-.}/scripts/gates/ so that a missing file is
# a silent no-op with a success exit (the research proceeds on prose alone),
# while behaviour stays byte-identical when the files are present. Three forms
# are accepted, all upstream idioms:
#
#   1. [ -f "$G/emit-trace.sh" ] && bash "$G/emit-trace.sh" ... || true
#   2. if [ -f "$G/pre-exec-review-check.sh" ]; then bash "$G/..." ... || exit; fi
#      (fail-closed gates keep their halt-on-RED when present)
#   3. . "$G/derive-proj.sh" 2>/dev/null || true   (sourcing; upstream's idiom)
#
# A bare invocation (no probe) regresses to exit 127 against a missing file and
# is the defect this ratchet exists to catch.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

python3 - "$REPO_ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
gate_path = r'"\$\{SCHOLAR_SKILL_DIR:-\.\}/scripts/gates/[^" ]+"'
call_pattern = re.compile(rf'(?P<verb>bash|\.) (?P<path>{gate_path})')
probe_pattern = re.compile(rf'\[ -f (?P<path>{gate_path}) \]')
failures = []
calls = 0

lines_by_file = {}
for path in sorted((root / ".claude").rglob("*.md")):
    lines_by_file[path] = path.read_text().splitlines()

for path, lines in lines_by_file.items():
    for index, line in enumerate(lines):
        match = call_pattern.search(line)
        if not match:
            continue
        # a commented-out example is documentation, not a call site
        if "#" in line[: match.start()]:
            continue
        calls += 1
        verb = match.group("verb")
        gate = match.group("path")
        before = line[: match.start()]
        rel = path.relative_to(root)

        # source calls: upstream's own guarded idiom
        if verb == ".":
            if "2>/dev/null ||" in line:
                continue
            failures.append(f"{rel}:{index + 1}: unguarded source call")
            continue

        # form 1: `[ -f <gate> ] && bash <gate> ... || true`
        if f"[ -f {gate} ] && " in before:
            command = line[match.end():]
            cursor = index
            while command.rstrip().endswith("\\") and cursor + 1 < len(lines):
                cursor += 1
                command += "\n" + lines[cursor]
            if "|| true" in command:
                continue
            failures.append(f"{rel}:{index + 1}: probe without trailing true")
            continue

        # form 2: the call sits under `if [ -f <gate> ]; then ... fi`
        prev = lines[index - 1] if index > 0 else ""
        if f"if [ -f {gate} ]; then" in prev:
            tail = "\n".join(lines[index: index + 8])
            if re.search(r"^\s*fi\b", tail, re.M):
                continue
            failures.append(f"{rel}:{index + 1}: if-guard without closing fi")
            continue

        failures.append(f"{rel}:{index + 1}: unguarded gate call (probe on the same path is required)")

if failures:
    print("Unguarded or mis-guarded gate calls:")
    print("\n".join(f"  {failure}" for failure in failures))
    raise SystemExit(1)

print(f"All {calls} direct root gate calls are guarded")
PY
