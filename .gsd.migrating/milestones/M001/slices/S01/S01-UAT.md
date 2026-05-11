# S01: Wire the Startup Hook — UAT

**Milestone:** M001
**Written:** 2026-05-11T19:31:20.778Z

## UAT: S01 — Wire the Startup Hook

### 1. Hook Registration
- [x] Qwen Code starts → no AHE-related errors
- [x] Settings.json contains ahe-startup-check in SessionStart hooks

### 2. Health Report
- [x] First daily session → health report with all sections appears
- [x] Same-day subsequent sessions → silent exit 0

### 3. Reseed Script
- [x] Reseed runs without PowerShell errors
- [x] pipeline-findings.json written to ~/.ahe/status/

### 4. Scheduled Task
- [x] AHEDailyBrief runs at 7AM with exit code 0
- [x] Command references ahe-reseed-daily.ps1, not tools.ps1

