#!/usr/bin/env python3
"""
ingest.py — populate the corpus manifest from a source (Zotero or a folder).

This is stage 1 of the pipeline (source -> corpus.sqlite manifest). It does NOT
extract or embed; run extract.py then chunk_embed.py next (or use run-ingest.sh
to chain all three). Stdlib-only, so it runs before the venv exists.

Usage:
  python3 ingest.py zotero [--limit N] [--types t1,t2] [--with-pdf-only]
  python3 ingest.py folder <dir> [--limit N]
  python3 ingest.py status
"""
import os, sys, json, glob, argparse, hashlib
import store
import zotero_reader as zr


def ingest_zotero(limit=None, types=None, with_pdf_only=False):
    zdir = zr.detect_zotero_dir()
    if not zdir:
        raise SystemExit("ERROR: no Zotero library found. Set SCHOLAR_ZOTERO_DIR.")
    con_z, note = zr.open_zotero_db(zdir)
    sys.stderr.write("[ingest] zotero: %s (%s)\n" % (zdir, note))
    con = store.connect()
    n = with_pdf = 0
    for rec in zr.fetch_items(con_z, zdir, types=types,
                              with_pdf_only=with_pdf_only, limit=limit):
        if not rec.get("doc_id"):
            continue
        rec["source"] = "zotero"
        store.upsert_document(con, rec)
        n += 1
        if rec.get("n_pdf"):
            with_pdf += 1
    con.commit()
    store.write_manifest(source="zotero", zotero_dir=zdir)
    return {"ingested": n, "with_pdf": with_pdf, **store.counts(con)}


def ingest_folder(folder, limit=None):
    con = store.connect()
    pdfs = sorted(glob.glob(os.path.join(folder, "**", "*.pdf"), recursive=True))
    n = 0
    for pdf in pdfs:
        if limit and n >= limit:
            break
        stem = os.path.splitext(os.path.basename(pdf))[0]
        doc_id = hashlib.sha256(pdf.encode()).hexdigest()[:16]
        rec = {"doc_id": doc_id, "zotero_key": "", "doi": "", "title": stem,
               "authors": [], "year": None, "journal": "", "item_type": "pdf",
               "source": "folder",
               "pdf_paths": [{"path": pdf, "exists": True, "link_mode": 2, "key": ""}]}
        store.upsert_document(con, rec)
        n += 1
    con.commit()
    store.write_manifest(source="folder", folder=folder)
    return {"ingested": n, **store.counts(con)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["zotero", "folder", "status"])
    ap.add_argument("folder", nargs="?")
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--types", default=None)
    ap.add_argument("--with-pdf-only", action="store_true")
    args = ap.parse_args()
    if args.command == "status":
        print(json.dumps(store.counts(store.connect()), indent=2)); return
    if args.command == "zotero":
        res = ingest_zotero(limit=args.limit,
                            types=args.types.split(",") if args.types else None,
                            with_pdf_only=args.with_pdf_only)
    else:
        if not args.folder:
            raise SystemExit("folder mode needs a directory argument")
        res = ingest_folder(args.folder, limit=args.limit)
    print(json.dumps(res, indent=2))


if __name__ == "__main__":
    main()
