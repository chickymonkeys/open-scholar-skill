# Economic Magnitude

Routed to **R4**. Principles that bite hardest: **P2** (a headline number that is a weighted average can be driven by a small, unrepresentative subset) and **P4** (a significant estimate from a noisy design overstates the true magnitude).

Ask what the number is an average *of* before asking whether it is large.

Prefix findings `MAG-`.

## Check 1 — Baseline quantification

**Tests** whether the paper **converts** its key coefficients into a baseline unit a reader thinks in — a share of a control-group or pre-period mean, a percentage point of a binary outcome, a share of the response scale. **Violation**: the prose never performs the conversion. A mean sitting in an appendix summary-statistics table that no sentence uses leaves the magnitude just as uninterpretable as no mean at all; a coefficient on a 0/1 outcome that is never stated in percentage points is the common case. **Evidence required**: the table with the coefficient; the sentence that converts it, or the absence of any such sentence. Check the summary-statistics table before assigning severity. Where that table is not in the document you were given, say so and cap severity at MAJOR rather than assuming the baseline is missing.

## Check 2 — Percent against percentage point

**Tests** whether the paper keeps the two apart. **Violation**: the text says "X percent" where "X percentage points" is correct, or the reverse, in a way that changes what the magnitude means. **Evidence required**: the sentence; the correct reading given the coefficient and the baseline.

## Check 3 — Contextualisation against the literature

**Tests** whether the effect size is placed beside comparable estimates **from outside the paper**. **Violation**: no external comparator is offered at all — including the common case where a paper benchmarks its effect only against the other coefficients in its own regressions, which establishes a ranking within one specification and nothing about the literature. A small effect needs external calibration more than a large one, not less. It is also a violation when the effect is large or surprising relative to the literature and the paper does not say so. **Evidence required**: the effect size; the comparators offered, and whether any is external. Where the paper benchmarks internally, say which comparator it chose and which larger one in the same table it passed over. The comparator set is a field question — see below.

## Check 4 — Practical against statistical significance

**Tests** whether significance is being read as importance. **Violation**: a statistically significant but economically tiny effect is called "substantial" or "large" with no magnitude relative to a meaningful baseline. **Evidence required**: the characterisation; the effect relative to the baseline, computed where the baseline is reported.

## Check 5 — Uncertainty carried into the narrative

**Tests** whether the prose reports the interval, not only the point. **Violation**: the text states a point estimate with no confidence interval or standard error, where the interval would materially change the reading. **Evidence required**: the text statement; the table column holding the standard error. Under P4, say what the interval implies about the plausible magnitude, not only about the sign.

## Check 6 — Sign and direction

**Tests** whether the text states the sign the table reports. **Violation**: the text says positive where the table reports negative, or the reverse. **Evidence required**: the text statement and the table cell.

## Check 7 — Which statistic is being quoted

**Tests** what statistic of the estimate's distribution the headline magnitude is, and whether the set it was selected from is disclosed. **Violation**: a headline number is the **maximum** over many cells, periods, regions or specifications, presented without that word and without the central tendency — "up to X", "as large as X", "in some years, in some regions". A maximum over a large selection set is the number most inflated by noise, and it is the one a reader will remember. It is equally a violation to quote a ratio to a small denominator where the absolute effect is the interpretable quantity, or to report a relative change in a probability as though it were a share of that probability. **Evidence required**: the quoted number; the object it is computed over and how many cells that is; the mean or median if the paper reports one, or the note that it does not; and the absolute effect alongside the relative one. Under P4, say what the coefficient's own confidence interval does to the quoted figure.

## What the field tunes

The field supplies the comparator estimates and the units a reader thinks in — elasticities in trade and IO, standard deviations of test scores in education, months of consumption in development, percent of GDP in macro. Name the units this field reads magnitudes in and check the paper offers them.

## Invariants

- Do not demand a welfare calculation the design cannot support.
- A missing baseline is not CRITICAL where the mean sits in the summary-statistics table. Read the full tables first.
- Reporting percentage points rather than percentage change is a choice, not an error. Flag only the wrong term for the units actually reported.
