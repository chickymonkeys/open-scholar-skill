# Blindspot — the Opportunities mode

**Not a validity dimension and not on the route table.** Blindspot is a cross-cutting mode the
**synthesis** runs at MODE 1 Step 4, after the routed validity checks have returned, and it lands in
the report's **Opportunities** section.

Every other reference hunts for problems. This one hunts for the paper missing the best version of
itself — and that positive report consequence is why it survives as its own mode rather than folding
into any dimension. A paper can be entirely correct and still leave its strongest result undersold.

It runs after the validity checks because an opportunity is only worth naming once it is clear the
paper stands up: an Opportunity attached to a design that fails Essential Point 1 is noise.

Prefix findings `BS-`. Severity is MINOR by construction.

## Two categories

**Unasked question** — something the paper could answer with its own data and did not ask:

- heterogeneity the data plainly support (sub-population, region, cohort, firm size, dosage) where
  only the pooled estimate is reported
- a mechanism the prose gestures at, where a split or a mediating-outcome regression on variables
  already in hand would speak to it
- a secondary outcome already in the dataset that bears on the contribution and sits in a footnote
- a sub-population the design naturally identifies — a cleaner set of compliers, a never-treated
  comparison group — that the paper does not isolate
- an alternative estimand the same data could target: an ATT beside the reported LATE, a dynamic
  event study beside a single pooled coefficient

**Unexploited strength** — something the paper has and undersells:

- identification stronger than claimed, where a sentence or one table would let the authors say so
- a falsification or placebo that is trivially runnable, not run, and would crush an obvious
  objection if it came back null
- a descriptive fact already constructible from the data that pre-empts the most likely referee
  complaint

## Calibration

Flag an opportunity only when **both** hold:

1. The paper **has the data or the setup** — you can name the variable, the sub-sample or the design
   feature that makes it feasible with no new collection.
2. **A reviewer would expect it** — it is salient given the paper's own claims.

Asking for a new identification strategy, a new dataset or a different research question is asking
for a different paper, which P7 forbids.

## How it lands in the report

Each item is framed *"the paper could also ___, because it already has ___."* Opportunities are
non-binding: they never escalate the recommendation, never count toward the three-Essential-Point
cap, and never enter the Severity × Confidence Matrix.

## Worked examples

**Unexploited strength.** *The paper observes a flat pre-period (p. 12, §5.1) but never runs the
reform as a placebo on the never-eligible firms, which would directly rule out the anticipation story
a referee will raise. Table 1 reports 1,840 never-eligible firms with the same outcome over the same
window, so the placebo is constructible with no new data.*

**Unasked question.** *The paper reports only the pooled employment effect (p. 8, §4.1) though its
data identify the firm-size strata the introduction calls theoretically central. Section 2
distinguishes small from large firms and Table 1 already reports the size variable for the full
sample, so the split is immediate.*

**Not an opportunity.** *"The paper could have used a richer dataset with more covariates."* The
paper does not have those covariates. That is a different paper.
