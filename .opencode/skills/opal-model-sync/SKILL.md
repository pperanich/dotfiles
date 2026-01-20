---
name: opal-model-sync
description: Use when OPAL's model catalog changes or you need to refresh OpenCode models from https://opal.jhuapl.edu/openapi.json - fetches the OpenAPI spec, extracts model IDs, and updates ~/.config/opencode-work/opencode.json.
license: MIT
compatibility: opencode
metadata:
  source: opal
  scope: opencode-work-config
---

## What I do

- Pull the latest OPAL OpenAPI spec from `https://opal.jhuapl.edu/openapi.json`.
- Extract model IDs (chat, embeddings, image generation) from the spec.
- Update the `opal` provider in `~/.config/opencode-work/opencode.json` with the full model list.

## When to use me

- A new OPAL model was added or removed.
- You see model mismatch errors in OpenCode.
- You want the local OPAL model list to mirror the OpenAPI spec.

## Update workflow

1. Fetch the spec: `curl -s https://opal.jhuapl.edu/openapi.json`.
2. Locate the model list in the spec or `/v2/models` schema.
3. Ensure `provider.opal` exists in `~/.config/opencode-work/opencode.json` with:
   - `npm`: `@ai-sdk/openai-compatible`
   - `options.baseURL`: `https://opal.jhuapl.edu/v2`
4. Replace `provider.opal.models` with the complete set of model IDs.
5. Keep other providers and settings unchanged.

## Output format

Use a flat `models` map where each key is the model ID and the `name` matches the ID:

```json
"models": {
  "zai-org/GLM-4.5-Air-FP8": { "name": "zai-org/GLM-4.5-Air-FP8" },
  "Qwen/Qwen3-Embedding-8B": { "name": "Qwen/Qwen3-Embedding-8B" }
}
```

## Common pitfalls

- Forgetting embedding or image-generation models.
- Overwriting other providers (e.g., Google/Anthropic).
- Changing the default `model` unintentionally.
