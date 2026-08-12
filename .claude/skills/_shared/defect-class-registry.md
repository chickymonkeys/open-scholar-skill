# Defect-Class Registry (cross-project)

A named, persistent catalogue of defect **classes** — not individual bugs. Individual bugs are
found once and fixed; classes recur across projects and recur *in the guards written to prevent
them*. This file is the memory that makes them findable.

**Why a registry rather than review-brief prose.** Measured on the 2026-08
a 2026-08 large-corpus annotation run: instances 1–5 of class DC-01 were found incidentally,
across four review iterations, by agents chasing unrelated symptoms. Instances 6–14 were found
**within hours of the class being named and written down**, by agents sweeping for the *pattern*
rather than the reported symptom. Naming is the intervention.

**And naming does not immunise the author.** Three DC-01 defects were introduced *in guards
written to enforce DC-01*, within one session of naming it. Treat every entry here as something
you are also capable of committing while fixing.

**Consumers.** All six `.claude/agents/review-code-*.md` briefs carry a standing sweep for
DC-01 and cross-reference this file. `scholar-auto-improve` reads it during AUDIT and IMPROVE.
Add a class here when a defect recurs in ≥2 places or survives ≥2 review passes.

---

## DC-01 — Three-valued logic collapse

**Statement.** Code converts *"not assessed"* into something that reads as *assessed*. A third
state (NA, unparseable, empty, absent, undefined) is silently folded into a definite one, and
every downstream reader treats the fold as a measurement.

**Frequency observed.** 14+ instances, four files, three independent agents, one run — none of
whom were looking for the same thing.

| site | collapse | consequence |
|---|---|---|
| FDR correction | `pv[!as.logical(below_floor),]` | phantom row inflates `nrow(pv)`, passed as **K** → every *other* cell's correction more conservative |
| diagnostic adjudication | `&&` short-circuits NA→FALSE | a diagnostic that *could not be computed* read as *computed and found nothing* — on every row |
| registry build | `length(dirs)>0 && all(...)` | **"pre-registration falsified"** emitted from an empty set |
| temporal trends | `length(unique(numeric(0)))<=1` | **"AGREE"** on a hypothesis from zero executed controls |
| feature build | NaN → `"NAN"` → no branch matches | a variety **KEPT with no evidence** |
| precision audit | `False == False` on two unparseables | scored as two codebooks **agreeing** |
| hurdle model | `!is.na(th) && th<1e-4` | NA→FALSE = "checked, not at boundary"; keeps a clean tag and an AIC advantage the file says must never happen |
| frequency weights | NaN / absent / UNMEASURABLE | all land in **KEEP**, disagreeing with a sibling whose docstring promises they cannot disagree |
| leak audit | bare `except: return []` | unreadable parquet indistinguishable from clean parquet |
| κ validation gate | `nan < 0.70` is False in IEEE-754 | an **undefined** κ passed a hard gate that printed "FAIL" on the same line |

### The countable trigger

The natural-language rule ("record how a conclusion was reached whenever more than one route can
produce the same value") has a flaw as a review trigger: it asks for exactly the awareness that
was missing. Every author who wrote a collapsing instance failed to notice the multiplicity.
Use the countable form instead — it needs no domain knowledge:

> **Count the branches that write a column; count the distinct values they can emit.
> If branches > values, the column is lossy and needs a companion.**

### Sibling shapes

- **Shape A — lazy evaluation (R).** `basename(x)` on an undefined variable inside a
  `stop()`/`warning()`/`message()` never evaluates until the fatal branch fires, so the guard
  crashes with `object not found` exactly when it is needed. **Invisible to parse checks and
  happy-path runs by construction.** *Remedy:* `force()` every message argument at entry.
  *Hunt:* grep for parameters appearing **only** inside `stop`/`warning`/`message`.

- **Shape B — a guard whose failure mode is a false alarm about something graver.** A
  locale-dependent integrity digest (R's default `sort()` is locale-collated) fails on a
  different node — and a failing integrity hash does not read as "this check is broken", it
  reads as **"the data have been altered"**, mid-run, with the authority of an alarm nobody will
  override. *Generalisation:* a guard whose failure mode falsely reports a graver condition is
  more expensive than no guard, because the response it triggers is proportional to the
  condition it falsely reports.

- **Shape C — a default propagating into rows where it does not apply.** An estimator string
  (`feglm`) copied onto two arms that are not logits. *A field whose value was copied rather
  than chosen is unassessed and must be detectable as such.*

- **Shape D — two *definite* states sharing one label.** Subtler than A–C, and **no NA-hunting
  grep finds it**: there is no missing value anywhere, only a lossy encoding.
  `precision_decisions.csv` printed `decision = DROP` for variety B under both audit
  vintages. At n=1,000 the Wilson **upper** bound sat below the floor — *measured below the
  floor*. At n=100 the interval merely **straddled** it — *could not tell, so the pre-stated
  tie-break decided*. Same verdict, entirely different epistemic status. Any prose describing
  variety B as "measured below the measurement floor" is true of one vintage and false of the
  other.

### Remedy, and two constraints on it

The companion column names the **deciding rule**, not just the verdict
(`measured_below_floor` / `indeterminate_resolved_by_tiebreak` / `measured_above_floor`), and
the registry surfaces the companion rather than the verdict alone. Two constraints, both learned
by watching them fail:

1. **The companion must be written by the deciding branch, never reconstructed afterwards.**
   Reconstruction is what `analysis_table_sha256` did — read from a manifest and stamped without
   hashing — and it is why a sampling frame would have been unrecoverable had it not been
   captured deliberately.
2. **The companion must have no default.** A companion defaulting to `measured` reintroduces
   shape D one level up. That is precisely the route by which `feglm` reached two arms that are
   not logits.

### Stated limit

The rule cannot reach a producer that never distinguished the states *in memory* — if the route
is lost before the write, there is no companion to write. The remedy there is upstream and is
the same sentence as the frame-capture lesson: **don't collapse before you record.**

### Mechanical detection (partial)

Lintable sub-cases: `&&` / `||` on NA-capable operands; `as.logical()` feeding a row index;
`identical()` assigning a verdict; a bare `except:` returning an empty container; a float
comparison against a value that can be NaN. Shapes C and D are **not** mechanically detectable
and need the countable trigger applied by a reader.

**Reference implementation of the remedy:** `scholar-annotate/assets/annotate_engine.py`
`cmd_validate` — every gold row excluded from κ carries `excluded_by` naming the branch that
excluded it (`annotator_absent` / `annotator_blank` / `gold_empty`), and `cohen_kappa: null` is
always accompanied by a non-null `kappa_undefined_reason`.

---

## DC-02 — Guards verified in their design state, never in the states they will meet

**Statement.** A guard is tested against the input it was written for and never against the
input it will actually meet. It looks protective and is decoration.

**Frequency observed.** 7 instances in one run, each of which had passed an ordinary
correctness review.

| guard | verified as | actually |
|---|---|---|
| cross-artifact drift check | "0.000% apart — PASS" | threshold `>0.01` against a real drift of **0.449%** — would have passed on its own motivating failure |
| vintage guard | fail-closed vs a *stale* file | skipped entirely on an *absent* file; the reader returns NULL before the provenance call |
| torn-checkpoint self-test | PASS | **constructed the buggy state and asserted it as PASS** |
| merge under-coverage | `rc=4` fatal | `os.replace()` published *before* the check ran |
| downloader exit-5 | correct on run 1 | self-disarming on run 2 — the skip-list its own first run wrote empties the todo set |
| local-mode leak audit | "0 leaks, PASS" | would print the same with the parquet library absent, having inspected **zero** schemas |
| analysis-table integrity | sha256 in manifest | verified by nobody — the DSL stamps a copied claim the registry compares against the same manifest |

**Why ordinary review misses it.** Every review brief asks whether the code is *correct*. None
asked the question that separates a guard from decoration: **what input makes this fire, and
what slips past?**

**Remedy — now a required report field.** `review-code-robustness` and `review-code-correctness`
must emit a per-guard `FIRES ON:` / `SLIPS PAST:` pair. Cheap, and it converts "looks
protective" into a falsifiable claim. When fix tracks were instructed to annotate every guard
this way, the next review round found materially fewer guard defects.

**Sub-shape — asserting presence where you mean to assert state.** A preflight required two
model arms to be *present* in a registry and to carry `assumed_inputs`. Correct when written.
Once those arms were legitimately retired, the preflight could not distinguish **"correctly
withdrawn"** from **"missing"**. *Generalisation:* when a guard checks for the presence of a
thing as a proxy for that thing being correct, it silently forbids the thing being legitimately
removed. Assert the state you mean (`status: retired` + a revision note), not a proxy for it.

---

## DC-03 — Fix commits are a fresh unaudited surface

**Statement.** Fixes fail at approximately the rate of original code, because they are written
under time pressure, in unfamiliar regions, by an author who has just been told they were wrong.

**Evidence.** CRITICAL counts by Phase 5.5 iteration: **40 → 15 → 26 → 11**. Iteration 3
reviewed six fixes written earlier the same day and found **two defective**. Iteration 4 reviewed
the iteration-3 fixes and found 11 CRITICALs, **8 of them in the assurance layer itself**.

> Fix commits are not evidence against a class; they are a fresh unaudited surface for it,
> written under exactly the conditions that produce the original.

**Remedy.** `iter2-required-check.sh` enforces iterN, not iter2: any RED iteration requires a
following iteration, **scoped to the diff** (a full re-review re-finds settled issues; the
diff-scoped iteration 4 found 11 real CRITICALs in one pass). Note that a pattern-absence check
such as `fix-contract-verify.sh --phase AFTER` verifies the flagged pattern is gone — it cannot
see a defect the fix *introduced*. Only another review iteration can.

---

## DC-04 — A measurement consumed without the question that produced it

**Statement.** A constant derived from a measurement is consumed by a model that needs a
*different* construct than the instrument asked about. Both instruments validate well against
their own gold; the mismatch is invisible to reliability metrics by construction.

**Evidence.** `TARGET_RECALL <- 0.62`, measured under a prompt asking about "the superordinate category in the
sense used by domain experts" and crediting colloquial alternatives — consumed by a
model implementing a lexicon that deliberately excludes them. A codebook-matched re-draw on the
same item set measured **0.94**; the "surface-form asymmetry" that drove two declared sensitivity
arms and a planned manuscript caveat was **absent**. Survived four review iterations; surfaced
only when the estimator refused a degenerate fit.

**Three compounding reasons, each with its own remedy:**

1. **A literal is not a read.** Retracting the source artifact — renaming the discredited column,
   writing `claim_supported = False` on every row — reached none of the hard-coded
   number. *A number typed into source cannot be invalidated by fixing the artifact it came from.*
2. **A comment asserted the opposite.** The block header read *"NOTHING here is hard-coded from a
   count"* — true of the cell counts, false of the rate, and the rate was load-bearing.
3. **Nobody asked what the annotator was asked.** Six agents checked whether the number was
   *used* correctly; none checked whether it *measured the construct the model needed.*

**Remedies.** `design/measurement-constants.json` + `design/construct-match.json`, enforced by
`scripts/gates/measurement-instrument-check.sh`; the instrument block in
`validation_report.json`; and the U17 paragraph in the `review-code-statistics` /
`review-code-data-handling` briefs. Full treatment:
`scholar-annotate/references/construct-match.md`.

**Adjacent shape — prose fields inside artifacts are outputs.** When a claim is retracted from
code, it is not thereby retracted from the estimand strings, `*_NOTE` columns, drafter
instructions, and arm inventories that ship beside the numbers — some of which are lifted
**verbatim into the manuscript**. All six `review-code-*` agents read code; the `verify-*` agents
read the manuscript against the tables; **nobody reads the prose inside the analysis artifacts.**
Estimand strings destined for a manuscript should be generated from the same artifact the numbers
come from, never typed alongside them.

---

## DC-05 — A default that determines evidentiary strength

**Statement.** A CLI default or unset flag silently decides how strong the evidence behind a
shipped decision is.

**Evidence.** (a) A precision audit was authorised at n=400 (n=1,000 for a borderline case)
*specifically because* a KEEP/DROP gate rested on overlapping Wilson intervals. A rebuild re-ran
that node at the wrapper's default `PER_STRATUM=100` and overwrote it; variety A flipped from
0.925 [0.895, 0.947] KEEP to 0.83 [0.745, 0.891] INDETERMINATE→DROP — **a power artifact**, the
point estimate having moved within sampling noise. (b) A separate wrapper defaulted to a
full-pool relabel of ~90k comments (8h, 4 GPUs, under a *different quant* than the shipped
labels) unless `AUDIT_ONLY=1` was set; the driver simply never set it.

> **Any default that silently determines the evidentiary strength of a shipped decision is a
> trap, not a default.** The safe path is the default; expensive or destructive paths require an
> explicit opt-in that the caller must state.

**Remedies.** Design parameters (n, stratification, stopping rule) are declared properties in
`design/`, read by the wrapper and **stamped on the artifact** — see `measurement-design.json`
and the `<out>.design.json` sidecar written by `annotate_engine.py sample`, compared by
`measurement-instrument-check.sh` R4. Engine-side: `--allow-unreadable` defaults to 0, so a
corpus read that lost files fails closed rather than silently shrinking the sample.

---

## DC-06 — Presence checked where vintage is meant

**Statement.** `require_file`-style guards check that an input **exists**, not that it belongs to
the **current build**. A stale artifact from a previous build satisfies the check.

**Evidence.** A resubmission of an FDR node was refused by a track that noticed its required
input existed *from the previous build*. The node would not have failed — it would have
*succeeded*, writing a freshly-timestamped corrections table holding families 1/3/4 from build
63032 and family 2 from the current build: internally mixed, mtime-current, and invisible to per-row
vintage machinery because the registry never reads inside it.

**Remedy.** `require_file` → `require_artifact_of_build`: presence **plus** the artifact's own
recorded `build_id` matching the current manifest. Presence checks are the default idiom
throughout HPC wrapper code and every one of them has this hole. Guidance:
`scholar-annotate/references/scale-engine.md` §Build-vintage guards.

---

## DC-07 — A pin trusted by permission rather than verified by content

**Statement.** Freezing code for the duration of a long run by making it read-only prevents
nothing, because `chmod a-w` is advisory against the file's **owner** and every job runs as the
owner.

**Evidence.** A DAG node failed 37s in with `Error: unexpected symbol`; the script's mtime was
16 seconds before the failure — an agent was editing an analysis script while a 12-hour DAG was
reading it. Cascade: six nodes. A sibling track's blast-radius audit found its own margin was
**10 minutes** on one file; it held by luck.

The correction matters more than the finding, and it is itself an instance of DC-02: the
immutability test written to *demonstrate* the pin instead modified the pinned file
(`pin_mtime` moved), and a re-run on a second file confirmed it — `touch` SUCCEEDED. What
actually protected the resubmitted job was not the permission bit but a parse-check job printing
`sha=7b174349c0f34889` and the job executing that same content. **The chmod was decoration; the
digest was the guarantee.**

> **A pin must be verified by content at job start, never trusted by permission.** The strong
> form is a content-addressed store — the pinned path *is* the digest (`_pinned/<sha256>/`), so
> "has it moved?" becomes unanswerable-by-construction rather than checked. Failing that, the
> runner re-hashes the entry script and its first-party imports immediately before exec and
> refuses on mismatch. **An unset pin must refuse, not pass** — otherwise every hand-submitted
> job silently opts out, and those are the submissions most likely to be racing an edit.

Pinning prevents an **accident**, which is the actual failure mode that killed the node, but
prevents nothing an owner can do deliberately. Verification is the load-bearing half.

---

## How to add a class

1. Confirm it recurs — ≥2 independent sites, or it survived ≥2 review passes.
2. State it as a **mechanism**, not a symptom, in one sentence.
3. Give the evidence table: site → what the code does → what the reader concludes.
4. Give a **countable or greppable trigger** where one exists, and say plainly where none does.
5. Name the remedy AND its constraints — a remedy with an unstated constraint becomes the next
   entry (see DC-01 shape D, constraint 2).
6. Cross-reference the consuming briefs and gates so the class is swept, not just filed.
