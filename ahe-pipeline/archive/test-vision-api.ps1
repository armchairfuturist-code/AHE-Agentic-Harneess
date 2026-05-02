# Test script for crof.ai vision API
# Tests whether Kimi models can actually process images

param(
    [string]$ImagePath = "C:\Users\Administrator\Downloads\54b91e27-de67-4b2d-9ebb-cd3ae4935472.jpg",
    [string]$Model = "kimi-k2.6",
    [string]$Endpoint = "https://crof.ai/v1"
)

$ErrorActionPreference = "Stop"

# Check if image exists
if (-not (Test-Path $ImagePath)) {
    Write-Host "ERROR: Image not found at $ImagePath" -ForegroundColor Red
    exit 1
}

# Get image info
$imageInfo = Get-Item $ImagePath
Write-Host "Testing image: $($imageInfo.Name)" -ForegroundColor Cyan
Write-Host "  Size: $([math]::Round($imageInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
Write-Host "  Model: $Model" -ForegroundColor Gray
Write-Host "  Endpoint: $Endpoint" -ForegroundColor Gray
Write-Host ""

# Convert image to base64
$imageBytes = [System.IO.File]::ReadAllBytes($ImagePath)
$base64Image = [Convert]::ToBase64String($imageBytes)
Write-Host "Image converted to base64 ($($base64Image.Length) chars)" -ForegroundColor Gray

# Get API key
$apiKey = $env:CROFAI_API_KEY
if (-not $apiKey) {
    Write-Host "ERROR: CROFAI_API_KEY environment variable not set" -ForegroundColor Red
    exit 1
}

# Build the request body
$requestBody = @{
    model = $Model
    messages = @(
        @{
            role = "user"
            content = @(
                @{ type = "text"; text = "Describe what you see in this image in detail." },
                @{ type = "image_url"; image_url = @{ url = "data:image/jpeg;base64,$base64Image" } }
            )
        }
    )
    max_tokens = 500
    temperature = 0.1
} | ConvertTo-Json -Depth 10 -Compress

Write-Host "Sending request to $Endpoint/chat/completions..." -ForegroundColor Cyan

# Measure time
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    $response = Invoke-RestMethod -Uri "$Endpoint/chat/completions" `
        -Method Post `
        -Headers @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type" = "application/json"
        } `
        -Body $requestBody `
        -TimeoutSec 60

    $stopwatch.Stop()

    Write-Host ""
    Write-Host "=== RESPONSE ===" -ForegroundColor Green
    Write-Host "Status: SUCCESS" -ForegroundColor Green
    Write-Host "Time: $($stopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Gray
    Write-Host "Model: $($response.model)" -ForegroundColor Gray
    Write-Host "Tokens used: $($response.usage.total_tokens) (prompt: $($response.usage.prompt_tokens), completion: $($response.usage.completion_tokens))" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Cyan
    Write-Host $response.choices[0].message.content -ForegroundColor White
    Write-Host ""
    Write-Host "=== END RESPONSE ===" -ForegroundColor Green

    # Check if response is empty
    if ([string]::IsNullOrWhiteSpace($response.choices[0].message.content)) {
        Write-Host "WARNING: Response is empty!" -ForegroundColor Yellow
        exit 2
    }

    Write-Host ""
    Write-Host "✅ Vision API test PASSED" -ForegroundColor Green

} catch {
    $stopwatch.Stop()
    Write-Host ""
    Write-Host "=== ERROR ===" -ForegroundColor Red
    Write-Host "Status: FAILED" -ForegroundColor Red
    Write-Host "Time: $($stopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Gray
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    # Try to parse error response
    if ($_.Exception.Response) {
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $streamReader.ReadToEnd()
        $streamReader.Close()
        Write-Host "Response body: $errorBody" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "❌ Vision API test FAILED" -ForegroundColor Red
    exit 1
}
