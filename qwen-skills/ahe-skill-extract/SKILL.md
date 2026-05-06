---
name: ahe-skill-extract
description: Read recent session manifests, identify repeatable patterns, and generate new .qwen/skills/ entries from discovered workflows. Invoke with /ahe-skill-extract after accumulating 5+ session manifests.
---

# AHE Skill Extraction — Patterns to Skills

Read recent session manifests and identify workflows that should be formalized as reusable skills.

## Trigger

Run after 5+ session manifests have accumulated, or when you notice a pattern repeating across sessions.

## Extraction Criteria

A pattern is a skill candidate if it meets any of:
- **Repeat count**: Same workflow appeared in 3+ sessions with similar tool sequence
- **Complexity**: The task involved 5+ distinct tool calls and a non-trivial decision tree
- **Error density**: Same error appeared in 2+ sessions and the fix was non-trivial
- **User correction**: User corrected your approach in a way that should be remembered
- **Discovery**: You discovered a workflow the user didn't explicitly ask for but was valuable

## Input

Read session manifests from `~/.ahe/session-manifests/`.

Also check existing skills in `.qwen/skills/` for:
- Skills that match the candidate pattern (skip if already covered)
- Skills that have been used 0 times (candidates for pruning — flag but don't act)

## Output

For each candidate, generate a SKILL.md at `.qwen/skills/extracted-<name>/SKILL.md`:

```markdown
---
name: extracted-<name>
description: Autodetected from session patterns. <brief one-line>
---

# <Name>

## Trigger
When to use this skill — specific conditions from the originating sessions.

## Procedure
Step-by-step workflow extracted from successful sessions.

## Pitfalls
Errors hit during the originating sessions — documented fixes.

## Verification
How to confirm the skill worked correctly.
```

## Non-Action Items

- Do NOT overwrite existing skills — use a unique name
- Do NOT create skills for one-off tasks (run once, unlikely to repeat)
- Do NOT create skills that already exist under a different name — check first
- Flag potential duplicates to the user rather than creating conflicts

## Integration with Existing AHE

AHE already has skill linking via `ahe-evolve.ps1` (creates junctions from `plugins/compound-engineering/skills/` to `.qwen/skills/`). For skills you create here, reference this pattern in the summary rather than duplicating it.
