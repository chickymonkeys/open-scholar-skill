#!/usr/bin/env bash
# test-measurement-instrument-check.sh — fixtures for measurement-instrument-check.sh.
#
# The central fixture reproduces handoff §12 exactly: a BROAD instrument (asked about the
# "Mandarin dialect supergroup in the linguists' sense", crediting colloquial alternatives)
# feeding a NARROW consumer (a lexicon that deliberately excludes them), via a hard-coded
# `TARGET_RECALL <- 0.62` whose block comment asserts "NOTHING here is hard-coded from a count".
# Under the pre-2026-08-11 system that shape passed six review-code-* agents across four
# iterations. It must now RED.
#
# FIRES ON  — undeclared instrument (R1); constant drift between script and declaration (R2);
#             construct verdict != MATCH, or a missing/unnamed instrument_id (R3); artifact
#             design parameters disagreeing with the declared design (R4).
# SLIPS PAST — a matched instrument with a correctly-declared constant (positive control);
#             a project that never used the measurement path (INERT, not GREEN).

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="${REPO_ROOT}/scripts/gates/measurement-instrument-check.sh"
PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== measurement-instrument-check.sh (U16/U18/U14/U15) ==="
echo ""
[ -x "$GATE" ] || { echo "  FAIL: $GATE missing or not executable"; exit 1; }

TMP="$(mktemp -d -t micgate.XXXXXX)"; trap 'rm -rf "$TMP"' EXIT

mk_script() {   # mk_script <proj> <value> [comment]
  mkdir -p "$1/scripts"
  { echo "# Model of naming behaviour."
    echo "# ${3:-NOTHING here is hard-coded from a count.}"
    echo "TARGET_RECALL <- $2"
    echo "fit <- glm(y ~ x, offset = log(TARGET_RECALL))"
  } > "$1/scripts/06-logits.R"
}
mk_const() {    # mk_const <proj> <declared_value> <instrument_id>
  mkdir -p "$1/design"
  printf '{"constants":[{"name":"TARGET_RECALL","value":%s,"script":"scripts/06-logits.R","instrument_id":"%s"}]}\n' \
    "$2" "$3" > "$1/design/measurement-constants.json"
}
mk_match() {    # mk_match <proj> <instrument_id> <verdict>
  mkdir -p "$1/design"
  printf '{"instruments":[{"instrument_id":"%s","asked":"Does this comment name the superordinate category in the sense used by domain experts, including an alternative or colloquial name?","needed":"Does this comment fire names_target as the lexicon implements it?","verdict":"%s","note":"fixture"}]}\n' \
    "$2" "$3" > "$1/design/construct-match.json"
}
rc_of() { bash "$GATE" "$1" >"$TMP/out" 2>&1; echo $?; }

# ---- INERT: the measurement path was never used ----------------------------------
A="$TMP/unused"; mkdir -p "$A/scripts"
RC=$(rc_of "$A")
[ "$RC" -eq 3 ] && pass "project with no measurement artifacts → INERT (rc 3), not GREEN" \
                || fail "unused project: expected rc3, got $RC"

# ---- R3: THE §12 SHAPE — broad instrument, narrow consumer -----------------------
B="$TMP/sec12"; mk_script "$B" 0.62; mk_const "$B" 0.62 "target-recall-broad"; mk_match "$B" "target-recall-broad" "BROADER"
RC=$(rc_of "$B")
[ "$RC" -eq 1 ] && pass "§12 shape: BROADER instrument feeding a narrow consumer → RED (rc 1)" \
                || fail "§12 shape: expected rc1, got $RC"
grep -q "MIC_RED R3" "$TMP/out" && pass "the RED is attributed to R3 (construct mismatch)" || fail "R3 not attributed"
grep -q "not asked the question this model needs" "$TMP/out" \
  && pass "the message names the actual defect, not just a failed field" || fail "R3 message unclear"

# ---- R3: NARROWER and UNASSESSED are RED too -------------------------------------
for V in NARROWER UNASSESSED; do
  C="$TMP/v$V"; mk_script "$C" 0.62; mk_const "$C" 0.62 "iid-$V"; mk_match "$C" "iid-$V" "$V"
  RC=$(rc_of "$C")
  [ "$RC" -eq 1 ] && pass "verdict $V → RED (rc 1)" || fail "verdict $V: expected rc1, got $RC"
done

# ---- R3: a constant with no construct-match record at all ------------------------
D="$TMP/norecord"; mk_script "$D" 0.62; mk_const "$D" 0.62 "ghost-instrument"
RC=$(rc_of "$D")
[ "$RC" -eq 1 ] && pass "instrument_id with no construct-match record → RED (rc 1)" || fail "no-record: expected rc1, got $RC"

# ---- R2: the script drifted away from its declaration ----------------------------
E="$TMP/drift"; mk_script "$E" 0.612; mk_const "$E" 0.62 "target-recall-v2"; mk_match "$E" "target-recall-v2" "MATCH"
RC=$(rc_of "$E")
[ "$RC" -eq 1 ] && pass "script value drifted from declared value → RED (rc 1)" || fail "drift: expected rc1, got $RC"
grep -q "MIC_RED R2" "$TMP/out" && pass "drift is attributed to R2" || fail "R2 not attributed"

# ---- R2: a comment claiming the opposite must not rescue the file ----------------
F="$TMP/lyingcomment"; mk_script "$F" 0.612 "TARGET_RECALL <- 0.62  (this comment is a lie)"
mk_const "$F" 0.62 "target-recall-v2"; mk_match "$F" "target-recall-v2" "MATCH"
RC=$(rc_of "$F")
[ "$RC" -eq 1 ] && pass "a comment restating the declared value does not satisfy R2 (comments are stripped)" \
                || fail "lying comment: expected rc1, got $RC"

# ---- positive control: matched instrument, correct declaration -------------------
G="$TMP/good"; mk_script "$G" 0.94; mk_const "$G" 0.94 "target-recall-v2"; mk_match "$G" "target-recall-v2" "MATCH"
RC=$(rc_of "$G")
[ "$RC" -eq 0 ] && pass "positive control: MATCH verdict + declared constant → GREEN (rc 0)" \
                || fail "positive control: expected rc0, got $RC"

# ---- R5: an undeclared measurement-shaped literal is advisory, not silent --------
H="$TMP/undeclared"; mk_script "$H" 0.62
RC=$(rc_of "$H")
[ "$RC" -eq 2 ] && pass "undeclared measurement-shaped literal → YELLOW (rc 2), never silent" \
                || fail "undeclared literal: expected rc2, got $RC"
grep -q "MIC_YELLOW R5" "$TMP/out" && pass "R5 names the literal and where to declare it" || fail "R5 not attributed"

# ---- R1: a validation report with no instrument block ----------------------------
I="$TMP/noinst"; mkdir -p "$I/tables"
echo '{"fields":{},"GATE_pass":true}' > "$I/tables/validation_report.json"
RC=$(rc_of "$I")
[ "$RC" -eq 1 ] && pass "validation_report.json without an instrument block → RED (rc 1)" || fail "R1: expected rc1, got $RC"
# and a waiver is YELLOW, not GREEN
echo '{"fields":{},"instrument":{"declared":false,"waived":true},"GATE_pass":true}' > "$I/tables/validation_report.json"
RC=$(rc_of "$I")
[ "$RC" -eq 2 ] && pass "an explicit --no-instrument waiver → YELLOW (rc 2), not GREEN" || fail "waiver: expected rc2, got $RC"

# ---- R3b: a validated instrument with NO construct-match record at all ----------
# Found by an end-to-end run of the engine into the gate: R3 only reaches instruments
# named by a DECLARED CONSTANT, so an instrument that produced shipped LABELS and was
# never construct-matched passed GREEN — the §12 situation minus the hard-coded number.
# YELLOW, not RED: the labels carry their codebook, so this is a missing assessment
# rather than a demonstrated mismatch.
M="$TMP/labelsonly"; mkdir -p "$M/tables"
cat > "$M/tables/validation_report.json" <<'EOF'
{"fields":{"relevance":{"cohen_kappa":0.91,"coverage":1.0,"pass":true}},
 "instrument":{"declared":true,"instrument_id":"relevance-v1","model":"glm-5.2"},
 "GATE_pass":true,"STATUS":"GREEN"}
EOF
RC=$(rc_of "$M")
[ "$RC" -eq 2 ] && pass "validated instrument with no construct-match record → YELLOW (rc 2)" \
                || fail "R3b: expected rc2, got $RC"
grep -q "MIC_YELLOW R3b" "$TMP/out" && pass "R3b names the un-assessed instrument" || fail "R3b not attributed"
mkdir -p "$M/design"
printf '{"instruments":[{"instrument_id":"relevance-v1","asked":"X","needed":"X","verdict":"MATCH"}]}\n' \
  > "$M/design/construct-match.json"
RC=$(rc_of "$M")
[ "$RC" -eq 0 ] && pass "adding the construct-match record clears R3b → GREEN (rc 0)" \
                || fail "R3b control: expected rc0, got $RC"

# ---- R4: a rebuild silently reverted the sample size (the variety-A regression) --
J="$TMP/designdrift"; mkdir -p "$J/design" "$J/tables"
echo 'variety,precision' > "$J/tables/precision_by_stratum.csv"
printf '{"n_requested":100,"pool_per_stratum":500,"seed":23,"strata_col":"variety"}\n' \
  > "$J/tables/precision_by_stratum.csv.design.json"
printf '{"measurements":[{"name":"precision-audit-variety","artifact":"tables/precision_by_stratum.csv","expect":{"n_requested":400}}]}\n' \
  > "$J/design/measurement-design.json"
RC=$(rc_of "$J")
[ "$RC" -eq 1 ] && pass "artifact produced at n=100 against a declared n=400 → RED (rc 1)" || fail "R4: expected rc1, got $RC"
grep -q "MIC_RED R4" "$TMP/out" && pass "design drift is attributed to R4" || fail "R4 not attributed"
# same declaration, artifact now produced at the declared n -> clears
printf '{"n_requested":400,"pool_per_stratum":500,"seed":23,"strata_col":"variety"}\n' \
  > "$J/tables/precision_by_stratum.csv.design.json"
RC=$(rc_of "$J")
[ "$RC" -eq 0 ] && pass "artifact matching its declared design → GREEN (rc 0)" || fail "R4 control: expected rc0, got $RC"

# ---- a malformed declaration must not read as 'nothing declared' -----------------
K="$TMP/malformed"; mkdir -p "$K/design" "$K/scripts"
echo '{"constants":[' > "$K/design/measurement-constants.json"
RC=$(rc_of "$K")
[ "$RC" -eq 1 ] && pass "unparseable declaration → RED (rc 1), not treated as empty" || fail "malformed: expected rc1, got $RC"

# ---- paths containing spaces ------------------------------------------------------
L="$TMP/with space/proj"; mk_script "$L" 0.94; mk_const "$L" 0.94 "target-recall-v2"; mk_match "$L" "target-recall-v2" "MATCH"
RC=$(rc_of "$L")
[ "$RC" -eq 0 ] && pass "project path containing a space → GREEN (rc 0)" || fail "space path: expected rc0, got $RC"


# ---- defects found by INDEPENDENT external audit (2026-08-12) --------------------
# All of these produced GREEN/INERT under the author's own fixtures.

# A malformed schema was iterated CHARACTER BY CHARACTER, every char skipped as
# "not a dict", leaving the gate GREEN on an unassessable declaration.
for BADSHAPE in '{"constants":"garbage"}' '{"constants":[1,2,3]}' '["not","objects"]'; do
  M="$TMP/badshape$RANDOM"; mkdir -p "$M/design" "$M/scripts"
  printf '%s\n' "$BADSHAPE" > "$M/design/measurement-constants.json"
  RC=$(rc_of "$M")
  [ "$RC" -eq 1 ] && pass "malformed constants schema → RED ($BADSHAPE)" \
                  || fail "malformed schema $BADSHAPE: expected rc1, got $RC"
done
M="$TMP/baddesign"; mkdir -p "$M/design"
printf '{"measurements":"garbage"}\n' > "$M/design/measurement-design.json"
RC=$(rc_of "$M")
[ "$RC" -eq 1 ] && pass "malformed measurement-design schema → RED" || fail "bad design schema: expected rc1, got $RC"

# Python treats the STRING "false" as truthy, so `"declared":"false"` entered the
# declared branch and `"waived":"false"` recorded a waiver.
# The fixture supplies a VALID instrument_id, so under the old truthy-string behaviour it
# would have been accepted as declared and exited GREEN. Without the id, the declared
# branch REDs for a missing id regardless and the assertion is vacuous.
M="$TMP/strbool"; mkdir -p "$M/tables" "$M/design"
printf '{"instruments":[{"instrument_id":"iid-sb","asked":"A","needed":"A","verdict":"MATCH"}]}\n' > "$M/design/construct-match.json"
printf '{"fields":{},"instrument":{"declared":"false","instrument_id":"iid-sb","model":"m"},"GATE_pass":true}\n' > "$M/tables/validation_report.json"
RC=$(rc_of "$M")
[ "$RC" -eq 1 ] && pass 'string "false" is not a declared instrument → RED (id present, so only truthiness decides)' \
                || fail "string-bool declared: expected rc1, got $RC"
grep -q "instrument.declared=false" "$TMP/out" && pass "the RED is the undeclared-instrument rule, not a missing id" || fail "wrong RED reason for string-bool"
printf '{"fields":{},"instrument":{"declared":false,"waived":"false"},"GATE_pass":true}\n' > "$M/tables/validation_report.json"
RC=$(rc_of "$M")
[ "$RC" -eq 1 ] && pass 'string "false" is not a waiver → RED' || fail "string-bool waived: expected rc1, got $RC"

# NaN compares unequal to everything, so a NaN declaration could never register drift —
# the same IEEE-754 failure mode that was fixed in the kappa gate.
# The declared NAME must match the one mk_script actually writes (TARGET_RECALL), otherwise
# the RED comes from "no numeric assignment found" and the non-finite rule is never reached.
M="$TMP/nanconst"; mk_script "$M" 0.62; mk_match "$M" "iid-n" "MATCH"
mkdir -p "$M/design"
printf '{"constants":[{"name":"TARGET_RECALL","value":NaN,"script":"scripts/06-logits.R","instrument_id":"iid-n"}]}\n' > "$M/design/measurement-constants.json"
RC=$(rc_of "$M")
[ "$RC" -eq 1 ] && pass "non-finite declared value → RED (cannot ever register drift)" || fail "NaN constant: expected rc1, got $RC"
grep -q "is not a finite number" "$TMP/out" \
  && pass "the RED is the non-finite rule, not a missing assignment" \
  || fail "NaN fixture RED came from the wrong rule — assertion would be vacuous"
# control: the same fixture with a FINITE matching value must be GREEN
printf '{"constants":[{"name":"TARGET_RECALL","value":0.62,"script":"scripts/06-logits.R","instrument_id":"iid-n"}]}\n' > "$M/design/measurement-constants.json"
RC=$(rc_of "$M")
[ "$RC" -eq 0 ] && pass "the same fixture with a finite value → GREEN (probe is live)" || fail "finite control: expected rc0, got $RC"

# The literal regex required a leading digit, so `.62` evaded R5 entirely and a project
# whose only literal was leading-dot exited INERT claiming no measurement literals.
M="$TMP/leadingdot"; mkdir -p "$M/scripts"
printf '# m\nTARGET_RECALL <- .62\n' > "$M/scripts/m.R"
RC=$(rc_of "$M")
[ "$RC" -eq 2 ] && pass "leading-dot literal (.62) is detected by R5 → YELLOW, not INERT" \
                || fail "leading-dot literal: expected rc2, got $RC"

# A construct-match record with no instrument_id was silently dropped from the registry.
# The constant resolves cleanly; the ONLY defect is a second record with no instrument_id.
# Previously the constant's id was unresolvable, so the RED came from that and the
# malformed record could have been silently dropped without the test noticing.
M="$TMP/noiid"; mk_script "$M" 0.62; mk_const "$M" 0.62 "iid-ok"
mkdir -p "$M/design"
printf '{"instruments":[{"instrument_id":"iid-ok","asked":"A","needed":"A","verdict":"MATCH"},{"asked":"A","needed":"B","verdict":"MATCH"}]}\n' > "$M/design/construct-match.json"
RC=$(rc_of "$M")
[ "$RC" -eq 1 ] && pass "a construct-match record without instrument_id → RED (even when every constant resolves)" \
                || fail "no-iid record: expected rc1, got $RC"
grep -q "has no instrument_id" "$TMP/out" && pass "the RED names the unnamed record" || fail "wrong RED reason for the unnamed record"


# ---- ROUND-2 audit: a fix that broke a documented form --------------------------
# The malformed-schema fix (as_entries) initially treated EVERY top-level object as a
# wrapper and substituted [] when the wrapper key was absent — silently discarding the
# BARE-OBJECT form construct-match.md documents, and producing a FALSE missing-construct
# RED. A hardening fix must not break the contract it hardens.
M="$TMP/bareobject"; mk_script "$M" 0.94
mk_const "$M" 0.94 "iid-bare"
mkdir -p "$M/design"
printf '{"instrument_id":"iid-bare","asked":"A","needed":"A","verdict":"MATCH"}\n' > "$M/design/construct-match.json"
RC=$(rc_of "$M")
[ "$RC" -eq 0 ] && pass "bare-object construct-match record is honoured → GREEN (documented form)" \
                || fail "bare object: expected rc0, got $RC"
grep -q "CONSTRUCT_MATCH_RECORDS=1" "$TMP/out" && pass "the bare object is counted as one record" || fail "bare object not registered"

# an object that is neither a wrapper nor a recognisable record stays RED
M="$TMP/ambiguous"; mkdir -p "$M/design"
printf '{"totally":"unrelated"}\n' > "$M/design/construct-match.json"
RC=$(rc_of "$M")
[ "$RC" -eq 1 ] && pass "an object that is neither wrapper nor record → RED (not silently empty)" \
                || fail "ambiguous object: expected rc1, got $RC"

echo ""
echo "════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
