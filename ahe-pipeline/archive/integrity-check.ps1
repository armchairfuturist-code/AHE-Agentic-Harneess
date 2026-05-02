<#
.SYNOPSIS
    Monthly DISM + SFC integrity check with logging.
    Called by the MonthlyIntegrityCheck scheduled task.
#>
$logDir = "C:\Users\Administrator\Scripts\logs"
if (!(Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logDir "integrity-check-$(Get-Date -Format 'yyyy-MM-dd').log"

"[$(Get-Date)] Starting integrity check" | Out-File $logFile
"=== DISM Health Check ===" | Out-File $logFile -Append
& dism /Online /Cleanup-Image /ScanHealth 2>&1 | Out-File $logFile -Append
& dism /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-File $logFile -Append
"=== SFC Scan ===" | Out-File $logFile -Append
& sfc /scannow 2>&1 | Out-File $logFile -Append
"[$(Get-Date)] Complete" | Out-File $logFile -Append
