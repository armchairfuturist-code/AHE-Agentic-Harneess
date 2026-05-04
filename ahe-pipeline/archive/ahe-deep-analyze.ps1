$py = "C:\Users\Administrator\Scripts\archive\ahe-research-module.py"
$analysis = Join-Path $env:USERPROFILE ".autoresearch\knowledge\deep-analysis.json"
$findingsFile = Join-Path $env:USERPROFILE ".autoresearch\knowledge\research-findings.json"

# Get latest candidates
& python $py 2>$null | Out-Null

# Read findings
$findings = Get-Content $findingsFile -Raw | ConvertFrom-Json
$mcps = $findings.mcps

# Dedup and filter
$seen = @{}
$relevant = @()
foreach ($m in $mcps) {
    $n = $m.name
    if (-not $seen.ContainsKey($n) -and $n -notmatch "xhs|nginx|muapi|gemini-cli") {
        $seen[$n] = $true
        $relevant += $m
    }
}
$relevant = $relevant | Sort-Object stars -Descending | Select-Object -First 5

# Our current MCPs
$existing = "filesystem","github","brave-search","context7","chrome-devtools","qwen-memory","autocontext","mcp-toolbox"
$gaps = "web scraping (only brave-search URLs, not page content)","code indexing (no graph/understanding MCP)","monitoring/observability (no log/metrics MCP)"

# Build candidate descriptions
$candText = ""
for ($i=0; $i -lt $relevant.Count; $i++) {
    $c = $relevant[$i]
    $candText += "$($i+1). $($c.name) ($($c.stars)★) - $($c.desc)`n"
}

$prompt = @"
Analyze these MCP servers for an AHE harness.
EXISTING MCPs: $($existing -join ', ')
KEY GAPS: $($gaps -join '; ')
CANDIDATES:
$candText
Return JSON: [{rank, name, gap_filled, install_effort:easy/medium/hard, recommendation:install/skip/defer, reasoning}]
"@

$output = "HARNESS: $($existing -join ', ') | Benchmark: 100/100 | Gaps: $($gaps -join ', ') | $candText"
$rubric = "Score 0-1. Return JSON array with per-candidate analysis including rank, name, gap_filled, install_effort, recommendation (install/skip/defer), reasoning. Non-JSON = score 0."

$env:OPENAI_API_KEY = [Environment]::GetEnvironmentVariable("CROFAI_API_KEY","User")
$env:OPENAI_BASE_URL = "https://crof.ai/v1"
$env:AUTOCONTEXT_JUDGE_MODEL = "kimi-k2.6-precision"

$result = & python -m autocontext.cli judge -p $prompt -o $output -r $rubric --json --provider openai-compatible 2>&1 | Out-String

try {
    $r = $result | ConvertFrom-Json
    Write-Host "Score: $($r.score)"
    Write-Host "Reasoning: $($r.reasoning)"
    $r | ConvertTo-Json -Depth 5 | Set-Content $analysis -Force
    Write-Host "Analysis saved: $analysis"
} catch {
    Write-Host "Error parsing result: $result"
}
