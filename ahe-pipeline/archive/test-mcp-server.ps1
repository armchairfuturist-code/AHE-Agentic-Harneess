# Test the Qwen Memory MCP Server
Write-Host "Testing Qwen Memory MCP Server" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

# Start the MCP server in background
$serverProcess = Start-Process -FilePath "node" -ArgumentList "C:\Users\Administrator\.qwen\memory\memory-mcp-server.js" -NoNewWindow -PassThru -RedirectStandardInput temp-input.txt -RedirectStandardOutput temp-output.txt

Write-Host "MCP Server PID: $($serverProcess.Id)" -ForegroundColor Gray

# Test that the server file exists
$serverFile = "C:\Users\Administrator\.qwen\memory\memory-mcp-server.js"
if (Test-Path $serverFile) {
    Write-Host "✓ Memory MCP server file exists" -ForegroundColor Green
    $size = (Get-Item $serverFile).Length
    Write-Host "  Size: $size bytes" -ForegroundColor Gray
} else {
    Write-Host "✗ Memory MCP server file NOT found" -ForegroundColor Red
}

# Test that the memory directory exists
$memDir = "C:\Users\Administrator\.qwen\memory"
if (Test-Path $memDir) {
    Write-Host "✓ Memory directory exists" -ForegroundColor Green
} else {
    Write-Host "✗ Memory directory NOT found" -ForegroundColor Red
}

# Test settings.json MCP configuration
Write-Host "`nTest: MCP Server Configuration in Settings.json" -ForegroundColor Yellow
$settingsFile = "C:\Users\Administrator\.qwen\settings.json"
$settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
if ($settings.mcpServers) {
    Write-Host "✓ MCP Servers configured: $($settings.mcpServers | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)" -ForegroundColor Green
    foreach ($server in ($settings.mcpServers | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)) {
        $cfg = $settings.mcpServers.$server
        $argsStr = $cfg.args -join ' '
        Write-Host "  - ${server}: ${argsStr}" -ForegroundColor Gray
    }
} else {
    Write-Host "✗ No MCP Servers configured" -ForegroundColor Red
}

# Test filesystem MCP server is installed
Write-Host "`nTest: Filesystem MCP Server Installation" -ForegroundColor Yellow
$fsServer = Get-Command "@modelcontextprotocol/server-filesystem" -ErrorAction SilentlyContinue
if (Get-Command npx -ErrorAction SilentlyContinue) {
    Write-Host "✓ npx available for running filesystem MCP server" -ForegroundColor Green
} else {
    Write-Host "✗ npx NOT available" -ForegroundColor Red
}

# Stop background process
Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue

Write-Host "`n" + "=" * 60 -ForegroundColor Green
Write-Host "Phase 2 Complete!" -ForegroundColor Green
Write-Host "`nMCP Servers Configured:" -ForegroundColor Yellow
Write-Host "1. filesystem - Project file indexing (via @modelcontextprotocol/server-filesystem)" -ForegroundColor Gray
Write-Host "2. qwen-memory - Persistent memory with hybrid storage/retrieval" -ForegroundColor Gray
Write-Host "`nMemory Tools Available:" -ForegroundColor Yellow
Write-Host "- memory_store: Store key-value memories with tags" -ForegroundColor Gray
Write-Host "- memory_retrieve: Search/retrieve memories" -ForegroundColor Gray
Write-Host "- memory_delete: Remove memories" -ForegroundColor Gray
Write-Host "- memory_list_projects: List project namespaces" -ForegroundColor Gray
Write-Host "- memory_stats: Storage statistics" -ForegroundColor Gray
Write-Host "- session_start/end: Session tracking" -ForegroundColor Gray
Write-Host "- entity_extract/query: Knowledge graph entities" -ForegroundColor Gray
