param(
  [string]$RepoRoot   = ".",
  [string]$AdapterDir = ".control-plane",
  [switch]$Quiet
)

# Health check for a control-plane client attachment.
# Verifies all required files, hooks, and adapter fields are present and wired.
# Read-only — does not modify any file.
#
# Usage:
#   .\installers\health-check.ps1 -RepoRoot <path-to-client-repo>
#
# Exit code: 0 = all checks PASS, 1 = one or more checks FAIL.

$ErrorActionPreference = "Stop"

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
$resolvedAdapterDir = Join-Path $resolvedRepoRoot $AdapterDir

$checks  = [System.Collections.Generic.List[object]]::new()
$failed  = 0

function Add-Check {
  param([string]$Name, [bool]$Pass, [string]$Detail = "")
  $script:checks.Add([PSCustomObject]@{ name = $Name; pass = $Pass; detail = $Detail })
  if (-not $Pass) { $script:failed++ }
}

function Check-File {
  param([string]$Name, [string]$Path, [string]$Label = "")
  $exists = Test-Path -LiteralPath $Path
  $lbl = if ($Label) { $Label } else { $Path.Replace($resolvedRepoRoot, "<repo>") }
  Add-Check -Name $Name -Pass $exists -Detail $(if ($exists) { "found: $lbl" } else { "MISSING: $lbl" })
}

# ── 1. Adapter file ──────────────────────────────────────────────────────────

$adapterPath = Join-Path $resolvedAdapterDir "adapter.json"
Check-File "adapter.json present" $adapterPath ".control-plane/adapter.json"

$adapter = $null
if (Test-Path -LiteralPath $adapterPath) {
  try {
    $adapter = Get-Content $adapterPath -Raw | ConvertFrom-Json
  } catch {
    Add-Check "adapter.json parseable" $false "JSON parse error: $_"
  }
}

if ($null -ne $adapter) {
  Add-Check "adapter.controlPlaneRepo set" `
    (-not [string]::IsNullOrWhiteSpace($adapter.controlPlaneRepo) -and $adapter.controlPlaneRepo -notmatch "^FILL_IN") `
    $(if ($adapter.controlPlaneRepo -match "^FILL_IN") { "placeholder not replaced" } else { $adapter.controlPlaneRepo })

  $cpResolved = $false
  if (-not [string]::IsNullOrWhiteSpace($adapter.controlPlaneRepo)) {
    $cpResolved = Test-Path -LiteralPath $adapter.controlPlaneRepo
  }
  Add-Check "controlPlaneRepo path exists" $cpResolved $adapter.controlPlaneRepo
}

# ── 2. Control-plane resolver ────────────────────────────────────────────────

Check-File "resolve-control-plane.ps1" (Join-Path $resolvedAdapterDir "resolve-control-plane.ps1") ".control-plane/resolve-control-plane.ps1"

# ── 3. Hook wrapper scripts ──────────────────────────────────────────────────

$hooksDir = Join-Path $resolvedAdapterDir "hooks"
Check-File "hook: check-ownership.ps1"     (Join-Path $hooksDir "check-ownership.ps1")     ".control-plane/hooks/check-ownership.ps1"
Check-File "hook: check-write-target.ps1"  (Join-Path $hooksDir "check-write-target.ps1")  ".control-plane/hooks/check-write-target.ps1"
Check-File "hook: capture-session-state.ps1" (Join-Path $hooksDir "capture-session-state.ps1") ".control-plane/hooks/capture-session-state.ps1"

# ── 4. Git hooks ─────────────────────────────────────────────────────────────

$gitHooksDir = Join-Path $resolvedRepoRoot ".git/hooks"
Check-File "git pre-commit hook"  (Join-Path $gitHooksDir "pre-commit")  ".git/hooks/pre-commit"
Check-File "git post-commit hook" (Join-Path $gitHooksDir "post-commit") ".git/hooks/post-commit"

# ── 5. Claude settings ───────────────────────────────────────────────────────

$clueSettingsPath = Join-Path $resolvedRepoRoot ".claude/settings.local.json"
Check-File ".claude/settings.local.json" $clueSettingsPath ".claude/settings.local.json"

if (Test-Path -LiteralPath $clueSettingsPath) {
  $raw = Get-Content $clueSettingsPath -Raw
  $hasPreToolUse = $raw -match '"PreToolUse"'
  $hasStop       = $raw -match '"Stop"'
  Add-Check "settings: PreToolUse hook present" $hasPreToolUse ".claude/settings.local.json"
  Add-Check "settings: Stop hook present"       $hasStop       ".claude/settings.local.json"
}

# ── 6. Protected paths file ───────────────────────────────────────────────────

$protectedPathsPath = Join-Path $resolvedAdapterDir "protected-paths.json"
Check-File "protected-paths.json" $protectedPathsPath ".control-plane/protected-paths.json"

if (Test-Path -LiteralPath $protectedPathsPath) {
  try {
    $pp = Get-Content $protectedPathsPath -Raw | ConvertFrom-Json
    $hasEntries = ($null -ne $pp.protectedPaths -and @($pp.protectedPaths).Count -gt 0)
    Add-Check "protected-paths has entries" $hasEntries "$((@($pp.protectedPaths)).Count) entry/entries"
  } catch {
    Add-Check "protected-paths.json parseable" $false "JSON parse error: $_"
  }
}

# ── 7. Session log directory ──────────────────────────────────────────────────

$agentsDir = Join-Path $resolvedRepoRoot ".agents"
Check-File ".agents/ directory" $agentsDir ".agents/"

# ── 8. Shared skills (optional) ───────────────────────────────────────────────

$skillsDir   = Join-Path $resolvedRepoRoot ".agents/skills"
$sessionClose = Join-Path $skillsDir "session-close/SKILL.md"
$skillsOk    = Test-Path -LiteralPath $sessionClose
Add-Check "shared skills synced (session-close)" $skillsOk $(if ($skillsOk) { "found" } else { "run sync-shared-skills.ps1 to install" })

# ── 9. Write-guard functional smoke test ──────────────────────────────────────

$writeGuardPath = Join-Path $hooksDir "check-write-target.ps1"
if (Test-Path -LiteralPath $writeGuardPath) {
  # Native stderr (e.g. the BLOCKED message) must not become a terminating
  # error under Stop preference — same class as the PBR-TestHarness issue.
  # -NoProfile: without it, PS 5.1 hosts consume the stdin pipe during profile
  # lookup, so the write-guard child reads empty stdin and exits 0 (false
  # negative for the block test). Cross-shell verified 2026-08-23 (backlog
  # clearance phase 4): PS5.1 host -> exit 2 with -NoProfile, exit 0 without;
  # pwsh7 host -> exit 2 either way.
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $testPayload = '{"file_path":"README.md"}'
  $exitCode = $null
  try {
    $testPayload | & powershell -NoProfile -NonInteractive -File $writeGuardPath 2>$null
    $exitCode = $LASTEXITCODE
  } catch {
    $exitCode = -1
  } finally {
    $ErrorActionPreference = $prevEAP
  }
  $guardOk = ($exitCode -eq 0)
  Add-Check "write-guard smoke test (README.md -> exit 0)" $guardOk "exit=$exitCode"
}

# ── 10. Enforcement surface protected (P3, findings register 2026-08-17) ──────
# Only applies when the Claude Code harness registry exists: the registry file,
# hook wrappers, and git-hook backstop must be inside protected-paths.json,
# otherwise an agent can rewrite its own enforcement registration.

if (Test-Path -LiteralPath $clueSettingsPath) {
  $requiredSurface = @(
    ".claude/settings.local.json",
    ".git/hooks/"
  )
  $surfaceOk = $false
  $surfaceDetail = "protected-paths.json missing or unparseable"
  if (Test-Path -LiteralPath $protectedPathsPath) {
    try {
      $ppSurface = Get-Content $protectedPathsPath -Raw | ConvertFrom-Json
      $protectedList = @($ppSurface.protectedPaths)
      # Control-plane adapter dir: the broad ".control-plane/" entry satisfies
      # the wrapper-surface requirement on its own; otherwise require the
      # specific ".control-plane/hooks/" entry.
      $cpCovered = ($protectedList -contains ".control-plane/") -or ($protectedList -contains ".control-plane/hooks/")
      $unprotected = @($requiredSurface | Where-Object { $protectedList -notcontains $_ })
      if (-not $cpCovered) { $unprotected = @(".control-plane/ (or .control-plane/hooks/)") + $unprotected }
      $surfaceOk = ($unprotected.Count -eq 0)
      if ($surfaceOk) {
        $surfaceDetail = "registry, wrappers, git hooks covered"
      } else {
        $surfaceDetail = "unprotected: $($unprotected -join ', ') - re-run install-claude-client.ps1 to merge"
      }
    } catch {
      $surfaceDetail = "protected-paths.json parse error: $_"
    }
  }
  Add-Check "enforcement surface in protected paths (P3)" $surfaceOk $surfaceDetail

  if (Test-Path -LiteralPath $writeGuardPath) {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $blockPayload = '{"file_path":".claude/settings.local.json"}'
    $blockExit = $null
    try {
      $blockPayload | & powershell -NoProfile -NonInteractive -File $writeGuardPath 2>$null
      $blockExit = $LASTEXITCODE
    } catch {
      $blockExit = -1
    } finally {
      $ErrorActionPreference = $prevEAP
    }
    Add-Check "write-guard blocks registry edit (P3 negative control)" ($blockExit -eq 2) "exit=$blockExit"
  }
}

# ── Output ────────────────────────────────────────────────────────────────────

if (-not $Quiet) {
  foreach ($c in $checks) {
    $icon = if ($c.pass) { "[PASS]" } else { "[FAIL]" }
    $color = if ($c.pass) { "Green" } else { "Red" }
    Write-Host "$icon $($c.name)" -ForegroundColor $color -NoNewline
    if ($c.detail) { Write-Host "  [$($c.detail)]" -ForegroundColor DarkGray } else { Write-Host }
  }
  Write-Host ""
}

# Disk-space preflight (WARN only, added 2026-08-23). A 0-GB-free C: drive
# caused phantom test failures (disk-full errors masquerading as logic bugs);
# this alerts before that class of waste recurs. WARN does not affect exit code.
$diskDrive = [System.IO.Path]::GetPathRoot($resolvedRepoRoot)
try {
  $diskFree = (Get-PSDrive -Name $diskDrive[0] -ErrorAction Stop).Free
  $diskFreeGB = [math]::Round($diskFree / 1GB, 1)
  if ($diskFreeGB -lt 2.0) {
    Write-Host "[WARN] disk space on ${diskDrive}: $diskFreeGB GB free — below 2 GB; phantom-failure risk (disk-full errors can masquerade as test/logic failures)" -ForegroundColor Yellow
  } else {
    Write-Host "[OK  ] disk space on ${diskDrive}: $diskFreeGB GB free" -ForegroundColor DarkGray
  }
} catch {
  Write-Host "[WARN] disk preflight skipped: $_" -ForegroundColor Yellow
}

$total  = $checks.Count
$passed = $total - $failed

if ($failed -eq 0) {
  Write-Host "health-check: PASS ($passed/$total checks)" -ForegroundColor Green
  exit 0
} else {
  Write-Host "health-check: FAIL ($passed/$total checks, $failed failed)" -ForegroundColor Red
  exit 1
}
