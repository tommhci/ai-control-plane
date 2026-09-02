param(
  [string]$ClientRoot = ".",
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Continue"
$pass = $true
$root = Resolve-Path $ClientRoot

function Check {
  param([string]$Name, [bool]$Result, [string]$Reason = "")
  if ($Result) { Write-Output "PASS: $Name" }
  else { Write-Output "FAIL: $Name$(if ($Reason) { " -- $Reason" })"; $script:pass = $false }
}

# Check 1
$adapterPath = Join-Path $root ".control-plane/adapter.json"
Check "adapter.json exists" (Test-Path $adapterPath)

# Check 2
$adapter = $null
try { $adapter = Get-Content $adapterPath -Raw | ConvertFrom-Json; Check "adapter.json parses" $true }
catch { Check "adapter.json parses" $false $_.Exception.Message }

# Check 3
if ($adapter) {
  foreach ($f in @("adapterId","project","controlPlaneRepo","ownershipFile","sessionLog")) {
    Check "field '$f' present" ($adapter.$f -ne $null -and $adapter.$f -ne "")
  }
}

# Check 4
if ($adapter -and $adapter.controlPlaneRepo) {
  Check "controlPlaneRepo resolves" (Test-Path $adapter.controlPlaneRepo)
}

# Check 5
$ppPath = Join-Path $root ".control-plane/protected-paths.json"
Check "protected-paths.json exists" (Test-Path $ppPath)
if (Test-Path $ppPath) {
  try { Get-Content $ppPath -Raw | ConvertFrom-Json | Out-Null; Check "protected-paths.json parses" $true }
  catch { Check "protected-paths.json parses" $false $_.Exception.Message }
}

# Check 6
if ($adapter -and $adapter.ownershipFile) {
  $ownerPath = Join-Path $root $adapter.ownershipFile
  Check "ownershipFile exists" (Test-Path $ownerPath)
}

# Check 7 — flag deprecated/legacy repo-name leakage in a client's own adapter.json.
# Generic by design: any client's adapterId may legitimately reference itself;
# what's checked is deprecated names that do NOT match this client's own id
# (mirrors the equivalent check in security/scan_client_security.ps1).
if ($adapter -and (Test-Path $adapterPath)) {
  $deprecatedNames = @("legacy-client-backup") # boundary-lint:allow detector signature (deprecated-name check)
  $clientId = [string]$adapter.adapterId
  $leaked = $deprecatedNames | Where-Object {
    $_ -ne $clientId -and (Select-String -Path $adapterPath -Pattern ([regex]::Escape($_)) -Quiet)
  }
  Check "no deprecated repo names in adapter.json" ($leaked.Count -eq 0) $(if ($leaked.Count -gt 0) { "found: $($leaked -join ', ')" } else { "" })
}

if ($pass) { Write-Output ""; Write-Output "All checks PASS."; exit 0 }
else { Write-Output ""; Write-Output "Some checks FAILED."; exit 1 }
