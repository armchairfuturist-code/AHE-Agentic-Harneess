# AHE — Agentic Harness Evolution

Personal automation harnesses, self-improving pipelines, and dev tools for AI-augmented development on Windows.

## What is AHE?

AHE is an **intelligence layer** that sits on top of Qwen Code, turning it from a semi-autonomous coding harness into a fully self-improving system. It discovers improvements via nightly research, benchmarks their impact with multi-tract evaluation, applies safe changes with rollback safety, and surfaces findings inside Qwen Code sessions via hooks.

Think of it as the methodology layer GSD adds to pi, but for Qwen Code: **Pi → GSD :: Qwen Code → AHE**.

## Architecture

AHE integrates through Qwen Code's native **hooks system** (SessionStart, PreToolUse):

```
Nightly Pipeline (AHENightlyAudit @ 2AM)
  → research + benchmark + compound
  ↓
Reseed Bridge (AHEDailyBrief @ 7AM + session start)
  → writes pipeline-findings.json
  ↓
Startup Hook (ahe-startup-check.js)
  → reads pipeline findings, generates health report in conversation
  ↓
Heartbeat Hook (ahe-session-heartbeat.js)
  → tracks every tool call for reliable session capture
```

## Current State

**Milestone M001 complete** — Wired the AHE loop:

| Component | Status |
|-----------|--------|
| SessionStart hook | Registered + firing |
| PreToolUse hook | Registered + tracking |
| Reseed bridge | Running daily |
| Pipeline findings | Visible in health report |
| Session manifests | Heartbeat-backed + stale inference |
| AHEDailyBrief (7AM) | Fixed |
| AHENightlyAudit (2AM) | Running |

## Quick Start

```powershell
# Run the improvement pipeline
.\ahe-pipeline\pipeline.ps1

# Check AHE functionality (all 16 components)
node C:\Users\Administrator\.qwen\ahe-doctor.cjs
```

## Core Scripts

See `ahe-pipeline/`: pipeline.ps1 (7-phase orchestration), benchmark.ps1 (25 tests, k=3 multi-rollout, 3-tract scoring), ahe-heavyskill.ps1 (parallel reasoning gate), ahe-backup-rollback.ps1 (snapshot safety).

## Research Foundation

Inspired by AHE (2604.25850), RecursiveMAS (2604.25917), HeavySkill (2605.02396), HAL (2510.11977), ResearchGym (2602.15112), Geometry of Benchmarks (2512.04276), and TRACE (2510.00415).

## License

MIT
