#!/usr/bin/env node
// ahe-startup-check.js — SessionStart hook: AHE daily health forecast
// Auto-runs on the FIRST Qwen Code session of each day.
// Silent on subsequent sessions. Outputs a Hermes-style health report.
//
// Companion skills: ~/.qwen/skills/ahe-daily/, ahe-weekly/, ahe-closure/

const fs = require('fs');
const path = require('path');

const AHE_DIR = path.resolve(process.env.USERPROFILE || 'C:\\Users\\Administrator', '.ahe');
const MANIFESTS_DIR = path.join(AHE_DIR, 'session-manifests');
const STATUS_DIR = path.join(AHE_DIR, 'status');
const BRIEF_DIR = path.join(AHE_DIR, 'daily-brief');
const MARKER_FILE = path.join(STATUS_DIR, '.last-startup-date');
const QWEN_DIR = path.resolve(process.env.USERPROFILE || 'C:\\Users\\Administrator', '.qwen');
const HOOKS_DIR = path.join(QWEN_DIR, 'hooks');
const AUTORESEARCH_DIR = path.resolve(process.env.USERPROFILE || 'C:\\Users\\Administrator', '.autoresearch');

// ── Helpers ──

function today() {
  const d = new Date();
  return d.toISOString().slice(0, 10); // YYYY-MM-DD
}

function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / 1048576).toFixed(1) + ' MB';
}

function safeReadJSON(filepath) {
  try {
    if (!fs.existsSync(filepath)) return null;
    let raw = fs.readFileSync(filepath, 'utf8');
    if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
    return JSON.parse(raw);
  } catch (_) { return null; }
}

function safeReadDir(dirpath) {
  try {
    if (!fs.existsSync(dirpath)) return [];
    return fs.readdirSync(dirpath).sort().reverse();
  } catch (_) { return []; }
}

function safeReadFile(filepath) {
  try {
    if (!fs.existsSync(filepath)) return '';
    return fs.readFileSync(filepath, 'utf8');
  } catch (_) { return ''; }
}

// ── Is this the first session today? ──

function isFirstSessionToday() {
  try {
    if (!fs.existsSync(MARKER_FILE)) return true;
    const marker = fs.readFileSync(MARKER_FILE, 'utf8').trim();
    return marker !== today();
  } catch (_) { return true; }
}

function writeMarker() {
  try {
    if (!fs.existsSync(STATUS_DIR)) fs.mkdirSync(STATUS_DIR, { recursive: true });
    fs.writeFileSync(MARKER_FILE, today(), 'utf8');
  } catch (_) { /* best-effort */ }
}

// ── Checks ──

function checkSessionManifests() {
  const files = safeReadDir(MANIFESTS_DIR);
  if (files.length === 0) return { count: 0, recentErrors: [], recentSessions: [], recurring: [], summary: 'No session manifests yet' };

  const recent = files.slice(0, 5);
  const sessions = [];
  const errors = [];

  for (const f of recent) {
    const fp = path.join(MANIFESTS_DIR, f);
    const data = safeReadJSON(fp);
    if (!data) continue;
    sessions.push(data);
    if (data.errors_hit && data.errors_hit.length > 0) {
      for (const e of data.errors_hit) {
        errors.push({ session: f.replace('.json', ''), error: e.error, resolved: e.resolved });
      }
    }
  }

  // Count recurring errors
  const errorCounts = {};
  for (const e of errors) {
    const key = e.error.slice(0, 60);
    errorCounts[key] = (errorCounts[key] || 0) + 1;
  }

  return {
    count: files.length,
    recentSessions: sessions,
    recentErrors: errors.slice(0, 10),
    recurring: Object.entries(errorCounts).filter(([, c]) => c >= 2).map(([err, count]) => ({ err, count })),
    summary: `${files.length} total, ${sessions.length} recent`
  };
}

function checkBenchmark() {
  const benchDir = path.join(AUTORESEARCH_DIR, 'benchmarks');
  const files = safeReadDir(benchDir);
  if (files.length === 0) return null;

  // Get latest 2 benchmarks
  const latest = files.slice(0, 2).map(f => safeReadJSON(path.join(benchDir, f))).filter(Boolean);
  if (latest.length === 0) return null;

  const current = latest[0];
  const prev = latest.length > 1 ? latest[1] : null;

  const currentScore = current.median_score !== undefined ? current.median_score : (current.max_score || 0);
  const prevScore = prev ? (prev.median_score !== undefined ? prev.median_score : (prev.max_score || 0)) : 0;
  const trend = prev ? currentScore - prevScore : null;

  return {
    score: currentScore,
    maxScore: current.max_score || 100,
    trend: trend !== null ? (trend > 0 ? `+${trend.toFixed(1)}` : trend.toFixed(1)) : null,
    date: (current.timestamp || '').slice(0, 10) || 'unknown'
  };
}

function checkDisk() {
  try {
    const { execSync } = require('child_process');
    const result = execSync('powershell -Command "Get-PSDrive C | Select-Object Used,Free | ConvertTo-Json"', { encoding: 'utf8', timeout: 5000 });
    const data = JSON.parse(result);
    if (!data || !data.Free) return null;
    const free = data.Free;
    const used = data.Used || 0;
    const total = free + used;
    const pct = ((free / total) * 100).toFixed(1);
    return { freeBytes: free, totalBytes: total, freePercent: parseFloat(pct) };
  } catch (_) { return null; }
}

function checkMCP() {
  const settings = safeReadJSON(path.join(QWEN_DIR, 'settings.json'));
  if (!settings || !settings.mcpServers) return { healthy: 0, total: 0, servers: [] };

  const servers = Object.entries(settings.mcpServers);
  return {
    total: servers.length,
    servers: servers.map(([name]) => name),
    healthy: servers.length // optimistic — we can't test connectivity without a session
  };
}

function checkHooks() {
  const required = [
    'rtk-wrapper.js',
    'settings-guardian.js',
    'settings-startup-check.js',
    'post-execution.js',
    'ahe-startup-check.js'
  ];
  const present = [];
  const missing = [];
  for (const h of required) {
    const hp = path.join(HOOKS_DIR, h);
    if (fs.existsSync(hp)) {
      present.push(h);
    } else {
      missing.push(h);
    }
  }
  return { present, missing, total: required.length, ok: present.length };
}

function checkTodayBrief() {
  const briefPath = path.join(BRIEF_DIR, today() + '.md');
  if (fs.existsSync(briefPath)) {
    const content = safeReadFile(briefPath);
    return { exists: true, size: content.length };
  }
  return { exists: false };
}

function checkAHEFile(path) {
  try { return fs.existsSync(path) && fs.statSync(path).size; } catch (_) { return false; }
}

// ── Generate Report ──

function generateReport() {
  const date = today();
  const manifests = checkSessionManifests();
  const benchmark = checkBenchmark();
  const disk = checkDisk();
  const mcp = checkMCP();
  const hooks = checkHooks();
  const brief = checkTodayBrief();
  const lines = [];

  // ── Header ──
  lines.push('========================================');
  lines.push(`  AHE Daily Forecast — ${date}`);
  lines.push('========================================');
  lines.push('');

  // ── Summary Bar ──
  const issues = [];
  if (hooks.missing.length > 0) issues.push(`${hooks.missing.length} hook(s) missing`);
  if (manifests.recurring && manifests.recurring.length > 0) issues.push(`${manifests.recurring.length} recurring error(s)`);
  if (disk && disk.freePercent < 10) issues.push('Low disk space');
  const hasIssues = issues.length > 0;

  const statusEmoji = hasIssues ? '⚠️' : '✅';
  const statusText = hasIssues ? 'Warnings' : 'Healthy';
  lines.push(`Status: ${statusEmoji} ${statusText}`);
  if (hasIssues) {
    lines.push(`Issues: ${issues.join(', ')}`);
  }
  lines.push('');

  // ── Sessions ──
  lines.push('── Sessions ──');
  if (manifests.count === 0) {
    lines.push('  No session manifests yet. Start working to build history.');
  } else {
    lines.push(`  Total: ${manifests.count} | Recent: ${manifests.recentSessions.length} loaded`);
    
    // Recurring errors
    if (manifests.recurring.length > 0) {
      lines.push('  ⚠️ Recurring errors:');
      for (const r of manifests.recurring) {
        lines.push(`    • "${r.err.slice(0, 80)}" (${r.count}x)`);
      }
    }

    // Recent outcomes
    const outcomes = manifests.recentSessions.filter(s => s.outcome).map(s => s.outcome);
    const failed = outcomes.filter(o => o === 'failed').length;
    if (failed > 0) lines.push(`  ❌ ${failed}/${outcomes.length} recent sessions failed`);
    else if (outcomes.length > 0) lines.push(`  ✅ All ${outcomes.length} recent sessions successful`);
  }
  lines.push('');

  // ── Benchmark ──
  lines.push('── Benchmark ──');
  if (benchmark) {
    const trendIcon = benchmark.trend ? (parseFloat(benchmark.trend) >= 0 ? '↗️' : '↘️') : '—';
    lines.push(`  Score: ${benchmark.score}/100 | Trend: ${trendIcon} ${benchmark.trend || 'N/A'} | As of: ${benchmark.date}`);
  } else {
    lines.push('  No benchmark data yet. Run pipeline.ps1 to establish baseline.');
  }
  lines.push('');

  // ── System Health ──
  lines.push('── System Health ──');
  lines.push(`  MCP Servers: ${mcp.healthy}/${mcp.total} configured (${mcp.servers.join(', ')})`);
  lines.push(`  Hooks: ${hooks.ok}/${hooks.total} present`);
  if (hooks.missing.length > 0) {
    lines.push(`  ⚠️ Missing: ${hooks.missing.join(', ')}`);
  }

  if (disk) {
    const icon = disk.freePercent < 10 ? '🔴' : disk.freePercent < 20 ? '🟡' : '🟢';
    const gb = (disk.freeBytes / 1073741824).toFixed(1);
    lines.push(`  Disk: ${icon} ${disk.freePercent}% free (${gb} GB)`);
  } else {
    lines.push('  Disk: ⚪ Unable to check');
  }
  lines.push('');

  // ── Daily Brief ──
  lines.push('── Daily Brief ──');
  if (brief.exists) {
    lines.push(`  ✅ Today's brief exists (${formatBytes(brief.size)})`);
  } else {
    lines.push('  ⏳ Not yet created. Run /ahe-daily or it will generate during this session.');
  }
  lines.push('');

  // ── Recommendations ──
  lines.push('── Recommendations ──');
  const recs = [];

  if (manifests.count === 0) {
    recs.push('[ ] First session detected — no AHE data yet. Run /ahe-closure after work to start building history.');
  } else {
    if (manifests.count >= 5 && manifests.count % 5 < 1) {
      recs.push('[ ] /ahe-weekly — 5+ session manifests ready for skill extraction + memory hygiene');
    }
    if (hooks.missing.includes('ahe-startup-check.js')) {
      recs.push('[ ] Install ahe-startup-check.js — auto health forecasts at session start');
    }
    if (brief.exists === false) {
      recs.push('[ ] /ahe-daily-brief — fetch today\'s trending repos and stack news');
    }
  }

  if (recs.length === 0) {
    lines.push('  ✅ No recommendations — everything looks nominal.');
  } else {
    for (const r of recs) lines.push(`  ${r}`);
  }
  lines.push('');

  // ── Footer ──
  lines.push('========================================');
  lines.push('  AHE auto-check complete. Run /ahe-daily for full startup flow.');

  return lines.join('\n');
}

// ── Main ──

if (!isFirstSessionToday()) {
  process.exit(0); // Silent — already ran today
}

// Generate and output the report
const report = generateReport();
console.error(report); // console.error reaches conversation context

// Write health status file
try {
  if (!fs.existsSync(STATUS_DIR)) fs.mkdirSync(STATUS_DIR, { recursive: true });
  fs.writeFileSync(path.join(STATUS_DIR, today() + '.md'), report, 'utf8');
  writeMarker();
} catch (_) { /* best-effort */ }

process.exit(0); // Always succeed — we're reporting, not failing
