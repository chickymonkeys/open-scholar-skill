#!/usr/bin/env bash
# test-defect-class-registry.sh — the cross-project defect-class registry must exist, carry its
# classes, and be reachable from the briefs and skills that are supposed to sweep for them.
#
# A registry nobody loads is a document, not a control. These assertions are cheap and they pin
# the wiring, which is the half that rots.
#
# Also pins the two scholar-auto-improve corrections shipped alongside it:
#   - the dead "Phase 14" integration hook (scholar-full-paper ends at terminal Phase 12)
#   - IMPROVE Step 3a could not ingest a hand-authored run ledger, which for the 2026-08 run
#     was the richest defect source and was addressed to this skill by name

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SK="${REPO_ROOT}/.claude/skills"
AG="${REPO_ROOT}/.claude/agents"
REG="${SK}/_shared/defect-class-registry.md"
AI="${SK}/scholar-auto-improve/SKILL.md"
FP="${SK}/scholar-full-paper/SKILL.md"
PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== defect-class registry + auto-improve ingestion ==="
echo ""

# ---- registry exists and carries its classes -------------------------------------
[ -f "$REG" ] && pass "_shared/defect-class-registry.md exists" || { echo "  FAIL: $REG missing"; exit 1; }
for dc in DC-01 DC-02 DC-03 DC-04 DC-05 DC-06 DC-07; do
  grep -q "^## ${dc} " "$REG" && pass "registry carries ${dc}" || fail "registry missing class ${dc}"
done

# the countable trigger is the part a reviewer can apply without domain knowledge
grep -q "Count the branches that write a column" "$REG" \
  && pass "DC-01 carries the countable trigger (branches vs distinct values)" \
  || fail "DC-01 has no countable trigger — the natural-language rule alone is not a check"

# a remedy with an unstated constraint becomes the next entry
grep -q "written by the deciding branch" "$REG" && grep -q "no default" "$REG" \
  && pass "DC-01 states both companion constraints (deciding branch, no default)" \
  || fail "DC-01 remedy is stated without its constraints"
grep -qi "stated limit" "$REG" \
  && pass "DC-01 states where the rule cannot reach" \
  || fail "DC-01 has no stated limit — a rule presented as total will be over-trusted"

# ---- every review-code-* brief sweeps for the class ------------------------------
MISSING=0
for f in "$AG"/review-code-*.md; do
  grep -q "defect-class-registry.md" "$f" || { echo "       $(basename "$f") does not reference the registry"; MISSING=$((MISSING+1)); }
  grep -q "Three-Valued Logic Collapse" "$f" || { echo "       $(basename "$f") lacks the DC-01 standing sweep"; MISSING=$((MISSING+1)); }
done
[ "$MISSING" -eq 0 ] \
  && pass "all six review-code-* briefs carry the DC-01 sweep and cite the registry" \
  || fail "$MISSING gap(s) between the registry and the briefs that should sweep for it"

# ---- the two agents that must emit FIRES ON / SLIPS PAST -------------------------
for a in robustness correctness; do
  grep -q "SLIPS PAST" "${AG}/review-code-${a}.md" \
    && pass "review-code-${a} requires the per-guard FIRES ON / SLIPS PAST pair" \
    || fail "review-code-${a} has no FIRES ON / SLIPS PAST requirement (DC-02)"
done

# ---- the two agents that must trace constants to instruments ---------------------
for a in statistics data-handling; do
  grep -q "CRIT-INSTRUMENT" "${AG}/review-code-${a}.md" \
    && pass "review-code-${a} traces measurement constants to their instrument (DC-04)" \
    || fail "review-code-${a} does not require instrument tracing"
done

# ---- auto-improve loads the registry and ingests ledgers ------------------------
grep -q "defect-class-registry.md" "$AI" \
  && pass "scholar-auto-improve loads the defect-class registry" \
  || fail "scholar-auto-improve does not reference the registry"
grep -q "scholar-system-handoff" "$AI" \
  && pass "IMPROVE Step 3a ingests hand-authored run ledgers" \
  || fail "IMPROVE cannot ingest a run ledger — the richest defect source stays unread"
grep -q "UPDATE REGISTER" "$AI" \
  && pass "the ledger parser knows the UPDATE REGISTER table shape" \
  || fail "no UPDATE REGISTER parsing rule in Step 3a"
grep -qi "re-verify against the live tree" "$AI" \
  && pass "ingested ledger rows are treated as claims to verify, not facts" \
  || fail "ledger rows would be obeyed without verification (violates ABSOLUTE RULE 5)"

# ---- the dead Phase-14 hook must not be (re)introduced ---------------------------
# scholar-full-paper is not part of every distribution. Where it ships, its terminal phase
# is 12; where it does not, auto-improve must not claim a hook into it at all.
grep -q "Phase 14: Auto-Improve" "$AI" \
  && fail "scholar-auto-improve documents a Phase 14 hook that does not exist" \
  || pass "no non-existent Phase-14 hook"
grep -q "Phases 0–13" "$AI" \
  && fail "scholar-auto-improve claims to scan Phases 0–13" \
  || pass "no Phases-0–13 claim"
if [ -f "$FP" ]; then
  grep -q "terminal Phase 12" "$FP" \
    && pass "scholar-full-paper confirms terminal Phase 12 (the correction is grounded)" \
    || fail "scholar-full-paper no longer says terminal Phase 12 — re-check the auto-improve fix"
else
  echo "  INERT: scholar-full-paper not shipped in this distribution"
  grep -qE "scholar-full-paper.*Phase 1[0-9]" "$AI" \
    && fail "auto-improve references full-paper phases but the orchestrator is not shipped" \
    || pass "auto-improve makes no claim about an unshipped orchestrator"
fi

# ---- U8/U9 retargeted guidance landed where the HPC surface actually is ---------
SE="${SK}/scholar-annotate/references/scale-engine.md"
grep -q "verified by content at job start" "$SE" \
  && pass "scale-engine.md carries the content-pinning rule (DC-07)" \
  || fail "no content-pinning guidance on the plugin's only HPC surface"
grep -q "advisory" "$SE" && grep -q "chmod" "$SE" \
  && pass "the chmod-is-decoration correction is stated, not just the original claim" \
  || fail "scale-engine.md recommends pinning without the chmod correction"
grep -q "require_artifact_of_build" "$SE" \
  && pass "scale-engine.md carries the build-vintage guard (DC-06)" \
  || fail "no require_artifact_of_build guidance"

# ---- U13 provenance rule in the objectivity mandate ----------------------------
OM="${SK}/_shared/objectivity-mandate.md"
grep -qi "verified.*forwarded\|forwarded.*verified" "$OM" \
  && pass "objectivity mandate distinguishes verified from forwarded claims" \
  || fail "no claim-provenance rule in the objectivity mandate"

echo ""
echo "════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
