# M001: Wire the AHE Loop

**Vision:** Wire AHE's existing infrastructure into a working feedback loop. The startup hook, skill files, session manifests, and pipeline all exist but are disconnected — no hook fires, findings are invisible, sessions aren't captured. This milestone connects them so AHE is demonstrably active on every session.

## Success Criteria

- User opens Qwen Code and sees a daily health forecast automatically
- User sees pipeline findings without checking log files
- Session manifests are captured for every session (not just 3 in 5 days)
- AHE startup hook does not break existing hooks (mcp-startup-cleanup, rtk-wrapper)

## Slices

- [x] **S01: S01** `risk:low` `depends:[]`
  > After this: startup hook fires every morning, health report appears in Qwen Code. AHEDailyBrief task fixed.

- [x] **S02: S02** `risk:low` `depends:[]`
  > After this: pipeline findings (benchmark scores, discovered MCPs/skills) appear in the daily health report

- [x] **S03: S03** `risk:medium` `depends:[]`
  > After this: every session captured reliably via heartbeat + stale detection + closure trigger

- [x] **S04: S04** `risk:low` `depends:[]`
  > After this: QWEN.md AHE section reflects what actually works, not what was planned

## Boundary Map

Not provided.
