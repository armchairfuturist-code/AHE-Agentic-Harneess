# APM (Agent Package Manager) — Evaluation

**Date:** 2026-05-14
**Verdict:** Parked — worth revisiting if harness landscape standardizes

## Overview

[Microsoft APM](https://github.com/microsoft/apm) (v0.13.0, MIT, released 2026-05-13) is a dependency manager for AI agent primitives — skills, prompts, plugins, MCP servers, hooks, and agents. Declared in `apm.yml`, installed with `apm install`.

## What It Does Well

- **Package resolution from GitHub repos** — pull any repo's skills/agents/plugins by name
- **Version pinning** — `apm.lock.yaml` pins content hashes for reproducibility
- **Security scanning** — detects hidden Unicode characters (zero-width, homoglyphs) at install time
- **Multi-harness targeting** — supports Claude Code, Cursor, Copilot, Codex, Gemini, OpenCode, Windsurf in one manifest
- **Clean CLI** — `apm install`, `apm update`, `apm outdated`, `apm audit`

## Why It Doesn't Replace update-plugins.ps1 (Yet)

| Gap | Impact |
|-----|--------|
| **No npm/pip/binary support** | APM only handles git-based skill repos. Our script handles npm, pip, GitHub releases, and local node_modules. A second tool is needed alongside APM. |
| **No Qwen Code target** | APM deploys to `.claude/`, `.cursor/`, `.codex/` — not `~/.qwen/skills/`. Qwen Code reads from its own directory structure. |
| **Empire vs republic** | APM is a framework (single manifest, lockfile, deploy pipeline). Our current approach is protocols-native: AGENTS.md + MCP + symlinks. The A/B test confirmed protocols beat frameworks for this setup. |
| **Bleeding edge** | Released 1 day before evaluation. 2.4k stars but 1,190 commits in rapid development — API may shift. |

## Recommendation

Revisit APM if:
1. Qwen Code adds native APM support (target detection or `~/.qwen/` integration)
2. The project standardizes on a recognized harness (e.g., Claude Code officially)
3. APM adds npm/pip/binary wrappers for non-git dependencies

For now, `update-plugins.ps1` remains the correct tool — it's Qwen Code-aware, handles all dependency types, and we've already extended it to cover git-based repos (gstack, geo-seo, last30days).

## Installed Artifacts

APM CLI binary at `%LOCALAPPDATA%\Programs\apm\bin\apm.cmd`. Test project at `ahe-harness/` in the repo root. Both can be removed.
