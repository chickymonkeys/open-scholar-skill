#!/usr/bin/env bash
# Smoke test: journal calibration controls the MODE 1 reviewer persona.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$PROJECT_ROOT/.claude/skills/scholar-respond/SKILL.md"

persona_for() {
  local journal="$1"
  awk -F '|' -v journal="**${journal}**" '
    {
      label = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", label)
    }
    label == journal {
      persona = $3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", persona)
      print persona
      exit
    }
  ' "$SKILL"
}

[ "$(persona_for AER)" = "economist" ]
[ "$(persona_for ASR)" = "sociologist" ]

grep -Fq 'theoretical [persona] reviewing a [journal] paper' "$SKILL"
grep -Fq 'senior [persona] and former associate editor at [journal]' "$SKILL"

if grep -Fq 'theoretical sociologist reviewing a [journal] paper' "$SKILL"; then
  echo "FAIL: theorist dispatch still hard-codes sociology" >&2
  exit 1
fi

for journal in AER 'AEJ: Applied' 'AEJ: Economic Policy' 'AEJ: Macroeconomics' \
  'AEJ: Microeconomics' QJE JPE Econometrica REStud JDE JOLE JPubE RJE JME; do
  if [ "$(persona_for "$journal")" != "economist" ]; then
    echo "FAIL: $journal does not select the economist persona" >&2
    exit 1
  fi
done

echo "scholar-respond journal persona checks passed."
