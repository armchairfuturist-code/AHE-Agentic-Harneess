# Find files larger than 100MB under ~/.qwen/
$targetDir = "$env:USERPROFILE\.qwen"
$sizeLimitMB = 100
$sizeLimitBytes = $sizeLimitMB * 1MB

Write-Host "Scanning $targetDir for files > ${sizeLimitMB}MB..."
Get-ChildItem -Path $targetDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt $sizeLimitBytes } |
    Sort-Object Length -Descending |
    Select-Object FullName, @{N='SizeMB';E={[math]::Round($_.Length/1MB, 2)}}, LastWriteTime |
    Format-Table -AutoSize

if ((Get-ChildItem -Path $targetDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt $sizeLimitBytes }).Count -eq 0) {
    Write-Host "No files found over ${sizeLimitMB}MB."
}
