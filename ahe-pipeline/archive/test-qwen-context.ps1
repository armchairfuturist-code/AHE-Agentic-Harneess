# Test QWEN.md Hierarchical Context System
# This script verifies that Qwen Code loads context from QWEN.md files

Write-Host "Testing QWEN.md Hierarchical Context System" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

# Test 1: Check if root QWEN.md exists
Write-Host "`nTest 1: Root QWEN.md exists" -ForegroundColor Yellow
$rootQwen = "$env:USERPROFILE\.qwen\QWEN.md"
if (Test-Path $rootQwen) {
    Write-Host "✓ Root QWEN.md found at: $rootQwen" -ForegroundColor Green
    $size = (Get-Item $rootQwen).Length
    Write-Host "  Size: $size bytes" -ForegroundColor Gray
} else {
    Write-Host "✗ Root QWEN.md NOT found" -ForegroundColor Red
}

# Test 2: Check project-specific QWEN.md files
Write-Host "`nTest 2: Project-specific QWEN.md files" -ForegroundColor Yellow
$projects = @(
    "$env:USERPROFILE\Documents\Projects\rooted-leader-site\QWEN.md",
    "$env:USERPROFILE\plugins\compound-engineering\QWEN.md"
)

foreach ($project in $projects) {
    if (Test-Path $project) {
        $size = (Get-Item $project).Length
        Write-Host "✓ Found: $project" -ForegroundColor Green
        Write-Host "  Size: $size bytes" -ForegroundColor Gray
    } else {
        Write-Host "✗ Missing: $project" -ForegroundColor Red
    }
}

# Test 3: Check settings.json configuration
Write-Host "`nTest 3: Settings.json QWEN context configuration" -ForegroundColor Yellow
$settingsFile = "$env:USERPROFILE\.qwen\settings.json"
if (Test-Path $settingsFile) {
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
    if ($settings.context.qwenContext) {
        Write-Host "✓ QWEN context configuration found" -ForegroundColor Green
        Write-Host "  Enabled: $($settings.context.qwenContext.enabled)" -ForegroundColor Gray
        Write-Host "  Hierarchical Scanning: $($settings.context.qwenContext.hierarchicalScanning)" -ForegroundColor Gray
        Write-Host "  Root File: $($settings.context.qwenContext.rootContextFile)" -ForegroundColor Gray
    } else {
        Write-Host "✗ QWEN context configuration NOT found" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Settings.json NOT found" -ForegroundColor Red
}

# Test 4: Display context file contents summary
Write-Host "`nTest 4: Context file contents summary" -ForegroundColor Yellow
if (Test-Path $rootQwen) {
    $content = Get-Content $rootQwen
    $lineCount = $content.Count
    $wordCount = ($content -join " ").Split(" ").Count
    Write-Host "Root QWEN.md:" -ForegroundColor Gray
    Write-Host "  Lines: $lineCount" -ForegroundColor Gray
    Write-Host "  Words: $wordCount" -ForegroundColor Gray
    Write-Host "  First line: $($content[0])" -ForegroundColor Gray
}

Write-Host "`n" + "=" * 60 -ForegroundColor Green
Write-Host "Test Complete" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Run Qwen Code in a project directory" -ForegroundColor Gray
Write-Host "2. Use /context command to view loaded context" -ForegroundColor Gray
Write-Host "3. Verify QWEN.md files are being loaded" -ForegroundColor Gray
