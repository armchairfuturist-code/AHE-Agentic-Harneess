"""AHE prune module — identify components that can be removed to debloat."""
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

QWEN = Path.home() / ".qwen"
HOOKS = QWEN / "hooks"
SKILLS = QWEN / "skills"
MEMORY = Path.home() / ".autoresearch"
ERROR_LOG = MEMORY / "error-patterns.jsonl"
SETTINGS = QWEN / "settings.json"
OUTPUT = MEMORY / "knowledge" / "prune-candidates.json"

NOW = datetime.now(timezone.utc)

CRITICAL = {"filesystem","qwen-memory","github","autocontext","context-mode"}
KEYWORDS = ["browser","chrome","search","db","database","memory","fs","file","github","git","terminal","shell"]


def load_settings():
    try:
        return json.loads(SETTINGS.read_text(encoding="utf-8"))
    except Exception:
        return {}


def list_all():
    """Return all components: MCPs, hooks, skills."""
    items = []
    settings = load_settings()
    for name, cfg in settings.get("mcpServers", {}).items():
        items.append({"type":"mcp","name":name.strip('"'),"cmd":cfg.get("command","")})
    if HOOKS.exists():
        for f in sorted(HOOKS.glob("*.js")):
            try:
                items.append({"type":"hook","name":f.stem,"lines":len(f.read_text().splitlines()),"age_days":(NOW-datetime.fromtimestamp(f.stat().st_mtime,tz=timezone.utc)).days})
            except: pass
    if SKILLS.exists():
        for d in sorted(SKILLS.iterdir()):
            try:
                has = (d/"SKILL.md").exists()
                items.append({"type":"skill","name":d.name,"has_skill_md":has,"age_days":(NOW-datetime.fromtimestamp(d.stat().st_mtime,tz=timezone.utc)).days})
            except: pass
    return items


def load_errors():
    if not ERROR_LOG.exists():
        return []
    errs = []
    for line in ERROR_LOG.read_text().splitlines():
        try:
            e = json.loads(line.strip())
            ts = datetime.fromisoformat(e.get("ts",""))
            if abs((ts - NOW).days) < 30:
                errs.append(e)
        except: pass
    return errs


def error_count(errs, name):
    return sum(1 for e in errs if name.lower() in ((e.get("t","") or "") + (e.get("a","") or "")).lower())


def score(item, errs, mcps):
    n, t = item["name"], item["type"]
    s = 50
    s -= min(error_count(errs, n) * 10, 30)
    if t == "mcp":
        nl = n.lower()
        for k in KEYWORDS:
            if k in nl:
                s -= min(sum(1 for m in mcps if m["name"] != n and k in m["name"].lower()) * 5, 20)
        if n in CRITICAL:
            s += 30
    if t == "hook" and item.get("lines",0) > 200:
        s -= 10
    if t == "skill" and item.get("has_skill_md"):
        s += 10
    age = item.get("age_days",0)
    s += 10 if age < 7 else (-10 if age > 90 else 0)
    return max(0, min(100, s))


def overlaps(item, all_items):
    if item["type"] != "mcp":
        return []
    nl = item["name"].lower()
    return [m["name"] for m in all_items if m["name"] != item["name"] and m["type"]=="mcp"
            and any(k in nl and k in m["name"].lower() for k in KEYWORDS)]


def main():
    MEMORY.mkdir(parents=True, exist_ok=True)
    items = list_all()
    mcps = [i for i in items if i["type"]=="mcp"]
    errs = load_errors()

    scored = [{"name":i["name"],"type":i["type"],"score":score(i,errs,mcps),
               "errors":error_count(errs,i["name"]),"overlaps":overlaps(i,items)} for i in items]
    scored.sort(key=lambda x: x["score"])

    result = {"ts":NOW.isoformat(),"total":len(scored),"mcps":len([i for i in items if i["type"]=="mcp"]),
              "hooks":len([i for i in items if i["type"]=="hook"]),
              "skills":len([i for i in items if i["type"]=="skill"]),
              "errors_30d":len(errs),
              "candidates":[s for s in scored if s["score"]<50][:10],
              "safe":sum(1 for s in scored if s["score"]>=50)}
    OUTPUT.write_text(json.dumps(result, indent=2))
    print(json.dumps({"candidates":len(result["candidates"]),"safe":result["safe"],"total":result["total"]}))

if __name__ == "__main__":
    main()
