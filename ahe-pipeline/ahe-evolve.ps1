function Invoke-Evolve {
    Write-Host "=== Phase: Evolve ===" -ForegroundColor Cyan
    $ce="$env:USERPROFILE\plugins\compound-engineering\skills"
    $sk="$env:USERPROFILE\.qwen\skills"
    $l=0
    if(Test-Path $ce){
        $cs=Get-ChildItem "$ce\ce-*" -Dir -EA 0
        $os=Get-ChildItem "$sk\ce-*" -Dir -EA 0|ForEach-Object{$_.Name}
        foreach($s in $cs){
            if($s.Name -notin $os){
                try{New-Item -ItemType Junction -Path "$sk\$($s.Name)" -Target $s.FullName -Force -EA 0|Out-Null;$l++
                    Log "EVOLVE: Linked CE skill $($s.Name)"}
                catch{Log "EVOLVE FAIL: $($s.Name)"}
            }
        }
    }
    if($l){Log "EVOLVE: $l CE skills linked"}
    try{$nv=npm view @qwen-code/qwen-code version 2>`$null;$cv=qwen --version 2>`$null;if(-not$cv){$cv="0.15.5"};if($nv-and$nv-ne$cv){Log "EVOLVE: Qwen Code $cv -> $nv available. Run: npm install -g @qwen-code/qwen-code"}}catch{}
    Log "Evolve done"
}

function Invoke-LinkCeSkills {
    Write-Host "=== Phase: Link CE Skills ===" -ForegroundColor Cyan
    $ce="$env:USERPROFILE\plugins\compound-engineering\skills"
    $sk="$env:USERPROFILE\.qwen\skills"
    if(-not(Test-Path $ce)){Log "CE dir not found";return}
    $cs=Get-ChildItem "$ce\ce-*" -Dir -EA 0
    $os=Get-ChildItem "$sk\ce-*" -Dir -EA 0|ForEach-Object{$_.Name}
    $l=0;$f=0;$p=0
    foreach($x in $cs){
        if($x.Name -notin $os){
            try{New-Item -ItemType Junction -Path "$sk\$($x.Name)" -Target $x.FullName -Force -EA 0|Out-Null;$l++
                Log "LINKED: $($x.Name)"}
            catch{Log "FAIL: $($x.Name): $_";$f++}
        }else{$p++}
    }
    Write-Host "  $l linked, $p present, $f failed" -ForegroundColor $(if($f-eq0){"Green"}else{"Yellow"})
}