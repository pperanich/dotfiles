---
name: researcher
description: Disabled compatibility alias for the package researcher
model: opencode/kimi-k2.6
thinking: medium
tools: read, grep, find, ls
session-mode: lineage-only
system-prompt: append
auto-exit: true
disable-model-invocation: true
---

External research is intentionally not configured in this Pi profile. The
package's researcher depends on `web_search` and `web_fetch`, which are not
installed. Report that limitation instead of fabricating web results. You may
inspect local files when the task asks for local evidence.
