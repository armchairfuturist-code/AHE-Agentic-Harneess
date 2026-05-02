#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Unified System Optimization Script for Windows 11 Pro
.DESCRIPTION
    Consolidates all gaming, performance, security, and networking optimizations.
    Combines functionality from apply-guide-optimizations.ps1 and ultimate-optimizations.ps1.
    
    This script is IDEMPOTENT - safe to run multiple times.
    
.PARAMETER Gaming
    Apply gaming-specific optimizations (HAGS, Game Mode, mouse acceleration off).
.PARAMETER Security
    Apply security hardening (UAC, firewall, audit policies, network hardening).
.PARAMETER Performance
    Apply performance optimizations (telemetry disable, services, visual effects).
.PARAMETER Network
    Apply network optimizations (TCP, DNS, Nagle algorithm).
.PARAMETER ScheduledTasks
    Create/update scheduled tasks for maintenance.
.PARAMETER Cleanup
    Apply system cleanup optimizations (power plans, services, Wi-Fi, desktop/Downloads organization).
.PARAMETER All
    Apply all optimizations (default).
.PARAMETER WhatIf
    Preview changes without applying them.
.PARAMETER Force
    Re-apply even if already configured.
.EXAMPLE
    .\optimize-system.ps1 -All
    .\optimize-system.ps1 -Gaming -Performance
    .\optimize-system.ps1 -Security -WhatIf
.NOTES
    Requires Administrator privileges.
    Creates logs in Scripts\logs\
#>

[CmdletBinding()]
param(
    [switch]$Gaming,
    [switch]$Security,
    [switch]$Performance,
    [switch]$Network,
    [switch]$ScheduledTasks,
    [switch]$Cleanup,
    [switch]$All = $true,
    [switch]$WhatIf,
    [switch]$Force
)

$ErrorActionPreference = 'Continue'

# ============================================================================
# CONFIGURATION
# ============================================================================
$ScriptName = "Optimize-System"
$LogDir = "C:\Users\Administrator\Scripts\logs"
$LogFile = Join-Path $LogDir "optimize-system-$(Get-Date -Format 'yyyy-MM-dd').log"
$StartTime = Get-Date

# ============================================================================
# LOGGING
# ============================================================================

function Initialize-Logging {
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    
    $header = "=" * 80
    $header | Out-File -FilePath $LogFile -Append -Encoding UTF8
    "[$ScriptName] Started at: $StartTime" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    $header | Out-File -FilePath $LogFile -Append -Encoding UTF8
    "" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'ACTION')]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    $entry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    
    if (-not $WhatIf) {
        $color = switch ($Level) {
            'OK'    { 'Green'  }
            'WARN'  { 'Yellow' }
            'ERROR' { 'Red'    }
            'ACTION'{ 'Cyan'   }
            default { 'Gray'   }
        }
        Write-Host $entry -ForegroundColor $color
    }
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Magenta
    Write-Host "  $Title" -ForegroundColor Magenta
    Write-Host ("=" * 80) -ForegroundColor Magenta
    Write-Host ""
    Write-Log $Title -Level ACTION
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [ValidateSet('DWord', 'String', 'Binary', 'QWord', 'ExpandString')]$Type = 'DWord'
    )
    
    if ($WhatIf) {
        Write-Log "WOULD SET: $Path\$Name = $Value" -Level INFO
        return $false
    }
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
        }
        
        $current = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($current -and $current.$Name -eq $Value) {
            if (-not $Force) {
                Write-Log "Already set: $Path\$Name = $Value" -Level INFO
                return $false
            }
        }
        
        $regType = switch ($Type) {
            'DWord'      { [Microsoft.Win32.RegistryValueKind]::DWord }
            'String'     { [Microsoft.Win32.RegistryValueKind]::String }
            'Binary'     { [Microsoft.Win32.RegistryValueKind]::Binary }
            'QWord'      { [Microsoft.Win32.RegistryValueKind]::QWord }
            'ExpandString'{ [Microsoft.Win32.RegistryValueKind]::ExpandString }
        }
        
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $regType -Force -ErrorAction Stop | Out-Null
        Write-Log "Set: $Path\$Name = $Value" -Level OK
        return $true
    }
    catch {
        Write-Log "Failed: $Path\$Name - $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Set-ServiceConfig {
    param(
        [string]$Name,
        [ValidateSet('Automatic', 'Manual', 'Disabled')][string]$StartupType,
        [switch]$StopIfRunning
    )
    
    if ($WhatIf) {
        Write-Log "WOULD SET: $Name -> $StartupType" -Level INFO
        return $false
    }
    
    try {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Log "Service not found: $Name" -Level WARN
            return $false
        }
        
        if ($svc.StartType -ne $StartupType) {
            Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
            Write-Log "Service $Name -> $StartupType" -Level OK
        } else {
            Write-Log "Service $Name already $StartupType" -Level INFO
        }
        
        if ($StopIfRunning -and $svc.Status -eq 'Running') {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
            Write-Log "Service $Name stopped" -Level OK
        }
        return $true
    }
    catch {
        Write-Log "Failed to configure $Name : $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function New-MaintenanceTask {
    param(
        [string]$Name,
        [string]$Description,
        [string]$Command,
        [string]$Arguments,
        [ValidateSet('Daily', 'Weekly', 'Monthly')]$Frequency,
        [string]$Time = "03:00",
        [int]$WeeksInterval = 0
    )
    
    if ($WhatIf) {
        Write-Log "WOULD CREATE: Task $Name" -Level INFO
        return $false
    }
    
    try {
        $existing = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
        if ($existing -and -not $Force) {
            Write-Log "Task already exists: $Name" -Level INFO
            return $false
        }
        
        if ($existing) {
            Unregister-ScheduledTask -TaskName $Name -Confirm:$false -ErrorAction SilentlyContinue
        }
        
        $action = New-ScheduledTaskAction -Execute $Command -Argument $Arguments
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
        
        $trigger = switch ($Frequency) {
            'Daily' {
                New-ScheduledTaskTrigger -Daily -At $Time
            }
            'Weekly' {
                if ($WeeksInterval -gt 1) {
                    New-ScheduledTaskTrigger -Weekly -WeeksInterval $WeeksInterval -DaysOfWeek Saturday -At $Time
                } else {
                    New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At $Time
                }
            }
            'Monthly' {
                New-ScheduledTaskTrigger -Weekly -WeeksInterval 4 -DaysOfWeek Sunday -At $Time
            }
        }
        
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Hours 2)
        
        Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description $Description | Out-Null
        Write-Log "Created task: $Name" -Level OK
        return $true
    }
    catch {
        Write-Log "Failed to create task $Name : $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# ============================================================================
# GAMING OPTIMIZATIONS
# ============================================================================

function Invoke-GamingOptimizations {
    Write-Section "GAMING OPTIMIZATIONS"
    
    Write-Log "Configuring Hardware-Accelerated GPU Scheduling..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord
    
    Write-Log "Configuring Game Mode and Game DVR..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AllowGameDVR" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
    Set-RegistryValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1
    
    Write-Log "Disabling mouse acceleration..." -Level ACTION
    Set-RegistryValue -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value 0
    Set-RegistryValue -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value 0
    Set-RegistryValue -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value 0
    
    Write-Log "Configuring system responsiveness for gaming..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "GPU Priority" -Value 8
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "Priority" -Value 6
    
    Write-Log "Gaming optimizations completed!" -Level OK
}

# ============================================================================
# PERFORMANCE OPTIMIZATIONS
# ============================================================================

function Invoke-PerformanceOptimizations {
    Write-Section "PERFORMANCE OPTIMIZATIONS"
    
    # --- Storage Sense ---
    Write-Log "Configuring Storage Sense..." -Level ACTION
    $storagePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
    Set-RegistryValue -Path $storagePath -Name "01" -Value 1 -Type DWord
    Set-RegistryValue -Path $storagePath -Name "2048" -Value 30 -Type DWord
    Set-RegistryValue -Path $storagePath -Name "04" -Value 1 -Type DWord
    Set-RegistryValue -Path $storagePath -Name "08" -Value 1 -Type DWord
    Set-RegistryValue -Path $storagePath -Name "256" -Value 30 -Type DWord
    Set-RegistryValue -Path $storagePath -Name "32" -Value 0 -Type DWord
    
    # --- NTFS Optimizations ---
    Write-Log "Configuring NTFS..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsMemoryUsage" -Value 2 -Type DWord
    
    # --- Background Apps ---
    Write-Log "Disabling background apps..." -Level ACTION
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1
    
    # --- Pagefile ---
    Write-Log "Configuring pagefile..." -Level ACTION
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem
        if ($cs.AutomaticManagedPagefile) {
            if (-not $WhatIf) {
                $cs | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false }
                Write-Log "Disabled automatic pagefile management" -Level OK
            }
        }
        
        # For32GB RAM, 4-8GB pagefile is sufficient
        $pf = Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "C:*" }
        if ($pf) {
            if (-not $WhatIf) {
                $pf | Set-CimInstance -Property @{ InitialSize = 4096; MaximumSize = 8192 }
                Write-Log "Pagefile set to 4096-8192MB" -Level OK
            }
        } else {
            if (-not $WhatIf) {
                New-CimInstance -ClassName Win32_PageFileSetting -Property @{
                    Name = "C:\pagefile.sys"
                    InitialSize = 4096
                    MaximumSize = 8192
                } | Out-Null
                Write-Log "Created pagefile at 4096-8192MB" -Level OK
            }
        }
    }
    catch {
        Write-Log "Pagefile configuration failed: $($_.Exception.Message)" -Level WARN
    }
    
    # --- Visual Effects ---
    Write-Log "Optimizing visual effects..." -Level ACTION
    Set-RegistryValue -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "1"
    Set-RegistryValue -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "2"
    Set-RegistryValue -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0"
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0
    
    # --- Memory Management ---
    Write-Log "Optimizing memory management..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 1
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "ClearPageFileAtShutdown" -Value 0
    
    # --- Windows Search ---
    Write-Log "Setting Windows Search to Manual..." -Level ACTION
    Set-ServiceConfig -Name "WSearch" -StartupType Manual
    
    # --- SysMain (Superfetch) ---
    Write-Log "Setting SysMain to Manual..." -Level ACTION
    Set-ServiceConfig -Name "SysMain" -StartupType Manual
    
    # --- Delivery Optimization ---
    Write-Log "Disabling Delivery Optimization..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0
    
    # --- Windows Tips and Suggestions ---
    Write-Log "Disabling Windows tips and suggestions..." -Level ACTION
    $cdmPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    @("SubscribedContent-338393Enabled", "SubscribedContent-353907Enabled", "SubscribedContent-365986Enabled",
      "SubscribedContent-338389Enabled", "SubscribedContent-310093Enabled", "SubscribedContent-202934Enabled",
      "SubscribedContent-288275Enabled", "SystemPaneSuggestionsEnabled", "RotatingLockScreenOverlayEnabled",
      "SoftLandingEnabled", "PreInstalledAppsEnabled", "SilentInstalledAppsEnabled") | ForEach-Object {
        Set-RegistryValue -Path $cdmPath -Name $_ -Value 0
    }
    
    # --- Startup Delay ---
    Write-Log "Disabling startup delay..." -Level ACTION
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Name "StartupDelayInMSec" -Value 0
    
    Write-Log "Performance optimizations completed!" -Level OK
}

# ============================================================================
# SECURITY HARDENING
# ============================================================================

function Invoke-SecurityOptimizations {
    Write-Section "SECURITY HARDENING"
    
    # --- Windows Defender Preferences ---
    Write-Log "Configuring Windows Defender preferences..." -Level ACTION
    try {
        if (-not $WhatIf) {
            Set-MpPreference -MAPSReporting Advanced -ErrorAction SilentlyContinue
            Set-MpPreference -SubmitSamplesConsent SendSafeSamples -ErrorAction SilentlyContinue
            Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
            Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction SilentlyContinue
            Set-MpPreference -ScanScheduleQuickScanTime 03:00:00 -ErrorAction SilentlyContinue
            Set-MpPreference -ScanScheduleDay 1 -ErrorAction SilentlyContinue
            Write-Log "Defender preferences applied" -Level OK
        }
    }
    catch {
        Write-Log "Defender configuration warning: $($_.Exception.Message)" -Level WARN
    }
    
    # --- Firewall Block Rules ---
    Write-Log "Configuring firewall block rules..." -Level ACTION
    $firewallRules = @(
        @{ Name = "Block Inbound SMBv1"; Direction = "Inbound"; Action = "Block"; Protocol = "TCP"; LocalPort = "445" },
        @{ Name = "Block Inbound NetBIOS-TCP"; Direction = "Inbound"; Action = "Block"; Protocol = "TCP"; LocalPort = "137-139" },
        @{ Name = "Block Inbound NetBIOS-UDP"; Direction = "Inbound"; Action = "Block"; Protocol = "UDP"; LocalPort = "137-139" },
        @{ Name = "Block Inbound RPC"; Direction = "Inbound"; Action = "Block"; Protocol = "TCP"; LocalPort = "135" }
    )
    
    foreach ($rule in $firewallRules) {
        if ($WhatIf) {
            Write-Log "WOULD CREATE: Firewall rule '$($rule.Name)'" -Level INFO
            continue
        }
        
        $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Log "Firewall rule already exists: $($rule.Name)" -Level INFO
            continue
        }
        
        New-NetFirewallRule -DisplayName $rule.Name -Direction $rule.Direction -Action $rule.Action `
            -Protocol $rule.Protocol -LocalPort $rule.LocalPort -Enabled True -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Created firewall rule: $($rule.Name)" -Level OK
    }
    
    # --- UAC ---
    Write-Log "Configuring UAC..." -Level ACTION
    $uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    Set-RegistryValue -Path $uacPath -Name "EnableLUA" -Value 1
    Set-RegistryValue -Path $uacPath -Name "ConsentPromptBehaviorAdmin" -Value 2
    Set-RegistryValue -Path $uacPath -Name "PromptOnSecureDesktop" -Value 1
    Set-RegistryValue -Path $uacPath -Name "ConsentPromptBehaviorUser" -Value 3
    
    # --- Security Policy via secedit ---
    Write-Log "Applying security policy..." -Level ACTION
    if (-not $WhatIf) {
        $secInfContent = @"
[Unicode]
Unicode=yes
[System Access]
MinimumPasswordLength = 12
PasswordComplexity = 1
LockoutBadCount = 5
ResetLockoutCount = 30
LockoutDuration = 30
[Version]
signature="`$CHICAGO`$"
Revision=1
"@
        $secInfFile = Join-Path $env:TEMP "optimize-secpol.inf"
        $secDbFile = Join-Path $env:TEMP "optimize-secpol.sdb"
        $secInfContent | Out-File $secInfFile -Encoding Unicode -Force
        & secedit /configure /db $secDbFile /cfg $secInfFile /areas SECURITYPOLICY /quiet 2>&1 | Out-Null
        Remove-Item $secInfFile -Force -ErrorAction SilentlyContinue
        Remove-Item $secDbFile -Force -ErrorAction SilentlyContinue
        Write-Log "Security policy applied: MinPwdLen=12, Complexity=on, Lockout=5/30/30" -Level OK
    }
    
    # --- Audit Policy ---
    Write-Log "Configuring audit policies..." -Level ACTION
    if (-not $WhatIf) {
        $auditPolicies = @(
            @{ Subcategory = "Logon"; Setting = "/success /failure" },
            @{ Subcategory = "Logoff"; Setting = "/success" },
            @{ Subcategory = "Account Lockout"; Setting = "/success /failure" },
            @{ Subcategory = "Special Logon"; Setting = "/success" },
            @{ Subcategory = "Security Group Management"; Setting = "/success /failure" },
            @{ Subcategory = "User Account Management"; Setting = "/success /failure" },
            @{ Subcategory = "Process Creation"; Setting = "/success" },
            @{ Subcategory = "Removable Storage"; Setting = "/success /failure" },
            @{ Subcategory = "Audit Policy Change"; Setting = "/success /failure" }
        )
        foreach ($policy in $auditPolicies) {
            & auditpol /set /subcategory:$($policy.Subcategory) $($policy.Setting) 2>&1 | Out-Null
        }
        Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1
        Write-Log "Audit policies configured" -Level OK
    }
    
    # --- Network Hardening ---
    Write-Log "Hardening network protocols..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "EnableMDNS" -Value 0
    
    # Disable NetBIOS over TCP/IP
    if (-not $WhatIf) {
        $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"
        foreach ($adapter in $adapters) {
            $adapter | Invoke-CimMethod -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = 2 } -ErrorAction SilentlyContinue | Out-Null
        }
        Write-Log "NetBIOS over TCP/IP disabled on all adapters" -Level OK
    }
    
    # --- Exploit Protection ---
    Write-Log "Configuring exploit mitigations..." -Level ACTION
    try {
        if (-not $WhatIf) {
            Set-ProcessMitigation -System -Enable DEP, SEHOP, ForceRelocateImages, BottomUp, HighEntropy -ErrorAction SilentlyContinue
            Write-Log "Exploit mitigations enabled (DEP, SEHOP, ForceRelocateImages, BottomUp, HighEntropy)" -Level OK
        }
    }
    catch {
        Write-Log "Exploit mitigation configuration warning: $($_.Exception.Message)" -Level WARN
    }
    
    Write-Log "Security hardening completed!" -Level OK
}

# ============================================================================
# NETWORK OPTIMIZATIONS
# ============================================================================

function Invoke-NetworkOptimizations {
    Write-Section "NETWORK OPTIMIZATIONS"
    
    # --- TCP Settings ---
    Write-Log "Configuring TCP settings..." -Level ACTION
    if (-not $WhatIf) {
        try {
            # Note: Disabling auto-tuning can cause issues with some routers/servers
            # Consider testing before deploying
            & netsh interface tcp set global autotuninglevel=normal 2>&1 | Out-Null
            & netsh interface tcp set global window_scaling=enabled 2>&1 | Out-Null
            & netsh interface tcp set global ecncapability=disabled 2>&1 | Out-Null
            & netsh interface tcp set global initialRto=2000 2>&1 | Out-Null
            & netsh interface tcp set global timestamps=disabled 2>&1 | Out-Null
            Write-Log "TCP settings configured (auto-tuning=normal, scaling=enabled, ECN=disabled)" -Level OK
        }
        catch {
            Write-Log "TCP configuration warning: $($_.Exception.Message)" -Level WARN
        }
    }
    
    # --- DNS Settings ---
    Write-Log "Configuring DNS settings..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "ServerPriorityTimeLimit" -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheEntryTtlLimit" -Value 0
    
    # --- Nagle's Algorithm (per-adapter) ---
    Write-Log "Disabling Nagle's Algorithm on active network adapters..." -Level ACTION
    if (-not $WhatIf) {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Name -notlike '*Bluetooth*' }
        foreach ($adapter in $adapters) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($adapter.InterfaceGuid)"
            Set-RegistryValue -Path $regPath -Name "TcpAckFrequency" -Value 1
            Set-RegistryValue -Path $regPath -Name "TCPNoDelay" -Value 1
        }
        Write-Log "Nagle's Algorithm disabled on $($adapters.Count) adapter(s)" -Level OK
    }
    
    # --- Network Adapter Power Management ---
    Write-Log "Disabling network adapter power saving..." -Level ACTION
    if (-not $WhatIf) {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Name -notlike '*Bluetooth*' }
        foreach ($adapter in $adapters) {
            try {
                Set-NetAdapterPowerManagement -Name $adapter.Name -AllowComputerToTurnOffDevice "Disabled" -ErrorAction SilentlyContinue
            }
            catch { }
        }
        Write-Log "Network adapter power saving disabled" -Level OK
    }
    
    Write-Log "Network optimizations completed!" -Level OK
}

# ============================================================================
# TELEMETRY DISABLEMENT
# ============================================================================

function Invoke-TelemetryDisablement {
    Write-Section "TELEMETRY DISABLEMENT"
    
    # --- Services ---
    Write-Log "Disabling telemetry services..." -Level ACTION
    Set-ServiceConfig -Name "DiagTrack" -StartupType Disabled -StopIfRunning
    Set-ServiceConfig -Name "dmwappushservice" -StartupType Disabled -StopIfRunning
    
    # --- Registry ---
    Write-Log "Disabling telemetry via registry..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowDeviceNameInTelemetry" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "MaxTelemetry" -Value 0
    
    # --- CEIP ---
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Value 0
    
    # --- Windows Error Reporting ---
    Write-Log "Disabling Windows Error Reporting..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name "DoReport" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1
    
    # --- Application Telemetry ---
    Write-Log "Disabling application telemetry..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "AITEnable" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableUAR" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableInventory" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableEngine" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisablePCA" -Value 1
    
    # --- Location Tracking ---
    Write-Log "Disabling location tracking..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentApplications\location" -Name "Value" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocationScripting" -Value 1
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentApplications\location" -Name "Value" -Value 0
    
    # --- Feedback Notifications ---
    Write-Log "Disabling feedback notifications..." -Level ACTION
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "PeriodInNanoSeconds" -Value 0
    
    # --- Advertising ID ---
    Write-Log "Disabling advertising ID..." -Level ACTION
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1
    
    # --- Timeline and Activity Feed ---
    Write-Log "Disabling timeline and activity feed..." -Level ACTION
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0
    
    # --- Scheduled Tasks ---
    Write-Log "Disabling telemetry scheduled tasks..." -Level ACTION
    if (-not $WhatIf) {
        $telemetryTasks = @(
            "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
            "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
            "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
            "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
            "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
            "\Microsoft\Windows\Feedback\Siuf\DmClient",
            "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
        )
        foreach ($task in $telemetryTasks) {
            Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
        }
        Write-Log "Telemetry scheduled tasks disabled" -Level OK
    }
    
    Write-Log "Telemetry disablement completed!" -Level OK
}

# ============================================================================
# SERVICE CONFIGURATION
# ============================================================================

function Invoke-ServiceConfiguration {
    Write-Section "SERVICE CONFIGURATION"
    
    # Services to disable (with reasons)
    $disableServices = @(
        @{ Name = "XblGameSave"; Reason = "Xbox Game Save - not needed" },
        @{ Name = "XboxNetApiSvc"; Reason = "Xbox Networking - not needed" },
        @{ Name = "XblAuthManager"; Reason = "Xbox Auth - not needed" },
        @{ Name = "MapsBroker"; Reason = "Downloaded Maps Manager" },
        @{ Name = "PhoneSvc"; Reason = "Phone Service" },
        @{ Name = "RetailDemo"; Reason = "Retail Demo Service" },
        @{ Name = "RemoteRegistry"; Reason = "Remote Registry - security risk" },
        @{ Name = "SCardSvr"; Reason = "Smart Card Service" },
        @{ Name = "WbioSrvc"; Reason = "Windows Biometric Service" },
        @{ Name = "lfsvc"; Reason = "Geolocation Service" },
        @{ Name = "diagnosticshub.standardcollector.service"; Reason = "Diagnostic Hub" },
        @{ Name = "Fax"; Reason = "Fax Service" },
        @{ Name = "TabletInputService"; Reason = "Touch Keyboard and Handwriting Panel" },
        @{ Name = "WalletService"; Reason = "Wallet Service" }
    )
    
    foreach ($svc in $disableServices) {
        Write-Log "Disabling: $($svc.Name) - $($svc.Reason)" -Level ACTION
        Set-ServiceConfig -Name $svc.Name -StartupType Disabled -StopIfRunning
    }
    
    # Services to set to Manual
    $manualServices = @(
        @{ Name = "BITS"; Reason = "Background Intelligent Transfer" },
        @{ Name = "wuauserv"; Reason = "Windows Update (manual for control)" },
        @{ Name = "UsoSvc"; Reason = "Update Orchestrator Service" },
        @{ Name = "StorSvc"; Reason = "Storage Service" },
        @{ Name = "TimeBrokerSvc"; Reason = "Time Broker" },
        @{ Name = "StateRepository"; Reason = "State Repository Service" },
        @{ Name = "TokenBroker"; Reason = "Web Account Manager" }
    )
    
    foreach ($svc in $manualServices) {
        Write-Log "Setting to Manual: $($svc.Name) - $($svc.Reason)" -Level ACTION
        Set-ServiceConfig -Name $svc.Name -StartupType Manual
    }
    
    # IMPORTANT: Ensure Bluetooth services remain enabled
    Write-Log "Ensuring Bluetooth services remain enabled..." -Level ACTION
    $bluetoothServices = @("BthAvctpSvc", "bthserv", "BluetoothUserService")
    foreach ($svc in $bluetoothServices) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s -and $s.StartType -eq 'Disabled') {
            Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
            Write-Log "Bluetooth service enabled: $svc" -Level OK
        }
    }
    
    Write-Log "Service configuration completed!" -Level OK
}

# ============================================================================
# WINDOWS UPDATE CONFIGURATION
# ============================================================================

function Invoke-WindowsUpdateConfiguration {
    Write-Section "WINDOWS UPDATE CONFIGURATION"
    
    Write-Log "Configuring Windows Update policies..." -Level ACTION
    
    $wuAUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    Set-RegistryValue -Path $wuAUPath -Name "AUOptions" -Value 4 -Type DWord
    Set-RegistryValue -Path $wuAUPath -Name "ScheduledInstallDay" -Value 0 -Type DWord
    Set-RegistryValue -Path $wuAUPath -Name "ScheduledInstallTime" -Value 3 -Type DWord
    Set-RegistryValue -Path $wuAUPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord
    
    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    Set-RegistryValue -Path $wuPath -Name "DeferFeatureUpdatesPeriodInDays" -Value 30 -Type DWord
    Set-RegistryValue -Path $wuPath -Name "DeferQualityUpdatesPeriodInDays" -Value 7 -Type DWord
    Set-RegistryValue -Path $wuPath -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord
    
    Write-Log "Windows Update configured: auto-download+schedule, 30d feature defer, 7d quality defer" -Level OK
}

# ============================================================================
# SCHEDULED TASKS
# ============================================================================

function Invoke-ScheduledTasksConfiguration {
    Write-Section "SCHEDULED TASKS CONFIGURATION"
    
    # --- BiWeeklyRestorePoint ---
    Write-Log "Creating BiWeeklyRestorePoint task..." -Level ACTION
    New-MaintenanceTask -Name "BiWeeklyRestorePoint" `
        -Description "Create system restore point every 2 weeks" `
        -Command "powershell.exe" `
        -Arguments "-NoProfile -WindowStyle Hidden -Command `"Checkpoint-Computer -Description 'BiWeekly Automatic Restore Point' -RestorePointType MODIFY_SETTINGS`"" `
        -Frequency Weekly -Time "03:00" -WeeksInterval 2
    
    # --- MonthlyIntegrityCheck ---
    Write-Log "Creating MonthlyIntegrityCheck task..." -Level ACTION
    New-MaintenanceTask -Name "MonthlyIntegrityCheck" `
        -Description "Monthly DISM + SFC integrity check" `
        -Command "powershell.exe" `
        -Arguments "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\Users\Administrator\Scripts\integrity-check.ps1`"" `
        -Frequency Monthly -Time "05:00"
    
    Write-Log "Scheduled tasks configuration completed!" -Level OK
}

# ============================================================================
# WINDOWS DEFENDER EXCLUSIONS
# ============================================================================

function Invoke-DefenderExclusions {
    Write-Section "WINDOWS DEFENDER EXCLUSIONS (Optional)"
    
    Write-Log "Adding development exclusions for better build performance..." -Level ACTION
    
    $pathExclusions = @(
        "$env:USERPROFILE\.claude",
        "$env:USERPROFILE\.antigravity",
        "$env:USERPROFILE\Projects",
        "$env:USERPROFILE\dev",
        "$env:USERPROFILE\.bun",
        "$env:USERPROFILE\.cache",
        "$env:LOCALAPPDATA\npm-cache"
    )
    
    $processExclusions = @(
        "node.exe", "bun.exe", "claude.exe", "pwsh.exe", "code.exe"
    )
    
    if ($WhatIf) {
        Write-Log "WOULD ADD: Defender exclusions" -Level INFO
        return
    }
    
    try {
        foreach ($path in $pathExclusions) {
            if (Test-Path $path) {
                Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
                Write-Log "Excluded path: $path" -Level OK
            }
        }
        foreach ($proc in $processExclusions) {
            Add-MpPreference -ExclusionProcess $proc -ErrorAction SilentlyContinue
            Write-Log "Excluded process: $proc" -Level OK
        }
    }
    catch {
        Write-Log "Defender exclusions require admin: $($_.Exception.Message)" -Level WARN
    }
}

# ============================================================================
# CLEANUP & ORGANIZATION
# ============================================================================

function Invoke-CleanupOptimizations {
    Write-Section "CLEANUP & ORGANIZATION"

    # --- Remove bloatware power plans ---
    Write-Log "Removing bloatware power plans..." -Level ACTION
    $bloatPlans = @(
        @{ GUID = "efb1f212-766e-40a8-8b5c-9d52ec7121ee"; Name = "Driver Booster Power Plan" },
        @{ GUID = "ce9fa8b3-8e9e-42db-b4e1-e6297f6cdd7e"; Name = "GameTurbo" }
    )
    foreach ($plan in $bloatPlans) {
        $exists = powercfg /list 2>&1 | Select-String $plan.GUID
        if ($exists) {
            if (-not $WhatIf) {
                $active = (powercfg /getactivescheme 2>&1) -match $plan.GUID
                if ($active) {
                    # Switch to High Performance before deleting active plan
                    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
                    Write-Log "Switched active plan to High Performance before deleting $($plan.Name)" -Level WARN
                }
                & powercfg -delete $plan.GUID 2>&1 | Out-Null
            }
            Write-Log "Removed power plan: $($plan.Name)" -Level OK
        } else {
            Write-Log "Power plan already removed: $($plan.Name)" -Level INFO
        }
    }

    # --- Set AMD External Events Utility to Manual (iGPU user, Intel Arc drives display) ---
    Write-Log "Setting AMD External Events Utility to Manual..." -Level ACTION
    Set-ServiceConfig -Name "AMD External Events Utility" -StartupType Manual

    # --- Disable unused Ethernet adapter ---
    Write-Log "Disabling unused Ethernet adapter..." -Level ACTION
    if (-not $WhatIf) {
        $eth = Get-NetAdapter -Name "Ethernet" -ErrorAction SilentlyContinue
        if ($eth -and $eth.Status -eq 'Disconnected') {
            Disable-NetAdapter -Name "Ethernet" -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Disabled disconnected Ethernet adapter" -Level OK
        } elseif ($eth) {
            Write-Log "Ethernet adapter is connected, skipping" -Level INFO
        } else {
            Write-Log "No Ethernet adapter found" -Level INFO
        }
    }

    # --- Optimize Wi-Fi adapter settings ---
    Write-Log "Optimizing Wi-Fi adapter settings..." -Level ACTION
    if (-not $WhatIf) {
        $wifi = Get-NetAdapter -Name "Wi-Fi" -ErrorAction SilentlyContinue
        if ($wifi) {
            # Set roaming aggressiveness to Lowest (not roaming on desktop)
            try {
                Set-NetAdapterAdvancedProperty -Name "Wi-Fi" -RegistryKeyword "*RoamingAggressiveness" -RegistryValue "1" -ErrorAction SilentlyContinue
                Write-Log "Wi-Fi roaming aggressiveness: Lowest" -Level OK
            } catch {
                Write-Log "Wi-Fi roaming setting not available" -Level WARN
            }

            # Set preferred band to 5GHz
            try {
                Set-NetAdapterAdvancedProperty -Name "Wi-Fi" -RegistryKeyword "*PreferredBand" -RegistryValue "2" -ErrorAction SilentlyContinue
                Write-Log "Wi-Fi preferred band: 5GHz" -Level OK
            } catch {
                Write-Log "Wi-Fi preferred band setting not available" -Level WARN
            }
        }
    }

    # --- Set unnecessary automatic services to Manual ---
    Write-Log "Setting unnecessary automatic services to Manual..." -Level ACTION
    $manualServices = @(
        @{ Name = "nginx"; Reason = "Web server - not needed 24/7" },
        @{ Name = "cloudflared"; Reason = "Cloudflare tunnel - not needed 24/7" },
        @{ Name = "BthAvctpSvc"; Reason = "Bluetooth audio gateway - no BT audio devices" },
        @{ Name = "bthserv"; Reason = "Bluetooth support - no BT audio devices" },
        @{ Name = "SyncShareSvc"; Reason = "Work Folders sync - not used" }
    )
    foreach ($svc in $manualServices) {
        $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if ($s -and $s.StartType -eq 'Automatic') {
            Set-ServiceConfig -Name $svc.Name -StartupType Manual -Reason $svc.Reason
        }
    }

    # --- Organize Desktop ---
    Write-Log "Organizing Desktop..." -Level ACTION
    if (-not $WhatIf) {
        $desktop = "$env:USERPROFILE\Desktop"
        $folders = @{
            "Work"       = @("*.md", "*.txt", "*.pdf", "*.docx", "*.doc")
            "Scripts"    = @("*.ps1", "*.bat", "*.cmd", "*.sh")
            "Shortcuts"  = @("*.lnk", "*.url")
            "Images"     = @("*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.svg", "*.ico", "*.webp")
            "Archives"   = @("*.zip", "*.rar", "*.7z", "*.tar", "*.gz")
        }

        foreach ($folderEntry in $folders.GetEnumerator()) {
            $folderName = $folderEntry.Key
            $patterns = $folderEntry.Value
            $folderPath = Join-Path $desktop $folderName

            if (-not (Test-Path $folderPath)) {
                New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
                Write-Log "Created Desktop folder: $folderName" -Level INFO
            }

            foreach ($pattern in $patterns) {
                $files = Get-ChildItem -Path $desktop -Filter $pattern -File -ErrorAction SilentlyContinue
                # Skip if file is already inside a subfolder
                $files = $files | Where-Object { $_.DirectoryName -eq $desktop }
                foreach ($file in $files) {
                    $dest = Join-Path $folderPath $file.Name
                    if (-not (Test-Path $dest)) {
                        Move-Item -Path $file.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                        Write-Log "Moved to Desktop\$folderName : $($file.Name)" -Level OK
                    }
                }
            }
        }
    }

    # --- Organize Downloads ---
    Write-Log "Organizing Downloads..." -Level ACTION
    if (-not $WhatIf) {
        $downloads = "$env:USERPROFILE\Downloads"
        $folders = @{
            "Financial"  = @("*statement*", "*invoice*", "*receipt*", "*irs*", "*loan*", "*checking*", "*credit*", "*rental*", "*bank*")
            "Games"      = @("*trainer*", "*repack*", "*crack*", "*patch*", "*game*")
            "Media"      = @("*.mp4", "*.mkv", "*.avi", "*.mov", "*.mp3", "*.wav", "*.flac")
            "Documents"  = @("*.pdf", "*.docx", "*.doc", "*.pptx", "*.xlsx", "*.txt", "*.md")
            "Archives"   = @("*.zip", "*.rar", "*.7z", "*.tar", "*.gz")
            "Installers" = @("*.exe", "*.msi", "*.appx")
        }

        foreach ($folderEntry in $folders.GetEnumerator()) {
            $folderName = $folderEntry.Key
            $patterns = $folderEntry.Value
            $folderPath = Join-Path $downloads $folderName

            if (-not (Test-Path $folderPath)) {
                New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
                Write-Log "Created Downloads folder: $folderName" -Level INFO
            }

            foreach ($pattern in $patterns) {
                if ($pattern -like "*.*" -and $pattern -notlike "*\**") {
                    # File extension pattern
                    $files = Get-ChildItem -Path $downloads -Filter $pattern -File -ErrorAction SilentlyContinue
                } else {
                    # Name-based pattern (use Where-Object for partial matches)
                    $files = Get-ChildItem -Path $downloads -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern }
                }
                $files = $files | Where-Object { $_.DirectoryName -eq $downloads }
                foreach ($file in $files) {
                    $dest = Join-Path $folderPath $file.Name
                    if (-not (Test-Path $dest)) {
                        Move-Item -Path $file.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                        Write-Log "Moved to Downloads\$folderName : $($file.Name)" -Level OK
                    }
                }
            }
        }
    }

    Write-Log "Cleanup & organization completed!" -Level OK
}

# ============================================================================
# MAIN
# ============================================================================

function Invoke-Main {
    # Verify admin
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
        Write-Host "Run: Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor Yellow
        exit 1
    }
    
    Initialize-Logging
    
    Write-Host ""
    Write-Host "  $ScriptName" -ForegroundColor Magenta
    Write-Host "  Started at: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    if ($WhatIf) { Write-Host "  (WHATIF MODE - No changes will be made)" -ForegroundColor Yellow }
    Write-Host ""
    
    # Determine what to run
    if ($Gaming -or $Security -or $Performance -or $Network -or $ScheduledTasks) {
        $All = $false
    }
    
    if ($All -or $Gaming) { Invoke-GamingOptimizations }
    if ($All -or $Performance) { Invoke-PerformanceOptimizations }
    if ($All -or $Security) { Invoke-SecurityOptimizations }
    if ($All -or $Network) { Invoke-NetworkOptimizations }
    if ($All -or $Cleanup) { Invoke-CleanupOptimizations }
    
    # Always run telemetry and service config with -All
    if ($All) {
        Invoke-TelemetryDisablement
        Invoke-ServiceConfiguration
        Invoke-WindowsUpdateConfiguration
        Invoke-ScheduledTasksConfiguration
    }
    
    # Summary
    $endTime = Get-Date
    $duration = $endTime - $StartTime
    
    Write-Section "OPTIMIZATION COMPLETE"
    Write-Host "  Completed at: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host "  Duration: $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor Cyan
    Write-Host "  Log: $LogFile" -ForegroundColor Gray
    Write-Host ""
    
    if (-not $WhatIf) {
        Write-Host "  IMPORTANT:" -ForegroundColor Yellow
        Write-Host "  - A system restart is recommended for all changes to take effect" -ForegroundColor Yellow
        Write-Host "  - SecurityHealthService may need to be re-enabled if Defender was disabled" -ForegroundColor Yellow
        Write-Host ""
    }
    
    $footer = "=" * 80
    $footer | Out-File -FilePath $LogFile -Append -Encoding UTF8
    "[$ScriptName] Completed at: $endTime (Duration: $($duration.Minutes)m $($duration.Seconds)s)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    $footer | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# Execute
Invoke-Main