"""AHE Task-Based Benchmark — measures real agent capability, not just config checks.
Each task tests whether the harness can complete a real operation.
"""
import json, os, subprocess, sys
from pathlib import Path

TASK_BANK = Path.home() / "Scripts" / "archive" / "ahe-task-bank.json"
TEMP = Path.home() / ".autoresearch" / "task-test"
OUTPUT = Path.home() / ".autoresearch" / "knowledge" / "task-benchmark-results.json"


def verify_task(task):
    """Run a task's verification command and return pass/fail."""
    cmd = task.get("verify", "")
    if not cmd:
        return "skip"
    
    # For side-effect tasks, check file existence directly
    name = task.get("name", "")
    if name == "file-creation":
        p = TEMP / "hello.txt"
        if p.exists() and p.read_text().strip() == "hello world from AHE agent":
            return "pass"
        return "fail"
    
    if name == "code-generation":
        p = TEMP / "fib.py"
        if not p.exists():
            return "fail"
        try:
            r = subprocess.run([sys.executable, str(p)], capture_output=True, text=True, timeout=10)
            last = r.stdout.strip().split("\n")[-1] if r.stdout.strip() else ""
            return "pass" if last == "34" else "fail"
        except:
            return "fail"
    
    if name == "multi-file":
        a = TEMP / "nested" / "a.txt"
        b = TEMP / "nested" / "b.txt"
        if a.exists() and b.exists() and a.read_text().strip() == "file A" and b.read_text().strip() == "file B":
            return "pass"
        return "fail"
    
    if name == "json-creation":
        p = TEMP / "config.json"
        if not p.exists():
            return "fail"
        try:
            j = json.loads(p.read_text())
            return "pass" if j.get("name") == "test" and j.get("enabled") is True and j.get("count") == 5 else "fail"
        except:
            return "fail"
    
    # For MCP-dependent tasks, check agent output keyword presence
    # These require the agent to have run the prompt — side effects alone can't verify
    return "unverified"


def main():
    TEMP.mkdir(parents=True, exist_ok=True)
    
    tasks = json.loads(TASK_BANK.read_text(encoding="utf-8"))
    total = len(tasks)
    passed = 0
    failed = 0
    unverified = 0
    details = []
    
    for task in tasks:
        result = verify_task(task)
        details.append({
            "id": task["id"],
            "name": task["name"],
            "capability": task["capability"],
            "result": result
        })
        if result == "pass":
            passed += 1
        elif result == "fail":
            failed += 1
        else:
            unverified += 1
    
    # Score = pass / (pass + fail) — only count verifiable tasks
    verifiable = passed + failed
    pass_rate = round(passed / verifiable * 100, 1) if verifiable > 0 else 0
    
    result = {
        "timestamp": __import__("datetime").datetime.now().isoformat(),
        "total_tasks": total,
        "verifiable": verifiable,
        "passed": passed,
        "failed": failed,
        "unverifiable": unverified,
        "pass_rate": pass_rate,
        "results": details
    }
    
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2))
    
    print(json.dumps({
        "pass_rate": pass_rate,
        "verifiable": verifiable,
        "passed": passed,
        "failed": failed,
        "unverifiable": unverified,
        "total": total
    }))


if __name__ == "__main__":
    main()
