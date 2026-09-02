---
name: multi-agent-workflow
description: "How to run multiple AI agents in parallel on this project safely. Load this when dispatching work to >1 agent, or when designing cross-tool / cross-session division of labor. Do NOT load for single-agent node execution."
status: v2 — 2026-06-25. Validated by two real runs (Auditor/Scout/Strategist parallel). Net-benefit claim downgraded to task-dependent after external verification of the compute confound (arXiv:2604.02460).
---

# Multi-Agent Workflow

## Core principle (read this before anything else)

**Structure matters more than autonomy.** The value of multiple agents is not parallelism
or agent count — it is *structured adversarial filtering with context/model separation*.
Adding agents without output contracts, a synthesis step, and producer≠reviewer separation
makes things worse, not better.

> Source: Refute-or-Promote (arXiv:2604.19049, 2026-04) — "Structure matters more than
> autonomy." Anthropic, *How we built our multi-agent research system* (engineering blog,
> 2025-06) — orchestrator-worker beats single agent by 90.2% on breadth-first tasks, at 15x
> token cost; only worth it when the task is breadth-first and exceeds one context window.

## When multi-agent is justified (and when it is NOT)

| Use multi-agent when | Stay single-agent when |
|----------------------|------------------------|
| Task is breadth-first (many independent sub-questions) | Task is narrow and deep (one file, one node) |
| Total information exceeds one context window | Everything fits in one session |
| You need independent verification of a high-stakes claim | The change is mechanical / low-risk |
| Producer and reviewer must not share context | A single pass is enough |

**[Decision gate]** Before dispatching: if the human integration cost of merging N parallel
outputs exceeds the marginal value of those outputs, do NOT go multi-agent. (Anthropic 15x
token cost; this is a real budget, not free parallelism.)

**[Hard counter-evidence — do not skip]** Under EQUAL thinking-token budgets, single-agent
*matches or outperforms* multi-agent on multi-hop / sequential-reasoning tasks; many reported
multi-agent advantages are "better explained by unaccounted computation and context effects
rather than inherent architectural benefits." Source: arXiv:2604.02460 (2026-04-11). Net
benefit is strongly task-dependent, not universal — MAST (arXiv:2503.13657, NeurIPS 2025,
κ=0.88) catalogs 14 failure modes and finds benchmark gains "often minimal." **Implication:**
multi-agent is justified for *parallel-decomposable + independent-adversarial-view* tasks
(risk audit, breadth-first research), NOT for sequential reasoning or simple/mechanical tasks
where a strong single agent is cheaper and faster.

## The four evidence-backed rules

1. **Producer ≠ Reviewer.** The agent that produced an artifact must not be the agent that
   reviews it. An LLM has a 64.5% blind spot on its *own* output but catches *external*
   errors well. Source: Self-Correction Bench (arXiv:2507.02778, 2025-07).

2. **Reviewer gets fresh context, NOT a repeat pass.** Cross-context review F1=28.6% beats
   same-session 24.6%. Repeating review in the same session (SR2) drops to 21.7% — *worse
   than a single pass*. Never re-review in the same session; open a new one.
   Source: CCR (arXiv:2603.12123, 2026-03).

3. **Cross-model critic, not just cross-context.** A same-model reviewer shares correlated
   blind spots even with fresh context. Use a different model family for the critic when the
   stakes justify it. Source: Refute-or-Promote (arXiv:2604.19049).

4. **Reviewer has a kill mandate.** The reviewer's job is to *refute* the claim, not confirm
   it. Default the verdict to "false / not-real" and require the artifact to survive refutation.
   Confirmatory review lets plausible-but-wrong findings through. Source: Refute-or-Promote.

   - Corollary: **empirical validation overrides review consensus.** In the source campaign,
     one test caught a false positive that ten reviewers unanimously endorsed. For code, run
     the test — do not trust agreement among reviewers.

## Agent roles and naming

**Name agents by function and output contract, not by tool or model identity.** Never
"Claude-1 / Codex-2" — those can't be traced in a log and break when tools are swapped.
A role name should tell you what the agent produces and where it writes it.

> Convention follows Anthropic's subagent spec: each agent needs an objective, an output
> format, tool/source guidance, and clear task boundaries.

| Role | Function | Maps to skill | Writes to |
|------|----------|---------------|-----------|
| **Orchestrator** | Classify the task, route it, merge outputs. Does NOT produce final conclusions itself. | — | dispatch + synthesis |
| **Scout** | Gather evidence, separate fact/inference/gap | evidence-check | `## AGENT_OUTPUTS/Scout` |
| **Auditor** | Refute (kill mandate), find failure conditions | challenge-review | `## AGENT_OUTPUTS/Auditor` |
| **Intake** | Select the safest next node, confirm scope | node-intake | proposal only |
| **Executor** | Make the code change for one node | verify-task | code + diff |
| **Strategist** | Direction / drift diagnosis | strategic-alignment | recommendation only |
| **Publisher** | Commit / push / PR (user-confirmed) | publish-safe | git |
| **Recorder** | Update HANDOVER, run session-close | session-close | HANDOVER |

## The three-phase pipeline

```
Phase 1 — PARALLEL (read-only only)
  Orchestrator spawns N read-only agents, each with: objective + output format + boundaries.
  Read-only agents CANNOT conflict on files → safe to run concurrently.
    Scout, Auditor, Strategist run in parallel, each in its own context window.
  Each writes a self-contained block to HANDOVER ## AGENT_OUTPUTS, tagged [role][date].

Phase 2 — SYNTHESIS (Orchestrator or human)
  Read all Phase-1 blocks. Identify overlap and contradiction.
  Promote durable findings → ## PROTOCOL LEARNINGS. Clear the AGENT_OUTPUTS staging area.
  This is the citation/synthesis pass — a separate step, never folded into Phase 1.

Phase 3 — SERIAL (file-mutating agents)
  Only ONE write-agent active at a time. It must hold an ACTIVE_EDIT_OWNERSHIP entry.
  Executor → (verify) → Publisher → Recorder, each releasing ownership before the next.
```

**Why Phase 1 can be parallel but Phase 3 must be serial:** read-only agents never touch
files, so no edit conflict is possible. Write-agents share files; concurrency would corrupt
state. `ACTIVE_EDIT_OWNERSHIP.md` is the serialization lock for Phase 3.

## Dispatch prompt contract (keep it short — AgentIF)

Each agent's instruction must be SHORT with BINARY boundaries. Long or conditional
instructions have lower instruction-following reliability, and N agents each roll that die
independently. Source: AgentIF (arXiv:2505.16944) — instruction-following drops as constraint
count rises; conditional constraints score well below vanilla (CSR ~55–66% vs ~80–87%), and
tool/formatting are the absolute worst at 10–45% (web-verified 2026-06-26).

Template (≤5 constraints, no nested conditions):
```
角色：[role name]
任务：[one sentence, one deliverable]
约束：
- 只读 / 可写（明确二选一）
- 每条发现标 [Fact] / [Inference] / [Insufficient evidence]
- [kill mandate if Auditor: 默认结论为假，你的任务是反驳它]
输出：写入 HANDOVER ## AGENT_OUTPUTS/[role] 区块
      标题行格式：[role=Scout | run=YYYY-MM-DD-NN | task=<task_id> | model=<model>]
      例：[role=Auditor | run=2026-06-25-02 | task=binary-fix-decision | model=Sonnet 4.6]
```

**Why run_id matters:** role + date alone is ambiguous when the same role runs multiple times
on the same day. `run=YYYY-MM-DD-NN` (NN = sequential run number that day, starting from 01)
makes every output block independently citable and auditable without relying on context position.

## Autonomy risk (AURA lens)

Score autonomy risk per dispatch; do not treat it as binary. Watch three things only:
1. Can the agent misread a *recommendation* as an *execution order*?
2. Is there an *auto-write chain* into governance/ or publish without a human gate?
3. Is there *cross-environment escalation* without confirmation (e.g. an agent in one tool
   committing on behalf of another)?

Source: AURA (arXiv:2510.15739, 2025-10) — agent autonomy should be scored with HITL
oversight and explicit agent-to-human communication, not assumed safe.

## Known failure modes of THIS workflow

- **Over-engineering a narrow task.** Multi-agent on a deep/narrow task is negative ROI.
  Re-check the decision gate above. (D7 risk: building the workflow instead of using it.)
- **All-same-model review** = correlated blind spots survive (rule 3 violated).
- **Synthesis skipped** → N disconnected conclusions, nobody owns the merge.
- **AGENT_OUTPUTS not cleared** → stale findings re-enter the next round and never converge.
- **Phase 3 run in parallel** → file corruption; ownership lock bypassed.

## Comparison rubric (use this for every single-vs-multi experiment)

A comparison without these four controls produces a confounded result. Record all four in the
EFFECTIVENESS_LOG entry; if any is missing, tag the conclusion `confounded`.

1. **Task input** — one sentence + task type (parallel-decomposable / sequential / mechanical).
2. **Single-agent output** — produced under a *stated token budget*.
3. **Multi-agent output** — produced under the *same* token budget (e.g. let the single agent
   serially play all N roles, so total compute matches). This is the control the first two runs
   LACKED — without it you are measuring compute, not architecture (arXiv:2604.02460).
4. **Decision rubric** — declared BEFORE seeing outputs: what counts as "found earlier",
   "more correct", "fewer omissions", and what the coordination/token cost was.

Verdict must state: which task type, whether budgets were matched, and net benefit *after*
subtracting coordination cost. "Multi-agent found more" with unequal budgets = `confounded`,
not a win.

## Validation status

[Fact] Two real runs completed (2026-06-25). Both were parallel-decomposable risk-audit tasks
and both surfaced findings a single inline pass missed. [Insufficient evidence] Neither
controlled token budget, so neither isolates architecture from compute. The next comparison
must (a) be on a real *product* task, not an infra task, and (b) match token budgets per the
rubric above. Until then, the validated claim is narrow: *on parallel-decomposable adversarial
audits, role-separated multi-agent surfaces more than a single inline pass* — nothing broader.
