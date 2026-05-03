Write-Host "=== Phase: AHE Research ===" -ForegroundColor Cyan

$pyModule = "C:\Users\Administrator\Scripts\archive\ahe-research-module.py"
$pyEval = "C:\Users\Administrator\Scripts\archive\ahe-evaluate-candidates.py"
$pyReport = "C:\Users\Administrator\Scripts\archive\ahe-report-generator.py"

# Step 1: Research — find new MCPs, tools, gaps
Write-Host "  [1/3] Searching for new MCPs, tools, and config gaps..." -ForegroundColor Gray
$result = & python $pyModule 2>&1 | Out-String
if (-not $result) { Write-Host "  ERROR: Research module failed" -ForegroundColor Red; return }

# Step 2: Evaluate — score and rank candidates
Write-Host "  [2/3] Evaluating and scoring candidates..." -ForegroundColor Gray
$evalResult = & python $pyEval 2>&1 | Out-String
if (-not $evalResult) { Write-Host "  ERROR: Evaluation module failed" -ForegroundColor Red; return }

# Step 3: Report — generate human-readable markdown to Obsidian
Write-Host "  [3/3] Generating report to Obsidian vault..." -ForegroundColor Gray
$reportResult = & python $pyReport 2>&1 | Out-String
try {
    $r = $reportResult | ConvertFrom-Json
    Write-Host "  Report written: $($r.report)" -ForegroundColor Green
    Write-Host "  Candidates evaluated: $($r.candidates)" -ForegroundColor Cyan
} catch {
    Write-Host "  Report generated (see Obsidian vault)" -ForegroundColor Green
}

Write-Host "  Research complete" -ForegroundColor Cyan
