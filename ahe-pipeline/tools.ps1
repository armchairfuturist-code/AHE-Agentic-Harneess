$s = "C:\Users\Administrator\Scripts\archive"
$cmd = $args[0]

function Run-Script {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) {
        Write-Host "ERROR: $Label script not found at $Path" -ForegroundColor Red
        return
    }
    & $Path @args
}

if (-not $cmd) {
    Write-Host "Available: status, check, audit, cleanup, optimize, update, mcpmodel, measure, pcauto, validate, analyze, qwenbench, cycle, integrity, fix, sync, tokens, game-mode, dev-mode"
    Write-Host "Example: tools.ps1 status"
    Read-Host "Press Enter to exit"
    exit
}

switch($cmd) {
    status     { Run-Script "$s\self-heal-main.ps1" "Self-Heal" status }
    check      { Run-Script "$s\self-heal-main.ps1" "Self-Heal" check }
    cycle      { Run-Script "$s\self-heal-main.ps1" "Self-Heal" cycle }
    fix        { Run-Script "$s\self-heal-main.ps1" "Self-Heal" fix }
    tokens     { Run-Script "$s\self-heal-main.ps1" "Self-Heal" tokens }
    sync       { Run-Script "$s\self-heal-main.ps1" "Self-Heal" sync }
    game-mode  { Run-Script "$s\self-heal-main.ps1" "Self-Heal" game-mode }
    dev-mode   { Run-Script "$s\self-heal-main.ps1" "Self-Heal" dev-mode }
    audit      { Run-Script "$s\security-audit.ps1" "Security-Audit" }
    cleanup    { Run-Script "$s\full-cleanup.ps1" "Full-Cleanup" }
    optimize   { Run-Script "$s\optimize-system.ps1" "Optimize-System" }
    update     { & "$env:USERPROFILE\Scripts\update-plugins.ps1" }
    mcpmodel   { & "$env:USERPROFILE\Scripts\update-crofai-models.ps1" }
    measure    { Run-Script "$s\measure-pc.ps1" "Measure-PC" }
    pcauto     { Run-Script "$s\pc-autoresearch.ps1" "PC-Autoresearch" }
    validate   { Run-Script "$s\validate-settings.ps1" "Validate-Settings" }
    analyze    { Run-Script "$s\analyze-autoresearch.ps1" "Analyze-Autoresearch" }
    qwenbench  { Run-Script "$s\autoresearch-qwen.ps1" "Autoresearch-Qwen" }
    integrity  { Run-Script "$s\integrity-check.ps1" "Integrity-Check" }
    default    { Write-Host "Unknown command: $cmd. Run 'tools' without args for list." }
}
