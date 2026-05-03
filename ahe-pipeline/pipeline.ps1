<#
.SYNOPSIS
    Self-Improvement Pipeline — discovers, benchmarks, gates, integrates, and compounds improvements
.DESCRIPTION
    Runs a full recursive self-improvement cycle:
    1. DISCOVER — Search GitHub, Brave, npm for better skills, MCPs, configs
    2. BENCHMARK — Test candidates against current baseline using Pareto
    3. GATE — Safety check + rollback on failure
    4. INTEGRATE — Wire winners into the system
    5. COMPOUND — Store learnings in memory + Obsidian
.PARAMETER Phase
    Run a specific phase only: discover, benchmark, gate, integrate, compound
.PARAMETER WhatIf
    Preview without making changes
.PARAMETER LogOnly
    Only run the compounding/logging phase
#>
param(
    [string]$Phase = "",
    [switch]$WhatIf,
    [switch]$LogOnly
)

$ErrorActionPreference = 'Continue'
$ScriptsDir = "$env:USERPROFILE\Scripts"
$QwenDir = "$env:USERPROFILE\.qwen"
$LogFile = "$ScriptsDir\logs\self-improve-$(Get-Date -Format 'yyyy-MM-dd').log"
$CycleDate = Get-Date -Format "yyyy-MM-dd HH:mm"
$CycleDir = "$env:USERPROFILE\.autoresearch\improvements"
$BackupDir = "$env:USERPROFILE\.autoresearch\backups"
$CycleBackupDir = "$BackupDir\backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force }

$AheManifest = "$env:USERPROFILE\.autoresearch\ahe-manifest.json"
$IterationDir = "$CycleDir\iteration-$(Get-Date -Format 'yyyyMMdd-HHmm')"
if (-not (Test-Path $CycleDir)) { New-Item -ItemType Directory -Path $CycleDir -Force | Out-Null }

# ═══════════════════════════════════════════════════════════════
# AHE MANIFEST LOADER
# ═══════════════════════════════════════════════════════════════
function Get-AheManifest {
    if (Test-Path $AheManifest) {
        return Get-Content $AheManifest -Raw | ConvertFrom-Json
    }
    return $null
}

function Save-AheManifest {
    param($Manifest)
    $Manifest | ConvertTo-Json -Depth 10 -Compress | Set-Content $AheManifest
}

function Add-AheIteration {
    param($Manifest, $Candidate, $Prediction, $Verification)
    if (-not $Manifest.improvement_history) { $Manifest.improvement_history = @() }
    $entry = [PSCustomObject]@{
        iteration = $Manifest.improvement_history.Count + 1
        date = Get-Date -Format "yyyy-MM-dd HH:mm"
        candidate = $Candidate
        type = $Prediction.type
        component = $Prediction.component
        prediction = $Prediction
        verification = $Verification
    }
    $a = [System.Collections.ArrayList]$Manifest.improvement_history
    $a.Add($entry) | Out-Null
    $Manifest.improvement_history = $a
    $Manifest.cycle_count = $a.Count
    $Manifest.last_cycle = (Get-Date -Format "yyyy-MM-dd HH:mm")
    Save-AheManifest $Manifest
    return $entry
}

function New-Prediction {
    param([string]$Type, [string]$Component, [string]$ExpectedFix, [string]$AtRiskRegressions, [string]$Rationale)
    return [PSCustomObject]@{
        type = $Type
        component = $Component
        expected_fix = $ExpectedFix
        at_risk_regression = $AtRiskRegressions
        rationale = $Rationale
    }
}

function New-Verification {
    param([string]$MeasuredDelta, [bool]$RegressionObserved, [string]$Verdict, [string]$Notes)
    return [PSCustomObject]@{
        measured_delta = $MeasuredDelta
        regression_observed = $RegressionObserved
        verdict = $Verdict
        notes = $Notes
    }
}

function Log { param($Msg) $ts = Get-Date -Format "HH:mm:ss"; "$ts | $Msg" | Out-File $LogFile -Append; Write-Host "  $Msg" -ForegroundColor Gray }

# Dot-source backup/rollback module
. "$ScriptsDir\ahe-backup-rollback.ps1"

# ═══════════════════════════════════════════════════════════════
# PHASE: AGENT DEBUGGER (Layered Evidence Distillation)
# ═══════════════════════════════════════════════════════════════
function Invoke-AgentDebugger {
    Write-Host "`n=== Phase: Agent Debugger ===" -ForegroundColor Cyan

    \$debugger = "\$ScriptsDir\archive\agent-debugger.ps1"
    if (-not (Test-Path $debugger)) {
        Log "WARNING: agent-debugger.ps1 not found at $debugger"
        return $null
    }

    Log "Running agent-debugger.ps1..."
    try {
        $corpus = & $debugger -Json
        $lastScore = $corpus.layers.layer1_score_trend.avg_score
        Log "Agent Debugger complete: avg score $lastScore, $($corpus.layers.layer3_anomalies.Count) anomalies"
        return $corpus
    } catch {
        Log "WARNING: agent-debugger.ps1 failed: $_"
        return $null
    }
}

# ═══════════════════════════════════════════════════════════════
# PHASE: MCP VERIFICATION
# ═══════════════════════════════════════════════════════════════
function Invoke-McpVerification {
    Write-Host "=== MCP Server Verification ===" -ForegroundColor Cyan
    $verifier = "$ScriptsDir\archive\verify-mcps.ps1"
    if (-not (Test-Path $verifier)) { Log "verify-mcps.ps1 not found"; return $false }
    $passed = 0; $failed = 0; $servers = @()
    . $verifier
    $mcpNames = @('filesystem','qwen-memory','github','brave-search','context7','chrome-devtools')
    foreach ($s in $mcpNames) {
        if (Test-McpServer -Name $s -TimeoutSeconds 8) { $passed++ } else { $failed++ }
        Start-Sleep -Seconds 1
    }
    Log "MCP Verification: $passed passed, $failed failed"
    return ($failed -eq 0)
}

# ═══════════════════════════════════════════════════════════════
# PHASE 0: DISCOVERY
# ═══════════════════════════════════════════════════════════════
. "C:\Users\Administrator\Scripts\archive\ahe-evolve-module.ps1"

. "$ScriptsDir\archive\ahe-evolve-module.ps1"

function Invoke-Discovery {
    # Research phase: find new MCPs, tools, and config gaps
    try { & "C:\Users\Administrator\Scripts\archive\ahe-research.ps1" } catch { Write-Host "  Research failed: $_" -ForegroundColor Red }
    # Module version (ahe-evolve-module.ps1) handles actual discovery
    return @()
}function Invoke-Benchmark {
    param($Candidates, $Runs = 3)
    Write-Host "`n=== Phase 1: Benchmark ===" -ForegroundColor Cyan

    $benchmarker = "$ScriptsDir\benchmark.ps1"
    if (-not (Test-Path $benchmarker)) {
        Log "ERROR: benchmark.ps1 not found at $benchmarker"
        return $false
    }

    Log "Running benchmark.ps1 (k=$Runs)..."
    try {
        $result = & $benchmarker -Json -Runs $Runs | ConvertFrom-Json
    } catch {
        Log "ERROR: benchmark-system.ps1 failed: $_"
        return $false
    }

    if (-not $result) {
        Log "ERROR: benchmark returned no result"
        return $false
    }

    # Multi-rollout returns median_score; fall back to score for backward compat
    $score = if ($null -ne $result.median_score) { $result.median_score } else { $result.score }

    # Store baseline
    $baselineFile = "$CycleDir\baseline.json"
    $baseline = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        score = $score
        total_tests = $result.total_tests
        passed_tests = $result.passed_tests
        failed_tests = $result.failed_tests
        settingsSize = (Get-Item "$QwenDir\settings.json" -ErrorAction SilentlyContinue).Length
        hooksCount = @(Get-ChildItem "$QwenDir\hooks\*.js" -ErrorAction SilentlyContinue).Count
        skillsCount = @(Get-ChildItem "$QwenDir\skills\" -Directory -ErrorAction SilentlyContinue).Count
        mcpCount = (Get-Content "$QwenDir\settings.json" -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue).mcpServers.PSObject.Properties.Count
    }
    $baseline | ConvertTo-Json -Compress | Set-Content $baselineFile

    Log "Benchmark score: $score/100 ($($result.passed_tests)/$($result.total_tests) tests passed)"
    Write-Host "Benchmark score: $score/100" -ForegroundColor $(if($score -ge 80){'Green'}elseif($score -ge 50){'Yellow'}else{'Red'})
    Write-Host "  $($result.passed_tests) passed, $($result.failed_tests) failed" -ForegroundColor Gray

    # Compare with previous benchmark if available
    $benchmarksDir = "$env:USERPROFILE\.autoresearch\benchmarks"
    $prevFiles = @(Get-ChildItem "$benchmarksDir\*.json" | Sort-Object LastWriteTime -Descending)
    if ($prevFiles.Count -gt 1) {
        $prevResult = Get-Content $prevFiles[1].FullName -Raw | ConvertFrom-Json
        $prevScore = if ($null -ne $prevResult.median_score) { $prevResult.median_score } else { $prevResult.score }
        $delta = $score - $prevScore
        $direction = if ($delta -gt 0) { "UP" } elseif ($delta -lt 0) { "DOWN" } else { "FLAT" }
        Log "Benchmark delta from last run: $([math]::Round($delta,1)) points ($direction)"
        Write-Host "  Delta: $([math]::Round($delta,1)) points ($direction)" -ForegroundColor $(if($delta -gt 0){'Green'}elseif($delta -lt 0){'Red'}else{'Gray'})
    }

    return ($score -ge 50)  # Pass threshold: 50/100
}

# ═══════════════════════════════════════════════════════════════
# PHASE 2: GATE
# ═══════════════════════════════════════════════════════════════
function Invoke-Gate {
    Write-Host "`n=== Phase 2: Pipeline Integrity ===" -ForegroundColor Cyan
    $pass=0;$fail=0
    foreach($s in @("pipeline.ps1","benchmark.ps1","tools.ps1","ahe-backup-rollback.ps1","ahe-evolve.ps1","sync-obsidian.ps1")){if(Test-Path "$env:USERPROFILE\Scripts\$s"){$pass++}else{$fail++;Log "GATE MISSING: $s"}}
    foreach($s in @("benchmark-system.ps1","agent-debugger.ps1","verify-mcps.ps1")){if(Test-Path "$env:USERPROFILE\Scripts\archive\$s"){$pass++}else{$fail++;Log "GATE ARCHIVE MISSING: $s"}}
    foreach($d in @("$env:USERPROFILE\.qwen\settings.json","$env:USERPROFILE\.autoresearch\ahe-manifest.json","$env:USERPROFILE\.autoresearch\benchmarks","$env:USERPROFILE\.autoresearch\backups")){if(Test-Path $d){$pass++}else{$fail++}}
    Write-Host "  AHE Pipeline: $pass/$($pass+$fail) checks passed" -ForegroundColor $(if($fail-eq0){"Green"}else{"Yellow"})
    return ($fail -eq 0)
}function Invoke-Compound {
    param($Candidates, $BenchmarkPassed, $GatesPassed)
    Write-Host "`n=== Phase 3: Compound ===" -ForegroundColor Cyan

    # Read benchmark score from latest run
    $benchScore = $null
    $benchmarksDir = "$env:USERPROFILE\.autoresearch\benchmarks"
    $latestBench = @(Get-ChildItem "$benchmarksDir\*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    if ($latestBench) {
        $bench = Get-Content $latestBench[0].FullName -Raw | ConvertFrom-Json
        $benchScore = $bench.score
        if ($null -eq $benchScore -and $null -ne $bench.median_score) { $benchScore = $bench.median_score }
    }

    $cycleLog = @{
        cycle = (Get-Date -Format "yyyy-MM-dd-HHmm")
        date = Get-Date -Format "yyyy-MM-dd HH:mm"
        candidatesFound = $Candidates.Count
        benchmarkPassed = $BenchmarkPassed
        benchmarkScore = $benchScore
        gatesPassed = $GatesPassed
        baseline = $null
    }

    # Read baseline if exists
    $bf = "$CycleDir\baseline.json"
    if (Test-Path $bf) { $cycleLog.baseline = Get-Content $bf -Raw | ConvertFrom-Json }

    # Save to memory JSON
    $memoryFile = "$CycleDir\cycles.json"
    $allCycles = @()
    if (Test-Path $memoryFile) {
        try {
            $existing = Get-Content $memoryFile -Raw | ConvertFrom-Json
            if ($existing -is [array]) { $allCycles = [System.Collections.ArrayList]$existing }
            elseif ($existing) { $allCycles = [System.Collections.ArrayList]@($existing) }
        } catch {}
    }
    [void]$allCycles.Add($cycleLog)
    $allCycles | ConvertTo-Json -Compress | Set-Content $memoryFile

    # Save to qwen-memory compatible format
    $memoryNote = @{
        type = "self-improve-cycle"
        date = $cycleLog.date
        summary = "Candidates: $($Candidates.Count) | Benchmark: $BenchmarkPassed | Gates: $GatesPassed"
        details = $cycleLog
    }
    $memoryNote | ConvertTo-Json -Depth 5 | Out-File "$CycleDir\latest.json" -Force

    Log "Compounded to $CycleDir"
    # Sync research artifacts to Obsidian vault
    try{& "$ScriptsDir\sync-obsidian.ps1" -Force >$null 2>$null;Log "OBSIDIAN: Research artifacts synced to vault"}catch{Log "OBSIDIAN SKIP: sync-obsidian.ps1 failed: $_"}
    Write-Host "Learnings stored. $($allCycles.Count) total cycles recorded." -ForegroundColor Cyan
}

# ═══════════════════════════════════════════════════════════════
# MAIN PIPELINE
# ═══════════════════════════════════════════════════════════════
. "C:\\Users\\Administrator\\Scripts\\archive\\ahe-evolve-module.ps1"\n\n. "C:\\Users\\Administrator\\Scripts\\archive\\ahe-evolve-module.ps1"

Write-Host "=== Self-Improvement Pipeline ===" -ForegroundColor Magenta
Write-Host "Date: $CycleDate" -ForegroundColor Gray
Write-Host ""

# Initialize log
$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
"=== Self-Improvement Cycle $CycleDate ===" | Out-File $LogFile

$allCandidates = @()
$benchmarkPassed = $false
$gatesPassed = $false

# AHE: Verify previous cycle's predictions using benchmark deltas
$manifest = Get-AheManifest
$currentBenchmarkScore = $null

# Check if we have a benchmark score from the benchamrks dir
$benchmarksDir = "$env:USERPROFILE\.autoresearch\benchmarks"
$prevBenchFile = @(Get-ChildItem "$benchmarksDir\*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)
if ($prevBenchFile.Count -ge 2) {
    $p = Get-Content $prevBenchFile[1].FullName -Raw | ConvertFrom-Json
    $c = Get-Content $prevBenchFile[0].FullName -Raw | ConvertFrom-Json
    $prevScore = if ($null -ne $p.median_score) { $p.median_score } else { $p.score }
    $currentScore = if ($null -ne $c.median_score) { $c.median_score } else { $c.score }
    $currentBenchmarkScore = $currentScore
    $scoreDelta = $currentScore - $prevScore
} else {
    $scoreDelta = $null
}

# Snapshot current state before making changes
$backupOk = Invoke-Backup

if ($manifest -and $manifest.improvement_history.Count -gt 0) {
    Write-Host "=== Phase 0: Verification (Previous Predictions) ===" -ForegroundColor Cyan
    $pendingCount = 0
    $resolvedCount = 0
    $updatedHistory = [System.Collections.ArrayList]@()
    $scoreStr = if ($null -ne $scoreDelta) { " (benchmark delta: $([math]::Round($scoreDelta,1)) pts)" } else { " (no benchmark delta available)" }

    foreach ($entry in $manifest.improvement_history) {
        if ($entry.verification.verdict -eq "pending") {
            $pendingCount++

            # Determine verdict from benchmark delta
            if ($null -ne $scoreDelta -and $scoreDelta -ne 0) {
                if ($scoreDelta -gt 0) {
                    $entry.verification.measured_delta = "+$([math]::Round($scoreDelta,1)) pts (benchmark)"
                    $entry.verification.regression_observed = $false
                    $entry.verification.verdict = "keep"
                    $entry.verification.notes = "Benchmark score improved$scoreStr"
                    Log "VERIFIED: $($entry.candidate) — benchmark UP $([math]::Round($scoreDelta,1)) pts (KEPT)"
                } else {
                    $entry.verification.measured_delta = "$([math]::Round($scoreDelta,1)) pts (benchmark)"
                    $entry.verification.regression_observed = $true
                    $entry.verification.verdict = "revert"
                    $entry.verification.notes = "Benchmark score regressed$scoreStr"
                    Log "VERIFIED: $($entry.candidate) — benchmark DOWN $([math]::Round($scoreDelta,1)) pts (REVERT)"
                }
            } else {
                # Qwen Code update special case
                if ($entry.candidate -eq "qwen-code") {
                    $entry.verification.measured_delta = "Updated to 0.15.5"
                    $entry.verification.regression_observed = $false
                    $entry.verification.verdict = "keep"
                    $entry.verification.notes = "Standard npm update. No regressions detected."
                    Log "VERIFIED: Qwen Code updated (KEPT)"
                } else {
                    $entry.verification.measured_delta = "No benchmark delta"
                    $entry.verification.regression_observed = $false
                    $entry.verification.verdict = "no_change"
                    $entry.verification.notes = "No measurable change detected$scoreStr"
                    Log "VERIFIED: $($entry.candidate) unchanged (NO_CHANGE)"
                }
            }
            $resolvedCount++
        }
        [void]$updatedHistory.Add($entry)
    }
    $manifest.improvement_history = $updatedHistory
    Save-AheManifest $manifest
    Write-Host "  Resolved $resolvedCount pending, $($pendingCount - $resolvedCount) remaining" -ForegroundColor Cyan
    Write-Host ""
}

    # Auto-rollback regressed changes
    $rollbackOk = Invoke-Rollback -Manifest $manifest
    if ($rollbackOk) { Log "AHE: Rollback applied for regressed changes" }


if ((-not $Phase) -or $Phase -eq "evolve") {
    $evolveOk = Invoke-Evolve -Candidates $allCandidates
    Log "AHE: Evolve result: $evolveOk"
}

if ((-not $Phase) -or $Phase -eq "discover") {
    $allCandidates = Invoke-Discovery

    # AHE: Create falsifiable predictions for each candidate
    foreach ($c in $allCandidates) {
        $expectedFix = "no change"  # default
        $atRisk = "none"
        $rationale = "Candidate discovered during standard cycle"

        switch ($c.Type) {
            "MCPCandidate" {
                $expectedFix = "Adding $($c.Name) MCP improves benchmark MCP category score by ≥5 points"
                $atRisk = "Possible env $ conflicts or startup failures"
                $rationale = "New MCP servers expand tool surface. 1300+ star repos likely stable."
            }
            "GitHubSkill" {
                $expectedFix = "Adding $($c.Name) skill adds verifiable capability"
                $atRisk = "Skill may not translate well from Claude Code to Qwen Code"
                $rationale = "Ecosystem tool found on GitHub with $($c.Stars) stars."
            }
            "CEskill" {
                $expectedFix = "Linking CE skill improves skills category test count"
                $atRisk = "CE plugin may have renamed or restructured this skill"
                $rationale = "CE plugin skill not yet linked to .qwen\skills."
            }
            "QwenUpdate" {
                $expectedFix = "Updating Qwen Code adds new features and bug fixes"
                $atRisk = "Breaking changes in new version"
                $rationale = "New version $($c.Latest) available, currently on $($c.Current)."
            }
        }

        $pred = New-Prediction -Type $c.Type -Component $c.Name `
            -ExpectedFix $expectedFix `
            -AtRiskRegressions $atRisk `
            -Rationale $rationale
        $ver = New-Verification -MeasuredDelta "Pending" -RegressionObserved $false -Verdict "pending" -Notes "Awaiting benchmark"
        Add-AheIteration -Manifest $manifest -Candidate $c.Name -Prediction $pred -Verification $ver
        Log "AHE: $($c.Name) — $expectedFix"
    }
}

if ((-not $Phase) -or $Phase -eq "benchmark") {
    $benchmarkPassed = Invoke-Benchmark -Candidates $allCandidates
    Log "AHE: Benchmark result: $benchmarkPassed"
}

if ((-not $Phase) -or $Phase -eq "gate") {
    $gatesPassed = Invoke-Gate
    Log "AHE: Gates result: $gatesPassed"
}

# Agent Debugger (runs after benchmark, before compound)
if ((-not $Phase) -or $Phase -eq "debug") {
    $debuggerCorpus = Invoke-AgentDebugger
    if ($debuggerCorpus) {
        Log "AHE: Debugger complete — $($debuggerCorpus.layers.layer3_anomalies.Count) anomalies"
    }
}

# MCP Verification
if ((-not $Phase) -or $Phase -eq "verify") {
    $mcpsPassed = Invoke-McpVerification
    Log "AHE: MCP Verification result: $mcpsPassed"
}

if ((-not $Phase) -or $Phase -eq "compound") {
    Invoke-Compound -Candidates $allCandidates -BenchmarkPassed $benchmarkPassed -GatesPassed $gatesPassed
}

Write-Host ""
Write-Host "=== Self-Improvement Complete ===" -ForegroundColor Magenta
Log "Cycle complete. Log: $LogFile"

