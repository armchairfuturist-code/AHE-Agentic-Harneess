<#
.SYNOPSIS
    Measure real PC performance metrics for Pareto-optimized autoresearch.
    Outputs comma-separated values for use with pc-autoresearch.ps1.
.NOTES
    This script is AUTO-CALLED by pc-autoresearch.ps1. You do NOT need to
    run it manually unless you want to take a quick PC performance snapshot.

    Workflow:
      1. Run pc-autoresearch.ps1 (which calls this internally)
      2. Review Pareto frontier results
      3. Apply winning config

    Standalone usage for quick check:
      .\measure-pc.ps1
      # Output: 12.5,8192,5.3,10.7,351
      #        (cpu%, mem_mb, disk_latency_ms, ping_ms, processes)
.EXAMPLE
    .\pc-autoresearch.ps1 -Iterations 50 -Reflect
    # Recommended: Run this instead of using measure-pc.ps1 directly
#>
param([switch]$Benchmark, [switch]$Quiet)

$ErrorActionPreference = 'SilentlyContinue'
$samples = if ($Benchmark) { 5 } else { 3 }

if (-not $Quiet) { Write-Host "Measuring PC performance ($samples samples)..." -ForegroundColor Cyan }

# 1. CPU load (average across samples)
$cpuScores = @()
for ($i = 0; $i -lt $samples; $i++) {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $cpuScores += $cpu | Measure-Object -Property LoadPercentage -Average | ForEach-Object { [math]::Round($_.Average, 1) }
    if ($i -lt $samples - 1) { Start-Sleep -Milliseconds 500 }
}
$cpuAvg = if ($cpuScores.Count -gt 0) { ($cpuScores | Measure-Object -Average).Average } else { 50 }
$cpuVal = [math]::Round($cpuAvg, 1)
if (-not $Quiet) { Write-Host "  CPU load: $cpuVal%" -ForegroundColor Gray }

# 2. Memory usage (MB)
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($os) {
    $totalMem = [math]::Round($os.TotalVisibleMemorySize / 1024, 0)
    $freeMem = [math]::Round($os.FreePhysicalMemory / 1024, 0)
    $usedMem = $totalMem - $freeMem
} else {
    $usedMem = 8192; $totalMem = 16384
}
if (-not $Quiet) { Write-Host "  Memory: ${usedMem}MB / ${totalMem}MB used" -ForegroundColor Gray }

# 3. Disk latency (ms) — sample performance counter
$diskScores = @()
for ($i = 0; $i -lt $samples; $i++) {
    try {
        $disk = Get-Counter '\PhysicalDisk(*)\Avg. Disk sec/Read' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty CounterSamples
        $diskScores += $disk | Where-Object { $_.Status -eq 0 } | Select-Object -First 1 | ForEach-Object { [math]::Round($_.CookedValue * 1000, 1) }
    } catch { $diskScores += 5 }
    if ($i -lt $samples - 1) { Start-Sleep -Milliseconds 300 }
}
$diskVal = if ($diskScores.Count -gt 0) { ($diskScores | Where-Object { $_ -gt 0 } | Measure-Object -Average).Average } else { 5 }
$diskVal = [math]::Round($diskVal, 1)
if (-not $Quiet) { Write-Host "  Disk latency: ${diskVal}ms" -ForegroundColor Gray }

# 4. Network latency (ms) — ping to cloudflare
$pingScores = @()
for ($i = 0; $i -lt $samples; $i++) {
    $ping = Test-Connection -ComputerName '1.1.1.1' -Count 1 -ErrorAction SilentlyContinue
    $pingScores += $ping | ForEach-Object { $_.ResponseTime }
    if ($i -lt $samples - 1) { Start-Sleep -Milliseconds 200 }
}
$pingVal = if ($pingScores.Count -gt 0) { ($pingScores | Where-Object { $_ -gt 0 } | Measure-Object -Average).Average } else { 20 }
$pingVal = [math]::Round($pingVal, 1)
if (-not $Quiet) { Write-Host "  Network latency: ${pingVal}ms" -ForegroundColor Gray }

# 5. Process count (simple system load indicator)
$procCount = (Get-Process).Count
if (-not $Quiet) { Write-Host "  Running processes: $procCount" -ForegroundColor Gray }

# Output comma-separated values
"$cpuVal,$usedMem,$diskVal,$pingVal,$procCount"
