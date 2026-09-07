# Reproducibility

Routed to **R3**. Principles that bite hardest: **P5**, **P7**.

The question is executable: could a third party rerun the tables, figures, estimates and simulations
without knowledge only the authors hold? Transparency asks whether choices are visible;
reproducibility asks whether the computation runs.

Prefix findings `REPRO-`.

## Check 1 — Replication package sufficiency

**Tests** whether the paper points to a package or appendix covering data, code, scripts and
instructions.
**Violation**: headline results depend on code or data that are unavailable, incomplete, or described
informally with no credible access path.
**Evidence required**: the data and code availability statement, the appendix — or the absence of any
statement.

## Check 2 — Computational determinism

**Tests** whether stochastic analyses disclose seeds, software versions, package or model versions and
simulation settings where results depend on them.
**Violation**: simulations, bootstraps, machine-learning models, randomised procedures or numerical
solvers carry central results and cannot be rerun deterministically from the paper's description.
**Evidence required**: the method, table or appendix where the stochastic computation appears, and
the missing detail.

## Check 3 — End-to-end reproduction path

**Tests** whether raw data, intermediate construction, final estimation and table generation are
linked by an auditable workflow — the master script that produces every table, figure and in-text
number.
**Violation**: final estimates are reported without documenting sample construction, cleaning, merges,
exclusions or table generation well enough to connect inputs to outputs.
**Evidence required**: the construction step or the appendix gap.

## Check 4 — Restricted or proprietary data

**Tests** whether restricted, proprietary or confidential data have a nonexclusive access path, a
synthetic substitute, or third-party verification. Two cases sit here and they are not equally
serious. A **licensed government or archive file** has a standard route a third party can walk, and
the failure is usually that the paper does not name it — a documentation fix. A **private
researcher-to-researcher transfer** has no route at all, and no amount of documentation creates one;
that is the harder case, and it is worse when the privately supplied series is what answers the
paper's own central identification objection.
**Violation**: central results depend on inaccessible data with no access protocol, no substitute and
no verification path; or a licensed file is used without naming the licence route.
**Evidence required**: the data source and the availability statement. Say which of the two cases it
is, and name who supplied a privately transferred series.

## Check 5 — Recompute what the tables claim to derive

**Tests** every number the paper says it derived from other numbers it prints: an average, a ratio,
a difference, an index, a share, a reported observation count that a stated rule determines.

This is the cheapest high-yield audit available to a reviewer who cannot rerun anything, because it
needs only the printed page. Do it before asking for code.

**Violation**: a printed number cannot be reproduced from the rule the paper states for it. A
reported index sample size that matches the stated rule only if one component is dropped, a ratio
that does not follow from the two coefficients it is built on, a percentage that does not follow
from the coefficient and the baseline.
**Evidence required**: the rule as stated, the arithmetic you performed, and the printed number that
disagrees. Show the calculation. Where the arithmetic does reconcile, say so — a verified derivation
is worth recording, and it tells the editor which numbers were checked.

## Check 6 — Do the printed significance markers match the stated inference procedure?

**Tests** whether the significance the tables report is what the inference method the paper claims
would produce.

**Violation**: the paper names a procedure whose output is not a standard error — a wild cluster
bootstrap p-value, a randomisation-inference p-value, a weak-IV-robust confidence set — while every
star in the tables falls exactly where a normal approximation to the printed coefficient/standard-error
ratio would put it. The stars are then not coming from the procedure the paper names, and with few
clusters or a weak first stage that distinction decides which results survive.
**Evidence required**: the sentence naming the procedure; a handful of coefficient/standard-error
ratios against the stars printed beside them; and what the named procedure outputs instead. Report
the arithmetic. This check needs no code.

## Invariants

- Do not require public release where law, privacy, contract or ethics forbid it. Require a credible
  access or verification path instead.
- Do not ask a purely theoretical paper for code unless numerical examples, simulations or
  computational proofs carry a central claim.
- Calibrate severity to how central the unreproducible component is to the contribution.
