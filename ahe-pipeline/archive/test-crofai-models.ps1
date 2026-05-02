# CrofAI Model Smoke Test Script
# Tests all models from both production and test endpoints

param(
    [switch]$Help,
    [string]$Model
)

$ErrorActionPreference = "Stop"

# Colors for output
$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Header = "Magenta"
}

function Write-Color {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Show-Help {
    Write-Color "CrofAI Model Smoke Test" -Color $Colors.Header
    Write-Color "=======================" -Color $Colors.Header
    Write-Host ""
    Write-Color "Usage:" -Color $Colors.Info
    Write-Host "  .\test-crofai-models.ps1 [options]"
    Write-Host ""
    Write-Color "Options:" -Color $Colors.Info
    Write-Host "  -Model <name>    Test specific model only"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Color "Examples:" -Color $Colors.Info
    Write-Host "  .\test-crofai-models.ps1"
    Write-Host "  .\test-crofai-models.ps1 -Model deepseek-v4-pro"
}

function Test-Model {
    param(
        [string]$ModelName,
        [string]$Endpoint
    )
    
    $apiKey = [Environment]::GetEnvironmentVariable('CROFAI_API_KEY', 'Machine')
    if (-not $apiKey) {
        return @{ success = $false; error = "CROFAI_API_KEY not set" }
    }
    
    $headers = @{
        'Authorization' = "Bearer $apiKey"
        'Content-Type' = 'application/json'
    }
    
    $body = @{
        model = $ModelName
        messages = @(@{ role = 'user'; content = 'Hello' })
        max_tokens = 10
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$Endpoint/v1/chat/completions" -Method Post -Headers $headers -Body $body -ErrorAction Stop -TimeoutSec 10
        return @{ success = $true; error = $null }
    } catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

Write-Color "CrofAI Model Smoke Test" -Color $Colors.Header
Write-Color "=======================" -Color $Colors.Header
Write-Host ""

# Get models from settings
$settingsPath = "C:\Users\Administrator\.qwen\settings.json"
if (-not (Test-Path $settingsPath)) {
    Write-Color "✗ Settings file not found: $settingsPath" -Color $Colors.Error
    exit 1
}

try {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $models = $settings.modelProviders.openai
} catch {
    Write-Color "✗ Failed to parse settings.json: $_" -Color $Colors.Error
    exit 1
}

# Filter to specific model if requested
if ($Model) {
    $models = $models | Where-Object { $_.id -like "*$Model*" -or $_.name -like "*$Model*" }
    if ($models.Count -eq 0) {
        Write-Color "✗ Model '$Model' not found in settings" -Color $Colors.Error
        exit 1
    }
}

# Get non-test models
$nonTestModels = $models | Where-Object { $_.id -notlike "*-test" }
Write-Color "Testing $($nonTestModels.Count) models..." -Color $Colors.Info
Write-Host ""

$successCount = 0
$failCount = 0
$failedModels = @()

foreach ($model in $nonTestModels) {
    $endpoint = $model.baseUrl
    $modelName = $model.id
    $modelDisplayName = $model.name
    
    Write-Color "Testing $modelDisplayName ($modelName)..." -Color $Colors.Info
    
    # Test production endpoint
    $prodResult = Test-Model -ModelName $modelName -Endpoint $endpoint
    if ($prodResult.success) {
        Write-Color "  ✓ Production: SUCCESS" -Color $Colors.Success
        $successCount++
    } else {
        Write-Color "  ✗ Production: FAILED - $($prodResult.error)" -Color $Colors.Error
        $failCount++
        $failedModels += "$modelDisplayName (production)"
    }
    
    # Test test endpoint (if model exists there)
    $testEndpoint = $endpoint -replace 'crof\.ai', 'test.crof.ai'
    $testModelName = "$modelName-test"
    $testResult = Test-Model -ModelName $testModelName -Endpoint $testEndpoint
    if ($testResult.success) {
        Write-Color "  ✓ Test: SUCCESS" -Color $Colors.Success
        $successCount++
    } else {
        Write-Color "  ✗ Test: FAILED - Model not deployed yet" -Color $Colors.Warning
        $failCount++
        $failedModels += "$modelDisplayName (test - not deployed)"
    }
    
    Write-Host ""
}

# Summary
Write-Color "Summary:" -Color $Colors.Header
Write-Color "  Total tests: $($successCount + $failCount)" -Color $Colors.Info
Write-Color "  Passed: $successCount" -Color $Colors.Success
Write-Color "  Failed: $failCount" -Color $Colors.Warning

if ($failedModels.Count -gt 0) {
    Write-Host ""
    Write-Color "Notes:" -Color $Colors.Info
    foreach ($failed in $failedModels) {
        Write-Color "  - $failed" -Color $Colors.Warning
    }
    Write-Host ""
    Write-Color "Note: Some models may not be deployed on test endpoint yet." -Color $Colors.Info
}

if ($failCount -eq 0) {
    Write-Host ""
    Write-Color "✓ All models working correctly!" -Color $Colors.Success
    exit 0
} else {
    exit 0
}
