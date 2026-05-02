<# 
.SYNOPSIS
    Validate Qwen Code settings.json integrity and restore from backup if corrupt.
.DESCRIPTION
    Checks C:\Users\Administrator\.qwen\settings.json for valid JSON and required sections.
    Maintains a .last-good backup and auto-restores on corruption.
    Designed for standalone use and callable from self-heal scripts.
.PARAMETER Quiet
    Silent on success, vocal only on failure (default for non-interactive use).
.PARAMETER Verbose
    Full diagnostic output including what was checked.
.PARAMETER Fix
    Attempt to fix corruption by restoring from .last-good backup.
.EXAMPLE
    .\validate-settings.ps1 -Quiet          # Silent on success, returns exit code
    .\validate-settings.ps1 -Verbose         # Full output
    .\validate-settings.ps1 -Fix            # Attempt restore from backup
.NOTES
    Exit codes: 0 = healthy, 1 = restored from backup, 2 = no backup available
#>

param(
    [switch]$Quiet,
    [switch]$Verbose,
    [switch]$Fix
)

$settingsPath = 'C:\Users\Administrator\.qwen\settings.json'
$backupPath = 'C:\Users\Administrator\.qwen\settings.json.last-good'
$requiredSections = @('modelProviders', 'env', 'security', 'mcpServers')

function Write-Message {
    param([string]$Message, [string]$ForegroundColor = 'White')
    if (-not $Quiet) { Write-Host $Message -ForegroundColor $ForegroundColor }
}

function Test-IsValidJson {
    param([string]$Path)
    try {
        $null = Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-HasRequiredSections {
    param([string]$Path)
    try {
        $config = Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        foreach ($section in $requiredSections) {
            if ($null -eq $config.$section) {
                if ($Verbose) { Write-Message "  Missing section: $section" -ForegroundColor Yellow }
                return $false
            }
        }
        return $true
    } catch {
        return $false
    }
}

function Backup-Settings {
    param([string]$Source, [string]$Dest)
    try {
        Copy-Item -Path $Source -Destination $Dest -Force -ErrorAction Stop
        if ($Verbose) { Write-Message "  Backup saved to: $Dest" -ForegroundColor Green }
        return $true
    } catch {
        Write-Message "  Failed to create backup: $_" -ForegroundColor Red
        return $false
    }
}

# ── Main logic ──

if (-not (Test-Path $settingsPath)) {
    Write-Message "ERROR: settings.json not found at $settingsPath" -ForegroundColor Red
    exit 2
}

if ($Fix -or $Verbose) {
    Write-Message "Validating: $settingsPath" -ForegroundColor Cyan
}

# Check if valid JSON with required sections
$isValidJson = Test-IsValidJson -Path $settingsPath
if ($isValidJson) {
    $hasSections = Test-HasRequiredSections -Path $settingsPath
} else {
    $hasSections = $false
}

if ($isValidJson -and $hasSections) {
    # Settings are valid -- update .last-good backup if different
    $shouldBackup = $true
    if (Test-Path $backupPath) {
        try {
            $currentHash = (Get-FileHash -Path $settingsPath -Algorithm SHA256).Hash
            $backupHash = (Get-FileHash -Path $backupPath -Algorithm SHA256).Hash
            if ($currentHash -eq $backupHash) {
                $shouldBackup = $false
            }
        } catch {
            if ($Verbose) { Write-Message "  Hash comparison failed, will re-backup" -ForegroundColor Yellow }
        }
    }

    if ($shouldBackup) {
        $null = Backup-Settings -Source $settingsPath -Dest $backupPath
    }

    if ($Verbose) { Write-Message "PASS: settings.json is valid" -ForegroundColor Green }
    exit 0
}

# ── Settings INVALID -- attempt recovery ──
Write-Message "FAIL: settings.json is corrupt or missing required sections" -ForegroundColor Yellow

if (Test-Path $backupPath) {
    Write-Message "  Backup found at: $backupPath" -ForegroundColor Cyan

    if ($Fix) {
        try {
            if ($Verbose) { Write-Message "  Restoring from backup..." -ForegroundColor Cyan }
            Copy-Item -Path $backupPath -Destination $settingsPath -Force -ErrorAction Stop

            # Verify restore
            $restoreValidJson = Test-IsValidJson -Path $settingsPath
            $restoreHasSections = Test-HasRequiredSections -Path $settingsPath
            if ($restoreValidJson -and $restoreHasSections) {
                Write-Message "OK: settings.json restored from .last-good backup" -ForegroundColor Green
                exit 1
            } else {
                Write-Message "ERROR: Restored file is also corrupt!" -ForegroundColor Red
                Write-Message "  Check manually: $settingsPath" -ForegroundColor Yellow
                exit 2
            }
        } catch {
            Write-Message "ERROR: Failed to restore backup: $_" -ForegroundColor Red
            exit 2
        }
    } else {
        Write-Message "  Run with -Fix to restore from backup" -ForegroundColor Yellow
        Write-Message "  Or manually: Copy-Item '$backupPath' '$settingsPath'" -ForegroundColor Gray
        exit 1
    }
} else {
    Write-Message "CRITICAL: No .last-good backup found" -ForegroundColor Red
    Write-Message "  Run 'self-heal fix settings' or manually recreate settings.json" -ForegroundColor Yellow
    exit 2
}
