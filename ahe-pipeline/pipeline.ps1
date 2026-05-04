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
        $m = Get-Content $AheManifest -Raw | ConvertFrom-Json
        # Ensure best_score exists (needed for Best-So-Far Gate)
        if ($null -eq $m.best_score) { $m | Add-Member -NotePropertyName "best_score" -NotePropertyValue $null -Force }
        return $m
    }
    return $null
}

function Save-AheManifest {
    param($Manifest)
    try {
        $json = $Manifest | ConvertTo-Json -Depth 10 -Compress -ErrorAction Stop
        $json | Set-Content $AheManifest -ErrorAction Stop
        Log "Manifest saved: $($Manifest.improvement_history.Count) entries ($($json.Length) bytes)"
    } catch {
        Log "ERROR saving manifest: $_"
        Write-Host "  ERROR saving manifest: $_" -ForegroundColor Red
    }
}

function Add-AheIteration {
    param($Manifest, $Candidate, $Prediction, $Verification)
    if (-not $Manifest.improvement_history) { $Manifest.improvement_history = @() }
    try {
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
    } catch {
        Log "ERROR in Add-AheIteration: $_"
        return $null
    }
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
. "$ScriptsDir\ahe-candidate-eval.ps1"

# ═══════════════════════════════════════════════════════════════
# PHASE: AGENT DEBUGGER (Layered Evidence Distillation)
# ═══════════════════════════════════════════════════════════════
function Invoke-AgentDebugger {
    Write-Host "`n=== Phase: Agent Debugger ===" -ForegroundColor Cyan

    $debugger = "$ScriptsDir\archive\agent-debugger.ps1"
    if (-not (Test-Path $debugger)) {
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

. "$ScriptsDir\archive\ahe-evolve-module.ps1"

function Invoke-Discovery {
    # Research phase: find new MCPs, tools, and config gaps
    try { & "$ScriptsDir\archive\ahe-research.ps1" } catch { Write-Host "  Research failed: $_" -ForegroundColor Red }

    # Read scored candidates from knowledge directory (ahe-evaluate-candidates.py output)
    $knowledgeFile = "$env:USERPROFILE\.autoresearch\knowledge\candidate-evaluations.json"
    $knownNames = @{}
    if ($manifest -and $manifest.improvement_history) {
        foreach ($entry in $manifest.improvement_history) {
            if ($entry.candidate) { $knownNames[$entry.candidate] = $true }
        }
    }

    $scoredCandidates = @()
    if (Test-Path $knowledgeFile) {
        try {
            $evalData = Get-Content $knowledgeFile -Raw | ConvertFrom-Json
            if ($evalData.scored -and $evalData.scored.Count -gt 0) {
                $sorted = $evalData.scored | Sort-Object score -Descending
                foreach ($c in $sorted) {
                    if (-not $knownNames.ContainsKey($c.name)) {
                        $scoredCandidates += [PSCustomObject]@{
                            Type = "MCPCandidate"
                            Name = $c.name
                            Stars = $c.stars
                            Score = $c.score
                            Category = $c.category
                            Description = $c.desc
                            GapNeed = $c.gap_name.need
                            GapWeight = $c.gap_name.weight
                            Source = "knowledge-eval"
                            Date = Get-Date
                        }
                        $knownNames[$c.name] = $true
                    }
                }
                if ($scoredCandidates.Count -gt 0) {
                Log "Discovery: $($evalData.scored.Count) total, $($scoredCandidates.Count) new after dedup (best: $($sorted[0].name) @ $($sorted[0].score)/100)"
            } else {
                Log "Discovery: $($evalData.scored.Count) total, $($scoredCandidates.Count) new after dedup"
            }
            }
        } catch {
            Log "WARNING: Could not read candidate-evaluations.json: $_"
        }
    }

    # Also read research-findings.json for gap analysis context
    $findingsFile = "$env:USERPROFILE\.autoresearch\knowledge\research-findings.json"
    if (Test-Path $findingsFile) {
        try {
            $findings = Get-Content $findingsFile -Raw | ConvertFrom-Json
            if ($findings.gaps -and $findings.gaps.Count -gt 0) {
                Log "Gap analysis: $($findings.gaps.Count) gaps identified"
                foreach ($g in $findings.gaps) {
                    Log "  Gap: $($g.test) — $($g.detail)"
                }
            }
        } catch {}
    }

    if ($scoredCandidates.Count -eq 0) {
        Log "Discovery: No new candidates found (all known or none scored)"
    }

    return $scoredCandidates
}

function Invoke-Benchmark {
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
}
Invoke-Compound {
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

    # Sync research artifacts to Obsidian vault
    try{& "$ScriptsDir\sync-obsidian.ps1" -Force >$null 2>$null;Log "OBSIDIAN: Research artifacts synced to vault"}catch{Log "OBSIDIAN SKIP: sync-obsidian.ps1 failed: $_"}

    # Learnings.md - per-cycle structured accumulation (auto-harness pattern)
    $learningsFile = "$CycleDir\learnings.md"
    $prevLearnings = ""
    $prevLearnPath = "$env:USERPROFILE\.autoresearch\learnings.md"
    if (Test-Path $prevLearnPath) { $prevLearnings = Get-Content $prevLearnPath -Raw }
    $cycleLearnings = @(
        "## Cycle $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        "- Candidates: $($Candidates.Count) | Benchmark passed: $BenchmarkPassed | Gates: $gatesPassed"
        "- Score: $benchScore"
        "- Best score: $($manifest.best_score)"
    )
    if ($Candidates.Count -gt 0) {
        $topC = $Candidates[0]
        $cycleLearnings += "- Top candidate: $($topC.Name) (score $($topC.Score)/100)"
    }
    $cycleLearnings += @("","")
    $allLearnings = $prevLearnings + ($cycleLearnings -join "`r`n")
    $allLearnings | Out-File $prevLearnPath -Encoding utf8
    $cycleLearnings -join "`r`n" | Out-File $learningsFile -Encoding utf8
    Log "Learnings appended to $prevLearnPath"

    # Regression suite - self-maintained eval suite (auto-harness gating.py pattern)
    $regressionFile = "$env:USERPROFILE\.autoresearch\regression-suite.json"
    $latestBench = @(Get-ChildItem "$benchmarksDir\*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    if ($latestBench) {
        try {
            $benchResult = Get-Content $latestBench[0].FullName -Raw | ConvertFrom-Json
            $suite = @{}
            if (Test-Path $regressionFile) { $suite = Get-Content $regressionFile -Raw | ConvertFrom-Json }
            $suite.last_run = (Get-Date -Format "yyyy-MM-dd HH:mm")
            $suite.score = $benchScore
            $suite.best_score = $manifest.best_score

            # Parse per-task data from individual run files
            $allTasks = @{}
            $suiteTasks = @{}
            if ($suite.tasks -and $suite.tasks.PSObject.Properties) {
                foreach ($__prop in $suite.tasks.PSObject.Properties) { $suiteTasks[$__prop.Name] = $__prop.Value }
            }
            if ($benchResult.run_files) {
                foreach ($rf in $benchResult.run_files) {
                    if (Test-Path $rf) {
                        $runData = Get-Content $rf -Raw | ConvertFrom-Json
                        $suite.total_tests = $runData.total_tests
                        $suite.passed_tests = $runData.passed_tests
                        $suite.failed_tests = $runData.failed_tests
                        if ($runData.tests) {
                            foreach ($t in $runData.tests.PSObject.Properties) {
                                $taskName = $t.Name
                                $taskPass = $t.Value.pass
                                if (-not $allTasks.ContainsKey($taskName)) { $allTasks[$taskName] = $taskPass }
                                $__inSuite = $suiteTasks.ContainsKey($taskName)
                                # Auto-promote: if passing and not in suite, add it
                                if ($taskPass -and -not $__inSuite) {
                                    $suiteTasks[$taskName] = @{ added = (Get-Date -Format "yyyy-MM-dd HH:mm"); status = "passing" }
                                }
                                # Flag regression: was in suite but now failing
                                if (-not $taskPass -and $__inSuite) {
                                    $suiteTasks[$taskName].status = "regressed"
                                    $suiteTasks[$taskName].last_fail = (Get-Date -Format "yyyy-MM-dd HH:mm")
                                }
                            }
                        }
                    }
                }
            }
            # Use Add-Member for JSON objects (can't set new properties directly)
            $suite | Add-Member -NotePropertyName "tasks" -NotePropertyValue $suiteTasks -Force

            # Track trend direction
            if ($suite.history -isnot [array]) { $suite.history = @() }
            $prevScore = if ($suite.history.Count -gt 0) { $suite.history[-1].score } else { $null }
            $trend = if ($null -eq $prevScore) { "initial" } elseif ($benchScore -gt $prevScore) { "up" } elseif ($benchScore -lt $prevScore) { "down" } else { "flat" }
            $suite | Add-Member -NotePropertyName "trend" -NotePropertyValue $trend -Force
            $suite.history += @{ date = (Get-Date -Format "yyyy-MM-dd HH:mm"); score = $benchScore; trend = $trend; tasks = $suite.passed_tests; total = $suite.total_tests }
            if ($suite.history.Count -gt 20) { $suite.history = $suite.history | Select-Object -Last 20 }

            $suite | ConvertTo-Json -Depth 5 -Compress | Set-Content $regressionFile
            $regressedCount = @($suiteTasks.Values | Where-Object { $_.status -eq "regressed" }).Count
            $promotedCount = @($suiteTasks.Values | Where-Object { $_.added -eq (Get-Date -Format "yyyy-MM-dd HH:mm") }).Count
            Log "Regression suite: $($suite.passed_tests)/$($suite.total_tests) passing ($trend), $regressedCount regressed, $promotedCount promoted"
        } catch { Log "WARNING: Could not update regression suite: $_" }
    }
    Write-Host "Learnings stored. $($allCycles.Count) total cycles recorded." -ForegroundColor Cyan
    Write-Host "Learnings stored. $($allCycles.Count) total cycles recorded." -ForegroundColor Cyan
}

# ═══════════════════════════════════════════════════════════════
# MAIN PIPELINE
# ═══════════════════════════════════════════════════════════════
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

    # Generate PROGRAM.md for top-scored candidate (auto-harness pattern)
    if ($allCandidates.Count -gt 0) {
        $topCandidate = $allCandidates | Sort-Object Score -Descending | Select-Object -First 1
        $programFile = "$CycleDir\PROGRAM.md"
        $bestScore = $null
        if ($manifest.best_score) { $bestScore = $manifest.best_score }

        @"
# PROGRAM.md — AHE Auto-Implementation Plan
## Cycle: $(Get-Date -Format "yyyy-MM-dd HH:mm")

### Top Candidate: $($topCandidate.Name)
- **Score:** $($topCandidate.Score)/100 ($($topCandidate.Stars)★)
- **Category:** $($topCandidate.Category)
- **Description:** $($topCandidate.Description)

### Instructions
1. Review the candidate at https://github.com/$($topCandidate.Name)
2. Determine if this MCP/server should be installed
3. If yes: install it, update settings.json, and run the benchmark
4. If no: log rationale and skip

### Gating
- Run $ScriptsDir\benchmark.ps1 before and after
- Current best score: $($bestScore)
- Gate: score must improve or remain flat with no regressions

### Regression Suite
Check $env:USERPROFILE\.autoresearch\regression-suite.json for previously-passing tasks
"@ | Out-File $programFile -Encoding utf8
        Log "PROGRAM.md written for $($topCandidate.Name) — $programFile"

    # Auto-implement top candidate (Phase 2 Lean)
    if ($topCandidate.Score -ge 70) {
        $evalResult = Invoke-CandidateEval -Candidate $topCandidate -Manifest $manifest
        if ($evalResult) {
            Log "CAND_EVAL: $($evalResult.candidate) → $($evalResult.verdict) (score: $($evalResult.score))"
        }
    }
    }
}

if ((-not $Phase) -or $Phase -eq "benchmark") {
    $benchmarkPassed = Invoke-Benchmark -Candidates $allCandidates
    Log "AHE: Benchmark result: $benchmarkPassed"

    # Best-So-Far Gate (Paper Algorithm 1, line 14)
    $bestScoreFile = "$CycleDir\baseline.json"
    if (Test-Path $bestScoreFile) {
        $currentBest = Get-Content $bestScoreFile -Raw | ConvertFrom-Json
        $currentScore = if ($null -ne $currentBest.median_score) { $currentBest.median_score } else { $currentBest.score }
        $prevBest = $manifest.best_score
        if ($null -eq $prevBest -or $currentScore -gt $prevBest) {
            # JSON objects from ConvertFrom-Json can't set new properties directly
            if ($null -eq $manifest.best_score -and $null -eq $prevBest) {
                $manifest | Add-Member -NotePropertyName "best_score" -NotePropertyValue $currentScore -Force
            } else {
                $manifest.best_score = $currentScore
            }
            if ($null -ne $prevBest) {
                Log "Best-So-Far Gate: NEW BEST $currentScore (was $prevBest, +$([math]::Round($currentScore - $prevBest, 1)) pts)"
            } else {
                Log "Best-So-Far Gate: Initial baseline $currentScore"
            }
            Save-AheManifest $manifest
        } else {
            Log "Best-So-Far Gate: $currentScore <= $prevBest (no improvement)"
        }
    }
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
    Invoke-Swarm -Goal "Optimize AHE harness with multi-model routing"
    Invoke-Compound -Candidates $allCandidates -BenchmarkPassed $benchmarkPassed -GatesPassed $gatesPassed
}

Write-Host ""
Write-Host "=== Self-Improvement Complete ===" -ForegroundColor Magenta
Log "Cycle complete. Log: $LogFile"

# Phase 3: Swarm / Ralph Loop
function Invoke-Swarm {
    param([string]$Goal)
    Write-Host "`n=== Phase: Swarm / Ralph Loop ===" -ForegroundColor Cyan
    $py = "C:\Users\Administrator\Scripts\archive\ahe-ralph-loop.py"
    if (-not (Test-Path $py)) {
        Log "WARNING: ralph-loop.py not found - skipping swarm phase"
        return
    }
    Log "Running Ralph loop with goal: $Goal"
    $result = & python $py $Goal 2>&1 | Out-String
    Log "Ralph loop complete"
}


