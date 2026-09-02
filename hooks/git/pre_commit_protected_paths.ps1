# CANONICAL SOURCE — ai-control-plane/hooks/git/pre_commit_protected_paths.ps1
#
# This is the single authoritative protected-path git pre-commit hook.
# Client repos must NOT own a copy of this file. They install a thin delegation
# wrapper via installers/install-claude-client.ps1, which writes
# .control-plane/hooks/git-pre-commit-protected-paths.ps1 as a resolver shim
# that calls this file at runtime.
#
# Adapter awareness:
#   - Reads protectedPaths[] from .control-plane/protected-paths.json (client repo).
#   - Falls back to ["governance/", "AGENTS.md", "AI_BOOTSTRAP.md"] if file absent.
#
# See hooks/README.md for install instructions and delegation chain diagram.

param(
  [string]$RepoRoot = ".",
  [string]$ProtectedPathsFile = ".control-plane/protected-paths.json"
)

$ErrorActionPreference = "Stop"

$resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$protectedPathsPath = Join-Path $resolvedRepoRoot $ProtectedPathsFile

function Normalize-RepoPath {
  param([string]$Path)

  $normalized = $Path.Replace("\", "/")
  if ($normalized.StartsWith("./", [System.StringComparison]::Ordinal)) {
    $normalized = $normalized.Substring(2)
  }
  return $normalized
}

function Test-GovernanceToken {
  param([string[]]$BlockedNormalizedFiles)

  $tokenPath = Join-Path $resolvedRepoRoot ".control-plane/.governance-approval.json"
  $auditPath = Join-Path $resolvedRepoRoot ".control-plane/.governance-audit.jsonl"

  $now = Get-Date
  $consumed = $false
  $result = "invalid"

  if (-not (Test-Path -LiteralPath $tokenPath)) { return $false }

  try {
    $token = Get-Content -LiteralPath $tokenPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    Remove-Item -LiteralPath $tokenPath -Force -ErrorAction SilentlyContinue
    return $false
  }

  $valid = $true
  $expiresAt = $null
  try { $expiresAt = [datetime]::Parse($token.expiresAt) } catch { $valid = $false }
  if ($valid -and (Get-Date) -gt $expiresAt) { $valid = $false }

  $approvedFiles = @()
  if ($null -ne $token.approvedFiles) { $approvedFiles = @($token.approvedFiles) }

  foreach ($blockedFile in $BlockedNormalizedFiles) {
      $found = $false
      foreach ($approved in $approvedFiles) {
          if ($approved -eq $blockedFile) { $found = $true; break }
      }
      if (-not $found) { $valid = $false }
  }

  # Content binding (added 2026-08-15): if the token carries staged blob
  # hashes, the CURRENT staged blob hash must match — approving file A then
  # committing different content of A is rejected. Legacy tokens without
  # blobHashes are accepted (file-scope only) for backward compatibility.
  #
  # Burn-down audit (2026-08-29, lessons W1a): snapshot the current staged
  # blob hash of every blocked file at consume time, whether or not the
  # token carries blobHashes. Read-only — the index is never modified. The
  # snapshot lands in the approval_consumed audit line so the audit log can
  # prove approved-content == committed-content (or show exactly what
  # drifted between approval and commit).
  $stagedBlobHashes = [ordered]@{}
  $failureReason = ""
  $hashPairs = @()
  foreach ($blockedFile in $BlockedNormalizedFiles) {
    $currentHash = ""
    $ls = & git ls-files -s -- $blockedFile
    if ($LASTEXITCODE -eq 0) {
      $parts = ($ls -split "\s+")
      if ($parts.Count -ge 2) { $currentHash = $parts[1] }
    }
    $stagedBlobHashes[$blockedFile] = $currentHash
    $hashPairs += "$blockedFile=$currentHash"
  }

  if ($valid -and $null -ne $token.blobHashes) {
    foreach ($blockedFile in $BlockedNormalizedFiles) {
      $approvedHash = $null
      foreach ($prop in $token.blobHashes.PSObject.Properties) {
        if ($prop.Name -eq $blockedFile) { $approvedHash = $prop.Value; break }
      }
      if ($null -eq $approvedHash -or $approvedHash -ne $stagedBlobHashes[$blockedFile]) {
        $valid = $false
        $failureReason = "blob_mismatch"
        break
      }
    }
  }

  # Single-use: consume the token regardless of outcome (keep audit evidence).
  if ($valid) { $result = "consumed" }
  elseif ($failureReason -eq "blob_mismatch") { $result = "rejected_blob_mismatch" }
  else { $result = "rejected_expired_or_mismatch" }
  try {
    $auditLine = [ordered]@{
      event = "approval_consumed"
      timestamp = $now.ToString("o")
      token = if ($null -ne $token.token) { $token.token } else { "" }
      result = $result
      failureReason = $failureReason
      blockedFiles = $BlockedNormalizedFiles
      stagedBlobHashes = $stagedBlobHashes
      # Text form survives every PS version's JSON round-trip unchanged —
      # the structured field above is lossy on some ConvertFrom-Json
      # combinations (empty ordered table serializes as [], which CI's PS 7.6
      # turned into a missing/null property on read, 2026-08-29).
      stagedBlobHashesText = ($hashPairs -join ';')
      approvedBy = if ($null -ne $token.approvedBy) { $token.approvedBy } else { "" }
    } | ConvertTo-Json -Compress -Depth 6
    Add-Content -LiteralPath $auditPath -Value $auditLine -Encoding utf8
  } catch {
    # audit write failure must not block the commit flow itself
  }
  Remove-Item -LiteralPath $tokenPath -Force -ErrorAction SilentlyContinue
  return $valid
}

Push-Location $resolvedRepoRoot
try {
  $protected = @()

  if (Test-Path -LiteralPath $protectedPathsPath) {
    $config = Get-Content -LiteralPath $protectedPathsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $config.protectedPaths) {
      $protected = @($config.protectedPaths)
    }
  }

  if ($protected.Count -eq 0) {
    $protected = @("governance/", "AGENTS.md", "AI_BOOTSTRAP.md")
  }

# No environment-variable bypass. Approval requires a token file generated
# by a separate manual run of hooks/git/approve_governance_commit.ps1.


  $stagedFiles = @(& git diff --cached --name-only --diff-filter=ACMR)
  if ($LASTEXITCODE -ne 0) {
    throw "git diff --cached failed"
  }

  $blocked = New-Object System.Collections.Generic.List[string]
  foreach ($file in $stagedFiles) {
    $normalizedFile = Normalize-RepoPath -Path $file
    foreach ($pattern in $protected) {
      $normalizedPattern = Normalize-RepoPath -Path ([string]$pattern)
      if ([string]::IsNullOrWhiteSpace($normalizedPattern)) {
        continue
      }

      $isDirectoryPattern = $normalizedPattern.EndsWith("/")
      $matches = if ($isDirectoryPattern) {
        $normalizedFile.StartsWith($normalizedPattern, [System.StringComparison]::OrdinalIgnoreCase)
      } else {
        $normalizedFile.Equals($normalizedPattern, [System.StringComparison]::OrdinalIgnoreCase)
      }

      if ($matches) {
        $blocked.Add("$normalizedFile") | Out-Null
      }
    }
  }

  if ($blocked.Count -gt 0) {
      if (Test-GovernanceToken -BlockedNormalizedFiles $blocked) {
          Write-Output "protected-path pre-commit: approved by governance token (consumed)"
          exit 0
      }

      [Console]::Error.WriteLine("BLOCKED [pre-commit]: protected governance path staged.")
      foreach ($item in $blocked) {
          [Console]::Error.WriteLine(" - $item")
      }
      [Console]::Error.WriteLine("Run hooks/git/approve_governance_commit.ps1 in a separate terminal step, then rerun git commit.")
      exit 1
  }

  Write-Output "protected-path pre-commit: PASS"
  exit 0
} finally {
  Pop-Location
}
