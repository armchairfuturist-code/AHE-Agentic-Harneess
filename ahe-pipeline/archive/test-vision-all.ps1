# Comprehensive vision API test for all Kimi models across all endpoints

$ErrorActionPreference = "Stop"
$apiKey = $env:CROFAI_API_KEY

if (-not $apiKey) {
    Write-Host "ERROR: CROFAI_API_KEY not set" -ForegroundColor Red
    exit 1
}

# Test image (white square with text)
$imagePath = "C:\Users\Administrator\test.png"
$imageBytes = [System.IO.File]::ReadAllBytes($imagePath)
$base64Image = [Convert]::ToBase64String($imageBytes)

# Test configurations
$tests = @(
    @{ Model = "kimi-k2.6"; Endpoint = "https://crof.ai/v1" },
    @{ Model = "kimi-k2.6"; Endpoint = "https://test.crof.ai/v1" },
    @{ Model = "kimi-k2.6"; Endpoint = "https://beta.crof.ai/v1" },
    @{ Model = "kimi-k2.5-lightning"; Endpoint = "https://crof.ai/v1" },
    @{ Model = "kimi-k2.5-lightning"; Endpoint = "https://test.crof.ai/v1" }
)

Write-Host "=== Vision API Compatibility Test ===" -ForegroundColor Cyan
Write-Host "Testing image: $imagePath ($($imageBytes.Length) bytes)" -ForegroundColor Gray
Write-Host ""

$results = @()

foreach ($test in $tests) {
    $model = $test.Model
    $endpoint = $test.Endpoint
    
    Write-Host "Testing $model on $endpoint..." -ForegroundColor Yellow
    
    $requestBody = @{
        model = $model
        messages = @(
            @{
                role = "user"
                content = @(
                    @{ type = "text"; text = "Describe this image in one sentence." },
                    @{ type = "image_url"; image_url = @{ url = "data:image/png;base64,$base64Image" } }
                )
            }
        )
        max_tokens = 100
        temperature = 0.1
    } | ConvertTo-Json -Depth 10 -Compress

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $response = Invoke-RestMethod -Uri "$endpoint/chat/completions" `
            -Method Post `
            -Headers @{
                "Authorization" = "Bearer $apiKey"
                "Content-Type" = "application/json"
            } `
            -Body $requestBody `
            -TimeoutSec 30

        $stopwatch.Stop()
        $content = $response.choices[0].message.content
        
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  ❌ FAILED: Empty response" -ForegroundColor Red
            $results += @{ Model = $model; Endpoint = $endpoint; Status = "FAILED"; Time = $stopwatch.Elapsed.TotalSeconds; Response = "EMPTY" }
        } else {
            Write-Host "  ✅ SUCCESS: $($stopwatch.Elapsed.TotalSeconds.ToString('F2'))s" -ForegroundColor Green
            Write-Host "     Response: $($content.Substring(0, [Math]::Min(80, $content.Length)))..." -ForegroundColor Gray
            $results += @{ Model = $model; Endpoint = $endpoint; Status = "SUCCESS"; Time = $stopwatch.Elapsed.TotalSeconds; Response = $content }
        }
    } catch {
        $stopwatch.Stop()
        Write-Host "  ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $results += @{ Model = $model; Endpoint = $endpoint; Status = "ERROR"; Time = $stopwatch.Elapsed.TotalSeconds; Response = $_.Exception.Message }
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
$successCount = ($results | Where-Object { $_.Status -eq "SUCCESS" }).Count
$totalCount = $results.Count

Write-Host "Results: $successCount / $totalCount tests passed" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Yellow" })
Write-Host ""

$results | ForEach-Object {
    $color = if ($_.Status -eq "SUCCESS") { "Green" } elseif ($_.Status -eq "ERROR") { "Red" } else { "Yellow" }
    Write-Host "$($_.Status) | $($_.Model) | $($_.Endpoint)" -ForegroundColor $color
}

Write-Host ""
if ($successCount -eq $totalCount) {
    Write-Host "✅ All vision tests PASSED!" -ForegroundColor Green
    Write-Host "The crof.ai API supports images with Kimi models." -ForegroundColor Green
} else {
    Write-Host "⚠️  Some tests failed. Check which endpoints/models work." -ForegroundColor Yellow
}
