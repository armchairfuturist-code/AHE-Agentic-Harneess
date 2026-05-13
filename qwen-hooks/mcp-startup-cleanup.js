#!/usr/bin/env node
// mcp-startup-cleanup.js — SessionStart hook: kill orphaned MCP server processes
// Uses wmic (built into Windows, no PowerShell needed) for fast process enumeration.
// Prevents MCP process accumulation across Qwen Code sessions.

const { execSync } = require('child_process');

function getNodeProcesses() {
  try {
    // wmic is built into Windows — no PowerShell startup overhead
    const result = execSync(
      'wmic process where "name=\'node.exe\'" get ProcessId,CommandLine /format:csv',
      { encoding: 'utf8', timeout: 5000, stdio: ['ignore', 'pipe', 'ignore'] }
    );
    return result.toString().trim().split('\n').slice(1).map(line => {
      const parts = line.trim().split(',');
      if (parts.length >= 3) {
        return { pid: parseInt(parts[1], 10), cmd: parts.slice(2).join(',') };
      }
      return null;
    }).filter(Boolean);
  } catch { return []; }
}

try {
  const processes = getNodeProcesses();
  const mcpKeywords = ['mcp-local', 'server-filesystem', 'server-github', 'server-brave-search', 'context7-mcp', 'chrome-devtools-mcp', 'qwen-code'];
  const ownPid = process.pid;

  const toKill = processes.filter(p =>
    p.pid && p.pid !== ownPid && mcpKeywords.some(k => p.cmd && p.cmd.includes(k))
  );

  if (toKill.length === 0) process.exit(0);

  for (const p of toKill) {
    try {
      execSync(`taskkill /F /PID ${p.pid}`, { stdio: 'ignore', timeout: 3000 });
    } catch { /* best-effort */ }
  }
} catch { /* best-effort */ }

process.exit(0);
