# Identification

Routed to **R1**. Principles that bite hardest: **P1** (name the estimand), **P2** (decompose the
estimator and inspect the weights), **P3** (locate the identifying variation in the paper's own
words). Do that reasoning first; the checks below anchor it to specific evidence.

Prefix findings `ID-`.

**Each check names the designs it applies to.** Read the design first and run only the checks that
match it; a check that does not apply costs one line to dismiss, not a paragraph. Checks 7 and 8
carry the large class of papers that identify from selection on observables inside a rich
fixed-effects design, which is neither IV, nor RD, nor a canonical event study.

## Check 1 — IV exclusion restriction

*Applies to:* instrumental-variables designs.

**Tests** whether the exclusion restriction is stated in a form that could be confronted with
evidence.
**Violation**: the restriction is asserted without being tested against its observable implications;
or the paper's own tables show the instrument correlating with pre-treatment outcomes.
**Evidence required**: the page and section stating the restriction; the table or equation showing
the correlation, where one exists.

## Check 2 — IV instrument strength

*Applies to:* instrumental-variables designs.

**Tests** whether the first stage is strong enough for the inference the paper draws from it.
**Violation**: first-stage F below 10 (the conventional Stock–Yogo threshold) with no weak-IV-robust
inference such as Anderson–Rubin confidence intervals. F below 104.7 (the Lee et al. 2022 tF
threshold) is a violation only where the paper invokes the tF approach and does not acknowledge the
gap.
**Evidence required**: the table reporting the first-stage F, or a statement that none is reported.

## Check 3 — RDD continuity and smoothness

*Applies to:* regression-discontinuity designs.

**Tests** whether the running variable's density is continuous at the cutoff and predetermined
covariates do not jump.
**Violation**: no McCrary (2008) density test where manipulation is plausible in this institutional
setting; or a statistically and economically significant jump in a predetermined covariate at the
cutoff.
**Evidence required**: the section where continuity is or is not tested.

## Check 4 — RDD bandwidth selection

*Applies to:* regression-discontinuity designs.

**Tests** whether the bandwidth rule is stated, justified and perturbed.
**Violation**: the selection rule is unstated; or the result changes sign or loses significance under
a bandwidth half or double the reported one.
**Evidence required**: the table where bandwidth robustness is or is not reported.

## Check 5 — Group-and-time designs: parallel trends and the estimator's weights

*Applies to:* difference-in-differences, event studies, and **any** design whose treatment varies
across groups and over time inside a two-way fixed-effects specification — including a
non-absorbing treatment that switches on and off, and a group × cohort design in repeated cross
sections. The weighting problem is not confined to canonical staggered adoption.

**Tests** whether parallel trends is stated, tested and shown, and whether the estimator survives
treatment-effect heterogeneity.
**Violation**: no pre-trends test; or economically or statistically significant pre-period
coefficients; or a staggered-adoption design estimated by two-way fixed effects with no
heterogeneity-robust alternative (Callaway–Sant'Anna, Sun–Abraham, de Chaisemartin–D'Haultfœuille,
Borusyak–Jaravel–Spiess, or equivalent).
**Evidence required**: the event-study figure or pre-trends table, or a statement of its absence.
Under P2, say where the two-way fixed-effects weights fall and whether any are negative — which
cells, cohorts or episodes the single reported number is an average over. A paper whose aggregate
claim rests on treatment-effect heterogeneity while its estimator assumes that heterogeneity away
is contradicting itself, and that tension is the finding.

## Check 6 — Randomised assignment used as identification

*Applies to:* experiments and quasi-experiments with an explicit assignment mechanism.

**Tests** whether the randomisation described actually delivers the estimand claimed.
**Violation**: no balance table covering pre-treatment outcomes; or differential attrition present
and unaddressed; or non-compliance treated as if it were assignment.
**Evidence required**: the balance table (or its absence) and the attrition statistics. Design-level
experimental checks belong to `experimental.md`; this check covers only the step from assignment to
the identified quantity.

## Check 7 — Selection and omitted-variable bias

*Applies to:* any design that identifies from selection on observables, including a rich
fixed-effects specification with no experiment, instrument or discontinuity behind it.

**Tests** whether the identifying assumption is stated and credible where the design rests on
selection on observables.
**Violation**: the identifying assumption is never stated explicitly; or observables predict both
treatment and outcome with no sensitivity analysis (Oster 2019 δ, or equivalent).
**Evidence required**: the section stating the assumption; the table showing the predictors.

## Check 8 — Post-treatment conditioning

*Applies to:* every design.

**Tests** whether the control set includes variables the treatment itself moves — the bad-controls
problem. Conditioning on a mediator changes the estimand from the total effect to a controlled
direct effect, which is a different quantity and is not identified without a further
no-unobserved-mediator-confounding assumption.

**Violation**: the specification controls for outcomes of the treatment — education, employment,
income, marital status, location, firm survival — while the abstract or conclusion states the total
effect. The clearest form of this violation is a paper that *says* the controls are included
because the treatment may have moved them, and then reads the residual as the effect.
**Evidence required**: the control list; the sentence or the cited literature establishing that the
treatment moves those controls; the claim that is stated as a total effect. Say which of the two
quantities the paper's own language is claiming, and ask for the other one alongside it — the gap
between them is the indirect channel, which is usually of interest in its own right.

## Invariants

- IV identifies a LATE for compliers, not an ATE. The paper may already say so; flag it only where it
  bears on the contribution claim, and route the scope question to `external-validity.md`.
- A first-stage F below the conventional threshold disqualifies the design **unless** the paper uses
  weak-IV-robust inference, in which case the threshold does not apply.
- Pre-trends tests, balance tables and density tests often live in appendices. Read the appendices
  before flagging an absence.
