#!/usr/bin/env bash
# test-annotate-engine-gate.sh — regression fixtures for the scholar-annotate MODE 7
# hard gate (`annotate_engine.py validate`).
#
# WHY THIS EXISTS. The 2026-08-11 `a large-corpus annotation run` handoff §2 records the
# most productive finding of that run: "guards are verified in the state they were designed
# for, never in the states they will meet." The κ gate was one of them. A fixture where the
# annotator FAILED 40% of documents was run against the shipped engine and it printed
# "PASS — cleared for MODE 8" with exit 0. Three independent defects produced that:
#
#   E1  pred was INNER-joined onto gold, so every document the annotator failed on left the
#       denominator. Failing the hard cases RAISED the reported κ. (The `g.notna()` mask was
#       also dead code after `.fillna("")`.)
#   E1b the resulting single-label column made κ = NaN, and `nan < gate` is False in
#       IEEE-754, so ok_gate was never cleared. "Could not be computed" read as "not below
#       threshold" — the three-valued collapse the gate itself exists to prevent.
#   E2  only the FIRST --on field could fail the gate; a secondary field at κ=0.000 printed
#       FAIL and still exited 0.
#
# Each case below is the negative fixture for one of those, plus a positive control so the
# gate cannot be "fixed" by simply always failing. Per handoff §2, every guard is stated as
# FIRES ON / SLIPS PAST:
#   FIRES ON  — coverage below --min-coverage; undefined κ; any gated field below --gate;
#               absent instrument provenance.
#   SLIPS PAST — gold rows with an empty gold label (correctly excluded, and counted in
#               excluded_by.gold_empty); a genuinely good annotator (positive control).

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENG="${REPO_ROOT}/.claude/skills/scholar-annotate/assets/annotate_engine.py"
PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== annotate_engine.py validate — MODE 7 hard gate ==="
echo ""
[ -f "$ENG" ] || { echo "  FAIL: $ENG missing"; exit 1; }

# Dependency probe: pandas + sklearn. Absent -> INERT, never a false PASS (handoff U7:
# a check that passes because it could not look must say so).
if ! python3 -c "import pandas, sklearn" >/dev/null 2>&1; then
  echo "  INERT: pandas/scikit-learn unavailable — gate fixtures not runnable here"
  echo ""
  echo "════════════════════"
  echo "Results: 0 passed, 0 failed (INERT — missing python deps)"
  exit 0
fi

TMP="$(mktemp -d -t annotgate.XXXXXX)"; trap 'rm -rf "$TMP"' EXIT

# ---- fixture builder -------------------------------------------------------------
# mk <dir> <n_total> <n_failed> <frame_mode>
#   n_failed rows are absent from pred entirely (annotator failure).
#   frame_mode=good -> pred frame matches gold; bad -> pred frame always F1.
mk() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import csv, os, sys
d, n, nfail, frame_mode = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
os.makedirs(d, exist_ok=True)
gold, pred = [], []
for i in range(n):
    hard = i < nfail
    g_rel = "B" if i % 3 == 0 else "A"
    g_frm = "F1" if i % 2 == 0 else "F2"
    gold.append({"video_id": f"v{i}", "relevance": g_rel, "frame": g_frm})
    if hard:
        continue                                  # annotator produced nothing for this row
    pred.append({"video_id": f"v{i}", "relevance": g_rel,
                 "frame": g_frm if frame_mode == "good" else "F1"})
for name, rows in (("gold.csv", gold), ("pred.csv", pred)):
    with open(os.path.join(d, name), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["video_id", "relevance", "frame"])
        w.writeheader(); w.writerows(rows)
PY
}

run() { # run <dir> [extra args...] ; echoes rc, leaves stdout in $TMP/out
  local d="$1"; shift
  ( cd "$d" && python3 "$ENG" validate --pred pred.csv --gold gold.csv \
      --id-col video_id --on relevance,frame --gate 0.70 \
      --out report.json "$@" ) > "$TMP/out" 2>&1
  echo $?
}

# ---- 1. E1/E1b: annotator fails 40% of documents ---------------------------------
A="$TMP/coverage"; mk "$A" 100 40 good
RC=$(run "$A" --no-instrument)
[ "$RC" -eq 2 ] && pass "40% annotator failure → RED (rc 2)" || fail "40% failure: expected rc2, got $RC"
grep -q "coverage 60.0% < 95%" "$TMP/out" \
  && pass "coverage loss is REPORTED, not silently absorbed" \
  || fail "coverage reason line absent"
python3 - "$A/report.json" <<'PY' && pass "gold is the denominator (n_gold_labeled=100, n_scored=60)" || fail "denominator still the intersection"
import json,sys
r=json.load(open(sys.argv[1]))["fields"]["relevance"]
sys.exit(0 if r["n_gold_labeled"]==100 and r["n_scored"]==60 and r["n_unscored"]==40 else 1)
PY
python3 - "$A/report.json" <<'PY' && pass "each exclusion names its deciding branch (excluded_by)" || fail "excluded_by companion missing/incomplete"
import json,sys
e=json.load(open(sys.argv[1]))["fields"]["relevance"]["excluded_by"]
sys.exit(0 if e.get("annotator_absent")==40 and set(e)>={"annotator_absent","annotator_blank","gold_empty"} else 1)
PY

# ---- 2. E1b: an undefined κ must never pass --------------------------------------
B="$TMP/degenerate"; python3 - "$B" <<'PY'
import csv, os, sys
d = sys.argv[1]; os.makedirs(d, exist_ok=True)
# Every scored row is the same label on both sides -> κ undefined (0/0), coverage 100%.
gold = [{"video_id": f"v{i}", "relevance": "A", "frame": "F1"} for i in range(50)]
for name, rows in (("gold.csv", gold), ("pred.csv", list(gold))):
    with open(os.path.join(d, name), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["video_id", "relevance", "frame"]); w.writeheader(); w.writerows(rows)
PY
RC=$(run "$B" --no-instrument)
[ "$RC" -eq 2 ] && pass "undefined κ (single label, full coverage) → RED (rc 2)" || fail "undefined κ: expected rc2, got $RC"
grep -q "κ undefined" "$TMP/out" && pass "undefined κ is named as such, not printed as a number" || fail "undefined κ not surfaced"

# ---- 3. E2: a non-primary field below the gate must block ------------------------
C="$TMP/secondary"; mk "$C" 100 0 bad
RC=$(run "$C" --no-instrument)
[ "$RC" -eq 2 ] && pass "secondary field κ≈0 with perfect primary → RED (rc 2)" || fail "secondary field: expected rc2, got $RC"
# and --primary-only restores the documented legacy behaviour, explicitly and auditably
RC=$(run "$C" --no-instrument --primary-only)
[ "$RC" -eq 0 ] && pass "--primary-only opt-out still passes (back-compat preserved)" || fail "--primary-only: expected rc0, got $RC"
python3 - "$C/report.json" <<'PY' && pass "the primary-only choice is recorded on the artifact" || fail "primary_only not recorded"
import json,sys
sys.exit(0 if json.load(open(sys.argv[1]))["gate"]["primary_only"] is True else 1)
PY

# ---- 4. positive control: a good annotator still clears ---------------------------
D="$TMP/good"; mk "$D" 100 0 good
RC=$(run "$D" --no-instrument)
[ "$RC" -eq 0 ] && pass "positive control: full coverage, κ=1.0 both fields → GREEN (rc 0)" || fail "positive control: expected rc0, got $RC"

# ---- 5. instrument provenance is required unless explicitly waived ---------------
RC=$(run "$D")
[ "$RC" -eq 2 ] && pass "absent instrument provenance → RED (rc 2)" || fail "no-manifest: expected rc2, got $RC"
grep -q "instrument provenance absent" "$TMP/out" && pass "instrument REASON explains how to satisfy it" || fail "instrument reason line absent"
cat > "$D/codebook.md" <<'EOF'
# codebook
relevance: A | B
EOF
cat > "$D/run.json" <<EOF
{"instrument_id":"rel-v3","codebook":"$D/codebook.md",
 "provider":{"strategy":"local","provider":"local","model":"glm-5.2","api_base":"http://127.0.0.1:8080/v1"}}
EOF
RC=$(run "$D" --manifest "$D/run.json" --program-hash abc123)
[ "$RC" -eq 0 ] && pass "declared instrument + good annotator → GREEN (rc 0)" || fail "with manifest: expected rc0, got $RC"
python3 - "$D/report.json" <<'PY' && pass "instrument block carries id, model and codebook sha256" || fail "instrument block incomplete"
import json,sys
i=json.load(open(sys.argv[1]))["instrument"]
sys.exit(0 if i.get("declared") and i.get("instrument_id")=="rel-v3" and i.get("model")=="glm-5.2"
         and i.get("codebook_sha256") else 1)
PY

# ---- 6. the report must be strict JSON (NaN is not) ------------------------------
# Uses the DEGENERATE fixture deliberately: its kappa is undefined, so this is the report
# that WOULD carry a bare NaN if allow_nan=False were removed. Pointing this at a report
# with a defined kappa (as an earlier version did) made the assertion vacuous — it could
# not catch its own regression. Confirm the null is actually there first.
python3 - "$B/report.json" <<'PYN' && pass "the degenerate fixture really does carry a null kappa (probe is live)" || fail "probe fixture has a defined kappa — the JSON check below would be vacuous"
import json,sys
r=json.load(open(sys.argv[1]))["fields"]["relevance"]
sys.exit(0 if r["cohen_kappa"] is None else 1)
PYN
python3 - "$B/report.json" <<'PY' && pass "report parses as strict JSON (no bare NaN)" || fail "report emits non-standard JSON constants"
import json,sys
def boom(x): raise ValueError(x)
json.load(open(sys.argv[1]), parse_constant=boom)
PY

# ---- 7. a gold row with no gold label is excluded, not counted against ----------
E="$TMP/goldblank"; mk "$E" 100 0 good
python3 - "$E" <<'PY'
import csv, sys
d=sys.argv[1]
rows=list(csv.DictReader(open(f"{d}/gold.csv")))
for r in rows[:10]: r["relevance"]=""          # 10 rows genuinely lack ground truth
with open(f"{d}/gold.csv","w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=["video_id","relevance","frame"]); w.writeheader(); w.writerows(rows)
PY
RC=$(run "$E" --no-instrument)
[ "$RC" -eq 0 ] && pass "blank gold labels excluded from the denominator → still GREEN" || fail "gold_empty: expected rc0, got $RC"
python3 - "$E/report.json" <<'PY' && pass "gold_empty exclusions are counted separately from failures" || fail "gold_empty not distinguished"
import json,sys
r=json.load(open(sys.argv[1]))["fields"]["relevance"]
sys.exit(0 if r["n_gold_labeled"]==90 and r["excluded_by"]["gold_empty"]==10
         and r["excluded_by"]["annotator_absent"]==0 else 1)
PY


# ---- 8. defects found by INDEPENDENT external audit (2026-08-12) -----------------
# Each of these passed the author's own fixtures and was found only by a cross-model
# review. They are pinned here so they cannot silently return.

# C1: an empty --on list assessed NOTHING and exited 0 "cleared for MODE 8" — the exact
# not-assessed-reads-as-assessed collapse this gate exists to prevent, committed inside
# the fix for it.
RC=$(run "$D" --no-instrument --on ',,')
[ "$RC" -eq 2 ] && pass "empty --on list → RED (assessing zero fields is not a pass)" \
                || fail "empty --on: expected rc2, got $RC"
grep -q "no_fields_to_validate" "$TMP/out" && pass "the empty-field RED names its reason" || fail "no reason for empty --on"

# H1: a parseable but EMPTY manifest was accepted as declared provenance, yielding a
# GREEN report whose instrument block identified nothing.
echo '{}' > "$D/empty-manifest.json"
RC=$(run "$D" --manifest "$D/empty-manifest.json")
[ "$RC" -eq 2 ] && pass "empty manifest {} → RED (provenance that identifies nothing is not provenance)" \
                || fail "empty manifest: expected rc2, got $RC"

# H4: duplicate ids row-weighted kappa and the coverage denominator.
mk "$TMP/dup" 40 0 good
python3 - "$TMP/dup" <<'PYD'
import csv, sys
d = sys.argv[1]
rows = list(csv.DictReader(open(f"{d}/gold.csv")))
rows += [dict(rows[0]) for _ in range(20)]      # 20 duplicates of one document
with open(f"{d}/gold.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["video_id", "relevance", "frame"]); w.writeheader(); w.writerows(rows)
PYD
RC=$(run "$TMP/dup" --no-instrument)
[ "$RC" -eq 2 ] && pass "duplicate ids → RED (duplicates reweight kappa and coverage)" \
                || fail "duplicate ids: expected rc2, got $RC"

# M: fail-open thresholds were honoured silently.
# Assert the REASON, not just rc: `--gate 2` exits 2 anyway because any kappa is below 2,
# so an rc-only assertion passes even with threshold validation removed (vacuous).
for BAD in "--gate -1" "--min-coverage -0.5" "--gate 2" "--min-coverage 1.5"; do
  RC=$(run "$D" --no-instrument $BAD)
  if [ "$RC" -eq 2 ] && grep -q "REASON=invalid_threshold" "$TMP/out"; then
    pass "invalid threshold ($BAD) → RED with REASON=invalid_threshold"
  else
    fail "threshold $BAD: expected rc2 + REASON=invalid_threshold, got rc=$RC"
  fi
done
# control: the boundary values 0.0 and 1.0 are VALID and must not be rejected as invalid
for OK_T in "--gate 1.0" "--min-coverage 1.0" "--gate 0.0"; do
  RC=$(run "$D" --no-instrument $OK_T)
  grep -q "REASON=invalid_threshold" "$TMP/out" \
    && fail "valid boundary threshold $OK_T was rejected as invalid" \
    || pass "valid boundary threshold $OK_T is accepted"
done

# M: join-key / indicator collisions produced tracebacks instead of a structured verdict.
RC=$(run "$D" --no-instrument --on video_id)
[ "$RC" -eq 2 ] && pass "--on naming the join key → structured RED, not a traceback" || fail "id-col collision: expected rc2, got $RC"

# H: the report schema changed shape; consumers need a version to branch on.
RC=$(run "$D" --manifest "$D/run.json")
python3 - "$D/report.json" <<'PYS' && pass "report carries schema_version for consumers" || fail "no schema_version in the report"
import json, sys
sys.exit(0 if json.load(open(sys.argv[1])).get("schema_version") == 2 else 1)
PYS


# ---- ROUND-2 audit: --min-coverage 0 was still fail-open ------------------------
# A stderr warning is not a control: warnings are lost in logs. Disabling the coverage
# check now requires an explicit flag, and the waiver is stamped on the artifact (DC-05).
RC=$(run "$D" --no-instrument --min-coverage 0)
[ "$RC" -eq 2 ] && pass "--min-coverage 0 alone → RED (coverage check cannot be silently disabled)" \
                || fail "min-coverage 0: expected rc2, got $RC"
grep -q "coverage_check_disabled" "$TMP/out" && pass "the zero-coverage RED names its reason" || fail "no reason for zero coverage"
RC=$(run "$D" --no-instrument --min-coverage 0 --allow-zero-coverage)
[ "$RC" -eq 0 ] && pass "--allow-zero-coverage is an explicit, honoured opt-in" || fail "allow-zero-coverage: expected rc0, got $RC"
python3 - "$D/report.json" <<'PYW' && pass "the coverage waiver is recorded on the artifact" || fail "waiver not recorded"
import json, sys
sys.exit(0 if json.load(open(sys.argv[1]))["gate"]["coverage_check_waived"] is True else 1)
PYW

echo ""
echo "════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
