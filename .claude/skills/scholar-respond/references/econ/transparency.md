# Transparency

Routed to **R3**. Principles that bite hardest: **P3**, **P5**, **P7**.

The question is **visibility**: can a reader see the provenance, the sample construction, the code
status, the estimator choices and the discretionary decisions that stand behind the claims? Whether a
choice was *correct* belongs to the dimension that owns it; whether the computation *runs* belongs to
`reproducibility.md`.

Prefix findings `TRANS-`.

## Check 1 — Data provenance

**Tests** whether each central dataset has a named source, collection period, unit of observation,
coverage, restrictions and access status.
**Violation**: a central variable or sample comes from an underspecified source, private merge, scrape
or administrative extract, with too little provenance to judge coverage and access.
**Evidence required**: the data section, table or appendix where provenance is stated or missing.

## Check 2 — Sample and exclusion transparency

**Tests** whether the analysis sample follows visibly from raw coverage through exclusions, merges,
trimming and missing-value rules.
**Violation**: the final sample size or composition is not reconciled with the source population;
consequential exclusions go undescribed or unsized; **or** outcomes reported side by side in one
table were estimated on different observations and the paper does not say so. The last is routine in
survey-based work with rotating question modules, and it is consequential: columns estimated on
different survey years rest on different cohorts and different exposure, and averaging them into one
index describes no single population.
**Evidence required**: the sample-construction text, the flow table, or the missing reconciliation;
the observation counts across columns and whether anything in the paper explains their spread; and
the size of each stated exclusion, or the note that none is given. An exclusion that conditions on
something the treatment may itself move — turnout, survival, staying in the sample — belongs here
and should be named as such.

## Check 3 — Code and materials disclosure

**Tests** whether code, instruments, surveys, treatment materials, model files or notebooks are
disclosed or reachable, and whether funding and competing interests are declared.
**Violation**: a claim depends on materials neither provided nor described well enough for independent
scrutiny; or funding sources, institutional affiliations bearing on the subject, and competing
interests are undeclared where the journal requires them.
**Evidence required**: the code and materials statement, the funding and disclosure statement, or the
appendix. **The absence of a data and code availability statement is one finding, not two** — raise
it under `reproducibility.md` Check 1 and cross-reference it here rather than filing it twice.

## Check 4 — Researcher degrees of freedom

**Tests** whether discretionary choices are visible: outcome definitions, transformations, controls,
windows, bandwidths, fixed-effect structures, clustering, hyperparameters, model primitives.
**Violation**: central results depend on choices that are not disclosed, or are disclosed only after
the results have been interpreted.
**Evidence required**: the specification, the table note, the appendix — or the absence of disclosure.

## Invariants

- Transparency findings are about visibility. Route the substantive design flaw to the dimension that
  owns it.
- Do not demand disclosure of private information. Ask for aggregate documentation, an access protocol
  or third-party verification where raw release is impossible.
- A limitation statement can satisfy transparency even where it does not solve the limitation.
