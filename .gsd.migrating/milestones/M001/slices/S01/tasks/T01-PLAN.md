---
estimated_steps: 1
estimated_files: 1
skills_used: []
---

# T01: Register startup hook in settings.json

Add ahe-startup-check.js entry to settings.json hooks.SessionStart array

## Inputs

- `ahe-startup-check.js`
- `settings.json`

## Expected Output

- `settings.json with ahe-startup-check.js in hooks.SessionStart`

## Verification

node -e JSON.parse
