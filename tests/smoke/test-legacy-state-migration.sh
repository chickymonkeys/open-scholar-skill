#!/usr/bin/env bash
# test-legacy-state-migration.sh — a scholar-auto-research project created under state
# schema 1.1.0 can be migrated to the installed contract instead of being refused forever
# (2026-09-01 resume plan §A8; shipped 2026-09-06).
#
# BEFORE (measured on output/loop-livetest-hukou): schema 1.1.0, recorded contract
# 099756bf…, installed beb6125a… → every command answered CONTRACT_DRIFT and
# migration-status said "no allowlisted migration matches". Named outside the
# test-auto-research* glob on purpose (the packaged coverage manifest reserves that prefix).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STATE="$REPO_ROOT/.claude/skills/scholar-auto-research/scripts/auto-research-state.sh"
PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
[ -f "$STATE" ] || { echo "FATAL: missing $STATE"; exit 1; }
TMP="$(mktemp -d -t legacymig.XXXXXX)"; trap 'rm -rf "$TMP"' EXIT
MIG=legacy-state-1.1.0-backfill-v1
LEGACY_SHA=099756bfdee1ba0f04b1cfb9f1947f646ac252e64f9e5fe3177aa13a8aea7771

make_legacy() {  # <proj>: init a current-schema project, then rewrite its state to the 1.1.0 shape
  local P="$1"; mkdir -p "$P"; bash "$STATE" init "$P" >/dev/null 2>&1 || return 1
  python3 - "$P/.auto-research/state.json" "$LEGACY_SHA" <<'PY'
import json, sys
p, sha = sys.argv[1], sys.argv[2]; s = json.load(open(p))
for k in ("run_nonce","halted","halt","halt_history","safety_blocked","safety_inventory","review_assurance_profile","review_attempt_epochs","review_evidence_history","contract_migration_history"):
    s.pop(k, None)
s["schema_version"] = "1.1.0"; s["contract_sha256"] = sha
json.dump(s, open(p, "w"), indent=2)
PY
}

echo "T1: BEFORE — a 1.1.0 state is refused with CONTRACT_DRIFT and no eligible migration existed before this entry"
make_legacy "$TMP/a" || { fail "could not build the legacy fixture"; echo "test-legacy-state-migration: $PASS passed, $FAIL failed"; exit 1; }
OUT=$(bash "$STATE" next "$TMP/a" 2>&1); RC=$?
[ "$RC" -ne 0 ] && printf '%s\n' "$OUT" | grep -c 'CONTRACT_DRIFT' >/dev/null && pass "next → CONTRACT_DRIFT (rc=$RC)" || fail "legacy state was not refused (rc=$RC)"
MS=$(bash "$STATE" migration-status "$TMP/a" 2>&1)
printf '%s\n' "$MS" | python3 -c "import json,sys; j=json.load(sys.stdin); assert j['contract_drift'] is True and '$MIG' in j['eligible_migration_ids'] and j['state_schema']=='1.1.0'" \
  && pass "migration-status: drift=true, $MIG eligible" || { fail "migration-status did not offer the legacy migration"; printf '%s\n' "$MS" | head -8; }

echo "T2: migrate-contract applies the allowlisted legacy migration and backfills the 1.3.0 fields"
OUT=$(bash "$STATE" migrate-contract "$TMP/a" "$MIG" --operator test-operator --reason "legacy 1.1.0 backfill" 2>&1); RC=$?
[ "$RC" -eq 0 ] && pass "migrate-contract rc=0" || { fail "migrate-contract rc=$RC: $(printf '%s\n' "$OUT" | tail -2 | tr '\n' ' ')"; }
python3 - "$TMP/a/.auto-research/state.json" <<'PY' && pass "schema 1.3.0, installed contract, all backfilled fields present, review evidence invalidated" || fail "post-migration state shape wrong"
import json, sys
s = json.load(open(sys.argv[1]))
assert s["schema_version"] == "1.3.0", s["schema_version"]
assert s["contract_sha256"] == "beb6125aa0b17e6505f99cc8950dc0a87a355f6ab5f886ef7b3f77b4702028f4"
for k in ("run_nonce","halted","halt","halt_history","safety_blocked","safety_inventory","review_assurance_profile","review_attempt_epochs","review_evidence_history","contract_migration_history"):
    assert k in s, k
assert s["halted"] is False and s["halt"] is None and s["review_assurance_profile"] == "normal"
assert len(s["run_nonce"]) == 32
assert s["contract_migration_history"][-1]["migration_id"] == "legacy-state-1.1.0-backfill-v1"
PY
OUT=$(bash "$STATE" next "$TMP/a" 2>&1); RC=$?
printf '%s\n' "$OUT" | grep -c 'CONTRACT_DRIFT' >/dev/null && fail "still CONTRACT_DRIFT after migration" || pass "next runs after migration (rc=$RC: $(printf '%s\n' "$OUT" | grep -E '^NEXT_PHASE=' | head -1))"
OUT=$(bash "$STATE" hash-check "$TMP/a" 2>&1); RC=$?
[ "$RC" -eq 0 ] && pass "hash-check rc=0" || fail "hash-check rc=$RC: $(printf '%s\n' "$OUT" | head -1)"

echo "T3: negative control — the legacy entry does not apply to a 1.2.0 state (predecessor mismatch)"
mkdir -p "$TMP/b"; bash "$STATE" init "$TMP/b" >/dev/null 2>&1
python3 - "$TMP/b/.auto-research/state.json" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p)); s["schema_version"] = "1.2.0"; s["contract_sha256"] = "c73cabcadc74bd09a29df2ccef4473349c02eded6d74e82fc8a756999f90db70"; json.dump(s, open(p, "w"), indent=2)
PY
OUT=$(bash "$STATE" migrate-contract "$TMP/b" "$MIG" --operator test-operator --reason "wrong source" 2>&1); RC=$?
[ "$RC" -ne 0 ] && printf '%s\n' "$OUT" | grep -c 'PREDECESSOR_MISMATCH' >/dev/null && pass "refused: CONTRACT_MIGRATION_PREDECESSOR_MISMATCH" || fail "legacy entry applied to a non-1.1.0 state (rc=$RC)"

echo "T4: the registry still targets the installed contract (every entry's to_contract_sha256 == on-disk contract)"
INST=$(shasum -a 256 "$REPO_ROOT/.claude/skills/scholar-auto-research/references/phase-contract.json" | cut -d' ' -f1)
python3 -c "import json,sys; m=json.load(open(sys.argv[1])); bad=[e['id'] for e in m['migrations'] if e['to_contract_sha256']!=sys.argv[2]]; assert not bad, bad" "$REPO_ROOT/.claude/skills/scholar-auto-research/references/contract-migrations.json" "$INST" \
  && pass "4 entries all target $INST" || fail "an entry targets a stale contract"

echo ""
echo "test-legacy-state-migration: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
