# ECC Capability Gap Map

**Reference:** [affaan-m/ECC — Everything Claude Code](https://github.com/affaan-m/ECC)
**Assessed:** 2026-06-28
**Scope:** ai-control-plane vs ECC public repo (README + CLAUDE.md)

## What ECC Is

- Cross-harness agent operating system: curated bundle of agents, skills, hooks, rules, and commands
- Targets breadth: 271 skills, 67 specialized agents, 92 commands, 34 language/framework rule sets
- Supports 6+ harnesses: Claude Code, Cursor, Codex, OpenCode, GitHub Copilot, Zed
- Key differentiators: AgentShield (102-rule security auditor), Continuous Learning v2 (auto pattern extraction), GitHub App (hosted/paid)
- Distribution: `npx ecc-universal`, plugin marketplace, shell script fallback

## ai-control-plane Design Position

ai-control-plane is intentionally a **thin governance substrate**, not a domain skill library. Its value is:
- Durable per-project governance (adapter, hooks, session state, protected paths)
- Operator-visible audit trail (JSONL + SQLite mirror)
- Cross-session and cross-tool continuity (handover, skills lock)
- Quality protocol layer (AIS, Darwin checks, evidence discipline)

This is orthogonal to ECC's breadth-first skill marketplace model — both can coexist.

## Capability Matrix

| Capability | ECC | ai-control-plane | Gap |
|---|---|---|---|
| Per-project adapter config | Yes (harness adapters) | Yes (adapter.json) | NONE |
| Session state log (JSONL) | No | Yes | FULL — acp advantage |
| Session state SQLite mirror | No | Yes | FULL — acp advantage |
| Git hooks: protected-path pre-commit | Partial (post-edit, secret detection) | Yes | PARTIAL — acp stronger |
| Git hooks: post-commit session capture | Partial (SessionStart hook) | Yes | PARTIAL — acp stronger |
| Health-check (multi-point attach verify) | Partial (AgentShield) | Yes (17 checks) | PARTIAL — acp stronger |
| Drift scanner | No | Yes | FULL — acp advantage |
| Governance / constitution layer | No | Yes (governance/, agent-constitution.md) | FULL — acp advantage |
| Protocol library (7 protocols) | No | Yes | FULL — acp advantage |
| Node/queue-based work tracking | No | Yes (NODE_QUEUE.md) | FULL — acp advantage |
| Effectiveness log + summarizer | Partial (Continuous Learning v2) | Yes (JSONL + summarizer) | PARTIAL |
| Permissions profile installer | Partial (install profiles) | Yes | PARTIAL — acp more structured |
| Focused skill library (8 governance skills) | No equivalent | Yes | FULL — acp advantage |
| **Security auditing (rules-based)** | **Yes (AgentShield, 102 rules)** | **No** | **FULL — ECC has it** |
| **Automatic memory persistence hook** | **Yes (SessionStart/End)** | **Partial (manual HANDOVER.md)** | **PARTIAL — ECC stronger** |
| **Cross-harness support** | **Yes (6+ harnesses)** | **No (Claude Code only)** | **FULL — ECC has it** |
| Specialized domain agents (67) | Yes | No | FULL — ECC has it |
| Broad skill library (271 skills) | Yes | No (by design) | FULL — ECC has it |
| Language/framework rule sets (34) | Yes | No (by design) | FULL — ECC has it |
| Legacy slash commands (92) | Yes | No (by design) | FULL — ECC has it |
| Token optimization guidance | Yes | No | FULL — ECC has it |
| Package manager auto-detection | Yes | No | FULL — ECC has it |
| GitHub App / hosted tier | Yes | No (by design) | FULL — ECC has it |
| Plugin marketplace distribution | Yes | No (by design) | FULL — ECC has it |
| Test suite (coverage) | Partial | Yes (6 test scripts) | PARTIAL — acp more systematic |

## Top 5 Gaps Worth Closing

### 1. Security Auditing (P7 — next priority)
ECC's AgentShield runs 102 rules against: agent configs, MCP surfaces, hooks, secrets, permissions. ai-control-plane has no rules-based scan.
**Minimum viable:** scan agent config, hooks, permissions, protected-paths, and secrets surface. Produce a scored finding list.

### 2. Automatic Memory Persistence Hook (P8 candidate)
ECC's SessionStart hook auto-restores context. ai-control-plane relies on manual HANDOVER.md updates — the most common failure mode in this project's history.
**Minimum viable:** post-commit hook emits a structured handover update to `.agents/session_log.jsonl`; session-close reads it back.

### 3. Effectiveness Log → Promotion Automation (P8)
ai-control-plane has the JSONL log and summarizer; ECC's `/evolve` command shows auto-extraction is feasible. The current manual promotion loop is the weakest link in the continuous-learning path.
**Minimum viable:** a `promote_instincts.ps1` that reads effectiveness_log.jsonl, extracts patterns above a threshold, and proposes a HANDOVER.md update.

### 4. Drift Scanner + Health-Check Unification (P6 quick win)
ai-control-plane has both separately. An operator status command that runs both and returns a single JSON verdict would close the observability gap.
**Minimum viable:** `scripts/check-attach-health.ps1` wrapper that runs health-check + drift scan and emits one combined result.

### 5. Cursor Adapter (P9)
ECC supports Cursor with 15 hook events. If the operator switches to Cursor mid-project, ai-control-plane loses all governance. A `.cursor/rules/` adapter (2-3 rules files) would close the most common tool-switch gap.
**Minimum viable:** `.cursor/rules/acp-bootstrap.mdc` that reads adapter.json and enforces protected paths.

## Non-Goals — What ECC Does That ai-control-plane Should NOT Copy

| ECC capability | Why it is not a goal |
|---|---|
| 271-skill domain library (frameworks, ML, marketing) | Scope bloat; contradicts thin-substrate design |
| Plugin marketplace distribution | Would force user-facing feature pressure |
| Hosted GitHub App / paid tier | Contradicts local-first charter |
| 92 legacy slash commands | No legacy command surface to maintain |
| Language-specific rule sets (34) | Product repos supply their own coding rules |
| Broad specialized agent library (67) | Out of scope for a governance layer |

## Summary

ai-control-plane has structural advantages ECC lacks: durable session state, governance layer, drift detection, and protocol discipline. ECC has breadth advantages ai-control-plane intentionally skips. The gaps worth closing are in security auditing (P7), memory automation (P8), and cross-harness coverage (P9). Everything else is a deliberate non-goal.
