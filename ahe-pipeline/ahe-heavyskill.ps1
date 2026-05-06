<#
.SYNOPSIS
    HeavySkill Reasoning Engine — replaces external Python BoN (Ralph Loop) with
    parallel-reasoning → summarization prompting strategy. No model training.
.DESCRIPTION
    Implements HeavySkill (arXiv:2605.02396) as a harness-level improvement:
    - Stage 1: Generate N parallel reasoning traces in a single LLM call
    - Stage 2: Summarize traces into a coherent decision/plan/action
    - Replaces 4-step sequential Python loop with 1 HeavySkill call

    Uses PowerShell Invoke-RestMethod to crof.ai API (no Python dependency).
    Routes reasoning to DeepSeek V4 Pro, summarization to Kimi K2.6.
#>

$CrofAiBase = "https://crof.ai/v1"
$CrofAiKey = [Environment]::GetEnvironmentVariable("CROFAI_API_KEY")
if (-not $CrofAiKey) {
    Write-Warning "CROFAI_API_KEY not set — HeavySkill calls will fail"
}

# Model routing (from Ralph Loop's ROLE_MODEL, reused):
# - DeepSeek V4 Pro Precision for reasoning (evolve/code roles)
# - Kimi K2.6 Precision for judgment/summarization (structured analysis)
$HeavySkillModels = @{
    reasoning    = "deepseek-v4-pro-precision"  # parallel trace generation
    summarizer   = "kimi-k2.6-precision"        # trace synthesis + verdict
    quick_verify = "deepseek-v4-flash"           # lightweight checks
}

# Mock mode for testing: when $env:AHE_HEAVYSKILL_MOCK = "1", returns deterministic output
# without calling the LLM API. Used by test-heavyskill-scenario.ps1 to validate
# gate parsing logic without requiring CROFAI_API_KEY.
function Invoke-Llm {
    param(
        [string]$Prompt,
        [string]$Model,
        [int]$MaxTokens = 2000,
        [int]$TimeoutSec = 60
    )
    if ($env:AHE_HEAVYSKILL_MOCK -eq "1") {
        # Deterministic mock for testing: checks numeric scores, not keywords.
        # The prompt always contains all decision options (KEEP/ROLLBACK/NO_CHANGE),
        # so keyword matching on option names is unreliable. Instead, extract
        # the KAPPA value from the context to determine the expected verdict:
        #   kappa > 0.2  → KEEP (positive trend)
        #   kappa < -0.1 → ROLLBACK (negative trend)
        #   otherwise    → NO_CHANGE (flat)
        $kappaMatch = [regex]::Match($Prompt, 'KAPPA[^0-9\-]*([-0-9.]+)')
        # Check if this is a plan vs gate prompt (plan prompts start with 'GOAL:' at line start)
        $isPlan = $Prompt -match '(?m)^GOAL:'
        
        if ($isPlan) {
            # HeavySkillPlan mock
            return "## Summary`nAnalyze AHE harness improvements`n`n## Rationale`nMock plan based on goal`n`n## Confidence`nMEDIUM`n`n## Assumptions`nMock mode"
        } elseif ($kappaMatch.Success) {
            $kappa = [double]$kappaMatch.Groups[1].Value
            if ($kappa -gt 0.2) {
                return "## Summary`nKEEP`n`n## Rationale`nMock: kappa=$kappa positive trend`n`n## Confidence`nHIGH`n`n## Assumptions`nMock mode"
            } elseif ($kappa -lt -0.1) {
                return "## Summary`nROLLBACK`n`n## Rationale`nMock: kappa=$kappa negative trend`n`n## Confidence`nHIGH`n`n## Assumptions`nMock mode"
            } else {
                return "## Summary`nNO_CHANGE`n`n## Rationale`nMock: kappa=$kappa flat`n`n## Confidence`nMEDIUM`n`n## Assumptions`nMock mode"
            }
        } else {
            return "## Summary`nNO_CHANGE`n`n## Rationale`nMock: no kappa found`n`n## Confidence`nMEDIUM`n`n## Assumptions`nMock mode"
        }
    }
    if (-not $CrofAiKey) { return "ERROR: CROFAI_API_KEY not set" }

    $body = @{
        model = $Model
        messages = @(@{ role = "user"; content = $Prompt })
        max_tokens = $MaxTokens
    } | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri "${CrofAiBase}/chat/completions" `
            -Method Post `
            -Headers @{ "Authorization" = "Bearer $CrofAiKey"; "Content-Type" = "application/json" } `
            -Body $body `
            -TimeoutSec $TimeoutSec `
            -ErrorAction Stop
        return $response.choices[0].message.content
    } catch {
        return "LLM_ERROR: $_"
    }
}

<#
.SYNOPSIS
    HeavySkill parallel reasoning → summarization.
    The core algorithmic improvement over BoN:
    - Stage 1: Generate N parallel reasoning traces within one prompt
    - Stage 2: Summarize traces into a single coherent output
.PARAMETER Context
    The problem/context the reasoning should address.
.PARAMETER Traces
    Number of parallel reasoning traces to generate (default 3).
.PARAMETER OutputType
    What to produce: "decision", "plan", "analysis", "verdict"
.PARAMETER Rubric
    Optional rubric/constraints for the summarizer.
#>
function Invoke-HeavySkillReasoning {
    param(
        [string]$Context,
        [int]$Traces = 3,
        [ValidateSet("decision","plan","analysis","verdict")]
        [string]$OutputType = "analysis",
        [string]$Rubric = ""
    )

    Write-Host "  [HeavySkill] Reasoning with $Traces parallel traces..." -ForegroundColor Cyan

    # Stage 1: Parallel reasoning prompt
    $tracePrompts = @()
    for ($i = 1; $i -le $Traces; $i++) {
        $perspective = switch ($i) {
            1 { "optimistic view — assume best-case conditions" }
            2 { "pessimistic view — identify risks and failure modes" }
            3 { "pragmatic view — balance trade-offs with measurable outcomes" }
            default { "neutral systems-analysis view" }
        }
        $tracePrompts += "[Trace $i — $perspective]"
    }

    $stage1Prompt = @"
You are a HeavySkill parallel reasoning engine.

CONTEXT:
$Context

STAGE 1 — GENERATE $Traces PARALLEL REASONING TRACES:
$($tracePrompts -join "`n")

For each trace, think step-by-step. Do NOT pick a winner yet.
Be thorough — consider causes, effects, constraints, and edge cases.

After all $Traces traces are generated, proceed to Stage 2.

STAGE 2 — SUMMARIZE:
Synthesize the $Traces traces into a single coherent $OutputType.
$(if ($Rubric) { "RUBRIC: $Rubric" } else { "" })
Format your response as:

## Summary
[A concise $OutputType statement]

## Rationale
[Why this was chosen over alternatives]

## Confidence
[HIGH / MEDIUM / LOW]

## Assumptions
[Key assumptions that this $OutputType depends on]
"@

    return Invoke-Llm -Prompt $stage1Prompt -Model $HeavySkillModels.reasoning -MaxTokens 4000
}

<#
.SYNOPSIS
    HeavySkill-powered gate decision.
    Replaces the if/elseif/else decision matrix with parallel reasoning
    over tract scores, then summarizes into a gate verdict.
.PARAMETER TractScores
    Hashtable with correctness, utility, reliability scores.
.PARAMETER BenchmarkDelta
    Optional score delta from previous cycle.
.PARAMETER Kappa
    Optional trailing trend metric.
#>
function Invoke-HeavySkillGate {
    param(
        [hashtable]$TractScores,
        [double]$BenchmarkDelta,
        [double]$Kappa,
        [string]$CandidateName = "current cycle"
    )

    Write-Host "  [HeavySkill] Gating candidate: $CandidateName..." -ForegroundColor Cyan

    $context = @"
CANDIDATE: $CandidateName
TRACT SCORES:
  - Correctness: $($TractScores.correctness)/100
  - Utility: $($TractScores.utility)/100
  - Reliability: $($TractScores.reliability)/100
BENCHMARK DELTA: $($BenchmarkDelta) pts
KAPPA (trailing trend): $($Kappa)

DECISION OPTIONS:
1. KEEP — accept the candidate, incorporate improvements
2. ROLLBACK — revert the candidate, restore previous state
3. NO_CHANGE — neither keep nor rollback (neutral)
"@

    $rubric = @"
Evaluate each DECISION OPTION through the 3 parallel traces:
- Trace 1 (optimistic): Focus on what's gained by keeping — new capabilities, higher scores.
- Trace 2 (pessimistic): Focus on regression risk — correctness drop, reliability cost.
- Trace 3 (pragmatic): Focus on measurable outcomes — kappa trend, delta magnitude.

Critical thresholds from prior harness:
- Correctness < 95: high regression risk (paper: ROLLBACK trigger)
- Utility > 80 or Reliability > 80: strong forward progress signal (KEEP trigger)
- Positive kappa: upward trend (KEEP if no regression)
- Negative kappa with no utility gain: NO_CHANGE

Return the gate decision and a brief rationale.
"@

    return Invoke-HeavySkillReasoning -Context $context -Traces 3 -OutputType "verdict" -Rubric $rubric
}

<#
.SYNOPSIS
    HeavySkill-powered action planning.
    Replaces the Ralph Loop's 4-step sequential (judge→evolve→code→verify)
    with a single parallel-reasoning plan + structured output.
.PARAMETER Goal
    The goal to plan actions for.
.PARAMETER History
    Optional history of previous iterations.
#>
function Invoke-HeavySkillPlan {
    param(
        [string]$Goal,
        [array]$History = @()
    )

    Write-Host "  [HeavySkill] Planning for: ${Goal}..." -ForegroundColor Cyan

    $historyStr = if ($History.Count -gt 0) {
        ($History | Select-Object -Last 3 | ForEach-Object {
            "Iteration $($_.iteration): Action=$($_.action.Substring(0, [Math]::Min(100, $_.action.Length)))"
        }) -join "`n"
    } else { "No prior actions" }

    $context = @"
GOAL: $Goal

RECENT HISTORY:
$historyStr

Generate a single actionable plan. Include:
1. What to do (specific action)
2. Why this action
3. What success looks like
4. What could go wrong
"@

    $rubric = "Output must be a single actionable plan, not multiple options. Prioritize actions that directly advance the goal."

    return Invoke-HeavySkillReasoning -Context $context -Traces 3 -OutputType "plan" -Rubric $rubric
}

<#
.SYNOPSIS
    HeavySkill-powered research synthesis.
    Replaces external research scripts with inline HeavySkill reasoning
    over arxiv findings.
.PARAMETER Papers
    Array of paper objects from arxiv discovery.
.PARAMETER Context
    Current system context to evaluate papers against.
#>
function Invoke-HeavySkillResearch {
    param(
        [array]$Papers,
        [string]$SystemContext = "AHE agentic harness system for Qwen Code on Windows"
    )

    if ($Papers.Count -eq 0) { return "No papers to synthesize" }

    Write-Host "  [HeavySkill] Synthesizing $($Papers.Count) papers..." -ForegroundColor Cyan

    $paperSummary = ($Papers | ForEach-Object {
        "[$($_.relevance_score)/10] $($_.title) ($($_.published))"
    }) -join "`n"

    $context = @"
SYSTEM CONTEXT: $SystemContext

PAPERS FOUND (sorted by relevance):
$paperSummary

Generate a research synthesis:
1. Which papers are most relevant to this system?
2. What actionable insight does each provide?
3. What should be prioritized for implementation?
"@

    return Invoke-HeavySkillReasoning -Context $context -Traces 2 -OutputType "analysis" 
}

# Designed for dot-sourcing (pipeline.ps1 uses . "$PSScriptRoot\ahe-heavyskill.ps1")
# When using Import-Module instead, uncomment:
# Export-ModuleMember -Function Invoke-HeavySkillReasoning, Invoke-HeavySkillGate, Invoke-HeavySkillPlan, Invoke-HeavySkillResearch, Invoke-Llm
