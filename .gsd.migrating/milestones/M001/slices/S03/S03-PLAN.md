# S03: Session-End Reliability

**Goal:** Create PreToolUse heartbeat hook and stale-session detection for reliable session capture
**Demo:** every session captured reliably via heartbeat + stale detection + closure trigger

## Must-Haves

- Complete the planned slice outcomes.

## Verification

- Run the task and slice verification checks for this slice.

## Tasks

- [x] **T01: Create and register heartbeat hook** `est:15 min`
  Create ahe-session-heartbeat.js PreToolUse hook that tracks cumulative session state
  - Files: `ahe-session-heartbeat.js`, `settings.json`
  - Verify: node --check ahe-session-heartbeat.js

- [x] **T02: Add stale-session detection to startup hook** `est:10 min`
  Add detectStaleSession() to startup hook to infer ended sessions from stale heartbeats >60 min
  - Files: `ahe-startup-check.js`
  - Verify: node --check ahe-startup-check.js

## Files Likely Touched

- ahe-session-heartbeat.js
- settings.json
- ahe-startup-check.js
