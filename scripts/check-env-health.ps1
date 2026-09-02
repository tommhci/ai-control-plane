# check-env-health.ps1 — session-open environment gate (L3: environment layer)
# Born from the 2026-09-02 incident: a live process reverted .git/refs and loose
# objects in a dev directory sitting under the user profile. Git-layer governance
# cannot defend against OS/process-level interference — so verify the environment
# BEFORE working, not after losing refs.
#
# Usage:  .\check-env-health.ps1 -RepoRoot C:\dev\decision-os
# Exit:   0 = healthy · 1 = FATAL (do not work in this directory)
param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [string]$CanonicalAnchor = "C:\dev"
)
$ErrorActionPreference = "Continue"
$fail = 0

if (-not (Test-Path $RepoRoot)) {
    Write-Host "FATAL: '$RepoRoot' does not exist." -ForegroundColor Red
    exit 1
}

# Rule 1 — physical isolation: the repo must live under the canonical anchor
# and must NOT sit under the user profile or any cloud-sync root.
$repo = (Resolve-Path $RepoRoot -ErrorAction Stop).Path
$anchor = (Resolve-Path $CanonicalAnchor -ErrorAction SilentlyContinue).Path
if ($anchor -and -not $repo.StartsWith($anchor, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "FATAL: '$repo' is outside the canonical dev anchor '$anchor'. Cloud-sync and profile-resident directories are known .git killers (incident 2026-09-02)." -ForegroundColor Red
    $fail++
}
$oneDriveRoots = @()
try {
    $accounts = "HKCU:\Software\Microsoft\OneDrive\Accounts"
    Get-ChildItem $accounts -ErrorAction SilentlyContinue | ForEach-Object {
        $uf = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).UserFolder
        if ($uf) { $oneDriveRoots += $uf }
    }
} catch { }
foreach ($root in $oneDriveRoots) {
    if ($repo.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "FATAL: '$repo' is inside OneDrive sync root '$root'. Move the repo out before any git work." -ForegroundColor Red
        $fail++
    }
}

# Rule 2 — git structural integrity: refs/heads must exist and HEAD must resolve.
$gitDir = Join-Path $repo ".git"
if (-not (Test-Path $gitDir)) {
    Write-Host "FATAL: no .git at '$repo'." -ForegroundColor Red; exit 1
}
if (-not (Test-Path (Join-Path $gitDir "refs\heads"))) {
    Write-Host "FATAL: .git\refs\heads missing — the refs purge signature from incident 2026-09-02. Do NOT attempt repairs in place; re-clone from the remote and rescue untracked assets first." -ForegroundColor Red
    $fail++
} else {
    $head = git -C $repo rev-parse --verify HEAD 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FATAL: HEAD does not resolve (unborn or corrupt). Re-clone from remote." -ForegroundColor Red
        $fail++
    }
}

# Rule 3 — divergence check vs the remote-tracking ref (offline; informational).
$tracking = git -C $repo "rev-parse" "@{upstream}" 2>$null
if ($LASTEXITCODE -eq 0) {
    $headSha = git -C $repo rev-parse HEAD
    if ($headSha -ne $tracking) {
        Write-Host "WARN: HEAD ($($headSha.Substring(0,8))) differs from upstream ($($tracking.Substring(0,8))). Fetch and compare before pushing."
    }
}

if ($fail -gt 0) { Write-Host "`nRESULT: FAIL ($fail fatal)." -ForegroundColor Red; exit 1 }
Write-Host "RESULT: PASS — environment healthy for git work in '$repo'."
exit 0
