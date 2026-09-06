# Dataverse

Dataverse is an open-source web application for sharing, preserving, and analyzing research data. Developed by Harvard's IQSS, it operates as a federated network of installations — institutional research data, social science datasets, and replication packages with DOIs.

**Best For**: Institutional research data, social science datasets, replication packages with DOIs
**Major Installations**: Harvard, DataverseNL, Abacus (UBC), Australia Data Archive
**Documentation**: <https://guides.dataverse.org/en/latest/api/search.html>

## Primary Access: REST API

Use the REST API as the primary access method. It provides comprehensive coverage including file-level access and MD5 verification.

## Search API

Search endpoint (also reachable as `/api/v1/search` on older servers):

```
GET https://<server>/api/search
```

| Parameter | Purpose |
|-----------|---------|
| `q` | Search term(s); `title:data` narrows to the title field; `*` is a wildcard |
| `type` | `dataset`, `dataverse`, or `file` (repeatable) |
| `subtree` | Narrow to a Dataverse collection and its children (repeatable) |
| `sort` | `name`, `date`, or `score` (relevance, default) |
| `order` | `asc` or `desc` |
| `per_page` | Results per request (default 10, max 1000) |
| `start` | Cursor for paging (iterate until `total_count`) |
| `fq` | Filter query, e.g. `fq=publicationStatus:Published` for released versions only |
| `metadata_fields` | Include metadata fields, e.g. `citation:author` (repeatable) |

Response items for datasets carry `global_id` (the DOI), `citation`, `fileCount`,
`versionState`, `updatedAt`, and `authors` — enough to fill the provenance record.

## Search Example

```bash
curl -s "https://dataverse.harvard.edu/api/search?q=replication+stata+economics&type=dataset&per_page=100&sort=date&order=desc&fq=publicationStatus:Published"
```

Iterate with `start` until `total_count` is reached.

## Authentication

Obtain an API token from account settings or via the `DATAVERSE_API_TOKEN`
environment variable. Pass it as the `X-Dataverse-key` header. A token is required
to search unpublished content; public released records do not need one.

## DOI Retrieval

```bash
curl -H "X-Dataverse-key: YOUR_TOKEN" \
  "https://dataverse.harvard.edu/api/v1/datasets/:persistentId?persistentId=doi:10.7910/DVN/EXAMPLE&latest=true"
```

## File Download with Verification

```bash
# Dataset bundle
curl -L -H "X-Dataverse-key: YOUR_TOKEN" \
  "https://dataverse.harvard.edu/api/v1/access/dataset/:persistentId?persistentId=doi:10.7910/DVN/EXAMPLE" -o bundle.zip

# Single file by id — verify the MD5 from the file metadata after download
curl -s "https://dataverse.harvard.edu/api/v1/files/{file_id}" | jq -r '.data.md5'
```

## MCP Server (Discovery Only)

Dataverse provides an MCP server at <https://mcp.dataverse.org> with some working
tools (`search_datasets`, `get_croissant_record`, `overview`). MCP is available for
discovery but not guaranteed; use the REST API for file downloads and detailed
operations.

## Alternative Discovery

Use `websearch` with `site:dataverse.harvard.edu [topic|concept|title|author]` for initial discovery.
