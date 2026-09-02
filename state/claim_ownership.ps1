param(
  [string]$Tool = "claude-code",
  [string]$Files = "",
  [string]$Purpose = "",
  [string]$ReleaseCondition = "At session-close.",
  [string]$Outcome = "",
  [string]$OwnershipFile = ".agents/ACTIVE_EDIT_OWNERSHIP.md",
  [string]$RepoRoot = "",
  [switch]$CheckOnly,
  [switch]$ReleaseOwnership
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm UTC"
$content = Get-Content $OwnershipFile -Raw -ErrorAction SilentlyContinue

# Normalize tool name: remove non-alphanumeric chars except /, lowercase.
# Keeps session qualifiers (Owner/A stays "owner/a") so Owner/A and Owner/B remain distinct.
function Get-NormalizedTool {
  param([string]$Name)
  return ($Name -replace '[^a-zA-Z0-9/]', '').ToLower()
}

# Test whether two tool names refer to the same owner.
# Rule: if BOTH have session qualifiers, require exact match.
#       If ONE has no qualifier, match on base name only.
# This handles "claude-code" (hook default) matching "ClaudeCode/session-suffix" (claim identifier).
function Test-ToolMatch {
  param([string]$A, [string]$B)
  $nA = Get-NormalizedTool $A
  $nB = Get-NormalizedTool $B
  if ($nA -eq $nB) { return $true }
  $baseA = $nA -replace '/.*', ''
  $baseB = $nB -replace '/.*', ''
  # One side has no qualifier → base-name match is sufficient
  if ($nA -notmatch '/' -and $baseA -eq $baseB) { return $true }
  if ($nB -notmatch '/' -and $baseA -eq $baseB) { return $true }
  return $false
}

function Get-WorktreeRemedy {
  param(
    [string]$CurrentTool,
    [string]$CurrentRepoRoot
  )

  if ([string]::IsNullOrWhiteSpace($CurrentRepoRoot) -or -not (Test-Path -LiteralPath $CurrentRepoRoot)) {
    return "REMEDY: use a separate git worktree for the second writer, or wait for the current owner to release ownership."
  }

  $worktreeScript = Join-Path $scriptDir "..\worktrees\new_task_worktree.ps1"
  $resolvedWorktreeScript = (Resolve-Path -LiteralPath $worktreeScript).Path
  $safeTool = (($CurrentTool -replace '[^A-Za-z0-9._-]', '-').Trim('-')).ToLower()
  if ([string]::IsNullOrWhiteSpace($safeTool)) {
    $safeTool = "writer"
  }

  return "REMEDY: either wait for the current owner to release ownership, or create a separate worktree: powershell -NoProfile -ExecutionPolicy Bypass -File `"$resolvedWorktreeScript`" -RepoRoot `"$CurrentRepoRoot`" -Name `"$safeTool`""
}

function Get-CurrentOwnershipBody {
  param([string]$Text)

  $match = [regex]::Match(
    $Text,
    '(?s)## Current Ownership\r?\n(.*?)\r?\n## Entry Format'
  )

  if (-not $match.Success) {
    return "None."
  }

  return $match.Groups[1].Value.Trim()
}

function Set-CurrentOwnershipBody {
  param(
    [string]$Text,
    [string]$NewBody
  )

  return [regex]::Replace(
    $Text,
    '(?s)(## Current Ownership\r?\n)(.*?)(\r?\n## Entry Format)',
    ('$1' + $NewBody.Trim() + '$3')
  )
}

$currentBody = Get-CurrentOwnershipBody -Text $content

# Active-claim detection (hardened 2026-08-29 by zcode, synthetic-fixture verified):
# a body line counts as the current claimant only if it has an owner= and is not a
# released entry — bracket marker 'released]' OR a release field that self-declares
# RELEASED/superseded. The 2026-08 defect class (releases recorded in the release
# field without the bracket marker) previously fail-closed ALL new claims repo-wide.
$bodyOwner = ''
foreach ($bodyLine in ($currentBody -split "\r?\n")) {
  if ($bodyLine -notmatch 'owner=') { continue }
  $lineOwner = [regex]::Match($bodyLine, 'owner=(\S+)').Groups[1].Value
  $isReleasedLine = ($bodyLine -match '\breleased\]') -or ($bodyLine -match 'release="[^"]*(RELEASED|superseded)')
  if (-not $isReleasedLine) { $bodyOwner = $lineOwner; break }
}

$isNone = [string]::IsNullOrWhiteSpace($currentBody) -or $currentBody -match '^(?i:none\.?)$' -or [string]::IsNullOrWhiteSpace($bodyOwner)

if ($CheckOnly) {
  if (-not $isNone -and -not (Test-ToolMatch $Tool $bodyOwner)) {
    [Console]::Error.WriteLine("OWNERSHIP CONFLICT: $currentBody")
    [Console]::Error.WriteLine((Get-WorktreeRemedy -CurrentTool $Tool -CurrentRepoRoot $RepoRoot))
    exit 2
  }
  Write-Output "OK: No conflicting ownership found"
  exit 0
}

if ($ReleaseOwnership) {
  if ([string]::IsNullOrWhiteSpace($Outcome)) {
    $Outcome = "Released by $Tool"
  }

  $releaseEntry = "[$timestamp released] owner=$Tool files=`"$Files`" outcome=`"$Outcome`""
  $remaining = @()

  if (-not $isNone) {
    $remaining = @(
      $currentBody -split "\r?\n" |
      Where-Object {
        if (-not $_.Trim()) { return $false }
        $lineOwner = [regex]::Match($_, 'owner=(\S+)').Groups[1].Value
        if (-not $lineOwner) { return $false }
        # Released entries and non-entry junk lines (fences/headings) do not
        # belong in the active body — dropping them lets the body reach the
        # canonical "None." state instead of accumulating forever.
        $isReleasedLine = ($_ -match '\breleased\]') -or ($_ -match 'release="[^"]*(RELEASED|superseded)')
        if ($isReleasedLine) { return $false }
        -not (Test-ToolMatch $Tool $lineOwner)
      }
    )
  }

  $newBody = if ($remaining.Count -gt 0) {
    ($remaining -join "`r`n").Trim()
  } else {
    "None."
  }

  $updated = Set-CurrentOwnershipBody -Text $content -NewBody $newBody
  Set-Content -LiteralPath $OwnershipFile -Value $updated -Encoding utf8
  Add-Content -LiteralPath $OwnershipFile -Value $releaseEntry -Encoding utf8
  Write-Output "Released: $releaseEntry"
  exit 0
}

if (-not $isNone -and -not (Test-ToolMatch $Tool $bodyOwner)) {
  [Console]::Error.WriteLine("OWNERSHIP CONFLICT: $currentBody")
  [Console]::Error.WriteLine((Get-WorktreeRemedy -CurrentTool $Tool -CurrentRepoRoot $RepoRoot))
  exit 2
}

$entry = "[$timestamp active] owner=$Tool files=`"$Files`" purpose=`"$Purpose`" release=`"$ReleaseCondition`""
$updated = Set-CurrentOwnershipBody -Text $content -NewBody $entry
Set-Content -LiteralPath $OwnershipFile -Value $updated -Encoding utf8
Write-Output "Claimed: $entry"
