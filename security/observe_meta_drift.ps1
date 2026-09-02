param(
  [string]$SessionLog    = "",
  [int]$Threshold        = 3,
  [int]$LookbackSessions = 10,
  [switch]$Record                   # write a machine-authored note event if warning fires
)

# D7 Meta-Session Drift Observer.
# Reads session_log.jsonl and reports consecutive meta/infra/governance sessions.
# OBSERVATION-ONLY. Does not block. Does not enforce.
# Run manually or from Darwin checks / session-close reviews.
#
# Failure modes: sparse or unlabeled sessions produce INSUFFICIENT_DATA, not invented conclusions.
# A warning means "consider whether recent work is product or meta", not "you must stop".

$ErrorActionPreference = "Stop"

# ── locate log ──────────────────────────────────────────────────────────────

if ([string]::IsNullOrWhiteSpace($SessionLog)) {
    # Only the CWD-relative location is probed. Platform tooling must not
    # hardcode any client repo's path; pass -SessionLog <path> to audit a
    # specific client (2026-08-29: removed a hardcoded client-relative
    # candidate originally flagged by the 2026-07-14 audit).
    $candidates = @(
        ".agents/session_log.jsonl"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $SessionLog = $c; break }
    }
}

if ([string]::IsNullOrWhiteSpace($SessionLog) -or -not (Test-Path $SessionLog)) {
    @{
        status          = "INSUFFICIENT_DATA"
        reason          = "session_log.jsonl not found; pass -SessionLog <path>"
        meta_streak     = 0
        product_streak  = 0
        warning         = $false
    } | ConvertTo-Json
    exit 0
}

# ── load + filter ────────────────────────────────────────────────────────────

$rawLines = Get-Content $SessionLog -ErrorAction SilentlyContinue
if ($null -eq $rawLines -or $rawLines.Count -eq 0) {
    @{ status = "INSUFFICIENT_DATA"; reason = "log is empty"; warning = $false } | ConvertTo-Json
    exit 0
}

$entries = $rawLines |
    Where-Object { $_ -match '^\{' } |
    ForEach-Object { try { $_ | ConvertFrom-Json } catch { $null } } |
    Where-Object { $_ -ne $null } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.session_id) -and $_.session_id -ne "post-commit-auto" }

if ($entries.Count -eq 0) {
    @{
        status       = "INSUFFICIENT_DATA"
        reason       = "no human-authored session entries found (only auto-capture entries)"
        total_raw    = $rawLines.Count
        warning      = $false
    } | ConvertTo-Json
    exit 0
}

# ── classify each session ────────────────────────────────────────────────────

# META signals: domain=governance, node starts with Infra, summary has infra/meta keywords
# PRODUCT signals: active_node matches Node-\d+, domain not governance, tests passed
# UNKNOWN: insufficient data to classify

$metaKeywords  = @('infra', 'governance', 'protocol', 'meta', 'extract', 'control.?plane', 'audit', 'boundary', 'sanitiz', 'release.?ready', 'license', 'public.?ready')
$productKeywords = @('feat', 'fix', 'node-\d', 'test.*pass', 'build.*pass', 'vitest')

function Get-SessionClass {
    param($e)
    $score = 0
    # Positive meta signals
    if ($e.domain -eq "governance") { $score -= 2 }
    if ($e.active_node -and $e.active_node.value -match '^Infra') { $score -= 2 }
    foreach ($kw in $metaKeywords) {
        if ($e.summary -imatch $kw -or ($e.session_id -imatch $kw)) { $score -= 1 }
    }
    # Positive product signals
    if ($e.active_node -and $e.active_node.value -match '^Node-\d') { $score += 3 }
    if ($e.tests -and $e.tests.status -eq "pass") { $score += 2 }
    foreach ($kw in $productKeywords) {
        if ($e.summary -imatch $kw -or $e.session_id -imatch $kw) { $score += 1 }
    }
    if ($score -ge 1)  { return "product" }
    if ($score -le -1) { return "meta" }
    return "unknown"
}

$classified = $entries | ForEach-Object {
    [PSCustomObject]@{
        session_id = $_.session_id
        class      = Get-SessionClass $_
        domain     = $_.domain
        node       = if ($_.active_node) { $_.active_node.value } else { "" }
        summary    = if ($_.summary.Length -gt 80) { $_.summary.Substring(0,80) + "..." } else { $_.summary }
    }
}

# ── compute streaks (most-recent window) ─────────────────────────────────────

$recent = @($classified | Select-Object -Last $LookbackSessions)

$metaStreak    = 0
$productStreak = 0
$unknownCount  = 0
$productCount  = 0
$metaCount     = 0

foreach ($s in $recent) {
    switch ($s.class) {
        "meta"    { $metaCount++ }
        "product" { $productCount++ }
        "unknown" { $unknownCount++ }
    }
}

# Consecutive streak from most recent
for ($i = $recent.Count - 1; $i -ge 0; $i--) {
    if ($recent[$i].class -eq "meta") { $metaStreak++ } else { break }
}
for ($i = $recent.Count - 1; $i -ge 0; $i--) {
    if ($recent[$i].class -eq "product") { $productStreak++ } else { break }
}

# ── data quality check ───────────────────────────────────────────────────────

$classifiableRatio = ($metaCount + $productCount) / [Math]::Max($recent.Count, 1)
$dataQuality = if ($classifiableRatio -ge 0.5) { "sufficient" } elseif ($classifiableRatio -ge 0.2) { "sparse" } else { "insufficient" }

$warning = ($metaStreak -ge $Threshold) -and ($dataQuality -ne "insufficient")
$warnText = if ($warning) {
    "D7 SIGNAL: $metaStreak consecutive meta/infra sessions in last $LookbackSessions. Consider returning to product work."
} else { $null }

# ── output ───────────────────────────────────────────────────────────────────

$result = [ordered]@{
    status            = if ($dataQuality -eq "insufficient") { "INSUFFICIENT_DATA" } else { "OK" }
    warning           = $warning
    warning_text      = $warnText
    data_quality      = $dataQuality
    sessions_inspected = $recent.Count
    total_sessions    = $entries.Count
    meta_streak       = $metaStreak
    product_streak    = $productStreak
    meta_count        = $metaCount
    product_count     = $productCount
    unknown_count     = $unknownCount
    threshold         = $Threshold
    recent_sessions   = $recent | Select-Object session_id, class, node, domain
}

$result | ConvertTo-Json -Depth 4

# ── optional machine-authored record ─────────────────────────────────────────

if ($Record -and $warning -and (Test-Path $SessionLog)) {
    $writerCandidates = @(
        (Join-Path $PSScriptRoot "..\state\write_session_event.ps1"),
        "<ai-control-plane-repo>\state\write_session_event.ps1"
    )
    $writer = $writerCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($writer) {
        & powershell -NonInteractive -File $writer `
          -EventType note `
          -SessionId "d7-observer-auto" `
          -Domain "governance" `
          -Summary $warnText `
          -OutputPath $SessionLog `
          2>$null | Out-Null
        Write-Output "D7 warning recorded to session_log."
    }
}
