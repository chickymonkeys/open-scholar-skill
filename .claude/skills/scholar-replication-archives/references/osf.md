# Open Science Framework (OSF)

OSF is a free, open-source project management platform by the Center for Open Science. It supports the entire research lifecycle and integrates with GitHub, Dropbox, Google Drive, and more.

**Key Stats**: JSON-API v2, 10,000 requests/day (authenticated), 100/hour (unauthenticated)
**Best For**: Project-based research, preprints, multi-component studies
**Documentation**: <https://developer.osf.io/>

## Authentication

Create a Personal Access Token at <https://osf.io/settings/tokens> or use the `OSF_TOKEN` environment variable:

```python
import requests
import os

BASE_URL = "https://api.osf.io/v2"
token = os.environ.get('OSF_TOKEN', 'your_personal_access_token')

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/vnd.api+json"
}
```

## Node Search

```python
response = requests.get(
    f"{BASE_URL}/nodes/",
    headers=headers,
    params={
        "filter[category]": "data",
        "filter[tags]": "replication",
        "filter[public]": "true",
        "page": 1
    }
)
```

## Pagination

OSF uses cursor-based pagination via `links.next`. Only pass query params on the first request; subsequent URLs are fully qualified:

```python
results = []
url = f"{BASE_URL}/nodes/"
params = {"filter[public]": "true", "filter[tags]": "replication"}

while url:
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    data = response.json()
    results.extend(data["data"])  # Results are in data["data"] array
    url = data["links"].get("next")  # Follow links.next for next page
    params = {}  # Only use params on first request; next URL includes them
```

**Key points:**

- Results are in `data["data"]` (JSON-API envelope)
- Next page URL is in `data["links"]["next"]` — `None` when no more pages
- Download URLs for files: `file_obj['links']['download']`

## Common Tags

- `replication`, `replication data`, `data and code`
- `economics`, `econometrics`, `causal inference`
- `stata`, `r`, `python`, `panel data`

## Node-to-File Workflow

```python
# 1. Get node ID from search
# 2. List storage providers
providers_url = f"{BASE_URL}/nodes/{node_id}/files/"

# 3. Navigate to specific provider (e.g., osfstorage)
files_url = f"{BASE_URL}/nodes/{node_id}/files/osfstorage/"

# 4. Download using the Waterbutler URL from file_obj['links']['download']
```

## Preprint Search

```python
response = requests.get(
    f"{BASE_URL}/preprints/",
    headers=headers,
    params={"filter[title]": "economics instrumental variables"}
)
```

## Search Filters

```python
# By category
categories = ["data", "software", "analysis"]

# By title keywords
keywords = ["replication", "data and code", "empirical analysis"]

# Advanced search
params = {
    "filter[title]": "instrumental variables",
    "filter[category]": "data",
    "filter[public]": "true"
}
```
