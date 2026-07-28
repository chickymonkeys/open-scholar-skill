# MODE 7 — Validation (HARD GATE)

**No full-corpus run until this passes.** LLM labels are a measurement; report their reliability.

## Command
```bash
python3 assets/annotate_engine.py validate \
  --pred output/tables/llm_dev_pred.csv --gold output/tables/devset_gold.csv \
  --id-col video_id --on relevance,discourse_frame --gate 0.70 \
  --out output/tables/validation_report.json
```
Reports, per field: n, **Cohen κ (LLM vs gold)**, **macro-F1**, and a classification report.
**Exit code 2 if the primary field's κ < 0.70** — the gate blocks the pipeline.

## The bar
- **κ ≥ 0.70** on the primary field (per-field F1 reported for transparency). κ, not accuracy —
  it corrects for the class prior (a 90%-one-class corpus makes accuracy meaningless).
- Report per-class F1: a high overall κ can still hide a failing rare class (often the target).
  If the target class F1 is weak, iterate even if overall κ passes.

## Lin & Zhang (2025) four risks — assess all four
1. **Validity** — does the annotator measure the intended construct? (inspect CoT rationales on a sample).
2. **Reliability** — temperature=0; report run-to-run κ on a 50-doc re-annotation.
3. **Replicability** — exact model id + version + date + prompts/program hash archived.
4. **Transparency** — prompts reproduced in the appendix; limitations stated.

## If it fails
Do NOT scale. Iterate the cheapest lever first: sharpen the codebook definitions/boundary
rules → re-optimize few-shot (MODE 6) → re-validate. Consider a stronger model for the target
class. Only a passing gate unlocks MODE 8.
