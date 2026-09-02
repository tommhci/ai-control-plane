param(
  [string]$LockPath = ".agents/skills-lock.json",
  [switch]$AllowMismatch
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LockPath)) {
  throw "Missing skills lock: $LockPath"
}

$lock = Get-Content -Raw -LiteralPath $LockPath | ConvertFrom-Json
$errors = New-Object System.Collections.Generic.List[string]

foreach ($entry in $lock.skills) {
  if (-not (Test-Path -LiteralPath $entry.path)) {
    $errors.Add("missing skill file: $($entry.path)")
    continue
  }

  $actual = (Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToUpperInvariant()
  $expected = ([string]$entry.sha256).ToUpperInvariant()

  if ($actual -ne $expected) {
    # EOL-variant tolerance (2026-08-16, batch-2 learning): lock entries may
    # be pinned from an LF (editor-written worktree) or CRLF (autocrlf
    # checkout) copy; accept both, never assume one convention.
    $lfHash = $null
    try {
      $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $entry.path))
      $text = [System.Text.Encoding]::UTF8.GetString($bytes)
      $lfBytes = [System.Text.Encoding]::UTF8.GetBytes(($text -replace "`r`n", "`n"))
      $lfHash = ([BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($lfBytes))).Replace("-", "")
    } catch { }
    if ($lfHash -ne $expected) {
      $errors.Add("hash mismatch: $($entry.skill) path=$($entry.path) expected=$expected actual=$actual")
    }
  }
}

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Output $_ }
  if (-not $AllowMismatch) {
    throw "skills lock validation failed with $($errors.Count) mismatch(es)"
  }
  Write-Output "skills_lock_validation_mismatch_allowed"
  exit 0
}

Write-Output "skills_lock_validation_ok"
