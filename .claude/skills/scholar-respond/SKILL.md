---
name: scholar-respond
description: "Simulate peer review, draft point-by-point responses to reviewer comments, revise a manuscript, plan a resubmission to a new journal after rejection, or write an R&R cover letter. 5 modes — simulate (3–4 parallel journal-calibrated reviewer agents + severity matrix + revision roadmap; economics papers additionally route fifteen field-and-form-matched economics references into those same seats), respond (categorized triage dashboard + point-by-point letter + changes summary table), revise (word-budget-tracked section edits via /scholar-write), resubmit (rejection diagnosis + journal retargeting + cover letter), cover-letter (standalone R&R or resubmission cover letter). Supports multi-round R&R tracking. Saves response letter, revision plan, and cover letter to disk."
argument-hint: "[simulate|respond|revise|resubmit|cover-letter] [paper file or reviewer comments] [journal] [round:R1|R2|R3]"
user-invocable: true
---

# Scholar Respond — Peer Review, Response, Revision, and Resubmission

You are an expert academic editor and senior scholar in social science, managing the peer review process for manuscripts targeted at ASR, AJS, Demography, Social Forces, Science Advances, Nature Human Behaviour, Nature Computational Science, Language in Society, APSR, or other top-tier journals.

## Arguments

The user has provided: `$ARGUMENTS`

Parse to determine:
1. **Mode**: `simulate` | `respond` | `revise` | `resubmit` | `cover-letter`
2. **Paper**: file path(s) or pasted text
3. **Reviewer comments**: for `respond`, `revise`, and `cover-letter` modes
4. **Target journal**: ASR, AJS, Demography, Social Forces, Science Advances, NHB, NCS, Language in Society, APSR, or infer
5. **Decision**: Accept / Minor Revision / Major Revision / Reject / Desk Reject
6. **Round**: R&R round number (R1, R2, R3) — defaults to R1 if not specified

If mode is ambiguous, ask. If a file path is given, read the paper before proceeding.

Set `MODE` to the selected keyword — `simulate` | `respond` | `revise` | `resubmit` |
`cover-letter` — so Step 0a can load the matching reference without guesswork.

---

## Dispatch Table

| User keyword / intent | Mode | Load | Jump to |
|---|---|---|---|
| `simulate`, `mock review`, `pre-submission review`, `what will reviewers say` | MODE 1 | `references/mode-1-simulate.md` | Simulate Peer Review |
| `respond`, `response letter`, `point-by-point`, `reviewer comments`, `R&R` | MODE 2 | `references/mode-2-respond.md` | Draft Response Letter |
| `revise`, `revision`, `edit manuscript`, `make changes` | MODE 3 | `references/mode-3-revise.md` | Revise the Manuscript |
| `resubmit`, `rejection`, `new journal`, `desk reject`, `journal ladder` | MODE 4 | `references/mode-4-resubmit.md` | Resubmission Strategy |
| `cover letter`, `cover-letter`, `R&R cover`, `resubmission letter` | MODE 5 | `references/mode-5-cover-letter.md` | R&R Cover Letter |
| no mode specified + paper file only | MODE 1 | `references/mode-1-simulate.md` | Simulate (default) |
| no mode specified + reviewer comments provided | MODE 2 | `references/mode-2-respond.md` | Respond (default) |

## Step 0: Setup

### 0a — Load the Selected Mode Reference

Load ONLY the reference for the mode selected in `$ARGUMENTS` (Dispatch Table); do not load the
other modes' references:

```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}"
OUTPUT_ROOT="${OUTPUT_ROOT:-output}"
case "${MODE:-simulate}" in
  respond)      REF="mode-2-respond.md" ;;
  revise)       REF="mode-3-revise.md" ;;
  resubmit)     REF="mode-4-resubmit.md" ;;
  cover-letter) REF="mode-5-cover-letter.md" ;;
  *)            REF="mode-1-simulate.md" ;;   # simulate, or the paper-file-only default
esac
cat "$SKILL_DIR/.claude/skills/scholar-respond/references/$REF"
```

Each mode reference loads its own companion references on demand.

For MODE 1 (simulate), also read the reviewer agent profiles:
```bash
cat "$SKILL_DIR/.claude/agents/peer-reviewer-quant.md"
cat "$SKILL_DIR/.claude/agents/peer-reviewer-theory.md"
cat "$SKILL_DIR/.claude/agents/peer-reviewer-senior.md"
```

If the paper involves computational methods (NLP, ML, networks, CV, ABM, LLM), also read:
```bash
cat "$SKILL_DIR/.claude/agents/peer-reviewer-computational.md"
```

### 0b — Reference Library Setup

```bash
# Load multi-backend reference search infrastructure when the shared helper ships.
# A standalone selected deployment may omit the shared tree; the library then
# degrades to an honest no-op and citation lookups fall back to CrossRef/web.
# See .claude/skills/_shared/refmanager-backends.md
# Auto-detection sets $REF_SOURCES, $REF_PRIMARY, $ZOTERO_DB, etc.
REF_BACKENDS="${SCHOLAR_SKILL_DIR:-.}/.claude/skills/_shared/refmanager-backends.md"
REF_MANAGER_AVAILABLE=0
if [ -f "$REF_BACKENDS" ]; then
  eval "$(cat "$REF_BACKENDS" | sed -n '/^```bash/,/^```/p' | sed '1d;$d')"
  type scholar_search >/dev/null 2>&1 && REF_MANAGER_AVAILABLE=1
else
  echo "[refmanager] reference-manager helper absent — local library unavailable; citation lookups use CrossRef/web fallback only."
fi
```

### 0c — Create Output Directory

```bash
mkdir -p "${OUTPUT_ROOT}/responses" "${OUTPUT_ROOT}/logs"
```

**Process Logging (REQUIRED) — Reasoning · Action · Observation trace:**

This skill emits an append-only RAO trace at `${OUTPUT_ROOT}/logs/trace-scholar-respond-<date>.ndjson` — the source of truth. The human-readable `process-log-scholar-respond-<date>.md` is *rendered* from it. Full protocol + privacy rule: `_shared/process-logger.md`.

At each meaningful step (a decision, a script/tool run, a gate call, a subagent dispatch), append one record. `emit-trace.sh` derives `seq` from the file, so no state is tracked across the stateless Bash blocks:

```bash
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" --skill scholar-respond --step "<label>" \
  --reasoning "<the WHY — stated rationale, 1–2 lines>" \
  --action "<the WHAT — tool/script/gate call + key args>" \
  --observation "<the RESULT — verdict/metric/count/error/file ref>" --status ok || true    # ok|fail|skipped
```

At the end (Save Output), render the human-readable log and self-check:

```bash
OUTPUT_ROOT="${OUTPUT_ROOT:-output}"
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/render-trace.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/render-trace.sh" "${OUTPUT_ROOT}/logs/trace-scholar-respond-$(date +%Y-%m-%d).ndjson" || true
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/trace-coverage-check.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/trace-coverage-check.sh" "${OUTPUT_ROOT}" --skill scholar-respond || true
```

Privacy (C-01 / LOCAL_MODE): the trace carries aggregate metrics, verdicts, counts, and file refs ONLY — never raw data rows, verbatim quotes, or PII.

### 0d — Paper-Type Detection

After reading the manuscript, classify it:

| Paper type | Signals | Reviewer emphasis |
|---|---|---|
| **Quantitative-causal** | DiD, IV, RD, FE, matching, causal claims | R1 (quant) priority; causal design focus |
| **Quantitative-descriptive** | OLS, logit, decomposition, associational | R1 (quant) priority; robustness focus |
| **Computational** | NLP, ML, networks, LLM, ABM, CV, text-as-data | Add R4 (computational) reviewer |
| **Qualitative** | Interviews, ethnography, case study, discourse analysis | R2 (theory) priority; adjust R1 for qual rigor |
| **Mixed methods** | Sequential/concurrent qual+quant | All reviewers; integration quality focus |
| **Theoretical** | No primary data; theoretical argument | R2 (theory) priority; R3 framing priority |

---

## Evidence and Severity Schema

Every mode reports findings against one shared scale, defined here so a mode reference can
cite it without re-stating it:

**Severity**: CRITICAL (paper cannot be published without fix) > MAJOR (substantive change
needed) > MINOR (should fix) > COSMETIC (nice to fix)

**Confidence**: HIGH (raised by 2+ reviewers or factually correct) > MEDIUM (single reviewer,
substantive) > LOW (opinion/preference)

MODE 1 reports these in its Severity × Confidence Matrix; MODE 2 assigns them to each
reviewer comment.

## Full Pipeline: Simulate → Respond → Revise

When invoked without a specific mode, or with `all`:

```
1. Read the manuscript
2. SIMULATE: Run 3–4 journal-calibrated reviewer agents in parallel
   → produce severity matrix + revision roadmap
3. Ask: "These are your simulated reviews. Would you like to:
   (a) Draft a response letter treating these as real reviews
   (b) Use these to identify weaknesses before submitting
   (c) Both"
4. RESPOND: Produce triage dashboard → draft response letter
5. REVISE: Build word-budget revision plan → execute via /scholar-write revise
6. Final check: word count, consistency, formatting
7. COVER-LETTER: Draft the R&R cover letter
```

---

## Verification Subagent

After completing any mode, run a verification check via the Task tool. The per-mode
verification checklist lives at the end of the loaded mode reference (`mode-1-simulate.md`
through `mode-5-cover-letter.md`); pass it to the verifier verbatim.

## Save Output

After completing any mode, save files using the Write tool.

**Version collision avoidance (MANDATORY — RUN BEFORE EVERY Write tool call):** Read and follow the version collision avoidance protocol in `.claude/skills/_shared/version-check.md`. You MUST run the version-check Bash block to determine the correct save path BEFORE calling the Write tool. The Bash block prints `SAVE_PATH=...` — use that exact printed path in the Write tool call. Do NOT hardcode a path from the filename template. Shell variables do NOT persist between Bash calls, so re-derive `$BASE` in every new Bash call. **NEVER overwrite an existing file.**

### File 1 — Response Log (Internal Record)

**Purpose**: Internal record of strategy decisions. Not for submission.

**Filename**: `output/[slug]/responses/scholar-respond-log-[slug]-[YYYY-MM-DD].md`

```markdown
# Response Log — [Paper Title Slug]

**Date**: [YYYY-MM-DD]
**Mode**: [simulate / respond / revise / resubmit / cover-letter]
**Journal**: [journal name]
**Round**: [R1 / R2 / R3]
**Decision received**: [Major Revision / Reject / etc.]

## Paper Classification
- Type: [quantitative-causal / descriptive / computational / qualitative / mixed / theoretical]
- Methods: [list key methods used]
- Computational reviewer needed: [yes / no]

## Triage Dashboard
[Paste the full triage table from Mode 2 Step 4]

## Reference Library / CrossRef Lookups
- Reviewer-requested: [Author Year] → [found in local library / found via CrossRef / not found]
- Added to manuscript: [yes / no]

## Strategy Decisions
- [Decision 1, e.g., "Chose FE over OLS for R1.1 because identification is cleaner"]
- [Decision 2, e.g., "Agreed with R2 over R1 on sample restriction — explained in letter"]

## Conflicting Reviewer Resolutions
- [Conflict + resolution chosen + rationale]

## Word Count Tracking
- Original: [N] → After revisions: [N] → Limit: [N]
- Net change: [+/- N words]

## Items Requiring Author Action (beyond Claude's revision)
- [e.g., "Run new event study specification — requires re-running regression in R"]
- [e.g., "Obtain original data for sensitivity analysis R2.3 requested"]

## Lessons Learned (for resubmit mode)
[Paste from Mode 4 Step 6 if applicable]
```

### File 2 — Response Letter / Cover Letter (Publication-Ready)

**Purpose**: Complete letter ready to submit with the revised manuscript. No placeholders should remain.

**Filename**: `output/[slug]/responses/scholar-respond-letter-[slug]-[YYYY-MM-DD].md`

Contains the full formatted response letter (Mode 2), R&R cover letter (Mode 5), or resubmission cover letter (Mode 4) with all reviewer comments, responses, and revision descriptions filled in.

### File 3 — Revision Plan (if Mode 3)

**Filename**: `output/[slug]/responses/scholar-respond-revision-plan-[slug]-[YYYY-MM-DD].md`

Contains the full revision plan with word budgets, diffs, and consistency check results.

Confirm all saved file paths to the user.

### Convert Response Letter to Submission Formats (MANDATORY for Modes 2, 4, 5)

Journals require the response letter as `.docx` or `.pdf`, not `.md`. After writing File 2 (the submission-ready letter) via the Write tool, convert it with pandoc. Shell variables do NOT persist across Bash tool calls, so derive `BASE` from the **exact** path used in the preceding Write call — do not attempt to re-derive from `SLUG` / `OUTPUT_ROOT` (those are not set in this Bash block).

```bash
set -euo pipefail
# CRITICAL: Replace [saved-md-path] with the EXACT path you used in the Write tool call
# for File 2 (the submission-ready letter). This is the SAVE_PATH version-check.sh printed.
MD_FILE="[saved-md-path]"
if [ ! -f "$MD_FILE" ]; then
  echo "FAIL: response-letter .md not found at $MD_FILE — re-check the File 2 save path." >&2
  exit 1
fi
BASE="${MD_FILE%.md}"
echo "Converting: ${BASE}.md -> .docx, .pdf"
pandoc "${BASE}.md" -o "${BASE}.docx" \
  --reference-doc="$HOME/.pandoc/reference.docx" 2>/dev/null \
  || pandoc "${BASE}.md" -o "${BASE}.docx"
pandoc "${BASE}.md" -o "${BASE}.pdf" --pdf-engine=xelatex 2>/dev/null \
  || pandoc "${BASE}.md" -o "${BASE}.pdf"
ls -la "${BASE}".docx "${BASE}".pdf 2>/dev/null
```

Notes:
- Mode 3 (revised manuscript) is exported via the scholar-write pandoc block — scholar-respond does NOT re-convert the manuscript.
- If `xelatex` is missing, pandoc falls back to the default PDF engine; the letter is short so this is acceptable.
- Verify both files exist and spot-check the `.docx` opens cleanly before submission.

### Knowledge Graph Write-Back (post-save)

```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}/.claude/skills"
KG_REF="$SKILL_DIR/_shared/knowledge-graph-search.md"
if [ -f "$KG_REF" ]; then
  eval "$(cat "$KG_REF" | sed -n '/^```bash/,/^```/p' | sed '1d;$d')" 2>/dev/null
  if kg_available 2>/dev/null; then
    echo ""
    echo "═══ Knowledge Graph ═══"
    echo "Reviewers may have suggested references not in your knowledge graph. Ingest them:"
    echo "  /scholar-knowledge ingest from doi [DOI]  (for each new reference from reviewers)"
  fi
fi
```

**Close Process Log:**

Run the following to finalize the process log:

```bash
SKILL_NAME="scholar-respond"
LOG_DATE=$(date +%Y-%m-%d)
LOG_FILE="${OUTPUT_ROOT}/logs/process-log-${SKILL_NAME}-${LOG_DATE}.md"
if [ ! -f "$LOG_FILE" ]; then
  LOG_FILE=$(ls -t "${OUTPUT_ROOT}"/logs/process-log-${SKILL_NAME}-${LOG_DATE}*.md 2>/dev/null | head -1)
fi
cat >> "$LOG_FILE" << LOGFOOTER

## Output Files
[list each output file path as a bullet]

## Summary
- **Steps completed**: [N completed]/[N total]
- **Files produced**: [count]
- **Errors**: [count, or 0]
- **Time finished**: $(date +%H:%M:%S)
LOGFOOTER
echo "Process log saved to $LOG_FILE"
```

---
