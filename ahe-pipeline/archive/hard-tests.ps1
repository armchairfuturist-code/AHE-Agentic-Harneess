function Invoke-HardTests {
    Write-Host "  Hard Tests (weight x4, rubric 0-3):" -ForegroundColor Cyan
    $bk="$env:USERPROFILE\.autoresearch\backups"
    $bf=Get-ChildItem "$bk\backup-*" -Dir -EA 0|Sort-Object Name -Descending|Select-Object -First 3
    $bc=[Math]::Min($bf.Count,3)
    Test-Scenario "hard.backups" $bc 3
    $ph=0;if(Test-Path "C:\Users\Administrator\Scripts\pipeline.ps1"){$ph++};if(Test-Path "C:\Users\Administrator\Scripts\benchmark.ps1"){$ph++};if(Test-Path "C:\Users\Administrator\Scripts\tools.ps1"){$ph++}
    Test-Scenario "hard.scripts_valid" $ph 3
    $ml="$env:USERPROFILE\.qwen\skills";$ce="$env:USERPROFILE\plugins\compound-engineering\skills"
    $cd=Get-ChildItem "$ce\ce-*" -Dir -EA 0;$md=Get-ChildItem "$ml\ce-*" -Dir -EA 0;$mn=$md|ForEach-Object{$_.Name};$lk=0;$cd|ForEach-Object{if($_.Name -in $mn){$lk++}};$ls=0;if($cd.Count-gt0){$ls=[Math]::Floor($lk*3/$cd.Count)};Test-Scenario "hard.ce_skill_links" $ls 3
    $ah="$env:USERPROFILE\.autoresearch";$pr=0;if(Test-Path $ah){$pr++};if(Test-Path ($ah+"\benchmarks")){$pr++};if(Test-Path ($ah+"\backups")){$pr++};if(Test-Path ($ah+"\debugger")){$pr++};if(Test-Path ($ah+"\improvements")){$pr++};$as=0;if($pr-ge5){$as=3}elseif($pr-ge3){$as=2}elseif($pr-ge1){$as=1};Test-Scenario "hard.autoresearch_dirs" $as 3
    $mf="$env:USERPROFILE\.autoresearch\ahe-manifest.json"
    if(Test-Path $mf){$mi=1;$rx=Get-Content $mf -Raw -EA 0;if($rx){try{$m=$rx|ConvertFrom-Json;$e=$m.improvement_history.Count;$wp=@($m.improvement_history|?{$_.prediction}).Count;$r=0;if($e-gt0){$r=[Math]::Floor($wp*100/$e)};if($r-ge90){$mi=3}elseif($r-ge70){$mi=2}elseif($r-ge50){$mi=1}}catch{$mi=1}};Test-Scenario "hard.manifest_integrity" $mi 3}else{Test-Scenario "hard.manifest_integrity" 0 3}
    $bkf="$env:USERPROFILE\.qwen\settings.json.last-good"
    if(Test-Path $bkf){try{$bc=Get-Content $bkf -Raw|ConvertFrom-Json;if($bc.mcpServers){Test-Scenario "hard.settings_backup" 3 3}else{Test-Scenario "hard.settings_backup" 2 3}}catch{Test-Scenario "hard.settings_backup" 1 3}}else{Test-Scenario "hard.settings_backup" 0 3}
    $pp="C:\Users\Administrator\Scripts\pipeline.ps1"
    if(Test-Path $pp){try{& $pp -Phase gate 2>"";Test-Scenario "hard.pipeline_dry" 3 3}catch{Test-Scenario "hard.pipeline_dry" 1 3}}else{Test-Scenario "hard.pipeline_dry" 0 3}
    try{npm audit 2>$null;Test-Scenario "hard.security_npm_audit" 3 3}catch{Test-Scenario "hard.security_npm_audit" 0 3}
    $hk="$env:USERPROFILE\.qwen\hooks";$hs=3;if(Test-Path $hk){Get-ChildItem "$hk\*.js" -EA 0|ForEach-Object{$c=Get-Content $_.FullName -Raw -EA 0;if($c){$lns=@($c -split "\n");foreach($l in $lns){if($l -match "api[_-]?key|api[_-]?secret"){$hs=1}}}};Test-Scenario "hard.security_hook_keys" $hs 3}else{Test-Scenario "hard.security_hook_keys" 0 3}
}