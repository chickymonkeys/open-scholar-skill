#!/usr/bin/env bash
# test-scholar-simulate-dryrun.sh — offline end-to-end contract for the scholar-simulate engine.
#
# Exercises the three stdlib-only paths the smoke layer can run with NO API key and NO
# third-party packages: persona sampling, a --dry-run fan-out (zero API calls), and the MODE 6
# fidelity validator. This is the executable companion to test-scholar-simulate-structure.sh
# (which checks the skill's file/contract surface); here we actually run the engine.
#
# Pipeline under test:
#   1. simulate_engine.py personas  — IPF/raking sampler emits a reproducible persona pool
#   2. simulate_engine.py run --dry-run — builds (condition x persona x item x rep) requests,
#      writes a request preview + cost estimate, makes ZERO calls, exits 0
#   3. simulate_engine.py validate  — scores synthetic responses vs a human benchmark; the
#      fixtures are constructed so synthetic == human on every item → verdict PASS, exit 0
#
# Coverage:
#   D1  personas: command exits 0
#   D2  personas: personas.jsonl has exactly N lines
#   D3  personas: each line carries persona_id + description (the prompt scaffold)
#   D4  run --dry-run: exits 0
#   D5  run --dry-run: requests-preview.jsonl written
#   D6  run --dry-run: cost-estimate.json written and reports the expected request count
#   D7  run --dry-run: NO responses.jsonl produced (zero calls => no checkpoints)
#   D8  validate: exits 0 (hard-gate-friendly) — exact-match fixtures + --allow-missing-subgroup
#   D9  validate: fidelity.json verdict == PASS on exact-match fixtures
#   D10 validate: coverage == 1.0 and item_pass_rate == 1.0 on exact-match fixtures
#   D11 validate: WITHOUT --allow-missing-subgroup, a non-computable subgroup r FAILS (exit 1)
#   D12 validate: a skewed benchmark (distributions far apart) FAILS (exit 1)
#   D13 validate: that skewed run's fidelity.json verdict == FAIL
#   I1  interactive run --dry-run: exits 0 (stdlib only; no langgraph/langchain, no key)
#   I2  interactive run --dry-run: conversation-plan.jsonl written
#   I3  interactive run --dry-run: cost-estimate.json reports expected n_model_calls
#   I4  interactive run --dry-run: NO graph.sqlite and NO transcripts.jsonl (zero calls)

set -uo pipefail

SKILL_ROOT="${SCHOLAR_SKILL_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
ENGINE="$SKILL_ROOT/.claude/skills/scholar-simulate/assets/simulate_engine.py"
RUNNER="$SKILL_ROOT/.claude/skills/scholar-simulate/assets/interactive_runner.py"

# --- preconditions ---------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not available; cannot run the engine contract."; exit 0
fi
if [ ! -f "$ENGINE" ]; then
  echo "FATAL: engine not found: $ENGINE"; exit 1
fi
if [ ! -f "$RUNNER" ]; then
  echo "FATAL: interactive runner not found: $RUNNER"; exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS + 1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

N=8                                  # persona pool size (and the per-item response count)
SPEC="$TMP/spec.json"                # persona spec (joint distribution targets)
PERSONAS="$TMP/personas.jsonl"       # sampled persona pool
ITEMS="$TMP/items.json"             # survey/vignette items
MANIFEST="$TMP/manifest.json"        # run manifest (provider/model/strategy + paths)
CKPT="$TMP/ckpt"                     # checkpoint dir the engine writes into
RESP="$TMP/responses.jsonl"          # synthetic responses (hand-built to match the benchmark)
BENCH="$TMP/benchmark.csv"           # human benchmark (long format)
BENCH_SKEW="$TMP/benchmark-skew.csv" # deliberately mismatched benchmark (forces verdict FAIL)
FIDELITY="$TMP/fidelity.json"        # validator output
FIDELITY_SKEW="$TMP/fidelity-skew.json"  # validator output for the skewed (FAIL) run

# --- fixtures --------------------------------------------------------------
# Persona spec: two categorical variables raked to simple marginals. `source` is mandatory
# provenance for the methods text; the sampler warns (to stderr) without it.
cat > "$SPEC" <<'JSON'
{
  "variables": {
    "age":   {"categories": ["18-44", "45+"]},
    "party": {"categories": ["Dem", "Rep"]}
  },
  "marginals": [
    {"vars": ["age"],   "target": {"18-44": 0.5, "45+": 0.5}},
    {"vars": ["party"], "target": {"Dem": 0.5, "Rep": 0.5}}
  ],
  "context": {"time_period": "2024", "country": "US"},
  "source": "SMOKE-TEST synthetic marginals (not real data)",
  "persona_prefix": "p"
}
JSON

# Items document: a global system prompt, a user-turn template, and two Likert items.
cat > "$ITEMS" <<'JSON'
{
  "system": "You are simulating a survey respondent. Answer with a single integer.",
  "task_template": "{item_text}\n\nOptions: {options}\nReply with ONLY the number.",
  "items": [
    {"item_id": "q1", "text": "Rate your agreement (1-5).", "options": ["1", "2", "3", "4", "5"]},
    {"item_id": "q2", "text": "Rate your concern (1-5).",   "options": ["1", "2", "3", "4", "5"]}
  ]
}
JSON

# Run manifest: anthropic + batch is a valid (provider, strategy) pair; --dry-run never
# constructs a provider client, so no SDK/key is touched. Paths are absolute (cwd-independent).
cat > "$MANIFEST" <<JSON
{
  "provider": "anthropic",
  "model": "claude-haiku-4-5",
  "scale_strategy": "batch",
  "cache": true,
  "n_reps": 1,
  "max_tokens": 16,
  "personas": "$PERSONAS",
  "items": "$ITEMS",
  "checkpoint_dir": "$CKPT",
  "cost_cap_usd": 100
}
JSON

# Synthetic responses: q1 -> {3,4,3,4,...} mean 3.5 ; q2 -> {2,3,2,3,...} mean 2.5.
# custom_id format is "cond|persona_id|item_id|rep" (matches build_requests + validate parsing).
{
  for i in 1 2 3 4 5 6 7 8; do
    pid="$(printf 'p%05d' "$i")"                        # p00001 .. p00008
    if [ $((i % 2)) -eq 1 ]; then q1=3; q2=2; else q1=4; q2=3; fi  # alternate to hit the target means
    printf '{"custom_id": "base|%s|q1|r0", "text": "%s"}\n' "$pid" "$q1"
    printf '{"custom_id": "base|%s|q2|r0", "text": "%s"}\n' "$pid" "$q2"
  done
} > "$RESP"

# Human benchmark (long format item_id,value): q1 -> {3,3,4,4} mean 3.5 ; q2 -> {2,2,3,3} mean 2.5.
# Synthetic means equal human means => mean_diff 0, KS 0, JSD 0, within +/-2SE band => PASS.
cat > "$BENCH" <<'CSV'
item_id,value
q1,3
q1,3
q1,4
q1,4
q2,2
q2,2
q2,3
q2,3
CSV

# Skewed human benchmark: q1 all 1s, q2 all 5s. Synthetic means are 3.5 / 2.5, so |mean_diff|
# is ~2.5 (>> abs_mean_diff_max 0.50), KS/JSD are large, and the all-constant human columns have
# zero SE so nothing falls in the +/-2SE band → coverage 0, item_pass_rate 0 → verdict FAIL.
cat > "$BENCH_SKEW" <<'CSV'
item_id,value
q1,1
q1,1
q1,1
q1,1
q2,5
q2,5
q2,5
q2,5
CSV

# ── Stage 1: personas ──────────────────────────────────────────────
echo "Stage 1: personas (IPF/raking sampler)"
python3 "$ENGINE" personas --spec "$SPEC" --n "$N" --out "$PERSONAS" --seed 42 >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "D1.personas-exit0" || no "D1.personas-exit0 (rc=$rc)"

if [ -f "$PERSONAS" ]; then
  lines=$(grep -c '' "$PERSONAS")
  [ "$lines" -eq "$N" ] && ok "D2.personas-count ($lines==$N)" || no "D2.personas-count ($lines!=$N)"
  if grep -q '"persona_id"' "$PERSONAS" && grep -q '"description"' "$PERSONAS"; then
    ok "D3.personas-fields (persona_id + description present)"
  else
    no "D3.personas-fields (missing persona_id or description)"
  fi
else
  no "D2.personas-count (no personas.jsonl)"
  no "D3.personas-fields (no personas.jsonl)"
fi

# ── Stage 2: run --dry-run ─────────────────────────────────────────
echo "Stage 2: run --dry-run (zero API calls)"
python3 "$ENGINE" run --manifest "$MANIFEST" --dry-run >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "D4.dryrun-exit0" || no "D4.dryrun-exit0 (rc=$rc)"

assert_file(){ [ -f "$2" ] && ok "$1" || no "$1 (missing $2)"; }
assert_file "D5.requests-preview" "$CKPT/requests-preview.jsonl"
assert_file "D6.cost-estimate"    "$CKPT/cost-estimate.json"

# Expected fan-out: 1 condition x N personas x 2 items x 1 rep = 2N requests.
if [ -f "$CKPT/cost-estimate.json" ]; then
  want=$((N * 2))
  if grep -q "\"n_requests\": $want" "$CKPT/cost-estimate.json"; then
    ok "D6b.request-count (n_requests=$want)"
  else
    no "D6b.request-count (expected n_requests=$want in cost-estimate.json)"
  fi
fi

# A dry run makes no calls, so it must NOT write a responses checkpoint.
if [ ! -f "$CKPT/responses.jsonl" ]; then
  ok "D7.no-responses (dry-run wrote no checkpoint)"
else
  no "D7.no-responses (responses.jsonl should not exist after --dry-run)"
fi

# ── Stage 3: validate (MODE 6 fidelity gate) ───────────────────────
# These fixtures carry no subgroup structure, so the subgroup-correlation floor is not
# computable. Under the hardened default that FAILS; we pass --allow-missing-subgroup to opt
# out explicitly (the opt-out is recorded in fidelity.json) and isolate the PASS on coverage +
# per-item metrics. Stage 5 below exercises the WITHOUT-opt-out hard-fail on the same inputs.
echo "Stage 3: validate (fidelity gate, exact-match fixtures + opt-out => PASS)"
python3 "$ENGINE" validate --responses "$RESP" --benchmark "$BENCH" --out "$FIDELITY" \
  --allow-missing-subgroup >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "D8.validate-exit0" || no "D8.validate-exit0 (rc=$rc)"

if [ -f "$FIDELITY" ]; then
  if grep -q '"verdict": "PASS"' "$FIDELITY"; then
    ok "D9.verdict-PASS"
  else
    no "D9.verdict-PASS (verdict not PASS)"
  fi
  if grep -q '"coverage": 1.0' "$FIDELITY" && grep -q '"item_pass_rate": 1.0' "$FIDELITY"; then
    ok "D10.coverage+itempass (both 1.0)"
  else
    no "D10.coverage+itempass (expected coverage=1.0 and item_pass_rate=1.0)"
  fi
else
  no "D9.verdict-PASS (no fidelity.json)"
  no "D10.coverage+itempass (no fidelity.json)"
fi

# ── Stage 5: validate hard-fails when subgroup r is not computable (no opt-out) ─
# Identical exact-match inputs as Stage 3 but WITHOUT --allow-missing-subgroup. The hardened
# verdict must now FAIL (exit 1) rather than silently pass, proving the Argyle floor is no
# longer skippable by omission. Stages 3 and 5 together are the missing-subgroup pair.
echo "Stage 5: validate missing-subgroup hard-fail (no opt-out => exit 1)"
python3 "$ENGINE" validate --responses "$RESP" --benchmark "$BENCH" --out "$TMP/fidelity-nosub.json" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 1 ] && ok "D11.missing-subgroup-hardfail (exit 1)" || no "D11.missing-subgroup-hardfail (rc=$rc, expected 1)"

# ── Stage 6: validate fails on a distributionally-skewed benchmark ─
# Pass --allow-missing-subgroup so the failure is attributable to the per-item metrics (mean/KS/
# JSD) and coverage, NOT to the missing subgroup gate — this isolates the metric-threshold FAIL.
echo "Stage 6: validate skewed-benchmark FAIL (distributions far apart => exit 1)"
python3 "$ENGINE" validate --responses "$RESP" --benchmark "$BENCH_SKEW" --out "$FIDELITY_SKEW" \
  --allow-missing-subgroup >/dev/null 2>&1
rc=$?
[ "$rc" -eq 1 ] && ok "D12.validate-fail-exit1" || no "D12.validate-fail-exit1 (rc=$rc, expected 1)"

if [ -f "$FIDELITY_SKEW" ]; then
  if grep -q '"verdict": "FAIL"' "$FIDELITY_SKEW"; then
    ok "D13.verdict-FAIL"
  else
    no "D13.verdict-FAIL (verdict not FAIL on skewed benchmark)"
  fi
else
  no "D13.verdict-FAIL (no fidelity-skew.json)"
fi

# ── Stage 4: interactive_runner.py run --dry-run (MODE 10, stdlib only) ─
# The interactive paradigm's dry-run path must be pure stdlib (langgraph/langchain are
# lazy-imported ONLY on the live path), so the smoke layer can exercise plan construction +
# cost estimation with no extras and no API key — exactly like the base engine's dry-run.
echo "Stage 4: interactive_runner.py run --dry-run (zero API calls, stdlib only)"
ICKPT="$TMP/ickpt"                    # checkpoint dir the interactive runner writes into
IMANIFEST="$TMP/interactive.json"     # interactive run manifest (paradigm=interactive)
ICONV=2                               # number of conversations to plan
ITURNS=4                              # per-conversation turn ceiling (round-robin: 1 call/turn)

# Interactive manifest: 2 agents, round-robin, 2 conversations x 4 turns = 8 model calls.
# provider=anthropic + a priced model exercises the real get_price() path; --dry-run never
# constructs a chat model, so no langchain/langgraph/key is touched.
cat > "$IMANIFEST" <<JSON
{
  "run_id": "smoke-interactive",
  "paradigm": "interactive",
  "provider": "anthropic",
  "model": "claude-haiku-4-5",
  "temperature": 0.7,
  "max_tokens": 32,
  "topology": "round-robin",
  "max_turns": $ITURNS,
  "n_conversations": $ICONV,
  "termination": {"on": "max_turns", "signal": "[[END]]"},
  "scenario": "A short smoke-test discussion between two agents.",
  "tools": [],
  "agents": [
    {"id": "a1", "role": "pro", "system": "You argue in favor."},
    {"id": "a2", "role": "con", "system": "You argue against."}
  ],
  "checkpoint_dir": "$ICKPT",
  "cost_cap_usd": 5.0
}
JSON

python3 "$RUNNER" run --manifest "$IMANIFEST" --dry-run >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "I1.interactive-dryrun-exit0" || no "I1.interactive-dryrun-exit0 (rc=$rc)"

assert_file "I2.conversation-plan" "$ICKPT/conversation-plan.jsonl"
assert_file "I3.cost-estimate"     "$ICKPT/cost-estimate.json"

# Expected fan-out: n_conversations x max_turns = 2 x 4 = 8 model calls (round-robin, 1 call/turn).
if [ -f "$ICKPT/cost-estimate.json" ]; then
  iwant=$((ICONV * ITURNS))
  if grep -q "\"n_model_calls\": $iwant" "$ICKPT/cost-estimate.json"; then
    ok "I3b.n_model_calls (n_model_calls=$iwant)"
  else
    no "I3b.n_model_calls (expected n_model_calls=$iwant in cost-estimate.json)"
  fi
fi

# A dry run makes no calls, so it must NOT write the native checkpoint store or the export.
if [ ! -f "$ICKPT/graph.sqlite" ] && [ ! -f "$ICKPT/transcripts.jsonl" ]; then
  ok "I4.no-live-artifacts (dry-run wrote no graph.sqlite/transcripts.jsonl)"
else
  no "I4.no-live-artifacts (graph.sqlite/transcripts.jsonl should not exist after --dry-run)"
fi

# I5: the MODE 10 hard gate's EXECUTABLE record. Even a dry-run must emit validation.json with
# the honest UNVALIDATED-EXPLORATORY verdict (the verdict is intentionally non-PASS, so this is
# a presence + honest-label check, not a PASS check). Reuses the Stage 4 dry-run output.
if [ -f "$ICKPT/validation.json" ] \
   && grep -q '"verdict": "UNVALIDATED-EXPLORATORY"' "$ICKPT/validation.json" \
   && grep -q '"dry_run": true' "$ICKPT/validation.json"; then
  ok "I5.validation-record (UNVALIDATED-EXPLORATORY, dry_run)"
else
  no "I5.validation-record (expected validation.json with UNVALIDATED-EXPLORATORY + dry_run:true)"
fi

# ── Stage 5: interactive structural refusals (fail loudly BEFORE any spend) ─
# These exercise the small-N-by-design guards in _validate_interactive_manifest; both raise
# SystemExit(2) and run on pure stdlib (no deps), so the smoke layer can assert them.
echo "Stage 5: interactive refusals (exit 2 before any API call)"

# I6: a single agent is not a multi-agent conversation -> refuse with exit 2.
I1MANIFEST="$TMP/interactive-1agent.json"
cat > "$I1MANIFEST" <<JSON
{
  "run_id": "smoke-1agent", "paradigm": "interactive", "provider": "anthropic",
  "model": "claude-haiku-4-5", "topology": "round-robin", "max_turns": 2, "n_conversations": 1,
  "tools": [], "agents": [{"id": "solo", "system": "the only voice"}],
  "checkpoint_dir": "$TMP/ick1", "cost_cap_usd": 5.0
}
JSON
err="$(python3 "$RUNNER" run --manifest "$I1MANIFEST" --dry-run 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'require >= 2 agents'; then
  ok "I6.refuse-1-agent (exit 2)"
else
  no "I6.refuse-1-agent (rc=$rc, expected 2 with '>= 2 agents' on stderr)"
fi

# I7: above the small-N cap (HARD_CONV_CAP=50) -> refuse with exit 2.
IOVERMANIFEST="$TMP/interactive-overcap.json"
cat > "$IOVERMANIFEST" <<JSON
{
  "run_id": "smoke-overcap", "paradigm": "interactive", "provider": "anthropic",
  "model": "claude-haiku-4-5", "topology": "round-robin", "max_turns": 2, "n_conversations": 51,
  "tools": [],
  "agents": [{"id": "a1", "system": "pro"}, {"id": "a2", "system": "con"}],
  "checkpoint_dir": "$TMP/ickover", "cost_cap_usd": 5.0
}
JSON
err="$(python3 "$RUNNER" run --manifest "$IOVERMANIFEST" --dry-run 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'exceeds the small-N cap'; then
  ok "I7.refuse-over-cap (exit 2)"
else
  no "I7.refuse-over-cap (rc=$rc, expected 2 with 'exceeds the small-N cap' on stderr)"
fi

# ── Stage 6: LOCAL_MODE egress gate (exit 5) ───────────────────────
# Under LOCAL_MODE a cloud provider would send persona prompts off-machine and must be refused.
# The gate is on the LIVE path only (after the dry-run early-return), and _safety_status() reads
# a cwd-relative .claude/safety-status.json — so we stage the sidecar and run live in a subshell.
# The gate fires BEFORE any langgraph import, so this needs no third-party deps.
echo "Stage 6: LOCAL_MODE egress gate (exit 5)"
LMDIR="$TMP/localmode"; mkdir -p "$LMDIR/.claude"
printf '{"SAFETY_STATUS": "LOCAL_MODE"}\n' > "$LMDIR/.claude/safety-status.json"
LMMANIFEST="$TMP/interactive-localmode.json"
cat > "$LMMANIFEST" <<JSON
{
  "run_id": "smoke-localmode", "paradigm": "interactive", "provider": "anthropic",
  "model": "claude-haiku-4-5", "topology": "round-robin", "max_turns": 2, "n_conversations": 1,
  "tools": [],
  "agents": [{"id": "a1", "system": "pro"}, {"id": "a2", "system": "con"}],
  "checkpoint_dir": "$TMP/icklm", "cost_cap_usd": 5.0
}
JSON
err="$( cd "$LMDIR" && python3 "$RUNNER" run --manifest "$LMMANIFEST" 2>&1 >/dev/null )"; rc=$?
if [ "$rc" -eq 5 ] && printf '%s' "$err" | grep -qi 'LOCAL_MODE'; then
  ok "I8.local-mode-egress (exit 5)"
else
  no "I8.local-mode-egress (rc=$rc, expected 5 with 'LOCAL_MODE' on stderr)"
fi

# ── Stage 7 (optional): offline fake-chat seam exercises the live StateGraph loop ─
# SCHOLAR_FAKE_CHAT=1 injects a stub chat model so the REAL LangGraph loop runs with no network,
# no API key, and no provider SDK — but it still needs langgraph + langchain-core installed. When
# those quarantined extras are absent (the default CI state) this SKIPs; it is never a FAIL. A true
# live PROVIDER run remains DEFERRED (no keys/deps); only the offline graph loop is exercised here.
echo "Stage 7 (optional): offline fake-chat live seam"
# The guard must test what the RUNNER imports, not a proxy for it. It previously checked only
# `langgraph, langchain_core` — 2 of the 3 requirements — so a PARTIAL install (langgraph present,
# no SqliteSaver backend) fell through to the live path and reported FAIL where this block plainly
# intends SKIP. interactive_runner.py:258-264 needs a SqliteSaver from EITHER layout, so probe both
# exactly as it does.
if python3 -c "import langgraph, langchain_core
try:
    from langgraph.checkpoint.sqlite import SqliteSaver
except ImportError:
    from langgraph_checkpoint_sqlite import SqliteSaver" >/dev/null 2>&1; then
  SCKPT="$TMP/seamck"
  SMANIFEST="$TMP/interactive-seam.json"
  cat > "$SMANIFEST" <<JSON
{
  "run_id": "smoke-seam", "paradigm": "interactive", "provider": "anthropic",
  "model": "claude-haiku-4-5", "topology": "round-robin", "max_turns": 4, "n_conversations": 2,
  "scenario": "smoke seam discussion", "tools": [],
  "agents": [{"id": "a1", "system": "pro"}, {"id": "a2", "system": "con"}],
  "checkpoint_dir": "$SCKPT", "cost_cap_usd": 5.0
}
JSON
  SCHOLAR_FAKE_CHAT=1 python3 "$RUNNER" run --manifest "$SMANIFEST" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && [ -f "$SCKPT/graph.sqlite" ] && [ -s "$SCKPT/transcripts.jsonl" ] \
     && grep -q '"verdict": "UNVALIDATED-EXPLORATORY"' "$SCKPT/validation.json" \
     && grep -q '"dry_run": false' "$SCKPT/validation.json"; then
    ok "I9.fake-chat-seam (graph.sqlite + transcripts + live validation.json)"
  else
    no "I9.fake-chat-seam (rc=$rc; expected graph.sqlite + non-empty transcripts + live validation.json)"
  fi
else
  # Name the ACTUAL missing import. Saying "langgraph/langchain-core" when the gap is the
  # SqliteSaver backend sends the reader after a package that is already installed.
  _i9_missing=$(python3 -c "
import importlib
for m in ('langgraph','langchain_core'):
    try: importlib.import_module(m)
    except ImportError: print(m); raise SystemExit
try: importlib.import_module('langgraph.checkpoint.sqlite')
except ImportError:
    try: importlib.import_module('langgraph_checkpoint_sqlite')
    except ImportError: print('SqliteSaver backend (langgraph.checkpoint.sqlite / langgraph_checkpoint_sqlite)')
" 2>/dev/null)
  echo "  SKIP: I9.fake-chat-seam (${_i9_missing:-interactive extras} not installed — live graph loop deferred)"
  unset _i9_missing
fi

# --- dry-run receipt enforcement (R1–R5; pre-execution-review protocol) ----
# Fresh manifest + checkpoint dir with a microscopic cost cap: a paid run that
# clears the receipt check deterministically stops at the cap (rc=3), so these
# cases never need an API key or provider construction.
CKPT2="$TMP/ckpt-receipt"
MANIFEST2="$TMP/manifest-receipt.json"
cat > "$MANIFEST2" <<JSON
{
  "provider": "anthropic",
  "model": "claude-haiku-4-5",
  "scale_strategy": "batch",
  "cache": true,
  "n_reps": 1,
  "max_tokens": 16,
  "personas": "$PERSONAS",
  "items": "$ITEMS",
  "checkpoint_dir": "$CKPT2",
  "cost_cap_usd": 0.0000001
}
JSON

echo ""
echo "Receipt R1: paid run with NO dry-run receipt is refused (rc=4)"
OUT_R1=$(python3 "$ENGINE" run --manifest "$MANIFEST2" 2>&1); rc=$?
if [ "$rc" -eq 4 ] && printf '%s' "$OUT_R1" | grep -q "no dry-run receipt"; then
  ok "R1.refusal (rc=4, receipt demanded, zero calls)"
else
  no "R1.refusal (rc=$rc; expected 4 + receipt message)"
fi

echo "Receipt R2: --dry-run writes a manifest-hash-bound receipt"
python3 "$ENGINE" run --manifest "$MANIFEST2" --dry-run >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$CKPT2/dry-run-receipt.json" ] \
   && grep -q '"manifest_sha256"' "$CKPT2/dry-run-receipt.json"; then
  ok "R2.receipt-written (manifest_sha256 present)"
else
  no "R2.receipt-written (rc=$rc)"
fi

echo "Receipt R3: matching receipt clears the check (run proceeds to cost-cap rc=3)"
OUT_R3=$(python3 "$ENGINE" run --manifest "$MANIFEST2" 2>&1); rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$OUT_R3" | grep -q "exceeds cost_cap_usd"; then
  ok "R3.receipt-clears (refused at cap, not at receipt)"
else
  no "R3.receipt-clears (rc=$rc; expected 3 at cost cap)"
fi

echo "Receipt R4: editing the manifest after dry-run stales the receipt (rc=4)"
python3 - "$MANIFEST2" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p))
m["max_tokens"] = 17   # single post-dry-run edit
json.dump(m, open(p, "w"), indent=2)
PY
OUT_R4=$(python3 "$ENGINE" run --manifest "$MANIFEST2" 2>&1); rc=$?
if [ "$rc" -eq 4 ]; then
  ok "R4.stale-receipt (post-dry-run manifest edit refused)"
else
  no "R4.stale-receipt (rc=$rc; expected 4)"
fi

echo "Receipt R5: --override-dry-run is accepted AND ledger-logged"
OUT_R5=$(python3 "$ENGINE" run --manifest "$MANIFEST2" --override-dry-run "smoke-test override" 2>&1); rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$OUT_R5" | grep -q "OVERRIDE accepted" \
   && grep -q '"event": "dry-run-override"' "$CKPT2/cost-ledger.jsonl"; then
  ok "R5.override (logged to cost ledger, then stopped at cap)"
else
  no "R5.override (rc=$rc; expected 3 + ledger event)"
fi

echo ""
echo "════════════════════"
echo "Results: $PASS passed, $FAIL failed"

[ "$FAIL" -eq 0 ]
