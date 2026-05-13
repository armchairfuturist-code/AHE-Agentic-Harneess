<#
.SYNOPSIS
    Gbrain-to-local-file adapter — replaces remote SSH-based gbrain operations
    with local file storage under ~/.autoresearch/gbrain/.
.DESCRIPTION
    All AHE pipeline data that was previously stored via SSH to gbrain
    (alex@100.102.182.39) is now stored locally. This is a drop-in replacement
    for Write-GbrainPage, Read-GbrainPage, and Invoke-GbrainContext.

    Directory layout:
      ~/.autoresearch/gbrain/
        configs/ahe/manifest.md          — AHE component manifest
        configs/ahe/benchmark.md         — Latest benchmark data
        research/ahe/pipeline-<date>.md  — Pipeline cycle histories
        research/ahe/attribution-<date>.md — Candidate attribution logs
        learnings/ahe/session-<date>.md  — Session manifest summaries
        learnings/ahe/reasoning-quality-<date>.md — HeavySkill eval trends
#>

$GbrainDir = "$env:USERPROFILE\.autoresearch\gbrain"

function Initialize-GbrainLocal {
    $subdirs = @(
        "configs/ahe",
        "research/ahe/pipeline",
        "research/ahe/attribution",
        "learnings/ahe/sessions",
        "learnings/ahe/reasoning"
    )
    foreach ($d in $subdirs) {
        $path = Join-Path $GbrainDir $d
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
    if (-not (Test-Path $GbrainDir)) {
        New-Item -ItemType Directory -Path $GbrainDir -Force | Out-Null
    }
    foreach ($scope in @("configs", "research", "learnings")) {
        $scopePath = Join-Path $GbrainDir $scope
        if (-not (Test-Path $scopePath)) {
            New-Item -ItemType Directory -Path $scopePath -Force | Out-Null
        }
    }
}

function Write-GbrainLocal {
    param(
        [string]$Slug,
        [string]$Content,
        [string]$Label = ""
    )
    try {
        Initialize-GbrainLocal
        $filePath = Join-Path $GbrainDir "$Slug.md"
        $dir = Split-Path $filePath -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $Content | Out-File -FilePath $filePath -Encoding utf8 -Force
        if ($Label) {
            Write-Host "  [GBRAIN-LOCAL] OK: $Label ($Slug)" -ForegroundColor Green
        }
        return $true
    } catch {
        Write-Host "  [GBRAIN-LOCAL] ERROR: $Label ($Slug) - $_" -ForegroundColor Yellow
        return $false
    }
}

function Read-GbrainLocal {
    param([string]$Slug)
    try {
        $filePath = Join-Path $GbrainDir "$Slug.md"
        if (Test-Path $filePath) {
            return Get-Content $filePath -Raw
        }
        return $null
    } catch {
        return $null
    }
}

function List-GbrainLocal {
    param([string]$SlugPrefix)
    try {
        $searchPath = Join-Path $GbrainDir "$SlugPrefix*.md"
        $files = @(Get-ChildItem $searchPath -ErrorAction SilentlyContinue)
        $slugs = foreach ($f in $files) {
            $relPath = $f.FullName.Substring($GbrainDir.Length + 1)
            $slug = $relPath -replace '\.md$', ''
            $slug -replace '\', '/'
        }
        return $slugs
    } catch {
        return @()
    }
}

function Invoke-GbrainLocalContext {
    param([ref]$KnownNames)
    try {
        $pipelineFiles = List-GbrainLocal -SlugPrefix "research/ahe/pipeline"
        $cyclesFound = 0
        $candidatesFound = 0

        foreach ($slug in $pipelineFiles) {
            $cyclesFound++
            $content = Read-GbrainLocal -Slug $slug
            if ($content) {
                $lines = $content -split "`n"
                $inTable = $false
                foreach ($pl in $lines) {
                    if ($pl -match '^\| Name \| Score \|') { $inTable = $true; continue }
                    if ($inTable -and $pl -match '^\| .+ \| .+ \|') {
                        $parts = $pl -split '\|'
                        if ($parts.Count -ge 2) {
                            $cname = $parts[1].Trim()
                            if ($cname -and $cname -ne '---') {
                                $KnownNames.Value[$cname] = $true
                                $candidatesFound++
                            }
                        }
                    }
                    if ($inTable -and $pl -match '^$') { $inTable = $false }
                }
            }
        }

        if ($cyclesFound -gt 0) {
            Write-Host "  [GBRAIN-LOCAL CONTEXT] $cyclesFound pipeline page(s), $candidatesFound known candidate(s) loaded" -ForegroundColor Cyan
        } else {
            Write-Host "  [GBRAIN-LOCAL CONTEXT] no pipeline pages found (first run)" -ForegroundColor DarkGray
        }
        return ($cyclesFound -gt 0)
    } catch {
        Write-Host "  [GBRAIN-LOCAL CONTEXT ERROR] $_" -ForegroundColor Yellow
        return $false
    }
}

# Initialize on dot-source
Initialize-GbrainLocal
