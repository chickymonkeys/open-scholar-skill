#!/usr/bin/env bash
# test-posttooluse-redactor.sh — validates scripts/gates/posttooluse-output-guard.sh
# (Strict-tier Bash STDOUT redactor) without invoking any host API. Asserts that
# at safety level strict the redactor REPLACES PII / bulk-row Bash stdout with a
# redaction notice (hookSpecificOutput.updatedToolOutput), and is a no-op at
# standard level and for a non-Bash tool.
#
# Note: this verifies the redactor SCRIPT. Whether the live PostToolUse hook
# actually invokes it in a strict session is separate and needs a Claude Code
# restart (hook config is snapshotted at session start).
set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
export SCHOLAR_SKILL_DIR="$ROOT"
RED="$ROOT/scripts/gates/posttooluse-output-guard.sh"

PASS=0; FAIL=0
pass(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
fail(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }
[ -f "$RED" ] || { echo "FAIL: redactor not found at $RED"; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# a project at $2 safety level, holding restricted data (a LOCAL_MODE entry)
mkproj(){ local p="$1" lvl="$2"; mkdir -p "$p/.claude"
  jq -n --arg l "$lvl" '{"data/raw/x.dta":"LOCAL_MODE","_safety_level":$l}' \
    > "$p/.claude/safety-status.json"; }

# a PostToolUse payload for a $2 tool whose stdout carries PII rows
payload(){ local cwd="$1" tool="${2:-Bash}"
  jq -n --arg c "$cwd" --arg t "$tool" '{
    tool_name:$t, tool_input:{command:"run_analysis"},
    tool_response:{
      stdout:"id,name,ssn,email\n1,Alice Ng,123-45-6789,alice@example.com\n2,Bob Lee,987-65-4321,bob@example.com\n",
      stderr:"", interrupted:false, isImage:false, noOutputExpected:false},
    cwd:$c}'; }

echo "=== posttooluse-output-guard redactor smoke tests ==="

# T1: strict + Bash + PII -> redacts (stdout replaced with notice, SSN gone)
PS="$WORK/strict"; mkproj "$PS" strict
OUT="$(payload "$PS" | bash "$RED" 2>/dev/null)"
if printf '%s' "$OUT" | jq -e '.hookSpecificOutput.updatedToolOutput.stdout | test("SAFETY GUARD")' >/dev/null 2>&1 \
   && ! printf '%s' "$OUT" | grep -q '123-45-6789'; then
  pass "T1 — strict: PII stdout replaced with redaction notice, raw rows gone"
else
  fail "T1 — strict redaction missing or leaked: $(printf '%s' "$OUT" | head -c 200)"
fi

# T2: standard -> no-op (empty output)
PD="$WORK/standard"; mkproj "$PD" standard
OUT="$(payload "$PD" | bash "$RED" 2>/dev/null)"
[ -z "$OUT" ] && pass "T2 — standard: no-op (empty)" \
  || fail "T2 — standard should be a no-op, got: $(printf '%s' "$OUT" | head -c 120)"

# T3: non-Bash tool at strict -> no-op (only Bash stdout is in scope)
OUT="$(payload "$PS" Read | bash "$RED" 2>/dev/null)"
[ -z "$OUT" ] && pass "T3 — non-Bash tool: no-op" \
  || fail "T3 — non-Bash tool should be a no-op"

echo
echo "  ---- $PASS passed, $FAIL failed ----"
[ "$FAIL" -eq 0 ]
