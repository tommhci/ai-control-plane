# CANONICAL SOURCE — ai-control-plane/scripts/boundary-lint.ps1
#
# Global-canon boundary check (G/L separation — see AGENTS.md "Layering").
# Binary verdict: exit 0 = PASS, exit 1 = FAIL. Designed for CI (verify
# workflow) and the monthly patrol; no human judgment involved.
#
# What it enforces: global-canon files must not carry tenant (client-project)
# details. Tenant lessons belong in the tenant repo (L layer); this repo keeps
# generic rules (G layer) and de-identified working records (R layer).
#
# Two rule tiers:
#   1. Machine-absolute paths (C:\Users\, C:/Users/, /c/Users/, C--Users-*)  # boundary-lint:allow (pattern definitions must state the patterns)
#      FAIL everywhere in canon, including R-layer files and identifier-exempt
#      dirs. They break on a new machine and leak private layout.
#   2. Client identifiers (tom-os, tom-master, browser-audit-lab, polymarket)  # boundary-lint:allow (pattern definitions must state the patterns)
#      FAIL in canon, EXCEPT inside $ExemptIdentifierDirs (per-client adapter
#      islands whose G/L ownership is an open item — see PROJECT_STATUS.md
#      "Open items") and on lines carrying a `boundary-lint:allow` marker
#      (reviewed exceptions, e.g. detectors that must match known
#      leaked-path signatures to work).
#
# R-layer files ($PathOnlyFiles, currently PROJECT_STATUS.md) may name clients
# (working-log function) but are still checked for machine-absolute paths.
#
# Scan scope (G-layer canon + R-layer status): AGENTS.md, CLAUDE.md,
# PROJECT_STATUS.md, docs/ (top level; audits/ and validation/ are R-layer
# records), hooks/, installers/, protocols/, skills/, security/, templates/,
# adapters/, scripts/, tests/. Not yet scanned: state/, worktrees/,
# permissions/, profiles/ (open item to extend).
#
# Comments are NOT exempt — comments ship with the repo.

param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

# Client identifiers are waived only inside these directories (identifier rule
# only; the machine-path rule still applies there).
$ExemptIdentifierDirs = @(
  "adapters/reference-client/" # boundary-lint:allow (exemption list must name the island)
)

# R-layer working records: identifier mentions allowed, machine paths not.
$PathOnlyFiles = @(
  "PROJECT_STATUS.md"
)

# Machine-absolute path signatures (matched case-insensitively).
$PathPatterns = @(
  'C:\\Users', # boundary-lint:allow (pattern definition)
  'C:/Users', # boundary-lint:allow (pattern definition)
  '/c/Users', # boundary-lint:allow (pattern definition)
  'C--Users' # boundary-lint:allow (pattern definition)
)

# Client identifiers (matched case-insensitively). Bare words like
# "standalone" are deliberately NOT matched — they are ordinary English and
# would flood the lint with false positives.
$IdentifierPatterns = @(
  'tom-os', # boundary-lint:allow (pattern definition)
  'tom-master', # boundary-lint:allow (pattern definition)
  'browser-audit-lab', # boundary-lint:allow (pattern definition)
  'polymarket' # boundary-lint:allow (pattern definition)
)

$AllowMarker = 'boundary-lint:allow'

if (-not (Test-Path -LiteralPath $RepoRoot)) {
  throw "RepoRoot does not exist: $RepoRoot"
}
$repoRootResolved = (Resolve-Path -LiteralPath $RepoRoot).Path.Replace('\', '/').TrimEnd('/')

function Get-CanonTargets {
  $targets = New-Object System.Collections.Generic.List[string]

  foreach ($f in @('AGENTS.md', 'CLAUDE.md', 'PROJECT_STATUS.md')) {
    $p = Join-Path $repoRootResolved $f
    if (Test-Path -LiteralPath $p) { $targets.Add($f + '|' + $p) | Out-Null }
  }

  $dirSpecs = @(
    @{ Dir = 'docs';      Exclusions = @('docs/audits/', 'docs/validation/') },
    @{ Dir = 'hooks';     Exclusions = @() },
    @{ Dir = 'installers'; Exclusions = @() },
    @{ Dir = 'protocols'; Exclusions = @() },
    @{ Dir = 'skills';    Exclusions = @() },
    @{ Dir = 'security';  Exclusions = @() },
    @{ Dir = 'templates'; Exclusions = @() },
    @{ Dir = 'adapters';  Exclusions = @() },
    @{ Dir = 'scripts';   Exclusions = @() },
    @{ Dir = 'tests';     Exclusions = @() }
  )

  foreach ($spec in $dirSpecs) {
    $dirPath = Join-Path $repoRootResolved $spec.Dir
    if (-not (Test-Path -LiteralPath $dirPath)) { continue }
    $files = Get-ChildItem -LiteralPath $dirPath -Recurse -File
    foreach ($file in $files) {
      # The enumerated FULL NAME is the only authority for reading. Never
      # re-derive an absolute path by string concatenation: on hosts where
      # Resolve-Path yields an 8.3 short form (CI runners do), the recomputed
      # prefix mismatches FullName and the joined path is garbage (CI failure
      # 2026-08-29). Rel is display/exemption-only, derived by marker search
      # so it degrades gracefully instead of corrupting reads.
      $abs = $file.FullName
      $absFwd = $abs.Replace('\', '/')
      $marker = '/' + $spec.Dir + '/'
      $idx = $absFwd.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)
      $rel = if ($idx -ge 0) { $absFwd.Substring($idx + 1) } else { $absFwd }
      $excluded = $false
      foreach ($ex in $spec.Exclusions) {
        if ($rel.StartsWith($ex, [System.StringComparison]::OrdinalIgnoreCase)) { $excluded = $true; break }
      }
      if (-not $excluded) { $targets.Add($rel + '|' + $abs) | Out-Null }
    }
  }
  return $targets.ToArray()
}

function Test-ExemptDir {
  param([string]$RelativePath)
  foreach ($exDir in $ExemptIdentifierDirs) {
    if ($RelativePath.StartsWith($exDir, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  return $false
}

$targets = @(Get-CanonTargets)
$hits = New-Object System.Collections.Generic.List[string]

foreach ($entry in $targets) {
  $sep = $entry.LastIndexOf('|')
  $rel = $entry.Substring(0, $sep)
  $abs = $entry.Substring($sep + 1)
  $isPathOnly = $PathOnlyFiles -contains $rel
  $isIdentifierExempt = Test-ExemptDir -RelativePath $rel

  try {
    $lines = [System.IO.File]::ReadAllLines($abs)
  } catch {
    $hits.Add("FAIL [$rel] unreadable file - $($_.Exception.Message.Trim()) - resolve manually")
    continue
  }
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.IndexOf($AllowMarker, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { continue }

    $lineNo = $i + 1

    foreach ($pat in $PathPatterns) {
      if ($line -match $pat) {
        $hits.Add("FAIL [$rel`:$lineNo] machine-absolute path (pattern '$pat'): $($line.Trim())")
        break
      }
    }

    if ($isPathOnly) { continue }
    if ($isIdentifierExempt) { continue }

    foreach ($pat in $IdentifierPatterns) {
      if ($line -match $pat) {
        $hits.Add("FAIL [$rel`:$lineNo] client identifier (pattern '$pat'): $($line.Trim())")
        break
      }
    }
  }
}

foreach ($h in $hits) { Write-Output $h }

if ($hits.Count -gt 0) {
  Write-Output ("boundary-lint: FAIL - {0} hit(s) across {1} file(s). Fix the lines, move tenant details to the tenant repo (L layer), or add a reviewed boundary-lint:allow marker." -f $hits.Count, $targets.Count)
  exit 1
}

Write-Output ("boundary-lint: PASS - {0} file(s) scanned, no client identifiers or machine-absolute paths in canon." -f $targets.Count)
exit 0
