# armchairfuturist-code

Personal automation harnesses, self-improving pipelines, and dev tools for AI-augmented development on Windows.

## AHE Pipeline - Self-Improvement Loop

The core system: an Agentic Harness Engineering (AHE) pipeline inspired by [arXiv:2604.25850](https://arxiv.org/html/2604.25850v3).

### Core Scripts (`ahe-pipeline/`)

| Script | Purpose |
|--------|---------|
| `pipeline.ps1` | Main orchestration |
| `benchmark.ps1` | AHE-weighted benchmark (24 tests, multi-rollout median) |
| `tools.ps1` | Dispatch wrapper |
| `ahe-evolve.ps1` | CE skill linker |
| `ahe-backup-rollback.ps1` | Safety: snapshots + reverts |
| `self-heal.bat` | Menu frontend |
| `bm-module.ps1` | HardTests module |

### Archive Scripts (`ahe-pipeline/archive/`)

Utility scripts: agent-debugger, verify-mcps, security-audit, benchmark-system, full-cleanup, optimize-system, hard-tests, validate-settings and more.

### Utility Scripts (`scripts/`)

sync-obsidian, update-plugins, update-crofai-models.

## Quick Start

```powershell
.\ahe-pipeline\pipeline.ps1
.\ahe-pipeline\pipeline.ps1 -Phase benchmark
.\ahe-pipeline\self-heal.bat
```

## autocontext Integration

The pipeline integrates [autocontext](https://github.com/greyhaven-ai/autocontext) (greyhaven-ai) as a Qwen Code MCP server.

### What it provides
- **Knowledge compounding** — benchmark results exported to autocontext-readable format
- **Playbook accumulation** — cross-session knowledge via autocontext knowledge dirs
- **5-role evaluation** — autocontext MCP tools available as `autocontext_*` tools in Qwen Code

### Setup
Configured in `settings.json` MCP servers. Uses crof.ai OpenAI-compatible provider with `deepseek-v4-pro-precision`.

## License
MIT
