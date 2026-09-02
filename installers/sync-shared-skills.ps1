param(
  [string]$RepoRoot = ".",
  [string]$AdapterDir = ".control-plane",
  [string]$SkillsDir = ".agents/skills"
)

$ErrorActionPreference = "Stop"

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
$resolvedAdapterDir = Join-Path $resolvedRepoRoot $AdapterDir
$adapterPath = Join-Path $resolvedAdapterDir "adapter.json"

$adapter = Get-Content $adapterPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($adapter.controlPlaneRepo)) {
  throw "adapter.json is missing controlPlaneRepo"
}

if ([string]::IsNullOrWhiteSpace($adapter.sharedAdapterPath)) {
  throw "adapter.json is missing sharedAdapterPath"
}

$sharedAdapterPath = Join-Path $adapter.controlPlaneRepo $adapter.sharedAdapterPath
if (-not (Test-Path $sharedAdapterPath)) {
  throw "Missing shared adapter definition: $sharedAdapterPath"
}

$sharedAdapter = Get-Content $sharedAdapterPath -Raw | ConvertFrom-Json
$sharedSkills = @($sharedAdapter.sharedSkills)
if ($sharedSkills.Count -lt 1) {
  throw "Shared adapter definition has no sharedSkills entries"
}

$resolvedSkillsDir = Join-Path $resolvedRepoRoot $SkillsDir
New-Item -ItemType Directory -Force -Path $resolvedSkillsDir | Out-Null

$synced = @()

foreach ($skillName in $sharedSkills) {
  $sourceDir = Join-Path $adapter.controlPlaneRepo "skills/$skillName"
  $targetDir = Join-Path $resolvedSkillsDir $skillName

  if (-not (Test-Path $sourceDir)) {
    throw "Missing shared skill source: $sourceDir"
  }

  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

  Get-ChildItem $sourceDir -Force | ForEach-Object {
    $destination = Join-Path $targetDir $_.Name
    Copy-Item $_.FullName -Destination $destination -Recurse -Force
  }

  $synced += $skillName
}

Write-Output "sync-shared-skills: PASS"
Write-Output "repoRoot=$resolvedRepoRoot"
Write-Output "skillsDir=$resolvedSkillsDir"
Write-Output "sharedSkills=$($synced -join ',')"
