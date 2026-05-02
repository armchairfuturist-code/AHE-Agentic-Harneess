<#
.SYNOPSIS
    Full system verification — tasks, services, scripts, network, sync, firewall, updates, health.
.DESCRIPTION
    Comprehensive system check covering:
    - Scheduled tasks status verification
    - Key services status
    - Syncthing sync status
    - PnP devices with issues
    - DNS/Network configuration
    - Rclone configuration
    - Custom firewall rules
    - Script file verification
    - Windows Update status
    - Disk health and space
    - RAM usage and top consumers
    - CPU information
    - Event log errors (last 24h)
    - System uptime
.PARAMETER LogFile
    Optional path to write report. Defaults to console only.
.EXAMPLE
    .\full-system-check.ps1
    .\full-system-check.ps1 -LogFile "C:\Logs\system-check.log"
#>
param(
    [string]$LogFile
)

$ErrorActionPreference = 'Continue'

function Write-Report {
    param(
        [string]$Text,
        [ConsoleColor]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
    if ($LogFile) { $Text | Out-File $LogFile -Append -Encoding UTF8 }
}

$divider = "=" * 70

Write-Report $divider "Cyan"
Write-Report "  FULL SYSTEM CHECK — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Cyan"
Write-Report $divider "Cyan"

# ============================================================================
# SCHEDULED TASKS
# ============================================================================
Write-Report "`n--- SCHEDULED TASKS ---" "Yellow"

$tasks = @(
    'AutoUpdateSystem',
    'BiWeeklyRestorePoint',
    'MonthlyIntegrityCheck',
    'AutoUpdateNotify'
)

foreach ($t in $tasks) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($task) {
        $info = Get-ScheduledTaskInfo -TaskName $t -ErrorAction SilentlyContinue
        $resultCode = $info.LastTaskResult
        $resultText = switch ($resultCode) {
            0       { "Success" }
            267009  { "Running" }
            267011  { "Never ran" }
            2147946720 { "ERROR: Invalid task value" }
            default { "Code $resultCode" }
        }
        $color = if ($resultCode -eq 0 -or $resultCode -eq 267009) { "Green" } 
                 elseif ($resultCode -eq 267011) { "Yellow" } 
                 else { "Red" }
        Write-Report ("  {0}: State={1}, LastRun={2}, Result={3}, NextRun={4}" -f `
            $t, $task.State, $info.LastRunTime, $resultText, $info.NextRunTime) $color
        
        # Additional context for errors
        if ($resultCode -eq 2147946720) {
            Write-Report "    -> Task XML may have invalid values or needs recreation" "DarkYellow"
        }
    } else {
        Write-Report "  $t — NOT FOUND" "Red"
    }
}

# ============================================================================
# KEY SERVICES
# ============================================================================
Write-Report "`n--- KEY SERVICES ---" "Yellow"

$services = @(
    @{ Name = 'WinDefend'; Expect = 'Running'; Desc = 'Windows Defender' },
    @{ Name = 'SecurityHealthService'; Expect = 'Running'; Desc = 'Windows Security Service' },
    @{ Name = 'Schedule'; Expect = 'Running'; Desc = 'Task Scheduler' },
    @{ Name = 'Dnscache'; Expect = 'Running'; Desc = 'DNS Client' },
    @{ Name = 'vmms'; Expect = 'Running'; Desc = 'Hyper-V VM Management' },
    @{ Name = 'WSLService'; Expect = 'Running'; Desc = 'WSL Service' },
    @{ Name = 'SysMain'; Expect = 'Stopped'; Desc = 'Superfetch (should be stopped/disabled)' },
    @{ Name = 'DiagTrack'; Expect = 'Stopped'; Desc = 'Telemetry (should be stopped)' },
    @{ Name = 'WSearch'; Expect = 'Stopped'; Desc = 'Windows Search (manual)' }
)

foreach ($s in $services) {
    $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
    if ($svc) {
        $statusOk = $svc.Status -eq $s.Expect
        $color = if ($statusOk) { "Green" } else { "Yellow" }
        Write-Report ("  {0} ({1}): Status={2}, StartType={3}" -f `
            $svc.Name, $s.Desc, $svc.Status, $svc.StartType) $color
        
        if (-not $statusOk) {
            $expectedText = if ($s.Expect -eq 'Stopped') { "should be stopped" } else { "should be running" }
            Write-Report "    -> Expected: $expectedText" "DarkYellow"
        }
    } else {
        Write-Report ("  {0} ({1}): NOT FOUND" -f $s.Name, $s.Desc) "Red"
    }
}

# ============================================================================
# SYNCTHING
# ============================================================================
Write-Report "`n--- SYNCTHING ---" "Yellow"

try {
    $configPath = "$env:LOCALAPPDATA\Syncthing\config.xml"
    if (Test-Path $configPath) {
        $apiKey = (Select-Xml -Path $configPath -XPath '//apikey').Node.InnerText
        $headers = @{ 'X-API-Key' = $apiKey }
        
        $st = Invoke-RestMethod -Uri 'http://127.0.0.1:8384/rest/system/status' -Headers $headers -TimeoutSec 5
        Write-Report ("  Running, uptime: {0}h" -f [math]::Round($st.uptime/3600,1)) "Green"
        
        $conn = Invoke-RestMethod -Uri 'http://127.0.0.1:8384/rest/system/connections' -Headers $headers -TimeoutSec 5
        foreach ($prop in $conn.connections.PSObject.Properties) {
            $c = if ($prop.Value.connected) { "Connected" } else { "Disconnected" }
            $color = if ($prop.Value.connected) { "Green" } else { "Yellow" }
            Write-Report ("  Peer {0}: {1}" -f $prop.Name.Substring(0,[Math]::Min(7,$prop.Name.Length)), $c) $color
        }
        
        # Check folder status
        $folders = Invoke-RestMethod -Uri 'http://127.0.0.1:8384/rest/db/status?folder=qvxcr-jnxac' -Headers $headers -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($folders) {
            $fColor = if ($folders.state -eq 'idle' -and $folders.needFiles -eq 0) { "Green" } else { "Yellow" }
            Write-Report ("  Vault: state={0}, files={1}, needFiles={2}, errors={3}" -f `
                $folders.state, $folders.localFiles, $folders.needFiles, $folders.errors) $fColor
        }
    } else {
        Write-Report "  Config not found at $configPath" "Yellow"
    }
} catch {
    Write-Report "  NOT RUNNING or API unreachable" "Red"
}

# ============================================================================
# PNP DEVICES WITH ISSUES
# ============================================================================
Write-Report "`n--- PNP DEVICES WITH ISSUES ---" "Yellow"

# Devices intentionally disabled (OK to have issues)
$ignoredDevices = @(
    "ROOT\AMDLOG\0000",           # AMD Crash Defender (often disabled, not needed)
    "PCI\VEN_1002&DEV_164E*"     # AMD Radeon iGPU (if using discrete GPU)
)

$bad = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
    if ($_.Status -eq 'OK' -or $_.Status -eq 'Unknown' -or !$_.FriendlyName) { return $false }
    foreach ($pattern in $ignoredDevices) {
        if ($_.InstanceId -like $pattern) { return $false }
    }
    return $true
}

if ($bad) {
    Write-Report "  Devices with issues ($($bad.Count)):" "Red"
    foreach ($dev in $bad) {
        $prob = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName "DEVPKEY_Device_ProblemCode" -ErrorAction SilentlyContinue).Data
        Write-Report ("  - {0} | Status={1} | ProblemCode={2}" -f $dev.FriendlyName, $dev.Status, $prob) "Yellow"
    }
} else {
    Write-Report "  All present devices healthy" "Green"
}

# ============================================================================
# DNS / NETWORK
# ============================================================================
Write-Report "`n--- NETWORK ---" "Yellow"

# DNS servers for Wi-Fi
$dns = Get-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($dns) {
    $expected = @('1.1.1.1', '1.0.0.1')
    $actual = $dns.ServerAddresses
    $match = ($actual[0] -eq $expected[0] -and $actual[1] -eq $expected[1])
    $color = if ($match) { "Green" } else { "Yellow" }
    Write-Report "  Wi-Fi DNS: $($actual -join ', ')" $color
    if (-not $match) {
        Write-Report "    -> Expected: $($expected -join ', ')" "DarkYellow"
    }
} else {
    Write-Report "  Wi-Fi DNS: Not configured" "Yellow"
}

# Nagle algorithm status
$naglePaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{0a9d6bd8-89d5-4bb8-b5d0-4155adf68023}",
    "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{6a7b8c9d-0e1f-2345-6789-abcdef012345}"
)
$nagleDisabled = $false
foreach ($path in $naglePaths) {
    $nagle = Get-ItemProperty -Path $path -Name TcpAckFrequency -ErrorAction SilentlyContinue
    if ($nagle -and $nagle.TcpAckFrequency -eq 1) {
        $nagleDisabled = $true
        break
    }
}
Write-Report "  Nagle disabled: $nagleDisabled" $(if ($nagleDisabled) { "Green" } else { "Yellow" })

# TCP settings
try {
    $tcpGlobal = netsh interface tcp show global 2>&1 | Out-String
    if ($tcpGlobal -match "Auto-tuning level\s*:\s*(\S+)") {
        $autoTuning = $matches[1]
        $color = if ($autoTuning -eq 'normal' -or $autoTuning -eq 'disabled') { "Green" } else { "Yellow" }
        Write-Report "  TCP Auto-tuning: $autoTuning" $color
    }
} catch {}

# ============================================================================
# RCLONE
# ============================================================================
Write-Report "`n--- RCLONE ---" "Yellow"

$rc = Get-Command rclone -ErrorAction SilentlyContinue
if ($rc) {
    $ver = & rclone version 2>&1 | Select-Object -First 1
    Write-Report "  $ver" "Green"
    $remotes = & rclone listremotes 2>&1
    if ($remotes) {
        Write-Report "  Remotes: $($remotes -join ' ')" "White"
    }
} else {
    # Check winget packages
    $wingetPath = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    $rcloneDir = Get-ChildItem $wingetPath -Directory -Filter "Rclone.Rclone*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($rcloneDir) {
        Write-Report "  Installed via winget but NOT in PATH" "Yellow"
        Write-Report "  Location: $($rcloneDir.FullName)" "DarkYellow"
        Write-Report "  Run: `$env:PATH += `";$($rcloneDir.FullName)`"" "DarkYellow"
    } else {
        Write-Report "  NOT INSTALLED" "Red"
        Write-Report "  Install: winget install Rclone.Rclone" "DarkGray"
    }
}

# ============================================================================
# CUSTOM FIREWALL RULES
# ============================================================================
Write-Report "`n--- CUSTOM FIREWALL RULES ---" "Yellow"

$rules = Get-NetFirewallRule -DisplayName 'Block Inbound*' -ErrorAction SilentlyContinue
if ($rules) {
    $rules | ForEach-Object {
        $color = if ($_.Enabled -eq 'True') { "Green" } else { "Red" }
        Write-Report ("  {0}: Enabled={1}, Action={2}" -f $_.DisplayName, $_.Enabled, $_.Action) $color
    }
} else {
    Write-Report "  No custom block rules found" "Yellow"
    Write-Report "  Run optimize-system.ps1 to create them" "DarkGray"
}

# ============================================================================
# SCRIPTS
# ============================================================================
Write-Report "`n--- SCRIPTS ---" "Yellow"

$scripts = @(
    'full-system-check.ps1',
    'integrity-check.ps1',
    'security-audit.ps1',
    'full-cleanup.ps1',
    'optimize-system.ps1',
    'self-heal.bat',
    'update-plugins.ps1',
    'update-crofai-models.ps1',
    'sync-obsidian.ps1',
    'validate-settings.ps1'
)

foreach ($f in $scripts) {
    $path = "C:\Users\Administrator\Scripts\$f"
    if (Test-Path $path) {
        $size = (Get-Item $path).Length
        Write-Report "  $f — $([math]::Round($size/1KB, 1))KB" "Green"
    } else {
        Write-Report "  $f — MISSING" "Red"
    }
}

# ============================================================================
# WINDOWS UPDATE
# ============================================================================
Write-Report "`n--- WINDOWS UPDATE ---" "Yellow"

try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $result = $searcher.Search('IsInstalled=0')
    if ($result.Updates.Count -eq 0) {
        Write-Report "  No updates available" "Green"
    } else {
        Write-Report "  $($result.Updates.Count) update(s) available:" "Yellow"
        $result.Updates | ForEach-Object { Write-Report "    - $($_.Title)" "White" }
    }
} catch {
    Write-Report "  Error: $($_.Exception.Message)" "Red"
}

# ============================================================================
# DISK HEALTH
# ============================================================================
Write-Report "`n--- DISK HEALTH ---" "Yellow"

Get-PhysicalDisk | ForEach-Object {
    $status = $_.HealthStatus
    $color = if ($status -eq "Healthy") { "Green" } else { "Red" }
    Write-Report ("  {0} | {1} | {2}GB | Status: {3}" -f `
        $_.FriendlyName, $_.MediaType, [math]::Round($_.Size/1GB), $status) $color
}

# Disk space for fixed volumes
Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
    $pctFree = if ($_.Size -gt 0) { [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1) } else { 0 }
    $color = if ($pctFree -lt 10) { "Red" } elseif ($pctFree -lt 20) { "Yellow" } else { "Green" }
    Write-Report ("  Drive {0}: {1}GB free / {2}GB total ({3}% free)" -f `
        $_.DriveLetter, [math]::Round($_.SizeRemaining/1GB,1), [math]::Round($_.Size/1GB,1), $pctFree) $color
}

# ============================================================================
# RAM USAGE
# ============================================================================
Write-Report "`n--- RAM USAGE ---" "Yellow"

$os = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$usedGB = $totalGB - $freeGB
$pctUsed = [math]::Round(($usedGB / $totalGB) * 100, 1)
$ramColor = if ($pctUsed -gt 90) { "Red" } elseif ($pctUsed -gt 75) { "Yellow" } else { "Green" }

Write-Report ("  Total: {0}GB | Used: {1}GB | Free: {2}GB | Usage: {3}%" -f `
    $totalGB, $usedGB, $freeGB, $pctUsed) $ramColor

Write-Report "  Top 5 memory consumers:" "Gray"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object {
    Write-Report ("    {0,-30} {1}MB" -f $_.ProcessName, [math]::Round($_.WorkingSet64/1MB)) "Gray"
}

# ============================================================================
# CPU
# ============================================================================
Write-Report "`n--- CPU ---" "Yellow"

$cpu = Get-CimInstance Win32_Processor
Write-Report "  $($cpu.Name)" "White"
Write-Report ("  Cores: {0} | Threads: {1} | Max Clock: {2}MHz" -f `
    $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors, $cpu.MaxClockSpeed) "White"

$cpuLoad = (Get-CimInstance Win32_Processor).LoadPercentage
$cpuColor = if ($cpuLoad -gt 90) { "Red" } elseif ($cpuLoad -gt 60) { "Yellow" } else { "Green" }
Write-Report "  Current Load: ${cpuLoad}%" $cpuColor

# ============================================================================
# EVENT LOG ERRORS (Last 24h)
# ============================================================================
Write-Report "`n--- EVENT LOG ERRORS (Last 24h) ---" "Yellow"

$cutoff = (Get-Date).AddHours(-24)
$logs = @("System", "Application")

foreach ($logName in $logs) {
    try {
        $errors = Get-WinEvent -FilterHashtable @{LogName=$logName; Level=2; StartTime=$cutoff} -ErrorAction SilentlyContinue
        $criticals = Get-WinEvent -FilterHashtable @{LogName=$logName; Level=1; StartTime=$cutoff} -ErrorAction SilentlyContinue
        $errorCount = ($errors | Measure-Object).Count
        $critCount = ($criticals | Measure-Object).Count
        $color = if ($critCount -gt 0) { "Red" } elseif ($errorCount -gt 5) { "Yellow" } else { "Green" }
        Write-Report ("  {0} — {1} errors, {2} critical" -f $logName, $errorCount, $critCount) $color
        
        if ($criticals) {
            $criticals | Select-Object -First 3 | ForEach-Object {
                $msg = $_.Message.Substring(0, [Math]::Min(100, $_.Message.Length))
                Write-Report "    CRITICAL: $msg..." "Red"
            }
        }
    } catch {
        Write-Report "  $logName — Unable to read" "Yellow"
    }
}

# ============================================================================
# SYSTEM UPTIME
# ============================================================================
Write-Report "`n--- SYSTEM UPTIME ---" "Yellow"

$boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptime = (Get-Date) - $boot
Write-Report "  Last Boot: $($boot.ToString('yyyy-MM-dd HH:mm:ss'))" "White"
Write-Report ("  Uptime: {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes) "White"

if ($uptime.Days -gt 14) {
    Write-Report "  -> Consider rebooting for updates" "Yellow"
}

# ============================================================================
# WINDOWS DEFENDER STATUS
# ============================================================================
Write-Report "`n--- WINDOWS DEFENDER ---" "Yellow"

try {
    $defender = Get-MpComputerStatus -ErrorAction Stop
    $avColor = if ($defender.AntivirusEnabled) { "Green" } else { "Red" }
    $rtColor = if ($defender.RealTimeProtectionEnabled) { "Green" } else { "Red" }
    $nioColor = if ($defender.IoavProtectionEnabled) { "Green" } else { "Yellow" }
    
    Write-Report ("  Antivirus Enabled: {0}" -f $defender.AntivirusEnabled) $avColor
    Write-Report ("  Real-Time Protection: {0}" -f $defender.RealTimeProtectionEnabled) $rtColor
    Write-Report ("  IOAV Protection: {0}" -f $defender.IoavProtectionEnabled) $nioColor
    
    if (-not $defender.AntivirusEnabled -or -not $defender.RealTimeProtectionEnabled) {
        Write-Report "  -> Run: Set-MpPreference -DisableRealtimeMonitoring `$false" "DarkYellow"
        Write-Report "  -> Check: Set-Service -Name SecurityHealthService -StartupType Automatic" "DarkYellow"
    }
} catch {
    Write-Report "  Unable to get Defender status: $($_.Exception.Message)" "Red"
}

# ============================================================================
# SUMMARY
# ============================================================================
Write-Report "`n$divider" "Cyan"
Write-Report "  Check complete." "Cyan"
Write-Report $divider "Cyan"

# Return exit code based on issues found
$issues = 0
if ($bad -and $bad.Count -gt 0) { $issues++ }
if ($pctUsed -gt 90) { $issues++ }
if ($cpuLoad -gt 90) { $issues++ }
if ($critCount -gt 0) { $issues++ }

if ($LogFile) {
    Write-Report "`nReport saved to: $LogFile" "Gray"
}

exit $issues