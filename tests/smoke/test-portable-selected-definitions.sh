#!/usr/bin/env bash
# Smoke test: the selected open-scholar components must be portable, permission-free
# definitions, and every selected skill that references the shared tree must degrade
# honestly when the shared helper is absent (standalone selected deployment).
#
# Contracts, mirroring the harness build's check_definition:
#   1. Skills — the six selected skills carry no configuration fields in frontmatter
#      (tools, permissions, model, mode, ...). Grants come from harness config, not
#      the skill file.
#   2. Agents — the fourteen selected agents carry name+description ONLY.
#   3. Shared-backend guards — scholar-respond Step 0b, scholar-citation setup + mode
#      references, and the four skills' citation-protocol cats must be honest no-ops
#      when the shared helper is absent: no failing eval, no misleading success, no
#      command-not-found, and no automatic network in the probes.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLS_ROOT="$REPO_ROOT/.claude/skills"
AGENTS_ROOT="$REPO_ROOT/.claude/agents"

SELECTED_SKILLS="scholar-respond scholar-code-review scholar-verify scholar-causal scholar-replication scholar-citation"
SELECTED_AGENTS="peer-reviewer-computational peer-reviewer-quant peer-reviewer-senior peer-reviewer-theory \
review-code-correctness review-code-data-handling review-code-reproducibility review-code-robustness \
review-code-statistics review-code-style verify-completeness verify-figures verify-logic verify-numerics"

PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS + 1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# extract every ```bash block containing $2 from $1; write each to $3$i.sh; print count
extract_blocks() {
  local file="$1" marker="$2" prefix="$3"
  awk -v m="$marker" -v p="$prefix" '
    /^[ \t]*```bash[ \t]*$/ { inb=1; buf=""; next }
    /^[ \t]*```[ \t]*$/ && inb { inb=0; if (buf ~ m) { i++; f = p i ".sh"; print buf > f; close(f) } next }
    inb { buf = buf $0 "\n" }
    END { print i + 0 }
  ' "$file"
}

# run a block in a hermetic env rooted at $1 (SCHOLAR_SKILL_DIR=$1, clean HOME)
run_hermetic() {
  local root="$1" block="$2"
  local home
  home="$(mktemp -d "$TMPD/home.XXXXXX")"
  HOME="$home" SCHOLAR_SKILL_DIR="$root" SCHOLAR_ZOTERO_DIR= SCHOLAR_BIB_PATH= SCHOLAR_ENDNOTE_XML= \
    bash -c "$block" 2>&1
}

echo "=== portable selected definitions (ticket 77 portability) ==="

# ---- 1. the six selected skills carry no configuration fields ----
CONFIG_FIELDS="tools allowed-tools disallowedTools permission permissions model model_reasoning_effort sandbox_mode color mode"
for skill in $SELECTED_SKILLS; do
  f="$SKILLS_ROOT/$skill/SKILL.md"
  if [ ! -f "$f" ]; then
    no "missing selected skill: $skill/SKILL.md"
    continue
  fi
  fm=$(awk 'NR>1 && /^---$/{exit} NR>1{print}' "$f")
  bad=""
  for field in $CONFIG_FIELDS; do
    if echo "$fm" | grep -qE "^${field}:"; then
      bad="$bad $field"
    fi
  done
  if [ -z "$bad" ]; then
    ok "$skill has no configuration fields in frontmatter"
  else
    no "$skill still carries configuration field(s):$bad"
  fi
done

# ---- 2. the fourteen selected agents carry name+description only ----
for agent in $SELECTED_AGENTS; do
  f="$AGENTS_ROOT/$agent.md"
  if [ ! -f "$f" ]; then
    no "missing selected agent: $agent.md"
    continue
  fi
  fm=$(awk 'NR>1 && /^---$/{exit} NR>1{print}' "$f")
  extras=$(printf '%s\n' "$fm" | grep -E '^[A-Za-z0-9_-]+:' | grep -vE '^(name|description):' | sed 's/:.*//' | tr '\n' ' ')
  if [ -z "$extras" ]; then
    ok "$agent frontmatter is name+description only"
  else
    no "$agent has extra frontmatter field(s): $extras"
  fi
  echo "$fm" | grep -qE '^name:' || no "$agent missing name field"
  echo "$fm" | grep -qE '^description:' || no "$agent missing description field"
done

# ---- 3. selected agent bodies name no single-harness capability ----
for agent in $SELECTED_AGENTS; do
  f="$AGENTS_ROOT/$agent.md"
  [ -f "$f" ] || continue
  if grep -qiE '\b(lsp|doom_loop|external_directory)\b|`question`|\bquestion tool\b' "$f"; then
    no "$agent names a single-harness capability"
  else
    ok "$agent uses only common capabilities"
  fi
done

TMPD="$(mktemp -d -t portable.XXXXXX)"
trap 'rm -rf "$TMPD"' EXIT

# ---- 4. scholar-respond Step 0b: shared helper present vs absent ----
echo "=== scholar-respond Step 0b shared-backend guard ==="
SKILL="$SKILLS_ROOT/scholar-respond/SKILL.md"
STEP0B=$(awk '/### 0b/{f=1} /### 0c/{f=0} f' "$SKILL" | sed -n '/^```bash/,/^```/p' | sed '1d;$d')
if [ -z "$STEP0B" ]; then
  no "could not extract Step 0b bash block from scholar-respond SKILL.md"
else
  ok "extracted Step 0b block (${#STEP0B} bytes)"
fi

# present case: helper ships
mkdir -p "$TMPD/present/.claude/skills/_shared"
cp "$SKILLS_ROOT/_shared/refmanager-backends.md" "$TMPD/present/.claude/skills/_shared/refmanager-backends.md"
PRESENT_OUT=$(run_hermetic "$TMPD/present" "$STEP0B"); PRESENT_RC=$?
if [ "$PRESENT_RC" -eq 0 ]; then
  ok "Step 0b exits 0 when the helper ships"
else
  no "Step 0b exit $PRESENT_RC when the helper ships (rc=$PRESENT_RC)"
fi
PRESENT_AVAIL=$(
  mkdir -p "$TMPD/avail-present"
  HOME="$(mktemp -d "$TMPD/home.XXXXXX")" SCHOLAR_SKILL_DIR="$TMPD/present" \
    bash -c "$STEP0B; printf '%s' \"\${REF_MANAGER_AVAILABLE:-0}\" > \"$TMPD/avail-present/mark\"" >/dev/null 2>&1
  cat "$TMPD/avail-present/mark"
)
if [ "$PRESENT_AVAIL" = "1" ]; then
  ok "helper present -> REF_MANAGER_AVAILABLE=1 (helper function truly available)"
else
  no "helper present -> REF_MANAGER_AVAILABLE='$PRESENT_AVAIL' (expected 1)"
fi
if HOME="$(mktemp -d "$TMPD/home.XXXXXX")" SCHOLAR_SKILL_DIR="$TMPD/present" bash -c "$STEP0B; type scholar_search" >/dev/null 2>&1; then
  ok "helper present -> scholar_search is defined"
else
  no "helper present -> scholar_search not defined (behaviour not preserved)"
fi
if printf '%s' "$PRESENT_OUT" | grep -qiE 'curl|wget|https?://'; then
  no "helper present -> probe touched the network"
else
  ok "helper present -> probe made no network call (local detection only)"
fi

# absent case: standalone selected deployment without the shared tree
mkdir -p "$TMPD/absent/.claude/skills"
ABSENT_OUT=$(run_hermetic "$TMPD/absent" "$STEP0B"); ABSENT_RC=$?
if [ "$ABSENT_RC" -eq 0 ]; then
  ok "Step 0b exits 0 when the helper is absent"
else
  no "Step 0b exit $ABSENT_RC when the helper is absent (rc=$ABSENT_RC)"
fi
ABSENT_AVAIL=$(
  mkdir -p "$TMPD/avail-absent"
  HOME="$(mktemp -d "$TMPD/home.XXXXXX")" SCHOLAR_SKILL_DIR="$TMPD/absent" \
    bash -c "$STEP0B; printf '%s' \"\${REF_MANAGER_AVAILABLE:-0}\" > \"$TMPD/avail-absent/mark\"" >/dev/null 2>&1
  cat "$TMPD/avail-absent/mark"
)
if [ "$ABSENT_AVAIL" != "1" ]; then
  ok "helper absent -> no REF_MANAGER_AVAILABLE=1 (no misleading success)"
else
  no "helper absent -> REF_MANAGER_AVAILABLE=1 (misleading success)"
fi
if printf '%s' "$ABSENT_OUT" | grep -q "helper absent"; then
  ok "helper absent -> honest absence note emitted"
else
  no "helper absent -> no honest absence note; output: $(printf '%s' "$ABSENT_OUT" | tr '\n' ' ')"
fi
if printf '%s' "$ABSENT_OUT" | grep -qE '\[refmanager\] Sources:'; then
  no "helper absent -> detection summary claims success (misleading)"
else
  ok "helper absent -> no detection success summary"
fi
if printf '%s' "$ABSENT_OUT" | grep -q "command not found"; then
  no "helper absent -> command-not-found surfaced"
else
  ok "helper absent -> no command-not-found"
fi

# ---- 5. scholar-citation setup loader: shared present / vendored / both absent ----
echo "=== scholar-citation setup loader guard ==="
CIT_LOADER_N=$(extract_blocks "$SKILLS_ROOT/scholar-citation/SKILL.md" "REF_MANAGER_AVAILABLE" "$TMPD/citloader")
if [ "$CIT_LOADER_N" -eq 1 ]; then
  ok "extracted citation setup loader block"
else
  no "expected 1 citation setup loader block, found $CIT_LOADER_N"
fi
CIT_LOADER="$(cat "$TMPD/citloader1.sh")"

# shared present
mkdir -p "$TMPD/cit-shared/.claude/skills/_shared" "$TMPD/cit-shared/.claude/skills/scholar-citation/references"
cp "$SKILLS_ROOT/_shared/refmanager-backends.md" "$TMPD/cit-shared/.claude/skills/_shared/refmanager-backends.md"
cp "$SKILLS_ROOT/scholar-citation/references/refmanager-backends.md" "$TMPD/cit-shared/.claude/skills/scholar-citation/references/refmanager-backends.md"
CIT_PRESENT_OUT=$(run_hermetic "$TMPD/cit-shared" "$CIT_LOADER"); CIT_PRESENT_RC=$?
CIT_PRESENT_AVAIL=$(
  mkdir -p "$TMPD/citavail1"
  HOME="$(mktemp -d "$TMPD/home.XXXXXX")" SCHOLAR_SKILL_DIR="$TMPD/cit-shared" \
    bash -c "$CIT_LOADER; printf '%s' \"\${REF_MANAGER_AVAILABLE:-0}\" > \"$TMPD/citavail1/mark\"" >/dev/null 2>&1
  cat "$TMPD/citavail1/mark"
)
[ "$CIT_PRESENT_RC" -eq 0 ] && ok "citation loader exits 0 (shared present)" || no "citation loader exit $CIT_PRESENT_RC (shared present)"
[ "$CIT_PRESENT_AVAIL" = "1" ] && ok "citation loader (shared present) -> REF_MANAGER_AVAILABLE=1" || no "citation loader (shared present) -> avail='$CIT_PRESENT_AVAIL'"
printf '%s' "$CIT_PRESENT_OUT" | grep -qiE 'curl|wget|https?://' && no "citation loader (shared present) touched the network" || ok "citation loader (shared present) -> no network"

# shared absent, vendored copy present (real standalone selected deployment)
mkdir -p "$TMPD/cit-vend/.claude/skills/scholar-citation/references"
cp "$SKILLS_ROOT/scholar-citation/references/refmanager-backends.md" "$TMPD/cit-vend/.claude/skills/scholar-citation/references/refmanager-backends.md"
CIT_VEND_OUT=$(run_hermetic "$TMPD/cit-vend" "$CIT_LOADER"); CIT_VEND_RC=$?
CIT_VEND_AVAIL=$(
  mkdir -p "$TMPD/citavail2"
  HOME="$(mktemp -d "$TMPD/home.XXXXXX")" SCHOLAR_SKILL_DIR="$TMPD/cit-vend" \
    bash -c "$CIT_LOADER; printf '%s' \"\${REF_MANAGER_AVAILABLE:-0}\" > \"$TMPD/citavail2/mark\"" >/dev/null 2>&1
  cat "$TMPD/citavail2/mark"
)
[ "$CIT_VEND_RC" -eq 0 ] && ok "citation loader exits 0 (shared absent, vendored present)" || no "citation loader exit $CIT_VEND_RC (vendored)"
[ "$CIT_VEND_AVAIL" = "1" ] && ok "citation loader (vendored) -> REF_MANAGER_AVAILABLE=1" || no "citation loader (vendored) -> avail='$CIT_VEND_AVAIL'"
printf '%s' "$CIT_VEND_OUT" | grep -q "vendored copy" && ok "citation loader (vendored) -> honest vendored-copy note" || no "citation loader (vendored) -> no vendored note"
printf '%s' "$CIT_VEND_OUT" | grep -qiE 'curl|wget|https?://' && no "citation loader (vendored) touched the network" || ok "citation loader (vendored) -> no network"

# both absent
mkdir -p "$TMPD/cit-none/.claude/skills"
CIT_NONE_OUT=$(run_hermetic "$TMPD/cit-none" "$CIT_LOADER"); CIT_NONE_RC=$?
CIT_NONE_AVAIL=$(
  mkdir -p "$TMPD/citavail3"
  HOME="$(mktemp -d "$TMPD/home.XXXXXX")" SCHOLAR_SKILL_DIR="$TMPD/cit-none" \
    bash -c "$CIT_LOADER; printf '%s' \"\${REF_MANAGER_AVAILABLE:-0}\" > \"$TMPD/citavail3/mark\"" >/dev/null 2>&1
  cat "$TMPD/citavail3/mark"
)
[ "$CIT_NONE_RC" -eq 0 ] && ok "citation loader exits 0 (both absent)" || no "citation loader exit $CIT_NONE_RC (both absent)"
[ "$CIT_NONE_AVAIL" != "1" ] && ok "citation loader (both absent) -> no misleading REF_MANAGER_AVAILABLE=1" || no "citation loader (both absent) -> misleading avail='$CIT_NONE_AVAIL'"
printf '%s' "$CIT_NONE_OUT" | grep -q "helper absent" && ok "citation loader (both absent) -> honest absence note" || no "citation loader (both absent) -> no honest note"
printf '%s' "$CIT_NONE_OUT" | grep -q "command not found" && no "citation loader (both absent) -> command-not-found surfaced" || ok "citation loader (both absent) -> no command-not-found"

# ---- 6. citation mode-reference call sites: absent helper -> guarded honest no-op ----
echo "=== citation mode-reference call guards (absent shared) ==="
for ref in mode-insert-audit mode-verify-retraction; do
  n=$(extract_blocks "$SKILLS_ROOT/scholar-citation/references/$ref.md" "type scholar_search" "$TMPD/$ref")
  good=0
  i=1
  while [ "$i" -le "$n" ]; do
    block="$(cat "$TMPD/$ref$i.sh")"
    OUT=$(run_hermetic "$TMPD/cit-none" "$block"); rc=$?
    cnf=$(printf '%s\n' "$OUT" | grep -c "command not found" || true)
    if [ "$rc" -eq 0 ] && [ "$cnf" -eq 0 ] && printf '%s\n' "$OUT" | grep -qE "unavailable|absent"; then
      good=$((good + 1))
    else
      no "$ref block $i: rc=$rc cmd-not-found=$cnf (expected honest unavailable note)"
    fi
    i=$((i + 1))
  done
  if [ "$n" -gt 0 ] && [ "$good" -eq "$n" ]; then
    ok "$ref: all $n scholar_* call blocks degrade honestly when helper absent"
  else
    no "$ref: only $good/$n call blocks degrade honestly"
  fi
done

# ---- 7. the four skills' citation-protocol cat guards: absent -> honest note ----
echo "=== citation-protocol cat guards (absent shared) ==="
for skill in scholar-causal scholar-verify scholar-replication scholar-code-review; do
  pn=$(extract_blocks "$SKILLS_ROOT/$skill/SKILL.md" "citation-verification-protocol" "$TMPD/proto-$skill")
  if [ "$pn" -ne 1 ]; then
    no "$skill: expected 1 protocol block, found $pn"
    continue
  fi
  block="$(cat "$TMPD/proto-${skill}1.sh")"
  OUT=$(run_hermetic "$TMPD/cit-none" "$block"); rc=$?
  cnf=$(printf '%s\n' "$OUT" | grep -c "command not found" || true)
  nosuch=$(printf '%s\n' "$OUT" | grep -c "No such file" || true)
  if [ "$rc" -eq 0 ] && [ "$cnf" -eq 0 ] && [ "$nosuch" -eq 0 ] && printf '%s\n' "$OUT" | grep -q "verification-protocol absent"; then
    ok "$skill protocol cat degrades honestly when shared absent"
  else
    no "$skill protocol cat: rc=$rc cmd-not-found=$cnf no-such-file=$nosuch out=$(printf '%s' "$OUT" | tr '\n' ' ' | head -c 140)"
  fi
done

# mode-3 Step 3a registry/adjudication cats (scholar-respond) — same absent guard
rn=$(extract_blocks "$SKILLS_ROOT/scholar-respond/references/mode-3-revise.md" "results-registry-contract" "$TMPD/m3reg")
if [ "$rn" -ge 1 ]; then
  REG_OK=0
  i=1
  while [ "$i" -le "$rn" ]; do
    block="$(cat "$TMPD/m3reg$i.sh")"
    OUT=$(run_hermetic "$TMPD/cit-none" "$block"); rc=$?
    cnf=$(printf '%s\n' "$OUT" | grep -c "command not found" || true)
    nosuch=$(printf '%s\n' "$OUT" | grep -c "No such file" || true)
    if [ "$rc" -eq 0 ] && [ "$cnf" -eq 0 ] && [ "$nosuch" -eq 0 ] && printf '%s\n' "$OUT" | grep -q "reference absent"; then
      REG_OK=$((REG_OK + 1))
    fi
    i=$((i + 1))
  done
  [ "$REG_OK" -eq "$rn" ] && ok "mode-3 Step 3a registry/adjudication cats degrade honestly when shared absent" || no "mode-3 Step 3a registry cats: only $REG_OK/$rn guarded"
else
  no "mode-3 Step 3a registry cat block not found"
fi

# ---- 8. no bare scholar_* call sites left unguarded in the selected references ----
echo "=== static guard sweep ==="
python3 - "$SKILLS_ROOT" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
call = re.compile(r'^\s*scholar_(?:search|verify|format)[a-z_]*[ \t]+(?=["\'$])')
guard = re.compile(r'^\s*if\s+type scholar_search')
checked = 0
bad = []
for f in sorted((root / "scholar-respond").rglob("*.md")) + sorted((root / "scholar-citation").rglob("*.md")):
    lines = f.read_text().splitlines()
    in_bash = False
    guarded = False
    for i, line in enumerate(lines):
        if line.strip() == "```bash":
            in_bash = True; guarded = False; continue
        if line.strip() == "```":
            in_bash = False; continue
        if not in_bash:
            continue
        if guard.search(line):
            guarded = True
            continue
        if call.search(line):
            checked += 1
            if not guarded:
                bad.append(f"{f.relative_to(root)}:{i+1}: {line.strip()}")
if bad:
    print("\n".join(bad))
    raise SystemExit(1)
print(f"all {checked} scholar_* call sites are inside a `type scholar_search` guard")
PY
if [ $? -eq 0 ]; then
  ok "static sweep: no unguarded scholar_* call sites"
else
  no "static sweep found unguarded scholar_* call sites"
fi

echo ""
echo "════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
