param(
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$ClientRoot = (Join-Path $env:TEMP ("ai-control-plane-dummy-client-" + [guid]::NewGuid().ToString("N"))),
  [switch]$KeepClient  # set by callers that need to reuse the client dir after this test completes
)

$ErrorActionPreference = "Stop"

function Invoke-HookCommand {
  param(
    [string]$Command,
    [string]$InputJson = "",
    [string]$ControlPlaneRepo = ""
  )

  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    # Prefer parameter passing over stdin piping. The write-guard target
    # (check_write_target.ps1) accepts -ToolInputJson; piping the payload via
    # stdin is fragile on PS 5.1 hosts (payload arrives with a UTF-8 BOM after
    # certain prior test runs -> ConvertFrom-Json fails -> hook exits 0,
    # silently unblocked; verified 2026-08-23 with a stdin probe:
    # BASE b64=eyJ... vs POST-OP b64=77u/eyJ...). A triple-shell
    # powershell -Command wrapper additionally loses exit codes on PS 5.1.
    #
    # Match: powershell -NonInteractive -File .control-plane/hooks/check-write-target.ps1 -ProtectedPathsFile .control-plane/protected-paths.json
    $cmdParsed = $null
    if ($Command -match '^\s*powershell(\.exe)?\s+-NonInteractive\s+-File\s+"?([^"\s]+)"?(\s+.*)?$') {
      $cmdParsed = @{ File = $Matches[2].Trim(); Args = if ($Matches[3]) { $Matches[3].Trim() } else { "" } }
    }
    if ($null -ne $cmdParsed -and
        $cmdParsed.File -match 'check-write-target\.ps1$' -and
        -not [string]::IsNullOrWhiteSpace($ControlPlaneRepo)) {
      # Resolve the client root from the wrapper's relative path. The command
      # runs with CWD = client root (dummy test Push-Location'd there), so
      # ".control-plane/hooks/..." is client-relative.
      $wrapperRel = $cmdParsed.File
      $wrapperAbs = if ([System.IO.Path]::IsPathRooted($wrapperRel)) { $wrapperRel } else { Join-Path (Get-Location) $wrapperRel }
      $clientRootAbs = (Resolve-Path (Join-Path (Split-Path -Parent $wrapperAbs) "..\..")).Path
      $protectedPaths = Join-Path $clientRootAbs ".control-plane/protected-paths.json"
      if ($Command -match '-ProtectedPathsFile\s+"?([^"\s]+)"?') {
        $ppRel = $Matches[1]
        if (-not [System.IO.Path]::IsPathRooted($ppRel)) {
          $protectedPaths = Join-Path $clientRootAbs $ppRel
        } else {
          $protectedPaths = $ppRel
        }
      }
      $target = Join-Path $ControlPlaneRepo "hooks/claude-code/check_write_target.ps1"
      if (Test-Path -LiteralPath $target) {
        if ([string]::IsNullOrWhiteSpace($InputJson)) {
          $output = & pwsh -NoProfile -NonInteractive -File $target -ProtectedPathsFile $protectedPaths 2>&1
        } else {
          # Native-argument quote handling differs by host (verified 2026-08-23):
          # - PS 5.1 host corrupts unescaped double quotes in args (real JSON
          #   -> hook exits 0), needs backslash-escaped JSON.
          # - pwsh7 host corrupts backslash-escaped quotes (escaped JSON
          #   -> hook exits 0), needs raw JSON.
          # Escape per host so -ToolInputJson survives parameter passing.
          $jsonArg = if ($PSVersionTable.PSVersion.Major -ge 7) { $InputJson } else { $InputJson.Replace('"', '\"') }
          $output = & pwsh -NoProfile -NonInteractive -File $target -ToolInputJson $jsonArg -ProtectedPathsFile $protectedPaths 2>&1
        }
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($output) }
      }
    }

    # Fallback: full command line with powershell -File prefix -> run innermost
    # script directly with pwsh -File (avoids triple-shell exit-code loss).
    if ($null -ne $cmdParsed) {
      $innerFile = $cmdParsed.File
      $innerArgs = $cmdParsed.Args
      if ([string]::IsNullOrWhiteSpace($InputJson)) {
        if ([string]::IsNullOrWhiteSpace($innerArgs)) {
          $output = & pwsh -NoProfile -NonInteractive -File $innerFile 2>&1
        } else {
          $output = & pwsh -NoProfile -NonInteractive -File $innerFile @($innerArgs -split ' ') 2>&1
        }
      } else {
        if ([string]::IsNullOrWhiteSpace($innerArgs)) {
          $output = $InputJson | & pwsh -NoProfile -NonInteractive -File $innerFile 2>&1
        } else {
          $output = $InputJson | & pwsh -NoProfile -NonInteractive -File $innerFile @($innerArgs -split ' ') 2>&1
        }
      }
    } elseif ($Command -match '^\s*powershell(\.exe)?\s') {
      if ([string]::IsNullOrWhiteSpace($InputJson)) {
        $output = & pwsh -NoProfile -NonInteractive -Command $Command 2>&1
      } else {
        $output = $InputJson | & pwsh -NoProfile -NonInteractive -Command $Command 2>&1
      }
    } elseif ([string]::IsNullOrWhiteSpace($InputJson)) {
      $output = & powershell -NoProfile -NonInteractive -Command $Command 2>&1
    } else {
      $output = $InputJson | & powershell -NoProfile -NonInteractive -Command $Command 2>&1
    }

    return [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Output = @($output)
    }
  } finally {
    $ErrorActionPreference = $oldPreference
  }
}

function Assert-LastExitCode {
  param(
    [string]$Step
  )

  if ($LASTEXITCODE -ne 0) {
    throw "$Step failed with exit $LASTEXITCODE"
  }
}

if (Test-Path -LiteralPath $ClientRoot) {
  Remove-Item -LiteralPath $ClientRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $ClientRoot | Out-Null
Push-Location $ClientRoot
try {
  & git init | Out-Null
  New-Item -ItemType Directory -Force -Path ".control-plane", ".agents" | Out-Null

  "# Dummy Client`n" | Set-Content -LiteralPath "README.md" -Encoding utf8
  "# Active Edit Ownership`n`n## Current Ownership`nNone.`n## Entry Format`n`nplaceholder`n`n## History`n" |
    Set-Content -LiteralPath ".agents/ACTIVE_EDIT_OWNERSHIP.md" -Encoding utf8

  $adapter = [ordered]@{
    adapterId = "generic-dummy"
    project = "generic-dummy"
    displayName = "Generic Dummy Client"
    mode = "client"
    controlPlaneRepo = $ControlPlaneRepo
    sharedAdapterPath = "adapters/generic/adapter.json"
    canonicalSources = @("README.md", "AGENTS.md", "HANDOVER.md")
    ownershipFile = ".agents/ACTIVE_EDIT_OWNERSHIP.md"
    sessionLog = ".agents/session_log.jsonl"
    effectivenessLog = ".agents/effectiveness_log.jsonl"
  }
  $adapter | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ".control-plane/adapter.json" -Encoding utf8

  [ordered]@{
    protectedPaths = @("governance/", "AGENTS.md", ".control-plane/protected-paths.json")
    notes = @("Dummy client protected path list for attach verification.")
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ".control-plane/protected-paths.json" -Encoding utf8

  [ordered]@{
    productSession = [ordered]@{
      primary = @("dummy verification")
    }
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ".control-plane/verification.json" -Encoding utf8

  & git config user.email "dummy-client@example.local" | Out-Null
  Assert-LastExitCode -Step "git config user.email"
  & git config user.name "Dummy Client" | Out-Null
  Assert-LastExitCode -Step "git config user.name"
  & git add README.md .control-plane .agents | Out-Null
  Assert-LastExitCode -Step "git add initial dummy files"
  & git commit -m "init dummy client" | Out-Null
  Assert-LastExitCode -Step "git commit initial dummy client"

  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "installers/install-claude-client.ps1") -RepoRoot "." -AdapterDir ".control-plane" | Out-Null
  Assert-LastExitCode -Step "install-claude-client"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "installers/sync-shared-skills.ps1") -RepoRoot "." -AdapterDir ".control-plane" -SkillsDir ".agents/skills" | Out-Null
  Assert-LastExitCode -Step "sync-shared-skills"

  $settings = Get-Content -LiteralPath ".claude/settings.local.json" -Raw | ConvertFrom-Json
  $preToolUse = @($settings.hooks.PreToolUse | Where-Object { $_.matcher -eq "Write|Edit" })
  if ($preToolUse.Count -ne 1) {
    throw "Expected one Write|Edit PreToolUse hook entry"
  }

  $commands = @($preToolUse[0].hooks | ForEach-Object { $_.command })
  if ($commands.Count -lt 2) {
    throw "Expected ownership and write-guard hook commands"
  }

  foreach ($command in $commands) {
    if ($command -match [regex]::Escape($ControlPlaneRepo)) {
      throw "Generated settings embeds control-plane absolute path: $command"
    }
  }

  $postCommitHook = Get-Content -LiteralPath ".git/hooks/post-commit" -Raw
  if ($postCommitHook -match [regex]::Escape($ControlPlaneRepo)) {
    throw "Generated post-commit hook embeds control-plane absolute path"
  }

  $ownership = Invoke-HookCommand -Command $commands[0] -ControlPlaneRepo $ControlPlaneRepo
  if ($ownership.ExitCode -ne 0) {
    throw "Ownership hook failed with exit $($ownership.ExitCode)"
  }

  # Test 1: Official nested Claude Code payload for protected path (Write/Edit)
  $blocked = Invoke-HookCommand -Command $commands[1] -InputJson '{"tool_name":"Write","tool_input":{"file_path":"governance/policy.md"}}' -ControlPlaneRepo $ControlPlaneRepo
  if ($blocked.ExitCode -ne 2) {
    throw "Expected nested protected path to be blocked with exit 2 (got exit $($blocked.ExitCode); output: $($blocked.Output -join ' | '))"
  }

  # Test 2: Official nested Claude Code payload for ordinary allowed path
  $allowed = Invoke-HookCommand -Command $commands[1] -InputJson '{"tool_name":"Write","tool_input":{"file_path":"src/example.txt"}}' -ControlPlaneRepo $ControlPlaneRepo
  if ($allowed.ExitCode -ne 0) {
    throw "Expected ordinary dummy path to be allowed (got exit $($allowed.ExitCode); output: $($allowed.Output -join ' | '))"
  }

  # Test 3: Backward-compatibility for legacy flat payload
  $legacyBlocked = Invoke-HookCommand -Command $commands[1] -InputJson '{"file_path":"governance/policy.md"}' -ControlPlaneRepo $ControlPlaneRepo
  if ($legacyBlocked.ExitCode -ne 2) {
    throw "Expected legacy flat protected path to be blocked with exit 2 (got exit $($legacyBlocked.ExitCode); output: $($legacyBlocked.Output -join ' | '))"
  }

  # Test 4: Corrupted JSON must fail-closed (exit 2)
  $corrupted = Invoke-HookCommand -Command $commands[1] -InputJson '{invalid json' -ControlPlaneRepo $ControlPlaneRepo
  if ($corrupted.ExitCode -ne 2) {
    throw "Expected corrupted payload to fail-closed with exit 2 (got exit $($corrupted.ExitCode); output: $($corrupted.Output -join ' | '))"
  }

  # Test 5: Missing file_path must fail-closed (exit 2)
  $missingPath = Invoke-HookCommand -Command $commands[1] -InputJson '{"tool_name":"Write","tool_input":{}}' -ControlPlaneRepo $ControlPlaneRepo
  if ($missingPath.ExitCode -ne 2) {
    throw "Expected missing file_path payload to fail-closed with exit 2 (got exit $($missingPath.ExitCode); output: $($missingPath.Output -join ' | '))"
  }

  & powershell -NoProfile -ExecutionPolicy Bypass -File ".control-plane/hooks/capture-session-state.ps1" `
    -SessionId "dummy-attach" `
    -Domain "unknown" `
    -ActiveNodeStatus "verified_now" `
    -TestsStatus "verified_now" `
    -TestsCommand "dummy attach" `
    -TestsResult "pass" `
    -Summary "dummy client attach verification" | Out-Null
  Assert-LastExitCode -Step "capture-session-state wrapper"

  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "state/validate_session_log.ps1") -InputPath ".agents/session_log.jsonl" | Out-Null
  Assert-LastExitCode -Step "validate dummy session log"

  $sharedAdapter = Get-Content -LiteralPath (Join-Path $ControlPlaneRepo "adapters/generic/adapter.json") -Raw | ConvertFrom-Json
  foreach ($skillName in @($sharedAdapter.sharedSkills)) {
    $localSkill = Join-Path ".agents/skills" "$skillName/SKILL.md"
    $sharedSkill = Join-Path $ControlPlaneRepo "skills/$skillName/SKILL.md"
    if (-not (Test-Path -LiteralPath $localSkill)) {
      throw "Missing synced skill: $skillName"
    }
    if ((Get-FileHash -LiteralPath $localSkill -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $sharedSkill -Algorithm SHA256).Hash) {
      throw "Shared skill hash mismatch: $skillName"
    }
  }

  # Verify post-commit template substitution was applied: no literal placeholder remains
  $postCommitHook = Get-Content -LiteralPath ".git/hooks/post-commit" -Raw
  if ($postCommitHook -match '\{\{CAPTURE_SESSION_STATE\}\}') {
    throw "post-commit hook still contains unsubstituted {{CAPTURE_SESSION_STATE}} placeholder"
  }
  if (-not ($postCommitHook -match 'capture-session-state\.ps1')) {
    throw "post-commit hook missing capture-session-state.ps1 reference after substitution"
  }

  # Run health-check as the final integration gate
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "installers/health-check.ps1") -RepoRoot "." -Quiet | Out-Null
  Assert-LastExitCode -Step "health-check"

  Write-Output "dummy_client_attach: PASS"
  Write-Output "clientRoot=$ClientRoot"
  Write-Output "sharedSkills=$($sharedAdapter.sharedSkills.Count)"
  Write-Output "governedExit=$($blocked.ExitCode)"
  Write-Output "allowedExit=$($allowed.ExitCode)"
} finally {
  Pop-Location
  if (-not $KeepClient -and (Test-Path -LiteralPath $ClientRoot)) {
    Remove-Item -LiteralPath $ClientRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
