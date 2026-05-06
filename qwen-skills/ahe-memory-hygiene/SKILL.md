---
name: ahe-memory-hygiene
description: Consolidate and deduplicate accumulated learnings and memory. Reads learnings.md, MEMORY.md, and session manifests to produce a leaner, more accurate knowledge store. Run weekly or when memory feels bloated.
---

# AHE Memory Hygiene — Knowledge Consolidation

Read the current knowledge stores, identify stale or redundant entries, merge related facts, and write a consolidated version.

## Trigger

- `/ahe-memory-hygiene` — manual invocation
- Weekly, suggested by ahe-startup health report
- When MEMORY.md exceeds 100 entries or learnings.md exceeds 50KB

## Input Sources

### 1. AHE Learnings
`~/.autoresearch/learnings.md` — accumulated improvement cycle learnings

### 2. Qwen Memory (MEMORY.md)
`~/.qwen/projects/c--users-administrator/memory/MEMORY.md` — cross-session index

### 3. Session Manifests
`~/.ahe/session-manifests/` — last 20 sessions for recent patterns

### 4. User Memory Files
`~/.qwen/projects/c--users-administrator/memory/` — individual memory entries (user/, feedback/, project/, reference/)

## Consolidation Rules

| Rule | Action |
|---|---|
| Exact duplicate | Delete one entry |
| Partial overlap | Merge into single entry, keep both facts |
| Contradictory facts | Evaluate which is more recent (check session manifests); update or flag |
| Stale (30+ days, no references) | Archive to `~/.ahe/archive/learnings/` |
| Superseded by skill | Remove — skill is the living version |
| Trivial / ephemeral | Remove — not worth cross-session retention |

## Output

For each source file, write a consolidated version back to the same path:

1. **learnings.md** — deduplicated, merged, archived stale entries
2. **MEMORY.md index** — leaner pointer list, removed dead entries
3. **Consolidation report** — write to `~/.ahe/status/hygiene-<YYYY-MM-DD>.md`:

```markdown
# Memory Hygiene — YYYY-MM-DD

## Before/After
- learnings.md: XX KB → YY KB (Z% reduction)
- MEMORY.md: N entries → M entries
- User memories archived: N
- Feedback archived: N
- Project memories archived: N

## Changes Made
- Removed: [entry name] — reason
- Merged: [entries] → [single entry] — reason
- Archived: [entry name] — stale since <date>

## Items Flagged for Human Review
- [ ] Contradictory: [topic] (which version is correct?)
- [ ] Uncertain: [entry] (verify accuracy)
```

## Constraints

- Do NOT delete user-curated content without verification — if unsure, flag for review
- Prefer merge over delete when entries partially overlap
- Preserve the latest update timestamps
- Keep a backup of pre-consolidation files in `~/.ahe/archive/hygiene/`
