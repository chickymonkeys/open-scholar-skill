#!/usr/bin/env bash
# test-preexec-doc-integrity.sh — cross-file integrity for the pre-execution
# review protocol (_shared/pre-execution-review.md) and the relocated
# code-review fix loop.
#
# Slice A invariants: shared files exist with their load-bearing sections,
# the old fix-loop path is a stub, no live reference targets the old path,
# the gate is executable, coverage-check speaks --phase, and
# scholar-code-review carries the planned mode + manifest + Step 6 contract.
# Per-skill duty assertions (SKILLS_WITH_DUTY) grow as Slices B/C land.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SK="$REPO_ROOT/.claude/skills"

PASS=0
FAIL=0
pass() { PASS=$((PASS+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "Test 1: shared protocol exists with load-bearing sections"
P="$SK/_shared/pre-execution-review.md"
if [ -f "$P" ] \
   && grep -q "DRAFTED  →  REVIEWED+HASHED  →  EXECUTABLE" "$P" \
   && grep -q "Pilot exemption" "$P" \
   && grep -q "pre-exec-review-check.sh" "$P" \
   && grep -q "pre-exec-analyze" "$P"; then
  pass "protocol file + state sequence + pilot + gate + phase tags"
else
  fail "_shared/pre-execution-review.md missing or missing sections"
fi

echo "Test 2: fix loop lives in _shared with Loop content + self-load path"
F="$SK/_shared/code-review-fix-loop.md"
if [ -f "$F" ] && grep -q "^## Loop" "$F" \
   && grep -q '_shared/code-review-fix-loop.md"' "$F" \
   && grep -q "AUTO_FIX" "$F"; then
  pass "_shared fix loop is the canonical copy"
else
  fail "_shared/code-review-fix-loop.md missing content or stale self-load"
fi

echo "Test 3: old fix-loop path is a pointer stub (skipped when scholar-full-paper absent)"
OLD="$SK/scholar-full-paper/references/code-review-fix-loop.md"
if [ ! -d "$SK/scholar-full-paper" ]; then
  pass "scholar-full-paper not in this roster — stub check not applicable"
elif [ -f "$OLD" ] && grep -q "MOVED" "$OLD" && ! grep -q "^## Loop" "$OLD"; then
  pass "old path is a stub, not a second canonical copy"
else
  fail "old fix-loop path is missing or still carries the full loop"
fi

echo "Test 4: no live reference targets the old fix-loop path"
STALE=$(grep -rln "scholar-full-paper/references/code-review-fix-loop" \
  "$SK" "$REPO_ROOT/scripts" "$REPO_ROOT/tests" 2>/dev/null \
  | grep -v "references/code-review-fix-loop.md$" \
  | grep -v "test-preexec-doc-integrity.sh$" || true)
if [ -z "$STALE" ]; then
  pass "no runtime/prose reference to the old path outside the stub"
else
  fail "stale references remain: $(echo "$STALE" | tr '\n' ' ')"
fi

echo "Test 5: gate exists and is executable"
G="$REPO_ROOT/scripts/gates/pre-exec-review-check.sh"
if [ -x "$G" ]; then
  pass "pre-exec-review-check.sh present + executable"
else
  fail "pre-exec-review-check.sh missing or not chmod +x (phase-verify-class silent-skip hazard)"
fi

echo "Test 6: coverage-check supports --phase"
C="$REPO_ROOT/scripts/gates/code-review-coverage-check.sh"
if grep -q -- '--phase=?\*' "$C" && grep -q "token-counting cannot stand in" "$C"; then
  pass "coverage-check --phase + no-token-GREEN rule present"
else
  fail "coverage-check missing --phase support or provenance rule"
fi

echo "Test 7: scholar-code-review carries planned mode, manifest, dispatch recording, Step 6"
S="$SK/scholar-code-review/SKILL.md"
OK=1
grep -q "Planned-Script (Pre-Execution) Mode" "$S" || { OK=0; fail "planned-script mode section missing"; }
grep -q "code-review-manifest/v1" "$S" || { OK=0; fail "reviewed-script manifest schema missing"; }
grep -q "emit-task-dispatch.sh" "$S" || { OK=0; fail "dispatch recording missing"; }
grep -q "Step 6: Post-Fix Re-Review" "$S" || { OK=0; fail "post-fix re-review step missing"; }
grep -q "supersedes_review_id" "$S" || { OK=0; fail "supersedes chain fields missing"; }
[ "$OK" = "1" ] && pass "scholar-code-review upgrades all present"

echo "Test 8: per-skill duty references (grows with Slices B/C)"
# Format: "<skill-dir>" — each must reference the shared protocol AND the gate.
SKILLS_WITH_DUTY=(scholar-analyze scholar-eda scholar-ling scholar-compute scholar-data scholar-simulate)
DUTY_OK=1
for D in ${SKILLS_WITH_DUTY[@]+"${SKILLS_WITH_DUTY[@]}"}; do
  F="$SK/$D/SKILL.md"
  if ! grep -q "_shared/pre-execution-review.md" "$F" || ! grep -q "pre-exec-review-check.sh" "$F"; then
    DUTY_OK=0; fail "$D does not reference the protocol + gate"
  fi
done
if [ "$DUTY_OK" = "1" ]; then
  if [ "${#SKILLS_WITH_DUTY[@]}" -eq 0 ]; then
    pass "no per-skill duties registered yet (Slice A state)"
  else
    pass "all ${#SKILLS_WITH_DUTY[@]} duty-bearing skills reference protocol + gate"
  fi
fi

echo "════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
