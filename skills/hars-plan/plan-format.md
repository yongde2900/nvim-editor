# PLAN file format (normative)

The plan file is the only thing the hars skills share. It is written by the Planner, stamped by
`hars-plan`, mutated by `hars-execute`, closed by `hars-verify`, changed by `hars-revise`, and
read by `hars-status` — across separate sessions with no shared memory. So its schema, its state
machine, and its field ownership are defined **here, once**. Every skill links to this file
rather than restating it; if you change the format, change it here and check all six still agree.

| Skill | Relationship to this file |
|---|---|
| `hars-plan` | Creates it (via the Planner) and stamps `draft` → `approved` |
| `hars-execute` | Drives the task state machine and the Iteration Log |
| `hars-verify` | Runs the integration gate; the only skill that writes plan `done` |
| `hars-revise` | Changes an already-approved file, by rollback / amend / fork |
| `hars-status` | Reads it. Never writes, under any circumstance |
| `hars-grade` | Ignores it entirely — a grade is never a state transition |

---

## 1. File skeleton

```markdown
# PLAN-NNN — <brief>
Created: <YYYY-MM-DD>
Status: draft
Working Directory: <relative path>
BDD Spec: <working_dir>/bdd/BDD-NNN-<slug>.feature
Language: <stack>
Build cmd: <e.g. go build ./...>
Test cmd:  <e.g. go test -race ./<dir>/...>
Lint cmd:  <e.g. go vet ./<dir>/...>
Pass threshold: 7.0
Max iterations: 5
Superseded by: <optional — PLAN-MMM, written by hars-revise when forking>

## Known Context
<!-- Self-contained prose. Prior decisions with their WHY, architecture/interfaces already in
     place, gotchas to avoid. Cite [[slug]] alongside the prose for traceability, never instead
     of it. Write "none" if there is no knowledge base. -->
- <decision / constraint stated in full> — why: <reason> — source: [[slug]]

### Out of Scope & Ungraded Constraints
<!-- What was deliberately NOT built this round, plus any acceptance criterion that did not
     become a BDD scenario (and is therefore checked by a human, never by the harness).
     Required section: write "none" rather than omitting it. Full sentences — an Executor
     reads a missing capability as an oversight unless this says otherwise. -->
- <not built / not graded, stated in full> — why: <reason>

## Project Conventions
<!-- Error-handling style, state and cancellation model, naming, layout. Copied here verbatim
     because the Executor is prompted from this file. -->

## Overview
<one paragraph describing what will be built overall>

## Sub-Tasks
<!-- listed in dependency order: a task never precedes something it depends on -->

### Task 1: <name>
Status: pending
Directory: <relative path>
Depends on: <none | earlier Task numbers whose interfaces this task uses>
Provides (public interface): <exported types / function signatures other tasks may rely on>
Verify cmd: <optional — non-code tasks only; the command that checks the artifact>
Pass threshold: <optional — overrides the header default for this task only>
Expected Goals (from BDD scenarios):
- [ ] Scenario: <scenario name>
- [ ] Scenario: <scenario name>

## Coverage Check
<!-- REQUIRED: one row per BDD scenario, in spec order. Each scenario maps to exactly ONE task. -->
- Scenario: <scenario name> → Task N

## Integration Scenarios
<!-- Scenarios that only hold once multiple tasks are assembled (end-to-end / spanning layers).
     Each is still counted exactly once in Coverage Check above; re-verified as a whole at the
     end of execution. -->
- Scenario: <name>

## Iteration Log
<!-- updated by hars-execute after each Evaluate cycle -->

## Amendments
<!-- Created by hars-revise on its first in-place amendment; append-only, newest last.
     Absent from a fresh plan. Each entry: date, field, was/now, why, who approved. -->
```

---

## 2. Header fields

| Field | Written by | Notes |
|-------|-----------|-------|
| `Status` | Planner (`draft`) → hars-plan (`approved`) → hars-execute (`in-progress` / `done` / `stalled`) | See §3 |
| `Working Directory` | Planner | Absolute. All other paths are relative to it. |
| `BDD Spec` | Planner | Must itself carry `# Status: approved` before execution starts. |
| `Build cmd` / `Test cmd` / `Lint cmd` | Planner (from hars-plan Phase 0) | Concrete commands, never placeholders. This is what keeps hars language-agnostic. |
| `Pass threshold` | Planner | Weighted Evaluator score a task must reach. Default `7.0`. Raise it for a task where a subtle defect is expensive; lowering it below 7.0 needs a reason stated in the Overview. Not amendable mid-run — see §4. |
| `Max iterations` | Planner | Executor↔Evaluator cycles on one task before it goes `stalled`. Default `5`. Not amendable mid-run. |
| `Superseded by` | `hars-revise` | Present only on a forked-away plan, alongside `Status: superseded`. Names the plan that replaced it. |

`Pass threshold` and `Max iterations` are part of what the human approves at Gate 2 — they set
how hard the quality gate actually is, so they are presented alongside the task list, not
buried. `hars-execute` reads them from the file; it never carries its own defaults. If either
field is missing from an older plan, treat it as `7.0` / `5` and say so in the run report.

---

## 3. State machines

Both are **flat and total** — every value below is one that some step writes and some step
reads. Do not invent others: `hars-execute`'s task selection matches on these exact strings,
and a status it does not recognise silently drops the task out of every branch.

### Plan `Status`

```
draft ──(human approves at hars-plan Gate 2)──▶ approved
approved ──(hars-execute starts the first task)──▶ in-progress
in-progress ──(hars-verify: whole build + every Integration Scenario green)──▶ done
in-progress ──(any task hits Max iterations)──▶ stalled
stalled ──(hars-revise: unstall with a real change)──▶ in-progress
approved|in-progress|stalled ──(hars-revise: rollback, nothing executed yet)──▶ draft
approved|in-progress|stalled ──(hars-revise: forked to PLAN-MMM)──▶ superseded
```

- `draft` — the only state in which `hars-plan` may edit the file. `hars-execute` refuses to run it.
- `approved` — the human consent stamp. This single field is what licenses unattended execution.
- `in-progress` — execution has begun; `hars-plan` must treat the file as read-only from here.
- `done` — terminal. Only `hars-verify` writes it, and only from a completion run in which every
  task was `done` and every Integration Scenario was driven end-to-end. Per-task passes alone
  never justify it.
- `stalled` — a task exhausted `Max iterations`. Written together with that task's own `stalled`,
  so the next invocation stops at the approval check instead of re-deriving the blockage.
- `superseded` — terminal. The plan was forked away from; `Superseded by:` names its replacement.
  Treated like `done` by execution (nothing to run) without claiming the work finished.

### Task `Status`

```
pending ──(selected, before spawning the Executor)──▶ in-progress
in-progress ──(Evaluator PASSED: true AND lint+tests green)──▶ done
in-progress ──(Max iterations reached without a pass)──▶ stalled
```

- `pending` — initial value written by the Planner. Runnable only once every task in its
  `Depends on` is `done`.
- `in-progress` — also the crash-recovery marker: a task left here means a previous run died
  mid-task and the next invocation resumes it.
- `done` — terminal. Never reopened to look for work. The single exception is `hars-verify` in a
  completion run, which sets a task back to `in-progress` when an integration failure traces to
  its scope — and only with that failure recorded in the Iteration Log.
- `stalled` — terminal until a human intervenes. Setting it also sets the **plan** header to
  `stalled`, so a later invocation stops at E0b instead of re-deriving the blockage per task.

There is deliberately **no `failed` status.** A task that fails an Evaluate cycle stays
`in-progress` and its failure is recorded in the Iteration Log; it becomes `stalled` only on
exhausting `Max iterations`. A separate `failed` value would match no branch in task selection
and strand the plan.

---

## 4. Field ownership

The plan is shared mutable state. Ownership is what keeps the two skills from overwriting each
other, and what keeps execution honest about implementing the thing that was actually approved.

| Section / field | Owner | Everyone else |
|---|---|---|
| Everything, while `Status: draft` | `hars-plan` | — |
| Plan `Status`: `draft` → `approved` | `hars-plan` (Phase 3, only after Gate 2) | **nobody else, ever** |
| Plan `Status`: `approved` → `in-progress` | `hars-execute` | read-only |
| Plan `Status`: → `done` | `hars-verify` (completion run only) | read-only |
| Plan `Status`: → `stalled` | `hars-execute` (with the task it stalled on) | read-only |
| Plan `Status`: → `draft` / `superseded`, and `Superseded by` | `hars-revise` | read-only |
| Task `Status`, Expected Goals checkboxes, `## Iteration Log` | `hars-execute` | `hars-verify` may reopen a `done` task on integration failure; `hars-revise` may reset a `stalled` task to `pending` |
| `## Amendments` | `hars-revise` (append-only) | read-only |
| Header toolchain, thresholds, `## Known Context`, `## Project Conventions`, task scopes, `Depends on`, `Provides`, `## Coverage Check`, `## Integration Scenarios` | `hars-plan` (draft only), or `hars-revise` under its amendment rules | **read-only to `hars-execute` and `hars-verify`, always** |

If `hars-execute` or `hars-verify` finds one of the approved fields wrong, that is a `BLOCKED`
report, not a fix. Editing it would mean executing something the human never signed off on.

Two invariants hold across every skill:

- **Only `hars-plan` writes `approved`.** Consent has exactly one source. `hars-revise` can
  reopen a plan to `draft` or fork it, but it hands the re-approval back rather than granting it.
- **Only `hars-verify` writes `done`.** Finishing every task is not finishing the plan; the
  integration gate is what separates those two claims.

Once a plan leaves `draft`, `hars-plan` must not rewrite it — the task statuses and Iteration Log
are the only record that work happened, and they live nowhere else. Changing a non-draft plan is
`hars-revise`'s job, and it has one route per situation.
