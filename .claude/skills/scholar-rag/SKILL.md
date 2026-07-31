---
name: scholar-rag
description: "Build and query a local vector database + GraphRAG over your entire reference library (Zotero or a PDF folder) for literature review. Downloads/locates full-text PDFs, extracts text (pdftotext/PyMuPDF/vision-OCR), chunks and embeds with bge-m3 into LanceDB, and layers a local-LLM GraphRAG (entity/relation extraction + Leiden communities + community summaries) seeded from the scholar-knowledge graph. Exposes semantic retrieval to Claude Code and Codex via an MCP server (rag_search / rag_get_document / rag_neighbors / rag_stats). Fully self-contained and fully local (bge-m3 + ollama + LanceDB) — nothing leaves the machine. Use to build a searchable literature corpus, ground lit-review claims in cited passages, or find related papers."
tools: Read, Bash, Write
argument-hint: "[setup|ingest|query|mcp|graph|status] [args], e.g. 'ingest' or 'query how does segregation affect mobility' or 'graph run'"
user-invocable: true
---

# Scholar RAG — Local Vector DB + GraphRAG for Your Literature

You turn a scholar's whole reference library into a **searchable, cited knowledge base**. This skill ships a **real, self-contained execution engine** in `assets/` (a Python package + a venv provisioner + a resumable build wrapper + an MCP server) — not in-context snippets. Everything runs **locally**: `bge-m3` embeddings, an `ollama` LLM for GraphRAG, `LanceDB` for vectors, and a stdio MCP server. No data leaves the machine; the only network use is the optional open-access PDF fetch.

It is the **dense-retrieval complement** to `scholar-knowledge` (which stores *symbolic* extracted findings, keyword-searched). `scholar-knowledge` answers "what does the field claim"; `scholar-rag` answers "show me the exact passages, cited, and the papers near them." The two share paper identity by DOI/title and `scholar-rag`'s GraphRAG **seeds its entity graph from `scholar-knowledge`**.

> **SELF-CONTAINED.** The engine has no hard dependency on the rest of the plugin. It provisions its own venv, reads Zotero directly, and bundles its own logging. It *optionally* seeds from `scholar-knowledge` if present, degrading gracefully if not.

> **DATA SAFETY.** The corpus is *published papers* — normally `CLEARED`. But in `folder` mode a directory may contain unpublished drafts or sensitive PDFs. If a project safety sidecar (`.claude/safety-status.json`) marks any input `NEEDS_REVIEW`/`HALTED`, do not ingest it; route through `/scholar-safety` or `/scholar-init` first. Local embeddings + local LLM mean no external transfer by default.

---

## Arguments and Mode Routing

The user has provided: `$ARGUMENTS`

| Keyword(s) | Mode | What it does |
|---|---|---|
| `setup`, `install`, `venv` | **0 SETUP** | Provision the self-contained Python venv (one-time) |
| `ingest`, `build`, `index`, `add` | **1 INGEST** | Source → extract text → chunk → embed → LanceDB (resumable) |
| `query`, `search`, `find`, `ask` | **2 QUERY** | Semantic retrieval (dense + hybrid BM25 + optional rerank) |
| `mcp`, `register`, `serve`, `connect` | **3 MCP** | Register the MCP server with Claude Code / Codex |
| `graph`, `graphrag`, `neighbors`, `communities`, `global` | **4 GRAPH** | GraphRAG: seed → extract → build → summarize; local/global search |
| `status`, `stats`, `coverage` | **5 STATUS** | Corpus + index + graph coverage |

If the mode is ambiguous, ask. `full` runs 0→1→3 (setup, build, register MCP); GraphRAG (mode 4) is run explicitly because it is the long, LLM-bound stage.

---

## Setup block (run once per Bash session, all modes)

Resolve this skill's `assets/` dir (self-contained — tries the dev tree, the
marketplace install, then a find) and the venv interpreter:

```bash
# locate assets/ without depending on plugin bootstrap vars. CLAUDE_PLUGIN_ROOT
# is set by Claude Code for plugin skills; the rest are install-layout fallbacks.
RAG_ASSETS=""
for c in \
  "${CLAUDE_PLUGIN_ROOT:-}/skills/scholar-rag/assets" \
  "${SCHOLAR_SKILL_DIR:-}/.claude/skills/scholar-rag/assets" \
  "${SCHOLAR_SKILL_DIR:-}/skills/scholar-rag/assets" \
  "$HOME/.claude/skills/scholar-rag/assets"; do
  [ -n "$c" ] && [ -f "$c/ingest.py" ] && { RAG_ASSETS="$c"; break; }
done
[ -z "$RAG_ASSETS" ] && RAG_ASSETS="$(dirname "$(find "$HOME/.claude" -name mcp_server.py -path '*scholar-rag*' 2>/dev/null | head -1)")"
. "$RAG_ASSETS/_lib.sh"     # sets SCHOLAR_RAG_DIR, RAG_VENV, RAG_PY, rag_trace()
echo "assets=$RAG_ASSETS  store=$SCHOLAR_RAG_DIR  py=$RAG_PY"
```

Then `rag_py <script.py> ...` runs an engine module with the resolved interpreter.

### Process logging (RAO trace)

At each meaningful step (a build stage, MCP registration, a graph stage), append one Reasoning·Action·Observation record. Prefer the plugin's shared tracer when present; the engine also writes a **bundled** trace via `rag_trace()` in `_lib.sh`, so logging works even in a standalone deploy:

```bash
# shared emit-trace.sh if available, else the self-contained bundled fallback
TRACE() { bash "${CLAUDE_PLUGIN_ROOT:-${SCHOLAR_SKILL_DIR:-$RAG_ASSETS/../../..}}/scripts/gates/emit-trace.sh" --skill scholar-rag "$@" 2>/dev/null \
  || rag_trace "$(echo "$*" | sed -n 's/.*--step \([^ ]*\).*/\1/p')" ok "$*"; }
TRACE --step "ingest" --reasoning "build the vector DB from Zotero" \
      --action "run-ingest.sh --batch 64" --observation "<N> docs embedded" --status ok
```

Privacy: traces carry counts / verdicts / file refs only — never verbatim passage text or PII.

---

## MODE 0 — SETUP (one-time)

Provision the venv (CPython 3.12 via `uv`; installs PyMuPDF, LanceDB,
sentence-transformers/bge-m3, mcp, and the GraphRAG deps) and prefetch bge-m3:

```bash
bash "$RAG_ASSETS/setup-venv.sh" --prefetch-models   # add --no-graph to skip Leiden deps
```

Verify: the script prints `ok` for `fitz, lancedb, sentence_transformers, mcp, torch (MPS=…)`. Report the torch/MPS line — MPS-accelerated embedding is much faster.

---

## MODE 1 — INGEST (build the vector DB)

The resumable, three-stage build (source → extract → embed). Safe to re-run; each stage skips finished work. This is the main deliverable.

```bash
# whole Zotero library (auto-detected); use --limit to trial a subset first
bash "$RAG_ASSETS/run-ingest.sh" --batch 64            # foreground (watch it)
bash "$RAG_ASSETS/run-ingest.sh" --batch 64 --background   # detach; tail the printed log
# a folder of PDFs instead of Zotero:
bash "$RAG_ASSETS/run-ingest.sh" --source folder --folder /path/to/pdfs
# enable vision-OCR for scanned PDFs (slower; llama3.2-vision via ollama):
bash "$RAG_ASSETS/run-ingest.sh" --ocr
```

Scale note: a full library is embedding-bound (~thousands of PDFs → hours on MPS). It is resumable — a killed run continues. Individual stages: `rag_py ingest.py zotero --with-pdf-only`, `rag_py extract.py run`, `rag_py chunk_embed.py run`.

---

## MODE 2 — QUERY (semantic retrieval)

```bash
rag_py query.py "how does residential segregation affect intergenerational mobility?" -k 8 --hybrid
# filters + reranking:
rag_py query.py "identification strategy" -k 6 --section methods,results --year-min 2010 --rerank --json
```

Returns passages with an author-year citation, section, page range, DOI, and similarity. Use `--json` for machine-readable output. This is exactly what the MCP `rag_search` tool wraps.

---

## MODE 3 — MCP (expose to Claude Code / Codex)

```bash
bash "$RAG_ASSETS/mcp-setup.sh"              # register with every detected host
bash "$RAG_ASSETS/mcp-setup.sh" --print-only # just show the .mcp.json / config.toml snippets
```

Registers a stdio MCP server exposing **`rag_search`**, **`rag_get_document`**, **`rag_neighbors`**, **`rag_stats`**. Restart the Claude Code / Codex session to pick up the tools. In a lit-review session, call `rag_search` to ground every claim in cited passages from your own library.

---

## MODE 4 — GRAPH (GraphRAG)

The LLM-bound long pole; run **after** the vector build. Fully local via `ollama`.

```bash
rag_py graphrag.py seed                 # import scholar-knowledge concepts + citation edges (fast, no LLM)
rag_py graphrag.py extract              # LLM entity/relation extraction per paper (resumable; the long stage)
rag_py graphrag.py build                # dedup entities → Leiden communities
rag_py graphrag.py summarize            # LLM community summaries (global-search corpus)
# or the whole chain (bounded by --limit while trialing):
rag_py graphrag.py run --limit 50
# query:
rag_py graphrag.py local  "mechanisms linking neighborhood to health"   # entity-grounded passages
rag_py graphrag.py global "what are the major theoretical camps in this literature?"  # map-reduce over communities
rag_py graphrag.py neighbors <doc_id>   # papers sharing entities / citations
```

**Model note.** Extraction defaults to `deepseek-r1:32b` (runs on the installed ollama, honors `format=json`). `gpt-oss:20b` is faster and preferred **if** ollama is new enough to load it (older builds fail with an MoE "size overflow"): `brew upgrade ollama` then `export RAG_GRAPH_MODEL=gpt-oss:20b`. Any fast instruct model works, e.g. `RAG_GRAPH_MODEL=qwen2.5:7b-instruct`. Extraction over a full library is hours of local inference — run it detached and let it resume across sessions.

---

## MODE 5 — STATUS

```bash
rag_py ingest.py status        # documents by stage, chunk counts, no-PDF coverage
rag_py graphrag.py status      # entities / relations / communities / summaries
```

---

## Integration

- **Lit review / writing:** once the MCP server is registered, `scholar-lit-review`, `scholar-write`, and `scholar-citation` can call `rag_search` as a full-text semantic tier (complements Tier-0 KG metadata and Tier-1 Zotero).
- **Feedback to `scholar-knowledge`:** extracted full text can upgrade abstract-only nodes — run `/scholar-knowledge re-extract` after a build.
- **Shared identity:** `doc_id` = sha256(normalized DOI or title), so a passage hit cross-links to the same paper's symbolic findings.

## Configuration (`.env` or environment)

`SCHOLAR_RAG_DIR` (store, default `~/.claude/scholar-rag`) · `SCHOLAR_ZOTERO_DIR` (auto-detected) · `EMBED_MODEL` (default `BAAI/bge-m3`) · `RAG_CHUNK_CHARS` / `RAG_CHUNK_OVERLAP` · `RAG_GRAPH_MODEL` / `RAG_SUMMARY_MODEL` · `RAG_OCR_MODEL` (default `llama3.2-vision:90b`) · `OLLAMA_HOST`.

## Quality checklist

- [ ] `setup-venv.sh` reports all imports `ok` and torch MPS status.
- [ ] `ingest.py status` shows `embedded > 0` and a sane `no_pdf` count before querying.
- [ ] A known-topic `query.py` returns the expected paper with correct author-year + page.
- [ ] MCP handshake lists all four tools (`rag_search`/`rag_get_document`/`rag_neighbors`/`rag_stats`).
- [ ] GraphRAG `status` shows entities and communities before using `global`.
