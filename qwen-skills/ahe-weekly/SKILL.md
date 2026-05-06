---
name: ahe-weekly
description: Run weekly skill extraction + memory hygiene cycle. Invoke once per week.
---

# AHE Weekly — Extract + Consolidate

Runs skill extraction AND memory consolidation in sequence. Use once per week (Sundays recommended).

## What It Does

1. **Skill extraction** — Read recent session manifests (needs 5+). Identify repeatable patterns. Generate new `.qwen/skills/extracted-*/SKILL.md` entries for candidate workflows.
2. **Memory hygiene** — Read `learnings.md`, `MEMORY.md`, recent session manifests. Deduplicate, merge related entries, archive stale items (30+ days). Write consolidation report to `~/.ahe/status/hygiene-<date>.md`.

## Manual Invocation

```
/ahe-weekly
```

## Prerequisites

- Skill extraction needs 5+ session manifests in `~/.ahe/session-manifests/` to be useful
- Memory hygiene backs up pre-consolidation files to `~/.ahe/archive/hygiene/`
