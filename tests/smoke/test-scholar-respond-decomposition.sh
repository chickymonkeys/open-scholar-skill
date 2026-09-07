#!/usr/bin/env bash
# Smoke test: the progressive-disclosure decomposition preserves every mode's
# procedure. Each mode's distinctive markers must survive in its own on-demand
# reference (the same paper produces an equivalent report), while the shared schema
# stays in the always-loaded SKILL.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/scholar-respond"
SKILL="$SKILL_DIR/SKILL.md"

PASS=0
FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS + 1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== scholar-respond decomposition completeness checks ==="

# mode reference -> distinctive markers that must survive in that reference
declare -A MODE_MARKERS=(
  [mode-1-simulate.md]="Desk-Reject Risk Assessment|SEVERITY × CONFIDENCE MATRIX|Always spawn these three|Reviewer Personality Calibration"
  [mode-2-respond.md]="RESPONSE TRIAGE DASHBOARD|Round-specific calibration|RESPONSE TO REVIEWERS|Apply Response Tone Guidelines|Evidence Ledger"
  [mode-3-revise.md]="REVISION PLAN|New-Analysis Gate|Verification Gate|REVISION SUMMARY|Consistency Check"
  [mode-4-resubmit.md]="Triage the Rejection Decision|Diagnose Root Cause|journal ladder|Lessons Learned"
  [mode-5-cover-letter.md]="R&R COVER LETTER|R1 Cover Letter|R2 Cover Letter"
)

for ref in "${!MODE_MARKERS[@]}"; do
  file="$SKILL_DIR/references/$ref"
  if [ ! -f "$file" ]; then
    no "missing mode reference: $ref"
    continue
  fi
  IFS='|' read -ra markers <<< "${MODE_MARKERS[$ref]}"
  for marker in "${markers[@]}"; do
    if grep -Fq "$marker" "$file"; then
      ok "$ref carries: $marker"
    else
      no "$ref lost: $marker"
    fi
  done
done

# shared schema must stay in the always-loaded file
SCHEMA_MARKERS=(
  'Evidence and Severity Schema'
  'CRITICAL (paper cannot be published without fix)'
  'HIGH (raised by 2+ reviewers or factually correct)'
)
for marker in "${SCHEMA_MARKERS[@]}"; do
  if grep -Fq "$marker" "$SKILL"; then
    ok "always-loaded schema carries: $marker"
  else
    no "always-loaded SKILL.md lost: $marker"
  fi
done

# companion references still ship (loaded on demand by the mode references)
for companion in common-concerns response-templates; do
  if [ -f "$SKILL_DIR/references/$companion.md" ]; then
    ok "companion reference ships: $companion.md"
  else
    no "companion reference missing: $companion.md"
  fi
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
