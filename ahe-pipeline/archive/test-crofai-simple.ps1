# Simple crof.ai model test

$apiKey = [Environment]::GetEnvironmentVariable('CROFAI_API_KEY', 'Machine')
$headers = @{
    'Authorization' = "Bearer $apiKey"
    'Content-Type' = 'application/json'
}

$models = @(
    'deepseek-v4-pro',
    'qwen3.6-27b',
    'glm-4.7-flash',
    'kimi-k2.6'
)

Write-Host "Testing crof.ai models..." -ForegroundColor Cyan
Write-Host ""

foreach ($model in $models) {
    Write-Host "Testing $model..." -ForegroundColor Yellow
    
    # Test production
    $body = @{ model = $model; messages = @(@{ role = 'user'; content = 'Hello' }); max_tokens = 10 } | ConvertTo-Json
    try {
        $response = Invoke-RestMethod -Uri 'https://crof.ai/v1/chat/completions' -Method Post -Headers $headers -Body $body -ErrorAction Stop -TimeoutSec 10
        Write-Host "  ✓ Production: SUCCESS" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Production: FAILED - $_" -ForegroundColor Red
    }
    
    # Test test endpoint
    $testModel = "$model-test"
    $body = @{ model = $testModel; messages = @(@{ role = 'user'; content = 'Hello' }); max_tokens = 10 } | ConvertTo-Json
    try {
        $response = Invoke-RestMethod -Uri 'https://test.crof.ai/v1/chat/completions' -Method Post -Headers $headers -Body $body -ErrorAction Stop -TimeoutSec 10
        Write-Host "  ✓ Test: SUCCESS" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Test: FAILED - $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "Test complete!" -ForegroundColor Cyan
