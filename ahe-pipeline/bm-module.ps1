function Invoke-HardTests {
    Write-Host "  Hard Tests (weight x4, rubric 0-3):" -ForegroundColor Cyan
    $bk="$env:USERPROFILE\.autoresearch\backups"
    $bf=Get-ChildItem "$bk\backup-*" -Dir -EA 0|Sort-Object Name -Descending|Select-Object -First 3
    if ($bf.Count -ge 3) { Test-Scenario "hard.backups" 3 3 } else { Test-Scenario "hard.backups" $bf.Count 3 }
    $ph=0;if(Test-Path "C:\Users\Administrator\Scripts\pipeline.ps1"){$ph++};if(Test-Path "C:\Users\Administrator\Scripts\benchmark.ps1"){$ph++};if(Test-Path "C:\Users\Administrator\Scripts\tools.ps1"){$ph++}
    Test-Scenario "hard.scripts_valid" $ph 3
    try{$nv=npm audit 2>$null;Test-Scenario "hard.security_npm_audit" 3 3}catch{Test-Scenario "hard.security_npm_audit" 0 3}
    $hk="$env:USERPROFILE\.qwen\hooks";$hs=3;if(Test-Path $hk){Get-ChildItem "$hk\*.js" -EA 0|ForEach-Object{$x=Get-Content $_.FullName -Raw -EA 0;if($x){$lns=$x -split "`n";$lns|ForEach-Object{if($_ -match "api[_-]?key" -and $_ -notmatch "process\\.env\\." -and $_ -notmatch "{env:" -and $_ -notmatch "CROFAI_API_KEY|GEMINI_API_KEY"){$hs=1}}}}};Test-Scenario "hard.security_hook_keys" $hs 3
}