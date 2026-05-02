# Qwen Code Plugin & Extension Update Manager
# Intelligent script to detect, check, and update Qwen Code, GSD, CE plugins, and related projects
#
# Usage:
#   .\update-plugins.ps1              - Check and update everything
#   .\update-plugins.ps1 -CheckOnly   - Just report what would update
#   .\update-plugins.ps1 -Force       - Force update even if up to date
#   .\update-plugins.ps1 -Item qwen   - Only update a specific item (qwen, gsd, ce, rooted-leader)

param(
    [switch]$CheckOnly,
    [switch]$Force,
    [string]$Item,           # "qwen", "gsd", "ce", "rooted-leader", or "" for all
    [switch]$ListItems,
    [switch]$Help
)

$ErrorActionPreference = "Continue"   # Don't stop on individual failures
$Global:exitCode = 0

# ── Paths ────────────────────────────────────────────────────────────────────
$ScriptsDir      = "C:\Users\Administrator\Scripts"
$LogDir          = Join-Path $ScriptsDir "logs"
$LogFile         = Join-Path $LogDir "plugin-update.log"
$QwenDir         = "C:\Users\Administrator\.qwen"

# ── Plugins / tools paths ────────────────────────────────────────────────────
$CeExtensionDir  = [System.IO.Path]::Combine($QwenDir, "extensions", "compound-engineering")
$GSDVersionFile  = [System.IO.Path]::Combine($QwenDir, "get-shit-done", "VERSION")
$GSDWorkflowDir  = [System.IO.Path]::Combine($QwenDir, "get-shit-done", "workflows")
$RootedLeaderDir = "C:\Users\Administrator\Documents\Projects\rooted-leader-site"

# ── Colors ───────────────────────────────────────────────────────────────────
$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Header  = "Magenta"
    Muted   = "DarkGray"
}

# =============================================================================
#  HELPERS
# =============================================================================

function Write-Color {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logLine -ErrorAction SilentlyContinue
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Color $Message -Color $Colors.Header
    Write-Log $Message
}

function Write-Result {
    param([string]$Message, [bool]$Success)
    if ($Success) {
        Write-Color "  [OK] $Message" -Color $Colors.Success
        Write-Log "$Message (OK)"
    } else {
        Write-Color "  [FAIL] $Message" -Color $Colors.Error
        Write-Log "$Message (FAIL)" -Level "ERROR"
        $Global:exitCode = 1
    }
}

function Write-Skip {
    param([string]$Reason)
    Write-Color "  [-] $Reason" -Color $Colors.Muted
    Write-Log "$Reason (SKIPPED)"
}

function Compare-SemVer {
    param([string]$Current, [string]$Latest)
    if (-not $Current -or -not $Latest) { return "unknown" }
    try {
        $cv = [Version]$Current
        $lv = [Version]$Latest
        if ($cv -lt $lv) { return "outdated" }
        if ($cv -gt $lv) { return "newer" }
        return "current"
    } catch {
        if ($Current -eq $Latest) { return "current" } else { return "unknown" }
    }
}

# =============================================================================
#  LOGGING SETUP
# =============================================================================

if (-not (Test-Path $LogDir)) {
    $null = New-Item -ItemType Directory -Path $LogDir -Force
}

$Global:sessionId = Get-Date -Format "yyyyMMdd-HHmmss"
$mode = if ($CheckOnly) { "CHECK-ONLY" } else { "UPDATE" }
Write-Host ""
Write-Color " Qwen Code Update Manager" -Color $Colors.Header
Write-Color " ==========================" -Color $Colors.Header
Write-Color " Mode: $mode  |  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Color $Colors.Info
Write-Host ""
Write-Log "=== SESSION START ($mode) ==="

# =============================================================================
#  HELP / LIST
# =============================================================================

function Show-Help {
    Write-Color "Usage:" -Color $Colors.Info
    Write-Host "  .\update-plugins.ps1 [options]"
    Write-Host ""
    Write-Color "Options:" -Color $Colors.Info
    Write-Host "  -CheckOnly       Just check for available updates, don't install"
    Write-Host "  -Force           Force update even if already up to date"
    Write-Host "  -Item <name>     Only update one item (qwen, gsd, ce, rooted-leader)"
    Write-Host "  -ListItems       List all tracked items and their versions"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Color "Items:" -Color $Colors.Info
    Write-Host "  qwen            Qwen Code CLI (npm global package)"
    Write-Host "  gsd             Get-Shit-Done workflow plugin (npm package)"
    Write-Host "  ce              Compound Engineering extension (GitHub release)"
    Write-Host "  rooted-leader   Rooted Leader Site (Firebase project)"
}

function Show-ItemList {
    Write-Color "Tracked Items:" -Color $Colors.Header
    Write-Color "==============" -Color $Colors.Header

    # Inline version detection (avoids PS function-scoping issues)
    $qwenVer = "unknown"
    $gsdVer  = "unknown"
    $ceVer   = "unknown"

    try {
        $v = npm list -g @qwen-code/qwen-code --depth=0 2>$null
        $vText = $v | Out-String
        if ($vText -match '@qwen-code/qwen-code@(\S+)') { $qwenVer = $Matches[1] }
    } catch {}

    if (Test-Path $GSDVersionFile) {
        try { $gsdVer = (Get-Content $GSDVersionFile -Raw).Trim() } catch {}
    }

    $pluginJson = [System.IO.Path]::Combine($CeExtensionDir, ".claude-plugin", "plugin.json")
    if (Test-Path $pluginJson) {
        try { $ceVer = (Get-Content $pluginJson -Raw | ConvertFrom-Json).version } catch {}
    }

    Write-Host ""
    Write-Color "  qwen            Qwen Code CLI" -Color $Colors.Info
    Write-Host "    Version: $qwenVer (installed)"
    Write-Host "    Source:  npm global @qwen-code/qwen-code"
    Write-Host "    Update:  npm install -g @qwen-code/qwen-code"
    Write-Host ""
    Write-Color "  gsd             Get-Shit-Done workflow plugin" -Color $Colors.Info
    Write-Host "    Version: $gsdVer (installed)"
    Write-Host "    Source:  npm package get-shit-done-cc"
    Write-Host "    Update:  npx -y get-shit-done-cc@latest --claude --global"
    Write-Host ""
    Write-Color "  ce              Compound Engineering extension" -Color $Colors.Info
    Write-Host "    Version: $ceVer (installed)"
    Write-Host "    Source:  GitHub EveryInc/compound-engineering-plugin"
    Write-Host "    Update:  git clone or download release tarball"
    Write-Host ""
    Write-Color "  rooted-leader   Rooted Leader Site" -Color $Colors.Info
    Write-Host "    Location: $RootedLeaderDir"
    Write-Host "    Checks:   git status, npm outdated, Firebase deploy"
    Write-Host ""
}

if ($Help) {
    Show-Help
    exit 0
}

if ($ListItems) {
    Show-ItemList
    exit 0
}

# =============================================================================
#  QWEN CODE UPDATE
# =============================================================================

function Get-QwenCurrentVersion {
    try {
        $v = npm list -g @qwen-code/qwen-code --depth=0 2>$null
        $vText = $v | Out-String
        if ($vText -match '@qwen-code/qwen-code@(\S+)') {
            return $Matches[1]
        }
    } catch {}
    return "unknown"
}

function Get-QwenLatestVersion {
    try {
        $ver = npm view @qwen-code/qwen-code version 2>$null
        if ($ver) { return $ver.Trim() }
    } catch {}
    return $null
}

function Update-Qwen {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[1/4] Qwen Code CLI"

    $currentVer = Get-QwenCurrentVersion
    Write-Host "  Current:  $currentVer"

    $latestVer = Get-QwenLatestVersion
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest Qwen Code version from npm" $false
        return
    }

    $status = Compare-SemVer -Current $currentVer -Latest $latestVer

    if ($status -eq "outdated" -or ($status -eq "current" -and $Force)) {
        $action = if ($status -eq "outdated") {
            "Update available: $currentVer -> $latestVer"
        } else {
            "Already current at $currentVer (forced reinstall)"
        }
        Write-Color "  > $action" -Color $Colors.Warning

        if ($CheckOnly) {
            Write-Color "    (skipped - CheckOnly)" -Color $Colors.Muted
            Write-Log "Qwen Code $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Running: npm install -g @qwen-code/qwen-code"
            $output = npm install -g @qwen-code/qwen-code 2>&1
            $exit = $LASTEXITCODE
            if ($exit -eq 0) {
                $newVer = Get-QwenCurrentVersion
                Write-Result "Updated to $newVer" $true
                Write-Log "Qwen Code updated: $currentVer -> $newVer"
            } else {
                Write-Result "npm install failed (exit $exit): $($output -join '; ')" $false
                Write-Log "Qwen Code update FAILED: npm exit $exit" -Level "ERROR"
            }
        } catch {
            Write-Result "Exception during update: $_" $false
            Write-Log "Qwen Code update exception: $_" -Level "ERROR"
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

# =============================================================================
#  GSD (GET-SHIT-DONE) UPDATE
# =============================================================================

function Get-GSDCurrentVersion {
    if (Test-Path $GSDVersionFile) {
        try {
            $ver = (Get-Content $GSDVersionFile -Raw).Trim()
            if ($ver -match '^\d+\.\d+\.\d+') { return $ver }
        } catch {}
    }
    return "unknown"
}

function Get-GSDLatestVersion {
    try {
        $ver = npm view get-shit-done-cc version 2>$null
        if ($ver) { return $ver.Trim() }
    } catch {}
    return $null
}

function Update-GSD {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[2/4] Get-Shit-Done (GSD)"

    $currentVer = Get-GSDCurrentVersion
    Write-Host "  Current:  $currentVer"

    $latestVer = Get-GSDLatestVersion
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest GSD version from npm" $false
        return
    }

    $status = Compare-SemVer -Current $currentVer -Latest $latestVer

    if ($status -eq "outdated" -or ($status -eq "current" -and $Force)) {
        $action = if ($status -eq "outdated") {
            "Update available: $currentVer -> $latestVer"
        } else {
            "Already current at $currentVer (forced reinstall)"
        }
        Write-Color "  > $action" -Color $Colors.Warning

        if ($CheckOnly) {
            Write-Color "    (skipped - CheckOnly)" -Color $Colors.Muted
            Write-Log "GSD $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Running: npx -y get-shit-done-cc@latest --claude --global"
            $output = npx -y get-shit-done-cc@latest --claude --global 2>&1
            $exit = $LASTEXITCODE
            if ($exit -eq 0) {
                $newVer = Get-GSDCurrentVersion
                Write-Result "Updated to $newVer" $true
                Write-Log "GSD updated: $currentVer -> $newVer"
            } else {
                Write-Result "GSD update failed (exit $exit): $($output -join '; ')" $false
                Write-Log "GSD update FAILED: npx exit $exit" -Level "ERROR"
            }
        } catch {
            Write-Result "Exception during GSD update: $_" $false
            Write-Log "GSD update exception: $_" -Level "ERROR"
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

# =============================================================================
#  COMPOUND ENGINEERING (CE) EXTENSION UPDATE
# =============================================================================

function Get-CECurrentVersion {
    $pluginJson = [System.IO.Path]::Combine($CeExtensionDir, ".claude-plugin", "plugin.json")
    $qwenJson   = Join-Path $CeExtensionDir "qwen-extension.json"

    foreach ($path in @($pluginJson, $qwenJson)) {
        if (Test-Path $path) {
            try {
                $json = Get-Content $path -Raw | ConvertFrom-Json
                if ($json.version) { return $json.version }
            } catch {}
        }
    }
    return "unknown"
}

function Get-CELatestVersion {
    try {
        # Optimized: accept any media type; use Invoke-WebRequest with -UseBasicParsing for better compat
        $url = "https://api.github.com/repos/EveryInc/compound-engineering-plugin/releases/latest"
        $response = Invoke-RestMethod -Uri $url -Headers @{ "Accept" = "application/vnd.github.v3+json" } -UseBasicParsing -ErrorAction Stop
        $tag = $response.tag_name
        if ($tag -match 'compound-engineering-v?(\d+\.\d+\.\d+)') {
            return $Matches[1]
        }
        # Fallback: try stripping prefix
        $tag -replace '^compound-engineering-v', '' -replace '^v', ''
    } catch {
        return $null
    }
}

function Update-CE {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[3/4] Compound Engineering (CE)"

    $currentVer = Get-CECurrentVersion
    Write-Host "  Current:  $currentVer (extension)"
    Write-Host "  Source:   EveryInc/compound-engineering-plugin"

    $latestVer = Get-CELatestVersion
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest CE release from GitHub" $false
        return
    }

    $status = Compare-SemVer -Current $currentVer -Latest $latestVer

    if ($status -eq "outdated") {
        Write-Color "  > Update available: $currentVer -> $latestVer" -Color $Colors.Warning

        if ($CheckOnly) {
            Write-Color "    (skipped - CheckOnly)" -Color $Colors.Muted
            Write-Log "CE $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Downloading CE v$latestVer release from GitHub..."

            # Download the release zip to a temp location
            $tempDir = Join-Path $env:TEMP "ce-update-$Global:sessionId"
            $null = New-Item -ItemType Directory -Path $tempDir -Force

            $zipUrl = "https://api.github.com/repos/EveryInc/compound-engineering-plugin/zipball/compound-engineering-v$latestVer"
            $zipPath = Join-Path $tempDir "compound-engineering.zip"

            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
            Write-Host "    Downloaded to $zipPath"

            # Extract to temp
            $extractDir = Join-Path $tempDir "extracted"
            $null = New-Item -ItemType Directory -Path $extractDir -Force
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

            # Find the actual repo directory (GitHub zipballs wrap in a subfolder)
            $repoDir = $null
            $children = Get-ChildItem $extractDir -Directory
            if ($children.Count -eq 1) {
                $repoDir = $children[0].FullName
            } elseif ($children.Count -gt 1) {
                # Try to find the one that has .claude-plugin or similar
                foreach ($child in $children) {
                    if (Test-Path (Join-Path $child.FullName ".claude-plugin")) {
                        $repoDir = $child.FullName
                        break
                    }
                }
                if (-not $repoDir) { $repoDir = $children[0].FullName }
            }

            if (-not $repoDir) {
                Write-Result "Could not find repo directory in extracted zip" $false
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                return
            }

            # Copy the extension files into place
            $sourceExtDir = [System.IO.Path]::Combine($repoDir, "plugins", "compound-engineering")
            if (-not (Test-Path $sourceExtDir)) {
                # If no plugins/compound-engineering, use the repo root
                $sourceExtDir = $repoDir
            }

            # Validate: check for required metadata
            $validatePaths = @(
                (Join-Path (Join-Path $sourceExtDir ".claude-plugin") "plugin.json"),
                (Join-Path $sourceExtDir "qwen-extension.json")
            )
            $valid = $false
            foreach ($vp in $validatePaths) {
                if (Test-Path $vp) { $valid = $true; break }
            }

            if (-not $valid) {
                Write-Result "Downloaded release doesn't contain CE extension metadata" $false
                Write-Host "    Expected in: $sourceExtDir" -ForegroundColor DarkGray
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                return
            }

            # Backup current CE extension before replacing
            $backupDir = [System.IO.Path]::Combine($ScriptsDir, "backups", "compound-engineering-$currentVer")
            $null = New-Item -ItemType Directory -Path $backupDir -Force -ErrorAction SilentlyContinue
            Copy-Item -Path "$CeExtensionDir\*" -Destination $backupDir -Recurse -Force
            Write-Host "    Backed up current version to $backupDir"

            # Replace extension files (preserving .qwen-extension-install.json)
            $installMeta = Join-Path $CeExtensionDir ".qwen-extension-install.json"
            $installMetaContent = $null
            if (Test-Path $installMeta) {
                $installMetaContent = Get-Content $installMeta -Raw
            }

            # Remove old extension and copy new
            Remove-Item -Path "$CeExtensionDir\*" -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item -Path "$sourceExtDir\*" -Destination $CeExtensionDir -Recurse -Force

            # Restore install metadata
            if ($installMetaContent) {
                Set-Content -Path $installMeta -Value $installMetaContent
            }

            # Update version in qwen-extension.json
            $qwenJsonPath = Join-Path $CeExtensionDir "qwen-extension.json"
            if (Test-Path $qwenJsonPath) {
                $qwenJson = Get-Content $qwenJsonPath -Raw | ConvertFrom-Json
                $qwenJson.version = $latestVer
                $qwenJson | ConvertTo-Json -Compress | Set-Content -Path $qwenJsonPath
            }

            # Cleanup temp
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

            $newVer = Get-CECurrentVersion
            Write-Result "Updated to $newVer" $true
            Write-Log "CE updated: $currentVer -> $newVer"
            Write-Color "  !! Restart Qwen Code to load the updated extension" -Color $Colors.Warning

        } catch {
            Write-Result "Exception during CE update: $_" $false
            Write-Log "CE update exception: $_" -Level "ERROR"
            # Attempt cleanup
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } elseif ($status -eq "newer") {
        Write-Color "  > Local v$currentVer is newer than latest v$latestVer (dev/pre-release)" -Color $Colors.Warning
        Write-Result "Dev version detected, no update needed" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

# =============================================================================
#  ROOTED LEADER SITE CHECK
# =============================================================================

function Check-RootedLeader {
    param([bool]$CheckOnly)

    Write-Step "[4/4] Rooted Leader Site"

    if (-not (Test-Path $RootedLeaderDir)) {
        Write-Skip "Project directory not found at $RootedLeaderDir"
        return
    }

    $allOk = $true

    # --- Git status check ---
    try {
        Push-Location $RootedLeaderDir
        $gitStatus = git status --porcelain 2>&1
        $exitGit = $LASTEXITCODE

        if ($exitGit -ne 0) {
            Write-Result "Not a git repository or git not available" $false
            $allOk = $false
        } elseif ([string]::IsNullOrWhiteSpace($gitStatus)) {
            Write-Result "Working tree is clean" $true
            Write-Log "Rooted Leader: git working tree clean"
        } else {
            $modifiedCount = ($gitStatus | Where-Object { $_ -match '^[ MARC]' }).Count
            $untrackedCount = ($gitStatus | Where-Object { $_ -match '^\?\?' }).Count
            Write-Color "  > Git working tree has changes:" -Color $Colors.Warning
            Write-Color "    Modified/staged: $modifiedCount changes" -Color $Colors.Warning
            Write-Color "    Untracked: $untrackedCount new files" -Color $Colors.Warning
            Write-Host ""
            Write-Host "    Files:" -ForegroundColor DarkGray
            $gitStatus | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
            Write-Log "Rooted Leader: git working tree dirty ($modifiedCount modified, $untrackedCount untracked)"
        }
        Pop-Location
    } catch {
        Write-Result "Exception checking git status: $_" $false
        $allOk = $false
        try { Pop-Location } catch {}
    }

    # --- npm outdated check ---
    try {
        Push-Location $RootedLeaderDir
        $npmOutdated = npm outdated --json 2>&1
        $exitNpm = $LASTEXITCODE

        if ($exitNpm -eq 0) {
            Write-Result "All npm dependencies up to date" $true
            Write-Log "Rooted Leader: npm dependencies current"
        } elseif ($exitNpm -eq 1) {
            # npm outdated returns exit code 1 when there ARE outdated packages
            Write-Color "  > Some npm dependencies are outdated:" -Color $Colors.Warning

            $outdatedJson = $npmOutdated | Out-String | ConvertFrom-Json
            $outdatedObj = @{}
            if ($outdatedJson -is [PSCustomObject]) {
                $outdatedJson.PSObject.Properties | ForEach-Object {
                    $outdatedObj[$_.Name] = @{
                        current = $_.Value.current
                        wanted  = $_.Value.wanted
                        latest  = $_.Value.latest
                    }
                    Write-Host "    $($_.Name): $($_.Value.current) -> $($_.Value.latest)" -ForegroundColor DarkGray
                }
            }

            if (-not $CheckOnly) {
                Write-Host "  Running: npm update (safe updates only)"
                $updateOut = npm update 2>&1
                $updateExit = $LASTEXITCODE
                if ($updateExit -eq 0) {
                    Write-Result "npm update completed" $true
                    Write-Log "Rooted Leader: npm update ran successfully"
                } else {
                    Write-Result "npm update had issues (exit $updateExit)" $false
                    Write-Log "Rooted Leader: npm update exit $updateExit" -Level "ERROR"
                    $allOk = $false
                }
            } else {
                Write-Color "    (skipped - CheckOnly)" -Color $Colors.Muted
                Write-Log "Rooted Leader: npm outdated packages found (would update, skipped -CheckOnly)"
            }
        } else {
            Write-Result "npm outdated check failed (exit $exitNpm)" $false
            Write-Log "Rooted Leader: npm outdated exit $exitNpm" -Level "ERROR"
            $allOk = $false
        }
        Pop-Location
    } catch {
        # It's common for npm outdated to fail in non-trivial ways, don't fail hard
        Write-Color "  [-] npm outdated check skipped: $_" -Color $Colors.Muted
        try { Pop-Location } catch {}
    }

    # --- Firebase deployment check ---
    try {
        Push-Location $RootedLeaderDir
        $firebaseTools = where firebase 2>$null
        if ($LASTEXITCODE -eq 0) {
            $firebaseVer = firebase --version 2>$null
            Write-Host "  Firebase CLI: $firebaseVer" -ForegroundColor DarkGray
            Write-Log "Rooted Leader: Firebase CLI $firebaseVer available"
        } else {
            Write-Color "  [-] Firebase CLI not found on PATH" -Color $Colors.Muted
            Write-Log "Rooted Leader: Firebase CLI not available"
        }
        Pop-Location
    } catch {
        try { Pop-Location } catch {}
    }

    if ($allOk) {
        Write-Result "All checks passed" $true
    }
}

# =============================================================================
#  MAIN EXECUTION
# =============================================================================

try {
    # Determine which items to process
    $itemsToProcess = @()

    if ($Item) {
        switch ($Item.ToLower()) {
            "qwen"          { $itemsToProcess = @("qwen") }
            "gsd"           { $itemsToProcess = @("gsd") }
            "ce"            { $itemsToProcess = @("ce") }
            "rooted-leader" { $itemsToProcess = @("rooted-leader") }
            default {
                Write-Color "Unknown item: $Item. Valid values: qwen, gsd, ce, rooted-leader" -Color $Colors.Error
                exit 1
            }
        }
    } else {
        $itemsToProcess = @("qwen", "gsd", "ce", "rooted-leader")
    }

    $hasUpdates = $false

    if ($itemsToProcess -contains "qwen") {
        Update-Qwen -CheckOnly $CheckOnly -Force $Force
        if (-not $CheckOnly -and (Get-QwenCurrentVersion) -ne (Get-QwenLatestVersion)) { $hasUpdates = $true }
    }

    if ($itemsToProcess -contains "gsd") {
        Update-GSD -CheckOnly $CheckOnly -Force $Force
        if (-not $CheckOnly -and (Get-GSDCurrentVersion) -ne (Get-GSDLatestVersion)) { $hasUpdates = $true }
    }

    if ($itemsToProcess -contains "ce") {
        Update-CE -CheckOnly $CheckOnly -Force $Force
        if (-not $CheckOnly -and (Get-CECurrentVersion) -ne (Get-CELatestVersion)) { $hasUpdates = $true }
    }

    if ($itemsToProcess -contains "rooted-leader") {
        Check-RootedLeader -CheckOnly $CheckOnly
    }

    # Summary
    Write-Host ""
    Write-Color "============================================" -Color $Colors.Header
    if ($CheckOnly) {
        Write-Color " CHECK COMPLETE - Run without -CheckOnly to apply updates" -Color $Colors.Info
    } else {
        Write-Color " UPDATE COMPLETE" -Color $Colors.Success
        if ($hasUpdates) {
            Write-Color " !! Some updates require restarting Qwen Code" -Color $Colors.Warning
        }
    }
    Write-Color " Log: $LogFile" -Color $Colors.Muted
    Write-Color "============================================" -Color $Colors.Header
    Write-Host ""

    Write-Log "=== SESSION END (exit=$Global:exitCode) ==="

} catch {
    Write-Color "Unhandled error: $_" -Color $Colors.Error
    Write-Log "Unhandled exception: $_" -Level "ERROR"
    exit 1
}

exit $Global:exitCode
