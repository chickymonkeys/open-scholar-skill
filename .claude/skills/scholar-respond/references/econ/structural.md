# Structural and Counterfactual

Routed to **R1**. Principles that bite hardest: **P1**, **P2**, **P4**, **P5**.

The question is whether a reader can trace the chain from primitives to counterfactual: assumptions,
the mapping from model to data, which moments identify which parameter, fit, sensitivity, and what
the policy simulation rests on. Generic robustness cannot ask for that mapping; that is why this
dimension stays distinct.

Prefix findings `STR-`.

## Check 1 — Assumption inventory and plausibility

**Tests** whether maintained assumptions — equilibrium concept, information structure, functional
forms, timing — are listed and tied to the conclusions that need them.
**Violation**: a central result depends on an implicit or implausible assumption that is not
disclosed, motivated or tested.
**Evidence required**: the model section, equation or counterfactual where the assumption enters.

## Check 2 — Identification of the primitives

**Tests** whether the paper says which data variation or moments identify each key primitive.
**Violation**: parameters are estimated or calibrated with no transparent mapping from observables
and moments to primitives.
**Evidence required**: the parameter table, the moment table, the estimation section — or the missing
mapping.

## Check 3 — Fit and overidentification diagnostics

**Tests** whether fit is shown for the moments that matter to the counterfactual, not only the
targeted ones.
**Violation**: the model fits selected targets, or omits diagnostics for moments central to the policy
simulation.
**Evidence required**: fit tables, validation moments, figures — or their absence.

## Check 4 — Sensitivity to assumptions and calibrated values

**Tests** whether the headline counterfactual survives plausible changes in key assumptions, fixed
parameters, functional forms or moments.
**Violation**: a headline counterfactual or welfare number is shown under one maintained
specification despite an obvious sensitivity.
**Evidence required**: the sensitivity table, or its absence, and the assumption at issue.

## Check 5 — Counterfactual validity

**Tests** whether the simulated policy respects the support of the identifying variation, the
equilibrium response, and the data domain.
**Violation**: the paper simulates a policy outside the range or the institutional environment where
the parameters were identified, with no caveat and no sensitivity.
**Evidence required**: the counterfactual scenario and the identification or support discussion.

## Invariants

- Do not penalise a structural paper for having assumptions. Audit whether they are visible,
  motivated and consequential.
- Ask only for sensitivity analyses that would change an interpretation or a policy conclusion.
- Separate a failure of transparency from a disagreement with the modelling style.
