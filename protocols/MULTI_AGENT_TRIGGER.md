---
name: multi-agent-trigger
description: "Decision gate for single-agent vs multi-agent. Load when deciding whether to dispatch >1 agent. Companion to multi_agent_workflow.md (WHEN vs HOW)."
status: v1 — 2026-06-26
---

# Single-Agent / Multi-Agent Trigger Table

**Default rule:** start with `single-agent`. Upgrade only when the task clearly benefits from role separation or parallel evidence gathering. This table answers WHEN — for HOW to run once triggered, see `multi_agent_workflow.md`.

---

## 1. Use Single-Agent By Default

Use `single-agent` when any of these are true:

- The task is a single implementation node.
- The task is a narrow bug fix.
- The task is mostly mechanical editing or cleanup.
- The task depends on one evolving shared context.
- The task is sequential reasoning rather than parallel evidence gathering.
- The cost of merging parallel outputs is likely higher than the value of extra views.

**Examples:** one-file fix, one feature node, test repair, refactor inside one bounded module, writing a small adapter file.

---

## 2. Upgrade to Multi-Agent Only When Justified

Use `multi-agent` only when **at least 3 of the following 4 conditions** are true:

1. The task can be decomposed into 2 or more independent sub-questions.
2. The goal is to find risk, contradiction, omission, or competing interpretations — not to directly implement.
3. The total material is large enough that one context window is likely to miss something important.
4. Independent viewpoints are needed to reduce blind spots.

**Typical good fits:** governance audit, evidence review, strategic alignment review, challenge/red-team pass, cross-document conflict check, high-stakes claim verification, repo-wide risk scan with distinct roles.

### 2a. Paired-Audit Gate (governed paths / irreversible operations / "final state" claims)

If ANY of these is true, run the session as a paired audit instead of (or in addition to) fan-out: the session touches governed paths; it performs destructive or irreversible operations; it will declare a "final state", "resolved", or "solved".

Paired audit = exactly one writer (sole write access, including the git index) + one read-only auditor whose claims are verified against disk / CI / API - never against the writer's narrative. This is insurance, not performance: an LLM has a 64.5% blind spot on its own output (arXiv:2507.02778), and concentrated verification compresses independent-agent error amplification from 17.2x to 4.4x (arXiv:2512.08296). Fan-out buys breadth; paired-audit buys error decorrelation at irreversible moments. They do not substitute for each other.

### 2b. Capability Saturation Gate

If a strong single agent already completes this task class reliably, do NOT go multi-agent: past a ~45% single-agent baseline on a task class, coordination gains on that class flip negative (arXiv:2604.02460, arXiv:2512.08296). Fanning out in order to use the pattern is itself the failure mode - the pattern is a cost, paid only when its specific mechanism (breadth / decorrelation / verification) is the binding constraint.

---

## 3. Hard Stop: Do NOT Use Multi-Agent

Do not use `multi-agent` when any of these are true:

- The task is a single code change with clear scope.
- The work requires multiple agents to share the same live local state while editing.
- The task is primarily sequential implementation.
- There is no explicit synthesis owner (Orchestrator role not assigned).
- The user did not authorize the extra cost for a high-overhead review mode.
- The task can be completed safely with one agent and normal verification.

---

## 4. Human Authorization Boundary

The AI **may recommend** `multi-agent` but **must not start it automatically** when any of these are true:

- File writes will occur after the review.
- `governance/` may be edited.
- Commit / push / PR may follow.
- Cross-model or cross-tool dispatch is needed.
- The expected cost is materially higher than normal single-agent work.

**In these cases: stop and ask for approval.**

This is the standing split: AI judges routing, human controls authorization. See also: OpenAI's guardrails pattern (human review before side effects); NIST AI 600-1 (human oversight + go/no-go threshold).

---

## 5. Recommended Role Sets

### A. Audit Set
Use for risk review or protocol review.
- `Scout` → gather facts, conflicts, gaps (read-only)
- `Auditor` → refute, find failure modes (kill mandate, read-only)
- `Strategist` → judge direction, prioritization, drift (read-only)
- `Orchestrator` → synthesize only (no independent conclusions)

### B. Verification Set
Use for high-stakes claim checking.
- `Scout` → source collection (read-only)
- `Auditor` → challenge the claim (read-only)
- `Orchestrator` → compare and issue verdict

### C. Product Review Set
Use rarely, only for complex cross-feature review.
- `Scout` → trace behavior and file boundaries (read-only)
- `Auditor` → regression / failure review (read-only)
- `Orchestrator` → merge findings
- `Executor` stays separate and runs serially in Phase 3

---

## 6. Serial Write Rule

Even when `multi-agent` is used, all file mutation stays **serial**.

| Allowed in parallel | Not allowed in parallel |
|---------------------|-------------------------|
| Reading | Editing shared files |
| Searching | Updating governance state |
| Reviewing | Commit / push steps |
| Evidence gathering | Updating HANDOVER current state |
| Risk analysis | Any write to `governance/` |

### 6a. Conductor and worktree isolation (binary)

- **Default is single-agent.** Read-only scouts are permitted for discovery and
  classification only; a scout must not edit files, run mutating commands, commit, or
  claim ownership independently.
- **The Conductor is the only writer and the only committer.** Exactly one
  write-capable agent holds `ACTIVE_EDIT_OWNERSHIP.md` at a time.
- **Write-capable parallel agents are forbidden** unless all four hold: (1) each agent
  runs in a **separate git worktree**, (2) ownership is explicit per worktree, (3) a
  merge plan is predeclared, (4) the user explicitly authorized it.
- An ownership conflict between two write-capable agents is a **hard stop** (see
  `failure-recovery-flow.md`, step 1). Do not build a new multi-agent orchestration
  framework to work around this rule.

---

## 7. Output Contract (per dispatched agent)

Every parallel agent must have all five of these stated before fan-out. If any is missing, do not fan out.

1. One role (from the role table in `multi_agent_workflow.md`).
2. One sentence objective.
3. Read-only or write permission — stated explicitly.
4. One output location or format.
5. One stop condition.

---

## 8. Failure Modes to Watch

- **Role collapse** — nominally multi-agent but all agents use the same reasoning path.
- **Approval fatigue** — human reviews so often they click through; guardrails become noise.
- **Template overload** — new project inherits High-Governance machinery that slows delivery.
- **Wrong portability** — rules designed for this project copied as universal truths.
- **Metric gaming** — log entries accumulate but never prove "what multi-agent found that single-agent missed."
- **Skill supply chain pollution** — copied skills carry external dependencies or hidden action boundaries.

---

## Sources

- Anthropic, multi-agent research system (2025-06-13) — 15x token cost; breadth-first tasks only; most coding tasks not suited.
- OpenAI, practical agent guide (accessed 2026-06-26) — start single-agent, escalate only when needed, add guardrails + human review.
- NIST AI 600-1 GenAI Profile (2024-07-26) — define human oversight, go/no-go threshold.
- Tran & Kiela, arXiv:2604.02460 (2026-04-02) — equal-budget single-agent matches or beats multi-agent on multi-hop reasoning; advantage often from unaccounted compute.
- Zhang et al., MAST, arXiv:2503.13657 (2025-03-17) — 14 multi-agent failure modes; benchmark gains often minimal.
