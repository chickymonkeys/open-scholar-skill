#!/usr/bin/env bash
# test-proj-guard-auto-research-state.sh — auto-research-state.sh must not create a
# project directory for an option-like, empty, or nonexistent PROJ (plan 2026-09-06 P-A4).
#
# BEFORE (measured 2026-09-06): `auto-research-state.sh status --help` exited 1 with
# "state missing: run init first for --help" AND left ./--help/.auto-research/state.lock
# behind — the state machine opens the lock before dispatching. That is how a `--help/`
# directory appeared at the repository root on 2026-08-28. Same for any typo'd path.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARS="$REPO_ROOT/.claude/skills/scholar-auto-research/scripts/auto-research-state.sh"
PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
[ -f "$ARS" ] || { echo "FATAL: missing $ARS"; exit 1; }
W="$(mktemp -d -t ars-guard.XXXXXX)"; trap 'rm -rf "$W"' EXIT
cd "$W"

echo "T1: option-like PROJ is a usage error and creates nothing"
bash "$ARS" status --help >out 2>&1; rc=$?
[ "$rc" -eq 2 ] && pass "rc=2" || fail "rc=$rc (want 2): $(head -1 out)"
[ ! -e "$W/--help" ] && pass "no ./--help created" || fail "./--help/ was created (the 2026-08-28 artifact)"

echo "T2: empty PROJ is a usage error"
bash "$ARS" status "" >out 2>&1; rc=$?
[ "$rc" -eq 2 ] && pass "rc=2" || fail "rc=$rc (want 2)"

echo "T3: nonexistent PROJ with a non-init verb → same 'state missing' message, rc 1, nothing created"
bash "$ARS" status "$W/nope/proj" >out 2>&1; rc=$?
[ "$rc" -eq 1 ] && pass "rc=1 (unchanged)" || fail "rc=$rc (want 1)"
grep -q 'state missing: run init first for' out && pass "message unchanged" || fail "message changed: $(head -1 out)"
[ ! -e "$W/nope" ] && pass "no directory created" || fail "$W/nope was created"

echo "T4: init on a new path still creates the project (rc 0)"
bash "$ARS" init "$W/newproj" >out 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ -d "$W/newproj/.auto-research" ] && pass "init unchanged" || fail "init rc=$rc, dir=$([ -d "$W/newproj/.auto-research" ] && echo yes || echo no)"

echo "T5: existing dir without state → unchanged behaviour (rc 1, 'state missing')"
mkdir -p "$W/exists"
bash "$ARS" status "$W/exists" >out 2>&1; rc=$?
[ "$rc" -eq 1 ] && grep -q 'state missing' out && pass "rc=1 + message unchanged" || fail "rc=$rc: $(head -1 out)"

echo ""
echo "test-proj-guard-auto-research-state: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
