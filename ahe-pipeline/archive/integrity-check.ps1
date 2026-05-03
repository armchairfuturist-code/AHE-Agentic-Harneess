<#
.SYNOPSIS
    DISM + SFC integrity check with progress and Quick mode.
#>
param([switch]$Quick)

$logDir = "C:\Users\Administrator\Scripts\logs"
if (!(Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logDir ("integrity-check-" + (Get-Date -Format "yyyy-MM-dd") + ".log")

Write-Host "  === Integrity Check ===" -ForegroundColor Cyan
if ($Quick) { Write-Host "  QUICK MODE: DISM scan only (~30s)" -ForegroundColor Yellow } else { Write-Host "  FULL MODE: DISM + SFC (5-10 min)" -ForegroundColor Yellow }

"[" + (Get-Date) + "] Starting" | Out-File $logFile

Write-Host "  [1/3] DISM /ScanHealth..." -ForegroundColor Gray
& dism /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File $logFile -Append

if (-not $Quick) {
    Write-Host "  [2/3] DISM /RestoreHealth..." -ForegroundColor Gray
    & dism /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-File $logFile -Append
} else { Write-Host "  SKIP: DISM restore" -ForegroundColor Gray }

if (-not $Quick) {
    Write-Host "  [3/3] SFC /scannow..." -ForegroundColor Gray
    & sfc /scannow 2>&1 | Out-File $logFile -Append
} else { Write-Host "  SKIP: SFC" -ForegroundColor Gray }

Write-Host "  Log: $logFile" -ForegroundColor Green
