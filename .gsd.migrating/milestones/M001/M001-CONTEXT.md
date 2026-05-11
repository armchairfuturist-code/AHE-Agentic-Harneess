# M001: Wire the AHE Loop

**Gathered:** 2026-05-11
**Status:** Ready for planning

## Project Description

Wire AHE's existing infrastructure together into a working feedback loop. The startup hook, skill files, session manifests, and pipeline all exist but are disconnected. This milestone connects them.

## Why This Milestone

AHE has substantial infrastructure built but none of it actually works end-to-end. The startup hook isn't registered, session manifests aren't captured, pipeline findings go nowhere visible. The user runs self-heal.bat randomly because AHE doesn't show it's doing anything. This milestone fixes that — making AHE demonstrably active on every session.

## User-Visible Outcome

### When this milestone is complete, the user can:

- Open Qwen Code and see a health forecast with benchmark scores and any issues — every day, automatically
- See what the nightly pipeline found (scores, new MCPs/skills) without checking log files
- Trust that every session is being recorded for later analysis
- Run `/ahe-daily`, `/ahe-closure`, `/ahe-weekly` and have them actually work

### Entry point / environment

- Entry point: Qwen Code session start (auto-triggered via SessionStart hook)
- Environment: local Windows, Qwen Code CLI
- Live dependencies involved: Qwen Code hooks subsystem, scheduled tasks

## Completion Class

- Contract complete means: Files exist, hooks registered, scripts run without errors, data written to disk
- Integration complete means: Startup hook fires inside real Qwen Code session, health report appears in conversation context, pipeline findings are surfaced
- Operational complete means: Works across Qwen Code restarts, handles back-to-back sessions, survives reboot

## Final Integrated Acceptance

To call this milestone complete, we must prove:

- A SessionStart hook fires on first daily Qwen Code session and injects a health report into conversation context
- The AHEDailyBrief scheduled task runs without error
- Session manifests are written (either in-session or via stale-detection)
- Pipeline findings from `.autoresearch/benchmarks/` appear in the startup hook's output

## Architectural Decisions

### Lifecycle Integration via Hooks

**Decision:** Use Qwen Code's native hooks system (SessionStart, PreToolUse) rather than MCP or an external daemon.

**Rationale:** Research of OMX (28k stars), Oh My Pi, GSD2, and Hermes Agent shows meta-layers integrate via hooks + config injection, not MCP. Qwen Code already supports SessionStart and PreToolUse hook types. This matches the industry pattern.

**Alternatives Considered:**
- MCP server — MCP is for external tool exposure (databases, APIs), not agent lifecycle; rejected
- Standalone daemon — Overkill for single-machine, single-user setup; adds failure modes

### Pipeline Visibility

**Decision:** Two-layer: startup hook surfaces findings in conversation context (immediate), reseed script persists to status file (durable).

**Rationale:** Layer 1 gives instant visibility with no risk. Layer 2 provides persistence. Avoids auto-editing QWEN.md until differential measurement proves value.

**Alternatives Considered:**
- Auto-update QWEN.md — Too risky without measurement; could inject unused/untested config
- Only log files — User never checks them; defeats the purpose

### Session-End Capture

**Decision:** PreToolUse heartbeat tracks ongoing state; stale-detection on next startup infers ended sessions; QWEN.md instruction triggers closure in-session.

**Rationale:** No native SessionEnd hook. PreToolUse provides the only reliable hook point. Writing cumulative state per-tool-call is lightweight. Stale detection handles abrupt exits.

**Alternatives Considered:**
- Pure QWEN.md instruction — Unreliable for abrupt exits; only 3 manifests recorded in months
- Wrapper script around qwen launch — Adds friction to startup

## Error Handling Strategy

- All hooks must exit 0 on success and exit 0 on failure (never crash Qwen Code on hook error)
- Reseed script failures are logged but never block the startup hook
- Missing pipeline data is handled gracefully ("No benchmark data yet") rather than crashing
- Stale session detection is pessimistic: if heartbeat > 60 min old, assume session ended

## Risks and Unknowns

- Qwen Code hook execution environment — hooks run in a Node.js context; file system access and child_process are available but env variables may differ from user shell
- PreToolUse hook frequency — fires before every tool call; heartbeat writes must be async/non-blocking to avoid latency
- The `ahe-reseed-daily.ps1` script is called in the startup hook but missing — removing the call or creating the script changes the startup hook

## Existing Codebase / Prior Art

- `.qwen/hooks/ahe-startup-check.js` — Startup hook: health report, isFirstSessionToday gating, reseed call. Correct architecture, not registered.
- `.qwen/hooks/` — 10 other hook files (rtk-wrapper, settings-guardian, error-capture, etc.). Shows hook system works.
- `.qwen/settings.json` — hooks.SessionStart array with mcp-startup-cleanup. Pattern to follow.
- `.qwen/QWEN.md` — AHE Self-Improvement Loop section, Complexity Auto-Swarm section.
- `.ahe/` — Session manifests (3), status (1), empty daily-brief and archive dirs.
- `.autoresearch/benchmarks/` — Pipeline benchmark output.

## Relevant Requirements

- R001 — Startup hook fires reliably on first daily session
- R002 — Pipeline findings surface in Qwen Code context
- R003 — Session manifests capture reliably
- R004 — Broken scheduled tasks fixed
- R005 — Complexity auto-swarm documented in QWEN.md works

## Scope

### In Scope

- Wire `ahe-startup-check.js` in settings.json hooks
- Create `~/.ahe/scripts/ahe-reseed-daily.ps1` that reads pipeline outputs into a findings JSON
- Create `ahe-session-heartbeat.js` PreToolUse hook
- Update startup hook to read findings JSON and create session lock
- Add QWEN.md instruction for in-session closure on PreToolUse end detection
- Fix AHEDailyBrief scheduled task
- Update QWEN.md AHE section to reflect working state

### Out of Scope / Non-Goals

- Differential measurement / per-candidate attribution (M002)
- Full Hermes-style skill pruning and consolidation (M002)
- Auto-updating QWEN.md from pipeline findings (M002)
- Distributed evaluation or multi-machine testing (future)
- Qwen Code version upgrades (operational, not architectural)

## Technical Constraints

- All hooks must exit 0 on error — never crash Qwen Code
- Heartbeat writes must be non-blocking (use `fs.writeFileSync` is OK for small payloads under 1KB)
- Reseed script uses only built-in PowerShell (no external modules)
- Paths use `$env:USERPROFILE` for portability within the machine

## Integration Points

- Qwen Code settings.json — hooks registration
- Qwen Code session lifecycle — SessionStart (startup hook), PreToolUse (heartbeat)
- Pipeline outputs — `.autoresearch/benchmarks/`, `.autoresearch/research/findings.json`
- Scheduled tasks — AHEDailyBrief, AHENightlyAudit
- QWEN.md — AHE section updates

## Testing Requirements

- Unit: Each hook script runs standalone without errors
- Integration: Hook registration in settings.json is valid JSON
- Integration: Health report output contains expected sections (Status, Sessions, Benchmark, System Health)
- Smoke: AHEDailyBrief task runs without PowerShell errors

## Acceptance Criteria

- Startup hook fires and injects health report on first daily session
- Health report includes pipeline findings when available
- Session heartbeat writes to `~/.ahe/status/` on each tool call
- Session manifest is written (either in-session or via stale-detection)
- AHEDailyBrief scheduled task runs cleanly

## Open Questions

- None resolved.

## Slices

- [ ] **S01: Wire the Startup Hook** `risk:low` `depends:[]`
  > After this: startup hook fires every morning, health report appears in Qwen Code. AHEDailyBrief task fixed.
- [ ] **S02: Build the Reseed Bridge** `risk:low` `depends:[S01]`
  > After this: pipeline findings appear in daily health report. Feedback loop closed.
- [ ] **S03: Session-End Reliability** `risk:medium` `depends:[S01]`
  > After this: every session captured. Lost sessions inferred from stale heartbeats.
- [ ] **S04: Update QWEN.md** `risk:low` `depends:[S01]`
  > After this: QWEN.md AHE section reflects working state, not aspirational state.

## Horizontal Checklist

- [x] Every active R### re-read against new code — still fully satisfied?
- [ ] Graceful shutdown / cleanup on termination verified
- [ ] Auth boundary documented — what's protected vs public
