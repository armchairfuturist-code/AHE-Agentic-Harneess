# AHE — Agentic Harness Evolution

## What This Is

AHE is an autonomous intelligence layer that sits on top of Qwen Code, turning it from a semi-autonomous coding harness into a fully self-improving system. It discovers improvements (MCP servers, skills, config optimizations), benchmarks their impact, applies changes with rollback safety, and surfaces findings inside Qwen Code sessions — all without manual intervention.

## Core Value

The harness improves itself. AHE must reliably run its improvement cycle, surface findings where the user can see them, and never silently break Qwen Code's operation. If everything else is cut, the daily startup health check must still fire and the nightly audit must still run.

## Project Shape

- **Complexity:** simple
- **Why:** Single-machine, single-user, PowerShell+Node.js stack. The architecture is straightforward wiring of existing components. No distributed systems, no multi-user concerns, no external APIs beyond what already exists.

## Current State

AHE has significant infrastructure built: a startup hook script (`ahe-startup-check.js`) with health reporting and isFirstSessionToday gating, skill files for daily/weekly/closure operations, swarm routing in QWEN.md, and a nightly scheduled task running the pipeline. But the startup hook is not registered in settings.json, the reseed script is missing, the daily brief scheduled task is broken, session manifests are barely used (3 total, 5 days stale), and the pipeline's findings never reach Qwen Code's context.

## Architecture / Key Patterns

- Qwen Code's hooks system (`SessionStart`, `PreToolUse`) for lifecycle integration
- Pipeline runs via scheduled task (AHENightlyAudit: research+benchmark+compound at 2AM)
- AHE data under `~/.ahe/` (session-manifests, daily-brief, status, archive)
- QWEN.md as the behavioral instruction layer (complexity routing, swarm config, AHE commands)
- Startup hook injects health report into conversation context via `console.error`

## Capability Contract

See `.gsd/REQUIREMENTS.md` for the explicit capability contract, requirement status, and coverage mapping.

## Milestone Sequence

- [ ] M001: Wire the AHE Loop — Register the startup hook, build the reseed bridge, fix session-end capture, update QWEN.md to reflect working state
