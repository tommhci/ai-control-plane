param(
  [string]$ClientRoot = ".",
  [string]$AdapterDir = ".control-plane",
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

$resolvedClientRoot = (Resolve-Path -LiteralPath $ClientRoot).Path
$adapterDirPath = Join-Path $resolvedClientRoot $AdapterDir
$adapterPath = Join-Path $adapterDirPath "adapter.json"
$settingsPath = Join-Path $resolvedClientRoot ".claude/settings.local.json"
$postCommitPath = Join-Path $resolvedClientRoot ".git/hooks/post-commit"
$preCommitPath = Join-Path $resolvedClientRoot ".git/hooks/pre-commit"
$legacyPreCommitPs1Path = Join-Path $resolvedClientRoot ".git/hooks/pre-commit.ps1"
$excludedDirectoryNames = @(".git", "node_modules", "dist", "build", ".vite", ".cache")

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-DriftError {
  param([string]$Message)
  $errors.Add($Message) | Out-Null
}

function Add-DriftWarning {
  param([string]$Message)
  $warnings.Add($Message) | Out-Null
}

function Get-RelativePath {
  param([string]$Path)
  $root = $resolvedClientRoot.TrimEnd("\", "/")
  $full = (Resolve-Path -LiteralPath $Path).Path
  if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $full.Substring($root.Length).TrimStart("\", "/").Replace("\", "/")
  }
  return $full.Replace("\", "/")
}

if (-not (Test-Path -LiteralPath $adapterPath)) {
  throw "Missing adapter: $adapterPath"
}

$adapter = Get-Content -LiteralPath $adapterPath -Raw | ConvertFrom-Json
foreach ($field in @("adapterId", "controlPlaneRepo", "sharedAdapterPath", "ownershipFile", "sessionLog")) {
  if ([string]::IsNullOrWhiteSpace($adapter.$field)) {
    Add-DriftError "adapter missing required field: $field"
  }
}

if ($errors.Count -eq 0) {
  $controlPlaneRepo = (Resolve-Path -LiteralPath $adapter.controlPlaneRepo).Path
  $sharedAdapterPath = Join-Path $controlPlaneRepo $adapter.sharedAdapterPath
  if (-not (Test-Path -LiteralPath $sharedAdapterPath)) {
    Add-DriftError "missing shared adapter: $sharedAdapterPath"
  } else {
    $sharedAdapter = Get-Content -LiteralPath $sharedAdapterPath -Raw | ConvertFrom-Json

    if ($null -eq $sharedAdapter.sharedSkills -or @($sharedAdapter.sharedSkills).Count -lt 1) {
      Add-DriftError "shared adapter has no sharedSkills"
    }

    foreach ($template in @($sharedAdapter.hookTemplates.ownershipCommand, $sharedAdapter.hookTemplates.writeGuardCommand, $sharedAdapter.hookTemplates.postCommitCaptureScript)) {
      if ([string]::IsNullOrWhiteSpace($template)) {
        Add-DriftError "shared adapter hook template missing command"
      } elseif ($template -match [regex]::Escape('${controlPlaneRepo}') -or $template -match "state/claim_ownership.ps1|hooks/claude-code/check_write_target.ps1|state/capture_session_state.ps1") {
        Add-DriftError "stale hook template metadata: $template"
      }
    }

    foreach ($skillName in @($sharedAdapter.sharedSkills)) {
      $localSkill = Join-Path $resolvedClientRoot ".agents/skills/$skillName/SKILL.md"
      $sharedSkill = Join-Path $controlPlaneRepo "skills/$skillName/SKILL.md"

      if (-not (Test-Path -LiteralPath $localSkill)) {
        Add-DriftError "missing local shared skill: $skillName"
        continue
      }
      if (-not (Test-Path -LiteralPath $sharedSkill)) {
        Add-DriftError "missing control-plane shared skill: $skillName"
        continue
      }

      $localHash = (Get-FileHash -LiteralPath $localSkill -Algorithm SHA256).Hash
      $sharedHash = (Get-FileHash -LiteralPath $sharedSkill -Algorithm SHA256).Hash
      if ($localHash -ne $sharedHash) {
        Add-DriftError "shared skill hash mismatch: $skillName"
      }
    }

    $localSharedNames = @()
    $skillsRoot = Join-Path $resolvedClientRoot ".agents/skills"
    if (Test-Path -LiteralPath $skillsRoot) {
      $localSharedNames = Get-ChildItem -LiteralPath $skillsRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") } |
        Where-Object { Test-Path -LiteralPath (Join-Path $controlPlaneRepo "skills/$($_.Name)/SKILL.md") } |
        ForEach-Object { $_.Name }
    }

    foreach ($name in $localSharedNames) {
      if (@($sharedAdapter.sharedSkills) -notcontains $name) {
        Add-DriftError "unmanaged duplicate shared skill: $name"
      }
    }
  }

  if (Test-Path -LiteralPath $settingsPath) {
    $settingsRaw = Get-Content -LiteralPath $settingsPath -Raw
    if ($settingsRaw -match [regex]::Escape($controlPlaneRepo)) {
      Add-DriftError "settings.local.json embeds control-plane absolute path"
    }
    $settings = $settingsRaw | ConvertFrom-Json
    $preToolUse = @($settings.hooks.PreToolUse | Where-Object { $_.matcher -eq "Write|Edit" })
    if ($preToolUse.Count -ne 1) {
      Add-DriftError "settings.local.json missing exactly one Write|Edit PreToolUse entry"
    } else {
      $commands = @($preToolUse[0].hooks | ForEach-Object { $_.command })
      if (-not ($commands -match [regex]::Escape(".control-plane/hooks/check-ownership.ps1"))) {
        Add-DriftError "settings.local.json ownership hook does not use repo-local wrapper"
      }
      if (-not ($commands -match [regex]::Escape(".control-plane/hooks/check-write-target.ps1"))) {
        Add-DriftError "settings.local.json write guard does not use repo-local wrapper"
      }
    }
  } else {
    Add-DriftError "missing settings.local.json"
  }

  if (Test-Path -LiteralPath $postCommitPath) {
    $postCommitRaw = Get-Content -LiteralPath $postCommitPath -Raw
    if ($postCommitRaw -match [regex]::Escape($controlPlaneRepo)) {
      Add-DriftError "post-commit hook embeds control-plane absolute path"
    }
    if ($postCommitRaw -notmatch [regex]::Escape('$REPO_ROOT/.control-plane/hooks/capture-session-state.ps1')) {
      Add-DriftError "post-commit hook does not use repo-local capture wrapper"
    }
  } else {
    Add-DriftError "missing .git/hooks/post-commit"
  }

  if (Test-Path -LiteralPath $preCommitPath) {
    $preCommitRaw = Get-Content -LiteralPath $preCommitPath -Raw
    if ($preCommitRaw -match [regex]::Escape($controlPlaneRepo)) {
      Add-DriftError "pre-commit hook embeds control-plane absolute path"
    }
    if ($preCommitRaw -notmatch [regex]::Escape('$REPO_ROOT/.control-plane/hooks/git-pre-commit-protected-paths.ps1')) {
      Add-DriftError "pre-commit hook does not use repo-local protected-path wrapper"
    }
  } else {
    Add-DriftError "missing .git/hooks/pre-commit"
  }

  if (Test-Path -LiteralPath $legacyPreCommitPs1Path) {
    $legacyRaw = Get-Content -LiteralPath $legacyPreCommitPs1Path -Raw
    if ($legacyRaw -notmatch "LEGACY COMPATIBILITY HELPER" -and $legacyRaw -notmatch "git-pre-commit-protected-paths\.ps1") {
      Add-DriftError "stale ambiguous .git/hooks/pre-commit.ps1"
    }
  }

  $activeFiles = @()
  foreach ($relative in @(".claude", ".git/hooks", ".control-plane", ".agents/scripts")) {
    $path = Join-Path $resolvedClientRoot $relative
    if (Test-Path -LiteralPath $path) {
      $activeFiles += Get-ChildItem -LiteralPath $path -File -Recurse -Force
    }
  }

  foreach ($file in $activeFiles) {
    $relative = Get-RelativePath -Path $file.FullName
    if ($relative -in @(".control-plane/adapter.json", ".control-plane/control-plane-root.txt")) {
      continue
    }

    $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($text -match [regex]::Escape($controlPlaneRepo)) {
      Add-DriftError "active wiring embeds control-plane absolute path: $relative"
    }
  }
}

$controlPlaneStateWriter = ""
if ($errors.Count -eq 0) {
  $controlPlaneStateWriter = (Join-Path (Resolve-Path -LiteralPath $adapter.controlPlaneRepo).Path "state/write_session_event.ps1")
}

$sessionWriteFiles = @()
foreach ($root in @($resolvedClientRoot, $(if ($errors.Count -eq 0) { (Resolve-Path -LiteralPath $adapter.controlPlaneRepo).Path } else { "" }))) {
  if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) {
    continue
  }

  $sessionWriteFiles += Get-ChildItem -LiteralPath $root -Recurse -File -Force -Filter "*.ps1" |
    Where-Object {
      $fullName = $_.FullName
      -not ($excludedDirectoryNames | Where-Object { $fullName -match "\\$([regex]::Escape($_))\\" }) -and
      -not ($fullName -match "\\tests\\")
    } |
    Where-Object {
      $lines = Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue
      @($lines | Where-Object { $_ -match "session_log\.jsonl" -and $_ -match "(Add-Content|Set-Content|Out-File)" }).Count -gt 0
    }
}

foreach ($file in $sessionWriteFiles) {
  $full = (Resolve-Path -LiteralPath $file.FullName).Path
  if ($controlPlaneStateWriter -and $full -eq (Resolve-Path -LiteralPath $controlPlaneStateWriter).Path) {
    continue
  }
  Add-DriftError "direct session_log write outside writer: $full"
}

if (-not $Quiet) {
  foreach ($warning in $warnings) {
    Write-Output "WARN: $warning"
  }
  foreach ($driftError in $errors) {
    Write-Output "ERROR: $driftError"
  }
}

if ($errors.Count -gt 0) {
  throw "control-plane drift scan failed with $($errors.Count) error(s)"
}

Write-Output "control_plane_drift_scan: PASS"
