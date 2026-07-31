#!/usr/bin/env python3
"""
chunk_embed.py — section-aware chunking + bge-m3 dense embeddings -> LanceDB.

For each extracted document (status='extracted'):
  1. rebuild full text with a char->page index (for accurate page citations)
  2. detect coarse sections (front / intro / methods / results / discussion /
     ... ); the References list is tagged and excluded from the chunk pool
  3. slide a ~500-token window (char-based, sentence-aware, with overlap)
  4. embed all chunks with BAAI/bge-m3 (normalized, MPS if available)
  5. write vectors + metadata to the LanceDB `chunks` table; mark embedded

Idempotent per document: existing LanceDB rows + chunk manifest rows for a doc
are deleted before re-adding, so re-runs converge. Resumable across runs.

Usage:
  python3 chunk_embed.py run [--limit N] [--force] [--batch 48]
  python3 chunk_embed.py model-info
"""
import os, re, sys, json, bisect, argparse
import store

EMBED_MODEL = os.environ.get("EMBED_MODEL", "BAAI/bge-m3")
CHARS_PER_CHUNK = int(os.environ.get("RAG_CHUNK_CHARS", "2000"))   # ~500 tokens
CHUNK_OVERLAP = int(os.environ.get("RAG_CHUNK_OVERLAP", "300"))    # ~75 tokens
TABLE = "chunks"

# section header patterns (line is short + starts with/equals a known heading)
_SECTIONS = [
    ("abstract", r"abstract|summary"),
    ("introduction", r"introduction|background"),
    ("literature", r"literature review|related work|prior (work|research|literature)|theoretical (background|framework)|theory"),
    ("methods", r"methods?|methodology|materials and methods|data and methods|research design|empirical (strategy|approach)|study design"),
    ("results", r"results?|findings|empirical results|analysis"),
    ("discussion", r"discussion|general discussion"),
    ("conclusion", r"conclusions?|concluding remarks"),
    ("references", r"references|bibliography|works cited|literature cited"),
]
_SECTION_RE = re.compile(
    r"^\s*(?:\d+\.?\s+|[IVXivx]+\.\s+)?(" +
    "|".join("(?P<s%d>%s)" % (i, p) for i, (_, p) in enumerate(_SECTIONS)) +
    r")\s*:?\s*$", re.IGNORECASE)


def build_fulltext(pages):
    """Concatenate pages -> (full_text, page_starts) where page_starts[i] is
    the char offset at which page i+1 begins (for char->page mapping)."""
    parts, starts, off = [], [], 0
    for p in pages:
        starts.append(off)
        t = p["text"] + "\n\n"
        parts.append(t); off += len(t)
    return "".join(parts), starts


def char_to_page(offset, page_starts):
    # page_starts is ascending; page number is 1-based index of the last start <= offset
    return max(1, bisect.bisect_right(page_starts, offset))


def detect_sections(full_text):
    """Return list of (label, start_char, end_char) covering full_text.
    Unlabeled spans before the first heading are 'front'."""
    marks = []  # (start_char, label)
    for m in re.finditer(r"^.{0,60}$", full_text, re.MULTILINE):
        line = m.group(0)
        sm = _SECTION_RE.match(line)
        if not sm:
            continue
        for i, (label, _) in enumerate(_SECTIONS):
            if sm.group("s%d" % i):
                marks.append((m.start(), label)); break
    if not marks or marks[0][0] > 0:
        marks = [(0, "front")] + marks
    spans = []
    for i, (start, label) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(full_text)
        spans.append((label, start, end))
    return spans


def _split_points(text, size, overlap):
    """Yield (start, end) windows over text, preferring to end at a sentence
    or paragraph boundary near the target size."""
    n = len(text); i = 0
    while i < n:
        end = min(i + size, n)
        if end < n:
            window = text[end - 200:end + 200]
            # nearest sentence boundary after the soft end
            m = None
            for mm in re.finditer(r"[.!?]\s|\n\n", window):
                m = mm
            if m:
                end = (end - 200) + m.end()
        end = min(max(end, i + 1), n)
        yield i, end
        if end >= n:
            break
        i = max(end - overlap, i + 1)


def chunk_document(pages):
    """Return list of chunk dicts (text + span metadata), references excluded."""
    full, page_starts = build_fulltext(pages)
    spans = detect_sections(full)
    chunks, ordn = [], 0
    for label, s, e in spans:
        if label == "references":
            continue                        # drop the reference list from retrieval
        section_text = full[s:e]
        if len(section_text.strip()) < 40:
            continue
        for cs, ce in _split_points(section_text, CHARS_PER_CHUNK, CHUNK_OVERLAP):
            text = section_text[cs:ce].strip()
            if len(text) < 40:
                continue
            abs_start = s + cs
            chunks.append({
                "ord": ordn, "section": label, "text": text,
                "char_start": abs_start, "char_end": s + ce,
                "n_chars": len(text),
                "page_start": char_to_page(abs_start, page_starts),
                "page_end": char_to_page(s + ce, page_starts),
                "text_sha256": store.sha256_text(text),
            })
            ordn += 1
    return chunks


# ---- embedding + LanceDB -----------------------------------------------------

_MODEL = None


def get_model():
    global _MODEL
    if _MODEL is None:
        from sentence_transformers import SentenceTransformer
        import torch
        dev = "mps" if torch.backends.mps.is_available() else (
            "cuda" if torch.cuda.is_available() else "cpu")
        sys.stderr.write("[embed] loading %s on %s\n" % (EMBED_MODEL, dev))
        _MODEL = SentenceTransformer(EMBED_MODEL, device=dev)
    return _MODEL


def emb_dim(model):
    # sentence-transformers renamed the accessor across versions
    for attr in ("get_embedding_dimension", "get_sentence_embedding_dimension"):
        if hasattr(model, attr):
            return getattr(model, attr)()
    return len(model.encode(["_"], convert_to_numpy=True)[0])


def embed_texts(texts, batch=48):
    model = get_model()
    return model.encode(texts, batch_size=batch, normalize_embeddings=True,
                        show_progress_bar=False, convert_to_numpy=True)


def open_table(dim):
    import lancedb
    db = lancedb.connect(os.path.join(store.rag_dir(), "index"))
    if hasattr(db, "list_tables"):
        _r = db.list_tables()
        tables = list(getattr(_r, "tables", _r))   # ListTablesResponse(.tables) or list
    else:
        tables = list(db.table_names())
    if TABLE in tables:
        return db, db.open_table(TABLE)
    # create with an explicit schema by seeding one dummy row then deleting it
    import pyarrow as pa
    schema = pa.schema([
        pa.field("chunk_id", pa.string()),
        pa.field("doc_id", pa.string()),
        pa.field("ord", pa.int32()),
        pa.field("section", pa.string()),
        pa.field("page_start", pa.int32()),
        pa.field("page_end", pa.int32()),
        pa.field("title", pa.string()),
        pa.field("authors", pa.string()),
        pa.field("year", pa.int32()),
        pa.field("journal", pa.string()),
        pa.field("doi", pa.string()),
        pa.field("text", pa.string()),
        pa.field("vector", pa.list_(pa.float32(), dim)),
    ])
    tbl = db.create_table(TABLE, schema=schema)
    return db, tbl


def run(con, limit=None, force=False, batch=48):
    todo = list(store.iter_documents(con, status="extracted", with_pdf=True))
    if force:
        todo = list(store.iter_documents(con, with_pdf=True))
    sys.stderr.write("[chunk_embed] %d documents to embed\n" % len(todo))
    if not todo:
        return {"docs": 0, "chunks": 0}
    dim = emb_dim(get_model())
    db, tbl = open_table(dim)
    total_chunks = docs_done = 0
    for i, d in enumerate(todo):
        if limit and i >= limit:
            break
        tp = d["text_path"]
        if not tp or not os.path.isfile(tp):
            store.set_status(con, d["doc_id"], "failed", "missing text cache")
            continue
        pages = json.load(open(tp)).get("pages", [])
        chunks = chunk_document(pages)
        if not chunks:
            store.set_status(con, d["doc_id"], "failed", "no chunks produced")
            continue
        vecs = embed_texts([c["text"] for c in chunks], batch=batch)
        # join authors with ';' — each author is "Last, First" (has an internal
        # comma), so ';' keeps author boundaries unambiguous for the formatter
        authors = "; ".join(json.loads(d["authors_json"] or "[]")[:8])
        rows = []
        for c, v in zip(chunks, vecs):
            rows.append({
                "chunk_id": "%s:%d" % (d["doc_id"], c["ord"]),
                "doc_id": d["doc_id"], "ord": c["ord"], "section": c["section"],
                "page_start": c["page_start"], "page_end": c["page_end"],
                "title": d["title"] or "", "authors": authors,
                "year": int(d["year"]) if d["year"] else 0,
                "journal": d["journal"] or "", "doi": d["doi"] or "",
                "text": c["text"], "vector": v.tolist()})
        tbl.delete("doc_id = '%s'" % d["doc_id"])     # idempotent re-embed
        tbl.add(rows)
        store.record_chunks(con, d["doc_id"], chunks)
        con.execute("UPDATE chunks SET embedded=1 WHERE doc_id=?", (d["doc_id"],))
        store.set_status(con, d["doc_id"], "embedded")
        total_chunks += len(chunks); docs_done += 1
        if (i + 1) % 25 == 0:
            sys.stderr.write("  ...%d/%d docs, %d chunks\n"
                             % (i + 1, len(todo), total_chunks))
    # build/refresh the full-text (BM25) index for hybrid search
    try:
        tbl.create_fts_index("text", replace=True)
    except Exception as e:
        sys.stderr.write("  [fts] index build skipped: %s\n" % e)
    store.write_manifest(embed_model=EMBED_MODEL, embed_dim=dim,
                         chunk_chars=CHARS_PER_CHUNK, chunk_overlap=CHUNK_OVERLAP)
    return {"docs": docs_done, "chunks": total_chunks}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["run", "model-info"])
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--batch", type=int, default=48)
    args = ap.parse_args()
    if args.command == "model-info":
        m = get_model()
        print(json.dumps({"model": EMBED_MODEL, "dim": emb_dim(m)}, indent=2))
        return
    con = store.connect()
    res = run(con, limit=args.limit, force=args.force, batch=args.batch)
    print(json.dumps({**res, **store.counts(con)}, indent=2))


if __name__ == "__main__":
    main()
