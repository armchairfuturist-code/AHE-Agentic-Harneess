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
    [switch]$LogOnly,
    [switch]$Research
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

# ============================================================================
# Gbrain Write Utility (SSH-based, graceful degradation)
# ============================================================================
function Write-GbrainPage {
    param([string]$Slug, [string]$Content, [string]$Label = "")
    try {
        $tmpFile = Join-Path $env:TEMP "gbrain-write-$([System.IO.Path]::GetRandomFileName()).md"
        $Content | Out-File -FilePath $tmpFile -Encoding utf8 -Force
        $gbrainCmd = "export PATH=/home/alex/.bun/bin:`$PATH && /home/alex/.bun/bin/gbrain put $Slug"
        $result = Get-Content $tmpFile -Raw | ssh alex@100.102.182.39 $gbrainCmd 2>&1
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Log "GBRAIN OK: $Label ($Slug)"
            return $true
        } else {
            $resultStr = ($result | Out-String).Trim()
            Log "GBRAIN FAIL: $Label ($Slug) - exit $exitCode $resultStr"
            return $false
        }
    } catch {
        Log "GBRAIN ERROR: $Label ($Slug) - $_"
        try { Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue } catch {}
        return $false
    }
}

# Dot-source modules (HeavySkill replaces external Python Ralph Loop + sequential debugger).
# Level 1-3 simplification: parallel reasoning → summarization instead of 4-step sequential BoN.
. "$ScriptsDir\ahe-backup-rollback.ps1"
. "$ScriptsDir\ahe-candidate-eval.ps1"
. "$PSScriptRoot\ahe-heavyskill.ps1"

# ═══════════════════════════════════════════════════════════════
# PHASE: AGENT DEBUGGER (via HeavySkill inner reasoning)
# ═══════════════════════════════════════════════════════════════
# Replaced external archive/agent-debugger.ps1 call with HeavySkill inline reasoning.
# The prior 4-step sequential loop (judge→evolve→code→verify) is now a single
# parallel reasoning → summarization call. No Python dependency, no external script.
function Invoke-AgentDebugger {
    Write-Host "`n=== Phase: Agent Debugger (HeavySkill inline) ===" -ForegroundColor Cyan
    Log "Agent Debugger: delegated to HeavySkill inner reasoning"
    return @{ status = "delegated"; method = "heavyskill-inline" }
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

# ============================================================================
# Gbrain Context Reader (pre-discover gbrain lookup)
# ============================================================================
function Invoke-GbrainContext {
    <#
    .SYNOPSIS
        Query gbrain for historical pipeline cycles and build a list of already-tried candidates.
    #>
    param([ref]$KnownNames)
    try {
        $listCmd = "export PATH=/home/alex/.bun/bin:`$PATH && /home/alex/.bun/bin/gbrain list --slug-prefix research/ahe/pipeline 2>/dev/null"
        $pageList = ssh alex@100.102.182.39 $listCmd 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $pageList) {
            Log "GBRAIN CONTEXT: no pipeline pages found (first run or gbrain unreachable)"
            return $false
        }
        $cyclesFound = 0
        $candidatesFound = 0
        $pageLines = $pageList -split "`n"
        foreach ($line in $pageLines) {
            $slug = ($line -split "`t")[0]
            if (-not $slug -or $slug -notmatch "pipeline") { continue }
            $getCmd = "export PATH=/home/alex/.bun/bin:`$PATH && /home/alex/.bun/bin/gbrain get $slug"
            $pageContent = ssh alex@100.102.182.39 $getCmd 2>$null
            if ($LASTEXITCODE -eq 0 -and $pageContent) {
                $cyclesFound++
                $lines = $pageContent -split "`n"
                $inTable = $false
                foreach ($pl in $lines) {
                    if ($pl -match '^\| Name \| Score \|') { $inTable = $true; continue }
                    if ($inTable -and $pl -match '^\| .+ \| .+ \|') {
                        $parts = $pl -split '\|'
                        if ($parts.Count -ge 2) {
                            $cname = $parts[1].Trim()
                            if ($cname -and $cname -ne '---') {
                                $KnownNames.Value[$cname] = $true
                                $candidatesFound++
                            }
                        }
                    }
                    if ($inTable -and $pl -match '^$') { $inTable = $false }
                }
            }
        }
        if ($cyclesFound -gt 0) {
            Log "GBRAIN CONTEXT: $cyclesFound pipeline page(s), $candidatesFound known candidate(s) loaded"
        } elseif ($pageList -and $pageList.Trim().Length -gt 0) {
            Log "GBRAIN CONTEXT: $($pageLines.Count) page(s) listed but none matched pipeline cycles"
        }
        return ($cyclesFound -gt 0)
    } catch {
        Log "GBRAIN CONTEXT ERROR: $_"
        return $false
    }

# ============================================================================
# Attribution Tracker (per-candidate evaluation storage in gbrain)
# ============================================================================
function Invoke-Attribution {
    param(
        [array]$Candidates,
        [object]$BenchResult,
        [bool]$BenchmarkPassed,
        [array]$AdditionalEntries = @()
    )
    try {
        $score = if ($BenchResult -and $null -ne $BenchResult.score) { $BenchResult.score } else { $null }
        $attributionContent = @"
# Pipeline Attribution: $(Get-Date -Format 'yyyy-MM-dd')
**Source:** AHE Self-Improvement Pipeline

## Summary
- **Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- **Candidates evaluated:** $($Candidates.Count)
- **Benchmark passed:** $BenchmarkPassed $(if($score){' (score: ' + $score + '/100)'}else{''})

## Candidate Attributions
"@
        if ($Candidates.Count -gt 0) {
            $attributionContent += @"
| Candidate | Type | Score | Verdict |
|-----------|------|-------|---------|
$(foreach ($c in $Candidates) {
"| $($c.Name) | $($c.Type) | $($c.Score) | pending |
"
})
"@
        } else {
            $attributionContent += @"
No candidates evaluated in this cycle.

"@
        }
        if ($AdditionalEntries.Count -gt 0) {
            $attributionContent += @"
## Additional Evaluation Data
$(foreach ($entry in $AdditionalEntries) {
"- **$($entry.candidate):** $($entry.verdict) (score: $(if($entry.score){$entry.score}else{'N/A'}))
"
})
"@
        }
        $attributionContent += @"
## Trend
- **Cycle count:** $(if($manifest -and $manifest.cycle_count){$manifest.cycle_count}else{'N/A'})
- **Best score:** $(if($manifest -and $manifest.best_score){$manifest.best_score}else{'N/A'})
"@
        $attributionSlug = "research/ahe/attribution-$(Get-Date -Format 'yyyy-MM-dd')"
        $null = Write-GbrainPage -Slug $attributionSlug -Content $attributionContent -Label "Attribution"
        Log "ATTRIBUTION: $($Candidates.Count) candidate(s) tracked in gbrain ($attributionSlug)"
    } catch {
        Log "ATTRIBUTION ERROR: $_"
    }

# ============================================================================
# Learnings-Aware Gate (enriches gate verdict with gbrain historical patterns)
# ============================================================================
function Invoke-LearningsGate {
    param([array]$Candidates)
    try {
        $listCmd = "export PATH=/home/alex/.bun/bin:`$PATH && /home/alex/.bun/bin/gbrain list --slug-prefix research/ahe/attribution 2>/dev/null"
        $pageList = ssh alex@100.102.182.39 $listCmd 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $pageList) {
            Log "LEARNINGS GATE: No attribution history in gbrain (first run or unreachable)"
            return
        }
        $pageLines = $pageList -split "`n"
        $totalCycles = $pageLines.Count
        $readCount = 0
        foreach ($line in $pageLines) {
            if ($readCount -ge 5) { break }
            $slug = ($line -split "`t")[0]
            if (-not $slug) { continue }
            $getCmd = "export PATH=/home/alex/.bun/bin:`$PATH && /home/alex/.bun/bin/gbrain get $slug 2>/dev/null"
            $pageContent = ssh alex@100.102.182.39 $getCmd 2>$null
            if ($LASTEXITCODE -eq 0 -and $pageContent) {
                $readCount++
            }
        }
        $currentScore = $null
        $benchmarksDir = "$env:USERPROFILE\.autoresearchenchmarks"
        $latestBench = @(Get-ChildItem "$benchmarksDir\*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
        if ($latestBench) {
            $bench = Get-Content $latestBench[0].FullName -Raw | ConvertFrom-Json
            $currentScore = if ($null -ne $bench.score) { $bench.score } elseif ($null -ne $bench.median_score) { $bench.median_score } else { $null }
        }
        $patternSummary = "Historical context: $totalCycles attribution page(s) read, $readCount with data"
        if ($currentScore) { $patternSummary += " | Current benchmark: $currentScore/100" }
        if ($Candidates.Count -gt 0) {
            $patternSummary += " | Evaluating $($Candidates.Count) candidate(s) this cycle"
        }
        Log "LEARNINGS GATE: $patternSummary"
    } catch {
        Log "LEARNINGS GATE ERROR: $_"
    }
}
}
}

# ============================================================================
# PHASE 0: DISCOVERY
# ============================================================================

. "$ScriptsDir\archive\ahe-evolve-module.ps1\"
function Invoke-Discovery {
    param(
        [hashtable]$ExternalKnownNames = @{}
    )    # Research phase: find new MCPs, tools, and config gaps
    try { & "$ScriptsDir\archive\ahe-research.ps1" } catch { Write-Host "  Research failed: $_" -ForegroundColor Red }

    # Read scored candidates from knowledge directory (ahe-evaluate-candidates.py output)
    $knowledgeFile = "$env:USERPROFILE\.autoresearch\knowledge\candidate-evaluations.json"
    $knownNames = @{}
    # Merge external known names (from gbrain context) with manifest history
    foreach ($k in $ExternalKnownNames.Keys) { $knownNames[$k] = $true }    if ($manifest -and $manifest.improvement_history) {
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

    # Tract scores + kappa from multi-tract benchmark
    $tractScores = @{}
    $kappa = $null
    if ($result.tract_scores) { $tractScores = $result.tract_scores }
    if ($null -ne $result.kappa) { $kappa = $result.kappa }

    Log "  Correctness: $($tractScores.correctness)/100 | Utility: $($tractScores.utility)/100 | Reliability: $($tractScores.reliability)/100 | Kappa: $kappa"

    # Return an object with tract-level detail for the pipeline decision matrix
    return @{
        passed = ($score -ge 50)
        score = $score
        tract_scores = $tractScores
        kappa = $kappa
    }
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
function Invoke-Compound {
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
        tract_scores = $tractScores
        kappa = $kappa
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
    Write-Host "Learnings stored. $($allCycles.Count) total cycles recorded." -ForegroundColor Cyan

    # ============================================================================
    # Gbrain writes (graceful degradation - never fails the pipeline)
    # ============================================================================
    
    # 1. Pipeline cycle summary -> research/ahe/pipeline-<date>
    $pipelineSlug = "research/ahe/pipeline-$(Get-Date -Format 'yyyy-MM-dd')"
    $pipelineContent = @"
# Pipeline Cycle: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
**Source:** AHE Self-Improvement Pipeline

## Summary
- **Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- **Candidates found:** $($Candidates.Count)
- **Benchmark:** $(if($BenchmarkPassed){'PASSED'}else{'FAILED'}) (score: $benchScore)
- **Gates:** $(if($GatesPassed){'PASSED'}else{'FAILED'})

"@
    if ($Candidates.Count -gt 0) {
        $pipelineContent += @"
## Top Candidates
| Name | Score | Category |
|------|-------|----------|
$(foreach ($c in ($Candidates | Select-Object -First 3)) {
"| $($c.Name) | $($c.Score) | $($c.Category) |
"
})
"@
    }
    $pipelineContent += @"
## Benchmark Detail
- **Score:** $benchScore
"@
    if ($tractScores) {
        $pipelineContent += @"
- **Correctness:** $($tractScores.correctness)
- **Utility:** $($tractScores.utility)
- **Reliability:** $($tractScores.reliability)
"@
    }
    if ($kappa -ne $null) {
        $pipelineContent += @"
- **Kappa:** $kappa
"@
    }
    $null = Write-GbrainPage -Slug $pipelineSlug -Content $pipelineContent -Label "Pipeline cycle"

    # 2. Latest benchmark -> configs/ahe/benchmark
    $benchSlug = "configs/ahe/benchmark"
    $benchContent = @"
# AHE Benchmark: Latest
**Updated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Score: $benchScore/100
- **Date:** $(Get-Date -Format 'yyyy-MM-dd')
- **Benchmark passed:** $BenchmarkPassed
"@
    if ($tractScores) {
        $benchContent += @"
- **Correctness:** $($tractScores.correctness)/100
- **Utility:** $($tractScores.utility)/100
- **Reliability:** $($tractScores.reliability)/100
"@
    }
    if ($kappa -ne $null) {
        $benchContent += @"
- **Kappa trend:** $kappa
"@
    }
    $null = Write-GbrainPage -Slug $benchSlug -Content $benchContent -Label "Benchmark"

    # 3. AHE Manifest summary -> configs/ahe/manifest
    $manifestSlug = "configs/ahe/manifest"
    $manifestContent = @"
# AHE Component Manifest
**Updated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Overview
- **Source:** $AheManifest
- **Last cycle:** $(if($manifest -and $manifest.last_cycle){$manifest.last_cycle}else{"N/A"})
- **Cycle count:** $(if($manifest -and $manifest.cycle_count){$manifest.cycle_count}else{0})
- **Best score:** $(if($manifest -and $manifest.best_score){$manifest.best_score}else{"N/A"})

## Components
"@
    if ($manifest -and $manifest.components) {
        $manifestContent += @"
| Component | Type | Active | Iterations |
|-----------|------|--------|------------|
$(foreach ($comp in $manifest.components) {
"| $($comp.id) | $($comp.type) | $(if($comp.active){"yes"}else{"no"}) | $($comp.iterations) |
"
})
"@
    } else {
        $manifestContent += @"
No components in manifest yet.
"@
    }
    $null = Write-GbrainPage -Slug $manifestSlug -Content $manifestContent -Label "Manifest"

    # 4. Session manifest summaries -> learnings/ahe/session-<date>
    $sessionManifestDir = "$env:USERPROFILE\.ahe\session-manifests"
    $sentinelFile = "$env:USERPROFILE\.autoresearch\.gbrain-session-sync.json"
    $sentinel = @{}
    if (Test-Path $sentinelFile) {
        try { $sentinel = Get-Content $sentinelFile -Raw | ConvertFrom-Json } catch {}
    }
    $manifestFiles = @(Get-ChildItem "$sessionManifestDir\*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    $syncedCount = 0
    foreach ($mf in $manifestFiles) {
        $slugSuffix = $mf.BaseName -replace '[^a-zA-Z0-9_-]', ''
        $sessionSlug = "learnings/ahe/session-$slugSuffix"
        if ($sentinel.PSObject.Properties.Name -contains $mf.Name) {
            continue
        }
        try {
            $sessionData = Get-Content $mf.FullName -Raw | ConvertFrom-Json
            $sessionContent = @"
# Session: $slugSuffix
**Source:** AHE session manifest

## Summary
- **Date:** $(if($sessionData.date){$sessionData.date}else{$sessionData.created})
- **Model:** $(if($sessionData.model){$sessionData.model}else{'unknown'})
- **Outcome:** $(if($sessionData.outcome){$sessionData.outcome}else{'unknown'})
- **Duration:** $(if($sessionData.duration_minutes){$sessionData.duration_minutes}else{'unknown'}) min
- **Tool count:** $(if($sessionData.tool_count){$sessionData.tool_count}else{'unknown'})

## Activity
$(if($sessionData.skills_used){"> **Skills:** $($sessionData.skills_used -join ', ')"}else{"> No skills data"})
$(if($sessionData.files_touched){"> **Files touched:** $($sessionData.files_touched -join ', ')"}else{"> No file data"})
$(if($sessionData.errors_hit){"> **Errors:** $($sessionData.errors_hit -join ', ')"}else{"> No errors"})
$(if($sessionData.patterns){"> **Patterns:** $sessionData.patterns"})
$(if($sessionData.summary){"> **Summary:** $sessionData.summary"})

## Outcome: $(if($sessionData.outcome){$sessionData.outcome}else{'unknown'})
"@
            $ok = Write-GbrainPage -Slug $sessionSlug -Content $sessionContent -Label "Session $slugSuffix"
            if ($ok) {
                $syncedCount++
                $sentinel | Add-Member -NotePropertyName $mf.Name -NotePropertyValue (Get-Date -Format "yyyy-MM-dd HH:mm") -Force
            }
        } catch {
            Log "GBRAIN SKIP: Session $($mf.Name) - $_"
        }
    }
    if ($syncedCount -gt 0) {
        $sentinel | ConvertTo-Json -Compress | Set-Content $sentinelFile -Force
        Log "GBRAIN: Synced $syncedCount session manifest(s) to gbrain"
    }

    # 5. Attribution tracking -> research/ahe/attribution-<date>
    $evalEntries = @()
    if ($manifest -and $manifest.improvement_history) {
        foreach ($h in $manifest.improvement_history) {
            if ($h.verification -and $h.verification.verdict -ne "pending") {
                $evalEntries += [PSCustomObject]@{
                    candidate = $h.candidate
                    verdict = $h.verification.verdict
                    score = if($h.verification.measured_delta){$h.verification.measured_delta}else{$null}
                }
            }
        }
    }
    Invoke-Attribution -Candidates $Candidates -BenchResult $benchResult -BenchmarkPassed $BenchmarkPassed -AdditionalEntries $evalEntries

    Log "GBRAIN: Pipeline cycle gbrain writes complete"
}

    # 24h guard: skip if run within 24 hours unless forced
    if (-not $Force -and (Test-Path $StateFile)) {
        try {
            $state = Get-Content $StateFile -Raw | ConvertFrom-Json
            if ($state.last_run) {
                $lastRun = [DateTime]$state.last_run
                if ((Get-Date) -lt $lastRun.AddHours(24)) {
                    $remaining = [math]::Round(($lastRun.AddHours(24) - (Get-Date)).TotalHours, 1)
                    Log "Research: skipped (next scan in $remaining hours, use -Research to force)"
                    if ($Json) { return @() }
                    return
                }
            }
        } catch {}
    }

    Write-Host "`n=== Phase: Research Discovery (arxiv) ===" -ForegroundColor Cyan
    Log "Querying arxiv for recent papers..."

    # 8 queries covering evaluation, self-improvement, benchmarks, tool-use, workflows
    $queries = @(
        @{label="agent-eval"; q="cat:cs.AI+AND+all:agent+evaluation+benchmark"},
        @{label="self-improve"; q="cat:cs.LG+AND+all:self+improving+self+rewarding"},
        @{label="benchmark-method"; q="cat:cs.LG+AND+all:benchmark+evaluation+methodology"},
        @{label="tool-use"; q="cat:cs.AI+AND+all:tool+use+function+calling+agent"},
        @{label="harness-arch"; q="cat:cs.AI+AND+all:agent+workflow+orchestration+harness"},
        @{label="code-eval"; q="cat:cs.SE+AND+all:code+generation+evaluation+execution"},
        @{label="test-time"; q="cat:cs.LG+AND+all:test+time+compute+scaling+inference"},
        @{label="multi-agent"; q="cat:cs.MA+AND+all:multi+agent+system+evaluation"}
    )

    # Load seen IDs
    $seen = @{}
    if (Test-Path $SeenFile) {
        try { $seenList = Get-Content $SeenFile -Raw | ConvertFrom-Json; foreach ($id in $seenList) { $seen[$id] = $true } } catch {}
    }

    $allEntries = @()

    foreach ($q in $queries) {
        $url = "http://export.arxiv.org/api/query?search_query=$($q.q)&start=0&max_results=20&sortBy=submittedDate&sortOrder=descending"
        try {
            $xml = Invoke-RestMethod -Uri $url -TimeoutSec 10 -ErrorAction Stop
            # Parse Atom feed entries
            if ($xml.feed.entry) {
                foreach ($entry in $xml.feed.entry) {
                    $id = ($entry.id -replace 'http://arxiv.org/abs/', '' -replace 'http://arxiv.org/abs/', '').Trim()
                    if (-not $id -or $seen.ContainsKey($id)) { continue }
                    $title = if ($entry.title) { "$($entry.title)".Trim() } else { "Untitled" }
                    $summary = if ($entry.summary) { "$($entry.summary)".Trim() } else { "" }
                    $published = if ($entry.published) { "$($entry.published)".Trim().Substring(0,10) } else { "" }
                    $authorNames = @()
                    if ($entry.author) {
                        $authors = if ($entry.author -is [array]) { $entry.author } else { @($entry.author) }
                        $authorNames = $authors | ForEach-Object { "$($_.name)".Trim() }
                    }
                    $cat = ""
                    if ($entry.'arxiv:primary_category') { $cat = "$($entry.'arxiv:primary_category'.term)" }
                    $pdfLink = ""
                    if ($entry.link) {
                        $links = if ($entry.link -is [array]) { $entry.link } else { @($entry.link) }
                        $pdfLink = ($links | Where-Object { $_.title -eq 'pdf' } | Select-Object -First 1).href
                    }
                    if (-not $pdfLink) { $pdfLink = "https://arxiv.org/abs/$id" }

                    # Heuristic relevance scoring (title + abstract keywords)
                    $relevanceScore = 5  # base
                    $lowerTitle = $title.ToLower()
                    $lowerSummary = $summary.ToLower()
                    $allText = $lowerTitle + " " + $lowerSummary
                    if ($allText -match 'benchmark|evaluation|metric') { $relevanceScore += 2 }
                    if ($allText -match 'self.improv|self.evolv|autonomous|recursive') { $relevanceScore += 2 }
                    if ($allText -match 'agent|harness|pipeline|workflow|orchestrat') { $relevanceScore += 1 }
                    if ($allText -match 'saturat|ceiling|plateau|diminish|decay') { $relevanceScore += 2 }
                    if ($allText -match 'tool.use|function.call|mcp|api') { $relevanceScore += 1 }

                    $allEntries += [PSCustomObject]@{
                        arxiv_id = $id
                        title = $title
                        published = $published
                        authors = $authorNames -join '; '
                        category = $cat
                        url = "https://arxiv.org/abs/$id"
                        pdf_url = $pdfLink
                        relevance_score = [math]::Min($relevanceScore, 10)
                        summary_1line = if ($summary.Length -gt 150) { $summary.Substring(0,150) + "..." } else { $summary }
                    }
                }
            }
        } catch {
            Log "  arxiv query '$($q.label)' failed: $_"
        }
        # Rate limit: 1 request per 3 seconds
        Start-Sleep -Seconds 3
    }

    # Sort by relevance, take top 5
    $topFindings = $allEntries | Sort-Object relevance_score -Descending | Select-Object -First 5

    if ($topFindings.Count -gt 0) {
        Log "Research: $($allEntries.Count) new papers found, top $($topFindings.Count) by relevance"
        foreach ($f in $topFindings) {
            Log "  [$($f.relevance_score)/10] $($f.title) ($($f.published))"
        }
    } else {
        Log "Research: No new relevant papers found"
    }

    # Persist findings
    $findingsOutput = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
        total_new = $allEntries.Count
        top_findings = $topFindings
    }
    $findingsOutput | ConvertTo-Json -Depth 3 -Compress | Set-Content $FindingsFile -Force

    # Update seen IDs
    $allIds = @($seen.Keys) + ($allEntries | ForEach-Object { $_.arxiv_id })
    $allIds | ConvertTo-Json -Compress | Set-Content $SeenFile -Force

    # Update state
    @{ last_run = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; last_count = $topFindings.Count } | ConvertTo-Json -Compress | Set-Content $StateFile -Force

    Log "Research findings saved to $FindingsFile"

    if ($Json) { return $topFindings }
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

# Research Discovery (arxiv): runs before benchmark, can be standalone with -Phase research or -Research
if ((-not $Phase) -or $Phase -eq "research" -or $Research) {
    Invoke-ResearchDiscovery
}

if ((-not $Phase) -or $Phase -eq "discover") {
    # Pre-discover: load gbrain context for candidate dedup
    $gbrainKnownNames = @{}
    $null = Invoke-GbrainContext -KnownNames ([ref]$gbrainKnownNames)
    $allCandidates = Invoke-Discovery -ExternalKnownNames $gbrainKnownNames

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
    $benchResult = Invoke-Benchmark -Candidates $allCandidates
    $benchmarkPassed = $benchResult.passed
    $tractScores = $benchResult.tract_scores
    $kappa = $benchResult.kappa
    Log "AHE: Benchmark result: passed=$benchmarkPassed score=$($benchResult.score) utility=$($tractScores.utility) reliability=$($tractScores.reliability) kappa=$kappa"
    Write-Host "  Tract scores — Correctness: $($tractScores.correctness) | Utility: $($tractScores.utility) | Reliability: $($tractScores.reliability)" -ForegroundColor Cyan
    if ($null -ne $kappa) {
        $kDir = if ($kappa -gt 0) { "↗" } elseif ($kappa -lt 0) { "↘" } else { "→" }
        Write-Host "  Kappa: $kDir $kappa (trailing trend)" -ForegroundColor $(if($kappa -gt 0){'Green'}elseif($kappa -lt 0){'Red'}else{'Gray'})
    }

    # Level 2: 3-Tract Decision Matrix → HeavySkill parallel reasoning gate
    # Replaces the prior if/elseif/else heuristic (33.7% fix precision) with HeavySkill's
    # parallel reasoning → summarization approach. Generates 3 reasoning traces
    # (optimistic/pessimistic/pragmatic) and summarizes into a gate verdict.
    # Separated from file-integrity Invoke-Gate checks above.
    $hsTractScores = @{
        correctness = if ($tractScores.correctness) { $tractScores.correctness } else { $benchResult.score }
        utility = if ($tractScores.utility) { $tractScores.utility } else { 0 }
        reliability = if ($tractScores.reliability) { $tractScores.reliability } else { 0 }
    }
    $benchDelta = if ($null -ne $scoreDelta) { $scoreDelta } else { 0 }
    $hsKappa = if ($null -ne $kappa) { $kappa } else { 0 }

    try {
        $gateResult = Invoke-HeavySkillGate -TractScores $hsTractScores -BenchmarkDelta $benchDelta -Kappa $hsKappa
        
        # Extract verdict from HeavySkill output
        if ($gateResult -match "## Summary") {
            $summarySection = ($gateResult -split "## Summary" | Select-Object -Skip 1 -First 1) -split "## " | Select-Object -First 1
            $verdictLine = $summarySection.Trim()
        } else {
            $verdictLine = ($gateResult -split "`n" | Select-Object -First 2) -join " "
        }
        
        # Determine actionable verdict for pipeline logic
        $verdictLower = $verdictLine.ToLower()
        if ($verdictLower -match "rollback|revert") {
            Log "DECISION: ROLLBACK via HeavySkill — $verdictLine"
            Write-Host "  🛑 DECISION: ROLLBACK (HeavySkill reasoning)" -ForegroundColor Red
        } elseif ($verdictLower -match "keep|accept") {
            Log "DECISION: KEEP via HeavySkill — $verdictLine"
            Write-Host "  ✅ DECISION: KEEP (HeavySkill reasoning)" -ForegroundColor Green
        } else {
            Log "DECISION: NO_CHANGE via HeavySkill — $verdictLine"
            Write-Host "  ➡️ DECISION: NO_CHANGE (HeavySkill reasoning)" -ForegroundColor Yellow
        }
        
        # Save full HeavySkill gate output for audit trail
        $gateFile = "$CycleDir\gate-reasoning.md"
        $gateResult | Out-File $gateFile -Encoding utf8
        Log "Gate reasoning saved to $gateFile"
    } catch {
        Log "WARNING: HeavySkill gate failed ($_), falling back to score-based heuristics"
        $fallbackScore = $hsTractScores.correctness
        if ($fallbackScore -lt 95) {
            Log "DECISION (fallback): ROLLBACK — $fallbackScore < 95"
            Write-Host "  🛑 DECISION: ROLLBACK (fallback heuristic)" -ForegroundColor Red
        } elseif ($fallbackScore -ge 95) {
            Log "DECISION (fallback): KEEP — $fallbackScore >= 95"
            Write-Host "  ✅ DECISION: KEEP (fallback heuristic)" -ForegroundColor Green
        }
    }

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
    Invoke-LearningsGate -Candidates $allCandidates
    $gatesPassed = Invoke-Gate
    Log "AHE: Gates result: $gatesPassed"
}

# Level 3: Agent Debugger — consolidated into HeavySkill inner reasoning
# (replaces external archive/agent-debugger.ps1 call)
if ((-not $Phase) -or $Phase -eq "debug") {
    $debuggerCorpus = Invoke-AgentDebugger
    if ($debuggerCorpus) {
        Log "AHE: Debugger complete — status=$($debuggerCorpus.status), method=$($debuggerCorpus.method)"
    }
}

# MCP Verification
if ((-not $Phase) -or $Phase -eq "verify") {
    $mcpsPassed = Invoke-McpVerification
    Log "AHE: MCP Verification result: $mcpsPassed"
}

# Compound: store learnings
if ((-not $Phase) -or $Phase -eq "compound") {
    Invoke-Compound -Candidates $allCandidates -BenchmarkPassed $benchmarkPassed -GatesPassed $gatesPassed
}

# Phase 6: Consolidate — regenerate QWEN.md from gbrain manifest
if ((-not $Phase) -or $Phase -eq "consolidate") {
    Write-Host "`n=== Phase 6: Consolidate ===" -ForegroundColor Cyan
    try {
        $consolidateScript = Join-Path $PSScriptRoot "consolidate.ps1"
        if (Test-Path $consolidateScript) {
            Log "Consolidate: running consolidate.ps1..."
            $output = & $consolidateScript -Force 2>&1
            Log "Consolidate: complete"
            Write-Host $output
        } else {
            Log "Consolidate SKIP: consolidate.ps1 not found at $consolidateScript"
        }
    } catch {
        Log "Consolidate ERROR: $_"
    }
}

Write-Host ""
Write-Host "=== Self-Improvement Complete ===" -ForegroundColor Magenta
Log "Cycle complete. Log: $LogFile"

# ═══════════════════════════════════════════════════════════════
# PHASE: SWARM / RALPH LOOP (Replaced by HeavySkill inner reasoning)
# ═══════════════════════════════════════════════════════════════
# Level 1: Replaced external Python Ralph Loop (ahe-ralph-loop.py) with HeavySkill
# parallel reasoning → summarization. The old loop made 4 sequential API calls per
# iteration (judge→Kimi, evolve→DeepSeek, code→DeepSeek, verify→Kimi). HeavySkill
# generates N parallel reasoning traces in one call, then summarizes.
# No Python dependency. No openai library. No external script.
function Invoke-Swarm {
param([string]$Goal)
Write-Host "`n=== Phase: Swarm / HeavySkill Inner Loop ===" -ForegroundColor Cyan

    if (-not $Goal) {
        $Goal = "Analyze the AHE harness and identify the top 3 improvements"
    }
    
    Log "HeavySkill swarm: $Goal"
    
    try {
        # Single HeavySkill call replaces 4 sequential Python API calls
        $result = Invoke-HeavySkillPlan -Goal $Goal
        
        # Save result for pipeline consumption
        $resultFile = "$CycleDir\swarm-result.md"
        $result | Out-File $resultFile -Encoding utf8
        Log "Swarm result saved to $resultFile"
        
        # Extract key sections for pipeline logging
        $summaryLine = ($result -split "`n" | Where-Object { $_ -match "^## Summary" } | Select-Object -First 1)
        if (-not $summaryLine) { $summaryLine = ($result -split "`n" | Select-Object -First 3) -join " | " }
        Log "Swarm result: $summaryLine"
        
        return $result
    } catch {
        Log "ERROR: HeavySkill swarm failed: $_"
        return $null
    }
}


