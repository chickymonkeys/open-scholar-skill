# Economics Review Router

Loaded by MODE 1 when the paper is economics. It decides **which of the fifteen economics
references are read, and by which reviewer seat**. It adds no reviewer seat and changes no spawn
logic: the seats are the ones MODE 1 already spawns, and this layer decides what they read.

Read this file, run the three steps below, then load only the references the route names.

## Step E1 — Classify on two axes

Economics papers are routed on two axes that compose. **Methodological form selects the checks;
economic field or topic tunes them.** Classify by the paper's own identifying vocabulary and its
headline claim, not by JEL code or journal.

### Axis 1 — methodological form (selects the checks)

| Form | Identifying vocabulary in the paper |
|---|---|
| **empirical/applied** | difference-in-differences, event study, instrumental variables, exclusion restriction, first stage, regression discontinuity, bandwidth, fixed effects, clustered standard errors, panel, treatment effect, LATE, ATT, ATE, placebo |
| **theoretical** | model, proposition, lemma, theorem, proof, equilibrium, comparative statics, existence, uniqueness, Bayesian Nash, subgame perfect, screening, matching, auction, contract |
| **structural or counterfactual** | model primitives, BLP, GMM, MLE, simulated method of moments, calibration, moments, fit, counterfactual, policy simulation, dynamic programming, value function, elasticity |
| **descriptive** | facts, trends, decomposition, inequality, mobility, national accounts, harmonised series, stylised facts — with no causal, structural or experimental headline |
| **experimental** | RCT, random assignment, lab experiment, field experiment, survey experiment, treatment arm, control arm, balance table, attrition, compliance, spillovers, SUTVA, pre-analysis plan |
| **mixed** | more than one of the above carries a claim the paper actually makes |

**A mixed paper receives the union of the matching rows.** Empirical and theoretical work are not
mutually exclusive: a paper that proves a proposition and then estimates a DiD is routed through
both rows, not through whichever one the abstract mentions first. Route a form in whenever the
paper makes a claim of that kind — not only when it is the headline.

### Axis 2 — economic field or topic (tunes the checks)

The field does not add or remove a dimension. It sets what a check is measured against.

| The field decides | Where it lands |
|---|---|
| which prior estimates the effect size is read beside, and what counts as a large effect here | economic magnitude, contribution |
| which institutions, rules and eligibility conditions a reader needs in order to judge transport | external validity |
| which data regimes are in play — administrative registers, household panels, firm censuses, platform traces, national accounts — and which of their known defects apply | data construction, transparency |
| which registration and disclosure norms bind (AEA RCT Registry for field experiments; AEA data and code policy for empirical, simulation and experimental work) | preregistration, reproducibility |

Labour, development, public, industrial organization, macro, trade, urban and regional, health,
education, environment and energy, finance, political economy, and economic history all sit on this
axis. Name the field in one line of the route and say what it changed; do not enumerate fields the
paper is not in.

### The modern-methods trigger (composes with every form)

Fires when the paper uses machine learning, NLP or text-as-data, embeddings, classifiers, platform
or digital-trace data, or large administrative data for prediction. It is **not** a separate
dimension: it turns on six named sub-checks inside two references that are already routed —
construct validity, provenance and representativeness in `data-construction.md`; leakage and
out-of-sample discipline, calibration and error structure, and task-matched validation in
`robustness.md`. When the trigger fires and the form does not already route those two references,
route them in.

## Step E2 — Read the route off the table

| Form | Always read | Form-routed | Conditional — read when the paper makes the claim |
|---|---|---|---|
| **empirical/applied** | contribution, data construction, reproducibility, transparency | identification, robustness, external validity | mechanism (a channel is claimed) · economic magnitude (scale or policy relevance is claimed) · preregistration (the paper calls an analysis confirmatory or pre-specified) |
| **theoretical** | contribution, transparency | theory | reproducibility (numerical examples, simulations or computational proofs carry a central claim) · economic magnitude (welfare or a quantitative interpretation is central) |
| **structural or counterfactual** | contribution, data construction, reproducibility, transparency | structural, robustness | external validity (counterfactual scope is claimed) · economic magnitude (welfare or policy magnitudes are claimed) · mechanism (the model's channel is presented as an empirical finding) |
| **descriptive** | contribution, data construction, reproducibility, transparency | descriptive | external validity (the fact is generalised beyond the sample) · economic magnitude (the scale of the fact is the point) |
| **experimental** | contribution, data construction, reproducibility, transparency | experimental, robustness, external validity, preregistration | identification (assignment alone does not deliver the estimand — non-compliance, spillovers, encouragement) · mechanism (a channel is claimed) · economic magnitude (scale or policy relevance is claimed) |
| **mixed** | the union of every row whose form the paper carries | | |

**Blindspot is not on this table.** It is a cross-cutting mode run in synthesis, after the validity
checks have returned — see Step E3.

Conditional is not redundant. Three of the conditionals test things no other reference tests:
`theory.md` tests whether a proof is valid, `structural.md` tests the chain from primitives to
counterfactual, and `preregistration.md` tests whether evidence presented as confirmatory was
time-ordered that way. A paper can pass every other check and fail one of these.

## Step E3 — Assign each routed reference to a seat

Every routed reference reaches **exactly one** seat, so no check is run twice and none is dropped.
The seats are MODE 1's own.

| Seat | Reads |
|---|---|
| **R1 — Methodologist / Empiricist** | identification, robustness, data construction, experimental, structural, descriptive, preregistration |
| **R2 — Theorist / Conceptual Critic** | theory, mechanism, external validity |
| **R3 — Senior Editor / Holistic** | contribution, reproducibility, transparency |
| **R4 — Interpretive Skeptic** | economic magnitude |
| **R5 — Computational Methods Specialist** (only when MODE 1 spawns it) | the six modern-methods sub-checks, taken over from R1 |
| **synthesis (the parent, Step 4)** | blindspot |

R1 keeps the rest of `data-construction.md` and `robustness.md` when R5 takes the sub-checks; when
MODE 1 does not spawn R5, the sub-checks stay with R1. Each sub-check has one owner either way.

A seat reads only the references the route gave it. Pass each seat the paths it needs:

```bash
SKILL_DIR="${SCHOLAR_SKILL_DIR:-.}"
ECON="$SKILL_DIR/.claude/skills/scholar-respond/references/econ"
cat "$ECON/protocol.md"          # every seat reads this
cat "$ECON/<routed-dimension>.md"  # ... plus its own routed references
```

`protocol.md` carries the reading principles, the finding schema, the severity mapping, the report
structure, the decision rubric and the conduct rules. Every seat reads it; it is stated once.

## Write the route down

Before the seats are spawned, state the route in the run — form(s) matched and the vocabulary that
matched them, the field and what it tuned, whether the modern-methods trigger fired, the routed
references, and the seat assignment. One short block, in the report's Appendix. A route that is not
written down cannot be checked against the report that came out of it.

## The caveat that travels with these references

**These fifteen references have never been observed to produce a referee report.** The controlled
evidence gate that preceded them ran the pre-consolidation shape — one auditor per dimension, spawned
in parallel — and it returned no final report on either paper of the gate. That condemned the
execution shape; the content was never tested. Treat every operation of this layer as
evidence-gathering: record what fired, what it missed, and what the human had to correct.
