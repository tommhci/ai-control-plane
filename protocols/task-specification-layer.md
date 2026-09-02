# Task Specification Layer

Status: reusable control-plane policy.

This protocol converts a user's natural-language request into the minimum task
specification needed for safe execution. It is a specification kernel, not a
prompt generator. The user supplies the pain point, desired outcome, and
authorization; the control plane supplies explicit boundaries, risk routing,
and verification requirements.

## Goals

- Preserve the user's original intent before adding professional terminology.
- Separate observed facts, unknowns, hypotheses, and invariants.
- Select the lightest contract depth that is safe for the task.
- Reuse one versioned contract across skills and agents.
- Make scope, permission, and verification drift visible.

## Non-Goals

- Do not require a visible contract for every question.
- Do not let an adapter expand user authorization or task scope.
- Do not treat replay fixtures as evidence of behavioral effectiveness.
- Do not replace ownership, protected-path, publish, or human-judgment gates.

## Fast Specification Check

Run this check after authorization validity and before task-type routing.

1. If a current `contract_id` and `contract_version` already cover the request,
   reuse them. Do not compile a second contract for the same task.
2. Check forced-escalation conditions before calculating a score.
3. Score the five risk dimensions from 0 to 2.
4. Apply the selected adapter's upgrade rules.
5. Select `pass-through`, `compact`, or `gated` depth.

### Contract Depth

| Depth | Typical task | Behavior |
|---|---|---|
| `pass-through` | Pure Q&A or read-only analysis with no side effect | No explicit contract is required. Existing read and evidence rules still apply. |
| `compact` | Clear, low-risk, bounded file or code change | Keep a concise internal contract and continue under existing authorization. |
| `gated` | Forced escalation, score 6-10, unknown impact, or adapter upgrade | Output the contract, run plan-freeze, and wait for the required approval. |

Scores 0-2 may pass through only when the task has no write or external side
effect. Scores 3-5 use a compact contract. Scores 6-10 use a gated contract.
A write task never becomes pass-through solely because its numeric score is low.

## Forced Escalation

Any applicable reason must be recorded in
`risk.forced_escalation_reasons`. A non-empty list sets `risk.depth` to
`gated`; the numeric score cannot reduce it.

- destructive operation
- push, deploy, publish, or release
- protected path or governance mutation
- external API or other external side effect
- privacy, security, account, financial, or data-integrity risk
- cross-route, cross-theme, cross-module, or system-consistency change
- conflicting user goals
- unknown impact scope
- multiple AI writers
- contract drift during execution

## Risk Dimensions

Each dimension is an integer from 0 to 2:

- `ambiguity`: 0 explicit, 1 interpretive room, 2 subjective or multi-solution.
- `blast_radius`: 0 one point, 1 one module, 2 cross-system.
- `irreversibility`: 0 easy recovery, 1 moderate, 2 difficult or external.
- `domain_uncertainty`: 0 reliable boundaries, 1 partial uncertainty, 2 the AI
  lacks reliable evidence. User unfamiliarity alone does not increase this score.
- `verification_complexity`: 0 direct check, 1 browser or human observation,
  2 multi-dimensional verification.

## Epistemic Boundaries

- `raw_user_intent` preserves the user's wording.
- `observed_facts` may only cite the user, a file, a tool observation, or a
  project protocol.
- `unknowns` remain explicit. Do not fill them with plausible language.
- `hypotheses` are professional interpretations, not user requirements.
- `invariants` require a source. High-confidence inference is allowed only when
  labeled as such and cannot override an explicit user or project constraint.

## Adapter Authority Boundary

An adapter may increase contract depth or verification requirements. It must not:

- expand user authorization;
- add files or outcomes to `scope`;
- remove an item from `non_scope`;
- weaken an existing permission or human-approval gate;
- turn a hypothesis into an invariant.

When an adapter needs broader scope, add an `unknowns` entry and stop for a
contract revision.

## Contract Lifecycle

- `contract_id` identifies one task across skills, agents, and handoffs.
- Increment `contract_version` whenever goal, scope, non-scope, permissions,
  invariants, or acceptance evidence changes.
- Set `supersedes_contract` when a new contract replaces another contract ID.
- Downstream consumers read the current contract; they do not independently
  reinterpret the raw request.
- Scope or permission drift during execution is a forced escalation. Stop,
  issue a new version, and obtain any newly required approval.

The machine-readable structure is defined in `task-contract.schema.json`.

## Consumer Contract

- `pre-task-decision-flow.md` owns the Fast Specification Check and depth decision.
- `node-intake` checks contract scope and permissions against repo/worktree state.
- `plan-freeze` binds scope, non-scope, invariants, permissions, and stop conditions.
- `verify-task` checks acceptance evidence and verification methods.
- `session-close` records contract drift, false escalation, missed escalation,
  wrong adapter, and fact/hypothesis contamination when observed.

## Failure And Fallback

- Missing adapter: use `generic-repo-change`; do not guess a neighboring domain.
- Invalid contract: stop gated work and report the schema error.
- Classifier uncertainty: keep unknowns explicit and choose the safer depth.
- TaskSpec unavailable: fall back to the existing pre-task flow. Never bypass an
  existing permission, ownership, protected-path, or publish gate.

## Evidence Status

The replay fixtures are structural smoke tests only. They can show that routing
examples, schema fields, and consumer references exist. They cannot prove fewer
missed escalations, fewer wrong professional completions, acceptable approval
burden, or consistent behavior across Codex, Claude, and Kiro. Those claims
require real-task telemetry and tool-by-tool validation.
