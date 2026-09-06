# Zenodo

Zenodo is a general-purpose open repository developed under the European OpenAIRE program and operated by CERN. It accepts multidisciplinary research outputs in all formats.

**Key Stats**: Elasticsearch-based search, 50GB per file (new API), DOI registration **Best For**: Publication-linked datasets, multidisciplinary research, versioned outputs **Documentation**: <https://developers.zenodo.org/>

## Authentication

Optional for open-access records, recommended for higher rate limits. Create a token at <https://zenodo.org/account/settings/applications/tokens/new/> or use the `ZENODO_TOKEN` environment variable:

```python
import os

access_token = os.environ.get('ZENODO_TOKEN', 'your_token')
headers = {'Authorization': f'Bearer {access_token}'}
```

## Records Search API

Search published records (the deposit API is for uploading, not discovery):

```python
response = requests.get(
    'https://zenodo.org/api/records',
    headers=headers,
    params={
        'q': 'replication',
        'type': 'dataset',
        'sort': 'mostrecent',
        'size': 25,     # max 25 anonymous, 100 authenticated
        'page': 1
    }
)
```

| Parameter | Purpose |
|-----------|---------|
| `q` | Elasticsearch query string (field-specific, phrases, date ranges) |
| `type` | Record type filter, e.g. `dataset`, `publication`, `software` |
| `subtype` | Subtype filter, e.g. `preprint`, `workingpaper` |
| `sort` | `bestmatch` (default) or `mostrecent`; prefix `-` for descending |
| `page` / `size` | Pagination; `size` max 25 (anonymous) / 100 (authenticated) |
| `all_versions` | `true`/`1` to include all versions of a record |

## Finding Replication Packages

| Strategy | Query Example |
|----------|---------------|
| Keywords | `q=replication OR reproducibility OR supplementary` |
| Related to papers | `q=metadata.related_identifiers.relation:isSupplementTo` |
| Recent datasets | `q=replication&sort=-mostrecent&type=dataset` |

## Complete Download

```python
def download_zenodo_record(record_id, output_dir):
    import os
    import requests

    record_url = f"https://zenodo.org/api/records/{record_id}"
    record = requests.get(record_url).json()

    os.makedirs(output_dir, exist_ok=True)
    for file_info in record.get('files', []):
        filename = file_info['key']
        file_url = file_info['links']['self']

        response = requests.get(file_url, stream=True)
        with open(os.path.join(output_dir, filename), 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

    return record['metadata']
```
