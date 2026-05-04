"""AHE Persistent Agent Loop — the "Ralph Loop."
Runs agents in a while-not-done loop until goal completion.
Implements the AHE paper's outer loop pattern (Algorithm 1).

Loop structure:
  1. Check goal completion  (judge: is done?)
  2. If not done: route to optimal model  (model-router)
  3. Execute action  (code agent / evolve agent / debugger)
  4. Verify result  (judge: did it work?)
  5. Store evidence  (memory)
  6. Repeat from 1

Each agent uses the model best suited to its task:
- Evolve Agent → deepseek-v4-pro-precision (reasoning)
- Agent Debugger → kimi-k2.6-precision (structured analysis)
- Code Agent → deepseek-v4-pro-precision (tool use)
- Judge → kimi-k2.6-precision (JSON scoring)
"""
import json, os, subprocess, sys, time
from pathlib import Path

KNOWLEDGE = Path.home() / ".autoresearch" / "knowledge"
MEMORY = Path.home() / ".qwen" / "memory"
BASE_URL = "https://crof.ai/v1"
API_KEY = os.environ.get("CROFAI_API_KEY") or ""

# Role → model mapping
ROLE_MODEL = {
    "evolve": "deepseek-v4-pro-precision",
    "code": "deepseek-v4-pro-precision",
    "debugger": "kimi-k2.6-precision",
    "judge": "kimi-k2.6-precision",
    "verify": "deepseek-v4-flash",
}


def call_llm(prompt, model=None, role="code", max_tokens=2000):
    """Call crof.ai API with specified model."""
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


def judge_output(output, rubric, model=None):
    """Judge an output against a rubric using Kimi model."""
    model = model or ROLE_MODEL["judge"]
    prompt = f"""Rubric: {rubric}

Output to evaluate:
{output}

Return a JSON with: score (0-1), reasoning, dimension_scores (object)."""
    return call_llm(prompt, model=model, max_tokens=1000)


def run_loop(goal, max_iterations=20, verify_every=1):
    """Run the persistent agent loop until goal is complete or max iterations."""
    KNOWLEDGE.mkdir(parents=True, exist_ok=True)
    history = []
    iteration = 0
    done = False

    print(f"Goal: {goal}")
    print(f"Max iterations: {max_iterations}")
    print()

    while not done and iteration < max_iterations:
        iteration += 1
        print(f"\n{'='*60}")
        print(f"Iteration {iteration}/{max_iterations}")
        print(f"{'='*60}")

        # Step 1: Check if goal is complete (Judge → Kimi)
        status_prompt = f"""Goal: {goal}

Previous attempts: {json.dumps(history[-3:] if history else [])}

Is the goal complete? Answer YES or NO. If NO, say what should be done next."""
        
        status = call_llm(status_prompt, role="judge")
        print(f"[Judge] Status: {status[:200]}")

        if "YES" in status.upper() and "NO" not in status.upper().split("YES")[0]:
            print("\n✓ Goal complete!")
            done = True
            break

        # Step 2: Determine next action (Evolve → DeepSeek)
        action_prompt = f"""Goal: {goal}

Current state: {status[:500]}

History: {json.dumps(history[-5:])}

What is the single next action to take? Be specific and actionable."""
        
        action = call_llm(action_prompt, role="evolve")
        print(f"[Evolve] Action: {action[:200]}")

        # Step 3: Execute (Code Agent → DeepSeek)
        exec_prompt = f"""Execute this action: {action}

Goal: {goal}

Provide the specific commands, code, or steps to execute."""
        
        result = call_llm(exec_prompt, role="code")
        print(f"[Code] Result: {result[:200]}")

        # Step 4: Verify (Judge → Kimi)
        verify_result = judge_output(
            result,
            f"Does this output advance the goal '{goal}'? Score 0-1."
        )
        print(f"[Verify] Score: {verify_result[:100]}")

        # Step 5: Store evidence
        entry = {
            "iteration": iteration,
            "status": status[:200],
            "action": action[:200],
            "result": result[:200],
            "verify_score": verify_result[:100],
        }
        history.append(entry)

        # Persist
        (KNOWLEDGE / "ralph-loop-history.json").write_text(json.dumps(history, indent=2))

    print(f"\n{'='*60}")
    print(f"Loop complete after {iteration} iterations")
    print(f"Goal achieved: {done}")
    print(f"{'='*60}")
    return done, history


if __name__ == "__main__":
    import sys as _sys
    goal = " ".join(_sys.argv[1:]) or "Analyze the AHE harness and identify the top 3 improvements"
    run_loop(goal)
