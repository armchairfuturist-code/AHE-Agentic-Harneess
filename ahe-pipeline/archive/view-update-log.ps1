<#
.SYNOPSIS
    Shows the most recent auto-update log with color-coded output.
#>
$LogDir = "C:\Users\Administrator\Scripts\logs"

$latest = Get-ChildItem $LogDir -Filter "auto-update-*.log" -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1

if (!$latest) {
    Write-Host "No auto-update logs found yet." -ForegroundColor Yellow
    Write-Host "Logs will appear after the first auto-update run." -ForegroundColor Gray
    Read-Host "Press Enter to close"
    return
}

Write-Host "=== Latest Auto-Update Log: $($latest.Name) ===" -ForegroundColor Cyan
Write-Host ""

Get-Content $latest.FullName | ForEach-Object {
    $color = "Gray"
    if ($_ -match "\[OK\]")    { $color = "Green"  }
    if ($_ -match "\[WARN\]")  { $color = "Yellow" }
    if ($_ -match "\[ERROR\]") { $color = "Red"    }
    if ($_ -match "═══|───|SUMMARY") { $color = "Cyan" }
    Write-Host $_ -ForegroundColor $color
}

Write-Host ""
Write-Host "── All logs ──" -ForegroundColor DarkGray
Get-ChildItem $LogDir -Filter "auto-update-*.log" | Sort-Object Name -Descending | Select-Object -First 7 |
    ForEach-Object { Write-Host "  $($_.Name)  ($([math]::Round($_.Length/1KB, 1))KB)" -ForegroundColor DarkGray }

Write-Host ""
Read-Host "Press Enter to close"
