# AHE Hermes-ification: Self-Improvement Loop for Qwen Code

**Date**: 2026-05-06

## Context

After analyzing Hermes Agent's self-improvement loop (autonomous skill creation,
daily health forecasts, memory consolidation, proactive research), we adapted
these patterns for the AHE + Qwen Code architecture on Windows.

Key constraint: the desktop runs ~12h/day (not 24/7 like the Hermes laptop).
No daemon, no always-on process. Everything is session-triggered or startup-triggered.

## Hermes Patterns Analyzed

| Hermes Feature | How It Works (Hermes) | AHE Adaptation |
|---|---|---|
| Autonomous skill creation | Agent creates skills after 5+ tool calls via skill_manage | ahe-skill-extract reads session manifests, detects repeatable patterns, generates .qwen/skills/ entries |
| Daily health forecast | Optimization Architect cron at 05:55 | ahe-startup-check.js SessionStart hook auto-fires on first session each day |
| Knowledge prefetch | Midnight Research + Morning Digest cron | ahe-daily-brief researches trending repos/MCP/stack news, writes daily context file |
| Memory consolidation | Weekly Memory Hygiene with FTS5 dedup | ahe-memory-hygiene reads learnings.md + MEMORY.md + manifests, deduplicates, archives stale entries |
| Session reflection | Post-task skill creation | ahe-closure writes structured session manifest at session end |

## Architecture

### 3 Consolidated Commands

| Command | Runs | Frequency |
|---|---|---|
| /ahe-daily | Health forecast + knowledge brief | First session each day |
| /ahe-closure | Session manifest write | End of each session |
| /ahe-weekly | Skill extraction + memory hygiene | Weekly |

### Auto-Trigger (no user action needed)

ahe-startup-check.js is a SessionStart hook that fires on every Qwen Code
session start. It checks a marker file; if this is the first session today,
it reads session manifests, benchmark data, and system health, then outputs
a structured health forecast directly into the conversation context.
Second+ sessions the same day are completely silent.

### Data Flow

Session End                    Session Start
[ahe-closure]                [ahe-startup-check.js]
  writes manifests             reads manifests
~/.ahe/session-manifests/    ~/.ahe/status/<date>.md
  +---> [ahe-skill-extract]
  +---> [ahe-memory-hygiene]

### Directory Layout

~/.ahe/
  session-manifests/   <- Post-session JSON manifests (ahe-closure)
  daily-brief/         <- Knowledge prefetch files (ahe-daily-brief)
  status/              <- Health reports (ahe-startup-check.js)
    .last-startup-date <- Marker: tracks first-session-of-day
  archive/             <- Stale data (ahe-memory-hygiene)

~/.qwen/
  hooks/
    ahe-startup-check.js  <- SessionStart auto-trigger
  skills/
    ahe-closure/         <- Session manifest
    ahe-daily/           <- Daily consolidated command
    ahe-weekly/          <- Weekly consolidated command
    ahe-startup/         <- Health forecast (used by ahe-daily)
    ahe-daily-brief/     <- Knowledge prefetch (used by ahe-daily)
    ahe-skill-extract/   <- Pattern-to-skill extraction
    ahe-memory-hygiene/  <- Knowledge consolidation
