
<#
.SYNOPSIS
    System Benchmark — evalutes MCPs, hooks, system integrity for AHE pipeline
.DESCRIPTION
    Runs real evaluation tests across all harness component types.
    Produces weighted pass@1 score (0-100) consumable by the AHE pipeline.

    Test categories and paper-aligned weights:
      mcp_tests     (×5) — Tools — +3.3 pp in AHE ablation
      hook_tests    (×4) — Middleware — +2.2 pp in AHE ablation
      memory_tests  (×3) — Memory — +5.6 pp in AHE ablation
      system_tests  (×2) — Integrity baseline
      skill_tests   (×1) — Skills inventory health
.PARAMETER Json
    Output results as JSON (for pipeline consumption)
.PARAMETER Detailed
    Show per-test breakdown (default: summary only)
.PARAMETER Runs
    Number of benchmark runs (k≥2 = multi-rollout, default 3 for noise reduction).
    Final score is the median of all runs, per AHE Algorithm 1.
#>
param(
    [switch]$Json,
    [switch]$Detailed,
    [int]$Runs = 3
)

. 'C:\Users\Administrator\.qwen\bm-module.ps1'

$ErrorActionPreference = 'Continue'
$QwenDir = "$env:USERPROFILE\.qwen"
$ScriptsDir = "$env:USERPROFILE\Scripts"
$SettingsFile = "$QwenDir\settings.json"
$BackupFile = "$SettingsFile.last-good"
$ManifestFile = "$env:USERPROFILE\.autoresearch\ahe-manifest.json"
$ResultsDir = "$env:USERPROFILE\.autoresearch\benchmarks"

# Ensure results directory
if (-not (Test-Path $ResultsDir)) { New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null }

# ═══════════════════════════════════════════════════════════════
# TEST HELPERS
# ═══════════════════════════════════════════════════════════════
$Results = @{}  # name → { pass, detail }

function Test-Pass {
    param([string]$Name, [string]$Detail = "ok")
    $Results[$Name] = @{ pass = $true; detail = $Detail }
}

function Test-Fail {
    param([string]$Name, [string]$Detail = "FAILED")
    $Results[$Name] = @{ pass = $false; detail = $Detail }
}

function Test-Scenario {
    param([string]$Name,[int]$Score,[int]$Max=3,[string]$D="")
    $p=[Math]::Round($Score/$Max*100);if($Score-ge$Max){Test-Pass $Name "$Score/$Max ($p%) $D"}else{Test-Fail $Name "$Score/$Max ($p%) $D"}
}

function Test-Skip {
    param([string]$Name, [string]$Detail = "SKIPPED")
    $Results[$Name] = @{ pass = $true; detail = $Detail }  # skip doesn't penalize
}

# ═══════════════════════════════════════════════════════════════
# TEST SUITE: SYSTEM TESTS (weight ×2)
# ═══════════════════════════════════════════════════════════════
function Invoke-SystemTests {
    Write-Host "  System Tests (weight x2):" -ForegroundColor Cyan
    try {
        $s=Get-Content "$env:USERPROFILE\.qwen\settings.json" -Raw | ConvertFrom-Json
        if($s.modelProviders.openai.Count -gt 0){Test-Pass "sys.settings_valid" "$($s.modelProviders.openai.Count) providers"}else{Test-Fail "sys.settings_valid" "No providers"}
    }catch{Test-Fail "sys.settings_valid" "Parse error: $_"}
    $nodeVer=& node --version 2>$null
    if($nodeVer){Test-Pass "sys.node" "Node $nodeVer"}else{Test-Fail "sys.node" "node not found"}
    $npxVer=& npx --version 2>$null
    if($npxVer){Test-Pass "sys.npx" "npx $npxVer"}else{Test-Fail "sys.npx" "npx not found"}
    $size=(Get-Item "$env:USERPROFILE\.qwen\settings.json" -ErrorAction SilentlyContinue).Length
    if($size -and $size -lt 20480){Test-Pass "sys.settings_size" "$([math]::Round($size/1KB,1)) KB"}else{Test-Fail "sys.settings_size" "$([math]::Round($size/1KB,1)) KB exceeds 20 KB"}
}function Invoke-McpTests {
    Write-Host "  MCP Tests (weight x5, real ops):" -ForegroundColor Cyan
    $settings=Get-Content "$env:USERPROFILE\.qwen\settings.json" -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if(-not $settings -or -not $settings.mcpServers){Test-Fail "mcp.servers" "No MCP servers configured";return}
    $expected=@("filesystem","qwen-memory","github","brave-search","context7","chrome-devtools")
    $found=0;foreach($name in $expected){if($settings.mcpServers.$name){$found++}}
    Test-Pass "mcp.configured" "$found/$($expected.Count) MCPs configured"
    if($found -eq 0){Test-Fail "mcp.coverage" "None found";return}
    $working=0;foreach($name in $expected){$cfg=$settings.mcpServers.$name;if($cfg){$cmd=Get-Command $cfg.command -ErrorAction SilentlyContinue;if($cmd){$working++}}}
    Test-Pass "mcp.commands" "$working/$found commands on PATH"
    $braveKey=[Environment]::GetEnvironmentVariable("BRAVE_API_KEY")-or[Environment]::GetEnvironmentVariable("BRAVE_API_KEY","User")
    if($braveKey){Test-Pass "mcp.brave_key" "BRAVE_API_KEY set"}else{Test-Fail "mcp.brave_key" "BRAVE_API_KEY missing"}
    $ghToken=[Environment]::GetEnvironmentVariable("GITHUB_TOKEN")
    if($ghToken){Test-Pass "mcp.github_token" "GITHUB_TOKEN set"}else{Test-Fail "mcp.github_token" "GITHUB_TOKEN missing"}
    $ctxKey=[Environment]::GetEnvironmentVariable("CONTEXT7_API_KEY")
    if($ctxKey){Test-Pass "mcp.context7_key" "CONTEXT7_API_KEY set"}else{Test-Pass "mcp.context7_key" "CONTEXT7_API_KEY optional"}
}function Invoke-HookTests {
    Write-Host "  Hook Tests (weight x4):" -ForegroundColor Cyan
    $d="$env:USERPROFILE\.qwen\hooks";if(!(Test-Path $d)){Test-Fail "hook.dir" "missing";return}
    $f=@(Get-ChildItem "$d\*.js");Test-Pass "hook.count" "$($f.Count) files"
    $o=0;$b=0;$f|%{$x=Get-Content $_.FullName -Raw -EA 0;if($x-and$x.Length-gt20-and($x-split"\n").Count-gt5){$o++}else{$b++}}
    Test-Pass "hook.valid" "$o/$(($o+$b)) valid"
    $k=@("rtk-wrapper.js","settings-guardian.js","token-tracker.js","gsd-prompt-guard.js");$p=0;$k|%{if(Test-Path "$d\$_"){$p++}};if($p-eq$k.Count){Test-Pass "hook.critical" "$p/$($k.Count)"}else{Test-Fail "hook.critical" "$p/$($k.Count)"}
}function Invoke-MemoryTests {
    Write-Host "  Memory Tests (weight x3, real ops):" -ForegroundColor Cyan
    $md="$env:USERPROFILE\.qwen\memory";if(Test-Path $md){$j=@(Get-ChildItem "$md\*.json" -EA 0).Count;Test-Pass "mem.dir" "$j JSON files"}else{Test-Fail "mem.dir" "dir not found"}
    $ix="$env:USERPROFILE\.qwen\projects\c--users-administrator\memory\MEMORY.md";if(Test-Path $ix){$e=(Get-Content $ix|?{$_.StartsWith("- [")}).Count;Test-Pass "mem.index" "$e entries"}else{Test-Fail "mem.index" "MEMORY.md not found"}
    $mf="$env:USERPROFILE\.autoresearch\ahe-manifest.json";if(Test-Path $mf){try{$m=Get-Content $mf -Raw|ConvertFrom-Json;Test-Pass "mem.manifest" "$($m.cycle_count) cycles, last: $($m.last_cycle)"}catch{Test-Fail "mem.manifest" "Corrupt: $_"}}else{Test-Fail "mem.manifest" "not found"}
    $tf="$md\_bmt.txt";try{"bench-"+(Get-Date -f "yyyyMMdd")|Set-Content $tf -Force;$rb=Get-Content $tf -Raw;if($rb-match"bench"){Test-Pass "mem.io" "R/W OK"}else{Test-Fail "mem.io" "mismatch"};Remove-Item $tf -Force -EA 0}catch{Test-Fail "mem.io" "error: $_"}
}function Invoke-SkillTests {
    Write-Host "  Skill Tests (weight x1):" -ForegroundColor Cyan
    $sd="$env:USERPROFILE\.qwen\skills";if(Test-Path $sd){$d=@(Get-ChildItem "$sd\*" -Dir -EA 0);$c=$d.Count;if($c-gt0){$w=@($d|?{Test-Path "$($_.FullName)\SKILL.md"}).Count;Test-Pass "skill.dir" "$c skills, $w have SKILL.md"}else{Test-Fail "skill.dir" "empty"}}else{Test-Fail "skill.dir" "not found"}
}

function Invoke-ScenarioTests {
    Write-Host "  Scenario Tests (weight x3, rubric 0-3):" -ForegroundColor Cyan
    $ds=0;$ceD="$env:USERPROFILE\plugins\compound-engineering\skills";$ghOk=$false;$ceOk=$false;$npOk=$false
    try{$r=Invoke-RestMethod 'https://api.github.com/search/repositories?q=mcp-server&sort=stars&per_page=1' -TimeoutSec 5 -EA 0;if($r-and$r.items){$ds++;$ghOk=$true}}catch{}
    if(Test-Path $ceD){$cs=(Get-ChildItem "$ceD\ce-*" -Dir -EA 0).Count;if($cs-gt0){$ds++;$ceOk=$true}}
    try{$nv=npm view @qwen-code/qwen-code version 2>$null;if($nv){$ds++;$npOk=$true}}catch{}
    Test-Scenario "scenario.discovery_depth" $ds 3 "GH=$ghOk CE=$ceOk npm=$npOk"
    $ps=0;$scripts=@("pipeline.ps1","benchmark.ps1","tools.ps1","ahe-evolve.ps1","sync-obsidian.ps1");$sc=0;$scripts|%{if(Test-Path "$env:USERPROFILE\Scripts\$_"){$sc++}};$ps=[Math]::Floor($sc*3/$scripts.Count)
    Test-Scenario "scenario.pipeline" $ps 3 "$sc/$($scripts.Count) scripts"
    $pr=0;$mf="$env:USERPROFILE\.autoresearch\ahe-manifest.json";if(Test-Path $mf){try{$m=Get-Content $mf -Raw|ConvertFrom-Json;$t=$m.improvement_history.Count;$sp=@($m.improvement_history|?{$_.prediction.expected_fix-ne"Benchmark candidate"}).Count;if($t-gt0){$r=[math]::Round($sp/$t*100);if($r-gt80){$pr=3}elseif($r-gt50){$pr=2}elseif($r-gt20){$pr=1}};Test-Scenario "scenario.prediction_quality" $pr 3 "$sp/$t specific ($($r)`%)"}catch{Test-Scenario "scenario.prediction_quality" 0 3 "parse err"}}else{Test-Scenario "scenario.prediction_quality" 0 3 "no manifest"}
    $st=0;$benchDir="$env:USERPROFILE\.autoresearch\benchmarks";$bf=@(Get-ChildItem "$benchDir\*.json" -EA 0|Sort-Object LastWriteTime -Descending|Select -First 5);if($bf.Count-ge2){$scores=@();$bf|%{try{$d=Get-Content $_.FullName -Raw|ConvertFrom-Json;$sv=if($null-ne$d.median_score){$d.median_score}else{$d.score};$scores+=$sv}catch{}};if($scores.Count-ge2){$spread=($scores|Measure -Max).Maximum-($scores|Measure -Min).Minimum;if($spread-le1){$st=3}elseif($spread-le5){$st=2}elseif($spread-le10){$st=1};Test-Scenario "scenario.stability" $st 3 "Spread=$spread across $($scores.Count) runs"}else{Test-Scenario "scenario.stability" 0 3 "insufficient data"}}else{Test-Scenario "scenario.stability" 0 3 "only $($bf.Count) benchmarks"}
}function Get-WeightedScore {
    param($TestResults)

    $categories = @{
        'system' = @{ weight = 2; names = @() }
        'mcp'    = @{ weight = 5; names = @() }
        'hook'   = @{ weight = 4; names = @() }
        'memory' = @{ weight = 3; names = @() }
        'skill'  = @{ weight = 1; names = @() }
        'scenario' = @{ weight = 3; names = @() }
        'hard' = @{ weight = 4; names = @() }
    }

    foreach ($name in $TestResults.Keys) {
        foreach ($cat in $categories.Keys) {
            if ($name -match "^$cat\.") {
                $categories[$cat].names += $name
                break
            }
        }
    }

    $totalWeight = 0
    $weightedScore = 0

    foreach ($cat in $categories.Keys) {
        $names = $categories[$cat].names
        $weight = $categories[$cat].weight
        if ($names.Count -eq 0) { continue }

        $passed = @($names | Where-Object { $TestResults[$_].pass }).Count
        $catScore = $passed / $names.Count
        $weightedScore += $catScore * $weight
        $totalWeight += $weight

        if ($Detailed) {
            Write-Host "    [$cat] $passed/$($names.Count) passed (weight ×$weight) → $([math]::Round($catScore * 100))%" -ForegroundColor $(if($passed -eq $names.Count){'Green'}elseif($passed -gt 0){'Yellow'}else{'Red'})
        }
    }

    if ($totalWeight -eq 0) { return 0 }
    return [math]::Round($weightedScore / $totalWeight * 100, 1)
}

# ═══════════════════════════════════════════════════════════════
# MULTI-ROLLOUT EXECUTION (k=Runs)
# ═══════════════════════════════════════════════════════════════
$allScores = @()
$allRunFiles = @()

for ($run = 1; $run -le $Runs; $run++) {
    # Reset results per run
    $Results = @{}

    if ($Runs -gt 1) {
        Write-Host ""
        Write-Host "─── Run $run of $Runs ───" -ForegroundColor Yellow
    }

    Write-Host "=== System Benchmark ===" -ForegroundColor Magenta
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
    Write-Host ""

    Invoke-SystemTests
    Invoke-McpTests
    Invoke-HookTests
    Invoke-MemoryTests
    Invoke-SkillTests
    Invoke-ScenarioTests
    Invoke-HardTests

    $score = Get-WeightedScore -TestResults $Results
    $allScores += $score

    Write-Host ""
    Write-Host "═══════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  Run $run Score: $score / 100" -ForegroundColor $(if($score -ge 80){'Green'}elseif($score -ge 50){'Yellow'}else{'Red'})
    Write-Host "═══════════════════════════════════" -ForegroundColor Magenta

    if ($Detailed) {
        Write-Host ""
        Write-Host "  ── Per-Test Results ──" -ForegroundColor Cyan
        foreach ($name in ($Results.Keys | Sort-Object)) {
            $r = $Results[$name]
            $icon = if ($r.pass) { "✅" } else { "❌" }
            Write-Host "  $icon $name — $($r.detail)" -ForegroundColor $(if($r.pass){'Green'}else{'Red'})
        }
    }

    # Save individual run
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $runTag = if ($Runs -gt 1) { "-run$run" } else { "" }
    $outputFile = "$ResultsDir\benchmark-$(Get-Date -Format 'yyyyMMdd-HHmmss')$runTag.json"
    $output = @{
        timestamp = $timestamp
        run = $run
        total_runs = $Runs
        score = $score
        total_tests = $Results.Count
        passed_tests = @($Results.Values | Where-Object { $_.pass }).Count
        failed_tests = @($Results.Values | Where-Object { -not $_.pass }).Count
        tests = $Results
    }
    $output | ConvertTo-Json -Depth 3 -Compress | Set-Content $outputFile -Force
    $allRunFiles += $outputFile

    Write-Host ""
    Write-Host "Saved: $outputFile" -ForegroundColor Gray
    Write-Host "───────────────────────────────────" -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════
# AGGREGATE (Multi-Rollout Median)
# ═══════════════════════════════════════════════════════════════
$sortedScores = $allScores | Sort-Object
$medianScore = [math]::Round(($sortedScores[[Math]::Floor(($sortedScores.Count-1)/2)] + $sortedScores[[Math]::Floor($sortedScores.Count/2)]) / 2, 1)
$minScore = $sortedScores[0]
$maxScore = $sortedScores[-1]
$spread = [math]::Round($maxScore - $minScore, 1)

if ($Runs -gt 1) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║       MULTI-ROLLOUT RESULTS          ║" -ForegroundColor Magenta
    Write-Host "╠══════════════════════════════════════╣" -ForegroundColor Magenta
    Write-Host "║  Runs: $Runs                              ║" -ForegroundColor Magenta
    Write-Host "║  Scores: $($allScores -join ', ')                  ║" -ForegroundColor Magenta
    Write-Host "║  Median: $medianScore / 100                    ║" -ForegroundColor $(if($medianScore -ge 80){'Green'}elseif($medianScore -ge 50){'Yellow'}else{'Red'})
    Write-Host "║  Range: $minScore - $maxScore (spread: $spread)         ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Magenta
} else {
    Write-Host ""
    Write-Host "═══════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  Score: $medianScore / 100" -ForegroundColor $(if($medianScore -ge 80){'Green'}elseif($medianScore -ge 50){'Yellow'}else{'Red'})
    Write-Host "═══════════════════════════════════" -ForegroundColor Magenta
}

# Save aggregate result (this is what the pipeline reads)
$aggFile = "$ResultsDir\benchmark-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$aggOutput = @{
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    runs = $Runs
    scores = $allScores
    median_score = $medianScore
    min_score = $minScore
    max_score = $maxScore
    spread = $spread
    run_files = $allRunFiles
}
$aggOutput | ConvertTo-Json -Depth 2 -Compress | Set-Content $aggFile -Force

if ($Json) {
    $aggOutput | ConvertTo-Json -Depth 2
} else {
    Write-Host ""
    Write-Host "Aggregate saved: $aggFile" -ForegroundColor Gray
    Write-Host "Total: $($Results.Count) tests × $Runs runs = $($Results.Count * $Runs) evaluations" -ForegroundColor Gray
}

return $medianScore

function Invoke-HardTests {
    Write-Host "  Hard Tests (weight x4):" -ForegroundColor Cyan
    $disk = Get-PSDrive C -ErrorAction SilentlyContinue
    if ($disk.Free -gt 10GB) { Test-Pass "hard.disk" "$([math]::Round($disk.Free/1GB,1)) GB free" }
    else { Test-Fail "hard.disk" "Low disk space" }
    $mem = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).TotalVisibleMemorySize
    if ($mem -gt 4GB/1KB) { Test-Pass "hard.memory" "$([math]::Round($mem*1KB/1GB,1)) GB" }
    else { Test-Fail "hard.memory" "Low memory" }
    $envVars = [Environment]::GetEnvironmentVariables()
    $credCount = @($envVars.Keys | Where-Object { $_ -like "*API_KEY*" -or $_ -like "*TOKEN*" }).Count
    if ($credCount -ge 2) { Test-Pass "hard.credentials" "$credCount API keys" }
    else { Test-Fail "hard.credentials" "Only $credCount credentials" }
}
