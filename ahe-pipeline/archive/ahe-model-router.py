"""AHE Model Router — routes tasks to optimal crof.ai models.
Maps the AHE paper's 3-role agent architecture to available models.

Model inventory from crof.ai (OpenAI-compatible):
  deepseek-v4-pro-precision — Best reasoning, best for Evolve Agent and Code Agent
  kimi-k2.6-precision       — Best structured output, best for Agent Debugger/Judge
  deepseek-v4-flash         — Fast/cheap, best for simple verifications
  Various GLM/Qwen          — Available but untested
"""
import json, os
from pathlib import Path

SETTINGS = Path.home() / ".qwen" / "settings.json"
API_KEY = os.environ.get("CROFAI_API_KEY") or os.environ.get("OPENAI_API_KEY") or ""
BASE_URL = "https://crof.ai/v1"

# AHE paper's 3-role agent architecture mapped to available models
ROLE_ROUTING = {
    "code_agent": {
        "description": "Executes tasks — the agent being evolved",
        "recommended_model": "deepseek-v4-pro-precision",
        "fallback": "kimi-k2.6-precision",
        "capability": "reasoning, tool use, multi-step execution",
        "ahe_role": "Rollout phase"
    },
    "agent_debugger": {
        "description": "Analyzes trajectories, produces evidence reports",
        "recommended_model": "kimi-k2.6-precision",
        "fallback": "deepseek-v4-pro-precision",
        "capability": "structured analysis, pattern detection, JSON output",
        "ahe_role": "AgentDebugger phase"
    },
    "evolve_agent": {
        "description": "Reads evidence, decides harness edits, writes manifest",
        "recommended_model": "deepseek-v4-pro-precision",
        "fallback": "kimi-k2.6-precision",
        "capability": "decision-making, code editing, strategic planning",
        "ahe_role": "Evolve phase"
    },
    "judge": {
        "description": "Evaluates outputs against rubrics",
        "recommended_model": "kimi-k2.6-precision",
        "fallback": "deepseek-v4-pro-precision",
        "capability": "strict JSON scoring, rubric-based evaluation",
        "ahe_role": "autocontext judge"
    },
    "fast_verify": {
        "description": "Simple pass/fail verification, quick checks",
        "recommended_model": "deepseek-v4-flash",
        "fallback": "kimi-k2.6-precision",
        "capability": "fast, cheap, good for binary decisions",
        "ahe_role": "Benchmark verification"
    }
}


def build_qwen_provider_config():
    """Build model provider configs that Qwen Code can use."""
    models = [
        {"id": "deepseek-v4-pro-precision", "name": "DeepSeek V4 Pro (precise)", "reasoning": True},
        {"id": "deepseek-v4-pro", "name": "DeepSeek V4 Pro (balanced)", "reasoning": True},
        {"id": "kimi-k2.6-precision", "name": "Kimi K2.6 (precise)", "reasoning": False},
        {"id": "deepseek-v4-flash", "name": "DeepSeek V4 Flash", "reasoning": False},
    ]
    providers = []
    for m in models:
        providers.append({
            "name": f"crof.ai: {m['name']}",
            "id": m["id"],
            "baseUrl": BASE_URL,
            "envKey": "CROFAI_API_KEY",
            "description": f"Model via CrofAI — {m['id']}",
            "reasoning": m["reasoning"],
        })
    return providers


def get_route(task_type):
    """Get optimal model for a task type."""
    route = ROLE_ROUTING.get(task_type)
    if not route:
        return {"model": ROLE_ROUTING["code_agent"]["recommended_model"], "role": "unknown"}
    return {
        "model": route["recommended_model"],
        "role": task_type,
        "description": route["description"],
        "fallback": route["fallback"],
        "capability": route["capability"],
    }


def print_routing_table():
    """Print routing table for the user."""
    print("\n=== AHE Model Routing Table ===")
    print(f"{'Role':<20} {'Model':<30} {'Fallback':<30} {'Capability'}")
    print("-" * 100)
    for role, cfg in ROLE_ROUTING.items():
        print(f"{role:<20} {cfg['recommended_model']:<30} {cfg['fallback']:<30} {cfg['capability']}")
    print()


if __name__ == "__main__":
    print_routing_table()
    print("Provider configs:", json.dumps(build_qwen_provider_config(), indent=2))
