---
estimated_steps: 1
estimated_files: 1
skills_used: []
---

# T02: Add stale-session detection to startup hook

Add detectStaleSession() to startup hook to infer ended sessions from stale heartbeats >60 min

## Inputs

- None specified.

## Expected Output

- `stale session inference in startup hook`

## Verification

node --check ahe-startup-check.js
