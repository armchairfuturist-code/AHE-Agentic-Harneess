# AHE Agentic Harness - Universal Agent Instructions

**Last Updated**: 2026-05-13
**Version**: 1.1
**Type**: Universal Project Context File

This file is the universal project context for the AHE repo. Qwen Code loads both this file and QWEN.md (which contains Qwen Code-specific config). AionUI auto-detects Qwen Code as a CLI agent and launches it as a subprocess — Qwen Code then reads this file through its native context loading. Future ACP agents reading AGENTS.md will receive the same project instructions.

---

## Repository Overview

THIS repo houses the AHE (Agentic Harness Evaluation) project - a research-focused agentic coding harness that tests the hypothesis that protocol composition (ACP + MCP + AGENTS.md) is all that is needed for effective multi-agent coding, and that hooks/daemons/frameworks provide zero quality improvement over well-authored project context.

### What is Here

- **Pipeline scripts** (ahe-pipeline/) - benchmarking, compounding, model updates, MCP/plugin management. Run as scheduled tasks, not agent hooks.
- **Pipeline adapter** (ahe-pipeline/ahe-gbrain-migrate.ps1) - local file storage for operational data. Replaced old SSH-based gbrain.
- **MCP config** — agentmemory MCP is configured globally in `~/.qwen/settings.json`, not in this repo.
- **Qwen-specific config** (qwen-config/) - hooks, channel config, skill router (Qwen-only).
- **Hook cleanup** (qwen-hooks/) - operational hooks only (disk health, MCP cleanup, session heartbeat).

### NOT in This Repo

- **GSD2** - Separate pi-session planning engine. Lives in .gsd/, never runs inside Qwen Code sessions.
- **agentmemory** - MCP server runs from .mcp.json config.
- **~/.ahe/** - Runtime data: manifests, briefs, benchmark outputs.
- **~/.autoresearch/gbrain/** - Local operational data store.

---

## Architecture: Four Layers, One Context File

### Design Principle: Protocols Over Frameworks

Research-verified three-layer stack:
- **MCP** - Agent-Tool communication
- **ACP** - Agent-Editor communication (for ACP-compatible editors)
- **AGENTS.md** - Project-level context for all agents

The A/B test confirms: hooks provide zero quality improvement while adding 7.9x latency. Protocol-native architecture wins.

### The Four Layers

1. **AionUI + Qwen Code** - Daily execution: build, fix, ship. AionUI provides the GUI wrapper (multi-agent, remote WebUI, MCP unified management). Qwen Code provides the agent engine.
2. **GSD2 CLI** (pi session) - Deep design, planning, research. Standalone — never runs inside Qwen Code.
3. **Pipeline scripts** (scheduled tasks) - Benchmarking, compounding, automation.
4. **AGENTS.md** (this file) - Universal project instructions consumed by all layers.

---

## Workflow Methodology

### Core Process

1. **Discuss** - Understand the problem, surface assumptions
2. **Plan** - Minimal verifiable plan with clear success criteria
3. **Execute** - Surgical changes, minimum scope
4. **Verify** - Work is not done until verification passes
5. **Learn** - Compound knowledge, update docs, update memory

### Task Types and Verification

| Task Type | Verification Method |
|---|---|
| Bug fix | Reproduce, fix, verify gone |
| Test addition | Run failing, pass after implementation |
| Documentation | Check paths, commands, examples |
| Configuration | Validate syntax, verify tool behavior |
| Refactoring | Run test suite, zero regressions |
| Script/automation | Run with inputs, exit code 0 |
| UI/browser | Visual verification, a11y check |
| Research | Cite sources, verify claims |

---

## Coding Standards

### General Rules

- Follow existing conventions. Minimum code. No speculative features.
- Match style - conformance over taste.
- Fail loud: surface uncertainty, do not hide it.

### Commit Conventions

- **Prefix by intent**: feat:, fix:, docs:, refactor:, chore:, test:
- **Include scope**: fix(cli):, feat(agent):
- **Atomic commits**: Focused and self-contained
- **No breaking markers without user confirmation**: Triggers major version bumps

---

## Karpathy Principles

### Think Before Coding
- State assumptions. Surface tradeoffs. Ask when uncertain.
- Goal-driven: transform tasks into verifiable goals, loop until verified.

### Simplicity First
- Minimum code. No speculative features. No unnecessary abstractions.

### Surgical Changes
- Touch only what is necessary. Clean only your changes. Match style.

### Verification Gates
- Goal -> Implement -> Verify -> Loop. Define success criteria before coding.

---

## Agent Behavior Rules

1. **Model for Judgment Only** - LLMs for classification/drafting/summarization, not routing/retries/status-codes
2. **Token Budgets Are Advisory** - Be concise, checkpoint, start fresh when approaching limit
3. **Surface Conflicts** - Pick one pattern, explain why, flag the other
4. **Read Before You Write** - Understand existing code before adding to it
5. **Tests Verify Intent** - Encode WHY, not just WHAT
6. **Checkpoint After Steps** - Summarize what is done, verified, left
7. **Match Conventions** - Conformance over taste inside the codebase
8. **Fail Loud** - Say so if you are not sure. Do not hide uncertainty.

---

## Pipeline Scripts

| Script | Purpose | Schedule |
|---|---|---|
| ahe-pipeline/pipeline.ps1 | Nightly: research-benchmark-compound | Nightly (2AM) |
| ahe-pipeline/ahe-heavyskill.ps1 | HeavySkill evaluation + auto-tuning | After benchmark |
| ahe-pipeline/consolidate.ps1 | Consolidate manifests into learnings | After compound |
| ahe-pipeline/benchmark.ps1 | Run benchmarks | Nightly |
| scripts/update-crofai-models.ps1 | Update crofai + GSD2 model configs | Weekly |
| scripts/update-plugins.ps1 | Update plugins and extensions | Weekly |
| scripts/sync-obsidian.ps1 | Sync manifests to Obsidian vault | On demand |

---

## MCP Servers

Configured globally in Qwen Code's `settings.json` (not in this repo):

| Server | Purpose |
|---|---|
| agentmemory | Semantic memory (expects server on localhost:3111) |
| filesystem | Project filesystem access |
| github | GitHub API |
| brave-search | Web search |
| context7 | Live docs context |
| chrome-devtools | Browser automation |

Additional servers (brave-search, context7, filesystem, github) configured per-agent.

---

## Operational Hooks (Remaining)

| Hook | Type | Purpose |
|---|---|---|
| ahe-startup-check.js | SessionStart | Daily health: disk, MCP, pipeline findings |
| mcp-startup-cleanup.js | SessionStart | Clean stale MCP processes |
| ahe-session-heartbeat.js | PreToolUse | Session state tracking for manifest capture |

Pipeline: heartbeat -> manifest -> pipeline.ps1 compound -> learnings

---

## AionUI Execution Surface

**Config file:** `%APPDATA%\AionUi\AionUi.exe` or your installed path.

AionUI auto-detects Qwen Code as an installed CLI agent. Launch AionUI, select Qwen Code from the agent list, and Qwen Code reads QWEN.md + AGENTS.md for context through its native loading chain. AionUI provides:

- **GUI wrapper** with multi-agent tabs for parallel sessions
- **Remote WebUI** — accessible from a phone or tablet for on-the-go work
- **MCP unified management** — AionUI's built-in MCP manager handles server lifecycle
- **Auto-detection** of any installed CLI agent (Qwen Code, Codex, Claude Code, etc.)

AionUI does not consume AGENTS.md itself — it launches agents that do. The repo context flows: **AionUI → Qwen Code → QWEN.md + AGENTS.md**.

## Platform Notes

### Windows
- PowerShell via cmd.exe. Write .ps1 files. Chain with -||-
- JSON files: use Node.js (not PowerShell Set-Content, which adds BOM)
- Process queries: wmic (110ms) over Get-CimInstance (1,271ms)
- Hooks: pwsh -NoProfile (~8x faster than powershell.exe)

### GSD2
Separate pi-session environment. Uses GSD methodology with milestone/slice/task decomposition. .gsd/ directory. Does not run in Qwen Code sessions.

### Data Dirs
- ~/.ahe/ - manifests, briefs, benchmarks, pipeline logs
- ~/.autoresearch/gbrain/ - operational data store
- ~/.qwen/hooks/ - hook implementations

---

## Document Evolution

Universal project context file for all agents working on this repo. Pair-file alongside QWEN.md (Qwen Code-specific config). Created M006 based on:

- A/B test: hooks provide zero quality improvement (2026-05-13, n=5)
- Research: AHE 2604.25850, RecursiveMAS 2604.25917, HeavySkill 2605.02396, HAL 2510.11977, ResearchGym 2602.15112, TRACE 2510.00415
- Decision: protocols over frameworks (ACP + MCP + AGENTS.md)
- Migration: Gbrain to local storage + agentmemory (D015)

If >30 days stale, audit for drift before starting new work.
