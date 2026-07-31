#!/usr/bin/env python3
"""
graphrag.py — a local, seedable GraphRAG layer over the scholar-rag corpus.

Pipeline (all local via ollama; $0, private):
  seed       import scholar-knowledge's existing entities/edges (872 papers,
             160 concepts, 861 edges) so extraction doesn't start from zero
  extract    gpt-oss:20b reads each paper's key sections -> entities + relations
             (1-few calls/paper, JSON-structured, resumable per doc)
  build      resolve/dedup entities -> igraph -> Leiden communities
  summarize  gpt-oss:120b writes a summary per community (global-search corpus)
  run        seed -> extract -> build -> summarize

Query:
  local <q>      entity-grounded: vector passages + the entities/neighbors of
                 the hit papers
  global <q>     map-reduce over community summaries -> synthesized answer
  neighbors <id> papers sharing entities / community / citations with <id>

Graph store (NDJSON + JSON under $SCHOLAR_RAG_DIR/graph/):
  entities.ndjson   {ent_id, name, type, aliases, doc_ids[], count, source}
  relations.ndjson  {src, rel, dst, doc_ids[], weight}
  communities.json  {ent_id: community_id}
  community_summaries.json  {community_id: {title, summary, entities[], size}}
"""
import os, re, sys, json, time, argparse, hashlib, glob
import store

OLLAMA = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
# Model selection. Prefer a fast MoE/instruct model. gpt-oss:20b is the ideal
# extractor (fast MoE) and is preferred once its blob is current — a stale
# (long-cached) gpt-oss blob fails to load with an MoE "size overflow"; a fresh
# `ollama pull gpt-oss:20b` fixes it. It requires /api/chat (harmony template),
# which ollama_json/ollama_text use. gpt-oss:120b is only auto-picked if present
# AND freshly pulled. Fallbacks: qwen instruct, then a reasoning model.
_EXTRACT_PREF = ["gpt-oss:20b", "qwen2.5:7b-instruct", "qwen2.5:14b-instruct",
                 "qwen2.5:7b", "llama3.1:8b", "mistral-nemo", "deepseek-r1:32b"]
_SUMMARY_PREF = ["gpt-oss:20b", "qwen2.5:14b-instruct", "qwen2.5:7b-instruct",
                 "deepseek-r1:32b"]


def _available_models():
    try:
        import requests
        r = requests.get(OLLAMA + "/api/tags", timeout=5)
        return [m["name"] for m in r.json().get("models", [])] if r.ok else []
    except Exception:
        return []


def _pick_model(preferred, env_key):
    v = os.environ.get(env_key)
    if v:
        return v
    avail = _available_models()
    for p in preferred:
        for a in avail:
            if a == p or a.split(":")[0] == p.split(":")[0]:
                return a
    return avail[0] if avail else preferred[-1]


EXTRACT_MODEL = _pick_model(_EXTRACT_PREF, "RAG_GRAPH_MODEL")
SUMMARY_MODEL = _pick_model(_SUMMARY_PREF, "RAG_SUMMARY_MODEL")
MAX_EXTRACT_CHARS = int(os.environ.get("RAG_GRAPH_MAX_CHARS", "12000"))  # ~3k tokens
GRAPH_NUM_PREDICT = int(os.environ.get("RAG_GRAPH_NUM_PREDICT", "1200"))  # cap output
ENT_TYPES = ["theory", "concept", "method", "dataset", "construct",
             "finding", "population", "author"]


def gdir():
    d = os.path.join(store.rag_dir(), "graph")
    os.makedirs(d, exist_ok=True)
    return d


def ent_id(name, typ):
    key = "%s|%s" % (typ, re.sub(r"\s+", " ", (name or "").strip().lower()))
    return hashlib.sha256(key.encode("utf-8", "ignore")).hexdigest()[:16]


# ---- ollama ------------------------------------------------------------------

# Reasoning effort for gpt-oss/other thinking models. "low" is ~4x faster than
# default with no measured loss on this extraction task. Disabled automatically
# for models that don't accept `think` (e.g. qwen2.5-instruct).
THINK = os.environ.get("RAG_GRAPH_THINK", "low")
_think_ok = True


def _chat(model, prompt, temperature, want_json, timeout):
    global _think_ok
    import requests
    body = {"model": model, "messages": [{"role": "user", "content": prompt}],
            "stream": False, "options": {"temperature": temperature}}
    if want_json:
        body["format"] = "json"
        body["options"]["num_predict"] = GRAPH_NUM_PREDICT
    if THINK and _think_ok:
        body["think"] = THINK
    r = requests.post(OLLAMA + "/api/chat", json=body, timeout=timeout)
    if not r.ok:
        # a non-thinking model rejects `think` -> disable for the session, signal retry
        if _think_ok and "think" in (r.text or "").lower():
            _think_ok = False
            return None, True
        return "", False
    return r.json().get("message", {}).get("content", ""), False


def ollama_json(prompt, model=EXTRACT_MODEL, retries=2, temperature=0):
    # /api/chat applies the model's chat template (required for gpt-oss's harmony
    # format; correct for all instruct/chat models). format=json constrains output.
    for attempt in range(retries + 1):
        try:
            txt, retry = _chat(model, prompt, temperature, True, 600)
            if retry:
                continue
            return json.loads(txt) if (txt and txt.strip()) else {}
        except Exception as e:
            if attempt == retries:
                sys.stderr.write("  [ollama] %s\n" % e)
                return {}
            time.sleep(1.5)
    return {}


def ollama_text(prompt, model=SUMMARY_MODEL, temperature=0.2):
    try:
        for _ in range(2):
            txt, retry = _chat(model, prompt, temperature, False, 900)
            if retry:
                continue
            return txt or ""
    except Exception as e:
        sys.stderr.write("  [ollama] %s\n" % e)
    return ""


# ---- graph store I/O ---------------------------------------------------------

def _load_ndjson(path):
    out = []
    if os.path.isfile(path):
        for line in open(path):
            line = line.strip()
            if line:
                try: out.append(json.loads(line))
                except Exception: pass
    return out


def load_entities():
    return {e["ent_id"]: e for e in _load_ndjson(os.path.join(gdir(), "entities.ndjson"))}


def load_relations():
    return _load_ndjson(os.path.join(gdir(), "relations.ndjson"))


def save_entities(ents):
    with open(os.path.join(gdir(), "entities.ndjson"), "w") as f:
        for e in ents.values():
            f.write(json.dumps(e, ensure_ascii=False) + "\n")


def save_relations(rels):
    with open(os.path.join(gdir(), "relations.ndjson"), "w") as f:
        for r in rels:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


def _merge_entity(ents, name, typ, doc_id, source="extract"):
    if not name or not name.strip():
        return None
    eid = ent_id(name, typ)
    e = ents.get(eid)
    if not e:
        e = {"ent_id": eid, "name": name.strip(), "type": typ, "aliases": [],
             "doc_ids": [], "count": 0, "source": source}
        ents[eid] = e
    if doc_id and doc_id not in e["doc_ids"]:
        e["doc_ids"].append(doc_id)
    e["count"] += 1
    return eid


# ---- seed from scholar-knowledge --------------------------------------------

def _kg_dir():
    return os.environ.get("SCHOLAR_KNOWLEDGE_DIR") or os.path.join(
        os.path.expanduser("~"), ".claude", "scholar-knowledge")


def _norm_title(t):
    return re.sub(r"[^a-z0-9 ]", " ", (t or "").lower())


def _kg_paperid_map(con, kg):
    """Map scholar-knowledge paper ids -> our doc_ids via DOI, then title."""
    doi2doc, title2doc = {}, {}
    for row in con.execute("SELECT doc_id, doi, title FROM documents"):
        if row["doi"]:
            doi2doc[row["doi"].strip().lower()] = row["doc_id"]
        if row["title"]:
            title2doc[re.sub(r"\s+", " ", _norm_title(row["title"])).strip()] = row["doc_id"]
    kgid2doc = {}
    for p in _load_ndjson(os.path.join(kg, "papers.ndjson")):
        did = None
        if p.get("doi"):
            did = doi2doc.get(p["doi"].strip().lower())
        if not did and p.get("title"):
            did = title2doc.get(re.sub(r"\s+", " ", _norm_title(p["title"])).strip())
        if did:
            kgid2doc[p["id"]] = did
    return kgid2doc


def seed():
    """Import scholar-knowledge concepts (as entities) and paper->paper edges
    (mapped to our doc_ids, as citation-style doc edges for neighbors())."""
    kg = _kg_dir()
    ents = load_entities()
    n_c = 0
    concepts = _load_ndjson(os.path.join(kg, "concepts.ndjson"))
    for c in concepts:
        typ = c.get("category", "concept")
        if typ not in ENT_TYPES:
            typ = "concept"
        eid = _merge_entity(ents, c.get("name", ""), typ, None, source="kg")
        if eid:
            e = ents[eid]
            for a in c.get("aliases", []):
                if a and a not in e["aliases"]:
                    e["aliases"].append(a)
            n_c += 1
    save_entities(ents)
    # paper->paper edges mapped to our doc_ids -> doc_edges.ndjson
    con = store.connect()
    kgid2doc = _kg_paperid_map(con, kg)
    doc_edges, n_e, n_map = [], 0, 0
    for ed in _load_ndjson(os.path.join(kg, "edges.ndjson")):
        s, d = ed.get("source_id"), ed.get("target_id")
        rel = ed.get("relationship") or "related"
        if not s or not d:
            continue
        n_e += 1
        sd, dd = kgid2doc.get(s), kgid2doc.get(d)
        if sd and dd and sd != dd:
            doc_edges.append({"src_doc": sd, "dst_doc": dd, "rel": rel,
                              "note": ed.get("note", ""), "source": "kg"})
            n_map += 1
    with open(os.path.join(gdir(), "doc_edges.ndjson"), "w") as f:
        for e in doc_edges:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")
    return {"seeded_concepts": n_c, "kg_edges_seen": n_e,
            "doc_edges_mapped": n_map, "kg_papers_matched": len(kgid2doc),
            "entities_total": len(ents)}


# ---- extraction --------------------------------------------------------------

_EXTRACT_PROMPT = """You are building a knowledge graph of social-science research.
From the paper excerpt below, extract the key scholarly entities and the
relationships between them. Return STRICT JSON with this shape:
{"entities":[{"name":"...","type":"one of %s"}],
 "relations":[{"subject":"...","relation":"short verb phrase","object":"..."}]}
Rules: entity names are canonical noun phrases (e.g. "spatial assimilation theory",
"difference-in-differences", "Common Core of Data"); 5-20 entities; only relations
whose subject and object both appear in entities; no prose outside the JSON.

PAPER: %s (%s)
EXCERPT:
%s
""" % (ENT_TYPES, "%s", "%s", "%s")


def _extraction_text(doc):
    """Bounded, section-labeled text for one document's extraction call."""
    tp = doc.get("text_path")
    if not tp or not os.path.isfile(tp):
        return ""
    pages = json.load(open(tp)).get("pages", [])
    full = "\n".join(p["text"] for p in pages)
    return full[:MAX_EXTRACT_CHARS]


def _extracted_docs_path():
    return os.path.join(gdir(), "extracted_docs.json")


def extract(limit=None, model=EXTRACT_MODEL, force=False):
    con = store.connect()
    done = set()
    if not force and os.path.isfile(_extracted_docs_path()):
        done = set(json.load(open(_extracted_docs_path())))
    ents = load_entities()
    rels = load_relations()
    docs = [d for d in store.iter_documents(con, with_pdf=True)
            if d["status"] in ("embedded", "extracted", "chunked")
            and (force or d["doc_id"] not in done)]
    sys.stderr.write("[graph.extract] %d docs to extract (model=%s)\n"
                     % (len(docs), model))
    n = 0
    for d in docs:
        if limit and n >= limit:
            break
        text = _extraction_text(d)
        if len(text) < 200:
            done.add(d["doc_id"]); continue
        title = (d["title"] or "")[:200]
        year = d["year"] or ""
        res = ollama_json(_EXTRACT_PROMPT % (title, year, text), model=model)
        if not isinstance(res, dict):        # LLM may return a bare list/str
            res = {}
        name2eid = {}
        for ent in (res.get("entities") or [])[:40]:
            if not isinstance(ent, dict):    # tolerate malformed items (e.g. bare strings)
                continue
            nm, ty = ent.get("name"), (ent.get("type") or "concept")
            if ty not in ENT_TYPES:
                ty = "concept"
            eid = _merge_entity(ents, nm, ty, d["doc_id"])
            if eid:
                name2eid[(nm or "").strip().lower()] = eid
        for rel in (res.get("relations") or [])[:60]:
            if not isinstance(rel, dict):    # some models emit relations as strings
                continue
            s = (rel.get("subject") or "").strip().lower()
            o = (rel.get("object") or "").strip().lower()
            se, oe = name2eid.get(s), name2eid.get(o)
            if se and oe and se != oe:
                rels.append({"src": se, "rel": (rel.get("relation") or "related")[:40],
                             "dst": oe, "doc_ids": [d["doc_id"]], "weight": 1,
                             "source": "extract"})
        done.add(d["doc_id"]); n += 1
        if n % 25 == 0:
            save_entities(ents); save_relations(rels)
            json.dump(sorted(done), open(_extracted_docs_path(), "w"))
            sys.stderr.write("  ...%d/%d docs, %d entities\n"
                             % (n, len(docs), len(ents)))
    save_entities(ents); save_relations(rels)
    json.dump(sorted(done), open(_extracted_docs_path(), "w"))
    return {"extracted_docs": n, "entities_total": len(ents),
            "relations_total": len(rels)}


# ---- build communities -------------------------------------------------------

def build():
    ents = load_entities()
    rels = load_relations()
    if not ents:
        return {"error": "no entities; run seed/extract first"}
    import igraph as ig
    import leidenalg as la
    ids = [e for e in ents if any(e == r["src"] or e == r["dst"] for r in rels)]
    idx = {e: i for i, e in enumerate(ids)}
    edges, weights = {}, {}
    for r in rels:
        if r["src"] in idx and r["dst"] in idx and r["src"] != r["dst"]:
            key = tuple(sorted((idx[r["src"]], idx[r["dst"]])))
            edges[key] = edges.get(key, 0) + r.get("weight", 1)
    if not edges:
        return {"error": "no usable edges among entities"}
    g = ig.Graph(n=len(ids), edges=list(edges.keys()))
    g.es["weight"] = [edges[k] for k in edges.keys()]
    part = la.find_partition(g, la.RBConfigurationVertexPartition,
                             weights="weight", seed=42)
    comm = {ids[v]: part.membership[v] for v in range(len(ids))}
    json.dump(comm, open(os.path.join(gdir(), "communities.json"), "w"))
    sizes = {}
    for c in comm.values():
        sizes[c] = sizes.get(c, 0) + 1
    return {"entities_in_graph": len(ids), "edges": len(edges),
            "communities": len(sizes),
            "largest": max(sizes.values()) if sizes else 0}


# ---- community summaries -----------------------------------------------------

_SUMMARY_PROMPT = """You are summarizing a thematic cluster of a social-science
literature knowledge graph. Given the entities below (concepts, theories,
methods, findings that co-occur across papers), write: (1) a 4-8 word TITLE for
the theme, then (2) a 3-5 sentence SUMMARY of what this cluster is about and the
kind of claims it supports. Return STRICT JSON: {"title":"...","summary":"..."}.

ENTITIES:
%s
"""


def summarize(model=SUMMARY_MODEL, max_communities=None, min_size=3):
    comm_path = os.path.join(gdir(), "communities.json")
    if not os.path.isfile(comm_path):
        return {"error": "run build first"}
    comm = json.load(open(comm_path))
    ents = load_entities()
    groups = {}
    for eid, c in comm.items():
        groups.setdefault(c, []).append(eid)
    out = {}
    items = sorted(groups.items(), key=lambda kv: -len(kv[1]))
    n = 0
    for c, eids in items:
        if len(eids) < min_size:
            continue
        if max_communities and n >= max_communities:
            break
        names = [ents[e]["name"] for e in eids if e in ents][:40]
        res = ollama_json(_SUMMARY_PROMPT % "\n".join("- " + x for x in names),
                          model=model)
        out[str(c)] = {"title": res.get("title", "cluster %s" % c),
                       "summary": res.get("summary", ""),
                       "entities": names[:25], "size": len(eids)}
        n += 1
        if n % 10 == 0:
            json.dump(out, open(os.path.join(gdir(), "community_summaries.json"), "w"),
                      ensure_ascii=False, indent=1)
    json.dump(out, open(os.path.join(gdir(), "community_summaries.json"), "w"),
              ensure_ascii=False, indent=1)
    return {"communities_summarized": len(out)}


# ---- query: neighbors / local / global --------------------------------------

def neighbors(doc_id, k=8):
    """Papers related to doc_id: shared graph entities + seeded citation edges."""
    ents = load_entities()
    score, why = {}, {}
    for e in ents.values():
        if doc_id in e.get("doc_ids", []):
            for other in e.get("doc_ids", []):
                if other != doc_id:
                    score[other] = score.get(other, 0) + 1
                    why.setdefault(other, set()).add("shared:" + e["name"])
    # citation edges from the scholar-knowledge seed (both directions)
    for ed in _load_ndjson(os.path.join(gdir(), "doc_edges.ndjson")):
        pair = None
        if ed.get("src_doc") == doc_id:
            pair = ed.get("dst_doc")
        elif ed.get("dst_doc") == doc_id:
            pair = ed.get("src_doc")
        if pair:
            score[pair] = score.get(pair, 0) + 2          # citations weigh more
            why.setdefault(pair, set()).add("cite:" + (ed.get("rel") or "related"))
    con = store.connect()
    out = []
    for other, sc in sorted(score.items(), key=lambda kv: -kv[1])[:k]:
        row = con.execute("SELECT title, year, doi FROM documents WHERE doc_id=?",
                          (other,)).fetchone()
        if row:
            out.append({"doc_id": other, "title": row["title"],
                        "year": row["year"], "doi": row["doi"],
                        "score": sc, "why": sorted(why.get(other, []))[:5]})
    return out


def local(q, k=8):
    """Entity-grounded local search: vector passages + their graph context."""
    import query as Q
    hits = Q.search(q, k=k, hybrid=True)
    ents = load_entities()
    doc_ids = {h["doc_id"] for h in hits}
    ctx_ents = sorted({e["name"] for e in ents.values()
                       if doc_ids & set(e.get("doc_ids", []))})
    return {"passages": hits, "entities_in_context": ctx_ents[:40]}


def global_search(q, model=SUMMARY_MODEL, top=8):
    """Map-reduce over community summaries for a corpus-level answer."""
    sp = os.path.join(gdir(), "community_summaries.json")
    if not os.path.isfile(sp):
        return {"error": "no community summaries; run build + summarize first"}
    summaries = json.load(open(sp))
    # rank communities by lexical overlap with the query (cheap, offline)
    qter = set(re.findall(r"\w+", q.lower()))
    scored = []
    for cid, s in summaries.items():
        blob = (s.get("title", "") + " " + s.get("summary", "") + " " +
                " ".join(s.get("entities", []))).lower()
        overlap = sum(1 for w in qter if w in blob)
        scored.append((overlap, cid, s))
    scored.sort(key=lambda t: -t[0])
    chosen = [s for ov, cid, s in scored[:top] if ov > 0] or [s for _, _, s in scored[:3]]
    context = "\n\n".join("THEME: %s\n%s" % (s["title"], s["summary"]) for s in chosen)
    ans = ollama_text(
        "Using ONLY the thematic summaries of a literature knowledge graph "
        "below, answer the question. Be specific about which themes support "
        "which points.\n\nQUESTION: %s\n\nTHEMES:\n%s\n\nANSWER:" % (q, context),
        model=model)
    return {"answer": ans, "themes_used": [s["title"] for s in chosen]}


def status():
    ents = load_entities()
    rels = load_relations()
    comm = {}
    cp = os.path.join(gdir(), "communities.json")
    if os.path.isfile(cp):
        comm = json.load(open(cp))
    sp = os.path.join(gdir(), "community_summaries.json")
    n_sum = len(json.load(open(sp))) if os.path.isfile(sp) else 0
    ncomm = len(set(comm.values())) if comm else 0
    return {"entities": len(ents), "relations": len(rels),
            "communities": ncomm, "community_summaries": n_sum}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["seed", "extract", "build", "summarize",
                                        "run", "neighbors", "local", "global",
                                        "status"])
    ap.add_argument("arg", nargs="?")
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--model", default=None)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("-k", type=int, default=8)
    args = ap.parse_args()

    if args.command == "seed":
        print(json.dumps(seed(), indent=2))
    elif args.command == "extract":
        print(json.dumps(extract(limit=args.limit,
                                 model=args.model or EXTRACT_MODEL,
                                 force=args.force), indent=2))
    elif args.command == "build":
        print(json.dumps(build(), indent=2))
    elif args.command == "summarize":
        print(json.dumps(summarize(model=args.model or SUMMARY_MODEL,
                                   max_communities=args.limit), indent=2))
    elif args.command == "run":
        print(json.dumps({"seed": seed(),
                          "extract": extract(limit=args.limit,
                                             model=args.model or EXTRACT_MODEL),
                          "build": build(),
                          "summarize": summarize(model=SUMMARY_MODEL,
                                                 max_communities=args.limit)},
                         indent=2))
    elif args.command == "neighbors":
        print(json.dumps(neighbors(args.arg, k=args.k), indent=2))
    elif args.command == "local":
        print(json.dumps(local(args.arg, k=args.k), ensure_ascii=False, indent=2))
    elif args.command == "global":
        print(json.dumps(global_search(args.arg, model=args.model or SUMMARY_MODEL),
                         ensure_ascii=False, indent=2))
    else:
        print(json.dumps(status(), indent=2))


if __name__ == "__main__":
    main()
