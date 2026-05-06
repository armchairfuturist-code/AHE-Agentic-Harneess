---
name: ahe-startup
description: Run a system health check at the start of a session. Reads recent session manifests, benchmark trends, and debugger data, then pre-fixes any drifting subsystems before starting user work.
---

# AHE Startup — Health Forecast

Run this skill at session start (triggered by QWEN.md instruction or manually with /ahe-startup).

Your job is to check system health and pre-fix issues before the user's main work begins.

## Health Checks

### 1. Session Manifest Review
Read the last 5 session manifest files from `~/.ahe/session-manifests/`. Look for:
- Recurring errors (same error in 2+ sessions → needs attention)
- Partial/failed outcomes
- Unresolved errors (noted but not fixed)

### 2. Benchmark Trend (if available)
Read the latest benchmark from `~/.autoresearch/benchmarks/`. If one exists:
- Check if current score has dropped >3 points from previous
- Check if any category has all failures
- Report the trend direction

### 3. Debugger Insights (if available)
Read the latest debugger output from `~/.autoresearch/debugger/`. If it exists:
- L1 anomalies (score drops)
- L2 flaky tests
- L3 persistent failures

### 4. MCP Connectivity
Quick-check MCP servers by attempting to use each one:
- filesystem, github, brave-search, qwen-memory, context7, context-mode, chrome-devtools

### 5. Hook Integrity
Check that critical hooks exist:
- `~/.qwen/hooks/rtk-wrapper.js`
- `~/.qwen/hooks/settings-guardian.js`
- `~/.qwen/hooks/settings-startup-check.js`
- `~/.qwen/hooks/post-execution.js`

### 6. Disk Space
Check `C:\` has >10% free space.

## Pre-Fix Actions

For any issue found:
- **Settings drift**: Restore from `.last-good` backup
- **Missing hook**: Re-create or note it
- **Recurring error pattern**: Note it as a knowledge item for upcoming sessions
- **Benchmark regression**: Flag for pipeline.ps1 (failures that need investigation)

## Output

Write a health status file to `~/.ahe/status/<YYYY-MM-DD>.md`:

```markdown
# AHE Health — YYYY-MM-DD

## Status: ✅ / ⚠️ / ❌

### Summary
- Sessions reviewed: N (last N days)
- Errors found: N (N resolved, N pending)
- MCP: N/N healthy
- Hooks: N/N present
- Disk: N% free

### Issues Found
- [ ] Unresolved issue 1
- [x] Auto-fixed issue 2

### Recommendations
- [ ] Run pipeline.ps1 for deeper investigation
- [ ] Suggested skill extraction candidate
```

## Reuse Existing Tools

Do NOT re-implement checks that AHE already has:
- For benchmark/debugger analysis: read existing files in `~/.autoresearch/`
- For MCP verification: AHE has `archive/verify-mcps.ps1`
- For backup/rollback: AHE has `ahe-backup-rollback.ps1`
- For full health check: `C:\Users\Administrator\Scripts\archive\self-heal-main.ps1 check`

Reference these scripts rather than duplicating their logic.
