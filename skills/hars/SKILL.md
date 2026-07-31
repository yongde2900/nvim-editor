# Hars — Harness-Driven Development

**Role split (critical):**
- **You = Coordinator** — retrieve relevant prior knowledge, clarify requirements with the user, fix the project toolchain, author the BDD spec, orchestrate agents, manage plan state, communicate with user
- **Planner (opus 4.8)** — map the approved BDD scenarios into dependency-ordered sub-tasks with interface contracts, and write the plan file
- **Executor (sonnet)** — implement each sub-task: Red → Green → Refactor → Regulate
- **Evaluator (sonnet)** — fresh context, reads the code from disk, reviews quality, and confirms the executed tests genuinely cover each BDD scenario

## Trigger

User says: "use harness", "hars mode", "harness workflow", or wants thorough quality-gated implementation.

## Workflow

```
Prompt
  → Phase 0  Coordinator retrieves relevant knowledge (./knowledge/) + clarifies requirements WITH the user + fixes the project's language / build / test / lint commands
  → Phase 1  Coordinator writes BDD-NNN.feature (Gherkin), self-checks scenario quality → present → wait for approval
  → Phase 2  spawn Planner → PLAN-NNN.md (scenarios → Expected Goals; tasks dependency-ordered, each with an interface contract) → present → wait for approval
  → Phase 3–5  for each sub-task in dependency order:
       • Code task:         spawn Executor (Red→Green→Refactor→Regulate) → spawn Evaluator → iterate to pass
       • Non-code artifact: spawn Executor (implement artifact) → spawn Evaluator → iterate to pass
  → Phase 6  Integrate & verify the assembled system end-to-end → then mark the plan done
```

⛔ **TWO mandatory human approval gates — Phase 1 (BDD) and Phase 2 (plan).** Each is a hard STOP: end your turn and wait for the user's word. Neither can be inferred, batched into the other, or skipped under time pressure. **Approving the BDD is NOT approving the plan** — the second gate is exactly as binding as the first.

---

## Phase 0 — Retrieve Knowledge, Clarify Requirements & Fix Toolchain (Coordinator, no subagent)

You (the Coordinator) talk to the user directly — do NOT spawn an agent for this.

### 0a — Retrieve prior knowledge (before asking anything)

If a knowledge base exists, mine it first so you don't re-litigate settled decisions or contradict known architecture/conventions:

```bash
cat ./knowledge/index.md 2>/dev/null
```

- If there is no `./knowledge/index.md`, skip this step — nothing to retrieve — and move on.
- Otherwise scan the index and open the entries relevant to this task — especially `decisions/`, `architecture/`, `conventions/`, and any `bugs`/gotchas touching the same area. Follow `[[slug]]` links between entries.
- Distill what you find into a short **Known Context** digest: relevant prior decisions (with their *why*), architecture/interfaces already in place, conventions to follow, and gotchas to avoid.

Carry this digest forward: it shapes your clarifying questions (confirm what the base already says — don't re-ask it), the BDD spec, the Planner prompt, and each Executor's Project Conventions. Record the entries you used in the plan's `## Known Context` section (Phase 2) so downstream agents and any future resume inherit them.

### 0b — Clarify & fix toolchain

Ask focused questions until you can describe the desired behavior concretely. Cover at least:
- **Actors & goal** — who uses this, what outcome do they want?
- **Happy path** — the main success flow, step by step.
- **Edge cases & errors** — empty input, invalid input, concurrency, failure modes.
- **Acceptance** — how will the user know it's correct? What's explicitly out of scope?

Stop asking once you have enough to write concrete Given/When/Then scenarios. Don't over-interrogate — if a default is obvious, state it and move on.

Also fix the project's **toolchain** now — you'll store these in the plan header and reuse them verbatim in every Executor, Evaluator, and verification step (this is what keeps hars language-agnostic):
- **Language / stack** — detect from the working dir if code already exists; otherwise ask.
- **Build / Test / Lint commands** — the exact commands for THIS project. Examples:
  - Go:      `go build ./...`  /  `go test -race ./<dir>/...`  /  `go vet ./<dir>/...`
  - Python:  `python -m compileall <dir>`  /  `pytest <dir>`  /  `ruff check <dir>`
  - TS/Node: `tsc -b`  /  `vitest run <dir>`  /  `eslint <dir>`
- **Project conventions** — error-handling style, state/cancellation model, etc. (pulled from the codebase, not hard-coded).

---

## Phase 1 — BDD Spec (Coordinator writes Gherkin, no subagent)

### 1a — Determine ID

Run once; the same NNN is reused for both the BDD and the plan file. Use the highest existing number + 1 (not a raw count — deletions leave gaps):
```bash
ls <working_dir>/plan/PLAN-*.md <working_dir>/bdd/BDD-*.feature 2>/dev/null \
  | grep -oE '(PLAN|BDD)-[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1
```
Next ID = that + 1, zero-padded to 3 digits (e.g. `003`). If nothing matches, start at `001`.

### 1b — Write the BDD file

Write `<working_dir>/bdd/BDD-NNN-<slug>.feature` using standard Gherkin. Each scenario must be a **measurable, testable behavior** — these scenarios become the Evaluator's grading standard, so avoid vague outcomes.

```gherkin
# BDD-NNN — <brief>
# Created: <YYYY-MM-DD>
# Status: draft
# Working Directory: <abs path>

Feature: <feature name>
  As a <role>
  I want <capability>
  So that <benefit>

  Scenario: <happy-path name>
    Given <precondition>
    When <action>
    Then <observable, checkable outcome>

  Scenario: <edge case>
    Given <precondition>
    When <action>
    Then <observable, checkable outcome>

  # add one Scenario per distinct behavior — happy paths, edges, and error paths
```

### 1b-check — Scenario quality gate (self-check before presenting)

These scenarios become the Executor's tests and the Evaluator's grading standard — garbage in, garbage out. Before presenting, verify EVERY scenario:
- [ ] Has all three of Given / When / Then.
- [ ] The **Then is observable and checkable** — a concrete outcome you could assert in a test (exit code, printed text, a count, a specific error message). Reject vague outcomes like "works correctly", "is fast", "handles it gracefully".
- [ ] Is independently testable — it does not rely on another scenario having run first.
- [ ] Covers a single distinct behavior — split any scenario that has multiple When/Then pairs.

Rewrite any scenario that fails a checkbox until it passes. Only then present it.

### 1c — User Confirmation (MANDATORY)

Present the scenarios and wait:

```
[hars] BDD-NNN ready for review.

Feature: <feature name>
Scenarios:
  1. <scenario name>
  2. <scenario name>
  ...

Reply "通過" / "go" / "ok" to lock the spec and start planning, or tell me what to change.
```

⛔ **Do NOT start Phase 2 until the user approves the BDD.** If the user requests changes, edit the `.feature` file and re-present. When approved, set the header `# Status: approved`.

---

## Phase 2 — Plan (spawn Planner, model=opus)

Spawn an `Agent` with `model: "opus"`. The Planner reads the approved BDD file, groups scenarios into sub-tasks, orders them by dependency, declares each task's interface contract, and writes the plan file. **Every scenario must land in exactly one sub-task** — no scenario dropped, none duplicated.

Planner prompt template:
```
You are a senior software architect. Map an approved BDD spec into dependency-ordered sub-tasks and write a plan file.

## BDD Spec (source of truth)
<paste the full contents of BDD-NNN-<slug>.feature>

## Known Context (from the knowledge base — reuse, don't contradict)
<paste the Phase 0 Known Context digest: prior decisions + why, existing architecture/interfaces, conventions, gotchas. Write "none" if there is no knowledge base.>

## Toolchain
Language: <stack>   Build: <build cmd>   Test: <test cmd>   Lint: <lint cmd>

## Working Directory
<abs path>

## Plan File Path
<working_dir>/plan/PLAN-NNN-<slug>.md

## Instructions

1. Group the BDD scenarios into sub-tasks. Each sub-task must have:
   - A clear, narrow scope (ideally one file or one feature boundary)
   - Expected Goals = the exact BDD scenarios it must satisfy, referenced by scenario name.
     Every scenario in the spec must be covered by exactly one sub-task.
   - **Depends on** — which earlier tasks' interfaces it uses (a real decomposition is rarely fully independent; be honest about coupling).
   - **Provides (public interface)** — the exported types / function signatures it exposes for dependents.
   Reuse the architecture and interfaces named in **Known Context** instead of inventing parallel ones; if a task must contradict a recorded decision, flag it explicitly in the Overview.
   Order the tasks topologically: every task appears AFTER the tasks it depends on.
   Also mark **Integration Scenarios**: any scenario that only truly holds once several tasks are assembled (typically the end-to-end happy path). It still belongs to exactly one task in Coverage Check, but ALSO list it under `## Integration Scenarios` for whole-system re-verification in Phase 6.

2. Write the plan file at the given path using this structure:

---
# PLAN-NNN — <brief>
Created: <YYYY-MM-DD>
Status: in-progress
Working Directory: <abs path>
BDD Spec: <working_dir>/bdd/BDD-NNN-<slug>.feature
Language: <stack>
Build cmd: <e.g. go build ./...>
Test cmd:  <e.g. go test -race ./<dir>/...>
Lint cmd:  <e.g. go vet ./<dir>/...>

## Known Context
<!-- knowledge-base entries this plan builds on; "none" if there is no knowledge base -->
- [[slug]] — <what it constrains or informs here>

## Overview
<one paragraph describing what will be built overall>

## Sub-Tasks
<!-- listed in dependency order: a task never precedes something it depends on -->

### Task 1: <name>
Status: pending
Directory: <relative path>
Depends on: <none | earlier Task numbers whose interfaces this task uses>
Provides (public interface): <exported types / function signatures other tasks may rely on>
Expected Goals (from BDD scenarios):
- [ ] Scenario: <scenario name>
- [ ] Scenario: <scenario name>

### Task 2: <name>
Status: pending
Directory: <relative path>
Depends on: <none | earlier Task numbers>
Provides (public interface): <...>
Expected Goals (from BDD scenarios):
- [ ] Scenario: <scenario name>

<!-- add more tasks as needed -->

## Coverage Check
<!-- REQUIRED: one row per BDD scenario, in spec order. Each scenario maps to exactly ONE task. -->
- Scenario: <scenario name> → Task N
- Scenario: <scenario name> → Task N

## Integration Scenarios
<!-- Scenarios that only hold once multiple tasks are assembled (end-to-end / spanning layers).
     Each is still counted exactly once in Coverage Check above; re-verified as a whole in Phase 6. -->
- Scenario: <name>

## Iteration Log
<!-- updated after each Evaluate cycle -->
---

3. Self-check coverage before returning — this is REQUIRED, not optional:
   - List every `Scenario:` name from the BDD spec above, in order.
   - Map each to the single sub-task that covers it, and fill in the `## Coverage Check` section.
   - Then audit that filled section: the number of Coverage Check rows MUST equal the number of scenarios in the spec, every scenario name appears exactly once, and no scenario is missing.
   - A scenario that appears in two tasks (duplicate) or in zero tasks (dropped) is a FAILURE — regroup the sub-tasks and redo the check until coverage is exactly-once.
   - Also confirm the task order is a valid topological order (no task depends on a later one).
   Do not return until both checks pass.

4. Return the plan file path and a numbered list of sub-tasks (in dependency order) showing each task's Depends-on and which scenarios it covers, plus one line confirming: "Coverage: N scenarios, each mapped to exactly one task."
```

### 2c — User Confirmation (MANDATORY)

After the Planner returns, read the plan file and present it:

```
[hars] PLAN-NNN ready for review.

Sub-tasks (dependency order):
  1. <Task 1 name>  (depends on: <none|tasks>) — covers scenarios: <names>
  2. <Task 2 name>  (depends on: <none|tasks>) — covers scenarios: <names>
  ...
Integration scenarios (re-checked whole in Phase 6): <names>

Reply "go", "ok", or "proceed" to start execution, or revise the plan first.
```

⛔ **GATE 2 of 2 — Do NOT start Phase 3 until the user confirms the plan.** This is a hard STOP, exactly as binding as the BDD gate. End your turn and wait for the user's word.

> - Do NOT infer plan approval from an earlier "go" on the BDD — **approving the spec is not approving the plan.**
> - Do NOT treat the deadline, "move fast", or "don't babysit this" as consent to skip.
> - Do NOT spawn the Executor to "get a head start" while waiting.
> - A user reply that only changes the plan is NOT approval — revise and re-present.

If the user requests changes, update the plan file (or re-spawn the Planner) and re-present.

---

## Phase 3 — Execute (spawn Executor per sub-task, model=sonnet)

For each sub-task **in the plan's dependency order**:
1. Mark `Status: in-progress` in the plan file.
2. Spawn an `Agent` with `model: "sonnet"` using the Executor prompt below.

Executor prompt template:
```
You are a senior software engineer implementing a specific sub-task using TDD.

## Sub-Task: <Task N name>
Directory: <relative path>

## BDD Scenarios this task must satisfy
<paste the Given/When/Then blocks for this task's scenarios from BDD-NNN-<slug>.feature>

## Available Interfaces (from completed dependencies)
<paste the `Provides (public interface)` of each task this one Depends on, so you build against real signatures, not guesses. Write "none" if this task has no dependencies.>

## Working Directory
<abs path>

## Toolchain
Test: <test cmd>   Lint: <lint cmd>

## Project Conventions & Known Gotchas (from Phase 0 knowledge base / the codebase — not hard-coded)
<paste this project's conventions (error-handling style, state model, cancellation, etc.) plus any relevant gotchas from the Known Context digest.>

## Instructions

### For code tasks — follow Red → Green → Refactor → Regulate:

**Red:** Write all tests first, one per BDD scenario above (Given=setup, When=action, Then=assertion).
Tests must reference types and functions that do not exist yet.
Run the Test cmd scoped to this task's directory.
Tests MUST fail here (compilation error is fine). If they pass, rewrite them to exercise missing code.

**Green:** Write the minimum implementation to make all tests pass.
Run the Test cmd again. All tests must pass before continuing.

**Refactor:** Clean up naming, eliminate duplication, harden edge cases. Run tests again — must still pass.

**Regulate:** Final gate — run the Lint cmd and the Test cmd for this task's directory.
Both must pass. If not, return to Green.

### For non-code artifacts (SQL migrations, YAML fixtures, proto definitions, config):
Implement the artifact directly. No test phases.

Return: a summary of what was implemented and the **list of file paths** created or modified — NOT their full contents (the Coordinator and Evaluator read them from disk).
```

After the Executor returns, verify from disk by running the project's **Lint cmd** and **Test cmd** for this task's directory (from the plan header). Keep the raw test output — the Evaluator needs it.
If this fails, re-spawn the Executor with the failure output as additional context.

---

## Phase 4 — Evaluate (spawn Evaluator per sub-task, model=sonnet)

> ⛔ **MANDATORY CHECKPOINT — no skipping, no batching multiple tasks together**
>
> Before spawning the Evaluator, confirm ALL of the following:
> 1. The project's **Build cmd** passes — OR the task is a non-code artifact.
>    **Both cases still require Evaluate.**
> 2. Tests pass — OR the task has no tests because it is a non-code artifact.
>    **No tests does NOT mean skip Evaluate.**
> 3. Evaluating **this task only** — do NOT bundle goals from other tasks.
> 4. MUST wait for the Evaluator result and confirm `PASSED: true` before starting the next task.
>
> ❌ Violations:
> - Combining multiple tasks into one Evaluator prompt
> - Skipping Evaluate and moving directly to the next task
> - Self-judging that a task "should pass" and omitting the Evaluator
>
> A violation means the results are untrusted — re-evaluate from the violated task.


Evaluator prompt template:
```
You are a rigorous code reviewer. You have no context about how this code was written.

## Sub-Task: <Task N name>
Directory: <relative path>

## BDD Scenarios (grading standard)
<paste the Given/When/Then blocks for this task's scenarios from BDD-NNN-<slug>.feature>

## Test Results (already executed in Phase 3 — the source of truth for functionality)
<paste the raw output of the project's Test cmd for this task>

## Instructions
Read the task's source and test files yourself from the Directory above — do not expect them pasted.

Grade four criteria 0–10:
- functionality (50%, HARD GATE): Do the executed tests above pass, AND do the tests genuinely exercise each BDD scenario's Given/When/Then (not trivially or tautologically)? Mark each scenario met/unmet. A scenario is `unmet` if no test truly checks it — even when the suite is green.
- craft         (25%): Error handling, edge cases, correctness under the scenarios' conditions.
- clarity       (15%): Naming, structure, readability.
- fit           (10%): Builds on the dependencies' real interfaces; no needless divergence from project conventions.

Compute the weighted average. Do NOT reject correct, all-scenarios-met code for being "plain" or "boilerplate" — plain code that meets every scenario is good. Style concerns are `warning`s, not blockers, unless they break a scenario.

SCORE: <0-10>
PASSED: <true only if EVERY scenario is met AND weighted score ≥ 7.0>
SUMMARY: <one sentence>
SCENARIOS:
- [met|unmet] <scenario name>: <which test covers it, or why it's unmet>
ISSUES:
- [error|warning|info] <criterion>: <specific finding>
DETAILS:
<per-criterion breakdown>
```

---

## Phase 5 — Iterate or Advance

After receiving the Evaluator's verdict, update the plan file:

```markdown
### Task N: <name>
Status: done           ← or: failed
Expected Goals (from BDD scenarios):
- [x] Scenario: <name>
- [x] Scenario: <name>

## Iteration Log
### Task N — Iter M — score X.X/10 — PASS|FAIL
- Changed: ...
- Remaining: ...
```

| Condition | Action |
|-----------|--------|
| `PASSED: true` + tests pass | Mark task `done`. Move to next sub-task (Phase 3). |
| `SCORE < 7.0` or any scenario `unmet` | Re-spawn Executor with evaluator's findings. Increment iter count. |
| All tasks `done` | Proceed to **Phase 6 (Integrate & Verify Whole)** before declaring the plan done. |
| 5 iterations on one task with no pass | Mark task `Status: stalled`. Report blocker. Ask user how to proceed. |

Output after each Evaluate cycle:
```
[hars] PLAN-NNN  task=N/M  iter=K  score=X.X/10  status=PASS|FAIL  — <one sentence>
```

---

## Phase 6 — Integrate & Verify Whole (MANDATORY before done)

Per-task Evaluators only judged tasks in isolation. Cross-cutting behavior stays unverified until the pieces are assembled.

> ⛔ Do NOT set the plan `Status: done` from per-task passes alone.

1. Run the project's **Build cmd** and full **Test cmd** across the WHOLE project (not a single task dir). All must pass.
2. Exercise every scenario under `## Integration Scenarios` against the assembled system end-to-end — actually run the built artifact / top-level entrypoint and confirm each `Then` holds. Reading the code is not enough; drive it.
3. If a build or integration failure traces to a task, reopen that task at Phase 3 with the failure as context (increment its iter count), then re-run this phase.
4. Only when the whole build is green AND every Integration Scenario holds: set plan `Status: done` and report the overall summary to the user.

Output:
```
[hars] PLAN-NNN  integration  build=PASS|FAIL  scenarios=K/K  — <one sentence>
```

After the plan is done, persist durable takeaways back to the knowledge base so the next hars run retrieves them in Phase 0 — new decisions (with their *why*), architecture/interfaces added, and gotchas hit. Invoke the **save-to-knowledge-base** skill for this.

---

## Resume After Interruption

```bash
cat <working_dir>/bdd/BDD-NNN-<slug>.feature   # the approved spec
cat <working_dir>/plan/PLAN-NNN-<slug>.md      # progress + iteration log
cat ./knowledge/index.md 2>/dev/null           # re-orient in the knowledge base
```
Re-read the plan's `## Known Context` and the knowledge entries it links before continuing.
- If the BDD header is not `# Status: approved`, resume at Phase 1.
- Else if any task's `Status:` is not `done`, resume at the first such task (Phase 3), using its BDD scenarios, available interfaces, and Iteration Log as context.
- Else if every task is `done` but the plan is not `done`, resume at Phase 6 (integration).
