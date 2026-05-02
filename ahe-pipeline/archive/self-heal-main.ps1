<#
.SYNOPSIS
    Self-healing system orchestrator — one entry point for health checks,
    fixes, audits, optimizations, and scheduled maintenance cycles.
.DESCRIPTION
    Hybrid orchestrator with subcommands:
      check       — Run all health checks
      status      — Quick one-line health summary
      fix         — Auto-fix settings, scripts
      audit       — Inventory scripts, MD files, hooks
      sync        — Sync research docs to Obsidian
      tokens      — RTK token savings report
      optimize    — Update all apps (winget) + Windows Update
      system-check — Full system health (services, disk, network, events)
      cleanup     — Disk cleanup (temp, cache, recycle bin)
      integrity   — DISM + SFC system file scan
      security    — Security audit snapshot
      game-mode   — Switch to gaming mode (high perf, disable search)
      dev-mode    — Switch to dev mode (enable search, Defender)
      cycle       — Full weekly maintenance cycle

.PARAMETER WhatIf
    Show actions without executing them.
.EXAMPLE
    .\self-heal status
    .\self-heal optimize
    .\self-heal game-mode
    .\self-heal cycle -WhatIf
#>
param(
    [switch]$WhatIf,
    [switch]$Pause  # Keep window open after completion (useful when double-clicking)
)

$ErrorActionPreference = 'Continue'
$QwenDir = "$env:USERPROFILE\.qwen"
$SettingsPath = "$QwenDir\settings.json"
$BackupPath = "$QwenDir\settings.json.last-good"
$ScriptsDir = "$env:USERPROFILE\Scripts"

# ─── Help ───────────────────────────────────────────────────────────────────
function Show-Help {
    Write-Host @"
Self-Heal — System health orchestrator

USAGE:
    self-heal <command> [args]

COMMANDS:
    check              Run all health checks
    status             Quick health summary
    fix settings       Restore settings.json from .last-good backup
    fix scripts        Run update-plugins.ps1
    audit scripts      Inventory all .ps1 files
    audit md           Find and classify .md files for Obsidian
    sync               Sync research docs to Obsidian
    tokens             Show RTK token savings report
    optimize           Update all apps (winget) + Windows Update
    system-check       Full system health (services, disk, network, events)
    cleanup            Disk cleanup (temp, cache, recycle bin)
    integrity          DISM + SFC system file scan
    security           Security audit snapshot
    game-mode          Switch to gaming mode (high perf, disable search)
    dev-mode           Switch to dev mode (enable search, Defender)
    cycle              Full weekly maintenance cycle

PARAMETERS:
    -WhatIf            Preview actions without executing
    -Pause             Keep window open (double-click from Explorer)
"@
}

# ─── Colors ──────────────────────────────────────────────────────────────────
function Ok  { param($s) Write-Host "  ✅ $s" -ForegroundColor Green }
function Warn{ param($s) Write-Host "  ⚠️  $s" -ForegroundColor Yellow }
function Err { param($s) Write-Host "  ❌ $s" -ForegroundColor Red }
function Info{ param($s) Write-Host "  ℹ️  $s" -ForegroundColor Cyan }

# ─── Commands ────────────────────────────────────────────────────────────────

function Invoke-Check {
    $errors = 0
    $warnings = 0
    Write-Host "=== Health Check ===" -ForegroundColor Cyan

    # 1. settings.json validity
    Write-Host "`n[Settings]" -ForegroundColor White
    if (Test-Path $SettingsPath) {
        try {
            $content = Get-Content $SettingsPath -Raw
            $null = $content | ConvertFrom-Json
            Ok "settings.json is valid JSON"
            # Check size
            $size = (Get-Item $SettingsPath).Length
            if ($size -gt 15KB) { Warn "settings.json is $([math]::Round($size/1KB,1)) KB (over 15 KB)"; $warnings++ }
            else { Ok "settings.json size: $([math]::Round($size/1KB,1)) KB" }
        } catch {
            Err "settings.json is invalid JSON: $_"
            $errors++
        }
    } else {
        Err "settings.json not found at $SettingsPath"
        $errors++
    }

    # 2. Backup exists
    if (Test-Path $BackupPath) {
        $age = (Get-Date) - (Get-Item $BackupPath).LastWriteTime
        Ok "Backup exists ($($age.Days)d $($age.Hours)h old)"
    } else {
        Warn "No .last-good backup found"
        $warnings++
    }

    # 3. MCP servers
    Write-Host "`n[MCP Servers]" -ForegroundColor White
    $mcpEntries = @(
        @{ Name="filesystem"; Cmd="npx"; Args="@('-y','@modelcontextprotocol/server-filesystem')" },
        @{ Name="qwen-memory"; Cmd="node"; Args="'$QwenDir\memory\memory-mcp-server.js'" },
        @{ Name="github"; Cmd="npx"; Args="@('-y','@modelcontextprotocol/server-github')" },
        @{ Name="brave-search"; Cmd="npx"; Args="@('-y','@modelcontextprotocol/server-brave-search')" }
    )
    foreach ($mcp in $mcpEntries) {
        $exe = (Get-Command $mcp.Cmd -ErrorAction SilentlyContinue)
        if ($exe) { Ok "$($mcp.Name) executable available" }
        else { Warn "$($mcp.Name) executable not on PATH"; $warnings++ }
    }

    # 4. Hooks exist
    Write-Host "`n[Hooks]" -ForegroundColor White
    $hooks = @("rtk-wrapper.js","gsd-prompt-guard.js","gsd-read-guard.js","gsd-context-monitor.js","settings-guardian.js","autoresearch-trigger.js","gsd-statusline.js")
    foreach ($h in $hooks) {
        $hp = "$QwenDir\hooks\$h"
        if (Test-Path $hp) { Ok "$h" }
        else { Warn "$h not found at hooks directory"; $warnings++ }
    }

    # 5. Scripts check
    Write-Host "`n[Scripts]" -ForegroundColor White
    $keyScripts = @("update-plugins.ps1","sync-obsidian.ps1","update-crofai-models.ps1")
    foreach ($s in $keyScripts) {
        $sp = "$ScriptsDir\$s"
        if (Test-Path $sp) {
            $modAge = (Get-Date) - (Get-Item $sp).LastWriteTime
            if ($modAge.TotalDays -gt 60) { Warn "$s unmodified for $($modAge.Days) days"; $warnings++ }
            else { Ok "$s (modified $($modAge.Days)d ago)" }
        } else { Warn "$s not found"; $warnings++ }
    }

    # Summary
    Write-Host ""
    if ($errors -eq 0 -and $warnings -eq 0) {
        Write-Host "✅ All systems healthy" -ForegroundColor Green
        return 0
    } elseif ($errors -eq 0) {
        Write-Host "⚠️  $warnings warnings (0 errors)" -ForegroundColor Yellow
        return 1
    } else {
        Write-Host "❌ $errors errors, $warnings warnings" -ForegroundColor Red
        return 2
    }
}

function Invoke-Status {
    $exitCode = Invoke-Check
    $stats = @{healthy=0; warning=0; error=0}
    if ($exitCode -eq 0) { Write-Host "✅ All systems healthy" -ForegroundColor Green }
    elseif ($exitCode -eq 1) { Write-Host "⚠️  Warnings detected (run 'self-heal check' for details)" -ForegroundColor Yellow }
    else { Write-Host "❌ Errors detected (run 'self-heal check' for details)" -ForegroundColor Red }
}

function Invoke-FixSettings {
    if ($WhatIf) { Info "Would restore $SettingsPath from $BackupPath"; return }
    if (-not (Test-Path $BackupPath)) { Err "No backup found at $BackupPath"; return }
    try {
        Copy-Item $BackupPath $SettingsPath -Force
        Ok "Restored settings.json from last-good backup"
    } catch { Err "Failed to restore: $_" }
}

function Invoke-FixScripts {
    $up = "$ScriptsDir\update-plugins.ps1"
    if (Test-Path $up) {
        if ($WhatIf) { Info "Would run: $up"; return }
        & $up
    } else { Err "update-plugins.ps1 not found" }
}

function Invoke-AuditScripts {
    Write-Host "=== Script Audit ===" -ForegroundColor Cyan
    $allScripts = @()
    $allScripts += Get-ChildItem "$ScriptsDir\*.ps1" -ErrorAction SilentlyContinue
    $allScripts += Get-ChildItem "$env:USERPROFILE\*.ps1" -ErrorAction SilentlyContinue
    $total = $allScripts.Count
    $old = @()
    $parseErrors = @()
    $workingDirs = @{ Scripts=0; Home=0 }
    foreach ($s in $allScripts) {
        if ($s.DirectoryName -eq $ScriptsDir) { $workingDirs.Scripts++ } else { $workingDirs.Home++ }
        $age = (Get-Date) - $s.LastWriteTime
        if ($age.TotalDays -gt 60) { $old += $s.Name }
    }
    Write-Host "Total: $total scripts ($($workingDirs.Scripts) in Scripts\, $($workingDirs.Home) in ~\))" -ForegroundColor White
    if ($old.Count -gt 0) {
        Warn "$($old.Count) scripts untouched for 60+ days"
        foreach ($o in $old) { Write-Host "     $o" -ForegroundColor DarkYellow }
    } else { Ok "All scripts modified recently" }
}

function Invoke-AuditMd {
    Write-Host "=== Markdown Audit ===" -ForegroundColor Cyan
    $researchPatterns = @('research','analysis','summary','optimization','journey','final','discovery','findings','results','audit','review','benchmark','comparison','vision','test-result')
    $skipNames = @('README.md','AUTORESEARCH-README.md','AGENTS.md','CLAUDE.md','QWEN.md','CONTRIBUTING.md','LICENSE','CHANGELOG.md','COMPARISON.md')
    $locations = @( "$env:USERPROFILE\Desktop\*.md", "$env:USERPROFILE\*.md" )
    foreach ($loc in $locations) {
        $files = Get-ChildItem $loc -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin $skipNames }
        foreach ($f in $files) {
            $isResearch = $researchPatterns | Where-Object { $f.BaseName -match $_ }
            if ($isResearch) {
                Write-Host "  📄 Research: $($f.Name)" -ForegroundColor Green
            } else {
                Write-Host "  📄 Config/Other: $($f.Name)" -ForegroundColor Gray
            }
        }
    }
}

function Invoke-Sync {
    $sync = "$ScriptsDir\sync-obsidian.ps1"
    if (Test-Path $sync) {
        if ($WhatIf) { Info "Would run: $sync -WhatIf"; & $sync -WhatIf; return }
        & $sync
    } else { Err "sync-obsidian.ps1 not found" }
}

function Invoke-Cycle {
    Write-Host "=== Weekly Maintenance Cycle ===" -ForegroundColor Cyan
    Write-Host "Starting $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
    Write-Host ""

    # Phase 1: Health check
    Write-Host "Phase 1/5: Health check" -ForegroundColor White
    $health = Invoke-Check

    # Phase 2: Script audit
    Write-Host "`nPhase 2/5: Script audit" -ForegroundColor White
    Invoke-AuditScripts

    # Phase 3: MD to Obsidian
    Write-Host "`nPhase 3/5: Sync research docs to Obsidian" -ForegroundColor White
    Invoke-Sync

    # Phase 4: Optimize (apps + Windows Update)
    Write-Host "`nPhase 4/5: Optimize (apps + Windows Update)" -ForegroundColor White
    Invoke-Optimize

    # Phase 5: Summary
    Write-Host "`nPhase 5/5: Complete" -ForegroundColor White
    $exitCode = if ($health -eq 2) { 2 } else { 0 }
    if ($exitCode -eq 0) {
        Write-Host "`n✅ Weekly cycle complete — all systems healthy" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  Cycle complete — $health issue(s) found (run 'self-heal check' for details)" -ForegroundColor Yellow
    }

    # Log to file
    $logFile = "$env:USERPROFILE\Scripts\logs\self-heal-cycle.log"
    $logDir = Split-Path $logFile -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | CYCLE | exit=$exitCode | health=$health" | Out-File $logFile -Append
}

# ─── New subcommands ─────────────────────────────────────────────────────────

function Invoke-Optimize {
    Write-Host "=== System Optimization ===" -ForegroundColor Cyan
    $needsReboot = $false
    $exitCode = 0

    # 1. Winget app updates
    Write-Host "`n[Apps] Checking for winget updates..." -ForegroundColor White
    if ($WhatIf) {
        Info "Would run: winget upgrade --all"
    } else {
        try {
            $result = winget upgrade --all --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
            if ($result -match 'No applicable update found') {
                Ok "All winget apps are up to date"
            } elseif ($result -match 'upgrade --all') {
                Warn "Some apps need updates (listed above)"
            } else {
                Ok "Winget update completed"
            }
        } catch { Warn "Winget failed: $_"; $exitCode = 1 }
    }

    # 2. Windows Update
    Write-Host "`n[Windows Update] Checking for updates..." -ForegroundColor White
    if ($WhatIf) {
        Info "Would trigger Windows Update scan"
    } else {
        try {
            $result = & usoclient ScanInstallWait 2>&1
            # Check if updates are pending
            $updateSession = New-Object -ComObject Microsoft.Update.UpdateSession
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
            if ($searchResult.Updates.Count -gt 0) {
                Warn "$($searchResult.Updates.Count) Windows update(s) available"
                foreach ($u in $searchResult.Updates) {
                    if ($u.IsRebootRequired) { $needsReboot = $true }
                    Write-Host "     $($u.Title)" -ForegroundColor DarkYellow
                }
                Info "Run 'self-heal optimize' again to install pending updates"
            } else {
                Ok "Windows is up to date"
            }
        } catch { Warn "Windows Update check failed: $_"; $exitCode = 1 }
    }

    # 3. Driver updates (via winget)
    Write-Host "`n[Drivers] Checking driver updates..." -ForegroundColor White
    if (-not $WhatIf) {
        try {
            $driverUpdates = winget upgrade --include-unknown 2>&1 | Select-String -Pattern '\S+\.\S+'
            if ($driverUpdates) {
                Warn "Driver updates may be available (check via Windows Update)"
            } else { Ok "No driver issues detected" }
        } catch { Info "Driver check skipped (winget)" }
    }

    # Summary
    Write-Host ""
    if ($needsReboot) { Warn "Reboot required to complete some updates" }
    if ($exitCode -eq 0) { Ok "Optimization complete" }
    else { Warn "Optimization completed with warnings" }
    return $exitCode
}

function Invoke-SystemCheck {
    $script = "$PSScriptRoot\full-system-check.ps1"
    if (Test-Path $script) {
        if ($WhatIf) { Info "Would run: $script"; return }
        & $script
    } else { Err "full-system-check.ps1 not found" }
}

function Invoke-Cleanup {
    $script = "$PSScriptRoot\full-cleanup.ps1"
    if (Test-Path $script) {
        if ($WhatIf) { Info "Would run: $script -WhatIf"; & $script -WhatIf; return }
        & $script
    } else { Err "full-cleanup.ps1 not found" }
}

function Invoke-Integrity {
    $script = "$PSScriptRoot\integrity-check.ps1"
    if (Test-Path $script) {
        if ($WhatIf) { Info "Would run: $script"; return }
        & $script
    } else { Err "integrity-check.ps1 not found" }
}

function Invoke-Security {
    $script = "$PSScriptRoot\security-audit.ps1"
    if (Test-Path $script) {
        if ($WhatIf) { Info "Would run: $script -OutputDir ."; return }
        & $script -OutputDir "$env:USERPROFILE\Documents"
    } else { Err "security-audit.ps1 not found" }
}

function Invoke-GameMode {
    Write-Host "=== Switching to GAME MODE ===" -ForegroundColor Yellow
    if ($WhatIf) { Info "Would: set High Performance power plan, stop search, pause sync, disable Defender real-time"; return }
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c; Ok "Power plan: High Performance"
    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue; Set-Service -Name "WSearch" -StartupType Disabled; Ok "Windows Search: Disabled"
    Set-MpPreference -DisableRealtimeMonitoring $true; Ok "Defender real-time: OFF (temp)"
    try { $apiKey=(Select-Xml -Path "$env:LOCALAPPDATA\Syncthing\config.xml" -XPath '//apikey').Node.InnerText; Invoke-RestMethod -Uri 'http://127.0.0.1:8384/rest/system/pause' -Method POST -Headers @{'X-API-Key'=$apiKey} | Out-Null; Ok "Syncthing: Paused" } catch { Info "Syncthing: Not running" }
    [System.GC]::Collect(); Ok "Memory cleanup"
    Write-Host "`n✅ GAME MODE ACTIVE — run 'self-heal dev-mode' when done" -ForegroundColor Green
}

function Invoke-DevMode {
    Write-Host "=== Switching to DEV MODE ===" -ForegroundColor Cyan
    if ($WhatIf) { Info "Would: set Dynamic Boost power plan, enable search, enable Defender, resume sync"; return }
    powercfg /setactive 10728b17-d7bd-4ca1-990c-b4f7c030f8cd; Ok "Power plan: Dynamic Boost"
    Set-Service -Name "WSearch" -StartupType Manual; Start-Service -Name "WSearch" -ErrorAction SilentlyContinue; Ok "Windows Search: Enabled"
    Set-MpPreference -DisableRealtimeMonitoring $false; Ok "Defender real-time: ON"
    try { $apiKey=(Select-Xml -Path "$env:LOCALAPPDATA\Syncthing\config.xml" -XPath '//apikey').Node.InnerText; Invoke-RestMethod -Uri 'http://127.0.0.1:8384/rest/system/resume' -Method POST -Headers @{'X-API-Key'=$apiKey} | Out-Null; Ok "Syncthing: Resumed" } catch { Info "Syncthing: Not running" }
    Get-Process | Where-Object { $_.PriorityClass -eq 'High' } | ForEach-Object { try { $_.PriorityClass = 'Normal' } catch {} }
    Ok "Process priorities: Normal"
    Write-Host "`n✅ DEV MODE ACTIVE" -ForegroundColor Green
}

function Invoke-Tokens {
    <#
    .SYNOPSIS
        Display accumulated RTK token savings
    #>
    $savingsFile = "$env:USERPROFILE\.qwen\token-savings.json"
    if (-not (Test-Path $savingsFile)) {
        Write-Host "No token savings data yet. RTK tracking is active and will collect data as you work." -ForegroundColor Yellow
        Write-Host "Run some commands first — RTK-wrapped commands are automatically tracked." -ForegroundColor Gray
        return
    }
    try {
        $s = Get-Content $savingsFile -Raw | ConvertFrom-Json
        Write-Host "=== RTK Token Savings ===" -ForegroundColor Cyan
        Write-Host "  Total tracked runs: $($s.runs)" -ForegroundColor White
        $saved = [math]::Round(($s.totalInputChars - $s.totalOutputChars) / 1000)
        if ($saved -gt 1000) {
            Write-Host "  Tokens saved: $([math]::Round($saved/1000, 1))M" -ForegroundColor Green
        } else {
            Write-Host "  Tokens saved: $saved K" -ForegroundColor Green
        }
        $inputK = [math]::Round($s.totalInputChars / 1000)
        $outputK = [math]::Round($s.totalOutputChars / 1000)
        Write-Host "  Input processed: $inputK K → Output: $outputK K (RTK compressed)" -ForegroundColor Gray
        if ($s.totalInputChars -gt 0) {
            $pct = [math]::Round((1 - $s.totalOutputChars / $s.totalInputChars) * 100, 1)
            Write-Host "  Overall reduction: $pct%" -ForegroundColor Green
        }
        if ($s.lastRun) {
            Write-Host ""
            Write-Host "  Last tracked command:" -ForegroundColor Gray
            Write-Host "    $($s.lastRun.command)" -ForegroundColor DarkGray
            Write-Host "    Saved: $([math]::Round(($s.lastRun.inputChars - $s.lastRun.outputChars)/1000)) K chars at $($s.lastRun.reduction)%" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "  ⚡ RTK is reducing token costs automatically." -ForegroundColor Cyan
        Write-Host "     Every Bash command is wrapped — higher savings on big outputs." -ForegroundColor Gray
    } catch {
        Write-Host "Error reading token savings: $_" -ForegroundColor Red
    }
}

# ─── Router ──────────────────────────────────────────────────────────────────
$command = $args[0]
if (-not $command) { Show-Help; exit 0 }

switch ($command.ToLower()) {
    'check'       { $exitCode = Invoke-Check }
    'status'      { Invoke-Status; $exitCode = 0 }
    'fix' {
        $target = $args[1]
        if (-not $target) { Write-Host "Specify: settings or scripts"; exit 1 }
        switch ($target.ToLower()) {
            'settings' { Invoke-FixSettings; $exitCode = 0 }
            'scripts'  { Invoke-FixScripts; $exitCode = 0 }
            default    { Write-Host "Unknown fix target: $target (use: settings, scripts)"; $exitCode = 1 }
        }
    }
    'audit' {
        $target = $args[1]
        if (-not $target) { Write-Host "Specify: scripts or md"; exit 1 }
        switch ($target.ToLower()) {
            'scripts' { Invoke-AuditScripts; $exitCode = 0 }
            'md'      { Invoke-AuditMd; $exitCode = 0 }
            default   { Write-Host "Unknown audit target: $target (use: scripts, md)"; $exitCode = 1 }
        }
    }
    'sync'         { Invoke-Sync; $exitCode = 0 }
    'tokens'       { Invoke-Tokens; $exitCode = 0 }
    'optimize'     { Invoke-Optimize; $exitCode = 0 }
    'system-check' { Invoke-SystemCheck; $exitCode = 0 }
    'cleanup'      { Invoke-Cleanup; $exitCode = 0 }
    'integrity'    { Invoke-Integrity; $exitCode = 0 }
    'security'     { Invoke-Security; $exitCode = 0 }
    'game-mode'    { Invoke-GameMode; $exitCode = 0 }
    'dev-mode'     { Invoke-DevMode; $exitCode = 0 }
    'cycle'        { Invoke-Cycle; $exitCode = 0 }
    default        { Show-Help; $exitCode = 1 }
}

if ($Pause) {
    Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
    Read-Host | Out-Null
}
exit $exitCode
