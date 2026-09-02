# Failure Recovery Flow

Status: reusable control-plane policy.

Companion to `pre-task-decision-flow.md`. That protocol governs **before** a task
starts (is this authorized, what type, what runtime boundary). This protocol
governs **during** execution: when something fails or is missing, decide whether to
hard-stop, repair, skip, or continue — without asking the human for every small
recoverable issue, and without bypassing a real safety boundary.

The goal is autonomy that is safe by construction: continue through recoverable
noise, stop hard on invariant corruption.

## Unified Failure Decision Tree

Apply these checks in order. The first match wins.

1. **Ownership conflict?**
   Another active session or tool holds `ACTIVE_EDIT_OWNERSHIP.md` on a file you
   need, and the owner is not you.
   → **HARD STOP the whole session.** Do not bypass. Report the conflict.

2. **Does the failure corrupt a session-wide invariant?**
   Session-wide invariants:
   - git index is untrusted (partial/aborted operation, detached state)
   - the planned edit scope exceeds the frozen plan / authorized file list
   - skills-lock cannot validate after **one** repair attempt
   - schema validation cannot be restored after **one** repair attempt
   - an unauthorized `governance/` change appears outside the frozen plan
   - data-loss risk (overwrite, delete, force operation)
   - a multi-agent write conflict that cannot be safely serialized
   → **HARD STOP.** Write a `stop_event`, switch to STEP, surface one question.

3. **Can a minimal version solve it safely?**
   → **YES:** implement the minimal version and state `simplified: <reason>` in the
   commit body. Continue.
   → **NO:** go to step 4.

4. **Is this missing information?** (file not found, line not found, section not
   found, protocol location unclear)
   → Search **twice** with different patterns.
   → If still not found: mark the current task `[Gap/Unresolved: <reason>]`, record it
   in the handover, and continue to the next **independent** task. Do not stop the
   session for one missing string.

5. **Independent task blocked but session still safe?**
   → Mark the task `[SKIPPED: <reason>]` and continue to the next independent task.

## Do NOT stop merely because

These are recoverable noise, not hard stops:

- exact text / one section heading is missing or differs
- one skill has an unusual structure
- one hash calculation fails once (retry once first)
- one template section is missing
- a build has a known pre-existing failure unrelated to this change
- a smoke-test assertion is stale but the new behavior is intentional and verified
  by direct invocation

## Hard-stop list (the only reasons to stop a session)

1. Ownership conflict with another active session/tool.
2. Planned edit scope exceeds the frozen plan / authorized file list.
3. A commit was made but skills-lock cannot pass validation after one repair attempt.
4. Schema validation cannot pass after one repair attempt.
5. An unauthorized `governance/` change appears outside the frozen plan.
6. git / index / auth / permission blocks a safe commit.
7. Data-loss risk appears.
8. Product-code edits become necessary (when the session is not authorized for them).
9. A multi-agent write conflict cannot be safely resolved.

On any hard stop, write a `stop_event` (see `stop_event.schema.json`) with
`resolution: "fired_awaiting_user"` **before** emitting the banner:

```text
STOP [reason] | mode=[STEP|CONTINUOUS|AUDIT] | needs your decision: [one question]
```

## Relationship to Route-Based Continuous Execution

When an AI is operating under a route authorization (see
`route-based-continuous-execution.md`), this decision tree still applies in
full. The route does not loosen any hard-stop condition; it only defines the
scope within which the AI may continue without asking the user between tasks.

## Relationship to state-control fields

The decision tree maps onto the machine-readable recovery tuple
(`task_state`, `failure_class`, `reviewer_trigger`, `next_allowed_action`,
`disallowed_actions`) recorded in session/handover state:

| Tree outcome | failure_class | task_state |
|--------------|---------------|------------|
| Ownership conflict (step 1) | `OWNERSHIP_CONFLICT` | `HARD_STOP` |
| Invariant corruption (step 2) | `VALIDATION_FAILED` / `SCOPE_DRIFT` | `HARD_STOP` |
| Minimal version used (step 3) | `NONE` | `PARTIAL_SUCCESS` |
| Missing info after 2 searches (step 4) | `MISSING_INFO` | `SKIPPED` |
| Independent task blocked (step 5) | varies | `SKIPPED` |
