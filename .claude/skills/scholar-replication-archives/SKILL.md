---
name: scholar-replication-archives
description: >
  Locate replication packages, code bundles, and dataset deposits across the major
  academic repositories — Dataverse, OpenICPSR/ICPSR, OSF, Zenodo, and GitHub. Use
  when finding reproducibility artifacts for a paper, validating package provenance,
  or comparing repository coverage and access constraints before recommending a
  deposit.
argument-hint: "[paper citation or title | author name(s) | DOI | repository keyword]"
user-invocable: true
---

# scholar-replication-archives — Replication Archive Discovery

> **Key differentiation from scholar-replication:**
> - `scholar-replication` builds and validates *your own* replication package (assemble, document, test, verify, archive).
> - `scholar-replication-archives` finds *other researchers'* deposited replication packages, code, and datasets across the major archives.
>
> This skill is a knowledge layer: it captures repository knowledge and access
> patterns and returns cited repository findings to the caller. It does not define
> multi-agent sequencing, does not write a findings file (the caller owns
> file-writing), and never invokes another skill.

## Step 0: Parse the search target

Parse `$ARGUMENTS` to fix what is being located:

- a **paper title or citation** — search by title and author names;
- a **DOI** — DOI-first lookup in the DOI-bearing repositories (Dataverse, Zenodo);
- **author name(s)** — search per author across repositories;
- a **repository keyword** — e.g. `dataverse`, `osf`, `openicpsr`, to compare coverage and access before searching.

**Process Logging (REQUIRED) — Reasoning · Action · Observation trace:**

This skill emits an append-only RAO trace at `${OUTPUT_ROOT}/logs/trace-scholar-replication-archives-<date>.ndjson` — the source of truth. The human-readable `process-log-scholar-replication-archives-<date>.md` is *rendered* from it, never hand-written. Full protocol + privacy rule: `_shared/process-logger.md`.

At each meaningful step (a decision, a repository search, an inspection, a fallback, a gate call), append one record. `emit-trace.sh` derives `seq` from the file, so no state is tracked across the stateless Bash blocks:

```bash
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" --skill scholar-replication-archives --step "<label>" \
  --reasoning "<the WHY — stated rationale, 1–2 lines>" \
  --action "<the WHAT — repository/tool/gate call + key args>" \
  --observation "<the RESULT — verdict/count/error/file ref>" --status ok || true    # ok|fail|skipped
```

## Core Repository Map

| Repository | Best For | Primary Access |
|------------|----------|----------------|
| Dataverse | DOI-linked institutional deposits | REST API and web records |
| OpenICPSR / ICPSR | Economics and social science archives | Web discovery + record pages |
| OSF | Project bundles and working-paper artifacts | API and web records |
| Zenodo | Versioned research deposits | API and web records |
| GitHub | Public code implementation repositories | Web discovery + file inspection |

## Progressive Disclosure

Load repository references only when the corresponding source is in play:

- `references/dataverse.md`
  - Load for DOI-first lookups and Dataverse API query patterns.

- `references/openicpsr.md`
  - Load for social-science archive discovery when no Dataverse hit exists.

- `references/osf.md`
  - Load for working-paper or project-hosted package searches.

- `references/zenodo.md`
  - Load for versioned package records and broad multidisciplinary deposits.

- `references/repository-comparison.md`
  - Load when selecting where to search first under time constraints.

Do not load all references by default; pull only the files needed for the current repository path.

## Search Workflow

### Step 1: DOI-first lookup

When the paper has a DOI, resolve it against the DOI-bearing repositories before any keyword search. Dataverse and Zenodo both index deposits by persistent identifier.

```bash
cat "${SCHOLAR_SKILL_DIR:-.}/.claude/skills/_shared/process-logger.md" 2>/dev/null | grep -q "emit-trace" \
  && [ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" --skill scholar-replication-archives --step "1-doi-lookup" \
       --reasoning "A DOI is the strongest provenance key — resolve it first so keyword false-negatives cannot hide an existing deposit" \
       --action "query Dataverse and Zenodo by persistentId/DOI for: $ARGUMENTS" \
       --observation "hits recorded with repository, PID, access type" --status ok || true
```

### Step 2: Repository-complete cross-repository pass

Search must be **repository-complete** before declaring "not found": coverage is uneven across archives, so a cross-repository pass reduces false negatives. For each repository the target plausibly lives in, run its reference's search pattern (Dataverse → OpenICPSR → OSF → Zenodo → GitHub, in an order informed by `references/repository-comparison.md`), and record each repository's outcome.

```bash
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" --skill scholar-replication-archives --step "2-repo-pass" \
  --reasoning "Coverage is uneven across archives; a single-repository search produces avoidable false negatives" \
  --action "cross-repository search for: $ARGUMENTS" \
  --observation "per-repository hit counts and any empty results" --status ok || true
```

### Step 3: Inspect candidate packages

For each candidate package found, load the relevant repository reference and capture the full provenance record (see [Provenance and Verification Standards](#provenance-and-verification-standards)) before recommending it.

```bash
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" --skill scholar-replication-archives --step "3-inspect" \
  --reasoning "A landing page is not package proof — contents, access type, and last-updated must be verified" \
  --action "inspect candidate records for: $ARGUMENTS" \
  --observation "provenance fields captured per candidate" --status ok || true
```

### Step 4: Author-hosted fallback

If primary repositories are empty for a paper, author-hosted artifacts may still exist. Treat these as **lower-trust fallbacks** because they lack DOI and version control. For each author:

1. Search "[author name]" personal site OR homepage.
2. Check for "Research", "Data", "Replication", "Code" sub-pages.
3. Look for links to GitHub, Dropbox, Google Drive hosted data.
4. Check co-authors' websites using the same pattern.
5. Note: author-hosted packages lack DOIs and version control — flag this in output.

```bash
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" --skill scholar-replication-archives --step "4-author-fallback" \
  --reasoning "Primary repositories empty; author-hosted material is a legitimate but weaker fallback (no DOI, no versioning)" \
  --action "author-site search for: $ARGUMENTS" \
  --observation "author-hosted hits flagged as lower-trust" --status ok || true
```

### Step 5: Coverage verdict and return

Run the coverage gate and return the cited repository findings to the caller (see [Output Expectations](#output-expectations)). The caller owns file-writing; this skill writes nothing but its trace.

```bash
OUTPUT_ROOT="${OUTPUT_ROOT:-output}"
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/emit-trace.sh" --skill scholar-replication-archives --step "5-verdict" \
  --reasoning "Repository-complete pass complete — record the final coverage verdict" \
  --action "render trace and run the coverage gate" \
  --observation "verdict returned: found / partial / not-found" --status ok || true
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/render-trace.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/render-trace.sh" "${OUTPUT_ROOT}/logs/trace-scholar-replication-archives-$(date +%Y-%m-%d).ndjson" || true
[ -f "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/trace-coverage-check.sh" ] && bash "${SCHOLAR_SKILL_DIR:-.}/scripts/gates/trace-coverage-check.sh" "${OUTPUT_ROOT}" --skill scholar-replication-archives || true
```

## Provenance and Verification Standards

For each candidate package, capture:

- persistent identifier (DOI or stable URL),
- repository location,
- package contents (code, data, docs),
- access type (open / restricted / embargoed),
- last-updated signal if available.

## Coverage Strategy

Search should be repository-complete before declaring "not found." Repository coverage is uneven, so cross-repository passes reduce false negatives. Declaring "not found" after checking only one repository creates avoidable false negatives.

## API Authentication Note

Some repository APIs may require tokens via local environment variables (`DATAVERSE_API_TOKEN`, `OSF_TOKEN`, `ZENODO_TOKEN`). Never exfiltrate or print secrets; pass tokens as headers only.

## Anti-Patterns (with Rationale)

- Declaring "not found" after checking only one repository: creates avoidable false negatives.
- Treating landing pages as package proof without content verification: often misses code/data completeness.
- Ignoring access restrictions: downstream teams cannot reproduce results without this detail.
- Mixing data-only and full replication bundles: causes misleading reproducibility claims.
- Using author-hosted mirrors as equivalent to archived deposits: provenance and version control are weaker.

## Output Expectations

Return repository findings with explicit provenance, access constraints, and package-content clarity so downstream handoffs remain machine-usable. Return per-candidate: persistent identifier, repository location, package contents, access type, last-updated signal, and the trust level (archived deposit vs author-hosted fallback). **This skill writes no findings file** — the master trace is its only artifact; the caller decides where findings land.
