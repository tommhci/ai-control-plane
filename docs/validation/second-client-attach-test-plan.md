# Second-Client Attach Test Plan

Status: plan only, not executed. Written 2026-07-14 as part of the reusability
audit's Phase 4 (validation expansion). No candidate repo was named at the
time of writing — this document defines the test; running it is a separate,
future action gated on picking a real repo.

## Goal

Prove generic-adapter reuse on a *real*, existing repository — not a dummy
fixture and not Reference-Client. This is the actual gate for calling
`ai-control-plane` "reusable infrastructure" rather than "validated
prototype" (see the audit's maturity classification).

## Why the dummy attach test doesn't already prove this

The 2026-07-14 dummy-client attach test (`toy-project-results.md`, reproduced
again this session) proves the generic adapter's *mechanical* attach path
works: files copy, hooks wire, skill sync runs, protected-path enforcement
fires. It does **not** prove the *skills* work under real session pressure,
because no real session ever ran against the dummy client — no node was
selected, no plan was frozen, no file was changed, no verification command
ran, no session was closed. Every one of `verify-task`, `publish-safe`,
`plan-freeze`, `node-intake`, `session-close` is exercised only by reading
its SKILL.md, never by executing its steps end-to-end. This test plan closes
that gap.

## Candidate repo requirements

In priority order — the more of these hold, the stronger the resulting
evidence:

1. **Not Reference-Client.** Obviously required.
2. **Non-Node, or at minimum non-`npm test`/`npm run build`.** This is the
   single most important stressor: `verify-task` and `publish-safe` were
   patched this session to read `.control-plane/verification.json` first,
   falling back to `npm test`/`npm run build` only if that file is absent.
   Attaching to another Node project would not exercise the fallback-vs-
   declared-command branch at all — the fallback would silently "work" by
   coincidence, not by design. A Python (`pytest`), PowerShell (custom test
   runner), Rust (`cargo test`), or Go (`go test`) repo forces the declared-
   command path to actually run.
3. **Has its own git history and is not a fresh scaffold.** A repo with real
   prior commits, and ideally a real (even if informal) sense of "what
   shouldn't be touched," exercises `plan-freeze`'s protected-path logic
   against genuine stakes, not an empty sandbox.
4. **Independent protected-paths semantics.** The client's own
   `.control-plane/protected-paths.json` should name at least one real file
   or directory that isn't `governance/` or `AGENTS.md` — something specific
   to that repo — so the test isn't just re-proving the Reference-Client convention
   works elsewhere.
5. **A real, even if small, task to perform.** Not "create an empty file" —
   an actual bug fix, doc correction, or small feature addition that the
   repo owner already wanted done. This is what "handoff pressure" in the
   original audit meant: a real task creates real time/correctness pressure
   that a synthetic task doesn't.

A repo satisfying only #1–#2 is still worth running; #3–#5 upgrade the
evidence quality but aren't blocking preconditions.

## Test procedure

### Setup

1. Copy `adapters/generic/adapter.json` into
   `<candidate-repo>/.control-plane/adapter.json`; fill in `controlPlaneRepo`
   and `adapterId`.
2. Create `<candidate-repo>/.control-plane/protected-paths.json` with at
   least one real path from that repo (not a copy-paste of Reference-Client's list).
3. Create `<candidate-repo>/.control-plane/verification.json` with the
   repo's **actual** test/build command — this must NOT be `npm test`.
4. Run `installers/install-claude-client.ps1` and
   `installers/sync-shared-skills.ps1` against the candidate repo.
5. Run `installers/health-check.ps1 -RepoRoot <candidate-repo>` — record
   pass/fail count.
6. Run `security/scan_client_security.ps1 -ClientRoot <candidate-repo>` —
   record score and findings.

### Live session

Run one real, complete session against the candidate repo:

```
node-intake → plan-freeze → [make the real small change] → verify-task → session-close
```

Record, for each step:

- Did the skill correctly read `.control-plane/verification.json` and
  `.control-plane/protected-paths.json`, or did it fall back to a Node/
  Reference-Client assumption?
- Did any step require guessing, or produce output that only made sense
  with Reference-Client context?
- Did any stop condition fire that shouldn't have, or fail to fire when it
  should have?
- What would a first-time user of this control plane not have known to do?

Use the `HUMAN_FILL_IN_TEMPLATE.md`-style structure from the original
validation packet for recording this: expected / actual / result
(PASS/FAIL/BLOCKED) / notes, per step.

### Teardown

- Confirm no unintended files were committed or pushed (this test plan does
  not authorize commit/push in the candidate repo — that decision belongs to
  whoever owns it).
- Record whether the candidate repo's owner would want the attach files kept
  or removed.

## Success criteria

The test is a **PASS** for reusability purposes only if all of the following
hold:

1. Attach mechanics succeed (health-check all-pass, or every failure is
   explained and non-blocking).
2. `verify-task` and `publish-safe` run the client's declared
   `verificationCommand`, not a Node fallback, and that command's exit code
   is correctly interpreted.
3. `plan-freeze`'s protected-path stop condition fires correctly against
   the client's own `protected-paths.json` entries, not Reference-Client's.
4. The live session completes end-to-end (node-intake → plan-freeze → change
   → verify-task → session-close) without a skill producing output that only
   makes sense with Reference-Client-specific context (a Reference-Client file name, a Reference-Client
   governance concept the client doesn't have, etc.).
5. Every ambiguity or guess required during the session is recorded, not
   silently absorbed.

A **PARTIAL** result — attach mechanics work but the live session surfaces
Reference-Client-shaped assumptions in `node-intake` or `session-close` — is expected
and useful; it does not invalidate the control plane, it identifies exactly
what the deferred "deep session-close/node-intake refactor" (see the
2026-07-14 audit's do-now/August split) needs to fix. Record it as evidence,
not as a failed test.

A **FAIL** — attach mechanics themselves break, or `verify-task`/
`publish-safe` silently run the wrong command without reporting it as a
fallback — means the WP2 parameterization patch has a bug and needs to be
fixed before any reusability claim is made.

## What this test does not prove

- Multi-model reliability (Codex, Cursor, cheaper models executing the same
  skills) — a separate, larger validation effort (see the original audit's
  Gap 5 / EVIDENCE_GAPS.md).
- External adoption by anyone other than the repo owner.
- Long-term maintainability under repeated real sessions (one session is one
  data point, not a trend).

## Status

Not yet executed. Owner must supply a candidate repo before this plan can be
run.
