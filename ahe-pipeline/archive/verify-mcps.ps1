function Test-McpServer {
    param([string]$Name, [int]$TimeoutSeconds = 8)
    
    $settings = Get-Content "$env:USERPROFILE\.qwen\settings.json" -Raw | ConvertFrom-Json
    $mcpConfig = $settings.mcpServers.$Name
    if (-not $mcpConfig) { Write-Host "  [$Name] NOT FOUND" -ForegroundColor Red; return $false }
    
    # Build env vars and start with env
    $envVars = ""
    if ($mcpConfig.env) {
        foreach ($kv in $mcpConfig.env.PSObject.Properties) {
            $val = $kv.Value
            if ($val -match '^\{env:(.+)\}$') { $val = [Environment]::GetEnvironmentVariable($matches[1]) }
            if ($val) { $envVars += "set $($kv.Name)=$val && " }
        }
    }
    
    $fullCmd = "$envVars$($mcpConfig.command) $($mcpConfig.args -join ' ')"
    Write-Host "  [$Name]" -NoNewline -ForegroundColor Yellow
    
    $proc = Start-Process -NoNewWindow -FilePath "cmd.exe" -ArgumentList "/c $fullCmd" -PassThru
    Start-Sleep -Seconds 2
    
    $running = (-not $proc.HasExited)
    if ($running) {
        $proc.Kill()
        Write-Host " [✅ started]" -ForegroundColor Green
        return $true
    } else {
        Write-Host " [❌ exited immediately]" -ForegroundColor Red
        return $false
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "=== MCP Server Verification ===" -ForegroundColor Cyan
    $servers = @('filesystem','qwen-memory','github','brave-search','context7','chrome-devtools')
    $passed=0; $failed=0
    foreach ($s in $servers) {
        if (Test-McpServer -Name $s) { $passed++ } else { $failed++ }
        Start-Sleep -Seconds 1
    }
    Write-Host "`nResults: $passed passed, $failed failed" -ForegroundColor $(if($failed -eq 0){"Green"}else{"Red"})
}
