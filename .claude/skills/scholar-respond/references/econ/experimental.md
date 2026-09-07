# Experimental

Routed to **R1**. Principles that bite hardest: **P1**, **P4**, **P5**, **P6**, **P7**.

Randomisation is a design, not a guarantee. The question is whether randomisation, power, balance,
attrition, compliance, interference and multiplicity support the causal and policy claims made.

Prefix findings `EXP-`.

## Check 1 — Randomisation design

**Tests** whether the assignment unit, strata, clusters, probabilities, blocking and implementation
are described well enough to pin down the estimand and the level of inference.
**Violation**: the protocol is underspecified, or mismatched to the standard errors or the analysis
unit.
**Evidence required**: the design section, the assignment description, or the table note.

## Check 2 — Power and minimum detectable effects

**Tests** whether power for the primary outcomes is reported or justified, and whether nulls are read
accordingly.
**Violation**: a null is presented as precise evidence of no effect despite low power or a missing
minimum-detectable-effect discussion.
**Evidence required**: power calculations, standard errors, confidence intervals — or the absence of
any power discussion.

## Check 3 — Attrition, balance and compliance

**Tests** whether attrition rates, balance, non-compliance, take-up and differential missingness are
reported and handled.
**Violation**: attrition or imbalance plausibly moves the estimand and is not quantified, adjusted,
bounded or discussed.
**Evidence required**: the attrition, balance, compliance or missingness tables.

## Check 4 — SUTVA, spillovers and interference

**Tests** whether the paper considers interference, spillovers, contamination, general-equilibrium or
network effects where treatment may reach controls.
**Violation**: the design assumes no interference while the setting creates obvious channels for it,
and none is measured or bounded.
**Evidence required**: the setting, the treatment description, and what the paper says about
spillovers.

## Check 5 — Pre-analysis plan and deviations

**Tests** whether the reported analysis matches the plan, or the deviations are disclosed as such.
**Violation**: exploratory or deviated analyses are presented as pre-specified confirmatory evidence.
**Evidence required**: the registry or plan text and the analysis section. The time-ordering question
in general belongs to `preregistration.md`, which is always routed alongside this reference.

## Check 6 — Multiple testing

**Tests** whether families of outcomes, arms, subgroups and hypotheses get multiplicity handling or
honest framing.
**Violation**: isolated significant results across many outcomes or subgroups are highlighted with no
adjustment, no family definition and no exploratory caveat.
**Evidence required**: the outcomes and subgroups tested, and the adjustment, or its absence.

## Invariants

- Do not demand a pre-analysis plan from a legacy experiment that claims no pre-specification;
  downgrade it to a transparency concern.
- A failed balance test is not automatically fatal. Ask whether the imbalance threatens the claimed
  estimand and whether it is handled.
- Treat spillovers as a finding only where the setting makes interference plausible and relevant to
  the claim.
