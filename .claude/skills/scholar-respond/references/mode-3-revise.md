# Scholar Respond — Progressive-Disclosure Reference

This reference is loaded on demand when its mode is selected from the Dispatch Table;
the common protocol, evidence and severity schema, and routing logic live in the
always-loaded `SKILL.md`. It carries the mode-specific procedure only.

This mode loads no companion reference: its collaborators (scholar-write, scholar-verify,
scholar-code-review, the `_shared/` protocols) are loaded inline in Steps 2–3.

## MODE 3: REVISE THE MANUSCRIPT

Use to execute section-by-section revisions based on the response letter.

### Step 1: Build a Revision Plan with Word Budget

From the response letter (Mode 2) or user-provided comments, extract all revision actions:

```
===== REVISION PLAN =====

Word Budget:
  Current manuscript: [N] words
  Journal limit: [N] words
  Available budget: [+/- N] words

─────────────────────────────────────────────
Priority 1 — Critical (editor + multi-reviewer):
[R1.1] Methods §, para 3    → Add pre-trend test + event study figure     [+200 words]
[Ed.1] Introduction, last ¶ → Rewrite contribution statement              [+100 words]

Priority 2 — Major:
[R1.2] Table 2              → Replace odds ratios with AME + 95% CI       [±0 words]
[R2.1] Theory §             → Add mechanism paragraph (X → M → Y)         [+300 words]

Priority 3 — Minor:
[R2.2] Theory § ¶3          → Add citation: Lee (2019)                    [+20 words]
[R3.1] Introduction         → Cut from 1,200 to 900 words                 [−300 words]

Consistency updates (always do last):
[Consist.] Abstract         → Update to reflect revised finding framing    [±0 words]
[Consist.] H labels         → Verify H1–H3 match across Theory, Results, Discussion
─────────────────────────────────────────────
Total revisions: [N] | Critical: [N] | Major: [N] | Minor: [N]
Estimated word count change: [+/- N words]
New estimated total: [N] words (limit: [N])

⚠ WORD COUNT WARNING: [if projected total exceeds limit, flag which sections to cut]
```

Confirm the revision plan with the user before executing.

### Step 2: Load Reference Manager and Writing Skill

**Step 2a — Re-load reference manager** (shell state does not persist between Bash calls):
```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}/.claude/skills"
eval "$(cat "$SKILL_DIR/_shared/refmanager-backends.md" | sed -n '/^```bash/,/^```/p' | sed '1d;$d')" 2>/dev/null
echo "REF_SOURCES=$REF_SOURCES | ZOTERO_DB=${ZOTERO_DB:-not found}"
```

This ensures `scholar_search` is available for any citation additions during revisions. When a revision item requires a new citation, call `scholar_search "KEYWORD" 15 keyword` to verify against Zotero/local backends before inserting. Flag any unverified citations as `[CITATION NEEDED]`.

**Step 2b — Load writing skill** for revision execution:
```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}"
cat "$SKILL_DIR/.claude/skills/scholar-write/SKILL.md"
```

For each revision item, apply `/scholar-write revise [section]`:
- Paste the relevant existing section text as input
- Specify the reviewer concern and required change as the revision instruction
- Use the REVISE mode's `[REVISED: reason]` annotation system

For each revision, produce a **diff**:
```
─── REVISION [R#.#] ───────────────────────
SECTION: [Methods § para 3]
COMMENT: [R1.1 — Parallel trends not tested]

ORIGINAL:
"[original text]"

REVISED:
"[new text]"

REASON: Addresses R1.1 (parallel trends) and partially addresses Ed.1 (identification)
WORD Δ: [+200 words]
RUNNING TOTAL: [N] words ([N] remaining in budget)
─────────────────────────────────────────────
```

**Revision writing standards**:
- Match the voice and tense of the surrounding text
- Do not introduce new claims not in the response letter
- Solve exactly the reviewer's concern — no over-revision
- Preserve strong existing text; change only what is needed
- **R2+ rule**: Minimal changes only. Do not rewrite paragraphs that were not flagged.

### Step 3: Consistency Check

After all revisions:
- [ ] Table and figure references in text still match the actual tables/figures
- [ ] Table and figure numbering is sequential (no gaps or duplicates)
- [ ] Abstract accurately reflects any changed findings or framing
- [ ] Contribution statement in Introduction reflects revisions
- [ ] Hypothesis labels (H1, H2...) are consistent across Theory, Results, Discussion
- [ ] All hypothesis results are discussed (no orphan hypotheses)
- [ ] Word count is within journal limit after all revisions
- [ ] All [CITATION NEEDED] markers from revision are flagged for `/scholar-citation`
- [ ] **NEW citations introduced during R&R** are verified via local library, CrossRef, Semantic Scholar, or OpenAlex — not inserted from Claude's memory alone
- [ ] **Claim verification (MANDATORY):** All prose claims attributing findings to newly added citations are checked against Knowledge Graph or PDF text — run `scholar-citation` Step V-3.5. R&R citations added under time pressure are the highest risk for mischaracterization. Flag all 7 marker types: `[CLAIM-REVERSED]`, `[CLAIM-MISCHARACTERIZED]`, `[CLAIM-OVERCAUSAL]`, `[CLAIM-UNSUPPORTED]`, `[CLAIM-WRONG-POPULATION]`, `[CLAIM-IMPRECISE]`, `[CLAIM-NOT-CHECKABLE]`. Correct all error-level markers before saving.
- [ ] Reference list includes all newly cited works and removes any dropped citations
- [ ] Tracked changes / blue text marking is applied consistently
- [ ] No new typos or grammatical errors introduced by revisions

**Run the claim verification gate on the revised manuscript:**
```bash
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/verify-claims.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/verify-claims.sh" "[revised_manuscript_path]" || true
```

### Step 3a: New-Analysis Gate (MANDATORY when reviewers request new analyses)

**Purpose:** R&R reviewers routinely ask for new regressions (add state FE, cluster SEs differently, subset sample, different outcome). The highest failure mode in R&R is running the new analysis without the rigor of the original pipeline, then dropping numbers into the response letter via prose paraphrase. This gate forces new analyses through the same contract as the initial study.

**Trigger:** any "Items Requiring Author Action" in the response strategy that involves re-running or adding a regression / subset / specification.

**Protocol — every new analysis dispatched from an R&R response must:**

1. Generate the analysis script under `${PROJ}/scripts/rr-NN-[description].R`, do NOT execute yet.
2. Run `scholar-code-review` in `statistics` + `data-handling` + `correctness` mode against the new script, using the Phase 3 design blueprint (if available) or the reviewer's specification as compliance reference. **Save the consolidated report + reviewed-scripts manifest (scholar-code-review Steps 5a/5a.5) BEFORE executing** — the review must be hash-bound to the exact `rr-NN-*.R` bytes that run (`pre-exec-review-check.sh` verifiable); a post-review edit re-enters Step 6 re-review. Apply the **Code-Review Fix Loop** from `cat "${SCHOLAR_SKILL_DIR:-.}/.claude/skills/_shared/code-review-fix-loop.md"`. CRITICAL halts.
3. Load the registry contract and adjudication rule:
   ```bash
   cat "${SCHOLAR_SKILL_DIR:-.}/.claude/skills/_shared/results-registry-contract.md"
   cat "${SCHOLAR_SKILL_DIR:-.}/.claude/skills/scholar-analyze/references/adjudication-rule.md"
   ```
   The new script must emit `${PROJ}/tables/rr-results-registry.csv` and (if hypothesis-bearing) `${PROJ}/tables/rr-adjudication-log.csv` in the same schemas as the originals, appended or separate.
4. Execute in a clean R session, then run plausibility + direction-consistency + (for ASR/AJS/Demography/Nature/Science) clean-room re-run checks from `cat "${SCHOLAR_SKILL_DIR:-.}/.claude/skills/_shared/phase-runtime-sanity.md"`. CRITICAL halts.
5. Disk-citation discipline in the response letter (Step 4 below): every numeric claim from a new analysis must carry `[rr-results-registry.csv row=X model_id=Y]` — never a prose paraphrase of the agent's return text.

**Skip only if:** the reviewer's comment is handled without new statistics (rewording, adding citations, arguing against the request, noting a limitation).

---

### Step 3b: Verification Gate (scholar-verify)

**Purpose:** R&R revisions often introduce new numbers, change table references, or alter statistical claims. Run `scholar-verify` on the revised manuscript to catch inconsistencies introduced during revision. When new analyses were run in Step 3a, `verify-numerics` and `verify-logic` MUST also compare prose claims against `rr-results-registry.csv` and `rr-adjudication-log.csv`.

**Check for raw outputs:**
```bash
OUTPUT_ROOT="${OUTPUT_ROOT:-output}"
TABLE_COUNT=$(ls "${OUTPUT_ROOT}"/tables/*.{html,tex,csv,docx} 2>/dev/null | wc -l)
FIGURE_COUNT=$(ls "${OUTPUT_ROOT}"/figures/*.{pdf,png,svg} 2>/dev/null | wc -l)
echo "Tables: $TABLE_COUNT | Figures: $FIGURE_COUNT"
```

**If raw outputs exist** (tables or figures found):

Read the `scholar-verify` SKILL.md:
```bash
cat .claude/skills/scholar-verify/SKILL.md
```

Run `scholar-verify` in **full** mode on the revised manuscript. This launches all 4 agents:
- **Stage 1**: verify-numerics + verify-figures (raw outputs → revised manuscript tables/figures)
- **Stage 2**: verify-logic + verify-completeness (revised manuscript tables/figures → revised prose)

This is especially important for R&R because:
1. New analyses requested by reviewers may have been transcribed incorrectly
2. Revised text may reference old (pre-revision) numbers
3. New tables/figures added during revision need completeness verification

**If no raw outputs exist**: The manual consistency checklist in Step 3 above is sufficient. Proceed to Step 4.

**Gate decision:**
- **0 CRITICAL issues**: Proceed to Step 4.
- **1+ CRITICAL issues**: Fix before proceeding. Include fixes in the response letter as additional revisions made during consistency checking.

Add any verification-driven fixes to the revision tracking in Step 4's Revision Summary under a "Post-revision verification fixes" subsection.

#### Step 3c (Optional): External Review via Codex (scholar-openai)

**Purpose:** For R&R revisions that involved substantial new analysis or major rewriting, run an independent external review via OpenAI Codex agents for a second opinion.

**Trigger:** User opts in, OR Step 3b found CRITICAL issues (cross-validate with external model).

```bash
cat .claude/skills/scholar-openai/SKILL.md
```

Run `scholar-openai` in the appropriate mode:
- `code` — if R&R involved new analysis scripts
- `stats` — if R&R involved new tables/numbers
- `full` — if R&R was comprehensive

Cross-reference Codex findings with Step 3b findings. Issues confirmed by both get highest confidence.

### Step 4: Produce Revision Summary

```
===== REVISION SUMMARY =====

Round: [R1 / R2 / R3]
Total revisions: [N] | Critical: [N] | Major: [N] | Minor: [N]

Changes by section:
  Abstract:       [description]
  Introduction:   [description]
  Theory:         [description]
  Methods:        [description]
  Results:        [description]
  Discussion:     [description]
  Tables/Figures: [description]
  Appendix:       [description]

Word count: Original [N] → Revised [N] (limit: [N])

Consistency check: [PASSED / FAILED — list failures]

Items requiring author attention (beyond what was revised here):
  • [Any items beyond what was revised — e.g., new analysis to run, data to check]
  • [e.g., "Run new event study specification — requires re-running regression in R"]
  • [e.g., "Obtain original data for sensitivity analysis R2.3 requested"]

Recommended next steps:
  1. [Run pending analyses]
  2. [/scholar-citation insert — to add all new citations to reference list]
  3. [/scholar-respond cover-letter — to write the R&R cover letter]
```

---

## MODE Verification Checklist

After completing the mode, run a verification check via the Task tool; pass this checklist to the verifier:

> "You are verifying a scholar-respond output. Check the following:
>
> 1. All revision plan items are executed;
> 2. Diffs are provided for each change;
> 3. Word budget is tracked;
> 4. Consistency check passes;
> 5. No over-revision beyond what reviewers asked;
>
> Flag any issues found. Output: [pass/fail] + [list of issues if any]."

### Causal Language
- [ ] Causal language audit passed: response letter and revised text maintain the manuscript's language precision — if study is non-causal, do not upgrade to causal language even when responding to reviewers. See scholar-write SKILL.md for full rule

### Consistency
- [ ] Table/figure references match actual tables/figures
- [ ] Hypothesis labels (H1, H2...) consistent across all sections
- [ ] Contribution statement in Introduction reflects revisions
- [ ] No new analyses or content added beyond what reviewers requested (R2+ rule)
