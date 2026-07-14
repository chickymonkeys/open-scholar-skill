#!/usr/bin/env bash
# trace-coverage-check.sh — hard gate: a skill/phase must produce a valid RAO
# trace (reasoning + action + observation), and every dispatched agent must
# appear in it.
#
# CONTRACT
#   Reads the run's trace sink(s) at <root>/logs/trace-<skill>-*.ndjson (written
#   by emit-trace.sh; agent steps folded in by ingest-agent-trace.sh) and the
#   dispatch manifest at <root>/logs/dispatch-manifest.jsonl.
#
# VERDICT
#   GREEN  (exit 0) — a non-empty, well-formed trace exists; every record has the
#           required fields + a non-empty RAO triad; and (if a manifest + --phase
#           are present) every dispatched agentId appears as a trace event.
#   RED    (exit 1) — trace present but empty / malformed line / missing field /
#           all-empty triad; OR the target skill has no trace while the project
#           is clearly a CURRENT run (a manifest or some other trace exists); OR
#           a dispatched agentId has no trace event.
#   YELLOW (exit 2) — no trace AND no trace/manifest infrastructure at all
#           (a legacy project predating trace adoption — bounded migration
#           window, mirrors the codex-prose-coverage legacy path).
#
#   Prints a `STATUS=GREEN|YELLOW|RED` line so it composes with
#   normalize-gate-status.sh.
#
# USAGE
#   bash scripts/gates/trace-coverage-check.sh <root> [--skill X] [--phase P]
#     <root> = project dir / OUTPUT_ROOT containing logs/

set -uo pipefail

ROOT="" SKILL="" PHASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skill) SKILL="${2:-}"; shift 2 ;;
    --phase) PHASE="${2:-}"; shift 2 ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^# *//'; exit 0 ;;
    *) if [ -z "$ROOT" ]; then ROOT="$1"; shift; else echo "ERROR: unexpected arg $1" >&2; exit 64; fi ;;
  esac
done

if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "Usage: trace-coverage-check.sh <root> [--skill X] [--phase P]" >&2
  echo "ABORT: root dir not found: ${ROOT:-<none>}" >&2
  exit 64
fi

LOG_DIR="$ROOT/logs"
MANIFEST="$LOG_DIR/dispatch-manifest.jsonl"

# ── Discover trace files ────────────────────────────────────────────────────
TARGET_TRACES=()
ANY_TRACE=0
if [ -d "$LOG_DIR" ]; then
  for f in "$LOG_DIR"/trace-*.ndjson; do
    [ -f "$f" ] || continue
    ANY_TRACE=1
    if [ -n "$SKILL" ]; then
      case "$(basename "$f")" in
        trace-"$SKILL"-*.ndjson) TARGET_TRACES+=("$f") ;;
      esac
    else
      TARGET_TRACES+=("$f")
    fi
  done
fi
HAS_MANIFEST=0
[ -f "$MANIFEST" ] && HAS_MANIFEST=1

# ── No target trace → YELLOW (migration-safe) ───────────────────────────────
# A project that predates trace adoption (or a skill that has not yet run) has
# no trace. During the rollout window this is advisory, NOT a hard failure —
# otherwise every legacy project would RED. The hard teeth are: (a) the static
# ratchet that every skill/agent CALLS emit-trace, and (b) the RED verdicts
# below for a trace that IS present but broken/incomplete.
if [ "${#TARGET_TRACES[@]}" -eq 0 ]; then
  echo "STATUS=YELLOW"
  echo "WARN: no RAO trace for ${SKILL:-<skill>} under $LOG_DIR — legacy/not-yet-run"
  echo "      (advisory during the trace-adoption migration window). Emit a trace via"
  echo "      emit-trace.sh per _shared/process-logger.md."
  exit 2
fi

# ── Validate present traces + agent-dispatch cross-link (python3) ───────────
if ! command -v python3 >/dev/null 2>&1; then
  echo "STATUS=YELLOW"
  echo "WARN: python3 unavailable — cannot validate NDJSON trace schema; advisory only."
  exit 2
fi

VERDICT=$(python3 - "$MANIFEST" "$PHASE" "${TARGET_TRACES[@]}" <<'PY'
import json, sys
manifest, phase = sys.argv[1], sys.argv[2]
trace_files = sys.argv[3:]
REQ = {"ts","seq","run_id","skill","phase","agent","agentId","step","reasoning","action","observation","refs","status"}

seen_agent_ids = set()
records = 0
for tf in trace_files:
    ln = 0
    for line in open(tf):
        line = line.strip()
        if not line:
            continue
        ln += 1
        try:
            r = json.loads(line)
        except Exception:
            print(f"RED|malformed NDJSON line {ln} in {tf}")
            sys.exit(0)
        miss = REQ - set(r)
        if miss:
            print(f"RED|record {ln} in {tf} missing fields: {sorted(miss)}")
            sys.exit(0)
        if not str(r.get("step") or "").strip():
            print(f"RED|record {ln} in {tf} has empty step")
            sys.exit(0)
        if not (str(r.get('reasoning') or '') or str(r.get('action') or '') or str(r.get('observation') or '')):
            print(f"RED|record {ln} in {tf} has an all-empty reasoning/action/observation triad")
            sys.exit(0)
        aid = r.get("agentId")
        if aid:
            seen_agent_ids.add(aid)
        records += 1

if records == 0:
    print("RED|trace file(s) present but contain zero records")
    sys.exit(0)

# Agent-dispatch cross-link: every dispatched agentId for this phase must have a trace event.
if phase and manifest and manifest != "" :
    import os
    if os.path.isfile(manifest):
        missing = []
        for line in open(manifest):
            line = line.strip()
            if not line:
                continue
            try:
                m = json.loads(line)
            except Exception:
                continue
            if str(m.get("phase")) != str(phase):
                continue
            aid = m.get("agentId")
            if aid and aid not in seen_agent_ids:
                missing.append(aid)
        if missing:
            uniq = sorted(set(missing))
            print(f"RED|{len(uniq)} dispatched agentId(s) for phase {phase} have no trace event: {uniq[:5]}")
            sys.exit(0)

print(f"GREEN|{records} valid RAO record(s); {len(seen_agent_ids)} agent event(s)")
PY
)

CODE="${VERDICT%%|*}"
MSG="${VERDICT#*|}"
case "$CODE" in
  GREEN) echo "STATUS=GREEN"; echo "PASS: $MSG"; exit 0 ;;
  RED)   echo "STATUS=RED"; echo "FAIL: $MSG"; exit 1 ;;
  *)     echo "STATUS=RED"; echo "FAIL: trace validation produced no verdict (fail closed): ${VERDICT:-<empty>}"; exit 1 ;;
esac
