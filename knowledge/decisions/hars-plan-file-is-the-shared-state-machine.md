# The PLAN file is a shared state machine with one normative schema

After `hars` was split into `hars-plan` and `hars-execute`, the plan file stopped being one
skill's scratchpad and became the **only** interface between two skills that never share a
context. That changed what the file has to be: a state machine with legal values, defined
field ownership, and a single normative definition.

## The schema lives in one file

`skills/hars-plan/plan-format.md` is normative. `hars-plan/planner.md` hands the Planner agent
its absolute path instead of pasting a skeleton, and `hars-execute/SKILL.md` links to it for
the state machine and the ownership table.

**Why:** the split had left the format defined twice — the Planner's prompt template declared
it, the execution skill assumed it — with nothing keeping the two in sync. Two copies of a
schema drift, and the drift surfaces as an execution run that silently misreads a field.

## Task statuses are `pending | in-progress | done | stalled` — there is no `failed`

**Why:** the inherited Phase 5 template offered `Status: done ← or: failed`, but the task
selection logic only ever matched `pending`, `in-progress`, `done`, `stalled`. A task written
as `failed` fell through every branch — not runnable, not done, not a reported blocker — and
stranded the plan. A failed Evaluate cycle now leaves the task `in-progress` with the failure
in the Iteration Log, which is also exactly the marker a resumed run needs.

Selection now rejects any status outside the legal set as a corrupt plan (`status=BLOCKED`)
rather than guessing or silently repairing it.

## Stalling writes the plan header too

Marking only the task `stalled` left the plan header reading `in-progress`, so the next
invocation re-walked the whole selection tree to rediscover the same blockage — and an outer
polling loop saw a plan that still looked runnable. Both fields are now written together, so
`hars-execute`'s E0b approval check stops the run immediately.

## Pass threshold and max iterations moved into the plan header

`SCORE ≥ 7.0` and "5 iterations" used to be constants scattered across `evaluator.md` and the
execution playbook. They are now `Pass threshold:` and `Max iterations:` header fields, set by
the Planner (per-task override allowed), presented at Gate 2, and read by `hars-execute` —
which keeps no defaults of its own beyond a declared fallback for pre-existing plans.

**Why:** how strictly a plan is graded is a property of *that feature*, and it is part of what
the human approves — a parser or a migration deserves a higher bar than a config shim. Keeping
the numbers in the prompt made them invisible at the approval gate and unadjustable per plan.

Related: [[hars-two-approval-gates]], [[hars-evaluator-functionality-hard-gate]],
[[hars-bdd-single-source-of-truth]].
