# S03: Session-End Reliability — UAT

**Milestone:** M001
**Written:** 2026-05-11T19:31:20.779Z

## UAT: S03 — Session-End Reliability

### 1. Heartbeat Tracking
- [x] Heartbeat written to ~/.ahe/status/session-heartbeat.json
- [x] Tool count increments correctly across invocations

### 2. Stale Session Detection
- [x] Heartbeat >60 min triggers inferred manifest
- [x] Stale state cleaned up after inference

### 3. Non-Interference
- [x] PreToolUse hooks show rtk-wrapper + heartbeat

