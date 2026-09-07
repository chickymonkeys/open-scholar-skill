# MODE 2 — Draft Response Letter

Also load the companion reference(s) this mode uses:
```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}"
cat "$SKILL_DIR/.claude/skills/scholar-respond/references/response-templates.md"
cat "$SKILL_DIR/.claude/skills/scholar-respond/references/common-concerns.md"
```

## MODE 2: DRAFT RESPONSE LETTER

Use when the user has received actual reviewer comments and needs to draft a professional, persuasive response.

### Step 1: Parse Round and Decision Context

Identify:
- **R&R round**: R1 (first revision), R2 (second revision), R3 (third revision)
- **Decision received**: Major Revision, Minor Revision, Conditional Accept
- **Editor's letter**: Does the editor highlight specific priorities? (Editor priorities override individual reviewer preferences)
- **Number of reviewers**: 2, 3, or 4
- **Previous response letter** (for R2+): If available, check for continuity

**Round-specific calibration**:

| Round | Tone | Scope of changes | Editor expectations |
|-------|------|-------------------|---------------------|
| **R1** (Major Revision) | Thorough, appreciative, demonstrate substantial engagement | Large revisions expected; new analyses OK | Show you took every comment seriously |
| **R1** (Minor Revision) | Efficient, precise; don't over-revise | Targeted fixes only; don't introduce new material | Quick turnaround; minimal new concerns |
| **R2** | More direct; less deferential | Only address remaining concerns; do NOT add new content beyond what was requested | Editor wants to accept; don't create new problems |
| **R3** | Extremely concise; surgical | Only the specific remaining items; absolutely nothing new | Paper should be nearly final; any new issue = reject |

### Step 2: Parse and Categorize All Comments

Read every reviewer comment and assign:
- **[CRITICAL]**: Raised by 2+ reviewers or editor-flagged — must address first
- **[MAJOR-FEASIBLE]**: Major concern, addressable
- **[MAJOR-INFEASIBLE]**: Major concern, not fully addressable (data limitations, etc.)
- **[MINOR-SUBSTANTIVE]**: Minor but non-trivial (add table, rephrase argument)
- **[MINOR-EASY]**: Minor fix (typo, citation, clarification)
- **[DISAGREE]**: Reviewer misunderstood or is factually wrong — respectful pushback needed
- **[CONFLICT]**: Contradicts another reviewer's demand
- **[NEW-IN-R2+]**: Comment raised for the first time in R2 or later — flag separately

Also note: **cross-reviewer overlaps** — the same concern raised by 2+ reviewers is the top priority.

**For R2+ rounds**: Flag any comment that was NOT raised in the previous round. New R2 concerns are lower priority than carried-over concerns, unless the editor specifically elevates them.

### Step 3: Local Library + CrossRef Lookup for Reviewer-Requested Citations

When a reviewer recommends citing a specific paper or author:

**Step 3a — Search local reference library first**:

```bash
# Re-load reference manager (shell state lost between Bash calls)
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}/.claude/skills"
REF_BACKENDS="$SKILL_DIR/_shared/refmanager-backends.md"
if [ -f "$REF_BACKENDS" ]; then
  eval "$(cat "$REF_BACKENDS" | sed -n '/^```bash/,/^```/p' | sed '1d;$d')" 2>/dev/null
fi

# Uses the multi-backend search function from Step 0b. When the shared helper is
# absent (standalone selected deployment) the local search degrades to the CrossRef
# fallback in Step 3b — no command-not-found, no silent "library ready".
# Searches across all detected backends (Zotero, BibTeX, etc.)
if type scholar_search &>/dev/null 2>&1; then
  scholar_search "KEYWORD" 15 keyword
else
  echo "[refmanager] local library unavailable (helper absent) — proceeding to CrossRef fallback (Step 3b)."
fi
```

**Step 3b — CrossRef API fallback** (if not found in local library):

```bash
# Search CrossRef for a citation the reviewer requested
curl -s "https://api.crossref.org/works?query.bibliographic=AUTHOR+KEYWORD&rows=5&select=DOI,title,author,published-print,container-title" \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data.get('message',{}).get('items',[]):
    authors = ', '.join([a.get('family','') for a in item.get('author',[])])
    title = item.get('title',[''])[0]
    year = str(item.get('published-print',{}).get('date-parts',[['']])[0][0])
    journal = item.get('container-title',[''])[0]
    doi = item.get('DOI','')
    print(f'{authors} ({year}). {title}. {journal}. DOI: {doi}')
" 2>/dev/null
```

If found in local library, use the stored metadata. If found via CrossRef, note the DOI. If not found via either, use WebSearch.

**Evidence Ledger (MANDATORY for citation work in an R&R):** load `.claude/skills/_shared/evidence-ledger.md` and capture ONE tier-honest anchor per NEWLY added citation at the moment you finalize the claim it supports (`EV_PRODUCED_BY=scholar-respond`; library PDF read → `source_verbatim`; abstract → `abstract_verbatim`; metadata-only match → visible `metadata_only`) — R&R citations added under time pressure are the highest mischaracterization risk. Inherited `<!--ev: anchor_id-->` bindings travel WITH their sentence through revisions — carry the tag into revised text attached to the same claim; if a revision changes an audited claim's direction, magnitude, population, or causal strength, note `re-adjudicate` in the revision diff. The response/revision log MUST include the row `Evidence anchors: N created / M reused`.

### Step 4: Produce the Response Triage Dashboard

Before drafting the letter, present a structured overview:

```
===== RESPONSE TRIAGE DASHBOARD =====
Round: [R1 / R2 / R3]
Decision: [Major Revision / Minor Revision]
Date received: [YYYY-MM-DD]

| #    | Reviewer | Comment Summary              | Category         | Priority | Section Affected | Word Impact | Action Planned                     |
|------|----------|------------------------------|------------------|----------|------------------|-------------|-----------------------------------|
| R1.1 | R1       | Parallel trends not tested   | CRITICAL         | ★★★      | Methods, App.    | +200        | Add event study + pre-trend test   |
| R1.2 | R1       | Report AME not odds ratios   | MAJOR-FEASIBLE   | ★★       | Results          | ±0          | Replace OR with AME in Tables 2–3  |
| R2.1 | R2       | Mechanism is vague           | MAJOR-FEASIBLE   | ★★       | Theory           | +300        | Add mechanism ¶ to Theory §        |
| R2.2 | R2       | Missing citation: Lee 2019   | MINOR-EASY       | ★        | Theory           | +20         | Add to Theory ¶3 (library ✓)      |
| R3.1 | R3       | Introduction too long        | MINOR-EASY       | ★        | Introduction     | −300        | Cut intro from 1,200 to 900 words  |
| Ed.1 | Editor   | Clarify contribution         | CRITICAL         | ★★★      | Introduction     | +100        | Rewrite final intro ¶              |

Summary statistics:
  Total comments: [N] | Critical: [N] | Major: [N] | Minor: [N]
  Sections affected: [list]
  Estimated net word change: [+/- N words]
  Current word count: [N] → Projected: [N] (limit: [N])

Cross-reviewer overlaps (must fix first):
- [Issue] raised by R1 + R2: [description]

Conflicting demands:
- R1 says [X]; R2 says [opposite] → proposed resolution: [approach]

Infeasible requests:
- [R#.#] [reason why infeasible] → closest alternative: [what you will do instead]

Editor priorities (from decision letter):
- [Priority 1 — often the single most important thing to address]
- [Priority 2]

[R2+ only] New comments not in previous round:
- [R#.#] [NEW-IN-R2+] — [description] — priority: [lower unless editor-elevated]
```

Present the dashboard to the user and ask for confirmation before drafting.

### Step 5: Develop Response Strategy

For each comment, determine:
1. **Action**: What changes in the manuscript?
2. **Where**: Which section/paragraph/table?
3. **Tone**: Agree fully / Agree partially / Respectfully disagree
4. **Word impact**: How many words added/removed?

**Decision rules**:
- If raised by 2+ reviewers → must address fully, note the overlap in the response
- If editor highlighted → treat as highest priority regardless of reviewer count
- If reviewer is factually wrong → correct politely with citation
- If request is genuinely infeasible → explain why; offer the closest feasible alternative
- If reviewers conflict → name the conflict and explain your resolution (see `references/common-concerns.md` conflict templates)
- If paper's core argument is challenged → defend with evidence and logic, not just assertion
- **R2+ rule**: Do not introduce new analyses, new citations, or new arguments beyond what reviewers asked for. Scope creep in R2 is the #1 cause of R3 rejection.

### Step 6: Draft the Response Letter

```
===== RESPONSE TO REVIEWERS =====

[Title of Paper]
[Journal Name] | Manuscript #: [if available]
Round: [R1 / R2 / R3]
[Date]

Dear [Dr. LastName / "Editor"],

[Round-appropriate opening — see templates below]

In the revised manuscript, we have [1–2 sentence summary of the most
significant changes]. All revisions are indicated in [blue text / tracked
changes]. The most significant changes include:
• [Major change 1]
• [Major change 2]
• [Major change 3]

We respond to each comment in turn below.

─────────────────────────────────────────────
REVIEWER 1
─────────────────────────────────────────────

Comment 1.1: "[Exact quote of reviewer comment]"

Response: [See tone guidelines below]

Revision: [What changed, specific location: "We have revised the third
paragraph of the Methods section (p. 12) to read: '...'"]

---

Comment 1.2: "[Exact quote]"

Response: ...
Revision: ...

[Continue for all comments]

─────────────────────────────────────────────
REVIEWER 2
─────────────────────────────────────────────

[Same format]

─────────────────────────────────────────────
REVIEWER 3 (if applicable)
─────────────────────────────────────────────

[Same format]

─────────────────────────────────────────────
EDITOR'S COMMENTS (if applicable)
─────────────────────────────────────────────

[Same format]

─────────────────────────────────────────────
CHANGES SUMMARY TABLE
─────────────────────────────────────────────

| Section | Changes Made | Comments Addressed | Word Δ |
|---------|-------------|-------------------|--------|
| Abstract | Updated to reflect revised framing | R3.1 | −15 |
| Introduction | Rewritten contribution ¶; cut background | Ed.1, R3.1 | −200 |
| Theory | Added mechanism ¶; added Lee (2019) | R2.1, R2.2 | +320 |
| Methods | Added pre-trend test description | R1.1 | +200 |
| Results | Replaced OR with AME; added Table A1 | R1.2, R1.1 | +50 |
| Discussion | Updated interpretation of H2 | R2.1 | +80 |
| Appendix | New event study figure (Fig A1) | R1.1 | +100 |
| **Total** | | | **[net Δ]** |

Final word count: [N] (limit: [N])

─────────────────────────────────────────────

We believe the revised manuscript is substantially stronger and addresses
all reviewer concerns. We hope it is now suitable for publication in [Journal].

Sincerely,
[Corresponding Author Name]
[Title, Affiliation, Email]
```

**Round-specific openings**:

**R1 (Major Revision)**:
> "We are grateful to the Editor and [two/three] reviewers for their careful reading and constructive feedback. The comments have helped us substantially improve the paper. We have made significant revisions in response to all concerns."

**R1 (Minor Revision)**:
> "We thank the Editor and reviewers for their positive assessment and helpful suggestions. We have addressed all remaining points as detailed below."

**R2**:
> "We thank the Editor for the opportunity to revise further and the reviewers for their continued engagement with our work. We have carefully addressed each remaining concern. The changes in this round are targeted to the specific points raised."

**R3**:
> "We appreciate the reviewers' and Editor's patience in guiding this manuscript to its final form. We have made the remaining [N] requested changes, which are detailed below."

### Step 7: Apply Response Tone Guidelines

**Full agreement**:
> "We thank Reviewer [N] for this observation. We agree that [restate concern]. We have [specific action]. The revised text now reads: '[new text]' (p. X, lines Y–Z)."

**Partial agreement**:
> "We appreciate this comment and agree that [aspect X]. We have revised [section] accordingly. However, we respectfully note that [your position], because [reason + citation]. We have revised the text to clarify this: '[new text]' (p. X)."

**Respectful disagreement**:
> "We appreciate Reviewer [N]'s concern about [topic]. After careful consideration, we respectfully maintain our original approach for the following reasons: [1–3 specific reasons with logic or citation]. We have, however, revised p. X to make our rationale explicit: '[new text]'."

**Infeasible request**:
> "Reviewer [N] recommends [request]. We share the reviewer's interest in [the goal]. Unfortunately, [specific reason why infeasible]. As an alternative, we [closest feasible action]. We believe this addresses the reviewer's underlying concern, though we acknowledge this limitation in the Discussion (p. X)."

**Reviewer misunderstood**:
> "We appreciate Reviewer [N]'s close reading and believe this comment may reflect an ambiguity in our presentation. To clarify: [explanation]. We have revised p. X to make this explicit: '[new text]'."

**Cross-reviewer overlap** (note it explicitly):
> "Both Reviewers 1 and 2 raise concerns about [issue]. We agree this is a priority and have [action]. [Describe revision with location.]"

**R2+ new comment not in previous round**:
> "We appreciate Reviewer [N]'s new observation regarding [topic]. We have [action]. We note that this concern was not raised in the first round, and we have addressed it within the scope of the current revision."

---

## MODE Verification Checklist

After completing the mode, run a verification check via the Task tool; pass this checklist to the verifier:

> "You are verifying a scholar-respond output. Check the following:
>
> 1. Every reviewer comment has a numbered response — no skipped items;
> 2. Every response includes specific revision text or explains why none was made;
> 3. Cross-reviewer overlaps are noted;
> 4. Conflicting demands are resolved with rationale;
> 5. Changes Summary Table matches the actual changes described;
> 6. Word count is tracked and within limits;
> 7. All reference library/CrossRef lookups are documented;
>
> Flag any issues found. Output: [pass/fail] + [list of issues if any]."

### Response Letter Quality
- [ ] Every reviewer comment has a numbered response — no skipped items
- [ ] Every response includes a specific revision action or explains why none was made
- [ ] Exact new text is quoted in the response (not just "we revised this")
- [ ] Page/line numbers given for all revisions in the response letter
- [ ] Response tone is respectful throughout, even when disagreeing
- [ ] Changes Summary Table included and matches actual changes

### Cross-Reviewer Handling
- [ ] Cross-reviewer overlaps identified and noted explicitly in letter
- [ ] Conflicting reviewer demands named and resolved with rationale
- [ ] Editor priorities addressed first and most thoroughly

### Citation and Reference Integrity
- [ ] Local reference library checked for all reviewer-requested citations
- [ ] CrossRef API used as fallback for citations not in local library
- [ ] All newly cited works added to reference list
- [ ] No orphaned citations (cited in text but missing from references)

### Word Count and Formatting
- [ ] Word count verified against journal limit after revisions
- [ ] Word impact tracked per revision item
- [ ] Abstract updated if findings or framing changed
- [ ] Tracked changes / blue text applied consistently

### Round-Specific
- [ ] R&R round noted in all output files
- [ ] Tone calibrated to round (R1 thorough; R2 direct; R3 surgical)
- [ ] R2+ new comments flagged as [NEW-IN-R2+]
- [ ] Cover letter matches round and revision scope
