---
name: ahe-closure
description: Write a session manifest at the end of every Qwen Code session. Tracks skills used, files touched, errors, and patterns for cross-session learning. Invoked automatically by QWEN.md instruction — invoke manually with /ahe-closure if the session is ending without auto-triggering.
---

# AHE Session Closure — Post-Session Manifest

You MUST write a session manifest. DO NOT skip this step.

Run this skill every time a session ends — even partial or failed sessions need manifests.

### When to Run

Run this skill when any of these conditions are true:
- The user says goodbye or indicates the session is over
- Your primary task is complete and you are concluding your work
- You detect a session timeout or shutdown signal
- You are about to exit Qwen Code

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

### Step-by-Step Instructions

Follow these steps to produce a complete, high-quality session manifest:

**Step 1: Gather session context**
Review the current conversation for:
- Tool calls made (bash, read, write, edit, etc.)
- Files changed (created, modified, deleted)
- Skills invoked
- Errors encountered and whether they were resolved

**Step 2: Estimate duration_minutes**
Calculate based on first tool call time to now. If unclear, estimate from task complexity:
- Simple task (1-2 files): 5-10 minutes
- Moderate task (3-5 files): 15-30 minutes
- Complex task (5+ files, multi-step): 30-60 minutes
- Multi-hour deep work: 60-240 minutes

**Step 3: Build the manifest JSON**
Use the format below. For each field:
- `session_id`: ISO timestamp when you started writing this manifest
- `date`: Today's date in YYYY-MM-DD format
- `duration_minutes`: Your estimate from Step 2
- `project`: Repository name, project directory name, or "general" if unknown
- `model`: The model you are running as
- `skills_used`: List each skill invoked with approximate invocation count
- `files_touched`: List all files you created or modified this session
- `tools_used`: List each tool you used with approximate count (e.g., bash: 15, read: 8)
- `errors_hit`: Summarize any errors encountered and whether resolved
- `patterns`: Note any recurring patterns (e.g., "edited multiple JSON configs", "debugged API auth flow")
- `outcome`: success (everything worked), partial (some things failed), or failed (primary goal not achieved)
- `summary`: One clear sentence describing what was accomplished
- `recommendation`: Optional — if this workflow repeated, suggest a skill name

**Step 4: Write the manifest**
Write the JSON to the full path: `C:\Users\Administrator\.ahe\session-manifests\<YYYYMMDD-HHmmss>.json`

Example:
```json
{
  "session_id": "2026-05-12T14:30:00Z",
  "date": "2026-05-12",
  "duration_minutes": 45,
  "project": "ahe-agentic-harness",
  "model": "deepseek-v4-pro-precision",
  "skills_used": [
    {"name": "ahe-closure", "invocations": 1},
    {"name": "git-advanced-workflows", "invocations": 2}
  ],
  "files_touched": [
    "qwen-skills/ahe-closure/SKILL.md",
    "qwen-config/QWEN.md"
  ],
  "tools_used": [
    {"tool": "read", "count": 5},
    {"tool": "write", "count": 2},
    {"tool": "bash", "count": 8}
  ],
  "errors_hit": [
    {"error": "File not found on first read attempt", "resolved": true}
  ],
  "patterns": [
    "Added step-by-step instructions to existing skill"
  ],
  "outcome": "success",
  "summary": "Enhanced ahe-closure skill with step-by-step guidance and improved trigger criteria",
  "recommendation": null
}
```

## Guidance

- Be honest about errors and partial outcomes — the health forecast skill reads these
- Use `duration_minutes` as a rough estimate based on task complexity and tool calls
- Keep `summary` to one line — detailed content stays in the session log
- `recommendation` is optional — leave null or omit if nothing stood out
- Write to the full absolute path: `C:\Users\Administrator\.ahe\session-manifests\<timestamp>.json`

### Verification

After writing the manifest, verify it exists:
```
test -f C:\Users\Administrator\.ahe\session-manifests\$(ls -t C:\Users\Administrator\.ahe\session-manifests\ | head -1) && echo "Manifest written successfully" || echo "ERROR: Manifest not found"
```
