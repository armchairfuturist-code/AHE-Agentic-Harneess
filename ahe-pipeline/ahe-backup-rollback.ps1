function Invoke-Backup {
    Write-Host "`n=== Phase: Backup ===" -ForegroundColor Cyan
    if (-not (Test-Path $CycleBackupDir)) { New-Item -ItemType Directory -Path $CycleBackupDir -Force }
    $saved=0; $failed=0
    foreach ($item in @(@{N="settings.json";P="$env:USERPROFILE\.qwen\settings.json"},@{N=".last-good";P="$env:USERPROFILE\.qwen\settings.json.last-good"},@{N="manifest";P="$env:USERPROFILE\.autoresearch\ahe-manifest.json"})) {
        $src=$item.P; $dst="$CycleBackupDir\$($item.N)"
        if (Test-Path $src) { try { Copy-Item $src $dst -Force; Log "BKUP: $($item.N)"; $saved++ } catch { Log "BKUP FAIL: $($item.N): $_"; $failed++ } }
        else { Log "BKUP SKIP: $($item.N)" } }
    $hd="$env:USERPROFILE\.qwen\hooks"; if (Test-Path $hd) { try { Copy-Item $hd "$CycleBackupDir\hooks" -Recurse -Force; Log "BKUP: hooks/"; $saved++ } catch { Log "BKUP FAIL: hooks/: $_"; $failed++ } }
    $sd="$env:USERPROFILE\.qwen\skills"; if (Test-Path $sd) { (Get-ChildItem "$sd\*" -Directory | % Name) | Set-Content "$CycleBackupDir\skills.txt" -Force; $saved++ }
    Log "Backup: $saved saved, $failed failed"; return ($failed -eq 0) }

function Invoke-Rollback {
    param($Manifest)
    Write-Host "`n=== Phase: Rollback ===" -ForegroundColor Cyan
    if (-not $Manifest -or -not $Manifest.improvement_history) { Log "ROLL: no manifest"; return $false }
    $re=@($Manifest.improvement_history | ? { $_.verification.verdict -eq "revert" })
    if ($re.Count -eq 0) { Log "ROLL: none to revert"; return $false }
    $bd=@(Get-ChildItem "$BackupDir\backup-*" -Dir | Sort-Object Name -Descending)
    if ($bd.Count -eq 0) { Log "ROLL: no backups"; return $false }
    $lb=$bd[0].FullName; Log "ROLL: from $lb"
    $map=@{"settings.json"="$env:USERPROFILE\.qwen\settings.json";".last-good"="$env:USERPROFILE\.qwen\settings.json.last-good";"manifest"="$env:USERPROFILE\.autoresearch\ahe-manifest.json"}
    $rc=0;$fc=0; foreach($e in $re){
        Log "ROLL: $($e.candidate)"; foreach($k in $map.Keys){ $bf="$lb\$k";$tf=$map[$k]; if(Test-Path $bf){ try { Copy-Item $bf $tf -Force;$rc++ } catch { Log "RESTORE FAIL: $tf : $_";$fc++ } } }
        $hb="$lb\hooks";$ht="$env:USERPROFILE\.qwen\hooks"; if(Test-Path $hb){ try { Get-ChildItem "$ht\*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force; Copy-Item "$hb\*" $ht -Recurse -Force } catch { $fc++ } } }
    $entry=[PSCustomObject]@{iteration=$Manifest.improvement_history.Count+1;date=(Get-Date "yyyy-MM-dd HH:mm");candidate="AUTO_ROLLBACK";type="system";component=(($re|%{$_.candidate})-join", ");prediction=$null;verification=([PSCustomObject]@{measured_delta="Rolled back $($re.Count)";regression_observed=$false;verdict="keep";notes="Auto-rollback from $lb"})}
    $a=[System.Collections.ArrayList]$Manifest.improvement_history; $a.Add($entry)
    $Manifest.improvement_history=$a; $Manifest.cycle_count=$a.Count; $Manifest.last_cycle=(Get-Date "yyyy-MM-dd HH:mm")
    Save-AheManifest $Manifest; Log "Rollback: $rc restored, $fc failed"; return ($fc -eq 0) }
