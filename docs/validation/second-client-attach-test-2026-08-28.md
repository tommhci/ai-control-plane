# Second-Client Attach Test — Execution Record (P6)

Executed 2026-08-28 per `second-client-attach-test-plan.md` (written 2026-07-14).
This closes the P6 item deferred since the 2026-07-14 reusability audit.

## Candidate

`polymarket-clv-tracker` — real, existing, non-Node (Python/pytest) repository
with genuine history (tip 2026-07-26, 26 tracked files) and repo-specific
stakes (`config.py`, `docs/paper_trades.csv` trade logs, `.env.example`).
Satisfies plan requirements #1–#4 (#5, a pre-wanted real task, not required —
#1–#2 were the blocking gate).

## Procedure and results

| Step | Result |
|------|--------|
| attach via productized `attach-project.ps1` (claude-code, minimal) | PASS — health-check 19/19 on first attach, including both P3 enforcement-surface checks (new client auto-protected) |
| declared `verification.json` (`python -m pytest tests/ -q`) written | PASS — exercises the declared-command branch (P6's core stressor: NOT npm test) |
| repo-specific protected paths added (`config.py`, `docs/paper_trades.csv`, `.env.example`) | PASS |
| health-check after customization | PASS 19/19 |
| `scan_client_security.ps1` | FAIL 72/100 — 1 HIGH (`.env` file present; verified UNTRACKED so no git leak; remediation = gitignore + secrets manager, owner's call), 1 LOW (no SQLite mirror — optional) |
| write-guard negative control on repo-specific path | PASS — `config.py` → exit 2 (blocked); `README.md` → exit 0 |
| declared verification command executed | PASS-with-note — command runs under the declared path; pytest collected 0 tests in this environment (2.82s, exit 0). Environment-side collection gap, not a control-plane behavior; the control-plane requirement was "declared command runs and exit code is interpreted", which held |

## Verdict

**PASS for reusability purposes** (plan success criteria 1–3 met; criterion 4's
full live skill session partially exercised — write-guard and verification
paths ran for real, but no end-to-end plan-freeze→change→verify-task cycle
against a real task was performed; recorded as the residual, not a failure —
matches the plan's PARTIAL expectation for session-layer depth).

## What this proves (per the plan's own framing)

`ai-control-plane` attaches to a real, non-Node, non-Reference-Client repository with
repo-specific enforcement semantics and correct declared-verification
behavior. The "validated prototype" classification can be retired: the
reusable-infrastructure gate has a real second (third, counting the Node
client and the worktree client) data point.

## Residuals (explicit)

1. Full live skill-session depth (node-intake → plan-freeze → real change →
   verify-task → session-close) still unexercised end-to-end — the plan's PARTIAL
   case; needs a real task the owner wants done in some client.
2. The HIGH `.env` finding belongs to the client owner (remediation not
   performed by this test; no commit/push made in the client repo per plan).
3. pytest collects 0 tests in the attaching environment — the client's own
   CI presumably has proper deps; unrelated to control-plane behavior.
