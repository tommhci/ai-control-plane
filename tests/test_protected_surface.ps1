param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# P2 (2026-08-28): protected-surface completeness gate.
# Any installer-generated/merged protected-paths.json for a claude-code client
# MUST contain the enforcement surface entry set. Drift shows up red here (and
# in CI) instead of waiting for the next audit.

$repoRoot = Split-Path $PSScriptRoot -Parent
$attachScript = Join-Path $repoRoot "installers\attach-project.ps1"
$harnessScript = Join-Path $repoRoot "installers\install-claude-client.ps1"
$tmpBase = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "aicp-protected-surface-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))")
New-Item -ItemType Directory -Path $tmpBase -Force | Out-Null

$pass = 0
$fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) {
        Write-Output "  PASS: $Label"
        $script:pass++
    } else {
        Write-Output "  FAIL: $Label"
        $script:fail++
    }
}

# Required enforcement-surface entries (P3, findings register 2026-08-17 item 2).
$required = @(
    ".control-plane/",
    ".claude/settings.local.json",
    ".git/hooks/",
    ".control-plane/adapter.json",
    ".control-plane/resolve-control-plane.ps1"
)

try {
    Write-Output ""
    Write-Output "=== test_attach_claude_code_generates_full_surface ==="
    $client = Join-Path $tmpBase "surface-client"
    New-Item -ItemType Directory -Path $client -Force | Out-Null
    "# Surface Client" | Set-Content -LiteralPath (Join-Path $client "README.md") -Encoding utf8

    & powershell -NoProfile -ExecutionPolicy Bypass -File $attachScript `
        -ClientRoot $client `
        -Profile claude-code `
        -Tier minimal `
        -ControlPlaneRepo $repoRoot 2>&1 | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "claude-code attach exits 0"

    $pp = Get-Content -LiteralPath (Join-Path $client ".control-plane\protected-paths.json") -Raw | ConvertFrom-Json
    foreach ($entry in $required) {
        Assert-True (@($pp.protectedPaths) -contains $entry) "attach output contains '$entry'"
    }

    Write-Output ""
    Write-Output "=== test_installer_self_heals_missing_entries ==="
    # Simulate drift: drop every required entry, keep one client-specific
    # sentinel, then re-run the harness installer and require it to merge the
    # surface back (never removes client-specific entries).
    $sentinel = "src/core/sentinel-only-client.js"
    $drained = @(@($pp.protectedPaths | Where-Object { $required -notcontains $_ }) + $sentinel)
    [ordered]@{
        protectedPaths = $drained
        notes = @("drained on purpose - installer must merge the surface back")
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $client ".control-plane\protected-paths.json") -Encoding utf8

    & powershell -NoProfile -ExecutionPolicy Bypass -File $harnessScript `
        -RepoRoot $client `
        -AdapterDir ".control-plane" 2>&1 | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "install-claude-client exits 0"

    $healed = Get-Content -LiteralPath (Join-Path $client ".control-plane\protected-paths.json") -Raw | ConvertFrom-Json
    foreach ($entry in $required) {
        Assert-True (@($healed.protectedPaths) -contains $entry) "self-healed surface contains '$entry'"
    }
    Assert-True (@($healed.protectedPaths) -contains $sentinel) "client-specific sentinel preserved by merge"

} finally {
    if (Test-Path -LiteralPath $tmpBase) {
        Remove-Item -LiteralPath $tmpBase -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ""
Write-Output "protected_surface: $pass/$($pass + $fail) PASS, $fail FAIL"
if ($fail -gt 0) { exit 1 }
if ($pass -eq 0) { exit 1 }
exit 0
