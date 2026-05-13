# CrofAI Model Update Script
# Updates Qwen Code settings.json with latest models from crof.ai endpoints
# Production models always included; use -INCLUDE_BETA for beta endpoint
# Uses selective generationConfig (only non-default overrides) and compact JSON
# NOTE: Preserves hooks, MCP servers, env, security, performance, permissions, ui, and context sections

param(
    [switch]$CheckOnly,
    [switch]$INCLUDE_BETA,
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$SettingsPath = "C:\Users\Administrator\.qwen\settings.json"

# Endpoints (no test endpoint included)
$Endpoints = @(
    @{ Name = "production"; Url = "https://crof.ai/v1"; Suffix = ""; Label = "CrofAI"; Desc = "Model via CrofAI" }
)
$Endpoints += @{ Name = "beta"; Url = "https://beta.crof.ai/v1"; Label = "CrofAI Beta"; Desc = "Model via CrofAI Beta Endpoint" }

$Colors = @{
    Success = "Green"; Warning = "Yellow"; Error = "Red"; Info = "Cyan"; Header = "Magenta"; Dim = "DarkGray"
}

function Write-Color { param([string]$Message, [string]$Color = "White") Write-Host $Message -ForegroundColor $Color }

function Show-Help {
    Write-Color "CrofAI Model Update Script (v2 - Compact)" -Color $Colors.Header
    Write-Color "=========================================" -Color $Colors.Header
    Write-Host ""
    Write-Color "Usage:" -Color $Colors.Info
    Write-Host "  .\update-crofai-models.ps1 [options]"
    Write-Host ""
    Write-Color "Options:" -Color $Colors.Info
    Write-Host "  -CheckOnly    Check available models without updating"
    Write-Host "  "
    Write-Host "  -Force        Force update even if no new models"
    Write-Host "  -Help         Show this help message"
    Write-Host ""
    Write-Color "Endpoints:" -Color $Colors.Info
    Write-Host "  - production (https://crof.ai/v1) — always included (20 models)"
    Write-Host "  - beta       (https://beta.crof.ai/v1) — auto-included (20 models)"
    Write-Host ""
    Write-Color "Size targets:" -Color $Colors.Info
    Write-Host "  < 5 KB:  Perfect, instant init"
    Write-Host "  5-10 KB: Fine"
    Write-Host "  > 10 KB: Warning (may slow init)"
    Write-Host ""
    Write-Color "Examples:" -Color $Colors.Info
    Write-Host "  .\update-crofai-models.ps1 -CheckOnly"
    Write-Host "  .\update-crofai-models.ps1"
    Write-Host "  .\update-crofai-models.ps1 -INCLUDE_BETA"
}

# --- Override profiles: only non-default values ---
function Get-OverrideProfile {
    param([string]$ModelId)
    $overrides = $null
    switch -Wildcard ($ModelId) {
        "glm-4.7-flash*" { $overrides = @{ samplingParams = @{ temperature = 0.1 } }; break }
        "kimi-k2.6-precision*" { $overrides = @{ samplingParams = @{ max_tokens = 8192; top_p = 0.85 }; extraBody = @{ reasoning_effort = "high"; enable_thinking = $true }; timeout = 120000; modalities = @{ image = $true } }; break }  # BEFORE kimi-k2.6*
        "kimi-k2.5-lightning*" { $overrides = @{ samplingParams = @{ max_tokens = 32768 }; extraBody = @{ enable_thinking = $false }; timeout = 45000; modalities = @{ image = $true } }; break }  # BEFORE kimi-k2.5*
        "kimi-k2.6*" { $overrides = @{ samplingParams = @{ max_tokens = 8192; top_p = 0.85 }; extraBody = @{ reasoning_effort = "medium"; enable_thinking = $true }; timeout = 90000; modalities = @{ image = $true } }; break }
        "kimi-k2.5*" { $overrides = @{ samplingParams = @{ max_tokens = 8192; top_p = 0.85 }; extraBody = @{ reasoning_effort = "medium"; enable_thinking = $true }; timeout = 90000; modalities = @{ image = $true } }; break }
        "deepseek-v3.2*" { $overrides = @{ samplingParams = @{ max_tokens = 8192; frequency_penalty = 0.1; presence_penalty = 0.1; top_p = 0.8 } }; break }
        "deepseek-v4-pro-precision*" { $overrides = @{ samplingParams = @{ max_tokens = 8192; frequency_penalty = 0.1; presence_penalty = 0.1; top_p = 0.8 }; extraBody = @{ enable_thinking = $true }; timeout = 180000 }; break }  # BEFORE v4-pro*
        "deepseek-v4-pro*" { $overrides = @{ samplingParams = @{ max_tokens = 8192; frequency_penalty = 0.1; presence_penalty = 0.1; top_p = 0.8 }; timeout = 180000 }; break }
        "deepseek-v4-flash*" { $overrides = @{ samplingParams = @{ max_tokens = 16384; temperature = 0.3; top_p = 0.9 }; timeout = 120000 }; break }
        "qwen3.6-27b*" { $overrides = @{ samplingParams = @{ max_tokens = 8192 }; extraBody = @{ reasoning_effort = "medium" }; timeout = 90000 }; break }
        "qwen3.5-397b-a17b*" { $overrides = @{ samplingParams = @{ max_tokens = 8192; top_p = 0.85 }; extraBody = @{ reasoning_effort = "medium"; enable_thinking = $true }; timeout = 90000 }; break }
        "gemma-4-31b-it*" { $overrides = @{ timeout = 45000 }; break }
        "glm-5.1-precision*" { $overrides = @{ extraBody = @{ enable_thinking = $true }; timeout = 90000 }; break }
        "minimax-m2.5*" { $overrides = @{ modalities = @{ image = $true } }; break }
        "qwen3.5-9b*" { $overrides = @{ samplingParams = @{ temperature = 0.3 } }; break }
        "glm-4.7*" { $overrides = @{ timeout = 120000 }; break }
        default { $overrides = $null }
    }
    return $overrides
}

function Build-ModelEntry {
    param([object]$ApiModel, [string]$EndpointUrl, [string]$Label, [string]$Desc, [string]$Suffix)
    $entry = @{
        id = $ApiModel.id + $Suffix
        name = "$Label`: $($ApiModel.name)"
        baseUrl = $EndpointUrl
        description = $Desc
        envKey = "CROFAI_API_KEY"
    }
    $overrides = Get-OverrideProfile -ModelId $ApiModel.id
    if ($overrides) {
        $genCfg = @{}
        if ($overrides.samplingParams) { $genCfg.samplingParams = $overrides.samplingParams }
        if ($overrides.extraBody) { $genCfg.extraBody = $overrides.extraBody }
        if ($overrides.timeout) { $genCfg.timeout = $overrides.timeout }
        if ($overrides.modalities) { $genCfg.modalities = $overrides.modalities }
        if ($ApiModel.context_length) { $genCfg.contextWindowSize = $ApiModel.context_length }
        if ($genCfg.Keys.Count -gt 0) { $entry.generationConfig = $genCfg }
    }
    return $entry
}


function Test-ModelHealth {
    param([string]$ModelId, [string]$Url, [string]$ApiKey)
    try {
        $body = @{ model = $ModelId; messages = @(@{ role = "user"; content = "ping" }); max_tokens = 5 } | ConvertTo-Json -Compress
        $response = Invoke-RestMethod -Uri "$Url/chat/completions" -Method Post -Headers @{ Authorization = "Bearer $ApiKey"; "Content-Type" = "application/json" } -Body $body -ErrorAction Stop -TimeoutSec 15
        return @{ healthy = $true; content = $response.choices[0].message.content }
    } catch {
        $sc = $_.Exception.Response.StatusCode.value__
        Write-Color "  ⚠ $ModelId failed: HTTP $sc - skipping" -Color $Colors.Warning
        return @{ healthy = $false; status = $sc }
    }
}

function Fetch-Models {
    param([string]$Url)
    try {
        $apiKey = [Environment]::GetEnvironmentVariable('CROFAI_API_KEY', 'Machine')
        if (-not $apiKey) { $apiKey = [Environment]::GetEnvironmentVariable('CROFAI_API_KEY', 'User') }
        if (-not $apiKey) { Write-Color "  ✗ CROFAI_API_KEY not set" -Color $Colors.Error; return $null }
        $response = Invoke-RestMethod -Uri "$Url/models" -Method Get -Headers @{Authorization="Bearer $apiKey"} -ErrorAction Stop
        return $response.data
    } catch {
        Write-Color "  ✗ Failed: $_" -Color $Colors.Error
        return $null
    }
}

# --- Main ---
if ($Help) { Show-Help; exit 0 }

Write-Color "CrofAI Model Update Script (v2 - Compact)" -Color $Colors.Header
Write-Color "=========================================" -Color $Colors.Header
Write-Host ""

$endpointsToCheck = $Endpoints | ForEach-Object { "$($_.Name) ($($_.Url))" }
Write-Color "Endpoints: $($endpointsToCheck -join ', ')" -Color $Colors.Info
if (-not $INCLUDE_BETA) {
    Write-Color "  (beta auto-included, deduped against production)" -Color $Colors.Dim
}
Write-Host ""

# Fetch models
$allModelData = @()
foreach ($ep in $Endpoints) {
    Write-Color "Fetching $($ep.Name)..." -Color $Colors.Info
    $models = Fetch-Models -Url $ep.Url
    if ($models) {
        Write-Color "  $($models.Count) models from $($ep.Label)" -Color $Colors.Success
        $allModelData += @{ Ep = $ep; Models = $models }
    }
}
Write-Host ""

# Build model list from scratch
$newModels = @()
$newCount = 0
foreach ($md in $allModelData) {
    foreach ($m in $md.Models) {
        $ak = [Environment]::GetEnvironmentVariable("CROFAI_API_KEY","User");if(-$null -eq $ak){$ak=[Environment]::GetEnvironmentVariable("CROFAI_API_KEY","Machine")}
        $health = Test-ModelHealth -ModelId $m.id -Url $md.Ep.Url -ApiKey $ak
        if (-not $health.healthy) { continue }
        $existingIds = $newModels | ForEach-Object { $_.id }
        if ($md.Ep.Name -eq "beta" -and $m.id -in $existingIds) {
            Write-Color "  - Skipping $($m.id) (already from production)" -Color $Colors.Dim
            continue
        }
        $entry = Build-ModelEntry -ApiModel $m -EndpointUrl $md.Ep.Url -Label $md.Ep.Label -Desc $md.Ep.Desc -Suffix $md.Ep.Suffix
        $newModels += $entry
        $newCount++
    }
}

# Load current settings for comparison
$currentSettings = $null
if (Test-Path $SettingsPath) {
    try { $currentSettings = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}
$currentIds = @()
if ($currentSettings -and $currentSettings.modelProviders.openai) {
    $currentIds = $currentSettings.modelProviders.openai | ForEach-Object { $_.id }
}

# Find new vs removed vs kept
$newIds = $newModels | ForEach-Object { $_.id }
$added = $newIds | Where-Object { $_ -notin $currentIds }
$removed = $currentIds | Where-Object { $_ -notin $newIds }
$kept = $newIds | Where-Object { $_ -in $currentIds }

Write-Color "Model comparison:" -Color $Colors.Info
Write-Color "  Current: $($currentIds.Count) models" -Color $Colors.Dim
Write-Color "  Available: $newCount models" -Color $Colors.Dim
if ($added.Count -gt 0) { Write-Color "  + New: $($added -join ', ')" -Color $Colors.Success }
if ($removed.Count -gt 0) { Write-Color "  - Removed: $($removed -join ', ')" -Color $Colors.Warning }
if ($added.Count -eq 0 -and $removed.Count -eq 0) { Write-Color "  No changes" -Color $Colors.Success }
Write-Host ""

$withGC = ($newModels | Where-Object { $_.generationConfig }).Count
Write-Color "  $newCount total models, $withGC with generationConfig" -Color $Colors.Dim

if ($CheckOnly) {
    Write-Color "=== Check complete ===" -Color $Colors.Header
    Write-Color "  Run without -CheckOnly to update settings.json" -Color $Colors.Info
    exit 0
}

if ($added.Count -eq 0 -and $removed.Count -eq 0 -and -not $Force) {
    Write-Color "No changes needed (use -Force to regenerate anyway)" -Color $Colors.Success
    exit 0
}

# Update settings.json
Write-Color "Updating settings.json..." -Color $Colors.Info

try {
    if (-not $currentSettings) {
        $currentSettings = [PSCustomObject]@{
            modelProviders = [PSCustomObject]@{ openai = @() }
            env = [PSCustomObject]@{ CROFAI_API_KEY = "{env:CROFAI_API_KEY}" }
            security = [PSCustomObject]@{ auth = [PSCustomObject]@{ selectedType = "openai" } }
            model = [PSCustomObject]@{ name = "kimi-k2.6-precision" }
            '$version' = 3
        }
    }

    # Replace only the models array, preserve everything else
    $currentSettings.modelProviders.openai = @($newModels)

    # Preserve non-model sections from existing config (hooks, MCP, env, etc.)
    if (Test-Path $SettingsPath) {
        $existingSettings = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

        $preserveSections = @('hooks', 'mcpServers', 'env', 'security', 'model', 'performance', 'permissions', 'ui', 'context')

        foreach ($section in $preserveSections) {
            if ($existingSettings.$section) {
                $currentSettings.$section = $existingSettings.$section
            }
        }
    }

    # Write compact JSON
    $json = $currentSettings | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetByteCount($json)
    $kb = [math]::Round($bytes / 1KB, 1)

    # Warn if too large
    if ($kb -gt 10) {
        Write-Color "  ⚠️  File size $kb KB exceeds 10 KB threshold — may slow init" -Color $Colors.Warning
    } elseif ($kb -gt 5) {
        Write-Color "  📏 File size: $kb KB" -Color $Colors.Warning
    } else {
        Write-Color "  ✅ File size: $kb KB" -Color $Colors.Success
    }

    $json | Set-Content $SettingsPath -Encoding UTF8 -NoNewline
    Write-Color "✓ settings.json updated" -Color $Colors.Success

    # --- GSD2 Model Update ---
    # Also update GSD2/pi's models.json with the same model list
    $gsdModelsPath = "$env:USERPROFILE\.gsd\agent\models.json"
    Write-Color "  Updating GSD2 models..." -Color $Colors.Info
    try {
        $gsdModels = @()
        foreach ($m in $newModels) {
            $baseId = $m.id
            if ($baseId -match '^(.*)-crofai$') { $baseId = $Matches[1] }
            $cleanName = $m.name
            if ($cleanName -match '^CrofAI: (.*)$') { $cleanName = $Matches[1] }
            $reasoning = ($m.generationConfig -and $m.generationConfig.extraBody -and ($m.generationConfig.extraBody.enable_thinking -or $m.generationConfig.extraBody.reasoning_effort))
            $ctx = 131072
            if ($m.generationConfig -and $m.generationConfig.contextWindowSize) { $ctx = $m.generationConfig.contextWindowSize }
            $mt = 8192
            if ($m.generationConfig -and $m.generationConfig.samplingParams -and $m.generationConfig.samplingParams.max_tokens) { $mt = $m.generationConfig.samplingParams.max_tokens }
            $gsdModels += [PSCustomObject]@{
                id = $baseId
                name = $cleanName
                reasoning = $reasoning
                contextWindow = $ctx
                maxTokens = $mt
            }
        }
        if (Test-Path $gsdModelsPath) {
            $gsdConfig = Get-Content $gsdModelsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $gsdConfig.providers.crofai.models = $gsdModels
            $gsdConfig | ConvertTo-Json -Depth 10 -Compress | Set-Content $gsdModelsPath -Encoding UTF8 -NoNewline
            Write-Color "  GSD2: $($gsdModels.Count) models updated" -Color $Colors.Success
        } else {
            Write-Color "  GSD2: models.json not found at $gsdModelsPath" -Color $Colors.Warning
        }
    } catch {
        Write-Color "  GSD2 update skipped: $_" -Color $Colors.Warning
    }

    if ($removed.Count -gt 0) {
        Write-Color "  Removed $($removed.Count) stale models" -Color $Colors.Warning
    }
    if ($added.Count -gt 0) {
        Write-Color "  Added $($added.Count) new models" -Color $Colors.Success
    }

} catch {
    Write-Color "✗ Failed: $_" -Color $Colors.Error
    exit 1
}

exit 0
