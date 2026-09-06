# Repository Access Methods

Access method summary for choosing the right repository.

## Access Method Summary

| Repository | Has API | Primary Access Method | Fallback Method | Best For |
|------------|---------|----------------------|-----------------|----------|
| **Dataverse** | ✅ Yes | `bash` + curl (REST API) | `websearch` + `webfetch` | Institutional data, DOI-based datasets |
| **OSF** | ✅ Yes | `bash` + curl (JSON-API) | Python requests | Project-based research, preprints |
| **Zenodo** | ✅ Yes | `bash` + curl (REST API) | Python requests | Multidisciplinary, publication-linked |
| **GitHub** | ✅ Yes | GitHub search (web or `api.github.com`) | `websearch` + `webfetch` | Code, methodology examples |
| **OpenICPSR / ICPSR** | ❌ No | `webfetch` (catalog) | `websearch` | Economics, social science |
| **Figshare** | ✅ Yes | `bash` + curl | `webfetch` | General academic outputs |

## Decision Flowchart

**Start**: What do you have?

→ **DOI found?** → Check Dataverse or Zenodo

- Use REST API for Dataverse
- Use API for Zenodo

→ **Economics paper?** → Search OpenICPSR/ICPSR

- Use websearch with site filter (`site:icpsr.umich.edu`)
- Parse metadata with webfetch

→ **Looking for code?** → Use GitHub

- Search by repository/title/author
- Filter by language (R, Stata, Python)

→ **Working paper?** → Check OSF

- Search preprints endpoint
- Filter by public status

→ **General dataset?** → Check Dataverse, Zenodo, Figshare

- Try Dataverse first
- Fall back to Zenodo API

## Quick Reference

**Fastest path to data**: Dataverse REST API → Zenodo API → OSF API

**Fastest path to code**: GitHub search

**Economics specific**: OpenICPSR/ICPSR (manual catalog search)

**No API available**: OpenICPSR/ICPSR only
