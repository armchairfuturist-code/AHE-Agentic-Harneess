---
name: ahe-daily
description: Run daily startup health forecast + knowledge brief. Consolidated entry point for morning startup flow.
---

# AHE Daily — Startup + Brief

Runs the startup health check AND the daily brief in sequence. Use once per day at the first session.

## What It Does

1. **Health forecast** — Check recent session manifests, benchmarks, MCP, hooks, disk. Pre-fix any drifting subsystems. Write health status to `~/.ahe/status/<date>.md`.
2. **Daily brief** — Research trending repos, MCP releases, stack news. Write brief to `~/.ahe/daily-brief/<date>.md`.

## Manual Invocation

```
/ahe-daily
```

If the daily flow already ran today (health report exists for today's date), this will note it and skip re-running — just read today's brief.

## Trigger Sources

- **Hook auto-trigger**: `ahe-startup-check.js` fires at session start if first session today. Outputs the health report directly to conversation context.
- **Manual fallback**: Run `/ahe-daily` anytime to re-run or catch up.
