function Invoke-Discovery {
    Write-Host "=== Phase: Benchmark-Driven Discovery ===" -ForegroundColor Cyan
    $candidates = @()
    $benchmarksDir = "$env:USERPROFILE\.autoresearch\benchmarks"
    $latest = Get-ChildItem "$benchmarksDir\*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        $bench = Get-Content $latest.FullName -Raw | ConvertFrom-Json
        if ($bench.tests) {
            foreach ($key in $bench.tests.PSObject.Properties.Name) {
                if (-not $bench.tests.$key.pass) {
                    Write-Host ("  [FAIL] " + $key + ": " + $bench.tests.$key.detail) -ForegroundColor Red
                }
            }
        }
    }
    $ceDir = "$env:USERPROFILE\plugins\compound-engineering\skills"
    if (Test-Path $ceDir) {
        $ceNames = (Get-ChildItem "$ceDir\ce-*" -Directory -ErrorAction SilentlyContinue).Name
        $ourSkills = (Get-ChildItem "$env:USERPROFILE\.qwen\skills\ce-*" -Directory -ErrorAction SilentlyContinue).Name
        $missing = $ceNames | Where-Object { $_ -notin $ourSkills }
        if ($missing) {
            Write-Host ("  [CANDIDATE] " + $missing.Count + " CE skills not linked") -ForegroundColor Cyan
            foreach ($m in $missing) {
                $candidates += [PSCustomObject]@{ Type="CEskill"; Name=$m }
            }
        }
    }
    Write-Host ("  Discovery: " + $candidates.Count + " candidates") -ForegroundColor Cyan
    return $candidates
}

function Invoke-Evolve {
    param($Candidates)
    Write-Host "=== Phase: Evolve ===" -ForegroundColor Cyan
    $applied = 0
    foreach ($c in $Candidates) {
        if ($c.Type -eq "CEskill") {
            $src = "$env:USERPROFILE\plugins\compound-engineering\skills" + $c.Name
            $dst = "$env:USERPROFILE\.qwen\skills" + $c.Name
            if (Test-Path $src -and -not (Test-Path $dst)) {
                try { New-Item -ItemType Junction -Path $dst -Target $src -Force -ErrorAction Stop | Out-Null; Write-Host ("  LINKED: " + $c.Name) -ForegroundColor Green; $applied++ } catch { Write-Host ("  ERROR: " + $c.Name + ": " + $_) -ForegroundColor Red }
            }
        }
    }
    Write-Host ("  Evolve: " + $applied + " applied") -ForegroundColor Cyan
    return ($applied -gt 0)
}
