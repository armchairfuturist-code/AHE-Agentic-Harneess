---
estimated_steps: 1
estimated_files: 1
skills_used: []
---

# T03: Fix AHEDailyBrief scheduled task

Update AHEDailyBrief scheduled task command from broken tools.ps1 pcauto to ahe-reseed-daily.ps1

## Inputs

- `AHEDailyBrief task config`

## Expected Output

- `AHEDailyBrief running reseed script`

## Verification

schtasks /query /tn AHEDailyBrief
