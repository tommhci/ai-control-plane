#Requires -Version 7
# ai-control-plane encoding health check (read-only, observation-only).
# Verifies every text file: strict UTF-8 validity, no BOM, no CRLF line endings.
#   Exit 0 = clean (ENCODING_CHECK_OK)
#   Exit 1 = violations found (ENCODING_CHECK_VIOLATIONS)
# Usage: pwsh -NoProfile -File scripts/check-encoding.ps1 [-AllText]
#
# .ps1 exception (added 2026-08-23): Windows PowerShell 5.1 reads BOM-less
# UTF-8 scripts as ANSI/GBK on zh-CN systems, corrupting non-ASCII content and
# breaking parsing (verified: list-profiles.ps1 etc.). .ps1 files therefore
# REQUIRE either a UTF-8 BOM or pure-ASCII content; BOM on .ps1 is a feature,
# not a violation. md/txt keep the no-BOM rule.
[CmdletBinding()]
param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot),
    [switch]$AllText,
    [string[]]$ExcludeDir = @('.git', '.obsidian', 'node_modules', 'worktrees')
)

$ErrorActionPreference = 'Stop'
$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
$patterns = if ($AllText) { @('*') } else { @('*.md', '*.markdown', '*.txt', '*.ps1') }

$root = $Path.TrimEnd('\', '/')

$files = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $rel = $_.FullName.Substring($root.Length).TrimStart('\', '/')
        foreach ($ex in $ExcludeDir) {
            if ($rel -eq $ex -or $rel.StartsWith($ex + '\') -or $rel.StartsWith($ex + '/')) { return $false }
        }
        foreach ($p in $patterns) { if ($_.Name -like $p) { return $true } }
        return $false
    }

$violations = [System.Collections.Generic.List[object]]::new()
$scanned = 0

foreach ($f in $files) {
    $scanned++
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    if ($bytes.Length -eq 0) { continue }
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $validUtf8 = $true
    try { $null = $utf8Strict.GetString($bytes) } catch { $validUtf8 = $false }
    $latin = [System.Text.Encoding]::Latin1.GetString($bytes)
    $crlf = ([regex]::Matches($latin, "`r`n")).Count
    $isPs1 = $f.Extension -eq '.ps1'
    # .ps1: BOM allowed (PS5.1 compatibility); no-BOM .ps1 must be pure ASCII.
    # md/txt: BOM forbidden.
    $bomViolation = if ($isPs1) {
        $hasBom -eq $false -and ($bytes | Where-Object { $_ -gt 127 }).Count -gt 0
    } else {
        $hasBom
    }
    if ($bomViolation -or -not $validUtf8 -or $crlf -gt 0) {
        $violations.Add([pscustomobject]@{
            File      = $f.FullName
            BOM       = $hasBom
            ValidUTF8 = $validUtf8
            CRLF      = $crlf
        })
    }
}

if ($violations.Count -eq 0) {
    "ENCODING_CHECK_OK | files scanned: $scanned | no violations (md/txt: no BOM; ps1: BOM or pure-ASCII; all: UTF-8 valid, no CRLF)"
    exit 0
}

"ENCODING_CHECK_VIOLATIONS | files scanned: $scanned | violations: $($violations.Count)"
$violations | Format-Table File, BOM, ValidUTF8, CRLF -AutoSize | Out-String -Width 200
exit 1
