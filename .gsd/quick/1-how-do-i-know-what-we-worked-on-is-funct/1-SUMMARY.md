# Quick Task: How do I know what we worked on is functioning for qwen code AHE harness?

**Date:** 2026-05-11
**Branch:** gsd/quick/1-how-do-i-know-what-we-worked-on-is-funct

## What Changed

Created `ahe-doctor.cjs` — a standalone diagnostic script that checks every component of the AHE wiring:

- **Hook files**: ahe-startup-check.js, ahe-session-heartbeat.js
- **Hook syntax**: Node.js parse check
- **settings.json registration**: Both hooks in correct arrays, existing hooks preserved
- **Reseed script**: ahe-reseed-daily.ps1 exists
- **Pipeline findings**: pipeline-findings.json readable with benchmark data
- **Session heartbeat**: Active with tool count and last activity timestamp
- **Session manifests**: Count and latest recorded
- **Scheduled tasks**: AHEDailyBrief and AHENightlyAudit configured and Ready
- **QWEN.md**: AHE section accurate with 4 services documented

Also updated QWEN.md to reference `node .qwen/ahe-doctor.cjs` as a verification command.

## How to Verify

### Quick diagnostic (any time)
```bash
node C:\Users\Administrator\.qwen\ahe-doctor.cjs
```
Or copy to anywhere and run:
```bash
node .qwen/ahe-doctor.cjs
```

### Check by looking at what AHE should do

| Time | What Should Happen | How to Verify |
|------|-------------------|---------------|
| **7:00 AM** | AHEDailyBrief fires → reseed reads pipeline → writes pipeline-findings.json | Check `~/.ahe/status/pipeline-findings.json` exists with today's date |
| **2:00 AM** | AHENightlyAudit fires → pipeline runs research+benchmark+compound | Check `~/.autoresearch/benchmarks/` for new benchmark files |
| **First session of day** | Startup hook fires → health report in conversation context | Look for "AHE Daily Forecast" with Sessions, Benchmark, Pipeline Findings, System Health sections |
| **Every tool call** | Heartbeat writes to session-heartbeat.json | Check `~/.ahe/status/session-heartbeat.json` for tool_count incrementing |
| **Session end** | Closure writes manifest | Check `~/.ahe/session-manifests/` for new JSON files |

### What the health report should look like
```
========================================
  AHE Daily Forecast — 2026-05-11
========================================
Status: ✅ Healthy
── Sessions ──
  Total: N | Recent: N loaded
── Benchmark ──
  Score: XX/100 | Trend: ↗️ +N
── Pipeline Findings ──
  Nightly audit: benchmark XX/100, N research findings
── System Health ──
  MCP Servers: N/N configured
  Hooks: 5/5 present
  Disk: 🟢 XX% free
── Daily Brief ──
  ⏳ Not yet created. Run /ahe-daily
── Recommendations ──
  [/ahe-weekly, /ahe-daily-brief, etc.]
```

## Files Modified
- `.gsd/quick/1-how-do-i-know-what-we-worked-on-is-funct/ahe-doctor.cjs` — diagnostic script
- `C:\Users\Administrator\.qwen\ahe-doctor.cjs` — copy in Qwen Code's directory

## Verification
- 16/16 diagnostic checks pass (✅ ALL CHECKS PASSED)
- All hook files exist with valid syntax
- Both hooks registered in settings.json
- Existing hooks (mcp-startup-cleanup, rtk-token-saver) preserved
- Pipeline findings bridge working (benchmark score 95.8/100)
- Session heartbeat tracking active
- Both scheduled tasks healthy and Ready
- QWEN.md AHE section accurately documents 4 working services
