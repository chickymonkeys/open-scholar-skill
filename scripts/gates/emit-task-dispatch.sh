#!/usr/bin/env bash
# emit-task-dispatch.sh — P3 dispatch-manifest helper (audit 2026-05-19,
# V4-SD-V4-1 follow-up).
#
# Why this exists:
#   The orchestrator's Phase 11.5 Stage B (and other gated-Task) flows
#   need to bind the artifact a subagent produces to a real Task
#   dispatch. F6/V4-SD-V4-1 added artifact↔log binding; this helper
#   adds a third binding point: a per-project dispatch manifest at
#   ${PROJ}/logs/dispatch-manifest.jsonl. Each Task dispatch the
#   orchestrator runs at a gated site SHOULD append one line here.
#
# Honest framing (per V-6 adversarial audit):
#   This is a SPEED-BUMP, not a structural barrier. A determined forger
#   can write artifact + log + manifest all consistently. The manifest
#   adds:
#     - 3-way binding (artifact + log + manifest agentId all match)
#     - manuscript-SHA cross-binding (manifest entry records the SHA
#       that was current at dispatch time; the gate verifies it matches
#       artifact + current manuscript)
#     - first-seen-wins for duplicate agentId entries (raises cost of
#       id-recycling bypass per V-6 bypass #2)
#     - purpose-binding (an agentId's first-recorded purpose is canonical;
#       later entries claiming the same id for a different purpose are
#       evidence of tampering)
#
#   True structural resistance requires runtime-level support (sidecar
#   non-writable sink, harness-signed entries) — see
#   references/dispatch-manifest-limits.md for the threat-model writeup.
#
# Usage:
#   emit-task-dispatch.sh \
#     --proj PROJ \
#     --subagent <type> \
#     --purpose "<one-line description>" \
#     --phase <X.X> \
#     --agentId <id-from-Task-tool-result> \
#     [--manuscript PATH]    # optional; auto-discovers newest manuscript
#
# Example (Phase 11.5 Stage B after a real Task dispatch):
#   emit-task-dispatch.sh --proj $PROJ \
#     --subagent general-purpose \
#     --purpose "Phase 11.5 semantic body-prose read" \
#     --phase 11.5 \
#     --agentId a95ed96414f4a35dd
#
# Exit codes:
#   0  manifest line appended
#   1  required arg missing / invalid agentId format
#   2  manuscript not found (SHA cannot be computed; line still appended
#      with manuscript_sha256=null and a warning)

set -uo pipefail

PROJ=""
SUBAGENT=""
PURPOSE=""
PHASE=""
AGENT_ID=""
MANUSCRIPT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --proj)        PROJ="${2:-}"; shift 2 ;;
    --subagent)    SUBAGENT="${2:-}"; shift 2 ;;
    --purpose)     PURPOSE="${2:-}"; shift 2 ;;
    --phase)       PHASE="${2:-}"; shift 2 ;;
    --agentId)     AGENT_ID="${2:-}"; shift 2 ;;
    --manuscript)  MANUSCRIPT="${2:-}"; shift 2 ;;
    -h|--help)     grep -E '^#' "$0" | sed 's/^# *//'; exit 0 ;;
    *)             echo "ERROR: unknown flag $1" >&2; exit 1 ;;
  esac
done

# Required-arg validation
if [ -z "$PROJ" ] || [ -z "$SUBAGENT" ] || [ -z "$PURPOSE" ] || [ -z "$PHASE" ] || [ -z "$AGENT_ID" ]; then
  echo "ERROR: --proj, --subagent, --purpose, --phase, --agentId all required" >&2
  exit 1
fi

if [ ! -d "$PROJ" ]; then
  echo "ERROR: --proj path is not a directory: $PROJ" >&2
  exit 1
fi

# agentId format check — real Task tool ids are `^[a-z][a-z0-9_-]{12,}$`
# (matches the regex tighten from V1 round). Reject placeholders.
if ! echo "$AGENT_ID" | grep -qE '^[a-z][a-z0-9_-]{12,}$'; then
  echo "ERROR: --agentId '$AGENT_ID' does not match Task tool id format (^[a-z][a-z0-9_-]{12,}\$)" >&2
  echo "       Pass the actual agentId returned by the Task tool, not a placeholder." >&2
  exit 1
fi

# Manuscript SHA — used for cross-binding to the artifact.
if [ -z "$MANUSCRIPT" ]; then
  # Auto-discover: newest reader-facing manuscript.
  for pat in manuscript-submission manuscript-final draft-manuscript manuscript; do
    cand=$(ls -t "$PROJ/drafts/${pat}"-*.md 2>/dev/null | head -1 || true)
    if [ -n "$cand" ] && [ -f "$cand" ]; then
      MANUSCRIPT="$cand"; break
    fi
  done
fi

MS_SHA="null"
if [ -n "$MANUSCRIPT" ] && [ -f "$MANUSCRIPT" ]; then
  if command -v shasum >/dev/null 2>&1; then
    MS_SHA=$(shasum -a 256 "$MANUSCRIPT" 2>/dev/null | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    MS_SHA=$(sha256sum "$MANUSCRIPT" 2>/dev/null | awk '{print $1}')
  fi
  MS_SHA=${MS_SHA:-null}
fi

# Append the manifest line. JSON values are escaped via simple bash
# (no special chars expected in agent-issued ids; purpose is one-line).
LOG_DIR="$PROJ/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || {
  echo "ERROR: cannot mkdir $LOG_DIR" >&2; exit 1
}
MANIFEST="$LOG_DIR/dispatch-manifest.jsonl"

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)
# Escape backslashes and double-quotes in user-supplied fields.
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
PURPOSE_E=$(esc "$PURPOSE")
SUBAGENT_E=$(esc "$SUBAGENT")
PHASE_E=$(esc "$PHASE")

printf '{"ts":"%s","agentId":"%s","subagent":"%s","purpose":"%s","manuscript_sha256":"%s","phase":"%s"}\n' \
  "$TS" "$AGENT_ID" "$SUBAGENT_E" "$PURPOSE_E" "$MS_SHA" "$PHASE_E" \
  >> "$MANIFEST"

# Output for observability (the orchestrator may log this).
echo "MANIFEST_APPENDED=$MANIFEST"
echo "AGENT_ID=$AGENT_ID"
echo "PURPOSE=$PURPOSE"
echo "MS_SHA=${MS_SHA:0:12}…"
[ "$MS_SHA" = "null" ] && { echo "WARN: manuscript not found at $MANUSCRIPT — manifest entry has null SHA" >&2; exit 2; }
exit 0
