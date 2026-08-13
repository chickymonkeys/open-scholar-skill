#!/usr/bin/env bash
# evidence-anchor-check.sh — Evidence Ledger coverage gate.
#
# Verifies that literature claims are backed by write-time evidence anchors
# (evidence/claim-anchors.ndjson, schema claim-anchor/v1) per the protocol in
# skills/_shared/evidence-ledger.md. All checks are countable: jq over the
# ledger/inventory JSON — never free-form markdown parsing.
#
# Phase modes:
#   --phase 2   Lit-review exit. Checks: (a) every ledger line is schema-valid;
#               (b) evidence/claim-inventory.json exists alongside the landscape
#               map; (c) every inventory row resolves >=1 anchor_id in the
#               ledger (many-to-many join); (d) row coverage >= threshold.
#   --phase 7   Drafting exit. Over the evidence-bearing section drafts
#               (draft-intro*/theory*/literature*/discussion* under drafts/):
#               (a) every <!--ev: id--> tag resolves in the ledger (RED on
#               unresolved); (b) tag relevance — each tag's anchor cite_key
#               must appear in the same line's prose (author token + year;
#               YELLOW on mismatches); (c) tag coverage — citation-bearing
#               lines lacking any ev tag vs threshold
#               (SCHOLAR_EVIDENCE_TAG_COVERAGE_MIN, default 60%).
#   --phase 8   Citation/audit exit. (a) the faithfulness audit exists
#               (evidence/claim-faithfulness-audit-*.ndjson; RED when the
#               ledger is non-empty on an orchestrated project but no audit
#               was produced — a skipped audit is no longer indistinguishable
#               from a passing one); (b) audit passes
#               check-claim-audit-consistency.sh (RED); (c) zero HIGH-severity
#               records (RED — mirrors the Phase 8 Hard Stop); (d) audit
#               coverage of tagged claims (anchor_refs join) vs
#               SCHOLAR_EVIDENCE_AUDIT_COVERAGE_MIN (default 70%, YELLOW);
#               (e) unused-anchor accounting (YELLOW); (f) metadata-only rate
#               among scholar-citation anchors vs
#               SCHOLAR_EVIDENCE_METADATA_ONLY_MAX (default 40%, YELLOW).
#   --phase 11-entry  Reconciliation before tag stripping: re-hash the
#               canonical drafting manuscript's comment-stripped lines and
#               compare against the audit's claim_fingerprints. Audited claims
#               no longer present verbatim (rewritten after Phase 8) and
#               tagged lines never audited are RED — re-adjudicate before
#               stripping (SCHOLAR_EVIDENCE_RECONCILE_SOFT=1 demotes to
#               YELLOW). INERT when no audit exists.
#
# Verdict policy (rollout: YELLOW-first):
#   RED    — structural: schema-invalid ledger lines; unresolvable inventory ids;
#            evidence/ dir EXISTS (post-feature scaffold) but the ledger is
#            absent/empty on an ORCHESTRATED project (logs/project-state.md
#            present) whose Phase-2 output exists.
#   YELLOW — advisory: coverage below threshold; inventory missing; empty ledger
#            on a STANDALONE project. Promote to RED with SCHOLAR_EVIDENCE_STRICT=1.
#   INERT  — nothing to check: the evidence/ dir does not exist. That is the
#            legacy signature — projects scaffolded before this feature have no
#            evidence/ dir (scaffold-project-dirs.sh creates it now), and a
#            pre-feature run must never be failed retroactively. Presence of
#            Phase-2 output itself is phase-verify.sh's job, not this gate's.
#
# Tuning (env vars, optional):
#   SCHOLAR_EVIDENCE_ROW_COVERAGE_MIN — min % inventory rows with a resolving
#                                       anchor (default 70)
#   SCHOLAR_EVIDENCE_STRICT           — 1 promotes YELLOW verdicts to RED (default 0)
#
# Exit codes: 0 = GREEN, 1 = RED, 2 = YELLOW (advisory), 3 = INERT (not applicable)
#
# Usage: evidence-anchor-check.sh <project_dir> [--phase 2]

set -u

PROJ="${1:-}"
PHASE="2"
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --phase) PHASE="${2:-}"; shift 2 ;;
    *) echo "FAIL"; echo "REASON=unknown argument: $1"; exit 1 ;;
  esac
done

if [ -z "$PROJ" ] || [ ! -d "$PROJ" ]; then
  echo "FAIL"
  echo "REASON=usage: evidence-anchor-check.sh <project_dir> [--phase 2]"
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "FAIL"; echo "REASON=jq is required"; exit 1; }

case "$PHASE" in
  2|7|8|11-entry) : ;;
  *)
    echo "FAIL"
    echo "REASON=unsupported --phase $PHASE (available: 2, 7, 8, 11-entry)"
    exit 1
    ;;
esac

LEDGER="$PROJ/evidence/claim-anchors.ndjson"
INVENTORY="$PROJ/evidence/claim-inventory.json"
COVERAGE_MIN="${SCHOLAR_EVIDENCE_ROW_COVERAGE_MIN:-70}"
STRICT="${SCHOLAR_EVIDENCE_STRICT:-0}"

# ── Locate the Phase-2 output (same search set as phase-verify.sh Phase 2) ──
LRH_FILE=""
for d in "$PROJ/drafts" "$PROJ/lit-review" "$PROJ/literature" "$PROJ"; do
  [ -d "$d" ] || continue
  LRH_FILE=$(find "$d" -maxdepth 1 -type f \
    \( -name "scholar-lrh-*.md" -o -name "lrh-*.md" -o -name "scholar-lit-review-*.md" \) \
    2>/dev/null | head -1 || true)
  [ -n "$LRH_FILE" ] && break
done

# ── INERT: no evidence/ dir → legacy / pre-feature project ──
# scaffold-project-dirs.sh creates evidence/ for every new project, and the
# ev_capture helper mkdir -p's it on first capture. A project with NO
# evidence/ dir predates the feature (or never loaded the protocol) and must
# not be failed retroactively — enforcement for such runs is the required
# "Evidence anchors: N created / M reused" log row in the producing skill.
if [ ! -d "$PROJ/evidence" ]; then
  echo "RESULT: INERT — no evidence/ dir (legacy or pre-feature project); nothing to check"
  exit 3
fi

# ═══════════════════════ Phase 7 mode ═══════════════════════
if [ "$PHASE" = "7" ]; then
  TAG_COVERAGE_MIN="${SCHOLAR_EVIDENCE_TAG_COVERAGE_MIN:-60}"
  ISSUES=0; ADVISORIES=0; REPORT=""
  if [ ! -s "$LEDGER" ]; then
    echo "RESULT: YELLOW — no evidence ledger; drafting could not bind anchored evidence (Phase-2 gate owns ledger production)"
    [ "$STRICT" = "1" ] && exit 1
    exit 2
  fi
  # Evidence-bearing section drafts (comment tags are line-local, so line
  # scans are sufficient; drafts resolved by fixed glob, maxdepth 1).
  DRAFTS=$(find "$PROJ/drafts" -maxdepth 1 -type f \
    \( -name "draft-intro*.md" -o -name "draft-introduction*.md" \
       -o -name "draft-theory*.md" -o -name "draft-literature*.md" \
       -o -name "draft-discussion*.md" \) 2>/dev/null | sort || true)
  if [ -z "$DRAFTS" ]; then
    echo "RESULT: INERT — no evidence-bearing section drafts under $PROJ/drafts yet"
    exit 3
  fi
  TOTAL_TAGS=0; UNRESOLVED_TAGS=0; ADJ_MISMATCH=0; CITE_LINES=0; TAGGED_CITE_LINES=0
  CITE_RE='\(([A-Z][A-Za-z-]+[^)]*[12][0-9]{3}[a-z]?)\)|\[@[a-zA-Z]'
  TAG_RE='<!--[[:space:]]*ev:[[:space:]]*[a-z0-9_,[:space:]-]*-->'
  while IFS= read -r df; do
    [ -f "$df" ] || continue
    c=$(grep -cE "$CITE_RE" "$df" 2>/dev/null || true); CITE_LINES=$((CITE_LINES + ${c:-0}))
    t=$(grep -E "$CITE_RE" "$df" 2>/dev/null | grep -cE "$TAG_RE" || true); TAGGED_CITE_LINES=$((TAGGED_CITE_LINES + ${t:-0}))
    # Per-tag resolution + cite-key adjacency
    while IFS= read -r line; do
      ids=$(printf '%s\n' "$line" | grep -oE "$TAG_RE" | grep -oE '[a-z0-9_-]+-[0-9a-f]{8}' || true)
      [ -n "$ids" ] || continue
      # Adjacency is judged against the PROSE — strip HTML comments first,
      # otherwise the anchor_id inside the tag trivially matches its own
      # cite_key and the relevance check never fires.
      lline=$(printf '%s' "$line" | sed -E 's/<!--[^>]*-->//g' | tr '[:upper:]' '[:lower:]')
      for id in $ids; do
        TOTAL_TAGS=$((TOTAL_TAGS + 1))
        if ! grep -qF "\"anchor_id\":\"$id\"" "$LEDGER" 2>/dev/null; then
          UNRESOLVED_TAGS=$((UNRESOLVED_TAGS + 1)); continue
        fi
        ck=$(grep -F "\"anchor_id\":\"$id\"" "$LEDGER" | head -1 | jq -r '.cite_key // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')
        [ -n "$ck" ] || continue
        author=$(printf '%s' "$ck" | sed 's/[0-9].*$//'); year=$(printf '%s' "$ck" | grep -oE '[12][0-9]{3}' | head -1 || true)
        ok=1
        [ -n "$author" ] && { printf '%s' "$lline" | grep -q "$author" || ok=0; }
        [ -n "$year" ] && { printf '%s' "$lline" | grep -q "$year" || ok=0; }
        [ "$ok" = "1" ] || ADJ_MISMATCH=$((ADJ_MISMATCH + 1))
      done
    done < <(grep -E "$TAG_RE" "$df" 2>/dev/null || true)
  done <<EOF_DRAFTS
$DRAFTS
EOF_DRAFTS
  if [ "$UNRESOLVED_TAGS" -gt 0 ]; then
    REPORT="${REPORT}\n  RED: $UNRESOLVED_TAGS <!--ev:--> tag(s) reference anchor_ids missing from the ledger"
    ISSUES=$((ISSUES + 1))
  fi
  if [ "$ADJ_MISMATCH" -gt 0 ]; then
    REPORT="${REPORT}\n  YELLOW: $ADJ_MISMATCH tag(s) whose anchor cite_key does not appear in the tagged line (presence != relevance)"
    ADVISORIES=$((ADVISORIES + 1))
  fi
  if [ "$CITE_LINES" -gt 0 ]; then
    PCT=$(( TAGGED_CITE_LINES * 100 / CITE_LINES ))
    if [ "$PCT" -lt "$TAG_COVERAGE_MIN" ]; then
      REPORT="${REPORT}\n  YELLOW: ev-tag coverage ${PCT}% (${TAGGED_CITE_LINES}/${CITE_LINES} citation-bearing lines) below threshold ${TAG_COVERAGE_MIN}%"
      ADVISORIES=$((ADVISORIES + 1))
    fi
  fi
  echo "Evidence anchor check (--phase 7) on $PROJ"
  echo "  Drafts scanned: $(printf '%s\n' "$DRAFTS" | grep -c . ); tags: $TOTAL_TAGS; citation lines: $CITE_LINES (tagged: $TAGGED_CITE_LINES)"
  [ -n "$REPORT" ] && printf "%b\n" "$REPORT"
  if [ "$ISSUES" -gt 0 ]; then echo "RESULT: RED — $ISSUES structural issue(s)"; exit 1; fi
  if [ "$ADVISORIES" -gt 0 ]; then
    if [ "$STRICT" = "1" ]; then echo "RESULT: RED — advisories promoted by SCHOLAR_EVIDENCE_STRICT=1"; exit 1; fi
    echo "RESULT: YELLOW — $ADVISORIES advisory issue(s)"; exit 2
  fi
  echo "RESULT: GREEN — all tags resolve; adjacency and coverage clear"
  exit 0
fi
# ═══════════════════════ Phase 8 / 11-entry helpers ═══════════════
_ev_find_audit() {
  local evdir="$PROJ/evidence" pointer cand
  pointer="$evdir/LATEST-audit.txt"
  if [ -f "$pointer" ]; then
    cand=$(tr -d '[:space:]' < "$pointer")
    case "$cand" in
      /*) : ;;
      ?*) cand="$evdir/$cand" ;;
    esac
    [ -f "$cand" ] && { printf '%s' "$cand"; return 0; }
  fi
  find "$evdir" -maxdepth 1 -type f -name "claim-faithfulness-audit-*.ndjson" 2>/dev/null | sort | tail -1
}

# ═══════════════════════ Phase 8 mode ═══════════════════════
if [ "$PHASE" = "8" ]; then
  AUDIT_COVERAGE_MIN="${SCHOLAR_EVIDENCE_AUDIT_COVERAGE_MIN:-70}"
  METADATA_ONLY_MAX="${SCHOLAR_EVIDENCE_METADATA_ONLY_MAX:-40}"
  ISSUES=0; ADVISORIES=0; REPORT=""
  AUDIT=$(_ev_find_audit)
  if [ ! -s "$LEDGER" ]; then
    echo "RESULT: YELLOW — no evidence ledger; audit coverage cannot be assessed"
    [ "$STRICT" = "1" ] && exit 1
    exit 2
  fi
  if [ -z "$AUDIT" ] || [ ! -s "$AUDIT" ]; then
    if [ -f "$PROJ/logs/project-state.md" ]; then
      echo "RESULT: RED — ledger has $(wc -l < "$LEDGER" | tr -d ' ') anchor(s) but no claim-faithfulness audit was produced (a skipped audit must not be indistinguishable from a passing one; dispatch verify-claim-faithfulness — phase-citation.md)"
      exit 1
    fi
    echo "RESULT: YELLOW — no claim-faithfulness audit yet (standalone run)"
    [ "$STRICT" = "1" ] && exit 1
    exit 2
  fi
  # (b) consistency of the audit artifact itself
  CONS_GATE="$(cd "$(dirname "$0")" && pwd)/check-claim-audit-consistency.sh"
  if [ -x "$CONS_GATE" ]; then
    if ! CONS_OUT=$(bash "$CONS_GATE" "$AUDIT" 2>&1); then
      REPORT="${REPORT}\n  RED: audit fails check-claim-audit-consistency.sh — $(printf '%s\n' "$CONS_OUT" | grep '^  RED:' | head -2 | tr '\n' ' ')"
      ISSUES=$((ISSUES + 1))
    fi
  fi
  # (c) HIGH severities — mirrors the Phase 8 Hard Stop
  HIGHS=$(jq -r 'select(.severity == "HIGH") | .claim_id' "$AUDIT" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${HIGHS:-0}" -gt 0 ]; then
    REPORT="${REPORT}\n  RED: $HIGHS HIGH-severity audit record(s) (CLAIM-REVERSED / CLAIM-UNSUPPORTED) — correct the manuscript before advancing"
    ISSUES=$((ISSUES + 1))
  fi
  # (d) audit coverage of tagged claims: every tag id appears in some anchor_refs
  TAGGED_IDS=$(find "$PROJ/drafts" -maxdepth 1 -type f -name "*.md" -exec grep -hoE '<!--[[:space:]]*ev:[[:space:]]*[a-z0-9_,[:space:]-]*-->' {} + 2>/dev/null \
    | grep -oE '[a-z0-9_-]+-[0-9a-f]{8}' | sort -u || true)
  if [ -n "$TAGGED_IDS" ]; then
    REFED_IDS=$(jq -r '(.anchor_refs // [])[]' "$AUDIT" 2>/dev/null | sort -u)
    TOTAL_TAGGED=$(printf '%s\n' "$TAGGED_IDS" | grep -c . )
    COVERED_TAGGED=$(comm -12 <(printf '%s\n' "$TAGGED_IDS") <(printf '%s\n' "$REFED_IDS") | grep -c . || true)
    PCT=$(( ${COVERED_TAGGED:-0} * 100 / TOTAL_TAGGED ))
    if [ "$PCT" -lt "$AUDIT_COVERAGE_MIN" ]; then
      REPORT="${REPORT}\n  YELLOW: audit covers ${PCT}% (${COVERED_TAGGED}/${TOTAL_TAGGED}) of tagged anchors (threshold ${AUDIT_COVERAGE_MIN}%)"
      ADVISORIES=$((ADVISORIES + 1))
    fi
  fi
  # (e) unused anchors: in the ledger, but neither tagged, inventoried, nor audited
  UNUSED=$(jq -r '.anchor_id' "$LEDGER" 2>/dev/null | sort -u | comm -23 - <( { printf '%s\n' "${TAGGED_IDS:-}"; jq -r '(.anchor_refs // [])[]' "$AUDIT" 2>/dev/null; [ -s "$INVENTORY" ] && jq -r '.rows[]?.anchor_ids[]?' "$INVENTORY" 2>/dev/null; } | grep . | sort -u) | grep -c . || true)
  if [ "${UNUSED:-0}" -gt 0 ]; then
    REPORT="${REPORT}\n  YELLOW: $UNUSED unused anchor(s) — captured but never bound to a claim or audited (see dossier's Unused section)"
    ADVISORIES=$((ADVISORIES + 1))
  fi
  # (f) metadata-only rate among scholar-citation INSERT anchors — an INSERT
  # run that skipped passage capture shows up here as tier degradation.
  MDO_LINE=$(jq -rs '
    [.[] | select(.produced_by == "scholar-citation")] as $c
    | if ($c | length) == 0 then "n/a (no scholar-citation anchors)"
      else (([$c[] | select(.evidence_form == "metadata_only" or .access_tier == "T4_none")] | length) * 100 / ($c | length) | floor | tostring) + "% of \($c | length)"
      end' "$LEDGER" 2>/dev/null)
  echo "  INFO: metadata-only rate among scholar-citation anchors: ${MDO_LINE:-n/a}"
  MDO_PCT=$(printf '%s' "$MDO_LINE" | grep -oE '^[0-9]+' || true)
  if [ -n "$MDO_PCT" ] && [ "$MDO_PCT" -gt "$METADATA_ONLY_MAX" ]; then
    REPORT="${REPORT}\n  YELLOW: metadata-only rate ${MDO_PCT}% exceeds ${METADATA_ONLY_MAX}% — INSERT is citing without reading (see mode-insert-audit.md I-4)"
    ADVISORIES=$((ADVISORIES + 1))
  fi
  echo "Evidence anchor check (--phase 8) on $PROJ"
  echo "  Audit: $(basename "$AUDIT") ($(wc -l < "$AUDIT" | tr -d ' ') record(s)); HIGH: ${HIGHS:-0}"
  [ -n "$REPORT" ] && printf "%b\n" "$REPORT"
  if [ "$ISSUES" -gt 0 ]; then echo "RESULT: RED — $ISSUES structural issue(s)"; exit 1; fi
  if [ "$ADVISORIES" -gt 0 ]; then
    if [ "$STRICT" = "1" ]; then echo "RESULT: RED — advisories promoted by SCHOLAR_EVIDENCE_STRICT=1"; exit 1; fi
    echo "RESULT: YELLOW — $ADVISORIES advisory issue(s)"; exit 2
  fi
  echo "RESULT: GREEN — audit consistent, no HIGH severities, coverage clear"
  exit 0
fi

# ═══════════════════════ Phase 11-entry mode (reconciliation) ═══════
if [ "$PHASE" = "11-entry" ]; then
  AUDIT=$(_ev_find_audit)
  if [ -z "$AUDIT" ] || [ ! -s "$AUDIT" ]; then
    echo "RESULT: INERT — no claim-faithfulness audit; reconciliation has nothing to compare (Phase-8 gate owns audit production)"
    exit 3
  fi
  # Canonical DRAFTING manuscript (tag-retained) via the shared resolver —
  # never newest-glob (the newest file post-11b is the stripped submission).
  RCD="$(cd "$(dirname "$0")" && pwd)/resolve-canonical-draft.sh"
  DRAFT=""
  if [ -f "$RCD" ]; then
    DRAFT=$(bash "$RCD" "$PROJ" drafting 2>/dev/null | grep '^CANONICAL_DRAFT=' | head -1 | cut -d= -f2- || true)
  fi
  if [ -z "$DRAFT" ] || [ ! -f "$DRAFT" ]; then
    echo "RESULT: INERT — no canonical drafting manuscript resolved; nothing to reconcile"
    exit 3
  fi
  command -v python3 >/dev/null 2>&1 || { echo "RESULT: YELLOW — python3 unavailable; fingerprint reconciliation skipped"; exit 2; }
  RECON=$(python3 - "$DRAFT" "$AUDIT" <<'PYEOF'
import hashlib, json, re, sys
draft_path, audit_path = sys.argv[1], sys.argv[2]

def norm(s):
    return re.sub(r"\s+", " ", s.lower()).strip()

def fp(s):
    return hashlib.sha256(norm(s).encode("utf-8")).hexdigest()

comment_re = re.compile(r"<!--.*?-->")
tag_re = re.compile(r"<!--\s*ev:\s*[a-z0-9_,\s-]+?-->")
draft_fps, tagged_fps = set(), set()
with open(draft_path, encoding="utf-8", errors="replace") as f:
    for line in f:
        stripped = comment_re.sub("", line).strip()
        if not stripped:
            continue
        h = fp(stripped)
        draft_fps.add(h)
        if tag_re.search(line):
            tagged_fps.add(h)

audit_fps = set()
with open(audit_path, encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        cf = r.get("claim_fingerprint")
        if cf:
            audit_fps.add(cf)
        else:
            # fall back to hashing the audited manuscript_quote
            mq = r.get("manuscript_quote")
            if mq:
                audit_fps.add(fp(comment_re.sub("", mq).strip()))

stale = len(audit_fps - draft_fps)        # audited then rewritten/removed
unaudited = len(tagged_fps - audit_fps)   # tagged now, never audited
print(f"STALE={stale}")
print(f"UNAUDITED={unaudited}")
print(f"AUDITED={len(audit_fps)}")
print(f"TAGGED={len(tagged_fps)}")
PYEOF
)
  STALE=$(printf '%s\n' "$RECON" | grep '^STALE=' | cut -d= -f2)
  UNAUDITED=$(printf '%s\n' "$RECON" | grep '^UNAUDITED=' | cut -d= -f2)
  echo "Evidence reconciliation (--phase 11-entry) on $PROJ"
  echo "  Draft: $DRAFT"
  printf '%s\n' "$RECON" | sed 's/^/  /'
  if [ "${STALE:-0}" -gt 0 ] || [ "${UNAUDITED:-0}" -gt 0 ]; then
    MSG="$STALE audited claim(s) rewritten/removed since the Phase-8 audit; $UNAUDITED tagged claim(s) never audited — re-adjudicate before tag stripping (re-dispatch verify-claim-faithfulness on the changed claims)"
    if [ "${SCHOLAR_EVIDENCE_RECONCILE_SOFT:-0}" = "1" ]; then
      echo "RESULT: YELLOW — $MSG (demoted by SCHOLAR_EVIDENCE_RECONCILE_SOFT=1)"
      exit 2
    fi
    echo "RESULT: RED — $MSG"
    exit 1
  fi
  echo "RESULT: GREEN — every audited claim still present verbatim; every tagged claim audited"
  exit 0
fi

# ═══════════════════════ Phase 2 mode (below) ═══════════════

ISSUES=0
ADVISORIES=0
REPORT=""

# ── Ledger absent entirely ──
if [ ! -s "$LEDGER" ]; then
  if [ -n "$LRH_FILE" ]; then
    if [ -f "$PROJ/logs/project-state.md" ]; then
      echo "RESULT: RED — lit-review output exists but evidence ledger is absent/empty on an orchestrated project"
      echo "  Expected: $LEDGER (see skills/_shared/evidence-ledger.md)"
      echo "  Lit-review output: $LRH_FILE"
      exit 1
    else
      echo "RESULT: YELLOW — lit-review output exists but evidence ledger is absent/empty (standalone run)"
      echo "  Expected: $LEDGER (see skills/_shared/evidence-ledger.md)"
      [ "$STRICT" = "1" ] && exit 1
      exit 2
    fi
  fi
  echo "RESULT: INERT — evidence/ exists but no ledger and no lit-review output yet"
  exit 3
fi

# ── (a) Schema-lite validation of every ledger line ──
TOTAL_LINES=$(wc -l < "$LEDGER" | tr -d ' ')
VALID_LINES=$(jq -c '
  select(
    .schema == "claim-anchor/v1"
    and (.anchor_id | type == "string" and test("^[a-z0-9_-]+-[0-9a-f]{8}$"))
    and (.cite_key | type == "string" and length > 0)
    and (.claim_kind | IN("prose_sentence","map_cell","hypothesis","mechanism_status","magnitude","theory_attribution","gap_claim","reading_list"))
    and (.stance | IN("supports","contradicts","qualifies"))
    and (.evidence_form | IN("source_verbatim","abstract_verbatim","kg_paraphrase","metadata_only"))
    and (.access_tier | IN("T0_kg_fulltext","T1_fulltext","T2_oa_fulltext","T3_abstract","T4_none"))
    and (.produced_by | type == "string" and length > 0)
    and (.ts | type == "string" and length > 0)
  )' "$LEDGER" 2>/dev/null | wc -l | tr -d ' ')
INVALID_LINES=$((TOTAL_LINES - VALID_LINES))
if [ "$INVALID_LINES" -gt 0 ]; then
  REPORT="${REPORT}\n  RED: $INVALID_LINES of $TOTAL_LINES ledger line(s) fail claim-anchor/v1 validation (schema/claim-anchor.schema.json)"
  ISSUES=$((ISSUES + 1))
fi

# ── Quote-cap advisory (protocol §1: evidence_quote <= 60 words) ──
OVERLONG=$(jq -r 'select(.evidence_quote != null) | .evidence_quote' "$LEDGER" 2>/dev/null \
  | awk '{ if (NF > 60) c++ } END { print c+0 }')
if [ "${OVERLONG:-0}" -gt 0 ]; then
  REPORT="${REPORT}\n  YELLOW: $OVERLONG evidence_quote(s) exceed the 60-word cap"
  ADVISORIES=$((ADVISORIES + 1))
fi

# ── (b)+(c)+(d) Inventory join ──
COVERED=0; ROWS=0; UNRESOLVED_IDS=0
if [ ! -s "$INVENTORY" ]; then
  if [ -n "$LRH_FILE" ]; then
    REPORT="${REPORT}\n  YELLOW: evidence/claim-inventory.json missing — map rows cannot be joined to anchors"
    ADVISORIES=$((ADVISORIES + 1))
  fi
else
  if ! jq -e 'type == "object" and (.rows | type == "array")' "$INVENTORY" >/dev/null 2>&1; then
    REPORT="${REPORT}\n  RED: claim-inventory.json is malformed (expected {rows: [...]})"
    ISSUES=$((ISSUES + 1))
  else
    ROWS=$(jq '.rows | length' "$INVENTORY")
    # A row is covered when >=1 of its anchor_ids appears in the ledger.
    COVERED=$(jq -r --slurpfile inv "$INVENTORY" -n '
      [inputs.anchor_id] as $ledger_ids
      | [$inv[0].rows[] | select((.anchor_ids // []) | map(IN($ledger_ids[])) | any)]
      | length' "$LEDGER" 2>/dev/null || echo 0)
    # Inventory anchor_ids that resolve to nothing (typos / dropped records).
    UNRESOLVED_IDS=$(jq -r --slurpfile inv "$INVENTORY" -n '
      [inputs.anchor_id] as $ledger_ids
      | [$inv[0].rows[] | (.anchor_ids // [])[] | select(IN($ledger_ids[]) | not)]
      | length' "$LEDGER" 2>/dev/null || echo 0)
    if [ "$ROWS" -gt 0 ]; then
      PCT=$(( COVERED * 100 / ROWS ))
      if [ "$PCT" -lt "$COVERAGE_MIN" ]; then
        REPORT="${REPORT}\n  YELLOW: inventory row coverage ${PCT}% (${COVERED}/${ROWS}) below threshold ${COVERAGE_MIN}%"
        ADVISORIES=$((ADVISORIES + 1))
      fi
    else
      REPORT="${REPORT}\n  YELLOW: claim-inventory.json has zero rows while a landscape map exists"
      ADVISORIES=$((ADVISORIES + 1))
    fi
    if [ "$UNRESOLVED_IDS" -gt 0 ]; then
      REPORT="${REPORT}\n  RED: $UNRESOLVED_IDS inventory anchor_id(s) do not resolve in the ledger"
      ISSUES=$((ISSUES + 1))
    fi
  fi
fi

# ── Summary ──
echo "Evidence anchor check (--phase 2) on $PROJ"
echo "  Ledger: $TOTAL_LINES record(s), $VALID_LINES valid"
[ -s "$INVENTORY" ] && echo "  Inventory: $ROWS row(s), $COVERED covered"
[ -n "$REPORT" ] && printf "%b\n" "$REPORT"

if [ "$ISSUES" -gt 0 ]; then
  echo "RESULT: RED — $ISSUES structural issue(s)"
  exit 1
fi
if [ "$ADVISORIES" -gt 0 ]; then
  if [ "$STRICT" = "1" ]; then
    echo "RESULT: RED — $ADVISORIES advisory issue(s) promoted by SCHOLAR_EVIDENCE_STRICT=1"
    exit 1
  fi
  echo "RESULT: YELLOW — $ADVISORIES advisory issue(s)"
  exit 2
fi
echo "RESULT: GREEN — ledger valid; inventory rows covered"
exit 0
