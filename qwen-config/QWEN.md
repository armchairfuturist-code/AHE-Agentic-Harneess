# Global Qwen Code Instructions

**Last Updated**: 2026-05-13
**Version**: 1.7
**Type**: Qwen Code-Specific Context File (supplements AGENTS.md)

This file contains Qwen Code-specific configuration. Universal project instructions (workflow, coding standards, commit conventions, agent behavior rules) live in AGENTS.md at the repo root. This file only overrides or extends AGENTS.md for Qwen Code-specific behavior.

---

## System Configuration

**User**: Administrator
**OS**: Windows (win32)
**Working Directory**: C:UsersAdministrator
**Shell**: PowerShell via cmd.exe. Prefer writing .ps1 files over inline multi-line PowerShell. Chain commands with -||- on Windows, && on Linux/WSL.

## Plugin Configuration

### Installed Plugins
1. **Compound Engineering (CE)**
   - ~35 ce-* skills
   - ~35 specialized typed agent reviewers

2. **Gstack (Garry Tan)**
   - ~30 skills
   - Compiled browser binary

### Skill Router
Ambiguous queries (no explicit /cmd) route by query type.

#### Step 0: Complexity Auto-Swarm
When a query exhibits 2+ complexity signals, auto-invoke /swarm. Signals: multi-file scope, multi-step work, debugging, research, ambiguity, risk.

#### Step 1: Ambiguity Trigger
Vague exploration -> office-hours, ce-brainstorm, grill-me, or direct.

#### Step 2: Per-Type Routing
Technical plans -> ce-plan, debugging -> ce-debug, code review -> ce-code-review, design -> ce-frontend-design, etc.

### MCP Tool Preferences
- Data: ctx_execute > run_shell_command
- Web: brave-search > web_fetch
- Docs: context7 > web_fetch
- Browser: chrome-devtools > agent-browser
- GitHub: github MCP tools

### Workflow Commands
- /ce-code-review - Review code changes
- /ce-compound - Document solved problems

## Memory System (Qwen Code Native)

### Current Implementation
- **Auto-memory**: File-based memory at .qwen/projects/<project>/memory/
- **save_memory tool**: Cross-session recall facts
- **agentmemory MCP**: Semantic memory via global settings.json

### Context Hierarchy
1. Directory QWEN.md
2. Project root QWEN.md
3. Global QWEN.md (this file)
4. AGENTS.md at repo root

## Key Projects

### AHE-Agentic-Harness
- AGENTS.md at repo root, pipeline scripts

### Compound Engineering Plugin
- CE methodology plugin at C:UsersAdministratorpluginscompound-engineering

## Personal Preferences

- Autonomous development with YOLO mode
- Structured workflow execution
- Compound knowledge across sessions
- Reference AGENTS.md and memory system

## Operating Hooks

Active hooks registered in `~/.qwen/settings.json`:

| Hook | Type | Purpose |
|---|---|---|
| mcp-startup-cleanup.js | SessionStart | Kill orphaned MCP processes from previous sessions |
| ahe-startup-check.js | SessionStart | Daily health: disk space, MCP status, pipeline findings |
| agentmemory-startup.js | SessionStart | Start agentmemory MCP server if not running |
| rtk-wrapper.js | PreToolUse | Wrap Bash commands with RTK/Squeez token compression |
| ahe-session-heartbeat.js | PreToolUse | Track session state for pipeline manifest capture |

Pipeline: heartbeat -> manifest -> `pipeline.ps1 compound` -> learnings

### Notes

- This file supplements AGENTS.md at repo root
- **JSON config files**: Use Node.js, not PowerShell (BOM issue)
- agentmemory MCP is configured globally in settings.json, not project-level `.mcp.json

### Useful Commands
- /context, /clear, /memory, /tokens

---

**Last Updated**: 2026-05-13
**Version**: 1.6
**Type**: Qwen Code-Specific Context File