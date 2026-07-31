#!/usr/bin/env python3
"""
store.py — the scholar-rag corpus store (self-contained, stdlib-only).

Owns the on-disk layout of the user-scoped store and the `corpus.sqlite`
manifest that tracks documents and chunks. Every other engine module imports
this so the store schema lives in exactly one place.

Layout (SCHOLAR_RAG_DIR, default ~/.claude/scholar-rag/):
    corpus.sqlite         document + chunk manifest (this module)
    raw/pdfs/             optional local copies of source PDFs
    raw/text/<doc_id>.json  extracted page-mapped text (cache; resumable)
    raw/meta/<doc_id>.json  full bibliographic record
    index/                LanceDB vector table (chunk_embed.py)
    graph/                GraphRAG artifacts (graphrag.py, M4)
    logs/                 RAO traces + run logs
    manifest.json         embed model / dim / engine version / build stats
"""
import os, sys, json, time, hashlib, sqlite3

ENGINE_VERSION = "0.1.0"


def rag_dir():
    return os.environ.get("SCHOLAR_RAG_DIR") or os.path.join(
        os.path.expanduser("~"), ".claude", "scholar-rag")


def ensure_dirs():
    root = rag_dir()
    for sub in ("raw/pdfs", "raw/text", "raw/meta", "index", "graph", "logs"):
        os.makedirs(os.path.join(root, sub), exist_ok=True)
    return root


def db_path():
    return os.path.join(rag_dir(), "corpus.sqlite")


SCHEMA = """
CREATE TABLE IF NOT EXISTS documents (
    doc_id        TEXT PRIMARY KEY,
    zotero_key    TEXT,
    doi           TEXT,
    title         TEXT,
    authors_json  TEXT,
    year          INTEGER,
    journal       TEXT,
    item_type     TEXT,
    source        TEXT,               -- zotero | folder | oa-fetch
    pdf_path      TEXT,
    pdf_sha256    TEXT,
    extract_method TEXT,              -- pymupdf | pdftotext | vision-ocr | none
    ocr_used      INTEGER DEFAULT 0,
    n_pages       INTEGER,
    n_chars       INTEGER,
    text_path     TEXT,
    quality       REAL,               -- chars-per-page heuristic (0..1 normalized)
    status        TEXT DEFAULT 'new', -- new | extracted | chunked | embedded | failed | no_pdf
    error         TEXT,
    ingested_at   TEXT,
    updated_at    TEXT
);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_doi    ON documents(doi);

CREATE TABLE IF NOT EXISTS chunks (
    chunk_id     TEXT PRIMARY KEY,    -- <doc_id>:<ord>
    doc_id       TEXT NOT NULL,
    ord          INTEGER,
    section      TEXT,
    page_start   INTEGER,
    page_end     INTEGER,
    char_start   INTEGER,
    char_end     INTEGER,
    n_chars      INTEGER,
    text_sha256  TEXT,
    embedded     INTEGER DEFAULT 0,
    FOREIGN KEY (doc_id) REFERENCES documents(doc_id)
);
CREATE INDEX IF NOT EXISTS idx_chunks_doc ON chunks(doc_id);
CREATE INDEX IF NOT EXISTS idx_chunks_emb ON chunks(embedded);
"""


def connect():
    ensure_dirs()
    con = sqlite3.connect(db_path())
    con.row_factory = sqlite3.Row
    con.executescript(SCHEMA)
    con.commit()
    return con


# ---- hashing helpers ---------------------------------------------------------

def sha256_file(path, _buf=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(_buf), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_text(s):
    return hashlib.sha256((s or "").encode("utf-8", "ignore")).hexdigest()


def _now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


# ---- document CRUD -----------------------------------------------------------

def upsert_document(con, rec):
    """Insert/refresh a document row from a zotero_reader record (dict).

    Preserves extraction state on re-ingest: only bibliographic fields and the
    chosen pdf_path are updated; status/extract_* are left intact unless new.
    """
    pdf_path = ""
    for p in rec.get("pdf_paths", []):
        if p.get("exists"):
            pdf_path = p["path"]; break
    if not pdf_path and rec.get("pdf_paths"):
        pdf_path = rec["pdf_paths"][0].get("path", "")
    now = _now()
    exists = con.execute(
        "SELECT doc_id, pdf_path, source FROM documents WHERE doc_id=?",
        (rec["doc_id"],)).fetchone()
    if exists:
        # never clobber a fetched/existing PDF with an empty re-ingest path
        # (e.g. a Zotero item whose attachment file still isn't on disk)
        if not pdf_path or (exists["source"] == "oa-fetch" and exists["pdf_path"]):
            pdf_path = exists["pdf_path"] or pdf_path
        con.execute("""UPDATE documents SET zotero_key=?, doi=?, title=?,
                authors_json=?, year=?, journal=?, item_type=?, pdf_path=?,
                updated_at=? WHERE doc_id=?""",
                    (rec.get("zotero_key"), rec.get("doi"), rec.get("title"),
                     json.dumps(rec.get("authors", []), ensure_ascii=False),
                     rec.get("year"), rec.get("journal"), rec.get("item_type"),
                     pdf_path, now, rec["doc_id"]))
    else:
        status = "new" if pdf_path else "no_pdf"
        con.execute("""INSERT INTO documents
                (doc_id, zotero_key, doi, title, authors_json, year, journal,
                 item_type, source, pdf_path, status, ingested_at, updated_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (rec["doc_id"], rec.get("zotero_key"), rec.get("doi"),
                     rec.get("title"),
                     json.dumps(rec.get("authors", []), ensure_ascii=False),
                     rec.get("year"), rec.get("journal"), rec.get("item_type"),
                     rec.get("source", "zotero"), pdf_path, status, now, now))
        # cache the full bibliographic record for downstream (citations, graph)
        try:
            with open(os.path.join(rag_dir(), "raw", "meta",
                                   rec["doc_id"] + ".json"), "w") as f:
                json.dump(rec, f, ensure_ascii=False, indent=1)
        except Exception:
            pass
    return rec["doc_id"]


def set_extract_result(con, doc_id, *, method, n_pages, n_chars, quality,
                       text_path, pdf_sha256=None, ocr_used=0,
                       status="extracted", error=None):
    con.execute("""UPDATE documents SET extract_method=?, n_pages=?, n_chars=?,
            quality=?, text_path=?, pdf_sha256=COALESCE(?, pdf_sha256),
            ocr_used=?, status=?, error=?, updated_at=? WHERE doc_id=?""",
                (method, n_pages, n_chars, quality, text_path, pdf_sha256,
                 ocr_used, status, error, _now(), doc_id))
    con.commit()


def set_status(con, doc_id, status, error=None):
    con.execute("UPDATE documents SET status=?, error=?, updated_at=? WHERE doc_id=?",
                (status, error, _now(), doc_id))
    con.commit()


def record_chunks(con, doc_id, chunks):
    """Replace all chunk rows for a doc. `chunks` = list of dicts."""
    con.execute("DELETE FROM chunks WHERE doc_id=?", (doc_id,))
    con.executemany("""INSERT INTO chunks
            (chunk_id, doc_id, ord, section, page_start, page_end,
             char_start, char_end, n_chars, text_sha256, embedded)
            VALUES (?,?,?,?,?,?,?,?,?,?,0)""",
                    [("%s:%d" % (doc_id, c["ord"]), doc_id, c["ord"],
                      c.get("section"), c.get("page_start"), c.get("page_end"),
                      c.get("char_start"), c.get("char_end"), c.get("n_chars"),
                      c.get("text_sha256")) for c in chunks])
    con.commit()


def iter_documents(con, status=None, with_pdf=True):
    q = "SELECT * FROM documents"
    conds, params = [], []
    if status:
        conds.append("status=?"); params.append(status)
    if with_pdf:
        conds.append("pdf_path!=''")
    if conds:
        q += " WHERE " + " AND ".join(conds)
    q += " ORDER BY doc_id"
    for row in con.execute(q, params):
        yield dict(row)


def counts(con):
    out = {"documents": con.execute("SELECT COUNT(*) FROM documents").fetchone()[0]}
    for st in ("new", "extracted", "chunked", "embedded", "failed", "no_pdf"):
        out[st] = con.execute("SELECT COUNT(*) FROM documents WHERE status=?",
                              (st,)).fetchone()[0]
    out["chunks"] = con.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    out["chunks_embedded"] = con.execute(
        "SELECT COUNT(*) FROM chunks WHERE embedded=1").fetchone()[0]
    return out


def read_manifest():
    p = os.path.join(rag_dir(), "manifest.json")
    if os.path.isfile(p):
        try:
            return json.load(open(p))
        except Exception:
            return {}
    return {}


def write_manifest(**kw):
    p = os.path.join(rag_dir(), "manifest.json")
    man = read_manifest()
    man.update(kw)
    man["engine_version"] = ENGINE_VERSION
    man["updated_at"] = _now()
    json.dump(man, open(p, "w"), indent=2)
    return man


if __name__ == "__main__":
    con = connect()
    print(json.dumps(counts(con), indent=2))
    print("store:", rag_dir())
