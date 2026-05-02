<#
.SYNOPSIS
    Comprehensive Obsidian vault sync — copies knowledge artifacts from all
    project directories, moves orphan research files from Desktop/Home,
    and organizes everything into Research/, Projects/, Reference/ buckets.
.PARAMETER DryRun
    Show what would be done without actually doing it.
.PARAMETER Force
    Skip confirmation prompts.
#>
param([switch]$DryRun, [switch]$Force)

$ErrorActionPreference = 'Continue'
$VaultRoot = "C:\Users\Administrator\Documents\Obsidian Vault"
$Today = Get-Date -Format "yyyy-MM-dd"
$DryRunActive = $DryRun -or (-not $Force)

function Log {
    param([string]$Msg, [string]$Color = "Gray")
    if ($Color -eq "Green") { Write-Host "  ✅ $Msg" -ForegroundColor Green }
    elseif ($Color -eq "Yellow") { Write-Host "  ⚠️  $Msg" -ForegroundColor Yellow }
    elseif ($Color -eq "Red") { Write-Host "  ❌ $Msg" -ForegroundColor Red }
    elseif ($Color -eq "Cyan") { Write-Host "  ℹ️  $Msg" -ForegroundColor Cyan }
    else { Write-Host "     $Msg" -ForegroundColor $Color }
}

function Copy-Artifact {
    param([string]$Source, [string]$Subdir, [string]$Label)
    $destDir = "$VaultRoot\$Subdir"
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

    $filename = [System.IO.Path]::GetFileName($Source)
    $destPath = "$destDir\$Today-$filename"

    if (Test-Path $destPath) {
        Log "Skipped (exists): $Label → $Subdir\$Today-$filename" "Yellow"
        return $false
    }
    if ($DryRunActive) {
        Log "WOULD COPY: $Label → $Subdir\$Today-$filename" "Cyan"
    } else {
        Copy-Item $Source $destPath -Force
        Log "Copied: $Label → $Subdir\$Today-$filename" "Green"
    }
    return $true
}

function Move-Orphan {
    param([string]$Source, [string]$Subdir, [string]$Label)
    $destDir = "$VaultRoot\$Subdir"
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

    $filename = [System.IO.Path]::GetFileName($Source)
    $destPath = "$destDir\$Today-$filename"

    if (Test-Path $destPath) {
        Log "Skipped (exists): $Label → $Subdir\$Today-$filename" "Yellow"
        return $false
    }
    if ($DryRunActive) {
        Log "WOULD MOVE + DELETE: $Label → $Subdir\$Today-$filename" "Cyan"
    } else {
        Copy-Item $Source $destPath -Force
        Remove-Item $Source -Force
        Log "Moved + deleted: $Label → $Subdir\$Today-$filename" "Green"
    }
    return $true
}

# ============================================================================
# PHASE 1: Orphan files from Desktop + Home directory → Obsidian
# ============================================================================
Write-Host "=== Phase 1: Orphan files → Obsidian ===" -ForegroundColor Cyan
$orphans = @(
    # Desktop files
    @{ Path = "C:\Users\Administrator\Desktop\autoresearch-complete.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\Desktop\AUTORESEARCH-README.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\Desktop\rooted-leader-site-overview.md"; Sub = "Projects\Rooted-Leader" },
    @{ Path = "C:\Users\Administrator\Desktop\zed-crofai-reference.md"; Sub = "Reference\Workflow" },
    # Home directory — Qwen optimization reports
    @{ Path = "C:\Users\Administrator\qwen-config-analysis.md"; Sub = "Research\Qwen-Code" },
    @{ Path = "C:\Users\Administrator\qwen-code-advanced-optimization.md"; Sub = "Research\Qwen-Code" },
    @{ Path = "C:\Users\Administrator\qwen-code-quick-optimizations.md"; Sub = "Research\Qwen-Code" },
    @{ Path = "C:\Users\Administrator\qwen-code-configuration-optimization.md"; Sub = "Research\Qwen-Code" },
    @{ Path = "C:\Users\Administrator\qwen-code-optimization-summary.md"; Sub = "Research\Qwen-Code" },
    @{ Path = "C:\Users\Administrator\qwen-code-autoresearch-final.md"; Sub = "Research\Qwen-Code" },
    @{ Path = "C:\Users\Administrator\qwen-code-memory-implementation-plan.md"; Sub = "Research\Qwen-Code" },
    @{ Path = "C:\Users\Administrator\qwen-memory-system-operational-status.md"; Sub = "Research\Qwen-Code" },
    @{ Path = "C:\Users\Administrator\token-optimization-comparison.md"; Sub = "Reference\Workflow" },
    @{ Path = "C:\Users\Administrator\quick-token-optimization-summary.md"; Sub = "Reference\Workflow" },
    # Home directory — Autoresearch reports
    @{ Path = "C:\Users\Administrator\autoresearch-skills-qwen-code.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\autoresearch-implementation-analysis.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\autoresearch-implementation-complete.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\autoresearch-skill-setup.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\autoresearch-meta-optimization-summary.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\autoresearch-results.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\quick-autoresearch-summary.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\filtered-autoresearch-repos.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\quick-filtered-summary.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\crofai-community-insights.md"; Sub = "Research\CrofAI" },
    @{ Path = "C:\Users\Administrator\pc-performance-autoresearch-final.md"; Sub = "Reference\Windows" },
    @{ Path = "C:\Users\Administrator\pc-performance-autoresearch-summary.md"; Sub = "Reference\Windows" },
    @{ Path = "C:\Users\Administrator\autoresearch-improvement-analysis.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\autoresearch-optimization-journey.md"; Sub = "Research\Autoresearch" },
    @{ Path = "C:\Users\Administrator\test-vision-image.png"; Sub = ""; Skip = $true }
)
$orphanCount = 0
foreach ($o in $orphans) {
    if ($o.Skip -or -not (Test-Path $o.Path)) { continue }
    $label = Split-Path $o.Path -Leaf
    if (Move-Orphan -Source $o.Path -Subdir $o.Sub -Label $label) { $orphanCount++ }
}

# ============================================================================
# PHASE 2: Project knowledge artifacts → Obsidian (COPY, keep originals)
# ============================================================================
Write-Host "`n=== Phase 2: Project knowledge artifacts → Obsidian ===" -ForegroundColor Cyan

$projectArtifacts = @(
    # Rooted Leader Site
    @{ Path = "C:\Users\Administrator\Documents\Projects\rooted-leader-site\MINTLIFY-IMPLEMENTATION.md"; Sub = "Projects\Rooted-Leader" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\rooted-leader-site\GEO-SEO-IMPLEMENTATION-REPORT.md"; Sub = "Projects\Rooted-Leader" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\rooted-leader-site\GEO-PROGRESS-REPORT.md"; Sub = "Projects\Rooted-Leader" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\rooted-leader-site\FINAL-GEO-SEO-AUDIT.md"; Sub = "Projects\Rooted-Leader" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\rooted-leader-site\geo-audit-report.md"; Sub = "Projects\Rooted-Leader" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\rooted-leader-site\hero-ux-audit.md"; Sub = "Projects\Rooted-Leader" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\rooted-leader-site\DESIGN.md"; Sub = "Projects\Rooted-Leader" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\rooted-leader-site\docs\hero-ux-audit.md"; Sub = "Projects\Rooted-Leader" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\rooted-leader-site\tests\ux-audit\UX-CONVERSION-AUDIT.md"; Sub = "Projects\Rooted-Leader" },
    # Armchair Futurist
    @{ Path = "C:\Users\Administrator\Documents\Projects\ArmchairFuturistLanding\docs\CONVERSION-ANALYSIS.md"; Sub = "Projects\Armchair-Futurist" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\ArmchairFuturistLanding\docs\IMPLEMENTATION-COMPLETE.md"; Sub = "Projects\Armchair-Futurist" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\ArmchairFuturistLanding\docs\INTEGRATION-GUIDE.md"; Sub = "Projects\Armchair-Futurist" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\ArmchairFuturistLanding\docs\FIREBASE_ANALYTICS_SETUP.md"; Sub = "Projects\Armchair-Futurist" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\ArmchairFuturistLanding\GEO-IMPROVEMENTS.md"; Sub = "Projects\Armchair-Futurist" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\ArmchairFuturistLanding\docs\STOP-SLOP-ANALYSIS.md"; Sub = "Projects\Armchair-Futurist" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\ArmchairFuturistLanding\design.md"; Sub = "Projects\Armchair-Futurist" },
    # Mindscape
    @{ Path = "C:\Users\Administrator\Documents\Projects\mindscape-site\autoresearch.md"; Sub = "Projects\Mindscape" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\mindscape-site\docs\CHATBOT_DEPLOYMENT.md"; Sub = "Projects\Mindscape" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\mindscape-site\.sisyphus\notepads\podcast-master-hotfix\learnings.md"; Sub = "Projects\Mindscape" },
    # GEO SEO
    @{ Path = "C:\Users\Administrator\Documents\Projects\geo-seo-claude\agents\geo-ai-visibility.md"; Sub = "Research\GEO-SEO" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\geo-seo-claude\agents\geo-content.md"; Sub = "Research\GEO-SEO" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\geo-seo-claude\agents\geo-platform-analysis.md"; Sub = "Research\GEO-SEO" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\geo-seo-claude\agents\geo-schema.md"; Sub = "Research\GEO-SEO" },
    @{ Path = "C:\Users\Administrator\Documents\Projects\geo-seo-claude\agents\geo-technical.md"; Sub = "Research\GEO-SEO" },
    # Self-healing reference
    @{ Path = "C:\Users\Administrator\Documents\Obsidian Vault\Research\2026\04\*self-healing*"; Sub = "Reference\Self-Healing"; Wildcard = $true }
)

$artifactCount = 0
$skippedCount = 0
foreach ($a in $projectArtifacts) {
    if ($a.Wildcard) {
        $files = Get-ChildItem $a.Path -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            if (Copy-Artifact -Source $f.FullName -Subdir $a.Sub -Label $f.Name) { $artifactCount++ } else { $skippedCount++ }
        }
        continue
    }
    if (-not (Test-Path $a.Path)) { continue }
    $label = Split-Path $a.Path -Leaf
    if (Copy-Artifact -Source $a.Path -Subdir $a.Sub -Label $label) { $artifactCount++ } else { $skippedCount++ }
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  OBSIDIAN VAULT SYNC COMPLETE" -ForegroundColor $(if ($DryRunActive) { "Yellow" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Mode: $(if ($DryRunActive) { 'DRY RUN (no files changed)' } else { 'LIVE' })" -ForegroundColor $(if ($DryRunActive) { "Yellow" } else { "Green" })
Write-Host "  Orphans moved + deleted: $orphanCount" -ForegroundColor Green
Write-Host "  Project artifacts copied: $artifactCount" -ForegroundColor Green
Write-Host "  Skipped (already exists): $skippedCount" -ForegroundColor Gray
Write-Host "  Destination: $VaultRoot" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($DryRunActive -and -not $DryRun) {
    Write-Host "`nRun with -Force to execute." -ForegroundColor Yellow
}
