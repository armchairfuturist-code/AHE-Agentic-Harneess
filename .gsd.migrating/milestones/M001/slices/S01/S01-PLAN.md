# S01: Wire the Startup Hook

**Goal:** Register ahe-startup-check.js in settings.json SessionStart hooks. Fix the AHEDailyBrief scheduled task. Verify the hook fires.
**Demo:** startup hook fires every morning, health report appears in Qwen Code. AHEDailyBrief task fixed.

## Must-Haves

- Complete the planned slice outcomes.

## Verification

- Run the task and slice verification checks for this slice.

## Tasks

- [x] **T01: Register startup hook in settings.json** `est:10 min`
  Add ahe-startup-check.js entry to settings.json hooks.SessionStart array
  - Files: `settings.json`
  - Verify: node -e JSON.parse

- [x] **T02: Create reseed script** `est:15 min`
  Create Scripts/ahe-reseed-daily.ps1 that reads pipeline outputs into pipeline-findings.json
  - Files: `ahe-reseed-daily.ps1`
  - Verify: pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/ahe-reseed-daily.ps1

- [x] **T03: Fix AHEDailyBrief scheduled task** `est:10 min`
  Update AHEDailyBrief scheduled task command from broken tools.ps1 pcauto to ahe-reseed-daily.ps1
  - Verify: schtasks /query /tn AHEDailyBrief

## Files Likely Touched

- settings.json
- ahe-reseed-daily.ps1
