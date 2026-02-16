---
name: opal-aa-benchmarking
description: Use when you need to rank OPAL models with Artificial Analysis benchmarks or compare OPAL models by speed, price, and evaluation scores - fetches Artificial Analysis model data, matches OPAL IDs safely, and produces a ranked report with unmatched models called out.
---

# OPAL Artificial Analysis Benchmarking

## Overview

Rank OPAL models using Artificial Analysis benchmarks by matching OPAL model IDs to Artificial Analysis entries with strict, reviewable rules. Core principle: never rank on ambiguous matches.

## When to Use

- Need a benchmark-based ranking of OPAL models.
- Need speed/price/evaluation comparisons across OPAL models.
- Artificial Analysis data is the source of truth for ranking.

## Core Pattern

1. Fetch OPAL model IDs.
2. Fetch Artificial Analysis model list with API key.
3. Normalize names and match by exact ID/slug/name.
4. Only allow controlled fallback matching; flag ambiguities.
5. Rank on a declared metric and publish unmatched list.

## Quick Reference

| Step | Action                                                      | Output          |
| ---- | ----------------------------------------------------------- | --------------- |
| 1    | Load OPAL model IDs                                         | `opal_models[]` |
| 2    | GET `https://artificialanalysis.ai/api/v2/data/llms/models` | `aa_models[]`   |
| 3    | Exact match by `slug` or `name`                             | `matched[]`     |
| 4    | Fallback match (token-equal)                                | `review[]`      |
| 5    | Rank by chosen metric                                       | `ranked_report` |

## Implementation

- OPAL list source: `https://opal.jhuapl.edu/v2/models` or `~/.config/opencode-work/opencode.json`.
- Artificial Analysis API:
  ```bash
  curl -s https://artificialanalysis.ai/api/v2/data/llms/models \
    -H "x-api-key: ${ARTIFICIAL_ANALYSIS_API_KEY}"
  ```
- Matching rules (strict):
  - Exact match by OPAL model ID == Artificial Analysis `slug` or `name`.
  - Normalize by lowercasing, trimming, and replacing consecutive whitespace with single spaces.
  - Fallback only if the normalized full string matches exactly after removing common prefixes (e.g., "openai/", "meta-llama/").
  - If multiple matches exist, mark as ambiguous and stop ranking that model.
- Ranking:
  - Default metric: `evaluations.artificial_analysis_intelligence_index`.
  - Include `artificial_analysis_coding_index`, `pricing.price_1m_blended_3_to_1`, `median_output_tokens_per_second`, `median_time_to_first_token_seconds` in report.
  - Always output unmatched and ambiguous models.

## Example (Python)

```python
import os
import requests

def normalize(value: str) -> str:
    return " ".join(value.lower().strip().split())

def strip_prefix(value: str) -> str:
    for prefix in ("openai/", "meta-llama/", "qwen/", "mistralai/", "google/"):
        if value.startswith(prefix):
            return value[len(prefix):]
    return value

opal_models = requests.get("https://opal.jhuapl.edu/v2/models").json()["data"]
aa = requests.get(
    "https://artificialanalysis.ai/api/v2/data/llms/models",
    headers={"x-api-key": os.environ["ARTIFICIAL_ANALYSIS_API_KEY"]},
).json()["data"]

by_slug = {normalize(m["slug"]): m for m in aa}
by_name = {normalize(m["name"]): m for m in aa}

matched, unmatched = [], []
for opal in opal_models:
    opal_id = normalize(opal["id"])
    candidate = by_slug.get(opal_id) or by_name.get(opal_id)
    if not candidate:
        stripped = normalize(strip_prefix(opal_id))
        candidate = by_slug.get(stripped) or by_name.get(stripped)
    if not candidate:
        unmatched.append(opal["id"])
        continue
    matched.append({
        "opal_id": opal["id"],
        "aa_name": candidate["name"],
        "intelligence": candidate["evaluations"].get("artificial_analysis_intelligence_index"),
        "coding": candidate["evaluations"].get("artificial_analysis_coding_index"),
        "price": candidate.get("pricing", {}).get("price_1m_blended_3_to_1"),
        "toks_per_sec": candidate.get("median_output_tokens_per_second"),
        "ttft": candidate.get("median_time_to_first_token_seconds"),
    })

ranked = sorted(
    [m for m in matched if m["intelligence"] is not None],
    key=lambda m: m["intelligence"],
    reverse=True,
)
print("Top models:", ranked[:5])
print("Unmatched:", unmatched)
```

## Rationalization Table

| Excuse                                     | Reality                                                              |
| ------------------------------------------ | -------------------------------------------------------------------- |
| "Substring matching is good enough"        | It creates silent mislinks. Use strict rules and report ambiguities. |
| "Deadline is tight, ship the quick script" | Wrong rankings erode trust. Output unmatched models instead.         |
| "Just ask a question and stop"             | Ask once, then proceed with strict matching and a review list.       |

## Red Flags

- "I’ll ignore mismatches for now"
- "Substring matches are close enough"
- "I’ll rank anyway and clean it later"

## Common Mistakes

- Ranking models with ambiguous matches.
- Omitting price/speed fields from the report.
- Using the wrong API key header (`x-api-key` is required).
- Failing to publish unmatched OPAL models.
