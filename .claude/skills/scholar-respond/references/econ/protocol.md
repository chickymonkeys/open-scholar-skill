# Economics Review Protocol

Every seat on an economics route reads this file, and it is stated only here. It carries the seven
reading principles, the finding schema, the report structure, the decision rubric and the conduct
rules. The routed dimension references carry checks and nothing else.

## Operate like a health inspector

Precise, evidence-bound, never vague. *"The identification strategy is weak"* is not a finding.
*"The exclusion restriction for Z is asserted but not tested — p. 8 says only that Z is 'plausibly
exogenous', while Table 3 column (2) shows Z correlates with the lagged outcome at p = 0.031"* is a
finding.

## The seven reading principles

The principles are a reasoning layer above the checklists — questions posed while reading, not
yes/no tests. A principle produces a finding only when the paper's text, tables or appendices fail
to answer it. Each dimension reference names the principles that bite hardest there.

**P1 — Name the estimand before judging the estimator.** Three objects must line up: the
*theoretical* estimand (what would answer the question with infinite data), the *empirical* estimand
(the function of the observable distribution the estimator targets under the paper's assumptions),
and the *estimator*. A paper that runs a two-way fixed-effects regression and calls the coefficient
"the effect", without saying which weighted average of group-period effects it identifies, has
skipped the middle object. (Lundberg, Johnson and Stewart 2021.)

**P2 — Decompose the estimator; inspect the weights.** If the estimate is a weighted sum, ask what
the weights are and which units, cells, cohorts or industries they fall on: Rotemberg weights for
shift-share IV (Goldsmith-Pinkham, Sorkin and Swift 2020), group-period weights including negative
ones for staggered difference-in-differences (de Chaisemartin and D'Haultfœuille 2020),
contamination weights for multi-treatment regression with controls (Goldsmith-Pinkham, Hull and
Kolesár 2024). A single number without the decomposition tells a reader nothing about where it came
from.

**P3 — Locate the identifying variation in the paper's own words.** The paper must finish the
sentence *"the variation that identifies our coefficient comes from ___"* in concrete institutional
terms — which firms, years, cohorts, dosages, discontinuities. *"Changes in policy across states"*
is a finding, not an identification strategy.

**P4 — Take the noise of the design seriously before believing the magnitude.** Under the paper's
own standard errors and a plausible prior on the true effect drawn from the literature rather than
from these data, how likely is the sign correct, and by what factor does selection on significance
inflate the magnitude? A precise point estimate from a small, noisy design read at face value is a
finding. (Gelman and Carlin 2014.)

**P5 — Audit analytic flexibility, not just the chosen specification.** The nominal p-value is
conditional on the specification actually run; the honest one is conditional on the menu the authors
would have run on other data. Enumerate the menu — sample windows, control sets, outcome
transformations, cluster levels, fixed-effect structures, winsorisation thresholds — and ask whether
the headline survives perturbing any one dimension. Twenty columns of the same sign do not answer
this; a specification curve does. (Gelman and Loken 2013.)

**P6 — Mechanism is a claim, not an interpretation.** A causal estimate identifies an average effect
for one population and one margin: the LATE for compliers, the ATT for treated cohorts, the local
effect at the cutoff. The mechanism story is a separate claim needing its own evidence —
heterogeneity by a mechanism-relevant covariate, a margin shift, or a placebo on an outcome the
mechanism should not touch.

**P7 — Calibrate the critique to the paper's claims, not to a universal checklist.** A finding binds
only when it threatens a claim the paper actually makes. A LATE-versus-ATE objection is not a
finding against a paper that claims a LATE. A pre-trend concern about years t−10 to t−5 is not a
finding against a paper that claims effects in the immediate post-period. (Berk, Harvey and
Hirshleifer 2017.)

Weight per dimension: identification P1–P3 · robustness P4, P5 · economic magnitude P2, P4 ·
contribution P1, P6 · external validity P6 · mechanism P1, P6 · data construction P3, P5 ·
structural P1, P2, P4, P5 · theory P1, P6 · experimental P1, P4–P6 · descriptive P3, P6 ·
preregistration P5 · reproducibility P5 · transparency P3, P5. P7 governs every dimension.

## Finding schema

Each finding is one structured object:

```yaml
id: ID-001                  # dimension prefix + sequential number
severity: CRITICAL          # the skill's own scale — see below
location:
  page: 8
  section: "3.1"
  text_quote: "Z is plausibly exogenous to the outcome"
issue: One sentence stating the specific gap, error, sensitivity or overclaim.
evidence: Cited evidence from the paper — table, equation, page, or quoted text.
suggested_action: What the authors could add, test, clarify or revise. Keep it non-prescriptive
  where the design may need fundamental change.
principle: P3               # optional; set it when one principle drives the finding
```

Prefixes, one per dimension: `ID-` identification · `ROB-` robustness · `DATA-` data construction ·
`CONTRIB-` contribution · `EV-` external validity · `MAG-` economic magnitude · `MECH-` mechanism ·
`STR-` structural · `TH-` theory · `EXP-` experimental · `DESC-` descriptive · `PAP-`
preregistration · `REPRO-` reproducibility · `TRANS-` transparency · `BS-` blindspot.

**Severity is the skill's own scale**, defined once in `SKILL.md` under *Evidence and Severity
Schema*: CRITICAL (the paper cannot be published without the fix) > MAJOR (substantive change
needed) > MINOR (should fix) > COSMETIC. Confidence is the same schema's HIGH / MEDIUM / LOW. Only
CRITICAL findings are eligible to become Essential Points. Blindspot findings are MINOR by
construction and never enter the severity matrix.

If you cannot fill both `issue` and `evidence` with specific citations, do not write the finding.

## Report structure

The economics route emits five sections. They sit inside the MODE 1 decision letter and replace
nothing else in it: the reviewer bodies, the Severity × Confidence Matrix and the Revision Roadmap
stay where MODE 1 puts them.

**1. Summary + Recommendation.** One or two paragraphs showing the editor the paper was understood.
State **the paper's one central novel contribution in one sentence** before the recommendation; the
rest of the summary supports that sentence. Flag unclear exposition. Then the decision, on the
rubric below. For Major Revision or Reject-and-Resubmit, state the specific conditions for eventual
acceptance. For Reject, state the fundamental flaw.

**2. Essential Points — at most three.** Each cites a page, equation, table or section, explains why
the paper cannot be published without it being addressed, and **names the reading principle it rests
on** (for example "P3 — identifying variation"), which tells the editor what kind of reasoning the
objection is made of.

**3. Suggestions.** Non-binding, organised under the routed dimensions — one heading per routed
reference, "None" where a routed dimension produced nothing. Authors may address them at their
discretion.

**4. Opportunities.** Virtue-side and non-binding, from `blindspot.md`, synthesised **after** the
validity checks have returned. Two kinds: questions the paper could answer with its own data but did
not ask, and strengths it undersells. Each is framed *"the paper could also ___, because it already
has ___."* Opportunities never escalate the recommendation and never count toward the
Essential-Points cap.

**5. Appendix — routed findings.** The route as written down in Step E3, then every finding by
dimension with its stable id.

## Decision rubric

| Decision | When |
|---|---|
| **Accept** | Identification is clean, data credible, results robust, contribution clear and not overclaimed. Only trivial copy-editing remains. |
| **Minor Revision** | One or two bounded, clearly fixable issues the editor can verify without a second round. Not for open-ended requests. |
| **Major Revision** | One to three specific addressable problems with a clear path to publication. The authors should know exactly what to do, and the outcome should be predictable if they do it. |
| **Reject-and-Resubmit** | Addressable, but with substantial uncertainty — probability of eventual acceptance below one half. The editor is not committed to the revised version. Never a kinder rejection: use it only where acceptance is genuinely possible. |
| **Reject** | A fundamental flaw no revision reaches: identification fatally flawed and unreframeable, the key variable irreparably wrong, the contribution not novel relative to directly cited work, or results that contradict themselves. |

The bar for Reject is *unfixable*, not merely difficult.

## Conduct

- **Comments, not rewrites.** Essential Points and Suggestions are inline comments on a specific
  page, equation or table, in the manner of an editor marking up a draft. Name the problem and
  explain why it matters; the authors own the fix and write the words. (Goldsmith-Pinkham.)
- **The cap is three, and it is a decision lever.** More than three CRITICAL findings means the
  recommendation should get more severe, not the report longer. Writing six Essential Points because
  the paper has six MAJOR issues is the error; Major Revision with two or three genuine Essential
  Points and the rest as Suggestions is the correction.
- **Do not act as a coauthor.** The report helps the editor decide. It does not redesign the paper,
  make an unpublishable paper publishable, or enforce citations.
- **Ask only for checks that bear on a named threat.** Decorative robustness bloats papers and wastes
  research effort. *"Common in the literature"* is not a threat.
- **Preference is not error.** *"I would have done this differently"* is not a finding.
- **Do not flag what the paper already tests and passes.** Read the robustness section, the
  appendices and the online supplement before writing any finding.
- **Be explicit about uncertainty.** Where a claim cannot be verified without rerunning the analysis,
  say that it could not be verified rather than assuming it is wrong. The report states what it could
  not check. It never promises that it found everything.
- **Keep it bounded.** Two or three pages is enough for most papers.
- **Hand on what is not yours.** A seat reads only its routed references, so a real problem sometimes
  turns up with no check to file it under — most often an inconsistency between the paper's claim
  language and its own exhibits, which another seat's reference owns. Report it plainly, say it fell
  outside your checks, and let the synthesis place it. The synthesis owns reconciliation across
  seats; a finding dropped because it had no home on one seat is the failure this rule prevents.

## Optional evidence packet: structured comprehension

Before the checks, a seat may write a short structured comprehension of the paper — question,
claim chain, which table or figure carries which claim, and the identifying variation in the paper's
own words. It helps most on a long manuscript or a tangled claim chain, and it makes P1 and P3
answerable before any check runs.

It is **optional and never a file the run waits on**. No step blocks on it, no check fails for its
absence, and it is never a required artifact. Where it is written, it belongs in the run's own notes
or the report appendix, not as a deliverable of its own.
