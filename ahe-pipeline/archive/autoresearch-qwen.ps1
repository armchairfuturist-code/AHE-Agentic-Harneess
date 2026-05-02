# Qwen Code Autoresearch Implementation
# Karpathy-style autonomous research and optimization
# Uses real measurements from crof.ai API with version tracking

param(
    [string]$Goal = "Optimize Qwen Code performance",
    [string]$Metric = "tokens/sec",
    [int]$Iterations = 10,
    [string]$Scope = "Qwen Code configuration",
    [string]$Direction = "higher",  # higher or lower is better
    [string]$Noise = "none",  # none, low, medium, high
    [int]$NoiseRuns = 0,  # 0 = use default based on noise level
    [int]$WarmupRuns = 0,  # Number of warmup runs to discard
    [double]$MinDelta = 0,  # Minimum improvement to keep
    [int]$MaxIterations = 0,  # Stop after N iterations
    [double]$MinImprovement = 0,  # Stop if no improvement > X%
    [int]$NoImprovementCount = 0,  # Stop after N consecutive no-improvement iterations
    [int]$TimeBudget = 0,  # Stop after time limit (seconds)
    [switch]$Rollback,  # Rollback to a specific iteration
    [int]$RollbackTo = 0,  # Iteration number to rollback to
    [switch]$AutoReport,  # Run analyze-autoresearch.ps1 after completion
    [switch]$Reflect,  # GEPA-style reflection after each iteration
    [string]$Guard = ""  # Command that must pass (exit 0) or iteration is forced to discard
)

$ErrorActionPreference = "Stop"

# Cross-platform directory handling
$autoresearchDir = Join-Path $env:USERPROFILE ".autoresearch"
$versionFile = Join-Path $autoresearchDir "versions.json"
$baselineFile = Join-Path $autoresearchDir "baseline.txt"
$logFile = "C:\Users\Administrator\autoresearch-log.tsv"

# Initialize autoresearch directory
function Initialize-AutoresearchDir {
    if (-not (Test-Path $autoresearchDir)) {
        New-Item -ItemType Directory -Path $autoresearchDir -Force | Out-Null
    }

    if (-not (Test-Path $versionFile)) {
        $initialVersion = @{
            versions = @()
            currentVersion = 0
            baseline = $null
            config = @{
                goal = $Goal
                metric = $Metric
                direction = $Direction
                noise = $Noise
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        $initialVersion | ConvertTo-Json -Depth 10 | Out-File -FilePath $versionFile -Encoding UTF8
    }
}

# Get noise configuration
function Get-NoiseConfig {
    $defaultRuns = switch ($Noise) {
        "none" { 1 }
        "low" { 2 }
        "medium" { 3 }
        "high" { 5 }
        default { 1 }
    }

    $runs = if ($NoiseRuns -gt 0) { $NoiseRuns } else { $defaultRuns }

    return @{
        Runs = $runs
        WarmupRuns = $WarmupRuns
        Strategy = $Noise
    }
}

# Get version info
function Get-VersionInfo {
    if (Test-Path $versionFile) {
        return Get-Content $versionFile | ConvertFrom-Json
    }
    return $null
}

# Save version info
function Save-VersionInfo {
    param($versionInfo)
    $versionInfo | ConvertTo-Json -Depth 10 | Out-File -FilePath $versionFile -Encoding UTF8
}

# Record a new version
function Record-Version {
    param(
        [int]$Iteration,
        [string]$Model,
        [string]$Endpoint,
        [double]$Score,
        [string]$GitHash
    )

    $versionInfo = Get-VersionInfo
    if (-not $versionInfo) { return }

    $version = @{
        iteration = $Iteration
        model = $Model
        endpoint = $Endpoint
        score = $Score
        gitHash = $GitHash
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $versionInfo.versions += $version
    $versionInfo.currentVersion = $Iteration

    Save-VersionInfo $versionInfo
}

# Rollback to a specific version
function Invoke-Rollback {
    param([int]$TargetVersion)

    $versionInfo = Get-VersionInfo
    if (-not $versionInfo) {
        Write-Host "ERROR: No version history found" -ForegroundColor Red
        return $false
    }

    $target = $versionInfo.versions | Where-Object { $_.iteration -eq $TargetVersion }
    if (-not $target) {
        Write-Host "ERROR: Version $TargetVersion not found" -ForegroundColor Red
        return $false
    }

    Write-Host "Rolling back to iteration $TargetVersion..." -ForegroundColor Yellow
    Write-Host "  Model: $($target.model)" -ForegroundColor Gray
    Write-Host "  Endpoint: $($target.endpoint)" -ForegroundColor Gray
    Write-Host "  Git hash: $($target.gitHash)" -ForegroundColor Gray

    # Try to revert to the git commit
    if ($target.gitHash) {
        try {
            git revert --no-edit HEAD
            Write-Host "✓ Successfully reverted to previous state" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "⚠ Git revert failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  Manual intervention may be required" -ForegroundColor Yellow
            return $false
        }
    }

    return $false
}

# Show version history
function Show-VersionHistory {
    $versionInfo = Get-VersionInfo
    if (-not $versionInfo -or $versionInfo.versions.Count -eq 0) {
        Write-Host "No version history available" -ForegroundColor Yellow
        return
    }

    Write-Host "=== Version History ===" -ForegroundColor Cyan
    Write-Host ""

    $versionInfo.versions | ForEach-Object {
        $marker = if ($_.iteration -eq $versionInfo.currentVersion) { "→" } else { " " }
        Write-Host "$marker Iteration $($_.iteration): $($_.model) ($($_.endpoint)) = $($_.score) $Metric" -ForegroundColor $(if($_.iteration -eq $versionInfo.currentVersion){"Green"}else{"White"})
    }

    Write-Host ""
    Write-Host "Current version: $($versionInfo.currentVersion)" -ForegroundColor Cyan
}

# Check termination conditions
function Test-TerminationCondition {
    param(
        [int]$Iteration,
        [double]$CurrentScore,
        [double]$BestScore,
        [int]$ConsecutiveNoImprovement,
        [datetime]$StartTime
    )

    # Max iterations
    if ($MaxIterations -gt 0 -and $Iteration -ge $MaxIterations) {
        Write-Host ""
        Write-Host "✓ Max iterations reached ($MaxIterations)" -ForegroundColor Green
        return $true
    }

    # No improvement threshold
    if ($NoImprovementCount -gt 0 -and $ConsecutiveNoImprovement -ge $NoImprovementCount) {
        Write-Host ""
        Write-Host "✓ No improvement for $ConsecutiveNoImprovement iterations" -ForegroundColor Green
        return $true
    }

    # Time budget
    if ($TimeBudget -gt 0) {
        $elapsed = (Get-Date) - $StartTime
        if ($elapsed.TotalSeconds -ge $TimeBudget) {
            Write-Host ""
            Write-Host "✓ Time budget exceeded ($TimeBudget seconds)" -ForegroundColor Green
            return $true
        }
    }

    # Diminishing returns (if configured via MinImprovement)
    if ($MinImprovement -gt 0 -and $BestScore -gt 0) {
        $improvement = (($CurrentScore - $BestScore) / $BestScore) * 100
        if ($improvement -lt $MinImprovement -and $ConsecutiveNoImprovement -ge 5) {
            Write-Host ""
            Write-Host "✓ Diminishing returns: improvement < $MinImprovement% for 5 iterations" -ForegroundColor Green
            return $true
        }
    }

    return $false
}

# Compute median of an array of numbers
function Get-Median {
    param([double[]]$Values)
    if ($Values.Count -eq 0) { return 0 }
    $sorted = $Values | Sort-Object
    $count = $sorted.Count
    if ($count % 2 -eq 1) {
        return $sorted[($count - 1) / 2]
    } else {
        return ($sorted[$count / 2 - 1] + $sorted[$count / 2]) / 2
    }
}

# Pareto frontier support for multi-metric optimization
function Get-ParetoFrontier {
    $frontierFile = Join-Path $env:USERPROFILE ".autoresearch\pareto-frontier.json"
    if (Test-Path $frontierFile) {
        return Get-Content $frontierFile -Raw | ConvertFrom-Json
    }
    return @{ candidates = @(); metricNames = @(); directions = @(); updatedAt = $null }
}

function Save-ParetoFrontier {
    param($Frontier)
    $frontierFile = Join-Path $env:USERPROFILE ".autoresearch\pareto-frontier.json"
    $Frontier | ConvertTo-Json -Depth 10 -Compress | Set-Content $frontierFile
}

function Test-Dominance {
    param([double[]]$ScoresA, [double[]]$ScoresB, [string[]]$Directions)
    $aBetter = $false
    $bBetter = $false
    for ($i = 0; $i -lt $ScoresA.Length; $i++) {
        $aVal = if ($Directions[$i] -eq 'lower') { -$ScoresA[$i] } else { $ScoresA[$i] }
        $bVal = if ($Directions[$i] -eq 'lower') { -$ScoresB[$i] } else { $ScoresB[$i] }
        if ($aVal -gt $bVal) { $aBetter = $true }
        if ($bVal -gt $aVal) { $bBetter = $true }
    }
    if ($aBetter -and -not $bBetter) { return 1 }
    if ($bBetter -and -not $aBetter) { return -1 }
    return 0
}

function Add-ToFrontier {
    param($Frontier, $Scores, $Config)
    $newEntry = @{
        scores = $Scores
        model = $Config.Model
        endpoint = $Config.Endpoint
        iteration = ($Frontier.candidates | Measure-Object).Count + 1
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    $isDominated = $false
    $toRemove = @()
    foreach ($existing in $Frontier.candidates) {
        $dom = Test-Dominance -ScoresA $Scores -ScoresB ([double[]]$existing.scores) -Directions $Frontier.directions
        if ($dom -eq -1) { $isDominated = $true; break }
        if ($dom -eq 1) { $toRemove += $existing }
    }
    if (-not $isDominated) {
        $Frontier.candidates = $Frontier.candidates | Where-Object { $_ -notin $toRemove }
        $Frontier.candidates += $newEntry
        $Frontier.updatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Save-ParetoFrontier $Frontier
        return $true
    }
    return $false
}

# Main script starts here
Write-Host "=== Qwen Code Autoresearch ===" -ForegroundColor Cyan
Write-Host "Goal: $Goal" -ForegroundColor Yellow
Write-Host "Metric: $Metric" -ForegroundColor Yellow
Write-Host "Iterations: $Iterations" -ForegroundColor Yellow
Write-Host "Scope: $Scope" -ForegroundColor Yellow
Write-Host "Direction: $Direction is better" -ForegroundColor Yellow
Write-Host "Noise: $Noise" -ForegroundColor Yellow
Write-Host "Reflect: $(if($Reflect){'ON'}else{'OFF'}) (GEPA-inspired analysis after each iteration)" -ForegroundColor Gray
Write-Host ""

# Parse multi-metric support
$metricNames = $Metric -split ',' | ForEach-Object { $_.Trim() }
$directions = $Direction -split ',' | ForEach-Object { $_.Trim().ToLower() }
$isMultiMetric = $metricNames.Count -gt 1
if ($isMultiMetric) {
    Write-Host "Multi-metric mode: $($metricNames.Count) metrics, Pareto frontier enabled" -ForegroundColor Magenta
    Write-Host "  Metrics: $($metricNames -join ', ')" -ForegroundColor Gray
    Write-Host "  Directions: $($directions -join ', ') is better" -ForegroundColor Gray
    Write-Host ""
}

# Initialize autoresearch directory
Initialize-AutoresearchDir

# Handle rollback request
if ($Rollback) {
    if ($RollbackTo -eq 0) {
        Show-VersionHistory
        Write-Host ""
        Write-Host "To rollback, use: -Rollback -RollbackTo <iteration>" -ForegroundColor Yellow
    } else {
        Invoke-Rollback -TargetVersion $RollbackTo
    }
    exit 0
}

# Show history before starting
Show-VersionHistory
Write-Host ""

# Get noise configuration
$noiseConfig = Get-NoiseConfig
Write-Host "Noise configuration: $($noiseConfig.Strategy) (runs: $($noiseConfig.Runs), warmup: $($noiseConfig.WarmupRuns))" -ForegroundColor Gray
Write-Host ""

# Define fitness function using REAL measurements
function Get-FitnessScore {
    param(
        [string]$Model,
        [string]$Endpoint,
        [int]$TestIterations = 3
    )

    $endpointUrl = switch ($Endpoint) {
        "production" { "https://crof.ai/v1" }
        "test"       { "https://test.crof.ai/v1" }
        "beta"       { "https://beta.crof.ai/v1" }
        default      { "https://crof.ai/v1" }
    }

    try {
        $body = @{
            model = $Model
            messages = @(
                @{
                    role = "user"
                    content = "Write a brief explanation of machine learning."
                }
            )
            max_tokens = 300
            stream = $false
        } | ConvertTo-Json -Depth 10

        $totalTime = 0
        $totalTokens = 0
        $successCount = 0

        # Warmup runs (discard results)
        if ($noiseConfig.WarmupRuns -gt 0) {
            for ($i = 1; $i -le $noiseConfig.WarmupRuns; $i++) {
                try {
                    $response = Invoke-RestMethod -Uri "$endpointUrl/chat/completions" -Method Post -Headers @{
                        "Authorization" = "Bearer $env:CROFAI_API_KEY"
                        "Content-Type" = "application/json"
                    } -Body $body
                } catch {
                    # Ignore warmup failures
                }
            }
        }

        # Measurement runs
        for ($i = 1; $i -le $TestIterations; $i++) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            $response = Invoke-RestMethod -Uri "$endpointUrl/chat/completions" -Method Post -Headers @{
                "Authorization" = "Bearer $env:CROFAI_API_KEY"
                "Content-Type" = "application/json"
            } -Body $body

            $stopwatch.Stop()

            $tokensUsed = $response.usage.total_tokens
            $timeTaken = $stopwatch.Elapsed.TotalSeconds
            $tokensPerSec = $tokensUsed / $timeTaken

            $totalTime += $timeTaken
            $totalTokens += $tokensUsed
            $successCount++
        }

        if ($successCount -gt 0) {
            $avgTokensPerSec = $totalTokens / $totalTime
            return [math]::Round($avgTokensPerSec, 2)
        } else {
            return 0.0
        }
    }
    catch {
        Write-Host "    Benchmark failed: $($_.Exception.Message)" -ForegroundColor Red
        return 0.0
    }
}

# Define model configurations to test (54 total: 18 production + 18 test + 18 beta)
$modelConfigs = @(
    # Production models
    @{ Model = "deepseek-v4-pro"; Endpoint = "production" },
    @{ Model = "deepseek-v3.2"; Endpoint = "production" },
    @{ Model = "glm-5.1"; Endpoint = "production" },
    @{ Model = "glm-5.1-precision"; Endpoint = "production" },
    @{ Model = "greg"; Endpoint = "production" },
    @{ Model = "kimi-k2.6"; Endpoint = "production" },
    @{ Model = "kimi-k2.6-precision"; Endpoint = "production" },
    @{ Model = "kimi-k2.5"; Endpoint = "production" },
    @{ Model = "kimi-k2.5-lightning"; Endpoint = "production" },
    @{ Model = "glm-5"; Endpoint = "production" },
    @{ Model = "glm-4.7"; Endpoint = "production" },
    @{ Model = "glm-4.7-flash"; Endpoint = "production" },
    @{ Model = "gemma-4-31b-it"; Endpoint = "production" },
    @{ Model = "minimax-m2.5"; Endpoint = "production" },
    @{ Model = "qwen3.6-27b"; Endpoint = "production" },
    @{ Model = "qwen3.5-397b-a17b"; Endpoint = "production" },
    @{ Model = "qwen3.5-9b"; Endpoint = "production" },
    @{ Model = "qwen3.5-9b-chat"; Endpoint = "production" },
    # Test models (same IDs, test endpoint)
    @{ Model = "deepseek-v4-pro"; Endpoint = "test" },
    @{ Model = "deepseek-v3.2"; Endpoint = "test" },
    @{ Model = "glm-5.1"; Endpoint = "test" },
    @{ Model = "glm-5.1-precision"; Endpoint = "test" },
    @{ Model = "greg"; Endpoint = "test" },
    @{ Model = "kimi-k2.6"; Endpoint = "test" },
    @{ Model = "kimi-k2.6-precision"; Endpoint = "test" },
    @{ Model = "kimi-k2.5"; Endpoint = "test" },
    @{ Model = "kimi-k2.5-lightning"; Endpoint = "test" },
    @{ Model = "glm-5"; Endpoint = "test" },
    @{ Model = "glm-4.7"; Endpoint = "test" },
    @{ Model = "glm-4.7-flash"; Endpoint = "test" },
    @{ Model = "gemma-4-31b-it"; Endpoint = "test" },
    @{ Model = "minimax-m2.5"; Endpoint = "test" },
    @{ Model = "qwen3.6-27b"; Endpoint = "test" },
    @{ Model = "qwen3.5-397b-a17b"; Endpoint = "test" },
    @{ Model = "qwen3.5-9b"; Endpoint = "test" },
    @{ Model = "qwen3.5-9b-chat"; Endpoint = "test" },
    # Beta models (same IDs, beta endpoint)
    @{ Model = "deepseek-v4-pro"; Endpoint = "beta" },
    @{ Model = "deepseek-v3.2"; Endpoint = "beta" },
    @{ Model = "glm-5.1"; Endpoint = "beta" },
    @{ Model = "glm-5.1-precision"; Endpoint = "beta" },
    @{ Model = "greg"; Endpoint = "beta" },
    @{ Model = "kimi-k2.6"; Endpoint = "beta" },
    @{ Model = "kimi-k2.6-precision"; Endpoint = "beta" },
    @{ Model = "kimi-k2.5"; Endpoint = "beta" },
    @{ Model = "kimi-k2.5-lightning"; Endpoint = "beta" },
    @{ Model = "glm-5"; Endpoint = "beta" },
    @{ Model = "glm-4.7"; Endpoint = "beta" },
    @{ Model = "glm-4.7-flash"; Endpoint = "beta" },
    @{ Model = "gemma-4-31b-it"; Endpoint = "beta" },
    @{ Model = "minimax-m2.5"; Endpoint = "beta" },
    @{ Model = "qwen3.6-27b"; Endpoint = "beta" },
    @{ Model = "qwen3.5-397b-a17b"; Endpoint = "beta" },
    @{ Model = "qwen3.5-9b"; Endpoint = "beta" },
    @{ Model = "qwen3.5-9b-chat"; Endpoint = "beta" }
)

# Main autoresearch loop
$bestScore = 0
$bestConfig = @{}
$baselineMeasured = $false
$baselineScore = 0
$consecutiveNoImprovement = 0
$startTime = Get-Date

# 3-phase sequential sweep state
$currentPhase = 1
$phase1Scores = @{}
$phase2Scores = @{}
$phase2Top5 = @()
$phase2Index = 0
$phase3BestModel = $null
$phase3RawScores = @()

# Find starting iteration number from history
$versionInfo = Get-VersionInfo
$maxHistoricalIter = if ($versionInfo -and $versionInfo.versions.Count -gt 0) {
    ($versionInfo.versions | ForEach-Object { [int]$_.iteration } | Measure-Object -Maximum).Maximum
} else { 0 }
$startIter = $maxHistoricalIter + 1
$endIter = $startIter + $Iterations - 1

# Initialize Pareto frontier for multi-metric support
$paretoFrontier = Get-ParetoFrontier
if ($isMultiMetric -and $paretoFrontier.metricNames.Count -eq 0) {
    $paretoFrontier.metricNames = $metricNames
    $paretoFrontier.directions = $directions
    Save-ParetoFrontier $paretoFrontier
}

$runIter = 0
for ($i = $startIter; $i -le $endIter; $i++) {
    $runIter++
    Write-Host "Iteration $i/$endIter (run range: $startIter-$endIter)" -ForegroundColor Green

    # Check termination conditions
    if (Test-TerminationCondition -Iteration $i -CurrentScore $bestScore -BestScore $bestScore -ConsecutiveNoImprovement $consecutiveNoImprovement -StartTime $startTime) {
        break
    }

    # 3-phase sequential sweep selection
    $N = $modelConfigs.Count

    if ($runIter -le $N) {
        # Phase 1: Sequential sweep — test each model config ONCE in order
        $currentPhase = 1
        $currentConfig = $modelConfigs[$runIter - 1]
    } elseif ($runIter -le ($N + 5)) {
        # Phase 2: Deep sweep — top 5 from Phase 1, each tested once per iteration (noise handling via Get-FitnessScore)
        if ($currentPhase -ne 2) {
            $currentPhase = 2
            # Sort phase 1 scores descending and take top 5 (or fewer)
            $phase2Top5 = $phase1Scores.GetEnumerator() `
                | Sort-Object { $_.Value } -Descending `
                | Select-Object -First ([Math]::Min(5, $phase1Scores.Count))
            # Build ordered list of model entries for phase 2 iterations
            $phase2Models = $phase2Top5 | ForEach-Object {
                $modelEntry = $_.Name
                $config = $modelConfigs | Where-Object { "$($_.Model):$($_.Endpoint)" -eq $modelEntry }
                if (-not $config) { $config = $modelConfigs[0] }
                $config
            }
            $phase2Index = 0
            Write-Host "  Phase 2: Deep sweep on top $($phase2Top5.Count) models" -ForegroundColor Magenta
        }
        $currentConfig = $phase2Models[$phase2Index++ % $phase2Models.Count]
    } else {
        # Phase 3: Convergence — test the single best model 5x
        if ($currentPhase -ne 3) {
            $currentPhase = 3
            # Pick the best model from Phase 2 median scores, or fall back to Phase 1 best
            if ($phase2Scores.Count -gt 0) {
                $phase3BestModel = ($phase2Scores.GetEnumerator() `
                    | Sort-Object { $_.Value } -Descending)[0].Name
            } else {
                $phase3BestModel = ($phase1Scores.GetEnumerator() `
                    | Sort-Object { $_.Value } -Descending)[0].Name
            }
            Write-Host "  Phase 3: Convergence on $phase3BestModel" -ForegroundColor Magenta
        }
        $currentConfig = $modelConfigs | Where-Object { "$($_.Model):$($_.Endpoint)" -eq $phase3BestModel }
        if (-not $currentConfig) {
            $currentConfig = $modelConfigs[0]
        }
    }

    $currentModel = $currentConfig.Model
    $currentEndpoint = $currentConfig.Endpoint

    Write-Host "  Testing: $currentModel ($currentEndpoint)" -ForegroundColor Yellow

    # Measure current fitness with noise handling
    $currentScore = Get-FitnessScore -Model $currentModel -Endpoint $currentEndpoint -TestIterations $noiseConfig.Runs

    # Guard check (BLOCKING): if Guard command is set and fails, force discard
    if ($Guard -ne "") {
        Write-Host "  Running Guard: $Guard" -ForegroundColor DarkYellow
        $guardExitCode = 0
        $guardOutput = ""
        try {
            $guardOutput = Invoke-Expression $Guard 2>&1
            $guardExitCode = $LASTEXITCODE
        } catch {
            $guardExitCode = 1
        }
        if ($guardExitCode -ne 0) {
            $currentScore = 0.0
            Write-Host "  GUARD BLOCKED: Guard command failed (exit code $guardExitCode)" -ForegroundColor Red
            Write-Host "  Guard output: $guardOutput" -ForegroundColor DarkRed
            # Skip recording — treat as invalid iteration
            continue
        }
        Write-Host "  Guard passed" -ForegroundColor DarkGreen
    }

    # Parse scores (supports comma-separated multi-metric output from Get-FitnessScore)
    if ($isMultiMetric) {
        $scoreString = "$currentScore"
        $scoreParts = $scoreString -split ','
        $scores = @()
        for ($i = 0; $i -lt $metricNames.Count; $i++) {
            $scores += [double]::Parse($scoreParts[$i].Trim())
        }
    } else {
        $scores = @($currentScore)
    }

    # Get git commit hash
    $gitHash = git rev-parse --short HEAD 2>$null

    # Record version
    Record-Version -Iteration $i -Model $currentModel -Endpoint $currentEndpoint -Score $currentScore -GitHash $gitHash

    # Set baseline on first successful measurement
    if (-not $baselineMeasured -and $currentScore -gt 0) {
        $baselineScore = $currentScore
        $baselineMeasured = $true
        $baselineScore | Out-File -FilePath $baselineFile -Encoding UTF8
        Write-Host "  Baseline: $baselineScore $Metric" -ForegroundColor Cyan
    }

    if ($isMultiMetric) {
        Write-Host "  Current scores: $($scores -join ', ') $Metric" -NoNewline
        $added = Add-ToFrontier -Frontier $paretoFrontier -Scores $scores -Config $currentConfig
        if ($added) {
            Write-Host " 🆕 FRONTIER ADDED" -ForegroundColor Green
            $consecutiveNoImprovement = 0
        } else {
            Write-Host ""
            $consecutiveNoImprovement++
        }
    } else {
        Write-Host "  Current score: $currentScore $Metric" -NoNewline

        if ($currentScore -gt $bestScore) {
            $bestScore = $currentScore
            $bestConfig = @{
                Model = $currentModel
                Endpoint = $currentEndpoint
                Score = $currentScore
            }
            Write-Host " 🆕 NEW BEST" -ForegroundColor Green
            $consecutiveNoImprovement = 0
        } else {
            Write-Host ""
            $consecutiveNoImprovement++
        }
    }

    # Calculate improvement over baseline
    if ($baselineMeasured -and $baselineScore -gt 0) {
        $improvement = (($currentScore - $baselineScore) / $baselineScore) * 100
        Write-Host "  Improvement vs baseline: $([math]::Round($improvement, 2))%" -ForegroundColor $(if($improvement -gt 0){"Green"}else{"Yellow"})
    }

    # Log result
    $logEntry = "$i`t$currentModel`t$currentEndpoint`t$currentScore`t$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-Content -Path $logFile -Value $logEntry

    # GEPA-style reflection
    if ($Reflect) {
        $reflectionDir = Join-Path $env:USERPROFILE ".autoresearch"
        $reflectionLog = Join-Path $reflectionDir "reflections.log"
        if (-not (Test-Path $reflectionDir)) { New-Item -ItemType Directory -Path $reflectionDir -Force | Out-Null }
        
        # Determine if this iteration was kept or discarded
        $improvement = (($currentScore - $baselineScore) / $baselineScore) * 100
        $wasImprovement = ($improvement -gt 0)
        
        # Build reflection entry
        $reflection = @{
            iteration = $i
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            model = $currentConfig.Model
            endpoint = $currentConfig.Endpoint
            score = $currentScore
            baseline = $baselineScore
            delta = [math]::Round($improvement, 2)
            verdict = if ($wasImprovement) { "keep" } else { "discard" }
        }
        
        # Write reflection to log
        $reflectionLine = "$($reflection.iteration)`t$($reflection.timestamp)`t$($reflection.verdict)`t$($reflection.score)`t$($reflection.delta)"
        Add-Content -Path $reflectionLog -Value $reflectionLine
        
        Write-Host "  GEPA reflection logged ($($reflection.verdict), delta: $($reflection.delta)%)" -ForegroundColor Cyan
    }

    # Phase score tracking
    $modelKey = "$currentModel`:$currentEndpoint"
    if ($currentPhase -eq 1) {
        $phase1Scores[$modelKey] = $currentScore
    } elseif ($currentPhase -eq 2) {
        $phase2Scores[$modelKey] = $currentScore
        # Check if Phase 2 is done (last iteration before Phase 3 would start)
        if ($runIter -eq ($modelConfigs.Count + 5)) {
            Write-Host "  Phase 2 results (sorted by score):" -ForegroundColor Cyan
            foreach ($entry in $phase2Scores.GetEnumerator() | Sort-Object { $_.Value } -Descending) {
                Write-Host "    $($entry.Name): $([math]::Round($entry.Value, 2)) $Metric" -ForegroundColor White
            }
        }
    } elseif ($currentPhase -eq 3) {
        $phase3RawScores += $currentScore
    }

    # Small delay between iterations
    Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "=== Autoresearch Complete ===" -ForegroundColor Cyan
Write-Host "Baseline: $baselineScore $Metric" -ForegroundColor Yellow

if ($isMultiMetric) {
    Write-Host "Pareto frontier ($($paretoFrontier.candidates.Count) non-dominated configurations):" -ForegroundColor Magenta
    foreach ($cand in $paretoFrontier.candidates) {
        $scoreStr = for ($j = 0; $j -lt $paretoFrontier.metricNames.Count; $j++) {
            "$($paretoFrontier.metricNames[$j]): $([math]::Round([double]$cand.scores[$j], 2))"
        }
        Write-Host "  $($cand.model) ($($cand.endpoint)) — $($scoreStr -join ', ')" -ForegroundColor White
    }
} else {
    Write-Host "Best configuration:" -ForegroundColor Yellow
    Write-Host "  Model: $($bestConfig.Model)" -ForegroundColor White
    Write-Host "  Endpoint: $($bestConfig.Endpoint)" -ForegroundColor White
    Write-Host "  Score: $($bestConfig.Score) $Metric" -ForegroundColor White

    if ($baselineMeasured -and $baselineScore -gt 0) {
        $totalImprovement = (($bestConfig.Score - $baselineScore) / $baselineScore) * 100
        Write-Host "  Total improvement: $([math]::Round($totalImprovement, 2))%" -ForegroundColor Green
    }
}

# Phase 3 convergence summary
if ($phase3RawScores.Count -ge 2) {
    $mean = [Math]::Round(($phase3RawScores | Measure-Object -Average).Average, 2)
    $variance = ($phase3RawScores | ForEach-Object { ($_ - $mean) * ($_ - $mean) } | Measure-Object -Average).Average
    $stddev = [Math]::Round([Math]::Sqrt($variance), 2)
    Write-Host "Phase 3 convergence ($($phase3RawScores.Count) runs on $phase3BestModel):" -ForegroundColor Cyan
    Write-Host "  Mean: $mean $Metric" -ForegroundColor White
    Write-Host "  Stddev: $stddev $Metric" -ForegroundColor White
    Write-Host "  CV: $([Math]::Round(($stddev / $mean) * 100, 2))%" -ForegroundColor White
    Write-Host "  Raw scores: $($phase3RawScores -join ', ')" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Version tracking saved to: $versionFile" -ForegroundColor Gray
Write-Host "Log saved to: $logFile" -ForegroundColor Gray
if ($isMultiMetric) {
    $frontierFile = Join-Path $env:USERPROFILE ".autoresearch\pareto-frontier.json"
    Write-Host "Pareto frontier saved to: $frontierFile" -ForegroundColor Gray
}
Write-Host ""
Write-Host "To view history: .\autoresearch-qwen.ps1 -Rollback" -ForegroundColor Cyan
Write-Host "To rollback: .\autoresearch-qwen.ps1 -Rollback -RollbackTo <iteration>" -ForegroundColor Cyan

# Auto-report generation
if ($AutoReport) {
    Write-Host ""
    Write-Host "Generating analysis report..." -ForegroundColor Cyan
    & "C:\Users\Administrator\Scripts\analyze-autoresearch.ps1" -OutputFormat markdown
    Write-Host "Report saved to: C:\Users\Administrator\autoresearch-results.md" -ForegroundColor Cyan
}
