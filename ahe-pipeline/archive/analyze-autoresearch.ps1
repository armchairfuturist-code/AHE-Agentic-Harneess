# Analyze and visualize autoresearch results
# Reads autoresearch-log.tsv and generates insights

param(
    [string]$LogFile = "C:\Users\Administrator\autoresearch-log.tsv",
    [string]$OutputFormat = "console"  # console, html, markdown
)

$ErrorActionPreference = "Stop"

# Check if log file exists
if (-not (Test-Path $LogFile)) {
    Write-Host "ERROR: Log file not found at $LogFile" -ForegroundColor Red
    exit 1
}

# Read log file - optimized with ReadCount 0 for single batch read
$lines = Get-Content $LogFile -ReadCount 0

if ($lines.Count -eq 0) {
    Write-Host "WARNING: Log file is empty" -ForegroundColor Yellow
    exit 0
}

Write-Host "=== Autoresearch Results Analysis ===" -ForegroundColor Cyan
Write-Host "Total entries: $($lines.Count)" -ForegroundColor Yellow
Write-Host ""

# Parse log entries - handle both formats
$logData = New-Object System.Collections.Generic.List[PSObject]

foreach ($line in $lines) {
    $parts = $line -split "`t"
    
    if ($parts.Count -ge 4) {
        # Format: iteration, model, [endpoint], score, timestamp
        $iteration = $parts[0]
        $model = $parts[1]
        
        # Check if this is old format (no endpoint) or new format (with endpoint)
        # Old: iteration, model, score, timestamp (4 parts)
        # New: iteration, model, endpoint, score, timestamp (5 parts)
        if ($parts.Count -eq 4) {
            # Old format - no endpoint
            $endpoint = "unknown"
            $score = $parts[2]
            $timestamp = $parts[3]
        } else {
            # New format - has endpoint
            $endpoint = $parts[2]
            $score = $parts[3]
            $timestamp = $parts[4]
        }
        
        $logData.Add([PSCustomObject]@{
            Iteration = $iteration
            Model = $model
            Endpoint = $endpoint
            Score = [double]$score
            Timestamp = $timestamp
        })
    }
}

if ($logData.Count -eq 0) {
    Write-Host "WARNING: No valid log entries found" -ForegroundColor Yellow
    exit 0
}

# Group by model and endpoint
$grouped = $logData | Group-Object -Property Model, Endpoint

Write-Host "=== Performance by Model/Endpoint ===" -ForegroundColor Cyan
Write-Host ""

$summary = @()

foreach ($g in $grouped) {
    $scores = $g.Group | ForEach-Object { $_.Score }
    $avgScore = ($scores | Measure-Object -Average).Average
    $maxScore = ($scores | Measure-Object -Maximum).Maximum
    $minScore = ($scores | Measure-Object -Minimum).Minimum
    $count = $scores.Count

    # Handle group name - it's a string like "Model, Endpoint"
    $groupParts = $g.Name -split ', '
    $model = if ($groupParts.Count -ge 1) { $groupParts[0].Trim() } else { "Unknown" }
    $endpoint = if ($groupParts.Count -ge 2) { $groupParts[1].Trim() } else { "Unknown" }

    $summary += [PSCustomObject]@{
        Model = $model
        Endpoint = $endpoint
        Average = [math]::Round($avgScore, 2)
        Max = [math]::Round($maxScore, 2)
        Min = [math]::Round($minScore, 2)
        Count = $count
    }
}

# Sort by average score (descending)
$summary = $summary | Sort-Object Average -Descending

# Display summary table
$summary | Format-Table -AutoSize

# Find best configuration
$best = $summary | Select-Object -First 1
Write-Host ""
Write-Host "=== Best Configuration ===" -ForegroundColor Cyan
Write-Host "Model: $($best.Model)" -ForegroundColor Yellow
Write-Host "Endpoint: $($best.Endpoint)" -ForegroundColor Yellow
Write-Host "Average Score: $($best.Average) tokens/sec" -ForegroundColor Green
Write-Host "Max Score: $($best.Max) tokens/sec" -ForegroundColor Green
Write-Host "Min Score: $($best.Min) tokens/sec" -ForegroundColor Yellow
Write-Host "Test Count: $($best.Count)" -ForegroundColor Gray

# Compare production vs test
$productionAvg = ($summary | Where-Object { $_.Endpoint -eq "production" } | Measure-Object -Property Average -Average).Average
$testAvg = ($summary | Where-Object { $_.Endpoint -eq "test" } | Measure-Object -Property Average -Average).Average

if ($productionAvg -and $testAvg) {
    $diff = $testAvg - $productionAvg
    $diffPercent = ($diff / $productionAvg) * 100

    Write-Host ""
    Write-Host "=== Production vs Test Comparison ===" -ForegroundColor Cyan
    Write-Host "Production average: $([math]::Round($productionAvg, 2)) tokens/sec" -ForegroundColor Yellow
    Write-Host "Test average: $([math]::Round($testAvg, 2)) tokens/sec" -ForegroundColor Yellow

    if ($diffPercent -gt 5) {
        Write-Host "Test is $([math]::Round($diffPercent, 1))% faster" -ForegroundColor Green
    } elseif ($diffPercent -lt -5) {
        Write-Host "Test is $([math]::Round([math]::Abs($diffPercent), 1))% slower" -ForegroundColor Red
    } else {
        Write-Host "Similar performance ($([math]::Round($diffPercent, 1))% difference)" -ForegroundColor Yellow
    }
}

# Generate ASCII chart
Write-Host ""
Write-Host "=== Performance Chart (ASCII) ===" -ForegroundColor Cyan
Write-Host ""

$maxScore = ($summary | Measure-Object -Property Average -Maximum).Maximum
$minScore = ($summary | Measure-Object -Property Average -Minimum).Minimum
$range = $maxScore - $minScore

foreach ($item in $summary | Select-Object -First 10) {
    $barLength = if ($range -gt 0) { [math]::Round((($item.Average - $minScore) / $range) * 50) } else { 0 }
    $bar = "█" * $barLength
    $label = "$($item.Model) ($($item.Endpoint))".PadRight(35)
    Write-Host "$label $bar $($item.Average)" -ForegroundColor $(if($item -eq $best){"Green"}else{"White"})
}

# Generate markdown report
if ($OutputFormat -eq "markdown") {
    $markdown = @"
# Autoresearch Results Analysis

## Summary
- **Total iterations**: $($logData.Count)
- **Best configuration**: $($best.Model) on $($best.Endpoint)
- **Best average score**: $($best.Average) tokens/sec

## Performance by Model/Endpoint

| Model | Endpoint | Average | Max | Min | Count |
|-------|----------|---------|-----|-----|-------|
"@

    foreach ($item in $summary) {
        $markdown += "| $($item.Model) | $($item.Endpoint) | $($item.Average) | $($item.Max) | $($item.Min) | $($item.Count) |`n"
    }

    $markdown += @"

## Best Configuration Details

- **Model**: $($best.Model)
- **Endpoint**: $($best.Endpoint)
- **Average Score**: $($best.Average) tokens/sec
- **Max Score**: $($best.Max) tokens/sec
- **Min Score**: $($best.Min) tokens/sec
- **Test Count**: $($best.Count)

## Recommendations

1. Use **$($best.Model)** on **$($best.Endpoint)** for maximum performance
2. Consider testing additional model variations
3. Monitor for model updates that may improve performance

---
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

    $markdownFile = "C:\Users\Administrator\autoresearch-results.md"
    $markdown | Out-File -FilePath $markdownFile -Encoding UTF8
    Write-Host ""
    Write-Host "Markdown report saved to: $markdownFile" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Analysis complete!" -ForegroundColor Green
