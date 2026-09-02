# Pre-Task Decision Flow

Status: reusable control-plane policy.

Use this after session start checks and before implementation. Its purpose is
to prevent agents from turning analysis, infrastructure, or skill-generation
work into unbounded execution.

## Step 0 - Node Or Authorization Validity

Is this task attached to an active queue item, an armed gate, or an explicit
human authorization?

If not, stop. Do not treat "seems important" as permission to execute.

## Step 0.5 - Fast Specification Check

Run the Fast Specification Check in `task-specification-layer.md` before task
type routing:

1. Reuse an existing current Task Contract when one already covers the request.
2. Check forced-escalation reasons before calculating the five risk scores.
3. Apply the selected v1 adapter without expanding user authorization or scope.
4. Select `pass-through`, `compact`, or `gated` contract depth.

Pass-through tasks need no visible contract. Compact tasks keep a concise
internal contract. Gated tasks must expose a schema-valid contract, run
`plan-freeze`, and wait for the required approval before execution.

The contract schema is `task-contract.schema.json`; the only v1 adapters are
defined in `task-spec-adapters.md`. If scope, permissions, invariants, or
acceptance evidence change during execution, treat that as contract drift and
return to this step with a new contract version.

## Step 1 - Task Type

Classify the task as one primary type:

- Decision
- Think
- Build
- Infra
- Meta-work
- Skill-generative

Do not mix Build and Think in the same session unless the human explicitly
authorizes the switch.

## Step 2 - Critical Artifact

If Build or Infra adds system complexity, name the critical-path artifact.

If the artifact has not produced real output, validate it before building the
next layer. "Designed", "configured", or "implemented" does not count as real
output.

## Step 3 - External Architecture Scan

If Infra introduces reusable infrastructure, perform a bounded Adopt / Adapt /
Build scan before local implementation.

The scan must cite official docs, a mature reference, or existing local
precedent. If no scan has been done, stop before local build unless explicitly
marked throwaway prototype.

## Step 4 - Human First-Pass

If the task is decision-generative or skill-generative, the human must provide a
first-pass judgment before AI refinement.

AI may challenge, structure, or test the judgment, but must not draft the first
position.

## Step 4.5 - Route Authorization (Continuous Execution)

If the user has provided a route authorization (a single instruction that covers
multiple sequential tasks), declare the route before beginning. A route converts
repeated per-step confirmations into one bounded authorization. See
`route-based-continuous-execution.md` for the full route contract, auto-commit
rules, and hard-stop conditions.

Without a declared route, treat every task as STEP-mode: one task, one
confirmation.

## Step 5 - Runtime Boundary

If the task affects files, tools, network, permissions, protected paths, or
persistent state, identify the required runtime boundary:

- permission
- hook
- writer
- validator
- protected-path rule

Prompt text alone is not sufficient for these rules.

## Blocking Format

```text
STOP [Step N - reason] | Needs your decision: [one question]
```
