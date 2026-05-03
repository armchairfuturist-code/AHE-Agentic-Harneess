function Invoke-Evolve {
    param($Candidates)
    Write-Host "=== Phase: Evolve ===" -ForegroundColor Cyan
    $applied = 0
    foreach ($c in $Candidates) {
        if ($c.Type -eq "CEskill") {
            $src = "$env:USERPROFILE\plugins\compound-engineering\skills\" + $c.Name
            $dst = "$env:USERPROFILE\.qwen\skills\" + $c.Name
            if (Test-Path $src -and -not (Test-Path $dst)) {
                try { New-Item -ItemType Junction -Path $dst -Target $src -Force -ErrorAction Stop | Out-Null; Write-Host "  LINKED: $($c.Name)" -ForegroundColor Green; $applied++ } catch { Write-Host "  ERROR: $($c.Name): $_" -ForegroundColor Red }
            }
        }
    }
    Write-Host "  Evolve: $applied applied" -ForegroundColor Cyan
    return ($applied -gt 0)
}
