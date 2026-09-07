# Robustness

Routed to **R1**. Principles that bite hardest: **P4** (take the noise of the design seriously before
believing the magnitude) and **P5** (audit analytic flexibility, not only the chosen specification).

One question governs every check: does this test a **named threat** to the core claim, or decorate
it?

Prefix findings `ROB-`.

## Check 1 — Robustness-check relevance

**Tests** whether each reported check corresponds to a threat the paper names.
**Violation**: a check is reported with no stated threat it addresses; or a threat is named with no
corresponding check.
**Evidence required**: the named threat and where it appears; the robustness table, or its absence.

## Check 2 — Alternative specifications

**Tests** whether the result survives plausible alternative functional forms, control sets and
windows.
**Violation**: the main result changes sign or loses significance under a plausible alternative, and
the paper neither reports nor addresses it.
**Evidence required**: the robustness table showing the sensitivity, or the absence of the test.

## Check 3 — Placebo tests, including the window where theory predicts nothing

**Tests** whether placebo treatments, placebo outcomes and placebo *exposure windows* are the right
ones and return nulls. The third kind is the one most often reported and least often read: running
the same treatment on a group, period or age range where the paper's own theory predicts no effect.
**Violation**: a placebo returns a significant result in the direction of the main effect and the
paper does not address it; **or** a placebo window returns coefficients that are significant,
opposite-signed, or larger in absolute value than the headline, and the text describes them as
"little or no effect". A significant coefficient where the theory predicts none is evidence about
the design, not a null — read the table rather than the sentence pointing at it.
**Evidence required**: the placebo table, the coefficient and its p-value, and the sentence in the
text that characterises it. Where the placebo windows overlap each other or the treatment window,
say so: overlapping windows share exposure and cannot be read as independent tests.

## Check 4 — Sensitivity to outliers and sub-periods

**Tests** whether the result is driven by influential observations or a short window.
**Violation**: the result rests on a single observation or a brief sub-period with no sensitivity
analysis.
**Evidence required**: leverage statistics, Cook's D, or the event-study figure showing it.

## Check 5 — Inference and the clustering level

**Tests** whether the clustering level matches the level at which treatment is assigned, and whether
alternatives are reported.
**Violation**: the clustering level is unjustified given the design; or significance changes when
clustering at a level natural to the assignment.
**Evidence required**: the stated clustering level; alternative standard errors, or their absence.

## Check 6 — Few clusters relative to the asymptotics invoked

**Tests** whether the number of clusters supports the inference procedure used. This is a distinct
question from Check 5: the level can be right and the count still too small.
**Violation**: the cluster count is small — a single-digit or low-double-digit number of regions,
states, cohorts, markets or waves — and the paper reads conventional p-values or significance stars
off it without small-cluster inference; **or** it uses wild-cluster-bootstrap p-values without saying
what those p-values rest on, when the bootstrap's finite-sample behaviour depends on cluster
homogeneity and score symmetry that a handful of heterogeneous clusters is unlikely to deliver.
**Evidence required**: the stated cluster level and count; the inference procedure; the tables whose
significance depends on it. Say how far the problem travels — a counterfactual or a policy number
built on those coefficients inherits it.
**Where the paper is silent on the count**, that is itself the finding: a reader cannot judge the
inference without it.

## Check 7 — Age, period and cohort restrictions

**Tests**, in any design whose variation runs across birth cohorts, calendar time and age, which
restriction the paper imposes to break the exact collinearity of the three — and whether the paper
says so.
**Violation**: the paper adds dummies "up to the point of collinearity", or includes group-specific
*linear* age or time trends, without stating which nonlinear cohort effects the design leaves
confounded with the treatment. A placebo drawn from a neighbouring or randomly assigned group
addresses spurious correlation, not a systematic group–cohort confounder correlated with the real
timing.
**Evidence required**: the specification and its footnote on collinearity; the trend terms included;
the placebo the paper offers and what it does and does not rule out.

## Check 8 — Analytic flexibility and the specification curve

**Tests** whether a paper with many researcher degrees of freedom shows the menu rather than one
column of it.
**Violation**: the paper shows **one branch** of a choice it visibly considered — a threshold it
defends in a footnote against an alternative it never reports, a window it names but does not vary,
an estimator it says gives "similar results" without showing them — and offers no specification
curve or multiverse-style summary across those choices. A raw count of discretionary choices is a
weak trigger: almost any applied paper with several outcomes and several datasets passes ten. The
sharp trigger is a choice the authors **visibly varied and reported once**.
**Evidence required**: enumerate the choices the paper itself raises and then does not show. A
robustness table of twenty columns all pointing the same way does not answer P5.

## Check 9 — Multiplicity and summary-index construction

**Tests** how many hypotheses the paper tests, and whether a summary index that carries its
significance is built validly.
**Violation**: many outcomes, arms, subgroups or exposure windows are tested with no family
definition, no adjustment and no exploratory caveat; **or** a summary index — an average effect
size, a standardised index, a first principal component — is presented as the paper's strongest
evidence without saying which outcomes enter it and on which observations each component was
estimated. An index averaged over components estimated on different, partly non-overlapping samples
does not describe any one population, and an index whose reported sample size cannot be reproduced
from its stated construction rule is a finding on its own.
**Evidence required**: the count of reported coefficients and the family the paper claims for them;
for an index, its component list, the stated construction rule, and the observation counts of the
components. Recompute the index's reported sample size from the rule and say whether it reconciles.

## Modern-methods sub-checks

These three fire only when the modern-methods trigger fires (machine learning, NLP or text-as-data,
embeddings, classifiers, platform or digital-trace data, large administrative data used for
prediction). They belong to **R5** when MODE 1 spawns that seat, and to R1 when it does not.

### Sub-check A — Leakage and out-of-sample discipline

**Tests** whether training, validation and test data are separated at the right unit and the right
point in time.
**Violation**: evaluation leaks future information, repeats units across splits, tunes on the test
set, or reports in-sample fit while claiming predictive validity.
**Evidence required**: the description of the split — by time, by unit — or its absence.

### Sub-check B — Calibration and error structure

**Tests** whether predicted scores or labels are calibrated, and whether their errors are assessed
for the subgroups and the downstream estimand that use them.
**Violation**: predicted probabilities, classifier outputs or model-assigned labels enter a
regression or a policy conclusion with no calibration, no propagation of their uncertainty, and no
subgroup error rates.
**Evidence required**: validation tables, calibration plots, error analysis — or the missing
diagnostic.

### Sub-check C — Task-matched validation

**Tests** whether the validation matches the task the output actually performs in the economics
argument: measurement, prediction, discovery, description or causal inference.
**Violation**: the paper reports generic accuracy or model fit and then uses the output for a
different task — most often as a measured variable in a causal design.
**Evidence required**: the stated purpose of the method and the validation metric offered for it.
Predictive performance is not identification: route causal design failures to `identification.md`.

## Invariants

- Every requested check must name the threat it tests.
- A sensitivity the paper already runs and passes is not a finding.
- A specification curve is warranted only at ten or more major degrees of freedom.
- State-of-the-art model performance is not required where a simpler validated measure carries the
  claim.
