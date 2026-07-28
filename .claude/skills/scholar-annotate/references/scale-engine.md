# MODE 8 — Scale Engine (full-corpus annotation)

Only after MODE 7 passes. All scaled work runs through `annotate_engine.py annotate` — never a
hand-rolled loop. Driven by a run manifest.

## Run manifest
```json
{"input":"corpus_or_sample.csv","id_col":"video_id","text_cols":["title","description","tags"],
 "strata_col":"query_category","codebook":"codebook.md","out_dir":"output/annotations",
 "provider":{"strategy":"local","provider":"local","model":"glm-5.2",
             "api_base":"http://127.0.0.1:8080/v1","key_env":"GLM_API_KEY"},
 "fewshot":{"gold":"output/tables/devset_gold.csv","k":2},"workers":16,"shards":64}
```

## Three strategies (`provider.strategy`)
- **`batch`** — managed OpenAI/Anthropic Batch API. 50% cheaper, async (minutes–24h). The engine
  submits, polls, and collects; `provider.provider` = `openai|anthropic`.
- **`async`** — concurrent live requests (`workers` threads). For mid-size, need-it-now runs.
- **`local`** — async against an OpenAI-compatible on-prem server (llama.cpp/ollama/vLLM). The
  privacy-preserving path; pair with `assets/hpc/` for SLURM.

## Durability (built in)
- **Resumable** — per-id checkpoint (`processed*.txt`); re-run skips done. In-run **stable-hash
  dedup** (a corpus mirror often has duplicate ids — don't pay to re-annotate them).
- **Sharded output** — `annot_###.csv` (no single giant file). **Job-array sharding**
  (`--shard i --nshards N`) splits the corpus across cluster nodes with disjoint, contention-free
  files.
- **Cost ledger** + `--dry-run` pre-flight estimate.

## HPC (local model on GPUs)
`assets/hpc/annotate.sbatch` starts the server (llama.cpp/vLLM/ollama), waits for `/v1/models`,
then runs the engine against `localhost`. Scale horizontally with `#SBATCH --array=0-N`.
Transfer a slim corpus mirror first: `assets/hpc/prep-mirror.py` + `rsync-helper.sh`.
```bash
SMOKE=500 sbatch assets/hpc/annotate.sbatch   # smoke-test, eyeball output
sbatch assets/hpc/annotate.sbatch             # full run, resumable
```

## Hand-off
Merge shards → parquet; `relevance==TARGET` rows are the analyzable subset. Then MODE 10 (report)
or straight to `/scholar-analyze` / `/scholar-compute` on the labeled variable.
