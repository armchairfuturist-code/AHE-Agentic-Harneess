#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete verification of the Qwen Code memory system
.DESCRIPTION
    Runs all tests for the hybrid memory architecture:
    - Layer 1: QWEN.md hierarchical context system
    - Layer 2: MCP memory server
    - Memory banks & Git versioning
    - Knowledge graph
    - Optimization/compression
#>

$MEMORY_DIR = "$env:USERPROFILE\.qwen\memory"
$PASS = 0
$FAIL = 0
$TOTAL = 0

function Test-Step {
    param($Name, $ScriptBlock)
    $script:TOTAL++
    try {
        $result = & $ScriptBlock
        if ($result) {
            $script:PASS++
            Write-Host "  ✓ $Name" -ForegroundColor Green
        } else {
            $script:FAIL++
            Write-Host "  ✗ $Name" -ForegroundColor Red
        }
    } catch {
        $script:FAIL++
        Write-Host "  ✗ $Name (error: $_ )" -ForegroundColor Red
    }
}

Write-Host "Qwen Code Memory System - Complete Verification" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
Write-Host ""

# SECTION 1: Layer 1 - QWEN.md Context System
Write-Host "Layer 1: QWEN.md Hierarchical Context System" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor DarkGray

Test-Step "Root QWEN.md exists" { Test-Path "$env:USERPROFILE\.qwen\QWEN.md" }
Test-Step "Rooted Leader QWEN.md exists" { Test-Path "$env:USERPROFILE\Documents\Projects\rooted-leader-site\QWEN.md" }
Test-Step "CE Plugin QWEN.md exists" { Test-Path "$env:USERPROFILE\plugins\compound-engineering\QWEN.md" }
Test-Step "Root QWEN.md is non-empty" { (Get-Item "$env:USERPROFILE\.qwen\QWEN.md").Length -gt 1000 }
Test-Step "Settings has context.fileName config" { $null -ne (Get-Content "$env:USERPROFILE\.qwen\settings.json" -Raw | ConvertFrom-Json).context.fileName }
Write-Host ""

# SECTION 2: Layer 2 - MCP Memory Server
Write-Host "Layer 2: MCP Memory Server" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor DarkGray

Test-Step "Memory MCP server exists" { Test-Path "$MEMORY_DIR\memory-mcp-server.js" }
Test-Step "Memory MCP server is non-empty" { (Get-Item "$MEMORY_DIR\memory-mcp-server.js").Length -gt 5000 }
Test-Step "Settings has mcpServers config" { $null -ne (Get-Content "$env:USERPROFILE\.qwen\settings.json" -Raw | ConvertFrom-Json).mcpServers }
Test-Step "Settings has filesystem MCP" { $null -ne (Get-Content "$env:USERPROFILE\.qwen\settings.json" -Raw | ConvertFrom-Json).mcpServers.filesystem }
Test-Step "Settings has qwen-memory MCP" { $s = Get-Content "$env:USERPROFILE\.qwen\settings.json" -Raw | ConvertFrom-Json; $null -ne $s.mcpServers."qwen-memory" }
Write-Host ""

# SECTION 3: Memory Banks & Git
Write-Host "Layer 3: Memory Banks & Git Versioning" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor DarkGray

Test-Step "Memory bank directory exists" { Test-Path $MEMORY_DIR }
Test-Step "Git repository initialized" { Test-Path "$MEMORY_DIR\.git" }
Test-Step "Git has at least 1 commit" { (git -C $MEMORY_DIR rev-list --count HEAD) -ge 1 }
Test-Step "Global bank exists" { Test-Path "$MEMORY_DIR\global\README.md" }
Test-Step "Curation rules exist" { Test-Path "$MEMORY_DIR\global\rules\curation-rules.md" }
Test-Step "Project bank (rooted-leader) exists" { Test-Path "$MEMORY_DIR\project-rooted-leader\README.md" }
Test-Step "Curator agent script exists" { Test-Path "$MEMORY_DIR\scripts\curator-agent.ps1" }
Test-Step ".gitignore exists" { Test-Path "$MEMORY_DIR\.gitignore" }
Write-Host ""

# SECTION 4: Knowledge Graph
Write-Host "Layer 4: Knowledge Graph" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor DarkGray

Test-Step "Memory store file exists" { Test-Path "$MEMORY_DIR\memory-store.json" }
Test-Step "Seed script exists" { Test-Path "$MEMORY_DIR\scripts\seed-knowledge-graph.ps1" }

# Check memory store has entities
$memoryStore = Get-Content "$MEMORY_DIR\memory-store.json" -Raw | ConvertFrom-Json
Test-Step "Knowledge graph has entities" { $memoryStore.entities.Count -gt 0 }
Test-Step "Has Qwen Code entity" { $null -ne ($memoryStore.entities | Where-Object { $_.name -eq "Qwen Code" }) }
Test-Step "Has crof.ai entity" { $null -ne ($memoryStore.entities | Where-Object { $_.name -eq "crof.ai" }) }
Test-Step "Has rooted-leader-site entity" { $null -ne ($memoryStore.entities | Where-Object { $_.name -eq "rooted-leader-site" }) }
Test-Step "Has compound-engineering entity" { $null -ne ($memoryStore.entities | Where-Object { $_.name -eq "compound-engineering" }) }
Write-Host ""

# SECTION 5: Optimization
Write-Host "Layer 5: Optimization & Efficiency" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor DarkGray

Test-Step "Memory MCP has memory_context_load tool" { (Select-String -Path "$MEMORY_DIR\memory-mcp-server.js" -Pattern "memory_context_load" -SimpleMatch).Count -gt 0 }
Test-Step "Memory MCP has hybrid_search tool" { (Select-String -Path "$MEMORY_DIR\memory-mcp-server.js" -Pattern "hybrid_search" -SimpleMatch).Count -gt 0 }
Test-Step "Memory MCP has graph_viz_data tool" { (Select-String -Path "$MEMORY_DIR\memory-mcp-server.js" -Pattern "graph_viz_data" -SimpleMatch).Count -gt 0 }
Test-Step "Memory MCP has graph_query_path tool" { (Select-String -Path "$MEMORY_DIR\memory-mcp-server.js" -Pattern "graph_query_path" -SimpleMatch).Count -gt 0 }
Test-Step "Memory MCP has graph_build tool" { (Select-String -Path "$MEMORY_DIR\memory-mcp-server.js" -Pattern "graph_build" -SimpleMatch).Count -gt 0 }

# Check settings has fileName config
$settings = Get-Content "$env:USERPROFILE\.qwen\settings.json" -Raw | ConvertFrom-Json
Test-Step "context.fileName configured for QWEN.md" { $settings.context.fileName -contains "QWEN.md" }
Test-Step "loadFromIncludeDirectories enabled" { $settings.context.loadFromIncludeDirectories -eq $true }
Test-Step "Test script for QWEN.md exists" { Test-Path "$env:USERPROFILE\Scripts\test-qwen-context.ps1" }
Test-Step "Test script for MCP exists" { Test-Path "$env:USERPROFILE\Scripts\test-mcp-server.ps1" }
Write-Host ""

# SUMMARY
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Cyan
Write-Host "  Passed: $PASS / $TOTAL" -ForegroundColor $(if ($FAIL -eq 0) { "Green" } else { "Red" })
Write-Host "  Failed: $FAIL" -ForegroundColor $(if ($FAIL -eq 0) { "Green" } else { "Red" })
Write-Host "  Pass Rate: $([math]::Round($PASS / $TOTAL * 100))%" -ForegroundColor $(if ($FAIL -eq 0) { "Green" } else { "Red" })

if ($FAIL -eq 0) {
    Write-Host "`n✓ All systems operational!" -ForegroundColor Green
} else {
    Write-Host "`n⚠ $FAIL test(s) failed. Review output above." -ForegroundColor Yellow
}
