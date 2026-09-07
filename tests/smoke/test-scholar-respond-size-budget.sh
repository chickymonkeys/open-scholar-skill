#!/usr/bin/env bash
# Smoke test: the decomposition keeps scholar-respond inside the documented size
# ceiling, with mode- and dimension-specific material OUT of the always-loaded
# file. The 500-line ceiling is the documented skill-authoring budget; it is
# enforced here because the gate scripts never check skill size, and skill stubs
# were measured regrowing 14-69% as a result.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/scholar-respond"
SKILL="$SKILL_DIR/SKILL.md"

PASS=0
FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS + 1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== scholar-respond size-budget + always-loaded-shape checks ==="

# --- 1. the documented 500-line ceiling on the always-loaded file ---
lines=$(wc -l < "$SKILL" | tr -d ' ')
if [ "$lines" -le 500 ]; then
  ok "SKILL.md within the documented 500-line ceiling ($lines lines)"
else
  no "SKILL.md over the documented 500-line ceiling ($lines > 500)"
fi

# --- 2. always-loaded share of the component bytes stays far below the 50.9%
#        measured before the decomposition (49.4% before the persona work).
#        Component = SKILL.md + every references/*.md;
#        always-loaded = SKILL.md alone. Threshold 25%: generous headroom over
#        the 10.3% measured after the row, far under the measured before, so a
#        stub can regrow without silently re-monolithising.
component=0
for f in "$SKILL_DIR"/SKILL.md "$SKILL_DIR"/references/*.md; do
  [ -f "$f" ] || continue
  component=$((component + $(wc -c < "$f" | tr -d ' ')))
done
always_loaded=$(wc -c < "$SKILL" | tr -d ' ')
share=$((always_loaded * 100 / component))
if [ "$share" -le 25 ]; then
  ok "always-loaded share ${share}% of ${component} B (SKILL.md ${always_loaded} B)"
else
  no "always-loaded share ${share}% exceeds the 25% ceiling (SKILL.md ${always_loaded} B of ${component} B)"
fi

# --- 3. mode-specific sections live in the references, not the always-loaded file
#        (the always-loaded file carries only the common protocol, the evidence and
#        severity schema, and the routing logic) ---
MODE_MARKERS=(
  '## MODE 1: SIMULATE PEER REVIEW'
  '## MODE 2: DRAFT RESPONSE LETTER'
  '## MODE 3: REVISE THE MANUSCRIPT'
  '## MODE 4: RESUBMISSION STRATEGY'
  '## MODE 5: R&R COVER LETTER'
)
for marker in "${MODE_MARKERS[@]}"; do
  if grep -Fq "$marker" "$SKILL"; then
    no "mode-specific section still in always-loaded SKILL.md: $marker"
  else
    ok "mode-specific section absent from SKILL.md: $marker"
  fi
done

# --- 4. the router names every on-demand mode reference ---
for ref in mode-1-simulate mode-2-respond mode-3-revise mode-4-resubmit mode-5-cover-letter; do
  if [ -f "$SKILL_DIR/references/$ref.md" ]; then
    ok "on-demand reference present: $ref.md"
  else
    no "missing on-demand reference: $ref.md"
  fi
  if grep -Fq "references/$ref.md" "$SKILL"; then
    ok "router names $ref.md in SKILL.md"
  else
    no "router does not name $ref.md in SKILL.md"
  fi
done

# --- 5. the 0a load block routes mechanically (case maps every mode keyword to
#        its reference), so a verbatim run loads the right file, not mode 1 ---
if grep -Fq 'case "${MODE:-simulate}"' "$SKILL" \
   && grep -Fq 'respond)      REF="mode-2-respond.md"' "$SKILL" \
   && grep -Fq 'revise)       REF="mode-3-revise.md"' "$SKILL" \
   && grep -Fq 'resubmit)     REF="mode-4-resubmit.md"' "$SKILL" \
   && grep -Fq 'cover-letter) REF="mode-5-cover-letter.md"' "$SKILL" \
   && grep -Fq '*)            REF="mode-1-simulate.md"' "$SKILL"; then
  ok "0a load block routes every mode keyword to its reference"
else
  no "0a load block does not map every mode keyword to its reference"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
