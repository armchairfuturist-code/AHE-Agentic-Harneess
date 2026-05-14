# A/B Test: AHE Hooks Performance Evaluation

**Date:** 2026-05-14
**Tester:** User (in Qwen Code)
**Observer:** GSD2/pi (monitoring config state)

## Purpose

Determine whether AHE PreToolUse hooks (rtk-wrapper, ahe-session-heartbeat) measurably improve agent output quality — or are pure latency overhead. Previous A/B test (n=10, May 13) showed **zero quality improvement at 7.9x latency** (190s vs 24s). This test uses a more complex task to confirm or refute that finding.

## Protocol

### Run A — Hooks ON (current state)

1. Verify hooks are on: `.\ahe-ab-test.ps1 status`
2. Copy the prompt below into Qwen Code
3. Start a timer
4. Let Qwen Code complete the task
5. Stop timer, note total wall time, count tool calls (visible in session), note output quality

### Run B — Hooks OFF

1. Disable PreToolUse hooks: `.\ahe-ab-test.ps1 off`
2. Start Qwen Code fresh session
3. Copy the **same prompt** into Qwen Code
4. Start a timer
5. Let Qwen Code complete the task
6. Stop timer, note time and quality
7. Restore hooks: `.\ahe-ab-test.ps1 on`

## Test Prompt

> Research the latest agentic coding benchmarks (SWE-bench, CodeScore, HumanEval, etc.) as of May 2026. For each benchmark, find:
> 1. What it measures (task type, evaluation methodology)
> 2. Top current scores
> 3. Which models/approaches lead
> 4. Known limitations or controversies
>
> Then produce a structured comparison table as `docs/agentic-benchmarks-2026.md` with:
> - A markdown table with columns: Benchmark | What It Measures | Top Score | Leading Approach | Limitations
> - A prose summary of the key trends
> - Citation links for each benchmark
>
> Use web search (brave-search MCP) for current data. Save the file to C:\Users\Administrator\Documents\Projects\AHE-Agentic-Harness\docs\ .

## Measurement Template

| Metric | Run A (hooks ON) | Run B (hooks OFF) | Delta |
|--------|-----------------|-------------------|-------|
| Wall time | | | |
| Tool calls | | | |
| Sections delivered | | | |
| Facts correct | | | |
| File structure quality | | | |
| Subjective quality (/10) | | | |

## Comparison Criteria

**Run A is better if:** Output is more thorough, better structured, fewer errors — enough to justify the extra latency.

**Run B wins if:** Output quality is equivalent or better, but delivered significantly faster.

**Tie:** Quality is equivalent but Run A takes >2x the time — hooks are dead weight.
