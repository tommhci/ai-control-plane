<#
.SYNOPSIS
    Tests for profiles/ and installers/list-profiles.ps1 + install-profile.ps1
#>
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$listScript   = Join-Path $repoRoot "installers\list-profiles.ps1"
$installScript = Join-Path $repoRoot "installers\install-profile.ps1"
$profilesDir  = Join-Path $repoRoot "profiles"
$tmpBase = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "acp-p9-test-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))")
New-Item -ItemType Directory -Path $tmpBase -Force | Out-Null

$pass = 0; $fail = 0

function Assert-True  { param([bool]$c,[string]$l); if ($c){Write-Output "  PASS: $l";$script:pass++}else{Write-Output "  FAIL: $l";$script:fail++} }
function Assert-False { param([bool]$c,[string]$l); Assert-True (-not $c) $l }

# ─── test_list_profiles_works ────────────────────────────────────────────────
Write-Output ""
Write-Output "=== test_list_profiles_works ==="
$out = & $listScript 2>$null
Assert-True ([bool]($out | Select-String "claude-code"))    "list shows claude-code"
Assert-True ([bool]($out | Select-String "codex"))          "list shows codex"
Assert-True ([bool]($out | Select-String "cursor"))         "list shows cursor"
Assert-True ([bool]($out | Select-String "generic"))        "list shows generic"
Assert-True ([bool]($out | Select-String "opencode"))       "list shows opencode"
Assert-True ([bool]($out | Select-String "VERIFIED"))       "list shows VERIFIED status"
Assert-True ([bool]($out | Select-String "EXPERIMENTAL"))   "list shows EXPERIMENTAL status"

# ─── test_list_profiles_json ─────────────────────────────────────────────────
Write-Output ""
Write-Output "=== test_list_profiles_json ==="
$jsonOut = & $listScript -Json 2>$null
try {
    $parsed = $jsonOut | ConvertFrom-Json
    Assert-True ($parsed.Count -ge 4) "JSON output has >= 4 profiles"
    $ids = @($parsed | ForEach-Object { $_.profile_id })
    Assert-True ($ids -contains "claude-code") "JSON: claude-code present"
    Assert-True ($ids -contains "codex")       "JSON: codex present"
} catch {
    Assert-True $false "JSON output is parseable"
}

# ─── test_unknown_profile_fails ──────────────────────────────────────────────
Write-Output ""
Write-Output "=== test_unknown_profile_fails ==="
$fakeClient = Join-Path $tmpBase "fake_client"
New-Item -ItemType Directory -Path $fakeClient -Force | Out-Null
$errOut = & $installScript -ClientRoot $fakeClient -Profile "nonexistent-harness-xyz" 2>&1
Assert-True ([bool]($errOut | Select-String "Unknown profile|not found")) "unknown profile -> error message"

# ─── test_claude_code_profile_validates ──────────────────────────────────────
Write-Output ""
Write-Output "=== test_claude_code_profile_validates ==="
$profileFile = Join-Path $profilesDir "claude-code.json"
Assert-True (Test-Path $profileFile) "claude-code.json exists"
$p = Get-Content $profileFile | ConvertFrom-Json
Assert-True ($p.profile_id -eq "claude-code")       "profile_id=claude-code"
Assert-True ($p.supported_status -eq "verified")    "supported_status=verified"
Assert-True ($p.hook_support -eq $true)             "hook_support=true"
Assert-True ($p.required_files.Count -ge 3)         "has >= 3 required_files"
Assert-True ($p.install_steps.Count -ge 3)          "has >= 3 install_steps"
Assert-True ($p.health_checks.Count -ge 1)          "has >= 1 health_checks"
Assert-True ($p.known_limitations.Count -ge 1)      "has known_limitations"

# ─── test_experimental_profiles_not_verified ────────────────────────────────
Write-Output ""
Write-Output "=== test_experimental_profiles_not_verified ==="
foreach ($profId in @("codex","cursor","generic","opencode")) {
    $pf = Join-Path $profilesDir "$profId.json"
    Assert-True (Test-Path $pf) "$profId.json exists"
    $pp = Get-Content -Path $pf | ConvertFrom-Json
    Assert-True ($pp.supported_status -ne "verified") "$profId is not verified (status=$($pp.supported_status))"
}

# ─── test_install_profile_runs_on_empty_client ───────────────────────────────
Write-Output ""
Write-Output "=== test_install_profile_runs_on_empty_client ==="
$emptyClient = Join-Path $tmpBase "empty_client"
New-Item -ItemType Directory -Path $emptyClient -Force | Out-Null
$out2 = & $installScript -ClientRoot $emptyClient -Profile "claude-code" 2>&1
Assert-True ([bool]($out2 | Select-String "claude-code"))          "install output mentions profile"
Assert-True ([bool]($out2 | Select-String "verified"))             "install output mentions verified"
Assert-True ([bool]($out2 | Select-String "Install Steps"))        "install output shows install steps"

# ─── test_install_summary_parseable ──────────────────────────────────────────
Write-Output ""
Write-Output "=== test_install_summary_parseable ==="
$out3 = & $installScript -ClientRoot $emptyClient -Profile "cursor" 2>&1
Assert-True ([bool]($out3 | Select-String "WARNING|experimental|stub")) "non-verified profile shows warning"
Assert-True ([bool]($out3 | Select-String "not verified|unverified|not report"))  "install warns about unverified status"

# ─── cleanup ──────────────────────────────────────────────────────────────────
Remove-Item -Recurse -Force $tmpBase -ErrorAction SilentlyContinue

Write-Output ""
Write-Output "-----------------------------------------"
$total = $pass + $fail
Write-Output "install_profiles: $pass/$total PASS, $fail FAIL"
if ($fail -gt 0) { Write-Output "install_profiles: SOME FAILURES"; exit 1 }
else             { Write-Output "install_profiles: ALL PASS"; exit 0 }

