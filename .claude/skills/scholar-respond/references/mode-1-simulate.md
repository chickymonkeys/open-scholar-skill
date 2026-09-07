# Scholar Respond — Progressive-Disclosure Reference

This reference is loaded on demand when its mode is selected from the Dispatch Table;
the common protocol, evidence and severity schema, and routing logic live in the
always-loaded `SKILL.md`. It carries the mode-specific procedure only.

Also load the companion reference(s) this mode uses:
```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}"
cat "$SKILL_DIR/.claude/skills/scholar-respond/references/common-concerns.md"
```

## MODE 1: SIMULATE PEER REVIEW

Use when the user wants mock reviews before submission.

### Step 1: Read the Manuscript

Identify:
- Target journal (from title page or user input)
- Paper type (from 0d classification)
- Type of contribution (empirical, theoretical, methodological, computational, mixed)
- Core argument and hypotheses
- Data, design, and methods
- Key findings
- Claimed contribution
- Word count (estimate or exact)
- **Economics?** Whether the paper is an economics paper — the journal row selected in Step 2 has
  `Persona = economist`, or the manuscript is economics whatever journal it names. If it is, Step 2.5
  routes the economics layer; if it is not, Step 2.5 is skipped and MODE 1 runs exactly as it does
  for any other paper.

### Step 1.5: Desk-Reject Risk Assessment (before full review simulation)

Before spawning reviewer agents, assess desk-reject probability:

**Desk-reject risk factors** (flag if >=3 present):
- [ ] Word count exceeds journal limit by >10%
- [ ] Missing required sections (e.g., no Theory section for ASR; no Reporting Summary for NHB)
- [ ] Contribution claim is unclear or absent from Introduction
- [ ] Topic outside journal scope (check journal aims & scope)
- [ ] No causal identification strategy (for methods-demanding journals)
- [ ] Writing quality issues (>5 grammatical errors per page; unclear prose)
- [ ] Citation count outside norms (too few or too many)
- [ ] Missing data/code availability statement (for Nature family)

**Risk levels**:
- 0-1 flags: LOW risk -- proceed to full review simulation
- 2-3 flags: MODERATE risk -- warn user; recommend FORMAT-CHECK via scholar-journal first
- 4+ flags: HIGH risk -- recommend addressing flags before simulating review

### Step 2: Journal-Calibrated Reviewer Configuration

Before spawning agents, identify the journal-specific reviewer persona and priorities. Use the
`Persona` value from the selected journal row in the reviewer prompts in Step 3.

| Journal | Persona | R1 (Methods) emphasis | R2 (Theory) emphasis | R3 (Editor) emphasis |
|---------|---------|----------------------|---------------------|---------------------|
| **ASR** | sociologist | Causal claims vs. design; AME not OR; robustness; N | Theory depth ≥800 words; mechanism specification; H↔results | Contribution clarity; word count ≤12K; framing |
| **AJS** | sociologist | Same as ASR + historical/comparative scope | Classical theory engagement (Weber/Durkheim/Marx); theoretical innovation | Essay-style coherence; AJS readership fit |
| **Demography** | sociologist | Sensitivity analyses; missing data; decomposition; online appendix | Data-population connection; demographic framework | Replication package; data availability |
| **Social Forces** | sociologist | Solid empirical design; clear operationalization | Engagement with middle-range theories; clear literature positioning | Accessible framing; moderate theoretical ambition |
| **Science Advances** | sociologist | Replication materials; code availability; interdisciplinary methods | Interdisciplinary framing; sociological terms defined for broader audience | Broad significance; CRediT statement; word count |
| **NHB** | sociologist | Reporting Summary; power analysis; all test statistics (t, df, p); error bars labeled | Cross-disciplinary theory; claims accessible to psychologists/economists | Word limit (5K main); 50-reference limit; figure standards |
| **NCS** | sociologist | Code mandatory; computational rigor; benchmarks; reproducibility | Methodological contribution clarity; computational advance stated | NCS Reporting Summary; Results-before-Methods; word limit |
| **Language in Society** | sociologist | Sociolinguistic method rigor; transcription standards; speaker metadata | Language ideology frameworks; indexicality; language and power | Engagement with LiS readership; ethnographic depth |
| **APSR** | sociologist | Causal identification; pre-registration; replication data | Democratic theory; institutional frameworks; power | Political significance; policy relevance; generalizability |
| **JMF** | sociologist | Family demography methods; longitudinal design; selection | Life course theory; family process mechanisms | Applied significance; family policy implications |
| **PDR** | sociologist | Demographic techniques; formal demography; decomposition | Population theory; demographic transition | Broad demographic significance; data quality |
| **SMR** | sociologist | Methodological innovation; simulation evidence; proof | Clear methodological advance over existing tools | Sociological applicability; tutorial clarity |
| **Gender & Society** | sociologist | Feminist methodology; intersectional analysis | Gender theory; intersectionality; power structures | Feminist praxis; social justice implications |
| **Poetics** | sociologist | Cultural methods; text analysis; computational culture | Cultural theory; meaning-making; boundary work | Cultural sociology audience; symbolic boundaries |
| **Social Problems** | sociologist | Applied methods; policy-relevant design | Social constructionism; claims-making; inequality | Public relevance; policy implications; accessibility |
| **AER** | economist | Robust and credible conclusions; empirical-method detail; data/code reproducibility | Breadth, importance, innovation; essential proofs in the paper | Worthiness for publication; analysis quality; clarity |
| **AEJ: Applied** | economist | AEA data/code policy; replication package with R&R | Applied contribution and innovation; claims supported by analysis | Importance to applied-economics readers; clarity |
| **AEJ: Economic Policy** | economist | AEA data/code policy; credible quantitative analysis | Policy contribution and innovation; theory-to-policy connection | Importance to economic-policy readers; clarity |
| **AEJ: Macroeconomics** | economist | AEA data/code policy; empirical or simulation reproducibility | Macroeconomic contribution and innovation; model clarity | Importance to macroeconomics readers; clarity |
| **AEJ: Microeconomics** | economist | AEA data/code policy; empirical or simulation reproducibility | Microeconomic contribution and innovation; essential proofs | Importance to microeconomics readers; clarity |
| **QJE** | economist | Final data/programs; intermediate construction; replication README | Contribution and economic significance; experimental design where applicable | General-interest importance; coherent presentation |
| **JPE** | economist | Positive reproducibility check; provenance; raw/analysis data and code | Economic contribution; experimental or simulation logic where applicable | Publication conditional on reproducibility; broad significance |
| **Econometrica** | economist | Replicable empirical, experimental, and computational results; preregistration where required | Formal validity; data-collection and simulation logic | Expert, constructive assessment; transparent exemptions |
| **REStud** | economist | Code must reproduce every table, figure, and numerical result; full transformation chain | Contribution and formal validity; simulation-generation logic | Integrity, care, transparency; conflict and expertise disclosure |
| **JDE** | economist | Sound, feasible methods; power; data accuracy, consistency, bias, completeness | Contribution beyond a country/case/event; hypotheses and mechanisms | General-readership value; methodological rigor; interpretation matches evidence |
| **JOLE** | economist | Human-subject and confidential-data integrity; transparent LLM use | Labour-economics contribution; responsible evidence interpretation | Funding/conflict disclosure; reviewer accountability; correction policy |
| **JPubE** | economist | Rigorous quantitative analysis appropriate to the claim | Modern economic theory; public-economics contribution | Originality; international policy relevance; readership fit |
| **RJE** | economist | Empirical or theoretical rigor; critical assessment of supporting material | Industrial-organization contribution and originality | Quality, originality, significance to readers |
| **JME** | economist | Reproducible data, code, models, algorithms; robustness and computational experiments | Macroeconomic contribution; proof and model clarity | Main paper stands alone; significance to macroeconomics readers |

### Step 2.5: Economics Layer Routing (economics papers only)

Skip this step unless Step 1 marked the paper as economics.

The economics layer is fifteen routed references that live inside this mode. It adds no reviewer
seat and changes no spawn logic: the seats spawned in Step 3 are the ones below, and this layer
decides **what each of them reads**.

```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}"
cat "$SKILL_DIR/.claude/skills/scholar-respond/references/econ/router.md"
```

Follow the router's three steps — classify the paper on the two composable axes (economic field or
topic × methodological form), read the route off its table, and assign each routed reference to a
seat. A **mixed paper receives the union** of the forms it carries. Write the resulting route down;
it goes in the report appendix, and the verification checklist at the end of this reference checks
the report against it.

The route names a set of the fifteen: identification, robustness, mechanism, external validity,
structural, theory, experimental, descriptive, data construction, economic magnitude,
preregistration, reproducibility, transparency, blindspot, contribution. Blindspot is the exception
— it is a cross-cutting Opportunities mode the synthesis runs in Step 4, after the validity checks
return, not a seat's reading.

### Step 3: Spawn Reviewer Agents

Use the Task tool to run reviewers **in parallel**. The reviewer prompts come from the agent .md files read in Step 0.

**On an economics route**, append one paragraph to each seat's prompt below, naming the files that
seat reads and nothing else:

> "Before reviewing, read `references/econ/protocol.md` — the reading principles, finding schema,
> report structure, decision rubric and conduct rules — and then the routed references assigned to
> your seat: [paths from the Step 2.5 seat assignment]. Apply the checks in those references and no
> others. Every finding cites a page, equation, table or section; where a claim cannot be verified
> without rerunning the analysis, say that it could not be verified rather than assuming it is
> wrong. Comment on the paper; do not rewrite the authors' prose. Rate your recommended decision on
> the five-point rubric in `protocol.md`, which replaces the four-value rating named below."

**Always spawn these three**:

**Reviewer 1 — Methodologist / Empiricist** (from `peer-reviewer-quant.md`)

> "You are a rigorous methodologist reviewing a [journal] paper. Follow the evaluation criteria and output format in your agent profile. Additionally, apply the journal-specific emphasis: [insert from calibration table above]. Paper type: [from 0d]. Be specific: quote the paper. Rate your recommended decision (Accept / Minor Revision / Major Revision / Reject). Manuscript: [full text]"

**Reviewer 2 — Theorist / Conceptual Critic** (from `peer-reviewer-theory.md`)

> "You are a theoretical [persona] reviewing a [journal] paper. Follow the evaluation criteria and output format in your agent profile. Additionally, apply the journal-specific emphasis: [insert from calibration table above]. Paper type: [from 0d]. Be specific: quote the paper. Rate your recommended decision. Manuscript: [full text]"

**Reviewer 3 — Senior Editor / Holistic Reviewer** (from `peer-reviewer-senior.md`)

> "You are a senior [persona] and former associate editor at [journal]. Follow the evaluation criteria and output format in your agent profile. Additionally, apply the journal-specific emphasis: [insert from calibration table above]. Paper type: [from 0d]. Be specific: quote the paper. Rate your recommended decision. Manuscript: [full text]"

**Always spawn a fourth reviewer**:

**Reviewer 4 — Interpretive Skeptic**

> "You are a devil's advocate reviewer whose sole job is to check whether the authors' *interpretive labels* for their findings are accurate and whether the same numbers could support a different (possibly opposite) story. You are NOT reviewing methods, theory depth, or writing quality — only the alignment between data and interpretation. For each major finding or interpretive claim in the manuscript:
> 1. Identify the specific numbers cited in support of the claim.
> 2. Check: does the claim hold from BOTH cross-group AND within-group perspectives? If the paper compares groups, compute within-group distributions (e.g., positive-to-negative ratios within each group) and check if these tell the same story as the cross-group comparison.
> 3. Check: are the labels accurate? Could a skeptical reader look at the same table and conclude something different? If yes, state the alternative interpretation.
> 4. Check: are mechanism claims (in Theory or Discussion) actually supported by data the authors collected, or are they imported from other literatures without verification? Flag any claim about the study context that is asserted without measurement (e.g., 'absence of editorial gatekeeping' when editorial processes were not measured).
> 5. Check: does the paper use consistent terminology for its core concepts, or do competing labels appear across sections?
> Rate: PASS (interpretations are well-supported) or NEEDS REVISION (specific claims need re-examination). For each NEEDS REVISION item, state the claim, the numbers, and the alternative interpretation. Manuscript: [full text]"

**Conditionally spawn a fifth reviewer**:

If paper type is **computational** (NLP, ML, networks, CV, ABM, LLM annotation), add:

**Reviewer 5 — Computational Methods Specialist** (from `peer-reviewer-computational.md`)

> "You are a computational social scientist reviewing a [journal] paper. Follow the evaluation criteria and output format in your agent profile. The paper uses [specific computational methods]. Apply the journal-specific emphasis: [insert from calibration table]. Be specific: quote the paper. Rate your recommended decision. Manuscript: [full text]"

**For qualitative papers**, modify R1's prompt:
> "You are reviewing a qualitative/mixed-methods paper. Instead of statistical rigor, evaluate: (1) methodological transparency (sampling, data collection, analysis steps); (2) analytical rigor (coding procedure, inter-coder agreement if applicable, saturation); (3) reflexivity and positionality; (4) evidence quality (thick description, triangulation); (5) transferability claims."

### Step 3.5: Reviewer Personality Calibration

When simulating, optionally assign personality types to increase realism:

| Personality | Behavior | Tone Adaptation |
|---|---|---|
| **Constructive** (default) | Identifies issues + suggests solutions | Standard response templates |
| **Skeptical** | Questions every assumption; demands robustness | Provide extra evidence; preemptively address concerns |
| **Hostile** | Dismissive of contribution; tone is harsh | Acknowledge valid points diplomatically; do not be defensive |
| **Perfectionist** | Demands minor fixes on every page | Address each point briefly; batch similar concerns |
| **Confused** | Misunderstands methodology or contribution | Clarify with patience; consider if writing was unclear |

**Tone adaptation for hostile reviewer**: "We appreciate the reviewer's [specific valid concern]. We have addressed this by [concrete change]. We respectfully note that [evidence/citation supporting our approach]."

### Step 4: Synthesize and Produce Simulation Output

After all agents return, synthesize into a formatted decision letter with a **Severity × Confidence Matrix**:

```
===== SIMULATED EDITORIAL DECISION =====
Journal: [journal]
Paper Type: [quantitative-causal / descriptive / computational / qualitative / mixed / theoretical]
Decision: [Major Revision / Minor Revision / Accept / Reject]
Reviewer Consensus: [unanimous / split — describe]

Dear [Author],

Thank you for submitting "[Paper Title]" to [Journal]. We have received
[three/four] independent reviews. [Summary of overall assessment — 2 sentences.]

[Decision rationale — 2–3 sentences]

We invite you to revise and resubmit addressing the following concerns.

===== REVIEWER 1 (METHODOLOGIST) =====
[Full review from Agent 1]

===== REVIEWER 2 (THEORIST) =====
[Full review from Agent 2]

===== REVIEWER 3 (SENIOR/HOLISTIC) =====
[Full review from Agent 3]

===== REVIEWER 4 (COMPUTATIONAL) ===== [if applicable]
[Full review from Agent 4]

===== SEVERITY × CONFIDENCE MATRIX =====

| # | Issue | Severity | Raised by | Confidence | Est. Effort |
|---|-------|----------|-----------|------------|-------------|
| 1 | [issue] | CRITICAL | R1, R2 | HIGH (2+ reviewers) | [hours/days] |
| 2 | [issue] | MAJOR | R1 | HIGH (methodological) | [hours/days] |
| 3 | [issue] | MAJOR | R2 | MEDIUM | [hours/days] |
| 4 | [issue] | MINOR | R3 | LOW (stylistic) | [hours] |
| ... | ... | ... | ... | ... | ... |

Severity and confidence take the scale defined in the skill's Evidence and Severity Schema
(SKILL.md).

===== REVISION ROADMAP =====

Phase 1 — Critical fixes (do first):
1. [Issue] — [what to do] — est. [effort]
2. ...

Phase 2 — Major revisions:
1. [Issue] — [what to do] — est. [effort]
2. ...

Phase 3 — Minor improvements:
1. ...

Phase 4 — Cosmetic/polish:
1. ...

Strengths to preserve (do not change):
1. ...
2. ...

Estimated total revision effort: [X days/weeks]
Estimated word count impact: [+/- N words] → projected total: [N] (limit: [N])
```

#### Step 4e: The Economics Referee Report (economics route only)

On an economics route the letter above gains five sections and one calibration. Everything else in
the letter stays where it is: the reviewer bodies, the Severity × Confidence Matrix and the Revision
Roadmap are unchanged.

**The calibration.** The `Decision:` line takes the five-point economics rubric in
`references/econ/protocol.md` — Accept | Minor Revision | Major Revision | Reject-and-Resubmit |
Reject — in place of the four-value line above. Reject-and-Resubmit is the value the four-point line
has no room for: addressable, but with acceptance probability below one half.

**Blindspot runs here, and only here.** Once the routed validity checks have returned, read
`references/econ/blindspot.md` and synthesise the Opportunities section. It runs after the validity
checks because an opportunity attached to a design that fails Essential Point 1 is noise.

```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}"
cat "$SKILL_DIR/.claude/skills/scholar-respond/references/econ/blindspot.md"
```

Append the five sections to the letter:

```
===== ECONOMICS REFEREE REPORT =====

--- 1. SUMMARY + RECOMMENDATION ---
[1–2 paragraphs showing the editor the paper was understood. State the paper's ONE central novel
contribution in a single sentence before the recommendation; the rest of the summary supports it.
Flag unclear exposition.]

Decision: [Accept | Minor Revision | Major Revision | Reject-and-Resubmit | Reject]
[For Major Revision or Reject-and-Resubmit: the specific conditions for eventual acceptance.
For Reject: the fundamental flaw.]

--- 2. ESSENTIAL POINTS (at most three) ---
1. [Title] — [what fails, citing page / equation / table; why the paper cannot be published without
   it being addressed; the reading principle it rests on, e.g. "P3 — identifying variation".
   Name the problem; do not write the authors' replacement text.]
2. [...]
3. [...]
[Do not pad to three. More than three CRITICAL findings means the recommendation gets more severe,
not the report longer.]

--- 3. SUGGESTIONS (non-binding) ---
### [Routed dimension]
[Findings, or "None." — one heading per routed reference, in the order the route listed them.]

--- 4. OPPORTUNITIES (virtue-side, non-binding) ---
1. The paper could also [___], because it already has [___].
[Never escalates the recommendation; never counts toward the Essential-Points cap; never enters the
Severity × Confidence Matrix.]

--- 5. APPENDIX: ROUTE AND ROUTED FINDINGS ---
Route: form(s) [...] matched on [vocabulary]; field [...] tuned [...]; modern-methods trigger
[fired / did not fire]; references read [...]; seats [...].

### [Dimension] Audit
[ID-001 ...] — one line per finding, with its stable id.

Not verified: [every claim the report could not check without rerunning the analysis.]
```

The last line is not optional. The report says what it could not check; it never implies it found
everything.

---

## MODE Verification Checklist

After completing the mode, run a verification check via the Task tool; pass this checklist to the verifier:

> "You are verifying a scholar-respond output. Check the following:
>
> 1. Each reviewer addresses journal-specific concerns from the calibration table;
> 2. Reviews are realistic in length and tone;
> 3. Severity matrix is consistent with review content;
> 4. Revision roadmap addresses all critical and major items;
> 5. No reviewer concern is missing from the action plan;
>
> On an economics route, also check:
> 6. Every routed dimension in the appendix route has a Suggestions heading, findings or "None";
> 7. Essential Points number three or fewer, each cites a location and names its reading principle;
> 8. Opportunities are non-binding — none escalates the decision or appears in the severity matrix;
> 9. The decision uses the five-point rubric, including Reject-and-Resubmit where it applies;
> 10. No finding rewrites the authors' prose, and the "Not verified" line is present;
>
> Flag any issues found. Output: [pass/fail] + [list of issues if any]."
