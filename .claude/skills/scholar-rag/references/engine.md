# scholar-rag engine reference (`assets/`)

Self-contained Python engine. All modules import `store.py` for the corpus
manifest; nothing depends on the rest of the plugin. Run everything with the
venv interpreter (`$SCHOLAR_RAG_DIR/.venv/bin/python`, aliased `rag_py` / `RAG_PY`).

## Module map

| Module | Role | Key deps |
|---|---|---|
| `store.py` | `corpus.sqlite` schema + CRUD; store layout; hashing; manifest | stdlib only |
| `zotero_reader.py` | read `zotero.sqlite` (immutable-ro, no copy) → items + resolved PDF paths | stdlib only |
| `ingest.py` | stage 1: source (Zotero/folder) → document rows | stdlib only |
| `extract.py` | stage 2: PDF → page-mapped text (PyMuPDF → pdftotext → vision-OCR) | fitz |
| `chunk_embed.py` | stage 3: section-aware chunk + bge-m3 → LanceDB + BM25 index | sentence-transformers, lancedb |
| `query.py` | dense + hybrid (RRF) + rerank retrieval | sentence-transformers, lancedb |
| `graphrag.py` | seed(KG) → LLM extract → Leiden → summaries; local/global/neighbors | ollama HTTP, igraph, leidenalg |
| `mcp_server.py` | stdio MCP server (FastMCP successor `MCPServer`) | mcp |
| `setup-venv.sh` / `run-ingest.sh` / `mcp-setup.sh` / `_lib.sh` | provisioning + resumable build + registration + shell helpers | uv, bash |

## Store layout (`$SCHOLAR_RAG_DIR`, default `~/.claude/scholar-rag/`)

```
corpus.sqlite   documents(doc_id PK, zotero_key, doi, title, authors_json, year,
                journal, item_type, source, pdf_path, pdf_sha256, extract_method,
                ocr_used, n_pages, n_chars, text_path, quality, status, error, …)
                chunks(chunk_id PK, doc_id, ord, section, page_start, page_end,
                       char_start, char_end, n_chars, text_sha256, embedded)
raw/text/<doc_id>.json   page-mapped extracted text (cache; enables re-chunk/re-embed)
raw/meta/<doc_id>.json   full bibliographic record
index/                   LanceDB table `chunks` (vector + metadata + FTS/BM25)
graph/                   entities.ndjson, relations.ndjson, doc_edges.ndjson,
                         communities.json, community_summaries.json, extracted_docs.json
manifest.json            embed model + dim + chunk params + source + build stats
logs/                    trace-scholar-rag.ndjson + ingest-run-*.log
.venv/                   self-contained CPython 3.12 environment
```

`status` lifecycle per document: `new → extracted → embedded` (or `no_pdf` / `failed`). Each stage only processes rows not yet advanced, so the whole build is resumable.

## Data flow

```
Zotero/PDFs ──ingest──▶ documents(new)
   PDF ──extract(pymupdf|pdftotext|vision-ocr)──▶ raw/text + documents(extracted)
   text ──chunk(section-aware,~500tok,overlap)+bge-m3──▶ LanceDB + documents(embedded)
   query ──bge-m3 q-embed + cosine (+BM25 RRF +rerank)──▶ cited passages
   [GraphRAG] docs ──seed(scholar-knowledge)+LLM extract──▶ entities/relations
              ──Leiden──▶ communities ──LLM──▶ summaries ──▶ local/global search
   MCP server wraps query.py + graphrag.py for Claude Code / Codex
```

## Design decisions & gotchas

- **Python 3.12 venv via `uv`.** The host may run a Python newer than torch ships
  wheels for; `setup-venv.sh` provisions 3.12 with `uv` (no system Python touched).
- **bge-m3, offline at query time.** Instruction-free; queries and passages embed
  identically, normalized (cosine = dot). `query.py`/`mcp_server.py` set
  `HF_HUB_OFFLINE=1` so the cached model loads with no network round-trip. First
  use of an *uncached* reranker needs `HF_HUB_OFFLINE=0` once (or prefetch it).
- **Zotero attachment paths.** `itemAttachments.path` is only the filename
  (`storage:foo.pdf`); the real file is `storage/<attachment-item-key>/<filename>`,
  where the key is the attachment *item's* own `items.key`. `zotero_reader.py`
  resolves stored, base-dir (`attachments:`), and linked-file attachments.
- **Author formatting.** Authors are stored `"Last, First; Last, First"` (joined by
  `;`, since each name has an internal comma) so the citation formatter can count
  authors and emit `Surname (Year)` / `Surname et al. (Year)` correctly.
- **LanceDB API drift.** `list_tables()` returns a `ListTablesResponse` (`.tables`),
  not a list; both `chunk_embed.py` and `query.py` normalize this and fall back to
  the deprecated `table_names()` on older lancedb.
- **MCP SDK.** Newer SDKs expose `mcp.server.MCPServer` (the FastMCP successor:
  same `.tool()` decorator, `.run()` stdio default); `mcp_server.py` falls back to
  `mcp.server.fastmcp.FastMCP` on older SDKs.

## GraphRAG model selection (important)

`ollama` is the local LLM backend. **The installed ollama build determines what
runs:**

- `gpt-oss:20b` / `gpt-oss:120b` are the ideal (fast MoE) extractors but fail with
  `tensor "blk.0.ffn_down_exps.weight" size overflow` on older ollama builds.
  Fix: `brew upgrade ollama`, restart the server, then `RAG_GRAPH_MODEL=gpt-oss:20b`.
- `deepseek-r1:32b` / `:70b` **run** and honor `format=json`, but are *reasoning*
  models — slow for bulk extraction (default, but expect hours over a big library).
- **Recommended when gpt-oss is unavailable:** a fast instruct model, e.g.
  `ollama pull qwen2.5:7b-instruct` then `export RAG_GRAPH_MODEL=qwen2.5:7b-instruct`
  (fast, strong JSON adherence, multilingual).
- Vision-OCR uses `llama3.2-vision:90b` (`RAG_OCR_MODEL`).

Extraction is section-bounded (`RAG_GRAPH_MAX_CHARS`, default 12k chars ≈ 3k tokens)
and output-capped (`RAG_GRAPH_NUM_PREDICT`) to keep per-paper latency down. It is
resumable per document via `graph/extracted_docs.json`.

## Troubleshooting

- *"no index yet"* on query → run the build (mode 1) first; check `ingest.py status`.
- *HF network chatter on MCP start* → model not yet cached; run one online build, or
  `setup-venv.sh --prefetch-models`.
- *many `no_pdf`* → Zotero items whose attachment file isn't synced locally; the
  optional open-access fetch (roadmap) or syncing Zotero storage will fill these.
- *GraphRAG extraction stalls* → wrong/absent ollama model; check `ollama list` and
  the model-selection notes above.
