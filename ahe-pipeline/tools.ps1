$s="C:\\Users\\Administrator\\Scripts\\archive";
$cmd = $args[0]
switch($cmd){
  status{& $s\self-heal-main.ps1 status}
  check{& $s\self-heal-main.ps1 check}
  cycle{& $s\self-heal-main.ps1 cycle}
  fix{& $s\self-heal-main.ps1 fix}
  tokens{& $s\self-heal-main.ps1 tokens}
  sync{& $s\self-heal-main.ps1 sync}
  game-mode{& $s\self-heal-main.ps1 game-mode}
  dev-mode{& $s\self-heal-main.ps1 dev-mode}
  audit{& $s\security-audit.ps1}
  cleanup{& $s\full-cleanup.ps1}
  optimize{& $s\optimize-system.ps1}
  update{& "$env:USERPROFILE\Scripts\update-plugins.ps1"}
  mcpmodel{& "$env:USERPROFILE\Scripts\update-crofai-models.ps1"}
  measure{& $s\measure-pc.ps1}
  pcauto{& $s\pc-autoresearch.ps1}
  validate{& $s\validate-settings.ps1}
  analyze{& $s\analyze-autoresearch.ps1}
  qwenbench{& $s\autoresearch-qwen.ps1}
  integrity{& $s\integrity-check.ps1}
  
  default{Write-Host "Available: status, check, audit, cleanup, optimize, update, mcpmodel, measure, pcauto, validate, analyze, qwenbench, cycle, integrity, fix, sync, tokens, game-mode, dev-mode"
    Write-Host "Example: tools.ps1 status"
    if(-not $cmd){Read-Host "Press Enter to exit"}
    Write-Host 'Usage: tools <subcommand>. Run 'tools' for list.'}
}
