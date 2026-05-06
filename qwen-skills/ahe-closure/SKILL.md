---
name: ahe-closure
description: Write a session manifest at the end of every Qwen Code session. Tracks skills used, files touched, errors, and patterns for cross-session learning. Invoked automatically by QWEN.md instruction — invoke manually with /ahe-closure if the session is ending without auto-triggering.
---

# AHE Session Closure — Post-Session Manifest

When this session is ending (user indicates done, task is complete, or you are concluding), write a session manifest to `~/.ahe/session-manifests/`.

## Trigger

This skill is invoked automatically by a QWEN.md instruction. If the session is ending and you haven't written a manifest yet, do it now.

## Manifest Format

Write to: `~/.ahe/session-manifests/<YYYYMMDD-HHmmss>.json`

```json
{
  "session_id": "<ISO timestamp>",
  "date": "<YYYY-MM-DD>",
  "duration_minutes": <estimated>,
  "project": "<project or repo name if detectable>",
  "model": "<model used, e.g. deepseek-v4-pro-precision>",
  "skills_used": [
    {"name": "<skill-name>", "invocations": <count>}
  ],
  "files_touched": [
    "<relative file path>"
  ],
  "tools_used": [
    {"tool": "<tool-name>", "count": <int>}
  ],
  "errors_hit": [
    {"error": "<error summary>", "resolved": true/false}
  ],
  "patterns": [
    "<pattern description, e.g. 'edited 3 config JSON files in sequence'>"
  ],
  "outcome": "success|partial|failed",
  "summary": "<one-line summary of what was accomplished>",
  "recommendation": "<if this workflow repeated, should it be a skill? suggest name>"
}
```

## Guidance

- Be honest about errors and partial outcomes — the health forecast skill reads these
- Use `duration_minutes` as a rough estimate based on task complexity and tool calls
- Keep `summary` to one line — detailed content stays in the session log
- `recommendation` is optional — leave null or omit if nothing stood out
- Write to the full absolute path: `C:\Users\Administrator\.ahe\session-manifests\<timestamp>.json`
