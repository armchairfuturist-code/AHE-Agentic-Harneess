---
name: ahe-daily-brief
description: Research trending repositories, MCP releases, tech news, and stack-relevant developments. Writes a daily context file that subsequent sessions load. Invoke with /ahe-daily-brief or triggered at startup.
---

# AHE Daily Brief — Proactive Knowledge Prefetch

Research external knowledge sources and write a daily context brief. This brief is loaded by subsequent sessions to provide relevant context without ad-hoc web searches.

## Trigger Options

- **Manual**: `/ahe-daily-brief` — runs immediately
- **Startup**: Triggered by QWEN.md instruction at session start (preferred)
- **Scheduled**: Via Windows Task Scheduler (runs `C:\Users\Administrator\Scripts\tools.ps1 pcauto`)

## Research Sources

Use the tools you have available — you do NOT need all of them:

### 1. GitHub Trending (via github MCP)
- Search repositories your stack uses: qwen, compound-engineering, openclaw, hermes-agent
- Search for trending MCP servers in the last week
- Check for new releases of: nousresearch/hermes-agent, anthropics/claude-code

### 2. Web Search (via brave-search MCP)
- "latest MCP server tools released this week"
- "AI agent frameworks new releases"
- Stack-specific: Python tooling, TypeScript releases, dev tool news

### 3. Your Session History (via ~/.ahe/session-manifests/)
If manifests exist, check topics the user has been working on recently. Prioritize research relevant to those topics.

## Output

Write to `~/.ahe/daily-brief/<YYYY-MM-DD>.md`:

```markdown
# Daily Brief — YYYY-MM-DD

## Stack Highlights
- [Tool/Repo] — What changed, why it matters

## MCP / Tooling Updates
- [New MCP server] — What it does, whether to install

## Relevant to Recent Work
Based on last N sessions:
- [Topic] — Relevant finding

## Quick Links
- [title](url)
```

## Constraints

- Keep the brief under 5KB — brevity matters more than completeness
- Prioritize items relevant to the user's stack (crof.ai, Qwen Code, AHE, Hermes, CE skills)
- Skip items you're confident are irrelevant — quality over quantity
- If no interesting findings, write a minimal brief: "Nothing notable today"
