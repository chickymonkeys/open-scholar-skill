#!/usr/bin/env bash
# test-annotate-routing.sh — scholar-annotate must be REACHABLE, and the skills that hand
# work to it must agree that they do.
#
# BEFORE-STATE (verified 2026-08-11, open-scholar-skills v5.27.1):
#   scholar-annotate/SKILL.md claimed it "absorbs and replaces scholar-compute MODULE 7".
#   MODULE 7 was fully live and never mentioned scholar-annotate. scholar-full-paper routed
#   "LLM annotation" to scholar-compute. `grep -rl scholar-annotate .claude/skills/` outside
#   its own directory returned NOTHING — the skill was unreachable except by direct user
#   invocation, and there was no gate script for its κ gate.
#
#   That orphaning is the structural reason the 2026-08 run's costliest defect had no seat to
#   be caught in: a measurement instrument mismatched to its consumer (handoff §12), which
#   survived four Phase 5.5 iterations and surfaced only when an estimator refused to fit.
#
# The general rule this suite enforces: a skill that claims to absorb, replace, or own work
# from another skill must be reachable from it. A one-directional claim is an orphan.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SK="${REPO_ROOT}/.claude/skills"
PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== scholar-annotate reachability + reciprocal routing ==="
echo ""

ANN="${SK}/scholar-annotate/SKILL.md"
CMP="${SK}/scholar-compute/SKILL.md"
M07="${SK}/scholar-compute/references/module-07-llm-analysis.md"
FP="${SK}/scholar-full-paper/SKILL.md"
# $FP (scholar-full-paper) is optional — some distributions deliberately omit the
# orchestrator. The other three are required for this suite to mean anything.
for f in "$ANN" "$CMP" "$M07"; do
  [ -f "$f" ] || { echo "  FAIL: missing $f"; exit 1; }
done

# ---- 1. reachability: at least one skill outside scholar-annotate/ points at it ----
INBOUND=$(grep -rl "scholar-annotate" "$SK" --include="*.md" 2>/dev/null \
          | grep -v "/scholar-annotate/" | wc -l | tr -d ' ')
[ "$INBOUND" -ge 1 ] \
  && pass "scholar-annotate has $INBOUND inbound reference(s) from other skills (was 0)" \
  || fail "scholar-annotate is an ORPHAN — no skill outside its own directory references it"

# ---- 2. reciprocity: scholar-compute redirects, and MODULE 7 says so -------------
grep -q "scholar-annotate" "$CMP" \
  && pass "scholar-compute/SKILL.md routes annotation intent to /scholar-annotate" \
  || fail "scholar-compute does not mention scholar-annotate"
grep -qi "Step 1d" "$CMP" \
  && pass "the redirect is a numbered routing step, not a passing mention" \
  || fail "no Step 1d annotation redirect in scholar-compute"
grep -q "scholar-annotate" "$M07" \
  && pass "MODULE 7 reference carries the router to /scholar-annotate" \
  || fail "module-07-llm-analysis.md does not route measurement work out"

# ---- 3. corpus-wide orphan sweep -------------------------------------------------
# The general form of the bug: NO skill should be reachable only by direct user
# invocation. scholar-annotate was the sole orphan as of v5.27.1; this invariant keeps
# the next one from shipping.
#
# NOTE ON METHOD (CLAUDE.md Working Discipline rule 10). The first version of this check
# tried to parse absorb-claims out of English — `(absorbs?|replaces?|owns?)[^.]{0,80}
# (scholar-[a-z-]+)`. It reported 10 violations, ALL false: `owns?` matched the tail of
# "d-ownstream", and the `replaces?` hits were inside negations ("does not replace
# scholar-write"). That is precisely the handoff §9 failure — a naive grep matching text
# inside a negation and reading as a finding. Reachability is a checkable property; the
# claim's English is not. Do not reintroduce a prose parser here.
# Single indexing pass (one grep over the tree, not one per skill — the naive
# skill-by-skill form was O(n^2) and blew a 120s budget). The alternation is built from
# the ACTUAL skill directory names: an earlier version tokenized `scholar-[a-z-]*` and
# falsely reported `sync-docs` as an orphan because the pattern could not match it.
# Every name the sweep judges must be a name the index can see.
SKILL_NAMES=""
for d in "$SK"/*/; do
  s="$(basename "$d")"
  [ "$s" = "_shared" ] && continue
  [ -f "${d}SKILL.md" ] || continue
  SKILL_NAMES="${SKILL_NAMES}${SKILL_NAMES:+|}${s}"
done
IDX="$(mktemp -t skillrefs.XXXXXX)"; trap 'rm -f "$IDX"' EXIT
grep -roE "(${SKILL_NAMES})" "$SK" --include="*.md" 2>/dev/null \
  | sed "s|^${SK}/||" > "$IDX"
ORPHANS=0
for d in "$SK"/*/; do
  s="$(basename "$d")"
  [ "$s" = "_shared" ] && continue
  [ -f "${d}SKILL.md" ] || continue
  # a reference to $s from any file NOT under $s/ makes it reachable
  if ! grep -E ":${s}\$" "$IDX" | grep -qv "^${s}/"; then
    echo "       ORPHAN: $s is referenced by no other skill — reachable only by direct invocation"
    ORPHANS=$((ORPHANS + 1))
  fi
done
[ "$ORPHANS" -eq 0 ] \
  && pass "no orphan skills: every skill is reachable from at least one other skill" \
  || fail "$ORPHANS orphan skill(s) — unreachable from any pipeline, so their gates never run"

# ---- 4. the orchestrator can reach it (only where an orchestrator ships) ---------
# scholar-full-paper is deliberately absent from some distributions. Where it ships, the
# annotate branch must have a dispatchable Phase 6 seat; where it does not, the compute
# redirect in check 2 is the whole reachability story and this check is INERT.
if [ -f "$FP" ]; then
  grep -q "scholar-annotate" "$FP" \
    && pass "scholar-full-paper references scholar-annotate" \
    || fail "scholar-full-paper cannot reach scholar-annotate — Phase 6 has no annotate branch"
  awk '/^### Phase 6: /,/^### Phase 6\.2/' "$FP" | grep -q "scholar-annotate" \
    && pass "the reference is inside the Phase 6 branch block (a dispatchable seat)" \
    || fail "scholar-annotate is mentioned but not in the Phase 6 dispatch block"
  awk '/^### Phase 6\.2/,/^### Phase 6\.5/' "$FP" | grep -q "scholar-annotate" \
    && pass "Phase 6.2 compute pre-mortem trigger covers the annotate branch" \
    || fail "Phase 6.2 trigger does not fire for annotate-branch projects"
else
  echo "  INERT: scholar-full-paper not shipped in this distribution — orchestrator seat N/A"
fi

# ---- 5. the measurement gate exists and is wired ---------------------------------
GATE="${REPO_ROOT}/scripts/gates/measurement-instrument-check.sh"
[ -x "$GATE" ] && pass "measurement-instrument-check.sh exists and is executable" \
               || fail "measurement-instrument-check.sh missing or not executable"
# EXECUTE the wiring, do not grep for it. The first version of this check grepped
# phase-verify.sh for the gate name and PASSED while the wiring was dead: the call sat
# under `set -euo pipefail`, so a RED gate aborted the script before it could report.
# A grep for a filename proves the string is present, not that the gate runs.
MIC_T="$(mktemp -d -t micwire.XXXXXX)"
mkdir -p "$MIC_T/design" "$MIC_T/scripts"
printf '# m\nTARGET_RECALL <- 0.62\n' > "$MIC_T/scripts/m.R"
printf '{"constants":[{"name":"TARGET_RECALL","value":0.62,"script":"scripts/m.R","instrument_id":"iid-x"}]}\n' > "$MIC_T/design/measurement-constants.json"
printf '{"instruments":[{"instrument_id":"iid-x","asked":"A","needed":"B","verdict":"BROADER"}]}\n' > "$MIC_T/design/construct-match.json"
MIC_WIRE=$(bash "${REPO_ROOT}/scripts/gates/phase-verify.sh" 6 "$MIC_T" 2>&1 || true)
rm -rf "$MIC_T"
printf '%s\n' "$MIC_WIRE" | grep -q "measurement-instrument-check RED" \
  && pass "phase-verify Phase 6 actually surfaces a RED from the measurement gate" \
  || fail "the gate is referenced in phase-verify.sh but does not fire (check set -e handling)"
grep -q "measurement-instrument-check.sh" "${SK}/scholar-annotate/references/validation-gate.md" \
  && pass "MODE 7 validation-gate.md documents the construct-match gate" \
  || fail "validation-gate.md does not document the second blocking check"

# ---- 6. concept-gap: every reference file MODE 7 names must exist -----------------
MISSING=0
for ref in $(grep -oE 'references/[a-z0-9-]+\.md' "$ANN" | sort -u); do
  [ -f "${SK}/scholar-annotate/${ref}" ] || { echo "       missing: scholar-annotate/${ref}"; MISSING=$((MISSING + 1)); }
done
[ "$MISSING" -eq 0 ] && pass "every references/*.md named in scholar-annotate/SKILL.md exists" \
                     || fail "$MISSING reference file(s) named but not shipped"

echo ""
echo "════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
