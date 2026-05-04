"""Parallel agent swarm smoke test."""
import json, os, subprocess, time, concurrent.futures
from pathlib import Path

OUT = Path.home() / ".autoresearch" / "swarm-test"
OUT.mkdir(parents=True, exist_ok=True)

API_KEY = os.environ.get("CROFAI_API_KEY") or ""

AGENTS = [
    ("CodeAgent", "deepseek-v4-pro-precision", "Write a Python function to reverse a string",
     "def reverse(s): return s[::-1]", "Score 0-1 correctness"),
    ("Debugger", "kimi-k2.6-precision", "Find bugs: def add(a,b): return a-b",
     "Bug: subtracts instead of adding", "Score 0-1 bug detection"),
    ("Evolve", "deepseek-v4-pro-precision", "Improve: print hello",
     "Improvement: use logging instead of print", "Score 0-1 improvement quality"),
    ("Verify", "deepseek-v4-flash", "Verify: 2+2=5",
     "Incorrect: 2+2=4", "Score 0-1 accuracy"),
]


def run_agent(args):
    name, model, prompt, output, rubric = args
    env = os.environ.copy()
    env.update({
        "OPENAI_API_KEY": API_KEY,
        "OPENAI_BASE_URL": "https://crof.ai/v1",
        "AUTOCONTEXT_JUDGE_MODEL": model,
    })
    cmd = ["python", "-m", "autocontext.cli", "judge",
           "-p", prompt, "-o", output, "-r", rubric,
           "--json", "--provider", "openai-compatible"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60, env=env)
    result_data = r.stdout.strip() or r.stderr.strip()
    (OUT / f"{name}-{model}.json").write_text(result_data)
    return name, model


def main():
    print("Launching 4 parallel agents...")
    t0 = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
        results = list(ex.map(run_agent, AGENTS))
    elapsed = time.time() - t0

    print(f"\nAll {len(results)} agents completed in {elapsed:.1f}s")
    for name, model in results:
        print(f"  {name} ({model})")
    print("\nModels: deepseek-v4-pro (x2), kimi-k2.6, deepseek-v4-flash")

    # Read results
    for f in sorted(OUT.glob("*.json")):
        try:
            d = json.loads(f.read_text())
            score = d.get("score", "?")
            print(f"  {f.stem}: score={score}")
        except:
            print(f"  {f.stem}: error parsing result")


if __name__ == "__main__":
    main()
