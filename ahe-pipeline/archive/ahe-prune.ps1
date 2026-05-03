Write-Host "=== Phase: AHE Prune ===" -ForegroundColor Cyan

$pyModule = "C:\Users\Administrator\Scripts\archive\ahe-prune-module.py"
$benchmark = "C:\Users\Administrator\Scripts\benchmark.ps1"

# Step 1: Find pruning candidates
Write-Host "  [1/3] Analyzing component overhead..." -ForegroundColor Gray
$result = & python $pyModule 2>&1 | Out-String
try {
    $r = $result | ConvertFrom-Json
    Write-Host "  Components: $($r.total) | Candidates: $($r.candidates) | Safe: $($r.safe)" -ForegroundColor Cyan
} catch {
    Write-Host "  Prune analysis failed" -ForegroundColor Red
    return
}

if ($r.candidates -eq 0) {
    Write-Host "  No components to prune — all scoring above threshold." -ForegroundColor Green
    Write-Host "  Prune complete" -ForegroundColor Cyan
    return
}

Write-Host "  $($r.candidates) candidate(s) found for pruning." -ForegroundColor Yellow
Write-Host "  Prune complete (auto-pruning requires manual step: add disable/re-enable logic)" -ForegroundColor Cyan
