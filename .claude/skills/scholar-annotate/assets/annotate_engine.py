#!/usr/bin/env python3
"""
scholar-annotate — execution engine.  Verbs: sample | annotate | validate | distill.
Self-contained; only stdlib + pandas + scikit-learn (+ providers.py, codebook_schema.py here).
LLM calls go through providers.py (OpenAI/Anthropic live+Batch, or a local OpenAI-compatible
server). Aggregate-only stdout (LOCAL_MODE safe). See references/scale-engine.md.

Corpus spec (JSON) used by `sample` and `distill`:
  {"category_glob":"…/by_category/*.csv",        # 0+ files, filename stem = stratum
   "big_file":"…/all.csv", "big_only":["catA",…],# optional; big_file rows kept only for these strata
   "strata_col":"query_category"}                 # column holding the stratum in big_file
Run manifest (JSON) used by `annotate`:
  {"input":"sample.csv","id_col":"video_id","text_cols":["title","description","tags"],
   "codebook":"codebook.md","out_dir":"annotations",
   "provider":{"strategy":"local|async|batch","provider":"local|openai|anthropic",
               "model":"glm-5.2","api_base":"http://127.0.0.1:8080/v1","key_env":"GLM_API_KEY"},
   "fewshot":{"gold":"devset_gold.csv","k":2}, "workers":16, "shards":64}
"""
import os, sys, csv, json, glob, argparse, hashlib, random, threading, time
from concurrent.futures import ThreadPoolExecutor, as_completed
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import providers, codebook_schema

def sh(s): return int(hashlib.md5(str(s).encode("utf-8","ignore")).hexdigest()[:8],16)
def S(x): return x if isinstance(x,str) else ""
def robust_chunks(path, cols):
    import pandas as pd
    for eng in ("c","python"):
        try:
            for ch in pd.read_csv(path,usecols=lambda c:c in cols,chunksize=200_000,dtype=str,
                                  on_bad_lines="skip",engine=eng): yield ch
            return
        except Exception as e: print(f"  [{os.path.basename(path)}] engine={eng} failed ({str(e)[:60]})",flush=True)
    print(f"  [{os.path.basename(path)}] UNREADABLE",flush=True)

def iter_corpus(spec, cols, shard=0, nshards=1):
    """Yield dict rows (deduped by id within-run) from a corpus spec, optionally sharded."""
    import pandas as pd
    seen=set(); idc=cols[0]
    def keep(v): return v and v!=idc and (nshards<=1 or sh(v)%nshards==shard) and v not in seen
    for f in sorted(glob.glob(spec.get("category_glob",""))) if spec.get("category_glob") else []:
        cat=os.path.basename(f)[:-4]
        for ch in robust_chunks(f, cols):
            for r in ch.itertuples(index=False):
                d=r._asdict() if hasattr(r,"_asdict") else dict(zip(cols,r))
                v=d.get(idc)
                if not keep(v): continue
                seen.add(v); d[spec.get("strata_col","stratum")]=cat; yield d
    if spec.get("big_file"):
        bc=list(dict.fromkeys(cols+[spec.get("strata_col","query_category")]))
        for ch in robust_chunks(spec["big_file"], bc):
            if spec.get("big_only"): ch=ch[ch[spec["strata_col"]].isin(spec["big_only"])]
            for r in ch.itertuples(index=False):
                d=dict(zip(ch.columns, r)); v=d.get(idc)
                if not keep(v): continue
                seen.add(v); yield d

# ----------------------------- SAMPLE -----------------------------
def cmd_sample(a):
    import pandas as pd, collections
    random.seed(a.seed)
    spec=json.load(open(a.corpus)); cols=a.text_cols.split(","); idc=a.id_col
    strata=a.strata or spec.get("strata_col","stratum")
    lex=json.load(open(a.oversample)) if a.oversample else None   # {"target_class":[markers...], ...}
    def prior(txt):
        if not lex: return "?"
        t=txt.lower(); best=("?",0)
        for cls,ms in lex.items():
            h=sum(1 for m in ms if m in t)
            if h>best[1]: best=(cls,h)
        return best[0] if best[1]>0 else "?"
    pool=collections.defaultdict(list); cnt=collections.defaultdict(lambda:[0]); cap=a.pool
    read_cols=list(dict.fromkeys([idc]+cols))
    for d in iter_corpus(spec, read_cols):
        st=d.get(strata,"NA"); cnt[st][0]+=1
        item={k:S(d.get(k)) for k in read_cols}; item[strata]=st
        item["_prior"]=prior(" ".join(item[k] for k in cols))
        L=pool[st]
        if len(L)<cap: L.append(item)
        else:
            j=random.randint(0,cnt[st][0]-1)
            if j<cap: L[j]=item
    rows=[x for v in pool.values() for x in v]
    df=pd.DataFrame(rows).drop_duplicates(idc)
    keys=sorted(df[strata].unique()); per=max(1,a.n//max(1,len(keys)))
    sel=[]
    if lex and a.target:  # over-sample target class first
        tgt=df[df._prior==a.target]; floor=min(len(tgt), a.n//2)
        sel.append(tgt.sample(min(floor,len(tgt)),random_state=1)); df=df[~df[idc].isin(sel[0][idc])]
    for k in keys:
        sub=df[df[strata]==k]; sel.append(sub.sample(min(per,len(sub)),random_state=2))
    out=pd.concat(sel).drop_duplicates(idc).sample(frac=1,random_state=3).head(a.n)
    if "description" in out.columns: out["description"]=out["description"].fillna("").str.slice(0,600)
    out.to_csv(a.out,index=False)
    print(f"SAMPLE n={len(out)} -> {a.out}")
    print("prior distribution:"); print(out["_prior"].value_counts().to_string() if "_prior" in out else "(no lexicon)")
    print("strata:"); print(out[strata].value_counts().to_string())

# ----------------------------- ANNOTATE -----------------------------
def cmd_annotate(a):
    import pandas as pd
    m=json.load(open(a.manifest)); pv=m["provider"]; cb=codebook_schema.load(m["codebook"])
    idc=m.get("id_col","id"); tcols=m["text_cols"]; strata=m.get("strata_col","query_category")
    out_dir=m["out_dir"]; os.makedirs(out_dir,exist_ok=True)
    suf=f"_t{a.shard}of{a.nshards}" if a.nshards>1 else ""
    ckpt=os.path.join(out_dir,f"processed{suf}.txt"); failed=os.path.join(out_dir,f"failed{suf}.txt")
    ledger=os.path.join(out_dir,"cost_ledger.json")
    fewshot=providers.build_fewshot(m.get("fewshot"), cb, tcols)
    df=pd.read_csv(m["input"],dtype=str).fillna("")
    if a.limit: df=df.head(a.limit)
    if a.nshards>1: df=df[df[idc].map(lambda v: sh(v)%a.nshards==a.shard)]
    # pre-flight cost estimate
    est=providers.estimate_cost(pv, len(df), fewshot_len=len(fewshot))
    print(f"PRE-FLIGHT: {len(df)} docs, strategy={pv['strategy']} model={pv['model']} ~= {est}")
    if a.dry_run: print("dry-run: no calls made."); return
    done=set(open(ckpt).read().split()) if os.path.exists(ckpt) else set()
    todo=df[~df[idc].isin(done)]
    HEAD=[idc,strata]+cb["out_fields"]+["rationale"]

    if pv["strategy"]=="batch":
        providers.run_batch(todo, idc, strata, tcols, cb, fewshot, pv, out_dir, HEAD, ckpt)
        return
    # async / local : threaded live calls
    locks={}; files={}; guard=threading.Lock(); cklock=threading.Lock()
    ck=open(ckpt,"a"); fl=open(failed,"a")
    def writer(vid):
        with guard:
            p=os.path.join(out_dir,f"annot{suf}_{sh(vid)%m.get('shards',64):03d}.csv")
            if p not in files:
                new=not os.path.exists(p) or os.path.getsize(p)==0
                fh=open(p,"a",newline="",encoding="utf-8"); w=csv.DictWriter(fh,fieldnames=HEAD)
                if new: w.writeheader(); fh.flush()
                files[p]=(fh,w); locks[p]=threading.Lock()
            return locks[p],files[p]
    n=[0]; tok=[0,0]
    recs=todo.to_dict("records")
    def work(r):
        return providers.annotate_one(r, tcols, cb, fewshot, pv)
    with ThreadPoolExecutor(max_workers=m.get("workers",16)) as ex:
        futs={ex.submit(work,r):r for r in recs}
        for fut in as_completed(futs):
            r=futs[fut]; vid=r[idc]
            try: status,ann,usage=fut.result()
            except providers.QuotaStop as q: print(f"STOP {q}"); break
            if status=="ok":
                lock,(fh,w)=writer(vid); row={idc:vid,strata:r.get(strata,"")}; row.update(ann)
                with lock: w.writerow(row); fh.flush()
                with cklock: ck.write(vid+"\n"); ck.flush()
                n[0]+=1; tok[0]+=usage[0]; tok[1]+=usage[1]
                if n[0]%1000==0: print(f"  annotated={n[0]}",flush=True)
            else:
                with cklock: fl.write(vid+"\n"); fl.flush()
    ck.close(); fl.close()
    for fh,_ in files.values():
        try: fh.close()
        except Exception: pass
    json.dump({"model":pv["model"],"n":n[0],"prompt_tokens":tok[0],"completion_tokens":tok[1]},open(ledger,"w"),indent=1)
    print(f"DONE annotated={n[0]} (shard {a.shard}/{a.nshards}); ledger -> {ledger}")

# ----------------------------- VALIDATE (HARD GATE) -----------------------------
def cmd_validate(a):
    import pandas as pd
    from sklearn.metrics import cohen_kappa_score, f1_score, classification_report
    pred=pd.read_csv(a.pred,dtype=str).fillna(""); gold=pd.read_csv(a.gold,dtype=str).fillna("")  # blank/None pred -> "" label, not NaN (cohen_kappa sort-safe)
    idc=a.id_col; j=gold.merge(pred[[idc]+a.on.split(",")],on=idc,suffixes=("_g","_p"))
    rep={}; ok_gate=True
    for v in a.on.split(","):
        g,p=j[f"{v}_g"],j[f"{v}_p"]; mask=g.notna()&(g!="")
        k=float(cohen_kappa_score(g[mask],p[mask])); f=float(f1_score(g[mask],p[mask],average="macro",zero_division=0))
        rep[v]={"n":int(mask.sum()),"cohen_kappa":round(k,3),"f1_macro":round(f,3),
                "pass":bool(k>=a.gate)}
        if v==a.on.split(",")[0] and k<a.gate: ok_gate=False
        print(f"[{v}] n={int(mask.sum())} κ={k:.3f} F1={f:.3f}  {'PASS' if k>=a.gate else 'FAIL'}")
        print(classification_report(g[mask],p[mask],zero_division=0))
    rep["GATE_pass"]=ok_gate
    json.dump(rep,open(a.out,"w"),indent=1,ensure_ascii=False)
    print(f"\nHARD GATE (primary κ ≥ {a.gate}): {'PASS — cleared for MODE 8' if ok_gate else 'FAIL — iterate codebook/few-shot; DO NOT scale'}")
    print("report ->",a.out)
    sys.exit(0 if ok_gate else 2)

# ----------------------------- DISTILL -----------------------------
def cmd_distill(a):
    import pandas as pd, re
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import Pipeline
    from sklearn.metrics import cohen_kappa_score, f1_score
    import joblib
    try: import jieba; jieba.setLogLevel(60); HAS_J=True
    except Exception: HAS_J=False
    def analyzer(t):
        t=str(t).lower(); out=re.findall(r"[a-z][a-z'\-]{2,}",t)
        if re.search(r"[一-鿿]",t):
            if HAS_J: out+=[w for w in jieba.cut(t) if len(w)>=2 and re.search(r"[一-鿿]",w)]
            else:                                                 # jieba often absent on compute nodes -> CJK char-bigram fallback (else Chinese is silently dropped)
                ch=re.findall(r"[一-鿿]",t); out+=[ch[i]+ch[i+1] for i in range(len(ch)-1)]
        return out
    lab=pd.read_csv(a.labels,dtype=str); tcols=a.text_cols.split(","); idc=a.id_col
    samp=pd.read_csv(a.sample,dtype=str) if a.sample else lab
    d=lab.merge(samp[[idc]+tcols],on=idc) if a.sample else lab
    d["_text"]=d[tcols].fillna("").agg(" ".join,axis=1).str.slice(0,1200)
    d=d[d[a.target_col].notna()]
    pipe=Pipeline([("tf",TfidfVectorizer(analyzer=analyzer,min_df=10,max_df=0.4,max_features=30000)),
                   ("lr",LogisticRegression(max_iter=2000,C=4.0,class_weight="balanced",n_jobs=-1))])
    if a.gold and os.path.exists(a.gold):
        gold=pd.read_csv(a.gold,dtype=str); gs=set(gold[idc]); tr=d[~d[idc].isin(gs)]
        pipe.fit(tr._text,tr[a.target_col])
        g=gold.merge(samp[[idc]+tcols],on=idc); g["_text"]=g[tcols].fillna("").agg(" ".join,axis=1).str.slice(0,1200)
        pr=pipe.predict(g._text)
        print(f"DISTILLED vs gold: κ={cohen_kappa_score(g[a.target_col],pr):.3f} F1={f1_score(g[a.target_col],pr,average='macro',zero_division=0):.3f}")
    pipe.fit(d._text,d[a.target_col]); joblib.dump(pipe,a.model_out); print(f"model -> {a.model_out}")
    if a.corpus:
        spec=json.load(open(a.corpus)); hdr=not os.path.exists(a.out); nrow=0
        for row in _chunk_corpus(spec,[idc]+tcols):
            row["_text"]=" ".join(S(row.get(c)) for c in tcols)[:1200]
        # stream-score in chunks
        import pandas as pd
        for ch in _corpus_frames(spec,[idc]+tcols,tcols):
            ch["pred"]=pipe.predict(ch["_text"]); nrow+=len(ch)
            ch[[idc,"pred"]].to_csv(a.out,mode="a",header=hdr,index=False); hdr=False
        print(f"scored corpus n={nrow} -> {a.out}  (target subset = rows where pred=='{a.target}')" if a.target else f"scored n={nrow} -> {a.out}")

def _corpus_frames(spec,cols,tcols):
    import pandas as pd
    for f in sorted(glob.glob(spec.get("category_glob",""))) if spec.get("category_glob") else []:
        for ch in robust_chunks(f,cols):
            ch["_text"]=ch[tcols].fillna("").agg(" ".join,axis=1).str.slice(0,1200); yield ch
    if spec.get("big_file"):
        bc=list(dict.fromkeys(cols+[spec.get("strata_col","query_category")]))
        for ch in robust_chunks(spec["big_file"],bc):
            if spec.get("big_only"): ch=ch[ch[spec["strata_col"]].isin(spec["big_only"])]
            ch["_text"]=ch[[c for c in tcols if c in ch]].fillna("").agg(" ".join,axis=1).str.slice(0,1200); yield ch
def _chunk_corpus(spec,cols):  # placeholder to keep signature; real work in _corpus_frames
    return []

def main():
    ap=argparse.ArgumentParser(prog="annotate_engine")
    sub=ap.add_subparsers(dest="cmd",required=True)
    s=sub.add_parser("sample"); s.add_argument("--corpus",required=True); s.add_argument("--text-cols",required=True)
    s.add_argument("--id-col",default="video_id"); s.add_argument("--strata"); s.add_argument("--n",type=int,default=3000)
    s.add_argument("--pool",type=int,default=500); s.add_argument("--oversample"); s.add_argument("--target")
    s.add_argument("--seed",type=int,default=23); s.add_argument("--out",required=True); s.set_defaults(fn=cmd_sample)
    an=sub.add_parser("annotate"); an.add_argument("--manifest",required=True); an.add_argument("--dry-run",action="store_true")
    an.add_argument("--resume",action="store_true"); an.add_argument("--limit",type=int); an.add_argument("--shard",type=int,default=0)
    an.add_argument("--nshards",type=int,default=1); an.set_defaults(fn=cmd_annotate)
    v=sub.add_parser("validate"); v.add_argument("--pred",required=True); v.add_argument("--gold",required=True)
    v.add_argument("--on",default="label"); v.add_argument("--id-col",default="video_id"); v.add_argument("--gate",type=float,default=0.70)
    v.add_argument("--out",default="output/tables/validation_report.json"); v.set_defaults(fn=cmd_validate)
    d=sub.add_parser("distill"); d.add_argument("--labels",required=True); d.add_argument("--sample"); d.add_argument("--corpus")
    d.add_argument("--text-cols",required=True); d.add_argument("--id-col",default="video_id"); d.add_argument("--target-col",default="relevance")
    d.add_argument("--target"); d.add_argument("--gold"); d.add_argument("--model-out",default="output/models/distilled.joblib")
    d.add_argument("--out",default="output/tables/labels_full.csv"); d.set_defaults(fn=cmd_distill)
    a=ap.parse_args(); a.fn(a)

if __name__=="__main__": main()
