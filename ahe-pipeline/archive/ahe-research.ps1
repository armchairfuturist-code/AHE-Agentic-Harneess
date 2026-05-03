Write-Host "=== Phase: AHE Research ===" -ForegroundColor Cyan

$pyScript = "C:\Users\Administrator\Scripts\archive\ahe-research-module.py"
if (-not (Test-Path $pyScript)) {
    Write-Host "  ERROR: Research module not found at $pyScript" -ForegroundColor Red
    return
}

Write-Host "  Searching for new MCPs, tools, and config gaps..." -ForegroundColor Gray
$result = & python $pyScript 2>&1 | Out-String

if (-not $result) {
    Write-Host "  ERROR: Research module returned nothing" -ForegroundColor Red
    return
}

try {
    $json = $result | ConvertFrom-Json
    Write-Host "  Found $($json.summary.mcps) MCP candidates, $($json.summary.tools) tool candidates, $($json.summary.gaps) gaps" -ForegroundColor Cyan
    
    if ($json.mcps.Count -gt 0) {
        Write-Host ""
        Write-Host "  Top MCP candidates:" -ForegroundColor Cyan
        $json.mcps | Sort-Object stars -Descending | Select-Object -First 8 | ForEach-Object {
            Write-Host "    ($($_.stars)*) $($_.name)" -ForegroundColor Green
            Write-Host "       $($_.desc)" -ForegroundColor Gray
        }
    }
    if ($json.gaps.Count -gt 0) {
        Write-Host ""
        Write-Host "  Config gaps:" -ForegroundColor Yellow
        $json.gaps | ForEach-Object {
            Write-Host "    [FAIL] $($_.test): $($_.detail)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  ERROR parsing research results: $_" -ForegroundColor Red
}

Write-Host "  Research complete" -ForegroundColor Cyan
