"""
DEPRECATED — Replaced by HeavySkill inner reasoning (ahe-heavyskill.ps1).

This file is retained for reference only. The Ralph Loop's 4-step sequential
pattern (judge→evolve→code→verify) has been replaced by HeavySkill's parallel
reasoning → summarization approach in a single API call.

See: ../ahe-heavyskill.ps1  (Invoke-HeavySkillPlan, Invoke-HeavySkillGate)
See: ../pipeline.ps1         (Invoke-Swarm — now calls HeavySkill instead)

Removal date: TBD after verification cycle confirms no regressions.
"""

import json, os, subprocess, sys, time
from pathlib import Path

KNOWLEDGE = Path.home() / ".autoresearch" / "knowledge"
MEMORY = Path.home() / ".qwen" / "memory"
BASE_URL = "https://crof.ai/v1"
API_KEY = os.environ.get("CROFAI_API_KEY") or ""

ROLE_MODEL = {
    "evolve": "deepseek-v4-pro-precision",
    "code": "deepseek-v4-pro-precision",
    "debugger": "kimi-k2.6-precision",
    "judge": "kimi-k2.6-precision",
    "verify": "deepseek-v4-flash",
}

def call_llm(prompt, model=None, role="code", max_tokens=2000):
    model = model or ROLE_MODEL.get(role, "deepseek-v4-pro-precision")
    try:
        import openai
        client = openai.OpenAI(api_key=API_KEY, base_url=BASE_URL, timeout=60)
        r = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=max_tokens
        )
        return r.choices[0].message.content or ""
    except Exception as e:
        return f"ERROR: {e}"

if __name__ == "__main__":
    print("DEPRECATED: Use ahe-heavyskill.ps1 instead (HeavySkill parallel reasoning → summarization)")
    print("This file kept for reference. Running legacy Ralph Loop...")
    goal = " ".join(sys.argv[1:]) or "Analyze the AHE harness and identify the top 3 improvements"
    
    # Legacy behavior — for backward compatibility
    KNOWLEDGE.mkdir(parents=True, exist_ok=True)
    history = []
    iteration = 0
    max_iterations = 3  # reduced from 20 — just enough for verification
    
    while iteration < max_iterations:
        iteration += 1
        status = call_llm(f"Goal: {goal}\nPrevious: {json.dumps(history[-3:])}\nIs goal complete? YES or NO.", role="judge")
        if "YES" in status.upper() and "NO" not in status.upper().split("YES")[0]:
            break
        action = call_llm(f"Goal: {goal}\nStatus: {status[:500]}\nNext action?", role="evolve")
        result = call_llm(f"Execute: {action}", role="code")
        history.append({"iteration": iteration, "action": action[:200], "result": result[:200]})
        (KNOWLEDGE / "ralph-loop-history.json").write_text(json.dumps(history, indent=2))
    
    print(f"Legacy loop: {iteration} iterations. Switch to HeavySkill for better results.")
