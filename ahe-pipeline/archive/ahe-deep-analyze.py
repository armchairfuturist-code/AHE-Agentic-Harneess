"""Deep candidate analysis using crof.ai Kimi model."""
import json, os, urllib.request
from pathlib import Path

KNOWLEDGE = Path.home() / ".autoresearch" / "knowledge"
findings = json.loads((KNOWLEDGE / "research-findings.json").read_text())

candidates = list({c["name"]: c for c in findings.get("mcps", [])}.values())
skip = ["xhs-downloader", "nginx-ui", "muapi-cli", "gemini-cli"]
relevant = sorted([c for c in candidates if not any(k in c["name"].lower() for k in skip)],
                  key=lambda x: x.get("stars", 0), reverse=True)[:7]

prompt = """Analyze which MCP servers add most value to an AHE harness.
Our installed MCPs: filesystem, github, brave-search, context7, chrome-devtools, qwen-memory, autocontext, mcp-toolbox.
Missing capabilities: web scraping (full page content), code indexing (graph DB), monitoring/observability.

Candidates:
"""
for i, c in enumerate(relevant, 1):
    prompt += f"{i}. {c['name']} ({c['stars']}★) — {c['desc'][:100]}\n"
prompt += '\nReturn JSON list: [{rank:int, name, gap_filled, install_effort:easy/medium/hard, recommendation:install/skip/defer, reasoning}]'

api_key = os.environ.get("OPENAI_API_KEY") or os.environ.get("CROFAI_API_KEY")
req = urllib.request.Request(
    "https://crof.ai/v1/chat/completions",
    data=json.dumps({"model":"kimi-k2.6-precision","messages":[{"role":"user","content":prompt}],"max_tokens":2000}).encode(),
    headers={"Content-Type":"application/json","Authorization":f"Bearer {api_key}"}
)
resp = json.loads(urllib.request.urlopen(req, timeout=120).read())
content = resp["choices"][0]["message"]["content"]

result = {"model":"kimi-k2.6-precision","timestamp":__import__("datetime").datetime.now().isoformat(),"raw":content}
(KNOWLEDGE / "deep-analysis.json").write_text(json.dumps(result,indent=2))
print(content)
