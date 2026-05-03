"""Unified AHE report — anomalies, candidates, prune, gaps in one actionable doc."""
import json
from datetime import datetime, timezone
from pathlib import Path

MEMORY = Path.home() / ".autoresearch"
KNOWLEDGE = MEMORY / "knowledge"
DEBUGGER = MEMORY / "debugger"
OBSIDIAN = Path.home() / "Documents" / "Obsidian Vault" / "Research" / "Autoresearch"

NOW = datetime.now(timezone.utc)
TODAY = NOW.strftime("%Y-%m-%d")


def load_json(pattern):
    """Load latest JSON from a directory matching a pattern."""
    for p in sorted(pattern.parent.glob(pattern.name), reverse=True):
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except:
            continue
    return {}


def fmt_cmd(cmd):
    return f"```powershell\n{cmd}\n```"


def section_action(name, items, cmd_template=None, empty_msg="None"):
    """Build a section with action items."""
    if not items:
        return f"### {name}\n\n{empty_msg}\n\n"
    lines = [f"### {name}\n"]
    for item in items[:10]:
        lines.append(f"- **{item.get('name','?')}** (score {item.get('score','?')})")
        desc = item.get("desc") or item.get("description","") or ""
        if desc:
            lines.append(f"  — {desc[:120]}")
        overlap = item.get("overlaps", [])
        if overlap:
            lines.append(f"  ⚠ overlaps: {', '.join(overlap[:3])}")
    lines.append("")
    if cmd_template and items:
        lines.append("**Action:**")
        lines.append(fmt_cmd(cmd_template))
        lines.append("")
    return "\n".join(lines)


def main():
    OBSIDIAN.mkdir(parents=True, exist_ok=True)

    # Load all sources
    research = load_json(KNOWLEDGE / "research-findings.json")
    evals = load_json(KNOWLEDGE / "candidate-evaluations.json")
    prune = load_json(KNOWLEDGE / "prune-candidates.json")
    debug = load_json(DEBUGGER / "debugger-*.json")

    findings = research.get("mcps", []) + research.get("tools", [])
    gaps = research.get("gaps", [])
    scored_candidates = evals.get("summaries", [])
    prune_candidates = prune.get("candidates", [])
    layers = debug.get("layers", {})
    anomalies = layers.get("layer3_anomalies", []) if isinstance(layers.get("layer3_anomalies"), list) else []
    trend = layers.get("layer1_score_trend", {})
    layer2 = layers.get("layer2_per_test", [])

    lines = []
    lines.append(f"# AHE Unified Intelligence Report — {TODAY}")
    lines.append("")
    lines.append("> **One report to rule them all.** Anomalies, installation candidates, pruning opportunities, and config gaps collected from all pipeline phases.")
    lines.append("")
    lines.append("---")

    # Summary bar
    lines.append("## Summary")
    lines.append("")
    lines.append(f"| Category | Count |")
    lines.append(f"|----------|-------|")
    flaky_tests_list = layer2.get("flaky_tests", []) if isinstance(layer2, dict) else []
    failed_tests_list = layer2.get("failed_tests", []) if isinstance(layer2, dict) else []
    flaky = len(flaky_tests_list)
    failed = len(failed_tests_list)
    lines.append(f"| **Install candidates** (MCPs + tools) | {len(scored_candidates)} |")
    lines.append(f"| **Prune candidates** (overhead > value) | {len(prune_candidates)} |")
    lines.append(f"| **Config gaps** (benchmark failures) | {len(gaps)} |")
    lines.append(f"| **Anomalies** (score drops detected) | {len(anomalies)} |")
    lines.append(f"| **Flaky tests** | {flaky} |")
    lines.append(f"| **Persistent failures** | {failed} |")
    lines.append("")

    # INSTALL section — actionable
    lines.append("## 🔧 Install Candidates")
    lines.append("")
    lines.append("New MCP servers and tools that scored high enough to consider adding. Each candidate includes what it adds and why it was surfaced.")
    lines.append("")
    if scored_candidates:
        lines.append("| # | Score | Candidate | What it adds | Action |")
        lines.append("|---|-------|-----------|-------------|--------|")
        for i, c in enumerate(scored_candidates[:10], 1):
            expl = (c.get("explanation") or "").split("—", 1)[-1].strip()[:80]
            install_cmd = f"npx @modelcontextprotocol/server-{c.get('name','').split('/')[-1].replace('mcp-','')}" if 'mcp' in c.get('name','') else f"gh repo clone {c.get('name','')}"
            lines.append(f"| {i} | **{c.get('score','?')}** | {c.get('name','?')} | {expl} | `{install_cmd}` |")
        lines.append("")
        lines.append("**Bulk install command (evaluate top 3):**")
        lines.append(fmt_cmd("# npx @modelcontextprotocol/server-<name>"))
        lines.append("")
    else:
        lines.append("_No install candidates found in latest research._\n\n")

    # PRUNE section — actionable
    lines.append("## 🗑 Prune Candidates")
    lines.append("")
    lines.append("Components that scored below threshold. Consider removing to reduce overhead. The benchmark will confirm if removal improves the score.")
    lines.append("")
    if prune_candidates:
        lines.append("| # | Score | Name | Type | Errors (30d) | Overlaps |")
        lines.append("|---|-------|------|------|-------------|----------|")
        for i, c in enumerate(prune_candidates[:10], 1):
            errs = c.get("errors_30d", 0)
            ov = ", ".join(c.get("overlaps", [])[:2]) or "—"
            lines.append(f"| {i} | **{c.get('score','?')}** | {c.get('name','?')} | {c.get('type','?')} | {errs} | {ov} |")
        lines.append("")
        lines.append("**To disable a component:**")
        lines.append(fmt_cmd("# Remove from .qwen/settings.json mcpServers section"))
        lines.append(fmt_cmd("# Or add to a-prune-disable list"))
        lines.append("")
    else:
        lines.append("_All components scored above threshold. System is lean._\n\n")

    # CONFIG GAPS section — actionable
    lines.append("## ⚠ Config Gaps (Benchmark Failures)")
    lines.append("")
    if gaps:
        for g in gaps:
            test = g.get("test", "?")
            detail = g.get("detail", "")
            fix = {
                "mcp.brave_key": "Add BRAVE_API_KEY to user env vars via `setx BRAVE_API_KEY <value>`",
                "hard.security_hook_keys": "Add GEMINI_API_KEY to exclusion list in bm-module.ps1",
            }.get(test, "Investigate")
            lines.append(f"- **{test}**: {detail}")
            lines.append(f"  → **Fix:** {fix}")
        lines.append("")
    else:
        lines.append("_No config gaps found. All tests passing._\n\n")

    # ANOMALIES section — actionable
    lines.append("## 📉 Anomalies (Score Drops)")
    lines.append("")
    if anomalies:
        avg_score = trend.get('avg_score', '?')
        direction = trend.get('direction', 'unknown')
        delta = trend.get('delta', '?')
        lines.append(f"**Trend:** {direction} ({delta} pts) — avg score {avg_score} across {trend.get('benchmarks_analyzed', '?')} benchmarks")
        lines.append("")
        lines.append("| Cycle | Drop (pts) | Details |")
        lines.append("|-------|-----------|---------|")
        for a in anomalies[:10]:
            if isinstance(a, str):
                lines.append(f"| — | — | {a[:80]} |")
            else:
                detail = a.get('reason', '')[:60] or a.get('detail', '')[:60] or ''
                cycle = a.get('cycle', a.get('iteration', '?'))
                drop = a.get('drop', a.get('delta', '?'))
                lines.append(f"| {cycle} | {drop} | {detail} |")
        lines.append("")
        lines.append("**Investigate latest drop:**")
        lines.append(fmt_cmd("# Check benchmark around that cycle"))
        lines.append("")
    else:
        lines.append("_No anomalies detected._\n\n")

    # FLAKY TESTS
    if flaky or failed:
        lines.append("## 🔄 Flaky & Failing Tests")
        lines.append("")
        for t in flaky_tests_list:
            lines.append(f"- ⚠ {t} — flaky")
        for t in failed_tests_list:
            lines.append(f"- ❌ {t} — always fails")
        lines.append("")

    # METHODOLOGY
    lines.append("---")
    lines.append(f"*Generated {NOW.strftime('%Y-%m-%d %H:%M')} UTC by AHE pipeline*")
    lines.append(f"*Sources: agent-debugger, research-module, prune-module, benchmark*")

    # Write unified report
    report = OBSIDIAN / f"ahe-intelligence-{TODAY}.md"
    report.write_text("\n".join(lines), encoding="utf-8")
    print(f"Written: {report} ({len(lines)} lines)")


if __name__ == "__main__":
    main()
