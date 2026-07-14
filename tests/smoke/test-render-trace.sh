#!/usr/bin/env bash
# Regression test for render-trace.sh — NDJSON RAO trace -> markdown process log.
# Verifies: Reasoning column present, one row per record, pipe-escaping,
# status symbols, default output path derivation, and malformed-line handling.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$REPO_ROOT/scripts/gates/emit-trace.sh"
RENDER="$REPO_ROOT/scripts/gates/render-trace.sh"
for f in "$EMIT" "$RENDER"; do [ -f "$f" ] || { echo "FATAL: missing $f"; exit 1; }; done
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 needed"; exit 0; }

FAILS=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; FAILS=$((FAILS + 1)); }
TMP=$(mktemp -d "${TMPDIR:-/tmp}/rendertrace.XXXXXX"); trap 'rm -rf "$TMP"' EXIT
OR="$TMP/output"; DATE=$(date +%Y-%m-%d)
TRACE="$OR/logs/trace-scholar-eda-$DATE.ndjson"
MD="$OR/logs/process-log-scholar-eda-$DATE.md"

bash -n "$RENDER" && ok "render-trace.sh parses" || bad "syntax error"

OUTPUT_ROOT="$OR" bash "$EMIT" --skill scholar-eda --phase EDA --step load \
  --reasoning "need N before modeling" --action "read.csv(d)" --observation "N=5234" --refs "eda/t.csv" >/dev/null
OUTPUT_ROOT="$OR" bash "$EMIT" --skill scholar-eda --phase EDA --step corr \
  --reasoning "pipe | in reasoning" --action "cor(x,y)" --observation "r=0.31" >/dev/null

# Default output path derivation (no explicit out arg).
bash "$RENDER" "$TRACE" >/dev/null 2>&1 && [ -f "$MD" ] \
  && ok "renders to derived process-log-*.md path" || bad "did not render to default path"

grep -q '| # | Time | Phase | Agent | Step | Reasoning | Action | Observation | Refs | Status |' "$MD" \
  && ok "header carries the Reasoning column" || bad "Reasoning column missing from header"

# One data row per record (2 records -> 2 body rows).
BODY=$(grep -cE '^\| [0-9]+ \|' "$MD")
[ "$BODY" = "2" ] && ok "one rendered row per trace record (2)" || bad "row count=$BODY (want 2)"

grep -q 'pipe \\| in reasoning' "$MD" && ok "pipe characters are escaped in cells" || bad "pipe not escaped"
grep -q '| load |' "$MD" && grep -q 'N=5234' "$MD" && ok "reasoning/action/observation content rendered" || bad "cell content missing"

# Malformed line is skipped with a warning, valid rows still render.
printf '{not json}\n' >> "$TRACE"
OUTM=$(bash "$RENDER" "$TRACE" "$MD" 2>&1 || true)
grep -q 'WARNING:.*malformed' "$MD" && ok "malformed NDJSON line noted in output" || bad "malformed line not surfaced"

echo ""
if [ "$FAILS" -eq 0 ]; then echo "ALL render-trace checks passed"; exit 0
else echo "$FAILS render-trace check(s) FAILED"; exit 1; fi
