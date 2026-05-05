---
name: Settings.json BOM Corruption Incident
description: UTF-8 BOM from PowerShell Set-Content broke JSON.parse in Qwen Code — 21-model config lost every restart
type: project
---

# Settings.json BOM Corruption Incident

**Date:** 2026-05-05  
**Severity:** Critical  
**Status:** Resolved

## Summary

Qwen Code's `settings.json` kept losing all `generationConfig` entries (`enable_thinking`, `reasoning_effort`) on every restart, shrinking from 27.8 KB (21 models) to 3.1 KB (13 models, no generationConfig). After restart, Qwen Code would ask for initial authorization — a sign that settings.json was treated as corrupt.

## Root Cause

**UTF-8 BOM (byte order mark) from PowerShell's `Set-Content -Encoding UTF8`.**

1. `update-crofai-models.ps1` used `Set-Content -Encoding UTF8 -NoNewline` to write settings.json
2. In PowerShell, `-Encoding UTF8` prepends a BOM (bytes EF BB BF / 0xFEFF) to the file
3. Qwen Code's bundled `strip-json-comments` (v3.0.x) does **NOT** strip BOM before passing content to `JSON.parse`
4. Node.js `JSON.parse` DOES NOT handle BOM on input strings — it throws `SyntaxError`
5. Qwen Code detects the parse failure, renames the file to `settings.json.corrupted.{timestamp}`, and starts with empty settings
6. This triggers the "initial authorization" flow because no valid settings.json exists

**Secondary issue:** The `settings-startup-check.js` hook included `mcpServers` in `requiredSections`, but `mcpServers` is optional and not present in all setups. This was a red herring during debugging — the hook would fail validation but the real corruption was the BOM.

## What Didn't Work

- **Defense layers (settings-startup-check.js, settings-reasoning-enforcer.js):** These hooks never ran because Qwen Code's `loadSettings` failed BEFORE SessionStart hooks fire. The file was renamed to `.corrupted.{timestamp}` at load time (step 2 of startup), which is before hooks execute.
- **Backup restoration:** `.last-good` backup was synced after a `ConvertFrom-Json` | `ConvertTo-Json` round-trip (which strips BOM in PowerShell), so `.last-good` was BOM-free. But Qwen Code's `.orig` recovery happened at load time too, and .orig didn't exist (we had deleted it).

## Fixes Applied

| File | Change | Why |
|------|--------|-----|
| `hooks/settings-startup-check.js` | `requiredSections` removed `mcpServers` | Optional section shouldn't trigger false-corrupt |
| `settings.json` | Re-saved with `[System.IO.File]::WriteAllText(path, content, [System.Text.UTF8Encoding]::new($false))` | Writes UTF-8 without BOM |
| `settings.json.last-good` | Re-synced with BOM-free version | Recovery backup stays clean |
| `update-crofai-models.ps1` | `Set-Content -Encoding UTF8` → `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)` | Prevents BOM re-introduction on model updates |

## How to Prevent

### Rule 1: NEVER use `Set-Content -Encoding UTF8` for JSON files read by Qwen Code

PowerShell 5.1's `-Encoding UTF8` adds BOM. Use these BOM-free alternatives instead:

```powershell
# Option 1: .NET (recommended)
[System.IO.File]::WriteAllText($path, $jsonString, [System.Text.UTF8Encoding]::new($false))

# Option 2: Out-File with -Encoding UTF8NoBOM (PowerShell 6+)
$jsonString | Out-File -Encoding UTF8NoBOM -NoNewline

# Option 3: PowerShell 5.1 workaround
[System.IO.File]::WriteAllLines($path, $jsonString, [System.Text.UTF8Encoding]::new($false))
```

### Rule 2: Verify BOM status in CI/checks

```powershell
$bytes = [System.IO.File]::ReadAllBytes($path)
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Warning "settings.json has BOM — will break Qwen Code startup!"
}
```

### Rule 3: Test with Node.js not just PowerShell

PowerShell's `ConvertFrom-Json` handles BOM silently. Always verify JSON files with:
```powershell
node -e "JSON.parse(require('fs').readFileSync('settings.json','utf8'))"
```

### Rule 4: `mcpServers` should never be in requiredSections of startup hooks

`mcpServers` is an optional feature. If a hook requires it, every clean config without MCP will be flagged as corrupt.

## Related Memory Entries

- [Settings.json Critical Incident](project/settings-json-incident.md) — Earlier settings.json size reduction
- [Settings.json Bloat Prevention](feedback/settings-bloat-prevention.md) — File size limits
- [CrofAI BaseURL Fix](project/crofai-baseurl-fix.md) — Previous crof.ai settings fix
- [Settings-reasoning-config-lost-on-restart](../../docs/solutions/workflow-issues/settings-reasoning-config-lost-on-restart-2026-05-05.md) — Full ce-compound documentation
