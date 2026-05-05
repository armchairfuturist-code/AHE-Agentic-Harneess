---
title: Benchmark Stability Test Broken by Wrong File Glob Pattern
date: 2026-05-05
category: docs/solutions/performance-issues/
module: benchmark_system
problem_type: workflow_issue
component: tooling
severity: medium
applies_when:
  - Benchmark scores are stable at 95.6 instead of 100 despite all tests passing
  - The scenario.stability test always returns 0/3
  - Aggregate benchmark files use YYYYMMDD format in filenames
tags:
  - benchmark
  - stability
  - glob-pattern
  - file-filtering
  - scoring
  - benchmark.ps1
---

# Benchmark Stability Test Broken by Wrong File Glob Pattern

## Context

The system benchmark (`benchmark.ps1`) has a `scenario.stability` test that checks whether benchmark scores are consistent across recent runs. It looks for the 5 most recent aggregate benchmark files and measures their score spread. If the spread is ≤ 1 point, the stability test passes at 3/3.

The benchmark was consistently scoring 95.6 instead of 100 even though 24/25 individual tests were passing. The single failing test was `scenario.stability` at 0/3.

## Guidance

### The Bug: Wrong File Glob Pattern

In `benchmark.ps1` line 125, the stability test used this pattern to find aggregate files:

```powershell
# BUG: ???? expects 4 characters, but our dates use 8 (YYYYMMDD)
$bf = Get-ChildItem "$benchDir\benchmark-????-*.json"
```

Our files are named `benchmark-20260505-145732.json` — 8-digit date `20260505` does not match `????` (4 chars). **This pattern has never matched any file since the benchmark system was created.**

When 0 files are found, `$bf.Count -lt 2`, so the test falls through to:
```powershell
Test-Scenario "scenario.stability" 0 3 "only $($bf.Count) benchmarks"
```

Always returning 0/3.

### The Fix

Changed to use `*` wildcard:

```powershell
# FIX: * matches any date format
$bf = Get-ChildItem "$benchDir\benchmark-*.json" | Where-Object { $_.Name -notmatch '-run\d+\.' }
```

The `Where-Object` filter already removes run-specific files (`-run1.json`, `-run2.json`, `-run3.json`), so using `*` instead of `????` is safe.

### Score Impact

The scoring formula uses weighted categories:

| Category | Weight | Tests | Current | With Fix |
|----------|--------|-------|---------|----------|
| system | ×2 | 4/4 | 100% | 100% |
| mcp | ×5 | 5/5 | 100% | 100% |
| hook | ×4 | 3/3 | 100% | 100% |
| memory | ×3 | 4/4 | 100% | 100% |
| skill | ×1 | 1/1 | 100% | 100% |
| scenario | ×3 | 3/4 (75%) | 75% | 100% |
| hard | ×4 | 4/4 | 100% | 100% |

Total weight = 22. Score = (21.25 / 22) × 100 = 95.6 → (22 / 22) × 100 = 100

### Temporary Deflation from Corrupted Benchmarks

After fixing the glob, the stability test correctly finds 5 files but still scores 0/3 if recent benchmark runs include corrupted scores. On May 5, the BOM corruption incident produced two 80.9 scores that are in the top-5 window, creating a 14.7-point spread. After 3 more clean benchmark runs at ~95.6, the 80.9 scores age out and the spread drops to ≤ 1, giving 3/3.

## Why This Matters

- A broken glob in the stability test silently deflated every benchmark score from 100 to 95.6 since the scenario category was added to scoring
- This created a false appearance of "scores going down" when the system was actually healthy
- The AHE pipeline uses benchmark scores to decide whether to keep or discard improvement candidates — a false deflation could trigger unnecessary rollbacks
- The bug was invisible for so long because the `???? → 8 char date → no match` issue affects ALL files, not edge cases

## When to Apply

- **When modifying benchmark file patterns**: Always verify the glob matches actual file naming conventions. Test with `Get-ChildItem` before committing.
- **When adding new scoring categories**: Ensure all sub-tests have working data sources before adding their weights to the formula.
- **When debugging score drops**: Check the per-test results first. If 24/25 tests pass but score is 95.6, it's the stability test.

## Examples

**Before (broken):**
```powershell
$bf = Get-ChildItem "$benchDir\benchmark-????-*.json" -EA 0
# Matches example-0430-data.json (4-char date) → finds 0 files
# Our files: benchmark-20260505-145732.json (8-char date) → NO MATCH
```

**After (fixed):**
```powershell
$bf = Get-ChildItem "$benchDir\benchmark-*.json" -EA 0
# Matches: benchmark-20260505-145732.json ✅
# Run files filtered out by Where-Object: -notmatch '-run\d+\.'
```

**Verification command:**
```powershell
# Check stability test spread
$d = "$env:USERPROFILE\.autoresearch\benchmarks"
$bf = Get-ChildItem "$d\benchmark-*.json" | Where-Object { $_.Name -notmatch '-run\d+\.' } | Sort-Object LastWriteTime -Descending | Select -First 5
$scores = @()
$bf | ForEach-Object {
    $c = Get-Content $_.FullName -Raw | ConvertFrom-Json
    $sv = if ($null -ne $c.median_score) { $c.median_score } else { $c.score }
    $scores += $sv
}
$spread = ($scores | Measure -Max).Maximum - ($scores | Measure -Min).Minimum
Write-Host "Spread: $spread (need ≤1 for 3/3)"
```

## Related

- [Benchmark system](../benchmark.ps1) — Line 125, the stability test glob pattern
- [Settings.json BOM Incident](../../memory/project/settings-json-bom-incident-2026-05-05.md) — Caused the 80.9 scores that inflated the spread
- [AHE Pipeline Execution](project/ahe-pipeline-execution.md) — Pipeline that reads benchmark scores for decision making
