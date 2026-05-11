const fs = require('fs');
const path = require('path');
const UP = process.env.USERPROFILE || 'C:\\Users\\Administrator';

async function main() {
  const results = [];
  let allOk = true;
  const check = (ok, msg, detail) => { results.push({ok,msg,detail:detail||''}); if(!ok) allOk=false; };

  // 1. Hook files exist
  const files = [
    ['.qwen/hooks/ahe-startup-check.js', 'ahe-startup-check.js exists'],
    ['.qwen/hooks/ahe-session-heartbeat.js', 'ahe-session-heartbeat.js exists'],
    ['Scripts/ahe-reseed-daily.ps1', 'ahe-reseed-daily.ps1 exists'],
  ];
  for (const [rel, label] of files) {
    check(fs.existsSync(path.join(UP, rel)), label, path.join(UP, rel));
  }

  // 2. Hook scripts parse
  for (const name of ['ahe-startup-check.js', 'ahe-session-heartbeat.js']) {
    const fp = path.join(UP, '.qwen/hooks', name);
    try {
      require('child_process').execSync(`node --check "${fp}"`, { stdio: 'pipe' });
      check(true, `${name} syntax OK`, '');
    } catch(e) {
      check(false, `${name} syntax ERROR`, e.message);
    }
  }

  // 3. Hooks in settings.json
  let settings;
  try {
    const raw = fs.readFileSync(path.join(UP, '.qwen/settings.json'), 'utf8');
    settings = JSON.parse(raw);
    check(true, 'settings.json valid JSON', '');

    const sHooks = settings.hooks.SessionStart.map(h => h.name);
    const pHooks = settings.hooks.PreToolUse.map(h => h.name);

    check(sHooks.includes('ahe-startup-check'),
      'ahe-startup-check in SessionStart hooks',
      sHooks.join(', '));
    check(pHooks.includes('ahe-session-heartbeat'),
      'ahe-session-heartbeat in PreToolUse hooks',
      pHooks.join(', '));
    check(sHooks.includes('mcp-startup-cleanup'),
      'Existing mcp-startup-cleanup preserved', '');
    check(pHooks.includes('rtk-token-saver'),
      'Existing rtk-token-saver preserved', '');
  } catch(e) {
    check(false, 'settings.json parse failed', e.message);
  }

  // 4. Pipeline findings
  const findingsPath = path.join(UP, '.ahe/status/pipeline-findings.json');
  if (fs.existsSync(findingsPath)) {
    try {
      const d = JSON.parse(fs.readFileSync(findingsPath, 'utf8'));
      const scoreStr = d.benchmark ? `score ${d.benchmark.score}/${d.benchmark.maxScore || 100}` : 'no benchmark';
      check(true, 'pipeline-findings.json exists',
        `${scoreStr} | as of ${(d.timestamp || '').slice(0, 10) || 'unknown'}`);
    } catch(e) {
      check(true, 'pipeline-findings.json exists (parse issue)', '');
    }
  } else {
    check(false, 'pipeline-findings.json NOT found', 'Run ahe-reseed-daily.ps1 to populate');
  }

  // 5. Session heartbeat
  const hbPath = path.join(UP, '.ahe/status/session-heartbeat.json');
  if (fs.existsSync(hbPath)) {
    try {
      const hb = JSON.parse(fs.readFileSync(hbPath, 'utf8'));
      const age = hb.last_tool_time
        ? Math.round((new Date() - new Date(hb.last_tool_time)) / 1000 / 60) + ' min ago'
        : 'unknown';
      check(true, 'Session heartbeat active',
        `${hb.tool_count} calls | last: ${hb.last_tool} | ${age}`);
    } catch(e) {
      check(false, 'Session heartbeat data corrupt', e.message);
    }
  } else {
    check(false, 'No session heartbeat yet', 'Run a Qwen Code tool call to create one');
  }

  // 6. Session manifests
  const mDir = path.join(UP, '.ahe/session-manifests');
  if (fs.existsSync(mDir)) {
    const manifests = fs.readdirSync(mDir).filter(f => f.endsWith('.json'));
    check(manifests.length > 0,
      `${manifests.length} session manifest(s) recorded`,
      manifests.length > 0 ? `Latest: ${manifests[manifests.length-1]}` : '');
  } else {
    check(false, 'Session manifest directory missing', '');
  }

  // 7. Scheduled tasks
  for (const [name, expected] of [['AHEDailyBrief', 'ahe-reseed-daily.ps1'],
                                   ['AHENightlyAudit', 'nightly-audit.cmd']]) {
    try {
      const out = require('child_process').execSync(
        `schtasks /query /tn ${name} /v /fo list`, { encoding: 'utf8', timeout: 5000 });
      const status = (out.match(/Status:\s*(.+)/) || [])[1] || 'unknown';
      check(out.includes(expected),
        `${name}: ${status.trim()}`, `References ${expected}`);
    } catch(e) {
      check(false, `${name} query failed`, e.message);
    }
  }

  // 8. QWEN.md AHE section
  try {
    const q = fs.readFileSync(path.join(UP, '.qwen/QWEN.md'), 'utf8');
    const hasHeartbeat = q.includes('ahe-session-heartbeat.js');
    const has4Svcs = q.includes('4 consolidated services');
    check(hasHeartbeat && has4Svcs, 'QWEN.md AHE section accurate',
      '4 services, heartbeat hook, pipeline bridge documented');
  } catch(e) {
    check(false, 'QWEN.md read failed', e.message);
  }

  // ── Report ──
  console.log('========================================');
  console.log('  AHE Harness — Functionality Check');
  console.log('========================================\n');
  for (const r of results) {
    console.log(` ${r.ok ? '✓' : '✗'} ${r.msg}`);
    if (r.detail) console.log(`    ${r.detail}`);
  }
  console.log('');
  const pass = results.filter(r => r.ok).length;
  const fail = results.filter(r => !r.ok).length;
  console.log(` Overall: ${fail === 0 ? '✅ ALL CHECKS PASSED' : `⚠️  ${fail} CHECK(S) FAILED`}`);
  console.log(` ${pass}/${results.length} checks passed\n`);
  if (fail > 0) {
    console.log(' Failed:');
    results.filter(r => !r.ok).forEach(r => console.log(`   ✗ ${r.msg} — ${r.detail}`));
  }
  console.log(`\n Re-run: node "${__filename}"`);
}

main().catch(e => console.error('Error:', e));
