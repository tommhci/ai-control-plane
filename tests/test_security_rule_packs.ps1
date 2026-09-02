<#
.SYNOPSIS
    Tests for security/rules/ rule packs and scan_client_security.ps1 -RulePack support
#>
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot    = Split-Path $PSScriptRoot -Parent
$scanner     = Join-Path $repoRoot "security\scan_client_security.ps1"
$baseRules   = Join-Path $repoRoot "security\rules\base-security.json"
$agentRules  = Join-Path $repoRoot "security\rules\agent-client-baseline.json"
$tmpBase     = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "acp-p11-test-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))")
New-Item -ItemType Directory -Path $tmpBase -Force | Out-Null

$pass = 0; $fail = 0
function Assert-True  { param([bool]$c,[string]$l); if ($c){Write-Output "  PASS: $l";$script:pass++}else{Write-Output "  FAIL: $l";$script:fail++} }

# ── helpers ──────────────────────────────────────────────────────────────────
function New-CleanClient {
    param([string]$name)
    $root = Join-Path $tmpBase $name
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    # .control-plane
    New-Item -ItemType Directory -Path "$root\.control-plane" -Force | Out-Null
    $adapter = @{ adapterId="test-$name"; controlPlaneRepo=$repoRoot; project="test"; ownershipFile=".agents/ACTIVE_EDIT_OWNERSHIP.md"; sessionLog=".agents/session_log.jsonl" }
    $adapter | ConvertTo-Json | Set-Content "$root\.control-plane\adapter.json" -Encoding UTF8
    @{ protectedPaths=@("AGENTS.md","governance/") } | ConvertTo-Json | Set-Content "$root\.control-plane\protected-paths.json" -Encoding UTF8
    # .agents
    New-Item -ItemType Directory -Path "$root\.agents" -Force | Out-Null
    Set-Content "$root\.agents\ACTIVE_EDIT_OWNERSHIP.md" -Value "# lock" -Encoding UTF8
    Set-Content "$root\.agents\session_log.jsonl" -Value '{"event_id":"E001","event_type":"session_start"}' -Encoding UTF8
    # git hooks
    New-Item -ItemType Directory -Path "$root\.git\hooks" -Force | Out-Null
    Set-Content "$root\.git\hooks\pre-commit" -Value "#!/bin/sh`n# control-plane check" -Encoding UTF8
    Set-Content "$root\.git\hooks\post-commit" -Value "#!/bin/sh`n# session capture" -Encoding UTF8
    # .claude settings
    New-Item -ItemType Directory -Path "$root\.claude" -Force | Out-Null
    $settings = @{ hooks=@{ PreToolUse=@(@{ matcher="*"; hooks=@(@{ type="command"; command="check.ps1" }) }) }; permissions=@{ allow=@("Read(*)") } }
    $settings | ConvertTo-Json -Depth 10 | Set-Content "$root\.claude\settings.local.json" -Encoding UTF8
    return $root
}

# ─── test_default_rule_pack_loads ────────────────────────────────────────────
Write-Output ""
Write-Output "=== test_default_rule_pack_loads ==="
Assert-True (Test-Path $baseRules)  "base-security.json exists"
Assert-True (Test-Path $agentRules) "agent-client-baseline.json exists"
$bp = Get-Content -Path $baseRules  | ConvertFrom-Json
$ap = Get-Content -Path $agentRules | ConvertFrom-Json
Assert-True ($bp.rule_pack_id -eq "base-security")            "base pack has rule_pack_id"
Assert-True ($bp.rules.Count -ge 5)                           "base pack has >= 5 rules"
Assert-True ($ap.rule_pack_id -eq "agent-client-baseline")    "agent pack has rule_pack_id"
Assert-True ($ap.extends -eq "base-security")                 "agent pack extends base-security"
Assert-True (@($bp.rules | ForEach-Object { $_.rule_id }) -contains "SEC-001") "base has SEC-001"
Assert-True (@($bp.rules | ForEach-Object { $_.rule_id }) -contains "SEC-006") "base has SEC-006"
Assert-True (@($ap.rules | ForEach-Object { $_.rule_id }) -contains "ACB-001") "agent has ACB-001"

# ─── test_missing_rule_pack_fails_cleanly ────────────────────────────────────
Write-Output ""
Write-Output "=== test_missing_rule_pack_fails_cleanly ==="
$cleanClient = New-CleanClient "clean1"
$errOut = & $scanner -ClientRoot $cleanClient -RulePack "nonexistent-pack.json" 2>&1
Assert-True ($LASTEXITCODE -ne 0 -or [bool]($errOut | Select-String "not found|Cannot")) "missing rule pack fails with error"

# ─── test_scanner_with_base_rule_pack ────────────────────────────────────────
Write-Output ""
Write-Output "=== test_scanner_with_base_rule_pack ==="
$cleanClient2 = New-CleanClient "clean2"
$jsonOut = Join-Path $tmpBase "scan_base.json"
& $scanner -ClientRoot $cleanClient2 -RulePack $baseRules -OutputJson $jsonOut -Quiet 2>$null
Assert-True (Test-Path $jsonOut) "scanner with RulePack writes JSON output"
$result = Get-Content -Path $jsonOut | ConvertFrom-Json
Assert-True ([bool]($result.PSObject.Properties["status"]))   "result has status field"
Assert-True ([bool]($result.PSObject.Properties["score"]))    "result has score field"
Assert-True ([bool]($result.PSObject.Properties["findings"]))  "result has findings field"

# ─── test_scanner_output_includes_rule_id ────────────────────────────────────
Write-Output ""
Write-Output "=== test_scanner_output_includes_rule_id ==="
# Create client missing precommit to trigger SEC-006
$noHookClient = Join-Path $tmpBase "no_hook_client"
New-Item -ItemType Directory -Path $noHookClient -Force | Out-Null
New-Item -ItemType Directory -Path "$noHookClient\.control-plane" -Force | Out-Null
$adapter2 = @{ adapterId="test-nohook"; controlPlaneRepo=$repoRoot; project="test"; ownershipFile=".agents/ACTIVE_EDIT_OWNERSHIP.md"; sessionLog=".agents/session_log.jsonl" }
$adapter2 | ConvertTo-Json | Set-Content "$noHookClient\.control-plane\adapter.json" -Encoding UTF8
@{ protectedPaths=@("AGENTS.md") } | ConvertTo-Json | Set-Content "$noHookClient\.control-plane\protected-paths.json" -Encoding UTF8
New-Item -ItemType Directory -Path "$noHookClient\.agents" -Force | Out-Null
Set-Content "$noHookClient\.agents\session_log.jsonl" -Value "" -Encoding UTF8
# NO .git/hooks/pre-commit — should trigger SEC-006
New-Item -ItemType Directory -Path "$noHookClient\.git\hooks" -Force | Out-Null
$jsonOut2 = Join-Path $tmpBase "scan_nohook.json"
& $scanner -ClientRoot $noHookClient -RulePack $baseRules -OutputJson $jsonOut2 -Quiet 2>$null
$result2 = Get-Content -Path $jsonOut2 | ConvertFrom-Json
$allRuleIds = @($result2.findings | ForEach-Object { $_.rule_id })
Assert-True ($allRuleIds -contains "SEC-006") "findings include rule_id SEC-006 for missing pre-commit"

# ─── test_custom_rule_does_not_print_secrets ─────────────────────────────────
Write-Output ""
Write-Output "=== test_no_secret_value_printed ==="
$secretClient = New-CleanClient "secret_client"
Set-Content "$secretClient\.env" -Value "API_KEY=super-secret-value-abc123" -Encoding UTF8
$jsonOut3 = Join-Path $tmpBase "scan_secret.json"
$rawOut = & $scanner -ClientRoot $secretClient -RulePack $baseRules -OutputJson $jsonOut3 2>&1
$jsonContent = Get-Content -Path $jsonOut3 -Raw
Assert-True (-not ($jsonContent -match "super-secret-value-abc123")) "secret value not in JSON output"
Assert-True (-not ($rawOut -join " " | Select-String "super-secret-value-abc123")) "secret value not in stdout"
Assert-True ([bool]($jsonContent | Select-String "SEC-001")) "SEC-001 rule_id present for .env finding"

# ─── cleanup ──────────────────────────────────────────────────────────────────
Remove-Item -Recurse -Force $tmpBase -ErrorAction SilentlyContinue

Write-Output ""
Write-Output "─────────────────────────────────────────"
$total = $pass + $fail
Write-Output "security_rule_packs: $pass/$total PASS, $fail FAIL"
if ($fail -gt 0) { Write-Output "security_rule_packs: SOME FAILURES"; exit 1 }
else             { Write-Output "security_rule_packs: ALL PASS"; exit 0 }

