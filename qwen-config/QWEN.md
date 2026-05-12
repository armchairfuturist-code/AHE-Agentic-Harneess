# Global Qwen Code Instructions

## System Configuration

**User**: Administrator
**OS**: Windows (win32)
**Working Directory**: C:\Users\Administrator
**Shell**: PowerShell via cmd.exe. Prefer writing `.ps1` files over inline multi-line PowerShell. Chain commands with `-||-` on Windows, `&&` on Linux/WSL.

## Development Workflow

### YOLO Mode
- **Enabled**: Yes (auto-approve tool use)
- **Preference**: Autonomous development with minimal interruptions
- **Safety**: Still follow verification gates and review steps

### CE Workflow Methodology
- **CE**: Compound Engineering for knowledge compounding and cross-session retention
- **Process**: Brainstorm → Plan → Work → Review → Compound

## Coding Standards

### General
- Follow existing project conventions and patterns
- Write tests for all new features
- Use atomic commits with clear messages
- Reference AGENTS.md for workflow guidelines

### TypeScript/JavaScript
- Prefer explicit mappings over implicit magic
- Keep target-specific behavior in dedicated converters/writers
- Preserve stable output paths and merge semantics

### Commit Conventions
- **Prefix**: Based on intent (feat:, fix:, docs:, refactor:, etc.)
- **Scope**: Include component scope (skill/agent name, plugin area)
- **Format**: `type(scope): description`

## Plugin Configuration

### Installed Plugins
1. **Compound Engineering (CE)**
   - ~35 ce-* skills (brainstorm, plan, work, code-review, debug, etc.)
   - ~35 specialized typed agent reviewers

2. **Gstack (Garry Tan)**
   - ~30 skills (office-hours, GEO, brandkit, design, safety, browser)
   - Compiled browser binary (Playwright/Puppeteer)

### Skill Router
Ambiguous queries (no explicit `/cmd`) route by query type.

#### Step 0: Complexity Auto-Swarm (fires first, overrides all routing)
When a query exhibits **2+ complexity signals**, auto-invoke `/swarm` with appropriate params instead of handling solo. Complexity signals:
- **Multi-file scope**: task affects 3+ files, cross-module refactor, architecture change
- **Multi-step work**: task requires 5+ sequential operations to complete
- **Debugging**: root cause unknown, spans multiple systems, needs investigation
- **Research/analysis**: needs external research, comparison, or evaluation
- **Ambiguity**: requirements are vague, multiple valid approaches exist
- **Risk**: changes affect production, data, auth, or deployed infrastructure

| Complexity Level | Swarm Mode | Agents | Loops |
|---|---|---|---|
| Medium (2-3 signals) | `/swarm` | 4 | 1 |
| High (4-5 signals) | `/swarm-deep` | 6 | 3 |
| Critical (6 signals) | `/swarm-custom` | 8 | 5 |

If query explicitly invokes a specific tool/skill, skip auto-swarm and use the explicit command. If user says "swarm" in their query, route to swarm skill immediately.

#### Step 1: Ambiguity Trigger (fires first, overrides per-row routing)
Queries starting with "help me think through", "I'm thinking about", "I'm not sure how to", or vague exploration → classify into:

| If query is about... | Show fork | Default |
|---|---|---|
| A product/startup idea (validation, market, users) | `office-hours` / `ce-brainstorm` / direct | office-hours |
| A technical/architecture problem | `ce-brainstorm` / `ce-plan` / direct | ce-brainstorm |
| Stress-testing an existing plan/design | `grill-me` / `ce-brainstorm` / direct | grill-me |
| Genuinely fuzzy exploration | `ce-brainstorm` / `ce-ideate` / direct | direct |

#### Step 2: Per-Type Routing (only reached if Step 1 does not fire)

| Query Type | Skill | Notes |
|---|---|---|
| Product/startup idea validation | `office-hours` | YC forcing questions, premise challenge, design doc |
| Non-product exploration (arch, process) | `ce-brainstorm` | Collaborative requirements doc |
| Generate ideas/directions | `ce-ideate` | Grounded idea generation, not requirements |
| Technical plan needed | `ce-plan` | Structured multi-step plan |
| Debug root cause | `ce-debug` / `investigate` | Systematic diagnosis |
| Code quality review | `ce-code-review` | Panel of typed agent reviewers |
| Document problems solved | `ce-compound` | Save learnings to docs/solutions/ |
| Visual design / UI | `ce-frontend-design` / `design-review` | design-review uses chrome-devtools MCP for live-site audit |
| Browser testing | `ce-test-browser` / `qa` | |
| Web scraping | `scrape` → `skillify` | gstack pipeline |
| Geo/SEO audit | `geo-audit` (orchestrator) | Runs 7 sub-audits |
| Brand kit | `brandkit` | Premium brand-guidelines boards |
| Safety scoping | `freeze` / `guard` / `unfreeze` | gstack directory lock |
| PDF generation | `make-pdf` (gstack binary) | Requires cloned gstack at plugins/gstack |
| Everything else | handle directly, no skill | Default path |

### MCP Tool Preferences
Prefer these tools for token efficiency:
- **Data analysis / search**: `ctx_execute` / `ctx_execute_file` > `run_shell_command`
- **Web search**: `brave-search` (MCP) > `web_fetch`
- **File reads**: `read_file` (standard); `ctx_execute_file` for large/log files
- **File writes**: `write_file` / `edit` only
- **Documentation lookups**: `context7` (library docs) > `web_fetch`
- **Browser**: `chrome-devtools` (MCP) > agent-browser skill
- **GitHub**: `github` MCP tools (search, read, push, PRs)
- **Batch I/O**: `ctx_batch_execute` with concurrency 4-8 for parallel API calls

### Workflow Commands
- `/ce-code-review` - Review code changes
- `/ce-compound` - Document solved problems

## Memory System

### Current Implementation
- **Native QWEN.md**: Hierarchical context system (this file)
- **Auto-memory**: Persistent file-based memory at `.qwen/projects/<project>/memory/` — user info, feedback, project context, and reference pointers indexed in MEMORY.md
- **Gbrain**: Shared brain at `100.102.182.39`. See `.qwen/skills/gbrain/SKILL.md` for full protocol (brain-first lookup, auto-save signals, maintenance schedule)
- **`save_memory` tool**: Appends concise facts to context for cross-session recall
- **MCP Servers**: brave-search, context-mode, context7, filesystem, chrome-devtools, github, aionui-team-guide, aionui-image-gen, gbrain

### Context Hierarchy
1. Current directory QWEN.md
2. Parent directory QWEN.md files
3. Project root QWEN.md
4. Global QWEN.md (this file)

## Scripts Location

**Scripts Folder**: C:\Users\Administrator\Scripts

**Available Scripts**:
- `update-plugins.ps1` - Intelligent plugin/extension update manager

## Key Projects

- **Location**: C:\Users\Administrator\Documents\Projects\

### Compound Engineering Plugin
- **Location**: C:\Users\Administrator\plugins\compound-engineering
- **Purpose**: CE methodology for structured autonomous development
- **Workflow**: CE methodology

## Personal Preferences

### Development Style
- Prefer autonomous development with YOLO mode
- Use CE workflow for structured execution
- Compound knowledge across sessions
- Reference memory system for context retention

## Karpathy Development Principles

### Core Philosophy: Think Before Coding
- **State Assumptions Explicitly**: Before writing code, articulate what you assume to be true
- **Surface Tradeoffs**: Present multiple interpretations when uncertain; don't make silent decisions
- **Ask Questions When Uncertain**: Clarify requirements before implementing
- **Goal-Driven Execution**: Transform tasks into verifiable goals and loop until verified

### Simplicity First
- **Write Minimum Code**: Solve the problem with the smallest possible change
- **No Speculative Features**: Only implement what's explicitly needed
- **No Unnecessary Abstractions**: Avoid over-engineering; match existing patterns
- **No Impossible Error Handling**: Don't handle scenarios that can't occur

### Surgical Changes
- **Touch Only What's Necessary**: Modify only files directly related to the task
- **Clean Up Only Your Changes**: Don't refactor adjacent code unless requested
- **Match Existing Style**: Follow the project's conventions precisely
- **Atomic Commits**: Each change should be focused and self-contained

### Verification Gates
- **Goal → Implement → Verify → Loop**: Each step has a clear check before proceeding
- **Test-Driven Approach**: Write tests to reproduce issues before fixing
- **Success Criteria**: Define verifiable goals in the Plan phase
- **Gate in Work Phase**: Verify goals are met before moving to Review

### Integration with Existing Workflows
- **YOLO Mode**: Add pre-tool-use checks for assumption surfacing and simplicity validation
- **CE Workflow**: Embed goal-driven execution into phase plans with verifiable checks
- **Memory System**: Store feedback on when these principles succeed or fail for continuous improvement
- **AutoResearch**: Phase 0 of any infrastructure iteration must check QWEN.md for staleness — config changes are invisible until next session

### QWEN.md Governance
- This file is the single highest-leverage config. Treat as a living document, not bootstrap.
- Every infrastructure change (plugin update, new MCP server, new skill) MUST update relevant sections here
- Staleness canary: `Last Updated` date. If >7 days, audit for drift before starting new work

### Extended Rules (AHE supplement)
- **Model for Judgment Only** — use Qwen for classification, drafting, summarization, extraction. Do NOT use Qwen for routing, retries, status-code handling, or deterministic transforms. If a status code answers the question, plain code answers it. [Anecdotes](../.qwen/lessons/rules-5-12-anecdotes.md)
- **Token Budgets Are Not Advisory** — per-task: 5,000 tokens; per-session: 40,000. If a task is approaching budget, summarize and start fresh. Do not push through. Surfacing the breach > silently overrunning.
- **Surface Conflicts, Don't Average Them** — if two existing patterns contradict, pick one (more recent / more tested), explain why, flag the other for cleanup. Average code that satisfies both rules is the worst code.
- **Read Before You Write** — before adding code in a file, read its exports, the immediate caller, and any obvious shared utilities. If you don't understand why existing code is structured the way it is, ask before adding to it. "Looks orthogonal to me" is the most dangerous phrase in this codebase.
- **Tests Verify Intent, Not Just Behavior** — every test must encode WHY the behavior matters, not just WHAT it does. A test like `expect(getUserName()).toBe('John')` is worthless if the function takes a hardcoded ID. If you can't write a test that would fail when business logic changes, the function is wrong.
- **Checkpoint After Every Significant Step** — after completing each step in a multi-step task: summarize what was done, what's verified, what's left. Don't continue from a state you can't describe back. If you lose track, stop and restate.
- **Match the Codebase's Conventions, Even If You Disagree** — if the codebase uses snake_case and you'd prefer camelCase: snake_case. If it uses class-based components and you'd prefer hooks: class-based. Disagreement is a separate conversation. Inside the codebase, conformance > taste. If you genuinely think the convention is harmful, surface it — don't fork it silently.
- **Fail Loud** — if you can't be sure something worked, say so explicitly. "Migration completed" is wrong if records were skipped silently. "Tests pass" is wrong if any were skipped. "Feature works" is wrong if you didn't verify the edge case. Default to surfacing uncertainty, not hiding it.


## AHE Self-Improvement Loop

4 consolidated services implementing a closed feedback loop between the nightly pipeline and Qwen Code sessions.

### Auto-Triggered (no action needed)

**SessionStart hook** (`.qwen/hooks/ahe-startup-check.js`) — registered in `settings.json`. Fires on the first Qwen Code session each day. Reads session manifests, benchmark trends, system health, and pipeline findings from the nightly audit. Outputs a health forecast directly into conversation context. Includes pipeline findings (score trends, new MCPs, research). Silent on subsequent same-day sessions.

**PreToolUse hook** (`.qwen/hooks/ahe-session-heartbeat.js`) — registered in `settings.json`. Writes cumulative session state (tool calls, tool names) on every tool invocation. Enables session manifest capture even on abrupt exits. If a session goes silent >60 minutes, the next startup hook infers it ended and writes an inferred manifest.

**AHEDailyBrief** — scheduled task, runs daily at 7AM. Reads pipeline benchmark outputs and research findings into `~/.ahe/status/pipeline-findings.json`, which the SessionStart hook surfaces in the daily health report. Replaces the previously broken `tools.ps1 pcauto` path.

**AHENightlyAudit** — scheduled task, runs nightly at 2AM. Runs `pipeline.ps1 -Phase research,benchmark,compound`. Independent of the hook system.

### Commands
| Command | Runs | Frequency |
|---|---|---|
| `/ahe-daily` | Startup health forecast + daily knowledge brief | Daily, first session |
| `/ahe-closure` | Session manifest — writes `~/.ahe/session-manifests/<date>.json` | End of each session (heartbeat-backed) |
| `/ahe-weekly` | Skill extraction + memory consolidation | Weekly (Sundays) — needs 5+ manifests |


### End-of-Session Protocol

**Trigger:** When the user indicates the session is ending, your task is complete, or you are concluding your work.

**Imperative steps:**
1. Read ~/.qwen/skills/ahe-closure/SKILL.md for the manifest format and guidance
2. Write a session manifest to ~/.ahe/session-manifests/<YYYYMMDD-HHmmss>.json following the skill instructions
3. Confirm the manifest was written successfully

**Why it matters:** The manifest is required — without it, the self-improvement pipeline cannot learn from this session.

### Data Directory
All AHE data: `~/.ahe/` (session-manifests/, daily-brief/, status/, archive/)
## Notes

- This file is part of the hierarchical QWEN.md context system
- Project-specific QWEN.md files override these settings
- Directory-specific QWEN.md files take precedence

### Notes
- For JSON config files (settings.json): use Node.js `JSON.parse`+`stringify` (utf-8). Never use PowerShell `Set-Content`/`Out-File` — they add a UTF-8 BOM that breaks Node.js parsers. Invoke the `settings-edit` skill for safe edits.

### Useful CLI Commands
- `/context` — View which context files are currently loaded
- `/clear` — Reset conversation
- `/memory` — Refresh or load memory
- `/tokens` — Check token usage

---

**Last Updated**: 2026-05-10
**Version**: 1.5
**Type**: Global Context File
