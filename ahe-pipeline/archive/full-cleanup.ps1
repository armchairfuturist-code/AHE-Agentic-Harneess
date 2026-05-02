<#
.SYNOPSIS
    Full system cleanup — temp files, update cache, recycle bin, DISM cleanup.
.PARAMETER IncludeBrowserCache
    Also clear browser caches (Edge, Chrome, Thorium).
.PARAMETER WhatIf
    Show what would be cleaned without deleting.
#>
#Requires -RunAsAdministrator
param(
    [switch]$IncludeBrowserCache,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'
$totalFreed = 0

function Remove-PathContents {
    param([string]$Path, [string]$Label)
    if (!(Test-Path $Path)) { Write-Host "  SKIP: $Label (not found)" -ForegroundColor DarkGray; return 0 }
    $items = Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue
    $size  = ($items | Where-Object { !$_.PSIsContainer } | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $sizeMB = [math]::Round($size / 1MB, 1)
    if ($WhatIf) {
        Write-Host "  WOULD CLEAN: $Label — ${sizeMB}MB" -ForegroundColor Yellow
    } else {
        Remove-Item "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  CLEANED: $Label — ${sizeMB}MB freed" -ForegroundColor Green
    }
    return $size
}

Write-Host "=== FULL SYSTEM CLEANUP ===" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "(DRY RUN — no files will be deleted)" -ForegroundColor Yellow }

$totalFreed += Remove-PathContents $env:TEMP "User temp files"
$totalFreed += Remove-PathContents "C:\Windows\Temp" "System temp files"
$totalFreed += Remove-PathContents "C:\Windows\SoftwareDistribution\Download" "Windows Update cache"
$totalFreed += Remove-PathContents "C:\Windows\Logs\CBS" "CBS Logs"

# Recycle Bin
if (!$WhatIf) {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "  CLEANED: Recycle Bin" -ForegroundColor Green
} else {
    Write-Host "  WOULD CLEAN: Recycle Bin" -ForegroundColor Yellow
}

# Browser cache (optional)
if ($IncludeBrowserCache) {
    $browserPaths = @(
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\Cache_Data"; Name = "Edge" },
        @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\Cache_Data"; Name = "Chrome" },
        @{ Path = "$env:LOCALAPPDATA\Thorium\User Data\Default\Cache\Cache_Data"; Name = "Thorium" }
    )
    foreach ($bp in $browserPaths) {
        $totalFreed += Remove-PathContents $bp.Path "$($bp.Name) browser cache"
    }
}

# DISM component store cleanup
if (!$WhatIf) {
    Write-Host "  Running DISM component cleanup..." -ForegroundColor Gray
    & dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
    Write-Host "  CLEANED: DISM component store" -ForegroundColor Green
} else {
    Write-Host "  WOULD CLEAN: DISM component store" -ForegroundColor Yellow
}

$totalMB = [math]::Round($totalFreed / 1MB, 1)
$totalGB = [math]::Round($totalFreed / 1GB, 2)
Write-Host "`n=== TOTAL: ${totalMB}MB (${totalGB}GB) $(if($WhatIf){'would be'} else {'freed'}) ===" -ForegroundColor Cyan
