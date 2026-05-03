<#
.SYNOPSIS
    Security audit snapshot — startup items, firewall, users, updates, BitLocker.
.DESCRIPTION
    Exports a timestamped security report.
#>
param([string]$OutputDir = "$env:USERPROFILE\Documents")

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$reportFile = Join-Path $OutputDir "security-audit-$timestamp.txt"

function Write-Section {
    param([string]$Title)
    "`n$('=' * 60)" | Out-File $reportFile -Append
    "  $Title" | Out-File $reportFile -Append
    "$('=' * 60)" | Out-File $reportFile -Append
}

"SECURITY AUDIT SNAPSHOT — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $reportFile
"Machine: $env:COMPUTERNAME | User: $env:USERNAME" | Out-File $reportFile -Append

# Startup Items
Write-Host "  [1/8] Checking startup items..." -ForegroundColor Gray
Write-Section "STARTUP ITEMS"
"Registry (HKCU\Run):" | Out-File $reportFile -Append
Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue |
    ForEach-Object { $_.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } |
    ForEach-Object { "  $($_.Name) = $($_.Value)" } } | Out-File $reportFile -Append

"Registry (HKLM\Run):" | Out-File $reportFile -Append
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue |
    ForEach-Object { $_.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } |
    ForEach-Object { "  $($_.Name) = $($_.Value)" } } | Out-File $reportFile -Append

"Startup Folder (User):" | Out-File $reportFile -Append
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -ErrorAction SilentlyContinue |
    ForEach-Object { "  $($_.Name)" } | Out-File $reportFile -Append

"Scheduled Tasks (Logon trigger):" | Out-File $reportFile -Append
Get-ScheduledTask | Where-Object { $_.State -ne "Disabled" } | ForEach-Object {
    $task = $_
    $task.Triggers | Where-Object { $_.CimClass.CimClassName -like "*Logon*" } | ForEach-Object {
        "  $($task.TaskName) ($($task.TaskPath))"
    }
} | Out-File $reportFile -Append

# Firewall Rules
Write-Host "  [2/8] Checking firewall rules..." -ForegroundColor Gray
Write-Section "NON-DEFAULT FIREWALL RULES (Inbound Allow)"
Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True |
    Where-Object { $_.Group -notlike "@*" -and $_.Group -notlike "Core Networking*" } |
    Select-Object DisplayName, Profile, @{N='Program';E={
        ($_ | Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue).Program
    }} | Format-Table -AutoSize | Out-String | Out-File $reportFile -Append

# Local Users
Write-Host "  [3/8] Checking user accounts..." -ForegroundColor Gray
Write-Section "LOCAL USER ACCOUNTS & GROUP MEMBERSHIPS"
Get-LocalUser | ForEach-Object {
    $user = $_
    $groups = Get-LocalGroup | ForEach-Object {
        $g = $_
        try {
            $members = Get-LocalGroupMember $g -ErrorAction SilentlyContinue
            if ($members.Name -contains "$env:COMPUTERNAME\$($user.Name)") { $g.Name }
        } catch {}
    }
    "  $($user.Name) | Enabled: $($user.Enabled) | Groups: $($groups -join ', ')"
} | Out-File $reportFile -Append

# Pending Updates
Write-Host "  [4/8] Checking pending updates..." -ForegroundColor Gray
Write-Section "PENDING WINDOWS UPDATES"
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $pending = $searcher.Search("IsInstalled=0")
    if ($pending.Updates.Count -eq 0) {
        "  No pending updates" | Out-File $reportFile -Append
    } else {
        foreach ($u in $pending.Updates) {
            "  $($u.Title)" | Out-File $reportFile -Append
        }
    }
} catch {
    "  Error checking updates: $_" | Out-File $reportFile -Append
}

# BitLocker Status
Write-Host "  [5/8] Checking BitLocker..." -ForegroundColor Gray
Write-Section "BITLOCKER STATUS"
try {
    Get-BitLockerVolume -ErrorAction Stop | ForEach-Object {
        "  Drive $($_.MountPoint) | Status: $($_.VolumeStatus) | Protection: $($_.ProtectionStatus) | Method: $($_.EncryptionMethod)"
    } | Out-File $reportFile -Append
} catch {
    "  BitLocker not available or not configured" | Out-File $reportFile -Append
}

# Defender Status
Write-Host "  [6/8] Checking Windows Defender..." -ForegroundColor Gray
Write-Section "WINDOWS DEFENDER STATUS"
Get-MpComputerStatus -ErrorAction SilentlyContinue |
    Select-Object AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated,
        NISEnabled, IoavProtectionEnabled |
    Format-List | Out-String | Out-File $reportFile -Append

# Open Ports
Write-Host "  [7/8] Checking listening ports..." -ForegroundColor Gray
Write-Section "LISTENING PORTS"
Get-NetTCPConnection -State Listen | Sort-Object LocalPort |
    Select-Object LocalPort, @{N='Process';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
    Format-Table -AutoSize | Out-String | Out-File $reportFile -Append

Write-Host "  [8/8] Writing report..." -ForegroundColor Gray
Write-Host "Security audit saved to: $reportFile" -ForegroundColor Green
