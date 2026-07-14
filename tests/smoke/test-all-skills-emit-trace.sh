#!/usr/bin/env bash
# Instrumentation ratchet: every skill must emit an RAO trace (call emit-trace.sh),
# and every agent must carry the RAO Trace sidecar contract. This is the STATIC
# enforcement that trace instrumentation does not regress (the trace-coverage
# gate is the runtime half). If a new skill/agent is added without wiring, this
# fails and names it.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.claude/skills"
AGENTS_DIR="$REPO_ROOT/.claude/agents"

FAILS=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; FAILS=$((FAILS + 1)); }

# ── Allow-list: pure advisory no-op routers that write NO files by design are
# exempt from the emit-trace requirement (a trace IS a file, which would
# contradict their "writes no files" contract). Keep this list TINY and
# justified — any skill that produces an artifact does NOT belong here.
#   scholar-resume — reads project-state.md, emits a single RESUME_ROUTE line to
#                    stdout; writes nothing (execution/writes belong to the
#                    orchestrator it hands off to).
TRACE_EXEMPT="scholar-resume"
is_exempt() { case " $TRACE_EXEMPT " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# ── Skills: every <skill>/SKILL.md must call emit-trace.sh with its own name ──
MISSING_SKILLS=""
EXEMPTED=""
COUNT_SKILLS=0
for d in "$SKILLS_DIR"/*/; do
  s=$(basename "$d")
  [ "$s" = "_shared" ] && continue
  f="$d/SKILL.md"
  [ -f "$f" ] || continue
  if is_exempt "$s"; then
    EXEMPTED="$EXEMPTED $s"
    # A no-op router must NOT carry trace-writing instructions (consistency).
    grep -q 'emit-trace.sh' "$f" && bad "$s is trace-exempt (no-op router) but still contains emit-trace.sh — remove it or drop it from the allow-list"
    continue
  fi
  COUNT_SKILLS=$((COUNT_SKILLS + 1))
  if grep -q 'emit-trace.sh' "$f"; then
    # And it should reference its OWN skill name on an emit-trace --skill line
    if grep -qE "emit-trace\.sh --skill $s\b" "$f" || grep -qE "\-\-skill $s\b" "$f"; then
      : # good
    else
      MISSING_SKILLS="$MISSING_SKILLS $s(no --skill $s)"
    fi
  else
    MISSING_SKILLS="$MISSING_SKILLS $s"
  fi
done
if [ -z "$MISSING_SKILLS" ]; then
  ok "all $COUNT_SKILLS non-exempt skills call emit-trace.sh with their own --skill name (exempt:${EXEMPTED:- none})"
else
  bad "skills missing emit-trace instrumentation:$MISSING_SKILLS"
fi

# ── Agents: every <agent>.md must carry the RAO Trace sidecar contract ───────
MISSING_AGENTS=""
COUNT_AGENTS=0
for f in "$AGENTS_DIR"/*.md; do
  [ -f "$f" ] || continue
  a=$(basename "$f" .md)
  COUNT_AGENTS=$((COUNT_AGENTS + 1))
  if grep -qF 'RAO Trace' "$f" && grep -qF 'TRACE:' "$f"; then
    : # good
  else
    MISSING_AGENTS="$MISSING_AGENTS $a"
  fi
done
if [ -z "$MISSING_AGENTS" ]; then
  ok "all $COUNT_AGENTS agents carry the RAO Trace sidecar contract"
else
  bad "agents missing the RAO Trace contract:$MISSING_AGENTS"
fi

# ── The shared protocol docs must exist (skills/agents reference them) ───────
[ -f "$SKILLS_DIR/_shared/process-logger.md" ] && grep -q 'emit-trace.sh' "$SKILLS_DIR/_shared/process-logger.md" \
  && ok "_shared/process-logger.md documents the emit-trace protocol" \
  || bad "_shared/process-logger.md missing or does not document emit-trace"
[ -f "$SKILLS_DIR/_shared/agent-trace-contract.md" ] \
  && ok "_shared/agent-trace-contract.md exists" \
  || bad "_shared/agent-trace-contract.md missing"

echo ""
if [ "$FAILS" -eq 0 ]; then echo "ALL trace-instrumentation ratchet checks passed"; exit 0
else echo "$FAILS trace-instrumentation check(s) FAILED"; exit 1; fi
