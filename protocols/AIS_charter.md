---
name: AIS-charter
description: "AI Interaction System — minimal charter for Darwin checks and cross-system quality reviews. Load this when running strategic-alignment skill or doing Darwin checks. Do NOT load for routine node execution."
source: customize this file for your project; update when your team's failure-mode list has a major version bump
sync: manual
---

# AIS Charter

## Four non-negotiable constraints (always active)

① Judgment before evidence — lead with the core finding
② Distinguish [Fact] / [Assumption] / [Inference] — no conflation
③ Flag gaps directly — never substitute vague language for an honest gap marker
④ Frame core claims as open questions, not closed assertions

## Known AI collaboration failure modes (relevant to most projects)

- **C-08 Curse of Instructions:** P(all constraints followed) = P(single)^n. Every constraint added to a session degrades compliance with all others. Design governance with the fewest constraints that cover the most risk.
- **D7 System-as-avoidance:** Building infrastructure instead of doing real-use validation. Symptom: 3+ consecutive sessions of architectural work with zero friction-from-actual-use data.
- **D8 Visibility inversion:** In multi-agent workflows, short directional inputs from the human produce large AI outputs — the human's contribution becomes invisible. Counter: explicitly ask "was this a [Challenge] input or an execution input?"
- **D9 Premature execution on Challenge inputs:** When a question challenges a mechanism assumption (not choosing within a mechanism), executing immediately without restating + confirming first. Sequence: restate → confirm → propose → execute.
- **Scope escalation (execution-layer):** AI agent autonomously upgrades task scope beyond the instruction. Mitigation: hard stops in AGENTS.md for governance/ directory changes. Note: distinct from "autonomy escalation" (Microsoft AI Red Team taxonomy, June 2026) where an agent upgrades its own permission boundary mid-workflow — now addressed in `AGENTS.md` `## Autonomy Escalation Guardrail` (five explicit authorization triggers with stop banner) and `## Action Reversibility Table` (binary permission lookup with reversibility index ι, added 2026-06-27).
- **Conditional constraint fragility:** Conditional constraints (e.g., CONTINUOUS mode stop conditions in AGENTS.md) score well below vanilla constraints in agentic instruction-following (AgentIF CSR ~55–66% vs vanilla ~80–87%; tool and formatting constraints are even lower at 10–45%). Design stop conditions to be as binary and unconditional as possible. Source: AgentIF (arXiv:2505.16944, NeurIPS 2025), Table 2 — web-verified 2026-06-26.
- **Context fill degradation:** Instruction-following quality degrades measurably at 60–70% context fill in frontier models. Long sessions loading many governance files + code context are at risk. Signal: CONTINUOUS mode stop conditions become unreliable near session end. [Insufficient evidence — no verified source as of 2026-06-27; treat as working hypothesis.]

## Key research evidence (use when doing Darwin checks)

- AgentIF NeurIPS 2025 (arXiv:2505.16944): Best-model ISR 27.2% (o1-mini). Constraint Success Rate by type (web-verified Table 2, 2026-06-26): tool 10–27% and formatting 40–45% are the lowest; conditional 55–66% sits well below vanilla 80–87% but is NOT the worst type. Implication holds: binary > conditional stop conditions, because conditional sits far below vanilla. [Corrected 2026-06-26 — prior "conditional = lowest ISR" was a misread of the source.]
- CCR arXiv:2603.12123 (Song, 2026-03): Fresh-context review F1=28.6% vs same-session F1=24.6% (p=0.008, d=0.52). **Critical: repeated same-session review (SR2) F1=21.7% — worse than single review (p<0.001).** Running quality checks twice in the same session actively degrades quality below single-pass baseline.
- Self-Correction Bench arXiv:2507.02778: 64.5% avg blind spot rate across 14 models. "Wait" token reduces blind spots 89.3%.
- AURA arXiv:2510.15739: Scope escalation + reversibility are the two primary agent risk dimensions.
- Constraint recall ≠ constraint compliance (arXiv:2604.28031, 2026-04): Models recall constraints they are violating but continue to violate them. Constraints require active checkpoint triggers, not just presence in system instructions.

## Operational rule: quality check (pqs) usage

Derived from CCR SR2 result (arXiv:2603.12123):

- **If pqs finds issues → fix them → verify in a NEW session.** Do not re-run pqs in the same session.
- **If pqs finds no issues → do not re-run.** Open a new session with Mode B handoff + original output → run pqs fresh.
- Applies equally in chat and CLI agent sessions.

## Darwin check prompt (copy-paste ready)

Use in a fresh context or paste this charter at the top of a new agent session:

```
[Paste this file]

Review the following AI collaboration protocol for this project.
Using the failure modes and research evidence above, identify:
① Which known failure modes does this protocol NOT yet guard against?
② Which constraints could be removed without increasing risk (C-08 optimization)?
③ What did we learn in the last sprint that should change the protocol?

[Paste relevant sections of AGENTS.md or skills/*.md]
```

## For new projects adopting this control plane

**This file is the Darwin check trigger only — not a complete migration template.**

A new project needs three distinct layers, not one:

**Layer A — Quality constraints** (portable, copy from this file):
Copy the 4 non-negotiable constraints into the new project's AGENTS.md.

**Layer B — Operational routing** (portable, define in your project's operator manual):
- Bounded Charter initialization — why to send 4 constraints, not the full manual
- Default Task template + post-output check
- Mode B Handoff format — for cross-session state transfer
- Quality Check (pqs) — with the SR2 rule above applied
- Deliverable Gate — run before every output

**Layer C — Darwin check trigger** (this file):
Copy to `.agents/protocols/AIS_charter.md` in the new project.

**Customize for your project — do NOT copy verbatim into a new project:**
- Personal domain protocols (e.g., trading rules, research practices specific to your team). These are person-specific, not project-specific.
- Personal validation trackers. Replace with your own open questions.
- Domain-specific language or decision frameworks. Replace with your team's equivalents.

**Do NOT paste a full operator manual into any session** — that is C-08 territory (10+ constraints simultaneously).
