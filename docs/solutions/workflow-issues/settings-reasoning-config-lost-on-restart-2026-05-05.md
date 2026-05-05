---
title: Settings.json generationConfig Loss on Qwen Code Restart
date: 2026-05-05
category: docs/solutions/workflow-issues/
module: qwen_code_configuration
problem_type: workflow_issue
component: tooling
severity: medium
applies_when:
  - After Qwen Code restarts and model generationConfig entries (enable_thinking, reasoning_effort) disappear from settings.json
  - When relying on CrofAI provider with reasoning models that require enable_thinking or reasoning_effort
  - When the number of configured models unexpectedly drops after a restart
tags:
  - settings-json
  - generationConfig
  - enable-thinking
  - reasoning-effort
  - crofai
  - session-start-hook
  - backup-hygiene
---

# Settings.json generationConfig Loss on Qwen Code Restart

## Context

Qwen Code's `settings.json` loses `generationConfig.extraBody` entries (`enable_thinking`, `reasoning_effort`) whenever Qwen Code restarts. The config file shrinks from 27.8 KB (21 models with full config) to 3.1 KB (13 models with zero generationConfig). The root cause lives somewhere in Qwen Code's internal bundled code (24 MB `cli.js`) and was never definitively isolated — it could be a loading/merge quirk, an internal migration step, or a silent normalization pass. The bundled code's `loadSettings` merge uses a "replace" strategy for `modelProviders`, and the save path preserves genConfig exactly as in memory, so the loss happens during load or at some internal processing step before the file is written.

Since the root cause lives in opaque vendored code that can't be patched, the fix uses a **defense-in-depth** approach that restores config on every session start.

## Guidance

Use a **multi-layered defense** to ensure generationConfig entries survive Qwen Code restarts:

### Layer 1 — SessionStart Hook

File: `C:\Users\Administrator\.qwen\hooks\settings-reasoning-enforcer.js`

A SessionStart hook that runs after Qwen Code loads settings.json. It:
1. Reads the current `settings.json`
2. Checks each model entry under `modelProviders.openai` for `generationConfig.extraBody.enable_thinking`
3. Patches any model missing it:
   - All reasoning models: `enable_thinking: true`
   - DeepSeek + Qwen + Kimi models: `reasoning_effort: "high"`
4. Skips non-reasoning models: `qwen3.5-9b-chat`, `mimo-v2.5-pro`
5. Also updates `.last-good` backup to match

```javascript
// Key patch logic from settings-reasoning-enforcer.js
const REASONING_EFFORT_MODELS = new Set([
  'deepseek-v4-pro', 'deepseek-v4-pro-precision', 'deepseek-v4-flash', 'deepseek-v3.2',
  'qwen3.6-27b', 'qwen3.5-397b-a17b', 'qwen3.5-9b'
]);
const NON_REASONING_MODELS = new Set([
  'qwen3.5-9b-chat', 'mimo-v2.5-pro'
]);

function patchModel(model) {
  if (NON_REASONING_MODELS.has(model.id)) return false;
  if (!model.generationConfig) model.generationConfig = {};
  if (!model.generationConfig.extraBody) model.generationConfig.extraBody = {};
  let changed = false;
  if (model.generationConfig.extraBody.enable_thinking !== true) {
    model.generationConfig.extraBody.enable_thinking = true;
    changed = true;
  }
  if (REASONING_EFFORT_MODELS.has(model.id) &&
      model.generationConfig.extraBody.reasoning_effort !== 'high') {
    model.generationConfig.extraBody.reasoning_effort = 'high';
    changed = true;
  }
  return changed;
}
```

### Layer 2 — Update Script Sync

File: `C:\Users\Administrator\Scripts\update-crofai-models.ps1`

After writing a new settings.json (e.g., after fetching the latest model list from CrofAI), immediately sync the `.last-good` backup. Added after line 354:

```powershell
# Keep .last-good in sync for crash recovery
Copy-Item $SettingsPath "$SettingsPath.last-good" -Force
```

Also expanded the protected model list to prevent accidental removal on health check failure:

```powershell
$ProtectedModels = @(
    "deepseek-v4-pro", "deepseek-v4-pro-precision", "deepseek-v4-flash", "deepseek-v3.2",
    "kimi-k2.6", "kimi-k2.6-precision", "kimi-k2.5", "kimi-k2.5-lightning",
    "glm-5.1", "glm-5.1-precision", "glm-5", "glm-5-lightning",
    "glm-4.7", "glm-4.7-flash",
    "gemma-4-31b-it", "minimax-m2.5",
    "qwen3.5-397b-a17b", "qwen3.5-9b"
)
```

### Layer 3 — Backup Hygiene

- Clean up stale `.orig` and `.backup` files that hold old model lists
- Keep `.last-good` as the single source of truth for recovery
- After updating the model list, manually verify `.last-good` matches `settings.json`

## Why This Matters

Without this defense, every Qwen Code restart silently strips generationConfig from all reasoning models:

- Users relying on CrofAI provider lose `enable_thinking: true` and `reasoning_effort: "high"` silently — no error, no warning
- Models default to non-thinking mode, producing different output without the user noticing
- Debugging is painful because the file looks valid (valid JSON, valid schema) but is missing critical configuration
- The `.last-good` backup becomes stale and useless for restoration if never updated

The layered approach is necessary because the root cause is opaque — buried in Qwen Code's 24 MB bundled `cli.js` and not reproducible on demand. Instead of chasing a ghost in vendored code, the defense ensures correctness at every potential failure point: startup (hook), update (script), and recovery (backup).

## When to Apply

- **Always**: Keep the SessionStart hook registered and enabled. Without it, every restart is a regression.
- **After every model list update**: Run the enhanced update script (v2+) that syncs `.last-good`. A stale backup is worse than no backup.
- **During debugging sessions**: If settings.json config disappears, check in order:
  1. Is the hook running? Check `hooks/` directory.
  2. Is `.last-good` current? Compare file sizes.
  3. Are there stale `.orig` or `.backup` files? Clean them up.
  4. Did the model list change? Check if new models need to be added to the hook's skip list.
- **Never**: Rely on Qwen Code's internal config persistence alone for generationConfig entries. Always layer a SessionStart hook on top.

## Examples

**Before (restart only, no hook):**
- User configures 21 CrofAI models with `enable_thinking: true` and `reasoning_effort: "high"`
- Qwen Code restarts
- settings.json rewritten with 13 models, zero generationConfig
- All models silently lose thinking capability

**After (with hook + script sync):**
- User configures 21 CrofAI models
- Update script writes settings.json AND copies to `.last-good`
- Qwen Code restarts, loads settings.json (stripped version)
- SessionStart hook fires, reads settings.json, detects missing `enable_thinking`
- Hook patches all 21 models with correct generationConfig
- Hook updates `.last-good` to match
- Result: 27.8 KB, 21 models, all with correct generationConfig — transparent to user

**Verification command:**
```powershell
Get-Content C:\Users\Administrator\.qwen\settings.json | ConvertFrom-Json |
  Select-Object -ExpandProperty modelProviders |
  Select-Object -ExpandProperty openai |
  ForEach-Object { $_.id + " -> thinking=" + ($_.generationConfig.extraBody.enable_thinking -eq $true) }
```

## Related

- [Qwen Config Optimization](project/qwen-config-optimization.md) — Initial settings.json investigation and CrofAI integration
- [CrofAI Context Window Fix](project/crofai-context-window-fix.md) — Previous settings.json fix using actual API data
- [Settings.json Bloat Prevention](feedback/settings-bloat-prevention.md) — Keep settings.json under size limits
- [Settings.json Critical Incident](project/settings-json-incident.md) — Previous settings.json size reduction incident
