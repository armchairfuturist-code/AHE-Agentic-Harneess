---
title: "Phase 0 Qwen Code Harness Audit and Optimization"
date: 2026-05-04
category: docs/solutions/developer-experience
module: qwen-code-agentic-harness
problem_type: developer_experience
component: tooling
severity: medium
applies_when:
  - Starting work in a new Qwen Code session on this machine
  - Noticing slow hook execution or startup lag
  - After installing or updating plugins
  - When settings.json approaches 15 KB
symptoms:
  - "~60% of 107 skills are never used or dead"
  - "7-process hook chain per Bash call adds ~200ms latency"
  - Broken MCP entries prevent server startup
  - "Settings.json at 14.8 KB approaches guardian limit"
root_cause: inadequate_documentation
resolution_type: workflow_improvement
related_components:
  - self-heal
  - ahe-pipeline
  - settings-json
  - mcp-servers
  - hook-system
  - skill-registry
tags:
  - ahe-harness
  - hook-consolidation
  - mcp-cleanup
  - skill-audit
  - context-efficiency
  - self-heal
  - settings-optimization
  - pipeline-maintenance
---

# Phase 0 Qwen Code Harness Audit and Optimization

## Context

A Qwen Code agentic engineering system accumulated significant bloat over months of iterative development without architectural oversight. The system reached: 107 skills (estimated 55% dead weight), 19 hooks (competing process-heavy PostToolUse hooks), 10 MCP servers (2 with broken JSON config), 4 competing memory stores, and a 480-line self-heal.ps1 patched 8+ times. Cold-start skill enumeration cost 10-15K tokens. Each Bash tool call spawned 7 hook processes (~33KB process overhead, ~200-350ms latency). Settings.json sat at 14.8KB (98% of its 15KB guardian cap). The system worked but was fragile -- each fix addressed one symptom rather than the root cause.

This system was built on the Autonomous AI Engineering (AHE) research paper (arXiv:2604.25850), which defines a self-improvement loop for AI agents: Discover -> Install -> Verify -> Predict -> Rollout -> Attribute -> Distill -> Evolve. The user's implementation reached 10 pipeline cycles with 6/6 MCP servers verified and an 8/8 safety gate pass rate (auto memory: `ahe-pipeline-complete.md`).

## What Was Tried Before (session history)

The AHE harness went through several iterations before this Phase 0 audit:

- **AHE Pipeline (3 observable pillars)** -- component catalog (`ahe-manifest.json`), layered evidence, falsifiable predictions. Pipeline scripts at `Scripts/self-improve.ps1` with phases: Discover -> Benchmark -> Gate -> Attribute -> Compound.
- **Self-Heal System (Pillars 1-5)** -- settings-guardian.js (PreToolUse backup + JSON validation), settings-startup-check.js (session start auto-restore), gsd-statusline.js (health indicator), validate-settings.ps1, sync-obsidian.ps1.
- **RTK Token Optimization** -- rtk-wrapper.js PreToolUse hook intercepts Bash commands, wraps with `rtk` for 60-90% token reduction. Skip patterns for cmd built-ins. ~95ms avg startup.
- **Settings Optimization** -- Production-only models with selective generationConfig. Maintained at ~7.6 KB with -Compress flag.
- **Script Consolidation** -- 33 scripts across 2 locations consolidated into 5 core + archive pattern (auto memory: `consolidation-policy.md`).

### What Didn't Work

1. **self-heal.ps1 was patched 8+ times and still broken.** Each fix addressed one symptom but never the architecture. Specific failures: missing commands in help text, no -Pause flag for double-click, %~dp0 path issues in .bat wrapper, .ps1 vs .bat name collision, Read-Host blocking in piped mode, auto-pause triggering when it shouldn't. **Root cause:** 480 lines / 16 functions / 13 subcommands is too complex for a health check. (session history: `self-heal-rewrite-required.md`)

2. **AHE pipeline had no real evaluation benchmark initially.** Original pipeline was Discover -> Gate -> Compound with no measurement. Predictions always said "Benchmark candidate" but no benchmark was ever run. Fixed later with `benchmark-system.ps1`. (session history)

3. **Settings.json bloated to 41 KB** (60 models x full generationConfig) causing Qwen Code to hang on "initializing" during startup. Fixed by production-only config at 7.6 KB. (auto memory: `settings-bloat-prevention.md`)

4. **RTK regex patterns failed on bare commands.** `NO_BENEFIT_PREFIXES` used `\s` instead of `(\s|$)` so bare `clear` (no args) got incorrectly wrapped. (auto memory: `rtk-regex-pattern.md`)

5. **PowerShell `switch -Wildcard` gotcha.** Missing `; break` caused pattern collisions -- `deepseek-v4-pro-precision` matched both `"deepseek-v4-pro-precision*"` and `"deepseek-v4-pro*"`, second match overwriting the first. (auto memory: `settings-bloat-prevention.md`)

6. **Node.js pipe escaping on Windows.** Pipe characters inside JS strings in `node -e` commands are interpreted by cmd before reaching Node.js. Fix: `String.fromCharCode(124)`. (auto memory: `ahe-harness-build-learnings.md`)

## Guidance

### 1. Skills: Keep conservatively, prune aggressively
A skill SKILL.md file does nothing until triggered. But *all* skills are enumerated during initialization and listed in the `/skills` tool output. Every listed skill costs context tokens. Prune any skill that is:
- Platform-specific (macOS/Ruby/Rails) -- won't work on Windows
- Relies on authentication that doesn't exist (Slack tokens, X API keys)
- Replicates capability available through MCP tools (image generation, web fetch)
- Shadow/beta copies deprecated by the primary skill (`ce-work-beta` vs `ce-work`)

**Don't be over-aggressive.** The user chose to keep design/taste skills, storyforge, and GEO skills because they may be useful in future sessions. Conservative pruning is correct -- the goal is removing *broken* or *redundant* skills, not speculating about future needs.

### 2. Hooks: One process-merge pattern
Multiple PostToolUse Bash hooks each spawn their own Node.js process. Merge them into a single script:
- **Priority:** Context-critical checks first (suppress lower-priority work when context is tight)
- **Passive logging:** Token tracking runs unconditionally
- **Rollback:** Old hook files stay in place for safety

### 3. Settings.json: Stay under 15 KB
Use Node.js `JSON.stringify(obj, null, 2)` for output (NOT PowerShell's 4-space `ConvertTo-Json` which expands ~2.5x). Each new model or MCP server must be offset by a removal or compaction. The guardian enforces a 15 KB cap.

### 4. Self-heal: Thin dispatcher pattern
The old 480-line self-heal.ps1 was replaced by an 80-line self-heal.bat menu that delegates to focused PowerShell scripts. This is the correct AHE recommendation: thin tools.ps1 dispatches to archived scripts. No further refactoring needed.

### 5. MCP JSON keys: No quoting
The `mcpServers` config in settings.json requires bare (unquoted) keys. Quoted keys -- especially those with escaped quotes generated by some tools -- cause silent parsing failures. After any automated MCP config change, verify that keys are unquoted in the raw JSON.

## Why This Matters

The component taxonomy from the AHE paper assigns specific weight to each system layer:
- **Tools (MCP):** +3.3% per improvement
- **Middleware (hooks):** +2.2% per improvement
- **Memory:** +5.6% per improvement
- **Prompt:** -2.3% per change (diminishing returns)

This justifies prioritizing MCP/hook/memory maintenance over prompt tweaking. The Phase 0 audit addressed all three high-value layers: MCP cleanup (removing broken configs), hook consolidation (merging 3 processes into 1), and settings optimization (freeing space for memory entries).

Each unit of engineering work should make subsequent units of work easier, not harder. Before this audit, the system's complexity actively resisted maintenance (8+ patches to self-heal.ps1, each making it harder to fix). After the audit, the system has clear inventory boundaries and safe rollback paths.

## When to Apply

- Settings.json is approaching 15 KB (check with `fs.statSync('settings.json').size`)
- Cold-start feels slow or token-heavy (first response takes noticeably long)
- Hook definitions exceed 2 PostToolUse entries in settings.json
- MCP servers show in settings.json but aren't showing in the client's tool list
- Self-heal/guardian scripts exceed 150 lines or have been edited 3+ times
- Skill count exceeds 80 and includes niche or experimental entries

## Examples

### Skills: Before (107) -> After (103)

Removed 4:
- **ce-dhh-rails-style** -- Ruby/Rails platform, never invoked
- **ce-test-xcode** -- macOS only, won't work on Windows
- **ce-slack-research** -- requires Slack API tokens not configured
- **ce-gemini-imagegen** -- redundant with AionUI builtin MCP image generation

Kept (even though low probability of use):
- All design/taste skills (brandkit, gpt-taste, high-end-visual-design, etc.)
- storyforge (autonomous novel-writing Python pipeline)
- 12 GEO SEO audit skills
- All CE planning/review/coaching skills

### Hooks: 4 Bash PostToolUse entries -> 2

```
Before (3 separate processes per Bash call):
  gsd-context-monitor.js    8.1KB  -- context exhaustion warnings
  autoresearch-trigger.js   8.6KB  -- build/test failure detection
  token-tracker.js          2.0KB  -- RTK compression stats logging

After (1 merged process per Bash call):
  post-execution.js         ~18KB  -- all three, priority-ordered
```

Priority logic in merged hook:
```javascript
// Passive logging always runs
try { runTokenTracker(data); } catch (_) {}

// Context monitor highest priority
let ctxOutput = null;
try { ctxOutput = runContextMonitor(data); } catch (_) {}

// Autoresearch only if context is fine
let arOutput = null;
if (!ctxOutput) {
  try { arOutput = runAutoresearch(data); } catch (_) {}
}

// Emit whichever won priority
const output = ctxOutput || arOutput;
```

Old hook files (`gsd-context-monitor.js`, `autoresearch-trigger.js`, `token-tracker.js`) kept in place for rollback safety.

### MCP Config: 10 servers (2 broken) -> 9 servers (all clean)

Broken entries removed:
- **Duplicate chrome-devtools:** defined twice -- once clean, once with quoted JSON keys (`"\"chrome-devtools\""`) that made the entry unparseable
- **mcp-toolbox:** pointed to nonexistent `C:\Users\Administrator\Scripts\archive\tools.yaml`
- **aionui-image-generation:** had escaped quotes in ALL keys and values (e.g. `"\"AIONUI_IMG_PLATFORM": "gemini\""`), likely generated by an automated tool

Fix pattern (PowerShell):
```powershell
# Remove entries with quoted JSON keys
$mcp.PSObject.Properties | ForEach-Object {
    if ($_.Name -match '^"') { $keysToRemove += $_.Name }
}
# Re-add aionui-image-generation with clean unquoted config
$mcp | Add-Member -NotePropertyName 'aionui-image-generation' -NotePropertyValue @{
    command = 'node'
    args = @('C:\Program Files\AionUi\...\builtin-mcp-image-gen.js')
    env = @{
        AIONUI_IMG_PLATFORM = 'gemini'
        AIONUI_IMG_MODEL = 'gemini-2.5-flash-image'
        # ...
    }
}
```

### Settings.json: 14.8 KB -> 13.4 KB

Root cause: PowerShell `ConvertTo-Json` defaults to 4-space indent, expanding documents ~2.5x. The file hit 35 KB in one intermediate state.

Fix:
```bash
node -e "
  const fs = require('fs');
  const data = JSON.parse(fs.readFileSync('settings.json', 'utf8'));
  fs.writeFileSync('settings.json', JSON.stringify(data, null, 2) + '\n', 'utf8');
"
```

`-Compress` (0-space) removes too much readability for manual edits. 2-space indent is the right balance.

### Self-heal: 480 lines .ps1 -> 80 lines .bat

Before: self-heal.ps1 with 16 functions, 13 subcommands, 8+ cumulative patch layers (session history: `self-heal-rewrite-required.md`).

After: self-heal.bat as thin menu dispatcher delegating to modular PowerShell scripts per function. Implements the "thin tools.ps1 dispatches to archived scripts" pattern from the AHE learnings (auto memory: `ahe-harness-build-learnings.md`).

No rewrite was needed -- the .bat was already in this state when the audit discovered it.

## Multi-Agent Swarm (Ralph Loop)

- **Current limit: 4 agents** across 3 models (deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- **Theoretical max: much higher** — crof.ai provider can handle concurrent requests
- **Constraint is code, not infrastructure:** ThreadPoolExecutor(max_workers=4) is a script-level cap
- **To scale up:** increase max_workers in parallel dispatch, add model-specific rate limit handling
- **Ralph loop:** while-not-done persistent execution with judge verification per iteration
- **Natural language trigger:** `/swarm <goal>` or mention swarm for complex tasks
- **Smoke test passed:** 4 agents in 12.2s (3.3x speedup vs sequential)
- **Model routing per role:** Code/Evolve → DeepSeek V4 Pro, Debugger/Judge → Kimi K2.6, Verify → Flash
- **Pipeline integration:** Invoke-Swarm phase runs after MCP verification
- **Files:** archive/ahe-smoke-test.py, archive/ahe-ralph-loop.py, archive/ahe-model-router.py

## Related

- AHE Research Paper: https://arxiv.org/html/2604.25850v3
- AHE Pipeline Documentation: `docs/solutions/developer-experience/` (this directory)
- Settings Bloat Prevention: `C:\Users\Administrator\.qwen\projects\c--users-administrator\memory\feedback\settings-bloat-prevention.md` (auto memory)
- AHE Harness Build Learnings: `C:\Users\Administrator\.qwen\projects\c--users-administrator\memory\feedback\ahe-harness-build-learnings.md` (auto memory)
- Self-Healing System: `C:\Users\Administrator\.qwen\projects\c--users-administrator\memory\project\self-healing-system.md` (auto memory)
- AHE Pipeline Complete: `C:\Users\Administrator\.qwen\projects\c--users-administrator\memory\project\ahe-pipeline-complete.md` (auto memory)
