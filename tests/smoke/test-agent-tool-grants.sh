#!/usr/bin/env bash
# test-agent-tool-grants.sh — an agent brief must not mandate a tool its frontmatter withholds.
#
# BEFORE-STATE (verified 2026-08-11, v5.27.1): review-code-statistics.md line 60 read
#   "**MANDATORY mechanical step**: run `bash "${SCHOLAR_SKILL_DIR}/scripts/gates/
#    model-spec-lint.sh" "${PROJ}"` … Do NOT report the model class as clean until you have
#    pasted the linter output."
# while its frontmatter granted only `tools: Read, Write, Grep, Glob`. The agent was ordered
# to do something it structurally could not do. `model-spec-lint.sh` went unrun for FIVE
# consecutive Phase 5.5 iterations, each report dutifully noting the omission, until the
# orchestrator ran it by hand.
#
# This is the general concept-gap: prose mandating a capability the frontmatter does not
# grant. It is cheap to check and it recurs, so it is checked mechanically.
#
# FIRES ON  — a brief containing an imperative Bash/WebSearch/WebFetch instruction whose
#             frontmatter omits that tool.
# SLIPS PAST — prose that merely *mentions* a script by name without instructing the agent
#             to execute it (e.g. "the orchestrator runs X at the exit gate"), and blocks
#             explicitly marked as orchestrator-side.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS="${REPO_ROOT}/.claude/agents"
PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== agent tool grants vs mandated capabilities ==="
echo ""
[ -d "$AGENTS" ] || { echo "  FAIL: $AGENTS missing"; exit 1; }

VIOLATIONS=0
CHECKED=0
for f in "$AGENTS"/*.md; do
  b="$(basename "$f")"
  # frontmatter tools: line (first one only)
  TOOLS="$(grep -m1 '^tools:' "$f" 2>/dev/null || true)"
  [ -n "$TOOLS" ] || continue
  CHECKED=$((CHECKED + 1))

  # An imperative shell instruction: "run `bash ...`" / "execute `bash ...`" /
  # "you MUST run ... .sh". Deliberately narrow — a bare mention of a .sh path is NOT a
  # mandate, and widening this to any ".sh" hit reproduces the false-positive class that
  # CLAUDE.md Working Discipline rule 10 warns about.
  if grep -qiE '(run|execute|invoke) `?bash |you MUST run |MANDATORY mechanical step.*bash ' "$f"; then
    case "$TOOLS" in
      *Bash*) : ;;
      *)
        echo "       $b mandates a Bash invocation but frontmatter grants: ${TOOLS#tools: }"
        grep -niE '(run|execute|invoke) `?bash |you MUST run |MANDATORY mechanical step.*bash ' "$f" \
          | head -2 | sed 's/^/         /'
        VIOLATIONS=$((VIOLATIONS + 1))
        ;;
    esac
  fi

  # Same shape for web access.
  if grep -qiE '(you MUST|MANDATORY).{0,60}(WebSearch|web search)' "$f"; then
    case "$TOOLS" in
      *WebSearch*) : ;;
      *)
        echo "       $b mandates WebSearch but frontmatter grants: ${TOOLS#tools: }"
        VIOLATIONS=$((VIOLATIONS + 1))
        ;;
    esac
  fi
done

[ "$CHECKED" -ge 20 ] \
  && pass "scanned $CHECKED agent briefs with a tools: frontmatter" \
  || fail "only $CHECKED agent briefs scanned — expected 20+; is the glob right?"

[ "$VIOLATIONS" -eq 0 ] \
  && pass "no agent brief mandates a tool its frontmatter withholds" \
  || fail "$VIOLATIONS agent brief(s) mandate a capability they were not granted"

# ---- model-spec-lint coupling (only where that gate ships) ----------------------
# The public release does not ship scripts/gates/model-spec-lint.sh, and its
# review-code-statistics brief does not mandate it — so the concept-gap this suite exists
# for cannot occur here. Assert the coupling only when the gate is actually present, and
# say INERT rather than silently reporting a pass (the U7 rule applies to test suites too).
ST="${AGENTS}/review-code-statistics.md"
LINT="${REPO_ROOT}/scripts/gates/model-spec-lint.sh"
if [ -f "$LINT" ]; then
  grep -q "model-spec-lint.sh" "$ST" \
    && pass "review-code-statistics mandates model-spec-lint.sh" \
    || fail "model-spec-lint.sh ships but no brief invokes it"
  grep -m1 '^tools:' "$ST" | grep -q "Bash" \
    && pass "review-code-statistics is granted Bash to run it" \
    || fail "review-code-statistics mandates a linter run without Bash"
  grep -q "FORMULAS_RESOLVED" "$LINT" \
    && pass "model-spec-lint.sh reports formula coverage" \
    || fail "model-spec-lint.sh has no coverage measure"
  grep -q "zero formula coverage" "$LINT" \
    && pass "zero-coverage runs report INERT rather than GREEN" \
    || fail "model-spec-lint.sh can still report GREEN having resolved no formulas"
else
  echo "  INERT: model-spec-lint.sh not shipped in this distribution — coupling checks N/A"
  grep -q "model-spec-lint.sh" "$ST" \
    && fail "brief mandates model-spec-lint.sh but the gate is not shipped (concept-gap)" \
    || pass "no brief mandates the absent model-spec-lint.sh"
fi

echo ""
echo "════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
