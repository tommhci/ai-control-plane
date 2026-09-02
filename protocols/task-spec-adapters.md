# Task Specification Adapters

Status: v1 adapter set for the Task Specification Layer.

Adapters add domain-specific risk and verification requirements after the
generic specification kernel runs. They may increase depth or verification,
but they must not expand user authorization, add scope, remove non-scope, or
weaken an existing gate.

## Adapter: generic-repo-change

Use for bounded code, documentation, configuration, or test changes that do not
match a more specific adapter.

- Domain risks: hidden dependency impact, unclassified dirty files, scope creep,
  and tests that do not exercise the changed behavior.
- Default invariants: preserve unrelated user changes; use the repository's
  source of truth; keep the diff minimal.
- Upgrade triggers: unknown affected files, cross-module impact, dependency
  changes, generated artifacts, or an unexplained dirty worktree.
- Required evidence: current file contents, worktree state, exact changed-file
  list, and relevant test output.
- Verification: diff boundary check plus the smallest behavior-relevant test.
- Common failure: treating a plausible implementation plan as observed repo fact.

## Adapter: ui-system

Use for visual hierarchy, theme, layout, typography, spacing, component grammar,
or design-consistency work.

- Domain risks: local redesign, visual islands, theme divergence, interaction
  regression, and build/test results being mistaken for visual evidence.
- Default invariants: preserve explicit interaction behavior and the established
  design authority unless the user authorizes a redesign.
- Upgrade triggers: cross-theme, cross-route, shared token, layout-system, or
  design-language changes. These are forced escalation conditions.
- Required evidence: affected surfaces and components, current visual authority,
  and actual browser-visible behavior when a runtime is available.
- Verification levels:
  - mini UI check for one bounded component with no theme-system impact;
  - page-by-theme check for one route with light/dark implications;
  - full UI gate for shared tokens, multiple routes, or design-language changes.
- Common failure: converting a subjective symptom into unsupported technical
  requirements and then treating those hypotheses as user-approved invariants.

## Adapter: git-governance

Use for ownership, protected paths, staging, commits, pushes, releases,
multi-writer coordination, or governance-file changes.

- Domain risks: authority escalation, stale ownership, staged-scope mismatch,
  uncommitted work loss, and external publication.
- Default invariants: preserve user work; derive approval from current staged
  state; never infer push, release, or destructive authority.
- Upgrade triggers: protected paths, governance mutation, multiple writers,
  destructive Git operations, push, publish, deploy, or release.
- Required evidence: current branch, worktree, staged-file list, ownership state,
  and the exact approval boundary.
- Verification: re-read current Git state immediately before the irreversible or
  externally visible action.
- Common failure: allowing a prior chat statement or stale handoff to substitute
  for current staged-state evidence.

## Explicit V1 Boundary

The v1 adapter set contains exactly the three adapters above. Travel, account
support, life planning, finance, legal advice, and general research are outside
this software execution control plane. Missing domains fall back to
`generic-repo-change` only when that adapter is semantically valid; otherwise the
task remains an explicit unknown and does not gain execution authority.
