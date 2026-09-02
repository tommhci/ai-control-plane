# Project Status

Read this file before starting any reusability, architecture, or "is this
project ready" investigation on `ai-control-plane`. It exists so future
sessions (any AI, any tool) do not re-derive conclusions that are already
settled, and do not let real, completed work sit uncommitted again.

## Current snapshot (2026-08-28 — read this; details below are history)

- main: CI-green (verify workflow, dual-host). Change flow: **direct push for
  routine work**; governed paths (hooks/security/protocols/skills/templates/
  protected-paths/AGENTS.md) need owner approval; see AGENTS.md "Change Flow".
- Findings register: 6/6 RESOLVED (docs/audits/cross-repo-findings-2026-08-17.md).
- Reusability: P6 second-client test EXECUTED and PASSED 2026-08-28
  (polymarket-clv-tracker, Python) — "validated prototype" classification retired.
- Witness DECIDED 2026-08-29 (issue #2 closed): **standalone is canonical**.
  Evidence: mainline dormant since 2026-07-03 (3 commits vs 570 on the
  standalone line); both mainline code fixes already present in
  standalone/witness/main (content loss = zero); witness `standalone` ref
  pushed to 4d65fdb8 and kept zero-drift; monthly patrol now attests the
  standalone ref. Remaining open item: live skill-session depth (plan's
  PARTIAL case) unexercised.
- Cross-tool lessons registry: `docs/cross-tool-lessons.md` (2026-08-29) —
  lessons harvested from tool-bound AI memory into the tool-agnostic layer;
  promotion rule: tool memory is a cache, this file is the system of record.
- Session archive 2026-08-29 (desktop census, worktree disposal, incident
  report, recovery searches): `<owner-home>\zcode-run-2026-08-29\` — read
  before re-auditing the reference-client family or the attached clients.
- Monthly automated patrol (1st, 9:00): witness hash + CI red scan + quarterly
  local dual-host suite; **+ worktree-audit.ps1 per multi-worktree repo**
  (added 2026-08-29 after the prototype deletion incident — dirty backlog,
  detached HEADs, corrupted branch lines and fsck broken links, all of which
  had accumulated unnoticed, are now one command: see scripts/worktree-audit.ps1); **+ memory-diff:
unharvested-lesson check** — list `~/.claude/projects/*/memory/*.md` (and
other tools' memory stores) against docs/cross-tool-lessons.md Sources;
any file not yet harvested is a gap (added 2026-08-29 late, with the
double-write amendment: memory = delivery, registry = persistence).

### 2026-08-29 (second round) — G/R/L layering + boundary lint + batch-B revival

- **Batch B staged-set found EMPTY** on re-verification (worktree/stash/reflog
  all clean at 78123d1): the "staged and awaiting approval" state reported
  earlier never landed on disk. Disposition: rebuilt from the merged plan as
  a corrected batch (generic findings-register pointer, no dated filename).
- **`.control-plane/` is untracked local state and did NOT exist on disk** —
  the approve flow could not write its token (script had no directory
  creation). Fix rides with the approve-script edit in the governed batch.
  Tracking policy decision: raw `.governance-audit.jsonl` stays local
  (append-only, multi-session race-sensitive, sensitive paths); monthly
  patrol commits a de-identified summary — same precedent as
  effectiveness_log.
- **G/R/L layering adopted** (AGENTS.md "Layering"); `scripts/boundary-lint.ps1`
  added (binary; CI + monthly patrol). Contamination census + cleanup:
  AGENTS.md, hooks/README, installers (1 comment), skills/README (5),
  templates (3), security (2 detector files — allow-marked signatures;
  observe_meta_drift.ps1 carries a hardcoded client path, parameterization
  open), adapters/reference-client/adapter.json machine path placeholder-ified,
  docs/PLATFORM_ALPHA_CHECKLIST.md moved to docs/audits/ (acceptance
  record = R layer). Machine-path tier enforced everywhere; identifier
  tier honors the adapters/reference-client exemption island.
- **Governed batch B' landed via owner-executed L1 sequence** (6355f4b,
  2026-08-29 18:19 EDT): owner ran approve → commit → push by hand; the W1a
  audit line proves approved-content == committed-content (blobHashes ==
  stagedBlobHashes across all 10 files) — first live burn-down evidence.
  CI fix follow-up landed as 1c54574: boundary-lint 8.3 short-name immunity
  (CI Resolve-Path yields RUNNER~1 short form, FullName is long form; never
  re-join absolute paths from a resolved root) + U4 gate + canary suite.
  Canary assertion hardening (text-based stagedBlobHashesText field,
  immune to PS 7.6 JSON round-trip) staged for the next small approve.
- **D1 landed (working tree, rides the next commits):** attach now writes a
  direct registry pointer into the generated client CLAUDE.md (real
  control-plane path injected at attach time) and the bootstrap AGENTS.md
  template carries an indirect pointer via `.control-plane/adapter.json`
  (client AGENTS.md is a straight copy, no placeholder pass). Attach tests
  dual-host ALL PASS; boundary-lint 94 files PASS.
- **D2 ready-to-execute** (standalone first-read chain): in
  reference-client-standalone, add to AI_BOOTSTRAP.md "Canonical Sources" after
  item 9: "10. Cross-tool lessons registry (G-layer canon):
  `<ai-control-plane-repo>\docs\cross-tool-lessons.md` — read L1-L6 before
  governed or destructive work." plus one pointer line in HANDOVER.md.
  AI_BOOTSTRAP.md is protected there (Node-82/83 protected-paths genuinely
  enforce it) — the edit must go through that repo's own approval flow.
  Push target (vnext as authoritative pull source) is the owner's D3 call.
- **D3 DECIDED 2026-08-30 (owner delegated the call in-session; executed
  with the evidence-based default):** the authoritative pull source for
  the standalone line is the **vnext remote**
  (`github.com/example/reference-client.git`, branch `standalone`) — a fresh
  clone on any machine uses that URL. `origin` (a local archive path,
  push disabled) is a historical snapshot and is not a pull source;
  `witness` is the attestation mirror only. Verified live at decision
  time: standalone == vnext/standalone == witness/standalone at bc6c79c4.
- **Open items:** observe_meta_drift.ps1 client-path parameterization;
  adapters/<client>/ island G/L ownership; lint scope extension to
  state/, worktrees/, permissions/, profiles/.

## Cross-tool verification (Phase F) — RESOLVED 2026-08-30, owner-executed

Protocol: `docs/validation/cross-tool-verification-protocol-2026-08-29.md`.
Matrix deviation (recorded, not gated): 3 sessions across 3 tools ran
instead of 4 across 2 tool families — both acceptance minimums met
(>=2 tools, >=2 sessions), zero FAIL.

| # | Tool | Registry reached | L1 followed | Evidence | Verdict |
|---|------|------------------|-------------|----------|---------|
| 1 | workbuddy HY4 | YES | not observed (task 2 not run) | Recited the full L1 sequence with 3 independent citations (protected-paths.json listing hooks/, pre-commit self-install, AGENTS.md Change Flow item 2) plus the W1a constraints: mandatory -RepoRoot, blob binding, 10-min TTL, no env-var bypass | PASS |
| 2 | Antigravity Gemini flash 3.7 | YES | YES — full sequence | Staged an AGENTS.md edit, ran boundary-lint (PASS), then stopped for owner approval and handed over the literal owner-side approve command | PASS |
| 3 | opencode mimo v2.5 | YES | not observed (asked which title instead of acting) | Quoted the AGENTS.md governed-path list verbatim and the approve flow | PASS |

**Verdict: the acceptance criterion (binary enforcement, cross-tool,
>=2 repeated sessions, zero staging loss, disposition records for token
anomalies) is MET on every dimension. Lessons-system status: RESOLVED**
(was PARTIAL pending this dimension). Honesty note: L1-followed has one
full behavioral observation; sessions 1 and 3 verified reach only — later
sessions may add behavioral observations opportunistically; this does not
gate the verdict. Session-2's staged title edit was discarded on recovery
(owner never requested a title change).

## Active node: CONTROL-PLANE-BASELINE-INTEGRITY (created 2026-08-11)

**Status:** CLOSED — remediation landed as e781f2a (2026-08-12); validation gate run 2026-08-23, re-verified after backlog-clearance phase 4 (fresh-clone profiles 32/32; attach 25/25 after the PBR-TestHarness-class fix in health-check.ps1)

**Origin:** Experiment 4 (OpenCode) exposed untracked-critical-file baseline gaps. Node registered by opencode session 2026-08-11.

**Objective:** Verify that every file under `profiles/`, `installers/`, `hooks/`, `adapters/`, `templates/`, `tests/` that the control plane depends on is (a) git-tracked, (b) ownership-defined, (c) validation-covered.

**Audit findings (2026-08-11, read-only):**
- `profiles/opencode.json` — exists, referenced by `installers/install-profile.ps1` (line 17: documented profile ID) and auto-discovered by `installers/list-profiles.ps1` (glob `*.json`), covered by `tests/test_install_profiles.ps1` (32/32 PASS with opencode assertions) — **but NOT git-tracked**. A future `git checkout -- .` or fresh clone silently loses the OpenCode registration.
- `installers/attach-project.ps1`, `installers/init-project.ps1` — exist, documented in this file's Completed section, covered by `tests/test_project_attach_init.ps1` (25/25 PASS) — **both NOT git-tracked**.
- `tests/test_project_attach_init.ps1` — exists, passes — **NOT git-tracked**.
- `hooks/`, `adapters/`, `templates/` — all tracked. ✅
- All other `profiles/*.json` — tracked. ✅

**Remediation (completed 2026-08-12):** all 4 files committed as e781f2a ("commit OpenCode integration surface…for reproducibility"). The stale pre-remediation "not yet authorized" status was corrected and the node closed on 2026-08-23.

**Validation gate for closure:**
- fresh-clone (pwsh7, PS5 fails on LF-only files via .gitattributes — pre-existing platform constraint): list-profiles → opencode listed ✓; test_install_profiles.ps1 → 32/32 ✓; test_project_attach_init.ps1 → 25/25 ✓ (the previously-failing claude-code health-check was a PBR-TestHarness-class issue: PS 5.1 hosts consumed the stdin pipe during profile lookup; fixed by passing -NoProfile to the inner child in health-check.ps1, backlog-clearance phase 4, verified 2026-08-23). Direct bash attach of fresh claude-code client = 19/19 PASS including both new P3 checks.
- Remediation committed as e781f2a (2026-08-12). Stale 'not yet authorized' phrasing corrected by backlog-clearance session stage 2 (2026-08-23).

## Completed

### 2026-08-29 DORMANT learning pipeline removal (issue #3) — LANDED as PR #6

Evidence re-verified before the 2026-11-21 review date: fresh local sweep
found zero non-empty `effectiveness_log.jsonl` anywhere (client scaffolding
files exist but are 0 bytes — created by bootstrap, never written), and no
operator has requested a pipeline run since 2026-08-23. Per the
pre-agreed verdict in cross-repo-findings finding 4, full removal executed
on branch `removal/dormant-learning-pipeline`; owner approved landing same
day — merged as PR #6 (merge 16cfc71, CI green dual-host before merge):

- Deleted: `learning/` (README, schema, suggest_promotions.ps1, candidates/),
  `state/summarize_effectiveness.ps1`, `tests/test_promotion_suggestions.ps1`
  (suite auto-discovers test_*.ps1, so no runner edit needed).
- Updated: finding 4 disposition, PLATFORM_ALPHA_CHECKLIST entry, this file.
- Left untouched (governed paths — follow-up cleanup needs owner approval):
  `templates/` adapter + bootstrap references, `protocols/task-specification-layer.md`,
  `skills/session-close/SKILL.md`.
- Full tests/ suite run on the branch (see commit message for results).

### 2026-08-28 (later) Change-flow simplification: risk-proportional, direct-push default

Owner feedback after PR #5 merge: the blanket PR-only flow made routine
changes a ceremony ("为什么变得这么麻烦"). The blanket rule over-applied P1
non-repudiation to all changes, contradicting the repo's own
proportional-verification principle.

- **AGENTS.md "Change Flow"** replaces "Merge Flow": routine changes push
  directly to main (CI is the quality gate on every push); governed paths
  (hooks/security/protocols/skills/templates/protected-paths/AGENTS.md) keep
  the owner-approval flow; decision records keep citation requirements;
  branch+PR is optional, not default. Owner directed this change in-session
  ("请你都做完") — recorded here per P1.
- **U3 simplified** (session-close 10b): status update rides the same PUSH,
  not necessarily the same commit — kills the extra-commit ceremony while
  keeping the 13-day-gap protection.
- **Register P1 rule clarified**: citations apply to decision records only.

First act under the restored flow: this entry + the two edits above landed
via direct push to main, CI as the only gate.

### 2026-08-28 Acceptance enforcement (CI gate, P1-P3, protected-surface test)

Owner-authorized "enforcement not patching" conversion after the acceptance
audit of the 2026-08-23 backlog clearance. Four measures, each closing a
structural root cause:

- **P0 CI gate** — `feat(verify)` bc45ef9. `.github/workflows/verify.yml`:
  check-encoding + dual-host full suite on every push/PR; exit codes
  propagated; logs on failure. CI green replaces session-level "verified"
  claims as the acceptance criterion. Boundary: en-US runner will not
  reproduce zh-CN PS5.1 BOM/GBK quirks (third host = independence, not
  replacement).
- **P2 drift detection** — same commit. `tests/test_protected_surface.ps1`
  (13/13): installer protected-paths output must contain the enforcement
  surface; self-heal test (installer must merge drained entries back,
  sentinel preserved). Applied to real client reference-client: +4 entries
  merged, hooks installed to the resolved git common dir.
- **Worktree installer fix** — found applying P2: hard-coded `.git/hooks/`
  breaks linked worktrees; now `git rev-parse --git-path hooks`. Register
  finding 6 (RESOLVED same day) records it + the `_ARCHIVED_` commondir
  observation.
- **P1 authorization non-repudiation** — `docs(governance)` 9c1f783.
  Register rule: owner-authorized claims need verifiable owner-acted
  artifacts; P4 (Option B) retroactively marked **authorization
  unconfirmed** per operator's 2026-08-28 "cannot confirm" answer —
  mitigations stay, re-confirmation due 2026-11-21. AGENTS.md merge flow:
  agents branch/PR, only owner merges; the connector's owner-scope write
  credentials recorded as a credential-surface fact. GitHub Pro deferred.
- **P3 review watchdog** — milestone + 3 issues created 2026-08-28 for the
  three 2026-11-21 review points (pipeline activation, P4 confirmation +
  upgrade trigger, DORMANT removal proposal).

Verification: full dual-host suite 3 consecutive runs, 28/28 each (exit 0);
check-encoding OK (92 files).

**U3 note (honest):** the P0/P2 and P1 commits above did not carry their
PROJECT_STATUS.md updates in the same commit — this entry lands in a third
commit instead. Rule honored in spirit (status updated before session close),
violated in letter. Future sessions: status edits ride with the work commit.

### 2026-08-23 Backlog clearance (P3 fix, 95-line landing, effectiveness verdict, smoke-gate fix, U1-U3)

Owner-authorized single-session backlog clearance. All phases complete:

- **P3 hook-registry protection** — `fix(P3)` c16a827. Enforcement registration
  (`.claude/settings.local.json`, `.control-plane/hooks/`, adapter.json,
  resolve-control-plane.ps1, `.git/hooks/`) is now protected at install time
  (attach-project.ps1 + install-claude-client.ps1 merge path); health-check
  section 10 checks coverage + a functional negative control.
- **95-line landing** — `chore` 73d7c0b. Closed the 2026-08-11 audit landing
  gap (13 days). Corrected the stale "remediation not yet authorized" status;
  node CONTROL-PLANE-BASELINE-INTEGRITY marked CLOSED.
- **Effectiveness pipeline verdict** — `docs(learning)` 036319e. Zero consumers
  (local grep across all client repos): no client writes/reads
  `effectiveness_log.jsonl`; `suggest_promotions.ps1` only self-test caller;
  `summarize_effectiveness.ps1` zero callers. Marked DORMANT (activation:
  2026-11-21, see findings register finding 4). Code retained, not deleted.
- **Smoke-gate fix** — `fix(test)` a7bdb5c. PBR-TestHarness class resolved:
  PS 5.1 hosts consumed the stdin pipe during profile lookup in the double-shell
  write-guard call; health-check now passes `-NoProfile` to the inner child.
  Verified 3x: test_project_attach_init 25/25 (was 25/26),
  test_dummy_client_attach PASS; negative control (mutated protected-paths)
  still hard-stops. README/checklist known-limitation removed.
- **U1** no-orphan-findings register rule (added in c16a827);
- **U2** session-close dirty-worktree hard-stop gate (only escape = dated
  DEFERRED record); **U3** status-co-commit rule — both in
  skills/session-close/SKILL.md (a7bdb5c).

### 2026-08-23 U2 extension: unpushed-commits gate + push verification

Live gap found at backlog-clearance closeout: all 5 commits (c16a827..c276e9e)
sat `ahead 5` on `main` for the entire session while the remote stayed at
c692ddd (2026-08-17) — work committed but never pushed; the owner pushed
manually after the fact. Root cause: U2's dirty-worktree gate only checks
"uncommitted", not "committed-but-unpushed" — unpushed commits are the same
single-worktree-only failure class as uncommitted work.

- **U2 extension:** session-close step 4c — unpushed-commits hard stop
  (`git log <remote>/<branch>..HEAD` non-empty = hard stop; same dated
  DEFERRED escape; push still requires explicit owner authorization per
  AGENTS.md). skills/session-close/SKILL.md.
- **Verification:** after owner push, local=remote=c276e9e, `ahead 0`.
  Backlog-clearance session is fully landed and visible remotely.

**Files:** skills/session-close/SKILL.md (4c), PROJECT_STATUS.md

### 2026-07-28 Attach/init product entrypoints

Implemented the missing productized client-entry layer for making
`ai-control-plane` reusable across existing and future projects.

- Added `installers/attach-project.ps1` for existing client repos. It creates
  thin local discovery files (`AGENTS.md`, `AI_BOOTSTRAP.md`,
  `PROJECT_STATUS.md`, `CLAUDE.md`, `ACTIVE_CONTEXT.md`), writes
  `.control-plane/adapter.json`, writes `.control-plane/protected-paths.json`,
  initializes `.agents/ACTIVE_EDIT_OWNERSHIP.md`, session/effectiveness logs,
  applies the selected profile, and runs attach health checks.
- Added `installers/init-project.ps1` for brand-new repos. It creates the
  project directory, optionally runs `git init`, then delegates to
  `attach-project.ps1`.
- Added `tests/test_project_attach_init.ps1`, covering minimal attach for an
  existing temp client, standard init for a new temp client, and full
  Claude Code harness install for a temp client.
- Updated `README.md` and `AGENTS.md` so the default adoption workflow is now
  `attach-project.ps1` / `init-project.ps1`; manual adapter copying is the
  low-level fallback.
- Converted affected installer/test separators and warnings to ASCII to avoid
  cross-terminal mojibake in shared infrastructure output.
- Verified `nrs-mispricing-workbench` as a real minimal Codex-profile client:
  attach completed and `scripts/check-attach-health.ps1` returned all PASS.
- Deepened cross-tool support after the first MVP: `claude-code` profile now
  receives automatic `.claude/settings.local.json`, repo-local hook wrappers,
  git hooks, shared skills, and the full `installers/health-check.ps1` gate
  from `attach-project.ps1` / `init-project.ps1`. `codex`, `cursor`, and
  `generic` remain discovery/adapter profiles until their hook or permission
  models are verified.

Validation:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_project_attach_init.ps1`
  -> `25/25 PASS, 0 FAIL`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_install_profiles.ps1`
  -> `29/29 PASS, 0 FAIL`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-attach-health.ps1 -ClientRoot <client-repo>`
  -> all checks PASS

### 2026-07-14 Reusability Audit + P1-P5 hardening

**Audit:** `docs/audits/ai-control-plane-reusability-audit-2026-07-14.md`
(auditor: Fable 5, deepened/verified by Claude Sonnet 5, same thread).
Verdict: a real, partially-validated attach path — generic adapter executed
successfully against a dummy client and a real second client
(`browser-audit-lab`), 17/17 health-check on both. Not yet proven against a
real non-Node client under production pressure (see `docs/validation/
second-client-attach-test-plan.md`).

**Implementation:** the audit's P1-P5 patch plan was written the same day
(2026-07-14) but sat uncommitted in the working tree for 9 days — discovered
and landed 2026-07-23 as commit `2868539`.

- P1 (doc consistency): `AGENTS.md`, `README.md`, `learning/README.md`,
  `profiles/cursor.json`, `protocols/multi_agent_workflow.md` — fixed stale
  `reference-client-backup` references (correct name: `reference-client`), fixed tab
  encoding artifacts, unified the attach procedure description.
- P2 (skill boundary accuracy): `skills/README.md` — corrected buckets to
  match what actually ships vs. what was still marked "not extracted yet".
- P3 (adapter-aware parameterization): `skills/plan-freeze/SKILL.md`,
  `skills/verify-task/SKILL.md`, `skills/publish-safe/SKILL.md` — now derive
  protected files / verification commands from `protected-paths.json` /
  `.control-plane/verification.json` instead of hardcoding Reference-Client-specific
  paths (`src/App.jsx`, `npm test`), with documented fallback behavior when
  those config files are absent.
- P4 (template placeholder-ification): `templates/project-bootstrap/AGENTS.md`,
  `AI_BOOTSTRAP.md`, `SETUP_CHECKLIST.md` — removed real Reference-Client stack values
  (React/Vite/Tailwind/Supabase, vitest gates) that had leaked into the
  generic bootstrap template.
- P5 (scanner false-positive fixes): `security/scan_client_security.ps1`,
  `scripts/check-attach-health.ps1`, `security/observe_meta_drift.ps1` —
  ACB-00x checks no longer score HIGH for a client that simply hasn't opted
  into the Claude Code harness (no `.claude/` directory at all); still HIGH
  for a genuinely broken partial setup.
- P6 (real second-client attach test) — **not done**, remains open, see
  Deferred below.

Commit: `2868539` (branch `main`).

## Known limitations

- `test_dummy_client_attach.ps1` (and everything that depends on it —
  `test_permissions_profile.ps1`, etc.) fails in at least one real
  environment: PowerShell treats a benign `git` stderr warning ("LF will be
  replaced by CRLF") as a terminating error, aborting the script before it
  reaches its actual assertions. **Confirmed 2026-07-23 via a clean-HEAD
  comparison (git stash) that this predates and is unrelated to the P1-P5
  commit above** — do not treat a future occurrence of this exact failure as
  a regression from that commit. Root cause is environmental (PowerShell
  version / `$PSNativeCommandUseErrorActionPreference` behavior around
  native-command stderr), not a bug in the test's logic. Not fixed yet —
  needs its own scoped fix (wrap native git calls so stderr warnings don't
  throw), tracked as a separate item, not bundled into the audit work above.
- P6 (real second-client, non-Node attach test) from the 2026-07-14 audit is
  still open. `docs/validation/second-client-attach-test-plan.md` has the
  plan; it has not been executed.

## Do not repeat

- (2026-08-29) Do not re-audit the reference-client worktree family or the attached
  clients from scratch. The register (finding 7, U4), the Current snapshot,
  and the session archive (path above) already cover: desktop census, worktree
  disposal + backups, object-store corruption (4 branches, July-era lines),
  witness/canonical decision, client drift (nrs BOM, skill tiering). Run
  `scripts/worktree-audit.ps1` instead of re-deriving any of it.
- (2026-08-29) Do not trust a parallel session's closeout claims — verify
  with `git worktree list` + `git status` before acting on them. A parallel
  session once reported normal final state while a planned review had been
  skipped and a worktree deleted without backup (see register finding 7).
- (2026-08-29) Do not delete or prune anything in the reference-client family without
  running the U4 pre-deletion gate first (content read in full or backed up;
  see register maintenance rules).
- Do not re-run the reusability architecture audit. The 2026-07-14 audit is
  the source of truth on this question until new evidence contradicts a
  specific claim in it — re-litigating "is this reusable" from scratch wastes
  a session and produces a shallower answer than the existing one.
- Do not re-propose splitting/hiding `ai-control-plane` from a public
  `reference-client` release, or copying `approve_governance_commit.ps1` into
  `reference-client` as a workaround. The audit already establishes the correct
  shape: `ai-control-plane` is the reusable core (adapters + profiles already
  split generic-vs-project), not a dependency to be decoupled from. If a
  public-release decision is made, revisit *this* file's Deferred section,
  not the architecture question.
- Do not assume `git status` showing a clean tree means nothing is pending —
  check this file and the audit doc first; a clean tree with `main` ahead of
  `origin/main` (see `git log`) may still mean unpushed work.

## Deferred

- Fix `test_dummy_client_attach.ps1`'s native-stderr-as-terminating-error
  fragility (see Known limitations above) — scoped, small, not urgent.
- Execute P6: a real second-client attach test against a non-Node repo on
  the standard Claude Code harness — **EXECUTED 2026-08-28, PASS** (candidate:
  polymarket-clv-tracker, Python/pytest). Record:
  `docs/validation/second-client-attach-test-2026-08-28.md`. Reusability gate
  met; residual = full live skill-session depth (PARTIAL case per plan).
- If/when `reference-client` is actually decided to go public (not yet decided
  as of 2026-07-23): revisit whether `ai-control-plane` itself should also
  be published, and re-check for any remaining personal-identity residue
  across both repos before that decision is executed — do not assume the
  2026-07-14 audit's boundary findings (table 3, B1-B10) are still current
  without a fresh grep-based spot-check first.

## Meta note (why this file exists)

Added 2026-07-23 after a repeated pattern was observed across sessions and
across repos (`reference-client` and this one): real, verified engineering work
gets done, then sits uncommitted or unrecorded, and a later session
re-discovers the same "problem" from scratch — wasting time and tokens on
work that was already solved. This file is the fix: read it first, trust it
until contradicted by fresh evidence, and update it before closing any
session that changes what's completed, known-limited, or deferred here.
