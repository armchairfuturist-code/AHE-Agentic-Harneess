---
estimated_steps: 1
estimated_files: 1
skills_used: []
---

# T02: Create reseed script

Create Scripts/ahe-reseed-daily.ps1 that reads pipeline outputs into pipeline-findings.json

## Inputs

- `ahe-startup-check.js`

## Expected Output

- `ahe-reseed-daily.ps1`
- `pipeline-findings.json`

## Verification

pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/ahe-reseed-daily.ps1
