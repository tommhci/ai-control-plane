param(
  [Parameter(Mandatory)]
  [string]$ClientRoot,
  [string]$OutputJson = "",
  [string]$RulePack = "",
  [switch]$FailOnHigh,
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 1  # Version 1 allows .Count on single-item objects; inherited strict mode from parent can cause issues
$ClientRoot = (Resolve-Path $ClientRoot).Path
$scannedAt  = (Get-Date).ToString("o")

# --- RulePack loading (optional - does not change built-in checks) -----------
# When -RulePack is provided, load the pack and surface rule_ids in findings.
# Built-in checks remain authoritative; pack enriches rule_id metadata.
$loadedRulePack = $null
$rulePackRules  = @{}

function Load-RulePack {
  param([string]$packPath)
  if ([string]::IsNullOrWhiteSpace($packPath)) { return }
  $resolved = $packPath
  if (-not [System.IO.Path]::IsPathRooted($packPath)) {
    $resolved = Join-Path $PSScriptRoot $packPath
  }
  if (-not (Test-Path $resolved)) {
    Write-Host "[ERROR] RulePack not found: $resolved"
    exit 1
  }
  try {
    $pack = Get-Content $resolved -Raw -Encoding utf8 | ConvertFrom-Json
    Write-Status "[RulePack] Loaded: $($pack.rule_pack_id) v$($pack.version) - $($pack.description)"
    $script:loadedRulePack = $pack
    foreach ($r in $pack.rules) {
      if ($r.rule_id) { $script:rulePackRules[$r.rule_id] = $r }
    }
  } catch {
    Write-Host "[ERROR] Failed to parse RulePack: $resolved - $_"
    exit 1
  }
}

$findings = [System.Collections.Generic.List[hashtable]]::new()

function Add-Finding {
  param([string]$Severity, [string]$Category, [string]$Path, [string]$Message, [string]$Remediation, [string]$RuleId = "")
  $findings.Add(@{
    rule_id     = $RuleId
    severity    = $Severity
    category    = $Category
    path        = $Path
    message     = $Message
    remediation = $Remediation
  })
}

function Write-Status ([string]$msg) { if (-not $Quiet) { Write-Host $msg } }

Load-RulePack -packPath $RulePack

# -----------------------------------------------------------------------------
# 1. ADAPTER CONFIG
# -----------------------------------------------------------------------------
$adapterPath = Join-Path $ClientRoot ".control-plane\adapter.json"
if (-not (Test-Path $adapterPath)) {
  Add-Finding HIGH "adapter" $adapterPath "adapter.json missing" "Run ai-control-plane installer" "SEC-003"
} else {
  $adapterText = Get-Content $adapterPath -Raw -Encoding utf8
  try {
    $adapter = $adapterText | ConvertFrom-Json
  } catch {
    Add-Finding HIGH "adapter" $adapterPath "adapter.json is not valid JSON: $_" "Fix JSON syntax; check for invalid backslash escapes" "SEC-003"
    $adapter = $null
  }

  if ($null -ne $adapter) {
    $cpRepo = [string]$adapter.controlPlaneRepo
    if ([string]::IsNullOrWhiteSpace($cpRepo) -or $cpRepo -match "FILL_IN") {
      Add-Finding HIGH "adapter" $adapterPath "controlPlaneRepo is unset or placeholder" "Set controlPlaneRepo to the absolute path of your ai-control-plane checkout" "SEC-003"
    } elseif (-not (Test-Path $cpRepo)) {
      Add-Finding MEDIUM "adapter" $adapterPath "controlPlaneRepo path does not exist: $cpRepo" "Verify ai-control-plane is installed at the declared path" "SEC-003"
    }
    if ($adapterText -match '(?<!\\)\\[a-zA-Z](?!["\\nrtbf/])') {
      Add-Finding MEDIUM "adapter" $adapterPath "adapter.json may contain invalid JSON backslash escapes (use \\\\ for Windows paths)" "Replace single backslashes with \\\\" "SEC-003"
    }
    $clientId = [string]$adapter.adapterId
    if ($clientId -ne "reference-client" -and $adapterText -match "legacy-client-backup") { # boundary-lint:allow detector signature (known leaked-path check)
      Add-Finding MEDIUM "adapter" $adapterPath "Non-reference client references legacy-client-backup path" "Remove legacy-client-specific paths from adapter.json" "SEC-003" # boundary-lint:allow detector signature
    }
  }
}

# -----------------------------------------------------------------------------
# 2. PROTECTED PATHS
# -----------------------------------------------------------------------------
$ppPath = Join-Path $ClientRoot ".control-plane\protected-paths.json"
if (-not (Test-Path $ppPath)) {
  Add-Finding HIGH "protected-paths" $ppPath "protected-paths.json missing" "Run ai-control-plane installer" "SEC-004"
} else {
  try {
    $pp = Get-Content $ppPath -Raw -Encoding utf8 | ConvertFrom-Json
    $ppList = if ($pp.PSObject.Properties["protectedPaths"]) { @($pp.protectedPaths) } else { @() }
    if ($ppList.Count -eq 0) {
      Add-Finding HIGH "protected-paths" $ppPath "protectedPaths array is empty - no paths are protected" "Add at minimum AGENTS.md to protectedPaths" "SEC-004"
    } else {
      if ($ppList -notcontains "AGENTS.md") {
        Add-Finding HIGH "protected-paths" $ppPath "AGENTS.md is not in protectedPaths" "Add AGENTS.md to protectedPaths" "SEC-005"
      }
      if (-not ($ppList | Where-Object { $_ -match "\.control-plane" })) {
        Add-Finding LOW "protected-paths" $ppPath ".control-plane directory is not in protectedPaths (recommended)" "Consider adding .control-plane to protectedPaths" "SEC-004"
      }
    }
  } catch {
    Add-Finding HIGH "protected-paths" $ppPath "protected-paths.json is not valid JSON: $_" "Fix JSON syntax" "SEC-004"
  }
}

# -----------------------------------------------------------------------------
# 3. CLAUDE SETTINGS
# -----------------------------------------------------------------------------
# Claude Code is one of several supported harnesses (see profiles/*.json).
# A client with no .claude/ directory at all has likely not opted into the
# Claude Code harness — treat missing settings.local.json as informational in
# that case, not a HIGH failure. A client that HAS a .claude/ directory but is
# missing settings.local.json inside it looks like a broken partial setup —
# keep that HIGH.
$settingsPath = Join-Path $ClientRoot ".claude\settings.local.json"
$claudeDirPath = Join-Path $ClientRoot ".claude"
if (-not (Test-Path $settingsPath)) {
  if (Test-Path $claudeDirPath) {
    Add-Finding HIGH "settings" $settingsPath ".claude/ directory exists but settings.local.json is missing - broken partial Claude Code setup" "Run ai-control-plane installer" "ACB-001"
  } else {
    Add-Finding LOW "settings" $settingsPath ".claude/settings.local.json missing - only relevant if this client uses the Claude Code harness" "Run ai-control-plane installer if using Claude Code" "ACB-001"
  }
} else {
  try {
    $settings = Get-Content $settingsPath -Raw -Encoding utf8 | ConvertFrom-Json
  } catch {
    Add-Finding HIGH "settings" $settingsPath "settings.local.json is not valid JSON: $_" "Fix JSON syntax" "ACB-001"
    $settings = $null
  }

  if ($null -ne $settings) {
    $hooksObj = if ($settings.PSObject.Properties["hooks"]) { $settings.hooks } else { $null }
    $preToolUse = if ($hooksObj -and $hooksObj.PSObject.Properties["PreToolUse"]) { @($hooksObj.PreToolUse) } else { @() }
    if ($preToolUse.Count -eq 0) {
      Add-Finding MEDIUM "settings" $settingsPath "PreToolUse hooks not declared - write-guard may be inactive" "Run install-claude-client.ps1 to wire hooks" "ACB-002"
    }
    $allowAllow = if ($settings.permissions.PSObject.Properties["allow"]) { @($settings.permissions.allow) } else { @() }
    $allowAsk = if ($settings.permissions.PSObject.Properties["ask"]) { @($settings.permissions.ask) } else { @() }
    $allowList = ($allowAllow + $allowAsk) | Where-Object { $_ -ne $null }
    $dangerous = @("Bash(*)", "Write(*)", "Edit(*)")
    foreach ($d in $dangerous) {
      if ($allowList -contains $d) {
        Add-Finding HIGH "settings" $settingsPath "Dangerously broad allow pattern: $d" "Scope allow patterns to specific commands" "ACB-003"
      }
    }
    $permAllow = if ($settings.permissions.PSObject.Properties["allow"]) { @($settings.permissions.allow) } else { @() }
    foreach ($perm in $permAllow) {
      if ([string]$perm -match "bypass|no.verify") {
        Add-Finding HIGH "settings" $settingsPath "Allow permission may bypass hooks: $perm" "Remove or scope this permission" "ACB-003"
      }
    }
  }
}

# -----------------------------------------------------------------------------
# 4. GIT HOOKS
# -----------------------------------------------------------------------------
$gitDir     = Join-Path $ClientRoot ".git"
$preCommit  = Join-Path $gitDir "hooks\pre-commit"
$postCommit = Join-Path $gitDir "hooks\post-commit"

if (-not (Test-Path $preCommit)) {
  Add-Finding HIGH "hooks" $preCommit "pre-commit hook missing - protected-path enforcement inactive" "Run ai-control-plane installer" "SEC-006"
} else {
  $pcContent = Get-Content $preCommit -Raw -Encoding utf8
  if ($pcContent -notmatch "control-plane|protected.path") {
    Add-Finding MEDIUM "hooks" $preCommit "pre-commit hook does not reference control-plane or protected-path scripts" "Verify hook was installed by ai-control-plane" "SEC-009"
  }
  if ($null -ne $adapter -and [string]$adapter.adapterId -ne "reference-client" -and $pcContent -match "legacy-client-backup") { # boundary-lint:allow detector signature (known leaked-path check)
    Add-Finding MEDIUM "hooks" $preCommit "pre-commit hook contains legacy-client-specific path" "Re-run installer to regenerate hook" "SEC-006" # boundary-lint:allow detector signature
  }
}

if (-not (Test-Path $postCommit)) {
  Add-Finding MEDIUM "hooks" $postCommit "post-commit hook missing - session state capture inactive" "Run ai-control-plane installer" "ACB-005"
} else {
  $pocContent = Get-Content $postCommit -Raw -Encoding utf8
  if ($pocContent -match "\{\{CAPTURE_SESSION_STATE\}\}") {
    Add-Finding HIGH "hooks" $postCommit "post-commit hook still has unresolved {{CAPTURE_SESSION_STATE}} template placeholder" "Re-run install-claude-client.ps1 to substitute placeholder" "ACB-006"
  }
}

# -----------------------------------------------------------------------------
# 5. SECRETS / SENSITIVE FILES
# -----------------------------------------------------------------------------
$secretPatterns = @("API_KEY\s*=", "SECRET\s*=", "TOKEN\s*=", "PRIVATE_KEY", "sk-[A-Za-z0-9]{20,}", "ghp_[A-Za-z0-9]{36}", "password\s*=\s*\S+")

$envCandidates = @(".env", ".env.local", ".env.production", ".env.secret")
foreach ($envFile in $envCandidates) {
  $envPath = Join-Path $ClientRoot $envFile
  if (Test-Path $envPath) {
    Add-Finding HIGH "secrets" $envPath ".env file detected - may contain credentials. Contents NOT read." "Add $envFile to .gitignore; move credentials to a secrets manager" "SEC-001"
  }
}

$scanDirs = @(".control-plane", ".agents")
foreach ($d in $scanDirs) {
  $dir = Join-Path $ClientRoot $d
  if (-not (Test-Path $dir)) { continue }
  Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".json",".yaml",".yml",".md",".ps1",".sh") } | ForEach-Object {
    $filePath = $_.FullName
    try {
      $content = Get-Content $filePath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
      if ($null -eq $content) { return }
      foreach ($pattern in $secretPatterns) {
        if ($content -match $pattern) {
          $keyName = ($Matches[0] -replace "=.*", "=<REDACTED>").Trim()
          Add-Finding HIGH "secrets" $filePath "Secret-like pattern found: $keyName" "Remove secret from file; use environment variables or secrets manager" "SEC-002"
          break
        }
      }
    } catch {}
  }
}

# -----------------------------------------------------------------------------
# 6. PROMPT-INJECTION RISKY TEXT
# -----------------------------------------------------------------------------
$injectionPhrases = @(
  "ignore previous instructions",
  "disregard system instructions",
  "reveal hidden prompt",
  "bypass hooks",
  "disable safety",
  "ignore all previous",
  "pretend you have no restrictions"
)

$mdScanDirs = @(".", "audits", "inventory", "docs", ".agents")
foreach ($d in $mdScanDirs) {
  $dir = Join-Path $ClientRoot $d
  if (-not (Test-Path $dir)) { continue }
  Get-ChildItem $dir -File -Filter "*.md" -ErrorAction SilentlyContinue | ForEach-Object {
    $filePath = $_.FullName
    try {
      $content = Get-Content $filePath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
      if ($null -eq $content) { return }
      foreach ($phrase in $injectionPhrases) {
        if ($content -match [regex]::Escape($phrase)) {
          Add-Finding MEDIUM "prompt-injection" $filePath "Possible prompt-injection phrase found: '$phrase'" "Review file content; ensure phrase is quoted/escaped if intentional reference" "SEC-007"
          break
        }
      }
    } catch {}
  }
}

# -----------------------------------------------------------------------------
# 7. DATA / LOG SANITY
# -----------------------------------------------------------------------------
$sessionLog = Join-Path $ClientRoot ".agents\session_log.jsonl"
if (-not (Test-Path $sessionLog)) {
  Add-Finding MEDIUM "data" $sessionLog "session_log.jsonl missing - no session history" "Ensure .agents/ directory exists and write_session_event.ps1 is being used" "SEC-008"
} else {
  $lines = Get-Content $sessionLog -Encoding utf8 -ErrorAction SilentlyContinue
  $malformed = 0
  foreach ($line in $lines) {
    $stripped = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($stripped)) { continue }
    try { $null = $stripped | ConvertFrom-Json } catch { $malformed++ }
  }
  if ($malformed -gt 0) {
    Add-Finding LOW "data" $sessionLog "$malformed malformed line(s) in session_log.jsonl" "Run validate_session_log.ps1 to inspect" "SEC-008"
  }
}

$agentsDir = Join-Path $ClientRoot ".agents"
$dbFiles = if (Test-Path $agentsDir) { @(Get-ChildItem $agentsDir -File -Filter "*.db" -ErrorAction SilentlyContinue) } else { @() }
if ($dbFiles.Count -eq 0) {
  Add-Finding LOW "data" (Join-Path $ClientRoot ".agents") "No SQLite mirror DB found (.agents/*.db)" "Run state/sqlite/import_jsonl_to_sqlite.ps1 to create mirror" "SEC-010"
}

# -----------------------------------------------------------------------------
# SCORING
# -----------------------------------------------------------------------------
$highCount = 0; $mediumCount = 0; $lowCount = 0; $infoCount = 0
foreach ($f in $findings) {
  switch ($f.severity) {
    "HIGH"   { $highCount++ }
    "MEDIUM" { $mediumCount++ }
    "LOW"    { $lowCount++ }
    "INFO"   { $infoCount++ }
  }
}

$score = 100 - ($highCount * 25) - ($mediumCount * 10) - ($lowCount * 3)
if ($score -lt 0) { $score = 0 }

$status = if ($highCount -gt 0) { "FAIL" } elseif ($mediumCount -gt 0) { "WARN" } else { "PASS" }

# -----------------------------------------------------------------------------
# OUTPUT
# -----------------------------------------------------------------------------
if (-not $Quiet) {
  Write-Host ""
  Write-Host "=== Security Scan: $ClientRoot ==="
  if ($loadedRulePack) { Write-Host "RulePack: $($loadedRulePack.rule_pack_id) v$($loadedRulePack.version)" }
  Write-Host "Status : $status  |  Score: $score/100  |  HIGH: $highCount  MEDIUM: $mediumCount  LOW: $lowCount"
  Write-Host ""
  foreach ($f in $findings) {
    $badge = switch ($f.severity) {
      "HIGH"   { "[HIGH  ]" }
      "MEDIUM" { "[MEDIUM]" }
      "LOW"    { "[LOW   ]" }
      default  { "[INFO  ]" }
    }
    $relPath = $f.path.Replace($ClientRoot, "").TrimStart('\').TrimStart('/')
    $ruleTag = if ($f.rule_id) { " [$($f.rule_id)]" } else { "" }
    Write-Host "$badge$ruleTag $($f.category): $relPath"
    Write-Host "         $($f.message)"
    Write-Host "         Remediation: $($f.remediation)"
    Write-Host ""
  }
}

if (-not [string]::IsNullOrWhiteSpace($OutputJson)) {
  $rulePackInfo = if ($loadedRulePack) { @{ rule_pack_id = $loadedRulePack.rule_pack_id; version = $loadedRulePack.version } } else { $null }
  $result = @{
    client_root  = $ClientRoot
    scanned_at   = $scannedAt
    score        = $score
    status       = $status
    rule_pack    = $rulePackInfo
    high_count   = $highCount
    medium_count = $mediumCount
    low_count    = $lowCount
    info_count   = $infoCount
    findings     = @($findings)
  }
  $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputJson -Encoding utf8
  Write-Status "JSON written to: $OutputJson"
}

if ($FailOnHigh -and $highCount -gt 0) {
  exit 1
}
exit 0




