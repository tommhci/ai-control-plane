param(
  [string]$RepoRoot = ".",
  [string]$AdapterDir = ".control-plane"
)

$ErrorActionPreference = "Stop"

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
$resolvedAdapterDir = Join-Path $resolvedRepoRoot $AdapterDir

$adapterPath = Join-Path $resolvedAdapterDir "adapter.json"
$protectedPathsPath = Join-Path $resolvedAdapterDir "protected-paths.json"

$adapter = Get-Content $adapterPath -Raw | ConvertFrom-Json
$controlPlaneRepo = $adapter.controlPlaneRepo
$stopCommand = 'powershell -NonInteractive -Command "$log = (Get-Content .agents/session_log.jsonl -Raw 2>$null); if ($log -match ''session_state'') { Write-Host ''--- SESSION-CLOSE REQUIRED: read .agents/skills/session-close/SKILL.md inline (NOT via Skill tool) ---'' }"'

function Set-ContentIfChanged {
  param(
    [string]$Path,
    [string]$Value,
    [string]$Encoding = "ascii"
  )

  if (Test-Path -LiteralPath $Path) {
    $existing = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ($existing -eq $Value) {
      return
    }
  }

  Set-Content -LiteralPath $Path -Value $Value -Encoding $Encoding
}

if ([string]::IsNullOrWhiteSpace($controlPlaneRepo)) {
  throw "adapter.json is missing controlPlaneRepo"
}

$claimOwnership = Join-Path $controlPlaneRepo "state/claim_ownership.ps1"
$checkWriteTarget = Join-Path $controlPlaneRepo "hooks/claude-code/check_write_target.ps1"
$gitProtectedPreCommit = Join-Path $controlPlaneRepo "hooks/git/pre_commit_protected_paths.ps1"
$captureSessionState = Join-Path $controlPlaneRepo "state/capture_session_state.ps1"
$postCommitTemplate = Join-Path $controlPlaneRepo "hooks/git/templates/post-commit.sh"
$preCommitTemplate = Join-Path $controlPlaneRepo "hooks/git/templates/pre-commit.sh"
$preCommitCompatTemplate = Join-Path $controlPlaneRepo "hooks/git/templates/pre-commit-compat.ps1"
$repoLocalOwnershipHook = ".control-plane/hooks/check-ownership.ps1"
$repoLocalWriteGuardHook = ".control-plane/hooks/check-write-target.ps1"
$repoLocalCaptureHook = ".control-plane/hooks/capture-session-state.ps1"
$repoLocalProtectedPaths = ".control-plane/protected-paths.json"

foreach ($path in @($claimOwnership, $checkWriteTarget, $gitProtectedPreCommit, $captureSessionState, $postCommitTemplate, $preCommitTemplate, $preCommitCompatTemplate)) {
  if (-not (Test-Path $path)) {
    throw "Missing required control-plane file: $path"
  }
}

Push-Location $resolvedRepoRoot
try {
  New-Item -ItemType Directory -Force -Path ".claude" | Out-Null
  New-Item -ItemType Directory -Force -Path ".control-plane/hooks" | Out-Null

  # Resolve the real git hooks dir. Linked worktrees have `.git` as a pointer
  # FILE (no .git/hooks subdir), and git reads hooks from the common dir —
  # hard-coding ".git/hooks" breaks worktree clients (found 2026-08-28 on a
  # worktree-layout client). --git-path resolves correctly for both layouts.
  $gitHooksDir = (& git rev-parse --git-path hooks)
  if (-not [System.IO.Path]::IsPathRooted($gitHooksDir)) {
    $gitHooksDir = Join-Path $resolvedRepoRoot $gitHooksDir
  }
  New-Item -ItemType Directory -Force -Path $gitHooksDir | Out-Null

  $resolverContent = @'
param(
  [string]$RepoRoot = ".",
  [string]$AdapterDir = ".control-plane"
)

$ErrorActionPreference = "Stop"

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
$resolvedAdapterDir = Join-Path $resolvedRepoRoot $AdapterDir
$pointerPath = Join-Path $resolvedAdapterDir "control-plane-root.txt"
$adapterPath = Join-Path $resolvedAdapterDir "adapter.json"

$candidates = @()

if (-not [string]::IsNullOrWhiteSpace($env:AI_CONTROL_PLANE_ROOT)) {
  $candidates += $env:AI_CONTROL_PLANE_ROOT
}

if (Test-Path -LiteralPath $pointerPath) {
  $pointerValue = (Get-Content -LiteralPath $pointerPath -Raw).Trim()
  if (-not [string]::IsNullOrWhiteSpace($pointerValue)) {
    $candidates += $pointerValue
  }
}

if (Test-Path -LiteralPath $adapterPath) {
  $adapter = Get-Content -LiteralPath $adapterPath -Raw | ConvertFrom-Json
  if (-not [string]::IsNullOrWhiteSpace($adapter.controlPlaneRepo)) {
    $candidates += $adapter.controlPlaneRepo
  }
}

foreach ($candidate in $candidates) {
  $path = $candidate.Trim()
  if (-not [System.IO.Path]::IsPathRooted($path)) {
    $path = Join-Path $resolvedRepoRoot $path
  }

  if (Test-Path -LiteralPath $path) {
    Write-Output (Resolve-Path -LiteralPath $path).Path
    exit 0
  }
}

throw "Unable to resolve control-plane root. Set AI_CONTROL_PLANE_ROOT, .control-plane/control-plane-root.txt, or adapter.json controlPlaneRepo."
'@

  $ownershipWrapperContent = @'
param(
  [string]$Tool = "claude-code",
  [string]$Files = "",
  [string]$Purpose = "",
  [string]$ReleaseCondition = "At session-close.",
  [string]$Outcome = "",
  [string]$OwnershipFile = ".agents/ACTIVE_EDIT_OWNERSHIP.md",
  [switch]$CheckOnly,
  [switch]$ReleaseOwnership
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$controlPlaneDir = Split-Path -Parent $scriptDir
$repoRoot = (Resolve-Path (Join-Path $controlPlaneDir "..")).Path
$resolver = Join-Path $controlPlaneDir "resolve-control-plane.ps1"
$controlPlaneRepo = & $resolver -RepoRoot $repoRoot -AdapterDir ".control-plane"
$target = Join-Path $controlPlaneRepo "state/claim_ownership.ps1"

if (-not (Test-Path -LiteralPath $target)) {
  throw "Missing control-plane ownership script: $target"
}

& $target `
  -Tool $Tool `
  -Files $Files `
  -Purpose $Purpose `
  -ReleaseCondition $ReleaseCondition `
  -Outcome $Outcome `
  -OwnershipFile $OwnershipFile `
  -RepoRoot $repoRoot `
  -CheckOnly:$CheckOnly `
  -ReleaseOwnership:$ReleaseOwnership
exit $LASTEXITCODE
'@

  $writeGuardWrapperContent = @'
param(
  [string]$ProtectedPathsFile = ".control-plane/protected-paths.json"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$controlPlaneDir = Split-Path -Parent $scriptDir
$repoRoot = (Resolve-Path (Join-Path $controlPlaneDir "..")).Path
$resolver = Join-Path $controlPlaneDir "resolve-control-plane.ps1"
$controlPlaneRepo = & $resolver -RepoRoot $repoRoot -AdapterDir ".control-plane"
$target = Join-Path $controlPlaneRepo "hooks/claude-code/check_write_target.ps1"

# Anchor a relative ProtectedPathsFile to repoRoot so the guard works regardless
# of the caller's CWD (production hooks run from repo root; health checks may not).
if (-not [System.IO.Path]::IsPathRooted($ProtectedPathsFile)) {
  $ProtectedPathsFile = Join-Path $repoRoot $ProtectedPathsFile
}

if (-not (Test-Path -LiteralPath $target)) {
  throw "Missing control-plane write guard script: $target"
}

& $target -ProtectedPathsFile $ProtectedPathsFile
exit $LASTEXITCODE
'@

  $captureWrapperContent = @'
param(
  [string]$SessionId = "",
  [ValidateSet("product", "governance", "personal", "analytical", "unknown")]
  [string]$Domain = "unknown",
  [string]$ActiveNode = "",
  [ValidateSet("verified_now", "historical", "unknown", "waived_by_user")]
  [string]$ActiveNodeStatus = "unknown",
  [ValidateSet("verified_now", "historical", "not_run", "failed", "unknown", "waived_by_user")]
  [string]$TestsStatus = "not_run",
  [string]$TestsCommand = "",
  [string]$TestsResult = "",
  [string]$Summary = "",
  [string]$OutputPath = ".agents/session_log.jsonl"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$controlPlaneDir = Split-Path -Parent $scriptDir
$repoRoot = (Resolve-Path (Join-Path $controlPlaneDir "..")).Path
$resolver = Join-Path $controlPlaneDir "resolve-control-plane.ps1"
$controlPlaneRepo = & $resolver -RepoRoot $repoRoot -AdapterDir ".control-plane"
$target = Join-Path $controlPlaneRepo "state/capture_session_state.ps1"

if (-not (Test-Path -LiteralPath $target)) {
  throw "Missing control-plane capture script: $target"
}

& $target `
  -SessionId $SessionId `
  -Domain $Domain `
  -ActiveNode $ActiveNode `
  -ActiveNodeStatus $ActiveNodeStatus `
  -TestsStatus $TestsStatus `
  -TestsCommand $TestsCommand `
  -TestsResult $TestsResult `
  -Summary $Summary `
  -OutputPath $OutputPath
'@

  $gitPreCommitWrapperContent = @'
param(
  [string]$ProtectedPathsFile = ".control-plane/protected-paths.json"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$controlPlaneDir = Split-Path -Parent $scriptDir
$repoRoot = (Resolve-Path (Join-Path $controlPlaneDir "..")).Path
$resolver = Join-Path $controlPlaneDir "resolve-control-plane.ps1"
$controlPlaneRepo = & $resolver -RepoRoot $repoRoot -AdapterDir ".control-plane"
$target = Join-Path $controlPlaneRepo "hooks/git/pre_commit_protected_paths.ps1"

if (-not (Test-Path -LiteralPath $target)) {
  throw "Missing control-plane git pre-commit script: $target"
}

& $target -RepoRoot $repoRoot -ProtectedPathsFile $ProtectedPathsFile
exit $LASTEXITCODE
'@

  Set-ContentIfChanged ".control-plane/resolve-control-plane.ps1" -Value $resolverContent -Encoding ascii
  Set-ContentIfChanged ".control-plane/hooks/check-ownership.ps1" -Value $ownershipWrapperContent -Encoding ascii
  Set-ContentIfChanged ".control-plane/hooks/check-write-target.ps1" -Value $writeGuardWrapperContent -Encoding ascii
  Set-ContentIfChanged ".control-plane/hooks/git-pre-commit-protected-paths.ps1" -Value $gitPreCommitWrapperContent -Encoding ascii
  Set-ContentIfChanged ".control-plane/hooks/capture-session-state.ps1" -Value $captureWrapperContent -Encoding ascii

  $basePermissions = @(
    "WebSearch",
    "Bash(xargs wc -l)",
    "Bash(git add *)",
    "Bash(git commit -m ' *)",
    "mcp__Claude_in_Chrome__navigate",
    "mcp__Claude_in_Chrome__browser_batch",
    "mcp__Claude_in_Chrome__get_page_text"
  )
  $extraPermissions = @()
  if ($null -ne $adapter.additionalPermissions) {
    $extraPermissions = @($adapter.additionalPermissions)
  }
  $allPermissions = $basePermissions + $extraPermissions

  $settings = [ordered]@{
    permissions = [ordered]@{
      allow = $allPermissions
    }
    hooks = [ordered]@{
      PreToolUse = @(
        [ordered]@{
          matcher = "Write|Edit"
          hooks = @(
            [ordered]@{
              type = "command"
              command = "powershell -NonInteractive -File $repoLocalOwnershipHook -CheckOnly"
            },
            [ordered]@{
              type = "command"
              command = "powershell -NonInteractive -File $repoLocalWriteGuardHook -ProtectedPathsFile $repoLocalProtectedPaths"
            }
          )
        }
      )
      Stop = @(
        [ordered]@{
          hooks = @(
            [ordered]@{
              type = "command"
              command = $stopCommand
            }
          )
        }
      )
    }
  }

  Set-ContentIfChanged ".claude/settings.local.json" -Value ($settings | ConvertTo-Json -Depth 8) -Encoding utf8

  $hookContent = (Get-Content $postCommitTemplate -Raw).Replace(
    "{{CAPTURE_SESSION_STATE}}",
    '$REPO_ROOT/.control-plane/hooks/capture-session-state.ps1'
  )
  Set-ContentIfChanged (Join-Path $gitHooksDir "post-commit") -Value $hookContent -Encoding ascii

  $preCommitContent = Get-Content $preCommitTemplate -Raw
  Set-ContentIfChanged (Join-Path $gitHooksDir "pre-commit") -Value $preCommitContent -Encoding ascii

  $legacyPreCommitPs1 = Get-Content $preCommitCompatTemplate -Raw
  Set-ContentIfChanged (Join-Path $gitHooksDir "pre-commit.ps1") -Value $legacyPreCommitPs1 -Encoding ascii

  # P3 (cross-repo findings 2026-08-17): the enforcement registration written above
  # must itself appear in protected-paths.json. Merge-only — client-specific entries
  # are never removed. Covers direct harness installs that bypass attach-project.ps1.
  $enforcementSurface = @(
    ".claude/settings.local.json",
    ".control-plane/",
    ".control-plane/hooks/",
    ".control-plane/adapter.json",
    ".control-plane/resolve-control-plane.ps1",
    ".git/hooks/"
  )
  if (Test-Path -LiteralPath $protectedPathsPath) {
    $ppConfig = Get-Content -LiteralPath $protectedPathsPath -Raw | ConvertFrom-Json
    $existing = @($ppConfig.protectedPaths)
    $missing = @($enforcementSurface | Where-Object { $existing -notcontains $_ })
    if ($missing.Count -gt 0) {
      $ppConfig.protectedPaths = @($existing + $missing)
      $ppConfig | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $protectedPathsPath -Encoding utf8
      Write-Output "  UPDATE  .control-plane/protected-paths.json (+$($missing.Count) enforcement-surface entries for P3)"
    }
  } else {
    [ordered]@{
      protectedPaths = $enforcementSurface
      notes = @("generated by install-claude-client.ps1 - enforcement surface only (P3); merge project paths via attach-project.ps1")
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $protectedPathsPath -Encoding utf8
    Write-Output "  WRITE   .control-plane/protected-paths.json (enforcement surface, P3)"
  }
} finally {
  Pop-Location
}

Write-Output "install-claude-client: PASS"
Write-Output "repoRoot=$resolvedRepoRoot"
Write-Output "adapterDir=$resolvedAdapterDir"
