<#
.SYNOPSIS
    Integrate autocontext knowledge into the AHE pipeline compound phase.
.DESCRIPTION
    Exports benchmark results as autocontext knowledge packages.
    Reads playbooks from autocontext for pipeline improvement suggestions.
    Called from pipeline.ps1 compound phase when autocontext MCP is available.
#>

param(
    [switch]$Json,
    [string]$Action = "compound"
)

$AutoresearchDir = "$env:USERPROFILE\.autoresearch"
$BenchmarksDir = "$AutoresearchDir\benchmarks"
$KnowledgeDir = "$AutoresearchDir\knowledge"

if (-not (Test-Path $KnowledgeDir)) { New-Item -ItemType Directory -Path $KnowledgeDir -Force | Out-Null }

function Invoke-AutocontextCompound {
    Write-Host "  Autocontext: compounding knowledge..." -ForegroundColor Cyan
    
    # Get latest benchmark
    $latest = Get-ChildItem "$BenchmarksDir\*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { Write-Host "  No benchmarks to compound"; return }
    
    # Copy benchmark to knowledge dir as autocontext-readable artifact
    $target = "$KnowledgeDir\latest-benchmark.json"
    Copy-Item $latest.FullName $target -Force
    
    # Log it
    $log = "$KnowledgeDir\knowledge-log.jsonl"
    $entry = @{
        ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        source = "ahe-pipeline"
        artifact = "benchmark"
        path = $target
        benchmark = $latest.Name
    } | ConvertTo-Json -Compress
    Add-Content $log $entry
    
    Write-Host "  Compounded benchmark to autocontext knowledge dir" -ForegroundColor Green
}

function Invoke-AutocontextPlaybook {
    Write-Host "  Autocontext: checking playbooks..." -ForegroundColor Cyan
    
    # Check if autocontext has stored playbooks for our scenarios
    $playbookDir = "$env:USERPROFILE\knowledge"
    if (Test-Path $playbookDir) {
        $playbooks = Get-ChildItem "$playbookDir\**\playbook.md" -ErrorAction SilentlyContinue
        if ($playbooks) {
            foreach ($pb in $playbooks) {
                Write-Host "  Found playbook: $($pb.FullName)" -ForegroundColor Gray
            }
        }
    }
    Write-Host "  Autocontext playbook check complete" -ForegroundColor Green
}

switch ($Action) {
    "compound" { Invoke-AutocontextCompound }
    "playbook" { Invoke-AutocontextPlaybook }
    default { 
        Invoke-AutocontextCompound
        Invoke-AutocontextPlaybook
    }
}

if ($Json) {
    @{ status = "ok"; action = $Action } | ConvertTo-Json -Compress
}
