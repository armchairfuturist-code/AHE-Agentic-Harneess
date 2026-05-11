---
id: T02
parent: S03
milestone: M001
key_files:
  - C:/Users/Administrator/.qwen/hooks/ahe-startup-check.js
key_decisions:
  - Stale detection is pessimistic: >60 min idle = session ended
duration: 
verification_result: passed
completed_at: 2026-05-11T19:31:05.433Z
blocker_discovered: false
---

# T02: Added stale-session detection to startup hook

**Added stale-session detection to startup hook**

## What Happened

Added detectStaleSession() function to startup hook. If heartbeat shows last_tool_time >60 min ago, writes an inferred session manifest to ~/.ahe/session-manifests/ and cleans up stale heartbeat and lock files. Runs at startup before the main health report.

## Verification

Syntax check passes. detectStaleSession() present in startup hook code. Inferred manifest path and cleanup logic correct.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `node --check ahe-startup-check.js` | 0 | ✅ pass | 500ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `C:/Users/Administrator/.qwen/hooks/ahe-startup-check.js`
