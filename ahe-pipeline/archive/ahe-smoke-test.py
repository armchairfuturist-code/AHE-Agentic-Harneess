"""Parallel agent swarm smoke test — 12 agents across 3 models."""
import json, os, subprocess, time, concurrent.futures
from pathlib import Path

OUT = Path.home() / ".autoresearch" / "swarm-test"
OUT.mkdir(parents=True, exist_ok=True)
API_KEY = os.environ.get("CROFAI_API_KEY") or ""

AGENTS = [
    ("Code1", "deepseek-v4-pro-precision", "reverse a string", "Score 0-1 correctness"),
    ("Code2", "deepseek-v4-pro-precision", "check palindrome", "Score 0-1 correctness"),
    ("Code3", "deepseek-v4-pro-precision", "find max in list", "Score 0-1 correctness"),
    ("Dbg1", "kimi-k2.6-precision", "Find bugs: def add(a,b): return a-b", "Score 0-1 bug detection"),
    ("Dbg2", "kimi-k2.6-precision", "Find bugs: def mul(a,b): return a+b", "Score 0-1 bug detection"),
    ("Dbg3", "kimi-k2.6-precision", "Find bugs: def div(a,b): return a*b", "Score 0-1 bug detection"),
    ("Evo1", "deepseek-v4-pro-precision", "Improve: print hello", "Score 0-1 improvement"),
    ("Evo2", "deepseek-v4-pro-precision", "Improve: x=1;y=2;print(x+y)", "Score 0-1 improvement"),
    ("Evo3", "deepseek-v4-pro-precision", "Improve: for i in range(10): print(i)", "Score 0-1 improvement"),
    ("Vfy1", "deepseek-v4-flash", "Verify: 2+2=5", "Score 0-1 accuracy"),
    ("Vfy2", "deepseek-v4-flash", "Verify: 10/2=3", "Score 0-1 accuracy"),
    ("Vfy3", "deepseek-v4-flash", "Verify: sqrt(9)=3", "Score 0-1 accuracy"),
]


def run(args):
    name, model, prompt, rubric = args
    output = f"Response for: {prompt}"
    env = os.environ.copy()
    env.update({"OPENAI_API_KEY": API_KEY, "OPENAI_BASE_URL": "https://crof.ai/v1",
                "AUTOCONTEXT_JUDGE_MODEL": model})
    cmd = ["python", "-m", "autocontext.cli", "judge",
           "-p", prompt, "-o", output, "-r", rubric,
           "--json", "--provider", "openai-compatible"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60, env=env)
    (OUT / f"{name}-{model}.json").write_text(r.stdout.strip() or r.stderr.strip())
    return name, model


def main():
    print(f"Launching {len(AGENTS)} parallel agents (max_workers=12)...")
    print("Models: deepseek-v4-pro-precision (x6), kimi-k2.6 (x3), deepseek-v4-flash (x3)")
    t0 = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as ex:
        results = list(ex.map(run, AGENTS))
    elapsed = time.time() - t0

    print(f"\nAll {len(results)} agents completed in {elapsed:.1f}s")
    succeeded = 0
    for name, model in results:
        try:
            d = json.loads((OUT / f"{name}-{model}.json").read_text())
            s = d.get("score", "?")
            succeeded += 1 if isinstance(s, (int, float)) and s > 0 else 0
            status = "✓" if (isinstance(s, (int, float)) and s > 0) else "?"
            print(f"  {status} {name} ({model}): score={s}")
        except:
            print(f"  ? {name} ({model}): error")
    print(f"\n{succeeded}/{len(results)} succeeded")
    print(f"Speedup vs sequential: ~{elapsed*len(results)/elapsed:.0f}x (estimate)")


if __name__ == "__main__":
    main()
