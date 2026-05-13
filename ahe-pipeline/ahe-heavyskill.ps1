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

# Runtime-configurable presets for RL-scalable parameters.
# Selected by -Preset parameter on Invoke-HeavySkillReasoning/Gate/Plan/Research.
# Can be overridden via $env:AHE_HEAVYSKILL_PRESET for debugging.
# Level 4: These are the "trainable params" — trace count, model routing, max_tokens.
$HeavySkillPresets = @{
    quick = @{
        traces     = 2
        model      = $HeavySkillModels.quick_verify  # deepseek-v4-flash
        max_tokens = 2000
        label      = "quick"
    }
    balanced = @{
        traces     = 3
        model      = $HeavySkillModels.reasoning     # deepseek-v4-pro-precision
        max_tokens = 4000
        label      = "balanced"
    }
    deep = @{
        traces     = 5
        model      = $HeavySkillModels.reasoning     # deepseek-v4-pro-precision
        max_tokens = 8000
        label      = "deep"
    }
}

<#
.SYNOPSIS
    Selects a HeavySkill preset based on: env override -> explicit param -> default.
    When env AHE_HEAVYSKILL_PRESET is set, it takes priority (for debugging).
.PARAMETER Preset
    The explicit -Preset parameter value (empty string = not provided).
#>
function Resolve-HeavySkillPreset {
    param([string]$Preset = "balanced")
    # Env var override takes priority
    $envPreset = [Environment]::GetEnvironmentVariable("AHE_HEAVYSKILL_PRESET")
    if ($envPreset -and $HeavySkillPresets.ContainsKey($envPreset)) {
        return $HeavySkillPresets[$envPreset]
    }
    # Explicit param or default
    $key = if ($Preset -and $HeavySkillPresets.ContainsKey($Preset)) { $Preset } else { "balanced" }
    return $HeavySkillPresets[$key]
}

<#
.SYNOPSIS
    Selects HeavySkill preset based on evaluation scores from S01.
    High confidence -> quick (spend less), low confidence -> deep (spend more).
.PARAMETER EvalScores
    Hashtable with VerdictAccuracy, ReasoningCoherence, PlanActionability keys (0-1).
#>
function Select-HeavySkillPreset {
    param([hashtable]$EvalScores)

    $envPreset = [Environment]::GetEnvironmentVariable("AHE_HEAVYSKILL_PRESET")
    if ($envPreset -and $HeavySkillPresets.ContainsKey($envPreset)) {
        return $envPreset
    }

    if (-not $EvalScores) { return "balanced" }

    $acc = if ($EvalScores.ContainsKey('VerdictAccuracy')) { $EvalScores.VerdictAccuracy } else { 0.5 }
    $coh = if ($EvalScores.ContainsKey('ReasoningCoherence')) { $EvalScores.ReasoningCoherence } else { 0.5 }
    $act = if ($EvalScores.ContainsKey('PlanActionability')) { $EvalScores.PlanActionability } else { 0 }

    # High eval confidence -> quick (trace cheap, eval says we're good)
    if ($act -ge 0.8 -and $coh -ge 0.9) { return "quick" }
    # Low eval confidence -> deep (need more reasoning to get it right)
    if ($acc -lt 0.3 -or $coh -lt 0.5) { return "deep" }
    # Default
    return "balanced"
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
        [string]$Rubric = "",
        [ValidateSet("quick","balanced","deep","")]
        [string]$Preset = ""
    )

    # Resolve preset (env override -> explicit -> default "balanced")
    $config = Resolve-HeavySkillPreset -Preset $Preset
    $traceCount = $config.traces
    $model = $config.model
    $maxTokens = $config.max_tokens

    Write-Host "  [HeavySkill] Reasoning with $traceCount parallel traces ($($config.label))..." -ForegroundColor Cyan

    # Stage 1: Parallel reasoning prompt
    $tracePrompts = @()
    for ($i = 1; $i -le $traceCount; $i++) {
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

STAGE 1 — GENERATE $traceCount PARALLEL REASONING TRACES:
$($tracePrompts -join "`n")

For each trace, think step-by-step. Do NOT pick a winner yet.
Be thorough — consider causes, effects, constraints, and edge cases.

After all $traceCount traces are generated, proceed to Stage 2.

STAGE 2 — SUMMARIZE:
Synthesize the $traceCount traces into a single coherent $OutputType.
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

    return Invoke-Llm -Prompt $stage1Prompt -Model $model -MaxTokens $maxTokens
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
        [string]$CandidateName = "current cycle",
        [switch]$ReturnEval,
        [ValidateSet("quick","balanced","deep","")]
        [string]$Preset = ""
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

    $output = Invoke-HeavySkillReasoning -Context $context -OutputType "verdict" -Rubric $rubric -Preset $Preset

    if ($ReturnEval) {
        $hasKappa = ($Kappa -ne 0)
        $resolvePreset = Resolve-HeavySkillPreset -Preset $Preset
        $eval = Write-HeavySkillEvalResult -Output $output -FunctionName "Gate" -Mode gate -Kappa $Kappa -MockBaseline:$hasKappa -AutoTune -CurrentPreset $resolvePreset.label
        return @($output, $eval)
    }

    return $output
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
        [array]$History = @(),
        [switch]$ReturnEval,
        [ValidateSet("quick","balanced","deep","")]
        [string]$Preset = ""
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

    $output = Invoke-HeavySkillReasoning -Context $context -OutputType "plan" -Rubric $rubric -Preset $Preset

    if ($ReturnEval) {
        $resolvePreset = Resolve-HeavySkillPreset -Preset $Preset
        $eval = Write-HeavySkillEvalResult -Output $output -FunctionName "Plan" -Mode plan -AutoTune -CurrentPreset $resolvePreset.label
        return @($output, $eval)
    }

    return $output
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
        [string]$SystemContext = "AHE agentic harness system for Qwen Code on Windows",
        [switch]$ReturnEval,
        [ValidateSet("quick","balanced","deep","")]
        [string]$Preset = ""
    )

    if ($Papers.Count -eq 0) { 
        if ($ReturnEval) { return @("No papers to synthesize", (Invoke-HeavySkillEval -HeavySkillOutput "No papers to synthesize" -Mode research)) }
        return "No papers to synthesize" 
    }

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

    $output = Invoke-HeavySkillReasoning -Context $context -OutputType "analysis" -Preset $Preset

    if ($ReturnEval) {
        $resolvePreset = Resolve-HeavySkillPreset -Preset $Preset
        $eval = Write-HeavySkillEvalResult -Output $output -FunctionName "Research" -Mode research -AutoTune -CurrentPreset $resolvePreset.label
        return @($output, $eval)
    }

    return $output
}

<#
.SYNOPSIS
    Evaluates HeavySkill output quality per invocation — no LLM calls.
    Scores three dimensions: verdict accuracy, reasoning coherence, plan actionability.
.DESCRIPTION
    Parses HeavySkill structured output (## Summary, ## Rationale, ## Confidence,
    ## Assumptions sections) deterministically. For mock mode, compares extracted
    verdict against kappa-driven expected baselines.

    Scoring dimensions:
    - VerdictAccuracy (0-1): Does the ## Summary verdict match the mock-mode baseline?
      Without -MockBaseline or -ExpectedVerdict, returns 0.5 (unknown).
    - ReasoningCoherence (0-1): Are all 4 required sections present and non-empty?
    - PlanActionability (0-1): Does the output contain concrete action verbs
      vs analysis-only content? Adjusted by -Mode.
.PARAMETER HeavySkillOutput
    The raw text output from Invoke-HeavySkillGate, Invoke-HeavySkillPlan, etc.
.PARAMETER ExpectedVerdict
    Optional expected verdict for accuracy comparison (e.g., "KEEP", "ROLLBACK", "NO_CHANGE").
.PARAMETER Mode
    Output type being evaluated: 'gate' (default), 'plan', or 'research'.
    Adjusts actionability scoring thresholds.
.PARAMETER MockBaseline
    When set, uses the same kappa->verdict mapping as Invoke-Llm mock mode
    to determine expected verdict. Requires -Kappa to be set.
.PARAMETER Kappa
    Kappa value used with -MockBaseline to determine expected verdict.
#>
function Invoke-HeavySkillEval {
    param(
        [string]$HeavySkillOutput,
        [ValidateSet("","KEEP","ROLLBACK","NO_CHANGE")]
        [string]$ExpectedVerdict = "",
        [ValidateSet("gate","plan","research")]
        [string]$Mode = "gate",
        [switch]$MockBaseline,
        [double]$Kappa = 0
    )

    $scores = @{
        VerdictAccuracy = 0.5
        ReasoningCoherence = 0.0
        PlanActionability = 0.0
        SectionsPresent = @()
        SectionsMissing = @()
        Confidence = ""
        Summary = ""
        Rationale = ""
        RawLines = 0
    }

    if ([string]::IsNullOrEmpty($HeavySkillOutput)) {
        $scores.ReasoningCoherence = 0.0
        $scores.SectionsMissing = @("Summary", "Rationale", "Confidence", "Assumptions")
        return $scores
    }

    $lines = $HeavySkillOutput -split "`n"
    $scores.RawLines = $lines.Count

    # ── Parse required sections ──
    $summaryMatch = [regex]::Match($HeavySkillOutput, '(?ms)^## Summary\s*\n(.+?)(?=\n## |\Z)')
    $rationaleMatch = [regex]::Match($HeavySkillOutput, '(?ms)^## Rationale\s*\n(.+?)(?=\n## |\Z)')
    $confidenceMatch = [regex]::Match($HeavySkillOutput, '(?ms)^## Confidence\s*\n(.+?)(?=\n## |\Z)')
    $assumptionsMatch = [regex]::Match($HeavySkillOutput, '(?ms)^## Assumptions\s*\n(.+?)(?=\n## |\Z)')

    $sections = @{
        Summary     = if ($summaryMatch.Success) { $summaryMatch.Groups[1].Value.Trim() } else { "" }
        Rationale   = if ($rationaleMatch.Success) { $rationaleMatch.Groups[1].Value.Trim() } else { "" }
        Confidence  = if ($confidenceMatch.Success) { $confidenceMatch.Groups[1].Value.Trim() } else { "" }
        Assumptions = if ($assumptionsMatch.Success) { $assumptionsMatch.Groups[1].Value.Trim() } else { "" }
    }

    foreach ($key in $sections.Keys) {
        if ($sections[$key] -and $sections[$key].Length -gt 0) {
            $scores.SectionsPresent += $key
        } else {
            $scores.SectionsMissing += $key
        }
    }

    $scores.Summary = $sections.Summary
    $scores.Rationale = $sections.Rationale
    $scores.Confidence = $sections.Confidence

    # ── Reasoning Coherence (0-1) ──
    $presentCount = $scores.SectionsPresent.Count
    $totalSections = 4
    $scores.ReasoningCoherence = [Math]::Round($presentCount / $totalSections, 2)

    # ── Verdict Accuracy (0-1) ──
    $actualVerdict = ""
    if ($sections.Summary) {
        $vMatch = [regex]::Match($sections.Summary, '\b(KEEP|ROLLBACK|NO_CHANGE)\b')
        if ($vMatch.Success) {
            $actualVerdict = $vMatch.Groups[1].Value
        }
    }

    $expected = $ExpectedVerdict
    if (-not $expected -and $MockBaseline) {
        if ($Kappa -gt 0.2) {
            $expected = "KEEP"
        } elseif ($Kappa -lt -0.1) {
            $expected = "ROLLBACK"
        } else {
            $expected = "NO_CHANGE"
        }
    }

    if ($expected -and $actualVerdict -eq $expected) {
        $scores.VerdictAccuracy = 1.0
    } elseif ($expected -and $actualVerdict -ne $expected -and $actualVerdict) {
        $scores.VerdictAccuracy = 0.0
    } elseif ($actualVerdict) {
        $scores.VerdictAccuracy = 0.5
    }

    # ── Plan Actionability (0-1) ──
    $actionVerbs = @("Run", "Add", "Update", "Create", "Remove", "Replace", "Deploy", "Refactor", "Test", "Wire", "Install", "Configure", "Migrate", "Rename", "Delete", "Extract", "Merge", "Split", "Restart", "Enable", "Disable", "Generate", "Write", "Build", "Compile", "Execute", "Apply", "Set", "Export", "Import")
    $analysisVerbs = @("Consider", "Analyze", "Evaluate", "Think", "Review", "Assess", "Examine")

    $wordCount = 0
    $actionCount = 0
    $analysisCount = 0

    if ($Mode -ne "research") {
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if (-not $trimmed -or $trimmed -match '^## ') { continue }
            $words = $trimmed -split '\s+'
            $wordCount += $words.Count
            foreach ($word in $words) {
                $clean = $word -replace '[^a-zA-Z]', ''
                if ($clean.Length -eq 0) { continue }
                if ($actionVerbs -contains $clean) { $actionCount++ }
                if ($analysisVerbs -contains $clean) { $analysisCount++ }
            }
        }
    }

    if ($wordCount -gt 0) {
        $actionRatio = $actionCount / [Math]::Max(1, $wordCount)
        if ($Mode -eq "plan") {
            $scores.PlanActionability = [Math]::Min(1.0, [Math]::Round($actionRatio * 50, 2))
        } elseif ($Mode -eq "gate") {
            $scores.PlanActionability = [Math]::Round([Math]::Min(1.0, $actionCount / 3.0), 2)
        }
    }

    return $scores
}

<#
.SYNOPSIS
    Helper: runs Invoke-HeavySkillEval, persists to file, logs summary.
    Called by Invoke-HeavySkillGate/Plan/Research when -ReturnEval is set.
#>
function Write-HeavySkillEvalResult {
    param(
        [string]$Output,
        [string]$FunctionName,
        [ValidateSet("gate","plan","research")][string]$Mode = "gate",
        [switch]$MockBaseline,
        [double]$Kappa = 0,
        [string]$ExpectedVerdict = "",
        [switch]$AutoTune,
        [ValidateSet("quick","balanced","deep")]
        [string]$CurrentPreset = "balanced"
    )

    $eval = Invoke-HeavySkillEval -HeavySkillOutput $Output -Mode $Mode -MockBaseline:$MockBaseline -Kappa $Kappa -ExpectedVerdict $ExpectedVerdict

    # Compute output hash
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Output))
    $hashStr = -join ($hashBytes[0..3] | ForEach-Object { $_.ToString("x2") })

    # Persist to file
    $evalDir = if ($env:AHE_EVAL_DIR) { $env:AHE_EVAL_DIR } else { "$env:USERPROFILE\.autoresearch\reasoning-eval" }
    $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
    $evalPath = "$evalDir\$timestamp-$FunctionName.json"

    # Extract verdict from eval
    $vMatch = [regex]::Match($eval.Summary, '\b(KEEP|ROLLBACK|NO_CHANGE)\b')
    $verdict = if ($vMatch.Success) { $vMatch.Groups[1].Value } else { "NONE" }

    $evalRecord = @{
        timestamp = (Get-Date -Format "o")
        heavySkillFunction = $FunctionName
        verdict = $verdict
        outputHash = $hashStr
        scores = @{
            accuracy = $eval.VerdictAccuracy
            coherence = $eval.ReasoningCoherence
            actionability = $eval.PlanActionability
        }
        sectionsFound = $eval.SectionsPresent
        confidence = $eval.Confidence
        rawLines = $eval.RawLines
    } | ConvertTo-Json -Compress

    # Write to file, create dir if needed
    try {
        $parentDir = Split-Path $evalPath -Parent
        if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }
        $evalRecord | Set-Content -Path $evalPath -Encoding UTF8
    } catch {
        Write-Warning "HeavySkillEval: Could not persist to $evalPath : $_"
        $evalPath = "(disk write failed)"
    }

    Write-Host "  [HeavySkillEval] $FunctionName=$verdict | Acc=$($eval.VerdictAccuracy) Coh=$($eval.ReasoningCoherence) Act=$($eval.PlanActionability) | $evalPath" -ForegroundColor DarkYellow

    # Auto-tune: if flag set, run auto-tuning after writing eval
    if ($AutoTune) {
        $autoResult = Invoke-HeavySkillAutoTune -EvalDir $evalDir -CurrentPreset $CurrentPreset
        $eval | Add-Member -NotePropertyName "autoTune" -NotePropertyValue $autoResult -Force
    }

    return $eval
}

<#
.SYNOPSIS
    Reads all eval log files from .autoresearch/reasoning-eval/.
    Returns structured arrays of per-function scores for trend analysis.
#>
function Invoke-ReadEvalLogs {
    param(
        [string]$EvalDir = "$env:USERPROFILE\.autoresearch\reasoning-eval"
    )

    $allEntries = @()
    $files = Get-ChildItem "$EvalDir\*.json" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'trend.json' } | Sort-Object LastWriteTime

    foreach ($f in $files) {
        try {
            $data = Get-Content $f.FullName -Raw | ConvertFrom-Json
            $allEntries += [PSCustomObject]@{
                timestamp = $data.timestamp
                function = $data.heavySkillFunction
                verdict = $data.verdict
                accuracy = [double]$data.scores.accuracy
                coherence = [double]$data.scores.coherence
                actionability = [double]$data.scores.actionability
                confidence = $data.confidence
                sourceFile = $f.Name
            }
        } catch { continue }
    }

    return $allEntries
}

<#
.SYNOPSIS
    Computes moving averages and trend stats from eval log entries.
#>
function Invoke-ComputeEvalTrend {
    param(
        [array]$EvalEntries,
        [int]$ShortWindow = 3,
        [int]$LongWindow = 10
    )

    if ($EvalEntries.Count -eq 0) {
        return @{
            totalEvals = 0
            avgAccuracy = 0
            avgCoherence = 0
            avgActionability = 0
            shortWindow = $ShortWindow
            longWindow = $LongWindow
            movingAvgAccuracy = 0
            movingAvgCoherence = 0
            movingAvgActionability = 0
            entries = @()
        }
    }

    # Overall averages
    $totalAccuracy = ($EvalEntries | Measure-Object accuracy -Average).Average
    $totalCoherence = ($EvalEntries | Measure-Object coherence -Average).Average
    $totalActionability = ($EvalEntries | Measure-Object actionability -Average).Average

    # Moving averages (most recent N entries)
    $recentAccuracy = 0
    $recentCoherence = 0
    $recentActionability = 0
    $window = [Math]::Min($ShortWindow, $EvalEntries.Count)
    if ($window -gt 0) {
        $recent = $EvalEntries | Select-Object -Last $window
        $recentAccuracy = ($recent | Measure-Object accuracy -Average).Average
        $recentCoherence = ($recent | Measure-Object coherence -Average).Average
        $recentActionability = ($recent | Measure-Object actionability -Average).Average
    }

    # Longer-moving averages
    $longAccuracy = 0
    $longCoherence = 0
    $longActionability = 0
    $lw = [Math]::Min($LongWindow, $EvalEntries.Count)
    if ($lw -gt 0) {
        $long = $EvalEntries | Select-Object -Last $lw
        $longAccuracy = ($long | Measure-Object accuracy -Average).Average
        $longCoherence = ($long | Measure-Object coherence -Average).Average
        $longActionability = ($long | Measure-Object actionability -Average).Average
    }

    return @{
        totalEvals = $EvalEntries.Count
        avgAccuracy  = [Math]::Round($totalAccuracy, 3)
        avgCoherence  = [Math]::Round($totalCoherence, 3)
        avgActionability = [Math]::Round($totalActionability, 3)
        shortWindow  = $window
        longWindow   = $lw
        movingAvgAccuracy  = [Math]::Round($recentAccuracy, 3)
        movingAvgCoherence = [Math]::Round($recentCoherence, 3)
        movingAvgActionability = [Math]::Round($recentActionability, 3)
        longAvgAccuracy  = [Math]::Round($longAccuracy, 3)
        longAvgCoherence = [Math]::Round($longCoherence, 3)
        longAvgActionability = [Math]::Round($longActionability, 3)
        trend = if ($recentAccuracy -gt $totalAccuracy) { "improving" } elseif ($recentAccuracy -lt $totalAccuracy) { "declining" } else { "stable" }
        entries = $EvalEntries
    }
}

<#
.SYNOPSIS
    Computes a simple correlation between eval scores and benchmark kappa.
    Uses rank-order comparison (non-parametric) to avoid distribution assumptions.
    Returns -1 to 1 where positive = eval scores move with benchmark.
#>
function Invoke-CorrelateEvalAndBenchmark {
    param(
        [array]$EvalAccuracySeries,
        [array]$KappaSeries
    )

    if ($EvalAccuracySeries.Count -lt 2 -or $KappaSeries.Count -lt 2) {
        return @{ correlation = 0; samples = [Math]::Min($EvalAccuracySeries.Count, $KappaSeries.Count); note = "insufficient data" }
    }

    $minLen = [Math]::Min($EvalAccuracySeries.Count, $KappaSeries.Count)
    $paired = for ($i = 0; $i -lt $minLen; $i++) {
        [PSCustomObject]@{ eval = $EvalAccuracySeries[$i]; kappa = $KappaSeries[$i] }
    }

    # Simple direction-match correlation: do eval and kappa move in same direction?
    $agreeCount = 0
    $totalPairs = 0
    for ($i = 1; $i -lt $paired.Count; $i++) {
        $evalDelta = $paired[$i].eval - $paired[$i-1].eval
        $kappaDelta = $paired[$i].kappa - $paired[$i-1].kappa
        $totalPairs++
        if (($evalDelta -gt 0 -and $kappaDelta -gt 0) -or ($evalDelta -lt 0 -and $kappaDelta -lt 0) -or ($evalDelta -eq 0 -and $kappaDelta -eq 0)) {
            $agreeCount++
        }
    }

    $correlation = if ($totalPairs -gt 0) { [Math]::Round(($agreeCount / $totalPairs) * 2 - 1, 3) } else { 0 }

    return @{ correlation = $correlation; samples = $paired.Count; directionAgreement = "$agreeCount/$totalPairs"; note = "ok" }
}

<#
.SYNOPSIS
    Writes evaluation trend data to gbrain and local trend.json.
    Called from pipeline compound phase (or standalone for debugging).
#>
function Write-GbrainEvalTrend {
    param(
        [string]$EvalDir = "$env:USERPROFILE\.autoresearch\reasoning-eval",
        [switch]$SkipGbrain
    )

    $entries = Invoke-ReadEvalLogs -EvalDir $EvalDir
    $trend = Invoke-ComputeEvalTrend -EvalEntries $entries
    $date = Get-Date -Format "yyyy-MM-dd"

    # Build gbrain content
    $trendContent = @"
# Reasoning Quality Trend — $date
**Source:** AHE HeavySkill Evaluation (S01)

## Summary
- **Total evaluations:** $($trend.totalEvals)
- **Overall accuracy:** $($trend.avgAccuracy)
- **Overall coherence:** $($trend.avgCoherence)
- **Overall actionability:** $($trend.avgActionability)
- **Trend:** $($trend.trend)

## Moving Averages ($($trend.shortWindow)-cycle)
- **Accuracy:** $($trend.movingAvgAccuracy) (long: $($trend.longAvgAccuracy))
- **Coherence:** $($trend.movingAvgCoherence) (long: $($trend.longAvgCoherence))
- **Actionability:** $($trend.movingAvgActionability) (long: $($trend.longAvgActionability))

## Per-Function Breakdown
$(($entries | Group-Object function | ForEach-Object {
    $g = $_.Group
    $avgAcc = [Math]::Round(($g | Measure-Object accuracy -Average).Average, 3)
    $avgCoh = [Math]::Round(($g | Measure-Object coherence -Average).Average, 3)
    $avgAct = [Math]::Round(($g | Measure-Object actionability -Average).Average, 3)
    "- **$($_.Name)**: $($_.Count) calls | Acc=$avgAcc Coh=$avgCoh Act=$avgAct"
}) -join "`n")
"@

    # Save local trend.json
    try {
        $trendJson = @{
            updated = (Get-Date -Format "o")
            totalEvals = $trend.totalEvals
            overall = @{
                avgAccuracy = $trend.avgAccuracy
                avgCoherence = $trend.avgCoherence
                avgActionability = $trend.avgActionability
                trend = $trend.trend
            }
            movingAverage = @{
                shortWindow = $trend.shortWindow
                shortAccuracy = $trend.movingAvgAccuracy
                shortCoherence = $trend.movingAvgCoherence
                shortActionability = $trend.movingAvgActionability
                longAccuracy = $trend.longAvgAccuracy
                longCoherence = $trend.longAvgCoherence
                longActionability = $trend.longAvgActionability
            }
        } | ConvertTo-Json -Depth 3 -Compress

        if (-not (Test-Path $EvalDir)) { New-Item -ItemType Directory -Path $EvalDir -Force | Out-Null }
        $trendJson | Set-Content "$EvalDir\trend.json" -Encoding UTF8
        Write-Host "  [EvalTrend] Local trend saved: $EvalDir\trend.json" -ForegroundColor DarkYellow
    } catch {
        Write-Warning "EvalTrend: Could not save local trend: $_"
    }

    # Write to gbrain via SSH
    if (-not $SkipGbrain) {
        try {
            $tempFile = [System.IO.Path]::GetTempFileName() + ".md"
            $trendContent | Set-Content -Path $tempFile -Encoding UTF8 -Force
            $slug = "learnings/ahe/reasoning-quality-$date"
            $gbrainCmd = "export PATH=/home/alex/.bun/bin:`$PATH && /home/alex/.bun/bin/gbrain put $slug"
            Get-Content $tempFile -Raw | ssh alex@100.102.182.39 $gbrainCmd 2>&1 | Out-Null
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [EvalTrend] Gbrain OK: $slug" -ForegroundColor Green
            } else {
                Write-Host "  [EvalTrend] Gbrain FAIL: $slug (exit $LASTEXITCODE)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [EvalTrend] Gbrain SKIP: $_" -ForegroundColor Yellow
            try { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    return $trend
}

<#
.SYNOPSIS
    Auto-tuning: reads eval trend data and recommends HeavySkill preset adjustment.
    Decision logic for the feedback loop (S04):
    - Improving (avgAccuracy rising) → keep current preset
    - Stable (no significant change 3+ cycles) → escalate (warning, no change)
    - Regressed (avgAccuracy dropped >0.2) → fall back to 'balanced'
    - No data / error → 'balanced' default
.PARAMETER EvalDir
    Directory containing eval JSON files and trend.json.
.PARAMETER CurrentPreset
    The currently active preset name (for decision logging).
.PARAMETER RegressionThreshold
    Accuracy drop threshold for regression detection (default: 0.2).
.PARAMETER PlateauCycles
    Number of cycles without significant change to flag plateau (default: 3).
#>
function Invoke-HeavySkillAutoTune {
    param(
        [string]$EvalDir = "$env:USERPROFILE\.autoresearch\reasoning-eval",
        [ValidateSet("quick","balanced","deep")]
        [string]$CurrentPreset = "balanced",
        [double]$RegressionThreshold = 0.2,
        [int]$PlateauCycles = 3
    )

    $envOverride = [Environment]::GetEnvironmentVariable("AHE_HEAVYSKILL_PRESET")
    if ($envOverride -and $HeavySkillPresets.ContainsKey($envOverride)) {
        Write-Host "  [HeavySkillAutoTune] Env override active: $envOverride (bypassing auto-tune)" -ForegroundColor DarkYellow
        return @{ recommended = $envOverride; reason = "env-override"; action = "none" }
    }

    # Read trend data
    $trendFile = "$EvalDir\trend.json"
    $entries = @()
    if (Test-Path $trendFile) {
        try {
            $trendData = Get-Content $trendFile -Raw | ConvertFrom-Json
            if ($trendData.totalEvals -gt 0) {
                $entries = Invoke-ReadEvalLogs -EvalDir $EvalDir
            }
        } catch { }
    }

    if ($entries.Count -lt 2) {
        Write-Host "  [HeavySkillAutoTune] Insufficient eval data (count=$($entries.Count)) — staying at '$CurrentPreset'" -ForegroundColor DarkYellow
        return @{ recommended = $CurrentPreset; reason = "insufficient-data"; action = "none" }
    }

    # Compute recent accuracy trend
    $accuracies = $entries | Select-Object -ExpandProperty accuracy
    $recent3 = $accuracies | Select-Object -Last $PlateauCycles
    $prior3 = $accuracies | Select-Object -Last ([Math]::Min($PlateauCycles * 2, $accuracies.Count)) | Select-Object -First $PlateauCycles

    if ($recent3.Count -lt 2 -or $prior3.Count -lt 2) {
        Write-Host "  [HeavySkillAutoTune] Not enough cycles to detect trend — staying at '$CurrentPreset'" -ForegroundColor DarkYellow
        return @{ recommended = $CurrentPreset; reason = "insufficient-cycles"; action = "none" }
    }

    $recentAvg = ($recent3 | Measure-Object -Average).Average
    $priorAvg = ($prior3 | Measure-Object -Average).Average
    $delta = $recentAvg - $priorAvg

    # Decision logic
    if ($delta -lt (-$RegressionThreshold)) {
        # Regressed — fall back to balanced
        Write-Host "  [HeavySkillAutoTune] REGRESSION detected: accuracy dropped $([Math]::Round($delta,3)) — falling back to 'balanced'" -ForegroundColor Yellow
        return @{ recommended = "balanced"; reason = "regression"; action = "fallback"; delta = $delta }
    }

    if ([Math]::Abs($delta) -lt 0.05 -and $recent3.Count -ge $PlateauCycles) {
        # Plateaued — escalate (no preset change, but warn)
        Write-Host "  [HeavySkillAutoTune] PLATEAU detected: accuracy stable for $PlateauCycles cycles (delta=$([Math]::Round($delta,3))) — consider manual review" -ForegroundColor Yellow
        return @{ recommended = $CurrentPreset; reason = "plateau"; action = "escalate"; delta = $delta }
    }

    if ($delta -gt 0) {
        # Improving — keep current
        Write-Host "  [HeavySkillAutoTune] Improving: accuracy +$([Math]::Round($delta,3)) — staying at '$CurrentPreset'" -ForegroundColor Green
        return @{ recommended = $CurrentPreset; reason = "improving"; action = "keep"; delta = $delta }
    }

    # Stable — no change
    Write-Host "  [HeavySkillAutoTune] Stable: delta=$([Math]::Round($delta,3)) — staying at '$CurrentPreset'" -ForegroundColor DarkYellow
    return @{ recommended = $CurrentPreset; reason = "stable"; action = "none"; delta = $delta }
}

# Designed for dot-sourcing (pipeline.ps1 uses . "$PSScriptRoot\ahe-heavyskill.ps1")
# When using Import-Module instead, uncomment:
# Export-ModuleMember -Function Invoke-HeavySkillReasoning, Invoke-HeavySkillGate, Invoke-HeavySkillPlan, Invoke-HeavySkillResearch, Invoke-HeavySkillEval, Invoke-Llm
