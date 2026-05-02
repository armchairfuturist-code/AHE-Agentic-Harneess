<#
.SYNOPSIS
    Agent Debugger — layered evidence distillation from benchmark results
.DESCRIPTION
    Reads benchmark result files from .autoresearch/benchmarks/ and produces
    a layered evidence corpus for the Evolve Agent (AHE §3.2).

    Layers:
      L1 — Score summary per category with trend
      L2 — Per-test pass/fail history across all benchmarks
      L3 — Anomaly detection (regressions, improvements, noise)
      L4 — Actionable recommendations for Evolve Agent
.PARAMETER Json
    Output as JSON (for pipeline consumption)
.PARAMETER Latest
    Only analyze the N most recent benchmarks (default: all available)
#>
param(
    [switch]$Json,
    [int]$Latest = 0
)

$ErrorActionPreference = 'Continue'
$BenchmarksDir = "$env:USERPROFILE\.autoresearch\benchmarks"
$ManifestFile = "$env:USERPROFILE\.autoresearch\ahe-manifest.json"
$DebuggerDir = "$env:USERPROFILE\.autoresearch\debugger"
if (-not (Test-Path $DebuggerDir)) { New-Item -ItemType Directory -Path $DebuggerDir -Force | Out-Null }

# ═══════════════════════════════════════════════════════════════
# COLLECT BENCHMARK FILES
# ═══════════════════════════════════════════════════════════════
$allBenchFiles = @(Get-ChildItem "$BenchmarksDir\benchmark-*.json" | Sort-Object LastWriteTime)
if ($allBenchFiles.Count -eq 0) {
    Write-Error "No benchmark files found in $BenchmarksDir"
    return
}

# Filter to aggregate files only (not run1/run2)
$aggFiles = @($allBenchFiles | Where-Object { $_.Name -notmatch '-run\d\.json$' })
if ($aggFiles.Count -eq 0) { $aggFiles = $allBenchFiles }  # fallback

if ($Latest -gt 0 -and $Latest -lt $aggFiles.Count) {
    $aggFiles = $aggFiles[-$Latest..-1]
}

Write-Host "Agent Debugger: $($aggFiles.Count) benchmark files loaded" -ForegroundColor Cyan

# ═══════════════════════════════════════════════════════════════
# LAYER 1: SCORE TREND
# ═══════════════════════════════════════════════════════════════
Write-Host "`n─── Layer 1: Score Trend ───" -ForegroundColor Magenta

$scoreHistory = @()
foreach ($f in $aggFiles) {
    $data = Get-Content $f.FullName -Raw | ConvertFrom-Json
    $score = if ($null -ne $data.median_score) { $data.median_score } else { $data.score }
    $scoreHistory += [PSCustomObject]@{
        file = $f.Name
        timestamp = $data.timestamp
        score = $score
        runs = if ($null -ne $data.runs) { $data.runs } else { 1 }
        spread = if ($null -ne $data.spread) { $data.spread } else { $null }
    }
}

# Trend direction
$trendDirection = "flat"
$trendDelta = 0
if ($scoreHistory.Count -ge 2) {
    $first = $scoreHistory[0].score
    $last = $scoreHistory[-1].score
    $trendDelta = [math]::Round($last - $first, 1)
    if ($trendDelta -gt 0) { $trendDirection = "up" }
    elseif ($trendDelta -lt 0) { $trendDirection = "down" }
}

$maxScore = ($scoreHistory | Measure-Object score -Maximum).Maximum
$minScore = ($scoreHistory | Measure-Object score -Minimum).Minimum
$avgScore = [math]::Round(($scoreHistory | Measure-Object score -Average).Average, 1)

Write-Host "  Benchmarks analyzed: $($scoreHistory.Count)" -ForegroundColor Gray
Write-Host "  Score range: $minScore - $maxScore (avg: $avgScore)" -ForegroundColor Gray
Write-Host "  Trend: $trendDirection ($trendDelta pts)" -ForegroundColor $(if($trendDelta -gt 0){'Green'}elseif($trendDelta -lt 0){'Red'}else{'Gray'})

if ($scoreHistory.Count -ge 3) {
    # Compute rolling variance (last 3)
    $recent3 = $scoreHistory[-3..-1]
    $recentAvg = ($recent3 | Measure-Object score -Average).Average
    $variance = ($recent3 | ForEach-Object { [math]::Pow($_.score - $recentAvg, 2) } | Measure-Object -Average).Average
    $stdDev = [math]::Round([math]::Sqrt($variance), 2)
    Write-Host "  Stability (last 3): σ = $stdDev" -ForegroundColor $(if($stdDev -le 1){'Green'}elseif($stdDev -le 3){'Yellow'}else{'Red'})
}

# ═══════════════════════════════════════════════════════════════
# LAYER 2: PER-TEST HISTORY (cross-benchmark)
# ═══════════════════════════════════════════════════════════════
Write-Host "`n─── Layer 2: Per-Test History ───" -ForegroundColor Magenta

$testHistory = @{}  # test_name → [pass/fail per file]

foreach ($f in $aggFiles) {
    $data = Get-Content $f.FullName -Raw | ConvertFrom-Json
    if (-not $data.tests) { continue }

    # Check all test categories
    $categories = @('system','mcp','hook','memory','skill')
    foreach ($cat in $categories) {
        foreach ($testKey in $data.tests.PSObject.Properties.Name) {
            if ($testKey -match "^$cat\.") {
                $testData = $data.tests.$testKey
                if (-not $testHistory.ContainsKey($testKey)) { $testHistory[$testKey] = @() }
                $testHistory[$testKey] += $testData.pass
            }
        }
    }
}

$flakyTests = @()
$failedTests = @()
$perfectTests = @()

foreach ($testName in ($testHistory.Keys | Sort-Object)) {
    $results = $testHistory[$testName]
    $failCount = @($results | Where-Object { $_ -eq $false }).Count
    $passCount = @($results | Where-Object { $_ -eq $true }).Count
    $total = $results.Count
    $passRate = [math]::Round($passCount / $total * 100, 0)

    $status = "✅ $passRate%"
    if ($failCount -gt 0 -and $passCount -gt 0) {
        $flakyTests += $testName
        $status = "⚠️ $passRate% (flaky, $failCount/$total failed)"
    } elseif ($failCount -eq $total) {
        $failedTests += $testName
        $status = "❌ $passRate% (always fails)"
    } elseif ($passCount -eq $total) {
        $perfectTests += $testName
    }

    Write-Host "  $status — $testName" -ForegroundColor $(if($failCount -eq 0){'Green'}elseif($passCount -gt 0){'Yellow'}else{'Red'})
}

Write-Host ""
Write-Host "  Summary: $($perfectTests.Count) perfect, $($flakyTests.Count) flaky, $($failedTests.Count) failed" -ForegroundColor $(if($failedTests.Count -eq 0 -and $flakyTests.Count -eq 0){'Green'}else{'Yellow'})

# ═══════════════════════════════════════════════════════════════
# LAYER 3: ANOMALY DETECTION
# ═══════════════════════════════════════════════════════════════
Write-Host "`n─── Layer 3: Anomaly Detection ───" -ForegroundColor Magenta

$anomalies = @()

# Check for score drops
if ($scoreHistory.Count -ge 2) {
    for ($i = 1; $i -lt $scoreHistory.Count; $i++) {
        $drop = $scoreHistory[$i-1].score - $scoreHistory[$i].score
        if ($drop -gt 3) {
            $anomalies += "Score drop of $drop pts between $($scoreHistory[$i-1].file) and $($scoreHistory[$i].file)"
            Write-Host "  ⚠ Score drop: -$drop pts (cycle $i)" -ForegroundColor Yellow
        }
    }
}

# Check for flaky tests
foreach ($t in $flakyTests) {
    $anomalies += "Flaky test: $t (intermittent failures across cycles)"
}
foreach ($t in $failedTests) {
    $anomalies += "Persistent failure: $t (never passes)"
}

if ($anomalies.Count -eq 0) {
    Write-Host "  ✅ No anomalies detected" -ForegroundColor Green
} else {
    Write-Host "  $($anomalies.Count) anomalies found" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════
# LAYER 4: RECOMMENDATIONS
# ═══════════════════════════════════════════════════════════════
Write-Host "`n─── Layer 4: Recommendations ───" -ForegroundColor Magenta

$recommendations = @()

# Read manifest for pending predictions
$manifest = $null
if (Test-Path $ManifestFile) {
    try {
        $manifest = Get-Content $ManifestFile -Raw | ConvertFrom-Json
    } catch {}
}

$pendingCount = 0
$keptCount = 0
$revertedCount = 0
if ($manifest -and $manifest.improvement_history) {
    foreach ($entry in $manifest.improvement_history) {
        switch ($entry.verification.verdict) {
            "pending" { $pendingCount++ }
            "keep" { $keptCount++ }
            "revert" { $revertedCount++ }
        }
    }
}

Write-Host "  Manifest: $pendingCount pending, $keptCount kept, $revertedCount reverted" -ForegroundColor Cyan

# Score-based recommendations
if ($scoreHistory.Count -ge 2 -and $trendDelta -lt 0) {
    $rec = "Benchmark score declining ($trendDelta pts) — investigate recent changes"
    $recommendations += $rec
    Write-Host "  🔴 $rec" -ForegroundColor Red
} elseif ($scoreHistory.Count -ge 2 -and $trendDelta -gt 0) {
    $rec = "Score improving (+$trendDelta pts) — continue current approach"
    $recommendations += $rec
    Write-Host "  🟢 $rec" -ForegroundColor Green
} else {
    $rec = "Score stable at $avgScore — focus on expanding test coverage"
    $recommendations += $rec
    Write-Host "  🔵 $rec" -ForegroundColor Blue
}

# Flaky test recommendations
if ($flakyTests.Count -gt 0) {
    $rec = "$($flakyTests.Count) flaky tests — add noise handling or investigate root cause"
    $recommendations += $rec
    Write-Host "  🟡 $rec" -ForegroundColor Yellow
}

# Pending prediction recommendations
if ($pendingCount -gt 0) {
    $rec = "$pendingCount pending predictions — run benchmark to resolve"
    $recommendations += $rec
    Write-Host "  🟠 $rec" -ForegroundColor Yellow
}

# Missing coverage recommendations
$coveredCategories = @{}
foreach ($testName in $testHistory.Keys) {
    foreach ($cat in @('system','mcp','hook','memory','skill')) {
        if ($testName -match "^$cat\.") { $coveredCategories[$cat] = $true }
    }
}
$allCategories = @('system','mcp','hook','memory','skill')
$missingCategories = $allCategories | Where-Object { -not $coveredCategories.ContainsKey($_) }
if ($missingCategories.Count -gt 0) {
    $rec = "Missing test categories: $($missingCategories -join ', ') — add coverage"
    $recommendations += $rec
    Write-Host "  🟣 $rec" -ForegroundColor Magenta
}

# ═══════════════════════════════════════════════════════════════
# COMPILE EVIDENCE CORPUS
# ═══════════════════════════════════════════════════════════════
$corpus = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    benchmarks_analyzed = $aggFiles.Count
    layers = @{
        layer1_score_trend = @{
            scores = $scoreHistory
            trend_direction = $trendDirection
            trend_delta = $trendDelta
            min_score = $minScore
            max_score = $maxScore
            avg_score = $avgScore
        }
        layer2_per_test = @{
            perfect_tests = $perfectTests
            flaky_tests = $flakyTests
            failed_tests = $failedTests
        }
        layer3_anomalies = $anomalies
        layer4_recommendations = $recommendations
    }
    manifest_state = @{
        pending_predictions = $pendingCount
        kept = $keptCount
        reverted = $revertedCount
    }
}

# Save
$outputFile = "$DebuggerDir\debugger-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$corpus | ConvertTo-Json -Depth 5 -Compress | Set-Content $outputFile -Force
Write-Host ""
Write-Host "Evidence corpus saved: $outputFile" -ForegroundColor Cyan

if ($Json) {
    $corpus | ConvertTo-Json -Depth 5
}

return $corpus
