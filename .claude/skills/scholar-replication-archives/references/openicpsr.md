# OpenICPSR / ICPSR

OpenICPSR was the self-publishing repository operated by the Inter-university Consortium for Political and Social Research (ICPSR), specializing in social, behavioral, and health sciences replication datasets. **The openICPSR platform has been fully integrated into ICPSR** — the standalone `openicpsr.org` site no longer hosts the search; all former openICPSR projects remain searchable through the ICPSR catalog at `icpsr.umich.edu`.

**Best For**: Political science, economics, economic policy, applied economics **Note**: No public API available; requires web-based catalog access

## Hosted Repositories

- **AEA**: American Economic Association (mandatory for AER, AEJ journals)
- **JEH**: Journal of Economic History
- **PSID**: Panel Study of Income Dynamics
- **AERA**: American Educational Research Association

## Access Methods

**Catalog Search**: <https://www.icpsr.umich.edu/sites/icpsr/find-data>

All former openICPSR projects are returned by the "openICPSR" archive filter:

```
https://www.icpsr.umich.edu/sites/icpsr/search/studies?start=0&fq=ARCHIVE%3Aopenicpsr
```

Narrow to a specific former repository with the thematic collection filters, for example the AEA Data and Code Repository:

```
https://www.icpsr.umich.edu/sites/icpsr/search/studies?start=0&fq=ARCHIVE%3Aopenicpsr&fq=ARCHIVE_NAME%3AAmerican+Economic+Association+Data+and+Code+Repository
```

The interface is JavaScript-driven; automation requires a browser tool (or `websearch`/`webfetch` on the search URLs above).

## Metadata Available

Study pages include:

- Title and abstract
- Authors and affiliations
- Related publications
- Data format and structure
- Usage terms (some require institutional login)

## AI Agent Strategy

1. **Initial Discovery**: Use `websearch` with `site:icpsr.umich.edu "author name" replication`
2. **Detail Extraction**: Use `webfetch` to retrieve study pages
3. **Metadata Parsing**: Parse HTML for structured information
4. **Download Access**: Requires an ICPSR account and terms agreement

## Limitations

- No public API for programmatic access
- Some datasets require institutional authentication
- Downloads require explicit terms agreement per dataset
