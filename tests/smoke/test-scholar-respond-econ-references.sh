#!/usr/bin/env bash
# Smoke test: the row 4 economics layer — fifteen routed references integrated into
# scholar-respond MODE 1. This test is a ratchet on the four things the row is easiest
# to lose on later: the count of fifteen, the fold of the modern-methods checks into
# two existing dimensions, blindspot staying a synthesis-time Opportunities mode, and
# the salvaged protocol layer (report structure, the three-point cap, the accept-to-reject
# rubric, comments-not-rewrites).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/scholar-respond"
ECON="$SKILL_DIR/references/econ"
MODE1="$SKILL_DIR/references/mode-1-simulate.md"

PASS=0
FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS + 1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
has(){ grep -Fq "$2" "$1" && ok "$3" || no "$3"; }

echo "=== scholar-respond economics layer (row 4) ==="

# --- 1. fifteen routed references, and exactly fifteen ---
DIMENSIONS=(
  identification robustness mechanism external-validity structural theory
  experimental descriptive data-construction economic-magnitude preregistration
  reproducibility transparency blindspot contribution
)
for d in "${DIMENSIONS[@]}"; do
  [ -f "$ECON/$d.md" ] && ok "routed reference present: $d.md" || no "missing routed reference: $d.md"
done

# the count does not reopen: router + protocol are the only non-dimension files
count=$(ls "$ECON"/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -eq 17 ]; then
  ok "econ/ holds exactly 15 dimension references plus router.md and protocol.md"
else
  no "econ/ holds $count .md files; expected 17 (15 dimensions + router + protocol)"
fi
[ -f "$ECON/router.md" ] && ok "router present" || no "router.md missing"
[ -f "$ECON/protocol.md" ] && ok "protocol present" || no "protocol.md missing"

# --- 2. modern methods is folded, not a sixteenth dimension ---
if [ -f "$ECON/modern-methods.md" ]; then
  no "modern-methods.md exists as a sixteenth dimension — it must be folded"
else
  ok "no standalone modern-methods dimension"
fi
has "$ECON/data-construction.md" "Sub-check A — Construct validity" "data construction carries the construct-validity sub-check"
has "$ECON/data-construction.md" "Sub-check B — Provenance"          "data construction carries the provenance sub-check"
has "$ECON/data-construction.md" "Sub-check C — Representativeness"  "data construction carries the representativeness sub-check"
has "$ECON/robustness.md" "Sub-check A — Leakage and out-of-sample discipline" "robustness carries the leakage sub-check"
has "$ECON/robustness.md" "Sub-check B — Calibration and error structure"      "robustness carries the calibration sub-check"
has "$ECON/robustness.md" "Sub-check C — Task-matched validation"              "robustness carries the task-matched-validation sub-check"
has "$ECON/router.md" "The modern-methods trigger" "the router keeps the modern-methods trigger"

# --- 3. the three quarried diagnostic sub-checks, inside existing dimensions ---
has "$ECON/robustness.md" "Check 6 — Few clusters relative to the asymptotics invoked" "robustness carries the few-cluster inference check"
has "$ECON/robustness.md" "Check 7 — Age, period and cohort restrictions"              "robustness carries the age-period-cohort check"
has "$ECON/data-construction.md" "Check 6 — Retrospective proxies"                     "data construction carries the retrospective-proxy check"

# --- 4. the treatment-construction invariant check (no gate candidate derived it) ---
has "$ECON/data-construction.md" "Check 4 — Treatment-construction invariant" "the treatment-construction invariant check exists"
has "$ECON/data-construction.md" "at least one recession during ages 18–25"   "the invariant check carries its worked example"

# --- 4b. the checks the first operation earned (see the row-4 research note) ---
has "$ECON/identification.md" "Check 8 — Post-treatment conditioning" "identification carries the bad-controls check"
has "$ECON/identification.md" "*Applies to:*" "identification checks name the designs they apply to"
has "$ECON/robustness.md" "Check 9 — Multiplicity and summary-index construction" "robustness carries the multiplicity/index check"
has "$ECON/reproducibility.md" "Check 5 — Recompute what the tables claim to derive" "reproducibility carries the recompute check"
has "$ECON/reproducibility.md" "Check 6 — Do the printed significance markers match the stated inference procedure?" "reproducibility carries the stars-vs-procedure check"
has "$ECON/economic-magnitude.md" "Check 7 — Which statistic is being quoted" "magnitude carries the which-statistic check"
has "$ECON/data-construction.md" "A second worked example, on a different shape of rule" "the invariant check carries a second, unrelated worked example"
has "$ECON/protocol.md" "Hand on what is not yours" "a seat hands a finding outside its checks to the synthesis"

# --- 5. routing composes two axes, and a mixed paper takes the union ---
has "$ECON/router.md" "Axis 1 — methodological form (selects the checks)" "router axis 1: methodological form selects the checks"
has "$ECON/router.md" "Axis 2 — economic field or topic (tunes the checks)" "router axis 2: field tunes the checks"
has "$ECON/router.md" "A mixed paper receives the union" "a mixed paper receives the union of the matching rows"
for form in "empirical/applied" "theoretical" "structural or counterfactual" "descriptive" "experimental" "mixed"; do
  grep -Fq "$form" "$ECON/router.md" && ok "router routes form: $form" || no "router omits form: $form"
done

# --- 6. every routed reference reaches exactly one seat ---
SEATS=$(sed -n '/^| Seat | Reads |/,/^$/p' "$ECON/router.md")
SEAT_NAMES=(identification robustness "data construction" experimental structural descriptive
            preregistration theory mechanism "external validity" contribution reproducibility
            transparency "economic magnitude" blindspot)
for name in "${SEAT_NAMES[@]}"; do
  n=$(printf '%s\n' "$SEATS" | grep -Fo "$name" | wc -l | tr -d ' ')
  [ "$n" -eq 1 ] && ok "one seat owns: $name" || no "$name appears in $n seat rows (expected 1)"
done
printf '%s\n' "$SEATS" | grep -Fq "synthesis (the parent, Step 4)" \
  && ok "blindspot is owned by synthesis, not a reviewer seat" \
  || no "no synthesis row in the seat table"

# --- 7. blindspot is a cross-cutting Opportunities mode run AFTER the validity checks ---
has "$ECON/blindspot.md" "Not a validity dimension and not on the route table" "blindspot is off the route table"
has "$ECON/blindspot.md" "after the routed validity checks have returned"      "blindspot runs after the validity checks"
has "$MODE1" "Blindspot runs here, and only here"                              "MODE 1 runs blindspot in synthesis"
has "$MODE1" "OPPORTUNITIES (virtue-side, non-binding)"                        "the report carries an Opportunities section"

# --- 8. the salvaged protocol layer survives ---
has "$ECON/protocol.md" "Essential Points — at most three" "report structure: Essential Points capped at three"
has "$ECON/protocol.md" "Summary + Recommendation"          "report structure: Summary + Recommendation"
has "$ECON/protocol.md" "Suggestions"                        "report structure: Suggestions"
has "$ECON/protocol.md" "Appendix — routed findings"         "report structure: Appendix"
has "$ECON/protocol.md" "Comments, not rewrites"             "conduct rule: comments, not rewrites"
for decision in "Accept" "Minor Revision" "Major Revision" "Reject-and-Resubmit" "Reject"; do
  grep -Fq "**$decision**" "$ECON/protocol.md" && ok "decision rubric carries: $decision" \
    || no "decision rubric missing: $decision"
done
has "$ECON/protocol.md" "Be explicit about uncertainty"      "the audit is explicit about uncertainty"

# --- 9. structured comprehension is optional, never a required file ---
has "$ECON/protocol.md" "optional and never a file the run waits on" "structured comprehension is optional"

# --- 10. the layer is integrated into MODE 1, not sitting beside it ---
has "$MODE1" "Step 2.5: Economics Layer Routing" "MODE 1 carries the economics routing step"
has "$MODE1" "references/econ/router.md"          "MODE 1 loads the econ router"
has "$MODE1" "It adds no reviewer" "the layer adds no seat and no orchestration"
has "$MODE1" "Skip this step unless Step 1 marked the paper as economics" "the layer is inert for non-economics papers"
if [ -d "$PROJECT_ROOT/.claude/skills/econ-referee" ] || [ -d "$PROJECT_ROOT/.claude/skills/paper-critique" ]; then
  no "the economics layer ships as a separate skill — it must live inside scholar-respond MODE 1"
else
  ok "no separate economics skill: the layer lives inside scholar-respond MODE 1"
fi

# --- 11. every routed reference is reachable from the router ---
for d in "${DIMENSIONS[@]}"; do
  if [ "$d" = "blindspot" ]; then
    grep -Fq "blindspot.md" "$MODE1" && ok "blindspot.md is reachable from MODE 1 synthesis" \
      || no "blindspot.md is unreachable"
  else
    grep -Eq "\b${d//-/[- ]}\b" "$ECON/router.md" && ok "router names $d" || no "router never names $d"
  fi
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
