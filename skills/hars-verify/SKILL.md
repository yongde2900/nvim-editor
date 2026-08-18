---
name: hars-verify
description: Harness-Driven Development, whole-system integration gate. Builds the entire project, runs the full test suite, and drives every Integration Scenario end-to-end against the assembled system — then, only when all sub-tasks are done and everything is green, stamps the plan done and saves durable takeaways to the knowledge base. Use when the user says "hars verify", "hars 整合驗證", "重跑 PLAN-003 的整合測試", asks whether a finished plan still holds after a refactor or a dependency bump, or when hars-execute reaches the end of its task list. Do NOT use it to implement sub-tasks (that is hars-execute) or to grade one sub-task in isolation (that is hars-grade).
---

# Hars — Verify (Whole-System Integration Gate)

Per-task Evaluators judge tasks in isolation. Cross-cutting behavior stays unverified until the
pieces are assembled — so a plan whose every task passed is not a plan that works. This skill is
the gate between those two claims, and it is the only skill that may mark a plan `done`.

**Role split:** you do this yourself. No subagents — the evidence has to be terminal output you
ran, not a report you were handed.

## Trigger

User says: "hars verify", "hars 整合驗證", "重跑整合", "PLAN-003 還過嗎", or `hars-execute` has
finished its last task and needs the gate before declaring the plan done.

If tasks remain unimplemented, that is `hars-execute` — say so and stop; do not implement the
missing pieces to make verification pass.

## Two modes, decided by the plan — not by the user

Read the plan first, then pick. The mode is a fact about the file's state, so a user asking to
"just re-check it" cannot accidentally get a completion stamp.

| Plan state | Mode | What it may write |
|---|---|---|
| `in-progress` (or `approved`) and **every task `done`** | **Completion run** | On green: plan → `done`, then persist knowledge (§V4). On failure: reopen the task at fault. |
| `done` — re-checking after a refactor, upgrade, or merge | **Spot check** | Nothing. Report only. |
| Any task not `done` | **Spot check**, and say why | Nothing. Report `status=INCOMPLETE` and name the outstanding tasks. |
| `draft` | ⛔ STOP | Nothing. An unapproved plan is not verifiable — route to `hars-plan`. |
| `stalled` | ⛔ STOP | Nothing. Report the blocker; route to `hars-revise`. |

A spot check that goes green changes nothing on disk, and that is correct: the plan was already
`done`, and re-passing a gate is not new information worth rewriting state for.

## Workflow

```
Invocation
  → V0  Locate + validate the plan, pick the mode
  → V1  Build the WHOLE project · run the FULL test suite
  → V2  Drive every Integration Scenario end-to-end against the assembled system
  → V3  Failures → attribute to a task, reopen it (completion mode) or report (spot check)
  → V4  All green + completion mode → stamp done → persist knowledge
```

### V0 — Locate & validate

```bash
ls <working_dir>/plan/PLAN-*.md 2>/dev/null
```

Same selection rule as `hars-execute`: the plan the user named; else the single candidate; else
`in-progress` over `approved`, lowest NNN among equals. Read the plan and the BDD spec it names.
Confirm the BDD header says `# Status: approved`. Take the **Build cmd** and **Test cmd** from
the plan header — the plan's commands, never ones you infer from the repo.

### V1 — Build and test the whole project

Run the header's **Build cmd** and the **full Test cmd across the entire project** — not scoped
to any task directory. Both must pass.

Scoping matters more than it looks. Every per-task run in `hars-execute` was deliberately scoped
to one directory, so a break that only shows up when the packages are compiled together has
never been exercised until this moment.

Keep the raw output. It is the evidence for the report, and for the reopened task if V3 fires.

### V2 — Drive every Integration Scenario

For each scenario under the plan's `## Integration Scenarios`, run the **assembled system** —
the built artifact, the top-level entrypoint, the real CLI or server — and confirm the `Then`
holds against what actually came back.

> ⛔ **Reading the code is not verification.** Neither is a passing unit test that mocks the
> boundary the scenario exists to check. Drive it, and show the command and its output.

An integration scenario is precisely the claim that no single task could establish on its own,
so the only thing that settles it is the assembled artifact. If a scenario genuinely cannot be
driven (needs credentials, a device, a third-party sandbox), report it as `unverified` with the
reason — never as passed, and never quietly dropped from the count.

### V3 — Failure handling

Attribute each failure to the task whose scope owns it — by the `Directory` and
`Provides (public interface)` in the plan, not by which file the stack trace ends in.

| Mode | On failure |
|---|---|
| Completion run | Set that task back to `Status: in-progress`, append an Iteration Log entry recording the integration failure, and report `status=REOPENED` naming the task. `hars-execute` picks it up from there and this phase runs again afterwards. **Do not implement the fix here.** |
| Spot check | Change nothing. Report `status=FAIL` with the failing scenario and the raw output, and let the user decide whether it warrants `hars-revise`, a new plan, or a plain bugfix. |

If a failure traces to no task in the plan — it is in code the plan never touched — say that
explicitly. It is a regression from elsewhere, and reopening an innocent task to chase it wastes
a full Executor cycle and muddies that task's history.

Reopening is the one exception to `done` being terminal
([../hars-plan/plan-format.md](../hars-plan/plan-format.md) §3), and it is allowed only here,
only in completion mode, and only with the failure recorded in the Iteration Log.

### V4 — Stamp and persist (completion mode only)

Only when the whole build is green, the full suite passes, and **every** Integration Scenario
has been driven and holds:

1. Set the plan header `Status: done`.
2. Persist what the run taught, via the **save-to-knowledge-base** skill. This is the write half
   of the loop whose read half is `hars-plan`'s Phase 0 — that write-then-read across separate
   runs is how the two halves of hars share what they learn.

   Record what nobody could have known in advance:
   - **Decisions actually made during implementation**, with their *why*.
   - **Interfaces that ended up exported** — the real signatures, which are what the next plan builds against.
   - **Gotchas an Executor hit that weren't in the plan.** These are the ones that cost iterations; writing them down is what stops the next run paying the same cost.
   - **Any conflict found between an existing knowledge entry and the approved plan.** One of the two is stale, and leaving it unresolved means the next `hars-plan` run inherits the bad version.

## Output

```
[hars] PLAN-NNN  verify  mode=completion|spot-check
  build=PASS|FAIL   suite=PASS|FAIL
  integration=K/K   (unverified: <names, if any>)
  → status=DONE|REOPENED|FAIL|INCOMPLETE  — <one sentence>
```

On `DONE`, name the knowledge entries you wrote. On `REOPENED`, name the task and the failing
scenario. On `FAIL` or `INCOMPLETE`, give the user the next action — `hars run`, `hars-revise`,
or a plain fix — rather than leaving them to work it out from the raw output.
