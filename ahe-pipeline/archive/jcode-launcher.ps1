param(
  [switch]$Beta,
  [switch]$Tui,
  [string]$Prompt = ""
)

# Resolve paths
$jcodeBin = "$env:LOCALAPPDATA\jcode\bin\jcode.exe"
$apiKey = [Environment]::GetEnvironmentVariable('CROFAI_API_KEY', 'User')

# Set endpoint
if ($Beta) {
  $env:JCODE_OPENAI_COMPAT_API_BASE = 'https://beta.crof.ai/v1'
  Write-Host "β Using BETA endpoint (beta.crof.ai)" -ForegroundColor Cyan
} else {
  $env:JCODE_OPENAI_COMPAT_API_BASE = 'https://crof.ai/v1'
  Write-Host "Using PRODUCTION endpoint (crof.ai)" -ForegroundColor Green
}

# Override default model
$env:JCODE_OPENAI_COMPAT_DEFAULT_MODEL = 'deepseek-v3.2'
$env:OPENAI_COMPAT_API_KEY = $apiKey

if ($Tui) {
  # Launch interactive TUI
  & $jcodeBin
} elseif ($Prompt) {
  # Run one-shot prompt
  & $jcodeBin run --provider openai-compatible --quiet $Prompt
} else {
  # Default: interactive TUI
  & $jcodeBin
}
