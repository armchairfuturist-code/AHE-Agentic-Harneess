<#
.SYNOPSIS
    Smoke test for HeavySkill consolidation (Levels 1-3).
    Proves: module loads, gate reasoning works, pipeline doesn't spew errors.
    No CROFAI_API_KEY required for syntax/logic tests — only for actual LLM calls.
.DESCRIPTION
    Tests:
    1. Module syntax check (Import-Module dry-run)
    2. Pipeline.ps1 syntax check (script parsing)
    3. Gate decision with known inputs (mock mode)
    4. Swarm function signature (no external Python dependency)
    5. Orchestration simplicity (count external script calls)
#>

$ErrorActionPreference = 'Continue'
$RootDir = "C:\Users\Administrator\Documents\Projects\AHE-Agentic-Harness"
$PipelineFile = "$RootDir\ahe-pipeline\pipeline.ps1"
$HeavySkillFile = "$RootDir\ahe-pipeline\ahe-heavyskill.ps1"
$RalphLoopPy = "$RootDir\ahe-pipeline\archive\ahe-ralph-loop.py"

$Passed = 0
$Failed = 0
$Skipped = 0

function Test-Result {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    if ($Passed) {
        Write-Host "  ✅ $Name — $Detail" -ForegroundColor Green
        $script:Passed++
    } else {
        Write-Host "  ❌ $Name — $Detail" -ForegroundColor Red
        $script:Failed++
    }
}

function Test-Skip {
    param([string]$Name, [string]$Reason)
    Write-Host "  ⏭️  $Name — $Reason" -ForegroundColor Yellow
    $script:Skipped++
}

Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║    HeavySkill Consolidation — Scenario Test       ║" -ForegroundColor Magenta
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# ═════════════════════════════════════════════════════════════
# TEST 1: Pipeline Syntax Check
# ═════════════════════════════════════════════════════════════
Write-Host "── Test Group 1: Syntax & Parsing ──" -ForegroundColor Cyan

$parseOk = $false
try {
    $pe = @()
    $pt = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($PipelineFile, [ref]$pt, [ref]$pe)
    $parseOk = ($pe.Count -eq 0 -or $null -eq $pe)
    Test-Result "pipeline.ps1 parses" $parseOk $(if($parseOk){"No parse errors"}else{"$($pe.Count) parse errors"})
} catch {
    Test-Result "pipeline.ps1 parses" $false "Parse exception: $_"
}

$hsParseOk = $false
try {
    $he = @()
    $ht = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($HeavySkillFile, [ref]$ht, [ref]$he)
    $hsParseOk = ($he.Count -eq 0 -or $null -eq $he)
    Test-Result "ahe-heavyskill.ps1 parses" $hsParseOk $(if($hsParseOk){"No parse errors"}else{"$($he.Count) errors"})
} catch {
    Test-Result "ahe-heavyskill.ps1 parses" $false "Parse exception: $_"
}

# ═════════════════════════════════════════════════════════════
# TEST 2: No Python Dependency in Invoke-Swarm
# ═════════════════════════════════════════════════════════════
Write-Host "`n── Test Group 2: No Python Dependency ──" -ForegroundColor Cyan

$pipelineContent = Get-Content $PipelineFile -Raw

$hasPythonCall = $pipelineContent -match "python.*ralph-loop"
$hasOpenAiImport = $false
$ralphContent = Get-Content $RalphLoopPy -Raw -ErrorAction SilentlyContinue
if ($ralphContent) {
    $hasOpenAiImport = $ralphContent -match "import openai"
}

# Invoke-Swarm should NOT call python anymore
$swarmSection = $pipelineContent -match "(?s)function Invoke-Swarm.*?\n\}"
$swarmNoPython = $swarmSection -and -not ($pipelineContent -match "python.*ralph-loop" -and ($pipelineContent -match "Invoke-Swarm"))
# Simpler: check Invoke-Swarm doesn't reference ralph-loop.py
$swarmContentMatch = $pipelineContent -match "(?s)function Invoke-Swarm"
$swarmContent = if ($swarmContentMatch) {
    $start = $pipelineContent.IndexOf("function Invoke-Swarm")
    $end = $pipelineContent.IndexOf("function", $start + 20)
    if ($end -eq -1) { $end = $pipelineContent.Length - 1 }
    # Find the actual function end by brace matching
    $braceCount = 0
    $foundStart = $false
    $funcEnd = $end
    for ($i = $start; $i -lt $pipelineContent.Length; $i++) {
        if ($pipelineContent[$i] -eq '{') { $braceCount++; $foundStart = $true }
        elseif ($pipelineContent[$i] -eq '}') { $braceCount--; if ($foundStart -and $braceCount -eq 0) { $funcEnd = $i + 1; break } }
    }
    $pipelineContent.Substring($start, $funcEnd - $start)
} else {
    ""
}

# Check for actual Python subprocess execution, not comments or docstrings
$swarmCallsPython = $swarmContent -match "&\s+python" -or $swarmContent -match "python\.exe" -or `
    $swarmContent -match "Start-Process.*python" -or $swarmContent -match "Invoke-Expression.*python"
$swarmCommentsPython = $swarmContent -match "^\s*#.*python" -or $swarmContent -match "(?s)<#.*?python.*?#>"
Test-Result "Invoke-Swarm doesn't call Python" (-not $swarmCallsPython) `
    $(if($swarmCallsPython){"Found Python subprocess call"}else{"Clean — no Python dependency"})

Test-Result "Ralph Loop marks DEPRECATED" ($ralphContent -match "DEPRECATED") `
    "Deprecation notice present"

# ═════════════════════════════════════════════════════════════
# TEST 3: HeavySkill Module Exports
# ═════════════════════════════════════════════════════════════
Write-Host "`n── Test Group 3: HeavySkill Module Structure ──" -ForegroundColor Cyan

$hsContent = Get-Content $HeavySkillFile -Raw

$hasReasoningFunc = $hsContent -match "function Invoke-HeavySkillReasoning"
$hasGateFunc = $hsContent -match "function Invoke-HeavySkillGate"
$hasPlanFunc = $hsContent -match "function Invoke-HeavySkillPlan"
$hasResearchFunc = $hsContent -match "function Invoke-HeavySkillResearch"
$hasLlmFunc = $hsContent -match "function Invoke-Llm"
$hasExport = $hsContent -match "Export-ModuleMember"

Test-Result "Invoke-HeavySkillReasoning exists" $hasReasoningFunc "Function defined"
Test-Result "Invoke-HeavySkillGate exists" $hasGateFunc "Function defined"
Test-Result "Invoke-HeavySkillPlan exists" $hasPlanFunc "Function defined"
Test-Result "Invoke-Llm (API caller) exists" $hasLlmFunc "Function defined"
Test-Result "Export-ModuleMember present" $hasExport "Can be dot-sourced or Import-Module"

# ═════════════════════════════════════════════════════════════
# TEST 4: Gate Fallback Logic
# ═════════════════════════════════════════════════════════════
Write-Host "`n── Test Group 4: Gate Fallback Logic (no LLM) ──" -ForegroundColor Cyan

# The pipeline has a try/catch around Invoke-HeavySkillGate with a fallback.
# This proves the pipeline won't crash if CROFAI_API_KEY is missing/HeavySkill fails.
$hasFallback = $pipelineContent -match "falling back to score-based heuristics"
$hasCatch = $pipelineContent -match "catch" -and $pipelineContent -match "Invoke-HeavySkillGate"
Test-Result "Gate has fallback logic" ($hasFallback -and $hasCatch) `
    "try/catch + fallback to heuristic when HeavySkill unavailable"

# ═════════════════════════════════════════════════════════════
# TEST 5: Mock Mode Gate Parsing (no LLM required)
# ═════════════════════════════════════════════════════════════
Write-Host "`n── Test Group 5: Mock Mode Gate Parsing ──" -ForegroundColor Cyan

# Dot-source HeavySkill module for mock mode tests
. "$HeavySkillFile"

$env:AHE_HEAVYSKILL_MOCK = "1"
try {
    # Mock KEEP scenario
    $keepResult = Invoke-HeavySkillGate -TractScores @{correctness=96;utility=80;reliability=90} -BenchmarkDelta 2.0 -Kappa 0.5
    $keepHasSummary = $keepResult -match "## Summary"
    $keepHasRationale = $keepResult -match "## Rationale"
    $keepHasConfidence = $keepResult -match "## Confidence"
    $keepHasDecision = $keepResult -match "KEEP"
    $keepOk = $keepHasSummary -and $keepHasRationale -and $keepHasConfidence -and $keepHasDecision
    Test-Result "Mock KEEP gate produces correct format" $keepOk "Summary=$keepHasSummary Rationale=$keepHasRationale Confidence=$keepHasConfidence Decision=KEEP"
    
    # Mock ROLLBACK scenario
    $rollResult = Invoke-HeavySkillGate -TractScores @{correctness=82;utility=40;reliability=55} -BenchmarkDelta -3.2 -Kappa -0.5
    $rollOk = $rollResult -match "ROLLBACK"
    Test-Result "Mock ROLLBACK gate produces correct verdict" $rollOk "Verdict=ROLLBACK"
    
    # Mock NO_CHANGE scenario
    $noopResult = Invoke-HeavySkillGate -TractScores @{correctness=97;utility=50;reliability=60} -BenchmarkDelta 0 -Kappa 0
    $noopOk = $noopResult -match "NO_CHANGE"
    Test-Result "Mock NO_CHANGE gate produces correct verdict" $noopOk "Verdict=NO_CHANGE"
    
    # HeavySkillPlan mock
    $planResult = Invoke-HeavySkillPlan -Goal "Test mock plan"
    $planOk = $planResult -match "## Summary" -and $planResult -match "## Rationale"
    Test-Result "Mock HeavySkillPlan produces correct format" $planOk "Summary+Rationale sections present"
} catch {
    Test-Result "Mock mode tests" $false "Exception: $_"
}
Remove-Item Env:\AHE_HEAVYSKILL_MOCK -ErrorAction SilentlyContinue

# ═════════════════════════════════════════════════════════════
# TEST 6: Orchestration Simplicity (Script Count)
# ═════════════════════════════════════════════════════════════
Write-Host "`n── Test Group 6: Orchestration Simplicity ──" -ForegroundColor Cyan

# Count actual external subprocess calls (not comments, not dot-source of modules)
# Checks for: & "$ScriptsDir\archive\something.ps1" patterns (actual execution)
$extSubprocess = [regex]::Matches($pipelineContent, '&\s+"\$ScriptsDir\\archive\\').Count
$extPython = [regex]::Matches($pipelineContent, '&\s+python').Count
$extStartProc = [regex]::Matches($pipelineContent, 'Start-Process.*python').Count
$totalExternalCalls = $extSubprocess + $extPython + $extStartProc
Test-Result "No external subprocess calls" ($totalExternalCalls -le 1) `
    "$totalExternalCalls external subprocess calls found (≤1 = acceptable: MCP verify is OS-level)"

# Count dot-source lines
$dotSources = [regex]::Matches($pipelineContent, '\.\s*"\$').Count
Test-Result "Module dot-sources (reasonable count)" ($dotSources -le 6) `
    "$dotSources dot-source references (3 core + 3 optional)"

# Verify the Consolidation Summary matches what was implemented
$consolidationFile = "$RootDir\docs\consolidation-heavyskill-2026-05-05.md"
if (Test-Path $consolidationFile) {
    Test-Result "Consolidation summary exists" $true "docs/consolidation-heavyskill-2026-05-05.md"
} else {
    Test-Result "Consolidation summary exists" $false "Not found"
}

# ═════════════════════════════════════════════════════════════
# TEST 7: HeavySkill Evaluator
# ═════════════════════════════════════════════════════════════
Write-Host "`n── Test Group 7: HeavySkill Evaluator ──" -ForegroundColor Cyan

# Ensure module loaded with mock mode
$env:AHE_HEAVYSKILL_MOCK = "1"
. "$HeavySkillFile"

# Test 7.1: Perfect gate output
$perfectGate = @"
## Summary
KEEP - strong positive metrics across all dimensions

## Rationale
All KEEP criteria satisfied with high confidence

## Confidence
HIGH

## Assumptions
Model behavior remains consistent with observed trends
"@
$eval1 = Invoke-HeavySkillEval -HeavySkillOutput $perfectGate -Mode gate
$ok1 = $eval1.ReasoningCoherence -ge 0.75 -and $eval1.VerdictAccuracy -eq 0.5 -and $eval1.SectionsPresent.Count -eq 4
$detail1 = 'Coh=' + $eval1.ReasoningCoherence + ' Acc=' + $eval1.VerdictAccuracy + ' Sections=' + $eval1.SectionsPresent.Count
Test-Result "Perfect gate output scores" $ok1 $detail1

# Test 7.2: Plan output with action verbs
$planOutput = @"
## Summary
Test the new module and Update the pipeline config

## Rationale
Concrete actions identified with clear deliverables

## Confidence
HIGH

## Assumptions
All dependencies are installed
"@
$eval2 = Invoke-HeavySkillEval -HeavySkillOutput $planOutput -Mode plan
$det2 = 'Actionability=' + $eval2.PlanActionability
Test-Result "Plan output actionability >= 0.4" ($eval2.PlanActionability -ge 0.4) $det2

# Test 7.3: Missing sections
$partialOutput = @"
## Summary
Quick analysis

## Rationale
Some reasoning

## Confidence
MEDIUM
"@
$eval3 = Invoke-HeavySkillEval -HeavySkillOutput $partialOutput -Mode gate
$det3a = 'Coh=' + $eval3.ReasoningCoherence
$det3b = 'Missing=' + ($eval3.SectionsMissing -join ',')
Test-Result "Missing sections - coherence < 1.0" ($eval3.ReasoningCoherence -lt 1.0) $det3a
Test-Result "Missing sections - contains 'Assumptions'" ($eval3.SectionsMissing -contains "Assumptions") $det3b

# Test 7.4: Empty output
$eval4 = Invoke-HeavySkillEval -HeavySkillOutput "" -Mode gate
$det4a = 'Coh=' + $eval4.ReasoningCoherence
$det4b = 'Missing=' + $eval4.SectionsMissing.Count
Test-Result "Empty output - coherence 0" ($eval4.ReasoningCoherence -eq 0.0) $det4a
Test-Result "Empty output - all sections missing" ($eval4.SectionsMissing.Count -eq 4) $det4b

# Test 7.5: Malformed output (random text)
$eval5 = Invoke-HeavySkillEval -HeavySkillOutput "some random text without section headers" -Mode gate
$det5 = 'Coh=' + $eval5.ReasoningCoherence
Test-Result "Malformed output - coherence 0" ($eval5.ReasoningCoherence -eq 0.0) $det5

# Test 7.6: Baseline comparison - KEEP
$keepGate = @"
## Summary
KEEP is the recommended action

## Rationale
Strong positive metrics

## Confidence
HIGH

## Assumptions
Trend continues
"@
$eval6 = Invoke-HeavySkillEval -HeavySkillOutput $keepGate -MockBaseline -Kappa 0.5 -Mode gate
$lab6 = 'Kappa=0.5 baseline - verdict accuracy 1.0'
$detail6 = 'Acc=' + $eval6.VerdictAccuracy + ' (expected KEEP)'
Test-Result $lab6 ($eval6.VerdictAccuracy -eq 1.0) $detail6

# Test 7.7: Baseline comparison - ROLLBACK
$rollGate = @"
## Summary
ROLLBACK is necessary to restore stability

## Rationale
Sustained regression across metrics

## Confidence
HIGH

## Assumptions
Previous state remains viable
"@
$eval7 = Invoke-HeavySkillEval -HeavySkillOutput $rollGate -MockBaseline -Kappa -0.5 -Mode gate
$lab7 = 'Kappa=-0.5 baseline - verdict accuracy 1.0'
$detail7 = 'Acc=' + $eval7.VerdictAccuracy + ' (expected ROLLBACK)'
Test-Result $lab7 ($eval7.VerdictAccuracy -eq 1.0) $detail7

# Test 7.8: Baseline comparison - NO_CHANGE
$flatGate = @"
## Summary
NO_CHANGE - metrics are stable

## Rationale
No significant movement in either direction

## Confidence
MEDIUM

## Assumptions
Current state is acceptable
"@
$eval8 = Invoke-HeavySkillEval -HeavySkillOutput $flatGate -MockBaseline -Kappa 0.05 -Mode gate
$lab8 = 'Kappa=0.05 baseline - verdict accuracy 1.0'
$detail8 = 'Acc=' + $eval8.VerdictAccuracy + ' (expected NO_CHANGE)'
Test-Result $lab8 ($eval8.VerdictAccuracy -eq 1.0) $detail8

# Test 7.9: -ReturnEval integration
$gate9 = Invoke-HeavySkillGate -TractScores @{correctness=96;utility=80;reliability=90} -BenchmarkDelta 2.0 -Kappa 0.5 -ReturnEval
$isArray = $gate9 -is [array]
$has2Elements = $gate9.Count -eq 2
$firstIsString = $gate9[0] -is [string]
$secondIsHashtable = $gate9[1] -is [hashtable]
$ok9 = $isArray -and $has2Elements -and $firstIsString -and $secondIsHashtable
Test-Result "Gate -ReturnEval returns [output, eval]" $ok9 "Array=$isArray Count=2 Str=$firstIsString Ht=$secondIsHashtable"

# Test 7.10: Research output coherence
$researchOut = @"
## Summary
Multiple papers relevant to agentic harness optimization reviewed

## Rationale
Three papers provide actionable insights for the pipeline

## Confidence
MEDIUM

## Assumptions
Papers are representative of current SOTA
"@
$eval10 = Invoke-HeavySkillEval -HeavySkillOutput $researchOut -Mode research
$lab10a = 'Research output - coherence >= 0.75'
$lab10b = 'Research output - actionability 0'
$det10a = 'Coh=' + $eval10.ReasoningCoherence
$det10b = 'Act=' + $eval10.PlanActionability
Test-Result $lab10a ($eval10.ReasoningCoherence -ge 0.75) $det10a
Test-Result $lab10b ($eval10.PlanActionability -eq 0.0) $det10b

Remove-Item Env:\AHE_HEAVYSKILL_MOCK -ErrorAction SilentlyContinue

# ═════════════════════════════════════════════════════════════
# TEST 8: HeavySkill Presets
# ═════════════════════════════════════════════════════════════
Write-Host "`n── Test Group 8: HeavySkill Presets ──" -ForegroundColor Cyan

$env:AHE_HEAVYSKILL_MOCK = "1"
. "$HeavySkillFile"

# Test 8.1: Default preset (balanced)
$r1 = Invoke-HeavySkillReasoning -Context "test" -OutputType "analysis"
$ok1 = $r1 -match "## Summary" -and $r1 -match "## Rationale"
Test-Result "Default preset = balanced" $ok1 "Summary+Rationale present"

# Test 8.2: Quick preset
$r2 = Invoke-HeavySkillReasoning -Context "test" -OutputType "analysis" -Preset quick
Test-Result "Quick preset produces output" ($r2 -match "## Summary") "Has summary"

# Test 8.3: Deep preset
$r3 = Invoke-HeavySkillReasoning -Context "test" -OutputType "analysis" -Preset deep
Test-Result "Deep preset produces output" ($r3 -match "## Summary") "Has summary"

# Test 8.4: Env override
$env:AHE_HEAVYSKILL_PRESET = "quick"
$r4 = Invoke-HeavySkillReasoning -Context "test" -OutputType "analysis"
Test-Result "Env override AHE_HEAVYSKILL_PRESET=quick" ($r4 -match "## Summary") "Has summary"
Remove-Item Env:\AHE_HEAVYSKILL_PRESET -ErrorAction SilentlyContinue

# Test 8.5: Auto-select from eval scores
$autoHigh = Select-HeavySkillPreset -EvalScores @{VerdictAccuracy=1.0; ReasoningCoherence=1.0; PlanActionability=0.9}
$autoLow  = Select-HeavySkillPreset -EvalScores @{VerdictAccuracy=0.0; ReasoningCoherence=0.3; PlanActionability=0.0}
$autoMid  = Select-HeavySkillPreset -EvalScores @{VerdictAccuracy=0.5; ReasoningCoherence=0.75; PlanActionability=0.4}
Test-Result "Auto-select: high -> quick" ($autoHigh -eq "quick") "Result=$autoHigh"
Test-Result "Auto-select: low -> deep" ($autoLow -eq "deep") "Result=$autoLow"
Test-Result "Auto-select: mid -> balanced" ($autoMid -eq "balanced") "Result=$autoMid"

# Test 8.6: Resolve preset config
$cfgQuick = Resolve-HeavySkillPreset -Preset quick
$cfgDeep  = Resolve-HeavySkillPreset -Preset deep
$cfgBal   = Resolve-HeavySkillPreset -Preset balanced
Test-Result "Quick preset has 2 traces" ($cfgQuick.traces -eq 2) "traces=$($cfgQuick.traces)"
Test-Result "Deep preset has 5 traces" ($cfgDeep.traces -eq 5) "traces=$($cfgDeep.traces)"
Test-Result "Balanced preset has 3 traces" ($cfgBal.traces -eq 3) "traces=$($cfgBal.traces)"

# Test 8.7: Gate with explicit preset
$g1 = Invoke-HeavySkillGate -TractScores @{correctness=96;utility=80;reliability=90} -BenchmarkDelta 2.0 -Kappa 0.5 -Preset quick
Test-Result "Gate with quick preset" ($g1 -match "KEEP") "Verdict=KEEP"

# Test 8.8: Plan with deep preset
$p1 = Invoke-HeavySkillPlan -Goal "test preset" -Preset deep
Test-Result "Plan with deep preset" ($p1 -match "## Summary") "Has summary"

Remove-Item Env:\AHE_HEAVYSKILL_MOCK -ErrorAction SilentlyContinue

# ═════════════════════════════════════════════════════════════
# TEST 9: Eval Trend & Gbrain
# ═════════════════════════════════════════════════════════════
Write-Host "`n── Test Group 9: Eval Trend & Gbrain ──" -ForegroundColor Cyan

. "$HeavySkillFile"

# Create temp eval dir with synthetic data
$td = "$env:TEMP\ahe-scenario-trend-$(Get-Random)"
New-Item -ItemType Directory -Path $td -Force | Out-Null
1..10 | ForEach-Object {
    $score = [Math]::Round(0.3 + ($_ * 0.07), 2)
    $day = ([string]($_+1)).PadLeft(2,'0')
    @{ timestamp = "2026-05-${day}T10:00:00"; heavySkillFunction = "Gate"; verdict = "KEEP"; outputHash = "h$_"; scores = @{ accuracy = $score; coherence = 0.8; actionability = 0.5 }; sectionsFound = @("S","R","C","A"); confidence = "HIGH"; rawLines = 11 } | ConvertTo-Json -Compress | Set-Content "$td\2026-05-$_-Gate.json" -Encoding UTF8
}

# Test 9.1: ReadEvalLogs
$ent = Invoke-ReadEvalLogs -EvalDir $td
Test-Result "ReadEvalLogs returns entries" ($ent.Count -eq 10) "Count=$($ent.Count)"

# Test 9.2: ComputeEvalTrend
$tr = Invoke-ComputeEvalTrend -EvalEntries $ent
Test-Result "ComputeEvalTrend totalEvals" ($tr.totalEvals -eq 10) "total=$($tr.totalEvals)"
Test-Result "ComputeEvalTrend avgAccuracy > 0" ($tr.avgAccuracy -gt 0) "avgAcc=$($tr.avgAccuracy)"

# Test 9.3: Trend direction
$impLab = 'Trend direction = improving'
Test-Result $impLab ($tr.trend -eq "improving") "trend=$($tr.trend)"

# Test 9.4: Write-GbrainEvalTrend local persistence
$wr = Write-GbrainEvalTrend -EvalDir $td -SkipGbrain
Test-Result "WriteGbrainEvalTrend local trend.json" (Test-Path "$td\trend.json") "Exists"

# Test 9.5: trend.json structure
$tjson = Get-Content "$td\trend.json" -Raw | ConvertFrom-Json
Test-Result "trend.json has overall" ([bool]$tjson.overall) "present"
Test-Result "trend.json has movingAverage" ([bool]$tjson.movingAverage) "present"

# Test 9.6: Correlation
$c1 = Invoke-CorrelateEvalAndBenchmark -EvalAccuracySeries @(0.5,0.6,0.7) -KappaSeries @(0.1,0.2,0.3)
Test-Result "Correlation positive" ($c1.correlation -gt 0) "corr=$($c1.correlation)"

$c3 = Invoke-CorrelateEvalAndBenchmark -EvalAccuracySeries @(0.5) -KappaSeries @(0.1)
$c3Lab = 'Correlation insufficient data'
Test-Result $c3Lab ($c3.note -eq "insufficient data") "note=$($c3.note)"

# Cleanup
Remove-Item $td -Recurse -Force -ErrorAction SilentlyContinue

# ═════════════════════════════════════════════════════════════
# TEST 10: HeavySkill Auto-Tune
# ═════════════════════════════════════════════════════════════
Write-Host "`n── Test Group 10: HeavySkill Auto-Tune ──" -ForegroundColor Cyan

. "$HeavySkillFile"
$td10 = "$env:TEMP\ahe-scenario-autotune-$(Get-Random)"
New-Item -ItemType Directory -Path $td10 -Force | Out-Null

# Write improving trend
1..10 | ForEach-Object {
    $score = [Math]::Round(0.3 + ($_ * 0.07), 2)
    $day = ([string]($_+1)).PadLeft(2,'0')
    @{ timestamp = "2026-05-${day}T10:00:00"; heavySkillFunction = "Gate"; verdict = "KEEP"; outputHash = "h$_"; scores = @{ accuracy = $score; coherence = 0.8; actionability = 0.5 }; sectionsFound = @("S","R","C","A"); confidence = "HIGH"; rawLines = 11 } | ConvertTo-Json -Compress | Set-Content "$td10\2026-05-$_-Gate.json" -Encoding UTF8
}
Write-GbrainEvalTrend -EvalDir $td10 -SkipGbrain | Out-Null

# 10.1: Improving trend
$a1 = Invoke-HeavySkillAutoTune -EvalDir $td10 -CurrentPreset balanced
Test-Result "AutoTune: improving -> keep" ($a1.reason -eq "improving") "reason=$($a1.reason)"

# 10.2: Write regression trend
$td10b = "$env:TEMP\ahe-scenario-autotune-b-$(Get-Random)"
New-Item -ItemType Directory -Path $td10b -Force | Out-Null
1..10 | ForEach-Object {
    $score = [Math]::Round(0.9 - ($_ * 0.08), 2)
    $day = ([string]($_+1)).PadLeft(2,'0')
    @{ timestamp = "2026-05-${day}T10:00:00"; heavySkillFunction = "Gate"; verdict = "KEEP"; outputHash = "h$_"; scores = @{ accuracy = $score; coherence = 0.8; actionability = 0.5 }; sectionsFound = @("S","R","C","A"); confidence = "HIGH"; rawLines = 11 } | ConvertTo-Json -Compress | Set-Content "$td10b\2026-05-$_-Gate.json" -Encoding UTF8
}
Write-GbrainEvalTrend -EvalDir $td10b -SkipGbrain | Out-Null

$a2 = Invoke-HeavySkillAutoTune -EvalDir $td10b -CurrentPreset deep
Test-Result "AutoTune: regression -> fallback" ($a2.recommended -eq "balanced" -and $a2.reason -eq "regression") "recommended=$($a2.recommended)"

# 10.3: Plateau detection
$td10c = "$env:TEMP\ahe-scenario-autotune-c-$(Get-Random)"
New-Item -ItemType Directory -Path $td10c -Force | Out-Null
1..10 | ForEach-Object {
    $day = ([string]($_+1)).PadLeft(2,'0')
    @{ timestamp = "2026-05-${day}T10:00:00"; heavySkillFunction = "Gate"; verdict = "KEEP"; outputHash = "h$_"; scores = @{ accuracy = 0.5; coherence = 0.8; actionability = 0.5 }; sectionsFound = @("S","R","C","A"); confidence = "MEDIUM"; rawLines = 11 } | ConvertTo-Json -Compress | Set-Content "$td10c\2026-05-$_-Gate.json" -Encoding UTF8
}
Write-GbrainEvalTrend -EvalDir $td10c -SkipGbrain | Out-Null

$a3 = Invoke-HeavySkillAutoTune -EvalDir $td10c -CurrentPreset balanced
Test-Result "AutoTune: plateau -> escalate" ($a3.reason -eq "plateau" -and $a3.action -eq "escalate") "action=$($a3.action)"

# 10.4: No trend data
$a4 = Invoke-HeavySkillAutoTune -EvalDir "$env:TEMP\ahe-scenario-autotune-empty" -CurrentPreset deep
Test-Result "AutoTune: no data -> stays current" ($a4.recommended -eq "deep") "recommended=$($a4.recommended)"

# 10.5: Env override
$env:AHE_HEAVYSKILL_PRESET = "quick"
$a5 = Invoke-HeavySkillAutoTune -EvalDir $td10 -CurrentPreset balanced
Test-Result "AutoTune: env override" ($a5.recommended -eq "quick" -and $a5.reason -eq "env-override") "recommended=$($a5.recommended)"
Remove-Item Env:\AHE_HEAVYSKILL_PRESET -ErrorAction SilentlyContinue

# 10.6: AutoTune via Gate -ReturnEval
$env:AHE_HEAVYSKILL_MOCK = "1"
$gateWithAuto = Invoke-HeavySkillGate -TractScores @{correctness=96;utility=80;reliability=90} -BenchmarkDelta 2.0 -Kappa 0.5 -Preset balanced -ReturnEval
$hasAutoTune = $gateWithAuto[1].PSObject.Properties.Name -contains 'autoTune'
Test-Result "Gate -ReturnEval has autoTune field" $hasAutoTune "present=$hasAutoTune"
Remove-Item Env:\AHE_HEAVYSKILL_MOCK -ErrorAction SilentlyContinue

# Cleanup
Remove-Item $td10 -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $td10b -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $td10c -Recurse -Force -ErrorAction SilentlyContinue

# ═════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║           SCENARIO RESULTS            ║" -ForegroundColor Magenta
Write-Host "╠══════════════════════════════════════╣" -ForegroundColor Magenta
Write-Host "║  Passed: $($Passed)                              ║" -ForegroundColor Green
Write-Host "║  Failed: $($Failed)                              ║" $(if($Failed -eq 0){"Green"}else{"Red"})
Write-Host "║  Skipped: $($Skipped)                            ║" -ForegroundColor Yellow
$total = $Passed + $Failed + $Skipped
Write-Host "║  Total:  $total                              ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Magenta

Write-Host ""
if ($Failed -eq 0) {
    Write-Host "✅ All scenario tests passed. HeavySkill consolidation verified." -ForegroundColor Green
} else {
    Write-Host "⚠️  $Failed test(s) failed. See details above." -ForegroundColor Red
}

Write-Host ""
Write-Host "To run real HeavySkill LLM tests (requires CROFAI_API_KEY):"
Write-Host "  Import-Module '$HeavySkillFile' -Force" -ForegroundColor Gray
Write-Host "  Invoke-HeavySkillGate -TractScores @{correctness=96;utility=75;reliability=88} -BenchmarkDelta 1.2 -Kappa 0.3" -ForegroundColor Gray
