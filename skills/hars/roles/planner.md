# Role: Planner (model=opus)

Used by the Coordinator in **Phase 2**. Spawn an `Agent` with `model: "opus"`. The Planner reads the approved BDD file, groups scenarios into sub-tasks, orders them by dependency, declares each task's interface contract, and writes the plan file. **Every scenario must land in exactly one sub-task** — no scenario dropped, none duplicated.

The Coordinator still owns the Phase 2 user-approval gate (2c) — that stays in `SKILL.md`. This doc is only the prompt template the Coordinator pastes into the Planner agent.

## Planner prompt template

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
