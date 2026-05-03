"""AHE candidate evaluation and scoring module.
Ranks discovered MCPs/tools by:
- How they fill gaps in our current harness
- Safety and ease of installation
- Potential benchmark impact

Run: python ahe-evaluate-candidates.py
"""
import json
from pathlib import Path

KNOWLEDGE = Path.home() / ".autoresearch" / "knowledge"


# Known capability map: what we already have vs what's missing
EXISTING_CAPABILITIES = {
    "filesystem": {"type": "filesystem", "gap_score": 0},
    "github": {"type": "github", "gap_score": 0},
    "brave-search": {"type": "search", "gap_score": 0},
    "context7": {"type": "docs", "gap_score": 0},
    "chrome-devtools": {"type": "browser", "gap_score": 0},
    "qwen-memory": {"type": "memory", "gap_score": 0},
    "autocontext": {"type": "agent-eval", "gap_score": 0},
}

TARGET_GAPS = {
    "database": {"need": 2, "have": 0, "weight": 0.8},    # No DB access
    "monitoring": {"need": 1, "have": 0, "weight": 0.6},   # No system monitoring
    "search": {"need": 2, "have": 1, "weight": 0.3},       # Have brave-search
    "terminal": {"need": 1, "have": 0, "weight": 0.5},     # No terminal MCP
    "web-scrape": {"need": 1, "have": 0, "weight": 0.7},   # No dedicated scraper
    "code-graph": {"need": 1, "have": 0, "weight": 0.4},   # No code indexing
}


def classify_capability(name, desc):
    """Determine what capability a candidate provides."""
    n = name.lower() + " " + desc.lower()
    if any(k in n for k in ["database", "db ", "sql", "postgres", "mysql", "mongodb"]):
        return "database"
    if any(k in n for k in ["monitor", "observability", "log", "metrics"]):
        return "monitoring"
    if any(k in n for k in ["search", "scrape", "crawl", "web"]):
        return "web-scrape"
    if any(k in n for k in ["terminal", "shell", "command", "desktop"]):
        return "terminal"
    if any(k in n for k in ["code", "graph", "index"]):
        return "code-graph"
    return "other"


def score_candidate(candidate):
    """Score a candidate 0-100 based on gap fill, quality, and installability."""
    cap = classify_capability(candidate["name"], candidate.get("desc", ""))
    gap = TARGET_GAPS.get(cap, {"weight": 0.1})
    
    stars = candidate.get("stars", 0)
    star_score = min(stars / 500, 20)  # Up to 20 points for stars
    
    # Gap fill: how badly do we need this capability?
    gap_score = gap["weight"] * 50  # Up to 50 points for filling a gap
    
    # Relevance: does the desc actually match what we need?
    rel_score = 15 if cap != "other" else 5  # 15 for relevant, 5 for unknown
    
    # Safety: npm/npx-based is safer than binary downloads
    safe = 10  # npm-based default
    name_lower = candidate["name"].lower()
    if any(k in name_lower for k in ["chrome", "nginx", "downloader", "cli"]):
        safe = 5  # Lower confidence
    
    total = star_score + gap_score + rel_score + safe
    return {
        "name": candidate["name"],
        "stars": stars,
        "url": candidate.get("url", ""),
        "desc": candidate.get("desc", "")[:120],
        "category": cap,
        "gap_name": gap,
        "score": round(total, 1),
        "star_pts": round(star_score, 1),
        "gap_pts": round(gap_score, 1),
        "rel_pts": rel_score,
        "safe_pts": safe,
    }


def explain(candidate):
    """Generate a human-readable explanation of what this candidate adds."""
    name = candidate["name"]
    cat = candidate["category"]
    cap_name = candidate.get("desc", "no description")
    
    explanations = {
        "database": f"**{name}** — adds database query capability (currently missing). "
                    f"You could ask the agent to query databases directly via natural language.",
        "monitoring": f"**{name}** — adds system monitoring/observability. "
                      f"Would let the agent check logs, metrics, and system health.",
        "web-scrape": f"**{name}** — adds web scraping/search. "
                      f"Expands beyond brave-search with deeper page content extraction.",
        "terminal": f"**{name}** — adds terminal/command execution MCP. "
                    f"Would let the agent run shell commands with proper isolation.",
        "code-graph": f"**{name}** — adds code indexing/graph capabilities. "
                      f"Would improve code understanding across the project.",
        "other": f"**{name}** — {cap_name}",
    }
    return explanations.get(cat, explanations["other"])


def main():
    findings_file = KNOWLEDGE / "research-findings.json"
    if not findings_file.exists():
        print(json.dumps({"error": "No research findings found. Run ahe-research-module.py first."}))
        return
    
    findings = json.loads(findings_file.read_text())
    all_candidates = findings.get("mcps", []) + findings.get("tools", [])
    
    scored = [score_candidate(c) for c in all_candidates]
    scored.sort(key=lambda x: x["score"], reverse=True)
    
    # Dedup by name
    seen = set()
    unique = []
    for s in scored:
        if s["name"] not in seen:
            seen.add(s["name"])
            unique.append(s)
    
    result = {
        "timestamp": __import__("datetime").datetime.now().isoformat(),
        "total_candidates": len(unique),
        "scored": unique[:20],
        "summaries": [
            {"name": s["name"], "score": s["score"], "category": s["category"],
             "explanation": explain(s)}
            for s in unique[:10]  # Top 10 with explanations
        ],
        "gaps": findings.get("gaps", []),
    }
    
    (KNOWLEDGE / "candidate-evaluations.json").write_text(json.dumps(result, indent=2))
    print(json.dumps(result))


if __name__ == "__main__":
    main()
