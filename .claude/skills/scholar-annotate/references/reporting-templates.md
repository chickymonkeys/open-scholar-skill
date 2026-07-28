# MODE 10 — Reporting & Deliverables

Assemble the labeled dataset plus a reproducible Methods/Results packet.

## Artifacts
- `output/tables/…labeled.csv` / `.parquet` — the full labeled dataset (id + fields + rationale).
- `codebook.md` (versioned), `annotator_program.json` (+ hash), `validation_report.json`.
- `cost_ledger.json`, AI-use/data-transfer disclosures (from the audit log).

## Methods prose (drop-in) — fill every bracket
> We measured [construct] over [N] [units] using an LLM annotator. A codebook ([K] classes;
> [sub-codes]) was compiled into a typed prompt and output schema. We built a [size]-item gold
> set via [human double-coding (Krippendorff α = [x]) / dual-model agreement (Claude+GPT κ = [x])],
> optimized the prompt with DSPy (ChainOfThought + BootstrapFewShot, [k] demonstrations), and
> validated against a held-out gold split: **Cohen κ = [x]**, macro-F1 = [x] (per-class F1 in
> Table [n]). Annotation ran at temperature 0 on [model id] ([date]) via [managed Batch API /
> local llama.cpp server on <cluster>]; prompts, program hash, and model id are archived. [If
> distilled:] labels were distilled to a [TF-IDF+logistic] classifier (κ = [x] vs gold) to score
> the full corpus; predicted labels entering regressions were DSL-bias-corrected.

## Results reporting
- Class/frame distribution over the corpus (Table).
- Reliability: κ (+ per-class F1); human α if applicable.
- Cost + compute; data-transfer disclosure.
- Honest framing: this is a **measurement** with error — report the κ as the measurement's
  reliability and (for distillation) treat outputs as predicted-with-error.

## Save
Two files (version-checked): internal log + this Methods/Results doc → also `.docx/.tex/.pdf`
via `_shared/pandoc-multiformat.md`. Hand the labeled variable to `/scholar-analyze` or
`/scholar-compute` for downstream modeling.
