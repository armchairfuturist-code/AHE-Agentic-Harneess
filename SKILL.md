---
name: orchestrator
description: Skill and tool recommendation engine. Trigger when the user asks "what should I use", "which tool", "how should I approach", or expresses uncertainty about which skill/tool to apply to a task. Also triggers on task descriptions where the optimal toolset is non-obvious.
compatibility: qwen
---

# Orchestrator — Skill & Tool Recommendation

## When to Use

Trigger when the user:
- Asks "what should I use for X?"
- Says "which tool/skill is right for this?"
- Describes a task without specifying the approach
- Expresses uncertainty about tool selection
- Describes a task that could benefit from multiple tools

Relax: **If the user already specified a skill or tool, skip this and use it.** This is only for when they're unsure.

## Recommendation Map

### Debugging & Bug Fixing

| Goal | Recommended | Why |
|------|-------------|-----|
| Fix a bug, investigate failure | `ce-debug` | Systematic debug loop: reproduce → minimise → hypothesise → instrument → fix |
| Debug test failure | `ce-debug` + `tdd` | Red-green-refactor with systematic root cause |
| Performance regression | `ce-debug` or `diagnose` | Both have reproduction-focused loops |
| Chase a cryptic error | `ce-debug` | Structured root cause analysis |

### Optimization & Improvement

| Goal | Recommended | Why |
|------|-------------|-----|
| Optimize a numeric metric (speed, tokens, accuracy) | `autoresearch` | Modify → verify → keep/discard loop with metric-driven iteration |
| Multi-file code quality improvement | `ce-optimize` | Parallel experiments, Pareto selection |
| Improve benchmark score | `pipeline.ps1` (AHE) | Full self-improvement cycle |
| Find optimal configuration | `autoresearch` with Pareto multi-metric | Best for trading off competing goals |

### Planning & Design

| Goal | Recommended | Why |
|------|-------------|-----|
| Plan a multi-step feature | `ce-plan` | Structured plan with verification gates |
| Brainstorm requirements | `ce-brainstorm` | Collaborative requirements exploration |
| Stress-test a plan | `grill-me` | Interview-style Socratic questioning |
| Validate domain model | `domain-model` | Stress-test terminology against existing model |
| Design a UI | `gsd:sketch` + `ce-frontend-design` | Throwaway mockups then production build |

### Research & Learning

| Goal | Recommended | Why |
|------|-------------|-----|
| Research what people say about topic | `last30days` | Pulls Reddit, HN, GitHub, web |
| Search past sessions for context | `ce-sessions` | Ask questions about your session history |
| Learn a new framework | `qc-helper` + web search | Qwen Code docs + Brave/Context7 |
| Web research on best practices | `ce-ideate` + `web_fetch` | Grounded idea generation with evidence |

### Code Review & Quality

| Goal | Recommended | Why |
|------|-------------|-----|
| Review code before PR | `ce-code-review` | Multi-persona review pipeline |
| Auto-fix review issues | `ce-code-review` → `gsd:code-review-fix` | Fixer agent commits each fix |
| Simplify code after writing | `simplify` | Refactor for clarity without changing behavior |
| Security audit | `gsd:secure-phase` or self-heal.bat option 10 | Threat model verification |

### Writing & Documentation

| Goal | Recommended | Why |
|------|-------------|-----|
| Write PR description | `ce-pr-description` | Value-first, scales to change complexity |
| Write a novel/long-form | `storyforge` | Autonomous novel-writing pipeline |
| Document solved problem | `ce-compound` | Persist learnings to knowledge base |
| Review a document | `ce-doc-review` | Parallel persona agents |

### System & Pipeline

| Goal | Recommended | Why |
|------|-------------|-----|
| Run self-improvement cycle | `pipeline.ps1` | Full AHE: discover → benchmark → gate → compound |
| Check system health | self-heal.bat option 1 | Quick status of all subsystems |
| Update everything | self-heal.bat option 5 | Plugins, models, dependencies |
| Run benchmark | `benchmark.ps1 -Runs 3` | AHE-weighted multi-rollout evaluation |
| Create a new skill | `skill-creator` | Scaffolds a new SKILL.md with proper structure |

### MCP Tools (available but skill-wrapped)

| Need | Tool | How to access |
|------|------|---------------|
| Web search | `brave_web_search` | via `last30days` skill or the tool directly |
| GitHub operations | GitHub MCP tools | `mcp__github__*` — create repos, issues, PRs |
| Code analysis | Context7 | `mcp__context7__query-docs` for library docs |
| Browser automation | `agent-browser` skill | Navigate, fill, click, screenshot |
| Image generation | `ce-gemini-imagegen` or aion UI MCP | Text-to-image |

## Cross-Reference: Skill Ecosystem

```
                ┌─────────────┐
                │ ORCHESTRATOR │ ← You are here
                └──────┬──────┘
         ┌─────────────┼─────────────┐
    ┌────┴────┐  ┌────┴────┐  ┌────┴────┐
    │  Debug  │  │Optimize │  │  Plan   │
    │ ce-debug│  │autores. │  │ ce-plan │
    │ diagnose│  │ce-optim.│  │brainst. │
    │ tdd     │  │pipeline │  │grill-me │
    └─────────┘  └─────────┘  └─────────┘
    ┌────┴────┐  ┌────┴────┐  ┌────┴────┐
    │Research │  │  Review │  │Pipeline │
    │last30d. │  │ce-code  │  │pipeline │
    │ce-sess. │  │ simpl.  │  │benchmark│
    │qc-helper│  │ sec.aud.│  │self-heal│
    └─────────┘  └─────────┘  └─────────┘
```

## autocontext Integration

If the user expresses a complex, ambiguous, or unfamiliar goal:

1. **First pass** — Use this skill to recommend a known approach
2. **If stuck** — Suggest `autoctx investigate <goal>` for plain-language investigation with evidence and hypotheses
3. **If need multi-role evaluation** — Suggest autocontext MCP tools: `autocontext_evaluate_output` for rubric scoring, `autocontext_read_playbook` for accumulated knowledge

## Priority Rules

- If the user already named a skill: **use it, don't override**
- If multiple skills apply: recommend the most specific first, fallback to general
- If unsure: recommend `ce-brainstorm` or `ce-ideate` to clarify the goal first
- For pure execution (no learning/optimization needed): stay solo, just do it
