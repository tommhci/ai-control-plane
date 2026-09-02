param(
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$ClientRoot = (Join-Path $env:TEMP ("ai-control-plane-git-hook-client-" + [guid]::NewGuid().ToString("N")))
)

$ErrorActionPreference = "Continue"

function Assert-LastExitCode {
  param([string]$Step)
  if ($LASTEXITCODE -ne 0) {
    throw "$Step failed with exit $LASTEXITCODE"
  }
}

function Invoke-GitCommit {
  param([string]$Message)

  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & git commit -m $Message 2>&1
    return [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Output = @($output)
    }
  } finally {
    $ErrorActionPreference = $oldPreference
  }
}

if (Test-Path -LiteralPath $ClientRoot) {
  Remove-Item -LiteralPath $ClientRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $ClientRoot | Out-Null
Push-Location $ClientRoot
try {
  & git init | Out-Null
  Assert-LastExitCode -Step "git init"
  & git config user.email "git-hook-client@example.local" | Out-Null
  Assert-LastExitCode -Step "git config user.email"
  & git config user.name "Git Hook Client" | Out-Null
  Assert-LastExitCode -Step "git config user.name"

  New-Item -ItemType Directory -Force -Path ".control-plane", ".agents" | Out-Null
  "# Git Hook Client`n" | Set-Content -LiteralPath "README.md" -Encoding utf8
  "# Agent Rules`n" | Set-Content -LiteralPath "AGENTS.md" -Encoding utf8
  "# Active Edit Ownership`n`n## Current Ownership`nNone.`n" | Set-Content -LiteralPath ".agents/ACTIVE_EDIT_OWNERSHIP.md" -Encoding utf8

  [ordered]@{
    adapterId = "git-hook-client"
    project = "git-hook-client"
    displayName = "Git Hook Client"
    mode = "client"
    controlPlaneRepo = $ControlPlaneRepo
    sharedAdapterPath = "adapters/generic/adapter.json"
    canonicalSources = @("README.md", "AGENTS.md")
    ownershipFile = ".agents/ACTIVE_EDIT_OWNERSHIP.md"
    sessionLog = ".agents/session_log.jsonl"
    effectivenessLog = ".agents/effectiveness_log.jsonl"
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ".control-plane/adapter.json" -Encoding utf8

  [ordered]@{
    protectedPaths = @("governance/", "AGENTS.md", ".control-plane/protected-paths.json")
    notes = @("Git hook test protected path list.")
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ".control-plane/protected-paths.json" -Encoding utf8

  & git add README.md AGENTS.md .control-plane .agents | Out-Null
  Assert-LastExitCode -Step "git add initial files"
  & git commit -m "init git hook client" | Out-Null
  Assert-LastExitCode -Step "git commit initial files"

  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "installers/install-claude-client.ps1") -RepoRoot "." -AdapterDir ".control-plane" | Out-Null
  Assert-LastExitCode -Step "install-claude-client"

  if (-not (Test-Path -LiteralPath ".git/hooks/pre-commit")) {
    throw "missing installed .git/hooks/pre-commit"
  }

  "protected edit" | Add-Content -LiteralPath "AGENTS.md" -Encoding utf8
  & git add AGENTS.md | Out-Null
  Assert-LastExitCode -Step "git add protected file"

  $blocked = Invoke-GitCommit -Message "blocked protected file"
  if ($blocked.ExitCode -eq 0) {
    throw "Expected protected-path commit to be blocked"
  }

  & git reset -- AGENTS.md | Out-Null
  Assert-LastExitCode -Step "git reset protected staged file"

  "approved protected edit" | Add-Content -LiteralPath "AGENTS.md" -Encoding utf8
  & git add AGENTS.md | Out-Null
  Assert-LastExitCode -Step "git add approved protected file"

  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "hooks/git/approve_governance_commit.ps1") -RepoRoot "." | Out-Null
  Assert-LastExitCode -Step "approve_governance_commit"

  if (-not (Test-Path -LiteralPath ".control-plane/.governance-approval.json")) {
    throw "Expected approve_governance_commit to write a token file"
  }

  $approved = Invoke-GitCommit -Message "approved protected file"
  if ($approved.ExitCode -ne 0) {
    throw "Expected approved protected-path commit to succeed: $($approved.Output -join "`n")"
  }

  if (Test-Path -LiteralPath ".control-plane/.governance-approval.json") {
    throw "Expected governance approval token to be consumed (deleted) after use"
  }

  # Mismatch test: generate a token scoped ONLY to a different protected file
  # (governance/scratch.md), with nothing else staged at approval time, then
  # try to commit an unrelated AGENTS.md change against that stale token.
  New-Item -ItemType Directory -Force -Path "governance" | Out-Null
  "scratch approval target" | Set-Content -LiteralPath "governance/scratch.md" -Encoding utf8
  & git add governance/scratch.md | Out-Null
  Assert-LastExitCode -Step "git add governance scratch file for mismatch setup"

  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "hooks/git/approve_governance_commit.ps1") -RepoRoot "." | Out-Null
  Assert-LastExitCode -Step "approve_governance_commit for governance scratch file"

  if (-not (Test-Path -LiteralPath ".control-plane/.governance-approval.json")) {
    throw "Expected approve_governance_commit to write a token file scoped to governance/scratch.md"
  }

  & git reset -- governance/scratch.md | Out-Null
  Assert-LastExitCode -Step "unstage governance scratch file, keeping its now-orphaned token"
  Remove-Item -LiteralPath "governance/scratch.md" -Force

  "mismatched edit" | Add-Content -LiteralPath "AGENTS.md" -Encoding utf8
  & git add AGENTS.md | Out-Null
  Assert-LastExitCode -Step "git add AGENTS.md for mismatch commit attempt"

  $mismatched = Invoke-GitCommit -Message "mismatched token should still block"
  if ($mismatched.ExitCode -eq 0) {
    throw "Expected commit to be blocked: token was scoped to governance/scratch.md, not the staged AGENTS.md change"
  }
  if (Test-Path -LiteralPath ".control-plane/.governance-approval.json") {
    throw "Expected mismatched token to be consumed (deleted) even though it was rejected"
  }

  & git reset -- AGENTS.md | Out-Null
  & git checkout -- AGENTS.md | Out-Null
  Assert-LastExitCode -Step "restore AGENTS.md after mismatch test"

  "ordinary edit" | Add-Content -LiteralPath "README.md" -Encoding utf8
  & git add README.md | Out-Null
  Assert-LastExitCode -Step "git add ordinary file"

  $allowed = Invoke-GitCommit -Message "ordinary file allowed"
  if ($allowed.ExitCode -ne 0) {
    throw "Expected ordinary commit to succeed: $($allowed.Output -join "`n")"
  }

  Write-Output "git_protected_paths: PASS"
  Write-Output "clientRoot=$ClientRoot"
  Write-Output "blockedExit=$($blocked.ExitCode)"
  Write-Output "approvedExit=$($approved.ExitCode)"
  Write-Output "allowedExit=$($allowed.ExitCode)"
} finally {
  Pop-Location
}
