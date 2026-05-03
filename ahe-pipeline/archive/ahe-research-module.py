"""AHE proactive research module.
Uses GitHub API to discover new MCPs, tools, and config gaps.
"""

import json
import urllib.request
from pathlib import Path
from datetime import datetime

BASE = Path.home() / ".autoresearch"
BENCHMARKS = BASE / "benchmarks"
KNOWLEDGE = BASE / "knowledge"


def find_gaps():
    """Read latest benchmark, return failing tests."""
    files = sorted(BENCHMARKS.glob("*.json"), reverse=True)
    for f in files:
        if "run" not in f.stem:
            try:
                bench = json.loads(f.read_text())
                if "tests" in bench:
                    return [
                        {"test": n, "detail": d.get("detail", "")}
                        for n, d in bench["tests"].items()
                        if not d.get("pass", True)
                    ]
            except Exception:
                continue
    return []


def search_github(query_prefix, known):
    """Search GitHub for repos matching a category, filtered against known items."""
    results = []
    queries = [
        query_prefix + "+database",
        query_prefix + "+monitoring",
        query_prefix + "+search",
        query_prefix + "+docker",
        query_prefix + "+terminal",
    ]
    for q in queries:
        url = (
            "https://api.github.com/search/repositories?q="
            + q
            + "&sort=stars&per_page=3"
        )
        try:
            req = urllib.request.Request(
                url, headers={"Accept": "application/vnd.github.v3+json"}
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                for item in json.loads(resp.read()).get("items", []):
                    name = item["full_name"]
                    stars = item["stargazers_count"]
                    skip = any(
                        k.lower() in name.lower()
                        for k in known
                    )
                    if not skip and stars > 200:
                        results.append({
                            "name": name,
                            "stars": stars,
                            "url": item["html_url"],
                            "desc": (item.get("description") or "")[:120],
                        })
        except Exception:
            pass
    return results


def main():
    KNOWLEDGE.mkdir(parents=True, exist_ok=True)

    known = [
        "filesystem", "qwen-memory", "github", "brave-search",
        "context7", "chrome-devtools", "autocontext",
    ]

    gaps = find_gaps()
    mcps = search_github("mcp-server", known)
    tools = search_github("qwen-code", known + ["ce-", "gsd-", "taste-skill"])

    findings = {
        "ts": datetime.now().isoformat(),
        "gaps": gaps,
        "mcps": mcps,
        "tools": tools,
    }
    findings["summary"] = {
        k: len(v) for k, v in findings.items() if k != "ts"
    }

    report_path = KNOWLEDGE / "research-findings.json"
    report_path.write_text(json.dumps(findings, indent=2))
    print(json.dumps(findings))


if __name__ == "__main__":
    main()
