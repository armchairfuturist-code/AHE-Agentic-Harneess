# Qwen Code Plugin and Extension Update Manager
# Intelligent script to detect, check, and update Qwen Code, GSD, CE plugins, and related projects
#
# Usage:
#   .\update-plugins.ps1              - Check and update everything
#   .\update-plugins.ps1 -CheckOnly   - Just report what would update
#   .\update-plugins.ps1 -Force       - Force update even if up to date
#   .\update-plugins.ps1 -Item qwen   - Only update a specific item
#   .\update-plugins.ps1 -ListItems   - Show version table for all tools
#
# Items: qwen, gsd, ce, rooted-leader, rtk, context-mode, autocontext,
#        agent-browser, squeez, deepseek-tui, pi-acp, context7-mcp,
#        chrome-devtools-mcp, notebooklm-mcp

param(
    [switch]$CheckOnly,
    [switch]$Force,
    [string]$Item,           # Single item name, or "" for all
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
$GSDVersionFile  = [System.IO.Path]::Combine($env:USERPROFILE, ".claude", "get-shit-done", "VERSION")
$GSDWorkflowDir  = [System.IO.Path]::Combine($env:USERPROFILE, ".claude", "get-shit-done", "workflows")
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
    Write-Host "  -Item <name>     Only update one item"
    Write-Host "  -ListItems       List all tracked items and their versions"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Color "Items:" -Color $Colors.Info
    Write-Host "  qwen              Qwen Code CLI (npm global package)"
    Write-Host "  gsd               Get-Shit-Done workflow plugin (npm package)"
    Write-Host "  ce                Compound Engineering extension (GitHub release)"
    Write-Host "  rooted-leader     Rooted Leader Site (Firebase project)"
    Write-Host "  rtk               RTK Token Saver CLI (GitHub release)"
    Write-Host "  context-mode      Context-Mode MCP server (npm package)"
    Write-Host "  autocontext       AutoContext Python package (pip)"
    Write-Host "  agent-browser     Agent Browser CLI (npm package)"
    Write-Host "  squeez            Squeez token compressor (GitHub binary)"
    Write-Host "  deepseek-tui      Deepseek TUI CLI (npm global package)"
    Write-Host "  pi-acp            pi ACP SDK (npm global package)"
    Write-Host "  context7-mcp      Context7 docs MCP (mcp-local node_modules)"
    Write-Host "  chrome-devtools-mcp Chrome DevTools MCP (mcp-local node_modules)"
    Write-Host "  notebooklm-mcp    NotebookLM MCP (pip package)"
}

function Show-ItemList {
    Write-Color "Tracked Items:" -Color $Colors.Header
    Write-Color "==============" -Color $Colors.Header

    # Inline version detection (avoids PS function-scoping issues)
    $qwenVer = "unknown"
    $gsdVer  = "unknown"
    $ceVer   = "unknown"
    $rtkVer  = "unknown"
    $cmVer   = "unknown"
    $acVer   = "unknown"
    $abVer   = "unknown"
    $sqVer   = "unknown"
    $dstVer  = "unknown"
    $paVer   = "unknown"
    $c7Ver   = "unknown"
    $cdVer   = "unknown"
    $agVer   = "unknown"
    $nbVer   = "unknown"

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

    try {
        $rv = rtk --version 2>$null
        if ($rv -match 'rtk (\d+\.\d+\.\d+)') { $rtkVer = $Matches[1] }
    } catch {}

    try {
        $cv = npm list -g context-mode --depth=0 2>$null
        $cvt = $cv | Out-String
        if ($cvt -match 'context-mode@(\d+\.\d+\.\d+)') { $cmVer = $Matches[1] }
    } catch {}

    try {
        $av = pip show autocontext 2>$null | Out-String
        if ($av -match 'Version:\s+(\S+)') { $acVer = $Matches[1] }
    } catch {}

    try {
        $abv = npm list -g agent-browser --depth=0 2>$null
        $abvt = $abv | Out-String
        if ($abvt -match 'agent-browser@(\S+)') { $abVer = $Matches[1] }
    } catch {}

    # Squeez — native binary version
    try {
        $sq = squeez --version 2>$null
        if ($sq -match '\d+\.\d+\.\d+') { $sqVer = $Matches[0] }
    } catch {}

    # Deepseek TUI
    try {
        $ds = deepseek-tui --version 2>$null | Out-String
        if ($ds -match 'v?(\d+\.\d+\.\d+)') { $dstVer = $Matches[1] }
    } catch {}

    # pi-acp
    try {
        $pa = npm list -g pi-acp --depth=0 2>$null | Out-String
        if ($pa -match 'pi-acp@(\d+\.\d+\.\d+)') { $paVer = $Matches[1] }
    } catch {}

    # context7 MCP (local mcp install)
    try {
        $c7pkg = "$env:USERPROFILE\.qwen\mcp-local\node_modules\@upstash\context7-mcp\package.json"
        if (Test-Path $c7pkg) { $c7Ver = (Get-Content $c7pkg -Raw | ConvertFrom-Json).version }
    } catch {}

    # chrome-devtools MCP (local mcp install)
    try {
        $cdpkg = "$env:USERPROFILE\.qwen\mcp-local\node_modules\chrome-devtools-mcp\package.json"
        if (Test-Path $cdpkg) { $cdVer = (Get-Content $cdpkg -Raw | ConvertFrom-Json).version }
    } catch {}

    # agentmemory MCP — via npx, check npm registry version (always latest)
    try {
        $agVer = npm view @agentmemory/mcp version 2>$null
    } catch {}

    # notebooklm-mcp (pip)
    try {
        $nb = pip show notebooklm-mcp-cli 2>$null | Out-String
        if ($nb -match 'Version:\s+(\S+)') { $nbVer = $Matches[1] }
    } catch {}

    Write-Host ""
    Write-Color "  qwen            Qwen Code CLI" -Color $Colors.Info
    Write-Host "    Version: $qwenVer (installed)"
    Write-Host "    Source:  npm global @qwen-code/qwen-code"
    Write-Host "    Update:  npm install -g @qwen-code/qwen-code"
    Write-Host ""
    Write-Color "  gsd             Get-Shit-Done workflow plugin" -Color $Colors.Info
    Write-Host "    Version: $gsdVer (installed)"
    Write-Host "    Source:  npm package get-shit-done-cc"
    Write-Host "    Update:  npx -y get-shit-done-cc@latest --qwen --global"
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
    Write-Color "  rtk             RTK Token Saver" -Color $Colors.Info
    Write-Host "    Version: $rtkVer (installed)"
    Write-Host "    Source:  GitHub rtk-ai/rtk"
    Write-Host "    Update:  .\update-plugins.ps1 (auto)"
    Write-Host ""
    Write-Color "  context-mode    Context-Mode MCP server" -Color $Colors.Info
    Write-Host "    Version: $cmVer (installed)"
    Write-Host "    Source:  npm package context-mode"
    Write-Host "    Update:  npm install -g context-mode@latest"
    Write-Host ""
    Write-Color "  autocontext     AutoContext Python package" -Color $Colors.Info
    Write-Host "    Version: $acVer (installed)"
    Write-Host "    Source:  pip / greyhaven-ai/autocontext"
    Write-Host "    Update:  pip install -U autocontext"
    Write-Host ""
    Write-Color "  agent-browser   Agent Browser CLI" -Color $Colors.Info
    Write-Host "    Version: $abVer (installed)"
    Write-Host "    Source:  npm package agent-browser"
    Write-Host "    Update:  npm install -g agent-browser@latest"
    Write-Host ""
    Write-Color "  squeez          Squeez token compressor" -Color $Colors.Info
    Write-Host "    Version: $sqVer (installed)"
    Write-Host "    Source:  GitHub claudioemmanuel/squeez"
    Write-Host "    Update:  download latest squeez-windows-x86_64.exe from releases"
    Write-Host ""
    Write-Color "  deepseek-tui    Deepseek TUI CLI" -Color $Colors.Info
    Write-Host "    Version: $dstVer (installed)"
    Write-Host "    Source:  npm global deepseek-tui"
    Write-Host "    Update:  npm update -g deepseek-tui"
    Write-Host ""
    Write-Color "  pi-acp          pi ACP SDK" -Color $Colors.Info
    Write-Host "    Version: $paVer (installed)"
    Write-Host "    Source:  npm global pi-acp"
    Write-Host "    Update:  npm update -g pi-acp"
    Write-Host ""
    Write-Color "  context7-mcp    Context7 docs MCP" -Color $Colors.Info
    Write-Host "    Version: $c7Ver (installed)"
    Write-Host "    Source:  @upstash/context7-mcp (mcp-local)"
    Write-Host "    Update:  npm install @upstash/context7-mcp@latest in mcp-local"
    Write-Host ""
    Write-Color "  chrome-devtools-mcp Chrome DevTools MCP" -Color $Colors.Info
    Write-Host "    Version: $cdVer (installed)"
    Write-Host "    Source:  chrome-devtools-mcp (mcp-local)"
    Write-Host "    Update:  npm install chrome-devtools-mcp@latest in mcp-local"
    Write-Host ""
    Write-Color "  agentmemory-mcp AgentMemory MCP" -Color $Colors.Info
    Write-Host "    Version: $agVer (npm registry, fetched via npx)"
    Write-Host "    Source:  @agentmemory/mcp (npx)"
    Write-Host "    Update:  npx -y @agentmemory/mcp@latest"
    Write-Host ""
    Write-Color "  notebooklm-mcp  NotebookLM MCP" -Color $Colors.Info
    Write-Host "    Version: $nbVer (installed)"
    Write-Host "    Source:  pip package notebooklm-mcp"
    Write-Host "    Update:  pip install -U notebooklm-mcp"
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

    Write-Step "[1/14] Qwen Code CLI"

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

function Sync-GSD {
    param([string]$LatestVer)
    Write-Host "  Syncing GSD to Qwen Code path..."
    try {
        $src = "$env:USERPROFILE\.claude\get-shit-done"
        $dst = "$env:USERPROFILE\.qwen\get-shit-done"
        if (Test-Path "$src\VERSION") {
            # Backup current Qwen GSD first
            if (Test-Path $dst) {
                Copy-Item -Path "$dst\*" -Destination "$dst-backup" -Recurse -Force -ErrorAction SilentlyContinue
            }
            # Ensure destination directory exists before copying
            $null = New-Item -ItemType Directory -Path $dst -Force -ErrorAction SilentlyContinue
            Copy-Item -Path "$src\*" -Destination $dst -Recurse -Force
            Write-Result "Synced from .claude to Qwen Code (v$LatestVer)" $true
        } else {
            Write-Result "Source not found at $src" $false
        }
    } catch {
        Write-Result "GSD sync failed: $_" $false
    }
}
function Update-GSD {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[2/14] Get-Shit-Done (GSD)"

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
                Sync-GSD -LatestVer $newVer
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

    Write-Step "[3/14] Compound Engineering (CE)"

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

    Write-Step "[4/14] Rooted Leader Site"

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
#  RTK (RUST TOKEN KILLER) UPDATE
# =============================================================================

function Get-RTKCurrentVersion {
    try {
        $v = rtk --version 2>$null
        if ($v -match 'rtk (\d+\.\d+\.\d+)') { return $Matches[1] }
    } catch {}
    return "unknown"
}

function Get-RTKLatestVersion {
    try {
        $url = "https://api.github.com/repos/rtk-ai/rtk/releases/latest"
        $response = Invoke-RestMethod -Uri $url -Headers @{ "Accept" = "application/vnd.github.v3+json" } -UseBasicParsing -ErrorAction Stop
        $tag = $response.tag_name
        if ($tag -match 'v?(\d+\.\d+\.\d+)') { return $Matches[1] }
        return ($tag -replace '^v', '')
    } catch { return $null }
}

function Update-RTK {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[5/14] RTK Token Saver"

    $currentVer = Get-RTKCurrentVersion
    Write-Host "  Current:  $currentVer"
    Write-Host "  Source:   GitHub rtk-ai/rtk"

    $latestVer = Get-RTKLatestVersion
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest RTK release from GitHub" $false
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
            Write-Log "RTK $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Downloading RTK v$latestVer from GitHub releases..."
            $rtkDir = "$env:LOCALAPPDATA\rtk"
            $null = New-Item -ItemType Directory -Path $rtkDir -Force -ErrorAction SilentlyContinue

            # Download latest binary for Windows
            $url = "https://github.com/rtk-ai/rtk/releases/download/v$latestVer/rtk-x86_64-pc-windows-msvc.zip"
            $zipPath = Join-Path $env:TEMP "rtk-$latestVer.zip"
            try {
                Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
            } catch {
                # Try without v prefix
                $url2 = "https://github.com/rtk-ai/rtk/releases/download/$latestVer/rtk-x86_64-pc-windows-msvc.zip"
                Invoke-WebRequest -Uri $url2 -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
            }

            # Extract and replace
            $extractDir = Join-Path $env:TEMP "rtk-extract-$Global:sessionId"
            $null = New-Item -ItemType Directory -Path $extractDir -Force -ErrorAction SilentlyContinue
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

            $rtkExe = Get-ChildItem $extractDir -Recurse -Filter "rtk.exe" | Select-Object -First 1
            if ($rtkExe) {
                # Detect the RTK binary that's actually on PATH (the one Get-Command resolves)
                $activeRtk = (Get-Command rtk -ErrorAction SilentlyContinue).Source
                if ($activeRtk -and (Test-Path $activeRtk)) {
                    $localBin = Split-Path $activeRtk -Parent
                } else {
                    $localBin = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
                    if (Test-Path "C:\Users\Administrator\.local\bin") {
                        $localBin = "C:\Users\Administrator\.local\bin"
                    }
                }
                Copy-Item -Path $rtkExe.FullName -Destination "$localBin\rtk.exe" -Force
                Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue

                $newVer = Get-RTKCurrentVersion
                Write-Result "Updated to $newVer" $true
                Write-Log "RTK updated: $currentVer -> $newVer (downloaded from GitHub)"
            } else {
                Write-Result "Could not find rtk.exe in downloaded archive" $false
                Write-Log "RTK update FAILED: binary not found in release" -Level "ERROR"
            }
        } catch {
            Write-Result "Exception during RTK update: $_" $false
            Write-Log "RTK update exception: $_" -Level "ERROR"
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

# =============================================================================
#  CONTEXT-MODE MCP UPDATE
# =============================================================================

function Get-ContextModeCurrentVersion {
    # Check local package.json first (more reliable than npm list -g)
    $localPkg = "C:\Python314\Lib\site-packages\nodejs_wheel\node_modules\context-mode\package.json"
    if (Test-Path $localPkg) {
        try {
            $pkg = Get-Content $localPkg -Raw | ConvertFrom-Json
            if ($pkg.version) { return $pkg.version }
        } catch {}
    }
    try {
        $v = npm list -g context-mode --depth=0 2>$null
        $vt = $v | Out-String
        if ($vt -match 'context-mode@(\d+\.\d+\.\d+)') { return $Matches[1] }
    } catch {}
    return "unknown"
}

function Get-ContextModeLatestVersion {
    try {
        $ver = npm view context-mode version 2>$null
        if ($ver) { return $ver.Trim() }
    } catch {}
    return $null
}

function Update-ContextMode {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[6/14] Context-Mode MCP"

    $currentVer = Get-ContextModeCurrentVersion
    Write-Host "  Current:  $currentVer"
    Write-Host "  Source:   npm package context-mode"

    $latestVer = Get-ContextModeLatestVersion
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest context-mode version from npm" $false
        return
    }

    $status = Compare-SemVer -Current $currentVer -Latest $latestVer

    if ($status -eq "outdated" -or $currentVer -eq "unknown" -or ($status -eq "current" -and $Force)) {
        $action = if ($status -eq "outdated") {
            "Update available: $currentVer -> $latestVer"
        } else {
            "Already current at $currentVer (forced reinstall)"
        }
        Write-Color "  > $action" -Color $Colors.Warning

        if ($CheckOnly) {
            Write-Color "    (skipped - CheckOnly)" -Color $Colors.Muted
            Write-Log "Context-Mode $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            # EBUSY workaround: install to temp prefix and copy key files
            Write-Host "  Installing context-mode v$latestVer (working around EBUSY)..."
            $tempPrefix = Join-Path $env:TEMP "cm-install-$Global:sessionId"
            $null = New-Item -ItemType Directory -Path $tempPrefix -Force -ErrorAction SilentlyContinue

            $output = npm install -g context-mode@latest --prefix $tempPrefix --no-optional 2>&1
            $exit = $LASTEXITCODE
            if ($exit -eq 0) {
                # Copy key files from temp install to real location
                $cmDir = "C:\Python314\Lib\site-packages\nodejs_wheel\node_modules\context-mode"
                $tempCmDir = Join-Path $tempPrefix "node_modules\context-mode"
                if (Test-Path $tempCmDir) {
                    # Backup/replace start.mjs and key JS bundles (skip locked .node files)
                    $keyFiles = @("start.mjs", "cli.bundle.mjs", "server.bundle.mjs", "package.json")
                    foreach ($f in $keyFiles) {
                        $src = Join-Path $tempCmDir $f
                        $dst = Join-Path $cmDir $f
                        if (Test-Path $src) {
                            Copy-Item -Path $src -Destination $dst -Force -ErrorAction SilentlyContinue
                        }
                    }
                    # Also copy hooks and configs
                    foreach ($sub in @("hooks", "configs", "skills")) {
                        $srcDir = Join-Path $tempCmDir $sub
                        $dstDir = Join-Path $cmDir $sub
                        if (Test-Path $srcDir) {
                            Copy-Item -Path "$srcDir\*" -Destination $dstDir -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }

                    $newVer = Get-ContextModeCurrentVersion
                    Write-Result "Updated to $newVer (key files)" $true
                    Write-Log "Context-Mode updated: $currentVer -> $newVer"
                    Write-Color "  !! Restart Qwen Code to fully load updated MCP server" -Color $Colors.Warning
                } else {
                    Write-Result "Temp install succeeded but module not found at $tempCmDir" $false
                }
                # Cleanup temp
                Remove-Item -Path $tempPrefix -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                $errLines = ($output | Select-String -Pattern 'error') -join '; '
                Write-Result "npm install failed (exit $exit): $errLines" $false
                Write-Log "Context-Mode update FAILED: npm exit $exit" -Level "ERROR"
                Remove-Item -Path $tempPrefix -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Result "Exception during context-mode update: $_" $false
            Write-Log "Context-Mode update exception: $_" -Level "ERROR"
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

# =============================================================================
#  AUTOCONTEXT UPDATE
# =============================================================================

function Get-AutoContextCurrentVersion {
    try {
        $av = pip show autocontext 2>$null | Out-String
        if ($av -match 'Version: (\S+)') { return $Matches[1] }
    } catch {}
    return "unknown"
}

function Get-AutoContextLatestVersion {
    try {
        $url = "https://pypi.org/pypi/autocontext/json"
        $response = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop
        return $response.info.version
    } catch { return $null }
}

function Update-AutoContext {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[7/14] AutoContext (Python)"

    $currentVer = Get-AutoContextCurrentVersion
    Write-Host "  Current:  $currentVer"
    Write-Host "  Source:   pip / greyhaven-ai/autocontext"

    $latestVer = Get-AutoContextLatestVersion
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest autocontext version from PyPI" $false
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
            Write-Log "AutoContext $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Running: pip install -U autocontext"
            $output = pip install -U autocontext 2>&1
            $exit = $LASTEXITCODE
            if ($exit -eq 0) {
                $newVer = Get-AutoContextCurrentVersion
                Write-Result "Updated to $newVer" $true
                Write-Log "AutoContext updated: $currentVer -> $newVer"
                Write-Color "  !! Restart Qwen Code to load updated Python module" -Color $Colors.Warning
            } else {
                Write-Result "pip install failed (exit $exit)" $false
                Write-Log "AutoContext update FAILED: pip exit $exit" -Level "ERROR"
            }
        } catch {
            Write-Result "Exception during autocontext update: $_" $false
            Write-Log "AutoContext update exception: $_" -Level "ERROR"
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

# =============================================================================
#  AGENT-BROWSER UPDATE
# =============================================================================

function Get-AgentBrowserCurrentVersion {
    try {
        $v = npm list -g agent-browser --depth=0 2>$null
        $vt = $v | Out-String
        if ($vt -match 'agent-browser@(\S+)') { return $Matches[1] }
    } catch {}
    return "unknown"
}

function Get-AgentBrowserLatestVersion {
    try {
        $ver = npm view agent-browser version 2>$null
        if ($ver) { return $ver.Trim() }
    } catch {}
    return $null
}

function Update-AgentBrowser {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[8/14] Agent Browser CLI"

    $currentVer = Get-AgentBrowserCurrentVersion
    Write-Host "  Current:  $currentVer"
    Write-Host "  Source:   npm package agent-browser"

    $latestVer = Get-AgentBrowserLatestVersion
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest agent-browser version from npm" $false
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
            Write-Log "Agent-Browser $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Running: npm install -g agent-browser@latest"
            $output = npm install -g agent-browser@latest 2>&1
            $exit = $LASTEXITCODE
            if ($exit -eq 0) {
                $newVer = Get-AgentBrowserCurrentVersion
                Write-Result "Updated to $newVer" $true
                Write-Log "Agent-Browser updated: $currentVer -> $newVer"
            } else {
                Write-Result "npm install failed (exit $exit)" $false
                Write-Log "Agent-Browser update FAILED: npm exit $exit" -Level "ERROR"
            }
        } catch {
            Write-Result "Exception during agent-browser update: $_" $false
            Write-Log "Agent-Browser update exception: $_" -Level "ERROR"
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

# =============================================================================
#  SQUEEZ UPDATE (native binary)
# =============================================================================

function Get-SqueezCurrentVersion {
    try {
        $sq = squeez --version 2>$null
        if ($sq -match '(\d+\.\d+\.\d+)') { return $Matches[1] }
    } catch {}
    return "unknown"
}

function Get-SqueezLatestVersion {
    try {
        $url = "https://api.github.com/repos/claudioemmanuel/squeez/releases/latest"
        $resp = Invoke-RestMethod -Uri $url -Headers @{ "Accept" = "application/vnd.github.v3+json" } -UseBasicParsing -ErrorAction Stop
        $tag = $resp.tag_name
        if ($tag -match 'v?(\d+\.\d+\.\d+)') { return $Matches[1] }
        return ($tag -replace '^v', '')
    } catch { return $null }
}

function Update-Squeez {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[9/14] Squeez Token Compressor"

    $currentVer = Get-SqueezCurrentVersion
    Write-Host "  Current:  $currentVer (binary)"
    Write-Host "  Source:   GitHub claudioemmanuel/squeez"

    $latestVer = Get-SqueezLatestVersion
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest squeez release from GitHub" $false
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
            Write-Log "Squeez $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Downloading squeez v$latestVer from GitHub releases..."
            $dlUrl = "https://github.com/claudioemmanuel/squeez/releases/download/v$latestVer/squeez-windows-x86_64.exe"
            $tmpExe = Join-Path $env:TEMP "squeez-$latestVer.exe"
            Invoke-WebRequest -Uri $dlUrl -OutFile $tmpExe -UseBasicParsing -ErrorAction Stop

            # Detect actual binary path (JS wrapper resolves from ~/.claude/squeez/bin/)
            $binaryDir = "$env:USERPROFILE\.claude\squeez\bin"
            $null = New-Item -ItemType Directory -Path $binaryDir -Force -ErrorAction SilentlyContinue
            Copy-Item -Path $tmpExe -Destination "$binaryDir\squeez.exe" -Force
            Remove-Item -Path $tmpExe -Force -ErrorAction SilentlyContinue

            $newVer = Get-SqueezCurrentVersion
            Write-Result "Updated to $newVer" $true
            Write-Log "Squeez updated: $currentVer -> $newVer (downloaded from GitHub)"
        } catch {
            Write-Result "Exception during squeez update: $_" $false
            Write-Log "Squeez update exception: $_" -Level "ERROR"
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

# =============================================================================
#  DEEPSEEK TUI & PI-ACP (npm global packages)
# =============================================================================

function Get-DeepseekTuiCurrentVersion {
    try {
        $v = deepseek-tui --version 2>$null | Out-String
        if ($v -match 'v?(\d+\.\d+\.\d+)') { return $Matches[1] }
    } catch {}
    return "unknown"
}

function Get-PiAcpCurrentVersion {
    try {
        $v = npm list -g pi-acp --depth=0 2>$null | Out-String
        if ($v -match 'pi-acp@(\d+\.\d+\.\d+)') { return $Matches[1] }
    } catch {}
    return "unknown"
}

function Get-NpmLatestVersion {
    param([string]$Package)
    try {
        $ver = npm view $Package version 2>$null
        if ($ver) { return $ver.Trim() }
    } catch {}
    return $null
}

function Update-SimpleNpmPackage {
    param([string]$Name, [string]$Package, [string]$DisplayLabel, [int]$Step, [int]$TotalSteps, [bool]$CheckOnly, [bool]$Force, [scriptblock]$GetVerFn)

    Write-Step "[$Step/$TotalSteps] $DisplayLabel"

    $currentVer = & $GetVerFn
    Write-Host "  Current:  $currentVer"
    Write-Host "  Source:   npm package $Package"

    $latestVer = Get-NpmLatestVersion -Package $Package
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest $Name version from npm" $false
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
            Write-Log "$Name $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Running: npm install -g $Package@latest"
            $output = npm install -g "$Package@latest" 2>&1
            $exit = $LASTEXITCODE
            if ($exit -eq 0) {
                $newVer = & $GetVerFn
                Write-Result "Updated to $newVer" $true
                Write-Log "$Name updated: $currentVer -> $newVer"
            } else {
                Write-Result "npm install failed (exit $exit): $($output -join '; ')" $false
                Write-Log "$Name update FAILED: npm exit $exit" -Level "ERROR"
            }
        } catch {
            Write-Result "Exception during $Name update: $_" $false
            Write-Log "$Name update exception: $_" -Level "ERROR"
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

# =============================================================================
#  MCP-LOCAL and PIP packages
# =============================================================================

function Get-LocalMcpVersion {
    param([string]$PackageName)
    $pkg = "$env:USERPROFILE\.qwen\mcp-local\node_modules\$PackageName\package.json"
    if (Test-Path $pkg) {
        try { return (Get-Content $pkg -Raw | ConvertFrom-Json).version } catch {}
    }
    return "unknown"
}

function Update-LocalMcpPackage {
    param([string]$Name, [string]$PackageName, [string]$DisplayLabel, [int]$Step, [int]$TotalSteps, [bool]$CheckOnly, [bool]$Force, [scriptblock]$GetVerFn)

    Write-Step "[$Step/$TotalSteps] $DisplayLabel"

    $currentVer = & $GetVerFn
    Write-Host "  Current:  $currentVer"
    Write-Host "  Source:   $PackageName (mcp-local)"

    $latestVer = Get-NpmLatestVersion -Package $PackageName
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest $Name version from npm" $false
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
            Write-Log "$Name $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Installing $PackageName@latest in mcp-local..."
            Push-Location "$env:USERPROFILE\.qwen\mcp-local"
            $output = npm install "$PackageName@latest" 2>&1
            $exit = $LASTEXITCODE
            Pop-Location
            if ($exit -eq 0) {
                $newVer = & $GetVerFn
                Write-Result "Updated to $newVer" $true
                Write-Log "$Name updated: $currentVer -> $newVer"
                Write-Color "  !! Restart Qwen Code to load updated MCP server" -Color $Colors.Warning
            } else {
                Write-Result "npm install failed (exit $exit): $($output -join '; ')" $false
                Write-Log "$Name update FAILED: npm exit $exit" -Level "ERROR"
            }
        } catch {
            Write-Result "Exception during $Name update: $_" $false
            Write-Log "$Name update exception: $_" -Level "ERROR"
            try { Pop-Location } catch {}
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

function Get-NotebookLmCurrentVersion {
    try {
        $nb = pip show notebooklm-mcp-cli 2>$null | Out-String
        if ($nb -match 'Version:\s+(\S+)') { return $Matches[1] }
    } catch {}
    return "unknown"
}

function Get-NotebookLmLatestVersion {
    try {
        $ver = pip index versions notebooklm-mcp-cli 2>$null | Out-String
        if ($ver -match 'Available versions: (.+)') {
            $versions = $Matches[1] -split ',\s*'
            return $versions[0].Trim()
        }
    } catch {}
    return $null
}

function Update-NotebookLmMcp {
    param([bool]$CheckOnly, [bool]$Force)

    Write-Step "[14/14] NotebookLM MCP"

    $currentVer = Get-NotebookLmCurrentVersion
    Write-Host "  Current:  $currentVer"
    Write-Host "  Source:   pip package notebooklm-mcp"

    $latestVer = Get-NotebookLmLatestVersion
    if ($latestVer -eq $null) { Write-Host "  Latest:   unknown" } else { Write-Host "  Latest:   $latestVer" }

    if (-not $latestVer) {
        Write-Result "Could not fetch latest notebooklm-mcp version from PyPI" $false
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
            Write-Log "NotebookLM-MCP $currentVer -> $latestVer (would update, skipped -CheckOnly)"
            return
        }

        try {
            Write-Host "  Running: pip install -U notebooklm-mcp"
            $output = pip install -U notebooklm-mcp 2>&1
            $exit = $LASTEXITCODE
            if ($exit -eq 0) {
                $newVer = Get-NotebookLmCurrentVersion
                Write-Result "Updated to $newVer" $true
                Write-Log "NotebookLM-MCP updated: $currentVer -> $newVer"
                Write-Color "  !! Restart Qwen Code to load updated MCP server" -Color $Colors.Warning
            } else {
                Write-Result "pip install failed (exit $exit)" $false
                Write-Log "NotebookLM-MCP update FAILED: pip exit $exit" -Level "ERROR"
            }
        } catch {
            Write-Result "Exception during notebooklm-mcp update: $_" $false
            Write-Log "NotebookLM-MCP update exception: $_" -Level "ERROR"
        }
    } elseif ($status -eq "current") {
        Write-Result "Already up to date at v$currentVer" $true
    } else {
        Write-Skip "Version comparison inconclusive (current=$currentVer, latest=$latestVer)"
    }
}

try {
    # Determine which items to process
    $itemsToProcess = @()

    if ($Item) {
        switch ($Item.ToLower()) {
            "qwen"              { $itemsToProcess = @("qwen") }
            "gsd"               { $itemsToProcess = @("gsd") }
            "ce"                { $itemsToProcess = @("ce") }
            "rooted-leader"     { $itemsToProcess = @("rooted-leader") }
            "rtk"               { $itemsToProcess = @("rtk") }
            "context-mode"      { $itemsToProcess = @("context-mode") }
            "autocontext"       { $itemsToProcess = @("autocontext") }
            "agent-browser"     { $itemsToProcess = @("agent-browser") }
            "squeez"            { $itemsToProcess = @("squeez") }
            "deepseek-tui"      { $itemsToProcess = @("deepseek-tui") }
            "pi-acp"            { $itemsToProcess = @("pi-acp") }
            "context7-mcp"      { $itemsToProcess = @("context7-mcp") }
            "chrome-devtools-mcp" { $itemsToProcess = @("chrome-devtools-mcp") }
            "notebooklm-mcp"    { $itemsToProcess = @("notebooklm-mcp") }
            default {
                Write-Color "Unknown item: $Item. Valid values: qwen, gsd, ce, rooted-leader, rtk, context-mode, autocontext, agent-browser, squeez, deepseek-tui, pi-acp, context7-mcp, chrome-devtools-mcp, notebooklm-mcp" -Color $Colors.Error
                exit 1
            }
        }
    } else {
        $itemsToProcess = @("qwen", "gsd", "ce", "rooted-leader", "rtk", "context-mode", "autocontext", "agent-browser", "squeez", "deepseek-tui", "pi-acp", "context7-mcp", "chrome-devtools-mcp", "notebooklm-mcp")
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

    if ($itemsToProcess -contains "rtk") {
        Update-RTK -CheckOnly $CheckOnly -Force $Force
        if (-not $CheckOnly -and (Get-RTKCurrentVersion) -ne (Get-RTKLatestVersion)) { $hasUpdates = $true }
    }

    if ($itemsToProcess -contains "context-mode") {
        Update-ContextMode -CheckOnly $CheckOnly -Force $Force
        if (-not $CheckOnly -and (Get-ContextModeCurrentVersion) -ne (Get-ContextModeLatestVersion)) { $hasUpdates = $true }
    }

    if ($itemsToProcess -contains "autocontext") {
        Update-AutoContext -CheckOnly $CheckOnly -Force $Force
        if (-not $CheckOnly -and (Get-AutoContextCurrentVersion) -ne (Get-AutoContextLatestVersion)) { $hasUpdates = $true }
    }

    if ($itemsToProcess -contains "agent-browser") {
        Update-AgentBrowser -CheckOnly $CheckOnly -Force $Force
        if (-not $CheckOnly -and (Get-AgentBrowserCurrentVersion) -ne (Get-AgentBrowserLatestVersion)) { $hasUpdates = $true }
    }

    if ($itemsToProcess -contains "squeez") {
        Update-Squeez -CheckOnly $CheckOnly -Force $Force
    }

    if ($itemsToProcess -contains "deepseek-tui") {
        Update-SimpleNpmPackage -Name "Deepseek TUI" -Package "deepseek-tui" -DisplayLabel "Deepseek TUI CLI" -Step 10 -TotalSteps 14 -CheckOnly $CheckOnly -Force $Force -GetVerFn ${function:Get-DeepseekTuiCurrentVersion}
    }

    if ($itemsToProcess -contains "pi-acp") {
        Update-SimpleNpmPackage -Name "pi ACP" -Package "pi-acp" -DisplayLabel "pi ACP SDK" -Step 11 -TotalSteps 14 -CheckOnly $CheckOnly -Force $Force -GetVerFn ${function:Get-PiAcpCurrentVersion}
    }

    if ($itemsToProcess -contains "context7-mcp") {
        Update-LocalMcpPackage -Name "Context7 MCP" -PackageName "@upstash/context7-mcp" -DisplayLabel "Context7 MCP Server" -Step 12 -TotalSteps 14 -CheckOnly $CheckOnly -Force $Force -GetVerFn { Get-LocalMcpVersion -PackageName "@upstash/context7-mcp" }
    }

    if ($itemsToProcess -contains "chrome-devtools-mcp") {
        Update-LocalMcpPackage -Name "Chrome DevTools MCP" -PackageName "chrome-devtools-mcp" -DisplayLabel "Chrome DevTools MCP" -Step 13 -TotalSteps 14 -CheckOnly $CheckOnly -Force $Force -GetVerFn { Get-LocalMcpVersion -PackageName "chrome-devtools-mcp" }
    }

    if ($itemsToProcess -contains "notebooklm-mcp") {
        Update-NotebookLmMcp -CheckOnly $CheckOnly -Force $Force
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
