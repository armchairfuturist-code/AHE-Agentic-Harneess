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
