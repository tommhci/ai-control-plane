$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw "FAIL: $Message"
  }

  Write-Output "PASS: $Message"
}

function Read-RepoFile {
  param([string]$RelativePath)

  $path = Join-Path $repoRoot $RelativePath
  $null = Assert-True (Test-Path -LiteralPath $path) "file exists: $RelativePath"
  return Get-Content -LiteralPath $path -Raw
}

$preTask = Read-RepoFile "protocols/pre-task-decision-flow.md"
$kernel = Read-RepoFile "protocols/task-specification-layer.md"
$adapterDoc = Read-RepoFile "protocols/task-spec-adapters.md"
$planFreeze = Read-RepoFile "skills/plan-freeze/SKILL.md"
$nodeIntake = Read-RepoFile "skills/node-intake/SKILL.md"
$verifyTask = Read-RepoFile "skills/verify-task/SKILL.md"
$sessionClose = Read-RepoFile "skills/session-close/SKILL.md"

Assert-True ($preTask -match "Fast Specification Check") "pre-task flow references Fast Specification Check"
Assert-True ($preTask -match "task-specification-layer\.md") "pre-task flow references the specification kernel"

$schemaPath = Join-Path $repoRoot "protocols/task-contract.schema.json"
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
$requiredFields = @(
  "contract_id",
  "contract_version",
  "raw_user_intent",
  "goal",
  "observed_facts",
  "unknowns",
  "hypotheses",
  "invariants",
  "scope",
  "non_scope",
  "risk",
  "adapter",
  "permissions_required",
  "acceptance_evidence",
  "verification_method",
  "stop_conditions"
)

foreach ($field in $requiredFields) {
  Assert-True ($schema.required -contains $field) "schema requires $field"
}
Assert-True ($schema.required -notcontains "supersedes_contract") "supersedes_contract remains optional"

$riskRequired = @($schema.'$defs'.risk.required)
foreach ($field in @("forced_escalation_reasons", "ambiguity", "blast_radius", "irreversibility", "domain_uncertainty", "verification_complexity", "depth")) {
  Assert-True ($riskRequired -contains $field) "risk requires $field"
}

$forcedRule = $schema.'$defs'.risk.allOf | ConvertTo-Json -Depth 20
Assert-True ($forcedRule -match '"const":\s+"gated"') "non-empty forced escalation requires gated depth"

$expectedAdapters = @("generic-repo-change", "ui-system", "git-governance")
$schemaAdapters = @($schema.properties.adapter.enum)
Assert-True ($schemaAdapters.Count -eq 3) "schema exposes exactly three v1 adapters"
foreach ($adapter in $expectedAdapters) {
  Assert-True ($schemaAdapters -contains $adapter) "schema contains adapter $adapter"
}

$adapterHeadings = [regex]::Matches($adapterDoc, '(?m)^## Adapter: ([a-z-]+)$')
Assert-True ($adapterHeadings.Count -eq 3) "adapter document defines exactly three v1 adapters"
Assert-True ($adapterDoc -match "must not expand user authorization") "adapter authority cannot expand user authorization"
Assert-True ($adapterDoc -match "must not expand user authorization, add scope") "adapter authority cannot add scope"

foreach ($field in @("scope", "non_scope", "invariants", "permissions_required", "stop_conditions")) {
  Assert-True ($planFreeze -match [regex]::Escape($field)) "plan-freeze consumes $field"
}
foreach ($field in @("scope", "non_scope", "permissions_required")) {
  Assert-True ($nodeIntake -match [regex]::Escape($field)) "node-intake consumes $field"
}
foreach ($field in @("acceptance_evidence", "verification_method")) {
  Assert-True ($verifyTask -match [regex]::Escape($field)) "verify-task consumes $field"
}
foreach ($signal in @("contract_drift", "false_escalation", "missed_escalation", "wrong_adapter", "fact_hypothesis_contamination")) {
  Assert-True ($sessionClose -match [regex]::Escape($signal)) "session-close records $signal"
}

$fixturePath = Join-Path $repoRoot "tests/fixtures/task-spec-replay.json"
$fixtures = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
Assert-True ($fixtures.metadata.smoke_test_only -eq $true) "replay declares smoke-test-only status"
Assert-True ($fixtures.metadata.behavioral_effectiveness_claimed -eq $false) "replay does not claim behavioral effectiveness"
Assert-True (@($fixtures.cases).Count -ge 8) "replay contains at least eight cases"
Assert-True (@($fixtures.v1_adapters).Count -eq 3) "replay lists exactly three v1 adapters"

foreach ($case in @($fixtures.cases)) {
  Assert-True ($expectedAdapters -contains $case.expected_adapter) "fixture $($case.id) uses a v1 adapter"
  Assert-True (@("pass-through", "compact", "gated") -contains $case.expected_depth) "fixture $($case.id) uses a valid depth"
  if ($null -ne $case.forced_escalation_reason) {
    Assert-True ($case.expected_depth -eq "gated") "fixture $($case.id) forces gated depth"
  }
}

Assert-True ($kernel -match "structural smoke tests only") "kernel limits replay claims to structural smoke tests"
Assert-True ($kernel -match "expand user authorization") "kernel enforces adapter authorization boundary"

Write-Output "task_specification_layer_tests=PASS"
