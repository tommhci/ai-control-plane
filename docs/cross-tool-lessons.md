# Cross-Tool Lessons Registry

**Purpose:** make lessons survive tool switches. AI tool memory stores
(Claude memory/, Antigravity cloud conversations, Codex sessions) are
**caches, not the system of record** — a lesson encoded only there
evaporates when you switch tools. Every lesson discovered inside a
tool-bound store must be promoted here (tool-agnostic, in-repo) within the
same session.

**Rule (added 2026-08-29, after harvest round 1; amended same day —
double-write):** if you find yourself saying "I learned this before" while
reading a tool's memory — the lesson belongs in BOTH places: **this file
(persistence) and the tool's memory (runtime delivery)**. Tool memory is
the only layer with runtime retrieval (description matching); the registry
is the only layer that survives tool switches. Single-canon degrades
delivery — Claude had L1 in memory since 2026-07-23 and the approve flow
still failed on 2026-08-29 morning; a static registry alone would not have
done better. Write memory AND registry.

Sources: harvested 2026-08-29 from tool-bound memory stores of the first
client line (15 files; client-local paths de-identified per the G/R/L
layering rule in AGENTS.md). Originals remain in tool-local storage;
this file is the canonical tool-agnostic copy.

---

## Operational lessons (cross-tool)

### L1. Governance commit sequence (stage → approve → commit, no gaps)
**Trigger condition:** any flow touching `approve_governance_commit.ps1`,
`.governance-approval.json`, or a protected-path staging set.
The protected-path approval flow is order-sensitive: ① `git add <exact
files>` (the approval script checks the *staged* set, not the working
tree) → ② run `approve_governance_commit.ps1` (single-use token, ~10 min
TTL) → ③ `git commit` immediately, nothing in between. An empty-message
bare commit still triggers the pre-commit hook and burns the token.
*Validated 2026-08-29: a morning session's approve silently missed on a
wrong path, leaving staged protected changes stranded all day.*
*Enforcement since 2026-08-29: mechanical — tests/test_canary_l1.ps1
(12/12, dual host) exercises block → approve → burn → expiry → drift
end to end.*
*Retire when: the approval flow itself is replaced; the canary retires
with it.*
Source: memory/feedback_governance_commit_sequence.md (2026-07-23).

### L2. Check history before repair (per-file, not per-batch)
Before reconstructing corrupted/lost content, find each affected file's
own last-clean commit (`git log -- <path>` per file) and diff — never
rebuild by inference while a clean source exists. Generalizes: any
"state got damaged" task defaults to "check history for ground truth per
affected item." *Sibling of U4 (metadata ≠ content): U4 gates deletion,
this gates reconstruction.*
*Enforcement since 2026-08-29: scripts/u4-gate.ps1 makes the deletion
side mechanical (binary gate + disposal audit log).*
*Validated 2026-07-03: 11 files restored with zero inference.*
*Retire when: never — cognitive discipline; re-validate annually.*
Source: memory/feedback_check_history_before_repair.md (2026-07-03
mojibake incident, 11 files restored with zero inference).

### L3. Test with the exact engine the real run uses
**Trigger condition:** any new/modified `.ps1` script, any script with
non-ASCII content, any native (`git`/external) call — run dual-host before
commit.
pwsh vs Windows PowerShell 5.1 differ materially (BOM handling, native
stderr → NativeCommandError, EAP semantics). Scripts with non-ASCII
content or native calls must pass under BOTH hosts — see
`scripts/run-full-suite.ps1` (dual-host matrix) and findings finding 5.
*Re-learned independently on 2026-08-29 by the worktree-audit author —
the lesson existed in tool memory but not in the tool-agnostic layer.
Re-validated again 2026-08-29 (same day): the canary author wrapped
native git calls under 2>&1 without the EAP=Continue pattern and PS 5.1
terminated the test — third independent hit.*
*Retire when: the two PowerShell engines converge (no known date).*
Source: memory/feedback_powershell_engine_consistency.md.

### L4. Declare RECOVERY MODE after a false stop
After an interrupted/false-stop incident, explicitly declare recovery
mode before continuing — continuous-run and batch discipline otherwise
conflict silently.
*Validated: not re-triggered since harvest — apply on the next
false-stop and record the date here.*
*Retire when: a replacement session protocol covers interruption
semantics.*
Source: memory/feedback_recovery_mode.md.

### L5. User-action steps must be copy-pasteable
Whenever a step is reserved for the owner (approval scripts, terminal
actions), give the complete literal command for their real environment —
never a description. *Applied throughout the 2026-08-29 sessions.*
*Validated 2026-08-29: every owner-action step this round shipped as a
copy-pasteable literal command.*
*Retire when: never — human-factors constant.*
Source: memory/feedback_give_executable_instructions.md.

### L6. Load discipline (what to read at session start)
Per-session must-reads vs on-demand files are distinguished so startup
stays cheap — see each client's AGENTS.md Session Start Checklist and
PROJECT_STATUS.md "read this first" snapshot. Lessons and state belong in
those files, not in chat or tool memory.
*Validated 2026-08-29: this repo's first-read chain (CLAUDE.md →
AGENTS.md checklist → PROJECT_STATUS → registry) is in place and
boundary-lint-scanned; cross-tool reach itself is what the Phase F
verification protocol tests.*
*Retire when: a tool's native session loading makes manual first-read
chains redundant.*

---

> Provenance (2026-08-29): a former "flow-specific" section here (product
> design patterns, load mechanics, owner language preference) was relocated
> to the owning client repo's own docs per the G/L layering rule
> (AGENTS.md "Layering"). The language rule it carried is codified in
> AGENTS.md "Output Language"; the design patterns live in the client
> repo's NODE_QUEUE conventions. This registry keeps only cross-tool,
> client-agnostic lessons.

### L7. Scope-diff before bulk re-validation (hash churn ≠ semantic change)
**Trigger condition:** a batch validation gate reports many stale items at
once (stamps, signatures, checksums), and the gate's equality check cannot
distinguish hash churn from semantic change.
The gate's default remediation text ("re-read each item for real") coerces
an N-times full re-verification even when the staleness is pure hash churn.
Before complying, run one scope-diff over the batch's changes (files
touched, hunks, net delta) and classify: if no procedural or semantic
surface was touched, the whole batch becomes a single adjudication
("repin in one batch"), not N verifications. Objections are raised
per-item by whoever disagrees (one dissenter exits the batch), not by
re-running the gate.
*Validated 2026-08-29: an 8-commit range (net -111/+34, all hunks in
pointer-downgrade + checklist additions) collapsed 14 stale stamps into
one batch repin via a scoped diff — zero procedural sections touched.*
*Retire when: gates report a semantic-diff class alongside the hash,
making the pre-analysis redundant.*
Source: DiffScope pre-analysis in a client repo, ef70b0d7 (2026-08-29).

### L8. Proxy teardown vs long-lived client socket backoff
**Trigger condition:** an AI desktop/IDE client reports network or connection
loss while a local proxy or TUN is active.
When a proxy core restarts or the active node switches, all underlying TCP
sessions are reset. Browser traffic recovers instantly, but long-lived
multiplexed connections (gRPC/HTTP2) enter an exponential backoff loop
(30s-120s) and the client appears "dead" even though the machine-level path
is healthy.
**Triage rule (30-second gate before any destructive action):**
1. Test the browser path through the same proxy (a simple 204 endpoint).
2. Browser OK -> do NOT restart the proxy core/service: that resets the
   client's backoff timers and re-creates the outage. Restart only the
   affected client application; if that does not recover it, switch the exit
   node (shared-node server-side rate limiting is the next suspect).
3. Browser dead -> suspect proxy core crash, stale-route pollution, or exit
   node loss; only now is a core restart legitimate.
*Validated 2026-09-02: machine-level path verified healthy (HTTP 204) while
two desktop AI clients reported false death after a proxy core restart; the
restarted client recovered instantly, the other self-recovered on backoff
timeout.*
*Retire when: the affected clients ship fast, correct reconnect logic that
makes the false-death window unobservable.*
Source: network proxy incident post-mortem, 2026-09-02. Full evidence,
triage tree, and failure patterns live in the network governance repo:
`audits/network-infrastructure-audit/AI-NETWORK-RUNBOOK.md` under the
Clash Verge config directory.

---

## Promotion checklist (for future sessions)

1. Lesson discovered inside any tool-bound store →
2. **Classify G or L (boundary gate, 2026-08-29):** G = applies to any
   project/tool → this registry. L = project-specific → the owning
   client repo's own lessons/findings file. When in doubt, L —
   G promotion needs applicability beyond a single project (guards
   against overfitting the global layer to one client's failures) →
3. Restate it tool-agnostically (no project names, no client-specific
   paths, no machine-absolute paths in the rule body; provenance =
   date + event type only) →
4. Add to the chosen layer with source attribution (G: this file;
   L: the client repo) →
5. If it gates a destructive action, also add it to the register
   maintenance rules (see U4 for the pattern) →
6. For G entries: run `scripts/boundary-lint.ps1` (binary) →
   Commit + push. Tool memory entry can then be left to rot.
