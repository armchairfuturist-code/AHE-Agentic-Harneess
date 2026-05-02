<#
.SYNOPSIS
    PC Performance Autoresearch with Pareto frontier optimization.
    Tests system configurations (power plans, services, visual effects)
    against real PC performance metrics (CPU, memory, disk, network, processes).
.EXAMPLE
    .\pc-autoresearch.ps1 -Iterations 20 -Reflect
.EXAMPLE
    .\pc-autoresearch.ps1 -Iterations 10 -WhatIf
#>
param(
    [string]$Goal = "Optimize PC performance across CPU, memory, disk, and network",
    [int]$Iterations = 30,
    [string]$Metric = "cpu_pct,mem_mb,disk_latency_ms,ping_ms,processes",
    [string]$Direction = "lower,lower,lower,lower,lower",
    [string]$Scope = "system config, services, power settings",
    [switch]$WhatIf,
    [switch]$Reflect,
    [switch]$AutoReport,
    [switch]$Pause  # Keep window open after completion (useful when double-clicking)
)

$ErrorActionPreference = 'Continue'
$ScriptsDir = "$env:USERPROFILE\Scripts"

Write-Host "=== PC Performance Autoresearch (Pareto) ===" -ForegroundColor Cyan
Write-Host "Goal: $Goal" -ForegroundColor Yellow
Write-Host "Metric: $Metric" -ForegroundColor Yellow
Write-Host "Direction: $Direction" -ForegroundColor Yellow
Write-Host "Iterations: $Iterations" -ForegroundColor Yellow
Write-Host "Scope: $Scope" -ForegroundColor Yellow

# Check for measurement script
$measureScript = "$ScriptsDir\measure-pc.ps1"
if (-not (Test-Path $measureScript)) {
    Write-Host "ERROR: measure-pc.ps1 not found at $measureScript" -ForegroundColor Red
    exit 1
}

# Power plan GUIDs
$powerPlans = @{
    "Balanced" = "381b4222-f694-41f0-9685-ff5bb260df2e"
    "HighPerf" = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    "Ultimate" = "e9a42b02-d5df-448d-aa00-03f14749eb61"
}

# Service states to toggle
$tweakableServices = @(
    @{ Name = "WSearch"; Label = "Windows Search" },
    @{ Name = "SysMain"; Label = "SysMain (Superfetch)" }
)

$bestScore = 0
$bestConfig = ""
$baselineScore = 0
$baselineMeasured = $false
$consecutiveNoImprovement = 0
$startTime = Get-Date
$paretoFrontier = @{ candidates = @(); metricNames = @(); directions = @() }

# Parse metrics
$metricNames = $Metric -split ',' | ForEach-Object { $_.Trim() }
$directions = $Direction -split ',' | ForEach-Object { $_.Trim().ToLower() }
$isMultiMetric = $metricNames.Count -gt 1

if ($isMultiMetric) {
    $paretoFrontier.metricNames = $metricNames
    $paretoFrontier.directions = $directions
    Write-Host "  Pareto multi-metric mode ($($metricNames.Count) metrics)" -ForegroundColor Magenta
}

# Import Pareto functions from main harness
function Test-Dominance {
    param([double[]]$ScoresA, [double[]]$ScoresB, [string[]]$LocalDirections)
    $aBetter = $false; $bBetter = $false
    for ($i = 0; $i -lt $ScoresA.Length; $i++) {
        $aVal = if ($LocalDirections[$i] -eq 'lower') { -$ScoresA[$i] } else { $ScoresA[$i] }
        $bVal = if ($LocalDirections[$i] -eq 'lower') { -$ScoresB[$i] } else { $ScoresB[$i] }
        if ($aVal -gt $bVal) { $aBetter = $true }
        if ($bVal -gt $aVal) { $bBetter = $true }
    }
    if ($aBetter -and -not $bBetter) { return 1 }
    if ($bBetter -and -not $aBetter) { return -1 }
    return 0
}

function Get-PCSnapshot {
    # Measure current PC state
    $result = & $measureScript -Quiet
    $parts = $result -split ','
    if ($parts.Count -ge 5) {
        return @{ 
            cpu = [double]::Parse($parts[0].Trim())
            mem = [double]::Parse($parts[1].Trim())
            disk = [double]::Parse($parts[2].Trim())
            ping = [double]::Parse($parts[3].Trim())
            procs = [int]::Parse($parts[4].Trim())
        }
    }
    return $null
}

# Generate a random config change
function New-ConfigChange {
    $change = @{}
    $choice = Get-Random -Minimum 0 -Maximum 3
    switch ($choice) {
        0 { # Power plan
            $plans = @('Balanced', 'HighPerf', 'Ultimate')
            $change.Type = "power_plan"
            $change.Value = $plans | Get-Random
            $change.Description = "Power plan: $($change.Value)"
        }
        1 { # Toggle a service
            $svc = $tweakableServices | Get-Random
            $current = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($current.Status -eq 'Running') { $change.Value = 'Stop'; $change.Description = "Stop $($svc.Label)" }
            else { $change.Value = 'Start'; $change.Description = "Start $($svc.Label)" }
            $change.Type = "service"
            $change.ServiceName = $svc.Name
        }
        2 { # Do nothing (control measurement)
            $change.Type = "none"
            $change.Value = "measure"
            $change.Description = "Control measurement (no change)"
        }
    }
    return $change
}

# Apply a config change
function Apply-ConfigChange {
    param($Change)
    if ($WhatIf) { Write-Host "    Would: $($Change.Description)" -ForegroundColor DarkGray; return }
    switch ($Change.Type) {
        "power_plan" { powercfg /setactive $powerPlans[$Change.Value] | Out-Null }
        "service" {
            if ($Change.Value -eq 'Stop') { Stop-Service -Name $Change.ServiceName -Force -ErrorAction SilentlyContinue; Set-Service -Name $Change.ServiceName -StartupType Disabled -ErrorAction SilentlyContinue }
            else { Set-Service -Name $Change.ServiceName -StartupType Manual -ErrorAction SilentlyContinue; Start-Service -Name $Change.ServiceName -ErrorAction SilentlyContinue }
        }
    }
}

# Main loop
for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host "`nIteration $i/$Iterations" -ForegroundColor Green
    
    # Generate and apply change
    $change = New-ConfigChange
    Write-Host "  Config: $($change.Description)" -ForegroundColor Yellow
    Apply-ConfigChange $change
    
    if ($change.Type -ne "none") { Start-Sleep -Seconds 2 } # Wait for change to take effect
    
    # Measure
    $snapshot = Get-PCSnapshot
    if (-not $snapshot) { Write-Host "  ⚠ Measurement failed" -ForegroundColor Yellow; continue }
    
    Write-Host "  CPU: $($snapshot.cpu)% | Mem: $($snapshot.mem)MB | Disk: $($snapshot.disk)ms | Ping: $($snapshot.ping)ms | Procs: $($snapshot.procs)" -ForegroundColor Gray
    
    # Build scores array
    $scores = @($snapshot.cpu, $snapshot.mem, $snapshot.disk, $snapshot.ping, $snapshot.procs)
    
    # Compute overall score (lower is better for all metrics)
    $overallScore = $snapshot.cpu + ($snapshot.mem / 100) + $snapshot.disk + $snapshot.ping + ($snapshot.procs / 10)
    
    if (-not $baselineMeasured) {
        $baselineScore = $overallScore
        $baselineMeasured = $true
        Write-Host "  Baseline score: $([math]::Round($baselineScore, 1))" -ForegroundColor Cyan
    }
    
    # Pareto or single-track
    if ($isMultiMetric) {
        $frontierCandidates = [System.Collections.ArrayList]@($paretoFrontier.candidates)
        $isDominated = $false
        $toRemove = @()
        $newEntry = [PSCustomObject]@{
            scores = [double[]]@($scores[0], $scores[1], $scores[2], $scores[3], $scores[4])
            iteration = $i
            config = $change.Description
            timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        foreach ($existing in $frontierCandidates) {
            $dom = Test-Dominance -ScoresA $scores -ScoresB ([double[]]$existing.scores) -LocalDirections $directions
            if ($dom -eq -1) { $isDominated = $true; break }
            if ($dom -eq 1) { $toRemove += $existing }
        }
        
        if (-not $isDominated) {
            foreach ($remove in $toRemove) { $frontierCandidates.Remove($remove) }
            $frontierCandidates.Add($newEntry) | Out-Null
            $paretoFrontier.candidates = $frontierCandidates
            Write-Host "  🏁 PARETO FRONTIER ADDED" -ForegroundColor Cyan
            $consecutiveNoImprovement = 0
        } else {
            Write-Host "  (dominated — not added to frontier)" -ForegroundColor DarkYellow
            $consecutiveNoImprovement++
        }
    } else {
        if ($overallScore -lt $bestScore -or $bestScore -eq 0) {
            $bestScore = $overallScore
            $bestConfig = $change.Description
            Write-Host "  🆕 NEW BEST: $([math]::Round($overallScore, 1))" -ForegroundColor Green
            $consecutiveNoImprovement = 0
        } else {
            Write-Host "  Score: $([math]::Round($overallScore, 1)) (best: $([math]::Round($bestScore, 1)))" -ForegroundColor Gray
            $consecutiveNoImprovement++
        }
    }
    
    if ($Reflect) {
        $improvement = (($baselineScore - $overallScore) / $baselineScore) * 100
        Write-Host "  💡 Reflection: delta $([math]::Round($improvement, 1))%" -ForegroundColor Cyan
    }
    
    # Termination
    if ($consecutiveNoImprovement -ge 10) {
        Write-Host "`n✓ No improvement for 10 iterations — stopping early" -ForegroundColor Green
        break
    }
}

# Report
Write-Host "`n=== PC Performance Autoresearch Complete ===" -ForegroundColor Cyan

if ($isMultiMetric) {
    $frontierCount = @($paretoFrontier.candidates).Count
    Write-Host "`nPareto Frontier ($frontierCount non-dominated configurations):" -ForegroundColor Cyan
    foreach ($c in @($paretoFrontier.candidates)) {
        Write-Host "  $($c.config)" -ForegroundColor White
        Write-Host "    Iteration $($c.iteration): CPU $($c.scores[0])% | Mem $($c.scores[1])MB | Disk $($c.scores[2])ms | Ping $($c.scores[3])ms | Procs $($c.scores[4])" -ForegroundColor Gray
    }
    $frontierFile = "$env:USERPROFILE\.autoresearch\pc-pareto-frontier.json"
    $paretoFrontier | ConvertTo-Json -Depth 10 -Compress | Set-Content $frontierFile
    Write-Host "Frontier saved to: $frontierFile" -ForegroundColor Gray
} else {
    Write-Host "Best config: $bestConfig (score: $([math]::Round($bestScore, 1)))" -ForegroundColor Yellow
}

Write-Host "`nTo re-run: .\pc-autoresearch.ps1 -Iterations $Iterations -Reflect" -ForegroundColor Cyan

if ($Pause) {
    Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
    Read-Host | Out-Null
}
