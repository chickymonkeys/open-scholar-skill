#!/usr/bin/env bash
# Smoke test: journal calibration controls the MODE 1 reviewer persona.
# The calibration table and the reviewer dispatch prose live in the progressively
# disclosed MODE 1 reference, so this test reads that file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$PROJECT_ROOT/.claude/skills/scholar-respond/SKILL.md"
MODE1="$PROJECT_ROOT/.claude/skills/scholar-respond/references/mode-1-simulate.md"

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
  ' "$MODE1"
}

[ "$(persona_for AER)" = "economist" ]
[ "$(persona_for ASR)" = "sociologist" ]

# The MODE 1 dispatch prose is persona-parameterised and lives in the mode
# reference after the decomposition.
grep -Fq 'theoretical [persona] reviewing a [journal] paper' "$MODE1"
grep -Fq 'senior [persona] and former associate editor at [journal]' "$MODE1"

if grep -Fq 'theoretical sociologist reviewing a [journal] paper' "$MODE1"; then
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

# The router must still dispatch MODE 1 to the reference that carries the table.
grep -Fq 'references/mode-1-simulate.md' "$SKILL"

echo "scholar-respond journal persona checks passed."
