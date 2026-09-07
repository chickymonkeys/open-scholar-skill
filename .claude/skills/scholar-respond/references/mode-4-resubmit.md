# Scholar Respond — Progressive-Disclosure Reference

This reference is loaded on demand when its mode is selected from the Dispatch Table;
the common protocol, evidence and severity schema, and routing logic live in the
always-loaded `SKILL.md`. It carries the mode-specific procedure only.

Also load the companion reference(s) this mode uses:
```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}"
cat "$SKILL_DIR/.claude/skills/scholar-respond/references/common-concerns.md"
```

## MODE 4: RESUBMISSION STRATEGY

Use after a rejection to diagnose the root cause, select a new target journal, reframe the manuscript, and write a cover letter for resubmission.

### Step 1: Triage the Rejection Decision

| Decision type | What it means | Your response |
|--------------|--------------|---------------|
| **Desk reject** | Out of scope or below threshold; no external review | Reframe for a different journal; do not resubmit to same journal without major restructuring |
| **Reject after review** | External review; editor says fatal flaws | Diagnose root cause (Step 2); major revision before next submission |
| **Reject with invitation** | Rare; signals openness if specific concerns are addressed | Treat as conditional R&R; respond to each concern; resubmit as new submission with detailed cover letter |
| **R&R declined / expired** | You declined or missed deadline | Same as reject after review |

### Step 2: Diagnose Root Cause

Before resubmitting anywhere, identify the failure mode:

| Root cause | Diagnosis signs | Fix | Typical time |
|------------|----------------|-----|-------------|
| **Scope mismatch** | Desk reject; "outside our scope"; no substantive critique | Change framing and opening, not the paper | 1–2 weeks |
| **Contribution threshold** | "Interesting but not transformative enough for [journal]" | Assess if genuine advance is possible; or move down the journal ladder | 2–4 weeks |
| **Fatal methodological flaw** | "Identification assumption untenable"; "N too small for the claims" | Fix before resubmitting ANYWHERE — new reviewers will raise it too | 1–3 months |
| **Framing mismatch** | Sociology paper rejected by Nature: "too specialized"; Nature paper rejected by sociology: "not theoretical enough" | Substantive reframing of introduction and contribution | 2–4 weeks |
| **Theory too thin** | ASR/AJS: "insufficient theoretical contribution"; "too descriptive" | Expand Theory section; strengthen mechanism argument | 3–6 weeks |
| **Writing quality** | "Poorly written"; "hard to follow"; "argument unclear" | Substantial rewrite of Introduction and Theory | 2–4 weeks |
| **Data/reproducibility** | NCS/NHB: "code not available"; "not reproducible" | Deposit code and data; add Reporting Summary | 1–2 weeks |

### Step 3: Select Target Journal

Use expanded journal ladders by subfield:

**Computational sociology**:
NCS → Science Advances → NHB → PNAS → Sociological Methods & Research → AJS/ASR

**Stratification / inequality**:
ASR → AJS → Social Forces → Social Problems → Sociological Quarterly → Research in Social Stratification & Mobility

**Demography / population**:
Demography → Population and Development Review → Population Studies → Journal of Marriage and Family → Social Science Research

**Race / ethnicity**:
ASR → AJS → Du Bois Review → Social Forces → Ethnic and Racial Studies → Sociology of Race and Ethnicity

**Gender / family**:
ASR → Gender & Society → Journal of Marriage and Family → Social Forces → Journal of Family Issues

**Political sociology**:
ASR → APSR → AJS → Social Forces → Mobilization → Political Research Quarterly

**Culture / knowledge**:
AJS → ASR → Poetics → Cultural Sociology → Theory and Society

**Linguistics / language & society**:
Language in Society → Journal of Sociolinguistics → Language Variation and Change → Journal of Language and Social Psychology → Applied Linguistics

**Interdisciplinary / broad**:
Nature/Science → Science Advances → NHB → NCS → PNAS → PLOS ONE

**Decision rules**:
- Move down the ladder only if the contribution cannot clear the next tier's bar
- Address fatal flaws before moving anywhere on the ladder
- If rejected for scope mismatch, consider a lateral move (same tier, different subfield journal) rather than moving down
- Do not "shotgun" submissions — one active submission at a time

### Step 4: Reframe the Introduction for the New Journal

The analysis stays the same; the introduction framing changes for the new audience:

| Element | What to change | Why |
|---------|---------------|-----|
| Opening hook | Match the new journal's entry point (ASR: theoretical puzzle; AJS: historical question; Science Advances: societal significance; Demography: demographic trend; NCS: computational advance; LiS: language ideological puzzle; APSR: democratic/institutional puzzle) | Different readers care about different things |
| Contribution claim | Restate what is new relative to what the new journal's readers know | Contribution is always relative to an audience |
| Literature cited | Cite the new target journal's own recent articles | Show you know the conversation |
| Theory emphasis | ASR: mechanism; AJS: theoretical innovation; Science Advances: interdisciplinary significance; NCS: methodological advance; LiS: ideological critique | Each journal has a different theoretical register |
| Word count | Adjust to the new journal's limits | |
| Section structure | NCS: Results before Methods; Nature journals: brief Methods in main text + detailed in Supplementary | Journal-specific conventions |

**Reframed contribution paragraph template**:
> "[Target journal]'s readership will recognize [the puzzle or debate that motivates the paper]. Despite [what is known], [what remains unknown or contested]. We address this gap by [what we do]. Our contribution is [specific advance: new method / new population / resolved debate / boundary condition]. This matters because [why the target audience cares, in their own terms]."

### Step 5: Write the Resubmission Cover Letter

```
Dear [Dr. LastName / Editor],

Please find enclosed our manuscript, "[Title]," for consideration for
publication in [New Journal Name].

[1–2 sentences on why this paper is a strong fit for this journal's scope
and readership — be specific about the journal, not generic.]

[1–2 sentences summarizing the key contribution and findings.]

This manuscript has been substantially revised since an earlier version
was reviewed elsewhere. The current version includes [summary of major
revisions: e.g., "a new event study analysis, an expanded theory section,
and a reframed contribution argument"]. We believe these revisions
significantly strengthen the paper.

[Optional — pre-empt a predictable concern]:
"We note that while our design is observational, we conduct [specific
robustness checks] in Appendix B that bound the potential confounding."

The manuscript is [N] words (within [journal]'s [N]-word limit), has
not been published elsewhere, and is not under review at another journal.

We look forward to your consideration.

Sincerely,
[Name, Title, Affiliation, Email]
```

### Step 6: Lessons Learned Log

Document what went wrong and what was fixed for future reference:

```
===== POST-REJECTION LESSONS LEARNED =====

Previous journal: [journal]
Decision: [desk reject / reject after review]
Root cause: [from Step 2]

What reviewers said (key themes):
1. [Theme 1]
2. [Theme 2]

What we changed:
1. [Change 1 — addresses theme 1]
2. [Change 2 — addresses theme 2]

What we did NOT change (and why):
1. [Element preserved — rationale]

New target: [journal]
Key differences in framing:
1. [Difference 1]
2. [Difference 2]

Pre-emptive defenses added to manuscript:
1. [Defense 1 — anticipating concern X]
```

---

## MODE Verification Checklist

After completing the mode, run a verification check via the Task tool; pass this checklist to the verifier:

> "You are verifying a scholar-respond output. Check the following:
>
> 1. Root cause diagnosis is specific and actionable;
> 2. Journal selection is justified;
> 3. Reframed introduction matches new journal's conventions;
> 4. Cover letter is journal-specific, not generic;
>
> Flag any issues found. Output: [pass/fail] + [list of issues if any]."
