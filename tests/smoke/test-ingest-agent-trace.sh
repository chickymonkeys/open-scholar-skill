#!/usr/bin/env bash
# Regression test for ingest-agent-trace.sh — fold a Write-only agent's RAO
# sidecar into the master trace. Verifies: records land with agent=<type> +
# agentId stamped, seq monotonic in the master, malformed lines skipped,
# zero-valid-records fails loud, and agentId cross-checks the dispatch manifest.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ING="$REPO_ROOT/scripts/gates/ingest-agent-trace.sh"
EMIT="$REPO_ROOT/scripts/gates/emit-trace.sh"
for f in "$ING" "$EMIT"; do [ -f "$f" ] || { echo "FATAL: missing $f"; exit 1; }; done
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 needed"; exit 0; }

FAILS=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; FAILS=$((FAILS + 1)); }
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ingesttrace.XXXXXX"); trap 'rm -rf "$TMP"' EXIT
OR="$TMP/output"; PROJ="$TMP/proj"; DATE=$(date +%Y-%m-%d)
AID="a1b2c3d4e5f6a7b8"
mkdir -p "$PROJ/logs" "$PROJ/reviews"

bash -n "$ING" && ok "ingest-agent-trace.sh parses" || bad "syntax error"

SC="$PROJ/reviews/report.md.trace.ndjson"
printf '%s\n' \
  '{"step":"read-scripts","reasoning":"scan for clustering","action":"grep feols","observation":"3 models","refs":["scripts/04.R"],"status":"ok"}' \
  '{"step":"verdict","reasoning":"missing FE","action":"assess","observation":"1 CRITICAL","status":"fail"}' \
  '{bad json}' > "$SC"
printf '{"ts":"2026-07-13T00:00:00Z","agentId":"%s","subagent":"review-code-correctness","purpose":"code review","manuscript_sha256":"null","phase":"5.5"}\n' "$AID" > "$PROJ/logs/dispatch-manifest.jsonl"

OUT=$(OUTPUT_ROOT="$OR" bash "$ING" --sidecar "$SC" --skill scholar-code-review \
        --agent review-code-correctness --agentId "$AID" --phase 5.5 --proj "$PROJ" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "ingest succeeds (rc=0)" || bad "ingest failed rc=$rc"
printf '%s' "$OUT" | grep -q 'INGESTED=2' && ok "ingested exactly the 2 valid records" || bad "wrong ingest count"
printf '%s' "$OUT" | grep -q 'AGENTID_BOUND=yes' && ok "agentId cross-checked against dispatch manifest" || bad "agentId not cross-checked"

TR="$OR/logs/trace-scholar-code-review-$DATE.ndjson"
CHECK=$(python3 -c "
import json
rows=[json.loads(l) for l in open('$TR') if l.strip()]
seqs=[r['seq'] for r in rows]
agents=set(r['agent'] for r in rows)
aids=set(r['agentId'] for r in rows)
print('OK' if seqs==[1,2] and agents=={'review-code-correctness'} and aids=={'$AID'} else 'BAD:'+str(seqs)+str(agents)+str(aids))")
[ "$CHECK" = "OK" ] && ok "master trace: seq [1,2], agent + agentId stamped" || bad "master trace wrong: $CHECK"

# Zero valid records -> fail loud.
printf '{bad}\n' > "$TMP/empty.ndjson"
OUTPUT_ROOT="$OR" bash "$ING" --sidecar "$TMP/empty.ndjson" --skill s --agent a --agentId "$AID" >/dev/null 2>&1
[ $? -eq 1 ] && ok "zero valid records -> rc 1 (fail loud)" || bad "empty sidecar not rejected"

# Missing sidecar -> fail.
OUTPUT_ROOT="$OR" bash "$ING" --sidecar "$TMP/nope.ndjson" --skill s --agent a --agentId "$AID" >/dev/null 2>&1
[ $? -eq 1 ] && ok "missing sidecar -> rc 1" || bad "missing sidecar not rejected"

# agentId absent from manifest -> non-blocking WARN, still succeeds.
OUT2=$(OUTPUT_ROOT="$OR" bash "$ING" --sidecar "$SC" --skill scholar-code-review \
        --agent review-code-correctness --agentId "zzz9zzz9zzz9zzz9" --phase 5.5 --proj "$PROJ" 2>&1); rc2=$?
{ [ "$rc2" -eq 0 ] && printf '%s' "$OUT2" | grep -q 'AGENTID_BOUND=no'; } \
  && ok "unbound agentId -> non-blocking WARN (still rc 0)" || bad "unbound agentId handling wrong (rc=$rc2)"

echo ""
if [ "$FAILS" -eq 0 ]; then echo "ALL ingest-agent-trace checks passed"; exit 0
else echo "$FAILS ingest-agent-trace check(s) FAILED"; exit 1; fi
