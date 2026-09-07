# Data Construction

Routed to **R1**. Principles that bite hardest: **P3** (the identifying variation physically lives in
variable definitions, sample restrictions and the unit of observation) and **P5** (winsorisation
thresholds, restriction sequences and merge rules are forking-path decisions).

Transparency asks whether a construction choice is **visible**; this reference asks whether it
changes **the object being estimated**.

Prefix findings `DATA-`.

## Check 1 — Data source credibility

**Tests** whether primary sources are named, cited and fit for the question.
**Violation**: a primary source is unnamed or uncited; or it has coverage gaps documented in the
literature that bear directly on this sample.
**Evidence required**: the section listing sources; the documented issue, where one exists.

## Check 2 — Sample restrictions

**Tests** whether every restriction is stated with the observation count it removes.
**Violation**: a restriction appears in a footnote with no count; or restrictions are justified only
as "standard in the literature" with no design-based reason.
**Evidence required**: the footnote or table describing the restriction; the number dropped, where
reported.

## Check 3 — Variable definitions

**Tests** whether the key treatment and outcome variables are defined precisely enough to rebuild.
**Violation**: the definition lacks the exact survey question, administrative code or formula; or the
unit of observation is unstated.
**Evidence required**: the section or data appendix defining the variable.

## Check 4 — Treatment-construction invariant

**Tests** whether the constructed treatment, exposure or sample variable is internally consistent
with its own stated definition, in the paper's own exhibits.

A definition forces arithmetic. Derive the arithmetic from the definition, then read the paper's
tables and figures for a violation of it. This is a forensic check on the variable, not a judgement
about the design, and it is the one check no reviewer in the evidence gate behind this layer
derived on its own.

*Worked example.* Exposure is defined as experiencing at least one recession during ages 18–25 — an
eight-year window. Any run of consecutive treated birth cohorts must therefore be at least eight
cohorts long, because a single recession year treats eight adjacent cohorts. An appendix figure
showing a treated run of three or four cohorts contradicts the definition: the variable was not
built the way the text says it was.

*A second worked example, on a different shape of rule.* Eligibility is defined as household income
below a threshold in the year before the programme opened. That rule forces monotonicity: every
household below the threshold in that year is treated, so the treated share must be weakly
decreasing in baseline income, and no income bin above the threshold may contain treated households
at all. A descriptive table showing treated households in bins above the cutoff means either the
threshold moved, the year moved, or an unstated exception rule is doing work — and the paper says
none of the three.

The general form: take the stated rule, derive what it forces about counts, run lengths, bounds,
overlaps, totals or shares, then check the exhibit. Windows imply minimum run lengths. Thresholds
imply monotonicity. Exhaustive categories imply shares that sum to one. Age or eligibility cutoffs
imply which cohorts can appear at all. The two examples above are illustrations of the move, not a
list of the cases it covers: derive the arithmetic from *this* paper's rule.

**Violation**: an exhibit contradicts the arithmetic the stated definition forces, and the paper does
not name the extra rule that would reconcile them.
**Evidence required**: quote the definition; state the arithmetic it forces in one line; cite the
table cell or figure panel that violates it. Where the exhibit is a figure, say what in the figure
was read.

Severity is CRITICAL when the headline estimate is computed from the variable in question: the
paper's central number is then not the number the paper says it is.

## Check 5 — Measurement error

**Tests** whether known measurement error in a key variable is acknowledged and handled.
**Violation**: the literature documents measurement error in the variable and the paper neither
acknowledges nor addresses it.
**Evidence required**: the reference establishing the error; the paper's treatment of it, or its
absence.

## Check 6 — Retrospective proxies and the selection their correction trades for

**Tests**, where exposure is assigned from a variable reported after the fact — location at an
earlier age, recalled income, recalled employment, a retrospective health history — both halves of
the problem: the misclassification the proxy introduces, and the selection the obvious correction
introduces in its place.
**Violation**: the paper names the attenuation and then corrects it by restricting to the sub-sample
where the proxy is exact — non-movers, consistent reporters, complete histories — without asking
whether that sub-sample differs systematically on the outcome, on exposure, or on both. A restricted
sample that is "more precisely estimated" is not evidence that the coefficient is unbiased; the
coefficient *magnitude* is what would show attenuation, and the paper should say whether it moved.
**Evidence required**: the sentence defining the proxy; the restricted-sample table; whether the
paper reports the change in magnitude and any evidence on how the retained group differs. Where a
second dataset in the paper measures the same variable directly, say that it can bound the
misclassification rather than merely being compared with.

## Check 7 — Attrition and missing data

**Tests** whether differential attrition in the outcome is tested and handled.
**Violation**: differential attrition between treated and control groups is present and unaddressed.
**Evidence required**: the attrition statistics; the test result, or its absence.

## Check 8 — Replication feasibility of the construction

**Tests** whether the data and the construction code let a third party rebuild the analysis sample.
**Violation**: the data are not public, not reachable under a standard data-use agreement, and no
archive is offered; or the data appendix is too thin to reconstruct the dataset.
**Evidence required**: the data-availability statement; the archive URL, where present. Execution —
whether the code actually reruns — belongs to `reproducibility.md`.

## Modern-methods sub-checks

These three fire only when the modern-methods trigger fires. They belong to **R5** when MODE 1 spawns
that seat, and to R1 when it does not.

### Sub-check A — Construct validity of a derived measure

**Tests** whether a variable built by a model — a topic share, an embedding distance, a classifier
label, a dictionary count — measures the concept the paper names.
**Violation**: a text- or model-derived measure is treated as the construct with no human validation,
no construct-validity evidence, and no sensitivity to the representation choices that produced it
(preprocessing, vocabulary, number of topics, model version, codebook, intercoder agreement).
**Evidence required**: the corpus, labelling, dictionary or model section, and the validation offered.

### Sub-check B — Provenance of corpus, platform and trace data

**Tests** whether each central dataset has a named source, collection window, unit of observation,
coverage and access status — including what the platform or the scrape did to the data before the
authors saw it.
**Violation**: a central variable comes from an underspecified scrape, private merge, platform export
or administrative extract, with too little provenance to judge coverage or access.
**Evidence required**: the data section or appendix stating provenance, or the gap in it.

### Sub-check C — Representativeness of the observed population

**Tests** whether the coverage of platform, scrape, transaction or trace data maps onto the
population and the behaviour claimed.
**Violation**: observed users, transactions, participants or algorithmically filtered traces are
generalised with no coverage or selection analysis.
**Evidence required**: the sampling frame, the platform limitation, or the generalisation claim.

## Invariants

- A publicly available dataset is not a replication concern. Confirm the data really are unavailable
  before raising one.
- Missing data in a control is usually less severe than missing data in the outcome or the treatment.
- Restrictions inherited from an administrative source may be unavoidable. Ask whether this one
  threatens this design before flagging it.
