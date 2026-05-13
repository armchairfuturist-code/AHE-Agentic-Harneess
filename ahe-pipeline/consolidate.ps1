# AHE Consolidate — Read gbrain manifest, regenerate QWEN.md 
# Usage: pwsh -File ahe-pipeline/consolidate.ps1
# Depends on: SSH access to gbrain (alex@100.102.182.39), existing QWEN.md at ~/.qwen/

param([switch]$DryRun, [switch]$Force)

$ErrorActionPreference = "Continue"
$LogFile = "$env:USERPROFILE\Scripts\logs\consolidate-$(Get-Date -Format 'yyyy-MM-dd').log"
$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log { param($Msg) $ts = Get-Date -Format "HH:mm:ss"; "$ts | $Msg" | Out-File $LogFile -Append; Write-Host "  $Msg" -ForegroundColor Gray }

function Read-GbrainPage {
    param([string]$Slug)
    try {
        $sshCmd = "export PATH=/home/alex/.bun/bin:`$PATH && /home/alex/.bun/bin/gbrain get $Slug"
        $result = ssh alex@100.102.182.39 $sshCmd 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
        return $null
    } catch {
        Log "ERROR reading gbrain page ${Slug}: $_"
        return $null
    }
}

Write-Host "=== AHE Consolidate ===" -ForegroundColor Magenta
Log "Starting consolidation"

# 1. Read gbrain pages
Write-Host "Reading gbrain manifest..." -ForegroundColor Cyan
$manifestPage = Read-GbrainPage -Slug "configs/ahe/manifest"
if (-not $manifestPage) {
    Log "ERROR: Cannot read configs/ahe/manifest from gbrain (SSH unreachable or page missing)"
    Write-Host "  FAIL: gbrain unreachable. Exiting without changes." -ForegroundColor Red
    exit 1
}

$benchmarkPage = Read-GbrainPage -Slug "configs/ahe/benchmark"
if (-not $benchmarkPage) {
    Log "WARNING: configs/ahe/benchmark not found in gbrain (okay — first run)"
}

Log "Manifest page read: $($manifestPage.Length) chars"

# 2. Read current QWEN.md
$qwenPath = "$env:USERPROFILE\.qwen\QWEN.md"
$qwenBackup = "$env:USERPROFILE\.qwen\QWEN.md.consolidate-bak"
if (-not (Test-Path $qwenPath)) {
    Log "ERROR: QWEN.md not found at $qwenPath"
    Write-Host "  FAIL: QWEN.md not found" -ForegroundColor Red
    exit 1
}

$currentQwen = Get-Content $qwenPath -Raw

# 3. Find the AHE section boundary
# The AHE section starts with "### Extended Rules (AHE supplement)" or similar
$aheMarker = "### Extended Rules (AHE supplement)"
$aheIndex = $currentQwen.IndexOf($aheMarker)
if ($aheIndex -lt 0) {
    Log "WARNING: AHE section marker not found in QWEN.md, appending"
    $nonAheSection = $currentQwen.TrimEnd()
} else {
    $nonAheSection = $currentQwen.Substring(0, $aheIndex).TrimEnd()
}

# 4. Parse manifest content to extract component data
$today = Get-Date -Format "yyyy-MM-dd"
$pipelineCycles = @()
$sessionCount = 0
$benchmarkScore = "N/A"
$lastCycle = "N/A"

# Extract benchmark score
if ($benchmarkPage) {
    if ($benchmarkPage -match "## Score: ([0-9.]+)/100") {
        $benchmarkScore = $Matches[1]
    }
}

# Extract cycle info from manifest
if ($manifestPage -match "Last cycle: (.+)") {
    $lastCycle = $Matches[1]
}

# 5. Build the new AHE section
# @"
# ### Extended Rules (AHE supplement)
# 
# ## AHE Self-Improvement Loop
# 
# AHE is an autonomous intelligence layer that sits on top of Qwen Code, turning it into a self-improving system.
# "@

$aheSection = @"

### Extended Rules (AHE supplement)

## AHE Self-Improvement Loop

AHE is an autonomous intelligence layer that sits on top of Qwen Code, turning it from a semi-autonomous coding harness into a fully self-improving system.

**Latest benchmark:** $benchmarkScore/100 (last cycle: $(if($lastCycle -ne "N/A"){$lastCycle}else{'unknown'}))

### Components (curated from gbrain manifest)

The following AHE components are active and managed:

| Component | Type | Status | Purpose |
|-----------|------|--------|---------|
| ahe-startup-check.js | hook | active | Daily health report on session start, stale session detection |
| ahe-session-heartbeat.js | hook | active | PreToolUse tool tracking with type categorization |
| ahe-closure | skill | active | Session manifest creation at session end |
| sync-obsidian.ps1 | script | active | Obsidian vault sync from gbrain/manual |
| pipeline.ps1 | pipeline | active | Full self-improvement pipeline (discover/benchmark/gate/compound) |
| consolidate.ps1 | pipeline | active | QWEN.md regeneration from gbrain manifest |
"@

# 6. Write new QWEN.md
$newQwen = $nonAheSection + $aheSection

$tempFile = "$env:TEMP\qwen-consolidated-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
$newQwen | Out-File -FilePath $tempFile -Encoding utf8 -Force
Log "Consolidated QWEN.md written to $tempFile ($($newQwen.Length) chars)"

# 7. Compare with current
$diffLines = @()
$oldLines = $currentQwen -split "`n"
$newLines = $newQwen -split "`n"
$addedLines = ($newLines.Count) - ($oldLines.Count)
Log "Current QWEN.md: $($oldLines.Count) lines, New: $($newLines.Count) lines (delta: $addedLines)"

Write-Host "" -ForegroundColor Cyan
Write-Host "Consolidation complete." -ForegroundColor Green
Write-Host "  Temp file: $tempFile" -ForegroundColor Gray

if ($Force -and -not $DryRun) {
    # Backup current QWEN.md
    Copy-Item $qwenPath $qwenBackup -Force
    Log "Backup: $qwenBackup"
    
    # Write new QWEN.md
    $newQwen | Out-File -FilePath $qwenPath -Encoding utf8 -Force
    Log "QWEN.md updated at $qwenPath"
    Write-Host "  Deployed to: $qwenPath" -ForegroundColor Green
} else {
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Dry run: use -Force to deploy" -ForegroundColor Yellow
    Write-Host "  Preview: $tempFile" -ForegroundColor Gray
    Log "Dry run: $tempFile"
}
