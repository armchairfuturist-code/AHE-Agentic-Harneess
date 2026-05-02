param([string]$Path,[string]$Content)
if(!$Path){write-host "Usage: ws.ps1 -Path <file>";exit}
if(!$Content){$Content=$input|out-string}
$f=join-path "C:\Users\Administrator\Scripts" $Path
[io.file]::writealltext($f,$Content)
if($Path-like"*.ps1"){try{& $f -Phase gate 2>null;Write-Host "Syntax OK" -ForegroundColor Green}catch{Write-Warning "Syntax FAILED"}}