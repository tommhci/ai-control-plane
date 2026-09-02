---
name: project-governance-tiers
description: "Three-tier governance model for copying the AI collaboration infrastructure to new projects. Read when setting up a new project from this template."
status: v1 — 2026-06-26
---

# Project Governance Tiers

**Purpose:** copy only the amount of AI collaboration infrastructure the project can justify. Default recommendation: start at `Lite` or `Standard`. Use `High-Governance` only when the project has real coordination, audit, or drift risk.

---

## Tier 1: Lite

**Best for:** small solo projects, low-risk implementation work, short-lived repos, projects where speed matters more than governance depth.

**Include:**
- `AGENTS.md`
- `AI_BOOTSTRAP.md`
- `HANDOVER.md`
- `NODE_QUEUE.md`

**Optional:**
- Minimal `governance/README.md`

**Optional (low overhead, recommended even for Lite):**
- `.agents/skills/EFFECTIVENESS_LOG.md` — a single log file; almost no overhead, but feeds Darwin Check if you ever upgrade to Standard. Worth including from day one.

**Do not include by default:**
- Multi-agent workflow
- Protocol review layer
- Extensive skill routing
- Citation governance (unless research-heavy)

**Core rules to keep regardless of tier:**
- Read before write.
- Minimal diff, node-scoped.
- Verify before reporting done.
- One active node at a time.
- Handover snapshot before switching context.

**Failure mode if overbuilt:** meta overhead exceeds product work.

---

## Tier 2: Standard

**Best for:** serious product projects, medium-term repos, repeated AI usage across sessions, projects where drift, stale prompts, or handoff mistakes would hurt.

**Include everything in Lite, plus:**
- `governance/README.md`
- `governance/agent-constitution.md`
- `.agents/skills/README.md`
- `.agents/skills/EFFECTIVENESS_LOG.md`
- `.agents/ACTIVE_EDIT_OWNERSHIP.md`

**Recommended practices:**
- Session Start Check (ownership → session type → node alignment).
- Skill routing via `.agents/skills/README.md`.
- Explicit handoff discipline — `HANDOVER.md` updated before switching context.
- Experience Promotion Rule — session learnings promoted to repo files when pattern appears in 2+ sessions, applies cross-tool, costs >10min to re-derive.
- Blocked-session closeout — even a blocked session needs a `session-close` entry.
- Read-only analysis before risky changes.

**Do not include by default:**
- Full multi-agent workflow.
- Darwin / protocol review cadence.
- Heavy citation rules (unless the project produces claims for external audiences).

**Failure mode if underbuilt:** repeated drift across sessions, stale handoffs, protocol files edited inconsistently.

---

## Tier 3: High-Governance

**Best for:** governance-heavy systems, high-stakes research or policy workflows, long-lived projects with many AI sessions, projects using multiple AI tools or multi-agent review, projects where incorrect advice or stale docs can mislead future work.

**Include everything in Standard, plus:**
- `.agents/protocols/AIS_charter.md`
- `.agents/protocols/multi_agent_workflow.md`
- `.agents/protocols/MULTI_AGENT_TRIGGER.md`
- `.agents/MULTI_AGENT_ROI_LOG.md`
- Citation Integrity rules (in `AGENTS.md`)
- `HANDOVER.md` sections: `DEAD ENDS`, `PROTOCOL LEARNINGS`, `ANALYTICAL STATE`
- Explicit audit / review skills (Scout, Auditor, Strategist roles defined)
- Multi-agent dispatch rules + human authorization boundary

**Recommended practices:**
- Producer ≠ Reviewer (never let the same agent review its own output).
- Human approval for high-side-effect actions (writes, commits, publishes).
- Protocol Review cadence: after every 3 real product sessions, run one protocol review — apply the 4-step template (Claim → Variables → Evidence → Conclusion → Reopen condition) to one pending governance question. Do not run it more than once per cadence cycle.
- Cross-session drift checks.
- Strong [Fact] / [Inference] / [Insufficient evidence] discipline in every analytical output.

**Failure mode if overused:** governance becomes the work; routing cost exceeds delivery value; too many documents for simple projects.

---

## Selection Guide

| Choose | If |
|--------|-----|
| `Lite` | Solo, low stakes, mostly coding, low need for historical continuity |
| `Standard` | Repeated sessions expected; repo has real architectural rules; stale instructions would be costly; reliable handoff and routing needed |
| `High-Governance` | Governance is part of the product or process; AI workflow quality is a first-class concern; audits / strategy reviews / multi-agent review expected; wrong process decisions cost more than the overhead |

---

## Upgrade Rules

Upgrade a project one tier when **2 or more** of these become true:

- The same drift problem appears in 2+ sessions.
- Handoff mistakes cost meaningful time.
- AI tools are switching often.
- Strategic or research claims need explicit evidence discipline.
- The repo now includes governance-critical files.
- Multi-agent review is no longer rare.

---

## Downgrade Rules

Downgrade one tier when:

- Most sessions are simple implementation.
- Governance docs are rarely used.
- The process is slowing execution more than it improves quality.
- The repo has stabilized and no longer needs heavy review machinery.

**Do not carry `High-Governance` into every new repo by default.**

---

## Setup Sequence

When starting a new project:

1. Run `SETUP_CHECKLIST.md` to pick and adapt the base files.
2. Choose a tier from this document.
3. Delete files that belong to a higher tier than you chose — an unused protocol file is a future confusion source.
4. Run the smoke test in `SETUP_CHECKLIST.md` to verify the trimmed setup works.
5. Record the chosen tier in your `HANDOVER.md` INVARIANTS section.

---

## Common Error: Wrong Portability

Rules designed for one project become "universal truths" when copied blindly. Before copying a governance file to a new project, ask:

- Is this rule specific to the source project's scale, stack, or failure modes?
- Does the new project share those characteristics?
- If not, rewrite rather than copy.
